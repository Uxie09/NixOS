#!/usr/bin/env bash

# Interactive NixOS installer for custom flake
# Run this script as root in the NixOS live environment

set -e

# Check if running in NixOS live ISO
if [ ! -f "/etc/nixos" ] || [ -d "/run/booted-system" ]; then
  echo -e "${RED}Error: This script must be run in the NixOS live ISO environment.${NC}"
  echo "Please boot the NixOS live ISO and try again."
  exit 1
fi

# Ensure script is run as root
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root. Try sudo $0" >&2
  exit 1
fi

# Enable flakes in the live environment
export NIX_CONFIG="experimental-features = nix-command flakes"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Welcome to my NixOS installer!${NC}"

list_disks() {
  echo "Available disks:"
  lsblk -d -o NAME,SIZE,MODEL | grep -v loop
}

# Function to check for available editors
check_editors() {
  local editors=("vim" "nano" "vi")
  for editor in "${editors[@]}"; do
    if command -v "$editor" &>/dev/null; then
      echo "$editor"
      return
    fi
  done
  echo "none"
}

# Start of prompts
echo -e "\n${GREEN}Let's configure your NixOS installation.${NC}"

# 1. Partitioning method
echo -e "\n${GREEN}Choose partitioning method:${NC}"
echo "1) Automatic (for single OS or clean disk)"
echo "2) Manual (for dual-boot or custom layouts, launches cfdisk)"
while true; do
  read -p "Enter choice (1 or 2): " part_choice
  case $part_choice in
    1) partitioning="auto"; break;;
    2) partitioning="manual"; break;;
    *) echo -e "${RED}Invalid choice. Enter 1 or 2.${NC}";;
  esac
done

# 2. Disk selection
echo -e "\n${GREEN}Select the disk to install NixOS on:${NC}"
list_disks
while true; do
  read -p "Enter disk name (e.g., sda, nvme0n1): " disk
  if [ -b "/dev/$disk" ]; then
    break
  else
    echo -e "${RED}Invalid disk. Please try again.${NC}"
  fi
done
disk="/dev/$disk"

# 3. Filesystem for root partition
echo -e "\n${GREEN}Choose filesystem for root partition:${NC}"
echo "1) ext4"
echo "2) btrfs"
while true; do
  read -p "Enter choice (1 or 2): " fs_choice
  case $fs_choice in
    1) filesystem="ext4"; break;;
    2) filesystem="btrfs"; break;;
    *) echo -e "${RED}Invalid choice. Enter 1 or 2.${NC}";;
  esac
done

# 4. LUKS encryption
echo -e "\n${GREEN}Enable LUKS encryption for root partition?${NC}"
echo "1) Yes"
echo "2) No"
while true; do
  read -p "Enter choice (1 or 2): " luks_choice
  case $luks_choice in
    1) luks_enabled="yes"; break;;
    2) luks_enabled="no"; break;;
    *) echo -e "${RED}Invalid choice. Enter 1 or 2.${NC}";;
  esac
done

# 5. LUKS password (if enabled)
if [ "$luks_enabled" = "yes" ]; then
  echo -e "\n${GREEN}Set LUKS encryption password:${NC}"
  while true; do
    read -s -p "Enter LUKS password: " luks_password
    echo
    read -s -p "Confirm LUKS password: " luks_password_confirm
    echo
    if [ "$luks_password" = "$luks_password_confirm" ]; then
      if [ -z "$luks_password" ]; then
        echo -e "${RED}LUKS password cannot be empty. Try again.${NC}"
      else
        break
      fi
    else
      echo -e "${RED}Passwords do not match. Try again.${NC}"
    fi
  done
fi

# 6. Username
echo -e "\n${GREEN}Set up a user account:${NC}"
while true; do
  read -p "Enter username: " username
  if [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    break
  else
    echo -e "${RED}Invalid username. Use lowercase letters, numbers, underscores, or hyphens.${NC}"
  fi
done

# 7. User password
echo -e "\n${GREEN}Set password for $username:${NC}"
while true; do
  read -s -p "Enter password: " password
  echo
  read -s -p "Confirm password: " password_confirm
  echo
  if [ "$password" = "$password_confirm" ]; then
    if [ -z "$password" ]; then
      echo -e "${RED}Password cannot be empty. Try again.${NC}"
    else
      break
    fi
  else
    echo -e "${RED}Passwords do not match. Try again.${NC}"
  fi
done

# 8. Editor for flake.nix
default_editor=$(check_editors)
if [ "$default_editor" = "none" ]; then
  echo -e "${RED}No editors found (vim, nano, vi). Falling back to installation without editing flake.nix.${NC}"
  editor="none"
else
  echo -e "\n${GREEN}Choose an editor to customize flake.nix:${NC}"
  echo "1) $default_editor (default)"
  echo "2) vim"
  echo "3) nano"
  echo "4) vi"
  echo "5) Skip editing"
  while true; do
    read -p "Enter choice (1-5, default 1): " editor_choice
    editor_choice=${editor_choice:-1}
    case $editor_choice in
      1) editor="$default_editor"; break;;
      2) editor="vim"; break;;
      3) editor="nano"; break;;
      4) editor="vi"; break;;
      5) editor="none"; break;;
      *) echo -e "${RED}Invalid choice. Enter 1-5.${NC}";;
    esac
    # Verify editor exists
    if [ "$editor" != "none" ] && ! command -v "$editor" &>/dev/null; then
      echo -e "${RED}Editor $editor not found. Please choose another.${NC}"
    else
      break
    fi
  done
fi

# Display summary and confirm
echo -e "\n${GREEN}Installation Summary:${NC}"
echo "Partitioning: $partitioning"
echo "Disk: $disk"
echo "Filesystem: $filesystem"
echo "LUKS Encryption: $luks_enabled"
echo "Username: $username"
echo "Flake Editor: $editor"
if [ "$partitioning" = "manual" ]; then
  echo "Note: You will assign EFI, root, and swap partitions after cfdisk."
fi
if [ "$luks_enabled" = "yes" ]; then
  echo "LUKS Password: [hidden]"
fi
echo "User Password: [hidden]"
echo "Note: Hostname and other settings can be customized in flake.nix during editing."
read -p "Proceed with installation? (y/N): " confirm
if [[ ! "$confirm" =~ ^[yY]$ ]]; then
  echo -e "${RED}Installation aborted.${NC}"
  exit 1
fi

# Begin installation steps
echo -e "\n${GREEN}Starting installation...${NC}"

# Handle partitioning
echo -e "\n${GREEN}Setting up disk partitions...${NC}"
if [ "$partitioning" = "auto" ]; then
  # Automatic partitioning: 512M EFI, 2G swap, rest for root
  echo "Creating automatic partition layout..."
  wipefs -a "$disk"
  parted -s "$disk" \
    mklabel gpt \
    mkpart primary fat32 1MiB 513MiB \
    set 1 esp on \
    mkpart primary linux-swap 513MiB 2561MiB \
    mkpart primary 2561MiB 100%
  # Set partition variables
  if [[ "$disk" =~ nvme ]]; then
    part_boot="${disk}p1"
    part_swap="${disk}p2"
    part_root="${disk}p3"
  else
    part_boot="${disk}1"
    part_swap="${disk}2"
    part_root="${disk}3"
  fi
else
  # Manual partitioning with cfdisk
  echo "Launching cfdisk for manual partitioning..."
  echo "Please create partitions, including EFI, root, and optionally a swap. Save and quit when done."
  cfdisk "$disk"
  echo -e "\n${GREEN}Partitioning complete. Please specify partition assignments:${NC}"
  list_disks
  # Prompt for EFI partition
  while true; do
    read -p "Enter EFI partition (e.g., ${disk}1, ${disk}p1): " part_boot
    if [ -b "/dev/$part_boot" ]; then
      break
    else
      echo -e "${RED}Invalid partition. Try again.${NC}"
    fi
  done
  # Prompt for root partition
  while true; do
    read -p "Enter root partition (e.g., ${disk}2, ${disk}p2): " part_root
    if [ -b "/dev/$part_root" ] && [ "/dev/$part_root" != "/dev/$part_boot" ]; then
      break
    else
      echo -e "${RED}Invalid or same as EFI partition. Try again.${NC}"
    fi
  done
  # Prompt for swap partition (optional)
  echo "Swap partition is optional. Leave blank to skip."
  read -p "Enter swap partition (e.g., ${disk}3, ${disk}p3, or blank): " part_swap
  if [ -n "$part_swap" ] && [ ! -b "/dev/$part_swap" ]; then
    echo -e "${RED}Invalid swap partition. Skipping swap.${NC}"
    part_swap=""
  elif [ "/dev/$part_swap" = "/dev/$part_boot" ] || [ "/dev/$part_swap" = "/dev/$part_root" ]; then
    echo -e "${RED}Swap cannot be same as EFI or root. Skipping swap.${NC}"
    part_swap=""
  fi
fi

# Set up LUKS if enabled
if [ "$luks_enabled" = "yes" ]; then
  echo -e "\n${GREEN}Setting up LUKS encryption...${NC}"
  echo -n "$luks_password" | cryptsetup luksFormat "$part_root" -
  echo -n "$luks_password" | cryptsetup luksOpen "$part_root" luks-root -
  root_device="/dev/mapper/luks-root"
else
  root_device="$part_root"
fi

# Format partitions
echo -e "\n${GREEN}Formatting partitions...${NC}"
mkfs.fat -F32 "$part_boot"
if [ "$filesystem" = "ext4" ]; then
  mkfs.ext4 -F "$root_device"
elif [ "$filesystem" = "btrfs" ]; then
  mkfs.btrfs -f "$root_device"
fi
if [ -n "$part_swap" ]; then
  mkswap "$part_swap"
fi

# Mount filesystems
echo -e "\n${GREEN}Mounting filesystems...${NC}"
mount "$root_device" /mnt
mkdir -p /mnt/boot
mount "$part_boot" /mnt/boot
if [ -n "$part_swap" ]; then
  swapon "$part_swap"
fi

# Clone custom flake
echo -e "\n${GREEN}Cloning custom flake...${NC}"
mkdir -p /mnt/etc/nixos
git clone https://github.com/authxt/NixOS /mnt/etc/nixos

# Generate hardware configuration
echo -e "\n${GREEN}Generating hardware configuration...${NC}"
# mkdir -p /mnt/etc/nixos/hosts/Default
nixos-generate-config --show-hardware-config > /mnt/etc/nixos/hosts/Default/hardware-configuration.nix

# Edit flake.nix
if [ "$editor" != "none" ]; then
  echo -e "\n${GREEN}Opening flake.nix in $editor for customization...${NC}"
  echo "Edit the 'settings' block to customize username, editor, browser, hostname, etc."
  echo "Save and exit when done (e.g., :wq for vim, Ctrl+O then Ctrl+X for nano)."
  read -p "Press Enter to continue..."
  $editor /mnt/etc/nixos/flake.nix
else
  echo -e "${GREEN}Skipping flake.nix editing as requested or no editor available.${NC}"
fi

# replace username variable in flake.nix with $USER
sed -i -e "s/username = \".*\"/username = \"$username\"/" /mnt/etc/nixos/flake.nix

# Run nixos-install
echo -e "\n${GREEN}Running nixos-install...${NC}"
nixos-install --flake /mnt/etc/nixos#Default --no-root-passwd

# Clean up
echo -e "\n${GREEN}Cleaning up...${NC}"
umount -R /mnt
if [ -n "$part_swap" ]; then
  swapoff "$part_swap"
fi
if [ "$luks_enabled" = "yes" ]; then
  cryptsetup luksClose luks-root
fi

echo -e "\n${GREEN}Installation complete! Reboot to start your new NixOS system.${NC}"
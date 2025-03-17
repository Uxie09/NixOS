{
  pkgs,
  videoDriver,
  hostname,
  browser,
  editor,
  terminal,
  terminalFileManager,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardware/video/${videoDriver}.nix # Enable gpu drivers defined in flake.nix
    ../../modules/hardware/drives

    ../common.nix
    ../../modules/scripts

    ../../modules/desktop/hyprland # Enable hyprland window manager

    ../../modules/programs/games
    ../../modules/programs/browser/${browser} # Set browser defined in flake.nix
    ../../modules/programs/terminal/${terminal} # Set terminal defined in flake.nix
    ../../modules/programs/editor/${editor} # Set editor defined in flake.nix
    ../../modules/programs/cli/${terminalFileManager} # Set file-manager defined in flake.nix
    ../../modules/programs/cli/starship
    ../../modules/programs/cli/tmux
    ../../modules/programs/cli/direnv
    ../../modules/programs/cli/lazygit
    ../../modules/programs/cli/cava
    ../../modules/programs/cli/btop
    ../../modules/programs/shell/bash
    ../../modules/programs/shell/zsh
    ../../modules/programs/media/discord
    ../../modules/programs/media/spicetify
    ../../modules/programs/media/thunderbird
    ../../modules/programs/media/obs-studio
    ../../modules/programs/media/mpv
    ../../modules/programs/misc/tlp
    ../../modules/programs/misc/thunar
    # ../../modules/programs/misc/nix-ld
    # ../../modules/programs/misc/virt-manager
    # ../../modules/programs/misc/lact # gpu power and fan control (WIP)
  ];

  # Home-manager config
  home-manager.sharedModules = [
    (_: {
      home.packages = with pkgs; [
        # (pkgs.callPackage ../../pkgs/pokego.nix {})
        krita
        gimp
        # kdePackages.okular # pdf viwer
        # godot_4
        # unityhub
        # gparted
        vscode
        nitch
        pnpm
        neofetch
        clang
        nodejs
        python3
        brave
        google-chrome
        libreoffice
      ];
    })
  ];

  # Define system packages here
  environment.systemPackages = with pkgs; [
    jetbrains.webstorm
    rustup
    cargo

  ];

  networking.hostName = hostname; # Set hostname defined in flake.nix

  # Stream my Language lessons to my devices via vlc media player
  services.minidlna = {
    enable = true;
    openFirewall = true;
    settings = {
      friendly_name = "NixOS-DLNA";
      media_dir = [
        # A = Audio, P = Pictures, V, = Videos, PV = Pictures and Videos.
        "/mnt/work/Pimsleur"
        # "A,/mnt/work/Pimsleur/Russian"
      ];
      inotify = "yes";
      log_level = "error";
    };
  };
  users.users.minidlna = {
    extraGroups = ["users"]; # so minidlna can access the files.
  };
}

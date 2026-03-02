# Shared home configuration template for full server tooling
{
  config,
  pkgs,
  lib,
  inputs,
  username,
  hostname,
  ...
}: {
  imports = [
    inputs.nixvim.homeModules.nixvim
    ../configs/nixvim.nix
    ../configs/kitty.nix
    ../configs/zsh.nix
    ../configs/oh-my-posh.nix
    ../configs/zoxide.nix
    ../configs/fd.nix
    ../configs/fzf.nix
    ../configs/ripgrep.nix
    ../configs/jq.nix
    ../configs/opencode.nix
    ../configs/fastfetch.nix
  ];
  options = {
    packageSet = lib.mkOption {
      type = lib.types.attrs;
      default = pkgs;
      description = "The package set to use for installing packages";
    };
    cpu_architecture = lib.mkOption {
      type = lib.types.str;
      default =
        if pkgs.stdenv.hostPlatform.system == "aarch64-linux"
        then "aarch64"
        else "x86_64";
      description = "CPU architecture for Flatpak and other tools";
    };
  };
  config = lib.mkMerge [
    {
      home.stateVersion = "25.05";
      home.username = username;
      home.homeDirectory = "/home/${username}";

      home.packages = with pkgs; [
        (pkgs.writeShellScriptBin "cat-files" (builtins.readFile ../scripts/cat-files.sh))
        btop
        tree
        home-manager
        lsd
        inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
        fzf
        gemini-cli
        tldr
        rofi
        xdg-desktop-portal-gtk
      ];

      xdg.desktopEntries."superfile" = {
        name = "Superfile (TUI)";
        genericName = "TUI File Manager";
        comment = "Fast and modern TUI file manager";
        exec = "superfile";
        icon = "utilities-terminal";
        terminal = true;
        categories = ["Utility" "FileTools"];
        mimeType = ["inode/directory"];
      };

      programs.git = {
        enable = true;
        settings = {
          user.name = "cod";
          user.email = "cod@cod.com";
        };
      };

      home.file.".config/rofi" = {
        source = "${inputs.dotfiles}/rofi";
        recursive = true;
      };

      age.identityPaths = ["${config.home.homeDirectory}/.ssh/id_ed25519"];
      home.sessionVariables = {
        GH_TOKEN = "$(cat ${config.age.secrets.GH_TOKEN.path})";
      };
    }
  ];
}

# templates/minimal-home.nix — Lightweight home config for VPS/simple servers
# Used by mkVps. For full homelab servers, use server-home.nix instead.
{
  inputs,
  config,
  pkgs,
  lib,
  username,
  hostname,
  ...
}: {
  imports = [
    ../configs/zsh.nix
    ../configs/oh-my-posh.nix
    ../configs/zoxide.nix
    ../configs/fastfetch.nix
  ];

  options.packageSet = lib.mkOption {
    type = lib.types.attrs;
    default = pkgs;
    description = "The package set to use for installing packages";
  };

  config = {
    home.stateVersion = "25.05";
    home.username = username;
    home.homeDirectory = "/home/${username}";

    home.packages = with pkgs; [
      btop
      tree
      home-manager
      lsd
      inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    programs.git = {
      enable = true;
      settings = {
        user.name = "cod";
        user.email = "cod@cod.com";
      };
    };

    age.identityPaths = ["/home/${username}/.ssh/id_ed25519"];
  };
}

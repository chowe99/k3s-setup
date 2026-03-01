{ lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    git
    curl
  ];

  # SSH authorized keys for root
  # REPLACE THIS WITH YOUR PUBLIC KEY
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAvwD8Or0RnfKcvW4jAWdgDaijtt9H/N3l10Dc0yIF1l slayer@nix-config"
  ];

  system.stateVersion = "25.05";
}

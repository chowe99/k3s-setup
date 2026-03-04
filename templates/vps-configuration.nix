# templates/vps-configuration.nix — Parameterized VPS template
# Used by mkVps in flake.nix. Service modules come via extraModules, not imports here.
{
  config,
  pkgs,
  lib,
  hostname,
  username,
  ...
}: {
  options.vps = with lib; {
    publicIp = mkOption {
      type = types.str;
      description = "Public IPv4 address";
    };
    gateway = mkOption {
      type = types.str;
      description = "Default gateway address";
    };
    interface = mkOption {
      type = types.str;
      default = "ens3";
      description = "Primary network interface";
    };
    bootDevice = mkOption {
      type = types.str;
      default = "/dev/vda";
      description = "Boot device for GRUB";
    };
    prefixLength = mkOption {
      type = types.int;
      default = 24;
      description = "Network prefix length";
    };
    authorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "SSH authorized public keys for root and the main user";
    };
    firewallTCPPorts = mkOption {
      type = types.listOf types.port;
      default = [22 80 443];
      description = "Allowed TCP ports in the firewall";
    };
    firewallUDPPorts = mkOption {
      type = types.listOf types.port;
      default = [];
      description = "Allowed UDP ports in the firewall";
    };
  };

  config = let
    cfg = config.vps;
  in {
    assertions = [
      {
        assertion = cfg.authorizedKeys != [];
        message = "vps.authorizedKeys must contain at least one SSH public key";
      }
    ];
    nix.settings.experimental-features = ["nix-command" "flakes"];

    # Bootloader (BIOS/MBR — standard for cloud VPS)
    boot.loader.grub.enable = true;
    boot.loader.grub.device = cfg.bootDevice;

    # Networking
    networking.hostName = hostname;
    networking.nameservers = ["9.9.9.9" "149.112.112.112"];
    networking.useDHCP = false;
    networking.interfaces.${cfg.interface} = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = cfg.publicIp;
          prefixLength = cfg.prefixLength;
        }
      ];
    };
    networking.defaultGateway = {
      address = cfg.gateway;
      interface = cfg.interface;
    };
    networking.firewall = {
      enable = true;
      allowedTCPPorts = cfg.firewallTCPPorts;
      allowedUDPPorts = cfg.firewallUDPPorts;
      trustedInterfaces = ["docker0" "br-+"];
    };

    # Tailscale
    nixpkgs.overlays = [
      (self: super: {
        tailscale = super.tailscale.overrideAttrs (old: {
          doCheck = false;
        });
      })
    ];
    services.tailscale.enable = true;

    # Docker
    virtualisation.docker.enable = true;
    virtualisation.oci-containers.backend = "docker";

    # Time and locale
    time.timeZone = "Australia/Perth";
    i18n.defaultLocale = "en_AU.UTF-8";

    # User configuration
    users.users.${username} = {
      isNormalUser = true;
      description = username;
      extraGroups = ["wheel" "docker"];
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };

    users.users.root.openssh.authorizedKeys.keys = cfg.authorizedKeys;

    programs.zsh.enable = true;
    nixpkgs.config.allowUnfree = true;

    # SSH
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "yes";
        PubkeyAuthentication = true;
      };
    };

    security.sudo = {
      enable = true;
      extraRules = [
        {
          users = [username];
          commands = [
            {
              command = "/run/current-system/sw/bin/nixos-rebuild";
              options = ["NOPASSWD"];
            }
          ];
        }
      ];
    };

    # Agenix identity paths
    age.identityPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/home/${username}/.ssh/id_ed25519"
    ];

    environment.systemPackages = with pkgs; [
      vim
      wget
      git
      docker
      alejandra
      dig
      lsof
      btop
    ];

    system.stateVersion = "25.05";
  };
}

{
  description = "Standalone web app deployment infrastructure — K3s + Gitea CI/CD";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nixvim = {
      url = "github:nix-community/nixvim/";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      agenix,
      disko,
      ...
    } @ inputs: let
    lib = nixpkgs-unstable.lib;
    baseDomain = "";
    tld = "";
    fullDomain = "${baseDomain}.${tld}";

    # VPS nodes — add entries here as you provision new servers
    servers = {
      # Example:
      # webvps1 = { publicIp = "203.0.113.10"; };
      myNymBox = { publicIp = ""; };

    };

    nixosSystem = {
      system,
      hostname,
      username,
      modules,
    }:
      nixpkgs-unstable.lib.nixosSystem {
        specialArgs = {
          inherit inputs servers baseDomain tld;
          inherit hostname username;
        };
        modules =
          modules
          ++ [
            {nixpkgs.hostPlatform = system;}
          ];
      };

    # Generator for full server configurations (with Hyprland desktop)
    mkServer = {
      hostname,
      username ? hostname,
      system ? "x86_64-linux",
      hostConfig ? ./hosts/${hostname}/configuration.nix,
      homeConfig ? ./templates/server-home.nix,
      extraModules ? [],
    }:
      nixosSystem {
        inherit system hostname username;
        modules =
          [
            hostConfig
            inputs.agenix.nixosModules.default
            inputs.home-manager.nixosModules.home-manager
            {
              environment.systemPackages = [
                inputs.agenix.packages.${system}.default
              ];
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${username} = import homeConfig;
              home-manager.extraSpecialArgs = {
                inherit inputs servers baseDomain tld;
                inherit hostname username;
              };
              home-manager.sharedModules = [inputs.agenix.homeManagerModules.default];
            }
          ]
          ++ extraModules;
      };

    # Generator for VPS configurations — no per-host files needed
    mkVps = {
      hostname,
      username ? hostname,
      system ? "x86_64-linux",
      publicIp,
      gateway,
      interface ? "ens3",
      bootDevice ? "/dev/vda",
      prefixLength ? 24,
      hardwareConfig ? null,
      services ? [],
      extraModules ? [],
      useGeneric ? false,
    }:
      let
        baseModules = if useGeneric then genericModules else [];
        hwConfig = if hardwareConfig != null then hardwareConfig else ./hosts/${if useGeneric then "generic" else hostname}/hardware-configuration.nix;
      in
        mkServer {
          inherit hostname username system;
          hostConfig = ./templates/vps-configuration.nix;
          homeConfig = ./templates/minimal-home.nix;
          extraModules =
            baseModules
            ++ [
              hwConfig
              {
                vps = {inherit publicIp gateway interface bootDevice prefixLength;};
              }
            ]
            ++ services
            ++ extraModules;
        };

    genericModules = [
      disko.nixosModules.disko
      ./hosts/generic/disk-config.nix
      ./hosts/generic/configuration.nix
    ];
  in {
    # Shared NixOS module for K3s cluster management
    nixosModules = {
      k3s-cluster = import ./k3s/module.nix;
      default = self.nixosModules.k3s-cluster;
    };

    # Shared home-manager modules for tool configs
    homeManagerModules = let
      zsh = import ./configs/zsh.nix;
      nixvim = import ./configs/nixvim.nix;
      kitty = import ./configs/kitty.nix;
      oh-my-posh = import ./configs/oh-my-posh.nix;
      zoxide = import ./configs/zoxide.nix;
      fd = import ./configs/fd.nix;
      fzf = import ./configs/fzf.nix;
      ripgrep = import ./configs/ripgrep.nix;
      jq = import ./configs/jq.nix;
      fastfetch = import ./configs/fastfetch.nix;
      claude-code = import ./configs/claude-code.nix;
      opencode = import ./configs/opencode.nix;
    in {
      inherit zsh nixvim kitty oh-my-posh zoxide fd fzf ripgrep jq fastfetch claude-code opencode;
      # Bundle: all shared configs for a full server
      server-tools = {
        imports = [zsh nixvim kitty oh-my-posh zoxide fd fzf ripgrep jq fastfetch claude-code opencode];
      };
      # Bundle: minimal set for VPS
      minimal-tools = {
        imports = [zsh oh-my-posh zoxide fastfetch];
      };
    };

    nixosConfigurations = {
      myNymBox = mkVps {
        hostname = "myNymBox";
        publicIp = "";
        gateway = "80.71.235.1";
        useGeneric = true;
        bootDevice = "/dev/sda";
        interface = "enp3s0";
        services = [
          ./k3s
          ./configs/system-agenix.nix
          {
            k3s-cluster.enable = true;
          }
        ];
      };

      # NixOS Anywhere generic configuration
      # Run: nix run nixpkgs#nixos-anywhere -- --flake .#generic --generate-hardware-config nixos-generate-config ./hosts/generic/hardware-configuration.nix root@<IP>
      # After first install, remove --generate-hardware-config and use: nix run nixpkgs#nixos-anywhere -- .#generic root@<IP>
      generic = nixpkgs-unstable.lib.nixosSystem {
        system = "x86_64-linux";
        modules = genericModules;
      };
    };
  };
}

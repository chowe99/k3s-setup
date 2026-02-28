{
  description = "Standalone web app deployment infrastructure — K3s + Gitea CI/CD";
  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    dotfiles = {
      url = "git+https://git.howse.top/cod/dotfiles";
      flake = false;
    };
    nixvim = {
      url = "github:nix-community/nixvim/";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };
  outputs = {
    self,
    nixpkgs-unstable,
    home-manager,
    agenix,
    ...
  } @ inputs: let
    lib = nixpkgs-unstable.lib;
    baseDomain = "howse";
    tld = "top";
    fullDomain = "${baseDomain}.${tld}";

    # VPS nodes — add entries here as you provision new servers
    servers = {
      # Example:
      # webvps1 = { publicIp = "203.0.113.10"; };
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
      hardwareConfig ? ./hosts/${hostname}/hardware-configuration.nix,
      services ? [],
      extraModules ? [],
    }:
      mkServer {
        inherit hostname username system;
        hostConfig = ./templates/vps-configuration.nix;
        homeConfig = ./templates/minimal-home.nix;
        extraModules =
          [
            hardwareConfig
            {
              vps = {inherit publicIp gateway interface bootDevice prefixLength;};
            }
          ]
          ++ services
          ++ extraModules;
      };
  in {
    nixosConfigurations = {
      # Add VPS nodes here, e.g.:
      # webvps1 = mkVps {
      #   hostname = "webvps1";
      #   publicIp = "203.0.113.10";
      #   gateway = "203.0.113.1";
      # };
    };
  };
}

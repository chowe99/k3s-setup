{
  description = "Shared infrastructure library — K3s modules, home-manager tools, VPS templates";

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
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    agenix,
    ...
  } @ inputs: {
    # NixOS modules
    nixosModules = {
      k3s-cluster = import ./k3s/module.nix;
      vps-configuration = import ./templates/vps-configuration.nix;
      generic-host = {
        imports = [
          ./hosts/generic/disk-config.nix
          ./hosts/generic/configuration.nix
        ];
      };
      default = self.nixosModules.k3s-cluster;
    };

    # Home-manager modules (individual tools + bundles)
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

      # Template modules (for consumers that want the full template experience)
      minimal-home = import ./templates/minimal-home.nix;
      server-home = import ./templates/server-home.nix;
    };
  };
}

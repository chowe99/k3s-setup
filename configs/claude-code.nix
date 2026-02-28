{
  config,
  pkgs,
  lib,
  baseDomain,
  tld,
  ...
}: let
  fullDomain = "${baseDomain}.${tld}";
in {
  home.packages = with pkgs; [
    gemini-cli
  ];

  programs.claude-code = {
    enable = true;
    mcpServers = {
      nixos = {
        args = [
          "run"
          "github:utensils/mcp-nixos"
          "--"
        ];
        command = "nix";
      };
    };
  };
}

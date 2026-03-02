# k3s/default.nix — Local entry point for VPS K3s configuration
# Imports the shared module.nix and sets VPS-specific defaults
{
  config,
  lib,
  servers,
  baseDomain,
  tld,
  ...
}: let
  serverNames = builtins.attrNames servers;
  sortedNames = builtins.sort (a: b: a < b) serverNames;
  initialServerName =
    if serverNames != []
    then builtins.head sortedNames
    else null;
in {
  imports = [
    ./module.nix
    ./secrets.nix
  ];

  config = {
    k3s-cluster = {
      cluster.nodes = lib.mapAttrs (name: cfg: {
        ip = cfg.publicIp or "127.0.0.1";
        isInitialServer = name == initialServerName;
      }) servers;

      services.gitea.enable = lib.mkDefault true;
      services.gitea-runner.enable = lib.mkDefault true;
      services.cloudnativepg.enable = lib.mkDefault true;
    };
  };
}

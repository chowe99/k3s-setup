# k3s/default.nix — Main module: options, manifest writer, imports
{
  config,
  lib,
  pkgs,
  hostname,
  username,
  servers,
  baseDomain,
  tld,
  ...
}: let
  fullDomain = "${baseDomain}.${tld}";
  cfg = config.k3s-cluster;

  k3sLib = import ./lib.nix {inherit lib fullDomain;};

  # Convert each manifest attrset to a JSON file in the nix store
  manifestFiles =
    lib.mapAttrs'
    (name: resource:
      lib.nameValuePair name (pkgs.writeText "${name}.json" (builtins.toJSON resource)))
    cfg.manifests;
in {
  imports = [
    ./cluster.nix
    ./secrets.nix
    ./services
    ./infrastructure
  ];

  options.k3s-cluster = {
    enable = lib.mkEnableOption "Enable K3s cluster node";
    manifests = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "K8s manifests to deploy via K3s auto-deploy. Each value is a K8s resource attrset that gets serialized to JSON.";
    };
  };

  config = {
    # Pass k3sLib, fullDomain, and servers to all service modules unconditionally
    _module.args.k3sLib = k3sLib;
    _module.args.fullDomain = fullDomain;
    _module.args.servers = servers;

    # Only deploy manifests when K3s is enabled
    systemd.tmpfiles.rules = lib.mkIf cfg.enable (
      lib.mapAttrsToList
      (name: path: "L+ /var/lib/rancher/k3s/server/manifests/nix-${name}.json - - - - ${path}")
      manifestFiles
    );
  };
}

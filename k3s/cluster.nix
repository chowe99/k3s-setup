# k3s/cluster.nix — K3s cluster node configuration (dynamic VPS topology)
{
  config,
  pkgs,
  lib,
  hostname,
  username,
  servers,
  ...
}: let
  # Derive K3s nodes from the servers attrset passed via specialArgs.
  # Each server entry with a publicIp becomes a K3s node.
  # The first node alphabetically (or explicitly marked) is the initial server.
  serverNames = builtins.attrNames servers;
  hasNodes = serverNames != [];

  # First server in sorted order is the initial server
  sortedNames = builtins.sort (a: b: a < b) serverNames;
  initialServerName =
    if hasNodes
    then builtins.head sortedNames
    else null;

  k3sNodes = lib.mapAttrs (name: cfg: {
    role = "server";
    ip = cfg.publicIp or "127.0.0.1";
    isInitialServer = name == initialServerName;
    flannelIface = null;
  }) servers;

  thisNode = k3sNodes.${hostname} or null;
  initialServerIp =
    if initialServerName != null
    then k3sNodes.${initialServerName}.ip
    else "127.0.0.1";

  commonFlags = [
    "--disable=traefik"
    "--kube-controller-manager-arg=node-monitor-grace-period=20s"
    "--kube-apiserver-arg=default-not-ready-toleration-seconds=30"
    "--kube-apiserver-arg=default-unreachable-toleration-seconds=30"
  ];

  nodeSpecificFlags =
    if thisNode == null
    then []
    else
      [
        "--node-ip=${thisNode.ip}"
      ]
      ++ (lib.optionals (thisNode.flannelIface != null) [
        "--flannel-iface=${thisNode.flannelIface}"
      ])
      ++ (
        if thisNode.isInitialServer
        then [
          "--cluster-init"
          "--advertise-address=${thisNode.ip}"
        ]
        else [
          "--server=https://${initialServerIp}:6443"
          "--advertise-address=${thisNode.ip}"
        ]
      );
in {
  config = lib.mkIf (config.k3s-cluster.enable && thisNode != null) {
    services.k3s = {
      enable = true;
      role = thisNode.role;
      tokenFile = "/run/agenix/k3s-token";
      extraFlags = toString (commonFlags ++ nodeSpecificFlags);
    };

    environment.variables.KUBECONFIG = "/home/${username}/.kube/config";

    environment.systemPackages = with pkgs; [
      kubectl
      k3s
      etcd
    ];
  };
}

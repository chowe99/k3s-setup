# k3s/module.nix — Shared NixOS module for K3s cluster management
# Importable by any repo via nixosModules.k3s-cluster
# Defines options for cluster topology, shared services (gitea, gitea-runner, CNPG),
# and handles manifest-to-JSON-to-tmpfiles + K3s service configuration.
#
# NOTE: baseDomain, tld, hostname, and username must be passed via specialArgs in the flake.
# They flow through specialArgs -> _module.args for submodule access without depending on config.
{
  config,
  lib,
  pkgs,
  hostname,
  username,
  baseDomain ? "",
  tld ? "",
  ...
}: let
  # These depend only on function args (specialArgs), never on config
  fullDomain = "${baseDomain}.${tld}";
  k3sLib = import ./lib.nix {inherit lib fullDomain;};
in {
  imports = [
    ./services/gitea.nix
    ./services/gitea-runner.nix
    ./infrastructure/cloudnativepg.nix
  ];

  options.k3s-cluster = {
    enable = lib.mkEnableOption "K3s cluster node";

    manifests = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "K8s manifests to deploy via K3s auto-deploy. Each value is a K8s resource attrset that gets serialized to JSON.";
    };

    cluster = {
      nodes = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            role = lib.mkOption {
              type = lib.types.str;
              default = "server";
              description = "K3s node role (server or agent)";
            };
            ip = lib.mkOption {
              type = lib.types.str;
              description = "Node IP address";
            };
            isInitialServer = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether this is the initial cluster server (runs --cluster-init)";
            };
            flannelIface = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Network interface for Flannel CNI";
            };
          };
        });
        default = {};
        description = "K3s cluster node definitions";
      };

      commonFlags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "--disable=traefik"
          "--kube-controller-manager-arg=node-monitor-grace-period=20s"
          "--kube-apiserver-arg=default-not-ready-toleration-seconds=30"
          "--kube-apiserver-arg=default-unreachable-toleration-seconds=30"
        ];
        description = "Common K3s flags applied to all nodes";
      };
    };

    services.gitea = {
      enable = lib.mkEnableOption "Gitea";
      sshPort = lib.mkOption {
        type = lib.types.int;
        default = 22;
        description = "SSH port for Gitea (container + service)";
      };
      sshEnabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether SSH access is enabled";
      };
      livenessInitialDelay = lib.mkOption {
        type = lib.types.int;
        default = 60;
        description = "Liveness probe initial delay in seconds";
      };
      livenessFailureThreshold = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "Liveness probe failure threshold";
      };
      affinity = lib.mkOption {
        type = lib.types.attrs;
        default = {};
        description = "Kubernetes affinity rules for the Gitea deployment";
      };
      storageSize = lib.mkOption {
        type = lib.types.str;
        default = "50Gi";
        description = "PVC storage size for Gitea data";
      };
    };

    services.gitea-runner = {
      enable = lib.mkEnableOption "Gitea Actions runner";
      dockerMode = lib.mkOption {
        type = lib.types.enum ["tls" "socket"];
        default = "tls";
        description = "Docker connection mode: 'tls' uses tcp://localhost:2376 with TLS certs, 'socket' uses unix socket";
      };
      affinity = lib.mkOption {
        type = lib.types.attrs;
        default = {};
        description = "Kubernetes affinity rules for the runner deployment";
      };
      storageSize = lib.mkOption {
        type = lib.types.str;
        default = "20Gi";
        description = "PVC storage size for runner data";
      };
    };

    services.cloudnativepg = {
      enable = lib.mkEnableOption "CloudNativePG";
      storageSize = lib.mkOption {
        type = lib.types.str;
        default = "10Gi";
        description = "Storage size per CNPG instance";
      };
      instances = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "Number of PostgreSQL instances in the cluster";
      };
      resources = {
        requests = {
          memory = lib.mkOption {
            type = lib.types.str;
            default = "512Mi";
            description = "Memory request per CNPG instance";
          };
          cpu = lib.mkOption {
            type = lib.types.str;
            default = "500m";
            description = "CPU request per CNPG instance";
          };
        };
        limits = {
          memory = lib.mkOption {
            type = lib.types.str;
            default = "2Gi";
            description = "Memory limit per CNPG instance";
          };
          cpu = lib.mkOption {
            type = lib.types.str;
            default = "2000m";
            description = "CPU limit per CNPG instance";
          };
        };
      };
      bootstrap = {
        database = lib.mkOption {
          type = lib.types.str;
          default = "app";
          description = "Database to create during CNPG bootstrap";
        };
        owner = lib.mkOption {
          type = lib.types.str;
          default = "app";
          description = "Owner of the bootstrap database";
        };
        secret = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "K8s secret name with 'username' and 'password' keys for the DB owner. If empty, CNPG uses auto-generated credentials.";
        };
      };
      postgresqlParameters = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {
          max_connections = "200";
          shared_buffers = "256MB";
          effective_cache_size = "768MB";
          maintenance_work_mem = "64MB";
          checkpoint_completion_target = "0.9";
          wal_buffers = "7864kB";
          default_statistics_target = "100";
          random_page_cost = "1.1";
          effective_io_concurrency = "200";
          work_mem = "655kB";
          min_wal_size = "1GB";
          max_wal_size = "4GB";
        };
        description = "PostgreSQL configuration parameters";
      };
    };
  };

  config = let
    # Config-dependent values (evaluated lazily within config section)
    cfg = config.k3s-cluster;

    manifestFiles =
      lib.mapAttrs'
      (name: resource:
        lib.nameValuePair name (pkgs.writeText "${name}.json" (builtins.toJSON resource)))
      cfg.manifests;

    k3sNodes = cfg.cluster.nodes;
    thisNode = k3sNodes.${hostname} or null;
    initialServerNames = builtins.filter (name: k3sNodes.${name}.isInitialServer) (builtins.attrNames k3sNodes);
    initialServerName =
      if initialServerNames != []
      then builtins.head initialServerNames
      else null;
    initialServerIp =
      if initialServerName != null
      then k3sNodes.${initialServerName}.ip
      else "127.0.0.1";

    commonFlags = cfg.cluster.commonFlags;
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
  in
    lib.mkMerge [
      # Pass k3sLib and fullDomain to all modules — these don't depend on config
      {
        _module.args.k3sLib = k3sLib;
        _module.args.fullDomain = fullDomain;
      }

      # Manifest writer: deploy manifests when K3s is enabled
      (lib.mkIf cfg.enable {
        systemd.tmpfiles.rules =
          lib.mapAttrsToList
          (name: path: "L+ /var/lib/rancher/k3s/server/manifests/nix-${name}.json - - - - ${path}")
          manifestFiles;
      })

      # K3s service configuration derived from cluster.nodes
      (lib.mkIf (cfg.enable && thisNode != null) {
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
      })
    ];
}

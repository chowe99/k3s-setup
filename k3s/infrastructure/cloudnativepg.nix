# k3s/infrastructure/cloudnativepg.nix — CloudNativePG cluster + NodePort (shared module)
# Activated via k3s-cluster.services.cloudnativepg.enable, parameterized via options
{
  config,
  lib,
  k3sLib,
  ...
}: let
  cfg = config.k3s-cluster;
  cnpgCfg = cfg.services.cloudnativepg;
in {
  config = lib.mkIf (cfg.enable && cnpgCfg.enable) {
    # Secret "postgresql-cluster-superuser" is injected by k3s/secrets.nix (cnpg-k8s-secrets service)
    k3s-cluster.manifests.cloudnativepg = k3sLib.mkList [
      # CNPG Cluster CRD
      {
        apiVersion = "postgresql.cnpg.io/v1";
        kind = "Cluster";
        metadata = {
          name = "postgresql-cluster";
          namespace = "default";
        };
        spec = {
          description = "Production PostgreSQL cluster for homelab applications";
          imageName = "ghcr.io/cloudnative-pg/postgresql:17.2";
          instances = cnpgCfg.instances;
          storage = {
            size = cnpgCfg.storageSize;
            storageClass = "local-path";
          };
          resources = {
            requests = {
              memory = cnpgCfg.resources.requests.memory;
              cpu = cnpgCfg.resources.requests.cpu;
            };
            limits = {
              memory = cnpgCfg.resources.limits.memory;
              cpu = cnpgCfg.resources.limits.cpu;
            };
          };
          priorityClassName = "";
          affinity = {
            enablePodAntiAffinity = true;
            topologyKey = "kubernetes.io/hostname";
          };
          postgresql.parameters = cnpgCfg.postgresqlParameters;
          superuserSecret.name = "postgresql-cluster-superuser";
        };
      }

      # NodePort for non-K8s services
      {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "postgresql-cluster-nodeport";
          namespace = "default";
        };
        spec = {
          type = "NodePort";
          selector = {
            "cnpg.io/cluster" = "postgresql-cluster";
            "cnpg.io/instanceRole" = "primary";
          };
          ports = [
            {
              port = 5432;
              targetPort = 5432;
              nodePort = 30432;
            }
          ];
        };
      }
    ];
  };
}

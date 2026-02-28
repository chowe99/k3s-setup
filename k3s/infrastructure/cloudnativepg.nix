# k3s/infrastructure/cloudnativepg.nix — CloudNativePG cluster + NodePort
{
  k3sLib,
  cnpgStorageSize ? "50Gi",
  ...
}: {
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
        instances = 3;
        storage = {
          size = cnpgStorageSize;
          storageClass = "local-path";
        };
        resources = {
          requests = {
            memory = "512Mi";
            cpu = "500m";
          };
          limits = {
            memory = "2Gi";
            cpu = "2000m";
          };
        };
        priorityClassName = "";
        affinity = {
          enablePodAntiAffinity = true;
          topologyKey = "kubernetes.io/hostname";
        };
        postgresql.parameters = {
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
}

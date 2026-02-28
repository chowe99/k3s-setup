# k3s/services/gitea-runner.nix — Gitea Actions runner with Docker-in-Docker
# Enables CI/CD pipelines: build Docker images, push to Gitea registry, deploy to K3s
{
  k3sLib,
  fullDomain,
  ...
}: {
  k3s-cluster.manifests.gitea-runner = k3sLib.mkList [
    # --- apps namespace ---
    {
      apiVersion = "v1";
      kind = "Namespace";
      metadata = {
        name = "apps";
        labels = {
          "kubernetes.io/metadata.name" = "apps";
        };
      };
    }

    # --- NetworkPolicy: restrict app pods in apps namespace ---
    {
      apiVersion = "networking.k8s.io/v1";
      kind = "NetworkPolicy";
      metadata = {
        name = "apps-default-policy";
        namespace = "apps";
      };
      spec = {
        podSelector = {};
        policyTypes = ["Ingress" "Egress"];
        ingress = [
          {
            from = [
              {
                namespaceSelector.matchLabels = {
                  "kubernetes.io/metadata.name" = "default";
                };
              }
            ];
          }
        ];
        egress = [
          {
            to = [
              {
                namespaceSelector.matchLabels = {
                  "kubernetes.io/metadata.name" = "default";
                };
              }
            ];
          }
          {
            to = [
              {
                ipBlock = {
                  cidr = "0.0.0.0/0";
                  except = ["10.0.0.0/8"];
                };
              }
            ];
          }
        ];
      };
    }

    # --- ServiceAccount for runner (kubectl deploy access) ---
    {
      apiVersion = "v1";
      kind = "ServiceAccount";
      metadata = {
        name = "gitea-runner";
        namespace = "default";
      };
    }

    # --- Role: scoped to apps namespace only ---
    {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "Role";
      metadata = {
        name = "gitea-runner-deployer";
        namespace = "apps";
      };
      rules = [
        {
          apiGroups = ["" "apps" "networking.k8s.io"];
          resources = ["deployments" "services" "configmaps" "secrets" "ingresses" "pods" "pods/log"];
          verbs = ["get" "list" "watch" "create" "update" "patch" "delete"];
        }
      ];
    }

    # --- RoleBinding: bind runner SA to deployer role in apps namespace ---
    {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "RoleBinding";
      metadata = {
        name = "gitea-runner-deployer";
        namespace = "apps";
      };
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io";
        kind = "Role";
        name = "gitea-runner-deployer";
      };
      subjects = [
        {
          kind = "ServiceAccount";
          name = "gitea-runner";
          namespace = "default";
        }
      ];
    }

    # --- PVC for runner data + Docker layer cache ---
    (k3sLib.mkPvc {
      name = "gitea-runner-pvc";
      storage = "20Gi";
    })

    # --- Runner Deployment: act_runner + DinD sidecar ---
    {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = "gitea-runner";
        namespace = "default";
        labels.app = "gitea-runner";
      };
      spec = {
        replicas = 1;
        strategy.type = "Recreate";
        selector.matchLabels.app = "gitea-runner";
        template = {
          metadata.labels.app = "gitea-runner";
          spec = {
            serviceAccountName = "gitea-runner";
            containers = [
              # act_runner — connects to Gitea, executes workflows
              {
                name = "runner";
                image = "gitea/act_runner:latest";
                env = [
                  {
                    name = "GITEA_INSTANCE_URL";
                    value = "http://gitea.default.svc.cluster.local:3000";
                  }
                  {
                    name = "GITEA_RUNNER_REGISTRATION_TOKEN";
                    valueFrom.secretKeyRef = {
                      name = "gitea-runner-secrets";
                      key = "RUNNER_TOKEN";
                    };
                  }
                  {
                    name = "GITEA_RUNNER_NAME";
                    value = "k3s-runner";
                  }
                  {
                    name = "GITEA_RUNNER_LABELS";
                    value = "ubuntu-latest:docker://node:20-bookworm,ubuntu-22.04:docker://node:20-bookworm,self-hosted:host";
                  }
                  {
                    name = "DOCKER_HOST";
                    value = "tcp://localhost:2376";
                  }
                  {
                    name = "DOCKER_TLS_VERIFY";
                    value = "1";
                  }
                  {
                    name = "DOCKER_CERT_PATH";
                    value = "/certs/client";
                  }
                ];
                volumeMounts = [
                  {
                    name = "runner-data";
                    mountPath = "/data";
                  }
                  {
                    name = "docker-certs";
                    mountPath = "/certs";
                    readOnly = true;
                  }
                ];
                resources = {
                  requests = {
                    memory = "256Mi";
                    cpu = "100m";
                  };
                  limits = {
                    memory = "512Mi";
                    cpu = "500m";
                  };
                };
              }
              # Docker-in-Docker sidecar — provides Docker daemon for image builds
              {
                name = "dind";
                image = "docker:27-dind";
                securityContext = {
                  privileged = true;
                };
                env = [
                  {
                    name = "DOCKER_TLS_CERTDIR";
                    value = "/certs";
                  }
                ];
                volumeMounts = [
                  {
                    name = "docker-certs";
                    mountPath = "/certs";
                  }
                  {
                    name = "dind-storage";
                    mountPath = "/var/lib/docker";
                  }
                ];
                resources = {
                  requests = {
                    memory = "512Mi";
                    cpu = "250m";
                  };
                  limits = {
                    memory = "4Gi";
                    cpu = "2000m";
                  };
                };
              }
            ];
            volumes = [
              {
                name = "runner-data";
                persistentVolumeClaim.claimName = "gitea-runner-pvc";
              }
              {
                name = "docker-certs";
                emptyDir = {};
              }
              {
                name = "dind-storage";
                emptyDir = {};
              }
            ];
            affinity = {
              nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution = [
                {
                  weight = 100;
                  preference.matchExpressions = [
                    {
                      key = "kubernetes.io/hostname";
                      operator = "In";
                      values = ["blackserver"];
                    }
                  ];
                }
              ];
            };
          };
        };
      };
    }
  ];
}

# k3s/services/gitea.nix — Self-hosted Git service (shared module)
# Activated via k3s-cluster.services.gitea.enable, parameterized via options
{
  config,
  lib,
  k3sLib,
  fullDomain,
  ...
}: let
  cfg = config.k3s-cluster;
  giteaCfg = cfg.services.gitea;
  sshPort = toString giteaCfg.sshPort;
  sshDisabled =
    if giteaCfg.sshEnabled
    then "false"
    else "true";
in {
  config = lib.mkIf (cfg.enable && giteaCfg.enable) {
    # Secret "gitea-secrets" is injected by k3s/secrets.nix (gitea-k8s-secrets service)
    k3s-cluster.manifests.gitea = k3sLib.mkList [
      (k3sLib.mkPvc {
        name = "gitea-pvc";
        storage = giteaCfg.storageSize;
      })
      (k3sLib.mkDeployment {
        name = "gitea";
        image = "gitea/gitea:1.22";
        labels.app = "gitea";
        strategy = {type = "Recreate";};
        ports = [
          {
            containerPort = 3000;
            name = "http";
          }
          {
            containerPort = giteaCfg.sshPort;
            name = "ssh";
          }
        ];
        env = {
          GITEA__database__DB_TYPE = "postgres";
          GITEA__database__HOST = "postgresql-cluster-rw:5432";
          GITEA__database__NAME = "gitea";
          GITEA__database__USER = "gitea";
          GITEA__database__SSL_MODE = "disable";
          GITEA__server__DOMAIN = "git.${fullDomain}";
          GITEA__server__ROOT_URL = "https://git.${fullDomain}/";
          GITEA__server__HTTP_PORT = "3000";
          GITEA__server__SSH_PORT = sshPort;
          GITEA__server__SSH_DOMAIN = "git.${fullDomain}";
          GITEA__server__SSH_LISTEN_PORT = sshPort;
          GITEA__server__DISABLE_SSH = sshDisabled;
          GITEA__server__START_SSH_SERVER = "true";
          GITEA__security__INSTALL_LOCK = "true";
          GITEA__lfs__PATH = "/data/lfs";
          GITEA__lfs__STORAGE_TYPE = "local";
          GITEA__service__DISABLE_REGISTRATION = "false";
          GITEA__service__REQUIRE_SIGNIN_VIEW = "false";
          GITEA__service__ENABLE_NOTIFY_MAIL = "true";
          GITEA__admin__USER = "gitea_admin";
          GITEA__admin__EMAIL = "admin@${fullDomain}";
          GITEA__repository__ROOT = "/data/git/repositories";
          GITEA__log__MODE = "console";
          GITEA__log__LEVEL = "Info";
          # Enable Gitea Actions (CI/CD runners)
          GITEA__actions__ENABLED = "true";
          # Enable container registry (Gitea Packages)
          GITEA__packages__ENABLED = "true";
          GITEA__packages__LIMIT_SIZE_CONTAINER = "-1";
        };
        envVars = [
          {
            name = "GITEA__database__PASSWD";
            valueFrom.secretKeyRef = {
              name = "gitea-secrets";
              key = "DB_PASSWORD";
            };
          }
          {
            name = "GITEA__security__SECRET_KEY";
            valueFrom.secretKeyRef = {
              name = "gitea-secrets";
              key = "SECRET_KEY";
            };
          }
          {
            name = "GITEA__security__INTERNAL_TOKEN";
            valueFrom.secretKeyRef = {
              name = "gitea-secrets";
              key = "INTERNAL_TOKEN";
            };
          }
          {
            name = "GITEA__admin__PASSWORD";
            valueFrom.secretKeyRef = {
              name = "gitea-secrets";
              key = "ADMIN_PASSWORD";
            };
          }
        ];
        affinity = giteaCfg.affinity;
        initContainers = [
          {
            name = "wait-for-postgres";
            image = "busybox:1.36";
            command = [
              "sh"
              "-c"
              ''
                until nc -z postgresql-cluster-rw 5432; do
                  echo "Waiting for CloudNativePG..."
                  sleep 2
                done
                echo "PostgreSQL is ready!"
              ''
            ];
          }
        ];
        resources = {
          requests = {
            memory = "512Mi";
            cpu = "250m";
          };
          limits = {
            memory = "2Gi";
            cpu = "1000m";
          };
        };
        livenessProbe = {
          httpGet = {
            path = "/api/healthz";
            port = 3000;
          };
          initialDelaySeconds = giteaCfg.livenessInitialDelay;
          periodSeconds = 10;
          timeoutSeconds = 5;
          failureThreshold = giteaCfg.livenessFailureThreshold;
        };
        readinessProbe = {
          httpGet = {
            path = "/api/healthz";
            port = 3000;
          };
          initialDelaySeconds = 10;
          periodSeconds = 5;
          timeoutSeconds = 3;
          failureThreshold = 3;
        };
        volumes = [
          {
            name = "data";
            pvc = "gitea-pvc";
            mountPath = "/data";
          }
        ];
      })
      # Multi-port NodePort service (raw attrset)
      {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "gitea";
          namespace = "default";
          labels.app = "gitea";
        };
        spec = {
          type = "NodePort";
          selector.app = "gitea";
          ports =
            [
              {
                name = "http";
                port = 3000;
                targetPort = 3000;
                nodePort = 30090;
              }
            ]
            ++ lib.optionals giteaCfg.sshEnabled [
              {
                name = "ssh";
                port = giteaCfg.sshPort;
                targetPort = giteaCfg.sshPort;
                nodePort = 30091;
              }
            ];
        };
      }
      (k3sLib.mkIngress {
        name = "gitea";
        subdomain = "git";
        port = 3000;
      })
    ];
  };
}

# k3s/secrets.nix — K8s secret injection from agenix (Gitea + CNPG only)
{
  config,
  pkgs,
  lib,
  fullDomain,
  ...
}: let
  cfg = config.k3s-cluster;
  # Common wrapper for K8s secret injection services
  mkSecretService = {
    name,
    description,
    secretArgs,
    checkVar,
  }: {
    systemd.services."${name}" = {
      inherit description;
      after = ["k3s.service"];
      requires = ["k3s.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.writeShellScript name ''
          #!/bin/sh
          set -e

          # Wait for K3s to be ready
          sleep 10

          # Use k3s kubectl
          KUBECTL="/run/current-system/sw/bin/k3s kubectl"
          if ! $KUBECTL version &>/dev/null 2>&1; then
            echo "k3s kubectl not ready yet, skipping..."
            exit 0
          fi

          ${secretArgs}

          echo "${name} updated successfully"
        ''}";
      };
    };

    systemd.timers."${name}" = {
      description = "Timer to refresh ${name}";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "1h";
        Unit = "${name}.service";
      };
    };
  };
in {
  config = lib.mkIf cfg.enable (lib.mkMerge [
    # CloudNativePG superuser secret
    (mkSecretService {
      name = "cnpg-k8s-secrets";
      description = "Create CloudNativePG superuser K8s secret from agenix";
      checkVar = "CNPG_PASS";
      secretArgs = ''
        CNPG_PASS=$(cat ${config.age.secrets.postgres-cnpg-pass.path} 2>/dev/null || echo "")

        if [ -z "$CNPG_PASS" ]; then
          echo "Warning: postgres-cnpg-pass not found in agenix"
          exit 0
        fi

        $KUBECTL create secret generic postgresql-cluster-superuser \
          --from-literal=password="$CNPG_PASS" \
          --namespace=default \
          --dry-run=client -o yaml | $KUBECTL apply -f -
      '';
    })

    # Gitea secrets
    (mkSecretService {
      name = "gitea-k8s-secrets";
      description = "Create Gitea K8s secrets from agenix";
      checkVar = "DB_PASSWORD";
      secretArgs = ''
        DB_PASSWORD=$(cat ${config.age.secrets.postgres-gitea-pass.path} 2>/dev/null || echo "")
        SECRET_KEY=$(cat ${config.age.secrets.gitea-secret-key.path} 2>/dev/null || echo "")
        INTERNAL_TOKEN=$(cat ${config.age.secrets.gitea-internal-token.path} 2>/dev/null || echo "")
        JWT_SECRET=$(cat ${config.age.secrets.gitea-jwt-secret.path} 2>/dev/null || echo "")
        ADMIN_PASSWORD=$(cat ${config.age.secrets.gitea-admin-pass.path} 2>/dev/null || echo "")

        if [ -z "$DB_PASSWORD" ]; then
          echo "Warning: postgres-gitea-pass not found in agenix"
          exit 0
        fi

        $KUBECTL create secret generic gitea-secrets \
          --from-literal=DB_PASSWORD="$DB_PASSWORD" \
          --from-literal=SECRET_KEY="$SECRET_KEY" \
          --from-literal=INTERNAL_TOKEN="$INTERNAL_TOKEN" \
          --from-literal=JWT_SECRET="$JWT_SECRET" \
          --from-literal=ADMIN_PASSWORD="$ADMIN_PASSWORD" \
          --namespace=default \
          --dry-run=client -o yaml | $KUBECTL apply -f -
      '';
    })

    # Gitea Actions runner secrets (default namespace)
    (mkSecretService {
      name = "gitea-runner-k8s-secrets";
      description = "Create Gitea Actions Runner K8s secrets from agenix";
      checkVar = "RUNNER_TOKEN";
      secretArgs = ''
        RUNNER_TOKEN=$(cat ${config.age.secrets.gitea-runner-token.path} 2>/dev/null || echo "")
        REGISTRY_TOKEN=$(cat ${config.age.secrets.gitea-registry-token.path} 2>/dev/null || echo "")

        if [ -z "$RUNNER_TOKEN" ]; then
          echo "Warning: gitea-runner-token not found in agenix"
          exit 0
        fi

        $KUBECTL create secret generic gitea-runner-secrets \
          --from-literal=RUNNER_TOKEN="$RUNNER_TOKEN" \
          --from-literal=REGISTRY_TOKEN="$REGISTRY_TOKEN" \
          --namespace=default \
          --dry-run=client -o yaml | $KUBECTL apply -f -
      '';
    })

    # Gitea registry pull secret (apps namespace, for deployed pods to pull images)
    (mkSecretService {
      name = "gitea-registry-pull-k8s-secrets";
      description = "Create Gitea registry pull secret for apps namespace";
      checkVar = "REGISTRY_TOKEN";
      secretArgs = ''
        REGISTRY_TOKEN=$(cat ${config.age.secrets.gitea-registry-token.path} 2>/dev/null || echo "")

        if [ -z "$REGISTRY_TOKEN" ]; then
          echo "Warning: gitea-registry-token not found in agenix"
          exit 0
        fi

        # Ensure apps namespace exists
        $KUBECTL create namespace apps --dry-run=client -o yaml | $KUBECTL apply -f -

        $KUBECTL create secret docker-registry gitea-registry-pull \
          --docker-server=git.${fullDomain} \
          --docker-username=gitea_admin \
          --docker-password="$REGISTRY_TOKEN" \
          --namespace=apps \
          --dry-run=client -o yaml | $KUBECTL apply -f -
      '';
    })
  ]);
}

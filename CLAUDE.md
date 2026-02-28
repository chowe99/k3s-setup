# CLAUDE.md

## Repository Overview

Standalone NixOS flake for deploying web application VPS nodes with K3s, Gitea (CI/CD + container registry), and CloudNativePG. A custom "Vercel-like" deployment platform built on declarative Nix infrastructure. Designed to be independent of the homelab nix-config.

## Architecture

Each VPS node runs:
- **K3s** — single-node or multi-node Kubernetes cluster
- **Gitea** — Git hosting with Actions CI/CD and container registry
- **Gitea Runner** — Docker-in-Docker CI runner for building/deploying apps
- **CloudNativePG** — HA PostgreSQL 17 cluster
- **Tailscale** — mesh VPN for management access
- **Docker** — container runtime

### Deployment Flow

```
Developer pushes code → Gitea repo (webhook triggers)
  → Gitea Actions runner (builds Docker image)
    → Pushes to Gitea container registry
      → Deploys to K3s (apps namespace)
        → CloudNativePG provides database
```

## Flake Structure

- `mkVps` — generates a VPS NixOS config from IP/gateway params (headless, minimal)
- `mkServer` — generates a full server config with desktop tooling (Hyprland, nixvim, etc.)
- `servers` attrset — populated as you add VPS nodes; first alphabetically becomes K3s initial server

## Directory Layout

- **templates/** — Base NixOS and home-manager templates
  - `vps-configuration.nix` — Parameterized VPS module (networking, firewall, Docker, Tailscale)
  - `minimal-home.nix` — Lightweight home for VPS (zsh, oh-my-posh, zoxide)
  - `server-home.nix` — Full tooling home (nixvim, kitty, etc.)
- **configs/** — Reusable home-manager modules
- **k3s/** — Declarative K8s manifests (Nix → JSON → K3s auto-deploy)
  - `cluster.nix` — Dynamic node topology derived from `servers` attrset
  - `secrets.nix` — Agenix → K8s secret bridge (Gitea + CNPG only)
  - `services/` — Gitea + Gitea Runner
  - `infrastructure/` — CloudNativePG
- **hosts/** — Per-VPS hardware configs (created when provisioning)
- **secrets/** — Agenix encrypted secrets (`.age` files)
- **scripts/** — Helper scripts

## Common Commands

```bash
# Build and switch (on VPS)
sudo nixos-rebuild switch --flake ~/vercel-nix-config#<hostname>

# Build without activating (test for errors)
nixos-rebuild build --flake ~/vercel-nix-config#<hostname>

# Edit a secret
agenix -e secrets/<secret-name>.age

# K3s status
sudo k3s kubectl get nodes
sudo k3s kubectl get pods -A

# CloudNativePG status
sudo k3s kubectl get cluster.postgresql.cnpg.io

# Access Gitea database
sudo k3s kubectl exec -it postgresql-cluster-1 -c postgres -- psql -U postgres

# Check Gitea runner
sudo k3s kubectl logs deployment/gitea-runner -c runner

# Deploy an app manually
sudo k3s kubectl apply -f my-app.yaml -n apps
```

## Adding a New VPS Node

1. Provision VPS, note its public IP and gateway
2. Copy `/etc/nixos/hardware-configuration.nix` to `hosts/<hostname>/hardware-configuration.nix`
3. Add the system SSH host key to `secrets/secrets.nix` (`targetSystems` list)
4. Rekey all secrets: `agenix -r`
5. Create secrets: `agenix -e secrets/<name>.age` for each entry
6. Add the server to `servers` attrset and `nixosConfigurations` in `flake.nix`:
   ```nix
   servers = {
     webvps1 = { publicIp = "203.0.113.10"; };
   };
   nixosConfigurations = {
     webvps1 = mkVps {
       hostname = "webvps1";
       publicIp = "203.0.113.10";
       gateway = "203.0.113.1";
     };
   };
   ```
7. Deploy: `sudo nixos-rebuild switch --flake ~/vercel-nix-config#webvps1`

## Deploying a Web App (End-to-End)

### 1. Create the repo in Gitea

Push your app (with a Dockerfile) to `https://git.<domain>/<user>/<app>.git`.

### 2. Add a Gitea Actions workflow

Create `.gitea/workflows/deploy.yml` in the repo:

```yaml
name: Build and Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Login to Gitea Registry
        run: |
          echo "${{ secrets.REGISTRY_TOKEN }}" | docker login git.<domain> -u gitea_admin --password-stdin

      - name: Build and Push
        run: |
          docker build -t git.<domain>/<user>/<app>:${{ github.sha }} .
          docker build -t git.<domain>/<user>/<app>:latest .
          docker push git.<domain>/<user>/<app>:${{ github.sha }}
          docker push git.<domain>/<user>/<app>:latest

      - name: Deploy to K3s
        run: |
          cat <<EOF | kubectl apply -f -
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: <app>
            namespace: apps
          spec:
            replicas: 1
            selector:
              matchLabels:
                app: <app>
            template:
              metadata:
                labels:
                  app: <app>
              spec:
                imagePullSecrets:
                  - name: gitea-registry-pull
                containers:
                  - name: <app>
                    image: git.<domain>/<user>/<app>:${{ github.sha }}
                    ports:
                      - containerPort: 3000
          ---
          apiVersion: v1
          kind: Service
          metadata:
            name: <app>
            namespace: apps
          spec:
            type: ClusterIP
            selector:
              app: <app>
            ports:
              - port: 3000
                targetPort: 3000
          EOF
```

### 3. Create the database (if needed)

```bash
sudo k3s kubectl exec -it postgresql-cluster-1 -c postgres -- psql -U postgres
CREATE ROLE myapp WITH LOGIN PASSWORD 'secret';
CREATE DATABASE myapp_db OWNER myapp;
```

App connects to `postgresql-cluster-rw:5432` from within the cluster.

### 4. Expose externally

Add a K8s Ingress or configure your reverse proxy (Cloudflare Tunnel, Caddy, etc.) to route traffic to the app's ClusterIP service.

## Adding a New PostgreSQL Database

Use the existing CloudNativePG cluster:
```bash
sudo k3s kubectl exec -it postgresql-cluster-1 -c postgres -- psql -U postgres
CREATE ROLE myapp WITH LOGIN PASSWORD 'secret';
CREATE DATABASE myapp_db OWNER myapp;
```

Then point your service to `postgresql-cluster-rw:5432` (in-cluster).

## Dokploy vs This Stack

Dokploy is a self-hosted PaaS (Heroku/Vercel alternative) with a web UI. It uses Docker Swarm, NOT Kubernetes. It is a **parallel system**, not something that integrates into this K3s stack.

| Feature | This Stack (K3s + Gitea) | Dokploy |
|---------|--------------------------|---------|
| **Orchestration** | Kubernetes (K3s) | Docker Swarm |
| **Config approach** | Declarative (Nix) | UI-driven (imperative) |
| **Git server** | Built-in (Gitea) | External only (GitHub/GitLab/Gitea) |
| **Container registry** | Built-in (Gitea Packages) | External only |
| **CI/CD** | Gitea Actions + DinD runner | Nixpacks/Buildpacks (auto-build) |
| **Database HA** | CloudNativePG (3-instance failover) | Single container (no HA) |
| **Web dashboard** | No (kubectl + optional Homepage) | Yes (full web UI) |
| **Preview deploys** | No (manual) | Yes (reported buggy) |
| **Templates** | Manual K8s manifests | 382+ one-click templates |
| **Multi-node** | K3s cluster (etcd HA) | Docker Swarm |
| **Storage** | K3s local-path (or add Longhorn) | Docker volumes (local) |
| **TLS/SSL** | BYO (Cloudflare/Caddy/Pangolin) | Built-in Traefik + Let's Encrypt |
| **Reproducibility** | Full (Nix flake, git-tracked) | None (state in database) |
| **License** | All FOSS (Apache/MIT) | Custom (source-available concerns) |

**When to use Dokploy instead**: You want a web UI for quick deploys, don't need database HA, and prefer clicking over writing YAML/Nix. Run it on a separate node to avoid Docker Swarm / K3s conflicts.

**When to use this stack**: You want reproducible infrastructure, HA databases, self-hosted git + registry, and declarative config that's version-controlled. More work upfront, more reliable long-term.

## Key Design Patterns

1. **Template inheritance** — VPS configs import `vps-configuration.nix`, servers import host-specific config
2. **Dynamic K3s topology** — `cluster.nix` derives nodes from `servers` attrset (no hardcoded IPs)
3. **Agenix dual-layer** — System secrets (`/run/agenix/`) + user secrets (`~/.agenix-cache/`)
4. **Manifest-as-Nix** — K8s resources defined as Nix attrsets, serialized to JSON
5. **Apps namespace isolation** — Deployed apps live in `apps` namespace with NetworkPolicy restricting access

## Important Notes

- Uses **nixpkgs-unstable** channel
- Timezone: `Australia/Perth`, Locale: `en_AU.UTF-8`
- Formatter: `alejandra` (Nix code)
- Caddy/Pangolin are NOT included — VPS nodes handle their own TLS or use Cloudflare
- No GlusterFS, Keepalived, or homelab networking
- Docker bridge traffic needs `trustedInterfaces = ["docker0" "br-+"]` (already set in vps-configuration.nix)
- Gitea SSH runs on port 2222 (NodePort 30091)
- Gitea HTTP runs on port 3000 (NodePort 30090)

# secrets/secrets.nix — Agenix key definitions
# Add VPS system SSH public keys here as you provision new nodes.
# Run: ssh-keyscan -t ed25519 <vps-ip> | grep ed25519
let
  # User SSH keys
  user_darkslayer_pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIArFnd2GORgeTd2HTOqy6aZfsHCluAs7nVmt19NV9e8b darkslayer@blackarch";

  # System SSH host keys — add new VPS keys here
  # system_webvps1_pubkey = "ssh-ed25519 AAAA... root@webvps1";

  users = [user_darkslayer_pubkey];
  targetSystems = [
    # Add VPS system keys as they are provisioned
  ];
  defaultRecipientKeys = users ++ targetSystems;
in {
  # API keys (user-level, home-manager)
  "GH_TOKEN.age".publicKeys = defaultRecipientKeys;

  # K3s cluster
  "k3s-token.age".publicKeys = defaultRecipientKeys;
  "k3s-postgres-pass.age".publicKeys = defaultRecipientKeys;

  # CloudNativePG
  "postgres-cnpg-pass.age".publicKeys = defaultRecipientKeys;

  # Gitea
  "postgres-gitea-pass.age".publicKeys = defaultRecipientKeys;
  "gitea-secret-key.age".publicKeys = defaultRecipientKeys;
  "gitea-internal-token.age".publicKeys = defaultRecipientKeys;
  "gitea-jwt-secret.age".publicKeys = defaultRecipientKeys;
  "gitea-admin-pass.age".publicKeys = defaultRecipientKeys;

  # Gitea Actions runner + registry
  "gitea-runner-token.age".publicKeys = defaultRecipientKeys;
  "gitea-registry-token.age".publicKeys = defaultRecipientKeys;
}

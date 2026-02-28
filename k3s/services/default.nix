# k3s/services/default.nix — Import K8s service definitions
{...}: {
  imports = [
    ./gitea.nix
    ./gitea-runner.nix
  ];
}

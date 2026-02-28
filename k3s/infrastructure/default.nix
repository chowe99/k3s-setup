# k3s/infrastructure/default.nix — Import infrastructure resources
{...}: {
  imports = [
    ./cloudnativepg.nix
  ];
}

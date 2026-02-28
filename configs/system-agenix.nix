{
  config,
  pkgs,
  lib,
  username,
  ...
}: {
  age.secrets = {
    k3s-token = {
      file = ../secrets/k3s-token.age;
      path = "/run/agenix/k3s-token";
      owner = "root";
      group = "root";
      mode = "0400";
    };
    GH_TOKEN = {
      file = ../secrets/GH_TOKEN.age;
      path = "/run/agenix/GH_TOKEN";
      owner = username;
      group = "users";
      mode = "0440";
    };
    k3s-postgres-pass = {
      file = ../secrets/k3s-postgres-pass.age;
      path = "/run/agenix/k3s-postgres-pass";
      owner = "root";
      group = "root";
      mode = "0400";
    };
    postgres-gitea-pass = {
      file = ../secrets/postgres-gitea-pass.age;
      path = "/run/agenix/postgres-gitea-pass";
      owner = "root";
      group = "root";
      mode = "0400";
    };
    postgres-cnpg-pass = {
      file = ../secrets/postgres-cnpg-pass.age;
      path = "/run/agenix/postgres-cnpg-pass";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    # Gitea secrets
    gitea-secret-key = {
      file = ../secrets/gitea-secret-key.age;
      path = "/run/agenix/gitea-secret-key";
      owner = "root";
      group = "root";
      mode = "0400";
    };
    gitea-internal-token = {
      file = ../secrets/gitea-internal-token.age;
      path = "/run/agenix/gitea-internal-token";
      owner = "root";
      group = "root";
      mode = "0400";
    };
    gitea-jwt-secret = {
      file = ../secrets/gitea-jwt-secret.age;
      path = "/run/agenix/gitea-jwt-secret";
      owner = "root";
      group = "root";
      mode = "0400";
    };
    gitea-admin-pass = {
      file = ../secrets/gitea-admin-pass.age;
      path = "/run/agenix/gitea-admin-pass";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    # Gitea Actions runner + registry
    gitea-runner-token = {
      file = ../secrets/gitea-runner-token.age;
      path = "/run/agenix/gitea-runner-token";
      owner = "root";
      group = "root";
      mode = "0400";
    };
    gitea-registry-token = {
      file = ../secrets/gitea-registry-token.age;
      path = "/run/agenix/gitea-registry-token";
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };
}

{
  config,
  pkgs,
  lib,
  inputs,
  username,
  ...
}: {
  age.secrets = {
    gemini-api-key = {
      file = "${inputs.self}/secrets/gemini-api-key.age";
      path = "${config.home.homeDirectory}/.agenix-cache/gemini-api-key";
    };
    openai-api-key = {
      file = "${inputs.self}/secrets/openai-api-key.age";
      path = "${config.home.homeDirectory}/.agenix-cache/openai-api-key";
    };
    anthropic-api-key = {
      file = "${inputs.self}/secrets/anthropic-api-key.age";
      path = "${config.home.homeDirectory}/.agenix-cache/anthropic-api-key";
    };
    GH_TOKEN = {
      file = "${inputs.self}/secrets/GH_TOKEN.age";
      path = "${config.home.homeDirectory}/.agenix-cache/GH_TOKEN";
    };
    k3s-token = {
      file = "${inputs.self}/secrets/k3s-token.age";
      path = "${config.home.homeDirectory}/.agenix-cache/k3s-token";
    };
  };
}

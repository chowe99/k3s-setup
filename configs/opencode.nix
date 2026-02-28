{
  inputs,
  config,
  pkgs,
  lib,
  baseDomain,
  tld,
  ...
}: let
  fullDomain = "${baseDomain}.${tld}";
in {
  programs.opencode = {
    enable = true;
    settings = {
      "$schema" = "https://opencode.ai/config.json";

      permission = {
        edit = "ask";
        bash = "ask";
      };

      provider = {
        ollama = {
          npm = "@ai-sdk/openai-compatible";
          name = "Ollama (local)";
          options = {
            baseURL = "http://localhost:11434/v1";
          };
          models = {
            "devstral:latest" = {
              name = "Devstral";
            };
          };
        };
      };

      mcp = {};
      agent = {};
    };
  };
}

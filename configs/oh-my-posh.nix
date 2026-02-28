{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  programs.oh-my-posh = {
    enable = true;
    enableZshIntegration = true;
    useTheme = "1_shell";
  };
}

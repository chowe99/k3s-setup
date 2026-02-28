{
  config,
  lib,
  pkgs,
  username,
  hostname,
  baseDomain,
  tld,
  ...
}: let
  fullDomain = "${baseDomain}.${tld}";
in {
  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "";
      plugins = [
        "git"
        "common-aliases"
        "colored-man-pages"
        "vi-mode"
      ];
    };
    plugins = [
      {
        name = "fzf-tab";
        src = "${pkgs.zsh-fzf-tab}/share/fzf-tab";
      }
      {
        name = "zsh-autosuggestions";
        src = config.packageSet.zsh-autosuggestions;
        file = "share/zsh-autosuggestions/zsh-autosuggestions.zsh";
      }
      {
        name = "fast-syntax-highlighting";
        src = config.packageSet.zsh-fast-syntax-highlighting;
        file = "share/zsh/site-functions/fast-syntax-highlighting.plugin.zsh";
      }
      {
        name = "zsh-syntax-highlighting";
        src = config.packageSet.zsh-syntax-highlighting;
        file = "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
      }
    ];
    initContent = ''
      # Load fzf completion and key bindings
      if command -v fzf &> /dev/null; then
        if [[ -f /usr/share/fzf/completion.zsh ]]; then
          source /usr/share/fzf/completion.zsh
        fi
        if [[ -f /usr/share/fzf/key-bindings.zsh ]]; then
          source /usr/share/fzf/key-bindings.zsh
        fi
      fi

      # fzf-tab integration for cd, ls, and cat
      zstyle ':fzf-tab:complete:(cd|lsd|cat|nvim|rm):*' fzf-preview '[[ -d $realpath ]] && ls --color $realpath || ([[ -f $realpath ]] && cat $realpath || echo "Not a file or directory")'
      zstyle ':fzf-tab:complete:(cd|lsd|cat|nvim|rm):*' fzf-completion-opts --preview-window=down:3:wrap
      zstyle ':fzf-tab:complete:(cd|lsd):*' query-string zoxide query -l

      # Enable fzf for systemctl and other commands
      zstyle ':completion:*' menu select
      zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}

      bindkey "^[[1;3D" backward-word
      bindkey "^[[1;3C" forward-word
      bindkey -v
      export KEYTIMEOUT=1
      export PATH="$HOME/bin:$HOME/Applications:$PATH"
      export EDITOR=vim
      alias vim=nvim
      alias age=agenix
      alias rebuild="zsh ~/vercel-nix-config/scripts/rebuild.sh"
      alias switch="home-manager switch --flake ~/vercel-nix-config#${username}"
      alias c="clear && fastfetch"
      unalias open 2>/dev/null
      if grep -q "ID=nixos" /etc/os-release 2>/dev/null; then
        alias open="superfile"
      fi
      alias ls='lsd'
      alias l='ls -l'
      alias la='ls -a'
      alias lla='ls -la'
      alias lt='ls --tree'
      alias g='git'
      alias gs='git status'
      alias ga='git add'
      alias gc='git commit -m'
      alias gp='git push'

      alias man='tldr'
      alias kubectl='sudo k3s kubectl'
      ZSH_HIGHLIGHT_STYLES[path]=fg=#8A2BE2

      # Export secrets from home-manager agenix cache
      SECRETS_DIR="$HOME/.agenix-cache"
      if [[ -n "$SECRETS_DIR" && -f "$SECRETS_DIR/openai-api-key" ]]; then
        export OPENAI_API_KEY=$(cat "$SECRETS_DIR/openai-api-key")
      fi
      if [[ -n "$SECRETS_DIR" && -f "$SECRETS_DIR/gemini-api-key" ]]; then
        export GEMINI_API_KEY=$(cat "$SECRETS_DIR/gemini-api-key")
      fi
      if [[ -n "$SECRETS_DIR" && -f "$SECRETS_DIR/anthropic-api-key" ]]; then
        export ANTHROPIC_API_KEY=$(cat "$SECRETS_DIR/anthropic-api-key")
      fi
      if [[ -n "$SECRETS_DIR" && -f "$SECRETS_DIR/k3s-token" ]]; then
        export K3S_TOKEN=$(cat "$SECRETS_DIR/k3s-token")
      fi
      if [[ -n "$SECRETS_DIR" && -f "$SECRETS_DIR/GH_TOKEN" ]]; then
        export GH_TOKEN=$(cat "$SECRETS_DIR/GH_TOKEN")
      fi
      fastfetch
    '';
  };
}

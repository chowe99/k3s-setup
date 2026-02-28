{config, lib, pkgs, hostname, ...}: let
  isServer = !(lib.hasPrefix "lemur" hostname || lib.hasPrefix "darkslayer" hostname || hostname == "blackarch" || hostname == "cod");
  omarchyLogoSource = "~/.config/omarchy/branding/about.txt";
in {
  programs.fastfetch = {
    enable = true;
    package = pkgs.fastfetch;
    settings = {
      logo = if isServer then {
        type = "auto";
      } else {
        type = "file";
        source = omarchyLogoSource;
        color = {
          "1" = "green";
        };
        padding = {
          top = 2;
          right = 6;
          left = 2;
        };
      };
      display = {
        separator = ": ";
      };
      modules = [
        "break"
        {
          type = "custom";
          format = "┌──────────────────────Hardware──────────────────────┐";
        }
        {
          type = "host";
          key = " PC";
          keyColor = "green";
        }
        {
          type = "cpu";
          key = "│ ├";
          showPeCoreCount = true;
          keyColor = "green";
        }
        {
          type = "gpu";
          key = "│ ├";
          detectionMethod = "pci";
          keyColor = "green";
        }
        {
          type = "display";
          key = "│ ├󇴄";
          keyColor = "green";
        }
        {
          type = "disk";
          key = "│ ├󰋊";
          keyColor = "green";
        }
        {
          type = "memory";
          key = "│ ├";
          keyColor = "green";
        }
        {
          type = "swap";
          key = "└ └󰓡 ";
          keyColor = "green";
        }
        {
          type = "custom";
          format = "└────────────────────────────────────────────────────┘";
        }
        "break"
        {
          type = "custom";
          format = "┌──────────────────────Software──────────────────────┐";
        }
        (if isServer then {
          type = "os";
          key = "OS";
          keyColor = "blue";
        } else {
          type = "command";
          key = "OS";
          keyColor = "blue";
          text = "version=$(omarchy-version 2>/dev/null || echo unknown); echo Omarchy $version";
        })
        (if isServer then {
          type = "command";
          key = "│ ├󰘬";
          keyColor = "blue";
          text = "nix --version | awk '{print \$2}'";
        } else {
          type = "command";
          key = "│ ├󰘬";
          keyColor = "blue";
          text = "branch=$(omarchy-version-branch 2>/dev/null || echo n/a); echo $branch";
        })
        (if isServer then {
          type = "command";
          key = "│ ├󰔫";
          keyColor = "blue";
          text = "echo nix";
        } else {
          type = "command";
          key = "│ ├󰔫";
          keyColor = "blue";
          text = "channel=$(omarchy-version-channel 2>/dev/null || echo n/a); echo $channel";
        })
        {
          type = "kernel";
          key = "│ ├";
          keyColor = "blue";
        }
        {
          type = "wm";
          key = "│ ├";
          keyColor = "blue";
        }
        {
          type = "de";
          key = "│ ├ DE";
          keyColor = "blue";
        }
        {
          type = "terminal";
          key = "│ ├";
          keyColor = "blue";
        }
        {
          type = "packages";
          key = "│ ├󰏖";
          keyColor = "blue";
        }
        (if isServer then {
          type = "custom";
          key = "│ ├󰉼";
          keyColor = "blue";
          format = "";
        } else {
          type = "command";
          key = "│ ├󰸌";
          keyColor = "blue";
          text = "theme=$(omarchy-theme-current 2>/dev/null || echo n/a); echo $theme";
        })
        {
          type = "terminalfont";
          key = "└ └";
          keyColor = "blue";
        }
        {
          type = "custom";
          format = "└────────────────────────────────────────────────────┘";
        }
        "break"
        {
          type = "custom";
          format = "┌────────────────Age / Uptime / Update───────────────┐";
        }
        {
          type = "command";
          key = "󱦟 OS Age";
          keyColor = "magenta";
          text = ''echo $(( ($(date +%s) - $(stat -c %W /)) / 86400 )) days'';
        }
        {
          type = "uptime";
          key = "󱫐 Uptime";
          keyColor = "magenta";
        }
        {
          type = "command";
          key = " Update";
          keyColor = "magenta";
          text = ''echo "$(date '+%A, %B %d %Y at %H:%M')"'';
        }
        {
          type = "custom";
          format = "└────────────────────────────────────────────────────┘";
        }
        "break"
      ];
    };
  };
}

{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  programs.nixvim = {
    enable = true;
    colorschemes.kanagawa = {
      enable = true;
      settings = {
        background.dark = "wave";
      };
    };
    extraPackages = with pkgs;
      [
        nil
        lua-language-server
        typescript-language-server
        pyright
        tailwindcss-language-server
        yaml-language-server
        bash-language-server
        emmet-ls
        eslint
        eslint_d
        pylint
        stylelint
        shellcheck
        prettierd
        black
        shfmt
        ripgrep
        fd
        nodePackages.graphql-language-service-cli
        nodejs
        nodePackages.typescript-language-server # If using TS/JS LSP via mason
        nodePackages."@tailwindcss/language-server" # For Tailwind CSS IntelliSense
      ]
      ++ lib.optionals (lib.hasSuffix "linux" pkgs.stdenv.hostPlatform.system) [libnotify]; # Exclude on macOS
    clipboard = {
      register = "unnamedplus";
      providers = lib.mkIf pkgs.stdenv.isLinux {wl-copy.enable = true;}; # Only for Linux
    };
    globals = {
      mapleader = " ";
      python3_host_prog = "~/.pyenv/shims/python";
    };
    opts = {
      undofile = true;
      undodir = "${config.home.homeDirectory}/.local/share/nvim/undo";
      encoding = "utf-8";
      fileencoding = "utf-8";
      number = true;
      relativenumber = true;
      title = true;
      autoindent = true;
      smartindent = true;
      hlsearch = true;
      backup = false;
      showcmd = true;
      cmdheight = 0;
      laststatus = 0;
      expandtab = true;
      scrolloff = 10;
      inccommand = "split";
      ignorecase = true;
      smarttab = true;
      breakindent = true;
      shiftwidth = 2;
      tabstop = 2;
      wrap = false;
      backspace = ["start" "eol" "indent"];
      path = ["**"];
      wildignore = ["*/node_modules/*"];
      splitbelow = true;
      splitright = true;
      splitkeep = "cursor";
      mouse = "a";
      formatoptions = "r";
      foldmethod = "expr";
      foldexpr = "nvim_treesitter#foldexpr()";
      foldenable = false;
      foldlevel = 0;
      shell = "${pkgs.zsh}/bin/zsh";
    };
    plugins = {
      copilot-lua = {
        enable = true;
        settings.suggestion = {
          auto_trigger = true;
          keymap = {
            accept = "<Right>";
            next = "<Left>";
          };
        };
      };
      render-markdown.enable = true;
      visual-multi.enable = true;
      spectre.enable = true;
      harpoon = {
        enable = false;
        #   enableTelescope = true;
        #   settings = {
        #     save_on_change = true; # Auto-save marks on changes (default: true)
        #     sync_on_ui_close = true; # Sync marks when closing UI (default: true)
        #     # Add other settings from Harpoon 2 docs if desired
        #   };
      };
      comment = {
        enable = true;
        settings = {
          toggler = {
            line = "<leader>/";
            block = "<leader>cb";
          };
          opleader = {
            line = "<leader>c";
            block = "<leader>b";
          };
        };
      };
      lsp = {
        enable = true;
        servers = {
          lua_ls = {
            enable = true;
            settings = {
              Lua = {
                runtime = {version = "LuaJIT";};
                diagnostics = {globals = ["vim" "nvim"];};
                workspace = {
                  library = {__raw = "vim.api.nvim_get_runtime_file('', true)";};
                  maxPreload = 1000;
                  preloadFileSize = 1000;
                };
                telemetry = {enable = false;};
              };
            };
          };
          ts_ls = {
            enable = true;
            filetypes = ["javascript" "javascriptreact" "typescript" "typescriptreact"];
            extraOptions = {
              onAttach = ''
                function(client, bufnr)
                  client.server_capabilities.documentFormattingProvider = false
                end
              '';
            };
          };
          pyright.enable = true;
          tailwindcss.enable = true;
          html.enable = true;
          cssls.enable = true;
          jsonls.enable = true;
          yamlls.enable = true;
          dockerls.enable = true;
          graphql = {
            enable = true;
            package = null;
          };
          bashls.enable = true;
          emmet_ls = {
            enable = true;
            filetypes = ["html" "css" "javascript" "javascriptreact" "typescriptreact"];
          };
          eslint.enable = true;
        };
      };
      none-ls = {
        enable = true;
        settings = {
          debounce = 250;
          diagnostics_format = "[#{c}] #{m} (#{s})";
          on_attach = ''
            function(client, bufnr)
              vim.api.nvim_buf_set_option(bufnr, "formatexpr", "v:lua.vim.lsp.formatexpr()")
            end
          '';
        };
      };
      notify = {
        enable = true;
        settings = {
          background_colour = "#000000";
          top_down = false;
        };
      };
      web-devicons.enable = true;
      treesitter = {
        enable = true;
        settings = {
          highlight = {enable = true;};
          ensure_installed = [
            "javascript"
            "typescript"
            "tsx"
            "python"
            "html"
            "css"
            "json"
            "yaml"
            "gitignore"
            "graphql"
            "http"
            "scss"
            "sql"
            "vim"
            "lua"
          ];
        };
      };
      ts-autotag = {
        enable = true;
        # Optional: Customize
        settings = {
          opts = {
            enable_close = true;
            enable_rename = true;
            enable_close_on_slash = false; # Auto-close on </
          };
          per_filetype = {
            # e.g., Disable for specific langs if needed
            jsx = {enable_close = true;};
          };
        };
      };
      telescope = {
        enable = true;
        extensions = {
          file-browser.enable = true;
          fzy-native.enable = true;
          ui-select.enable = true;
          frecency = {
            enable = true;
            settings = {db_safe_mode = false;};
          };
        };
      };
      dap = {
        enable = true;
      };
      bufferline.enable = true;
      toggleterm = {
        enable = true;
        settings = {
          size = 20;
          open_mapping = "[[<c-\\>]]";
          shade_factor = 2;
          direction = "float";
          float_opts = {border = "curved";};
        };
      };
      noice = {
        enable = true;
        settings.routes = [
          {
            filter = {
              event = "msg_show";
              kind = "search_count";
            };
            opts = {skip = true;};
          }
        ];
      };
      transparent.enable = true;
      lualine.enable = true;
      cmp = {
        enable = true;
        settings = {
          sources = [
            {name = "nvim_lsp";}
            {name = "buffer";}
            {name = "path";}
            {name = "luasnip";}
          ];
          mapping = {
            __raw = ''
              {
                ["<Up>"] = cmp.mapping.select_prev_item(),
                ["<Down>"] = cmp.mapping.select_next_item(),
                ["<CR>"] = cmp.mapping.confirm({ select = true }),
                ["<Tab>"] = cmp.mapping.select_next_item(),
                ["<S-Tab>"] = cmp.mapping.select_prev_item(),
              }
            '';
          };
        };
      };
      luasnip = {
        enable = true;
        settings = {
          snippetEngineSetup = {friendly-snippets = {enable = true;};}; # Loads web/JS snippets
        };
      };
      indent-blankline.enable = true;
      gitsigns.enable = true;
      alpha = {
        enable = true;
        theme = "dashboard";
      };
      nvim-autopairs.enable = true;
      nvim-surround.enable = true;
      neo-tree = {
        enable = true;
        settings = {
          enable_diagnostics = true;
          enable_git_status = true;
          enable_modified_markers = true;
          enable_refresh_on_write = true;
          close_if_last_window = true;
          popup_border_style = "rounded";
          buffers = {
            bind_to_cwd = false;
            follow_current_file = {
              enabled = true;
            };
          };
          window = {
            position = "right";
            width = 25;
            auto_expand_width = false;
            mappings = {"<space>" = "none";};
          };
        };
      };

      avante = {
        enable = true;
        settings = {
          provider = "gemini";
          behaviour = {use_absolute_path = true;};
          providers = {
            openai = {
              endpoint = "https://api.openai.com/v1";
              model = "gpt-5";
              extra_request_body = {
                temperature = 1;
                max_completion_tokens = 8000;
              };
            };
            gemini = {
              model = "gemini-2.5-flash";
              extra_request_body = {
                temperature = 0;
                max_tokens = 8000;
                timeout = 30000;
              };
            };
            ollama = {
              endpoint = "http://localhost:11434";
              model = "devstral:latest";
            };
            claude = {
              endpoint = "https://api.anthropic.com";
              model = "claude-3-5-sonnet-20241022";
              extra_request_body = {
                temperature = 0;
                max_tokens = 8000;
                timeout = 30000;
              };
            };
          };
          debug = true;
        };
      };
      which-key = {
        enable = true;
      };
      lz-n.enable = true;
    };
    extraPlugins = with pkgs.vimPlugins; [
      mini-icons
      nui-nvim
      plenary-nvim
      nvim-dap
      undotree
      nvim-spectre
      vim-visual-multi
      nvim-ts-autotag
      hologram-nvim
      copilot-lua
      mason-nvim
      mason-lspconfig-nvim
      nvim-navic
      nvim-ts-context-commentstring
      bigfile-nvim
      friendly-snippets
      tokyonight-nvim
      dressing-nvim
      none-ls-nvim
      telescope-nvim
      harpoon2
      # (pkgs.vimUtils.buildVimPlugin {
      #   name = "harpoon2";
      #   src = pkgs.fetchFromGitHub {
      #     owner = "ThePrimeagen";
      #     repo = "harpoon";
      #     rev = "ed1f853847ffd04b2b61c314865665e1dadf22c7"; # e.g., "a1b2c3d4e5f6..."
      #     sha256 = "sha256-L7FvOV6KvD58BnY3no5IudiKTdgkGqhpS85RoSxtl7U="; # e.g., "abc123..."
      #   };
      #   dontCheck = true; # Skip the failing require check
      # })
      (pkgs.vimUtils.buildVimPlugin {
        name = "vscode-es7-javascript-react-snippets";
        src = pkgs.fetchFromGitHub {
          owner = "dsznajder";
          repo = "vscode-es7-javascript-react-snippets";
          rev = "master";
          sha256 = "sha256-VLRkj1rd53W3b9Ep2FAd+vs7B8CzKH2O3EE1Lw6vnTs=";
        };
      })
      (pkgs.vimUtils.buildVimPlugin {
        name = "tailwindcss-colorizer-cmp-nvim";
        src = pkgs.fetchFromGitHub {
          owner = "roobert";
          repo = "tailwindcss-colorizer-cmp.nvim";
          rev = "main";
          sha256 = "sha256-PIkfJzLt001TojAnE/rdRhgVEwSvCvUJm/vNPLSWjpY=";
        };
      })
      (pkgs.vimUtils.buildVimPlugin {
        name = "neominimap.nvim";
        src = pkgs.fetchFromGitHub {
          owner = "Isrothy";
          repo = "neominimap.nvim";
          rev = "v3.15.4";
          sha256 = "14b41njji4fwhcx5gqpbq6bkwx58qzz69700ybr0718h4fxyrx9j";
        };
      })
    ];
    keymaps = [
      {
        mode = "n";
        key = "<leader>q";
        action = "<cmd>lua local sidebar = require('avante').get(); if sidebar:is_open() then sidebar:close() end<CR><cmd>Neotree close<CR><cmd>q<CR>";
        options = {desc = "Quit and close NeoTree and Avante if open";};
      }
      {
        mode = "n";
        key = "<leader>w";
        action = "<cmd>w<CR>";
        options = {desc = "Save file";};
      }
      {
        mode = "n";
        key = "<leader>H";
        action = "";
        options = {desc = "Harpoon Mappings";};
      }
      # Harpoon mappings (Harpoon 2 API)
      # Harpoon add file (Harpoon 2: add to list)
      {
        mode = "n";
        key = "<leader>Ha";
        action = "<cmd>lua require('harpoon'):list():add()<CR>";
        options = {desc = "Harpoon add file";};
      }
      # Toggle Harpoon quick menu (Harpoon 2: pass the list to ui)
      {
        mode = "n";
        key = "<leader>Hm";
        action = "<cmd>lua require('harpoon').ui:toggle_quick_menu(require('harpoon'):list())<CR>";
        options = {desc = "Harpoon toggle quick menu";};
      }
      # Navigate to file 1 (Harpoon 2: select from list)
      {
        mode = "n";
        key = "<leader>1";
        action = "<cmd>lua require('harpoon'):list():select(1)<CR>";
        options = {desc = "Harpoon navigate to file 1";};
      }
      # Navigate to file 2
      {
        mode = "n";
        key = "<leader>2";
        action = "<cmd>lua require('harpoon'):list():select(2)<CR>";
        options = {desc = "Harpoon navigate to file 2";};
      }
      # Navigate to file 3
      {
        mode = "n";
        key = "<leader>3";
        action = "<cmd>lua require('harpoon'):list():select(3)<CR>";
        options = {desc = "Harpoon navigate to file 3";};
      }
      # Navigate to file 4
      {
        mode = "n";
        key = "<leader>4";
        action = "<cmd>lua require('harpoon'):list():select(4)<CR>";
        options = {desc = "Harpoon navigate to file 4";};
      }
      # Navigate to next mark (Harpoon 2: next on list)
      {
        mode = "n";
        key = "<leader>n";
        action = "<cmd>lua require('harpoon'):list():next()<CR>";
        options = {desc = "Harpoon navigate to next mark";};
      }
      # Navigate to previous mark (Harpoon 2: prev on list)
      {
        mode = "n";
        key = "<leader>p";
        action = "<cmd>lua require('harpoon'):list():prev()<CR>";
        options = {desc = "Harpoon navigate to previous mark";};
      }
      # Telescope Harpoon marks (unchanged, works with Harpoon 2)
      {
        mode = "n";
        key = "<leader>Hf";
        action = "<cmd>Telescope harpoon marks<CR>";
        options = {desc = "Search Harpoon marks with Telescope";};
      }
      {
        mode = "n";
        key = "<leader>s";
        action = "";
        options = {desc = "Search Mappings";};
      }
      {
        mode = "n";
        key = "<leader>sb";
        action = "<cmd>Telescope buffers<CR>";
        options = {desc = "Search buffers";};
      }
      {
        mode = "n";
        key = "<leader>sh";
        action = "<cmd>Telescope help_tags<CR>";
        options = {desc = "Search help tags";};
      }
      {
        mode = "n";
        key = "<leader>sf";
        action = "<cmd>Telescope find_files<CR>";
        options = {desc = "Find files";};
      }
      {
        mode = "n";
        key = "<leader>sg";
        action = "<cmd>Telescope live_grep<CR>";
        options = {desc = "Live grep";};
      }
      {
        mode = "n";
        key = "<C-t>";
        action = "<cmd>Neotree toggle<CR>";
        options = {desc = "Toggle Neotree";};
      }
      {
        mode = "n";
        key = "x";
        action = "\"_x";
        options = {desc = "Delete character without yank";};
      }
      {
        mode = "v";
        key = "d";
        action = "\"_d";
        options = {desc = "Delete selection without yank";};
      }
      {
        mode = "n";
        key = "<leader>e";
        action = "";
        options = {desc = "Error handling";};
      }
      {
        mode = "n";
        key = "<leader>ee";
        action = "<cmd>lua vim.diagnostic.open_float()<CR>";
        options = {desc = "Show diagnostics float";};
      }
      {
        mode = "n";
        key = "<leader>en";
        action = "<cmd>lua vim.diagnostic.goto_next()<CR>";
        options = {desc = "Go to next diagnostic";};
      }
      {
        mode = "n";
        key = "<leader>ep";
        action = "<cmd>lua vim.diagnostic.goto_prev()<CR>";
        options = {desc = "Go to previous diagnostic";};
      }
      {
        mode = "n";
        key = "<leader>el";
        action = "<cmd>Telescope diagnostics bufnr=0<CR>";
        options = {desc = "List buffer diagnostics";};
      }
      {
        mode = "n";
        key = "<leader>ed";
        action = "<cmd>Telescope diagnostics<CR>";
        options = {desc = "List all diagnostics";};
      }
      {
        mode = "n";
        key = "<leader>eh";
        action = "<cmd>Noice all<CR>";
        options = {desc = "Show all messages";};
      }
      {
        mode = "n";
        key = "<leader>eq";
        action = ''
          lua << EOF
          local function quickfix()
            vim.lsp.buf.code_action({
              filter = function(a) return a.isPreferred end,
              apply = true
            })
          end
          quickfix()
          EOF
        '';
        options = {
          desc = "Apply preferred LSP quickfix";
          noremap = true;
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>u";
        action = "<cmd>UndotreeToggle<CR><cmd>UndotreeFocus<CR>";
        options = {desc = "Toggle and focus Undotree window";};
      }
      {
        mode = "n";
        key = "<leader>t";
        action = "";
        options = {desc = "Toggle terminal";};
      }
      {
        mode = "n";
        key = "<leader>t1";
        action = "<cmd>ToggleTerm 1<CR>";
        options = {desc = "Toggle terminal 1";};
      }
      {
        mode = "n";
        key = "<leader>t2";
        action = "<cmd>ToggleTerm 2<CR>";
        options = {desc = "Toggle terminal 2";};
      }
      {
        mode = "n";
        key = "<leader>t3";
        action = "<cmd>ToggleTerm 3<CR>";
        options = {desc = "Toggle terminal 3";};
      }
      {
        mode = "n";
        key = "<leader>t4";
        action = "<cmd>ToggleTerm 4<CR>";
        options = {desc = "Toggle terminal 4";};
      }
      {
        mode = "n";
        key = "<leader>t5";
        action = "<cmd>ToggleTerm 5<CR>";
        options = {desc = "Toggle terminal 5";};
      }
      {
        mode = "n";
        key = "<leader>t6";
        action = "<cmd>ToggleTerm 6<CR>";
        options = {desc = "Toggle terminal 6";};
      }
      {
        mode = "n";
        key = "<leader>t7";
        action = "<cmd>ToggleTerm 7<CR>";
        options = {desc = "Toggle terminal 7";};
      }
      {
        mode = "n";
        key = "<leader>t8";
        action = "<cmd>ToggleTerm 8<CR>";
        options = {desc = "Toggle terminal 8";};
      }
      {
        mode = "n";
        key = "<leader>t9";
        action = "<cmd>ToggleTerm 9<CR>";
        options = {desc = "Toggle terminal 9";};
      }
      {
        mode = "n";
        key = "<leader>t0";
        action = "<cmd>ToggleTerm 10<CR>";
        options = {desc = "Toggle terminal 10";};
      }
      {
        mode = "n";
        key = "<leader><C-a>";
        action = "<Plug>(VM-Select-All)";
        options = {desc = "Select all occurrences";};
      }
      {
        mode = "n";
        key = "<C-n>";
        action = "<Plug>(VM-Find-Under)";
        options = {desc = "Find under cursor";};
      }
      {
        mode = "n";
        key = "<C-M-Down>";
        action = "<Plug>(VM-Add-Cursor-Down)";
        options = {desc = "Add cursor down";};
      }
      {
        mode = "n";
        key = "<C-M-Up>";
        action = "<Plug>(VM-Add-Cursor-Up)";
        options = {desc = "Add cursor up";};
      }
      {
        mode = "n";
        key = "<leader>S";
        action = "";
        options = {desc = "Spectre Mappings";};
      }
      {
        mode = "n";
        key = "<leader>Ss";
        action = "<cmd>lua require('spectre').toggle()<CR>";
        options = {desc = "Toggle Spectre";};
      }
      {
        mode = "v";
        key = "<leader>Sw";
        action = "<cmd>lua require('spectre').open_visual()<CR>";
        options = {desc = "Search selection with Spectre";};
      }
      {
        mode = "n";
        key = "<leader>Sp";
        action = "<cmd>lua require('spectre').open_file_search({select_word=true})<CR>";
        options = {desc = "Search in file with Spectre";};
      }
      {
        mode = "n";
        key = "<leader>rn";
        action = "<cmd>lua vim.lsp.buf.rename()<CR>";
        options = {
          desc = "Rename symbol";
          noremap = true;
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>a";
        action = "";
        options = {desc = "Avante";};
      }
    ];
    extraConfigLua = ''
       -- Lualine: Show full file path in filename
       require('lualine').setup({
         sections = {
           lualine_c = {
             {
               'filename',
               path = 1,  -- 1 = relative path
             },
           },
         },
       })
       -- Harpoon Setup
       local harpoon = require("harpoon")
       harpoon:setup({
           global_settings = {
           save_on_change = true;  -- Auto-save marks (your setting)
           sync_on_ui_close = true;  -- Sync on UI close (your setting)
           -- Add more from Harpoon docs if needed (e.g., menu = { width = 120; })
           }
           })
       require("telescope").load_extension("harpoon")
       -- Disable netrw at the very start of your init.lua (strongly advised)
       vim.g.loaded_netrw = 1
       vim.g.loaded_netrwPlugin = 1
       require("nvim-autopairs").setup()
       -- Mason Setup
       require("mason").setup()
       require("mason-lspconfig").setup({
         ensure_installed = {
           "ts_ls", "pyright", "lua_ls", "tailwindcss", "html", "cssls",
           "jsonls", "yamlls", "dockerls", "graphql", "bashls", "emmet_ls", "eslint"
         },
         automatic_installation = true,
       })
       -- DAP Setup
       local dap = require('dap')
       dap.adapters.node2 = {
         type = 'executable',
         command = '${pkgs.nodejs}/bin/node',
         args = { vim.fn.expand("${pkgs.vimPlugins.nvim-dap}/out/src/nodeDebug.js") },
       }
       dap.configurations.javascript = {
         {
           name = 'Launch',
           type = 'node2',
           request = 'launch',
           program = "$\{file}",
           cwd = vim.fn.getcwd(),
           sourceMaps = true;
           protocol = 'inspector',
           on_error = function(err)
             vim.notify("DAP Node2 adapter failed: " .. tostring(err), vim.log.levels.ERROR)
           end,
         },
       }
        -- Format on save (disabled)
        -- vim.api.nvim_create_autocmd("BufWritePre", {
        --   callback = function()
        --     vim.lsp.buf.format()
        --   end,
        -- })
       -- VSCode Snippets setup
       require('luasnip.loaders.from_vscode').lazy_load({ paths = { "./vscode-es7-javascript-react-snippets" } })
       -- Tailwind CSS Colorizer setup
       require("tailwindcss-colorizer-cmp").setup()
       -- Avante window size customization
       local open_sidebar = require("avante.sidebar").open
       require("avante.sidebar").open = function(self, opts)
         open_sidebar(self, opts)
         if self:get_layout() == "horizontal" then
           if self.containers.input ~= nil then
             self.containers.input:update_layout({
               size = {
                 height = "40%", -- Larger input window
               },
             })
           end
           if self.containers.result ~= nil then
             self.containers.result:update_layout({
               size = {
                 height = "20%", -- Smaller output window
               },
             })
           end
         elseif self:get_layout() == "vertical" then
           if self.containers.input ~= nil then
             self.containers.input:update_layout({
               size = {
                 height = "40%", -- Larger input window
               },
             })
           end
           if self.containers.result ~= nil then
             self.containers.result:update_layout({
               size = {
                 height = "20%", -- Smaller output window
               },
             })
           end
          end
        end
        -- Neominimap configuration - small box at bottom right
         vim.g.neominimap = {
           auto_enable = true,
           -- Make text bigger by reducing multipliers
           x_multiplier = 1,  -- Each minimap character spans 2 columns (bigger text)
           y_multiplier = 1,  -- Each minimap character spans 1 row
           layout = "float",
          float = {
            minimap_width = 20,  -- Small width for the box
            max_minimap_height = 50,  -- Limit height to keep it small
            margin = {
              right = 1,  -- Position from right edge
              top = 0,
              bottom = 1,  -- Position from bottom edge
            },
            z_index = 1,
            window_border = "none",  -- Clean look without border
          },
          -- Disable some features to keep it minimal
          diagnostic = {
            enabled = false,
          },
           git = {
             enabled = true,
             mode = "sign",  -- Show git changes as signs in the minimap
             priority = 6,
           },
          search = {
            enabled = false,
          },
          treesitter = {
            enabled = true,
          },
        }
      if vim.fn.has('macunix') == 1 then
         vim.g.clipboard = {
           name = 'macOS-clipboard',
           copy = {
             ['+'] = 'pbcopy',
             ['*'] = 'pbcopy'
           },
           paste = {
             ['+'] = 'pbpaste',
             ['*'] = 'pbpaste'
           },
           cache_enabled = 0
         }
       end
    '';
  };
}

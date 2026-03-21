return {
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    init = function()
      require('tokyonight').setup {
        transparent = true,
        style = 'night',
        dim_inactive = true,
      }
      vim.cmd [[colorscheme tokyonight]]
    end
  },
  {
    'nvim-lualine/lualine.nvim',
    lazy = false,
    dependencies = {
      'nvim-tree/nvim-web-devicons',
      'SmiteshP/nvim-navic',
      {
        'linrongbin16/lsp-progress.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        config = true
      },
    },
    config = function()
      local navic = require('nvim-navic')
      require('lualine').setup {
        options = {
          theme = 'tokyonight'
        },
        sections = {
          lualine_c = { { 'filename', path = 1 } },
        },
        tabline = {
          lualine_a = { { 'buffers' } },
          lualine_b = { {
            function()
              return navic.get_location()
            end,
            cond = navic.is_available
          } },
          lualine_z = { { 'require("lsp-progress").progress()' } },
        }
      }
      -- Callbacks to refresh LSP progress
      vim.api.nvim_create_augroup("lualine_augroup", { clear = true })
      vim.api.nvim_create_autocmd("LspProgress", {
        group = "lualine_augroup",
        callback = require("lualine").refresh,
      })
    end
  }}

return {
  { 'lambdalisue/vim-suda' },
  {
    'dstein64/vim-startuptime',
    cmd = 'StartupTime',
    init = function() vim.g.startuptime_tries = 10 end,
  },
  { 'folke/which-key.nvim' },
  {
    'folke/sidekick.nvim',
    opts = {
      nes = { enabled = false },
      cli = {
        context = {},
        prompts = {},
      }
    },
    keys = {
      {
        "<C-\\>",
        function() require("sidekick.cli").prompt({ name = "gemini" }) end,
        mode = { 'n', 'v', 'x' },
        desc = "Sidekick select prompt"
      }
    }
  },
}

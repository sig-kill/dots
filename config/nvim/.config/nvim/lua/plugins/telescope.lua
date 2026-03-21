return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
      bigfile = { enabled = true },
      dashboard = { enabled = true },
      dim = { enabled = true },
      explorer = { enabled = true },
      indent = { enabled = true },
      input = { enabled = true },
      picker = {
        enabled = true,
        win = {
          input = {
            keys = {
              ["<Esc>"] = { "close", mode = { "n", "i" } },
              ["i"] = { "toggle_focus", mode = { "n" } },
            }
          }
        }
      },
      notifier = { enabled = true },
      quickfile = { enabled = true },
      scope = { enabled = true },
      scroll = { enabled = true },
      statuscolumn = { enabled = true },
      words = { enabled = true },
    },
    keys = {
      { "<C-S-L>",     function() Snacks.picker.grep() end,      desc = "Grep" },
      { "<C-p>",       function() Snacks.picker.smart() end,     desc = "Smart Find Files" },
      { ":E ",         function() Snacks.picker.files() end,     desc = "Find Files" },
      { ":b",          function() Snacks.picker.buffers() end,   desc = "Buffers" },
      { ":B ",         function() Snacks.picker.buffers() end,   desc = "Buffers" },
      { ":reg<Enter>", function() Snacks.picker.registers() end, desc = "Registers" },
      { "<leader>u",   function() Snacks.picker.undo() end,      desc = "Undo tree" }
    }
  }
}

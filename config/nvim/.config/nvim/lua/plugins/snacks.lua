--- Jump to the buffer lualine lists at position `i` in the tabline.
---@param i integer
local function lualine_buffer_jump(i)
  return function()
    vim.cmd("LualineBuffersJump! " .. i)
  end
end

-- `:b<digit>` jumps by tabline position, `:b ` opens the buffers picker
local buffer_keys = {}
for i = 1, 9 do
  buffer_keys[i] = { ":b" .. i, lualine_buffer_jump(i), desc = "Buffer " .. i }
end

--- Name of the buffer lualine lists at position `i` in the tabline
---@param i integer
---@return string
local function tabline_buffer_name(i)
  local buf = (require("lualine.components.buffers").bufpos2nr or {})[i]
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return "no buffer"
  end
  local name = vim.api.nvim_buf_get_name(buf)
  return (name == "" and "[No Name]" or vim.fn.fnamemodify(name, ":~:."))
      .. (vim.bo[buf].modified and " [+]" or "")
end

-- which-key re-evaluates these on every popup, so labels track the tabline
do
  local specs = { { ":b", group = "Buffers" } }
  for i = 1, 9 do
    local n = i
    specs[#specs + 1] = {
      ":b" .. n,
      desc = function()
        return tabline_buffer_name(n)
      end,
    }
  end
  require("which-key").add(specs)
end

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
      dashboard = {
        enabled = true,
        preset = {
          keys = {
            { icon = " ", key = "e", desc = "Explorer", action = ":lua Snacks.picker.explorer()" },
            { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.picker.files()" },
            { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = " ", key = "c", desc = "Config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = " ", key = "s", desc = "Restore Session", section = "session" },
            { icon = "󰒲 ", key = "L", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy ~= nil },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
        sections = {
          { section = "header" },
          { icon = " ", title = "Keymaps", section = "keys", indent = 2, padding = 1 },
          { icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
          { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
          { section = "startup" },
        },
      },
      dim = { enabled = true },
      explorer = { enabled = true, replace_netrw = true },
      indent = { enabled = true },
      input = { enabled = true },
      picker = {
        enabled = true,
        sources = {
          explorer = {
            hidden = true,
            exclude = { '*.orig' },
          },
        },
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
      scroll = { enabled = os.getenv("SSH_CONNECTION") == nil },
      statuscolumn = { enabled = true },
      words = { enabled = true },
      rename = { enabled = true },
    },
    keys = vim.list_extend({
      { "<leader>/", function() Snacks.picker.grep() end,  desc = "Grep" },
      { "<C-p>",     function() Snacks.picker.smart() end, desc = "Smart Find Files" },
      {
        ":E ",
        function()
          Snacks.picker.files({
            exclude = { "GoogleDrive" }
          })
        end,
        desc = "Find Files"
      },
      { ":b ",         function() Snacks.picker.buffers() end,   desc = "Buffers" },
      { ":B ",         function() Snacks.picker.buffers() end,   desc = "Buffers" },
      { ":reg<Enter>", function() Snacks.picker.registers() end, desc = "Registers" },
      { "<leader>u",   function() Snacks.picker.undo() end,      desc = "Undo tree" },
      {
        "<leader>c",
        function() Snacks.picker.grep({ cwd = vim.fn.stdpath("config") }) end,
        desc = "Plugin specs"
      },
      { "<leader>p",  function() Snacks.picker.commands() end,            desc = "Commands" },
      { "gr",         function() Snacks.picker.lsp_references() end,      desc = "Find references" },
      { "gd",         function() Snacks.picker.lsp_definitions() end,     desc = "Go to definition" },
      { "gD",         function() Snacks.picker.lsp_declarations() end,    desc = "Go to declaration" },
      { "gI",         function() Snacks.picker.lsp_implementations() end, desc = "Go to implementation" },
      { "<leader>ss", function() Snacks.picker.lsp_symbols() end,         desc = "LSP symbols" },
      {
        "<leader>l",
        function() Snacks.picker.explorer({ matcher = { fuzzy = true } }) end,
        desc = "Explorer"
      }
    }, buffer_keys)
  }
}

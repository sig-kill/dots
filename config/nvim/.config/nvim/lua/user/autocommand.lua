local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

local general = augroup("General Settings", { clear = true })

autocmd("BufReadPost", {
  callback = function()
    if vim.fn.line "'\"" > 1 and vim.fn.line "'\"" <= vim.fn.line "$" then
      vim.cmd 'normal! g`"'
    end
  end,
  group = general,
  desc = "Jump to last cursor position on file open",
})

autocmd("BufReadPost", {
  callback = function()
    if vim.fn.line "'\"" > 1 and vim.fn.line "'\"" <= vim.fn.line "$" then
      vim.cmd 'normal! g`"'
    end
  end,
  group = general,
  desc = "Jump to last cursor position on file open",
})

autocmd("TextYankPost", {
  callback = function()
    vim.hl.on_yank{ higroup = "YankHighlight", timeout = 200 }
  end,
  group = general,
  desc = "Highlight on yank",
})

autocmd("BufEnter", {
  callback = function()
    vim.opt.formatoptions:remove { "c", "r", "o" }
  end,
  group = general,
  desc = "Disable continuing comment on newline",
})

-- autocmd({ "FocusLost", "BufLeave", "BufWinLeave", "InsertLeave" }, {
--   callback = function()
--     vim.cmd "silent! w"
--   end,
--   group = general,
--   desc = "Autosave",
-- })

autocmd("VimResized", {
  callback = function()
    vim.cmd "wincmd ="
  end,
  group = general,
  desc = "Equalize splits on resize",
})

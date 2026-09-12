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

autocmd("TextYankPost", {
  callback = function()
    vim.hl.on_yank({ higroup = "IncSearch", timeout = 200 })
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

autocmd({ "BufEnter", "WinEnter" }, {
  callback = function()
    if vim.w.column_match_id then
      pcall(vim.fn.matchdelete, vim.w.column_match_id)
      vim.w.column_match_id = nil
    end
    if vim.bo.buftype == "" and vim.bo.filetype ~= "" then
      vim.w.column_match_id = vim.fn.matchadd("ColorColumn", [[\%81v.]])
    end
  end,
  group = general,
  desc = "Highlight column 81 only if it exists",
})

autocmd({ "BufLeave", "WinLeave" }, {
  callback = function()
    if vim.w.column_match_id then
      pcall(vim.fn.matchdelete, vim.w.column_match_id)
      vim.w.column_match_id = nil
    end
  end,
  group = general,
})

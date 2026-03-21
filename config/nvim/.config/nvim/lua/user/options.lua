require('user/autocommand')
-------------
-- Options --
-------------
vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
vim.opt.mouse = ''
vim.opt.updatetime = 300
vim.opt.backup = false
vim.opt.number = true
vim.opt.swapfile = false
vim.opt.undodir = vim.fn.stdpath('config') .. "nvim/undo"
vim.opt.undofile = true

vim.opt.conceallevel = 0
vim.opt.foldenable = false

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.smartindent = true
vim.opt.hlsearch = true
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.textwidth = 80
vim.opt.termguicolors = true
vim.g.guibg = NONE

vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.scrolloff = 4
-- Ignore configs in old Vim directories
vim.opt.runtimepath:remove("/usr/share/vim/vimfiles")

-----------------
-- Keymappings --
-----------------
vim.g.mapleader = " "

local keyset = function(mode, lhs, rhs, desc)
  local opts = { noremap = true, silent = true }
  if desc ~= nil then
    opts['desc'] = desc
  end
  vim.keymap.set(mode, lhs, rhs, opts)
end
keyset("i", "jk", "<Esc>")
keyset("t", "<Esc><Esc>", "<C-\\><C-n>")
keyset("n", "j", "gj")
keyset("n", "k", "gk")
keyset("n", "Q", "@@")
keyset("n", "<C-h>", "<C-w>h")
keyset("n", "<C-j>", "<C-w>j")
keyset("n", "<C-k>", "<C-w>k")
keyset("n", "<C-l>", "<C-w>l")
keyset("n", "g=", function() vim.lsp.buf.format() end)
keyset("n", "<C-[>", function() vim.diagnostic.open_float() end)
keyset('n', '<leader>s', [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
  'Replace all instances of word')
keyset('n', '<leader>w', ":CellularAutomaton make_it_rain<CR>",
  "Why Can't I Hold All This Code")

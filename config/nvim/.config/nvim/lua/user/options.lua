vim.g.mapleader = " "
vim.g.maplocalleader = " "
require('user.util')
require('user.autocommand')
require('user.commands')
-------------
-- Options --
-------------
vim.opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
vim.opt.mouse = ''
vim.opt.updatetime = 300
vim.opt.backup = false
vim.opt.number = true
vim.opt.swapfile = false
local undodir = vim.fn.stdpath('state') .. "/undo"
if vim.fn.isdirectory(undodir) == 0 then
  vim.fn.mkdir(undodir, "p")
end
vim.opt.undodir = undodir
vim.opt.undofile = true

vim.opt.conceallevel = 0
vim.opt.foldenable = false

vim.opt.list = true
vim.opt.listchars = "tab:▷ ,trail:·,extends:◣,precedes:◢,nbsp:○"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.smartindent = true
vim.opt.hlsearch = true
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.textwidth = 0
vim.opt.termguicolors = true

vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.scrolloff = 4
-- Ignore configs in old Vim directories
vim.opt.runtimepath:remove("/usr/share/vim/vimfiles")

-----------------
-- Keymappings --
-----------------
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
keyset("n", "<leader>=", function() vim.lsp.buf.format() end)
keyset("n", "<C-'>", function() vim.diagnostic.open_float() end, "Open diagnostic float")
keyset("n", "[p", function() vim.diagnostic.jump({ count = -1, float = true }) end, "Jump to previous diagnostic")
keyset("n", "]p", function() vim.diagnostic.jump({ count = 1, float = true }) end, "Jump to next diagnostic")
keyset('n', '<leader>s', [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
  'Replace all instances of word')
keyset("n", "<leader>w", "<cmd>w<CR>", "Save file")
keyset("n", "[b", "<cmd>bprevious<CR>", "Previous buffer")
keyset("n", "]b", "<cmd>bnext<CR>", "Next buffer")
keyset("n", "<S-h>", "<cmd>bprevious<CR>", "Previous buffer")
keyset("n", "<S-l>", "<cmd>bnext<CR>", "Next buffer")
vim.cmd([[cabbrev <expr> w!! (getcmdtype() == ':' && getcmdline() == 'w!!') ? 'SudaWrite' : 'w!!']])
keyset("n", "<leader>rr", "<cmd>restart<CR>", "Restart Neovim")

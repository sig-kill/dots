-- Load all LSP configs
local lsp_path = vim.fn.stdpath("config") .. "/lua/lsp"

for file, type in vim.fs.dir(lsp_path) do
  local module = file:match("(.-)%.lua$")
  if module and module ~= "init" then
    require('lsp.' .. module)
  end
end

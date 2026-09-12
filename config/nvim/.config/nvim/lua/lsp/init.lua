-- Load all LSP configs
local lsp_path = vim.fn.stdpath("config") .. "/lua/lsp"

if vim.fn.isdirectory(lsp_path) == 1 then
  for file, _ in vim.fs.dir(lsp_path) do
    local module = file:match("(.-)%.lua$")
    if module and module ~= "init" then
      require('lsp.' .. module)
    end
  end
end

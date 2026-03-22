function reload_config()
  for name, _ in pairs(package.loaded) do
    if name:match('^user') or name:match('^lsp') or name:match('^plugins') then
      package.loaded[name] = nil
    end
  end
  dofile(vim.env.MYVIMRC)
  vim.notify("nvim config reloaded", vim.log.levels.INFO)
end

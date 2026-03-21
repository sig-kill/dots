vim.api.nvim_create_user_command('Rename', function(opts)
    local dir = vim.fn.expand('%:p:h')
    local new_name = dir .. '/' .. opts.args
    Snacks.rename.rename_file({ to = new_name })
  end,
  { nargs = 1, desc = 'Rename the current file' })

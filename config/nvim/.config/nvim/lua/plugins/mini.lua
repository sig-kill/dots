return {
  {
    'nvim-mini/mini.sessions',
    version = false,
    opts = {
      autoread = true,
      autowrite = true,
      file = ''
    }
  },
  { 'nvim-mini/mini.cursorword', opts = { delay = 40 } },
  {
    'nvim-mini/mini.hipatterns',
    opts = function()
      local hipatterns = require('mini.hipatterns')
      return {
        highlighters = {
          -- Highlight standalone 'FIXME', 'HACK', 'TODO', 'NOTE'
          fixme     = { pattern = '%f[%w]()FIXME()%f[%W]', group = 'MiniHipatternsFixme' },
          hack      = { pattern = '%f[%w]()HACK()%f[%W]', group = 'MiniHipatternsHack' },
          todo      = { pattern = '%f[%w]()TODO()%f[%W]', group = 'MiniHipatternsTodo' },
          note      = { pattern = '%f[%w]()NOTE()%f[%W]', group = 'MiniHipatternsNote' },

          -- Highlight hex color strings (`#ff0000`) using that color
          hex_color = hipatterns.gen_highlighter.hex_color(),
        },
      }
    end
  },

}

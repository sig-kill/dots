local awful = require('awful')

return {
  restore_session = function(s)
    local debug = io.open(persist_tags_filename .. '.debug_' .. tostring(s.index), 'w+')
    local f = io.open(
      persist_tags_filename .. '.screen_' .. tostring(s.index), 'r')
    if f and debug then
      local tag_number = 1
      for line in f:lines('*l') do
        local tagname, layout_index = line:match('(%g+) (%d+) #.*')
        debug:write('Setting ' .. tagname .. ' to '
          .. layout_index .. ':'
          .. tostring(awful.layout.layouts[tonumber(layout_index)].name) .. '\n')
        s.tags[tag_number].name = tagname
        s.tags[tag_number].layout = awful.layout.layouts[tonumber(layout_index)]
        tag_number = tag_number + 1
      end
      f:close()
      -- Focus last focused tag
      if #s.tags >= 1 then
        local fname = persist_tags_filename .. "-selected." .. tostring(s.index)
        f = io.open(fname, "r")
        local last_focused_tagnum = 1
        if f then
          last_focused_tagnum = tonumber(f:read("*l"))
          if last_focused_tagnum == nil or last_focused_tagnum > #s.tags then
            last_focused_tagnum = 1
          end
          f:close()
        end
        s.tags[last_focused_tagnum]:view_only()
      end
      debug:close()
    end
  end,

  persist_session = function(_)
    for s in screen do
      local f = io.open(persist_tags_filename .. ".screen_" .. tostring(s.index), "w+")
      if f then
        for _, t in ipairs(s.tags) do
          f:write(t.name .. " "
            .. awful.layout.get_tag_layout_index(t)
            .. ' # layout: ' .. t.layout.name .. "\n")
        end
        f:close()
      end
      f = io.open(persist_tags_filename .. "-selected." .. tostring(s.index), "w+")
      if f then
        f:write(s.selected_tag.index .. "\n")
        f:close()
      end
    end
  end
}

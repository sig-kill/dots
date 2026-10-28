-- Tag lookup by name, tolerating the "<index>:" prefix used by tag names.

local M = {}

local function tag_base(name)
  return (name:gsub("^%d+:", ""))
end

-- Resolve "index:tag" and "tag" to the tag named "index:tag".
M.find_tag = function(screen, name)
  if not screen or not name then return nil end
  local base = tag_base(name)
  for _, t in ipairs(screen.tags) do
    if t.name == name or tag_base(t.name) == base then return t end
  end
  return nil
end

return M

---------------------------------------------------------------------------
--- Centerwork layout module for SomeWM
--
-- Features:
-- - One master window centered horizontally.
-- - Flanking secondary columns on left and right.
-- - Creation order:
--     1: Center (master)
--     2: Left (full height)
--     3: Right (full height)
--     4: Left half-split bottom (left column divided in 2: #2 top, #4 bottom)
--     5: Right half-split bottom (right column divided in 2: #3 top, #5 bottom)
--     6: Left tri-split bottom (left column divided in 3: #2, #4, #6)
--     7: Right tri-split bottom (right column divided in 3: #3, #5, #7)
--     etc.
-- - Single client remains centered with master_width_factor.
-- - Two clients: center remains centered, left occupies left column, right remains empty.
-- - Master width factor dynamically adjustable via mouse drag (Mod4 + Right Click) or keybindings.
---------------------------------------------------------------------------

-- Clamp for master_width_factor, applied by both arrange() and the mouse
-- resize handler.
local MIN_MASTER_WIDTH_FACTOR = 0.05
local MAX_MASTER_WIDTH_FACTOR = 0.95

local capi = {
  screen = screen,
  mouse = mouse,
  mousegrabber = mousegrabber,
}

local centerwork = {
  name = "centerwork",
}

-- Geometry contract: the master keeps `master_width_factor` of the workarea and
-- stays centered; the remaining width is split into a left and a right column
-- (odd pixel goes to the right one), and each column is divided between its
-- clients (remaining pixels go to the last one).
function centerwork.arrange(p)
  local wa = p.workarea
  local cls = p.clients
  if not cls or #cls == 0 then return end

  local t = p.tag or (capi.screen and capi.screen[p.screen] and capi.screen[p.screen].selected_tag)
  local mwfact = (t and t.master_width_factor) or 0.5
  mwfact = math.max(MIN_MASTER_WIDTH_FACTOR, math.min(MAX_MASTER_WIDTH_FACTOR, mwfact))

  local main_width = math.floor(wa.width * mwfact)
  local side_width = wa.width - main_width
  local left_width = math.floor(side_width / 2)
  local right_width = side_width - left_width

  local left_x = wa.x
  local center_x = wa.x + left_width
  local right_x = wa.x + left_width + main_width

  -- 1. Master window in center
  p.geometries[cls[1]] = {
    x = center_x,
    y = wa.y,
    width = math.max(1, main_width),
    height = math.max(1, wa.height),
  }

  if #cls <= 1 then return end

  -- 2. Left column (even indices: 2, 4, 6, ...)
  local num_left = math.floor(#cls / 2)
  if num_left > 0 then
    local h_left = math.floor(wa.height / num_left)
    for i = 2, #cls, 2 do
      local k = i / 2
      local y_pos = wa.y + (k - 1) * h_left
      local h = (k == num_left) and (wa.y + wa.height - y_pos) or h_left
      p.geometries[cls[i]] = {
        x = left_x,
        y = y_pos,
        width = math.max(1, left_width),
        height = math.max(1, h),
      }
    end
  end

  -- 3. Right column (odd indices: 3, 5, 7, ...)
  local num_right = math.floor((#cls - 1) / 2)
  if num_right > 0 then
    local h_right = math.floor(wa.height / num_right)
    for i = 3, #cls, 2 do
      local k = (i - 1) / 2
      local y_pos = wa.y + (k - 1) * h_right
      local h = (k == num_right) and (wa.y + wa.height - y_pos) or h_right
      p.geometries[cls[i]] = {
        x = right_x,
        y = y_pos,
        width = math.max(1, right_width),
        height = math.max(1, h),
      }
    end
  end
end

function centerwork.skip_gap(nclients, t)
  -- Do not skip gap so that padding around the centered master is preserved
  return false
end

centerwork.resize_jump_to_corner = false

-- Mod4 + Right click: snap the pointer to the master border, then track the
-- pointer until the button is released and update master_width_factor live.
function centerwork.mouse_resize_handler(c, corner, x, y)
  if not c or not c.screen then return end
  local s = c.screen
  local t = s.selected_tag
  if not t then return end

  local wa = s.workarea
  local center_x = wa.x + wa.width / 2
  local cur = capi.mouse.coords()

  -- Calculate closest master border
  local mwfact = t.master_width_factor or 0.5
  local half_w = math.floor((wa.width * mwfact) / 2)
  local border_x = (cur.x < center_x) and (center_x - half_w) or (center_x + half_w)

  -- Snap X to border, preserve Y
  capi.mouse.coords({ x = math.floor(border_x), y = cur.y })

  capi.mousegrabber.run(function(m)
    if not c.valid then return false end

    for _, btn in ipairs(m.buttons) do
      if btn then
        local dist = math.abs(m.x - center_x)
        local new_mwfact = (2 * dist) / wa.width
        new_mwfact = math.min(math.max(new_mwfact, MIN_MASTER_WIDTH_FACTOR),
          MAX_MASTER_WIDTH_FACTOR)
        t.master_width_factor = new_mwfact
        return true
      end
    end
    return false
  end, "sb_h_double_arrow")
end

return centerwork

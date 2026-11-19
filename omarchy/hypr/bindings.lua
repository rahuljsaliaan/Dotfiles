-- Keep only your personal keybinding overrides here. Add new bindings with
-- o.bind or replace defaults with o.rebind.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding. o.rebind takes the same arguments as o.bind.
-- This example replaces the default file manager with Flea.
-- o.rebind("SUPER + SHIFT + F", "File manager", { launch = "flea" })

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, { panel = "omarchy.emojis" })

-- Window overview (NittyGriddy plugin): Super+E opens/closes a grid of every
-- window on the focused screen ("Exposé"); three-finger swipes are in
-- hypr/gestures.lua. Only these and Esc are taken from the plugin's snippet:
-- its Super+Tab, Super+W/Q and Super+Shift+number overrides are left out so
-- Omarchy's keys keep working as before.
o.bind("SUPER + E", "Window overview", "omarchy-shell shell toggle timsonner.nitty-griddy")

-- Hyprpin plugin: its keys act on windows that have a Hyprpin rule (set in its
-- bar panel) and fall back to Omarchy's own action for every other window, so
-- ordinary windows behave exactly as before.
--   Super+O      pop the window out to its rule's spot, or put it back
--   Super+T      float a tiled-edge pin out / tile a corner pin in
--   Super+P      cycle the pin's placement (edges, then corners)
--   Super+Z      zoom a pop-out to half the screen and back (new key)
--   Super+Alt+S  send the pin to the scratchpad (Super+S summons it)
--   Super+Alt+O  switch Hyprpin on/off, like right-clicking its bar icon
--                (Super+Shift+O stays Omarchy's Obsidian); the panel, to add
--                a window or change its spot, opens from the pin icon
local function hyprpin_or(name, fallback)
  return function()
    local window = hl.get_active_window()
    if not window then return end
    local hyprpin = _G.__hyprpin
    if hyprpin and hyprpin[name] and hyprpin[name](window.address) then return end
    if fallback then fallback() end
  end
end

-- Pop-out and float toggle, done here rather than through Omarchy's
-- omarchy-hyprland-window-pop and a bare float toggle. Both of those *toggle*
-- floating, which on a floating-layout workspace tiles a window that was
-- already floating: Super+O tiled the window instead of popping it (a second
-- press popped it), and tiling a window there is where Hyprland 0.56.2 crashed
-- twice on 2026-11-14 (a null layout space in its float-toggle and centre
-- code; crash reports in ~/.cache/hyprland). So Super+O sets floating
-- explicitly and never toggles it blind. Super+T still toggles: that is its job.
local POP_TILED = "pop-was-tiled"
local FLOATING_WORKSPACE = "omarchy-floating-workspace"

local function has_tag(window, name)
  for _, tag in ipairs(window.tags or {}) do
    local plain = tag:gsub("%*$", "")
    if plain == name then return true end
  end
  return false
end

local function set_tag(window, tag)
  hl.dispatch(hl.dsp.window.tag({ tag = tag, window = window }))
end

local function pop_size(window)
  local monitor = window.monitor
  if not monitor or not monitor.width then return 1300, 900 end
  local scale = monitor.scale or 1
  local width, height = math.floor(monitor.width / scale), math.floor(monitor.height / scale)
  if (monitor.transform or 0) % 2 == 1 then width, height = height, width end
  return math.min(1300, math.floor(width * 0.9)), math.min(900, math.floor(height * 0.9))
end

-- Super+O: float the window, centre it and pin it to every workspace; again
-- puts it back, tiled only if popping is what floated it.
local function pop_out()
  local window = hl.get_active_window()
  if not window then return end

  if window.pinned then
    hl.dispatch(hl.dsp.window.pin({ window = window }))
    set_tag(window, "-pop")
    if has_tag(window, POP_TILED) then
      set_tag(window, "-" .. POP_TILED)
      if not has_tag(window, FLOATING_WORKSPACE) then
        hl.dispatch(hl.dsp.window.float({ action = "off", window = window }))
      end
    end
    return
  end

  local fullscreen = window.fullscreen or 0
  if fullscreen ~= 0 then
    hl.dispatch(hl.dsp.window.fullscreen({ mode = fullscreen == 1 and "maximized" or "fullscreen", action = "unset", window = window }))
  end
  if not window.floating then
    set_tag(window, "+" .. POP_TILED)
    hl.dispatch(hl.dsp.window.float({ action = "on", window = window }))
  end
  local width, height = pop_size(window)
  hl.dispatch(hl.dsp.window.resize({ x = width, y = height, relative = false, window = window }))
  hl.dispatch(hl.dsp.window.center({ window = window }))
  hl.dispatch(hl.dsp.window.pin({ window = window }))
  hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = window }))
  set_tag(window, "+pop")
end

-- Super+T: float or tile the window, as Omarchy's own binding does. It was
-- briefly blocked for floating windows on floating-layout workspaces as a crash
-- precaution, but tiling a window there is a normal thing to want, the crash
-- never reproduced with it alone, and the block took the key away.
-- user_tiled remembers a window tiled this way, so a floating workspace's mode
-- does not float it again when it leaves fullscreen (hypr/user-tiled.lua).
local user_tiled = require("hypr.user-tiled")

-- Super + T floats a window at the size Omarchy gives every window on a
-- floating workspace (default/hypr/workspace-modes.lua): min(1100, 64%) x
-- min(760, 68%) of the screen inside the bar, centred. One size everywhere,
-- the Super + S scratchpad included, keeps floating windows consistent.
-- Hyprland's own choice, the size the window last floated at, varied from
-- window to window and could be the whole screen (left by a fullscreen or
-- full-size window): that came out over the bar and past the top edge, and in
-- the scratchpad off the screen altogether.
local function float_size(monitor)
  local scale = monitor.scale or 1
  local width = math.floor((monitor.width or 0) / scale)
  local height = math.floor((monitor.height or 0) / scale)
  if (monitor.transform or 0) % 2 == 1 then width, height = height, width end
  local reserved = monitor.reserved or {}
  width = width - (reserved.left or 0) - (reserved.right or 0)
  height = height - (reserved.top or 0) - (reserved.bottom or 0)
  return math.min(1100, math.floor(width * 0.64)), math.min(760, math.floor(height * 0.68))
end

-- A scratchpad float is sized again when the scratchpad next opens on another
-- screen: Hyprland carries a float across at its old size, which is not that
-- screen's size (and overflowed a smaller one). Tiling it drops the tag.
local SCRATCHPAD = "special:scratchpad"
local SCRATCHPAD_FLOAT = "rahulj-scratchpad-float"
local OLD_SCRATCHPAD_FILL = "rahulj-scratchpad-fill"
local floated_on = {}

local function size_float(window)
  local width, height = float_size(window.monitor)
  if width < 200 or height < 150 then return end
  hl.dispatch(hl.dsp.window.resize({ x = width, y = height, relative = false, window = window }))
  hl.dispatch(hl.dsp.window.center({ window = window }))
  floated_on[window.address] = window.monitor.name
end

local function fit_float(address)
  local window = hl.get_window("address:" .. address)
  if not window or not window.floating or not window.monitor or (window.fullscreen or 0) ~= 0 then return end
  if window.workspace and window.workspace.name == SCRATCHPAD then
    set_tag(window, "+" .. SCRATCHPAD_FLOAT)
  end
  if has_tag(window, OLD_SCRATCHPAD_FILL) then set_tag(window, "-" .. OLD_SCRATCHPAD_FILL) end
  size_float(window)
end

local function pair(v)
  if type(v) ~= "table" then return 0, 0 end
  return v.x or v[1] or 0, v.y or v[2] or 0
end

-- Super + T twice should put a window back where it was, but Hyprland tiles a
-- window again as a brand-new one: the scrolling layout puts it after the
-- column in the middle of the row, dwindle splits whatever the focus is on. So
-- the window's place among its workspace's tiled windows is noted as it floats
-- and put back as it tiles. A place is a column of the row, windows that share
-- a column's x stacking in it, counted from the left; scrolling swaps the
-- window's column back to it (and gives it its old width). Dwindle notes the
-- window it was split from and which side of it it was on, and tiles it there
-- again by preselecting that side of the old neighbour.
local PLACE_SLACK = 20
local places = {}

local function tiled_columns(workspace)
  local list = {}
  for _, other in ipairs(workspace:get_windows() or {}) do
    if not other.floating and other.mapped and not other.hidden then
      local x, y = pair(other.at)
      list[#list + 1] = { window = other, x = x, y = y }
    end
  end
  table.sort(list, function(a, b) return a.x < b.x end)

  local columns, column_x = {}, nil
  for _, entry in ipairs(list) do
    if not column_x or entry.x - column_x > PLACE_SLACK then
      columns[#columns + 1] = {}
      column_x = entry.x
    end
    local column = columns[#columns]
    column[#column + 1] = entry
  end
  for _, column in ipairs(columns) do
    table.sort(column, function(a, b) return a.y < b.y end)
  end
  return columns
end

local function column_of(columns, address)
  for i, column in ipairs(columns) do
    for _, entry in ipairs(column) do
      if entry.window.address == address then return i end
    end
  end
end

-- The tiled window a dwindle window was split from: the one that takes over
-- its space when it floats. It shares a whole edge with the window (same span,
-- touching across the gap); failing that, the neighbour with the longest shared
-- edge. Returns it and the side of it the window sat on ("l", "r", "u", "d").
local EDGE_GAP = 40
local EDGE_SPAN = 6

local function dwindle_sibling(window)
  local bx, by = pair(window.at)
  local bw, bh = pair(window.size)
  local best, best_side, best_overlap, best_exact

  for _, other in ipairs(window.workspace:get_windows() or {}) do
    if other.address ~= window.address and not other.floating and other.mapped and not other.hidden then
      local ox, oy = pair(other.at)
      local ow, oh = pair(other.size)
      local side, overlap, exact
      local x_overlap = math.min(bx + bw, ox + ow) - math.max(bx, ox)
      local y_overlap = math.min(by + bh, oy + oh) - math.max(by, oy)
      if math.abs(ox - (bx + bw)) <= EDGE_GAP and y_overlap > 0 then
        side, overlap, exact = "r", y_overlap, math.abs(oy - by) <= EDGE_SPAN and math.abs(oh - bh) <= EDGE_SPAN
      elseif math.abs((ox + ow) - bx) <= EDGE_GAP and y_overlap > 0 then
        side, overlap, exact = "l", y_overlap, math.abs(oy - by) <= EDGE_SPAN and math.abs(oh - bh) <= EDGE_SPAN
      elseif math.abs(oy - (by + bh)) <= EDGE_GAP and x_overlap > 0 then
        side, overlap, exact = "d", x_overlap, math.abs(ox - bx) <= EDGE_SPAN and math.abs(ow - bw) <= EDGE_SPAN
      elseif math.abs((oy + oh) - by) <= EDGE_GAP and x_overlap > 0 then
        side, overlap, exact = "u", x_overlap, math.abs(ox - bx) <= EDGE_SPAN and math.abs(ow - bw) <= EDGE_SPAN
      end
      if side and (not best or (exact and not best_exact) or (exact == best_exact and overlap > best_overlap)) then
        best, best_side, best_overlap, best_exact = other, side, overlap, exact
      end
    end
  end
  return best, best_side
end

local function remember_place(window)
  -- A floating window keeps the place noted when it floated.
  if window.floating then return end
  places[window.address] = nil
  if (window.fullscreen or 0) ~= 0 or not window.workspace then return end
  if window.workspace.tiled_layout == "dwindle" then
    local sibling, side = dwindle_sibling(window)
    if sibling then
      places[window.address] = { workspace = window.workspace.id, sibling = sibling.address, side = side }
    end
    return
  end
  local columns = tiled_columns(window.workspace)
  local index = column_of(columns, window.address)
  if not index then return end
  -- A window that sat below others in a column comes back as its own column
  -- next to theirs: Hyprland tiles it into a column of its own, and putting it
  -- back in the stack is not something it offers.
  local below = columns[index][1].window.address ~= window.address
  places[window.address] = {
    workspace = window.workspace.id,
    column = below and index + 1 or index,
    width = (pair(window.size)),
  }
end

-- The width a column's share of the row is measured against: the screen less
-- the outer gaps.
local function row_width(monitor)
  if not monitor or not monitor.width then return nil end
  local width = monitor.width / (monitor.scale or 1)
  if (monitor.transform or 0) % 2 == 1 then width = (monitor.height or 0) / (monitor.scale or 1) end
  local gaps = hl.get_config("general.gaps_out")
  if type(gaps) == "table" then
    width = width - (gaps.left or 0) - (gaps.right or 0)
  elseif type(gaps) == "number" then
    width = width - 2 * gaps
  end
  return width
end

-- Layout messages go to the focused monitor's workspace, which is the
-- window's own only when it is the one on screen; a special workspace (the
-- scratchpad) counts while it is open, and the focused window is on it.
local function messages_reach(window)
  local active = hl.get_active_workspace()
  if not active or not window.workspace then return false end
  if active.id == window.workspace.id then return true end
  local focused = hl.get_active_window()
  return window.workspace.name:sub(1, 8) == "special:" and focused ~= nil and focused.address == window.address
end

local function restore_place(window)
  local place = places[window.address]
  places[window.address] = nil
  if not place or not window.workspace or window.workspace.id ~= place.workspace then return end
  if window.workspace.tiled_layout ~= "scrolling" then return end

  if not messages_reach(window) then return end

  local columns = tiled_columns(window.workspace)
  local from = column_of(columns, window.address)
  if not from then return end
  local steps = math.min(place.column, #columns) - from
  for _ = 1, math.abs(steps) do
    hl.dispatch(hl.dsp.layout("swapcol " .. (steps < 0 and "l" or "r")))
  end

  -- A tiled window gets the default column width; give back the one it had.
  local row = row_width(window.monitor)
  local now = hl.get_window("address:" .. window.address)
  if not row or not now then return end
  local missing = place.width - (pair(now.size))
  if math.abs(missing) > 6 then
    hl.dispatch(hl.dsp.layout(string.format("colresize %+.4f", missing / row)))
  end
end

-- Tile a floating dwindle window next to the window it was split from, on the
-- side it was on: preselect that side of the old neighbour (the side of it the
-- new window opens on is the opposite of where the neighbour was) and tile with
-- the neighbour focused. Returns false, leaving everything as it was, when
-- there is nothing to go back to.
local OPENS_ON = { l = "r", r = "l", u = "d", d = "u" }

local function tile_in_place(window)
  local place = places[window.address]
  if not place or not place.sibling or not window.workspace or window.workspace.id ~= place.workspace then return false end
  if window.workspace.tiled_layout ~= "dwindle" then return false end
  if not messages_reach(window) then return false end

  local sibling = hl.get_window("address:" .. place.sibling)
  if not sibling or sibling.floating or not sibling.mapped or sibling.hidden
      or not sibling.workspace or sibling.workspace.id ~= place.workspace then
    return false
  end

  places[window.address] = nil
  local no_warps = hl.get_config("cursor.no_warps")
  hl.config({ cursor = { no_warps = true } })
  hl.dispatch(hl.dsp.focus({ window = "address:" .. sibling.address }))
  hl.dispatch(hl.dsp.layout("preselect " .. OPENS_ON[place.side]))
  hl.dispatch(hl.dsp.window.float({ action = "off", window = window }))
  hl.dispatch(hl.dsp.focus({ window = "address:" .. window.address }))
  hl.config({ cursor = { no_warps = no_warps == true } })
  return true
end

local function toggle_floating()
  local window = hl.get_active_window()
  if window then remember_place(window) end
  if not (window and window.floating and tile_in_place(window)) then
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
  end
  if window then
    local now = hl.get_window("address:" .. window.address)
    if now and not now.floating then
      restore_place(now)
      for _, tag in ipairs({ SCRATCHPAD_FLOAT, OLD_SCRATCHPAD_FILL }) do
        if has_tag(now, tag) then set_tag(now, "-" .. tag) end
      end
      floated_on[now.address] = nil
    end
    fit_float(window.address)
  end
  user_tiled.remember(window)
end

hl.on("window.close", function(closed)
  if closed and closed.address then places[closed.address] = nil end
end)

hl.on("workspace.special_active", function(workspace)
  if not workspace or workspace.name ~= SCRATCHPAD then return end
  hl.timer(function()
    for _, listed in ipairs(hl.get_windows({ tag = SCRATCHPAD_FLOAT }) or {}) do
      local window = hl.get_window("address:" .. listed.address)
      if window and window.floating and window.monitor and (window.fullscreen or 0) == 0
          and window.workspace and window.workspace.name == SCRATCHPAD
          and floated_on[window.address] ~= window.monitor.name then
        size_float(window)
      end
    end
  end, { type = "oneshot", timeout = 60 })
end)

-- Reachable from `hyprctl eval`, so both can be run without the keys.
_G.rahulj_keys = { pop_out = pop_out, toggle_floating = toggle_floating, fit_float = fit_float }

hl.unbind("SUPER + O")
o.bind("SUPER + O", "Pop window out (Hyprpin or float & pin)", hyprpin_or("toggle_pop", pop_out))
hl.unbind("SUPER + T")
o.bind("SUPER + T", "Toggle window floating/tiling (tiles back in its old place; Hyprpin dock)", hyprpin_or("toggle_dock", toggle_floating))
hl.unbind("SUPER + P")
o.bind("SUPER + P", "Cycle Hyprpin placement / pseudo window", hyprpin_or("cycle", function() hl.dispatch(hl.dsp.window.pseudo()) end))
o.bind("SUPER + Z", "Zoom Hyprpin pop-out", hyprpin_or("toggle_big"))
o.bind("SUPER + ALT + O", "Hyprpin on/off", "hyprpin-toggle")
hl.unbind("SUPER + ALT + S")
o.bind("SUPER + ALT + S", "Move window to scratchpad (Hyprpin aware)", hyprpin_or("send_to_scratchpad", function() hl.dispatch(hl.dsp.window.move({ workspace = "special:scratchpad", follow = false })) end))

-- Esc closes the overview while it is open, and passes through otherwise.
local function nitty_griddy_mapped()
  local layers = hl.get_layers({ namespace = "timsonner-nitty-griddy" })
  return layers ~= nil and #layers > 0
end

local function dismiss_nitty_griddy()
  if not nitty_griddy_mapped() then
    return { ok = false }
  end
  hl.dispatch(hl.dsp.exec_cmd("omarchy-shell shell hide timsonner.nitty-griddy"))
end

o.bind_commands[dismiss_nitty_griddy] = "omarchy-shell shell hide timsonner.nitty-griddy"
o.bind("ESCAPE", "Close window overview", dismiss_nitty_griddy, { auto_consuming = true })

-- Super+Tab / Super+Shift+Tab page the overview's workspace strip (All, 1, 2,
-- 3, ...) while it is open, and otherwise do exactly what Omarchy's do: next /
-- previous workspace on this monitor (m+1 / m-1).
local function overview_or_next_workspace()
  if nitty_griddy_mapped() then
    hl.dispatch(hl.dsp.event("timsonner.nitty-griddy:workspace-next"))
    return
  end
  hl.dispatch(hl.dsp.focus({ workspace = "m+1" }))
end

local function overview_or_previous_workspace()
  if nitty_griddy_mapped() then
    hl.dispatch(hl.dsp.event("timsonner.nitty-griddy:workspace-prev"))
    return
  end
  hl.dispatch(hl.dsp.focus({ workspace = "m-1" }))
end

o.bind_commands[overview_or_next_workspace] = 'hl.dsp.focus({ workspace = "m+1" })'
o.bind_commands[overview_or_previous_workspace] = 'hl.dsp.focus({ workspace = "m-1" })'
o.rebind("SUPER + TAB", "Next workspace", overview_or_next_workspace)
o.rebind("SUPER + SHIFT + TAB", "Previous workspace", overview_or_previous_workspace)

-- H/J/K/L alternatives to Omarchy's Super + arrow binds. On the 60% keyboard
-- the arrows need Fn, and Fn together with Super toggles the keyboard's own
-- Win-key lock, so these avoid Fn entirely. The arrow binds stay as they are.
local vim_directions = {
  { key = "H", dir = "l", name = "left", swap = "to the left" },
  { key = "J", dir = "d", name = "down", swap = "down" },
  { key = "K", dir = "u", name = "up", swap = "up" },
  { key = "L", dir = "r", name = "right", swap = "to the right" },
}

for _, d in ipairs(vim_directions) do
  o.bind("SUPER + SHIFT + " .. d.key, "Swap window " .. d.swap, hl.dsp.window.swap({ direction = d.dir }))
  o.bind("SUPER + SHIFT + CTRL + " .. d.key, "Move window to " .. d.name .. " monitor", o.workspaces.move_window_to_monitor(d.dir))
  o.bind("SUPER + SHIFT + ALT + " .. d.key, "Move workspace to " .. d.name .. " monitor", o.workspaces.move_to_monitor(d.dir))
end

-- Super + H/J/K/L focus stays on the current workspace: Hyprland's directional
-- focus falls through to the next monitor when nothing is left in that
-- direction, so only dispatch when this workspace has a window on that side.
local function vec(v)
  if type(v) ~= "table" then
    return 0, 0
  end
  return v.x or v[1] or 0, v.y or v[2] or 0
end

local function center(window)
  local x, y = vec(window.at)
  local w, h = vec(window.size)
  return x + w / 2, y + h / 2
end

local function has_window_towards(dir)
  local active = hl.get_active_window()
  if not active or not active.workspace then
    return false
  end

  local cx, cy = center(active)
  for _, w in ipairs(active.workspace:get_windows() or {}) do
    if w.address ~= active.address and w.mapped and not w.hidden then
      local wx, wy = center(w)
      if (dir == "l" and wx < cx - 1) or (dir == "r" and wx > cx + 1)
        or (dir == "u" and wy < cy - 1) or (dir == "d" and wy > cy + 1) then
        return true
      end
    end
  end
  return false
end

local function within_workspace(dir, dispatcher)
  return function()
    if has_window_towards(dir) then
      hl.dispatch(dispatcher)
    end
  end
end

-- Left/right focus wraps around: past the last window it goes back to the
-- first, and before the first it goes on to the last. "First" and "last" are
-- the leftmost and rightmost columns of this workspace (the topmost window of
-- that column), so it works the same on the scrolling layout, where columns
-- off screen still have a place in the row. Nothing wraps when every window
-- shares one column, since there is no other side to jump to.
local function wrap_target(dir)
  local active = hl.get_active_window()
  if not active or not active.workspace then
    return nil
  end

  local cx = center(active)
  local best, best_x, best_y
  for _, w in ipairs(active.workspace:get_windows() or {}) do
    if w.mapped and not w.hidden then
      local wx, wy = center(w)
      local better = not best
        or (dir == "r" and wx < best_x - 1) or (dir == "l" and wx > best_x + 1)
        or (math.abs(wx - best_x) <= 1 and wy < best_y)
      if better then
        best, best_x, best_y = w, wx, wy
      end
    end
  end

  if best and math.abs(best_x - cx) > 1 then
    return best
  end
  return nil
end

-- Inside a window group, left/right walk the group's tabs first: the tabs sit
-- side by side in the group bar, so H/L reach them as they read. Past the
-- first or last tab the key goes on to the next window as usual.
local function group_step(dir)
  local active = hl.get_active_window()
  local group = active and active.group
  if not group or (group.size or 0) < 2 or type(group.members) ~= "table" then
    return false
  end
  local index
  for i, member in ipairs(group.members) do
    if member.address == active.address then
      index = i
      break
    end
  end
  if not index then
    return false
  end
  if dir == "l" and index > 1 then
    hl.dispatch(hl.dsp.group.prev())
    return true
  elseif dir == "r" and index < #group.members then
    hl.dispatch(hl.dsp.group.next())
    return true
  end
  return false
end

local function focus_or_wrap(dir)
  return function()
    if group_step(dir) then
      return
    end
    if has_window_towards(dir) then
      hl.dispatch(hl.dsp.focus({ direction = dir }))
      return
    end
    local target = wrap_target(dir)
    if target then
      hl.dispatch(hl.dsp.focus({ window = "address:" .. target.address }))
    end
  end
end

-- One keyboard language. Super + H/J/K/L moves between windows and Super + Alt
-- + H/J/K/L moves a window into a group, as Super (+ Alt) + arrows do, so
-- nothing needs the 60% board's Fn layer. Focus stays on this screen, H/L wrap
-- around the row and walk a group's tabs first, so there is no separate tab
-- key (and no nav mode: these direct keys do everything it did).
-- Omarchy's Super + arrow binds stay (they still cross to the next monitor).
-- The descriptions are Omarchy's own, so the key list and the Quick Reference
-- guide show each pair on one line (Super + H / Super + Left).
local focus_word = { l = "left", r = "right", u = "above", d = "below" }
local group_word = { l = "left", r = "right", u = "top", d = "bottom" }
for _, d in ipairs(vim_directions) do
  local focus = (d.dir == "l" or d.dir == "r") and focus_or_wrap(d.dir)
    or within_workspace(d.dir, hl.dsp.focus({ direction = d.dir }))
  o.bind_expressions[focus] = string.format('hl.dsp.focus({ direction = "%s" })', d.dir)
  o.rebind("SUPER + " .. d.key, "Focus on " .. focus_word[d.dir] .. " window", focus)

  local into = within_workspace(d.dir, hl.dsp.window.move({ into_group = d.dir }))
  o.bind_expressions[into] = string.format('hl.dsp.window.move({ into_group = "%s" })', d.dir)
  o.rebind("SUPER + ALT + " .. d.key, "Move window to group on " .. group_word[d.dir], into)
end
_G.rahulj_keys.focus_or_wrap = focus_or_wrap
_G.rahulj_keys.group_step = group_step

-- The keys that sat on J/K/L move to keys that still say what they do.
o.bind("SUPER + Y", "Toggle window split", hl.dsp.layout("togglesplit")) -- was Super + J; Y is a fork
o.bind("SUPER + N", "Cycle workspace layout", "omarchy-hyprland-workspace-layout-toggle") -- was Super + L
o.bind("SUPER + ALT + N", "Cycle workspace layout back", "omarchy-hyprland-workspace-layout-toggle back") -- was Super + Alt + L
-- The key lists sit on / (the ? key), paired the way Enter opens them: Super
-- for the desktop, Super + Alt for tmux, Super + Ctrl for herdr.
o.rebind("SUPER + SLASH", "Keybindings", "omarchy-menu-keybindings") -- was monitor scaling up
o.rebind("SUPER + ALT + SLASH", "Tmux keybindings", "omarchy-menu-tmux-keybindings") -- was monitor scaling down
o.bind("SUPER + CTRL + SLASH", "Herdr keybindings", "omarchy-menu-herdr-keybindings")
hl.unbind("SUPER + CTRL + K")
o.bind("SUPER + CTRL + ALT + code:21", "Monitor scaling up", "omarchy-hyprland-monitor-scaling up")
o.bind("SUPER + CTRL + ALT + code:20", "Monitor scaling down", "omarchy-hyprland-monitor-scaling down")

-- Fn-free keys in place of Omarchy's on the 60% board's Fn layer (`, Home,
-- Delete). Omarchy's are removed, so the key list shows one key per action.
for _, old in ipairs({
  "SUPER + grave", "SUPER + SHIFT + grave", "SUPER + Home", "SUPER + ALT + Home",
  "CTRL + ALT + DELETE", "SUPER + CTRL + Delete", "SUPER + CTRL + ALT + Delete",
}) do
  hl.unbind(old)
end
o.bind("SUPER + D", "Toggle Quake console", hl.dsp.workspace.toggle_special("qconsole")) -- Super + `; D for drop-down
o.bind("SUPER + ALT + D", "Move window to Quake console", hl.dsp.window.move({ workspace = "special:qconsole", follow = false })) -- as Super + Alt + S for the scratchpad
o.bind("SUPER + R", "Restore window width", "omarchy-hyprland-window-width restore") -- Super + Home
o.bind("SUPER + ALT + R", "Save window width", "omarchy-hyprland-window-width save") -- Super + Alt + Home
o.bind("SUPER + CTRL + ALT + Q", "Close all windows", "omarchy-hyprland-window-close-all") -- Ctrl + Alt + Delete
o.bind("SUPER + CTRL + M", "Toggle laptop display", "omarchy-hyprland-monitor-internal toggle") -- Super + Ctrl + Delete
o.bind("SUPER + CTRL + ALT + M", "Toggle laptop display mirroring", "omarchy-hyprland-monitor-internal-mirror toggle") -- Super + Ctrl + Alt + Delete

-- Bar panels by name. Super + Ctrl opens the system panels (Audio, Network...);
-- Super + Ctrl + Alt peeks at the rest, as it shows battery, time and weather.
o.bind("SUPER + CTRL + U", "AI usage", { panel = "jim.aiusage" })
o.bind("SUPER + CTRL + G", "Quick reference guides", { panel = "jcmarin.qrg" })
o.bind("SUPER + CTRL + ALT + A", "Agents panel", { panel = "omarchy.agents" })
o.bind("SUPER + CTRL + ALT + S", "Agent skills", { panel = "oliwier.agent-skills-manager" })
o.bind("SUPER + CTRL + ALT + N", "Network speed", { panel = "rahulj.net-speed" })
o.bind("SUPER + CTRL + ALT + P", "Hyprpin panel", { panel = "io.github.jondkinney.hyprpin" })
o.bind("SUPER + CTRL + ALT + O", "Omapop panel", { panel = "io.github.jondkinney.omapop" })

-- App keys that opened an installer or an app not used here. A web app's
-- description is also the title it is focused by when already open.
o.rebind("SUPER + SHIFT + M", "YouTube Music", { webapp = "https://music.youtube.com/", focus = true }) -- was Spotify
o.rebind("SUPER + SHIFT + G", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true }) -- was Signal
o.rebind("SUPER + SHIFT + ALT + G", "Google Messages", { webapp = "https://messages.google.com/web/conversations", focus = true }) -- was WhatsApp
hl.unbind("SUPER + SHIFT + CTRL + G") -- Google Messages, now on Super + Shift + Alt + G
hl.unbind("SUPER + SHIFT + SLASH") -- 1Password, not installed
o.rebind("SUPER + SHIFT + E", "Gmail", { webapp = "https://mail.google.com/", focus = true }) -- was HEY
o.rebind("SUPER + SHIFT + ALT + E", "Outlook", { webapp = "https://outlook.office.com/mail/", focus = true }) -- was HEY new email
hl.unbind("SUPER + CTRL + SPACE") -- same as Super + Ctrl + W (Background switcher)
hl.unbind("SUPER + SHIFT + CTRL + SPACE") -- same as Super + Ctrl + T (Theme menu)

-- Tasks: Taskwarrior's terminal UI (the to-do list). T names it, so the system
-- task manager (btop, "Activity") moves to the Alt version of the same key.
o.rebind("SUPER + SHIFT + T", "Tasks", { tui = "taskwarrior-tui", focus = true }) -- was Activity
o.bind("SUPER + SHIFT + ALT + T", "Activity", { tui = "btop" })

-- Ctrl + H/J/K/L in Omarchy's menus and pickers. Their search box types plain
-- letters, so, as in fzf and Neovim's pickers, Ctrl + J/K move down/up and
-- Ctrl + H/L go back/open (left/right in a grid). While one of these layers is
-- open the key reaches it as the arrow key, with no modifiers (sent the way
-- jis.lua sends its keys); otherwise it goes to the app as usual
-- (auto_consuming passes it on), so Ctrl + H/J/K/L in a terminal or Neovim are
-- untouched.
local MENU_LAYERS = {
  "omarchy-menu", "omarchy-clipboard", "omarchy-emojis", "omarchy-dock-apps",
  "omarchy-image-selector", "timsonner-nitty-griddy", "omarchy-keyboard-panel", "omarchy-reminders",
}
local function menu_open()
  for _, namespace in ipairs(MENU_LAYERS) do
    local layers = hl.get_layers({ namespace = namespace })
    if layers and #layers > 0 then
      return true
    end
  end
  return false
end
local function menu_arrow(arrow)
  return function()
    if not menu_open() then
      return { ok = false }
    end
    hl.dispatch(hl.dsp.send_key_state({ mods = "", key = arrow, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = "", key = arrow, state = "up" }))
    end, { timeout = 30, type = "oneshot" })
  end
end
_G.rahulj_keys.menu_open = menu_open
_G.rahulj_keys.menu_arrow = {}
for _, m in ipairs({ { "H", "Left", "back or left" }, { "J", "Down", "down" }, { "K", "Up", "up" }, { "L", "Right", "open or right" } }) do
  local press = menu_arrow(m[2])
  _G.rahulj_keys.menu_arrow[m[1]] = press
  o.bind("CTRL + " .. m[1], "Menus: " .. m[3], press, { auto_consuming = true })
end

-- Super + - / Super + = on a scrolling workspace: Omarchy's 100px resize
-- barely moves a scrolling column, and a column holding one window cannot
-- change height at all, so there the keys step the column width instead
-- (Alt for a small step, Ctrl for a big one). Hyprland keeps a column between
-- a sliver and the full screen. Floating windows and other layouts keep
-- Omarchy's pixel resize.
--
-- Only the focused column changes width; every other column keeps its width
-- and slides aside, as Hyprland's own mouse resize does. A wider column pushes
-- its neighbours off screen, and a narrower one leaves them where the row puts
-- them. (Taking the width from the neighbour instead, as these keys once did,
-- squeezed a window that was never touched.) No column shrinks below
-- MIN_SHARE of the screen, and Hyprland stops one at the full screen.
--
-- Hyprland sizes a column from its left edge, so a column on the right of the
-- screen shrank away from the screen edge and left bare wallpaper there. The
-- keys move the edge that faces the rest of the layout, by the column's place
-- on screen: a right-hand column (one with a neighbour on screen to its left
-- only, or nearer the right edge, or a full-width one with columns only to its
-- left) scrolls the view by the change, so its right edge stays put; any
-- other column keeps its left edge. If that would leave bare wallpaper at one
-- screen edge while columns hide past the other, the view scrolls them in to
-- fill it. Layout messages go to the focused monitor's workspace, so nothing
-- happens when that is not the window's own.
local MIN_SHARE = 0.15
local EDGE_SLACK = 40
-- A neighbour counts as on screen only when it is wholly on it; a few pixels
-- cover rounding. Moving the edge with one hanging off the screen kept it
-- clipped there.
local ON_SCREEN_SLACK = 4

local function on_scrolling_column(window)
  return window ~= nil and not window.floating and (window.fullscreen or 0) == 0
    and window.workspace ~= nil and window.workspace.tiled_layout == "scrolling"
end

local function xy(v)
  if type(v) ~= "table" then
    return 0, 0
  end
  return v.x or v[1] or 0, v.y or v[2] or 0
end

local function screen_span(monitor)
  local w, h = monitor.width or 0, monitor.height or 0
  if (monitor.transform or 0) % 2 == 1 then
    w = h
  end
  return monitor.x or 0, w / (monitor.scale or 1)
end

-- Where the column sits and what is beside it: the nearest column on each side
-- (and whether it is fully on screen), and which edge it should work.
local function column_place(window)
  local monitor = window.monitor
  if not monitor or not monitor.width then
    return nil
  end
  local mx, mw = screen_span(monitor)
  local x, w = xy(window.at), xy(window.size)

  local left, right, any_left, any_right
  -- The extent of the whole row of columns, off-screen ones included.
  local row_left, row_right = x, x + w
  for _, other in ipairs(window.workspace:get_windows() or {}) do
    if other.address ~= window.address and not other.floating and other.mapped and not other.hidden then
      local ox, ow = xy(other.at), xy(other.size)
      row_left, row_right = math.min(row_left, ox), math.max(row_right, ox + ow)
      local on_screen = ox >= mx - ON_SCREEN_SLACK and ox + ow <= mx + mw + ON_SCREEN_SLACK
      -- Windows stacked in this column share its x and count as neither side.
      if ox + ow <= x + EDGE_SLACK then
        any_left = true
        if on_screen and (not left or ox > xy(left.at)) then left = other end
      elseif ox >= x + w - EDGE_SLACK then
        any_right = true
        if on_screen and (not right or ox < xy(right.at)) then right = other end
      end
    end
  end

  -- Which side works is settled by what is on screen, not by position, so a
  -- press and its opposite always undo each other: with a neighbour on screen
  -- on one side only, that side; on both sides, the right. Only a column with
  -- neither falls back on its place on screen.
  local right_hand
  if left and not right then
    right_hand = true
  elseif right then
    right_hand = false
  else
    local left_gap, right_gap = x - mx, (mx + mw) - (x + w)
    if math.abs(left_gap - right_gap) > EDGE_SLACK then
      right_hand = right_gap < left_gap
    else
      right_hand = any_left and not any_right
    end
  end

  return {
    screen = mw,
    screen_left = mx,
    width = w,
    right_edge = x + w,
    row_left = row_left,
    row_right = row_right,
    right_hand = right_hand,
  }
end

local function colresize(share)
  hl.dispatch(hl.dsp.layout(string.format("colresize %+.4f", share)))
end

-- The pixel change this press makes, kept so the column stays at least
-- MIN_SHARE of the screen. Hyprland stops a column at the full screen itself.
local function resize_column(window, step)
  -- Layout messages go to the focused monitor's workspace, which is not always
  -- the focused window's; then nothing is resized rather than the wrong column.
  local workspace = hl.get_active_workspace()
  if not workspace or workspace.id ~= window.workspace.id then
    return
  end

  local place = column_place(window)
  if not place then
    colresize(step)
    return
  end

  -- A column never shrinks below MIN_SHARE of the screen.
  local min_width = MIN_SHARE * place.screen
  local px = step * place.screen
  if px < 0 then
    px = math.max(px, min_width - place.width)
  end
  if math.abs(px) < 1 then
    return
  end
  local share = px / place.screen

  colresize(share)
  local now = hl.get_active_window()
  if not now or now.address ~= window.address then
    return
  end

  -- Where the row lands. The column keeps its place in the row and grows or
  -- shrinks to the right, so it and the columns right of it move by the change
  -- and the rest stay; Hyprland may also have scrolled the view to keep it on
  -- screen, which its new left edge shows. A right-hand column then scrolls
  -- back to where its right edge was.
  local x, w = xy(now.at), xy(now.size)
  local delta = w - place.width
  local scrolled = x - (place.right_edge - place.width)
  local offset = place.right_hand and (place.right_edge - (x + w)) or 0
  local row_left = place.row_left + scrolled + offset
  local row_right = place.row_right + delta + scrolled + offset

  -- Never leave bare wallpaper at one screen edge while columns hide past the
  -- other: scroll them in to fill it. Windows sit inside the outer gap and
  -- their border.
  local gaps = hl.get_config("general.gaps_out")
  local gap_left, gap_right = 0, 0
  if type(gaps) == "table" then
    gap_left, gap_right = gaps.left or 0, gaps.right or 0
  elseif type(gaps) == "number" then
    gap_left, gap_right = gaps, gaps
  end
  local border = tonumber(hl.get_config("general.border_size")) or 0
  local fill_left = place.screen_left + gap_left + border
  local fill_right = place.screen_left + place.screen - gap_right - border
  if row_right < fill_right - 8 and row_left < fill_left - 8 then
    offset = offset + math.min(fill_right - row_right, fill_left - row_left)
  elseif row_left > fill_left + 8 and row_right > fill_right + 8 then
    offset = offset - math.min(row_left - fill_left, row_right - fill_right)
  end

  offset = math.floor(offset + 0.5)
  if offset ~= 0 then
    hl.dispatch(hl.dsp.layout(string.format("move %+d", offset)))
    -- Hyprland's "move" also focuses whichever column ends up in the middle
    -- of the screen, often the neighbour, and the next press then resized
    -- that one. Focus goes straight back, with pointer warps off so the
    -- pointer stays where it is.
    local after = hl.get_active_window()
    if not after or after.address ~= window.address then
      local no_warps = hl.get_config("cursor.no_warps")
      hl.config({ cursor = { no_warps = true } })
      hl.dispatch(hl.dsp.focus({ window = "address:" .. window.address }))
      hl.config({ cursor = { no_warps = no_warps == true } })
    end
  end
end

local function resize_width(step, px)
  return function()
    local window = hl.get_active_window()
    if on_scrolling_column(window) then
      resize_column(window, step)
    else
      hl.dispatch(hl.dsp.window.resize({ x = px, y = 0, relative = true }))
    end
  end
end

-- e.g. hyprctl eval 'rahulj_keys.resize_width(-0.1, -100)()'
_G.rahulj_keys.resize_width = resize_width

for _, r in ipairs({
  { mods = "SUPER", hmods = "SUPER + SHIFT", name = "", step = 0.1, px = 100 },
  { mods = "SUPER + ALT", hmods = "SUPER + SHIFT + ALT", name = " a little", step = 0.05, px = 25 },
  { mods = "SUPER + CTRL", hmods = "SUPER + CTRL + SHIFT", name = " a lot", step = 0.25, px = 300 },
}) do
  local narrower, wider = resize_width(-r.step, -r.px), resize_width(r.step, r.px)
  o.bind_commands[narrower] = string.format("hl.dsp.window.resize({ x = %d, y = 0, relative = true })", -r.px)
  o.bind_commands[wider] = string.format("hl.dsp.window.resize({ x = %d, y = 0, relative = true })", r.px)
  o.rebind(r.mods .. " + code:20", "Decrease window width" .. r.name, narrower)
  o.rebind(r.mods .. " + code:21", "Increase window width" .. r.name, wider)
  -- Height keeps Omarchy's resize and its modifier order (the key list matches
  -- it as text); only the label said "Shrink window up".
  o.rebind(r.hmods .. " + code:20", "Decrease window height" .. r.name, hl.dsp.window.resize({ x = 0, y = -r.px, relative = true }))
  o.rebind(r.hmods .. " + code:21", "Increase window height" .. r.name, hl.dsp.window.resize({ x = 0, y = r.px, relative = true }))
end

-- Volume on the bracket keys: this 60% keyboard has no media keys, and keys
-- behind Fn clash with its Fn + Super Win-key lock. Same commands as Omarchy's
-- media keys, so the volume popup still shows.
o.bind("SUPER + BRACKETRIGHT", "Volume up", { audio = "raise" }, { locked = true, repeating = true })
o.bind("SUPER + BRACKETLEFT", "Volume down", { audio = "lower" }, { locked = true, repeating = true })
o.bind("SUPER + BACKSLASH", "Mute", { audio = "mute-toggle" }, { locked = true })
o.bind("SUPER + SHIFT + BRACKETRIGHT", "Volume up precise", "omarchy-audio-output-volume +1", { locked = true, repeating = true })
o.bind("SUPER + SHIFT + BRACKETLEFT", "Volume down precise", "omarchy-audio-output-volume -1", { locked = true, repeating = true })

-- Screen brightness on the same bracket keys with Ctrl (Alt is taken by the
-- webcam overlay). Same commands as Omarchy's brightness keys, so the popup shows.
o.bind("SUPER + CTRL + BRACKETRIGHT", "Brightness up", { brightness = "raise" }, { locked = true, repeating = true })
o.bind("SUPER + CTRL + BRACKETLEFT", "Brightness down", { brightness = "lower" }, { locked = true, repeating = true })
o.bind("SUPER + CTRL + SHIFT + BRACKETRIGHT", "Brightness up precise", "omarchy-brightness-display +1%", { locked = true, repeating = true })
o.bind("SUPER + CTRL + SHIFT + BRACKETLEFT", "Brightness down precise", "omarchy-brightness-display 1%-", { locked = true, repeating = true })

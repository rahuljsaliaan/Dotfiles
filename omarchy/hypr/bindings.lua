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

local function toggle_floating()
  local window = hl.get_active_window()
  hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
  user_tiled.remember(window)
end

-- Reachable from `hyprctl eval`, so both can be run without the keys.
_G.rahulj_keys = { pop_out = pop_out, toggle_floating = toggle_floating }

hl.unbind("SUPER + O")
o.bind("SUPER + O", "Pop window out (Hyprpin or float & pin)", hyprpin_or("toggle_pop", pop_out))
hl.unbind("SUPER + T")
o.bind("SUPER + T", "Toggle window floating/tiling (Hyprpin dock)", hyprpin_or("toggle_dock", toggle_floating))
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

-- Navigation mode: Super + ; turns it on, then plain H/J/K/L focus windows,
-- Shift + H/J/K/L move the window into a group and Ctrl + H/L move focus
-- inside a group. It stays on until Esc or Super + ; again.
o.bind("SUPER + SEMICOLON", "Nav mode: turn on (H/J/K/L focus; Esc leaves)", hl.dsp.submap("nav"))

-- Nav mode stays on the current workspace: Hyprland's directional focus
-- falls through to the next monitor when nothing is left in that direction,
-- so only dispatch when this workspace has a window on that side.
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

hl.define_submap("nav", function()
  for _, d in ipairs(vim_directions) do
    o.bind(d.key, "Nav mode: Focus " .. d.name .. " window", within_workspace(d.dir, hl.dsp.focus({ direction = d.dir })))
    o.bind("SHIFT + " .. d.key, "Nav mode: Move window to group " .. d.name, within_workspace(d.dir, hl.dsp.window.move({ into_group = d.dir })))
  end
  o.bind("CTRL + H", "Nav mode: Grouped window focus left", hl.dsp.group.prev())
  o.bind("CTRL + L", "Nav mode: Grouped window focus right", hl.dsp.group.next())
  o.bind("ESCAPE", "Nav mode: leave", hl.dsp.submap("reset"))
  o.bind("SUPER + SEMICOLON", "Nav mode: leave", hl.dsp.submap("reset"))
end)

-- Nav mode shows a notification card for as long as it is on, since nothing
-- else on screen says a submap is active. The card is the usual notification
-- card (rahulj.notifications), kept up by its x-rahulj-resident hint and kept
-- out of history as transient. It follows Hyprland's submap event rather than
-- the keys, so it goes however the mode ends.
local NAV_CARD = "Navigation mode"
local NAV_GLYPH = "\u{f0041}" -- nf-md-arrow_all
hl.on("keybinds.submap", function(name)
  if name == "nav" then
    hl.exec_cmd("notify-send -a Hyprland -u normal"
      .. " -h boolean:transient:true -h boolean:x-rahulj-resident:true"
      .. " -h string:omarchy-glyph:" .. NAV_GLYPH
      .. " '" .. NAV_CARD .. "' 'HJKL focus · Shift+HJKL group · Ctrl+H/L tab · Esc exits'")
  else
    hl.exec_cmd("omarchy-notification-dismiss '" .. NAV_CARD .. "'")
  end
end)

-- Super + - / Super + = on a scrolling workspace: Omarchy's 100px resize
-- barely moves a scrolling column, and a column holding one window cannot
-- change height at all, so there the keys step the column width instead
-- (Alt for a small step, Ctrl for a big one). Hyprland keeps a column between
-- a sliver and the full screen. Floating windows and other layouts keep
-- Omarchy's pixel resize.
--
-- Hyprland sizes a column from its left edge, so a column on the right of the
-- screen shrank away from the screen edge and left bare wallpaper there. The
-- keys now move the edge that faces the rest of the layout, by the column's
-- place on screen:
--
-- * With a neighbour fully on screen on that side, the edge between them moves,
--   as a split does: the column takes width from the neighbour or gives it
--   back, so the pair keeps its width. Resizing one alone would leave a pair
--   narrower than the screen, which Hyprland centres. The neighbour gives way
--   down to MIN_SHARE of the screen; past that the column grows alone and
--   pushes it off screen, so any column can still reach the full screen.
--   No column shrinks below MIN_SHARE.
-- * With no such neighbour the column resizes alone. A right-hand column (one
--   nearer the right edge, or a full-width one with columns only to its left)
--   then scrolls the view by the change, so its right edge stays put and the
--   column to its left comes into view. If that would leave bare wallpaper at
--   one screen edge while columns hide past the other, the view scrolls them
--   in to fill it.
--
-- The rightmost column on screen works its left edge, every other one its
-- right edge. Hyprland's colresize acts on the focused column only, so the
-- neighbour is focused for its half, with cursor warps off so the pointer stays
-- where it is, and focus goes straight back. Layout messages go to the focused
-- monitor's workspace, so nothing happens when that is not the window's own.
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
    neighbour = right_hand and left or right,
  }
end

local function colresize(share)
  hl.dispatch(hl.dsp.layout(string.format("colresize %+.4f", share)))
end

-- The pixel change this press makes, kept so the column (and a neighbour that
-- gives way) stay at least MIN_SHARE of the screen. Hyprland stops a column at
-- the full screen itself.
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

  -- The neighbour gives way only while it stays at least MIN_SHARE wide. Past
  -- that the column grows on its own and pushes the neighbour off screen, so
  -- it can still reach the full screen; shrinking back brings the neighbour
  -- into view again, and once it is fully on screen the edge between them
  -- moves again.
  local neighbour = place.neighbour
  if neighbour and px > 0 and xy(neighbour.size) - px < min_width then
    neighbour = nil
  end

  if neighbour then
    local no_warps = hl.get_config("cursor.no_warps")
    hl.config({ cursor = { no_warps = true } })
    colresize(share)
    hl.dispatch(hl.dsp.focus({ window = "address:" .. neighbour.address }))
    colresize(-share)
    hl.dispatch(hl.dsp.focus({ window = "address:" .. window.address }))
    hl.config({ cursor = { no_warps = no_warps == true } })
    return
  end

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
  { mods = "SUPER", name = "", step = 0.1, px = 100 },
  { mods = "SUPER + ALT", name = " a little", step = 0.05, px = 25 },
  { mods = "SUPER + CTRL", name = " a lot", step = 0.25, px = 300 },
}) do
  local narrower, wider = resize_width(-r.step, -r.px), resize_width(r.step, r.px)
  o.bind_commands[narrower] = string.format("hl.dsp.window.resize({ x = %d, y = 0, relative = true })", -r.px)
  o.bind_commands[wider] = string.format("hl.dsp.window.resize({ x = %d, y = 0, relative = true })", r.px)
  o.rebind(r.mods .. " + code:20", "Narrower window" .. r.name .. " (scrolling: column width)", narrower)
  o.rebind(r.mods .. " + code:21", "Wider window" .. r.name .. " (scrolling: column width)", wider)
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

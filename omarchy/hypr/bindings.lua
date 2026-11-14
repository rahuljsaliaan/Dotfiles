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
-- code; crash reports in ~/.cache/hyprland). So: floating is set explicitly,
-- never toggled blind, and nothing is tiled on a floating-layout workspace.
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

-- Super+T: float or tile the window, except that a floating window on a
-- floating-layout workspace stays floating (Super+L changes the layout).
local function toggle_floating()
  local window = hl.get_active_window()
  if not window then return end
  if window.floating and has_tag(window, FLOATING_WORKSPACE) then
    hl.exec_cmd('omarchy-notification-send -u low "Floating layout" "Windows float on this workspace. Super + L switches it to tiling."')
    return
  end
  hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
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

-- Volume on the bracket keys: this 60% keyboard has no media keys, and keys
-- behind Fn clash with its Fn + Super Win-key lock. Same commands as Omarchy's
-- media keys, so the volume popup still shows.
o.bind("SUPER + BRACKETRIGHT", "Volume up", { audio = "raise" }, { locked = true, repeating = true })
o.bind("SUPER + BRACKETLEFT", "Volume down", { audio = "lower" }, { locked = true, repeating = true })
o.bind("SUPER + BACKSLASH", "Mute", { audio = "mute-toggle" }, { locked = true })
o.bind("SUPER + SHIFT + BRACKETRIGHT", "Volume up precise", "omarchy-audio-output-volume +1", { locked = true, repeating = true })
o.bind("SUPER + SHIFT + BRACKETLEFT", "Volume down precise", "omarchy-audio-output-volume -1", { locked = true, repeating = true })

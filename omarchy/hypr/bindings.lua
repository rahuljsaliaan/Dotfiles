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

hl.define_submap("nav", function()
  for _, d in ipairs(vim_directions) do
    o.bind(d.key, "Nav mode: Focus " .. d.name .. " window", hl.dsp.focus({ direction = d.dir }))
    o.bind("SHIFT + " .. d.key, "Nav mode: Move window to group " .. d.name, hl.dsp.window.move({ into_group = d.dir }))
  end
  o.bind("CTRL + H", "Nav mode: Grouped window focus left", hl.dsp.group.prev())
  o.bind("CTRL + L", "Nav mode: Grouped window focus right", hl.dsp.group.next())
  o.bind("ESCAPE", "Nav mode: leave", hl.dsp.submap("reset"))
  o.bind("SUPER + SEMICOLON", "Nav mode: leave", hl.dsp.submap("reset"))
end)

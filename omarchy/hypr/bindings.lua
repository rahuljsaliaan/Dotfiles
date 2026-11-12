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

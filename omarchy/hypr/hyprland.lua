-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- Round Linux-style title-bar buttons (colours, symbols, order in hypr/looknfeel.lua):
-- top-right, faint at rest, full colour + symbols on hover, same on unfocused
-- windows. button_rest_opacity needs the personal plugin build (looknfeel.lua).
-- (inactive_button_color 0 = no override, so buttons keep their own colour).
-- Must come after default.hypr.toggles, which applies Omarchy's titlebar settings.
if hl.plugin and hl.plugin.hyprbars then
  hl.config({
    plugin = {
      hyprbars = {
        icon_on_hover = true,
        button_rounding = -1,
        bar_buttons_alignment = "right",
        bar_button_padding = 6,
        button_rest_opacity = 30,
        inactive_button_color = "rgba(00000000)",
      },
    },
  })
end

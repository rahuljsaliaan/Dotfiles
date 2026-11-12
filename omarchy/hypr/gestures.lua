-- Touchpad gestures. Loaded from hypr/hyprland.lua after Omarchy's defaults.
-- Stock Omarchy registers no three-finger gestures, so nothing is replaced.

-- Window overview (NittyGriddy plugin): three fingers up opens the grid of
-- windows on the focused screen, three fingers down closes it. The plugin's
-- left/right swipes (workspace switching) are left out on purpose.
hl.gesture({
  fingers = 3,
  direction = "up",
  action = function()
    hl.dispatch(hl.dsp.event("timsonner.nitty-griddy:open"))
  end,
})

hl.gesture({
  fingers = 3,
  direction = "down",
  action = function()
    hl.dispatch(hl.dsp.event("timsonner.nitty-griddy:close"))
  end,
})

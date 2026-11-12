-- Touchpad gestures. Loaded from hypr/hyprland.lua after Omarchy's defaults.
-- Stock Omarchy registers no three-finger gestures, so nothing is replaced.

-- Window overview (NittyGriddy plugin): three fingers up opens the grid of
-- windows on the focused screen, three fingers down closes it. Left/right
-- page the overview's workspace strip while it is open, and otherwise switch
-- to the previous/next workspace on this monitor, the same as Super+Tab.

local function overview_open()
  local layers = hl.get_layers({ namespace = "timsonner-nitty-griddy" })
  return layers ~= nil and #layers > 0
end
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

hl.gesture({
  fingers = 3,
  direction = "left",
  action = function()
    if overview_open() then
      hl.dispatch(hl.dsp.event("timsonner.nitty-griddy:workspace-prev"))
      return
    end
    hl.dispatch(hl.dsp.focus({ workspace = "m-1" }))
  end,
})

hl.gesture({
  fingers = 3,
  direction = "right",
  action = function()
    if overview_open() then
      hl.dispatch(hl.dsp.event("timsonner.nitty-griddy:workspace-next"))
      return
    end
    hl.dispatch(hl.dsp.focus({ workspace = "m+1" }))
  end,
})

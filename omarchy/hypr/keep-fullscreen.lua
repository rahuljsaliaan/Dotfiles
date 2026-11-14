-- Keep fullscreen through a monitor dropping out.
--
-- The middle BenQ (HDMI-A-1) drops off HDMI a few seconds after it goes to
-- sleep and comes back on its own. Each time, Hyprland moves its workspaces to
-- another screen and, on the way, takes every window out of fullscreen and
-- maximized. Omarchy's monitor-workspaces brings the workspaces back when the
-- screen returns, but the fullscreen state stays lost.
--
-- Hyprland clears the state while it moves the windows, so it can't be read
-- from the change events. Instead, which windows are fullscreen or maximized
-- is noted every two seconds; the note is frozen the moment a monitor goes,
-- and put back once it has returned and its workspaces are home again.

local watched = {}   -- address -> "fullscreen" | "maximized"
local frozen = false

local function snapshot()
  if frozen then return end
  local now = {}
  for _, w in ipairs(hl.get_windows() or {}) do
    if w.address and w.fullscreen == 2 then
      now[w.address] = "fullscreen"
    elseif w.address and w.fullscreen == 1 then
      now[w.address] = "maximized"
    end
  end
  watched = now
end

local function restore()
  local current = {}
  for _, w in ipairs(hl.get_windows() or {}) do
    if w.address then current[w.address] = w.fullscreen or 0 end
  end
  for address, mode in pairs(watched) do
    local state = current[address]
    -- Still open, and no longer in the state it was in.
    if state ~= nil and state ~= (mode == "fullscreen" and 2 or 1) then
      hl.dispatch(hl.dsp.window.fullscreen({ mode = mode, action = "set", window = "address:" .. address }))
    end
  end
  frozen = false
  snapshot()
end

hl.timer(snapshot, { type = "repeat", timeout = 2000 })

hl.on("monitor.removed", function()
  frozen = true
end)

-- Omarchy reconciles the workspaces on monitor.added; restore after it.
hl.on("monitor.added", function()
  hl.timer(restore, { type = "oneshot", timeout = 1500 })
end)

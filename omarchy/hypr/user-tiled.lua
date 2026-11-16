-- Keep a window tiled when SUPER + T tiled it on a floating workspace.
--
-- On a workspace in floating mode, Omarchy's workspace-modes floats every tiled
-- window again whenever it re-applies the mode: after a window leaves
-- fullscreen, after one is carried to another workspace, and when the config
-- reloads. That undoes SUPER + T. The mode's own functions are local to its
-- file, so this module does not change them. It remembers the windows you tiled
-- by hand and, a moment after the mode has run, tiles back only the ones the
-- mode floated (they carry its "claimed" tag). A window you floated yourself,
-- a pinned one, and a fullscreen one are never touched.
--
-- The memory lasts for the session: a window tiled this way is a new window
-- after a logout, and floats like any other.

local TAG = "rahulj-user-tiled"
local CLAIMED = "omarchy-mode-floated"
-- Long enough to run after Omarchy's own one-tick timers, short of a frame.
local AFTER = 20

local M = {}

local function has_tag(window, name)
  for _, tag in ipairs(window.tags or {}) do
    if (tag:gsub("%*$", "")) == name then return true end
  end
  return false
end

local function set_tag(window, tag)
  hl.dispatch(hl.dsp.window.tag({ tag = tag, window = window }))
end

local function fresh(address)
  local window = hl.get_window("address:" .. address)
  if window and window.mapped then return window end
  return nil
end

-- Called by SUPER + T after the toggle: tiled by hand is remembered, floated
-- by hand is forgotten.
function M.remember(window)
  if not window then return end
  local current = fresh(window.address)
  if not current then return end
  set_tag(current, (current.floating and "-" or "+") .. TAG)
end

-- Tile back one window the mode floated against the user's choice.
local function undo(window)
  if not window.floating then return end
  if (window.fullscreen or 0) ~= 0 or window.pinned then return end
  if not has_tag(window, TAG) or not has_tag(window, CLAIMED) then return end
  set_tag(window, "-" .. CLAIMED)
  hl.dispatch(hl.dsp.window.float({ action = "off", window = window }))
end

local function sweep()
  for _, window in ipairs(hl.get_windows({ tag = TAG }) or {}) do
    local current = fresh(window.address)
    if current then undo(current) end
  end
end

local function later()
  hl.timer(sweep, { type = "oneshot", timeout = AFTER })
end

hl.on("window.fullscreen", later)
hl.on("window.move_to_workspace", later)
hl.on("workspace.active", later)
hl.on("config.reloaded", later)

return M

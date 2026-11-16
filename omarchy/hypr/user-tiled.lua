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
-- Across a logout the choice is kept as "this app stays tiled on this
-- workspace", saved in a small file. Last Session reopens the app on that
-- workspace, and for the first minutes of the session a window of that app that
-- appears there is tiled the same way. Later windows are left to the mode, and
-- SUPER + T on a window of that app floats it again and drops the entry. If you
-- tiled one of two windows of an app on the same workspace, both come back
-- tiled: the entry names the app and workspace, not the window.
--
-- Tests can point RAHULJ_USER_TILED_FILE and RAHULJ_USER_TILED_RESTORE_SECONDS
-- elsewhere.

local TAG = "rahulj-user-tiled"
local CLAIMED = "omarchy-mode-floated"
local FLOATING_WORKSPACE = "omarchy-floating-workspace"
-- Long enough to run after Omarchy's own one-tick timers, short of a frame.
local AFTER = 20

local HOME = os.getenv("HOME") or ""
local STATE = os.getenv("RAHULJ_USER_TILED_FILE") or (HOME .. "/.local/state/rahulj-user-tiled.txt")
-- Last Session restores within about half a minute of the shell starting; slow
-- apps take longer.
local RESTORE_SECONDS = tonumber(os.getenv("RAHULJ_USER_TILED_RESTORE_SECONDS")) or 180

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

-- ---------------------------------------------------------------- the file
-- One "class<TAB>workspace" line per app that stays tiled on a workspace.

local function entry_for(window, workspace_override)
  local workspace = workspace_override or (window.workspace and window.workspace.id)
  local class = window.class
  if not workspace or not class or class == "" then return nil end
  return class .. "\t" .. tostring(workspace)
end

local function read_entries()
  local entries = {}
  local file = io.open(STATE, "r")
  if not file then return entries end
  for line in file:lines() do
    if line ~= "" then entries[line] = true end
  end
  file:close()
  return entries
end

local function write_entries(entries)
  local lines = {}
  for line in pairs(entries) do lines[#lines + 1] = line end
  table.sort(lines)
  local temp = STATE .. ".tmp"
  local file = io.open(temp, "w")
  if not file then return end
  for _, line in ipairs(lines) do file:write(line, "\n") end
  file:close()
  os.rename(temp, STATE)
end

-- Seconds since Hyprland started, from the kernel's process start time. A
-- config reload keeps the process, so it does not restart the clock.
local function session_age()
  local uptime_file = io.open("/proc/uptime", "r")
  local stat_file = io.open("/proc/self/stat", "r")
  if not uptime_file or not stat_file then
    if uptime_file then uptime_file:close() end
    if stat_file then stat_file:close() end
    return math.huge
  end
  local uptime = tonumber((uptime_file:read("*l") or ""):match("^(%S+)"))
  local stat = stat_file:read("*l") or ""
  uptime_file:close()
  stat_file:close()
  -- Field 22 is the start time; the command name before it may hold spaces, so
  -- count from the closing parenthesis (the first field after it is field 3).
  local rest = stat:match("%)%s(.*)$") or ""
  local index, started = 0, nil
  for field in rest:gmatch("%S+") do
    index = index + 1
    if index == 20 then started = tonumber(field) break end
  end
  if not uptime or not started then return math.huge end
  return uptime - started / 100
end

-- ------------------------------------------------------------ the behaviour

-- Called by SUPER + T after the toggle: tiled by hand is remembered, floated
-- by hand is forgotten.
function M.remember(window)
  if not window then return end
  local current = fresh(window.address)
  if not current then return end
  set_tag(current, (current.floating and "-" or "+") .. TAG)

  local entry = entry_for(current)
  if not entry then return end
  local entries = read_entries()
  if current.floating then
    if not entries[entry] then return end
    entries[entry] = nil
  elseif has_tag(current, FLOATING_WORKSPACE) then
    if entries[entry] then return end
    entries[entry] = true
  else
    return
  end
  write_entries(entries)
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

-- A window that appears on a workspace where its app was tiled, in the first
-- minutes after login, is one Last Session brought back: remember it as tiled.
local function adopt(window, workspace)
  if not window or not window.address then return end
  if has_tag(window, TAG) then return end
  if session_age() > RESTORE_SECONDS then return end
  -- A move is still being committed when its event fires, so the workspace the
  -- window is going to comes with the event.
  local entry = entry_for(window, workspace and workspace.id)
  if not entry or not read_entries()[entry] then return end
  set_tag(window, "+" .. TAG)
end

hl.on("window.open", function(window)
  adopt(window)
  later()
end)
hl.on("window.move_to_workspace", function(window, workspace)
  adopt(window, workspace)
  later()
end)
hl.on("window.fullscreen", later)
hl.on("workspace.active", later)
hl.on("config.reloaded", later)

return M

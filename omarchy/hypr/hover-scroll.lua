-- Scrolling workspaces: pointing at a half-hidden column focuses it but does
-- not slide the row over to it. Clicking it, or moving to it with the keys,
-- still brings it into view.
--
-- Two things slid the row on hover:
--
-- 1. Hyprland's follow_min_visible. A column the pointer focuses is scrolled
--    into view when at least that share of the screen of it already shows
--    (0.4 by default), so a wide column showing beside the one in use took the
--    screen as soon as the pointer crossed it. At 1 hovering never scrolls.
--
-- 2. Omarchy's drop-down console (default/hypr/qconsole.lua) refits itself to
--    every screen the pointer moves onto, even while it is hidden. A refit
--    rewrites the console's workspace rule and refreshes every layout, and
--    Hyprland takes that refresh as a cue to bring the focused column fully
--    into view. Crossing to another screen fires the refit before focus leaves
--    the column the pointer last passed over, so that column slid over the
--    window in use, on the way out or on the way back. While the console is
--    hidden its new size is now held back, and applied as it next opens.

hl.config({ scrolling = { follow_min_visible = 1 } })

local CONSOLE = "special:qconsole"

-- A reload starts Lua afresh, so these are always Hyprland's own functions.
local write_rule = hl.workspace_rule
local refresh_now = hl.exec_scheduled_prop_refresh_immediately

local held = nil
local skip_refresh = false

local function console_shown()
  local workspace = hl.get_workspace(CONSOLE)
  return workspace ~= nil and workspace.visible == true
end

local function console_rule(spec)
  return type(spec) == "table" and spec.workspace == CONSOLE
end

hl.workspace_rule = function(spec, ...)
  if console_rule(spec) then
    if not console_shown() then
      held = table.pack(spec, ...)
      skip_refresh = true
      return
    end
    held = nil
  end
  return write_rule(spec, ...)
end

-- Omarchy refreshes right after writing the console's rule; with the rule held
-- back there is nothing to refresh for.
hl.exec_scheduled_prop_refresh_immediately = function(...)
  if skip_refresh then
    skip_refresh = false
    return
  end
  return refresh_now(...)
end

-- Omarchy refits the console as it opens, but skips writing a size it already
-- wrote (or tried to), which may be the one held back here. This runs after
-- Omarchy's handler, so the console opens at the size it was fitted to.
hl.on("workspace.special_active", function(workspace)
  if held and workspace and workspace.name == CONSOLE and console_shown() then
    local rule = held
    held = nil
    skip_refresh = false
    write_rule(table.unpack(rule, 1, rule.n))
    refresh_now()
  end
end)

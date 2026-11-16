-- Popups that stay in front.
--
-- Hyprland draws every floating window above every tiled one, whatever has
-- focus. A window that opens tiled underneath a floating one is hidden behind
-- it, and focusing it does not bring it forward.

-- File pickers. Apps that use the portal get their Open/Save dialogs from
-- Files (Nautilus). Omarchy floats those only when the app titles the dialog
-- Open…, Save… or Choose…; Obsidian's folder picker is titled "Location", so on
-- a tiled or scrolling workspace it opened tiled, behind Obsidian's floating
-- vault window. A picker is titled before it opens, with the title the app
-- asked for; Files' own windows open untitled and only then become "Loading…"
-- (a folder already loaded, Recent and Trash too). So a Files window that
-- opens with any other title is a dialog: it floats, centred, at the size
-- Omarchy gives dialogs. ("Loading…" is the English text; under another
-- language it is translated, and this needs the translation.)
o.window({
  class = "^org\\.gnome\\.Nautilus$",
  initial_title = "negative:^(Loading…)?$",
}, { tag = "+floating-window" })

-- Obsidian's vault window (Create, Open, Sign in) has a fixed size, so
-- Hyprland floats it, over every tiled window, including the ones it opens: a
-- browser opened from one of its links came up behind it. On a scrolling
-- workspace it gets a column of its own instead, at its own size (pseudo-tiled,
-- centred in the column), so what it opens goes beside it. The column is
-- widened when the usual width is too narrow for it, and a screen too small
-- for it keeps it floating. Dwindle will not tile a fixed-size window, and
-- floating workspaces float it anyway; both are left as they are.
local function find_window(address)
  for _, window in ipairs(hl.get_windows()) do
    if window.address == address then
      return window
    end
  end
end

local function xy(v)
  if type(v) ~= "table" then
    return 0, 0
  end
  return v.x or v[1] or 0, v.y or v[2] or 0
end

local function side_gaps(option)
  local gaps = hl.get_config(option)
  if type(gaps) == "table" then
    return gaps.left or 0, gaps.right or 0, gaps.top or 0, gaps.bottom or 0
  end
  gaps = tonumber(gaps) or 0
  return gaps, gaps, gaps, gaps
end

local function on_floating_workspace(window)
  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "omarchy-floating-workspace" then
      return true
    end
  end
  return false
end

-- The share of the screen a column needs to hold a window this wide, or nil
-- when the screen is too small for it.
local function column_for(window, width, height)
  local monitor = window.monitor
  if not monitor or not monitor.width then
    return nil
  end

  local mw, mh = monitor.width, monitor.height
  if (monitor.transform or 0) % 2 == 1 then
    mw, mh = mh, mw
  end
  local scale = monitor.scale or 1
  local reserved = monitor.reserved or {}
  mw = mw / scale - (reserved.left or 0) - (reserved.right or 0)
  mh = mh / scale - (reserved.top or 0) - (reserved.bottom or 0)

  local left, right, top, bottom = side_gaps("general.gaps_out")
  local inner = side_gaps("general.gaps_in")
  local border = tonumber(hl.get_config("general.border_size")) or 0
  local usable = mw - left - right
  if usable <= 0 then
    return nil
  end

  local share = (width + 2 * border + inner) / usable
  if share > 1 or height + 2 * border > mh - top - bottom then
    return nil
  end
  return share, usable
end

hl.on("window.open", function(opened)
  if opened.class ~= "md.obsidian.Obsidian" or opened.initial_title ~= "Obsidian" then
    return
  end

  -- Omarchy tags a window it finds on a floating workspace as it opens, after
  -- this runs, and the window's own size settles a few milliseconds after it
  -- maps, so look a moment later.
  local address = opened.address
  hl.timer(function()
    local window = find_window(address)
    local workspace = window and window.workspace
    local id = workspace and tonumber(workspace.id)
    if not window or not window.floating or window.pinned or (window.fullscreen or 0) ~= 0
      or not id or id < 1 or workspace.tiled_layout ~= "scrolling" or on_floating_workspace(window) then
      return
    end

    local width, height = xy(window.size)
    local share, usable = column_for(window, width, height)
    if not share then
      return
    end

    -- Column widths change only through the focused column on the focused
    -- monitor. When the usual width is too narrow and focus has already moved
    -- on, the column cannot be widened, so the window stays floating.
    local default = tonumber(hl.get_config("scrolling.column_width")) or 0.5
    local active, current = hl.get_active_window(), hl.get_active_workspace()
    local widen = share > default
    if widen and not (active and active.address == address and current and current.id == id) then
      return
    end

    -- A pseudo-tiled window is fitted inside the tile's gaps and border, which
    -- would cut the fixed-size window short; sizing it again gives it its own.
    hl.dispatch(hl.dsp.window.float({ action = "off", window = window }))
    hl.dispatch(hl.dsp.window.pseudo({ action = "on", window = window }))
    hl.dispatch(hl.dsp.window.resize({ x = width, y = height, relative = false, window = window }))

    if widen then
      hl.dispatch(hl.dsp.layout(string.format("colresize %.4f", share)))
      local now = find_window(address)
      local got = now and xy(now.size)
      if got and got < width - 1 then
        hl.dispatch(hl.dsp.layout(string.format("colresize %.4f", math.min(1, share + (width - got) / usable))))
      end
    end
  end, { timeout = 100, type = "oneshot" })
end)

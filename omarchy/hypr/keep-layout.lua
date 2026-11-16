-- Keep each screen's windows as they were through the screen dropping out.
--
-- The middle BenQ (HDMI-A-1) drops off HDMI a few seconds after it goes to
-- sleep and comes back on its own, and a power cut does the same to any screen.
-- Each time Hyprland moves the screen's workspaces to another one, and Omarchy's
-- monitor-workspaces brings them back when it returns. What survives the trip,
-- measured on 2026-11-16 by switching DP-2 off and on:
--
-- * floating windows, dwindle splits and tab groups: kept;
-- * fullscreen and maximized: cleared by Hyprland on the way;
-- * scrolling workspaces: lost. The scrolling mode belongs to the workspace
--   number, so as a guest under another number the workspace tiles as dwindle,
--   and back home Hyprland rebuilds its columns: default widths, not always in
--   their old order, windows that shared a column in columns of their own, and
--   the view scrolled elsewhere;
-- * a pinned window: handed a workspace of another screen, so unpinning it
--   later would send it there;
-- * the other screens: one showing an empty workspace comes back on another.
--
-- So every second each screen is noted: what it shows, its windows' geometry,
-- pinning and fullscreen state, and for scrolling workspaces the columns
-- (order, width, stacked windows), the workspace's focused window and where it
-- sat on screen. A screen's note is frozen while it is away, and put back once
-- it has returned, its workspaces are home and the session is unlocked (a
-- locked session is retried every two seconds). Floating geometry is put back
-- too, in case a smaller screen squeezed a window.
--
-- Hyprland resizes, swaps and scrolls only the focused column, so the restore
-- moves focus through the columns with cursor warps off, and only ever sends a
-- layout message while the workspace being restored is the focused one.
-- Afterwards every screen shows what it showed before the drop and focus goes
-- back to the window that had it, except where the screen or the focus was
-- changed by hand while the screen was away: that choice stays. Hyprland moves
-- focus again just after a screen returns (to a pinned window, say), so focus
-- is put back once more if that happens. What Hyprland does to the pointer as
-- a screen goes is not undone: by then it has already moved.
--
-- Screens are told apart by make, model and serial, as monitor-workspaces does,
-- so a connector that is renamed still matches.

local SNAPSHOT_MS = 1000
local RESTORE_DELAY_MS = 1500
local RETRY_MS = 2000
local TOLERANCE = 2

local notes = {}   -- screen key -> note
local frozen = {}  -- screen key -> true while the screen is away
local pending = {} -- screen key -> a restore is scheduled
local last_active = nil -- the focused window at the last note
-- screen key -> the focused window around the drop: `before` it, `after`
-- Hyprland moved focus off the missing screen (half a second on), and
-- `touched` once focus is moved by hand before the screen returns.
local drop_focus = {}
-- screen key -> what the other screens showed around the drop: `before` it,
-- `after` Hyprland had moved things (half a second on), and `touched` for each
-- screen switched since, by hand, before this screen returned.
local drop_screens = {}

local function xy(v)
  if type(v) ~= "table" then
    return 0, 0
  end
  return v.x or v[1] or 0, v.y or v[2] or 0
end

local function key_of(monitor)
  local description = monitor and monitor.description or ""
  return description ~= "" and description or (monitor and monitor.name)
end

local function shown_by_screen()
  local shown = {}
  for _, monitor in ipairs(hl.get_monitors() or {}) do
    local key = key_of(monitor)
    if key then
      shown[key] = monitor.active_workspace and monitor.active_workspace.id or nil
    end
  end
  return shown
end

local function screen_of(monitor)
  local w, h = monitor.width or 0, monitor.height or 0
  if (monitor.transform or 0) % 2 == 1 then
    w, h = h, w
  end
  local scale = monitor.scale or 1
  return monitor.x or 0, monitor.y or 0, w / scale, h / scale
end

local function side_gaps(option)
  local gaps = hl.get_config(option)
  if type(gaps) == "table" then
    return gaps.left or 0, gaps.right or 0
  end
  gaps = tonumber(gaps) or 0
  return gaps, gaps
end

local function window_by_address(address)
  for _, w in ipairs(hl.get_windows() or {}) do
    if w.address == address then
      return w
    end
  end
  return nil
end

-- What one screen holds now.
local function note_screen(monitor)
  local mx, my = screen_of(monitor)
  local active = monitor.active_workspace
  local note = { visible = active and active.id or nil, windows = {}, scrolling = {} }
  local tiles = {}

  for _, w in ipairs(hl.get_windows() or {}) do
    local workspace = w.workspace
    if w.address and w.mapped and not w.hidden and w.monitor and w.monitor.name == monitor.name
      and workspace and workspace.id and workspace.id > 0 then
      local x, y = xy(w.at)
      local width, height = xy(w.size)
      local fullscreen = w.fullscreen or 0
      note.windows[w.address] = {
        workspace = workspace.id,
        floating = w.floating == true,
        pinned = w.pinned == true,
        fullscreen = fullscreen,
        x = x - mx, y = y - my, w = width, h = height,
      }
      if not w.floating and fullscreen == 0 and workspace.tiled_layout == "scrolling" then
        local list = tiles[workspace.id] or {}
        list[#list + 1] = { address = w.address, x = x, y = y, w = width }
        tiles[workspace.id] = list
      end
    end
  end

  -- Columns left to right; windows sharing a column top to bottom.
  for id, list in pairs(tiles) do
    table.sort(list, function(a, b)
      if math.abs(a.x - b.x) > TOLERANCE then
        return a.x < b.x
      end
      return a.y < b.y
    end)
    local columns = {}
    for _, tile in ipairs(list) do
      local column = columns[#columns]
      if column and math.abs(tile.x - column.x) <= TOLERANCE then
        column.windows[#column.windows + 1] = tile.address
      else
        columns[#columns + 1] = { x = tile.x, width = tile.w, windows = { tile.address } }
      end
    end
    local workspace = hl.get_workspace(id)
    local last = workspace and workspace.last_window
    note.scrolling[id] = { columns = columns, last = last and last.address or nil }
  end

  return note
end

local function snapshot()
  local active = hl.get_active_window()
  last_active = active and active.address or nil

  -- Focus moved while a screen was away, after Hyprland's own move, was moved
  -- by hand: it stays where it was put.
  for _, around in pairs(drop_focus) do
    if around.settled and not around.returned and last_active ~= around.after then
      around.touched = true
    end
  end

  -- A screen whose workspace changed while another screen was away, after
  -- Hyprland's own moves, was switched by hand: leave it as it is.
  for _, around in pairs(drop_screens) do
    if around.after and not around.returned then
      local shown = shown_by_screen()
      for key, id in pairs(shown) do
        if around.after[key] ~= nil and around.after[key] ~= id then
          around.touched[key] = true
        end
      end
    end
  end

  for _, monitor in ipairs(hl.get_monitors() or {}) do
    local key = key_of(monitor)
    if key and not frozen[key] then
      notes[key] = note_screen(monitor)
    end
  end
end

local function locked()
  local pipe = io.popen("owe status 2>/dev/null")
  if not pipe then
    return false
  end
  local status = pipe:read("*a") or ""
  pipe:close()
  return status:match('"locked"%s*:%s*true') ~= nil
end

local function focus(address)
  hl.dispatch(hl.dsp.focus({ window = "address:" .. address }))
end

-- Layout messages go to the focused monitor's workspace; send one only when
-- that is the workspace being restored.
local function layout_message(id, message)
  local active = hl.get_active_workspace()
  if active and active.id == id then
    hl.dispatch(hl.dsp.layout(message))
    return true
  end
  return false
end

local function restore_scrolling(id, saved, note, monitor)
  local mx, _, mw = screen_of(monitor)
  local gap_left, gap_right = side_gaps("general.gaps_out")
  local usable = mw - gap_left - gap_right
  local inner = side_gaps("general.gaps_in")
  local border = tonumber(hl.get_config("general.border_size")) or 0
  local extra = 2 * border + inner

  local function tile(address)
    local w = window_by_address(address)
    if w and w.workspace and w.workspace.id == id and not w.floating and (w.fullscreen or 0) == 0 then
      return w
    end
    return nil
  end

  -- Column order, and windows that shared a column. Hyprland brings the
  -- windows back as one column each, not always in their old order, so the
  -- saved columns are walked left to right: each is swapped into place right
  -- after the one before it, and a window that shared it is swapped in beside
  -- it and then moved into it. Columns of windows opened meanwhile end up to
  -- the right of the restored ones.
  local function column_xs()
    local xs = {}
    for _, w in ipairs(hl.get_workspace_windows(tostring(id)) or {}) do
      if not w.floating and (w.fullscreen or 0) == 0 and w.mapped and not w.hidden then
        local x = xy(w.at)
        local known = false
        for _, seen in ipairs(xs) do
          if math.abs(seen - x) <= TOLERANCE then
            known = true
          end
        end
        if not known then
          xs[#xs + 1] = x
        end
      end
    end
    table.sort(xs)
    return xs
  end

  local function index_of(address)
    local w = tile(address)
    if not w then
      return nil
    end
    local x = xy(w.at)
    for i, seen in ipairs(column_xs()) do
      if math.abs(seen - x) <= TOLERANCE then
        return i
      end
    end
    return nil
  end

  -- Swap the column holding `address` until it is at `target` (a function, as
  -- swapping can shift the column it is measured from). Bounded, in case a
  -- swap does not move it.
  local function bring(address, target)
    for _ = 1, 32 do
      local i, want = index_of(address), target()
      if not i or not want or i == want then
        return i ~= nil and i == want
      end
      focus(address)
      if not layout_message(id, i > want and "swapcol l" or "swapcol r") then
        return false
      end
      if index_of(address) == i then
        return false
      end
    end
    return false
  end

  local previous = nil
  for _, column in ipairs(saved.columns) do
    local present = {}
    for _, address in ipairs(column.windows) do
      if tile(address) then
        present[#present + 1] = address
      end
    end
    local first = present[1]
    if first then
      local after = previous
      bring(first, function()
        return after and index_of(after) and index_of(after) + 1 or 1
      end)
      for k = 2, #present do
        local this = present[k]
        if index_of(this) ~= index_of(first) then
          local placed = bring(this, function()
            return index_of(first) and index_of(first) + 1
          end)
          if placed then
            focus(this)
            local active = hl.get_active_workspace()
            if active and active.id == id then
              hl.dispatch(hl.dsp.window.move({ direction = "l" }))
            end
          end
        end
      end
      previous = first
    end
  end

  -- Widths, checked and corrected once.
  for _, column in ipairs(saved.columns) do
    local w = tile(column.windows[1])
    if w and math.abs(xy(w.size) - column.width) > TOLERANCE then
      focus(w.address)
      local share = (column.width + extra) / usable
      if layout_message(id, string.format("colresize %.4f", math.max(0.05, math.min(1, share)))) then
        local now = tile(w.address)
        local got = now and xy(now.size)
        if got and math.abs(got - column.width) > TOLERANCE then
          share = share + (column.width - got) / usable
          layout_message(id, string.format("colresize %.4f", math.max(0.05, math.min(1, share))))
        end
      end
    end
  end

  -- The workspace's focused window, where it sat on screen.
  local anchor = saved.last and tile(saved.last) and saved.last or nil
  if not anchor and saved.columns[1] then
    anchor = tile(saved.columns[1].windows[1]) and saved.columns[1].windows[1] or nil
  end
  if anchor and note.windows[anchor] then
    focus(anchor)
    local now = tile(anchor)
    if now then
      local shift = note.windows[anchor].x - (xy(now.at) - mx)
      if math.abs(shift) > TOLERANCE then
        layout_message(id, string.format("move %+d", math.floor(shift + 0.5)))
      end
    end
  end
end

local function put_back(key, monitor, note)
  local current = {}
  for _, w in ipairs(hl.get_windows() or {}) do
    if w.address then
      current[w.address] = w
    end
  end
  -- Still open, and back on its own workspace on this screen.
  local function home(address, saved)
    local w = current[address]
    if w and w.workspace and w.workspace.id == saved.workspace and key_of(w.monitor) == key then
      return w
    end
    return nil
  end

  for id, saved in pairs(note.scrolling) do
    local workspace = hl.get_workspace(id)
    if workspace and workspace.tiled_layout == "scrolling" and key_of(workspace.monitor) == key then
      restore_scrolling(id, saved, note, monitor)
    end
  end

  local mx, my = screen_of(monitor)
  for address, saved in pairs(note.windows) do
    local w = home(address, saved)
    if w and saved.floating and w.floating and (w.fullscreen or 0) == 0 then
      local x, y = xy(w.at)
      local width, height = xy(w.size)
      local target = "address:" .. address
      if math.abs(width - saved.w) > TOLERANCE or math.abs(height - saved.h) > TOLERANCE then
        hl.dispatch(hl.dsp.window.resize({ x = saved.w, y = saved.h, relative = false, window = target }))
      end
      if math.abs(x - mx - saved.x) > TOLERANCE or math.abs(y - my - saved.y) > TOLERANCE then
        hl.dispatch(hl.dsp.window.move({ x = mx + saved.x, y = my + saved.y, window = target }))
      end
    end
  end

  for address, saved in pairs(note.windows) do
    local w = home(address, saved)
    if w and saved.fullscreen ~= 0 and (w.fullscreen or 0) ~= saved.fullscreen then
      hl.dispatch(hl.dsp.window.fullscreen({
        mode = saved.fullscreen == 2 and "fullscreen" or "maximized",
        action = "set",
        window = "address:" .. address,
      }))
    end
  end
end

local schedule

local function restore(key)
  pending[key] = nil
  if not frozen[key] then
    return
  end

  local monitor
  for _, m in ipairs(hl.get_monitors() or {}) do
    if key_of(m) == key then
      monitor = m
    end
  end
  -- Gone again: wait for it to come back.
  if not monitor then
    return
  end

  local note = notes[key]
  if not note then
    frozen[key] = nil
    drop_focus[key] = nil
    drop_screens[key] = nil
    return
  end

  -- Moving focus under the lock screen is not safe; try again once unlocked.
  if locked() then
    schedule(key, RETRY_MS)
    return
  end

  -- Focus goes back to where it was before the drop, unless it was moved by
  -- hand while the screen was away. Hyprland moving it again as the screen
  -- returns does not count.
  local active = hl.get_active_window()
  local active_address = active and active.address or nil
  local around = drop_focus[key]
  if around and around.before and not around.touched and window_by_address(around.before) then
    active_address = around.before
  end
  local no_warps = hl.get_config("cursor.no_warps")
  hl.config({ cursor = { no_warps = true } })
  -- What the last restore did, for `hyprctl eval` when something looks off.
  _G.rahulj_keep_layout.last = { screen = key, active_at_start = active and active.address, focus_to = active_address,
    before = around and around.before, touched = around and around.touched }

  local ok, err = pcall(put_back, key, monitor, note)

  -- The screen shows the workspace it showed before, and focus goes back.
  pcall(function()
    local visible = note.visible and hl.get_workspace(note.visible)
    local showing = monitor.active_workspace
    if visible and key_of(visible.monitor) == key and not (showing and showing.id == visible.id) then
      monitor:set_workspace({ workspace = visible.name })
    end
    -- A pinned window shows on whatever its screen shows, but Hyprland hands
    -- it a workspace of another screen on the way, so unpinning it later would
    -- send it there. It goes back to the screen's workspace, pinned again.
    local shown = monitor.active_workspace
    if visible then
      shown = visible
    end
    local mx, my = screen_of(monitor)
    for address, saved in pairs(note.windows) do
      local w = window_by_address(address)
      if saved.pinned and w and w.pinned and shown and w.workspace and key_of(w.workspace.monitor) ~= key then
        local target = "address:" .. address
        hl.dispatch(hl.dsp.window.pin({ window = target }))
        hl.dispatch(hl.dsp.window.move({ workspace = tostring(shown.id), follow = false, window = target }))
        hl.dispatch(hl.dsp.window.pin({ window = target }))
        hl.dispatch(hl.dsp.window.move({ x = mx + saved.x, y = my + saved.y, window = target }))
      end
    end

    -- The other screens show what they showed before the drop, unless they
    -- were switched by hand meanwhile. A workspace that was empty is gone by
    -- now; focusing its number brings it back.
    local around_screens = drop_screens[key]
    if around_screens then
      for _, other in ipairs(hl.get_monitors() or {}) do
        local other_key = key_of(other)
        local want = around_screens.before[other_key]
        local now = other.active_workspace and other.active_workspace.id
        if other_key ~= key and want and want > 0 and now ~= want and not around_screens.touched[other_key] then
          local workspace = hl.get_workspace(want)
          if workspace and key_of(workspace.monitor) == other_key then
            other:set_workspace({ workspace = workspace.name })
          elseif not workspace then
            hl.dispatch(hl.dsp.focus({ monitor = other.name }))
            hl.dispatch(hl.dsp.focus({ workspace = tostring(want) }))
          end
        end
      end
    end

    if active_address and window_by_address(active_address) then
      focus(active_address)
    end
  end)

  hl.config({ cursor = { no_warps = no_warps == true } })

  -- Hyprland moves focus again a moment after a screen returns, to a pinned
  -- window or the last window of a workspace it shows (seen with this restore
  -- switched off too). Put it back if that happens just after the restore.
  if active_address then
    for _, ms in ipairs({ 150, 450 }) do
      hl.timer(function()
        local now = hl.get_active_window()
        if (not now or now.address ~= active_address) and window_by_address(active_address) then
          local warps = hl.get_config("cursor.no_warps")
          hl.config({ cursor = { no_warps = true } })
          focus(active_address)
          hl.config({ cursor = { no_warps = warps == true } })
        end
      end, { type = "oneshot", timeout = ms })
    end
  end

  frozen[key] = nil
  drop_focus[key] = nil
  drop_screens[key] = nil
  snapshot()

  if not ok then
    pcall(hl.exec_cmd, "notify-send -a Hyprland 'Keep layout' " .. o.shell_quote(tostring(err)))
  end
end

schedule = function(key, delay)
  if pending[key] then
    return
  end
  pending[key] = true
  hl.timer(function()
    restore(key)
  end, { type = "oneshot", timeout = delay })
end

hl.timer(snapshot, { type = "repeat", timeout = SNAPSHOT_MS })

hl.on("monitor.removed", function(monitor)
  local key = key_of(monitor)
  if key and not frozen[key] then
    frozen[key] = true
    -- Where focus was, and where Hyprland puts it once the screen has gone.
    local around = { before = last_active, touched = false }
    drop_focus[key] = around
    hl.timer(function()
      local now = hl.get_active_window()
      around.after = now and now.address or nil
      around.settled = true
    end, { type = "oneshot", timeout = 500 })

    local before = {}
    for other_key, note in pairs(notes) do
      if other_key ~= key and not frozen[other_key] then
        before[other_key] = note.visible
      end
    end
    local screens = { before = before, touched = {} }
    drop_screens[key] = screens
    hl.timer(function()
      screens.after = shown_by_screen()
    end, { type = "oneshot", timeout = 500 })
  end
end)

-- Omarchy brings the workspaces home on monitor.added; restore after it.
hl.on("monitor.added", function(monitor)
  local key = key_of(monitor)
  if key and drop_screens[key] then
    drop_screens[key].returned = true
  end
  if key and drop_focus[key] then
    drop_focus[key].returned = true
  end
  if key and frozen[key] then
    schedule(key, RESTORE_DELAY_MS)
  end
end)

-- Reachable from `hyprctl eval` for testing: rahulj_keep_layout.snapshot() etc.
_G.rahulj_keep_layout = { snapshot = snapshot, restore = restore, notes = notes, frozen = frozen }

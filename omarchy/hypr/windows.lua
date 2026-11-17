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
-- browser opened from one of its links came up behind it. On a tiled (dwindle)
-- or scrolling workspace it takes a place in the layout instead, at its own
-- size (pseudo-tiled, centred in its slot), so what it opens goes beside it.
--
-- * Dwindle will not tile a window with a fixed size, so while the window is
--   on a tiled workspace a tag lifts its maximum size; on a floating
--   workspace the tag comes off again, so it cannot be stretched there.
-- * Its slot is made big enough for it: on scrolling its column is widened,
--   on dwindle the split it sits in is moved. Both act only on the focused
--   window, so when the vault window is not focused, focus visits it and
--   comes straight back within the same step, without moving the pointer.
-- * When no slot can hold it (a cramped screen), it floats as before if it is
--   the focused window; if another window has just taken focus, it stays in
--   its slot cut down rather than cover that window, and grows back to its
--   own size once there is room.
-- * It is placed when it opens, when it moves to another workspace, and when
--   its workspace changes layout (Super + L). A window opening or closing
--   beside it changes its slot, so its slot is checked again then, and when
--   its workspace comes into view. Floating it by hand (Super + T) is left
--   alone until it moves or the layout changes; tiling it again fits it.

local VAULT = "rahulj-obsidian-vault"
local SIZE = "rahulj-own-size-"
local NO_MAX = "rahulj-no-max-size"

o.window({ tag = NO_MAX }, { no_max_size = true })

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

local function has_tag(window, name)
  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == name then
      return true
    end
  end
  return false
end

local function tag(window, name, on)
  if has_tag(window, name) ~= on then
    hl.dispatch(hl.dsp.window.tag({ tag = (on and "+" or "-") .. name, window = "address:" .. window.address }))
  end
end

-- The window's own size, noted when it opened.
local function own_size(window)
  for _, t in ipairs(window.tags or {}) do
    if t:sub(1, #SIZE) == SIZE then
      local w, h = t:sub(#SIZE + 1):match("^(%d+)x(%d+)$")
      if w then
        return tonumber(w), tonumber(h)
      end
    end
  end
end

local function tiled_workspace(window)
  local workspace = window.workspace
  local id = workspace and tonumber(workspace.id)
  return id and id >= 1 and not has_tag(window, "omarchy-floating-workspace")
end

local function visible(window)
  local workspace = window.workspace
  return workspace and workspace.monitor and workspace.monitor.active_workspace
    and workspace.monitor.active_workspace.id == workspace.id
end

-- Column width and split ratio change only through the focused window. Focus
-- visits the window and returns within this one step, so nothing is drawn in
-- between and no key or click can land elsewhere; the pointer stays put.
local function with_focus(window, fn)
  local before = hl.get_active_window()
  if before and before.address == window.address then
    return fn()
  end
  local warps = hl.get_config("cursor.no_warps")
  hl.config({ cursor = { no_warps = true } })
  hl.dispatch(hl.dsp.focus({ window = "address:" .. window.address }))
  local ok, result = pcall(fn)
  if before then
    hl.dispatch(hl.dsp.focus({ window = "address:" .. before.address }))
  end
  hl.config({ cursor = { no_warps = warps == true or warps == 1 } })
  if not ok then
    error(result)
  end
  return result
end

local function sizes(address)
  local window = find_window(address)
  if window then
    return xy(window.size)
  end
  return 0, 0
end

-- Its maximum size stays lifted while it is on a tiled workspace, so that
-- Super + T can tile it again.
local function float_back(window, w, h)
  hl.dispatch(hl.dsp.window.float({ action = "on", window = window }))
  hl.dispatch(hl.dsp.window.resize({ x = w, y = h, relative = false, window = window }))
  hl.dispatch(hl.dsp.window.center({ window = window }))
end

-- Scrolling: widen the column until the window fits, if the screen allows.
-- The tile is measured with pseudo-tiling off, then the window is sized to
-- its own size only once it fits (see fit_split).
local function fit_column(window, w, h)
  local address = window.address
  hl.dispatch(hl.dsp.window.pseudo({ action = "off", window = window }))
  local tw, th = sizes(address)
  local fits = tw >= w and th >= h

  if not fits and th >= h and visible(window) then
    local monitor = window.monitor
    local mw = monitor.width
    if (monitor.transform or 0) % 2 == 1 then
      mw = monitor.height
    end
    local reserved = monitor.reserved or {}
    mw = mw / (monitor.scale or 1) - (reserved.left or 0) - (reserved.right or 0)
    local gaps = hl.get_config("general.gaps_out")
    local left, right
    if type(gaps) == "table" then
      left, right = gaps.left or 0, gaps.right or 0
    else
      left, right = tonumber(gaps) or 0, tonumber(gaps) or 0
    end
    local inner = hl.get_config("general.gaps_in")
    inner = type(inner) == "table" and (inner.left or 0) or (tonumber(inner) or 0)
    local border = tonumber(hl.get_config("general.border_size")) or 0
    local usable = mw - left - right
    local share = (w + 2 * border + inner) / usable
    if usable > 0 and share <= 1 then
      with_focus(window, function()
        hl.dispatch(hl.dsp.layout(string.format("colresize %.4f", share)))
        local got = sizes(address)
        if got < w then
          hl.dispatch(hl.dsp.layout(string.format("colresize %.4f", math.min(1, share + (w - got + 1) / usable))))
        end
      end)
      tw, th = sizes(address)
      fits = tw >= w - 1 and th >= h
    end
  end

  hl.dispatch(hl.dsp.window.pseudo({ action = "on", window = window }))
  if fits then
    hl.dispatch(hl.dsp.window.resize({ x = w, y = h, relative = false, window = window }))
  end
  return fits
end

-- Dwindle: move the split the window sits in until its tile holds it. Which
-- way the ratio grows this window depends on its side of the split, so a
-- small step is tried first and measured.
local function fit_split(window, w, h)
  local address = window.address
  hl.dispatch(hl.dsp.window.pseudo({ action = "off", window = window }))
  local tw, th = sizes(address)
  local short_w, short_h = w - tw, h - th
  local fits = short_w <= 0 and short_h <= 0
  if not fits and visible(window) then
    local axis = short_w > 0 and 1 or 2
    with_focus(window, function()
      local function step(delta)
        hl.dispatch(hl.dsp.layout(string.format("splitratio %.4f", delta)))
        return sizes(address)
      end
      local function along(a, x, y)
        return a == 1 and x or y
      end
      local target, start = along(axis, w, h), along(axis, tw, th)
      local pw, ph = step(0.1)
      local rate = (along(axis, pw, ph) - start) / 0.1
      local now = along(axis, pw, ph)
      -- Aim a couple of pixels past it, and correct once: gaps and rounding
      -- keep the ratio from being exactly linear.
      for _ = 1, 2 do
        if math.abs(rate) < 1 or now >= target then
          break
        end
        now = along(axis, step((target + 2 - now) / rate))
      end
      local nw, nh = sizes(address)
      fits = nw >= w - 1 and nh >= h - 1
      if not fits then
        -- Put the split back where it was, by measuring rather than by
        -- undoing the steps: Hyprland caps the ratio, so steps past the cap
        -- did nothing. The probe may have moved the other side instead.
        local back_axis = math.abs(rate) >= 1 and axis or (axis == 1 and 2 or 1)
        local back_rate = (along(back_axis, pw, ph) - along(back_axis, tw, th)) / 0.1
        local back_start = along(back_axis, tw, th)
        local cur = along(back_axis, nw, nh)
        for _ = 1, 3 do
          if math.abs(back_rate) < 1 or math.abs(cur - back_start) <= 1 then
            break
          end
          cur = along(back_axis, step((back_start - cur) / back_rate))
        end
      end
    end)
  end
  hl.dispatch(hl.dsp.window.pseudo({ action = "on", window = window }))
  -- Sizing a pseudo-tiled window that does not fit would make the cut-down
  -- size its own, and it would stay that small once the slot grows again.
  if fits then
    hl.dispatch(hl.dsp.window.resize({ x = w, y = h, relative = false, window = window }))
  end
  return fits
end

-- Put a vault window in its workspace's layout, sized to fit; float it when
-- no slot can hold it. With retile, a floating one is tiled first.
local placing = false

local function place_now(window, retile)
  local w, h = own_size(window)
  if not w or (window.fullscreen or 0) ~= 0 or window.pinned then
    return
  end

  if not tiled_workspace(window) then
    -- Floating workspace: Omarchy floats it; keep it at its own size.
    if has_tag(window, NO_MAX) then
      tag(window, NO_MAX, false)
      hl.dispatch(hl.dsp.window.resize({ x = w, y = h, relative = false, window = window }))
      hl.dispatch(hl.dsp.window.center({ window = window }))
    end
    return
  end

  if window.floating and not retile then
    return
  end

  tag(window, NO_MAX, true)
  if window.floating then
    hl.dispatch(hl.dsp.window.float({ action = "off", window = window }))
  end
  local now = find_window(window.address)
  if not now or now.floating then
    return
  end

  local layout = now.workspace.tiled_layout
  local fits
  if layout == "scrolling" then
    fits = fit_column(now, w, h)
  elseif layout == "dwindle" then
    fits = fit_split(now, w, h)
  end

  -- No slot can hold it. Floating it would cover whatever it sits beside, so
  -- that happens only while it is the focused window (as it opens); when
  -- another window has just taken focus (a browser opened from one of its
  -- links) it stays in its slot, partly cut off, and takes its full size
  -- again by itself once the slot grows. Off screen its slot cannot be fitted
  -- yet; that happens when it is shown.
  local active = hl.get_active_window()
  if not fits and visible(now) and active and active.address == now.address then
    float_back(now, w, h)
  end
end

-- While it runs, the floating changes it makes are its own, not Super + T's.
local function place(window, retile)
  placing = true
  local ok, err = pcall(place_now, window, retile)
  placing = false
  if not ok then
    error(err)
  end
end

local function vault_windows(workspace_id)
  local found = {}
  for _, window in ipairs(hl.get_windows({ tag = VAULT })) do
    if not workspace_id or (window.workspace and window.workspace.id == workspace_id) then
      table.insert(found, window)
    end
  end
  return found
end

-- Run fn a moment after an event, once Omarchy has arranged the workspace.
local function later(fn)
  hl.timer(function()
    local ok, err = pcall(fn)
    if not ok then
      hl.exec_cmd("notify-send -a Hyprland 'Obsidian vault window' " .. o.shell_quote(tostring(err)))
    end
  end, { timeout = 100, type = "oneshot" })
end

hl.on("window.open", function(opened)
  local address = opened.address
  local vault = opened.class == "md.obsidian.Obsidian" and opened.initial_title == "Obsidian"
  later(function()
    local window = find_window(address)
    if not window then
      return
    end
    if vault then
      -- Its own size, while it still floats at it.
      local w, h = xy(window.size)
      tag(window, VAULT, true)
      tag(window, SIZE .. w .. "x" .. h, true)
      place(find_window(address), true)
    elseif window.workspace then
      -- A window opening beside one may have halved its dwindle slot, or
      -- narrowed its scrolling column (a lone column shows at full width).
      for _, other in ipairs(vault_windows(window.workspace.id)) do
        if not other.floating then
          place(other, false)
        end
      end
    end
  end)
end)

hl.on("window.move_to_workspace", function(moved)
  local address = moved.address
  later(function()
    local window = find_window(address)
    if not window or not window.workspace then
      return
    end
    if has_tag(window, VAULT) then
      place(window, true)
    else
      for _, other in ipairs(vault_windows(window.workspace.id)) do
        if not other.floating then
          place(other, false)
        end
      end
    end
  end)
end)

-- A window closing beside one gives its slot room again; one that had to
-- stay cut down gets its own size back.
hl.on("window.close", function(closed)
  local id = closed and closed.workspace and closed.workspace.id
  if not id or has_tag(closed, VAULT) then
    return
  end
  later(function()
    for _, window in ipairs(vault_windows(id)) do
      if not window.floating then
        place(window, false)
      end
    end
  end)
end)

-- Super + T tiling it again: Hyprland reports a change of floating only as a
-- rule update, so its floating state is followed here, and a change from
-- floating to tiled made by anything but place() gets it fitted.
local was_floating = {}
hl.on("window.update_rules", function(window)
  if not window or not has_tag(window, VAULT) then
    return
  end
  local address, before = window.address, was_floating[window.address]
  was_floating[address] = window.floating
  if placing or before ~= true or window.floating then
    return
  end
  later(function()
    local now = find_window(address)
    if now and not now.floating then
      place(now, false)
    end
  end)
end)

hl.on("workspace.active", function(workspace)
  if not workspace or not workspace.id then
    return
  end
  local id = workspace.id
  later(function()
    for _, window in ipairs(vault_windows(id)) do
      if not window.floating then
        place(window, false)
      end
    end
  end)
end)

-- Super + L changes a workspace's layout through o.workspace_mode, which
-- Omarchy defines after this file loads, so it is wrapped once loading is
-- done (and again after every reload, which defines it afresh). Going to
-- floating, the maximum size comes back first, so Omarchy's floating size
-- cannot stretch the window. The new tiled layout takes effect only after
-- the call returns, so the window is placed a moment later.
hl.timer(function()
  local original = o.workspace_mode
  if type(original) ~= "function" or original == _G.rahulj_vault_workspace_mode then
    return
  end
  _G.rahulj_vault_workspace_mode = function(spec)
    local id = spec and tonumber(spec.workspace)
    if id and spec.mode == "floating" then
      for _, window in ipairs(vault_windows(id)) do
        tag(window, NO_MAX, false)
      end
    end
    original(spec)
    if id then
      later(function()
        for _, window in ipairs(vault_windows(id)) do
          place(window, true)
        end
      end)
    end
  end
  o.workspace_mode = _G.rahulj_vault_workspace_mode
end, { timeout = 1, type = "oneshot" })

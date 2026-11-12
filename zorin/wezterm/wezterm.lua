-- WezTerm configuration (ported from the previous alacritty.toml)

local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()

-- Title bar on/off, toggled at runtime by the keybinding further down.
-- "RESIZE" drops the title bar but keeps the resize edges, unlike "NONE".
local DECORATIONS_ON = "TITLE | RESIZE"
local DECORATIONS_OFF = "RESIZE"

-- Fraction of the active screen the first window should cover, per axis.
-- Width is intentionally the smaller of the two: the screen is far wider than
-- it is tall, so equal fractions give a window that feels wide but squat.
local WINDOW_WIDTH_FRACTION = 0.75
local WINDOW_HEIGHT_FRACTION = 0.70

-- Thickness of the window frame a `tmux dev` session turns on, even on all four
-- sides since there is no title bar for a heavier top edge to sit under.
local DEV_BORDER_WIDTH = "0.25cell"

-- The user variable dev-session.sh sets to hand over the repo's accent colour.
local DEV_ACCENT_VAR = "tmux_dev_accent"

-- ==============================
-- BACKEND
-- ==============================
-- Run under XWayland rather than as a native Wayland client. WezTerm's Wayland
-- backend displaces a fullscreen window and leaves a black offset band behind
-- it whenever focus moves to the other monitor -- upstream wezterm#6275, open
-- and unfixed, reproduced on builds newer than the one here, so there is no
-- version to upgrade to. Two outputs of different heights (eDP-1 1920x1200,
-- HDMI-1 1920x1080) make it fire on every focus switch: the fullscreen surface
-- sized for one output is wrong for the other, and mutter paints the part the
-- surface fails to cover.
--
-- XWayland reaches fullscreen by an entirely different path and does not have
-- the bug. It would normally cost sharpness on a HiDPI screen, but both
-- monitors here are scale 1 with fractional scaling off, so it costs nothing.
-- Delete this line to go back to the Wayland backend.
config.enable_wayland = false

-- OpenGL rather than the default WebGpu backend. On this AMD Renoir / Mesa
-- setup WebGpu leaves stale glyphs behind after a scroll -- text from earlier
-- frames surviving in cells nothing redrew, which reads as windows bleeding
-- through each other and sent me chasing highlight groups and terminfo for it.
-- OpenGL repaints the damaged region properly.
--
-- If artifacts ever come back, "Software" is the check: clean there means the
-- GPU path is at fault rather than wezterm's drawing.
config.front_end = "OpenGL"

-- ==============================
-- WINDOW
-- ==============================
-- Plain transparency, no blur. WezTerm only ships blur for macOS and Windows,
-- and the GNOME/Wayland route (Blur my Shell) positions its backdrop in
-- monitor coordinates, which breaks on a multi-monitor desktop -- the blur is
-- created but clipped away from the window. Not worth the collateral damage it
-- caused to other apps, so this is transparency alone.
config.window_background_opacity = 0.88

-- No title bar. "RESIZE" keeps the resize edges (unlike "NONE"); move the
-- window with Super+drag since there is no titlebar left to grab. Rounded
-- corners are not a WezTerm feature in any version -- they come from the
-- "Rounded Window Corners Reborn" GNOME extension.
config.window_decorations = DECORATIONS_OFF

-- Fallback size for windows spawned after startup (Ctrl+Shift+N). The first
-- window is sized from the screen instead -- see STARTUP GEOMETRY below.
config.initial_cols = 170
config.initial_rows = 50

config.window_padding = { left = 12, right = 12, top = 10, bottom = 10 }

-- Alacritty had no tabs; keep the bar out of the way until a second tab exists
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false

-- Installed from apt, so let the package manager handle updates
config.check_for_updates = false

-- ==============================
-- FONT
-- ==============================
-- The "Bold" style forces the thicker, heavier weight for normal characters
config.font = wezterm.font({ family = "Hack Nerd Font", weight = "Bold" })
config.font_size = 11

-- Zooming (Ctrl+= / Ctrl+- / Ctrl+scroll) should scale the text inside a
-- window that stays put. Left at its default of true, WezTerm instead holds
-- the cell grid fixed and grows or shrinks the window to suit, which under
-- Wayland also makes the compositor shuffle the window around.
config.adjust_window_size_when_changing_font_size = false

config.font_rules = {
  {
    intensity = "Bold",
    font = wezterm.font({ family = "Hack Nerd Font", weight = "Bold" }),
  },
  {
    italic = true,
    font = wezterm.font({ family = "Hack Nerd Font", style = "Italic" }),
  },
}

-- ==============================
-- CURSOR
-- ==============================
config.default_cursor_style = "BlinkingBar"
config.cursor_blink_rate = 600
-- Hard on/off blink instead of WezTerm's default fade
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"

-- ==============================
-- SCROLLING
-- ==============================
config.scrollback_lines = 10000

-- ==============================
-- MOUSE
-- ==============================
config.hide_mouse_cursor_when_typing = true

config.mouse_bindings = {
  -- SELECTION: mirror alacritty's save_to_clipboard, which sends the
  -- selection to the clipboard as well as the primary selection
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "NONE",
    action = act.CompleteSelection("ClipboardAndPrimarySelection"),
  },
}

-- ==============================
-- COLORS (Tokyo Night inspired)
-- ==============================
config.colors = {
  background = "#222436",
  foreground = "#c0caf5",

  ansi = {
    "#15161e", -- black
    "#f7768e", -- red
    "#9ece6a", -- green
    "#e0af68", -- yellow
    "#7aa2f7", -- blue
    "#bb9af7", -- magenta
    "#7dcfff", -- cyan
    "#a9b1d6", -- white
  },

  brights = {
    "#414868", -- black
    "#f7768e", -- red
    "#9ece6a", -- green
    "#e0af68", -- yellow
    "#7aa2f7", -- blue
    "#bb9af7", -- magenta
    "#7dcfff", -- cyan
    "#c0caf5", -- white
  },
}

-- ==============================
-- KEYBOARD
-- ==============================
config.keys = {
  -- Paste (Ctrl+Shift+V)
  { key = "V", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },

  -- Copy (Ctrl+Shift+C)
  { key = "C", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },

  -- --- Keyboard Scrolling ---
  { key = "PageUp", mods = "SHIFT", action = act.ScrollByPage(-1) },
  { key = "PageDown", mods = "SHIFT", action = act.ScrollByPage(1) },
  { key = "Home", mods = "SHIFT", action = act.ScrollToTop },
  { key = "End", mods = "SHIFT", action = act.ScrollToBottom },

  -- Shift+Enter sends ESC CR (newline in REPLs, Claude Code, etc.)
  { key = "Enter", mods = "SHIFT", action = act.SendString("\x1b\r") },

  -- Show/hide the title bar
  { key = "T", mods = "CTRL|SHIFT|ALT", action = act.EmitEvent("toggle-titlebar") },
}

-- ==============================
-- ENV (fix some rendering issues)
-- ==============================
config.term = "xterm-256color"

-- ==============================
-- STARTUP GEOMETRY
-- ==============================
-- Open the first window at the screen fractions set at the top of this file.
--
-- The size is applied at spawn time in cells rather than resized afterwards:
-- `set_inner_size` is a no-op under Wayland in this build, and sizing the
-- window at creation also means the compositor places the correctly-sized
-- window instead of centring a small one and leaving it off-centre once it
-- grows.
--
-- Positioning is deliberately absent: Wayland does not let a client place its
-- own window. Centring is the compositor's job, via
-- `org.gnome.mutter center-new-windows`.
--
-- Cell size in pixels for the font configured above, measured on this machine
-- at scale 1.0 / 96dpi (both monitors here match): a maximized window gains one
-- column per ~9px of width, and the vertical padding differential (80px of
-- padding costs 5 rows) puts the cell height at 16px.
--
-- Expressed as pixels per cell rather than a screen-to-grid ratio on purpose:
-- a ratio silently breaks the moment the display resolution changes, whereas
-- cell size only depends on the font and dpi.
--
-- Re-measure if font_size changes: maximize a window and run `stty size`, then
-- repeat with window_padding raised by a known amount and divide the extra
-- padding by the rows lost.
local CELL_WIDTH_PX = 9
local CELL_HEIGHT_PX = 16

-- window_padding above, totalled per axis
local PADDING_X = 24
local PADDING_Y = 20

-- Never open smaller than the old fixed size, however small the screen is
local MIN_COLS = 85
local MIN_ROWS = 25

wezterm.on("gui-startup", function(cmd)
  local screen = wezterm.gui.screens().active
  local args = cmd or {}

  args.width = math.max(MIN_COLS, math.floor(
    (screen.width * WINDOW_WIDTH_FRACTION - PADDING_X) / CELL_WIDTH_PX))
  args.height = math.max(MIN_ROWS, math.floor(
    (screen.height * WINDOW_HEIGHT_FRACTION - PADDING_Y) / CELL_HEIGHT_PX))

  wezterm.mux.spawn_window(args)
end)

-- ==============================
-- TITLE BAR TOGGLE
-- ==============================
-- WezTerm has no built-in action for showing/hiding decorations, so this
-- flips `window_decorations` as a per-window config override. Bound to
-- Ctrl+Shift+Alt+T in the KEYBOARD section above.
-- A frame around the whole window, in the repo's own colour.
--
-- tmux cannot draw this: its pane borders exist only *between* panes, so there
-- is no option there for an outer edge -- the terminal has to draw it. But the
-- colour is tmux's to choose, since it is the accent dev-session.sh derives
-- from the repo name for the status badge, and wezterm knows nothing about
-- which repo a session is for.
--
-- So dev-session.sh sends the colour over as an OSC 1337 user variable and this
-- turns it into a per-window override. Being an override rather than a config
-- value is what keeps the border to `tmux dev` windows: a plain wezterm window
-- is never sent the variable and so never grows a border.
wezterm.on("user-var-changed", function(window, pane, name, value)
  if name ~= DEV_ACCENT_VAR then
    return
  end

  local overrides = window:get_config_overrides() or {}

  -- An empty value clears the border, so leaving a dev session can put the
  -- window back to unframed without restarting it.
  if value == "" then
    overrides.window_frame = nil
  else
    overrides.window_frame = {
      border_left_width = DEV_BORDER_WIDTH,
      border_right_width = DEV_BORDER_WIDTH,
      border_top_height = DEV_BORDER_WIDTH,
      border_bottom_height = DEV_BORDER_WIDTH,
      border_left_color = value,
      border_right_color = value,
      border_top_color = value,
      border_bottom_color = value,
    }
  end

  window:set_config_overrides(overrides)
end)

wezterm.on("toggle-titlebar", function(window)
  local overrides = window:get_config_overrides() or {}

  if overrides.window_decorations == DECORATIONS_ON then
    overrides.window_decorations = DECORATIONS_OFF
  else
    overrides.window_decorations = DECORATIONS_ON
  end

  window:set_config_overrides(overrides)
end)

return config

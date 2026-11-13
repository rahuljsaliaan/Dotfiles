-- Change the default Omarchy look'n'feel.

-- Opt another application in to Omarchy's standard transparency.
-- Find its class with: hyprctl clients
-- o.transparent_window("my-app")
-- o.transparent_window("my-app", "0.9 0.85") -- Custom active/inactive opacity.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })

-- ---------------------------------------------------------------------------
-- Personal look: rounded windows and Nerd Font title-bar buttons.
-- ---------------------------------------------------------------------------

hl.config({
  decoration = {
    rounding = 10,
  },
})

-- Floating-window title-bar buttons as VS Code-style Nerd Font (codicon)
-- window controls, coloured from the current theme (Tokyo Night: red close,
-- green maximize, yellow minimize).
--
-- Omarchy adds its own three buttons (× □ −) when the titlebar plugin loads,
-- and the plugin can add buttons but never remove them, so instead of adding
-- more, each of Omarchy's buttons is restyled as it is added. This file loads
-- before default.hypr.toggles, where Omarchy sets the titlebars up.
local function theme_color(key, fallback)
  local file = io.open(os.getenv("HOME") .. "/.local/state/omarchy/current/theme/colors.toml", "r")
  if file then
    for line in file:lines() do
      local name, hex = line:match('^%s*([%w_]+)%s*=%s*"#(%x%x%x%x%x%x)"')
      if name == key then
        file:close()
        return "rgb(" .. hex .. ")"
      end
    end
    file:close()
  end
  return fallback
end

-- Title-bar buttons: Linux order (minimize, maximize, close; close in the
-- top-right corner) as round Tokyo Night buttons.
--   at rest:  faint yellow / green / red circles (button_rest_opacity);
--   on hover: the same circles in full colour with bold Material symbols (-, box, x).
-- button_rest_opacity is not in Omarchy's titlebar plugin: it comes from a
-- personal build of it (~/.local/src/omarchy-hyprland-titlebars, branch
-- personal-rest-opacity) installed at ~/.local/lib/omarchy-hyprland-titlebars/,
-- which is loaded in place of Omarchy's copy below whenever it exists.
-- Rebuild it after a Hyprland update (see that repo's PERSONAL.md).
local titlebar_button_size = 16
local titlebar_symbol = "rgba(" .. theme_color("background", "rgb(1a1b26)"):match("%x%x%x%x%x%x") .. "ff)"

local titlebar_buttons = {
  ["×"] = { icon = "\u{F0156}", bg = theme_color("red", "rgb(f7768e)") },    -- close: bold x
  ["□"] = { icon = "\u{F0763}", bg = theme_color("green", "rgb(9ece6a)") },  -- maximize: bold square
  ["−"] = { icon = "\u{F05B0}", bg = theme_color("yellow", "rgb(e0af68)") }, -- minimize: bold line
}
-- Right-aligned: the first button added sits furthest right, so this gives
-- minimize, maximize, close from left to right.
local titlebar_order = { "×", "□", "−" }

local function restyle_titlebar_buttons(hyprbars)
  if not hyprbars or hyprbars.__personal_buttons then
    return
  end
  local add_button = hyprbars.add_button
  local pending, count = {}, 0
  hyprbars.add_button = function(button)
    local style = titlebar_buttons[button.icon]
    if not style then
      return add_button(button)
    end
    if not pending[button.icon] then
      count = count + 1
    end
    pending[button.icon] = button
    if count < #titlebar_order then
      return
    end
    for _, key in ipairs(titlebar_order) do
      local b, st = pending[key], titlebar_buttons[key]
      b.icon = st.icon
      b.bg_color = st.bg
      b.fg_color = titlebar_symbol
      b.size = titlebar_button_size
      add_button(b)
    end
    pending, count = {}, 0
  end
  hyprbars.__personal_buttons = true
end

local SYSTEM_TITLEBARS = "/usr/lib/omarchy-hyprland-titlebars/titlebars.so"
local PERSONAL_TITLEBARS = os.getenv("HOME") .. "/.local/lib/omarchy-hyprland-titlebars/titlebars.so"
local function personal_titlebars_present()
  local f = io.open(PERSONAL_TITLEBARS, "r")
  if f then f:close() return true end
  return false
end

local load_plugin = hl.plugin.load
hl.plugin.load = function(path, ...)
  if path == SYSTEM_TITLEBARS and personal_titlebars_present() then
    path = PERSONAL_TITLEBARS
  end
  local result = load_plugin(path, ...)
  restyle_titlebar_buttons(hl.plugin.hyprbars)
  return result
end

if hl.plugin.hyprbars then
  restyle_titlebar_buttons(hl.plugin.hyprbars)
end

-- Window borders to suit the glass: the focused window gets a soft, partly
-- see-through gradient of the theme's accent and magenta (Tokyo Night blue ->
-- purple) instead of the theme's solid line; unfocused windows a faint outline.
local function theme_rgba(key, fallback_hex, alpha)
  local color = theme_color(key, "rgb(" .. fallback_hex .. ")")
  return "rgba(" .. color:match("%x%x%x%x%x%x") .. alpha .. ")"
end

local soft_active_border = {
  colors = { theme_rgba("accent", "7aa2f7", "aa"), theme_rgba("magenta", "ad8ee6", "aa") },
  angle = 45,
}
local soft_inactive_border = theme_rgba("muted", "414868", "55")

hl.config({
  general = {
    col = { active_border = soft_active_border, inactive_border = soft_inactive_border },
  },
  group = {
    col = { border_active = soft_active_border, border_inactive = soft_inactive_border },
  },
})

-- Nautilus stays glassy everywhere. Glassy windows fade it to 0.75 (GTK draws
-- it solid), but on a floating workspace Omarchy forces windows to 1.0, and the
-- two rules took turns: every folder change flipped it between glass and solid.
-- One overriding value settles it, added once the rest of the config has loaded
-- so it comes after both of those rules.
hl.timer(function()
  o.window("org\\.gnome\\.Nautilus", { opacity = "0.80 override 0.80 override" })
end, { timeout = 1, type = "oneshot" })

-- Floating workspaces: a window opening onto an empty one sits exactly in the
-- middle. Omarchy steps each new window up to 48px off-centre so a run of them
-- does not stack exactly; with nothing else on the workspace there is nothing
-- to step away from. Only windows the floating mode placed are moved (not
-- dialogs or apps that float on their own), once Omarchy has placed them.
local function placed_by_floating_mode(window)
  for _, tag in ipairs(window.tags or {}) do
    local name = tag:gsub("%*$", "")
    if name == "omarchy-mode-opened" or name == "omarchy-mode-floated" then
      return true
    end
  end
  return false
end

hl.on("window.open", function(opened)
  local address = opened.address
  hl.timer(function()
    local window
    for _, w in ipairs(hl.get_windows()) do
      if w.address == address then window = w break end
    end
    if not window or not window.floating or not window.workspace or not placed_by_floating_mode(window) then
      return
    end
    for _, other in ipairs(hl.get_workspace_windows(window.workspace.id) or {}) do
      if other.address ~= address and other.mapped and not other.hidden then
        return
      end
    end
    hl.dispatch(hl.dsp.window.center({ window = window }))
  end, { timeout = 80, type = "oneshot" })
end)

-- Frosted dock: blur what is behind the dock's see-through glass plate
-- (drawn in ~/.config/omarchy/plugins/rahulj.dock/DockWindow.qml). ignore_alpha
-- keeps the blur to the plate itself, not the dock's invisible surroundings.
hl.layer_rule({
  match = { namespace = "^omarchy-dock$" },
  blur = true,
  ignore_alpha = 0.2,
})

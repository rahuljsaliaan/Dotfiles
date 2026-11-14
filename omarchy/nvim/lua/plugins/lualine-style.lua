-- The status line in the Starship prompt's style, so the editor and the shell
-- read as one design: the mode on one rounded pill (like Starship's folder
-- pill and the bar's active workspace), then coloured icons and plain text on
-- the terminal's own (glass) background, groups split by a dim "│", and no
-- powerline arrows or clock (the top bar has one).
--
-- Colours come from the current Omarchy theme's colors.toml, the same keys the
-- Starship template uses (~/.config/omarchy/themed/starship.toml.tpl), so the
-- two always agree, on any theme. They are re-read whenever the colorscheme
-- changes, which Omarchy's theme hot-reload triggers.
local theme_file = vim.fn.expand("~/.local/state/omarchy/current/theme/colors.toml")

-- Tokyo Night's values, used when a key is missing.
local fallback = {
  background = "#1a1b26", foreground = "#a9b1d6", dark_foreground = "#565f89",
  bright_foreground = "#c0caf5", accent = "#7aa2f7", red = "#f7768e",
  yellow = "#e0af68", green = "#9ece6a", cyan = "#7dcfff", magenta = "#bb9af7",
  bright_magenta = "#bb9af7",
}

local cache
local function palette()
  if cache then return cache end
  cache = vim.deepcopy(fallback)
  local f = io.open(theme_file, "r")
  if f then
    for line in f:lines() do
      local key, hex = line:match('^%s*([%w_]+)%s*=%s*"(#%x%x%x%x%x%x)"')
      if key then cache[key] = hex end
    end
    f:close()
  end
  return cache
end
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("LualineStarshipPalette", { clear = true }),
  callback = function() cache = nil end,
})

local function c(key) return palette()[key] end
local function fg(key) return function() return { fg = c(key) } end end

-- Lualine theme: each mode's pill in its colour with the theme background as
-- text; every other section transparent, its separators in the dim colour.
local function theme()
  local function mode(key)
    return {
      a = { bg = c(key), fg = c("background"), gui = "bold" },
      b = { bg = "None", fg = c("dark_foreground") },
      c = { bg = "None", fg = c("dark_foreground") },
    }
  end
  return {
    normal = mode("accent"),
    insert = mode("green"),
    visual = mode("magenta"),
    replace = mode("red"),
    command = mode("cyan"),
    terminal = mode("green"),
    inactive = {
      a = { bg = "None", fg = c("dark_foreground") },
      b = { bg = "None", fg = c("dark_foreground") },
      c = { bg = "None", fg = c("dark_foreground") },
    },
  }
end

-- The pill's colour for the current mode, for its rounded caps.
local mode_key = { n = "accent", i = "green", v = "magenta", V = "magenta", ["\22"] = "magenta",
  R = "red", c = "cyan", t = "green", s = "magenta", S = "magenta" }
local function cap(glyph)
  return {
    function() return glyph end,
    color = function()
      local m = vim.api.nvim_get_mode().mode:sub(1, 1)
      return { fg = c(mode_key[m] or "accent"), bg = "None" }
    end,
    separator = "",
    padding = 0,
  }
end

-- The file path: folders dim, the file name bright, a modified file in the
-- theme's yellow, as Starship colours its segments.
local function path_highlights()
  vim.api.nvim_set_hl(0, "LualineStarshipDir", { fg = c("dark_foreground") })
  vim.api.nvim_set_hl(0, "LualineStarshipFile", { fg = c("bright_foreground"), bold = true })
  vim.api.nvim_set_hl(0, "LualineStarshipModified", { fg = c("yellow"), bold = true })
end
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("LualineStarshipPath", { clear = true }),
  callback = function() cache = nil; path_highlights() end,
})
path_highlights()

return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    opts.options = opts.options or {}
    opts.options.theme = theme
    opts.options.section_separators = { left = "", right = "" }
    -- Drawn in each section's (dim) colour between its components: the "│"
    -- that Starship puts between its segments.
    opts.options.component_separators = { left = "│", right = "│" }

    local s = opts.sections
    s.lualine_a = {
      cap("\u{e0b6}"),
      { "mode", separator = "", padding = 1 },
      cap("\u{e0b4}"),
    }
    s.lualine_b = {}

    -- Branch first, as in Starship: its git icon in the bright purple, the
    -- name in bright text. Then LazyVim's root, diagnostics, filetype icon and
    -- path (LazyVim's first four; anything it adds after them, such as the
    -- Trouble symbols, is kept), the path with the highlights above.
    local rest = s.lualine_c or {}
    s.lualine_c = {
      { "branch", icon = { "\u{f418}", color = fg("bright_magenta") }, color = fg("bright_foreground") },
      rest[1], rest[2], rest[3],
      { LazyVim.lualine.pretty_path({
          directory_hl = "LualineStarshipDir",
          filename_hl = "LualineStarshipFile",
          modified_hl = "LualineStarshipModified",
        }) },
    }
    for i = 5, #rest do
      table.insert(s.lualine_c, rest[i])
    end

    -- Git changes in Starship's meanings: added green, modified yellow,
    -- removed red.
    for _, component in ipairs(s.lualine_x or {}) do
      if type(component) == "table" and component[1] == "diff" then
        component.diff_color = {
          added = fg("green"),
          modified = fg("yellow"),
          removed = fg("red"),
        }
      end
    end

    -- Position as plain text, the percentage dimmed; no clock.
    s.lualine_y = {
      { "progress", color = fg("dark_foreground"), separator = " ", padding = { left = 1, right = 0 } },
      { "location", color = fg("bright_foreground"), padding = { left = 0, right = 1 } },
    }
    s.lualine_z = {}
  end,
}

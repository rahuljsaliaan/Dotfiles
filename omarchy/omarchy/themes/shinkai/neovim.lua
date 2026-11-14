-- Shinkai for Neovim: Omarchy's aether.nvim with the theme's palette, plus the
-- syntax colours Shinkai was designed with. Aether puts its own choices on
-- the syntax groups (pale bright-purple keywords, the dim muted grey for
-- comments, bright cyan fields, bright yellow constants, bold functions and
-- types), which read as a different theme; the overrides below give the
-- Material Ocean reading instead:
--
--   keywords purple · functions blue · strings green · numbers, constants and
--   parameters orange · types yellow · operators cyan · built-in functions
--   and errors red · comments the readable dim grey · fields, variables and
--   punctuation plain text
--
-- This file is shipped by the theme, so Omarchy does not generate one from
-- colors.toml: keep the colours below in step with it. The see-through
-- background comes from ~/.config/nvim/plugin/after/transparency.lua.
return {
  {
    "omacom/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg = "#0c1523",
        dark_bg = "#09111c",
        darker_bg = "#070b12",
        lighter_bg = "#162740",

        fg = "#a6accd",
        dark_fg = "#525975",
        light_fg = "#b8bedd",
        bright_fg = "#c8d3f5",
        muted = "#464b5d",

        red = "#f07178",
        yellow = "#ffcb6b",
        orange = "#f78c6c",
        green = "#c3e88d",
        cyan = "#89ddff",
        blue = "#82aaff",
        magenta = "#c792ea",
        brown = "#8f5f54",

        bright_red = "#ff898e",
        bright_yellow = "#fed282",
        bright_green = "#ccf196",
        bright_cyan = "#9ce1fe",
        bright_blue = "#8cb1fe",
        bright_magenta = "#dba5fe",

        accent = "#82aaff",
        cursor = "#c8d3f5",
        foreground = "#a6accd",
        background = "#0c1523",
        selection = "#1b3457",
        selection_foreground = "#c8d3f5",
        selection_background = "#1b3457",
      },
      -- Flat syntax, no italics or bold, as in the theme's design.
      styles = {
        comments = {},
        keywords = {},
        functions = {},
        variables = {},
      },
      on_highlights = function(hl, c)
        -- Comments: dark_fg, a step brighter than aether's muted grey.
        hl.Comment = { fg = c.dark_fg }
        hl.Todo = { fg = c.yellow, bold = true }
        hl["@comment.todo"] = { fg = c.yellow, bold = true }

        -- Keywords, in every flavour, purple.
        for _, group in ipairs({
          "Keyword", "Statement", "Conditional", "Repeat", "Exception", "Define",
          "Include", "StorageClass",
          "@keyword", "@keyword.function", "@keyword.return", "@keyword.operator",
          "@keyword.conditional", "@keyword.repeat", "@keyword.exception",
          "@keyword.import", "@keyword.storage", "@keyword.modifier", "@keyword.coroutine",
        }) do
          hl[group] = { fg = c.purple }
        end

        -- Functions blue, built-ins red.
        for _, group in ipairs({ "Function", "@function", "@function.call", "@function.method", "@function.method.call" }) do
          hl[group] = { fg = c.blue }
        end
        hl["@function.builtin"] = { fg = c.red }
        hl["@constructor"] = { fg = c.yellow }

        -- Values: numbers, booleans, constants and parameters orange.
        for _, group in ipairs({ "Number", "Float", "Boolean", "Constant", "@constant", "@constant.builtin", "@number", "@boolean", "@variable.parameter" }) do
          hl[group] = { fg = c.orange }
        end
        hl.String = { fg = c.green }

        -- Types yellow, not bold.
        hl.Type = { fg = c.yellow }
        hl["@type"] = { fg = c.yellow }
        hl["@type.builtin"] = { fg = c.yellow }

        -- Operators cyan.
        hl.Operator = { fg = c.cyan }
        hl["@operator"] = { fg = c.cyan }

        -- Names and punctuation stay plain text; the module table a touch brighter.
        for _, group in ipairs({ "Identifier", "@property", "@variable.member", "@variable", "@punctuation.bracket", "@punctuation.delimiter" }) do
          hl[group] = { fg = c.fg }
        end
        hl["@variable.builtin"] = { fg = c.red }
        hl["@module"] = { fg = c.bright_fg }
        -- Built-in namespaces (vim, std) read as plain names, as in the design.
        hl["@module.builtin"] = { fg = c.fg }
        hl["@namespace.builtin"] = { fg = c.fg }
      end,
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}

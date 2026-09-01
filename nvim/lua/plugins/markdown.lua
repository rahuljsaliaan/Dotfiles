-- In-buffer markdown rendering: headings, tables, code blocks and emphasis
-- drawn as they mean rather than as raw punctuation. Worth it here mainly for
-- CHEATSHEET.md, which is mostly wide tables and reads as pipe soup otherwise.
--
-- This is the one plugin out of LazyVim's markdown extra, added on its own on
-- purpose. The rest of that extra wires prettier into conform, and autoformat
-- is on by default (LazyVim's format.lua treats an unset `vim.g.autoformat` as
-- true) -- so the first save of CHEATSHEET.md would reflow every hand-wrapped
-- line in the file. The extra also pulls in marksman, markdownlint-cli2 and a
-- browser preview, none of which earn their keep on two markdown files.

return {
  {
    "MeanderingProgrammer/render-markdown.nvim",

    -- Loads only for markdown buffers, so it costs nothing elsewhere.
    ft = { "markdown" },

    -- nvim-treesitter and mini.icons are both already in this config, so they
    -- are left off `dependencies` -- same as LazyVim's own spec does.

    opts = {
      -- Mostly LazyVim's own options for this plugin, so switching its markdown
      -- extra on later would not change how anything renders.
      code = {
        sign = false,
        width = "block",
        right_pad = 1,
      },

      -- The exception. LazyVim sets `icons = {}` here, which leaves the literal
      -- `###` sitting in front of every heading; the default icons conceal the
      -- hashes and put a per-level glyph there instead, which is the whole
      -- point. Compared side by side on this repo's CHEATSHEET.md:
      --   icons = {}  ->  "### Toggles"
      --   default     ->  "󰲥 Toggles"
      -- The glyphs need a Nerd Font, which wezterm.lua already sets.
      heading = {
        sign = false,
      },
      checkbox = {
        enabled = false,
      },
    },

    config = function(_, opts)
      require("render-markdown").setup(opts)

      -- Lowercase `um`, which is also the key LazyVim's extra binds this to --
      -- so enabling the extra later lands on the same key rather than a second
      -- one. No Shift, unlike the minimap binding that used to live at `uM`.
      Snacks.toggle({
        name = "Render Markdown",
        get = require("render-markdown").get,
        set = require("render-markdown").set,
      }):map("<leader>um")
    end,
  },
}

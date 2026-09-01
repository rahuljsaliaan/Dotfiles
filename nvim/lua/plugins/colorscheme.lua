-- Let wezterm's transparency reach the editor.
--
-- wezterm runs at window_background_opacity 0.88, but a cell only keeps that
-- translucency while its background is the terminal's *default* colour -- any
-- explicit background is painted solid. tokyonight sets one on Normal, so the
-- editor covered its share of the window in opaque #222436 while the panes
-- beside it stayed see-through. Since the editor is most of a `tmux dev`
-- window, that read as "transparency is broken" rather than "one pane is
-- opaque".
--
-- `transparent` stops it painting Normal at all, leaving those cells on the
-- terminal default and so on wezterm's 0.88. The colour on screen is the same
-- #222436 either way -- it is wezterm's background, and it is tokyonight moon's
-- background -- but now the desktop shows through it.
--
-- LazyVim already ships this plugin, and lazy.nvim merges opts tables, so
-- naming it again here adds to that spec rather than replacing it. The style
-- is chosen elsewhere and is left alone -- `:colorscheme` still reports
-- tokyonight-moon after this.
return {
  {
    "folke/tokyonight.nvim",
    opts = {
      transparent = true,

      -- `transparent` only covers Normal. These are separate windows with
      -- their own highlight groups, which would otherwise stay solid and show
      -- up as opaque rectangles over a translucent editor -- the sidebar the
      -- snacks explorer lives in, and every floating window (pickers,
      -- which-key, LSP hover, diagnostics).
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },
}

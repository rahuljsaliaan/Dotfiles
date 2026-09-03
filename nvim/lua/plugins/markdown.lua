-- In-buffer markdown rendering: headings, tables, code blocks and emphasis
-- drawn as they mean rather than as raw punctuation. Worth it here mainly for
-- CHEATSHEET.md, which is mostly wide tables and reads as pipe soup otherwise.
--
-- LazyVim's `lang.markdown` extra is enabled (nvim/lazyvim.json) and already
-- declares this plugin, so what follows overrides the extra's own spec rather
-- than adding a plugin on its own. Everything here except the `heading` block
-- restates what the extra sets, kept verbatim so the deliberate difference is
-- one field wide and stays easy to re-check against upstream.
--
-- The extra also brings markdown-preview.nvim on `<leader>cp`. That is what
-- renders mermaid: render-markdown has no mermaid support at all, so a
-- diagram stays a plain code block in the buffer whatever is configured here.
--
-- The reflow hazard that once argued against the extra does not materialise.
-- It points conform at prettier, markdownlint-cli2 and markdown-toc, but
-- prettier is not installed and the other two are gated -- markdown-toc on a
-- `<!-- toc -->` marker no file here carries, markdownlint-cli2 on live
-- markdownlint diagnostics. Saving CHEATSHEET.md leaves it byte for byte
-- unchanged. Installing prettier would end that, and is the thing to watch.

return {
  {
    "MeanderingProgrammer/render-markdown.nvim",

    -- Loads only for markdown buffers, so it costs nothing elsewhere.
    ft = { "markdown" },

    -- nvim-treesitter and mini.icons are both already in this config, so they
    -- are left off `dependencies` -- same as LazyVim's own spec does.

    opts = {
      -- The extra's own options for this plugin, restated so the one
      -- deliberate difference below stands out against them.
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

      -- Lowercase `um`, the key LazyVim's extra binds this to as well. Since
      -- the extra is on, this whole `config` duplicates the one upstream would
      -- run; lazy.nvim keeps only the last `config` for a plugin, so it stays
      -- a single toggle rather than two. No Shift, unlike the minimap binding
      -- that used to live at `uM`.
      Snacks.toggle({
        name = "Render Markdown",
        get = require("render-markdown").get,
        set = require("render-markdown").set,
      }):map("<leader>um")
    end,
  },

  {
    -- markdown-preview.nvim itself comes from the `lang.markdown` extra; this
    -- entry only changes how the page is opened, so `optional` leaves it inert
    -- rather than pulling the plugin in on its own if the extra ever goes off.
    "iamcco/markdown-preview.nvim",
    optional = true,

    init = function()
      -- `<leader>cp` is what renders mermaid -- render-markdown has no support
      -- for it, so a diagram is only ever a code block in the buffer. Left
      -- alone the preview arrives as an ordinary tab in whatever browser
      -- xdg-open picks, where the file being edited is indistinguishable from
      -- everything else already open. Chromium's `--app=` opens the same URL
      -- as a bare window instead -- no tab strip, address bar or bookmarks --
      -- which reads as a preview pane beside the editor.
      --
      -- The flag has to travel through `g:mkdp_browserfunc` rather than
      -- `g:mkdp_browser`: the latter reaches the server as a bare application
      -- name with nowhere to put an argument (app/server.js passes it straight
      -- to `openUrl`). `browserfunc` names a Vim function that the server
      -- calls with the URL, and is checked first, so it wins outright.
      --
      -- Brave is this machine's browser and inherits the flag from Chromium.
      -- Elsewhere -- a machine install.sh has linked this onto without it --
      -- fall back to xdg-open, so the preview still opens, just as a tab.
      vim.g.mkdp_browserfunc = "MkdpOpenPopup"

      vim.cmd([[
        function! MkdpOpenPopup(url) abort
          if executable('brave-browser')
            call jobstart(['brave-browser', '--app=' . a:url, '--window-size=900,1100'])
          else
            call jobstart(['xdg-open', a:url])
          endif
        endfunction
      ]])
    end,
  },
}

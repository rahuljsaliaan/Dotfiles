-- Alt + S (S for select) grows the Treesitter selection, as LazyVim's
-- Ctrl + Space does. Ctrl + Space is the tmux and herdr prefix, so inside them
-- Neovim never gets it; Alt + S is free in tmux, herdr and Neovim. Keep pressing
-- Alt + S (or Ctrl + Space outside tmux) to grow it, Backspace to shrink it.
return {
  "folke/flash.nvim",
  keys = {
    {
      "<M-s>",
      mode = { "n", "o", "x" },
      function()
        require("flash").treesitter({
          actions = {
            ["<M-s>"] = "next",
            ["<c-space>"] = "next",
            ["<BS>"] = "prev",
          },
        })
      end,
      desc = "Treesitter Incremental Selection (Alt+S)",
    },
  },
}

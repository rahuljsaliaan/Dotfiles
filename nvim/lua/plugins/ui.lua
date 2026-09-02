-- UI overrides on top of LazyVim's defaults.

-- Below this many columns there is not enough room for a 40-column sidebar and
-- a usable editor beside it, so the explorer takes the whole window instead.
-- 120 is the same threshold snacks uses for its own responsive picker layout.
local SIDEBAR_MIN_COLUMNS = 120

local function explorer_fills_window()
  return vim.o.columns < SIDEBAR_MIN_COLUMNS
end

-- Close the current file and return to the explorer. Used by `q` while the
-- explorer is in full-window mode, where the file is the only window and a
-- plain quit would exit Neovim outright with nothing to fall back to.
local function back_to_explorer()
  local buf = vim.api.nvim_get_current_buf()
  Snacks.explorer()
  -- Drop the file buffer once the explorer is up, so `q` behaves like going
  -- back rather than leaving a growing pile of hidden buffers behind.
  if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified == false then
    pcall(vim.api.nvim_buf_delete, buf, {})
  end
end

-- Open the file under the cursor, and when the explorer is covering the whole
-- window, get the explorer out of the way so the file is actually visible.
-- Directories are left alone -- for those, confirm just toggles open/closed.
--
-- Setting `jump.close` before delegating means snacks closes the picker itself
-- and then loads the buffer into the window underneath, rather than us closing
-- it afterwards and fighting over which window ends up focused.
local function confirm_and_close_if_full(picker, item, action)
  local full_window = item and not item.dir and explorer_fills_window()
  if full_window then
    picker.opts.jump.close = true
  end

  require("snacks.explorer.actions").actions.confirm(picker, item, action)

  -- Closing the explorer leaves the file as the only window, so a plain quit
  -- would exit Neovim with nothing to fall back to. Bind `q` to go back --
  -- but buffer-locally, on just this file, so the global `q` (macro recording)
  -- is never touched. A global mapping that tried to fall through to the
  -- native `q` proved unreliable.
  if full_window then
    vim.schedule(function()
      local buf = vim.api.nvim_get_current_buf()
      if vim.bo[buf].buftype == "" then
        vim.keymap.set("n", "q", back_to_explorer, {
          buffer = buf,
          desc = "Back to Explorer",
        })
      end
    end)
  end
end

-- NOTE: this is deliberately *not* called `confirm`. The explorer source runs
-- `Snacks.config.merge(opts, { actions = { confirm = ... } })` in its own
-- setup, and that merge wins over user config -- so overriding `confirm`, or
-- the top-level `confirm` shortcut, is silently discarded. A custom action
-- name survives, and the keymaps below point at it instead. That same merge
-- does not touch `win`, so these key overrides stick.
local CONFIRM_ACTION = "confirm_or_close_explorer"

-- Directories excluded outright rather than merely hidden. Once gitignored
-- paths are in scope (see the sources below) these are what would flood the
-- explorer and make `fd`/`rg` walk tens of thousands of files, and neither is
-- edited by hand anyway. `exclude` has no runtime toggle the way `hidden` and
-- `ignored` do, so this list stays short.
local EXCLUDED_DIRS = { ".git", "node_modules" }

return {
  {
    "folke/snacks.nvim",
    opts = {
      -- Turn off the LazyVim start screen, so opening nvim with no file lands
      -- on an empty buffer rather than the dashboard.
      dashboard = { enabled = false },

      picker = {
        layouts = {
          -- Full-window explorer: no preview, no border, nothing beside it.
          explorer_full = {
            layout = {
              backdrop = false,
              width = 0,
              height = 0,
              border = "none",
              box = "vertical",
              { win = "input", height = 1, border = "bottom" },
              { win = "list", border = "none" },
            },
          },
        },

        sources = {
          explorer = {
            -- snacks filters out dotfiles (`hidden`) and gitignored paths
            -- (`ignored`) by default, which is why files like `.env` or a
            -- gitignored `temp/` cannot be opened from here -- they are never
            -- listed in the first place. `H` and `I` still toggle each filter
            -- while the explorer is open; this only moves the starting point.
            hidden = true,
            ignored = true,
            exclude = EXCLUDED_DIRS,

            layout = {
              -- Wide enough: sidebar on the right, editor alongside it.
              -- Too narrow: the explorer fills the window on its own, so no
              -- empty editor pane is left sitting next to it.
              --
              -- "right" is snacks' own preset for this -- it is defined as the
              -- sidebar preset with `position = "right"` -- so there is no need
              -- to hand-override the nested layout table.
              preset = function()
                return explorer_fills_window() and "explorer_full" or "right"
              end,
              preview = false,
            },

            actions = {
              [CONFIRM_ACTION] = confirm_and_close_if_full,
            },

            win = {
              list = {
                keys = {
                  ["<CR>"] = CONFIRM_ACTION,
                  ["l"] = CONFIRM_ACTION,
                  ["<2-LeftMouse>"] = CONFIRM_ACTION,
                },
              },
              input = {
                keys = {
                  ["<CR>"] = { CONFIRM_ACTION, mode = { "n", "i" } },
                },
              },
            },
          },

          -- Same visibility for the pickers, so anything the explorer shows can
          -- also be found by name (`<leader>ff`) and grepped (`<leader>sg`).
          -- `files` has to be set here rather than once at the `picker` level:
          -- its own source defaults are `hidden = false, ignored = false`, and
          -- source config beats top-level user config in snacks' merge order,
          -- so a top-level override would silently miss it -- and with it the
          -- `smart` picker (`<leader><space>`), which reuses `files`.
          files = { hidden = true, ignored = true, exclude = EXCLUDED_DIRS },
          grep = { hidden = true, ignored = true, exclude = EXCLUDED_DIRS },

          -- `<leader>ss` -- the equivalent of VS Code's Ctrl+Shift+O, a
          -- filterable list of the functions and other symbols in this file.
          --
          -- Snacks' default for it is a floating box with its own little
          -- preview pane off to one side, which is the part that feels worse
          -- than VS Code: you read the symbol in a cramped second view instead
          -- of watching the real editor move. `preview = "main"` previews into
          -- the actual editor window, so moving down the list scrolls the file
          -- behind it and highlights the symbol in place -- what VS Code does.
          -- The `lines` source already ships this way; symbols does not.
          --
          -- `ivy` puts the list along the bottom rather than over the middle
          -- of the file, so the code being previewed is not what gets covered.
          lsp_symbols = {
            layout = { preset = "ivy", preview = "main" },
          },
        },
      },
    },
  },

  {
    -- LazyVim sets which-key's "helix" preset, which anchors the menu to the
    -- right edge of the screen -- the same edge the explorer above lives on, so
    -- pressing Space appears to open a menu inside the sidebar. "modern" is a
    -- floating box at the bottom instead: it reads as sitting over the editor
    -- rather than as part of the explorer, and the bottom is the cheap edge
    -- here since only the status line occupies it.
    --
    -- "classic" is also at the bottom but spans the full width, which puts it
    -- flush under the explorer and back to looking like one wide strip.
    "folke/which-key.nvim",
    opts = {
      preset = "modern",

      -- The preset caps the popup at 25 rows and 90% of the width, which was
      -- enough before the test and debug extras added two more groups: past
      -- that the box fills and the rest is only reachable by scrolling, which
      -- is invisible unless you already know it is there. A fraction rather
      -- than a row count so it keeps its proportion on any terminal -- values
      -- below 1 are read as a share of the screen (see Layout.dim).
      win = {
        width = 0.95,
        height = { min = 4, max = 0.8 },
      },

      -- Wider columns so a long description is not truncated to make room for
      -- a column that would then be half empty.
      layout = { width = { min = 24 } },
    },
  },
}

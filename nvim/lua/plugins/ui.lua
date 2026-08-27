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
            layout = {
              -- Wide enough: the usual left sidebar with the editor alongside.
              -- Too narrow: the explorer fills the window on its own, so no
              -- empty editor pane is left sitting next to it.
              preset = function()
                return explorer_fills_window() and "explorer_full" or "sidebar"
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
        },
      },
    },
  },

}

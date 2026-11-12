-- Diagnostics that stay inside the editor, and a type checker that only speaks
-- when it has something worth saying.

-- Virtual text is drawn as a single unwrapped line at the end of the code line,
-- so a long message simply runs off the right edge -- under the explorer, and
-- off the window entirely. Capping it keeps every diagnostic inside the pane;
-- the full text is one keypress (or one cursor move) away, below.
local VIRTUAL_TEXT_MAX = 60

-- Collapse newlines and runs of spaces first: basedpyright's longer messages
-- are multi-line, and virtual text renders "\n" as a literal escape.
local function truncate(diagnostic)
  local message = diagnostic.message:gsub("%s+", " ")

  if vim.fn.strdisplaywidth(message) > VIRTUAL_TEXT_MAX then
    message = vim.fn.strcharpart(message, 0, VIRTUAL_TEXT_MAX - 1) .. "…"
  end

  return message
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        -- Short form on every line that has a diagnostic, so the gutter is not
        -- the only clue that something is wrong further down the file.
        virtual_text = {
          spacing = 4,
          source = "if_many",
          prefix = "●",
          format = truncate,

          -- Off on the line the cursor is on, where virtual_lines below is
          -- already showing the whole message -- otherwise it is said twice.
          current_line = false,
        },

        -- The full message, wrapped onto its own line beneath the code and
        -- indented under the symbol it belongs to. Only for the current line:
        -- every line at once pushes the file apart as the cursor moves.
        virtual_lines = { current_line = true },
      },

      servers = {
        basedpyright = {
          settings = {
            basedpyright = {
              analysis = {
                -- basedpyright defaults to "recommended", which is strict:
                -- untyped test fixtures draw a warning per parameter, and an
                -- existing codebase lights up on first open. "standard"
                -- matches upstream pyright -- real type errors, without the
                -- running commentary on missing annotations.
                typeCheckingMode = "standard",
              },
            },
          },
        },
      },
    },
  },
}

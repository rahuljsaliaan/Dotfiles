-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Ctrl+Backspace deletes the word before the cursor, as it does in VS Code and
-- most editors. Insert mode already had this on Ctrl+W; this only puts it where
-- the hand reaches for it.
--
-- Mapped as <C-h>, not <C-BS>: in the classic terminal encoding Ctrl+Backspace
-- is not a distinct key -- wezterm sends 0x08, which is what <C-h> means -- so
-- <C-BS> would never match. Nvim and wezterm both speak the kitty keyboard
-- protocol, which would make the real key bindable, but turning that on changes
-- the encoding of every modified key and is not worth it for one binding.
--
-- Insert and command mode only. <C-h> in normal mode is LazyVim's "window to
-- the left" and is left alone.
vim.keymap.set("i", "<C-h>", "<C-w>", { desc = "Delete word before cursor" })
vim.keymap.set("c", "<C-h>", "<C-w>", { desc = "Delete word before cursor" })

-- The forward half, which nvim has no built-in for: delete from the cursor to
-- the end of the word ahead. <C-o> runs one normal-mode command and returns to
-- insert, so the cursor is left where the deleted text began.
vim.keymap.set("i", "<C-Del>", "<C-o>dw", { desc = "Delete word after cursor" })

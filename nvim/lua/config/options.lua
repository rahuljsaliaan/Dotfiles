-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- LazyVim ships `wrap = false`, so a long line runs off the right edge and the
-- rest of it can only be reached by scrolling sideways. That is worst with the
-- explorer open, since the editor is then ~40 columns narrower. Soft-wrap
-- instead, so nothing sits past the edge. This is display-only -- no line break
-- is written to the file, and the buffer is byte-for-byte unchanged.
--
-- LazyVim already sets `linebreak` (breaks at spaces and punctuation instead of
-- mid-word) and maps `j`/`k` to `gj`/`gk` without a count, so wrapped lines are
-- both broken sensibly and walked one screen row at a time. Both were dormant
-- while `wrap` was off. `Space` `u` `w` still toggles this per window.
vim.opt.wrap = true

-- A wrapped row restarts at column 0 by default, which reads as a new statement
-- rather than a continuation -- the thing that makes wrapped *code* (as opposed
-- to prose) hard to follow. Keep the row on its own indent, push it 2 further
-- so it cannot be mistaken for a sibling line, and mark it.
vim.opt.breakindent = true
vim.opt.breakindentopt = "shift:2"
vim.opt.showbreak = "↳ "

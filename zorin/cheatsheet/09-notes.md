# Notes

Why a few things behave the way they do here.

> **★ marks a binding custom to this repo.** Everything unmarked is an
> upstream default. Neovim's leader key is `Space`, written out rather than
> as `<leader>` because that is what you press.

[← Back to the index](../CHEATSHEET.md)

---

- Neovim shows **relative line numbers**, which is what makes `5j` / `12k`
  practical — read the number beside the line you want and prefix the motion.
- The explorer is **responsive** ★: below 120 columns it takes the whole window
  (with `q` to come back), and at 120+ it is a right-hand sidebar with the
  editor beside it. Resize and press `Space` `e` again to see the other layout.
- The explorer and the file pickers show **dotfiles and gitignored files** ★
  — `.env`, a gitignored `temp/` — since a file that is never listed is a
  file you cannot open. `H` and `I` turn each filter back on for the session.
  `.git` and `node_modules` are left out of every list, with no toggle.
- Long lines **soft-wrap** ★ rather than running off the right edge — which
  matters most with the explorer open and the editor ~40 columns narrower.
  Wrapping happens at spaces, a wrapped row keeps its indent and is marked
  `↳`, and the file on disk is untouched — no line break is written. `Space`
  `u` `w` turns it off for the current window.
- The blue **pane border** cannot tell you where focus is when a window is split
  in two: tmux draws one divider and colours it as a border of the active pane,
  which with two panes it is either way. The heavy line makes the panes read
  as separate regions, but what says *which* has focus is the `▌` in its header.
  This is also why panes are not tinted by role — one shared divider cannot
  report two panes, and the headers already say what each one is in words.
- Markdown files **render in place** ★ — headings get a glyph, tables become
  ruled grids, code blocks a background. The line under the cursor drops back to
  raw source so it stays editable, which is why one row of a table always looks
  unrendered. `Space` `u` `m` toggles it. Formatting is deliberately not part of
  this: nothing reflows the hand-wrapped prose in this file on save.
- Keys in this file were extracted from the live config rather than written from
  memory. If something here is wrong, `Space` `s` `k` is the source of truth.

---

[← Neovim — git, toggles and the sharp end](08-neovim-git-and-more.md) · [Index](../CHEATSHEET.md)

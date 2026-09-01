# Neovim — git, toggles and the sharp end

Hunks and lazygit, the `Space` `u` toggles, and the keys worth graduating to.

> **★ marks a binding custom to this repo.** Everything unmarked is an
> upstream default. Neovim's leader key is `Space`, written out rather than
> as `<leader>` because that is what you press.

[← Back to the index](../CHEATSHEET.md)

---

### Git

| Keys | Action | Notes |
| --- | --- | --- |
| `Space` `g` `g` | Lazygit | Needs `lazygit` (installed via mise) |
| `q` | Quit lazygit, closing the float | Press again to back out of a panel |
| `]h` / `[h` | Next / previous changed hunk | |
| `Space` `g` `h` `s` | Stage hunk | Works on a visual selection |
| `Space` `g` `h` `r` | Reset hunk | |
| `Space` `g` `h` `p` | Preview the hunk inline | |
| `Space` `g` `h` `b` | Blame this line | |
| `Space` `g` `h` `B` | Blame the whole buffer | |
| `Space` `g` `h` `d` | Diff this file | |
| `Space` `g` `b` | Blame this line (quick) | Simpler than the `gh` variants above |
| `Space` `g` `l` | Browse commit log | |
| `Space` `g` `d` | Diff (hunks) | |
| `Space` `g` `s` | Git status | |
| `Space` `g` `f` | History of the current file | |

### Toggles

`Space` `u` then:

| Key | Toggles |
| --- | --- |
| `l` / `L` | Line numbers / relative numbers |
| `w` | Line wrap |
| `m` ★ | Markdown rendering |
| `s` | Spell check |
| `d` | Diagnostics |
| `g` | Indent guides |
| `c` | Conceal level |
| `b` | Dark / light background |
| `C` | Pick a colorscheme |
| `n` | Dismiss all notifications |

### Advanced

| Keys | Action | Notes |
| --- | --- | --- |
| `s` | Flash jump — type 2 chars, then the label | Fastest way across a file |
| `S` | Flash by syntax node | Jump to a function, block, string |
| `Ctrl` `Space` | Grow the selection by syntax node | Press again to widen |
| `Space` `q` `s` | Restore the session for this directory | persistence.nvim |
| `Space` `q` `l` | Restore the last session | |
| `Space` `.` | Toggle a scratch buffer | Per-project scratchpad |
| `Space` `S` | Pick a scratch buffer | |
| `Ctrl` `/` | Toggle a terminal | `Ctrl` `/` again to hide |
| `Space` `f` `t` | Terminal at the project root | |
| `Space` `n` | Notification history | Where messages go after they fade |
| `Space` `b` `D` | Close buffer *and* window | `Space` `b` `d` keeps the window |

---

[← Neovim — code intelligence](07-neovim-code.md) · [Index](../CHEATSHEET.md) · [Notes →](09-notes.md)

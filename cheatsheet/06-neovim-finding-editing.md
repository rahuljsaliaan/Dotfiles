# Neovim — finding and editing

Getting to a file, a symbol or a line, and changing it once you are there.

> **★ marks a binding custom to this repo.** Everything unmarked is an
> upstream default. Neovim's leader key is `Space`, written out rather than
> as `<leader>` because that is what you press.

[← Back to the index](../CHEATSHEET.md)

---

### Finding things

| Keys | Action | Notes |
| --- | --- | --- |
| `Space` `Space` | Find file by name | Project root |
| `Space` `f` `F` | Find file, current directory | |
| `Space` `f` `r` | Recent files | |
| `Space` `f` `g` | Find file tracked by git | |
| `Space` `/` | Grep across the project | Needs ripgrep |
| `Space` `,` | Switch buffer | |
| `Space` `s` `r` | Search and replace project-wide | grug-far |
| `Space` `s` `h` | Search help pages | |
| `Space` `:` | Command history | |
| `/` `?` | Search in the current file, forwards / back | |
| `n` / `N` | Next / previous match | |

### Editing

| Keys | Action | Notes |
| --- | --- | --- |
| `gcc` | Comment out the line | |
| `gc` + motion | Comment a range | e.g. `gc3j`, or `gc` in visual mode |
| `gco` / `gcO` | New commented line below / above | |
| `Alt` `J` / `Alt` `K` | Move the line down / up | Works in visual mode too |
| `Space` `c` `f` | Format the buffer | conform.nvim |
| `>>` / `<<` | Indent / outdent | |
| `ciw` / `ci"` | Change inner word / inside quotes | mini.ai adds more textobjects |
| `.` | Repeat the last change | |

---

[← Neovim — the basics](05-neovim-basics.md) · [Index](../CHEATSHEET.md) · [Neovim — code intelligence →](07-neovim-code.md)

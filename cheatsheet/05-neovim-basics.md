# Neovim — the basics

Staying alive: the explorer, moving around, and closing what you opened.

> **★ marks a binding custom to this repo.** Everything unmarked is an
> upstream default. Neovim's leader key is `Space`, written out rather than
> as `<leader>` because that is what you press.

[← Back to the index](../CHEATSHEET.md)

---

### Survival

| Keys | Action | Notes |
| --- | --- | --- |
| `Space` `e` | Explorer, project root (toggle) | Full-window on narrow terminals ★ |
| `Space` `E` | Explorer, current directory | |
| `q` | Back to the explorer ★ | Only on files opened full-window ★ |
| `Ctrl` `S` | Save | Works in insert mode too |
| `:w` / `:q` / `:wq` | Write / quit / both | |
| `Space` `q` `q` | Quit all | |
| `Esc` | Leave insert mode, clear search highlight | |
| `u` / `Ctrl` `R` | Undo / redo | |

### In the explorer

| Keys | Action |
| --- | --- |
| `j` / `k` or `↑` `↓` | Move |
| `Enter` / `l` | Open file, or expand directory |
| `h` | Collapse directory |
| `i` or `/` | Jump to the search box, then type to filter |
| `a` / `d` / `r` | Create / delete / rename |
| `H` | Hide / show dotfiles — shown by default ★ |
| `I` | Hide / show gitignored files — shown by default ★ |
| `Esc` | Back to the file list, or close |

### Moving around

| Keys | Action | Notes |
| --- | --- | --- |
| `5j` / `12k` | Down 5 lines / up 12 | Read the number off the gutter |
| `gg` / `G` | Top / bottom of file | |
| `:42` | Go to line 42 | Or `42G` |
| `w` / `b` | Next / previous word | |
| `0` / `^` / `$` | Line start / first non-blank / end | |
| `%` | Jump to the matching bracket | |
| `Ctrl` `D` / `Ctrl` `U` | Half page down / up | |
| `H` / `L` | Previous / next buffer | |
| `Ctrl` `O` / `Ctrl` `I` | Back / forward in the jump list | |

### Buffers — the tabs along the top

They are buffers on a bufferline, not real vim tabs, which is why the tab
commands do not apply to them.

| Keys | Action |
| --- | --- |
| `Space` `b` `d` | Close this one |
| `Space` `b` `o` | Close every other one |
| `Space` `b` `p` | Pin it, so `b` `o` spares it |
| `Space` `b` `D` | Close the buffer *and* its window |
| `Shift` `H` / `Shift` `L` | Previous / next |
| `Space` `,` | Switch by name |

`:bd` does the same as `Space` `b` `d`. Closing the last one leaves an empty
buffer rather than quitting. If you did open a real tab page with `:tabnew`,
that one closes with `:tabclose`.

### Windows — splits

| Keys | Action |
| --- | --- |
| `Ctrl` `H` `J` `K` `L` | Move to the window left / down / up / right |
| `Ctrl` `↑` `↓` `←` `→` | Resize the current window |
| `Ctrl` `W` `s` / `v` | Split horizontally / vertically |
| `Ctrl` `W` `q` | Close this split (`Ctrl` `W` `c` does the same) |
| `Ctrl` `W` `o` | Close every split *except* this one |

`:q` closes the current split too, and only exits Neovim when it is the last
window. These are Neovim's own splits — the tmux panes around them are
`Ctrl` `b` `x` to close and `Alt`+arrows to move between.

---

[← Multiplexer — tmux](04-tmux.md) · [Index](../CHEATSHEET.md) · [Neovim — finding and editing →](06-neovim-finding-editing.md)

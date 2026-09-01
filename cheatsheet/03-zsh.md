# Shell — zsh

Line editing, fuzzy history and the handful of commands defined here.

> **★ marks a binding custom to this repo.** Everything unmarked is an
> upstream default. Neovim's leader key is `Space`, written out rather than
> as `<leader>` because that is what you press.

[← Back to the index](../CHEATSHEET.md)

---

| Keys | Action | Notes |
| --- | --- | --- |
| `Ctrl` `R` ★ | Fuzzy history search | fzf, newest first |
| `Ctrl` `P` ★ | Find a file, open in Neovim | Runs `ff` |
| `Ctrl` `O` ★ | Find a directory and `cd` into it | Runs `fdc` |
| `↑` / `↓` ★ | History filtered by what you typed | Type `git ` then `↑` |
| `Ctrl` `A` / `Ctrl` `E` | Start / end of line | Emacs keybindings (`bindkey -e`) |
| `Ctrl` `W` | Delete word backwards | |
| `Ctrl` `U` | Clear the line | |

### Commands worth knowing

| Command | Action |
| --- | --- |
| `ff` ★ | File picker with preview → opens in Neovim |
| `fz` ★ | File picker with preview → opens in Zed |
| `fdc` ★ | Directory picker → `cd` |
| `workspace [name]` ★ | Restore a saved window layout; no argument lists them |
| `pyclean` ★ | Delete `__pycache__` and `.pyc` recursively |
| `z <partial>` | Jump to a frecent directory (zoxide) |
| `ls` / `ll` / `lt` ★ | eza with icons — plain, long, tree |

---

[← Terminal — WezTerm](02-wezterm.md) · [Index](../CHEATSHEET.md) · [Multiplexer — tmux →](04-tmux.md)

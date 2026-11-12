# Shortcuts Cheat Sheet

Every keyboard surface this repo configures — terminal, shell, multiplexer,
editor — from survival basics to the advanced end, split into chapters so you
can read one and stop.

> **★ marks a binding custom to this repo.** Everything unmarked is an upstream
> default, so it works on a stock install too. If you are ever unsure what a key
> does, [Getting started](cheatsheet/01-getting-started.md) beats this document
> — it lists the keys that show you the other keys.

**Neovim's leader key is `Space`.** It is written as `Space` throughout rather
than `<leader>`, because that is what you actually press.

## Contents

| # | Chapter | What is in it |
| --- | --- | --- |
| 1 | [Getting started](cheatsheet/01-getting-started.md) | The ten keys that cover a normal day, and how to find the rest yourself |
| 2 | [Terminal — WezTerm](cheatsheet/02-wezterm.md) | The window itself: copy and paste, scrollback, tabs, zoom, fullscreen |
| 3 | [Shell — zsh](cheatsheet/03-zsh.md) | Line editing, fuzzy history, and the commands defined here |
| 4 | [Multiplexer — tmux](cheatsheet/04-tmux.md) | Panes and windows, and the per-repo session `tmux dev` builds |
| 5 | [Neovim — the basics](cheatsheet/05-neovim-basics.md) | The explorer, moving around, and closing what you opened |
| 6 | [Neovim — finding and editing](cheatsheet/06-neovim-finding-editing.md) | Getting to a file or line, and changing it once you are there |
| 7 | [Neovim — code intelligence](cheatsheet/07-neovim-code.md) | What the language servers give you, and where errors are listed |
| 8 | [Neovim — git, toggles and the sharp end](cheatsheet/08-neovim-git-and-more.md) | Hunks and lazygit, the `Space` `u` toggles, keys worth graduating to |
| 9 | [Notes](cheatsheet/09-notes.md) | Why a few things behave the way they do here |

## If you only read one thing

Press `Space` in Neovim and wait — the which-key menu lists every leader
binding, and never goes stale the way this file can. `Ctrl` `b` `?` does the
same for tmux. Chapter 1 collects the rest of those.

## Common escapes

The keys people look up most, gathered in one place:

| Where you are | Way out |
| --- | --- |
| Lazygit | `q` — repeat to back out of a panel |
| A buffer / "tab" | `Space` `b` `d`, or `Space` `b` `o` for all the others |
| A Neovim split | `Ctrl` `W` `q`, or `Ctrl` `W` `o` to close the rest |
| A Neovim terminal | `Ctrl` `/`, or `Ctrl` `\` `Ctrl` `N` to get to normal mode first |
| A tmux pane | `Ctrl` `b` `x` |
| A tmux session | `Ctrl` `b` `d` detaches and leaves it running |
| Neovim itself | `Space` `q` `q` |

---

Keys in these chapters were extracted from the live config rather than written
from memory. If something is wrong, `Space` `s` `k` is the source of truth.

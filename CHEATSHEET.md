# Shortcuts Cheat Sheet

Every keyboard surface this repo configures — terminal, shell, multiplexer,
editor — from survival basics to the advanced end. Read top-down and stop when
you have enough.

> **★ marks a binding that is custom to this repo.** Everything unmarked is
> upstream default, so it works on a stock install too. If you are ever unsure
> what a key does, the next section beats this document.

**Neovim's leader key is `Space`.** It is written as `Space` throughout rather
than `<leader>`, because that is what you actually press.

---

## Quick start

The ten that cover most of a normal day.

| Keys | Where | Action |
| --- | --- | --- |
| `Space` `e` | Neovim | File explorer (toggle) |
| `Space` `Space` | Neovim | Find file by name |
| `Space` `/` | Neovim | Search *inside* files (grep) |
| `Space` `,` | Neovim | Switch buffer |
| `gd` | Neovim | Go to definition |
| `K` | Neovim | Hover docs |
| `Space` `g` `g` | Neovim | Lazygit |
| `Alt` `Shift` `+` ★ | tmux | Split pane right |
| `Alt` `←` `→` ★ | tmux | Move between panes |
| `Ctrl` `R` ★ | zsh | Fuzzy history search |

---

## Discovering keys yourself

The most useful section here, because it never goes stale.

| Keys | Where | Shows |
| --- | --- | --- |
| `Space` | Neovim | which-key menu of every leader binding — just wait |
| `Space` `?` | Neovim | Keymaps for the current buffer |
| `Space` `s` `k` | Neovim | Searchable list of *all* keymaps |
| `?` | Neovim picker | Keymap for the picker you are in |
| `Ctrl` `W` | Neovim | Window "hydra" mode, with hints |
| `Ctrl` `b` `?` | tmux | Every tmux binding |
| `:help {topic}` | Neovim | The manual, e.g. `:help text-objects` |

Pressing `Space` and reading the menu is faster than searching this file.

---

## Terminal — WezTerm

| Keys | Action | Notes |
| --- | --- | --- |
| `Ctrl` `Shift` `C` / `V` | Copy / paste | |
| *select with mouse* | Copies to clipboard immediately ★ | No extra keypress needed |
| `Shift` `PageUp` / `PageDown` | Scroll by page | |
| `Shift` `Home` / `End` ★ | Scroll to top / bottom | |
| `Shift` `Enter` ★ | Send `Esc`+`Return` | Newline in REPLs and Claude Code |
| `Ctrl` `Shift` `Alt` `T` ★ | Show/hide the title bar | Title bar is off by default |
| `Ctrl` `Shift` `N` | New window | Opens at 75% × 70% of the screen ★ |
| `Ctrl` `Shift` `T` | New tab | Tab bar appears only with 2+ tabs ★ |
| `Ctrl` `Tab` / `Ctrl` `Shift` `Tab` | Next / previous tab | |
| `Ctrl` `+` / `-` / `0` | Zoom text in / out / reset | Window size stays fixed ★ |
| `Ctrl` `Shift` `F` | Search the scrollback | |
| `Alt` `Enter` | Toggle fullscreen | |

There is no title bar to drag, so **move the window with `Super`+drag**.

---

## Shell — zsh

| Keys | Action | Notes |
| --- | --- | --- |
| `Ctrl` `R` ★ | Fuzzy history search | fzf, newest first |
| `Ctrl` `P` ★ | Find a file, open in VS Code | Runs `ff` |
| `Ctrl` `O` ★ | Find a directory and `cd` into it | Runs `fdc` |
| `↑` / `↓` ★ | History filtered by what you typed | Type `git ` then `↑` |
| `Ctrl` `A` / `Ctrl` `E` | Start / end of line | Emacs keybindings (`bindkey -e`) |
| `Ctrl` `W` | Delete word backwards | |
| `Ctrl` `U` | Clear the line | |

### Commands worth knowing

| Command | Action |
| --- | --- |
| `ff` ★ | File picker with preview → opens in VS Code |
| `fz` ★ | File picker with preview → opens in Zed |
| `fdc` ★ | Directory picker → `cd` |
| `workspace [name]` ★ | Restore a saved window layout; no argument lists them |
| `pyclean` ★ | Delete `__pycache__` and `.pyc` recursively |
| `z <partial>` | Jump to a frecent directory (zoxide) |
| `ls` / `ll` / `lt` ★ | eza with icons — plain, long, tree |

---

## Multiplexer — tmux

Prefix is `Ctrl` `b`. Mouse support is on ★, so you can click panes and scroll.

### Panes

| Keys | Action | Notes |
| --- | --- | --- |
| `Alt` `Shift` `+` ★ | Split right | No prefix needed |
| `Alt` `Shift` `-` ★ | Split below | No prefix needed |
| `Alt` `←` `→` `↑` `↓` ★ | Move between panes | No prefix needed |
| `Ctrl` `b` `z` | Zoom pane to full window (toggle) | |
| `Ctrl` `b` `x` | Close pane | |
| `Ctrl` `b` `space` | Cycle pane layouts | |

New panes open in the **current pane's directory** ★, not where the session started.

Split a window and each pane grows a **header** ★ showing its number, the
command running in it, and a blue `▌` on the pane with focus — plus the
focused pane sits on a **lighter background** than the others. The header
appears only while the window is split, so a single pane loses no room.

### A session per repo ★

`dev` opens (or re-attaches to) a session laid out for one repo:

```
┌───────────────────────────┬───────────────┐
│ editor  (nvim)            │ harness 1     │
│                           ├───────────────┤
├───────────────────────────┤ harness 2     │
│ shell                     │               │
└───────────────────────────┴───────────────┘
```

| Command | Result |
| --- | --- |
| `dev` | Session for the current directory |
| `dev ~/path/to/repo` | Session for that repo |
| `dev` again | Re-attaches; never builds a second copy |

Each pane is **colour-coded by role** in its header — editor blue, shell green,
the two harnesses magenta and yellow — and the **repo name sits on its own
colour** in the status bar, picked by hashing the name, so two of these side by
side are told apart without reading either. Colour marks what a pane *is*; the
`▌` and the lighter background still mark which one has *focus*.

Overrides, if a repo needs something else:

| Variable | Effect |
| --- | --- |
| `DEV_EDITOR_CMD=helix` | Different editor |
| `DEV_HARNESS_CMD=` | Leave the harness panes at a plain shell |
| `DEV_HARNESS_CMD='claude -c'` | Resume instead of starting fresh |

### Windows and sessions

| Keys | Action |
| --- | --- |
| `Ctrl` `b` `c` | New window |
| `Ctrl` `b` `n` / `p` | Next / previous window |
| `Ctrl` `b` `1`…`9` | Jump to window by number |
| `Ctrl` `b` `,` | Rename window |
| `Ctrl` `b` `d` | Detach (leaves everything running) |
| `Ctrl` `b` `[` | Copy mode — scroll and select |
| `tmux a` | Re-attach to the last session |

---

## Editor — Neovim / LazyVim

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

### Windows

| Keys | Action |
| --- | --- |
| `Ctrl` `H` `J` `K` `L` | Move to the window left / down / up / right |
| `Ctrl` `↑` `↓` `←` `→` | Resize the current window |
| `Ctrl` `W` `s` / `v` | Split horizontally / vertically |
| `Ctrl` `W` `q` | Close window |

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

### Code intelligence (LSP)

These attach when a language server starts, so they only exist in a supported file.

| Keys | Action |
| --- | --- |
| `gd` | Go to definition |
| `gr` | Find references |
| `gI` | Go to implementation |
| `gy` | Go to type definition |
| `gD` | Go to declaration |
| `K` | Hover documentation |
| `gK` | Signature help |
| `Space` `c` `a` | Code action (quick fixes) |
| `Space` `c` `r` | Rename symbol, project-wide |
| `Space` `c` `s` | Document symbols |
| `Space` `c` `l` | LSP info — what is attached |
| `Space` `c` `m` | Mason — install language servers |

### Diagnostics and lists

| Keys | Action |
| --- | --- |
| `]d` / `[d` | Next / previous diagnostic |
| `Space` `x` `x` | All diagnostics (Trouble) |
| `Space` `x` `X` | Diagnostics, current buffer only |
| `Space` `s` `d` | Search diagnostics |
| `]q` / `[q` | Next / previous quickfix item |
| `Space` `x` `q` | Quickfix list |
| `Space` `x` `t` | TODO / FIX / HACK comments |

### Git

| Keys | Action | Notes |
| --- | --- | --- |
| `Space` `g` `g` | Lazygit | Needs `lazygit` (installed via mise) |
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

## Notes

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
  which with two panes it is either way. That is why focus is shown on the pane
  itself — the `▌` header and the lighter background — rather than on the edge.
- Markdown files **render in place** ★ — headings get a glyph, tables become
  ruled grids, code blocks a background. The line under the cursor drops back to
  raw source so it stays editable, which is why one row of a table always looks
  unrendered. `Space` `u` `m` toggles it. Formatting is deliberately not part of
  this: nothing reflows the hand-wrapped prose in this file on save.
- Keys in this file were extracted from the live config rather than written from
  memory. If something here is wrong, `Space` `s` `k` is the source of truth.

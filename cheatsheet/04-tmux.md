# Multiplexer — tmux

Panes and windows, and the per-repo session `tmux dev` builds.

> **★ marks a binding custom to this repo.** Everything unmarked is an
> upstream default. Neovim's leader key is `Space`, written out rather than
> as `<leader>` because that is what you press.

[← Back to the index](../CHEATSHEET.md)

---

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
command running in it, and a blue `▌` on the pane with focus. Borders use
**heavy lines** ★ (`┃ ━ ┳`) so a divider reads as a real edge rather than a
hairline. The header appears only while the window is split, so a single pane
loses no room.

### A session per repo ★

`tmux dev` opens (or re-attaches to) a session laid out for one repo:

```
┌────────────────────────────────────────────┬──────────────────────┐
│ editor  (nvim)                             │ harness 1            │
│                                            │                      │
│                                            │                      │
│                                            ├──────────────────────┤
│                                            │ harness 2            │
│                                            │                      │
├────────────────────────────────────────────┤                      │
│ shell                                      │                      │
└────────────────────────────────────────────┴──────────────────────┘
```

| Command | Result |
| --- | --- |
| `tmux dev` | Session for the current directory |
| `tmux dev ~/path/to/repo` | Session for that repo |
| `tmux dev` again | Re-attaches; never builds a second copy |

`dev` is a subcommand only by courtesy of a wrapper function in `.zshrc` —
tmux's own `command-alias` cannot do it, because aliases are read from
`tmux.conf` and that is only loaded once a server is running, while tmux
refuses to start a server for a command it does not recognise. The wrapper
passes every other argument through to the real tmux. `tmux-dev` is the same
thing under its own name, for use from a non-zsh shell.

Each pane's header **names what it is** — editor, shell, harness 1, harness 2.
The only colour in a header marks focus: blue on the focused pane, grey on the
rest, the same rule the borders follow.

The **repo's own colour** sits behind its name in the status bar, picked by
hashing the name, and WezTerm draws a **frame around the whole window** in that
same colour ★ — so two of these side by side are told apart without reading
either. tmux has no outer border of its own, only dividers between panes, so
the frame is the terminal's doing: `dev` hands the colour over as it attaches
and clears it when the session ends.

The status bar also carries the **current branch** ★ beside the repo name,
re-read every few seconds, so it follows a checkout rather than freezing at
whatever was current when the session opened. The window is named `dev`, not
`main` — a window called `main` renders as `1 main` next to the badge and reads
as a branch that is nothing of the sort.

Two repos with the **same folder name** — `~/work/api` and `~/personal/api` —
get separate sessions ★; the plain name goes to whichever claimed it first.

Overrides, if a repo needs something else:

| Variable | Effect |
| --- | --- |
| `DEV_EDITOR_CMD=helix` | Different editor |
| `DEV_HARNESS_CMD=` | Leave the harness panes at a plain shell |
| `DEV_HARNESS_CMD='claude -c'` | Resume instead of starting fresh |
| `DEV_ACCENT='#f7768e'` | Pick the repo's colour instead of deriving it |

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

Changing that colour from inside the session:

| Keys | Action |
| --- | --- |
| `Ctrl` `b` `:` then `recolor` | A random colour from the palette ★ |
| `Ctrl` `b` `C` | Prompt for one, e.g. `#f7768e` ★ |

Both repaint the status badge and the window frame together.

---

[← Shell — zsh](03-zsh.md) · [Index](../CHEATSHEET.md) · [Neovim — the basics →](05-neovim-basics.md)

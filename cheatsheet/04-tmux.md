# Multiplexer — tmux

Panes and windows, the per-repo session `tmux dev` builds, and the one per
worktree behind `tmux wt`.

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

### A session per worktree ★

`tmux wt` is the same idea for parallel work: pick git worktrees, and get one
session on each, with an agent running in every one.

```
┌──────────────────────────────────┬────────────────────────┐
│ harness (claude)                 │ editor  (nvim)         │
│                                  │                        │
│                                  │                        │
│                                  ├────────────────────────┤
│                                  │ shell                  │
└──────────────────────────────────┴────────────────────────┘
```

The layout is `tmux dev` inverted, deliberately. There the editor leads and the
harnesses sit in a narrow column, because you are the one typing. Here the
agent has the work and you are reading it, so the harness takes 60% and the
editor comes along for review.

| Command | Result |
| --- | --- |
| `tmux wt` | Pick worktrees; one session opens on each |
| `tmux wt new feat/billing` | Branch off `origin/HEAD` into a new worktree, and open it |
| `tmux wt rm` | Pick worktrees to remove |

The picker is fzf, multi-select with `Tab`, and its preview shows what each
worktree is carrying — commits ahead of `origin/HEAD` first, then anything
uncommitted. Pick more than **four** and it asks before going ahead ★: past
four agents at once, reviewing what they did turns into waving it through.

Sessions are named `<repo>-<branch>` ★, so they never collide with the plain
repo name `tmux dev` claims, and each takes **its own colour** from the same
palette — four running at once are told apart at a glance rather than by
reading. A branch with a slash becomes a dash: `feat/billing` opens as
`myrepo-feat-billing`, in a directory called `feat-billing`.

`wt rm` never passes `--force`, so git refuses any worktree still holding
uncommitted or unmerged work ★ and names the one it kept. Removing a worktree
never removes its branch, which is what leaves the work mergeable afterwards.

New worktrees land in `~/Worktrees/<repo>/<branch>`, or under
`DEV_WORKTREE_ROOT` if it is set. `DEV_EDITOR_CMD` and `DEV_HARNESS_CMD` work
exactly as they do for `tmux dev`.

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

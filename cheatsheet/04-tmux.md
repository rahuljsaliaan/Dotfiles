# Multiplexer — tmux

Panes and windows, the per-repo session `tmux dev` builds, and the folder of
parallel worktrees `tmux wt` drives.

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
the frame is the terminal's doing, and tmux has to hand the colour over rather
than draw it. That happens on every session change ★, however you switch —
`prefix` `s`, `prefix` `S`, or a fresh `tmux a` — so the frame always matches
whatever is in front, and a session with no badge clears it.

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

### A folder of worktrees ★

`tmux wt` works on the **folder holding a project's worktrees**, not from inside
the repository. Point it at a checkout once and it remembers:

```
~/Worktrees/oriv-conduit/
├── .wt.conf          ← which checkout these belong to
├── fix-login/
├── feat-billing/
└── chore-deps/
```

| Command | Result |
| --- | --- |
| `tmux wt init` | Adopt this folder, finding the repo inside it |
| `tmux wt init ~/path/to/repo` | The same, naming the repo explicitly |
| `tmux wt` | Ask which worktrees to open; a Claude session on each |
| `tmux wt new feat/billing` | Add a worktree here, off `origin/HEAD`, and open it |
| `tmux wt new a b c` | Several at once |
| `tmux wt setup` | Re-run the setup hook on the ones you pick |
| `tmux wt rm` | Remove the ones you pick |

A folder of worktrees is not a git repository, and nothing in it says which
checkout they came from — git only knows the other way round. `.wt.conf` records
that, which is what lets every command run from here instead of from inside the
repo. `wt init` with no argument looks inside the current folder and finds the
repository itself ★ — every worktree of a repo reports the same checkout, so a
folder holding a clone and four of its worktrees still collapses to one answer,
and only two genuinely different repositories are refused (it lists them and
asks which). It is also written for you the first time you run `wt` in a folder
that plainly already holds worktrees ★. The file is read with
`sed`, never sourced, since it sits in a working directory.

Everything except `init` finds the folder by **walking up** ★, so the commands
work from the folder itself and from inside any worktree in it — a fifth task
that occurs to you while three agents are already running is one command away.

The picker is fzf and opens with **nothing ticked**: which worktrees to work on
is the question being asked. `Tab` ticks, `Enter` opens what is ticked, and the
preview shows what each is carrying — commits ahead of `origin/HEAD` first, then
anything uncommitted. Opening more than **four** asks first ★: past four agents
at once, reviewing what they did turns into waving it through.

### One pane per worktree ★

The worktrees you tick open as **panes in one window**, each running Claude in
its own checkout:

```
┌──────────────────────────┬──────────────────────────┐
│ claude                   │ claude                   │
│ fix-login                │ feat-billing             │
└──────────────────────────┴──────────────────────────┘
```

One session for the project, not one per worktree, so every agent is on screen
at once instead of behind a switch. `Alt` `←` `→` moves between them, and
`Ctrl` `b` `z` zooms one to full window and back.

Two panes sit side by side at full height; three or more **tile** ★, which
keeps each wide enough to be worth reading rather than shaving columns off one.
Each pane's **header names its branch** ★ — with several checkouts in one window
that is the only thing saying which is which, and it is why the branch is no
longer in the status bar: a `#()` against `#{pane_current_path}` would have
followed the focused pane, but tmux does not expand a format inside `#()`.

Running `tmux wt` again **adds** to the same window ★ — worktrees already open
are reported and skipped rather than opened a second time, so it is safe to
re-run as more tasks appear. `wt rm` closes the pane looking at a worktree
before removing it, since a shell in a deleted directory has nowhere to be.

The session is named `<repo>-wt` ★ so it never collides with the plain repo name
`tmux dev` claims, and takes its own colour from the same palette.

`DEV_HARNESS_CMD='claude -c'` resumes instead of starting fresh; empty leaves
the panes at plain shells.

### Making a worktree usable ★

A worktree is a **clean checkout** — no `node_modules`, no `.venv`, and nothing
gitignored, so the `.env` the app needs is absent too. An agent opened on one
fails in ways that look like its own mistake.

Put an executable `.worktree-setup` in the repo root and `wt new` runs it once,
in the new worktree, after creating it:

```sh
#!/bin/sh
cp "$WORKTREE_MAIN/.env" .
npm ci
```

`$WORKTREE_MAIN` is the main checkout — the only place gitignored files can be
copied from, since by definition they are not in the branch. `$WORKTREE_BRANCH`
is the branch name. Commit the hook and everyone, agents included, sets a
worktree up the same way.

A failing hook is reported but never fatal: the worktree still exists, and
`wt setup` re-runs the hook on one you pick — for a setup that failed, or for a
worktree made by hand with `git worktree add` that never went through `wt new`.
`DEV_WORKTREE_SETUP='npm ci'` overrides the hook for a one-off.

### Windows and sessions

| Keys | Action |
| --- | --- |
| `Ctrl` `b` `c` | New window |
| `Ctrl` `b` `n` / `p` | Next / previous window |
| `Ctrl` `b` `1`…`9` | Jump to window by number |
| `Ctrl` `b` `,` | Rename window |
| `Ctrl` `b` `d` | Detach (leaves everything running) |
| `Ctrl` `b` `[` | Copy mode — scroll and select |
| `Ctrl` `b` `s` | Session tree |
| `Ctrl` `b` `S` ★ | Fuzzy session picker, with branch and dirty mark |
| `tmux a` | Re-attach to the last session |

Lowercase `s` is tmux's own session tree and is untouched. Capital `S` opens a
popup listing every session with the branch its directory is on and a `✗` when
that tree is dirty — the thing the tree cannot show, and what you want once
`tmux wt` has four sessions open that differ only by branch.

Changing that colour from inside the session:

| Keys | Action |
| --- | --- |
| `Ctrl` `b` `:` then `recolor` | A random colour from the palette ★ |
| `Ctrl` `b` `C` | Prompt for one, e.g. `#f7768e` ★ |

Both repaint the status badge and the window frame together.

---

[← Shell — zsh](03-zsh.md) · [Index](../CHEATSHEET.md) · [Neovim — the basics →](05-neovim-basics.md)

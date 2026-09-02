# Working in this repo

## Commits

**Never add a `Co-Authored-By` trailer.** Commits here are authored solely as
the repo owner, with nothing appended to the message.

Conventions the history follows:

- `type: :gitmoji: Subject` — e.g. `feat: :sparkles:`, `fix: :bug:`,
  `docs: :memo:`, `revert: :rewind:`, `feat: :lipstick:` for a visual change.
- Subject in the imperative, describing the effect rather than the edit.
- **One concern per commit.** A change that touches tmux and zsh for unrelated
  reasons is two commits, even when it means splitting a file's hunks between
  them.
- The body explains *why*, and what was ruled out. A reader a year from now
  wants the reasoning, not a list of the lines that changed.

## This repo is public

`github.com/rahuljsaliaan/Dotfiles` is public. Before committing anything
sourced from outside the repo, check it for private repo or org names, internal
project descriptions, absolute paths that identify work, credentials, and
machine-specific state.

This is why `claude/` is linked out of `~/.claude` **file by file** rather than
as a directory — that directory also holds credentials, session history and
hundreds of megabytes of per-project state. `~/.claude/settings.json` is
deliberately not tracked: Claude Code writes to it at runtime, so a symlink
would keep depositing regenerated machine- and org-specific content into the
working tree.

## How the configs reach their applications

Every folder holds the real file; `install.sh` symlinks it into place, so the
repo is the single source of truth and edits take effect where they are. Add a
new config to the `LINKS` array there rather than linking it by hand.

`nvim/` is linked as a whole directory, so `lazy-lock.json` lands in the repo
and plugin versions stay reproducible — plugin updates show up as changes here,
and that is intended.

## Testing a change to tmux

Never `tmux kill-server`, and never test against the default socket: that
destroys whatever sessions are running. Use an isolated one — `tmux -L probe
…` — and kill only that server.

Percentages in `tmux/dev-session.sh` are applied once, when the panes are
split. Extreme values put small panes on tmux's minimum size, which a later
resize cannot scale back out of; moderate ones survive a fullscreen toggle
exactly.

## Documentation

`CHEATSHEET.md` is an index; the chapters live in `cheatsheet/`. Keys in them
are extracted from the live config rather than written from memory, so when a
binding changes, the chapter changes with it in the same commit.

#!/usr/bin/env bash
#
# Pick git worktrees, and open a tmux session on each one:
#
#   ┌──────────────────────────────────┬────────────────────────┐
#   │ harness (claude)                 │ editor  (nvim)         │
#   │                                  │                        │
#   │                                  │                        │
#   │                                  ├────────────────────────┤
#   │                                  │ shell                  │
#   └──────────────────────────────────┴────────────────────────┘
#
#   wt                  # pick worktrees to open, one session each
#   wt new <branch>...  # branch off origin/HEAD into new worktrees, and open them
#   wt setup            # re-run the setup hook on a worktree
#   wt rm               # pick worktrees to remove
#
# The mirror image of `tmux dev`, and deliberately so. There the editor leads and
# two harnesses sit in a narrow column, because you are the one typing. Here one
# agent has the work and you are reading it, so the harness takes the room and
# the editor is along for review.
#
# One session per worktree, named <repo>-<branch>, each on its own colour -- so
# four agents running at once are told apart at a glance rather than by reading
# the branch out of the status bar.
#
# Overrides:
#   DEV_WORKTREE_ROOT=~/wt      where `new` puts worktrees (default: ~/Worktrees)
#   DEV_WORKTREE_SETUP='npm ci' one-off setup, instead of the repo's hook
#   DEV_EDITOR_CMD=helix        command for the editor pane (default: nvim .)
#   DEV_HARNESS_CMD=            empty leaves the harness pane at a plain shell
#   DEV_HARNESS_CMD='claude -c' resume instead of starting fresh

set -euo pipefail

# ---------------------------------------------------------------- geometry ---
# Per cent of the window given to the editor column on the right. The harness
# keeps the rest, which is the whole point of this layout.
EDITOR_COLUMN_WIDTH=40
# Per cent of the right column given to the shell beneath the editor.
SHELL_ROW_HEIGHT=23

# Past this many at once you stop reviewing what the agents did and start
# waving it through, which costs more than the parallelism buys. Not a hard
# limit -- it asks rather than refuses.
MAX_SESSIONS=4

# ----------------------------------------------------------------- colours ---
# Tokyo Night, the same values wezterm.lua, tmux.conf and dev-session.sh use.
STATUS_BG="#222436"
STATUS_DIM="#414868"
STATUS_DARKEST="#1a1b26"

REPO_ACCENTS=("#7aa2f7" "#bb9af7" "#e0af68" "#9ece6a" "#f7768e" "#7dcfff")

WORKTREE_ROOT="${DEV_WORKTREE_ROOT:-$HOME/Worktrees}"

EDITOR_CMD="${DEV_EDITOR_CMD:-nvim .}"
# Assigned with :- rather than :=, so DEV_HARNESS_CMD= (set but empty) is
# honoured as "no harness" instead of falling back to the default.
HARNESS_CMD="${DEV_HARNESS_CMD-claude}"

die() { printf 'wt: %s\n' "$1" >&2; exit 1; }

# ------------------------------------------------------------------- badge ---
# Kept byte-identical to dev-session.sh's, so a worktree session and a repo
# session are the same object on screen. The branch is a #() shell call rather
# than a value baked in at creation, so it follows a checkout instead of
# freezing at whatever was current when the session opened.
badge() {  # badge <session> <accent> <worktree-path>
  tmux set -t "$1" @accent "$2"

  tmux set -t "$1" status-left \
    " #[bg=${2},fg=${STATUS_DARKEST},bold]  ${1} #[bg=${STATUS_BG},fg=${STATUS_DIM}]│ #[fg=#7aa2f7] #(git -C '${3}' rev-parse --abbrev-ref HEAD 2>/dev/null) #[fg=#414868]│"
}

# See dev-session.sh for why this is base64 in an OSC 1337, and why it needs the
# DCS passthrough wrapper when there is a tmux between here and wezterm.
frame_accent() {
  local b64
  b64="$(printf '%s' "$1" | base64 | tr -d '\n')"

  if [[ -n ${TMUX:-} ]]; then
    printf '\033Ptmux;\033\033]1337;SetUserVar=tmux_dev_accent=%s\007\033\\' "$b64"
  else
    printf '\033]1337;SetUserVar=tmux_dev_accent=%s\007' "$b64"
  fi
}

# ------------------------------------------------------------------- names ---
# tmux reads "." and ":" in a target as address separators, so they cannot
# survive into a session name. "/" is legal in one, but a branch like
# feat/billing would then read as a path in the status bar -- and the worktree
# directory flattens it the same way, so the two stay in step.
slug() {
  local s="${1//\//-}"   # feat/billing -> feat-billing
  s="${s//./_}"
  s="${s//:/_}"
  printf '%s' "$s"
}

# ------------------------------------------------------------------- setup ---
# A worktree is a clean checkout: no node_modules, no .venv, and nothing that
# is gitignored -- so the .env an app needs and the dependencies an agent needs
# to build or test are all absent. An agent opened on a bare checkout fails in
# ways that look like its own mistake, so this is where a project says how to
# get from a checkout to a working tree.
#
# A script in the repo root rather than a config format: what it has to do is a
# shell command, every project's is different, and committing it means everyone
# -- and every agent -- sets a worktree up the same way.
#
# The hook runs with the worktree as its working directory, and is handed
# $WORKTREE_MAIN (the main checkout) because gitignored files can only be
# copied from there -- by definition they are not in the branch.
SETUP_HOOK=".worktree-setup"

run_setup() {  # run_setup <worktree-path> <branch>
  local cmd
  if [[ -n ${DEV_WORKTREE_SETUP:-} ]]; then
    cmd="$DEV_WORKTREE_SETUP"
  elif [[ -x "$REPO/$SETUP_HOOK" ]]; then
    cmd="$REPO/$SETUP_HOOK"
  elif [[ -f "$REPO/$SETUP_HOOK" ]]; then
    printf 'wt: %s exists but is not executable -- skipped\n' "$SETUP_HOOK" >&2
    return 0
  else
    return 0
  fi

  printf 'wt: running setup in %s\n' "$1"

  # Not fatal. The worktree has already been created, and stranding it half
  # made would be worse than handing over one that needs a manual install --
  # but say so loudly, because the agent about to open on it will hit the same
  # failure in a much less legible form.
  if ! (cd "$1" && WORKTREE_MAIN="$REPO" WORKTREE_BRANCH="$2" sh -c "$cmd"); then
    printf 'wt: setup failed -- %s exists but is not ready. Fix and: wt setup\n' \
      "$1" >&2
  fi
}

# --------------------------------------------------------------- discovery ---
# git is the source of truth rather than a directory listing: it knows every
# worktree wherever it lives, and it knows the ones whose directory has been
# deleted out from under it, which a listing would silently miss.
#
# --porcelain emits a stanza per worktree, blank-line separated. The main
# checkout is the first stanza and is skipped -- it is not a worktree you would
# hand to an agent -- as is anything detached, which has no branch to merge.
worktrees() {  # -> "<branch>\t<path>" per line
  git -C "$REPO" worktree list --porcelain | awk '
    /^worktree / { path = substr($0, 10); if (main == "") main = path; next }
    /^branch /   { branch = substr($0, 8); sub(/^refs\/heads\//, "", branch)
                   if (path != main) print branch "\t" path }
  '
}

# What each worktree is carrying, for the picker's preview pane. Commits first,
# because that is what you are choosing between; uncommitted state second,
# because it is the thing that would block a merge later.
preview_cmd() {
  cat <<'PREVIEW'
    p={2}
    printf '\033[1m%s\033[0m\n\n' "$p"
    git -C "$p" --no-pager log --oneline --decorate -15 origin/HEAD..HEAD 2>/dev/null \
      || git -C "$p" --no-pager log --oneline -15
    printf '\n\033[1m── working tree ──\033[0m\n'
    git -C "$p" status --short 2>/dev/null | head -20 || true
PREVIEW
}

pick() {  # pick <prompt> ; reads worktrees on stdin, writes picks on stdout
  fzf --multi \
    --height 40% --layout=reverse \
    --delimiter='\t' --with-nth=1 \
    --prompt="$1 " \
    --preview "$(preview_cmd)" \
    --preview-window=right:60%
}

# ----------------------------------------------------------------- session ---
# Build the session detached and return. Opening several at once means no single
# one can be attached to from in here, so attaching is the caller's last act.
open_session() {  # open_session <branch> <path> -> echoes the session name
  local branch="$1" path="$2" session accent checksum
  local harness editor shell_pane cols rows

  session="$(slug "$(basename "$REPO")")-$(slug "$branch")"

  if tmux has-session -t "=$session" 2>/dev/null; then
    printf '%s' "$session"
    return 0
  fi

  # Hashing the session name rather than the branch alone: it already carries
  # both repo and branch, so two worktrees of one repo land on different
  # colours, and the same worktree keeps its colour across machines.
  checksum="$(printf '%s' "$session" | cksum | cut -d' ' -f1)"
  accent="${REPO_ACCENTS[$((checksum % ${#REPO_ACCENTS[@]}))]}"

  # A detached session is 80x24 unless told otherwise and the splits below are
  # percentages, so without this they divide up 80x24 rather than the terminal
  # about to attach, and the small panes land on tmux's minimum size.
  if [[ -n ${TMUX:-} ]]; then
    cols="$(tmux display -p '#{client_width}' 2>/dev/null || true)"
    rows="$(tmux display -p '#{client_height}' 2>/dev/null || true)"
  fi
  # Tested against 0 and not merely emptiness: #{client_width} resolves to 0,
  # not to nothing, when the session has no client attached yet -- and -x 0 is
  # silently clamped to tmux's 80x24, which is exactly what this avoids.
  (( ${cols:-0} > 0 )) || cols="$(tput cols 2>/dev/null || echo 80)"
  (( ${rows:-0} > 0 )) || rows="$(tput lines 2>/dev/null || echo 24)"

  # Named for the branch, not "dev": with several of these open the window list
  # is the only place the branch appears while you are switching between them.
  tmux new-session -d -s "$session" -c "$path" -n "$(slug "$branch")" \
    -x "$cols" -y "$rows"

  # Panes by id, never index -- every split renumbers the indices around it.
  harness="$(tmux list-panes -t "$session:" -F '#{pane_id}' | head -1)"
  editor="$(tmux split-window -h -l "${EDITOR_COLUMN_WIDTH}%" \
    -t "$harness" -c "$path" -P -F '#{pane_id}')"
  shell_pane="$(tmux split-window -v -l "${SHELL_ROW_HEIGHT}%" \
    -t "$editor" -c "$path" -P -F '#{pane_id}')"

  role() { tmux select-pane -t "$1" -T "$2"; tmux set -p -t "$1" @role "$2"; }
  role "$harness"    "harness"
  role "$editor"     "editor"
  role "$shell_pane" "shell"

  tmux send-keys -t "$editor" "$EDITOR_CMD" C-m
  [[ -n $HARNESS_CMD ]] && tmux send-keys -t "$harness" "$HARNESS_CMD" C-m

  badge "$session" "$accent" "$path"
  # Focus the harness, not the editor: the agent is what you came to watch.
  tmux select-pane -t "$harness"

  printf '%s' "$session"
}

# Attach last, once every session exists, so the ones after the first are not
# built behind an already-attached client.
connect() {  # connect <session>
  local accent
  accent="$(tmux show -t "$1" -v @accent 2>/dev/null || true)"
  frame_accent "$accent"

  if [[ -n ${TMUX:-} ]]; then
    exec tmux switch-client -t "=$1"
  fi

  tmux attach-session -t "=$1" || true
  frame_accent ""
}

# --------------------------------------------------------------- arguments ---
# The MAIN checkout, even when this is run from inside a worktree -- which is
# the normal case once you are working in one and want another. --show-toplevel
# would answer with the worktree itself, and the pool would then be nested
# under a branch name instead of the repo's. --git-common-dir points at the one
# .git every worktree shares, and its parent is the checkout that owns it.
REPO="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
  || die 'not inside a git repository'
REPO="$(dirname "$REPO")"

# Shared by `new` and the picker: both end up opening sessions, and the cost of
# too many is the same either way.
confirm_count() {  # confirm_count <n>
  (( $1 > MAX_SESSIONS )) || return 0
  printf 'wt: %d selected. Past %d agents at once, reviewing what they did\n' \
    "$1" "$MAX_SESSIONS" >&2
  printf 'wt: turns into waving it through.\n' >&2
  read -r -p "wt: open all $1 anyway? [y/N] " reply
  [[ $reply == [yY] ]]
}

case "${1:-open}" in
  new)
    shift
    (( $# > 0 )) || die 'usage: wt new <branch> [branch...]'
    confirm_count "$#" || exit 1

    pool="$WORKTREE_ROOT/$(basename "$REPO")"
    mkdir -p "$pool"

    # Branch off the remote's default rather than whatever is checked out here:
    # a worktree started from a half-finished local branch inherits work the
    # agent never asked for, and every one of these is merged back separately.
    # Fetched once for the whole batch rather than per branch.
    git -C "$REPO" fetch --quiet origin 2>/dev/null || true
    base="$(git -C "$REPO" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    [[ -n $base ]] || base="$(git -C "$REPO" rev-parse --abbrev-ref HEAD)"

    first=""
    for branch in "$@"; do
      dir="$pool/$(slug "$branch")"
      if [[ -e $dir ]]; then
        printf 'wt: skipped %s -- %s already exists\n' "$branch" "$dir" >&2
        continue
      fi

      # An existing branch is checked out as-is; only a new one is cut from the
      # base. git refuses either way if the branch is already in a worktree.
      if git -C "$REPO" show-ref --quiet --verify "refs/heads/$branch"; then
        git -C "$REPO" worktree add "$dir" "$branch" || continue
      else
        git -C "$REPO" worktree add -b "$branch" "$dir" "$base" || continue
      fi

      run_setup "$dir" "$branch"
      session="$(open_session "$branch" "$dir")"
      printf 'wt: %s\n' "$session"
      [[ -n $first ]] || first="$session"
    done

    [[ -n $first ]] || die 'nothing created'
    connect "$first"
    ;;

  setup)
    # For a worktree whose setup failed, or one made by hand with `git worktree
    # add`, which never went through `wt new`.
    picks="$(worktrees | pick 'setup>')" || exit 0
    [[ -n $picks ]] || exit 0

    while IFS=$'\t' read -r branch path; do
      [[ -n $path ]] || continue
      run_setup "$path" "$branch"
    done <<< "$picks"
    ;;

  rm)
    picks="$(worktrees | pick 'remove>')" || exit 0
    [[ -n $picks ]] || exit 0

    while IFS=$'\t' read -r branch path; do
      [[ -n $path ]] || continue
      session="$(slug "$(basename "$REPO")")-$(slug "$branch")"
      tmux kill-session -t "=$session" 2>/dev/null || true

      # No --force: git refuses a worktree with uncommitted changes or its own
      # unmerged commits, which is exactly the check wanted here. Reported and
      # skipped rather than fatal, so one dirty tree does not strand the rest.
      if git -C "$REPO" worktree remove "$path" 2>/dev/null; then
        printf 'wt: removed %s\n' "$branch"
      else
        printf 'wt: kept %s -- uncommitted or unmerged work\n' "$branch" >&2
      fi
    done <<< "$picks"
    ;;

  switch)
    # Bound to prefix + S in tmux.conf, and run inside a popup. Every session,
    # not just this repo's: `tmux dev` sessions are things to switch to as
    # well, and with four worktrees open the list is long enough that typing a
    # fragment of a branch beats reading down it.
    #
    # tmux's own prefix + s (choose-tree) stays exactly where it was. This is
    # the fuzzy one, and it carries the branch and a dirty mark, which
    # choose-tree has no way to show.
    current="$(tmux display-message -p '#{session_name}' 2>/dev/null || true)"

    # Session paths are fetched one at a time rather than in a single format:
    # tmux emits "\t" in a format literally rather than as a tab, so there is
    # no separator that is safe against a path, and the -f filter is the same
    # trick dev-session.sh uses to read a path back reliably.
    target="$(
      tmux list-sessions -F '#{session_name}' 2>/dev/null | while read -r name; do
        path="$(tmux list-sessions -f "#{==:#{session_name},$name}" \
          -F '#{session_path}' 2>/dev/null || true)"
        branch="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
        [[ -n $branch ]] || branch='-'
        dirty=''
        [[ -n "$(git -C "$path" status --porcelain 2>/dev/null | head -1)" ]] \
          && dirty=' ✗'
        mark=' '
        [[ $name == "$current" ]] && mark='*'
        printf '%s\t%s %-30s %s%s\n' "$name" "$mark" "$name" "$branch" "$dirty"
      done \
        | fzf --delimiter='\t' --with-nth=2 \
              --height 100% --layout=reverse --prompt='session> ' \
        | cut -f1
    )"

    [[ -n $target ]] && tmux switch-client -t "=$target"
    ;;

  open|"")
    available="$(worktrees)"
    [[ -n $available ]] \
      || die "no worktrees for $(basename "$REPO") -- make one with: wt new <branch>"

    picks="$(printf '%s\n' "$available" | pick 'worktree>')" || exit 0
    [[ -n $picks ]] || exit 0

    confirm_count "$(printf '%s\n' "$picks" | grep -c .)" || exit 1

    first=""
    while IFS=$'\t' read -r branch path; do
      [[ -n $path ]] || continue
      if [[ ! -d $path ]]; then
        printf 'wt: skipped %s -- directory is gone\n' "$branch" >&2
        continue
      fi
      session="$(open_session "$branch" "$path")"
      printf 'wt: %s\n' "$session"
      [[ -n $first ]] || first="$session"
    done <<< "$picks"

    [[ -n $first ]] || die 'nothing opened'
    connect "$first"
    ;;

  *)
    die "unknown command: $1 (try: wt, wt new <branch>..., wt setup, wt rm)"
    ;;
esac

#!/usr/bin/env bash
#
# Worktrees for one project, driven from the folder that holds them rather than
# from inside the repository:
#
#   ~/Worktrees/oriv-conduit/
#   ├── .wt.conf          written on first use -- which checkout these belong to
#   ├── fix-login/
#   ├── feat-billing/
#   └── chore-deps/
#
#   wt init <repo>      adopt this folder as <repo>'s worktree folder
#   wt                  pick which worktrees to open -- one Claude pane each
#   wt new <branch>...  add worktrees here, and open them
#   wt setup            re-run the setup hook on worktrees you pick
#   wt rm               remove worktrees you pick
#   wt switch           fuzzy-switch between open sessions (bound to prefix + S)
#
# Everything except `init` and `switch` locates the folder by walking up from
# the current directory looking for .wt.conf, so each works from the folder
# itself and from inside any worktree in it.
#
# The worktrees you pick open as panes in one window, side by side, each running
# the harness in its own checkout:
#
#   ┌──────────────────────┬──────────────────────┐
#   │ claude               │ claude               │
#   │ fix-login            │ feat-billing         │
#   └──────────────────────┴──────────────────────┘
#
# One session for the project rather than one per worktree, so every agent is on
# screen at once instead of behind a switch. Two panes sit side by side; three or
# more tile, which keeps each wide enough to be worth reading.
#
# Overrides:
#   DEV_HARNESS_CMD='claude -c' resume instead of starting fresh
#   DEV_HARNESS_CMD=            leave the pane at a plain shell
#   DEV_WORKTREE_SETUP='npm ci' one-off setup, instead of the repo's hook

set -euo pipefail

# Past this many at once you stop reviewing what the agents did and start waving
# it through, which costs more than the parallelism buys. Not a hard limit -- it
# asks rather than refuses.
MAX_SESSIONS=4

CONF_NAME=".wt.conf"

# ----------------------------------------------------------------- colours ---
# Tokyo Night, the same values wezterm.lua, tmux.conf and dev-session.sh use.
STATUS_BG="#222436"
STATUS_DIM="#414868"
STATUS_DARKEST="#1a1b26"

REPO_ACCENTS=("#7aa2f7" "#bb9af7" "#e0af68" "#9ece6a" "#f7768e" "#7dcfff")

HARNESS_CMD="${DEV_HARNESS_CMD-claude}"

die() { printf 'wt: %s\n' "$1" >&2; exit 1; }

# ------------------------------------------------------------------- badge ---
# Kept identical to dev-session.sh's, so a worktree session and a repo session
# are the same object on screen. The branch is a #() shell call rather than a
# value baked in at creation, so it follows a checkout instead of freezing.
badge() {  # badge <session> <accent> <worktree-path>
  tmux set -t "$1" @accent "$2"

  tmux set -t "$1" status-left \
    " #[bg=${2},fg=${STATUS_DARKEST},bold]  ${1} #[bg=${STATUS_BG},fg=${STATUS_DIM}]│ #[fg=#7aa2f7] #(git -C '${3}' rev-parse --abbrev-ref HEAD 2>/dev/null) #[fg=#414868]│"
}

# The pane-mode session holds several worktrees at once, so there is no single
# branch to put in the status bar. Each pane's header carries its own instead,
# through @role and tmux.conf's pane-border-format. A #() against
# #{pane_current_path} would have followed the focused pane, but tmux does not
# expand a format inside #() before running it -- it renders empty.
badge_repo() {  # badge_repo <session> <accent> <repo-name>
  tmux set -t "$1" @accent "$2"

  tmux set -t "$1" status-left \
    " #[bg=${2},fg=${STATUS_DARKEST},bold]  ${3} #[bg=${STATUS_BG},fg=${STATUS_DIM}]│"
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
# tmux reads "." and ":" in a target as address separators, so neither can
# survive into a session name. "/" is legal in one, but a branch like
# feat/billing would then read as a path in the status bar -- and the worktree
# directory flattens it the same way, so the two stay in step.
slug() {
  local s="${1//\//-}"
  s="${s//./_}"
  s="${s//:/_}"
  printf '%s' "$s"
}

# ------------------------------------------------------------------ config ---
# A folder of worktrees is not a git repository, so nothing in it says which
# checkout they belong to -- git only knows the other way round. The config
# records that, which is what lets every command run from here rather than from
# inside the repo.
#
# Read with sed rather than sourced: this file sits in a working directory and
# sourcing it would execute whatever ended up there.
conf_get() {  # conf_get <file> <key>
  sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*//p" "$1" | head -1
}

conf_write() {  # conf_write <dir> <main-checkout>
  cat > "$1/$CONF_NAME" <<EOF
# Written by \`wt\`. This folder holds git worktrees of the checkout below;
# every wt command run from here, or from inside one of them, reads this.
main = $2
EOF
}

# Walk up rather than looking only at the current directory, so the commands
# work from inside a worktree too -- the folder is then exactly one level up.
conf_find() {  # -> echoes the directory holding the config
  local dir="$PWD"
  while [[ $dir != / ]]; do
    [[ -f "$dir/$CONF_NAME" ]] && { printf '%s' "$dir"; return 0; }
    dir="$(dirname "$dir")"
  done
  return 1
}

# The main checkout that owns a directory: --git-common-dir points at the one
# .git every worktree of a repo shares, and its parent is the checkout itself.
# --show-toplevel would answer with the worktree instead.
main_of() {  # main_of <dir>
  local common
  common="$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
    || return 1
  dirname "$common"
}

# The checkout a directory belongs to, whether it is that checkout, a worktree
# of it, or the folder holding several of them. The last case is the normal one
# here: you stand in the worktree folder, and the repository is one of the
# things inside it, so asking you to name it would be asking a question the
# directory already answers.
#
# Every worktree of a repo reports the same main checkout, so a folder holding
# a clone and four of its worktrees still collapses to one answer. Two genuinely
# different repositories do not, and that is the one case worth refusing.
discover_main() {  # discover_main <dir> -> echoes the main checkout
  local dir="$1" child found seen=""

  if found="$(main_of "$dir")"; then
    printf '%s' "$found"
    return 0
  fi

  for child in "$dir"/*/; do
    [[ -d $child ]] || continue
    found="$(main_of "$child")" || continue
    [[ $seen == *"|$found|"* ]] && continue
    seen+="|$found|"
  done

  case "$(grep -o '|' <<< "$seen" | wc -l)" in
    0) return 1 ;;
    2) printf '%s' "${seen//|/}"; return 0 ;;
    *)
      printf 'wt: more than one repository here:\n' >&2
      sed 's/||/\n/g; s/|//g' <<< "$seen" | sed 's/^/wt:   /' >&2
      printf 'wt: name the one you mean: wt init <path-to-repo>\n' >&2
      return 2
      ;;
  esac
}

# POOL is the folder of worktrees; REPO the checkout they belong to. Resolved
# from the config, or adopted on the spot when the folder plainly already holds
# worktrees -- being asked to run `init` on a directory that is self-evidently
# a worktree folder is a question with only one answer.
require_pool() {
  if POOL="$(conf_find)"; then
    REPO="$(conf_get "$POOL/$CONF_NAME" main)"
    [[ -n $REPO ]] || die "$POOL/$CONF_NAME has no 'main =' line"
    [[ -d $REPO ]] || die "$REPO is gone -- fix 'main =' in $POOL/$CONF_NAME"
    return 0
  fi

  REPO="$(discover_main "$PWD")" && found=0 || found=$?
  (( found == 2 )) && exit 1
  (( found == 0 )) \
    || die "no repository in or under $PWD -- run: wt init <path-to-repo>"
  POOL="$PWD"
  conf_write "$POOL" "$REPO"
  printf 'wt: adopted this folder as worktrees of %s (%s)\n' \
    "$(basename "$REPO")" "$CONF_NAME" >&2
}

# ------------------------------------------------------------------- setup ---
# A worktree is a clean checkout: no node_modules, no .venv, and nothing that is
# gitignored -- so the .env an app needs and the dependencies an agent needs to
# build or test are all absent. An agent opened on a bare checkout fails in ways
# that look like its own mistake, so this is where a project says how to get
# from a checkout to a working tree.
#
# The hook runs with the worktree as its working directory and is handed
# $WORKTREE_MAIN, because gitignored files can only be copied from there.
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
# git is the source of truth for what exists -- it knows the ones whose
# directory has been deleted underneath it, which a listing would miss -- but
# the answer is narrowed to this folder. Worktrees of the same repo living
# somewhere else belong to whatever folder holds them, not to this one.
worktrees() {  # -> "<branch>\t<path>" per line
  git -C "$REPO" worktree list --porcelain | awk -v pool="$POOL/" '
    /^worktree / { path = substr($0, 10); if (main == "") main = path; next }
    /^branch /   { b = substr($0, 8); sub(/^refs\/heads\//, "", b)
                   if (path != main && index(path, pool) == 1) print b "\t" path }
  '
}

# Commits first, because that is what you are choosing between; uncommitted
# state second, because it is what would block a merge later.
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

# Nothing is ticked when this opens: which worktrees to work on is the question
# being asked, and answering it for you defeats the point of asking. Tab ticks,
# and the header says so -- multi-select is invisible otherwise.
pick() {  # pick <prompt> <header> ; worktrees on stdin, picks on stdout
  fzf --multi \
    --height 40% --layout=reverse \
    --delimiter='\t' --with-nth=1 \
    --prompt="$1 " \
    --header="$2" \
    --preview "$(preview_cmd)" \
    --preview-window=right:60%
}

confirm_count() {  # confirm_count <n>
  (( $1 > MAX_SESSIONS )) || return 0
  printf 'wt: %d selected. Past %d agents at once, reviewing what they did\n' \
    "$1" "$MAX_SESSIONS" >&2
  printf 'wt: turns into waving it through.\n' >&2
  read -r -p "wt: open all $1 anyway? [y/N] " reply
  [[ $reply == [yY] ]]
}

# ----------------------------------------------------------------- session ---
# One session for the project, one pane per worktree. Named <repo>-wt so it
# cannot collide with the bare basename `tmux dev` claims for the same repo.
wt_session() { printf '%s-wt' "$(slug "$(basename "$REPO")")"; }

# Which worktree paths already have a pane, so running this twice adds only what
# is new rather than opening a second pane onto the same checkout.
open_paths() {  # open_paths <session>
  tmux list-panes -t "=$1:" -F '#{pane_current_path}' 2>/dev/null || true
}

open_picked() {  # open_picked <"branch<TAB>path" lines>
  local session accent checksum branch path pane cols rows panes
  session="$(wt_session)"

  checksum="$(printf '%s' "$session" | cksum | cut -d' ' -f1)"
  accent="${REPO_ACCENTS[$((checksum % ${#REPO_ACCENTS[@]}))]}"

  # A detached session is 80x24 unless told otherwise, and panes are split out
  # of it -- at 80 columns a second pane is 40, which the harness cannot draw
  # itself into. Tested against 0 rather than emptiness: #{client_width}
  # resolves to 0, not to nothing, when no client is attached yet.
  if [[ -n ${TMUX:-} ]]; then
    cols="$(tmux display -p '#{client_width}' 2>/dev/null || true)"
    rows="$(tmux display -p '#{client_height}' 2>/dev/null || true)"
  fi
  (( ${cols:-0} > 0 )) || cols="$(tput cols 2>/dev/null || echo 80)"
  (( ${rows:-0} > 0 )) || rows="$(tput lines 2>/dev/null || echo 24)"

  while IFS=$'\t' read -r branch path; do
    [[ -n $path ]] || continue
    if [[ ! -d $path ]]; then
      printf 'wt: skipped %s -- directory is gone\n' "$branch" >&2
      continue
    fi

    if open_paths "$session" | grep -qxF "$path"; then
      printf 'wt: %s already open\n' "$branch"
      continue
    fi

    if tmux has-session -t "=$session" 2>/dev/null; then
      pane="$(tmux split-window -t "=$session:" -c "$path" -P -F '#{pane_id}')"
      # Re-tiled after every split rather than once at the end: each split has
      # to come out of a pane that still has room, and by the fourth the last
      # one is too small to divide.
      tmux select-layout -t "=$session:" tiled >/dev/null
    else
      tmux new-session -d -s "$session" -c "$path" -n worktrees \
        -x "$cols" -y "$rows"
      pane="$(tmux list-panes -t "=$session:" -F '#{pane_id}' | head -1)"
    fi

    # The branch, not a role: with several worktrees in one window the header is
    # the only thing saying which checkout a pane is looking at.
    tmux select-pane -t "$pane" -T "$branch"
    tmux set -p -t "$pane" @role "$branch"

    [[ -n $HARNESS_CMD ]] && tmux send-keys -t "$pane" "$HARNESS_CMD" C-m
    printf 'wt: %s\n' "$branch"
  done <<< "$1"

  tmux has-session -t "=$session" 2>/dev/null || die 'nothing opened'

  # Two read best side by side, full height each. Past that, tiled keeps every
  # pane wide enough to be worth reading rather than shaving columns off one.
  panes="$(tmux list-panes -t "=$session:" | wc -l)"
  if (( panes <= 2 )); then
    tmux select-layout -t "=$session:" even-horizontal >/dev/null
  else
    tmux select-layout -t "=$session:" tiled >/dev/null
  fi

  badge_repo "$session" "$accent" "$(basename "$REPO")"
  connect "$session"
}

# Attach last, once every pane exists, so the ones after the first are not built
# behind an already-attached client.
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
case "${1:-open}" in
  init)
    # No argument means this folder, which is where you already are -- the
    # repository is one of the things inside it, and naming it would be
    # answering a question the directory has already answered.
    target="${2:-.}"
    [[ -d $target ]] || die "no such directory: $target"

    # 2 means it already said what was wrong -- more than one repository, and
    # which ones -- so adding "no git repository" on top would contradict it.
    repo="$(discover_main "$target")" && found=0 || found=$?
    (( found == 2 )) && exit 1
    (( found == 0 )) || die "no git repository in or under $target"
    conf_write "$PWD" "$repo"
    printf 'wt: %s now holds worktrees of %s\n' "$PWD" "$repo"
    printf 'wt: add one with: wt new <branch>\n'
    ;;

  new)
    shift
    (( $# > 0 )) || die 'usage: wt new <branch> [branch...]'
    require_pool
    confirm_count "$#" || exit 1

    # Branch off the remote's default rather than whatever the checkout happens
    # to have out: a worktree started from a half-finished local branch inherits
    # work the agent never asked for, and each of these is merged back
    # separately. Fetched once for the batch rather than per branch.
    git -C "$REPO" fetch --quiet origin 2>/dev/null || true
    base="$(git -C "$REPO" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    [[ -n $base ]] || base="$(git -C "$REPO" rev-parse --abbrev-ref HEAD)"

    created=""
    for branch in "$@"; do
      dir="$POOL/$(slug "$branch")"
      if [[ -e $dir ]]; then
        printf 'wt: skipped %s -- %s already exists\n' "$branch" "$dir" >&2
        continue
      fi

      # An existing branch is checked out as-is; only a new one is cut from the
      # base. git refuses either way if it is already in another worktree.
      if git -C "$REPO" show-ref --quiet --verify "refs/heads/$branch"; then
        git -C "$REPO" worktree add "$dir" "$branch" || continue
      else
        git -C "$REPO" worktree add -b "$branch" "$dir" "$base" || continue
      fi

      run_setup "$dir" "$branch"
      created+="$branch"$'\t'"$dir"$'\n'
    done

    [[ -n $created ]] || die 'nothing created'
    open_picked "$created"
    ;;

  setup)
    require_pool
    picks="$(worktrees | pick 'setup>' \
      'Tab ticks · Enter runs setup on the ticked worktrees')" || exit 0
    [[ -n $picks ]] || exit 0

    while IFS=$'\t' read -r branch path; do
      [[ -n $path ]] || continue
      run_setup "$path" "$branch"
    done <<< "$picks"
    ;;

  rm)
    require_pool
    picks="$(worktrees | pick 'remove>' \
      'Tab ticks · Enter REMOVES the ticked worktrees · Ctrl-C cancels')" || exit 0
    [[ -n $picks ]] || exit 0

    while IFS=$'\t' read -r branch path; do
      [[ -n $path ]] || continue
      # Close the pane looking at it, if one is open -- the worktree is about
      # to stop existing and a pane sitting in a deleted directory is a shell
      # with nowhere to be.
      # Read line by line rather than word-split: a path may contain spaces,
      # and #{l:|} gives a separator that cannot appear in a pane id.
      while IFS= read -r entry; do
        [[ ${entry%%|*} == "$path" ]] || continue
        tmux kill-pane -t "${entry##*|}" 2>/dev/null || true
      done < <(tmux list-panes -t "=$(wt_session):" \
        -F '#{pane_current_path}#{l:|}#{pane_id}' 2>/dev/null || true)

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
    # Bound to prefix + S. No pool is resolved: this lists tmux sessions and
    # nothing else, and the binding fires from whatever pane has focus, very
    # often not a repository or a worktree folder at all.
    current="$(tmux display-message -p '#{session_name}' 2>/dev/null || true)"

    # Session paths are fetched one at a time rather than in a single format:
    # tmux emits "\t" in a format literally rather than as a tab, so there is no
    # separator safe against a path, and the -f filter is the same trick
    # dev-session.sh uses to read a path back reliably.
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
    require_pool
    available="$(worktrees)"
    [[ -n $available ]] \
      || die "no worktrees in $POOL -- add one with: wt new <branch>"

    picks="$(printf '%s\n' "$available" | pick 'worktree>' \
      'Tab ticks · Enter opens a Claude pane on each ticked worktree')" || exit 0
    [[ -n $picks ]] || exit 0

    confirm_count "$(printf '%s\n' "$picks" | grep -c .)" || exit 1
    open_picked "$picks"
    ;;

  *)
    die "unknown command: $1 (try: wt, wt init <repo>, wt new <branch>..., wt setup, wt rm)"
    ;;
esac

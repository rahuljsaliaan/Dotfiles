#!/usr/bin/env bash
#
# Open -- or re-attach to -- a tmux session laid out for working on one repo:
#
#   ┌───────────────────────────┬───────────────┐
#   │ editor  (nvim)            │ harness 1     │
#   │                           ├───────────────┤
#   ├───────────────────────────┤ harness 2     │
#   │ shell                     │               │
#   └───────────────────────────┴───────────────┘
#
#   dev [path]        # path defaults to the current directory
#
# The session takes the repo's directory name, and that name sits in the status
# bar on a colour derived from it -- so two of these open at once are told apart
# by colour rather than by reading. Each pane is colour-coded by role in its own
# header (see pane-border-format in tmux.conf).
#
# Overrides:
#   DEV_EDITOR_CMD=helix        command for the editor pane
#   DEV_HARNESS_CMD=            empty leaves the harness panes at a plain shell
#   DEV_HARNESS_CMD='claude -c' resume instead of starting fresh

set -euo pipefail

# ---------------------------------------------------------------- geometry ---
# Per cent of the window given to the harness column on the right.
HARNESS_COLUMN_WIDTH=35
# Per cent of the left column given to the shell beneath the editor.
SHELL_ROW_HEIGHT=25
# Per cent split between the two harness panes.
HARNESS_ROW_SPLIT=50

# ----------------------------------------------------------------- colours ---
# Tokyo Night, the same values wezterm.lua and tmux.conf use.
ROLE_EDITOR_COLOR="#7aa2f7"     # blue
ROLE_SHELL_COLOR="#9ece6a"      # green
ROLE_HARNESS_1_COLOR="#bb9af7"  # magenta
ROLE_HARNESS_2_COLOR="#e0af68"  # yellow

STATUS_BG="#222436"
STATUS_DIM="#414868"
STATUS_DARKEST="#1a1b26"

# The repo name is hashed into this list. Same family as the pane colours, far
# enough apart that neighbouring repos rarely land on the same one.
REPO_ACCENTS=("#7aa2f7" "#bb9af7" "#e0af68" "#9ece6a" "#f7768e" "#7dcfff")

# --------------------------------------------------------------- arguments ---
target="${1:-.}"
if [[ ! -d $target ]]; then
  printf 'dev: no such directory: %s\n' "$target" >&2
  exit 1
fi
REPO="$(cd "$target" && pwd)"

# tmux reads "." and ":" in a target as address separators, so a directory like
# "my.project" would be parsed as a window/pane reference rather than a name.
SESSION="$(basename "$REPO" | tr '.:' '__')"

EDITOR_CMD="${DEV_EDITOR_CMD:-nvim}"
# Assigned with :- rather than :=, so DEV_HARNESS_CMD= (set but empty) is
# honoured as "no harness" instead of falling back to the default.
HARNESS_CMD="${DEV_HARNESS_CMD-claude}"

# ------------------------------------------------------------------ attach ---
# "=" anchors the name: without it tmux prefix-matches, so `dev web` would
# attach to an existing "web-frontend" session.
connect() {
  if [[ -n ${TMUX:-} ]]; then
    exec tmux switch-client -t "=$SESSION"
  fi
  exec tmux attach-session -t "=$SESSION"
}

if tmux has-session -t "=$SESSION" 2>/dev/null; then
  connect
fi

# ------------------------------------------------------------------ layout ---
tmux new-session -d -s "$SESSION" -c "$REPO" -n main

# Panes are addressed by id (%3) rather than index. Indices are positional, so
# every split renumbers the panes around it and an index captured earlier can
# quietly come to mean a different pane; an id never moves.
editor="$(tmux list-panes -t "$SESSION:main" -F '#{pane_id}')"
harness_1="$(tmux split-window -h -l "${HARNESS_COLUMN_WIDTH}%" \
  -t "$editor" -c "$REPO" -P -F '#{pane_id}')"
harness_2="$(tmux split-window -v -l "${HARNESS_ROW_SPLIT}%" \
  -t "$harness_1" -c "$REPO" -P -F '#{pane_id}')"
shell_pane="$(tmux split-window -v -l "${SHELL_ROW_HEIGHT}%" \
  -t "$editor" -c "$REPO" -P -F '#{pane_id}')"

# ------------------------------------------------------------------- roles ---
# The title is what tmux itself shows; the two user options are what this
# repo's pane-border-format reads.
role() {  # role <pane-id> <label> <colour>
  tmux select-pane -t "$1" -T "$2"
  tmux set -p -t "$1" @role "$2"
  tmux set -p -t "$1" @role_color "$3"
}

role "$editor"     "editor"    "$ROLE_EDITOR_COLOR"
role "$shell_pane" "shell"     "$ROLE_SHELL_COLOR"
role "$harness_1"  "harness 1" "$ROLE_HARNESS_1_COLOR"
role "$harness_2"  "harness 2" "$ROLE_HARNESS_2_COLOR"

# ---------------------------------------------------------------- commands ---
tmux send-keys -t "$editor" "$EDITOR_CMD" C-m

if [[ -n $HARNESS_CMD ]]; then
  tmux send-keys -t "$harness_1" "$HARNESS_CMD" C-m
  tmux send-keys -t "$harness_2" "$HARNESS_CMD" C-m
fi

# ------------------------------------------------------- repo colour + name ---
# cksum is in coreutils and gives the same number for the same name on every
# machine, so a repo keeps its colour. $RANDOM or a hash of the full path would
# not survive a move.
checksum="$(printf '%s' "$SESSION" | cksum | cut -d' ' -f1)"
accent="${REPO_ACCENTS[$((checksum % ${#REPO_ACCENTS[@]}))]}"

# status-left is a session option, so this colours only this repo's window and
# leaves any other session alone.
tmux set -t "$SESSION" status-left \
  " #[bg=${accent},fg=${STATUS_DARKEST},bold]  ${SESSION} #[bg=${STATUS_BG},fg=${STATUS_DIM}]│"

tmux select-pane -t "$editor"
connect

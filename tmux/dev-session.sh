#!/usr/bin/env bash
#
# Open -- or re-attach to -- a tmux session laid out for working on one repo:
#
#   ┌────────────────────────────────────────────┬──────────────────────┐
#   │ editor  (nvim)                             │ harness 1            │
#   │                                            │                      │
#   │                                            │                      │
#   │                                            ├──────────────────────┤
#   │                                            │ harness 2            │
#   │                                            │                      │
#   ├────────────────────────────────────────────┤                      │
#   │ shell                                      │                      │
#   └────────────────────────────────────────────┴──────────────────────┘
#
#   dev [path]        # path defaults to the current directory
#
# The session takes the repo's directory name, and that name sits in the status
# bar on a colour derived from it -- so two of these open at once are told apart
# by colour rather than by reading. Each pane is colour-coded by role in its own
# header (see pane-border-format in tmux.conf).
#
# Overrides:
#   DEV_EDITOR_CMD=helix        command for the editor pane (default: nvim .)
#   DEV_HARNESS_CMD=            empty leaves the harness panes at a plain shell
#   DEV_HARNESS_CMD='claude -c' resume instead of starting fresh
#   DEV_ACCENT='#f7768e'        pick the repo's colour instead of deriving it,
#                               for the status badge and the window frame alike

set -euo pipefail

# ---------------------------------------------------------------- geometry ---
# Per cent of the window given to the harness column on the right.
HARNESS_COLUMN_WIDTH=33
# Per cent of the left column given to the shell beneath the editor.
SHELL_ROW_HEIGHT=23
# Per cent split between the two harness panes.
HARNESS_ROW_SPLIT=50

# ----------------------------------------------------------------- colours ---
# Tokyo Night, the same values wezterm.lua and tmux.conf use. Panes are not
# colour-coded by role any more -- their headers name what they are, and the
# only colour in a pane header now is the one marking focus.
STATUS_BG="#222436"
STATUS_DIM="#414868"
STATUS_DARKEST="#1a1b26"

# The repo name is hashed into this list. Same family as the pane colours, far
# enough apart that neighbouring repos rarely land on the same one.
REPO_ACCENTS=("#7aa2f7" "#bb9af7" "#e0af68" "#9ece6a" "#f7768e" "#7dcfff")

# ------------------------------------------------------------------- badge ---
# The repo's name on its accent, in the status bar. A function because three
# callers need it: first paint, the --recolor entry point below, and nothing
# else may drift from the glyphs in here.
# The branch is a #() shell call rather than a value baked in at creation, so it
# follows a checkout instead of freezing at whatever was current when the
# session opened. tmux re-runs it every status-interval (5s, set in tmux.conf).
badge() {  # badge <session> <accent> <repo-path>
  tmux set -t "$1" status-left \
    " #[bg=${2},fg=${STATUS_DARKEST},bold]  ${1} #[bg=${STATUS_BG},fg=${STATUS_DIM}]│ #[fg=#7aa2f7] #(git -C '${3}' rev-parse --abbrev-ref HEAD 2>/dev/null) #[fg=#414868]│"
}

# ---------------------------------------------------------------- recolour ---
# `:recolor` from inside a session -- prefix + : -- aliased in tmux.conf. Takes
# a colour, or picks one at random when given none. Only repaints; the layout
# and the panes are left alone.
if [[ ${1:-} == --recolor ]]; then
  session="$(tmux display-message -p '#{session_name}')"
  current="$(tmux show -t "$session" -v status-left 2>/dev/null \
    | grep -o 'bg=#[0-9a-f]\{6\}' | head -1 | cut -d= -f2)"

  new="${2:-}"
  if [[ -z $new ]]; then
    # Excluding the colour already on screen, so a random pick always visibly
    # changes something rather than silently landing on the same one.
    choices=()
    for c in "${REPO_ACCENTS[@]}"; do
      [[ $c != "$current" ]] && choices+=("$c")
    done
    new="${choices[RANDOM % ${#choices[@]}]}"
  fi

  badge "$session" "$new" \
    "$(tmux list-sessions -f "#{==:#{session_name},$session}" -F '#{session_path}')"

  # Written straight to the client's terminal rather than printed: run-shell
  # captures stdout, so an OSC sent the normal way would be swallowed and never
  # reach wezterm. Going to client_tty side-steps tmux, which also means no
  # passthrough wrapper is needed -- tmux is not in the path at all.
  tty="$(tmux display-message -p '#{client_tty}')"
  if [[ -n $tty ]]; then
    printf '\033]1337;SetUserVar=tmux_dev_accent=%s\007' \
      "$(printf '%s' "$new" | base64 | tr -d '\n')" > "$tty"
  fi

  exit 0
fi

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

# Two checkouts can share a directory name -- ~/work/api and ~/personal/api both
# reduce to "api". Attaching by that name alone silently drops the second repo
# into the first one's session: every pane is in the other checkout, so the
# prompt, the status line and the editor all report a branch that belongs to a
# different repo. Whichever path claims the plain name keeps it; any other path
# gets its own session, suffixed with a digest of the path so the same repo
# still lands in the same session every time.
#
# list-sessions rather than `display -p -t`: display evaluates a format in the
# context of a client, and with nothing attached yet #{session_path} is empty
# there. tmux's own -f filter rather than parsing the listing: tmux emits "\t"
# in a format literally rather than as a tab, so splitting the output on one
# silently matches nothing -- and a filter also survives spaces in a path.
# 2>/dev/null covers there being no server at all, where this is empty and the
# plain name is free by definition.
existing="$(tmux list-sessions -f "#{==:#{session_name},$SESSION}" \
  -F '#{session_path}' 2>/dev/null || true)"
if [[ -n $existing && $existing != "$REPO" ]]; then
  SESSION="$SESSION-$(printf '%s' "$REPO" | cksum | cut -d' ' -f1 | tail -c 5)"
fi

# "nvim ." rather than "nvim": handed a directory, LazyVim opens the file
# explorer on it, where a bare nvim only reaches the dashboard. The pane is
# already in $REPO, so "." is the repo.
EDITOR_CMD="${DEV_EDITOR_CMD:-nvim .}"
# Assigned with :- rather than :=, so DEV_HARNESS_CMD= (set but empty) is
# honoured as "no harness" instead of falling back to the default.
HARNESS_CMD="${DEV_HARNESS_CMD-claude}"

# ------------------------------------------------------------ repo colour ---
# cksum is in coreutils and gives the same number for the same name on every
# machine, so a repo keeps its colour. $RANDOM or a hash of the full path would
# not survive a move. Derived here rather than beside the status bar below,
# because connect() needs it on the re-attach path too.
checksum="$(printf '%s' "$SESSION" | cksum | cut -d' ' -f1)"
accent="${DEV_ACCENT:-${REPO_ACCENTS[$((checksum % ${#REPO_ACCENTS[@]}))]}}"

# Hand that colour to wezterm, which draws the frame around the whole window --
# tmux has no outer border of its own, only dividers between panes.
#
# OSC 1337 SetUserVar is wezterm's channel for this; the handler in wezterm.lua
# turns the variable into a window_frame override. The value is base64, which is
# what the sequence expects.
#
# Inside tmux the sequence has to be wrapped in the DCS passthrough form, with
# every ESC in the payload doubled, or tmux consumes it rather than forwarding
# it to the terminal. That also needs `allow-passthrough on`, set in tmux.conf.
frame_accent() {
  local b64
  b64="$(printf '%s' "$1" | base64 | tr -d '\n')"

  if [[ -n ${TMUX:-} ]]; then
    printf '\033Ptmux;\033\033]1337;SetUserVar=tmux_dev_accent=%s\007\033\\' "$b64"
  else
    printf '\033]1337;SetUserVar=tmux_dev_accent=%s\007' "$b64"
  fi
}

# ------------------------------------------------------------------ attach ---
# "=" anchors the name: without it tmux prefix-matches, so `dev web` would
# attach to an existing "web-frontend" session.
connect() {
  # Both paths through this script end here, so colouring the frame in one
  # place covers a fresh session and a re-attach alike.
  frame_accent "$accent"

  # Switching from inside tmux hands this window to another session, which
  # sends its own colour on the way in, so there is nothing to clean up here.
  if [[ -n ${TMUX:-} ]]; then
    exec tmux switch-client -t "=$SESSION"
  fi

  # Deliberately not exec: attach-session returns when the session is detached
  # or killed, and the frame belongs to the session rather than to the window,
  # so it has to come back off. exec would replace this script and leave the
  # window framed in the colour of a session that is no longer there.
  # || true because of set -e: attach-session exits non-zero when the session is
  # killed out from under the client rather than detached from, and that is
  # precisely the case the frame has to be cleared for -- without this the
  # script dies here and the window keeps the colour of a dead session.
  tmux attach-session -t "=$SESSION" || true
  frame_accent ""
}

if tmux has-session -t "=$SESSION" 2>/dev/null; then
  connect
fi

# ------------------------------------------------------------------ layout ---
# A detached session is 80x24 unless told otherwise, and the splits below are
# percentages -- so without this they divide up 80x24 rather than the terminal
# that is a moment away from attaching, and the small panes land on tmux's
# minimum size instead of their share. Build the window at the real size.
if [[ -n ${TMUX:-} ]]; then
  cols="$(tmux display -p '#{client_width}')"
  rows="$(tmux display -p '#{client_height}')"
else
  cols="$(tput cols 2>/dev/null || echo 80)"
  rows="$(tput lines 2>/dev/null || echo 24)"
fi

# Named "dev", not "main": the status bar's window list renders "#I #W", so a
# window called main shows up as "1 main" next to the repo badge and reads as a
# git branch that is nothing of the sort. The real branch is in the badge.
tmux new-session -d -s "$SESSION" -c "$REPO" -n dev -x "$cols" -y "$rows"

# Panes are addressed by id (%3) rather than index. Indices are positional, so
# every split renumbers the panes around it and an index captured earlier can
# quietly come to mean a different pane; an id never moves.
editor="$(tmux list-panes -t "$SESSION:dev" -F '#{pane_id}')"
harness_1="$(tmux split-window -h -l "${HARNESS_COLUMN_WIDTH}%" \
  -t "$editor" -c "$REPO" -P -F '#{pane_id}')"
harness_2="$(tmux split-window -v -l "${HARNESS_ROW_SPLIT}%" \
  -t "$harness_1" -c "$REPO" -P -F '#{pane_id}')"
shell_pane="$(tmux split-window -v -l "${SHELL_ROW_HEIGHT}%" \
  -t "$editor" -c "$REPO" -P -F '#{pane_id}')"

# ------------------------------------------------------------------- roles ---
# The title is what tmux itself shows; the two user options are what this
# repo's pane-border-format reads.
role() {  # role <pane-id> <label>
  tmux select-pane -t "$1" -T "$2"
  tmux set -p -t "$1" @role "$2"
}

role "$editor"     "editor"
role "$shell_pane" "shell"
role "$harness_1"  "harness 1"
role "$harness_2"  "harness 2"

# ---------------------------------------------------------------- commands ---
tmux send-keys -t "$editor" "$EDITOR_CMD" C-m

if [[ -n $HARNESS_CMD ]]; then
  tmux send-keys -t "$harness_1" "$HARNESS_CMD" C-m
  tmux send-keys -t "$harness_2" "$HARNESS_CMD" C-m
fi

# ------------------------------------------------------- repo colour + name ---
# status-left is a session option, so this colours only this repo's window and
# leaves any other session alone.
badge "$SESSION" "$accent" "$REPO"

tmux select-pane -t "$editor"
connect

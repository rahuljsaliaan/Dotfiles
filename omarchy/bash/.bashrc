# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source "$OMARCHY_PATH/default/bash/rc"

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

# tdl: Omarchy's tmux dev layout (editor | AI, terminal below), with pane sizes
# tuned by hand: terminal 22% of the height (Omarchy: 15%), AI 40% of the
# width (Omarchy: 30%). Also focuses the editor at the end; Omarchy's version
# selects an unset variable ($opencode_pane), so focus stayed where it was.
# Usage: tdl <ai> [<second_ai>]    e.g. tdl claude
tdl() {
  [[ -z $1 ]] && { echo "Usage: tdl <c|cx|codex|other_ai> [<second_ai>]"; return 1; }
  [[ -z $TMUX ]] && { echo "You must start tmux to use tdl."; return 1; }

  local current_dir="${PWD}"
  local editor_pane="$TMUX_PANE" ai_pane ai2_pane
  local ai="$1" ai2="$2"

  tmux rename-window -t "$editor_pane" "$(basename "$current_dir")"
  tmux split-window -v -p 22 -t "$editor_pane" -c "$current_dir"
  ai_pane=$(tmux split-window -h -p 40 -t "$editor_pane" -c "$current_dir" -P -F '#{pane_id}')

  if [[ -n $ai2 ]]; then
    ai2_pane=$(tmux split-window -v -t "$ai_pane" -c "$current_dir" -P -F '#{pane_id}')
    tmux send-keys -t "$ai2_pane" "$ai2" C-m
  fi

  tmux send-keys -t "$ai_pane" "$ai" C-m
  tmux send-keys -t "$editor_pane" "$EDITOR ." C-m
  tmux select-pane -t "$editor_pane"
}

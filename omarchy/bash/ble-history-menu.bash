# History dropdown that opens as you type, with fzf, for ble.sh.
#
# Typing the first character of a command opens a small fzf list of your
# history under the prompt (newest first), and the rest of your typing filters
# it, like PowerShell's history list view in Windows Terminal.
#   Enter      put the highlighted entry on the line (it does not run it)
#   Esc        close the list and keep what you typed
#   no match   the list closes by itself and you keep typing on the line
#   Backspace  on an empty search closes the list with an empty line
#
# It opens only for a key you press on an empty line: when more input is
# already queued (a paste, or tmux send-keys from tdl or another tool typing a
# command into the shell) it stays out of the way.
# Loaded by ~/.bashrc once ble.sh is loaded.

# Unique history entries, newest first, one per line (multi-line ones skipped).
function ble/hfzf/entries {
  local count i entry
  local -A seen=()
  ble/history/initialize
  ble/history/get-count -v count
  for ((i = count - 1; i >= 0; i--)); do
    ble/history/get-entry -v entry "$i"
    entry=${entry%"${entry##*[![:space:]]}"}
    [[ $entry && $entry != *$'\n'* && ! ${seen[$entry]-} ]] || continue
    seen[$entry]=1
    printf '%s\n' "$entry"
  done
}

# Runs inside ble.sh's command layout, like a `bind -x` function.
function ble/hfzf/run {
  local out ext
  out=$(ble/hfzf/entries | fzf \
    --height 12 --layout=reverse --border --info=inline \
    --scheme=history --query "$READLINE_LINE" \
    --bind 'esc:print-query,zero:print-query' \
    --bind 'bspace:backward-delete-char/eof')
  ext=$?
  # Enter prints the entry; Esc and no-match print the search (print-query).
  # Backspace past the start aborts with nothing: an empty line.
  if ((ext == 130)); then
    READLINE_LINE=
  else
    READLINE_LINE=$out
  fi
  READLINE_POINT=${#READLINE_LINE}
}

function ble/hfzf/after-insert {
  ((${#_ble_edit_str} == 1)) || return 0
  [[ $_ble_edit_str == [![:space:]] ]] || return 0
  [[ $_ble_decode_keymap == emacs ]] || return 0
  ble/decode/has-input && return 0
  ble/widget/.EDIT_COMMAND ble/hfzf/run
}
ble/function#advice after ble/widget/self-insert ble/hfzf/after-insert

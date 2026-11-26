# History dropdown under the prompt while typing, for ble.sh, matched by fzf.
#
# You type on the normal prompt line; under it the best history matches for
# what you typed are listed (fzf's fuzzy ranking, newest first on ties), like
# PowerShell's history list view in Windows Terminal.
#   Down / Up  move through the list, filling the line with that entry
#              (Up past the top goes back to what you typed)
#   Enter      runs the line, as always
# Every other key edits as normal: the list is only a panel, never a mode that
# takes the keyboard. With nothing typed, or no match, Up and Down step
# through history as usual. Loaded by ~/.bashrc once ble.sh is loaded.

: "${BLE_HISTORY_MENU_MAX:=8}"

_ble_hmenu_prefix=   # the typed text the list was built for
_ble_hmenu_items=()  # matches, best first
_ble_hmenu_index=-1  # highlighted entry; -1 = the typed text itself
_ble_hmenu_drawn=    # the line the panel was last drawn for
_ble_hmenu_cache=    # unique history entries, newest first, one per line
_ble_hmenu_cache_count=-1

# Rebuild the unique-entry list only when history has grown.
function ble/hmenu/entries {
  local count i entry
  ble/history/initialize
  ble/history/get-count -v count
  ((count == _ble_hmenu_cache_count)) && return 0
  local -A seen=()
  local -a list=()
  for ((i = count - 1; i >= 0; i--)); do
    ble/history/get-entry -v entry "$i"
    entry=${entry%"${entry##*[![:space:]]}"}
    [[ $entry && $entry != *$'\n'* && ! ${seen[$entry]-} ]] || continue
    seen[$entry]=1
    list+=("$entry")
  done
  printf -v _ble_hmenu_cache '%s\n' "${list[@]}"
  _ble_hmenu_cache_count=$count
}

function ble/hmenu/collect {
  local prefix=$1 line
  _ble_hmenu_items=()
  [[ $prefix =~ [^[:space:]] ]] || return 1
  ble/hmenu/entries
  while IFS= read -r line; do
    [[ $line == "$prefix" ]] && continue
    _ble_hmenu_items+=("$line")
  done < <(printf '%s' "$_ble_hmenu_cache" |
    fzf --filter="$prefix" --scheme=history | head -n "$BLE_HISTORY_MENU_MAX")
  ((${#_ble_hmenu_items[@]}))
}

function ble/hmenu/draw {
  local cols=${COLUMNS:-80} i item text=
  for i in "${!_ble_hmenu_items[@]}"; do
    item=${_ble_hmenu_items[i]}
    ((${#item} > cols - 4)) && item=${item:0:cols-5}…
    if ((i == _ble_hmenu_index)); then
      text+=$'\e[1;7m'" $item "$'\e[m'
    else
      text+=$'\e[38;2;92;99;112m'" $item"$'\e[m'
    fi
    ((i < ${#_ble_hmenu_items[@]} - 1)) && text+=$'\n'
  done
  ble/edit/info/show ansi "$text"
  local ret; ble/hmenu/typed
  _ble_hmenu_drawn=$ret
}

function ble/hmenu/clear {
  _ble_hmenu_items=() _ble_hmenu_index=-1
  local ret; ble/hmenu/typed
  _ble_hmenu_drawn=$ret
  ble/edit/info/default
}

# What was typed. While the grey suggestion shows, ble.sh keeps it in the
# line buffer after the cursor, so only the part before the cursor counts.
function ble/hmenu/typed {
  if [[ $_ble_decode_keymap == auto_complete ]]; then
    ret=${_ble_edit_str:0:_ble_edit_ind}
  else
    ret=$_ble_edit_str
  fi
}

# Rebuild the list whenever the typed text changes (not by Up/Down).
function ble/hmenu/update {
  local ret; ble/hmenu/typed
  [[ $ret == "$_ble_hmenu_drawn" ]] && return 0
  if ((_ble_hmenu_index >= 0)) && [[ $ret == "${_ble_hmenu_items[_ble_hmenu_index]}" ]]; then
    return 0
  fi
  _ble_hmenu_index=-1
  _ble_hmenu_prefix=$ret
  if ble/hmenu/collect "$_ble_hmenu_prefix"; then
    ble/hmenu/draw
  else
    ble/hmenu/clear
  fi
}

function ble/hmenu/idle {
  ble/util/idle.wait-user-input
  ble/hmenu/update
}
ble/util/idle.push-background ble/hmenu/idle

function ble/hmenu/select {
  # Drop the grey suggestion first; the chosen entry replaces the line.
  [[ $_ble_decode_keymap == auto_complete ]] && ble/widget/auto_complete/cancel
  _ble_hmenu_index=$1
  local line=$_ble_hmenu_prefix
  ((_ble_hmenu_index >= 0)) && line=${_ble_hmenu_items[_ble_hmenu_index]}
  ble-edit/content/reset "$line" edit
  _ble_edit_ind=${#line}
  ble/hmenu/draw
}

function ble/widget/hmenu-down {
  ble/hmenu/update
  local n=${#_ble_hmenu_items[@]}
  if ((n == 0)); then
    ble/widget/history-next
    ble/hmenu/clear
  elif ((_ble_hmenu_index < n - 1)); then
    ble/hmenu/select $((_ble_hmenu_index + 1))
  fi
}

function ble/widget/hmenu-up {
  ble/hmenu/update
  local n=${#_ble_hmenu_items[@]}
  if ((n == 0)); then
    ble/widget/history-prev
    ble/hmenu/clear
  elif ((_ble_hmenu_index >= 0)); then
    ble/hmenu/select $((_ble_hmenu_index - 1))
  else
    ble/hmenu/select $((n - 1))
  fi
}

ble-bind -m emacs -f down hmenu-down
ble-bind -m emacs -f up hmenu-up
# The same while the grey suggestion shows (ble.sh's auto_complete keymap).
ble-bind -m auto_complete -f down hmenu-down
ble-bind -m auto_complete -f up hmenu-up

# Clear the list when a command runs, so it never sits under the output.
function ble/hmenu/on-exec { ble/hmenu/clear; _ble_hmenu_drawn=; }
blehook PREEXEC+=ble/hmenu/on-exec
blehook PRECMD+=ble/hmenu/on-exec

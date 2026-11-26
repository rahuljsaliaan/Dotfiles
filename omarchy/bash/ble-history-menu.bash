# History dropdown while typing, for ble.sh.
#
# As you type, the newest history entries that start with the typed text are
# listed under the prompt. Up and Down walk through the list, filling the line
# with the highlighted entry; Up past the top goes back to what you typed.
# Enter runs the line as usual. Every other key edits as normal: the list is
# only a panel, not a menu mode that takes over the keyboard (ble.sh's own
# completion menu did, and swallowed Esc and Ctrl+U).
#
# With nothing typed, or no match, Up and Down step through history as usual.
# Loaded by ~/.bashrc once ble.sh is loaded.

: "${BLE_HISTORY_MENU_MAX:=8}"

_ble_hmenu_prefix=   # the typed text the list was built for
_ble_hmenu_items=()  # matching entries, newest first
_ble_hmenu_index=-1  # highlighted entry; -1 = the typed text itself
_ble_hmenu_drawn=    # the line the panel was last drawn for

# Fill _ble_hmenu_items with up to MAX unique entries starting with $1.
function ble/hmenu/collect {
  local prefix=$1 count i entry
  local -A seen=()
  _ble_hmenu_items=()
  [[ $prefix ]] || return 1
  ble/history/initialize
  ble/history/get-count -v count
  for ((i = count - 1; i >= 0; i--)); do
    ble/history/get-entry -v entry "$i"
    entry=${entry%"${entry##*[![:space:]]}"}  # trailing blanks
    [[ $entry == "$prefix"?* && $entry != *$'\n'* ]] || continue
    [[ ${seen[$entry]-} ]] && continue
    seen[$entry]=1
    _ble_hmenu_items+=("$entry")
    ((${#_ble_hmenu_items[@]} >= BLE_HISTORY_MENU_MAX)) && break
  done
  ((${#_ble_hmenu_items[@]}))
}

function ble/hmenu/hide {
  _ble_hmenu_items=() _ble_hmenu_index=-1 _ble_hmenu_prefix=
  ble/edit/info/default
}

# Draw the list in ble.sh's info panel, under the prompt.
function ble/hmenu/draw {
  local cols=${COLUMNS:-80} i item text= mark
  for i in "${!_ble_hmenu_items[@]}"; do
    item=${_ble_hmenu_items[i]}
    ((${#item} > cols - 4)) && item=${item:0:cols-5}…
    if ((i == _ble_hmenu_index)); then
      text+=$'\e[1;7m'" $item "$'\e[m'
    else
      # Typed part plain, the rest dim, like the inline suggestion.
      text+=" ${item:0:${#_ble_hmenu_prefix}}"$'\e[38;2;92;99;112m'"${item:${#_ble_hmenu_prefix}}"$'\e[m'
    fi
    ((i < ${#_ble_hmenu_items[@]} - 1)) && text+=$'\n'
  done
  ble/edit/info/show ansi "$text"
  _ble_hmenu_drawn=$_ble_edit_str
}

# Rebuild the list whenever the line changes by typing (not by our own Up/Down).
function ble/hmenu/update {
  [[ $_ble_edit_str == "$_ble_hmenu_drawn" ]] && return 0
  if ((_ble_hmenu_index >= 0)) && [[ $_ble_edit_str == "${_ble_hmenu_items[_ble_hmenu_index]}" ]]; then
    return 0
  fi
  _ble_hmenu_index=-1
  _ble_hmenu_prefix=$_ble_edit_str
  if ble/hmenu/collect "$_ble_hmenu_prefix"; then
    ble/hmenu/draw
  else
    _ble_hmenu_drawn=$_ble_edit_str
    ble/edit/info/default
  fi
}

function ble/hmenu/idle {
  ble/util/idle.wait-user-input
  ble/hmenu/update
}
ble/util/idle.push-background ble/hmenu/idle

function ble/hmenu/select {
  _ble_hmenu_index=$1
  local line=$_ble_hmenu_prefix
  ((_ble_hmenu_index >= 0)) && line=${_ble_hmenu_items[_ble_hmenu_index]}
  ble-edit/content/reset "$line" edit
  _ble_edit_ind=${#line}
  ble/hmenu/draw
}

# A line recalled from history is not typed text: no list for it, so the next
# Up or Down keeps walking history.
function ble/hmenu/skip-line {
  _ble_hmenu_items=() _ble_hmenu_index=-1
  _ble_hmenu_drawn=$_ble_edit_str
  ble/edit/info/default
}

function ble/widget/hmenu-down {
  ble/hmenu/update
  local n=${#_ble_hmenu_items[@]}
  if ((n == 0)); then
    ble/widget/history-next
    ble/hmenu/skip-line
  elif ((_ble_hmenu_index < n - 1)); then
    ble/hmenu/select $((_ble_hmenu_index + 1))
  fi
}

function ble/widget/hmenu-up {
  ble/hmenu/update
  local n=${#_ble_hmenu_items[@]}
  if ((n == 0)); then
    ble/widget/history-prev
    ble/hmenu/skip-line
  elif ((_ble_hmenu_index >= 0)); then
    ble/hmenu/select $((_ble_hmenu_index - 1))
  else
    ble/hmenu/select $((n - 1))
  fi
}

ble-bind -m emacs -f down hmenu-down
ble-bind -m emacs -f up hmenu-up

# Clear the list when a command runs, so it never sits under the output.
function ble/hmenu/on-exec { ble/hmenu/hide; _ble_hmenu_drawn=; }
blehook PREEXEC+=ble/hmenu/on-exec
blehook PRECMD+=ble/hmenu/on-exec

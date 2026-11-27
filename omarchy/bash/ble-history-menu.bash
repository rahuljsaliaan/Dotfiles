# History dropdown under the prompt while typing, for ble.sh, matched by fzf.
#
# You type on the normal prompt line; under it the best history matches for
# what you typed are listed (fzf's fuzzy ranking, newest first on ties), like
# PowerShell's history list view in Windows Terminal.
#   Down / Up  move through the list, filling the line with that entry
#              (Up past the top goes back to what you typed)
#   Enter      runs the line, as always
#   Esc        closes the list (and undoes a highlighted pick) until you type
# Every other key edits as normal: the list is only a panel, never a mode that
# takes the keyboard. With nothing typed, or no match, Up and Down step
# through history as usual. Loaded by ~/.bashrc once ble.sh is loaded.

: "${BLE_HISTORY_MENU_MAX:=8}"
_ble_hmenu_total=0

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
  _ble_hmenu_total=0
  # One fzf process, fed from a here-string (no pipe or subshell around it).
  local -a matches=()
  ble/util/assign-array matches 'fzf --filter="$prefix" --scheme=history <<< "$_ble_hmenu_cache"'
  for line in "${matches[@]}"; do
    [[ $line == "$prefix" ]] && continue
    ((++_ble_hmenu_total <= BLE_HISTORY_MENU_MAX)) && _ble_hmenu_items+=("$line")
  done
  ((${#_ble_hmenu_items[@]}))
}

# Colours from the current Omarchy theme (Shinkai values as the fallback),
# as "r;g;b" for 24-bit SGR.
function ble/hmenu/load-colors {
  local -A c=(
    [accent]='#82aaff' [selection]='#1b3457' [muted]='#464b5d'
    [lighter_background]='#162740' [foreground]='#a6accd'
    [dark_foreground]='#525975' [bright_foreground]='#c8d3f5'
  )
  local file=~/.local/state/omarchy/current/theme/colors.toml key value
  if [[ -r $file ]]; then
    while IFS='= ' read -r key value; do
      [[ $key ]] || continue
      value=${value//\"/}
      [[ ${c[$key]+set} && $value == \#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F] ]] && c[$key]=$value
    done < "$file"
  fi
  local name hex
  declare -gA _ble_hmenu_rgb=()
  for name in "${!c[@]}"; do
    hex=${c[$name]#\#}
    _ble_hmenu_rgb[$name]="$((16#${hex:0:2}));$((16#${hex:2:2}));$((16#${hex:4:2}))"
  done
}
ble/hmenu/load-colors

# One entry with the typed letters picked out in the accent colour (the
# first in-order match of each, case-insensitive, close to what fzf matched).
# $1 entry, $2 colour of the other letters; result in ret.
function ble/hmenu/mark-match {
  local item=$1 base=$2 typed=${_ble_hmenu_prefix,,} i j=0 ch out=
  local hi=$'\e[1;38;2;'"${_ble_hmenu_rgb[accent]}m" lo=$'\e[22;38;2;'"${base}m"
  for ((i = 0; i < ${#item}; i++)); do
    ch=${item:i:1}
    if ((j < ${#typed})) && [[ ${ch,,} == "${typed:j:1}" ]]; then
      out+=$hi$ch$lo; ((j++))
    else
      out+=$ch
    fi
  done
  ret=$lo$out
}

# The list as a rounded box under the prompt: entries on the theme's lighter
# background, the highlighted one on the selection colour with an accent bar,
# and a footer with the keys and the match count.
function ble/hmenu/draw {
  local -A rgb; local k; for k in "${!_ble_hmenu_rgb[@]}"; do rgb[$k]=${_ble_hmenu_rgb[$k]}; done
  local cols=${COLUMNS:-80} n=${#_ble_hmenu_items[@]} i item w=0 ret
  local hint=" ↑↓ select  enter run " count=" $n/$_ble_hmenu_total "
  ((_ble_hmenu_total > n)) || count=" $n "
  for item in "${_ble_hmenu_items[@]}"; do ((${#item} > w)) && w=${#item}; done
  local min=$((${#hint} + ${#count} + 2))
  ((w + 3 < min)) && w=$((min - 3))
  ((w > cols - 8)) && w=$((cols - 8))
  local inner=$((w + 3))   # bar + space + text + space
  local B=$'\e[22;38;2;'"${rgb[muted]}m" R=$'\e[m'
  local bg=$'\e[48;2;'"${rgb[lighter_background]}m" sel=$'\e[48;2;'"${rgb[selection]}m"
  local line; printf -v line '%*s' "$inner" ''; line=${line// /─}
  local text=" $B╭$line╮$R"$'\n'
  for i in "${!_ble_hmenu_items[@]}"; do
    item=${_ble_hmenu_items[i]}
    ((${#item} > w)) && item=${item:0:w-1}…
    local pad; printf -v pad '%*s' $((w - ${#item})) ''
    if ((i == _ble_hmenu_index)); then
      ble/hmenu/mark-match "$item" "${rgb[bright_foreground]}"
      text+=" $B│$sel"$'\e[38;2;'"${rgb[accent]}m▌ $ret$pad $B$sel$R$B│$R"$'\n'
    else
      ble/hmenu/mark-match "$item" "${rgb[foreground]}"
      text+=" $B│$bg  $ret$pad $R$B│$R"$'\n'
    fi
  done
  local fill=$((inner - ${#hint} - ${#count} - 1))
  printf -v line '%*s' "$fill" ''; line=${line// /─}
  text+=" $B╰─"$'\e[38;2;'"${rgb[dark_foreground]}m$hint$B$line"$'\e[38;2;'"${rgb[dark_foreground]}m$count$B╯$R"
  # ble/edit/info/show would re-parse all of this one character at a time
  # (~300 ms for the box). The layout is known here, so hand the panel the
  # finished text: every row is inner+3 columns wide, n+1 newlines.
  # Put the cursor back on the prompt line before anything is written, so the
  # terminal never shows it down in the box (one write, cursor hidden).
  if ble/is-function ble/edit/info/.render-content && ble/is-function ble/canvas/panel/save-position; then
    local pos; ble/canvas/panel/save-position; pos=$ret
    ble/edit/info/.render-content $((inner + 3)) $((n + 1)) "${text//$'\n'/$'\r\n'}"
    ble/canvas/panel/load-position "$pos"
    ble/util/buffer.flush
    _ble_edit_info_scene=show
  else
    ble/edit/info/show ansi "$text"
  fi
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
  # Rebuild the entry list (after a command, ~30 ms) while nothing is typed,
  # so the first key of the next command does not pay for it.
  [[ $_ble_edit_str ]] || ble/hmenu/entries
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

# Esc closes the list until you type again and leaves exactly what you typed:
# a highlighted entry is undone and the grey suggestion is dropped too.
function ble/widget/hmenu-close {
  [[ $_ble_decode_keymap == auto_complete ]] && ble/widget/auto_complete/cancel
  if ((${#_ble_hmenu_items[@]} && _ble_hmenu_index >= 0)); then
    ble-edit/content/reset "$_ble_hmenu_prefix" edit
    _ble_edit_ind=${#_ble_hmenu_prefix}
  fi
  ble/hmenu/clear
}
ble-bind -m emacs -f 'C-[' hmenu-close
ble-bind -m auto_complete -f 'C-[' hmenu-close

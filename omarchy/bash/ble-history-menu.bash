# History dropdown while typing, for ble.sh.
#
# ble.sh's own auto menu lists command and file completions. This swaps its
# source for the whole-line history: after a short pause, every history entry
# that starts with what is typed opens as a menu under the prompt (newest
# first). Tab or the arrows move in it, Enter takes the entry; keep typing and
# it narrows. Loaded by ~/.bashrc once ble.sh is loaded.

# ble.sh loads its completion library lazily; load it now so the function
# below replaces its auto-menu task, not the other way round.
ble-import lib/core-complete

# A context whose only source starts at column 0, so a candidate replaces the
# whole line and not just the last word.
function ble/complete/context:histline/generate-sources {
  sources=("histline 0")
}

# Inserts the entry as it is: no quoting, no trailing space, no description.
function ble/complete/action:histline/initialize { return 0; }
function ble/complete/action:histline/initialize.batch { inserts=("${cands[@]}"); }
function ble/complete/action:histline/complete { return 0; }
function ble/complete/action:histline/get-desc { desc=' '; }

function ble/complete/source:histline {
  local text=${comp_text:0:comp_index}
  [[ $text ]] || return 1
  local -a entries=()
  ble/util/assign-array entries 'HISTTIMEFORMAT= builtin history | sed "s/^ *[0-9]* *//" | tac | awk "!seen[\$0]++"'
  local line n=0 action=histline "${_ble_complete_yield_varnames[@]/%/=}"
  ble/complete/cand/yield.initialize "$action"
  for line in "${entries[@]}"; do
    [[ $line == "$text"?* ]] || continue
    ble/complete/cand/yield "$action" "$line"
    ((++n>=${BLE_HISTORY_MENU_MAX:-12})) && break
  done
}

# Same as ble.sh's auto-menu idle task, but asks for the histline context.
function ble/complete/auto-menu.idle {
  ble/util/idle.wait-user-input
  [[ $_ble_complete_menu_active ]] && return 0
  ((bleopt_complete_auto_menu>0)) || return 1
  case $_ble_decode_widget_last in
  (ble/widget/self-insert|ble/widget/magic-slash) ;;
  (ble/widget/complete) ;;
  (ble/widget/vi_imap/complete) ;;
  (ble/widget/auto_complete/self-insert) ;;
  (*) return 0 ;;
  esac
  [[ $_ble_edit_str ]] || return 0
  local until=$((_ble_idle_clock_start+bleopt_complete_auto_menu))
  ble/util/idle.sleep-until "$until" checked && return 0
  ble/widget/complete auto_menu:show_menu:no-empty:no-bell:context=histline
}
bleopt complete_auto_menu=250
bleopt complete_menu_style=desc

# Down steps into the menu from a typed line (Down again or Tab moves on,
# Enter takes the entry, Esc leaves it); on an empty line it stays the usual
# next-history key.
function ble/widget/history-menu-down {
  if [[ $_ble_edit_str ]]; then
    ble/widget/complete enter_menu:context=histline
  else
    ble/widget/history-next
  fi
}
ble-bind -m emacs -f down history-menu-down

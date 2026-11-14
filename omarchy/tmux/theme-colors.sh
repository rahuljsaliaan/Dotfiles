#!/bin/bash
# Give tmux the current Omarchy theme's colours, the same colors.toml keys the
# Starship template and Neovim's status line use, so the three draw one design
# in one palette. tmux.conf runs this at start; the theme-set hook
# (~/.config/omarchy/hooks/theme-set.d/tmux-colors) runs it again on every
# theme switch, so running sessions follow without a reload.
#
# It sets user options (@thm_accent, @thm_dim, ...) that the status line's
# formats read when they are drawn, and the style options that take a colour
# directly. A missing key keeps tmux.conf's named-colour default.
set -u

colors="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current/theme/colors.toml"
[[ -r $colors ]] || exit 0
tmux info >/dev/null 2>&1 || exit 0

declare -A c=()
while IFS= read -r line; do
  [[ $line =~ ^[[:space:]]*([a-z_]+)[[:space:]]*=[[:space:]]*\"(#[0-9A-Fa-f]{6})\" ]] && c[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
done <"$colors"

cmds=()
opt() { [[ -n ${2:-} ]] && cmds+=("set-option -g $1 \"$2\""); }

# Palette for the status formats.
opt @thm_bg "${c[background]:-}"
opt @thm_fg "${c[foreground]:-}"
opt @thm_bright "${c[bright_foreground]:-}"
opt @thm_dim "${c[dark_foreground]:-}"
opt @thm_accent "${c[accent]:-}"
opt @thm_magenta "${c[magenta]:-}"

# Styles that take a colour directly.
if [[ -n ${c[accent]:-} && -n ${c[background]:-} && -n ${c[dark_foreground]:-} ]]; then
  opt pane-border-style "fg=${c[dark_foreground]}"
  opt pane-active-border-style "fg=${c[accent]}"
  opt message-style "bg=${c[background]},fg=${c[accent]},bold"
  opt message-command-style "bg=${c[background]},fg=${c[magenta]:-${c[accent]}},bold"
  opt popup-border-style "fg=${c[accent]}"
  opt mode-style "bg=${c[accent]},fg=${c[background]}"
  opt clock-mode-colour "${c[accent]}"
fi

(( ${#cmds[@]} )) || exit 0
printf '%s\n' "${cmds[@]}" | tmux source-file - >/dev/null 2>&1
tmux list-clients -F '#{client_name}' 2>/dev/null | while read -r client; do
  tmux refresh-client -S -t "$client" 2>/dev/null
done
exit 0

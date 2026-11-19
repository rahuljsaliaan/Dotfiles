#!/usr/bin/env bash
#
# Claude Code status line (settings.json → statusLine), in the Omarchy theme's colours.
# Claude Code pipes session data in as JSON on stdin; this prints one short row:
#
#   󰚩 Opus 5.5 high │  feat/login 󰙅 login-wt │ ctx 68k 34% │ $4.12 │ 5h 23% ↻2h10m │ wk 41%
#
#   󰚩    the model and its reasoning effort
#        the git branch being worked on (a short hash when detached), and, in a
#        linked worktree, 󰙅 and the worktree's name. Hidden outside a git repo.
#   ctx  tokens in the context window, and how full it is
#   $    the session's estimated cost (list price, resets on /clear)
#   5h   the plan's 5-hour usage, and how long until it resets
#   wk   the plan's weekly usage
#
# Percentages go green, then yellow at 50 %, then red at 80 %; those three
# colours mean only that, so every other value (tokens, cost) is plain text. In a narrow
# window the reset time goes first, then the worktree name, then the model name
# (the effort stays), then the token count. Usage limits come from Claude Code (rate_limits) after
# a session's first reply.
set -uo pipefail

IFS=$'\x1f' read -r model effort ctx_pct ctx_used cost five_pct five_reset week_pct dir wt_name wt_branch < <(
  jq -r '[
    (.model.display_name // .model.id // "Claude"),
    (.effort.level // ""),
    (.context_window.used_percentage // ""),
    (.context_window.total_input_tokens // 0),
    (.cost.total_cost_usd // 0),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.used_percentage // ""),
    (.workspace.current_dir // .cwd // ""),
    (.worktree.name // ""),
    (.worktree.branch // "")
  ] | map(tostring) | join("\u001f")'
)

# Colours from the current Omarchy theme's colors.toml, read on every refresh,
# so the line follows a theme switch. The keys match the Starship prompt's
# (starship.toml.tpl); the fallbacks are Tokyo Night's.
declare -A theme=(
  [bright_foreground]=c0caf5 [dark_foreground]=565f89 [bright_magenta]=bb9af7
  [bright_cyan]=7dcfff [blue]=7aa2f7 [green]=9ece6a [yellow]=e0af68 [red]=f7768e
)
colors_toml="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current/theme/colors.toml"
if [[ -r $colors_toml ]]; then
  while IFS= read -r line; do
    [[ $line =~ ^[[:space:]]*([a-z_]+)[[:space:]]*=[[:space:]]*\"#([0-9A-Fa-f]{6})\" ]] || continue
    [[ -n ${theme[${BASH_REMATCH[1]}]+set} ]] && theme[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
  done <"$colors_toml"
fi
c() { printf '\033[38;2;%d;%d;%dm' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"; }
FG="$(c "${theme[bright_foreground]}")" DIM="$(c "${theme[dark_foreground]}")"
MAG="$(c "${theme[bright_magenta]}")" CYAN="$(c "${theme[bright_cyan]}")" BLUE="$(c "${theme[blue]}")"
GREEN="$(c "${theme[green]}")" YELLOW="$(c "${theme[yellow]}")" RED="$(c "${theme[red]}")" R=$'\033[0m'

# The git branch and worktree of the session's directory. Claude Code's own
# worktree fields (set by --worktree) win; otherwise ask git, which also covers
# a worktree entered with `git worktree` or `cd`.
branch="$wt_branch" wt="$wt_name"
if [[ -z $branch && -n $dir && -d $dir ]]; then
  branch="$(git --no-optional-locks -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null \
    || git --no-optional-locks -C "$dir" rev-parse --short HEAD 2>/dev/null || true)"
fi
if [[ -n $branch && -z $wt ]]; then
  # A linked worktree's git dir differs from the repository's common git dir.
  { read -r gitdir; read -r common; read -r top; } < <(
    git --no-optional-locks -C "$dir" rev-parse --absolute-git-dir --path-format=absolute --git-common-dir --show-toplevel 2>/dev/null
  ) || true
  [[ -n ${gitdir:-} && ${gitdir:-} != "${common:-}" ]] && wt="${top##*/}"
fi
(( ${#branch} > 32 )) && branch="${branch:0:31}…"

pct() { # pct <percent> → 34% in green, yellow or red
  local p=${1%%.*} col=$GREEN
  if (( p >= 80 )); then col=$RED; elif (( p >= 50 )); then col=$YELLOW; fi
  printf '%s%d%%%s' "$col" "$p" "$R"
}

tokens() { # 68400 → 68k, 1234567 → 1.2M
  local t=${1%%.*}
  if (( t >= 1000000 )); then awk -v t="$t" 'BEGIN { s = sprintf("%.1f", t / 1e6); sub(/\.0$/, "", s); print s "M" }'
  elif (( t >= 1000 )); then printf '%dk' $(( (t + 500) / 1000 ))
  else printf '%d' "$t"; fi
}

until_reset() { # until_reset <epoch> → 2h10m / 12m
  local left=$(( ${1%%.*} - $(date +%s) ))
  (( left < 0 )) && left=0
  if (( left >= 3600 )); then printf '%dh%02dm' $(( left / 3600 )) $(( left % 3600 / 60 ))
  else printf '%dm' $(( left / 60 )); fi
}

render() { # render <show model name> <show tokens> <show reset> <show worktree>
  local out="" sep=" ${DIM}│${R} "
  out+="${MAG}󰚩${R}"
  (( $1 )) && out+=" ${FG}${model}${R}"
  [[ -n $effort ]] && out+=" ${CYAN}${effort}${R}"
  if [[ -n $branch ]]; then
    out+="${sep}${BLUE} ${branch}${R}"
    (( $4 )) && [[ -n $wt ]] && out+=" ${DIM}󰙅 ${wt}${R}"
  fi
  out+="${sep}${DIM}ctx${R} "
  if [[ -n $ctx_pct ]]; then
    (( $2 )) && out+="${FG}$(tokens "$ctx_used")${R} "
    out+="$(pct "$ctx_pct")"
  else
    out+="${DIM}—${R}"
  fi
  out+="${sep}${FG}\$$(printf '%.2f' "$cost")${R}"
  if [[ -n $five_pct ]]; then
    out+="${sep}${DIM}5h${R} $(pct "$five_pct")"
    (( $3 )) && [[ -n $five_reset ]] && out+=" ${DIM}↻$(until_reset "$five_reset")${R}"
  fi
  [[ -n $week_pct ]] && out+="${sep}${DIM}wk${R} $(pct "$week_pct")"
  printf '%s' "$out"
}

width=$(( ${COLUMNS:-200} - 4 ))
visible() { local s; s="$(printf '%s' "$1" | sed $'s/\033\\[[0-9;]*m//g')"; printf '%d' "${#s}"; }

for flags in "1 1 1 1" "1 1 0 1" "1 1 0 0" "0 1 0 0" "0 0 0 0"; do
  line="$(render $flags)"
  (( $(visible "$line") <= width )) && break
done
printf '%s\n' "$line"

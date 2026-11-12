#!/usr/bin/env bash
#
# Claude Code status line (settings.json → statusLine), in Tokyo Night colours.
# Claude Code pipes session data in as JSON on stdin; each printed line is one
# row under the prompt box.
#
#   row 1, the session:  model and effort · folder and git branch · context
#                        tokens · session cost and time · lines changed
#   row 2, the plan:     5-hour and weekly usage with when each resets ·
#                        prompt-cache hit rate
#
# Bars and percentages go green, then yellow at 50 %, then red at 80 %.
# Segments are dropped from the end of a row when the terminal is too narrow.
# Usage limits come from Claude Code itself (rate_limits) and appear after the
# first reply of a session; until then the row says so.
set -uo pipefail

input="$(cat)"

IFS=$'\x1f' read -r model effort fast dir ctx_pct ctx_used ctx_size cost dur_ms added removed \
  five_pct five_reset week_pct week_reset cache_hit < <(
  jq -r '[
    (.model.display_name // .model.id // "Claude"),
    (.effort.level // ""),
    (.fast_mode // false),
    (.workspace.current_dir // .cwd // ""),
    (.context_window.used_percentage // ""),
    (.context_window.total_input_tokens // 0),
    (.context_window.context_window_size // 0),
    (.cost.total_cost_usd // 0),
    (.cost.total_duration_ms // 0),
    (.cost.total_lines_added // 0),
    (.cost.total_lines_removed // 0),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.used_percentage // ""),
    (.rate_limits.seven_day.resets_at // ""),
    (.prompt_cache.hit_ratio // "")
  ] | map(tostring) | join("\u001f")' <<<"$input"
)

# Tokyo Night
c() { printf '\033[38;2;%d;%d;%dm' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"; }
FG="$(c c0caf5)" DIM="$(c 565f89)" BLUE="$(c 7aa2f7)" MAG="$(c bb9af7)" CYAN="$(c 7dcfff)"
GREEN="$(c 9ece6a)" YELLOW="$(c e0af68)" RED="$(c f7768e)" BOLD=$'\033[1m' R=$'\033[0m'
SEP=" ${DIM}│${R} "

level() { # level <percent> → colour for it
  local p=${1%%.*}
  if (( ${p:-0} >= 80 )); then printf '%s' "$RED"; elif (( ${p:-0} >= 50 )); then printf '%s' "$YELLOW"; else printf '%s' "$GREEN"; fi
}

bar() { # bar <percent> <cells> → ▰▰▰▱▱▱ in the level's colour
  local p=${1%%.*} n=$2 full i out=""
  (( p < 0 )) && p=0; (( p > 100 )) && p=100
  full=$(( (p * n + 50) / 100 ))
  out+="$(level "$p")"
  for (( i = 0; i < n; i++ )); do
    (( i == full )) && out+="$DIM"
    out+=$([[ $i -lt $full ]] && printf '▰' || printf '▱')
  done
  printf '%s%s' "$out" "$R"
}

tokens() { # 68400 → 68k, 1000000 → 1M, 1234567 → 1.2M
  local t=${1%%.*}
  if (( t >= 1000000 )); then
    awk -v t="$t" 'BEGIN { s = sprintf("%.1f", t / 1000000); sub(/\.0$/, "", s); print s "M" }'
  elif (( t >= 1000 )); then printf '%dk' $(( (t + 500) / 1000 ))
  else printf '%d' "$t"; fi
}

span() { # span <seconds> → 2h10m, 12m, 45s
  local s=$1
  if (( s >= 3600 )); then printf '%dh%02dm' $(( s / 3600 )) $(( s % 3600 / 60 ))
  elif (( s >= 60 )); then printf '%dm' $(( s / 60 ))
  else printf '%ds' "$s"; fi
}

resets() { # resets <epoch> → in 2h10m, or Mon 14:00 when more than a day off
  local at=${1%%.*} now left
  now=$(date +%s); left=$(( at - now ))
  (( left < 0 )) && left=0
  if (( left < 86400 )); then printf 'in %s' "$(span "$left")"
  else date -d "@$at" +'%a %H:%M'; fi
}

# ---- Row 1: the session

model_seg="${MAG}󰚩 ${FG}${BOLD}${model}${R}"
[[ -n $effort ]] && model_seg+=" ${DIM}${effort}${R}"
[[ $fast == true ]] && model_seg+=" ${YELLOW}󱐋 fast${R}"

place_seg=""
if [[ -n $dir ]]; then
  place_seg="${BLUE}󰉋 ${FG}${dir##*/}${R}"
  branch="$(git -C "$dir" branch --show-current 2>/dev/null)"
  [[ -n $branch ]] && place_seg+=" ${MAG} ${FG}${branch}${R}"
fi

if [[ -n $ctx_pct ]]; then
  ctx_seg="${DIM}ctx${R} $(bar "$ctx_pct" 10) $(level "$ctx_pct")${ctx_pct%%.*}%${R}"
  (( ${ctx_size%%.*} > 0 )) && ctx_seg+=" ${DIM}·${R} ${FG}$(tokens "$ctx_used")${DIM}/$(tokens "$ctx_size")${R}"
else
  ctx_seg="${DIM}ctx $(bar 0 10) —${R}"
fi

cost_seg="${GREEN}\$$(printf '%.2f' "$cost")${R} ${DIM}·${R} ${FG}$(span $(( ${dur_ms%%.*} / 1000 )))${R}"

lines_seg=""
(( added > 0 || removed > 0 )) && lines_seg="${GREEN}+${added}${R} ${RED}−${removed}${R}"

# ---- Row 2: the plan's usage limits

if [[ -n $five_pct || -n $week_pct ]]; then
  five_seg="${CYAN}󰔟 ${DIM}5h —${R}"
  [[ -n $five_pct ]] && five_seg="${CYAN}󰔟 ${DIM}5h${R} $(bar "$five_pct" 10) $(level "$five_pct")${five_pct%%.*}%${R}"
  [[ -n $five_pct && -n $five_reset ]] && five_seg+=" ${DIM}· resets $(resets "$five_reset")${R}"
  week_seg="${CYAN}󰃭 ${DIM}week —${R}"
  [[ -n $week_pct ]] && week_seg="${CYAN}󰃭 ${DIM}week${R} $(bar "$week_pct" 10) $(level "$week_pct")${week_pct%%.*}%${R}"
  [[ -n $week_pct && -n $week_reset ]] && week_seg+=" ${DIM}· resets $(resets "$week_reset")${R}"
else
  five_seg="${CYAN}󰔟 ${DIM}5h and weekly usage show after the first reply${R}"
  week_seg=""
fi

cache_seg=""
[[ -n $cache_hit ]] && cache_seg="${DIM}cache${R} ${FG}$(awk -v h="$cache_hit" 'BEGIN { printf "%d%%", h * 100 + 0.5 }')${R}"

# ---- Print, dropping trailing segments that don't fit the terminal

width=${COLUMNS:-200}
visible() { local s; s="$(printf '%s' "$1" | sed $'s/\033\\[[0-9;]*m//g')"; printf '%d' "${#s}"; }

row() { # row <segment>... → joined with dividers, cut down to the width
  local segs=() s out
  for s in "$@"; do [[ -n $s ]] && segs+=("$s"); done
  while (( ${#segs[@]} > 0 )); do
    out="${segs[0]}"
    for s in "${segs[@]:1}"; do out+="$SEP$s"; done
    if (( $(visible "$out") <= width - 4 )) || (( ${#segs[@]} == 1 )); then printf '%s\n' "$out"; return; fi
    unset 'segs[${#segs[@]}-1]'
  done
}

row "$model_seg" "$ctx_seg" "$cost_seg" "$place_seg" "$lines_seg"
row "$five_seg" "$week_seg" "$cache_seg"

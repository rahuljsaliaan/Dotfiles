#!/bin/bash
# Claude Code statusLine — Powerline bar in the style of ~/.config/starship.toml.
#
#   row 1 (where you are):  ( directory > git > language                       clock
#   row 2 (the session):    ( model/effort > 5h session > 7d week > context > cost
#
# Row 2 alternates light and dark pills so that two meters sharing a severity
# tier can never sit side by side in the same colour.
#
# Each row opens with the rounded cap and closes with the arrow edge, matching
# starship.toml (line 4 opens with the cap, line 8 closes with the arrow).
#
# Segments intentionally NOT reproduced: docker_context / kubernetes,
# cmd_duration, fill, character.

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "."' 2>/dev/null)
[ -z "$cwd" ] && cwd="."

# Glyphs are built from codepoints, never pasted literally: private-use Nerd
# Font characters get silently stripped by some editors and copy paths, which
# is how the separator once became an empty string (segments rendered as bare
# colour blocks with no separators at all).
ARROW=$'\ue0b0'                 # powerline separator + closing edge, same as starship.toml
CAP_L=$'\ue0b6'                 # rounded opening cap, same as starship.toml line 4
ICON_GIT=$'\ue0a0'              # branch
ICON_NODE=$'\ue718'             # node
ICON_PY=$'\ue73c'               # python
ICON_RUST=$'\ue7a8'             # rust
ICON_GO=$'\ue627'               # go
ICON_MODEL=$'\U000f06a9'        # robot
ICON_CTX=$'\uf2db'              # chip - context window (memory in use)
ICON_FIVE=$'\uf252'             # hourglass - 5h rolling session window
ICON_WEEK=$'\uf073'             # calendar - 7d window
ICON_WARN=$'\uf071'             # warning triangle - meter at 60%+
ICON_DANGER=$'\uf06d'           # fire - meter at 90%+
ICON_COST=$'\uf155'             # dollar
ICON_CLOCK=$'\uf017'            # clock
ICON_RESET=$'\u21bb'            # reset arrow (rate-limit window)
MARK_DIRTY=$'\u2717'            # dirty worktree
MARK_AHEAD=$'\u21e1'            # ahead
MARK_BEHIND=$'\u21e3'           # behind

# ---- palette ---------------------------------------------------------------
# Colour says what KIND of thing a pill is; the icon says which one; together
# they say whether you should care right now. Three families:
#
#   place   (row 1)  cool hues, static facts, never alarm
#   agent            the model - Anthropic clay, identity, never ramps
#   meters           things that deplete - identity colour at rest, then the
#                    shared severity ramp below
#   money            dark green, the universal money colour
#
# Every pill carries the foreground that clears WCAG AA (>= 4.5:1) against its
# background - which is why dark pills exist at all.
FG_DARK="26;27;38"            # #1a1b26  text on light pills
FG_LIGHT="192;202;245"        # #c0caf5  text on dark pills - the clock's ink,
                              #          so the bar has exactly two inks

# place
DIR_BG="122;162;247"          # #7aa2f7  repo          6.79:1 on dark
GIT_BG="187;154;247"          # #bb9af7  branch        7.39:1 on dark
LANG_BG="158;206;106"         # #9ece6a  runtimes      9.35:1 on dark

# agent
MODEL_BG="217;119;87"         # #d97757  Anthropic clay 5.47:1 on dark

# Meters at rest. 5h and 7d are siblings: one neutral hue, the weekly one
# darker. Deliberately desaturated (35%/24% vs 89-100% for the identity
# pills) so quota recedes at rest and the amber/red alarm lands harder.
FIVE_BG="169;177;214"         # #a9b1d6  session steel 8.10:1 on dark
WEEK_BG="59;66;97"            # #3b4261  weekly slate  6.08:1 on light
CTX_BG="125;207;255"          # #7dcfff  context cyan  9.96:1 on dark

# money
COST_BG="23;83;47"            # #17532f  dark green    5.62:1 on light

# severity ramp, shared by every meter so there is one rule to learn. Each tier
# keeps a light and a dark shade so the 5h/7d sibling pairing survives alarming.
TIER_WARN_PCT=60
TIER_DANGER_PCT=90
WARN_BG="224;175;104"         # #e0af68  amber         8.55:1 on dark
WARN_DARK_BG="107;69;16"      # #6b4510  amber, darker 5.24:1 on light
DANGER_BG="247;118;142"       # #f7768e  red           6.46:1 on dark
DANGER_DARK_BG="139;36;56"    # #8b2438  red, darker   5.40:1 on light

TIME_FG="192;202;245"         # #c0caf5

RESET=$(printf '\033[0m')

# ---- row buffer -------------------------------------------------------------
# Segments accumulate into $LINE so the opening cap can be drawn in the colour
# of whichever segment turns out to be first (any segment may be absent).
LINE="" ; FIRST_BG="" ; LAST_BG="" ; GAP_PENDING=0
GAP_ROW=$' \u200b'            # invisible, but not an empty line - see flush()

seg() { # $1 = background triplet, $2 = foreground triplet, $3 = text
  if [ -z "$FIRST_BG" ]; then
    FIRST_BG="$1"
  else
    LINE+=$(printf "\033[38;2;%sm\033[48;2;%sm%s" "$LAST_BG" "$1" "$ARROW")
  fi
  LINE+=$(printf "\033[38;2;%sm\033[48;2;%sm\033[1m %s ${RESET}" "$2" "$1" "$3")
  LAST_BG="$1"
}

# The severity rule lives here and nowhere else, so it cannot drift between the
# three meters. Echoes "bg|fg|icon" for a meter at $1 percent.
meter_style() { # $1 = pct, $2 = shade (light|dark), $3 = rest bg, $4 = rest fg, $5 = rest icon
  if [ "$1" -ge "$TIER_DANGER_PCT" ] 2>/dev/null; then
    if [ "$2" = dark ]; then echo "$DANGER_DARK_BG|$FG_LIGHT|$ICON_DANGER"
    else                     echo "$DANGER_BG|$FG_DARK|$ICON_DANGER" ; fi
  elif [ "$1" -ge "$TIER_WARN_PCT" ] 2>/dev/null; then
    if [ "$2" = dark ]; then echo "$WARN_DARK_BG|$FG_LIGHT|$ICON_WARN"
    else                     echo "$WARN_BG|$FG_DARK|$ICON_WARN" ; fi
  else
    echo "$3|$4|$5"
  fi
}

flush() { # $1 = optional trailing text drawn outside the powerline chain
  if [ -n "$FIRST_BG" ]; then
    # The gap is emitted lazily, so a row with nothing to show leaves no
    # stray blank line behind it.
    if [ "$GAP_PENDING" = 1 ]; then printf '%s\n' "$GAP_ROW" ; GAP_PENDING=0 ; fi
    printf "\033[38;2;%sm%s${RESET}" "$FIRST_BG" "$CAP_L"
    printf "%s" "$LINE"
    printf "\033[38;2;%sm%s${RESET}" "$LAST_BG" "$ARROW"
    [ -n "$1" ] && printf "%s" "$1"
    printf "\n"
  fi
  LINE="" ; FIRST_BG="" ; LAST_BG=""
}

human_tokens() { # 173456 -> 173k ; 1000000 -> 1.0M
  awk -v n="$1" 'BEGIN{
    if (n >= 1000000) printf "%.1fM", n/1000000;
    else if (n >= 1000) printf "%dk", n/1000;
    else printf "%d", n;
  }'
}

human_eta() { # seconds remaining -> 3d2h / 2h13m / 45m
  awk -v s="$1" 'BEGIN{
    if (s <= 0) { printf "now"; exit }
    d = int(s/86400); h = int((s%86400)/3600); m = int((s%3600)/60);
    if (d > 0) printf "%dd%dh", d, h;
    else if (h > 0) printf "%dh%dm", h, m;
    else printf "%dm", m;
  }'
}

git_root=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)

# ============================ row 1: where you are ===========================

# ---- directory ----
if [ -n "$git_root" ]; then
  rel="${cwd#"$git_root"}"
  rel="${rel#/}"
  if [ -z "$rel" ]; then
    dir_display="$(basename "$git_root")"
  else
    dir_display="$(basename "$git_root")/$rel"
  fi
else
  dir_display=$(echo "$cwd" | awk -F/ '{ if (NF>2) print $(NF-1)"/"$NF; else print $0 }')
fi
if [ "$(echo "$dir_display" | awk -F/ '{print NF}')" -gt 2 ]; then
  dir_display=$(echo "$dir_display" | awk -F/ '{print $(NF-1)"/"$NF}')
fi
seg "$DIR_BG" "$FG_DARK" "$dir_display"

# ---- git branch + status ----
if [ -n "$git_root" ]; then
  branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
  status_symbol=""
  [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ] && status_symbol=" $MARK_DIRTY"

  ab_symbol=""
  ahead_behind=$(git -C "$cwd" --no-optional-locks rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)
  if [ -n "$ahead_behind" ]; then
    behind=$(echo "$ahead_behind" | awk '{print $1}')
    ahead=$(echo "$ahead_behind" | awk '{print $2}')
    [ "${ahead:-0}" -gt 0 ] 2>/dev/null && ab_symbol="$ab_symbol $MARK_AHEAD$ahead"
    [ "${behind:-0}" -gt 0 ] 2>/dev/null && ab_symbol="$ab_symbol $MARK_BEHIND$behind"
  fi
  seg "$GIT_BG" "$FG_DARK" "$ICON_GIT $branch$status_symbol$ab_symbol"
fi

# ---- language versions ----
base_dir="${git_root:-$cwd}"
lang_text=""
if [ -f "$base_dir/package.json" ] && command -v node >/dev/null 2>&1; then
  lang_text="$lang_text $ICON_NODE $(node -v | sed 's/^v//')"
fi
if { [ -f "$base_dir/pyproject.toml" ] || [ -f "$base_dir/requirements.txt" ] || [ -f "$base_dir/setup.py" ]; } && command -v python3 >/dev/null 2>&1; then
  lang_text="$lang_text $ICON_PY $(python3 --version 2>&1 | awk '{print $2}')"
fi
if [ -f "$base_dir/Cargo.toml" ] && command -v rustc >/dev/null 2>&1; then
  lang_text="$lang_text $ICON_RUST $(rustc --version | awk '{print $2}')"
fi
if [ -f "$base_dir/go.mod" ] && command -v go >/dev/null 2>&1; then
  lang_text="$lang_text $ICON_GO $(go version | awk '{print $3}' | sed 's/^go//')"
fi
lang_text="${lang_text# }"
[ -n "$lang_text" ] && seg "$LANG_BG" "$FG_DARK" "$lang_text"

flush "$(printf "   \033[38;2;%sm%s %s${RESET}" "$TIME_FG" "$ICON_CLOCK" "$(date +%H:%M)")"

# a blank row between the two halves of the bar, drawn only if row 2 has content
GAP_PENDING=1

# ============================== row 2: the session ===========================

# ---- model + effort (the agent) ----
# Effort rides with the model: it is a property of the model, and `.effort` is
# absent entirely when the current model has no reasoning-effort parameter.
model_name=$(echo "$input" | jq -r '.model.display_name // empty' 2>/dev/null)
effort=$(echo "$input" | jq -r '.effort.level // empty' 2>/dev/null)
if [ -n "$model_name" ]; then
  model_text="$ICON_MODEL $model_name"
  [ -n "$effort" ] && model_text="$model_text · $effort"
  seg "$MODEL_BG" "$FG_DARK" "$model_text"
fi

# ---- subscription rate limits (the sibling pair) ----
# Present only for Claude.ai subscribers, after the first API response; each
# window can be absent independently. The 5h pill is the light sibling, the 7d
# pill the dark one, in whichever severity tier they are currently in.
now=$(date +%s)
limit_seg() { # $1 = jq key, $2 = label, $3 = shade, $4 = rest bg, $5 = rest fg, $6 = rest icon
  local pct resets eta bg fg icon
  pct=$(echo "$input" | jq -r ".rate_limits.$1.used_percentage // empty" 2>/dev/null)
  [ -z "$pct" ] && return
  pct=${pct%%.*}
  resets=$(echo "$input" | jq -r ".rate_limits.$1.resets_at // empty" 2>/dev/null)
  eta=""
  [ -n "$resets" ] && eta=" $ICON_RESET$(human_eta $((resets - now)))"
  IFS='|' read -r bg fg icon <<< "$(meter_style "$pct" "$3" "$4" "$5" "$6")"
  seg "$bg" "$fg" "$icon $2 ${pct}%$eta"
}
limit_seg five_hour "5h" light "$FIVE_BG" "$FG_DARK" "$ICON_FIVE"
limit_seg seven_day "7d" dark  "$WEEK_BG" "$FG_LIGHT" "$ICON_WEEK"

# ---- context window ----
# used_percentage is null before the first API call and again after /compact.
ctx=$(echo "$input" | jq -r '
  .context_window as $c
  | if ($c.used_percentage // null) == null then empty
    else "\($c.used_percentage | floor) \(($c.total_input_tokens // 0) + ($c.total_output_tokens // 0)) \($c.context_window_size // 0)"
    end' 2>/dev/null)
if [ -n "$ctx" ]; then
  set -- $ctx
  ctx_pct="$1" ; ctx_used="$2" ; ctx_max="$3"
  IFS='|' read -r ctx_bg ctx_fg ctx_icon <<< "$(meter_style "$ctx_pct" light "$CTX_BG" "$FG_DARK" "$ICON_CTX")"
  seg "$ctx_bg" "$ctx_fg" "$ctx_icon $(human_tokens "$ctx_used")/$(human_tokens "$ctx_max") ${ctx_pct}%"
fi

# ---- session cost (money) ----
# Client-side estimate; resets to $0 when /clear starts a new session.
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty' 2>/dev/null)
if [ -n "$cost" ]; then
  seg "$COST_BG" "$FG_LIGHT" "$ICON_COST $(awk -v c="$cost" 'BEGIN{ printf (c >= 100 ? "$%.0f" : "$%.2f"), c }')"
fi

flush

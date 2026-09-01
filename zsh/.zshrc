# ==============================
# -------- HISTORY -------------
# ==============================
setopt histignorealldups sharehistory inc_append_history
HISTSIZE=5000
SAVEHIST=5000
HISTFILE=~/.zsh_history

# ==============================
# -------- KEYBINDINGS ---------
# ==============================
bindkey -e

# Prefix-based history (↑ ↓ filtered by what you type)
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# ==============================
# -------- COMPLETION ----------
# ==============================
autoload -Uz compinit
compinit

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}'

# ==============================
# -------- COLORS --------------
# ==============================
eval "$(dircolors -b)"

# ==============================
# -------- ENV -----------------
# ==============================

# LOCALE
# tmux reads the locale to decide whether the terminal is UTF-8 capable, and
# when it is not, replaces every multi-byte character with "_" -- which
# silently strips the Nerd Font glyphs out of the tmux status line. Plain
# "en_IN" carries no codeset, so name the UTF-8 variant explicitly.
export LANG=en_IN.UTF-8


# PYENV (Python version manager)
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"

# --no-rehash, because a bare `pyenv init -` appends `command pyenv rehash` and
# so rebuilds the shims on every single shell start. Rehash takes a lock at
# $PYENV_ROOT/shims/.pyenv-shim, and if a shell is ever killed mid-rehash that
# lock is left behind -- after which every new shell blocks a full 60 seconds
# waiting for it before the prompt appears. Suspending the hang with C-z only
# feeds it: the stopped process leaves the lock in place for the next shell.
# Shims only go stale when a Python or an entry-point-installing package is
# added, so run `pyenv rehash` by hand at those points instead.
eval "$(pyenv init - --no-rehash zsh)"

# Rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# ==============================
# -------- ALIASES -------------
# ==============================
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first'
alias lt='eza --tree --icons'

alias bat=batcat

# ==============================
# -------- TMUX ----------------
# ==============================
# `tmux dev [path]` opens the per-repo session template (tmux-dev, linked from
# this repo's tmux/dev-session.sh); everything else reaches the real tmux
# untouched.
#
# This is a shell wrapper rather than tmux's own command-alias because an alias
# is defined in tmux.conf, and tmux.conf is only read once a server is running
# -- while tmux refuses to start a server for a command it does not recognise.
# So `tmux dev` with nothing running yet, which is exactly when it would be
# typed, fails with "no server running". Intercepting here works cold.
tmux() {
  if [[ $1 == dev ]]; then
    shift
    tmux-dev "$@"
  else
    command tmux "$@"
  fi
}

# ==============================
# -------- ZOXIDE --------------
# ==============================
eval "$(zoxide init zsh)"

# ==============================
# -------- AUTOSUGGEST ---------
# ==============================
if [ -f ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#5c6370"
fi

# ==============================
# -------- FZF (DROPDOWN) ------
# ==============================
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh

export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline"

# Clean dropdown history (no numbers, fixed UI refresh)
fzf-history-widget() {
  local selected

  selected=$(history 1 | sed 's/^[ ]*[0-9]\+[ ]*//' | tac | \
    fzf --query="$LBUFFER") || {
      zle reset-prompt
      return
    }

  BUFFER="$selected"
  CURSOR=${#BUFFER}

  zle reset-prompt
}
zle -N fzf-history-widget
bindkey '^R' fzf-history-widget

# File search + preview + open in Neovim
ff() {
  local file
  file=$(fdfind | fzf --height 40% --layout=reverse \
    --preview '
      if [ -d {} ]; then
        eza --tree --level=2 --icons {}
      else
        case "$(file --mime-type -b {})" in
          text/*)
            batcat --style=numbers --color=always {}
            ;;
          *)
            echo "Binary / non-text file: {}"
            ;;
        esac
      fi
    ' \
    --preview-window=right:60%) || return

  [ -n "$file" ] && nvim "$file"
}
# Frecent directory picker + preview + cd
#
# The counterpart to fdc: fdc walks the filesystem *below here*, this one draws
# on zoxide's database of everywhere you have actually been, so it reaches a
# repo three directories up without a path. zoxide ships `zi` for this already
# -- kept as its own function only for the eza preview, which `zi` has no way
# to add.
fz() {
  local dir
  dir=$(zoxide query -l | fzf --height 40% --layout=reverse \
    --preview 'eza --tree --level=2 --icons --color=always {}' \
    --preview-window=right:60%) || return

  [ -n "$dir" ] && cd "$dir"
}
# Folder search + cd into it
fdc() {
  local dir
  dir=$(fdfind -t d | fzf --height 40% --layout=reverse) || return

  [ -n "$dir" ] && cd "$dir"
}

# Optional keybindings
bindkey -s '^P' 'ff\n'     # Ctrl + P → file search
bindkey -s '^O' 'fdc\n'    # Ctrl + O → folder jump

# Clear py-cache
function pyclean() {
    echo "--- DELETING PYTHON CACHE FILES ---"
    
    # Delete and print individual .pyc and .pyo files in real-time
    find . -type f \( -name "*.pyc" -o -name "*.pyo" \) -print -delete
    
    # Remove __pycache__ directories while verbosely printing what is deleted
    find . -type d -name "__pycache__" -exec rm -rfv {} +
    
    echo "-----------------------------------"
    echo "Python caches cleaned successfully!"
}

# AWSM Dynamic Workspace Manager
workspace() {
    local SESSION_DIR="$HOME/.config/another-window-session-manager/sessions"
    local DCONF_BASE="/org/gnome/shell/extensions/another-window-session-manager"

    if [[ -z "$1" ]]; then
        echo "Available Workspaces:"
        if [[ -d "$SESSION_DIR" ]]; then
            find "$SESSION_DIR" -mindepth 1 -maxdepth 1 \
                ! -name "currentSession" \
                -printf "  - %f\n" | sed 's/\.json$//'
        else
            echo "Error: Session directory not found at $SESSION_DIR"
        fi
        echo ""
        echo "Usage: workspace <name> (e.g., workspace Dev)"
        return 0
    fi

    local TARGET="$1"
    local TARGET_PATH="$SESSION_DIR/$TARGET"

    if [[ ! -d "$TARGET_PATH" && ! -f "$TARGET_PATH" ]]; then
        if [[ -f "${TARGET_PATH}.json" ]]; then
            TARGET_PATH="${TARGET_PATH}.json"
        else
            echo "Error: Workspace '$TARGET' not found."
            return 1
        fi
    fi

    echo "Status: Activating workspace '$TARGET'..."

    # Save original dconf values to restore after
    local PREV_SESSION PREV_AUTORESTORE PREV_NO_DIALOG
    PREV_SESSION=$(dconf read "$DCONF_BASE/autorestore-sessions")
    PREV_AUTORESTORE=$(dconf read "$DCONF_BASE/enable-autorestore-sessions")
    PREV_NO_DIALOG=$(dconf read "$DCONF_BASE/restore-at-startup-without-asking")

    # Point AWSM at the target session, enable it, skip the confirm dialog
    dconf write "$DCONF_BASE/autorestore-sessions" "'$TARGET'"
    dconf write "$DCONF_BASE/enable-autorestore-sessions" "true"
    dconf write "$DCONF_BASE/restore-at-startup-without-asking" "true"

    echo "Status: Launching applications..."
    if ! gdbus call --session \
        --dest org.gnome.Shell.Extensions.awsm \
        --object-path /org/gnome/Shell/Extensions/awsm \
        --method org.gnome.Shell.Extensions.awsm.Autostart.RestoreSession; then
        echo "Error: D-Bus call failed."
    fi

    # Restore original dconf values
    dconf write "$DCONF_BASE/autorestore-sessions" "$PREV_SESSION"
    [[ -n "$PREV_AUTORESTORE" ]] && dconf write "$DCONF_BASE/enable-autorestore-sessions" "$PREV_AUTORESTORE" \
        || dconf reset "$DCONF_BASE/enable-autorestore-sessions"
    [[ -n "$PREV_NO_DIALOG" ]] && dconf write "$DCONF_BASE/restore-at-startup-without-asking" "$PREV_NO_DIALOG" \
        || dconf reset "$DCONF_BASE/restore-at-startup-without-asking"

    echo "Status: Workspace '$TARGET' is ready."
}
# ==============================
# -------- STARSHIP ------------
# ==============================
unset PROMPT
unset RPROMPT
eval "$(starship init zsh)"
. "$HOME/.local/bin/env"

# MISE
eval "$(~/.local/bin/mise activate zsh)"

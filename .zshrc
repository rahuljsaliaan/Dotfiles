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

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# PYENV (Python version manager)
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

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

# File search + preview + open in VS Code
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

  [ -n "$file" ] && code "$file"
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

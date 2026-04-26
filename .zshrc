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
alias code="flatpak run com.visualstudio.code"

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

# ==============================
# -------- STARSHIP ------------
# ==============================
unset PROMPT
unset RPROMPT
eval "$(starship init zsh)"
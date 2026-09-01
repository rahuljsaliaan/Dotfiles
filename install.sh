#!/usr/bin/env bash
#
# Symlink every config in this repo into the location its application expects.
#
# Safe to re-run: an already-correct link is reported and skipped, and anything
# real sitting in the way is moved to <target>.bak rather than destroyed.

set -euo pipefail

# Resolve the repo root from this script's own location, so it works from any cwd
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# source-in-repo : destination
LINKS=(
  "zsh/.zshrc:$HOME/.zshrc"
  "starship/starship.toml:$HOME/.config/starship.toml"
  "wezterm/wezterm.lua:$HOME/.config/wezterm/wezterm.lua"
  "tmux/tmux.conf:$HOME/.config/tmux/tmux.conf"
  # Not a config -- a launcher, so it goes somewhere on PATH rather than into
  # ~/.config. Named for what it drives, and reachable as `tmux dev` too via
  # the wrapper in .zshrc.
  "tmux/dev-session.sh:$HOME/.local/bin/tmux-dev"
  "mise/config.toml:$HOME/.config/mise/config.toml"
  "nvim:$HOME/.config/nvim"
)

link() {
  local src="$REPO/$1" dest="$2"

  if [[ ! -e $src ]]; then
    printf '  MISSING  %s (nothing in the repo to link)\n' "$1"
    return 1
  fi

  # Already pointing where we want it
  if [[ -L $dest && "$(readlink "$dest")" == "$src" ]]; then
    printf '  ok       %s\n' "$dest"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"

  # A stale symlink is just replaced. Anything real is preserved.
  #
  # The directory case matters: `ln -sfn` against an existing *directory*
  # creates the link INSIDE it (~/.config/nvim/nvim) instead of replacing it,
  # so a real directory has to be moved out of the way first.
  if [[ -L $dest ]]; then
    rm -f "$dest"
  elif [[ -e $dest ]]; then
    mv "$dest" "$dest.bak"
    printf '  backup   %s -> %s.bak\n' "$dest" "$dest"
  fi

  ln -sfn "$src" "$dest"
  printf '  linked   %s -> %s\n' "$dest" "$src"
}

printf 'Linking dotfiles from %s\n' "$REPO"
status=0
for entry in "${LINKS[@]}"; do
  link "${entry%%:*}" "${entry#*:}" || status=1
done

printf '\nDone.'
if [[ $status -ne 0 ]]; then
  printf ' Some entries were missing -- see above.'
fi
printf '\n'

# Neovim needs to be newer than most distro packages ship; the version is
# pinned in mise/config.toml. Warn rather than fail, since the links are still
# valid without it.
if command -v nvim >/dev/null 2>&1; then
  have="$(nvim --version | head -1 | sed 's/^NVIM v//')"
  need="0.11.2"
  if [[ "$(printf '%s\n%s\n' "$need" "$have" | sort -V | head -1)" != "$need" ]]; then
    printf '\nWARNING: LazyVim needs Neovim >= %s but found %s.\n' "$need" "$have"
    printf '         Run `mise install` to pick up the pinned version.\n'
  fi
else
  printf '\nWARNING: no nvim on PATH. Run `mise install`.\n'
fi

exit $status

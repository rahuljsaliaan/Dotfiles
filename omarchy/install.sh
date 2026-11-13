#!/usr/bin/env bash
#
# Restore the Omarchy setup onto a fresh Omarchy install.
#
# Unlike zorin/install.sh this COPIES rather than symlinks: Omarchy's own tools
# write into these folders (`omarchy plugin clone`, `omarchy refresh`, theme
# switches, the shell saving shell.json), and a symlink would carry those writes
# straight into the repo. Re-run it after pulling, and copy changes made on the
# machine back by hand.
#
# Anything already at a destination is kept as <file>.bak.<timestamp>.
#
#   omarchy/install.sh             # configs + settings
#   omarchy/install.sh --titlebars # also build the patched titlebar plugin
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

copy() {
  local src="$REPO/$1" dest="$2"
  if [[ -e $dest || -L $dest ]]; then
    if diff -rq "$src" "$dest" >/dev/null 2>&1; then
      printf '  ok       %s\n' "$dest"
      return
    fi
    mv "$dest" "$dest.bak.$STAMP"
    printf '  backup   %s -> %s.bak.%s\n' "$dest" "$dest" "$STAMP"
  fi
  mkdir -p "$(dirname "$dest")"
  cp -a "$src" "$dest"
  printf '  copied   %s\n' "$dest"
}

printf 'Restoring Omarchy setup from %s\n' "$REPO"

# Hyprland: only the files that differ from Omarchy's defaults.
copy hypr/hyprland.lua   "$HOME/.config/hypr/hyprland.lua"
copy hypr/looknfeel.lua  "$HOME/.config/hypr/looknfeel.lua"
copy hypr/monitors.lua   "$HOME/.config/hypr/monitors.lua"
copy hypr/bindings.lua   "$HOME/.config/hypr/bindings.lua"
copy avatar/face.png     "$HOME/.face"
copy hypr/gestures.lua   "$HOME/.config/hypr/gestures.lua"

# Omarchy shell: settings, menu, cloned plugins, theme overlay, branding, hooks.
copy omarchy/shell.json                          "$HOME/.config/omarchy/shell.json"
copy omarchy/extensions/omarchy-menu.jsonc       "$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
for plugin in lock glasslock bar dock idle notifications notification-bell divider net-speed reminders; do
  copy "omarchy/plugins/rahulj.$plugin"          "$HOME/.config/omarchy/plugins/rahulj.$plugin"
done
copy omarchy/themes/tokyo-night/shell.toml       "$HOME/.config/omarchy/themes/tokyo-night/shell.toml"
copy omarchy/themes/tokyo-night/shell.lock.toml  "$HOME/.config/omarchy/themes/tokyo-night/shell.lock.toml"
copy omarchy/backgrounds/tokyo-night/code-brackets.png "$HOME/.config/omarchy/backgrounds/tokyo-night/code-brackets.png"
copy omarchy/backgrounds/tokyo-night/pixel-led.png "$HOME/.config/omarchy/backgrounds/tokyo-night/pixel-led.png"
copy omarchy/backgrounds/tokyo-night/intros/pixel-led.mp4 "$HOME/.config/omarchy/backgrounds/tokyo-night/intros/pixel-led.mp4"
copy omarchy/branding/screensaver-sources/code-brackets.png "$HOME/.config/omarchy/branding/screensaver-sources/code-brackets.png"
copy omarchy/branding/screensaver.txt            "$HOME/.config/omarchy/branding/screensaver.txt"
copy omarchy/hooks/theme-set.d/screensaver-art   "$HOME/.config/omarchy/hooks/theme-set.d/screensaver-art"
copy omarchy/hooks/theme-set.d/glassy-terminals  "$HOME/.config/omarchy/hooks/theme-set.d/glassy-terminals"

# Screensaver scripts, the floating tmux prompt, and browser-here.
for script in omarchy-launch-screensaver-main omarchy-screensaver-tokyo screensaver-art-from-wallpaper tmux-prompt browser-here; do
  copy "bin/$script" "$HOME/.local/bin/$script"
done

# Teams for Linux launcher, run natively on Wayland (see the file's comment).
copy applications/teams-for-linux.desktop "$HOME/.local/share/applications/teams-for-linux.desktop"
copy teams-for-linux/config.json         "$HOME/.config/teams-for-linux/config.json"

# Open/Save dialogs in Nautilus instead of the plain GTK chooser.
copy xdg-desktop-portal/hyprland-portals.conf  "$HOME/.config/xdg-desktop-portal/hyprland-portals.conf"
copy xdg-desktop-portal/portals/nautilus.portal "$HOME/.local/share/xdg-desktop-portal/portals/nautilus.portal"
copy systemd/xdg-desktop-portal.service.d/nautilus-filechooser.conf "$HOME/.config/systemd/user/xdg-desktop-portal.service.d/nautilus-filechooser.conf"

# Prompt, terminal multiplexer and editor.
copy starship/starship.toml "$HOME/.config/starship.toml"
copy tmux/tmux.conf         "$HOME/.config/tmux/tmux.conf"
copy bash/.bashrc           "$HOME/.bashrc"
copy foot/foot.ini          "$HOME/.config/foot/foot.ini"
copy mise/config.toml       "$HOME/.config/mise/config.toml"
copy nvim                   "$HOME/.config/nvim"

# Claude Code (file by file; never the whole ~/.claude).
copy claude/CLAUDE.md               "$HOME/.claude/CLAUDE.md"
copy claude/skills/lavish/SKILL.md  "$HOME/.claude/skills/lavish/SKILL.md"
copy claude/statusline.sh           "$HOME/.claude/statusline.sh"
if [[ -f $HOME/.claude/settings.json ]] && command -v jq >/dev/null; then
  # Merge the tracked keys instead of replacing a file Claude Code keeps writing.
  tmp="$(mktemp)"
  jq -s '.[0] * .[1]' "$HOME/.claude/settings.json" "$REPO/claude/settings.json" > "$tmp" && mv "$tmp" "$HOME/.claude/settings.json"
  printf '  merged   %s\n' "$HOME/.claude/settings.json"
else
  copy claude/settings.json "$HOME/.claude/settings.json"
fi

printf '\nApplying settings that are not files\n'

# Restart the portal service so the Nautilus file chooser takes effect.
systemctl --user daemon-reload && systemctl --user restart xdg-desktop-portal && printf '  restarted xdg-desktop-portal (Nautilus file chooser)\n'

# Tools from mise/config.toml (pnpm), next to Omarchy's own mise tools.
mise install >/dev/null 2>&1 && printf '  ok       mise tools (pnpm)\n'

# Microsoft Teams as a desktop app (teams-for-linux, prebuilt from the
# project's GitHub releases) instead of the Chromium web app: it keeps running
# in the tray when its window is closed, so notifications still arrive.
if omarchy pkg aur add teams-for-linux-bin >/dev/null; then
  printf '  ok       teams-for-linux-bin\n'
fi
if [[ -f "$HOME/.local/share/applications/Microsoft Teams.desktop" ]]; then
  omarchy-webapp-remove "Microsoft Teams" >/dev/null && printf '  removed  Microsoft Teams web app\n'
fi

# Web apps pinned in the dock (shell.json dock.pinned names them by launcher).
for entry in "Gmail|https://mail.google.com/|gmail" \
             "YouTube Music|https://music.youtube.com/|youtube-music"; do
  IFS='|' read -r name url icon <<<"$entry"
  if [[ -f "$HOME/.local/share/applications/$name.desktop" ]]; then
    printf '  ok       %s web app\n' "$name"
  else
    omarchy-webapp-install "$name" "$url" "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/$icon.png" >/dev/null &&
      printf '  added    %s web app\n' "$name"
  fi
done

# Community bar widgets, from their own repos (reviewed before adding):
#   Pulse: CPU, memory, disk and network activity in one widget
#   AI Usage: Claude subscription session and weekly limits
#   Quick Reference Guide: searchable cheat sheets (Neovim, git, Docker, zsh)
#   NittyGriddy: window overview grid (Super+E, three-finger swipes)
for entry in io.github.sanchokusika.pulse=https://github.com/SanchoKusika/omarchy-pulse.git \
             jim.aiusage=https://github.com/whitecliffs/omarchy-aiusage.git \
             jcmarin.qrg=https://github.com/jcmarinn/Omarchy-QRG.git \
             timsonner.nitty-griddy=https://github.com/timsonner/nitty-griddy.git; do
  id="${entry%%=*}" url="${entry#*=}"
  if [[ -d $HOME/.config/omarchy/plugins/$id ]]; then
    printf '  ok       %s\n' "$id"
  else
    omarchy plugin add "$url" --enable --yes >/dev/null && printf '  added    %s\n' "$id"
  fi
done

# Use the cloned plugins in place of Omarchy's own.
for plugin in glasslock bar dock idle notifications notification-bell divider net-speed reminders; do
  omarchy plugin enable "rahulj.$plugin" >/dev/null && printf '  enabled  rahulj.%s\n' "$plugin"
done
# Exactly one lock screen: Glasslock. rahulj.lock stays installed as a fallback
# (omarchy plugin enable rahulj.lock), and disabling it restores omarchy.lock,
# so both are switched off after it.
for plugin in rahulj.lock omarchy.lock; do
  omarchy plugin disable "$plugin" >/dev/null 2>&1 && printf '  disabled %s\n' "$plugin"
done

# Frosted windows and top bar.
omarchy hyprland window transparency glassy >/dev/null && printf '  glassy   windows\n'
omarchy bar background glassy >/dev/null && printf '  glassy   top bar\n'

# GTK/libadwaita apps: no buttons in their own header bars (Hyprland draws them).
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:' && printf '  gtk      header-bar buttons off\n'

# Wallpaper (also regenerates the screensaver art through the theme hook's script).
omarchy theme bg set "$HOME/.config/omarchy/backgrounds/tokyo-night/pixel-led.png" >/dev/null && printf '  wallpaper pixel-led\n'
"$HOME/.local/bin/screensaver-art-from-wallpaper" && printf '  screensaver art regenerated\n'

if [[ ${1:-} == "--titlebars" ]]; then
  printf '\nBuilding the patched titlebar plugin\n'
  "$REPO/titlebars/build.sh"
fi

printf '\nDone. Run `omarchy restart shell`, or log out and back in.\n'
printf 'Chromium and its web apps: right-click the tab bar and tick "Use system title bar and borders".\n'

# Dotfiles — Omarchy

The setup for the Omarchy (Arch + Hyprland) machine: a Tokyo Night "frosted
glass" desktop with rounded windows, three monitors with one main screen, and
the developer tools on top. The Zorin OS setup lives in [`../zorin`](../zorin).

## Restore

```sh
git clone https://github.com/rahuljsaliaan/Dotfiles.git
cd Dotfiles/omarchy
./install.sh --titlebars    # configs, settings, and the patched titlebar plugin
omarchy restart shell       # or log out and back in
```

`install.sh` **copies** rather than symlinks, because Omarchy's own tools write
into these folders (plugin clones, `omarchy refresh`, theme switches, the shell
saving `shell.json`). Anything it replaces is kept as `<file>.bak.<timestamp>`.
Changes made on the machine have to be copied back here by hand.

Two things it cannot do, because the apps own those settings:

- **Chromium and its web apps** (Teams, Outlook, WhatsApp, …): right-click the
  tab bar and tick *Use system title bar and borders*, so Hyprland draws the
  title bar instead of Chromium's own buttons.
- **Brave / Obsidian**: Brave's *Use system title bar and borders*, and
  Obsidian's *Settings → Appearance → Window frame style → Native frame*.

## Main screen

Three monitors: the laptop (`eDP-1`), the middle BenQ on HDMI (`HDMI-A-1`) and
the right BenQ on DisplayPort (`DP-2`). The middle one is the **main screen**,
falling back to the laptop when undocked. Only the main screen gets the top
bar, the dock, the lock-screen password box and the screensaver. The names
live in `mainScreenNames` / `lockInputScreens` in the plugins and in the jq
filter in `bin/omarchy-launch-screensaver-main`, and the positions in
`hypr/monitors.lua` match each monitor by model and serial. Change them all
together for different monitors.

## What is here

| Path | Goes to | What it does |
|---|---|---|
| `hypr/hyprland.lua` | `~/.config/hypr/` | Title-bar buttons: round, Linux order (minimize, maximize, close) top-right, faint at rest and full colour on hover |
| `hypr/looknfeel.lua` | `~/.config/hypr/` | 10px rounded windows; soft translucent blue→purple focused border; Tokyo Night title-bar button colours and bold symbols; loads the patched titlebar plugin; blurs the dock |
| `hypr/bindings.lua` | `~/.config/hypr/` | Super+E opens the window overview (NittyGriddy); Esc closes it while open and passes through otherwise; Super+Tab / Super+Shift+Tab page its workspace strip while open and otherwise switch workspace exactly as Omarchy's do. The plugin's Super+W/Q and Super+Shift+number overrides are deliberately left out |
| `hypr/gestures.lua` | `~/.config/hypr/` | Three-finger swipes (loaded from `hyprland.lua`): up opens the window overview, down closes it, left/right page its strip while open and otherwise switch to the previous/next workspace |
| `hypr/monitors.lua` | `~/.config/hypr/` | Fixed monitor positions (laptop, middle BenQ, right BenQ), matched by model and serial, so a monitor that reconnects after sleep returns to its place |
| `omarchy/shell.json` | `~/.config/omarchy/` | Bar layout in groups split by thin dividers (left: launcher and workspaces, CPU sparkline; centre: weather, clock and time zones; right: tools and AI usage, network, controls, tray and bell) on a frosted bar, dock pins (Chromium, Outlook, Teams for Linux, foot), idle timings (screensaver 2½ min, lock 5 min) |
| *(installed from git)* | `~/.config/omarchy/plugins/` | Community bar widgets: [Pulse](https://github.com/SanchoKusika/omarchy-pulse) (CPU, memory, disk and network in one widget), [AI Usage](https://github.com/whitecliffs/omarchy-aiusage) (Claude subscription session and weekly limits, tracking `claude`), [Quick Reference Guide](https://github.com/jcmarinn/Omarchy-QRG) (searchable cheat sheets for Neovim, git, Docker and zsh; add your own in `~/.config/qrg/guides/`) and [NittyGriddy](https://github.com/timsonner/nitty-griddy) (a window overview with live thumbnails and search). `install.sh` adds them with `omarchy plugin add`; their place in the bar is in `shell.json` |
| `omarchy/extensions/omarchy-menu.jsonc` | `~/.config/omarchy/extensions/` | Menu → Screensaver runs the main-screen-only launcher; System → AI Usage, Learn → Quick Reference and Trigger → Window Overview open those plugins, so menu search finds them |
| `omarchy/plugins/rahulj.lock` | `~/.config/omarchy/plugins/` | Lock screen: clock, date and password box on the main screen only, a frosted rounded field with the window-border gradient; re-blanks a monitor that reconnects while the screens are asleep |
| `omarchy/plugins/rahulj.bar` | `~/.config/omarchy/plugins/` | Top bar on the main screen only |
| `omarchy/plugins/rahulj.net-speed` | `~/.config/omarchy/plugins/` | Live up/down speed beside the network icon: a copy of [Net Speed Colour](https://github.com/brightwalker25/omarchy-net-speed) (MIT) with the arrows in the theme's blue and cyan instead of fixed colours |
| `omarchy/plugins/rahulj.divider` | `~/.config/omarchy/plugins/` | A thin vertical line between two groups of bar widgets, in the bar's text colour turned down low; place it between widgets in `shell.json` (it can be used many times) |
| `omarchy/plugins/rahulj.dock` | `~/.config/omarchy/plugins/` | Dock on the main screen only; auto-hides on tiled workspaces; frosted rounded glass plate; accent dot under running apps; lifted off the edge |
| `omarchy/plugins/rahulj.notifications` | `~/.config/omarchy/plugins/` | Notifications as "elevated glass" cards: lighter than any window, a fine rim, 14px corners and a deep shadow, with the app name beside the time and a small pointer up to the bar's bell. Shown on the main screen, for 12s (8s for low priority). Counts unread notifications, including ones silenced by Do Not Disturb |
| `omarchy/plugins/rahulj.notification-bell` | `~/.config/omarchy/plugins/` | Notification Center: a bell in the bar with a purple unread dot that opens a dropdown, like the Wi-Fi panel, listing notifications grouped Today / Yesterday / Earlier: search as you type, filter chips (All, Unread since last opened, Urgent, top apps), Do Not Disturb, Clear (all, or just what is shown), copy / remove per entry, click to focus the app, and keyboard control (↑↓, Enter, Delete, Ctrl+C, Esc) |
| `omarchy/plugins/rahulj.idle` | `~/.config/omarchy/plugins/` | Idle timer that starts the main-screen-only screensaver |
| `omarchy/themes/tokyo-night/shell.toml` | `~/.config/omarchy/themes/tokyo-night/` | Theme overlay: panels, prompts and the lock field use the soft gradient border, and the lock field is frosted glass; notifications use a lighter glass surface with a fine light rim |
| `omarchy/backgrounds/tokyo-night/code-brackets.png` | `~/.config/omarchy/backgrounds/tokyo-night/` | The `</>` wallpaper |
| `omarchy/branding/` | `~/.config/omarchy/branding/` | Screensaver art, and the clean (glow-free) `</>` it is traced from |
| `omarchy/hooks/theme-set.d/screensaver-art` | `~/.config/omarchy/hooks/theme-set.d/` | Re-traces the screensaver art from the wallpaper on every theme switch |
| `bin/omarchy-launch-screensaver-main` | `~/.local/bin/` | Omarchy's screensaver launcher, limited to the main screen |
| `bin/omarchy-screensaver-tokyo` | `~/.local/bin/` | The screensaver: navy background, 14 calm text effects, theme blue→purple finish |
| `bin/tmux-prompt` | `~/.local/bin/` | The floating tmux input box (fzf in a tmux popup): renames pre-fill the old name; `:` is a command palette listing every tmux command, filtered as you type (Tab completes, Enter runs, Esc cancels) |
| `bin/screensaver-art-from-wallpaper` | `~/.local/bin/` | Traces the wallpaper (or its clean source) into braille art |
| `titlebars/` | built into `~/.local/lib/omarchy-hyprland-titlebars/` | Patch adding `button_rest_opacity` to Omarchy's titlebar plugin, and `build.sh` |
| `starship/starship.toml` | `~/.config/starship.toml` | Tokyo Night powerline prompt; the Python segment only appears inside an active virtualenv |
| `tmux/tmux.conf` | `~/.config/tmux/` | Omarchy's tmux config with the status bar at the top, in line with the Omarchy bar. Renaming a window or session and the `:` command line open in a floating rounded box (`bin/tmux-prompt`) instead of tmux's prompt, which took over the status line and hid the session name while typing |
| `foot/foot.ini` | `~/.config/foot/` | Omarchy's terminal config, with bold text drawn in JetBrains Mono ExtraBold (regular text is SemiBold) so the prompt's bold text stands out |
| `applications/teams-for-linux.desktop` | `~/.local/share/applications/` | Launcher override for Teams for Linux that runs it natively on Wayland, not through the package's forced XWayland, so it is sharp on the scaled laptop screen |
| `teams-for-linux/config.json` | `~/.config/teams-for-linux/` | Teams notifications made by the app rather than the web page, so clicking one brings the window back from the tray, focuses it and opens the conversation |
| `bash/.bashrc` | `~/.bashrc` | Omarchy's bashrc plus a tuned `tdl` (tmux dev layout): terminal 20% of the height, AI pane 40% of the width, and focus left on the editor |
| `nvim/` | `~/.config/nvim` | Omarchy's LazyVim plus the Zorin keymaps, wrapping, explorer, LSP and markdown settings; Omarchy's theme hot-reload and clipboard kept |
| `claude/` | `~/.claude/` *(file by file)* | Global `CLAUDE.md`, the Lavish skill, and the tracked `settings.json` keys (attribution off, dark theme) |

### Plain settings `install.sh` applies

- `omarchy pkg aur add teams-for-linux-bin`, and removal of the Teams web app: Teams runs as a desktop app that stays in the tray when closed, so its notifications keep arriving

- `omarchy hyprland window transparency glassy`: frosted terminal and windows
- `omarchy bar background glassy`: frosted top bar
- `gsettings … button-layout 'appmenu:'`: no close buttons in GTK apps' own header bars
- `omarchy theme bg set …code-brackets.png`: the wallpaper

## The patched titlebar plugin

Omarchy's titlebar plugin can reveal a button's icon on hover, but not change
its background. `titlebars/button-rest-opacity.patch` adds one option,
`plugin:hyprbars:button_rest_opacity`, so the buttons draw faint at rest and in
full colour on hover. `hypr/looknfeel.lua` loads
`~/.local/lib/omarchy-hyprland-titlebars/titlebars.so` instead of Omarchy's copy
whenever it exists.

**After every Hyprland update, run `titlebars/build.sh`.** A plugin built
against older headers fails to load. To go back to Omarchy's plugin, delete
that `.so` and run `hyprctl reload`; the buttons then stay full colour at rest.

## Not tracked here

- **Hyprland `input.lua`, `autostart.lua`**:
  Omarchy's defaults, unchanged.
- **Claude Code's full `settings.json`**: Claude Code rewrites it at runtime;
  only the keys above are tracked, and merged in rather than replaced.
- **Omarchy, Superwhisper and diagnose-crash skills**: links to files those
  packages install.

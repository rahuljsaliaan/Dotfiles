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
| `hypr/looknfeel.lua` | `~/.config/hypr/` | 10px rounded windows; on a floating workspace a window opening onto an empty one is centred exactly (Omarchy steps new windows up to 48px off-centre); Nautilus kept glassy on floating workspaces too (it flipped between glass and solid on every folder change); soft translucent blue→purple focused border; Tokyo Night title-bar button colours and bold symbols; loads the patched titlebar plugin; blurs the dock |
| `hypr/bindings.lua` | `~/.config/hypr/` | Super+E opens the window overview (NittyGriddy); Esc closes it while open and passes through otherwise; Super+Tab / Super+Shift+Tab page its workspace strip while open and otherwise switch workspace exactly as Omarchy's do. The plugin's Super+W/Q and Super+Shift+number overrides are deliberately left out. H/J/K/L alternatives to the Super + arrow binds (Super+Shift swap, Super+Shift+Ctrl window to monitor, Super+Shift+Alt workspace to monitor), plus a nav mode on Super+; (H/J/K/L focus, Shift+H/J/K/L move into group, Ctrl+H/L group focus, Esc leaves; never crosses to another workspace or monitor), because on a 60% board the arrows need Fn and Fn+Super toggles the keyboard's Win-key lock. Volume on the bracket keys, since the 60% keyboard has no media keys: Super + ] / [ up and down (with Shift, in 1% steps), Super + \ mute |
| `hypr/gestures.lua` | `~/.config/hypr/` | Three-finger swipes (loaded from `hyprland.lua`): up opens the window overview, down closes it, left/right page its strip while open and otherwise switch to the previous/next workspace |
| `hypr/monitors.lua` | `~/.config/hypr/` | Fixed monitor positions (laptop, middle BenQ, right BenQ), matched by model and serial, so a monitor that reconnects after sleep returns to its place |
| `omarchy/shell.json` | `~/.config/omarchy/` | Bar layout in groups split by thin dividers (left: launcher and workspaces, CPU sparkline; centre: weather, clock and time zones; right: tools and AI usage, network, controls, tray and bell) on a frosted bar, dock pins in work order (Chromium, Gmail, Outlook, Teams for Linux, foot, then YouTube Music last as the one non-work app), idle timings (screensaver off, lock after 5 min) |
| *(installed from git)* | `~/.config/omarchy/plugins/` | Community bar widgets: [Pulse](https://github.com/SanchoKusika/omarchy-pulse) (CPU, memory, disk and network in one widget), [AI Usage](https://github.com/whitecliffs/omarchy-aiusage) (Claude subscription session and weekly limits, tracking `claude`), [Quick Reference Guide](https://github.com/jcmarinn/Omarchy-QRG) (searchable cheat sheets for Neovim, git, Docker and zsh; add your own in `~/.config/qrg/guides/`) and [NittyGriddy](https://github.com/timsonner/nitty-griddy) (a window overview with live thumbnails and search). `install.sh` adds them with `omarchy plugin add`; their place in the bar is in `shell.json` |
| `omarchy/extensions/omarchy-menu.jsonc` | `~/.config/omarchy/extensions/` | Menu → Screensaver runs the main-screen-only launcher; System → AI Usage, Learn → Quick Reference and Trigger → Window Overview open those plugins, so menu search finds them |
| `omarchy/plugins/rahulj.desk-map` | `~/.config/omarchy/plugins/` | The bar's workspace switcher, in place of `omarchy.workspaces`: a tiny map of the screens as they sit on the desk (laptop smaller, on the left). The focused screen opens up to hold its workspaces exactly as the stock widget shows them (1-10 per screen, the shown one as its layout symbol, square tiles, circle scrolls, triangle floats; click it to cycle the layout, click another to switch, scroll to step); the others stay small and show the workspace they are on, and clicking one focuses it. So the numbers always belong to the screen they sit in. Answers the `omarchy.workspaces refresh` IPC that Super + L sends. Placed in the bar by `shell.json` |
| `omarchy/plugins/rahulj.focus-sign` (with `branding/focus-sign/pixel-led-off.png`, the wallpaper with its sign switched off) | `~/.config/omarchy/plugins/` | Shows which screen has focus through the pixel wallpaper: the `</>` stays lit only on the focused screen and is switched off (a faint grey outline in the grid) on the others. A copy of the wallpaper, drawn exactly as the shell draws it, sits just above the wallpaper and below every window on the unfocused screens, takes no input, and jumps screens the moment focus moves. Only while `pixel-led.png` is the wallpaper, and from 9s after the shell starts, so the login intro plays untouched |
| `omarchy/plugins/rahulj.glasslock` | `~/.config/omarchy/plugins/` | The lock screen: [Glasslock](https://github.com/rocanrolpsycho/glasslock) (MIT, reviewed: the password only reaches Omarchy's own PAM lock service; network use is weather from geo.omarchy.org and Open-Meteo while locked, and Spotify album art) in this desktop's theme: a bold 24-hour JetBrains Mono clock with the date and weather, a frosted navy card with the window-gradient rim (red on a wrong password) holding the avatar, greeting and password field, Wi-Fi and battery in the corner, and a mini player. From `rahulj.lock` it keeps the clock, card and status on the main screen only and the re-blank of a monitor that reconnects while the screens are asleep. Options go in its `plugins` entry in `shell.json` (`name`, `avatar`, `weather`, `media`, ...) |
| `omarchy/plugins/rahulj.lock` | `~/.config/omarchy/plugins/` | Fallback lock screen, installed but disabled (`omarchy plugin enable rahulj.lock` to switch back): clock, date and password box on the main screen only, a frosted rounded field with the window-border gradient; re-blanks a monitor that reconnects while the screens are asleep |
| `omarchy/plugins/rahulj.bar` | `~/.config/omarchy/plugins/` | Top bar on the main screen only |
| `omarchy/plugins/rahulj.reminders` | `~/.config/omarchy/plugins/` | Reminder panel (Super+Ctrl+R) on one line instead of Omarchy's two steps: type the time and note as you'd say it (`30m Check the oven`, `1h30 Stand-up`, `at 15:30 Call mom`, `Tea in 10 min`), with a live read-back of when it fires and quick-time chips (click, or Tab to cycle) |
| `omarchy/plugins/rahulj.net-speed` | `~/.config/omarchy/plugins/` | Live up/down speed beside the network icon: a copy of [Net Speed Colour](https://github.com/brightwalker25/omarchy-net-speed) (MIT) with the arrows in the theme's blue and cyan instead of fixed colours |
| `omarchy/plugins/rahulj.divider` | `~/.config/omarchy/plugins/` | A thin vertical line between two groups of bar widgets, in the bar's text colour turned down low; place it between widgets in `shell.json` (it can be used many times) |
| `omarchy/plugins/rahulj.dock` | `~/.config/omarchy/plugins/` | Dock on the main screen only; auto-hides everywhere (shows when the pointer reaches the bottom edge, set by `dock.autohide` in `shell.json`); frosted rounded glass plate; accent dot under running apps; lifted off the edge |
| `omarchy/plugins/rahulj.notifications` | `~/.config/omarchy/plugins/` | Notifications as "Night Glass" cards, made to stand apart from windows: a lifted Tokyo Night surface (the float colour, a shade lighter than windows, 95% opaque and frosted by Hyprland's layer blur) with a slab edge underneath for thickness and a natural two-part shadow (a tight contact shadow plus a wide, faint navy one falling slightly down-left); the focused-window blue→purple gradient as the rim (red for critical), JetBrains Mono, the app name in a pill coloured by urgency (grey low, blue normal, red critical), a thin gradient line that drains as the card times out, and a 3D pop-out as a card arrives (it swings out of the screen edge towards you, then settles), lifting slightly on hover; 14px corners, a deep shadow, and a notch in the top card's own outline pointing up to the bar's bell, which grows out only once the card has settled and stays put on hover. Shown on the main screen, for 12s (8s for low priority). Counts unread notifications, including ones silenced by Do Not Disturb |
| `omarchy/plugins/rahulj.notification-bell` | `~/.config/omarchy/plugins/` | Notification Center: a bell in the bar with a purple unread dot that opens a dropdown, like the Wi-Fi panel, listing notifications grouped Today / Yesterday / Earlier: search as you type, filter chips (All, Unread since last opened, Urgent, top apps), Do Not Disturb, Clear (all, or just what is shown), copy / remove per entry, click to focus the app, and keyboard control (↑↓, Enter, Delete, Ctrl+C, Esc) |
| `omarchy/plugins/rahulj.idle` | `~/.config/omarchy/plugins/` | Idle timer that starts the main-screen-only screensaver |
| `omarchy/themes/tokyo-night/shell.toml` | `~/.config/omarchy/themes/tokyo-night/` | Theme overlay: panels, prompts and the lock field use the soft gradient border, and the lock field is frosted glass; notifications are the lifted float colour (#24283b, 95%) with the same gradient rim, and a red `border-critical` for critical ones. Shell surfaces read the copy `omarchy theme set tokyo-night` generates, so re-apply the theme after editing (then re-set the wallpaper, which the re-apply resets) |
| `omarchy/themes/tokyo-night/shell.lock.toml` | `~/.config/omarchy/themes/tokyo-night/` | The lock screen's colours (frosted navy, the window-gradient rim, red only on a wrong password). Stock Tokyo Night ships its own `shell.lock.toml`, which replaces the whole `[lock]` section of `shell.toml` when the theme is applied, so they have to live in this file |
| `omarchy/backgrounds/tokyo-night/pixel-led.png` (`backgrounds/src/pixel-led.svg` is its source) | `~/.config/omarchy/backgrounds/tokyo-night/` | The wallpaper: the screen as a faint grid of unlit pixels, like an LED panel switched off, fading towards the edges, with the `</>` lit in the middle in the avatar's pixel style (cyan → blue → purple, with a soft glow). Behind the glassy windows the grid blurs into a gentle texture |
| `omarchy/backgrounds/tokyo-night/intros/pixel-led.mp4` (`backgrounds/src/pixel-led-intro.py` renders its frames) | `~/.config/omarchy/backgrounds/tokyo-night/intros/` | The wallpaper's login intro, played once per session while background intros are on (`omarchy theme bg intro status`): the LED panel powering on. A line of pixels flickers across the middle, the grid spreads out from the centre as the navy fades in, the `</>` lights pixel by pixel and the glow fades in, 3.8s at 2560×1440, ending on a frame identical to the wallpaper |
| `omarchy/backgrounds/tokyo-night/code-brackets.png` | `~/.config/omarchy/backgrounds/tokyo-night/` | The previous, smooth `</>` wallpaper, kept for the screensaver art and as an alternative |
| `omarchy/branding/` | `~/.config/omarchy/branding/` | Screensaver art, and the clean (glow-free) `</>` it is traced from |
| `omarchy/hooks/theme-set.d/screensaver-art` | `~/.config/omarchy/hooks/theme-set.d/` | Re-traces the screensaver art from the wallpaper on every theme switch |
| `omarchy/hooks/theme-set.d/glassy-terminals` | `~/.config/omarchy/hooks/theme-set.d/` | Keeps terminals glassy after a theme switch: Omarchy gives every tmux pane a solid theme background (window-style and an OSC 11 into each pane), so the hook sets panes back to the terminal's own see-through background, and sets the terminal glass to 0.60 (a touch more see-through than Omarchy's 0.65) and resends it to running foot terminals, which the switch leaves solid |
| `bin/omarchy-launch-screensaver-main` | `~/.local/bin/` | Omarchy's screensaver launcher, limited to the main screen |
| `bin/omarchy-screensaver-tokyo` | `~/.local/bin/` | The screensaver: navy background, 14 calm text effects, theme blue→purple finish |
| `bin/tmux-prompt` | `~/.local/bin/` | The floating tmux input box (fzf in a tmux popup): renames pre-fill the old name; `:` is a command palette listing every tmux command, filtered as you type (Tab completes, Enter runs, Esc cancels) |
| `bin/browser-here` | `~/.local/bin/` | Opens a URL in the default browser on the same Hyprland workspace as the terminal it runs in: as a new tab in the browser window already there, or in a new window moved there. Claude Code uses it to open Lavish pages (see `claude/CLAUDE.md`) |
| `bin/screensaver-art-from-wallpaper` | `~/.local/bin/` | Traces the wallpaper (or its clean source) into braille art |
| `titlebars/` | built into `~/.local/lib/omarchy-hyprland-titlebars/` | Patch adding `button_rest_opacity` to Omarchy's titlebar plugin, and `build.sh` |
| `starship/starship.toml` | `~/.config/starship.toml` | Tokyo Night prompt: the folder on a rounded accent-blue pill (like the active workspace in the bar), then git, virtualenv, language versions and containers as coloured icons and text with dim │ dividers, in the plain style of the Claude Code status line; the last command's time on the right, no clock (the bar has one). The Python segment only appears inside an active virtualenv |
| `tmux/tmux.conf` | `~/.config/tmux/` | Omarchy's tmux config with the status bar at the top, in line with the Omarchy bar. Renaming a window or session and the `:` command line open in a floating rounded box (`bin/tmux-prompt`) instead of tmux's prompt, which took over the status line and hid the session name while typing |
| `mise/config.toml` | `~/.config/mise/` | Global tools installed with mise next to Omarchy's own (Node and friends): pnpm, latest |
| `foot/foot.ini` | `~/.config/foot/` | Omarchy's terminal config, with bold text drawn in JetBrains Mono Bold, one step heavier than the SemiBold regular text, so the prompt's bold text stands out |
| `applications/teams-for-linux.desktop` | `~/.local/share/applications/` | Launcher override for Teams for Linux that runs it natively on Wayland, not through the package's forced XWayland, so it is sharp on the scaled laptop screen |
| `xdg-desktop-portal/hyprland-portals.conf` | `~/.config/xdg-desktop-portal/` | Omarchy's portal choices, plus Open/Save dialogs ("upload a file" in the browser) in Nautilus instead of the plain GTK chooser |
| `xdg-desktop-portal/portals/nautilus.portal` | `~/.local/share/xdg-desktop-portal/portals/` | Declares Nautilus as a file-chooser backend: Nautilus serves the interface itself but ships no `.portal` file |
| `systemd/xdg-desktop-portal.service.d/nautilus-filechooser.conf` | `~/.config/systemd/user/xdg-desktop-portal.service.d/` | Points the portal service at the user folder above, refreshed at each start with links to every system backend and to `hyprland-portals.conf` (the service reads its config only from that folder once it is set) |
| `teams-for-linux/config.json` | `~/.config/teams-for-linux/` | Teams notifications made by the app rather than the web page, so clicking one brings the window back from the tray, focuses it and opens the conversation |
| `bash/.bashrc` | `~/.bashrc` | Omarchy's bashrc plus a tuned `tdl` (tmux dev layout): terminal 20% of the height, AI pane 40% of the width, and focus left on the editor |
| `nvim/` | `~/.config/nvim` | Omarchy's LazyVim plus the Zorin keymaps, wrapping, explorer, LSP and markdown settings; Omarchy's theme hot-reload and clipboard kept |
| `claude/` | `~/.claude/` *(file by file)* | Global `CLAUDE.md` (including: open Lavish pages with `browser-here` on Claude's own workspace), the Lavish skill, the tracked `settings.json` keys (attribution off, the Omarchy theme Omarchy generates from the current theme as `~/.claude/themes/omarchy.json`, status line), and `statusline.sh`: one short row under the prompt in Tokyo Night colours with the model and effort, context tokens and how full the window is, the session cost, and the 5-hour (with time to reset) and weekly plan usage; it trims itself to fit a narrow window |
| `avatar/face.png` (`avatar/avatar.svg` is its source; `avatar/avatar-cursor.svg` adds a blinking pixel cursor) | `~/.face` | The avatar on the lock screen: an R as a 5×7 terminal bitmap glyph, its lit pixels shading cyan → blue → purple like the window border, the unlit grid faint, on Tokyo Night navy. Square, with no rim of its own, and sized so the whole grid sits inside a circle crop (GitHub, WhatsApp, the lock screen) with a small margin; profile pictures (GitHub, WhatsApp) use `avatar/profile.svg` (and `profile-cursor.svg`), the same R inside the blue→purple ring, drawn just within the circle those sites crop to; render one with `rsvg-convert -w 2048 -h 2048 avatar/profile.svg -o avatar.png` |

### Plain settings `install.sh` applies

- `omarchy pkg aur add teams-for-linux-bin`, and removal of the Teams web app: Teams runs as a desktop app that stays in the tray when closed, so its notifications keep arriving
- `omarchy-webapp-install` for Gmail and YouTube Music (icons from the dashboard-icons set), so their dock pins have a launcher to point at

- `omarchy hyprland window transparency glassy`: frosted terminal and windows
- `omarchy bar background glassy`: frosted top bar
- `gsettings … button-layout 'appmenu:'`: no close buttons in GTK apps' own header bars
- `omarchy theme bg set …pixel-led.png`: the wallpaper

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

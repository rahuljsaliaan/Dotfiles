# Glasslock

A glassy lock screen for [Omarchy](https://omarchy.org): a big clock over your blurred wallpaper, and a frosted card with your avatar, a greeting, and the password field.

![Glasslock](preview.png)

- **Big clock and date**, with the current **weather** on the same line
- **Your avatar and a greeting** that changes with the time of day ("Good evening, Alex")
- **Caps Lock warning** under the password field, shown only while Caps Lock is on
- **Mini player** for whatever is playing (Spotify, YouTube, any MPRIS player), with previous / play-pause / next
- **Wi-Fi and battery** in the corner
- **Shakes on a wrong password**, and fades in when you lock
- **Follows your Omarchy theme**, or uses your own colors
- Show the typed password with the eye button or **Ctrl+E**

Glasslock only changes how the lock screen looks. Unlocking, PAM, fingerprint support and the rest are Omarchy's own lock service, unchanged.

## Install

```sh
omarchy plugin add https://github.com/rocanrolpsycho/glasslock.git --enable
omarchy restart shell
```

Lock with <kbd>Super</kbd> + <kbd>Escape</kbd>, or preview it without locking:

```sh
omarchy-shell lock preview      # click anywhere to close
```

## Configure

Glasslock works without any setup: it uses your account's name, `~/.face` as the avatar (your initial when there is none), and your theme's colors.

To change anything, add options to Glasslock's entry under `plugins` in `~/.config/omarchy/shell.json`. Changes apply as soon as you save.

```json
"plugins": [
  {
    "id": "io.github.rocanrolpsycho.glasslock",
    "name": "Alex",
    "avatar": "~/Pictures/me.png",
    "accent": "#E98597"
  }
]
```

| Option | Default | What it does |
|---|---|---|
| `name` | your account's name | Name in the greeting |
| `avatar` | `~/.face` | Path to a square-ish image. Your initial is shown when it is missing |
| `accent` | theme accent | Ring, field border, cursor and buttons (`#RRGGBB`) |
| `text` | theme lock text | Clock and text color (`#RRGGBB`) |
| `error` | theme error color | Wrong-password color (`#RRGGBB`) |
| `clock24h` | `false` | `true` for a 24-hour clock |
| `weather` | `true` | `false` hides the weather |
| `units` | from your country | `"metric"` or `"imperial"` |
| `media` | `true` | `false` hides the mini player |
| `status` | `true` | `false` hides Wi-Fi and battery |

## Privacy

- **Weather**: while the screen is locked, Glasslock asks Omarchy's location service (`geo.omarchy.org`, the same one the bar's weather uses) for your city once, then [Open-Meteo](https://open-meteo.com) for the temperature, at most every 15 minutes. Set `"weather": false` to turn this off.
- **Album art** is shown from local files and from Spotify's image server (`i.scdn.co`) only, downloaded with `curl` to `$XDG_RUNTIME_DIR/glasslock-art`. Any other remote URL a player reports is ignored.
- Media buttons work while locked, the same as on a phone's lock screen. Nothing else can be reached without your password.

## Remove

```sh
omarchy plugin remove --yes io.github.rocanrolpsycho.glasslock
omarchy plugin enable omarchy.lock
```

The second line matters: it switches Omarchy's own lock screen back on.

## If the lock screen ever breaks

Press <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>F2</kbd>, log in, and run:

```sh
omarchy plugin enable omarchy.lock
loginctl unlock-sessions
```

Then go back with <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>F1</kbd>.

## Translations

Strings live in `i18n/<language>.json` and follow the language picked in Omarchy. English is included; pull requests with other languages are welcome.

## Credits

Built on Omarchy's lock screen service (MIT). Weather icons mapping from Omarchy's weather panel.

## License

MIT, see [LICENSE](LICENSE).

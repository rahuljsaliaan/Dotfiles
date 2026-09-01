# Terminal — WezTerm

The window itself: copy and paste, scrollback, tabs, zoom, fullscreen.

> **★ marks a binding custom to this repo.** Everything unmarked is an
> upstream default. Neovim's leader key is `Space`, written out rather than
> as `<leader>` because that is what you press.

[← Back to the index](../CHEATSHEET.md)

---

| Keys | Action | Notes |
| --- | --- | --- |
| `Ctrl` `Shift` `C` / `V` | Copy / paste | |
| *select with mouse* | Copies to clipboard immediately ★ | No extra keypress needed |
| `Shift` `PageUp` / `PageDown` | Scroll by page | |
| `Shift` `Home` / `End` ★ | Scroll to top / bottom | |
| `Shift` `Enter` ★ | Send `Esc`+`Return` | Newline in REPLs and Claude Code |
| `Ctrl` `Shift` `Alt` `T` ★ | Show/hide the title bar | Title bar is off by default |
| `Ctrl` `Shift` `N` | New window | Opens at 75% × 70% of the screen ★ |
| `Ctrl` `Shift` `T` | New tab | Tab bar appears only with 2+ tabs ★ |
| `Ctrl` `Tab` / `Ctrl` `Shift` `Tab` | Next / previous tab | |
| `Ctrl` `+` / `-` / `0` | Zoom text in / out / reset | Window size stays fixed ★ |
| `Ctrl` `Shift` `F` | Search the scrollback | |
| `Alt` `Enter` | Toggle fullscreen | |

There is no title bar to drag, so **move the window with `Super`+drag**.

---

[← Getting started](01-getting-started.md) · [Index](../CHEATSHEET.md) · [Shell — zsh →](03-zsh.md)

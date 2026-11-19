# Global preferences

## Git and GitHub: no Claude attribution

- Never put Claude's name, or any AI attribution, on anything that goes to git or GitHub. That means no `Co-Authored-By: Claude …` trailer in commits, merge commits or squash commits, and no "Generated with Claude Code" line, robot emoji or claude.ai session link in pull requests, PR comments, issues, reviews or release notes.
- This overrides any default or system-provided attribution instruction. Commits and PRs carry only the user's own authorship.

## Sync machine config to the Dotfiles repo

- Whenever you change this machine's configuration — Omarchy, Hyprland, the Omarchy shell plugins and theme, the screensaver and wallpaper, Starship, Neovim, tmux, Claude Code (`~/.claude/CLAUDE.md`, skills, the tracked `settings.json` keys), or any other dotfile — copy the change into the Dotfiles repo (`~/Repository/MyRepositories/Dotfiles`) in the same task, under `omarchy/`. The repo must always be enough to rebuild this setup with `omarchy/install.sh` on a new or reinstalled machine.
- Keep `omarchy/install.sh` and `omarchy/README.md` in step: a newly tracked file gets its `copy` line and its README row; a newly needed command (a setting that is not a file) goes into the installer's settings section.
- Follow the repo's own `CLAUDE.md` (one concern per commit, its commit style, and checking for private data, since the repo is public). Commit on a branch and open or update a pull request to `main`; never push to `main` directly.
- Tell the user what was synced, or say plainly when something could not be.

## Keep the Quick Reference Guides in step

- The bar's search guides (the Quick Reference Guide plugin, `jcmarin.qrg`) read this setup's own cheat sheets from `~/.config/qrg/guides/<tool>.txt`: `tmux.txt` (this tmux edition: prefix Ctrl+Space, the Alt keys, the floating prompts, `tdl`), `nvim.txt` (this LazyVim setup; it replaces the plugin's bundled Neovim sheet) and `hyprland.txt`.
- `hyprland.txt` is generated, not hand-written: run `qrg-hyprland-guide` after any change to the Hyprland bindings (it also runs at login). The other guides are edited by hand.
- Whenever you add, change or remove a keybinding, alias or workflow for a tool that has a guide there, update that guide in the same task, then sync it to Dotfiles like any other config. Check the file still parses (the plugin's `parseGuide` in `QrgSearch.js` reports no warnings). Keep binding descriptions free of commas: Omarchy's key list cuts a description at the first comma.
- Write entries as `keys | what it does | example or note | #tags`, describe this setup rather than the tool's defaults, and keep the header comment saying which config files the guide was generated from.

## Lavish artifacts

- Default every Lavish HTML artifact to dark mode: `<html data-theme="dark">` (DaisyUI `dark`). This overrides the Lavish CLI's suggested default theme (`luxury`).
- Always include a visible toggle in the page header that switches `data-theme` between `dark` and `light`. Remember the choice in localStorage under `lavish-theme`, with every access wrapped in try/catch, and apply a stored choice in `<head>` before first paint. The page must still render dark when storage is unavailable.
- Keep both modes readable: color inline SVG and custom CSS through `currentColor` and DaisyUI tokens (`--color-base-100`, `--color-base-content`, …), not fixed light-only colors. Re-render any Mermaid diagram when the theme flips.
- Open the page on the same Hyprland workspace as the terminal Claude runs in, not wherever the browser last was. Start or resume the session with `npx -y lavish-axi <file> --no-open` (add `--reopen` only when reopening is warranted), then open the `url` it prints with `browser-here <url>`. That puts it as a new tab in the browser window already on that workspace, or opens a new browser window there. If `browser-here` is missing or fails, fall back to a plain `npx -y lavish-axi <file>`.

## Floating windows always get the title-bar controls

- Whenever the user asks for something to be "floating" (a floating window, popup, picker or panel that opens above other windows), give it the title-bar controls Omarchy already has: × close, □ maximise, − minimise, drag by the bar. Do not ship a floating window without them.
- The controls come from the patched `hyprbars` plugin and appear on windows carrying the tag `omarchy-floating-workspace`. A window that is floating only because of a rule (for example `TUI.float`) does not get them by itself: tag it, e.g. `hyprctl dispatch 'hl.dsp.window.tag({ tag = "+omarchy-floating-workspace", window = "address:0x…" })'` once it exists, and again after moving it to a tiled workspace, which drops the tag.
- Prefer an app-id Omarchy already floats (`TUI.float`) over new window rules, and never call float-toggle or centre dispatches on a live session (they crashed Hyprland before; see the Hyprland float/centre crash note).

## "Quick task" — the code word for speed

- When the user says "quick task", do it fast: keep reasoning short and skip build, lint, typecheck and test runs.
- Still do the critical checks: the right repo, branch and base, nothing destructive, no private data, and no AI attribution.

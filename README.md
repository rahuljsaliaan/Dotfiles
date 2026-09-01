# Dotfiles

Personal configuration, one folder per application. Each folder holds the real
file; `install.sh` symlinks it into wherever that application expects to find
it, so the repo stays the single source of truth and edits take effect in place.

## Shortcuts

**[CHEATSHEET.md](CHEATSHEET.md)** — every binding across WezTerm, zsh, tmux and
Neovim, basic to advanced, with the repo's own customisations marked. Keys in it
were extracted from the live config rather than written from memory.

## Install

```sh
git clone https://github.com/rahuljsaliaan/Dotfiles.git
cd Dotfiles
./install.sh          # create every symlink
mise install          # install the pinned tool versions
```

`install.sh` is safe to re-run. An already-correct link is reported and skipped;
anything real sitting at a destination is moved to `<target>.bak` rather than
overwritten. It warns if the Neovim on `PATH` is too old for LazyVim.

## Layout

| Folder | Links to | What it is |
| --- | --- | --- |
| `nvim/` | `~/.config/nvim` | Neovim, [LazyVim](https://www.lazyvim.org) starter |
| `wezterm/` | `~/.config/wezterm/wezterm.lua` | Terminal emulator |
| `tmux/` | `~/.config/tmux/tmux.conf` | Terminal multiplexer |
| `zsh/` | `~/.zshrc` | Shell |
| `starship/` | `~/.config/starship.toml` | Prompt |
| `mise/` | `~/.config/mise/config.toml` | Runtime and tool versions |
| `claude/` | `~/.claude/` *(file by file)* | Claude Code: global instructions, status line, skills |
| `archive/` | *(not linked)* | Configs kept for reference only |
| `CHEATSHEET.md` | — | Keyboard shortcuts for every tool here |

`nvim/` is linked as a whole directory rather than file by file, so
`lazy-lock.json` — which lazy.nvim writes into the config directory — lands in
the repo and keeps plugin versions reproducible. Plugin updates will therefore
show up as changes here; that is intended.

`claude/` is the opposite case: linked file by file, never as a whole
`~/.claude`. That directory also holds credentials, session history and
hundreds of megabytes of per-project state, so only the four configuration
pieces are linked out of it — `CLAUDE.md`, `statusline-command.sh`, and the
`graphify` and `code-cleanup` skills. Skills are linked individually too, so
local skills that are not published can sit in `~/.claude/skills` beside them.

`settings.json` is deliberately not here. Claude Code writes to it at runtime,
so linking it would land those writes — including the machine- and org-specific
`autoMode` block — in the working tree of a public repo.

## Requirements

Everything version-sensitive is pinned in `mise/config.toml`, so `mise install`
covers it without `sudo`:

- **Neovim >= 0.11.2** — LazyVim's minimum. Distro packages are usually far
  older (Ubuntu 24.04 ships 0.9.5), which is why it is pinned here instead of
  installed from `apt`. The `apt` package can stay installed; the mise shim
  takes precedence on `PATH`.
- **lazygit**, **tree-sitter** CLI, **fd** — LazyVim's companions. Note Ubuntu
  names its own fd binary `fdfind`, which is why `fd` comes from mise.

Needed from the system, and already present on a normal desktop: `git >= 2.19`,
a C compiler, `curl`, `ripgrep`, `fzf >= 0.25.1`, and `wl-clipboard` on Wayland.

A **Nerd Font v3+** is required for icons to render — this setup assumes
**Hack Nerd Font**, set as WezTerm's font and used for the glyphs in the tmux
status line.

## Notes

- **`zsh/.zshrc` sets `LANG` to a UTF-8 locale on purpose.** tmux reads the
  locale to decide whether the terminal handles UTF-8, and when it does not, it
  replaces every multi-byte character with `_` — which silently strips the Nerd
  Font glyphs out of the status line.
- **WezTerm sizes its first window from measured cell metrics** rather than a
  hardcoded pixel size, so it tracks whatever display is attached. If
  `font_size` or `window_padding` changes, re-measure per the comment in
  `wezterm/wezterm.lua`.
- **`tmux/tmux.conf` declares undercurl capabilities** so Neovim's LSP
  diagnostics keep their colour inside a tmux session.
- **`archive/` is deliberately not linked.** `alacritty.toml` is kept there as
  the reference the WezTerm config was ported from; Alacritty itself is no
  longer installed.

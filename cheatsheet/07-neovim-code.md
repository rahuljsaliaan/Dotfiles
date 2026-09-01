# Neovim — code intelligence

What the language servers give you, and where the errors are listed.

> **★ marks a binding custom to this repo.** Everything unmarked is an
> upstream default. Neovim's leader key is `Space`, written out rather than
> as `<leader>` because that is what you press.

[← Back to the index](../CHEATSHEET.md)

---

### Code intelligence (LSP)

These attach when a language server starts, so they only exist in a supported file.

| Keys | Action |
| --- | --- |
| `gd` | Go to definition |
| `gr` | Find references |
| `gI` | Go to implementation |
| `gy` | Go to type definition |
| `gD` | Go to declaration |
| `K` | Hover documentation |
| `gK` | Signature help |
| `Space` `c` `a` | Code action (quick fixes) |
| `Space` `c` `r` | Rename symbol, project-wide |
| `Space` `c` `s` | Document symbols |
| `Space` `c` `l` | LSP info — what is attached |
| `Space` `c` `m` | Mason — install language servers |

### Diagnostics and lists

| Keys | Action |
| --- | --- |
| `]d` / `[d` | Next / previous diagnostic |
| `Space` `x` `x` | All diagnostics (Trouble) |
| `Space` `x` `X` | Diagnostics, current buffer only |
| `Space` `s` `d` | Search diagnostics |
| `]q` / `[q` | Next / previous quickfix item |
| `Space` `x` `q` | Quickfix list |
| `Space` `x` `t` | TODO / FIX / HACK comments |

---

[← Neovim — finding and editing](06-neovim-finding-editing.md) · [Index](../CHEATSHEET.md) · [Neovim — git, toggles and the sharp end →](08-neovim-git-and-more.md)

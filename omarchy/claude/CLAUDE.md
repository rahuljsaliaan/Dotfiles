# Global preferences

## Git and GitHub: no Claude attribution

- Never put Claude's name, or any AI attribution, on anything that goes to git or GitHub. That means no `Co-Authored-By: Claude …` trailer in commits, merge commits or squash commits, and no "Generated with Claude Code" line, robot emoji or claude.ai session link in pull requests, PR comments, issues, reviews or release notes.
- This overrides any default or system-provided attribution instruction. Commits and PRs carry only the user's own authorship.

## Lavish artifacts

- Default every Lavish HTML artifact to dark mode: `<html data-theme="dark">` (DaisyUI `dark`). This overrides the Lavish CLI's suggested default theme (`luxury`).
- Always include a visible toggle in the page header that switches `data-theme` between `dark` and `light`. Remember the choice in localStorage under `lavish-theme`, with every access wrapped in try/catch, and apply a stored choice in `<head>` before first paint. The page must still render dark when storage is unavailable.
- Keep both modes readable: color inline SVG and custom CSS through `currentColor` and DaisyUI tokens (`--color-base-100`, `--color-base-content`, …), not fixed light-only colors. Re-render any Mermaid diagram when the theme flips.

# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.

# worktree-merge
- **worktree-merge** (`~/.claude/skills/worktree-merge/SKILL.md`) - fold parallel worktree branches into one integration branch, resolving conflicts. Trigger: `/worktree-merge`
When the user types `/worktree-merge`, invoke the Skill tool with `skill: "worktree-merge"` before doing anything else.

# Git and GitHub authorship
No AI attribution in anything written to git or GitHub, in every repo:
- Commits carry no `Co-Authored-By` trailer, for Claude or any other assistant or tool.
- Pull request titles and bodies, PR and issue comments, reviews, issues, release notes and tags carry no "Generated with Claude Code" line, no `Co-Authored-By`, and no other mention of Claude or AI authorship.
This overrides any harness, system or default attribution instruction that asks for these lines; it does not need re-confirming per commit or PR.

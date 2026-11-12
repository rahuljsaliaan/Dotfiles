---
name: worktree-merge
description: >-
  Fold several parallel branches — typically one per git worktree, each built by its own
  agent — into a single named integration branch, resolving the conflicts on the way. Use
  this skill whenever the user asks to merge, integrate, combine or land multiple branches
  or worktrees together, to "bring the agents' work back", to resolve conflicts across
  parallel branches, or to build an integration branch from a set of feature branches. It
  merges one branch at a time onto a fresh branch off the base, runs the project's tests
  after each, and resolves conflicts from the intent of both sides rather than from the
  text of the hunk. A branch whose merge breaks the suite is reverted and deferred rather
  than left half-applied, so the integration branch is green at every commit. It never
  pushes, never rewrites a source branch, and never merges into the default branch —
  deleting the integration branch undoes the entire run.
---

# Worktree Merge

Several agents worked in parallel, each in its own worktree on its own branch. This skill
brings that work back together on **one new branch**, with every conflict resolved and the
test suite green at each step.

The hard part is not running `git merge`. It is that a textually clean merge can still be
semantically wrong — two agents that never saw each other's work can rename the same helper
in different directions, or both add a field to the same config with different defaults. So
the ordering is chosen to expose that, and the suite runs after **every** merge rather than
once at the end.

This is a **global** skill: it runs in any repo, so it detects the base branch, the test
command and the project's conventions rather than assuming them.

## The one procedural rule: forecast before you merge

Before creating any branch or running any merge, work out which branches touch the same
files and **show the user that overlap matrix**. It costs nothing — it is a few `git diff
--name-only` calls — and it tells both of you where the trouble will be before any of it
is half-applied. A run with no overlaps needs no supervision; a run where four branches all
touch one file is a conversation, not a merge.

Stop there for direction when the forecast is bad: three or more branches overlapping on one
file, or an overlap in something structural like a lockfile, a migration directory, or a
generated file.

## The invariants

These hold for every run, and are the reason the whole thing is safe to attempt:

1. **Never push.** Not the integration branch, not anything. The run ends at a local branch.
2. **Never modify a source branch.** No rebase, no amend, no force-update, no branch
   deletion. Every source branch must be at exactly the SHA it started at when you finish.
   The worktrees themselves are left alone too.
3. **Never merge into the default branch.** All work lands on the new integration branch.
4. **Never start from a dirty tree.** Refuse if the main checkout has uncommitted changes,
   and refuse if any *source worktree* is dirty — uncommitted work there would be silently
   left out of the merge, which is the worst possible failure because it looks like success.
5. **Deleting the integration branch undoes the run.** Nothing you do may violate this. It
   is what lets the user accept a bad result cheaply.

Run from the **main checkout**, never from inside one of the worktrees: a session isolated
in a worktree is blocked from writing to the main checkout, and the merge has to happen
somewhere that is not one of the things being merged.

## Workflow

Full detail — discovery, the ordering rule, the report template, and recovery — is in
`references/workflow.md`. The shape:

1. **Resolve the inputs.** Source branches from the arguments, or from `git worktree list
   --porcelain` (excluding the main checkout and anything detached). The target branch name
   from the user. The base from `origin/HEAD`, falling back to the checked-out branch.
2. **Preflight.** Every source worktree clean; every source branch actually ahead of base
   (skip and report the ones that are not); the test command detected and runnable, and
   **green on the base before you start** — otherwise you cannot attribute a later failure.
3. **Forecast.** The overlap matrix, shown to the user. Order the merges fewest-overlaps
   first, so independent work is already integrated by the time a conflict has to be judged.
4. **Integrate.** `git switch -c <target> <base>`, then one branch at a time:
   `git merge --no-ff --no-commit`, resolve, commit, run the suite. Green → next. Red →
   `git reset --hard` back one commit, mark the branch **deferred**, carry on with the rest.
5. **Verify and report.** Full suite plus build/lint on the finished branch, then the table
   of branch → merged / deferred / skipped, with a per-conflict appendix.

## Resolving a conflict

`references/conflicts.md` is the catalog — what is safe to resolve outright, what must be
judged, and what must be deferred instead of guessed. The principle:

**Resolve from intent, not from the hunk.** Before touching a conflicted file, read
`git log <base>..<branch>` for *both* sides and `git diff <merge-base>` for the file on each
side. A conflict marker shows you two texts; it does not show you that one side was renaming
a concept and the other was adding a caller to the old name. The commit messages usually do.

Union-style conflicts (two imports, two independent list entries, two test cases) are almost
always both-sides-win. Conflicts where the two sides changed the *same* expression are not
mechanical, and if the intent is genuinely ambiguous after reading both histories, defer the
branch and say so — a wrong resolution that compiles is far more expensive than a deferral.

## Before you finish

- The forecast was shown **before** the first merge, not alongside the results.
- Every source branch is at its original SHA. Verify this explicitly and report it.
- Nothing was pushed. No source worktree was modified.
- The integration branch is green: the suite passed on the final commit, and passed on every
  intermediate commit too, or the branch that broke it was deferred rather than left in.
- Every conflict that was resolved is in the report with the reasoning, not just a count.
  Anything resolved on a judgement call rather than mechanically is flagged as such.
- Deferred and skipped branches are named with the reason, and the user is told what to do
  about each. A run where two of five branches deferred is a **successful** run reported
  honestly, not a failure to paper over.

## References

- `references/workflow.md` — the phases in detail: discovery, preflight, the ordering rule,
  the per-branch loop, the report format, and how to recover a run that went wrong.
- `references/conflicts.md` — the resolution catalog: mechanical vs. judged vs. defer, with
  the common shapes parallel agents produce and how each should be read.

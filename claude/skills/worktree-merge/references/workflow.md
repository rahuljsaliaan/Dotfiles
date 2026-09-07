# Workflow: forecast → integrate → verify

Every command here runs in the **main checkout**. Nothing in this file may modify a source
branch or a source worktree.

## Step 1 — Resolve the inputs

**Source branches.** Explicit arguments win. With none, take every branch that has a
worktree, excluding the main checkout and anything detached:

```sh
git worktree list --porcelain | awk '
  /^worktree / { path = substr($0, 10); if (main == "") main = path; next }
  /^branch /   { b = substr($0, 8); sub(/^refs\/heads\//, "", b)
                 if (path != main) print b "\t" path }'
```

**Base.** `git symbolic-ref --quiet --short refs/remotes/origin/HEAD`, falling back to the
currently checked-out branch when there is no remote. Fetch first if the repo has one, so
the base is not a stale local ref.

**Target.** The branch name the user asked for. If they did not give one, ask — do not
invent it. Refuse a target that already exists unless the user says to reuse it, and if they
do, verify it is an ancestor-free scratch branch rather than something with history you would
be building on top of blindly.

## Step 2 — Preflight

Every one of these is a stop, not a warning:

- **Main checkout clean.** `git status --porcelain` empty. You are about to switch branches.
- **Every source worktree clean.** Uncommitted work in a worktree will not be merged, and the
  run would report success having silently dropped it. Name the dirty worktree and stop.
- **Test command found.** Detect from `package.json` scripts, `Makefile`, `pyproject.toml`,
  `Cargo.toml`, `justfile`, or CI config. Ask if you cannot find one; do not proceed
  without a way to tell a good merge from a bad one.
- **Base is green.** Run the suite on the base *before* merging anything. If it is already
  red you cannot attribute a later failure to a branch, which is the whole mechanism here.
  Report the pre-existing failures and ask whether to continue against a red baseline.

Then drop, with a note rather than a stop:

- Branches with no commits ahead of base (`git rev-list --count <base>..<branch>` is 0) —
  nothing to merge.
- Branches already fully merged into base.

## Step 3 — Forecast

For each branch, the files it touches:

```sh
git diff --name-only <base>...<branch>
```

Intersect every pair. Present the result **before** doing anything else — a table of the
pairs that overlap and the files they overlap on, plus the branches that overlap with
nothing.

**Order the merges fewest-overlaps-first.** A branch that touches nothing anyone else touched
merges cleanly and is then part of the base that later conflicts are judged against, which
makes those judgements better-informed. The most entangled branch goes last, when the most
context is available.

Stop for direction when: three or more branches overlap on one file; an overlap lands in a
lockfile, migration directory, or generated artefact; or a branch renames or deletes a file
another branch modifies (`git diff --name-status` shows `R`/`D` against the other's `M`).

## Step 4 — Integrate

```sh
git switch -c <target> <base>
```

Then, per branch in the chosen order:

```sh
git merge --no-ff --no-commit <branch>
```

`--no-ff` so each branch is a distinct merge commit you can revert as a unit; `--no-commit`
so nothing is recorded until the conflicts are settled and inspected.

**On conflict**, for each conflicted file, before editing it:

```sh
git log --oneline <base>..<branch>          # what this side was trying to do
git log --oneline <base>..HEAD              # what is already integrated
git diff $(git merge-base <base> <branch>)..<branch> -- <file>
```

Resolve per `conflicts.md`. Record for every hunk: the file, what each side wanted, what you
chose, and why. That record is the report; do not reconstruct it afterwards from memory.

**Commit**, naming the branch, and say in the body what was resolved:

```sh
git commit -m "merge: integrate <branch>" -m "<what conflicted and how it was settled>"
```

**Run the suite.**

- **Green** → next branch.
- **Red** → this branch caused it, because everything before it passed. Fix only an obvious
  merge artefact: a duplicated import, a hunk applied twice, a stale reference to something
  the other side renamed. Anything beyond that is real work, and this is not the place to do
  it. Otherwise:

  ```sh
  git reset --hard HEAD~1
  ```

  Mark the branch **deferred**, and carry on with the rest. Never leave a red commit on the
  integration branch, and never `git merge --abort` before you have recorded the analysis —
  the reason it failed is the most useful thing the run produces.

## Step 5 — Verify and report

On the finished branch: the full suite, plus build and lint if the project has them. Then
confirm the invariants held, and say so explicitly rather than implying it:

```sh
git rev-parse <each source branch>     # compare against the SHAs recorded in step 1
git status --porcelain                 # in each source worktree: still clean
```

The report:

| Branch | Result | Conflicts | Tests |
| --- | --- | --- | --- |
| `fix-auth` | merged | 0 | pass |
| `feat/billing` | merged | 2 files | pass |
| `feat/search` | deferred | 1 file | failed: 3 specs |
| `chore/deps` | skipped | — | no commits ahead of base |

Then the per-conflict appendix: file, both intents, the resolution, and whether it was
mechanical or a judgement call. Flag the judgement calls; they are what the user needs to
review.

Close with what to do next about each deferred branch — usually "merge it alone and fix the
N failures", since by then the other work is already in and the conflict is smaller.

## Safety & rollback

The whole run is one branch. To undo everything:

```sh
git switch <base> && git branch -D <target>
```

Nothing else has changed: source branches are at their original SHAs, the worktrees are
untouched, nothing was pushed. If a run goes wrong midway, this is the recovery — do not try
to unpick individual merges.

If the working tree is left mid-merge by an interruption, `git merge --abort` returns to the
last good commit on the integration branch, which is green by construction.

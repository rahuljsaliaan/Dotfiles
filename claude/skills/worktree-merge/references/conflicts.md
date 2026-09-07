# Conflict catalog

Read this before resolving anything. Each entry is a shape that parallel agents actually
produce, with how to tell it apart and what to do. The three verdicts are **mechanical**
(resolve outright), **judged** (resolve, but say in the report that you decided), and
**defer** (revert the branch; do not guess).

The rule underneath all of them: **a conflict marker shows you two texts, not two
intentions.** Read `git log <base>..<branch>` for both sides before you touch the file.
Parallel agents never saw each other's work, so the two sides are often coherent apart and
incoherent together in a way the text alone will not reveal.

## 1. Union — both sides added, neither changed

### Detect
Both sides inserted at the same point without touching each other's lines: two new imports,
two new entries in a list, array or enum, two new test cases, two new sibling functions.

### Resolve — mechanical
Keep both. Preserve the file's existing ordering convention (alphabetical imports stay
alphabetical). Where the language has a canonical order, use it rather than concatenating
in merge order.

### Defer instead when
The two additions declare the **same name**. That is not a union, it is entry 3.

## 2. Formatting-only collision

### Detect
`git diff -w` on the conflicted region is empty, or the only difference is import ordering,
trailing commas, or a reflow.

### Resolve — mechanical
Take whichever side matches the project's formatter, then run the formatter over the file.
Do not hand-pick whitespace.

## 3. Same symbol, different definitions

### Detect
Both sides define, rename, or change the signature of the same function, constant, type or
config key. Frequently one side renamed a concept and the other added a caller to the old
name — which shows up as a conflict in one file and a *silent* break in another.

### Resolve — judged
Establish which side owns the concept from the commit messages. Take that side's definition,
then **grep the whole tree for the other side's name** and update every reference, including
in files that did not conflict. This is the case where a textually complete resolution is
still broken, so the post-merge test run matters most here.

### Defer instead when
Both sides changed the same signature in incompatible ways and the callers disagree about
which is right. Two valid designs cannot be merged by picking one and hoping.

## 4. Lockfiles and generated artefacts

### Detect
`package-lock.json`, `yarn.lock`, `poetry.lock`, `Cargo.lock`, `go.sum`, snapshot files,
compiled or codegen output.

### Resolve — mechanical, but never by hand
Never edit the conflict markers. Take the base version and regenerate:

```sh
git checkout --ours <lockfile> && npm install    # or the project's equivalent
```

For generated code, take either side and re-run the generator. A hand-merged lockfile is
wrong even when it parses.

### Defer instead when
The two sides pinned **incompatible versions** of the same dependency. Regenerating hides a
real disagreement about what the project depends on.

## 5. Both sides edited the same expression

### Detect
The conflicting lines are one statement, condition, or literal that each side changed
differently — a changed default, a tightened condition, a different timeout.

### Resolve — judged
Only when the two intents compose: one side tightened a condition and the other added an
unrelated clause to it, and the conjunction is what both wanted. Say in the report that you
composed them.

### Defer instead when
The intents are alternatives rather than additions — two different defaults for the same
setting, two different thresholds. There is a right answer and it is the user's, not yours.

## 6. One side deleted, the other modified

### Detect
`git status` shows `deleted by us` / `deleted by them`, or `git diff --name-status` shows
`D` on one side against `M` on the other.

### Resolve — judged
Read why it was deleted. A file removed as part of a rename (`git log --follow`, or a
matching addition elsewhere in the same branch) means the other side's changes should be
**moved to the new location**, not dropped.

### Defer instead when
The deletion was deliberate removal of a feature the other side was actively extending. That
is two people disagreeing about whether something should exist.

## 7. Migrations and ordered, append-only sequences

### Detect
Two branches each added a migration, a numbered fixture, or an entry to anything whose order
is part of its meaning.

### Resolve — judged
Keep both and renumber the later one so the sequence is contiguous, **only if** the two are
independent. Check what each touches first.

### Defer instead when
The two migrations touch the same table or column. Ordering them is a schema decision with
consequences beyond the merge.

## When you defer

Deferring is a normal outcome, not a failure. `git reset --hard HEAD~1`, mark the branch,
and continue with the rest — the remaining branches usually merge fine, and the deferred one
is easier to handle alone afterwards, against a base that now contains everything else.

In the report, give the user the three things they need: what the two sides each wanted, why
it could not be settled without them, and the smallest next step (nearly always: merge that
one branch on its own and resolve the single remaining question).

# Workflow: report → fix → verify

The operating contract: **report before you edit**. The only work that precedes the report is
read-only discovery and a baseline capture. Edits happen after the user has seen the scope.

---

## Step 1 — Scope

Pick the **smallest meaningful target**, in this order:
1. An explicit path/glob the user gave (file, dir, package).
2. Else the **changed files** (`git status --short`, `git diff --name-only`) — cleaning what's
   in flight is usually what's wanted.
3. Else the package/module you're currently in.

Confirm the scope if it's ambiguous, or if the user said "the whole repo" (a repo-wide pass is
fine, but say so and expect a long report). Never silently expand scope beyond what was asked.

## Step 2 — Discover (read-only)

Detect, don't assume:
- **Language & package manager** — `package.json` (+ `pnpm`/`npm`/`yarn` from the lockfile),
  `pyproject.toml`, `Cargo.toml`, `go.mod`, etc.
- **Commands** — the build / lint / typecheck / test commands. Look in `package.json` scripts,
  a task runner (turbo/nx/make), and CI config. Note monorepo filters (e.g. a per-package
  `--filter`) so you can scope verification to what you touched.
- **Constants conventions** — search for the existing home of constants: a `constants.*`
  module, enum files, `as const` maps, a registry, SQL-table-name exports. **You will reuse
  this.** Also find any **guard test** that bans bare literals (it both lists violations and
  is the contract to keep green).
- **Layer boundaries** — `eslint` `no-restricted-imports`, tsconfig `paths`, dependency-cruiser
  rules, or a stated import law. These tell you what you must not couple.
- **App-edge directories** — where env reads are *legitimate* (CLI entry, server bootstrap,
  test harness). Everything else is "library" for rule 2.

## Step 3 — Baseline

Run lint + typecheck now (and tests if they're fast), and **record the pre-existing
failures**. This is the line you measure against: your job is to fix what you targeted and add
**zero** new failures. It also stops you from blaming yourself for — or taking credit for —
pre-existing state. If the baseline is already broken in a way unrelated to the cleanup, note
it; don't silently "fix" unrelated things or hide behind them.

## Step 4 — Scan

Per rule (see `rules.md`):
- **Lint / type** — the linter and compiler output is the source of truth.
- **Magic literals** — grep/AST, ranked by repetition and identifier-likeness; run the guard
  test if one exists.
- **Config from env** — grep `process.env` (and language equivalents) **outside** the app
  edge; flag heavy/secret-bearing imports in library code.
- **The rest** — `any`/casts, unvalidated boundaries, non-additive public changes you might be
  about to make, cross-layer imports.

## Step 5 — Report (stop here for direction if large/risky)

Present a **grouped findings report**. Suggested shape:

```
Cleanup report — <scope>   (baseline: <N> lint, <M> type errors pre-existing)

1. Magic strings/numbers  (8)
   - path/to/a.ts:42   "__planner__"     → RESERVED_INTENT_ID.PLANNER (constants.ts exists)
   - path/to/b.ts:17   3 (retry cap)     → DEFAULTS.maxRetries
   ...
2. Config from env  (2)   ⚠ touches how keys flow
   - lib/x.ts:9        process.env.OPENAI_API_KEY  → thread via config.providerKeys; read at app edge
   ...
3. Strict types  (4)
4. Lint/type errors  (5)
   ...

Flagged / needs a decision:
   - "message" at ui/*.ts is BOTH a UI id and a result kind — leave bare (coupling risk)? 
   - removing exported `oldFoo` (rule 5) — confirm it's not consumed downstream.
```

Rules:
- Group **by rule**, each item `file:line → one-line proposed fix`.
- Mark **risky** items (anything touching public API, config flow, or wide renames) with `⚠`.
- Put genuinely **uncertain** calls under "needs a decision" — ask, don't guess.
- If the scope is large or several items are risky, **stop and get direction** before fixing.

## Step 6 — Fix

- **Smallest diffs, batched by rule.** One rule's worth of changes at a time is easier to
  review and to roll back.
- **Reuse the existing constants module / registry** — don't spawn a parallel one.
- **Re-point duplicates** when you extract a literal — the single source is the point.
- **Match surrounding style** — naming, formatting, comment density. The cleanup should be
  invisible as "an outsider edited this".
- **Don't change behavior.** A fix that alters what the code does is out of scope — surface it
  separately.
- **Don't change public API non-additively** without an explicit OK (rule 5).
- Verify between **risky** batches, not just at the end, so a regression is localized.

## Step 7 — Verify

- Re-run **build / lint / typecheck / test** for the touched scope; compare to the baseline:
  targeted issues resolved, **nothing new red**.
- If the repo has a **graph/index updater** that's meant to run after code changes (e.g.
  `graphify update .`), run it.
- If the repo keeps a **changelog / deviation log** for consumer-visible changes, add a concise
  note in the same pass (a public-API or config-flow change qualifies; pure-internal tidies
  usually don't).
- **Never end redder than baseline.** If you can't reach green, stop and report exactly what's
  left and why — don't paper over it with disables or by reverting the wrong thing.

## Step 8 — Summarize

Report: what was **found**, what was **fixed** (by rule, with counts), what was **deferred**
and why, and the **before → after** verification numbers. Be honest about anything still red,
skipped, or uncertain. If you flagged items in step 5 that the user hasn't decided, list them
as open.

---

## Safety & rollback

- **Read the target before you delete or "simplify" it.** A seemingly-unused export may be the
  public surface or referenced by string/reflection. When the code contradicts how it was
  described, surface that — don't proceed.
- **Don't touch** generated files, vendored/third-party code, lockfiles, or snapshots (except a
  guard/snapshot test you're *consciously* updating).
- **A wide ripple is a stop-and-confirm**, not a silent mass edit (a constant used in 50 places,
  a rename across packages).
- **`eslint-disable` is a last resort** for a true false positive, single line, with a reason.
  Never to silence a real issue or to make red go green dishonestly.
- **Keep batches revertible** — if verification goes red after a batch, you know which one and
  can back it out cleanly.

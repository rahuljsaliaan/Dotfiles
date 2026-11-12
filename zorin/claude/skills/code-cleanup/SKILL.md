---
name: code-cleanup
description: >-
  Clean up code and fix lint/type errors against a strict principle set — chiefly NO magic
  strings (extract every meaningful literal to a named constant) and, for SDKs/libraries,
  config and API keys INJECTED from outside rather than read from the environment. Use this
  skill whenever the user asks to clean up code, fix lint or typecheck errors, remove magic
  strings / hardcoded values, extract constants, get secrets or config out of library code,
  tidy a file / package / repo, or run a "principled cleanup pass". It runs a report → fix →
  verify cycle: scan for violations, present a grouped findings report FIRST, fix with the
  smallest diffs, then re-run the project's build/lint/typecheck/test to verify nothing
  regressed. Project-agnostic: it detects the project's commands, constants conventions, and
  layer boundaries instead of assuming them.
---

# Code Cleanup

Make code conform to a strict, principled standard — **without changing behavior** and
**without leaving the tree redder than you found it**. The headline of that standard is two
rules the user holds non-negotiable: **no magic strings**, and **library/SDK code takes its
config and secrets from the caller, never from the ambient environment**. Everything else
(strict types, validation at boundaries, additive public APIs, structural seams over heavy
imports, layer isolation, plus the project's own lint/type errors) rides alongside.

This is a **global** skill: it runs in any repo. So it never assumes file paths, command
names, or constant locations — it **detects** them. Where this doc shows a concrete example,
it is an illustration of the *shape* to look for, not a literal to expect.

## The one procedural rule: report before you edit

You operate in **report → fix → verify** order. You do not start editing until you have
shown the user a grouped findings report and they've seen the scope. A cleanup pass can touch
many files and restructure how config flows; the report is both the user's chance to redirect
and the record of what changed. Surface anything *uncertain* (a risky rename, a public-API
change, a literal that might be a deliberate exception) as a **question or a flagged item** —
never silently decide it.

The only thing you do before the report is **read-only discovery** (below) and capturing a
**baseline** of the linters/tests, so you can prove you didn't regress anything.

## The rule set this skill enforces

The two headline rules first — they override convenience and "it already works":

1. **No magic strings (or magic numbers).** Every literal that carries *meaning beyond its
   position* — an id, key, tool/event/widget name, table/column, status or enum value,
   env-var name, route, mode flag, sentinel, limit, timeout, port, retry count — becomes a
   **named constant with a single source of truth**. Reuse the project's existing constants
   module / enum / registry; don't invent a parallel one. Genuinely one-off human prose (a
   single log line) is exempt *unless the project centralizes those too* (e.g. a prompt
   registry — then route it there).

2. **Config & secrets come from outside, in library/SDK code.** A library, SDK, or any
   reusable package must **not** read configuration (API keys, URLs, model names, labels,
   budgets, feature flags) from `process.env` or other ambient global state. The caller
   passes it in through an explicit config object / parameter. Env reads live **only at the
   application edge** (the CLI/server entrypoint), which reads once and **injects** into the
   library. For heavy third-party clients, define a **structural interface** in the library
   and let the app inject the concrete implementation; lazy-load heavy deps so the default
   path never pulls them.

Then the supporting principles (full detail in `references/rules.md`):

3. **Strict types, no `any`.** Replace `any`/unchecked casts with real types or `unknown` +
   a narrowing/validation step.
4. **Validate at IO boundaries.** Untrusted input (wire, file, MCP, user) is parsed with the
   project's validation lib (e.g. Zod) at the seam, **fail-loud** with the offending field
   named — never silently dropped or coerced.
5. **Public APIs evolve additively.** Don't rename/remove/repurpose exported names, event
   types, or wire fields; new fields on existing shapes are optional. Internal renames are
   free if you update every in-repo caller in the same pass.
6. **Structural seams over heavy imports**, and **lazy-load heavy deps** — keep the common
   path light and the dependency graph honest.
7. **Respect layer isolation.** Honor the project's import boundaries (e.g. `no-restricted-
   imports`, tsconfig paths). If a lower layer needs a type from above, surface it the way
   the project already does — don't leak the dependency.

`references/rules.md` is the catalog: for each rule, **how to detect it**, **how to fix it**,
and **what is a legitimate exception** (e.g. a literal that doubles as two concepts and must
stay bare to avoid coupling them). Read it before scanning.

## Workflow

Full detail — command discovery, the report template, the verification ritual, scoping,
batching, and safety/rollback — is in `references/workflow.md`. The shape:

1. **Scope.** Default to the smallest meaningful target: an explicit path arg, else the
   changed files (`git status`/diff), else the package you're in. Confirm if the scope is
   ambiguous or the user said "the whole repo".
2. **Discover (read-only).** Detect: language + package manager; the build / lint / typecheck
   / test commands (package scripts, task runner, Makefile, CI); the constants conventions
   (existing constants/enum/registry modules, any guard test that bans bare literals); the
   layer boundaries; and the **app-edge directories** where env reads are legitimate.
3. **Baseline.** Run lint + typecheck (+ tests if fast) and record the *pre-existing* state.
   You will compare against this — you fix what you can and you must add **zero** new
   failures.
4. **Scan.** Collect violations per rule: the linter/compiler output for lint/type; grep/AST
   for magic literals, `process.env` outside the edge, `any`, unvalidated boundaries, etc.
5. **Report.** Present the grouped findings report (by rule → file:line → one-line fix), with
   risky items flagged and uncertain calls raised as questions. **Stop here for direction if
   the scope is large or anything is risky.**
6. **Fix.** Smallest diffs, batched by rule, reusing existing constant modules. Match the
   surrounding code's style. Don't change public API non-additively without flagging.
7. **Verify.** Re-run build/lint/typecheck/test; compare to baseline (targeted issues fixed,
   nothing new red). Run the project's graph/index updater if it has one (e.g. `graphify
   update .`). Add a changelog/deviation note if the repo keeps one.
8. **Summarize.** What was found, fixed, and deferred (with reasons), plus the before/after
   verification state. Be honest: if something is still red or was skipped, say so.

## Before you finish

- The report was shown **before** edits, and risky/uncertain items were flagged, not guessed.
- Every fixed magic literal points at **one** named constant in the project's conventional
  place; duplicates were re-pointed; a guard test (if any) still passes or was updated.
- No `process.env` (or ambient config read) remains in library/SDK code; env reads, if any,
  are at the app edge and **inject** into the library.
- No public/exported name, event type, or wire field was renamed or removed.
- Verification is **green relative to baseline** — you added no new lint/type/test failures.
  If you couldn't reach green, you said exactly what's left and why.
- Behavior is unchanged: no fix "works" by altering what the code does. An `eslint-disable`
  is used only for a genuine false positive, with a one-line justification.

## References

- `references/rules.md` — the full rule catalog: detect / fix / legitimate-exception for each
  rule, with the magic-string and config-injection rules covered in depth.
- `references/workflow.md` — report → fix → verify in detail: command & convention discovery,
  the report format, scoping & batching, the verification ritual, and safety/rollback.

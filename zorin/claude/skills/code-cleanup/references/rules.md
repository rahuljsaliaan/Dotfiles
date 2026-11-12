# Rule catalog

For each rule: **Detect** (how to find violations), **Fix** (how to resolve them), and
**Legitimate exception** (when it is *correct* to leave it). Apply judgement — the goal is
code that reads as principled, not a literal-free codebase that's harder to follow.

---

## 1. No magic strings (and magic numbers) — the headline rule

A *magic literal* is a hardcoded value that carries **meaning beyond its position**: the
reader has to *know* that `"__planner__"` is the planner's id, that `3` is the max retry
count, that `"plan-card"` names a widget the rest of the system keys off. That knowledge
belongs in a **named constant with one source of truth**, not scattered across call sites.

### What counts (extract these)
- **Identifiers & sentinels**: ids, reserved/default ids, session keys (`"__default__"`,
  `"__planner__"`).
- **Names the system keys off**: tool names, event/`type` discriminants, widget/UI ids,
  capability/interaction names, server ids.
- **Persistence**: table names, column names, SQL fragments reused in more than one place.
- **Enumerated values**: statuses (`"draft" | "approved"`), modes, kinds, finish reasons,
  source kinds — prefer a single enum/`as const` map the types derive from.
- **Wire/protocol**: route paths, header names, env-var *names* (the string `"OPENAI_API_KEY"`
  is itself a constant even where reading it is allowed).
- **Magic numbers with meaning**: limits, timeouts, ports, retry/attempt caps, byte caps,
  budgets, slice sizes. (`0`, `1`, `-1`, `2` in obvious arithmetic are fine.)
- **Any literal that appears more than once** — duplication is the strongest signal; a
  repeated literal is a constant waiting to be named, and a future typo waiting to happen.

### What does NOT need extraction
- **One-off human-facing prose**: a single log message or a single thrown-error string used
  in exactly one place — *unless* the project centralizes user-/model-facing text (a prompt
  registry, an i18n table). If it does, route the string **there**, not to a plain `const`.
- **Trivial, self-evident values**: `""`, `0`, booleans, an array's `.length === 0`.
- **Test fixtures / sample data** — literals in tests are usually fine. BUT a reserved id or
  protocol constant referenced *by* a test should use the exported constant, so the test
  tracks the source of truth (and a guard test stays meaningful).

### Detect
- `grep`/AST for string and numeric literals in the target; rank by **repetition** and by
  **whether the value looks like an identifier/key** (snake/kebab/`__sentinel__`, all-caps,
  url-ish, number-with-units).
- If the project has a **guard test** (a test that scans source for banned bare literals),
  run it — it names the violations for you and is the contract to keep green.
- Look for two call sites using the *same* literal: that's a guaranteed extraction.

### Fix
1. **Find the project's constants convention first** — a `constants.ts`, an enum module, an
   `as const` map, a registry, `*_TABLE_SQL` exports. Reuse it. Only create a new module if
   none exists, and put it where the project would (a leaf module others import, no cycles).
2. **Name by meaning**, grouped by domain (e.g. `RESERVED_INTENT_ID.PLANNER`,
   `DEFAULTS.maxRetries`). Derive enums/types from the constant, not vice versa, so there's
   one source.
3. **Re-point every duplicate** to the new constant in the same pass — the win is the single
   source, not just the one site you noticed.
4. If a value is **model-/user-facing text** and a registry exists for that, register it
   there (overridable) rather than as a code constant.
5. If the project has a **guard test**, add the new constant to its allowlist module or
   update the test so it still passes.

### Legitimate exception
- A literal that **doubles as two unrelated concepts** where naming one would wrongly couple
  them (e.g. a string that's both a UI id *and* a result `kind` discriminant). Extracting one
  use can entangle the other. Leave it bare **with a comment**, or exclude it from the guard
  test explicitly — and say so in the report.
- A value that is **defined by an external spec** and only ever appears once at the boundary
  that owns that spec (still prefer a named constant, but don't fan it out).

---

## 2. Config & secrets from outside (library/SDK code) — the headline rule

Reusable code (a library, SDK, published package, or any module a consumer embeds) must be
**inert about its environment**. It receives everything it needs — API keys, base URLs, model
names, labels, budgets, timeouts, feature flags — from the **caller**, through an explicit
config object or function parameter. It does not reach into `process.env`, read a global
config file, or carry hidden defaults sourced from the ambient environment.

Why the user holds this: **testability** (tests run offline with no env setup and no secrets
on disk), **embeddability** (the consumer owns its secrets and config), **determinism** (no
behavior that changes with an unset variable), and **honesty** (the dependency graph and the
config surface are visible, not smuggled).

### Where env reads ARE allowed
Only at the **application edge** — the CLI `index.ts`, the server bootstrap, the test
harness. The edge reads env **once** and **injects** it into the library's config. Even there,
prefer config-authoritative-with-env-fallback over scattering `process.env` through the app.

### Detect
- `grep` for `process.env` (JS/TS), `os.environ`/`getenv` (Python), `std::env` (Rust), etc.,
  **outside** the detected app-edge directories. Each hit in library code is a violation.
- Imports of **secret-bearing or heavy SDK clients** inside library code (the library should
  depend on a *structural interface*, with the concrete client injected by the app).
- Default values that resolve from globals/env at module load.
- A function that "just works" without the caller passing a key — find where it got the key.

### Fix
1. **Thread the value through the config object / params** from the edge to the use site. Add
   it to the library's config type (optional if it has a safe default the *caller* can set).
2. For a **heavy or secret-bearing third-party client**, define a **structural interface** in
   the library describing just the methods it calls; the app constructs the real client and
   injects it. (This also keeps the heavy dependency out of the library's import graph.)
3. **Lazy-load** heavy/optional deps so the default code path doesn't pull them; load only
   when the feature is configured.
4. At the **edge**, read env into the config: `config.key ?? process.env.THE_KEY` — config
   authoritative, env as fallback, the env-var *name* itself a named constant.
5. Make tests pass config explicitly (no env, no network) — if a test needed an env var
   before your change, that was the smell.

### Legitimate exception
- The **app entry/edge** reading env to build config — that's the intended home, not a
  violation.
- `NODE_ENV`-style **framework signals** that gate dev-only behavior (logging, error display)
  — still prefer threading a flag, but a single well-marked read at a boundary is tolerable.
  Never read **secrets/config** this way in library code.

---

## 3. Strict types — no `any`, no unchecked casts

**Detect**: `any` annotations, `as` casts that launder types, `@ts-ignore`/`@ts-expect-error`
without a reason, implicit-any params, untyped function returns at boundaries.
**Fix**: give the real type; or `unknown` + a narrowing guard / schema parse before use.
Replace a cast with a type guard. Keep `@ts-expect-error` only with a one-line reason.
**Exception**: a genuinely heterogeneous test helper, or a typed-at-the-seam interop point —
narrow it as locally as possible and comment why.

## 4. Validate at IO boundaries — fail loud

**Detect**: untrusted input (HTTP/wire, file, MCP/tool result, user input) used without a
parse/validate step; `JSON.parse` results used directly; silent `?? fallback` that hides a
malformed payload.
**Fix**: parse with the project's validation lib (e.g. Zod) **at the seam**; on failure throw
or return a typed error **naming the offending field** — never silently drop or coerce. The
inside of the module then works with validated, typed data.
**Exception**: data already validated upstream in the same trust domain — don't re-parse on
every hop; validate once at entry.

## 5. Public APIs evolve additively

**Detect**: a rename/removal/repurposing of an **exported** name, an event `type` value, or a
wire/serialized field within the cleanup diff.
**Fix**: keep the old name/shape; **add** the new one. New fields on existing public shapes
are **optional**. If you must restructure internals, update **every in-repo caller in the same
pass** — internal renames are free, public ones are not.
**Exception**: a name that was never actually public (not exported, not on the published
surface) — internal, rename freely.

## 6. Structural seams over heavy imports; lazy-load heavy deps

**Detect**: a library importing a large/optional/secret-bearing dependency directly on the
common path; a concrete heavy type crossing a layer boundary.
**Fix**: depend on a **structural interface** (the shape you use), inject the concrete thing;
`import type` for type-only needs (erased at runtime); dynamic-`import()` heavy optional deps
behind the feature that needs them.
**Exception**: a small, ubiquitous, always-needed dep — don't add indirection for its own
sake.

## 7. Respect layer isolation

**Detect**: an import that crosses a boundary the project forbids (check `eslint`
`no-restricted-imports`, tsconfig `paths`, dependency-cruiser config, or a stated "X may only
be imported from Y" rule); a lower layer importing an upper layer.
**Fix**: route through the seam the project already provides — surface the needed type/value
from the allowed module instead of reaching across. If a type genuinely must cross, **export
it from the owning layer** and import that.
**Exception**: none silently. If the boundary itself is wrong, **raise it** with the user;
don't quietly punch a hole.

## 8. Plain lint / typecheck / dead code

**Detect**: the linter and compiler output (the source of truth); unused exports/vars/imports;
unreachable code.
**Fix**: resolve the actual issue, not the symptom. Remove dead code only when you've
confirmed it's truly unused (not part of the public API, not referenced by string/reflection,
not a re-export others rely on). Prefer a real fix over a disable.
**Exception**: a lint rule that's a **false positive** here — `disable` the single line with a
one-line justification; don't blanket-disable a rule for a file.

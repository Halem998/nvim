# Research Report: Task #90

**Task**: 90 - Adoption lint for the shared task-lookup helper
**Started**: 2026-09-01
**Completed**: 2026-09-01
**Effort**: medium
**Dependencies**: None (informational overlap with task 48 and task 116 — see Risks)
**Sources/Inputs**: - Codebase (agent-system/extensions/**), specs/reviews/review-2026-08-24-refactor-survey.md, specs/errors.json, existing lint scripts (scripts/lint/*.sh), test-common-lib.sh, live command re-measurement via grep/jq
**Artifacts**: - specs/090_adoption_lint_for_shared_task_lookup_helper/reports/01_task-lookup-adoption-lint.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch numbers ("111 files", "SIX callers, ZERO overlap") do not reproduce and should not
  be carried into the plan. Re-measured against the current tree: the literal task-lookup jq
  shape appears in 122 files total, 96 of them on executable surfaces (`scripts/*.sh` +
  `commands/`, `skills/`, `agents/` `.md`); narrowed to the exact full-record-lookup shape that
  duplicates `skill_validate_input()` line-for-line, it is **63 files / 69 occurrences** on
  executable surfaces (62 after excluding `skill-base.sh` itself, the canonical definition).
- **`skill_validate_input()` (`skill-base.sh:185`) has zero real callers**, not six. Every
  non-definition, non-comment hit is either a doc example (`docs/guides/creating-skills.md`,
  `docs/examples/research-flow-example.md`) or the function's own docstring. `skill-researcher`,
  the reference research skill, hand-rolls the identical jq lines instead of calling it.
- There is a **second, separate canonical implementation** the dispatch message did not
  distinguish: `gate_in()` in `command-gate-in.sh`, invoked at the command layer via
  `source .claude/scripts/command-gate-in.sh "$task_number" "$operation"`. This one genuinely has
  adopters — `task.md`, `orchestrate.md`, `review.md`, `revise.md`, `todo.md`, plus
  `skill-orchestrate`/`skill-orchestrate-hard`/`skill-todo` (which source it transitively). The
  "SIX callers" in the dispatch message most likely describes `gate_in()`'s adoption, misattributed
  to `skill_validate_input()`. These are two distinct, un-unified helpers solving overlapping
  problems at different layers; the lint must not conflate them.
- The repo already has an established, working template for exactly this kind of gate:
  `tests/test-common-lib.sh`'s "single-source assertion" for the session-ID generator, corrected
  under `err_1787022038113_c3VPTR` (now `fixed`). It fixes precisely the three defects the
  dispatch asked to avoid: `.sh`-only file-type scope, an environment-dependent root, and no
  executable/prose distinction. Recommended: model the new lint's *scan-root and file-type-scope*
  logic on this file, but its *enforcement convention* (structural detection + explicit reasoned
  allowlist, not a hard zero-tolerance assertion) on `lint-state-writer-boundary.sh`, since the
  task-lookup class currently has real, non-zero migration debt that must not block landing the
  gate.
- **Recommendation**: ship `scripts/lint/lint-task-lookup-adoption.sh` (new) with a small,
  reasoned allowlist covering the ~62 known current offenders, wire it as `verify-deploy.sh` gate
  17, and let migration happen incrementally afterward — this satisfies "prevents NEW occurrences
  from day one" without gating the lint's landing on a full backlog migration.
- **Sequencing risk**: task 116 (core agent-system redesign, currently `researching`, run-alone)
  explicitly names this task's target files (`skill-researcher`, `skill-planner`,
  `skill-implementer`, `skill-orchestrate`, and their `-hard` twins) as candidates for deletion or
  heavy rewrite, and its own description flags that this lint's adopter/duplicate counts "change
  if the collapse lands first." See Risks & Mitigations.

## Context & Scope

Scope per the dispatch: build the adoption lint for the inline task-lookup jq pattern first, land
it green (baseline-known or fixed-then-enforced), then treat call-site migration as incremental.
Explicitly excluded: the raw `git commit -m` class, which is task 48's territory — this report
does not propose edits to git-commit call sites, though findings about that lint's stated
convention (`lint-state-writer-boundary.sh` family) are used as a cross-reference for how this
repo lands adoption lints.

Territory: research only. No files under `agent-system/extensions/**` or `.claude/**` were
modified. No task-number references appear outside `specs/**` in this report per
`rules/no-task-references-in-deliverables.md`.

## Findings

### Codebase Patterns

**The two canonical implementations, precisely:**

- `skill_validate_input()` — `agent-system/extensions/core/scripts/skill-base.sh:185`. Called by
  a skill's own bash block after `source .../skill-base.sh`. Sets `TASK_DATA`, `TASK_TYPE`,
  `TASK_STATUS`, `PROJECT_NAME`, `PADDED_NUM`, `TASK_DIR`, `TASK_DIR_ABS`; `exit 1` (not `return`)
  on not-found or terminal status. Zero real callers found anywhere in the source store.
- `gate_in()` — `agent-system/extensions/core/scripts/command-gate-in.sh` (auto-invoked as
  `gate_in "$1" "$2"` at the bottom of the file when sourced with two positional args). Sets
  `SESSION_ID`, `TASK_TYPE`, `TASK_STATUS`, `PROJECT_NAME`, `DESCRIPTION`, `PADDED_NUM`; `return 1`
  on failure (safe to source-and-check); also acquires the task lock, registers the session, and
  prints the deploy-freshness warning. Real adopters: `commands/task.md`, `commands/orchestrate.md`,
  `commands/review.md`, `commands/revise.md`, `commands/todo.md`,
  `skills/skill-orchestrate/SKILL.md`, `skills/skill-orchestrate-hard/SKILL.md`,
  `skills/skill-todo/SKILL.md`.

These are not interchangeable today (different export sets, different failure semantics, `gate_in`
does locking/session work `skill_validate_input` does not) — the lint's target is specifically the
**skill-layer duplication of `skill_validate_input`'s literal lookup shape**, not every use of
`.active_projects[] | select(.project_number == ...)` in the tree (many of those are legitimate
mutations, existence checks, or single-field extractions that neither helper serves — see next
section).

**Precise re-measured counts** (all commands run from repo root against
`agent-system/extensions/`):

| Scope | Files | Occurrences |
|---|---:|---:|
| Repo-wide, any file, broad pattern (`select(.project_number` present anywhere in the line) | 122 | 412 |
| Executable surfaces only (`scripts/*.sh` + `commands/`,`skills/`,`agents/` `.md`), broad pattern | 96 | 338 |
| Executable surfaces only, **narrow pattern** — filter is *exactly* `.active_projects[] | select(.project_number == $X)` with nothing piped after (the literal shape `skill_validate_input` and `gate_in` both implement) | 63 (62 excluding `skill-base.sh` itself) | 69 |
| `docs/` + `context/` (excluded from scope — illustrative prose) | 26 | — |

The broad-vs-narrow gap matters for lint design: the broad pattern also matches legitimate,
distinct operations that neither helper serves — in-place mutations
(`(.active_projects[] | select(...)) |= . + {...}`, seen in `manage-topics.sh`,
`reconcile-artifacts.sh`, `orchestrator-postflight.sh`), deletions (`del(.active_projects[] |
select(...))`, `task.md`), existence/length checks (`[.active_projects[] | select(...)] |
length`, `update-task-status.sh`, `task.md`), and single-field reads
(`select(...) | .status`, `command-gate-out.sh`, `spawn.md`). A lint written against the broad
pattern would false-positive on all of these. **The lint should target the narrow pattern.**

**The narrow-pattern offender list** (63 files, executable surfaces, excluding
`skill-base.sh`) breaks down as:

- `scripts/`: `command-gate-in.sh` (a legitimate second lookup beyond `gate_in`'s own — needs
  inspection, not automatic migration), `deprecated/archive-task.sh` (dead code — exempt by
  directory), `orchestrate-dry-run-report.sh`, `reconcile-task-status.sh`.
- `commands/`: `core/commands/orchestrate.md`, `spawn.md`, `task.md`,
  `epidemiology/commands/epi.md`, and 9 `founder/commands/*.md` and 5 `present/commands/*.md`
  files. Several of these (`task.md`, `orchestrate.md`, `spawn.md`) source `command-gate-in.sh`
  for the primary lookup already and carry *additional* narrow-pattern hits for genuinely
  different needs (multi-task dependency lookups, recover/sync/expand modes that explicitly
  document not sourcing `command-gate-in.sh`) — these need per-site judgment at migration time,
  not blanket conversion.
- `skills/`: the bulk of the class — every lifecycle `SKILL.md` across core
  (`skill-researcher{,-hard}`, `skill-planner{,-hard}`, `skill-implementer{,-hard}`,
  `skill-reviser`, `skill-spawn`) and across 7 extensions (`cslib`, `epidemiology`, `formal`,
  `founder`, `lean`, `present`, `web`) — 47 `SKILL.md` files total. This is the cleanest migration
  target: these are near-verbatim copies of `skill_validate_input`'s own body (confirmed
  byte-for-byte against `skill-researcher/SKILL.md:47-50`), sourcing `skill-base.sh` already in
  most cases, so the fix is a genuine one-line-for-eight-line swap.

### The existing template: `test-common-lib.sh`'s corrected single-source gate

`agent-system/extensions/core/scripts/tests/test-common-lib.sh` (370 lines) carries a
"single-source assertion" for the session-ID generator (`sess_$(date...)`), fixed under
`errors.json` entry `err_1787022038113_c3VPTR` (severity high, `fix_status: "fixed"`). Its
in-file comment names the exact two defects that made the old version worthless and that the
dispatch explicitly asked this task to avoid:

1. **Environment-dependent root**: the old version resolved its scan root via a fixed
   `../../..` walk from `SCRIPT_DIR`, correct only for the source-store layout, silently landing
   on the whole repo root when run from the deployed `.claude/scripts/tests/` copy.
2. **Wrong file-type scope**: the old version only scanned `*.sh`, structurally blind to the
   46-of-48 duplicates that lived in `.md` executable surfaces.

The fix (verified still present and green — `bash
agent-system/extensions/core/scripts/tests/test-common-lib.sh` passes 30/30 as of this
research): a `collect_session_id_offenders(mode, root)` function with **dual-mode root
resolution** — it probes for `core/manifest.json` one level under the candidate root to decide
source-store vs. deployed mode (reusing `run-all.sh`'s own probe verbatim, not a new heuristic),
then scans `*.sh` whole-tree plus `*.md` scoped *only* to `commands/`, `skills/`, `agents/`
subdirectories under each extension (source-store) or directly under the deploy root (deployed) —
leaving `context/`, `docs/`, `rules/` out of scope **by construction**, never by a growing
exclusion list. It ships three fixture-driven regression tests pinning: deployed-mode `.md`
detection, the prose-exclusion boundary (a planted `context/illustrative.md` offender must NOT be
flagged), and the mode-probe itself.

**This dual-mode-root + commands/skills/agents-only scope is exactly the "source-store-
deterministic root" and "restricted to executable surfaces" requirements from the dispatch.**
Recommendation: copy this scan-root/file-scope logic directly (it is already correct and
tested), rather than re-deriving it.

### Enforcement convention: which existing lint to model the pass/fail policy on

Two conventions coexist in this repo and the dispatch's phrasing ("failing-with-a-known-baseline
or fix-then-enforce, whichever convention the gate fix establishes") asks for a choice between
them:

- **`test-common-lib.sh` convention** — hard zero-tolerance: `pass()`/`fail()` on "any offender
  found at all." Viable because that class was fully migrated to zero before the gate was
  tightened (48 → 0 for the class this fixed version now polices).
- **`lint-state-writer-boundary.sh` convention** — structural detection (a shape classifier that
  exempts read-only checks and non-staging `mv`s by construction) *plus* a short, explicitly-
  reasoned **file-level allowlist** (Layer 2) for sites that legitimately still carry the old
  shape. This is the sibling task 48 (raw `git commit -m` migration) explicitly names as the
  precedent to follow once its own migration lands ("in the same family as
  `lint-state-writer-boundary.sh`, which already polices the analogous state.json write
  boundary").

Given the task-lookup class currently has real, non-zero migration debt (62 sites, not the small
residual `test-common-lib.sh` had when it was tightened), and the dispatch explicitly says
"migration can be incremental... preventing growth matters more than the backlog" — **the
`lint-state-writer-boundary.sh` convention is the right fit**: land the lint green today via an
explicit, reasoned allowlist naming the current offenders (mirroring that file's Layer 2), so it
enforces "no NEW site" immediately without blocking on the 62-file backlog. `deprecated/*.sh`
files are allowlist candidates by directory (already excluded from the live system);
`command-gate-in.sh` and `skill-base.sh` are allowlist candidates by definition (they *are* the
canonical implementations — `skill-base.sh`'s own `skill_validate_input()` body must never be
flagged as if it were a caller).

### External Resources

Not applicable — this is a pure codebase-convention question; no external documentation was
consulted or needed.

## Decisions

- **Target the narrow pattern**, not the broad one. The broad pattern (`select(.project_number`
  anywhere in a line) mixes in mutations, deletions, existence checks, and field-only reads that
  neither `skill_validate_input` nor `gate_in` serves; linting the broad pattern would produce
  false positives against legitimate, distinct jq operations (`manage-topics.sh`,
  `reconcile-artifacts.sh`, `update-task-status.sh`, `command-gate-out.sh`, `spawn.md`).
- **Scope to executable surfaces only**: `scripts/*.sh` (excluding `scripts/tests/*.sh`, which
  build fixture state for concurrency/regeneration tests and legitimately mutate rather than
  look up, and `scripts/deprecated/*.sh`, dead legacy code) plus `.md` files under `commands/`,
  `skills/`, `agents/` per extension — matching `test-common-lib.sh`'s corrected scope exactly.
  `docs/` and `context/` stay out of scope by construction.
- **Land via the `lint-state-writer-boundary.sh` convention** (structural + reasoned allowlist),
  not the `test-common-lib.sh` zero-tolerance convention, because non-zero migration debt exists
  today and the dispatch explicitly permits incremental migration.
- **Self-exempt both canonical implementations by file**: `skill-base.sh` (defines
  `skill_validate_input`) and `command-gate-in.sh` (defines `gate_in`, and legitimately contains
  one instance of the narrow pattern as `gate_in`'s own body).
- **Do not propose migration edits to git-commit call sites** or otherwise cross into task 48's
  territory, per the dispatch's explicit boundary.

## Risks & Mitigations

- **Sequencing collision with task 116.** Task 116 (`researching`, run-alone by its own
  description) is a design task for collapsing `/research`+`/plan`+`/implement` into a
  single-entry-point `/orchestrate`, and its own description explicitly names *this task*
  ("the shared-task-lookup-helper adoption lint") alongside the scoped-commit propagation task as
  work whose "counts change if the collapse lands first," instructing whoever sequences them to
  "say which" direction to run in. Every one of this task's cleanest migration targets
  (`skill-researcher`, `skill-planner`, `skill-implementer`, and their `-hard` twins,
  `skill-orchestrate`) is also a literal deletion/rewrite candidate under task 116's Phase A4/A5
  (hard-mode-as-contract-injection, team-mode folding). **Mitigation**: land the *lint* now (it is
  cheap, additive, and its allowlist can simply be edited if files are deleted or merged later);
  defer the bulk *migration* of the 47 lifecycle-skill sites until task 116's Phase A/B/C either
  lands or is explicitly deprioritized, so migration effort is not spent on files about to be
  deleted. This is consistent with the dispatch's own "prevent NEW occurrences first, migrate the
  backlog incrementally" framing — the lint's value (stopping regrowth) is independent of when the
  backlog shrinks.
- **False positives from the two canonical implementations' own bodies.** Both
  `skill_validate_input()` and `gate_in()` contain the exact narrow pattern being linted for (they
  *are* the pattern, correctly, once). A lint that does not self-exempt these two files by name
  will immediately fail on the very files that must never be touched. Mitigation: explicit
  file-level exemption for both, following `lint-state-writer-boundary.sh`'s pattern of stating
  the reason inline for every allowlist entry.
- **Per-site judgment required, not blanket rewrite.** Several `commands/*.md` narrow-pattern
  hits (`task.md`, `orchestrate.md`, `spawn.md`) are *not* simply un-migrated duplicates of
  `gate_in` — they are additional, distinct lookups for multi-task/recover/sync/expand code paths
  that intentionally do not source `command-gate-in.sh`. A migration pass that mechanically
  converts every narrow-pattern hit to a `skill_validate_input`/`gate_in` call without reading
  context would be wrong for these. Mitigation: the allowlist for the initial lint landing should
  simply list every current offender (permissive, not judgmental); the migration task (separate
  from this one) is where per-site disposition gets decided and recorded, mirroring how task 48's
  own acceptance bar requires stating a reason for every site *not* migrated rather than silently
  skipping it.

## Context Extension Recommendations

- **Topic**: Adoption-lint conventions.
- **Gap**: The repo has now accumulated three adoption-style lints
  (`lint-state-writer-boundary.sh`, the `test-common-lib.sh` single-source assertion, and — after
  this task's implementation phase — a task-lookup lint) plus a fourth pending one for
  `git-commit-scoped.sh` (task 48), but no single context file states the two competing
  conventions (zero-tolerance-after-cleanup vs. structural-plus-reasoned-allowlist) and when to
  pick each. This report had to re-derive the distinction from reading three separate files.
- **Recommendation**: a short `context/patterns/adoption-lint-conventions.md` naming both
  conventions, the precedent file for each, and the decision rule ("non-zero migration debt at
  landing time → allowlist convention; class already fully migrated → zero-tolerance convention")
  would save the next adoption-lint task (there is likely to be at least one more, per the
  review's Group C) from re-deriving this.

## Appendix

### Search queries / commands used

```bash
grep -rn "skill_validate_input" agent-system/ .claude/
grep -rlE 'active_projects\[\][[:space:]]*\|[[:space:]]*select\(\.project_number' agent-system/extensions/
grep -rlE "active_projects\[\][[:space:]]*\|[[:space:]]*select\(\.project_number *== *[^)]*\)[[:space:]]*['\"]" agent-system/extensions/*/scripts --include=*.sh
bash agent-system/extensions/core/scripts/tests/test-common-lib.sh   # confirmed 30/30 pass, template still green
```

### References

- `agent-system/extensions/core/scripts/skill-base.sh:185` — `skill_validate_input()`
- `agent-system/extensions/core/scripts/command-gate-in.sh` — `gate_in()`, its real adopters
- `agent-system/extensions/core/scripts/tests/test-common-lib.sh:230-370` — corrected single-
  source gate template (dual-mode root, commands/skills/agents-only `.md` scope)
- `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` — structural +
  reasoned-allowlist convention to model enforcement on
- `agent-system/extensions/core/scripts/verify-deploy.sh:565-608` — gates 11/12 wiring pattern
  (`REPO_ROOT="$TARGET" bash .../lint/lint-X.sh --verbose`) for the new gate 17
- `specs/reviews/review-2026-08-24-refactor-survey.md` — H3 (duplication classes), H4 (the
  corrected gate), Group C recommendation #9 (this task's origin)
- `specs/errors.json` entry `err_1787022038113_c3VPTR` — the fixed defect `test-common-lib.sh`
  now guards against
- `specs/state.json` project_number 116 — sequencing dependency (design collapse touching the
  same files); project_number 48 — sibling adoption-lint task, cross-referenced for convention
  precedent only, no edits proposed to its territory

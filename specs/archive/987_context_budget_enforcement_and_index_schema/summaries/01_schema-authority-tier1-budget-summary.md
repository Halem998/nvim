# Implementation Summary: Task #987

- **Task**: 987 - Context budget enforcement: demote always-load bloat, break the meta catch-all, one index schema
- **Status**: [COMPLETED]
- **Started**: 2026-07-30T01:35:56Z
- **Completed**: 2026-07-30T02:01:34Z
- **Effort**: ~2.5 hours
- **Dependencies**: 978 (COMPLETED)
- **Artifacts**: plans/01_schema-authority-tier1-budget.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

All six plan phases completed. `index.schema.json` is now the single reconciled schema authority
(`task_types` allowed, `languages` removed, exclusion rationale recorded in prose); advisory Rules
T (schema conformance) and U (EXTENSION.md length) were added to `check-extension-docs.sh` behind
a new `SCHEMA_CONFORMANCE_GATE_MODE` (default `advisory`) with a fixture test proving both fire;
the two competing prose examples (`extension-slim-standard.md`, `agent-system/extensions/README.md`)
were corrected to match the schema; Tier-1 always-load dropped from 996 to 334 lines (target
<=500) by demoting three entries off `always: true` and giving each a real hook, without
duplicating or losing `project-overview.md`'s single remaining load path; and four follow-on
tasks (990-993) were created carrying the deferred bulk migration work.

## What Changed

- `agent-system/extensions/core/context/index.schema.json` — added `task_types` to
  `load_when.properties`, removed `languages`, added a `$comment` recording why `description`/
  `tags`/`tier` are deliberately absent and a `description` on `load_when` naming the closed key
  set.
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — added
  `SCHEMA_CONFORMANCE_GATE_MODE` (sibling to `INDEX_TRUTH_GATE_MODE`, default `advisory`),
  `schema_conformance_report()`, `check_index_entries_schema()` (Rule T), `check_extension_md_length()`
  (Rule U), registered both in the per-extension loop, updated the header checks list and Rule
  letter index.
- `agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh` — new fixture test:
  5 Rule T positive cases + 1 negative, Rule U 61L/60L positive/negative, plus a
  `SCHEMA_CONFORMANCE_GATE_MODE=hard` severity-wiring assertion. 9/9 assertions pass.
- `agent-system/extensions/core/manifest.json` — declared the new test script in
  `provides.scripts`.
- `agent-system/extensions/core/docs/reference/standards/extension-slim-standard.md` — corrected
  the Index Integration example to the reconciled shape (`summary`/`domain`/`subdomain`/
  `task_types`, canonical `project/{ext}/...` path), added an authority pointer to
  `index.schema.json`, replaced the stale "~1,111 lines across 14 extensions" figure with a
  pointer to the lint output.
- `agent-system/extensions/README.md` — corrected the "Correct example" to the reconciled shape,
  added an authority pointer.
- `agent-system/extensions/core/index-entries.json` — three entries lost `always: true` and
  gained real hooks: `patterns/context-discovery.md` (`agents: [meta-builder-agent]`,
  `commands: [/meta]`), `patterns/jq-escaping-workarounds.md` (`agents:
  [meta-builder-agent, general-implementation-agent, general-implementation-hard-agent]`,
  `commands: [/errors, /meta]`), `repo/project-overview.md` (`commands: [/project-overview]`).
  Also corrected `index.schema.json`'s own `line_count` entry (127 -> 128) after Phase 1's edit
  changed its actual line count, to avoid introducing a fresh Rule R drift as a side effect.
- `specs/state.json`, `specs/TODO.md` — four follow-on tasks created (990
  `index_entries_schema_migration`, 991 `meta_catchall_decomposition`, 992
  `extension_md_slim_down`, 993 `promote_schema_gates_to_hard`, with 993 depending on
  `[987, 990, 992]`), via the mutex-guarded `state-write.sh --regen-todo`.
- `specs/987_context_budget_enforcement_and_index_schema/plans/01_schema-authority-tier1-budget.md`
  — all six phases marked `[COMPLETED]`, all checklist items checked off with completion notes,
  Scope Hypothesis reconciliation recorded, plan-level Status set to `[COMPLETED]`.

## Decisions

- Introduced a sibling `SCHEMA_CONFORMANCE_GATE_MODE` rather than reusing `INDEX_TRUTH_GATE_MODE`
  (per the plan's own correction to the research: the latter already defaults `hard` and Rules
  R/S depend on that).
- Corrected `extension-slim-standard.md`'s example path prefix from `context/project/{ext}/...`
  to the canonical `project/{ext}/...` form (matching `extensions/README.md`'s own canonical-path
  rule), beyond what the plan's task list literally spelled out, since leaving it uncorrected
  would have left a second, silent inconsistency in the same edit.
- Fixed `index.schema.json`'s own `line_count` entry (127->128) in `core/index-entries.json` as a
  direct, minimal side effect of Phase 1's schema edit, rather than leaving a self-inflicted
  fresh Rule R drift for a future run to discover.
- The fixture test's `check-extension-docs.sh` resolution deliberately inverts the deploy-first
  pattern other tests in this directory use, preferring the source-store sibling copy — see the
  Phase 4 "Implementation note" in the plan for the empirical reason (deploy-first silently
  tested a stale pre-Phase-2 script and produced 6 false negatives).

## Plan Deviations

- None (implementation followed plan; two items were treated as reasoned scope expansions
  within the plan's own "file_scope is advisory" allowance — the path-prefix correction and the
  index.schema.json line_count fix — both recorded above under Decisions, not as departures from
  the plan's intent).

## Verification

- Build: N/A (bash/JSON project)
- Tests: Passed — `test-index-entries-schema.sh` 9/9 assertions; `verify-deploy.sh` 15/15 checks;
  `check-task-references.sh` 0 findings; `validate-context-budgets.sh` Tier-1 OK (334L/3 entries).
- Files verified: Yes (`jq empty` on all touched JSON; `bash -n` on both touched/created scripts).

### Scope Hypothesis Reconciliation (Phase 2)

Rule U fired for exactly the 7 predicted extensions (core, cslib, email, lean, literature, nix,
present) — prediction confirmed. Rule T fired for 17 of 19 extensions (all except epidemiology
and slidev), not the predicted 14. Root cause: the plan's 14-count only tallied
`load_when.languages`-driven violations; it did not separately enumerate the `load_when.skills`
violation, which independently flags 3 more extensions with no `languages` usage at all (core: 9
entries, literature: 6, memory: 8). 14 + 3 = 17, confirmed correct by direct predicate
verification, not a bug. This has been carried into the `index_entries_schema_migration`
follow-on task's description so its scope is accurate.

## Impacts

- Doc-lint (`check-extension-docs.sh`) now has a durable, source-level signal for schema drift
  and EXTENSION.md bloat, currently advisory so it does not break any existing caller.
- Tier-1 always-load is now within budget; `meta-builder-agent` and other agents no longer load
  `context-discovery.md`/`jq-escaping-workarounds.md` on every single prompt, only when actually
  relevant (via the new `agents`/`commands` hooks).
- Four new tasks (990-993) exist in the tracker carrying the deferred bulk migration, meta
  catch-all decomposition, EXTENSION.md trims, and eventual hard-gate promotion.

## Follow-ups

- Follow-on task 990 (`index_entries_schema_migration`): migrate all 19 extensions'
  `index-entries.json` to the reconciled shape (fold `description` into `summary`, rename
  `tags`->`keywords`, `languages`->`task_types`, delete `skills` arrays). True scope is 17 of 19
  extensions (see Scope Hypothesis Reconciliation above), not 14.
- Follow-on task 991 (`meta_catchall_decomposition`): give the ~24 hookless
  `task_types:["meta"]`-only entries real hooks, trim the wider 123-entry set, derive `tier`
  algorithmically, fix 2 non-existent `load_when.agents` values.
- Follow-on task 992 (`extension_md_slim_down`): trim the 7 EXTENSION.md violators per the slim
  standard's migration template.
- Follow-on task 993 (`promote_schema_gates_to_hard`): flip `SCHEMA_CONFORMANCE_GATE_MODE` to
  `hard` once 990 and 992 land clean. Depends on both.
- Out-of-scope risks recorded (per the plan's Non-Goals), not addressed by this task:
  `install-extension.sh`'s stale index-merge jq logic (a separate deploy mechanism not exercised
  by the live Lua loader), and the pre-existing `nvim` directory vs `neovim` task_type string
  mismatch (belongs with routing-consolidation work).
- Transient doc-lint FAIL noise was observed mid-implementation from OTHER concurrently-running
  sibling implementation sessions in this same batch committing to shared files
  (`scripts/vault-operation.sh`, `context/patterns/jq-escaping-workarounds.md`,
  `context/patterns/task-lock.md`) — none attributable to this task's changes, confirmed by
  content diff against each commit's own git history, and resolved by the time of the final
  `verify-deploy.sh` run (15/15 PASS).

## References

- `specs/987_context_budget_enforcement_and_index_schema/plans/01_schema-authority-tier1-budget.md`
- `specs/987_context_budget_enforcement_and_index_schema/reports/01_context-budget-schema-reconciliation.md`

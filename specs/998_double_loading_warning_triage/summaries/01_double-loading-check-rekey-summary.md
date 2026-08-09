# Implementation Summary: Task #998

- **Task**: 998 - Triage the 49 Double-Loading context-index warnings
- **Status**: [COMPLETED]
- **Started**: 2026-08-09T00:00:00Z
- **Completed**: 2026-08-09T02:45:00Z
- **Effort**: ~3 hours
- **Dependencies**: 991 (satisfied)
- **Artifacts**: plans/01_double-loading-check-rekey.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Re-keyed the Double-Loading Check in `validate-context-budgets.sh` from a shape-only predicate
("both `agents[]` and `commands[]` hooks present") to a mechanically derived three-bucket
redundancy predicate (redundant / legitimate-dual / unclassifiable-command), narrowed the 36 core
index entries the predicate identifies as redundant, promoted the redundant bucket from a
WARNING to an exit-code-contributing VIOLATION, and committed a five-case regression test that
proves the check still fires and can be shown to fail under an inverted predicate.

## What Changed

- `agent-system/extensions/core/scripts/validate-context-budgets.sh` — replaced the
  `--- Double-Loading Check ---` section with the mechanical three-bucket predicate: live route
  derivation from `manifest.json`'s `routing_agents` block (`/research`, `/plan`, `/implement`)
  and the sole `subagent_type:` line in `skill-meta`/`skill-spawn`/`skill-reviser`'s `SKILL.md`
  (`/meta`, `/spawn`, `/revise`); a literal direct-command roster; a loud
  `[DEGRADED ROUTE DERIVATION]` precondition guard; env-var route overrides for test stubbing
  (`VALIDATE_BUDGETS_MANIFEST_OVERRIDE` and three matching skill-file overrides); and the
  redundant bucket promoted to `VIOLATIONS`.
- `agent-system/extensions/core/index-entries.json` — `load_when.commands` cleared to `[]` on
  exactly the 36 entries the predicate classifies redundant (dual-hook count: 47 → 11).
- `agent-system/extensions/core/scripts/tests/test-double-loading-check.sh` — new five-case
  regression test (positive, discrimination, orchestrate, unclassifiable, degraded-derivation)
  plus an inversion self-check proving the positive/discrimination assertions are live.
- `agent-system/extensions/core/manifest.json` — declared the new test under `provides.scripts`.
- `agent-system/extensions/core/context/patterns/context-discovery.md` — new "Hook-Shape Policy"
  section documenting when an entry should carry `agents[]` only, `commands[]` only, or both, and
  pointing to the check as the enforcement mechanism.
- `agent-system/extensions/core/context/index.schema.json` — extended the `commands` property
  description with the redundancy rule and a pointer to the policy section.
- `agent-system/extensions/core/context/guides/extension-development.md` — added a policy
  pointer at the "Create `index-entries.json`" quick-checklist step.

## Decisions

- Deliberately added a third, explicitly named `unclassifiable-command` bucket (informational,
  never exit-code-affecting) for commands outside the six mechanically-routable commands and the
  direct-command roster — mostly extension commands (e.g. `/grant`, `/epi`, `/deck`) whose
  command-name-to-agent route is not derivable from any manifest today. This corrects the
  research report's own predicate, which would have silently folded these into "legitimate".
- A degraded route source is represented in the route table by OMITTING the key entirely, never
  by an empty array — an empty array would make the redundancy subset test (`[] - $agents ==
  []`) vacuously true, silently misclassifying an unroutable command as redundant instead of
  routing it to unclassifiable. This was caught by the Phase 5 degraded-derivation test case
  during authoring, not assumed correct in advance.
- `VIOLATIONS` is incremented by 1 for a redundant finding (not by the redundant count), matching
  the existing convention every other check in the script already uses (Dead Entry Check, Tier
  Classification Check, etc.).

## Plan Deviations

- None (implementation followed plan). Two bugs were found and fixed during Phase 5 authoring
  (see Decisions above and the Phase 2 progress-file addendum) — these are refinements within
  Phase 2's already-committed scope, not deviations from the plan's stated approach.

## Verification

- Build: N/A (shell scripts)
- Tests: Passed — `test-double-loading-check.sh` 16/16 assertions, run both from the source-store
  location and the deployed `.claude/scripts/tests/` location; inversion self-check confirms the
  positive and discrimination assertions are live (they flip under a deliberately inverted
  predicate).
- Files verified: Yes

**Final verification bar** (deployed `.claude/scripts/validate-context-budgets.sh`):
```
--- Double-Loading Check ---
Entries with both agents and commands hooks: 13
Redundant (commands[] fully subsumed by agents[]): 0 -- OK
Legitimately dual-addressed (informational, not a violation): 13
Unclassifiable-command (informational; route not mechanically derivable, e.g. extension commands): 0
```
0 redundant, 13 legitimate (path-for-path identical to the Phase 1-derived legitimate-dual set),
0 unclassifiable. No `[DEGRADED ROUTE DERIVATION]` banner under normal operation.

**Cross-extension blast-radius measurement** (Phase 4): every extension's dual-hook entries
outside `core` land entirely in `unclassifiable-command` — 0 redundant anywhere else (`present`
36, `founder` 25, `epidemiology` 15, `slidev` 15, `filetypes` 10, all fully unclassifiable;
`memory` 2 and `literature` 6, currently loaded, fully legitimate). Promoting the redundant
bucket to a violation is confirmed safe for repos with a different extension set loaded.

**Adjacent validators**: `validate-index.sh`, `validate-context-index.sh`,
`validate-extension-index.sh`, `check-extension-docs.sh` all PASS. `validate-wiring.sh --claude`
passes (0 failures, 1 pre-existing warning); its 41 `--all`-scope failures are isolated entirely
to the unrelated `.opencode` tree (pre-existing "Missing context file" drift, confirmed
independent of this task by running `--claude` and `--opencode` in isolation).

**Full-run regression check**: section-by-section diff between the Phase 1 baseline capture and
the post-deploy `--verbose` capture is byte-identical for every section except Double-Loading
Check (Agent Budget Check, Tier 1 Check, Tier Classification Check, Dead Entry Check all
unchanged). `check-task-references.sh`, `lint-agent-contracts.sh` (33/33),
`lint-routing-wiring.sh` (323/323) all PASS.

## Impacts

- The Double-Loading Check now enforces a real invariant (no entry carries a redundant
  `commands[]` duplicate of its own `agents[]` reach) rather than reporting an inert, permanently
  non-zero warning count that nobody could act on without per-entry judgement calls.
- Future index-entry authors have a documented policy (context-discovery.md's Hook-Shape Policy
  section, cross-referenced from index.schema.json and extension-development.md) explaining when
  `agents[]`, `commands[]`, or both is the correct shape.
- The check's own coverage boundary (extension commands not mechanically routable today) is now
  visible in its own output via the named `unclassifiable-command` bucket, rather than silently
  absorbed into "legitimate" the way the research report's original predicate would have done.

## Follow-ups

- None required by this task. The `unclassifiable-command` bucket is deliberately left
  informational (not promoted to a violation) because no manifest today maps an extension
  command name to an agent; promoting it would require adding that mapping mechanism first, which
  is explicitly out of scope (see the plan's Non-Goals).
- Wiring `validate-context-budgets.sh` into `verify-deploy.sh` remains an unscheduled follow-up,
  as noted in the plan's Non-Goals (inherited from the research report).

## References

- Plan: `specs/998_double_loading_warning_triage/plans/01_double-loading-check-rekey.md`
- Research report: `specs/998_double_loading_warning_triage/reports/01_double_loading_warning_triage.md`
- Progress files: `specs/998_double_loading_warning_triage/progress/phase-{1..6}-progress.json`

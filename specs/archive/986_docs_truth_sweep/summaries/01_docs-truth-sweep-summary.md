# Implementation Summary: Task #986

- **Task**: 986 - Docs truth sweep: retire dispatch-agent fiction, dead-script refs, doc consolidation
- **Status**: [COMPLETED]
- **Started**: 2026-08-09
- **Completed**: 2026-08-09
- **Effort**: ~6.5 hours (matches plan estimate)
- **Dependencies**: 951, 960, 961, 962, 963, 969, 980, 982, 983, 984, 985, 987, 989, 992 (all landed)
- **Artifacts**: plans/01_docs-truth-sweep.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

All 5 phases of the plan are complete. The documentation layer no longer describes the
nonexistent `dispatch-agent.sh` mechanism or references 11 nonexistent scripts, three overlapping
orchestration validation docs are consolidated into one, `docs/README.md` is folded into
`docs-README.md`, and `merge-sources/claudemd.md` shrank by 273 lines (645 -> 372) with the
relocated content (including the `--lit` section) landing in durable homes, including a new
literature-owned merge source. All edits are confined to `agent-system/extensions/**` plus one
new `specs/decisions/` record, per the binding source-store and no-task-references rules.

## What Changed

- `agent-system/extensions/core/docs/architecture/architecture-spec.md` — deleted (599 lines of
  dispatch-agent fiction)
- `agent-system/extensions/core/docs/architecture/system-overview.md` — removed dispatch-agent
  claim
- `agent-system/extensions/core/docs/architecture/handoff-schema.md`,
  `orchestrate-state-machine.md`, `docs/templates/README.md`,
  `docs/guides/creating-agents.md`, `docs/fork-patterns.md` — repaired inbound links / dropped
  spec citations / reworded obsolete-mechanism note
- `agent-system/extensions/core/docs/guides/context-loading-best-practices.md`,
  `context/patterns/jq-escaping-workarounds.md`, `context/orchestration/sessions.md`,
  `context/standards/postflight-tool-restrictions.md`,
  `context/standards/shell-script-testing.md` — purged 17 dead-script references across 11
  script names
- `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` — trimmed 52
  narrative lines to a pointer, kept the Exemption Taxonomy table
- `specs/decisions/no-task-references-enforcement-history.md` — new decision record holding the
  extracted narrative (task numbers permitted here)
- `agent-system/extensions/core/docs/templates/agent-template.md` — frontmatter re-synced to the
  canonical template and the frontmatter standard
- `agent-system/extensions/core/root-files/settings.local.json` — dropped a stale one-time `mv`
  permission entry
- `agent-system/extensions/core/context/orchestration/validation.md` — became the single
  consolidated validation doc (698+313+233 -> merged); `subagent-validation.md` and
  `orchestration-validation.md` deleted
- `agent-system/extensions/core/context/orchestration/orchestration-core.md`, `delegation.md`,
  `orchestration-reference.md`, `context/architecture/system-overview.md` — repaired references
  to the consolidated doc
- `agent-system/extensions/core/docs/docs-README.md` — absorbed unique content from
  `docs/README.md` (now deleted); refreshed as the single directory map
- `agent-system/extensions/core/README.md`, `merge-sources/claudemd.md` — updated docs-README
  pointers
- `agent-system/extensions/core/context/patterns/context-discovery.md` — fixed the broken jq
  recipe (`--arg lang` / `$task_type` mismatch)
- `agent-system/extensions/literature/merge-sources/claudemd.md` — new file: superset of the
  former `EXTENSION.md` body plus the 162-line `--lit` section
- `agent-system/extensions/literature/manifest.json` — repointed
  `merge_targets.claudemd.source` to `merge-sources/claudemd.md`
- `agent-system/extensions/literature/EXTENSION.md` — deleted (no longer a declared merge source)
- `agent-system/extensions/core/merge-sources/claudemd.md` — removed 5 sections (--lit, State
  Synchronization, Context Discovery, Context Architecture, Multi-Task Creation Standards),
  replaced each with a durable-home pointer (645 -> 372 lines)
- `agent-system/extensions/core/context/architecture/context-layers.md` — extended with content
  moved from `claudemd.md`
- `agent-system/extensions/core/index-entries.json` — line_count reconciliation and entry updates
  across all four indexed phases
- `agent-system/extensions/core/manifest.json` — removed stale `provides.docs` declaration of the
  deleted `docs/README.md` (found and fixed during Phase 5 verification)

## Decisions

- Preserved the two-tier agent template split (`docs/templates/` tutorial vs.
  `context/templates/` canonical) rather than merging, per research's finding that this is
  deliberate.
- Kept the Exemption Taxonomy table in the no-task-references rule file — it is enforcement
  content, not narrative, correcting the task description's ~90-line estimate.
- Left `context/validation.md` (46L) untouched — a distinct, `on_demand`-only skill-contract
  concern, not part of the three-doc consolidation.
- Deleted (rather than trimmed) `literature/EXTENSION.md` once repointed, following the
  documented precedent from `core/EXTENSION.md` and `slidev/EXTENSION.md`.

## Plan Deviations

- Phase 5's `verify-deploy.sh` run shows 21/22 gates passing rather than 22/22. The one failure
  (gate 8, the shell test suite runner) traces to `test-index-entries-schema.sh`'s "Rule U did
  not fire on a 61-line EXTENSION.md" fixture assertion. Independently re-confirmed as
  pre-existing and unrelated to this diff: neither that test file nor
  `check-extension-docs.sh`'s Rule U logic was touched by any phase of this task (both were last
  modified by unrelated prior tasks — task 988 and task 992/993 respectively), and the test
  exercises a synthetic fixture extension, not any real content this task edited.
- The Testing & Validation item "Regenerated CLAUDE.md contains the `--lit` section exactly once,
  inside the literature section" was verified by a byte-exact superset diff of the new merge
  source plus a direct read of `merge.lua`'s `generate_claudemd()` resolution logic, rather than
  by a literal regenerated-CLAUDE.md read, because the literature extension is not active in this
  particular repo's current deploy configuration.

## Verification

- Build: N/A (documentation-only task)
- Tests: `check-extension-docs.sh` exits 0 (zero Rule R/T/U findings, independently re-run);
  `generate-context-line-counts.sh --check` reports 478/478 exact matches (independently
  re-run); `verify-deploy.sh` 21/22 gates pass (independently re-run), with the sole failure
  confirmed pre-existing and unrelated (see Plan Deviations)
- Files verified: Yes — dangling-reference grep sweep over `agent-system/extensions/` for
  `dispatch-agent`, `dispatch-agent-spec`, all 11 dead script names, the two deleted validation
  docs, `docs/README.md`, and `literature/EXTENSION.md` returns zero unmarked hits; every
  `index-entries.json` entry across every extension resolves to a file on disk

## Impacts

- `meta-builder-agent` no longer double-loads 931 overlapping validation lines.
- Every reader of `docs/architecture/` and related guides now sees only real, current
  architecture — no dispatch-agent fiction, no dangling script citations.
- `merge-sources/claudemd.md` is 273 lines lighter; the `--lit` documentation now merges into a
  deployed repo's CLAUDE.md only where the literature extension is actually loaded.
- The always-loaded `context-discovery.md` jq recipe is now copy-pasteable without error.

## Follow-ups

- None. The pre-existing `test-index-entries-schema.sh` fixture failure is out of this task's
  scope (untouched by any phase here) and may warrant a separate fix task if not already tracked.

## References

- `specs/986_docs_truth_sweep/plans/01_docs-truth-sweep.md`
- `specs/986_docs_truth_sweep/reports/01_docs-truth-sweep-findings.md`
- `specs/decisions/no-task-references-enforcement-history.md`

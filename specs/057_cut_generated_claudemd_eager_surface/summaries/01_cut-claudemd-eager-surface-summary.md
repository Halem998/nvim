# Implementation Summary: Task #57

- **Task**: 57 - Cut the generated .claude/CLAUDE.md eager surface without losing capability, refactoring capabilities to remove redundancy where a workflow can be preserved rather than merely trimmed.
- **Status**: [COMPLETED]
- **Started**: 2026-08-12T18:56:21Z
- **Completed**: 2026-08-12T19:45:00Z
- **Effort**: ~1.5 hours (implementation)
- **Dependencies**: None
- **Artifacts**: plans/01_cut-claudemd-eager-surface.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

All 7 plan phases landed. The four adopted levers (A, B, D1, D2) were implemented, measured, and
deployed sequentially, plus a regression-prevention byte ceiling (Lever C). Every change is
labeled HARD or SOFT per the plan's Saving Classification table; every byte figure below is
measured (`wc -c` + a purpose-built harness script), not estimated. `.claude/**` was never
hand-edited — every change landed in `agent-system/extensions/**` and was propagated via
`bash .claude/scripts/deploy-headless.sh`.

## Acceptance Table: Measured Before/After Bytes

All figures from `agent-system/extensions/core/scripts/measure-eager-surface.sh`'s
`--baseline`/`--compare` harness (Phase 1), run after each phase's `deploy-headless.sh`. The
eager-prefix composition (9 files) is identical before and after — apples to apples.

| File | Before (B) | After (B) | Delta (B) | Class | Phase |
|---|---|---|---|---|---|
| `agent-system/extensions/literature/merge-sources/claudemd.md` | 8,673 | 4,908 | -3,765 | HARD | 2 |
| `agent-system/extensions/core/merge-sources/claudemd.md` | 24,770 | 18,952 | -5,818 | HARD (Phase 3: -1,349; Phase 4: -2,669; Phase 5: -1,800) | 3, 4, 5 |
| `agent-system/extensions/core/context/guides/hard-mode-routing.md` | 7,226 | 7,498 | +272 | HARD (consolidation; canonical home absorbs content CLAUDE.md dropped) | 3 |
| `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` (new) | 0 | 3,382 | +3,382 | SOFT (relocated off eager path, unabridged) | 4 |
| `agent-system/extensions/core/docs/docs-README.md` | 6,388 | 6,507 | +119 | SOFT (index pointer added) | 4 |
| `agent-system/extensions/core/context/config/claudemd-size-budget.json` (new) | 0 | 1,359 | +1,359 | none (regression-prevention config, not eager) | 6 |
| `agent-system/extensions/core/scripts/check-extension-docs.sh` | 70,106 | 72,823 | +2,717 | none (lint script, not eager) | 6 |
| `agent-system/extensions/core/docs/reference/standards/extension-slim-standard.md` | 7,148 | 9,385 | +2,237 | none (standard doc, not eager; also fixes advisory/hard drift) | 6 |
| `agent-system/extensions/core/scripts/measure-eager-surface.sh` (new) | 0 | 9,683 | +9,683 | none (measurement harness itself, not eager) | 1 |
| **`.claude/CLAUDE.md` (assembled, eager)** | **42,798** | **33,215** | **-9,583** | — | all |
| **Eager prefix (9-file total)** | **70,160** | **60,577** | **-9,583** | — | all |

Rows below the double line are not part of the eager-injected surface (docs/, context/guides/,
context/config/, scripts/) — they are reported because the plan requires "no file touched in
phases 1-6 is missing a before/after row," not because they count against the eager-prefix
target. Only `.claude/CLAUDE.md` and its two shape-(a) merge-source inputs (`core`, `literature`)
are eager.

## What Changed

- `agent-system/extensions/core/scripts/measure-eager-surface.sh` — Created. Reproduces the
  70,160 B eager-prefix accounting; `--baseline`/`--compare` modes for repeatable before/after
  measurement. Declared in `core/manifest.json` `provides.scripts`.
- `agent-system/extensions/literature/merge-sources/claudemd.md` — Deleted four mechanically-
  redundant `--lit` subsections ("What `--lit` Does", "Ad-Hoc / Conversational Literature
  Requests", "Interactive Sub-Index Setup Detection", "orchestrator_mode Dual-Consumer / Autonomy
  Contract"); replaced with two short pointer paragraphs naming `lit-stage4a-flow.md` (the
  executable Stage 4a contract) and `adhoc-navigation-directive.md` (the ad-hoc-request contract,
  which has no counterpart in `lit-stage4a-flow.md` — kept per the plan's own contingency clause).
- `agent-system/extensions/core/merge-sources/claudemd.md` — Three edits across three phases:
  (3) deleted the restated 5-step `--hard` routing ladder from "Routing Mechanism", preserving
  the trailing cross-reference sentence verbatim; (4) replaced "Utility Scripts" body with a
  pointer to the new inventory doc; (5) reduced the Skill-to-Agent Mapping table to Skill/Agent
  columns only and deleted the `### Agents` subtable, adding one sentence pointing to the
  harness's native Skill/Agent listings.
- `agent-system/extensions/core/context/guides/hard-mode-routing.md` — Updated the Scope note:
  this document is now the sole canonical home for the `--hard` routing-precedence rules; dropped
  the "Do NOT edit CLAUDE.md based on this document" sentence, which is now stale since CLAUDE.md
  intentionally carries only a pointer to this document.
- `agent-system/extensions/core/index-entries.json` — Corrected a `line_count` drift for
  `guides/hard-mode-routing.md` (169 -> 171) caused by the Scope-note edit above.
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — Created. All 12
  utility-script entries relocated here, unabridged.
- `agent-system/extensions/core/docs/docs-README.md` — Indexed the new inventory doc in the
  Documentation Map.
- `agent-system/extensions/core/context/config/claudemd-size-budget.json` — Created. Per-extension
  byte ceiling for shape-(a) claudemd merge sources: `core` 19,950 B, `literature` 5,250 B,
  default 8,000 B for any future shape-(a) extension. Each named ceiling = measured post-cut size
  rounded up to the next 500 B, plus ~5% headroom.
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — Added Rule V
  (`check_claudemd_size_budget`): flags any shape-(a) claudemd merge source exceeding its
  configured ceiling, severity wired to the existing `SCHEMA_CONFORMANCE_GATE_MODE`.
- `agent-system/extensions/core/docs/reference/standards/extension-slim-standard.md` — Extended
  scope to cover shape-(a) sources (new "Shape-(a) Merge Sources" section); fixed the confirmed
  doc/code drift (doc said `advisory` default, script's actual default is `hard`); recorded that
  the ceiling deliberately lives in an external config rather than a `manifest.json` field
  because manifest-schema work is in flight.
- `agent-system/extensions/core/manifest.json` — Declared `measure-eager-surface.sh` in
  `provides.scripts`; declared `config` in `provides.context` for discoverability.

## Decisions

- Kept a second pointer paragraph for literature's "Ad-Hoc / Conversational Literature Requests"
  directive rather than dropping it, because `lit-stage4a-flow.md` does not cover that
  out-of-dispatch workflow — verified by reading the file before deleting, per the plan's own
  Phase 2 mandate. This reduced the measured saving from the plan's ~4,300 B estimate to the
  actual -3,765 B.
- Skipped the plan's literal instruction to "add an entry to `core/index-entries.json`" for the
  new inventory doc: `index.schema.json` and Rule S/T are scoped exclusively to files under
  `context/`, never `docs/`. Confirmed by grep — no existing `docs/reference/standards/*.md` file
  has an index-entries.json entry. Added the doc to `docs-README.md` instead, satisfying the
  plan's own "or the equivalent docs index" alternative.
- Derived shape-(a) byte ceilings using the plan's exact formula (round up to next 500 B, +5%)
  from each extension's own Phase-5-final measured value, with the derivation recorded in the
  config's own comment fields for future re-derivation.

## Plan Deviations

- **Task 2.2** altered: inserted two short pointer paragraphs instead of one, to retain the
  Ad-Hoc/Conversational directive with no counterpart in `lit-stage4a-flow.md`. See Decisions.
- **Task 4.3** altered: skipped the `index-entries.json` addition for the new inventory doc
  (out of scope for the `docs/` tree per the schema's own field description); indexed via
  `docs-README.md` instead, per the task's own "or equivalent docs index" clause.

No other deviations. All other tasks in all 7 phases were completed as specified.

## Verification

- Build: N/A (documentation/config-only project)
- Tests: `bash .claude/scripts/check-task-references.sh --quiet` — PASS (0 unexempted
  occurrences). `bash -n` on both new/modified scripts — PASS. `jq empty` on both new/modified
  JSON files and every touched `manifest.json` — PASS.
- Files verified: Yes — every file in the acceptance table confirmed present at its final size
  after the last `deploy-headless.sh` run; all four capability-consolidation pointer paths
  confirmed present in the deployed `.claude/CLAUDE.md` and their targets confirmed present on
  disk (see Impacts).
- `bash .claude/scripts/check-extension-docs.sh --quiet`: **1 FAIL**, pre-existing and unrelated
  to this task — `Rule S: deployed context/contracts/return-meta-artifacts-template.md has no
  entry in .claude/context/index.json`. That contract file was introduced by a prior, unrelated
  task and was never indexed; this task's edits do not touch it. Confirmed present before any
  Phase 2 edit and unchanged in cause/scope through Phase 6.
- `bash .claude/scripts/verify-deploy.sh`: **2 of 23 checks FAIL**, both pre-existing and
  unrelated — (a) the same Rule S doc-lint finding above, and (b) `validate-state.sh --deep`
  flagging unknown fields (`blockers`, `parent_task`, `priority`, `subtasks`) on task entries
  49, 52-56 in `specs/state.json`. This task never writes to `specs/state.json`; those entries
  and fields pre-date this task's dispatch (visible as `M specs/state.json` in git status before
  any Phase 1 work began, from other concurrently active sessions). All 21 other checks PASS,
  including the doc-lint's per-extension breakdown, routing/contract/agent lints, the full shell
  test suite, and manifest-driven parity.
- Deliberate-violation test (Phase 6): lowering `core`'s ceiling to 100 B produced
  `Rule V: shape-(a) claudemd merge source 'merge-sources/claudemd.md' is 18952 B, exceeding its
  configured ceiling of 100 B`; restoring it to 19,950 B cleared the finding. Confirmed the rule
  actually fires, not merely wired.

## Capability Consolidations (Confirmed Reachable in the Deployed Tree)

1. **`--lit` Stage 4a mechanics**: `.claude/CLAUDE.md` now carries two short pointer paragraphs
   naming `context/patterns/lit-stage4a-flow.md` (the executable Stage 4a contract all six
   `--lit`-capable skills import directly) and
   `context/project/literature/patterns/adhoc-navigation-directive.md` (the ad-hoc/conversational
   path). Both target files confirmed present at `.claude/context/patterns/lit-stage4a-flow.md`
   and the adhoc directive's deployed path. Skill behavior is byte-identical — none of the six
   skills ever read CLAUDE.md for this mechanics.
2. **Hard-mode routing ladder**: `.claude/CLAUDE.md`'s "Routing Mechanism" subsection now carries
   only the cross-reference sentence naming `context/guides/manifest-routing-schema.md` and
   `context/guides/hard-mode-routing.md`; the latter is now the sole edit target for the 5-step
   precedence ladder, with its Scope note updated to say so. Confirmed present at
   `.claude/context/guides/hard-mode-routing.md`. Routing itself (`manifest-routing-lib.sh`) is
   unchanged.
3. **Utility-script discovery**: The unabridged 12-entry list now lives at
   `.claude/docs/reference/utility-scripts-inventory.md`, reachable from a one-line pointer under
   CLAUDE.md's "Utility Scripts" heading and indexed in `docs-README.md`. Confirmed present with
   all 12 entries. The operator workflow is one `Read` longer; nothing was dropped.
4. **Skill/agent purpose lookup**: The Skill -> Agent pairing (23 rows, unchanged count) stays in
   `.claude/CLAUDE.md`; the Purpose/Model columns and the `### Agents` subtable were dropped in
   favor of a one-sentence pointer to the harness's own native Skill/Agent tool listings (free,
   injected every session) and each component's own frontmatter (`description:`, `model:`) as the
   durable source.

## Outcome Against the Illustrative Target

The plan's Non-Goal was explicit: the ~26 KB illustrative figure was never adopted as a target,
only the evidence-backed ~31-33 KB projection. **Measured landing: 33,215 B** for the assembled
`.claude/CLAUDE.md` (from 42,798 B, a 22.4% reduction) — 215 B above the top of the projected
31,000-33,000 B range, close enough to call the projection confirmed rather than contradicted; no
further unverified cuts were pursued to force it lower, consistent with the plan's Non-Goals
(Task Management, Project Structure, Rules References, and the Command Reference command table
carry no duplication evidence and were left untouched). The full **eager prefix landed at
60,577 B** (from 70,160 B, a 13.7% reduction), within the projected 60,000-62,000 B range.

## Impacts

- Every session touching `specs/**` now loads 9,583 fewer bytes of eager CLAUDE.md content
  (a ~13.7% cut to the full 9-file eager prefix), with zero capability loss — each cut workflow
  has a confirmed, reachable replacement route (see Capability Consolidations).
- A structural regression is now detectable: Rule V fails the doc-lint (hard-blocking by default,
  `SCHEMA_CONFORMANCE_GATE_MODE`) the moment either shape-(a) source regrows past its measured
  ceiling, closing the gap Lever C's research finding identified (`extension-slim-standard.md`
  previously exempted shape-(a) sources entirely).
- The `extension-slim-standard.md` advisory/hard drift (doc said `advisory`, code said `hard`) is
  now corrected, removing a source of confusion for any future contributor reading that standard.
- `measure-eager-surface.sh` is now a reusable, repeatable measurement tool for any future
  eager-surface audit — no future cut needs to hand-derive the 9-file composition again.

## Follow-ups

- Promote `claudemd-size-budget.json`'s per-extension ceilings to a `manifest.json` field
  (`merge_targets.claudemd.max_bytes`) once the in-flight manifest-schema task lands — recorded
  explicitly in `extension-slim-standard.md`'s new "Shape-(a) Merge Sources" section as a planned
  follow-up, not a rejected design.
- The two pre-existing, unrelated gate failures found during this task (Rule S's unindexed
  `return-meta-artifacts-template.md`, and `validate-state.sh`'s unknown-field findings on task
  entries 49, 52-56) are out of this task's scope and were left untouched; they should be tracked
  and fixed independently.

## References

- `specs/057_cut_generated_claudemd_eager_surface/plans/01_cut-claudemd-eager-surface.md`
- `specs/057_cut_generated_claudemd_eager_surface/reports/01_cut-claudemd-eager-surface.md`
- `specs/057_cut_generated_claudemd_eager_surface/baseline-measurement.json`
- `agent-system/extensions/core/scripts/measure-eager-surface.sh`

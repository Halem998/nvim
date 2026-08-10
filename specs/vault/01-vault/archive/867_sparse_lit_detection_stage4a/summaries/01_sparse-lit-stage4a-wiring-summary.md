# Implementation Summary: Task #867

**Completed**: 2026-07-15
**Duration**: ~4 hours (7 phases across 5 dependency waves)

## Overview

Closed two coupled gaps in the `--lit` literature pipeline: (1) sparse-coverage detection is now
surfaced loudly and machine-readably from both `literature-briefing.sh` and
`literature-lit-flag-resolve.sh`, gated by a new `LITERATURE_SPARSE_THRESHOLD` env var (default
3); and (2) the drifted Stage 4a flow across all six `--lit` skills was reconciled into one
shared, directly-executable block that actually calls the resolver, branches on every directive
with real `AskUserQuestion` instructions, and offers a new "Search online to ingest" option wired
to the existing `literature-ingest-online.sh` bridge.

## What Changed

- `agent-system/extensions/literature/scripts/literature-briefing.sh` — added
  `LITERATURE_SPARSE_THRESHOLD` (default 3), a machine-readable `<!-- lit-coverage mode=repo|global
  seg_count=N sparse=true|false threshold=T -->` marker in both per-repo and global-corpus modes,
  and a loud `[SPARSE COVERAGE ...]` banner when `sparse=true`. Existing human-readable output is
  byte-stable (additive only).
- `agent-system/extensions/literature/scripts/literature-lit-flag-resolve.sh` — added the same
  threshold env var and a new `SPARSE_PROMPT_NEEDED` directive: a sub-index that resolves to fewer
  than the threshold entries (including zero) now downgrades from `SUBINDEX_PRESENT` to
  `SPARSE_PROMPT_NEEDED` instead of silently proceeding with thin coverage.
- `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md` (new) — the single
  canonical Stage 4a block, placed in core context so its `@`-import resolves regardless of
  extension selection. Encodes the resolver call, all six directives, the shared four-option
  `AskUserQuestion` (adding "Search online to ingest"), the two-checkpoint sparse re-prompt, and
  the autonomous `[lit:auto]` fallback that never calls `AskUserQuestion` and never triggers
  online ingest.
- Six `SKILL.md` files (`skill-researcher`, `skill-planner`, `skill-implementer`, and their
  `-hard` variants) — replaced each skill's drifted, partly-commented-out Stage 4a block with a
  direct reference to the shared file, and removed the four remaining raw
  `literature-briefing.sh 2>/dev/null` call sites.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` and
  `skill-orchestrate-hard/SKILL.md` — changed `orchestrator_mode` from `false` to `true` for the
  research and plan dispatch sites (implement dispatch was already `true`), so `/orchestrate --lit`
  is treated as unattended in every phase, not just implement.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` and `architecture-spec.md` —
  added a dual-consumer cross-reference note: `orchestrator_mode` now gates both the
  `.orchestrator-handoff.json` write and the literature Stage 4a autonomy/`AskUserQuestion` gate.
- `agent-system/extensions/literature/EXTENSION.md`, `agent-system/extensions/core/merge-sources/claudemd.md`,
  and `agent-system/extensions/literature/context/project/literature/patterns/adhoc-navigation-directive.md`
  — synced to document the sixth directive, the threshold env var, the new online-ingest option,
  and the orchestrator_mode dual-consumer contract. `.claude/CLAUDE.md` (generated) was not
  hand-edited.

## Decisions

- Sparsity boundary is strictly `< threshold` (never `<=`), verified at counts 0/2/3/4 and with a
  threshold override.
- The resolver's `SUBINDEX_PRESENT`/`SPARSE_PROMPT_NEEDED` split reuses a lightweight
  `jq '.entries | length'` count rather than duplicating `literature-briefing.sh`'s full
  doc_id/global-index resolution loop (avoids double-counting logic).
- An autonomous run with a sparse-but-present sub-index (`SPARSE_PROMPT_NEEDED` +
  `orchestrator_mode: true`) reuses the existing sub-index via the plain per-repo briefing rather
  than launching a fresh global search — the curated sub-index, even if thin, is still the more
  relevant source, and online ingest stays interactive-only in every autonomous branch.
- The two-checkpoint sparse re-prompt only fires after the "Use global corpus now" choice, in
  interactive contexts, per the plan's risk mitigation (never after "Skip this run" or "Create
  curation task", and never in autonomous contexts).

## Plan Deviations

- None (implementation followed plan). One in-flight correction: the first draft of the shared
  block's skill-side reference text cited "the task-866 `literature-ingest-online.sh` bridge",
  which violates the repository's no-task-references-in-deliverables rule; corrected to the
  durable anchor "the STABLE-CONTRACT `literature-ingest-online.sh` bridge" across all six skills
  before committing.

## Verification

- Build: N/A (bash scripts + Markdown)
- Tests: `bash -n` clean on both modified scripts; resolver boundary fixtures (counts 0/2/3/4,
  plus a threshold override) match documented `< threshold` semantics exactly; briefing marker and
  banner verified in both per-repo and global-corpus modes; all six skills confirmed to reference
  the shared block via grep; zero raw `literature-briefing.sh 2>/dev/null` call sites remain;
  `bash .claude/scripts/check-extension-docs.sh` passes with all 20 extensions (including `core`
  and `literature`) reporting `OK`.
- Files verified: Yes

## Notes

- `agent-system/extensions/literature/scripts/test-lit-pipeline.sh` is a pre-existing test that
  greps the DEPLOYED `.claude/` tree (not the `agent-system/extensions/` source tree edited here);
  since the literature extension is not currently deployed in this repo's `.claude/` (per the
  pre-existing stale-pin state noted as out of scope in the plan's Non-Goals), this test was not
  run and may need updating once the extension is next (re)deployed.
- The literature extension's own Zotero-search fixture data was used read-only for smoke-testing
  `literature-briefing.sh --global`; no repo files outside the task's file scope were modified for
  this verification.

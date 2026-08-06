# Implementation Summary: Repair Stage 4 H4 Gate and Skeleton Summary Propagation

- **Task**: 959 - repair_stage4_h4_gate_and_skeleton_summary_propagation
- **Status**: [COMPLETED]
- **Started**: 2026-08-05T00:00:00Z
- **Completed**: 2026-08-05T01:00:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_h4-gate-and-summary-propagation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Fixed two mechanical defects in the Stage 4 region of
`agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`: a literal-string H4
adversarial-verification gate that false-negatived on a stronger-but-differently-headed claim
table (Defect A), and a skeleton-exhaustion exit path that transitioned status without ever
propagating `completion_summary`/`roadmap_items` (Defect B). Both fixes landed in one file across
four sequential phases, with a new shared helper routing both terminal exit paths through one
propagation path.

## What Changed

- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`:
  - **Defect A (Phase 1)**: Replaced the literal-string grep
    `grep -q "| Claim | Source/Counterexample" "$research_path"` in the `researched` handler's H4
    gate with a case- and spacing-insensitive shape regex
    `grep -qiE '\|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b[^|]*\|' "$research_path"`,
    and rewrote the adjacent comment to describe the shape-based match with both known passing
    header formats named as examples.
  - **Defect B, helper (Phase 2)**: Added `hard_orchestrate_propagate_completion()` alongside the
    existing `build_hard_mode_prompt_context()` helper. It reads (or accepts a precomputed)
    `.return-meta.json`-derived JSON blob, defaults an empty result via
    `[ -z "${completion_json:-}" ] && completion_json='{}'` (never the corrupting
    `"${var:-{}}"` idiom), extracts `completion_summary`/`roadmap_items`, calls
    `skill_propagate_completion_summary`, and emits the empty-summary warning.
  - **Defect B, wiring (Phase 3)**: The `elif [ "$last_skeleton" = "true" ]` skeleton-exhaustion
    branch now calls the helper (fresh read, no precomputed JSON) after the
    `update-task-status.sh postflight ... pr_ready` transition and before
    `rm -f "$loop_guard_file"` / `EXIT`. The Stage 5 `implemented` tail's inline propagation block
    was replaced with a single call to the same helper, passing `"${recover_json:-}"` as the
    precomputed-JSON argument so the "only ONE reader of `.return-meta.json` per cycle" invariant
    is preserved.

## Decisions

- Kept the H4 matcher inline (not extracted to a shared library file): research confirmed exactly
  one grepping call site exists for the literal string across `agent-system/extensions/core/`, so
  the task description's own conditional resolves to "keep it inline, well-commented."
- Placed `hard_orchestrate_propagate_completion()` in the same fenced block as
  `build_hard_mode_prompt_context()` rather than a new block, since it did not disturb that
  block's readability.
- The Stage 5 tail refactor (the higher-risk option per the plan's documented fallback) was
  applied successfully — the fallback (helper called only from the skeleton branch) was not
  needed.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (markdown/skill file, no build step)
- Tests: N/A (no automated test suite for this skill file)
- Files verified: Yes
- H4 gate fixtures (re-verified against the exact regex as it appears in the file, using
  `/run/current-system/sw/bin/grep`):
  - `| Claim | Source/Counterexample | Verification Method | Confidence |` → MATCH
  - `| # | Claim under attack | Source / counterexample | Outcome |` → MATCH
  - `| Some other table | with columns | not adversarial |` → NOMATCH
- `bash -n` clean on a combined scratch file covering all four edited/added regions (H4 gate
  conditional, the new helper, and both call sites).
- `bash .claude/scripts/check-task-references.sh` on the edited file: PASS, 0 unexempted
  occurrences.
- Diff scope confirmed via `git diff --name-only` across the three phase commits: only
  `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (plus `specs/**`
  artifacts) changed. No `.claude/**` path was touched.
- No `"${var:-{}}"` inline-default idiom appears in any new or edited line (verified by grep;
  the one pre-existing occurrence at line 937, `recovered_reported_status=$(echo
  "${recover_json:-{}}" | ...)`, predates this task and was not touched).

## Impacts

- The H4 adversarial-verification gate in hard-mode orchestration no longer forces a redundant
  re-dispatch when a research report's claim-verification table uses the observed
  `| # | Claim under attack | Source / counterexample | Outcome |` header instead of the
  canonical one.
- Hard-mode orchestration's skeleton-exhaustion exit now writes a non-empty, current-dispatch
  `completion_summary` (and `roadmap_items` when supplied) into `state.json`, instead of leaving
  a stale/misleading completion summary after a skeleton-exhaustion transition to `pr_ready`.
- A future third terminal exit path in this file has one obvious, named helper to call rather
  than a temptation to re-inline a fourth copy of the propagation logic.

## Follow-ups

- **Out-of-scope doc/code mismatch in `orchestrate-recover-outcome.sh`** (flagged by research,
  not fixed here — outside this task's file scope): the script's header comment claims
  `completion_summary`/`roadmap_items` are populated "regardless of branch," but the
  non-success `emit` calls (`STATUS_IN_PROGRESS`/`STATUS_NOT_SUCCESS`) hardcode `""`/`"[]"`.
  Candidate for a follow-up task against `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh`.
- **Pre-existing forbidden idiom at a different, untouched call site**: line 937 of the edited
  file (`recovered_reported_status=$(echo "${recover_json:-{}}" | jq -r '.status // "unknown"'
  ...)`) uses the same `"${var:-{}}"` inline-default idiom this task's Defect B fix documents as
  hazardous. It predates this task, sits outside the two regions this plan scoped for editing,
  and was left untouched; noted here as a candidate follow-up rather than folded into this fix.

## References

- Plan: `specs/959_repair_stage4_h4_gate_and_skeleton_summary_propagation/plans/01_h4-gate-and-summary-propagation.md`
- Research report: `specs/959_repair_stage4_h4_gate_and_skeleton_summary_propagation/reports/01_h4-gate-and-skeleton-summary-propagation.md`

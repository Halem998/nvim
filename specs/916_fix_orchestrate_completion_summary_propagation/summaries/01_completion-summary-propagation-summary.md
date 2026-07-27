# Implementation Summary: Task #916

**Completed**: 2026-07-27
**Duration**: ~6 phases, single session

## Overview

Every `/orchestrate` path (base single-task, base multi-task Stage MT-4, hard single-task, and
hard multi-task via inherited MT-4) drove a task to `completed` without ever reading
`completion_data.completion_summary`/`roadmap_items` out of `.return-meta.json` or writing them to
`state.json`. This implementation adds one shared reader extension
(`orchestrate-recover-outcome.sh` now emits `completion_summary`/`roadmap_items` in every branch)
and one shared writer function (`skill_propagate_completion_summary` in `skill-base.sh`), then
converges all six call sites (three producer-side, three orchestrator-side) onto that single pair.
The broken `commands/orchestrate.md` CHECKPOINT 2 step, which read a never-assigned
`$result_summary` and unconditionally clobbered `completion_summary` with an empty string, was
deleted.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` — extracts
  `completion_summary`/`roadmap_items` from `.completion_data`, extends `emit()` with two braced
  positional params (`${10}`/`${11}`), updates all six `emit` call sites, documents the new output
  fields in the header table.
- `agent-system/extensions/core/scripts/skill-base.sh` — new `skill_propagate_completion_summary`
  function (adjacent to `skill_propagate_memory_candidates`), implementing the guarded write via
  `jq --arg`/`--argjson` against `${SKILL_REPO_ROOT}`-relative `state.json`.
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` — Stage 7b converged onto the
  shared writer (sources `skill-base.sh` at the top); `SKIP_COMPLETION_DATA` escape hatch and the
  `operation_type`/`status` outer guards preserved unchanged. Still unwired (Non-Goal, as planned).
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` — Stage 7 Steps 2-3 replaced
  with a single shared-writer call.
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` — Stage 7a Steps 2-3
  replaced identically; the "only runs when Stage 7 did not refuse completion" precondition kept.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 5 `implemented)` case
  wired (resolves completion data via `$recover_json` reuse or a second scoped read, calls the
  shared writer, emits an empty-summary warning); Stage MT-4 step 3 wired identically per-task,
  using the per-task `task_type` already threaded through MT-2/MT-4 (no new lookup).
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — Stage 5 `implemented)`
  case wired identically, `[hard-orchestrate]` log prefix. No separate multi-task edit (hard mode
  delegates to base MT-1..MT-5, confirmed unchanged).
- `agent-system/extensions/core/commands/orchestrate.md` — deleted the broken CHECKPOINT 2
  "Populate Completion Summary" step (unconditional `$result_summary` clobber).
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — new note stating
  `completion_summary`/`roadmap_items` live exclusively in `.return-meta.json`, never in the
  handoff, and are read exclusively via `orchestrate-recover-outcome.sh` regardless of handoff
  presence.
- `agent-system/extensions/core/context/formats/return-metadata-file.md` — cross-reference note
  added alongside the existing `completion_data` field table.

## Decisions

- Kept the plan's design unmodified: one shared reader extension + one shared writer function,
  six call sites, zero new readers of `.return-meta.json` on the orchestrator path.
- Used `[ -z "${completion_json:-}" ] && completion_json='{}'` instead of the plan-sketched
  inline `"${completion_json:-{}}"` default (see Plan Deviations below).

## Plan Deviations

- **Phase 4 / Phase 5, `completion_json` empty-default idiom** — altered: the plan's sketched
  `"${completion_json:-{}}"` inline bash default has a parameter-expansion pitfall — bash's
  default-word matching for `${var:-word}` stops at the FIRST unescaped `}`, so on a non-empty
  `completion_json` it silently appends a stray trailing `}`, corrupting the JSON and making every
  downstream `jq ... 2>/dev/null` call fail closed to `""`. This would have made
  `completion_summary` empty on **every real invocation** — silently defeating this task's entire
  purpose. Caught by a functional simulation against a fixture (not just `bash -n`, which cannot
  catch a semantic default-value bug). Fixed by replacing it with a two-step
  `[ -z "${completion_json:-}" ] && completion_json='{}'` guard everywhere the idiom was used
  (`skill-orchestrate/SKILL.md` Stage 5 and Stage MT-4, `skill-orchestrate-hard/SKILL.md` Stage 5).
  Re-verified end-to-end against fixtures after the fix; all three call sites now correctly
  extract and propagate a non-empty `completion_summary`.
- No other deviations. All six phases completed as planned; no tasks skipped or deferred.

## Verification

- Build: N/A (shell scripts + markdown; no compiled build step)
- Tests: Passed — `bash -n` on all three modified shell scripts; Phase 1 fixture sweep (5 cases,
  re-run against final files); Phase 2 fixture harness (6 write cases including an adversarial
  quoting/newline/backslash string, re-run against final files); functional end-to-end simulations
  of the Stage 5 and Stage MT-4 wiring against fixture `.return-meta.json`/`state.json` pairs
  (covering the fresh-read path, the `$recover_json`-reuse path, and the empty-summary-warning
  path). All confirmed `specs/state.json` in the real repo was never touched by any verification
  step (`SKILL_REPO_ROOT` override used throughout).
- Files verified: Yes — `grep -rn "skill_propagate_completion_summary"` confirms exactly one
  definition (`skill-base.sh`) and exactly six call sites; `grep -rn "result_summary"` returns zero
  hits inside this task's edited files (one hit remains in `commands/implement.md`, a sibling
  out-of-scope defect — see Notes); no task-number citations were introduced in any of the ten
  touched non-specs files; `git status --porcelain .claude/` is empty (SOURCE-STORE RULE honored
  throughout — no `.claude/` edits at any point).
- `bash .claude/scripts/check-extension-docs.sh` (doc-lint) exits non-zero, as expected — see
  Notes below.

## Notes

- **Post-deployment validation, deliberately not run here**: the acceptance criterion's live test
  (a multi-task `/orchestrate` run driving 2+ tasks to `completed`, confirming every one carries a
  non-empty `completion_summary` in `state.json` with no manual intervention) can only be executed
  after `.claude/` is re-synced from the source store (`<leader>al` / "Load Core" / "Sync all").
  Per the binding self-modification-caution constraint, no phase of this implementation performed
  that sync — the orchestrator that dispatched and executed this very task ran, and continues to
  run, the pre-change code from start to finish. This validation is the natural next step after a
  sync, not a gap in this task's own scope.
- **`bash .claude/scripts/check-extension-docs.sh` reports 3 FAIL / non-zero exit**: this is
  expected drift between the stale `.claude/` deploy artifact and the now-updated source store for
  `skill-base.sh` and `orchestrator-postflight.sh` (plus one pre-existing, unrelated drift entry
  for `roadmap-integration.sh` that predates this task and was not touched by it). This resolves
  automatically on the user's next `.claude/` sync; it is not a defect introduced by this
  implementation.
- **Out-of-scope sibling defect discovered, not fixed**: `commands/implement.md` (lines ~173-180)
  has the byte-for-byte identical broken `$result_summary` clobber that `commands/orchestrate.md`
  had — reading a never-assigned variable and unconditionally writing an empty
  `completion_summary` after every plain (non-orchestrated) `/implement` run. This affects the
  plain `/implement` path, not any `/orchestrate` path, and touching `commands/implement.md` was
  outside this task's declared file scope, so it was deliberately left unfixed. Recommend a
  follow-up task mirroring this task's Phase 4 deletion (remove the broken step; the skill-side
  producer path already writes `completion_summary` correctly via
  `skill_propagate_completion_summary` as of Phase 3 of this task).
- **Pre-existing, low-impact latent bug also discovered, not fixed**: the exact same
  `"${var:-{}}"` brace-matching pitfall this task's own Phase 4 deviation fixed already exists,
  independently, at `skill-orchestrate/SKILL.md:562` and `skill-orchestrate-hard/SKILL.md:823`
  (`recovered_reported_status=$(echo "${recover_json:-{}}" | jq -r '.status // "unknown"' ...)`).
  Impact is low — it is diagnostic-only logging that always silently falls back to `"unknown"`
  rather than the real recovered status — but it is a real, reproducible defect. Left unfixed as
  outside this task's file-edit scope (neither line is one of the six converged call sites);
  flagged here as a candidate for a small follow-up fix using the same
  `[ -z ... ] && var='{}'` pattern.

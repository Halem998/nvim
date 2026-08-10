# Implementation Summary: Task #920

**Completed**: 2026-07-27
**Duration**: ~1 session

## Overview

Replaced the silent `case "$dispatch_status" in ... *) echo "no postflight update needed"` catch-all
at all three named call sites with an explicit three-tier structure: unchanged success arms
(`researched|planned|implemented`), a named Tier B arm for in-enum exception outcomes
(`partial|failed|blocked`), and a loud Tier C off-schema handler for everything else (including
`null`, empty, and `in_progress`). An off-schema dispatch that in fact succeeded can no longer be
silently indistinguishable from one that produced nothing.

## What Changed

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 5 handoff read changed
  to `.status // ""`; added the accept-list sync comment citing
  `context/formats/return-metadata-file.md`; added the `partial|failed|blocked` Tier B arm; added
  the `[OFF-SCHEMA DISPATCH STATUS - ...]` Tier C handler with phase-identification-only inference
  from `artifacts[0].type`; added the post-artifact-linking halt (`EXIT (partial)`) consumed after
  artifact linking, not inline. Also updated Stage MT-4: step 3's `Other → no postflight update`
  replaced with explicit Tier B/Tier C clauses (prose form), step 5's `failed_tasks` list extended
  for off-schema, the commit-message selection list extended, and the branch-coverage list
  extended.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — identical mirror of the
  Stage 5 change (handoff read, sync comment, Tier B/C arms, post-linking halt), adapted only in
  log prefix (`[hard-orchestrate]`) and preserving the pre-existing hard-mode-specific
  `implemented)` arm body and the `<!-- BEGIN/END 772 Item 5B -->` markers untouched.

## Decisions

- Followed the plan's Scope Decision (Option a): `agent-system/extensions/core/scripts/skill-base.sh`
  was deliberately NOT edited, to avoid a two-file collision with a task queued to run immediately
  after this one that already declares `skill-base.sh` in its own file scope.
- The MT-4 off-schema banner is referenced by exact quoted text (`[OFF-SCHEMA DISPATCH STATUS -
  ...]`, "character-identical, modulo the interpolated value") rather than duplicated as a third
  literal `echo` statement, since Stage MT-4 is prose instructions, not executable bash — this
  avoids a third drift-prone literal copy while still satisfying the cross-site consistency check.
- The off-schema halt is a flag (`offschema_dispatch_status`) set inside the `case` and consumed
  AFTER the artifact-linking block, never an inline exit — so a dispatch's artifact is always
  linked before any halt, preserving evidence.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (markdown-embedded bash instructions, no build step)
- Tests: Passed — `bash -n` parse check on extracted `case` blocks (both files); full trace-test
  harness exercised `dispatch_status` values `success`, `partial`, `implemented`, `` (empty),
  `in_progress`, and `researched` against the actual Stage 5 tail logic (stubbed shared
  functions), confirming: `success`/`` /`in_progress` all reach Tier C (banner + halt);
  `partial` reaches Tier B (no banner, no postflight call, loop counter still advances);
  `implemented`/`researched` reach the unchanged success arms.
- Files verified: Yes — greps confirm `no postflight update needed` and `Other → no postflight
  update` no longer appear anywhere in either file; `[OFF-SCHEMA DISPATCH STATUS` appears exactly
  once in the hard-mode file and twice in the base file (Stage 5 literal + MT-4 prose reference);
  `context/formats/return-metadata-file.md` and the `keep this list and that table in sync`
  wording are present at all three sites; `scripts/skill-base.sh`'s `skill_postflight_update`
  citation is present at all three Tier B sites.
- `bash .claude/scripts/validate-artifact.sh` on the plan file: PASS (0 warnings).
- Source-store gate: zero `.claude/` paths appear in any commit for this task; every modified path
  is under `agent-system/extensions/core/`.
- No-task-references gate: no new task-number citation was added by this work's diff; the
  pre-existing `<!-- BEGIN/END 772 Item 5B -->` markers in the hard-mode file were left untouched.

## What remains NON-FUNCTIONAL after this task

Reproduced verbatim (in substance) from the plan's Scope Decision — this task closes the named
silent-no-op defect but does NOT make `partial`/`failed`/`blocked` dispatch outcomes drive a real
`state.json` transition:

| Gap | Status after this task |
|-----|------------------------|
| `partial` / `failed` / `blocked` dispatch outcomes producing a real `state.json` transition | **STILL BROKEN.** They are now *recognized and logged honestly*, but no state transition occurs. `skill_postflight_update` in `scripts/skill-base.sh` has its own internal `case "$status" in researched\|planned\|implemented) ... *) ... skip` gate, so a call from SKILL.md would no-op one layer deeper regardless of what this task does. |
| A task stranded at `researching`/`planning`/`implementing` after a `partial` dispatch | **STILL STRANDED.** The next loop iteration still reaches Stage 4's `researching` handler and still emits the misleading "currently being researched in another session" message. |
| `failed` as a `state.json` target status | **STILL ABSENT.** `scripts/update-task-status.sh` has working `postflight:partial` and `postflight:blocked` mappings, but **no `postflight:failed` mapping at all**. Whether `failed` should map to `blocked`, remain escalation-only, or gain its own mapping is an open decision. |

**Named follow-up (not created by this task):** admit `partial` and `blocked` into
`skill_postflight_update`'s internal accept-list in
`agent-system/extensions/core/scripts/skill-base.sh`, routing on `$status` directly, and decide
the disposition of `failed` (no `postflight:` mapping today). This follow-up must be sequenced
after the task that already holds `skill-base.sh` in its file scope. In-file comments citing
`scripts/skill-base.sh`'s `skill_postflight_update` symbol are present at all three Tier B
branches as the durable pointer to this follow-up.

## Notes

The recovery path (`recovered=true`) was deliberately NOT touched: `orchestrate-recover-outcome.sh`
only ever sets `recovered=true` for `researched|planned|implemented`, so a recovered
`dispatch_status` is always in-enum and can never reach the off-schema arm. `artifacts[0].type`
inference is used only to name which phase produced the artifact in the off-schema banner/error —
never as a success-vs-partial signal, since the schema's own examples pair `summary` with both
`implemented` and `partial` outcomes.

# Implementation Summary: Task #897

**Completed**: 2026-07-25
**Duration**: ~35 minutes

## Overview

Added a narrow, sanctioned phase-marker `grep -c` recovery path to both orchestrate skills
(`skill-orchestrate` and `skill-orchestrate-hard`) so the state machine can recover
`phases_completed` / `phases_total` when a dispatch's `.orchestrator-handoff.json` is missing or
stale. The exception is count-only (two `grep -c` integers, ≤10 tokens per recovery event),
heading-line-only (`^### Phase N: ` anchors), and fires exclusively inside Stage 5's existing
missing/stale-handoff branch — never on the normal path. Reconciled the two architecture docs
(`handoff-schema.md`, `orchestrate-state-machine.md`) so no doc contradicts the SKILL.md files'
now-accurate three-exception reading contract.

## What Changed

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — added the "Recovery
  exception (phase-marker grep)" carve-out under `## MUST NOT (Context Flatness Constraint)`
  (items 1-4 and the "ONLY file read" / "~450 tokens" sentences left byte-for-byte unchanged),
  and appended the recovery grep block to Stage 5's missing/stale-handoff branch.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — rewrote Read-allowlist
  category 3 to name the three sanctioned bounded grep-only uses (H4 verification, next-phase
  selection, phase-marker recovery), and appended the recovery grep block (adapted: `[hard-
  orchestrate]` log prefix, one extra leading-comment sentence) to Stage 5's missing/stale-
  handoff branch. No `MUST NOT` heading was added, per plan.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — replaced the unqualified
  "orchestrator NEVER reads... plan files" claim with an accurate statement plus a
  three-exception table (adversarial-verification grep, next-phase selection grep, phase-marker
  recovery grep).
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — added the two
  additive, optional loop-guard fields (`last_recovered_phases_completed`,
  `last_recovered_phases_total`) to the loop-guard schema block with a one-sentence diagnostic-
  only note, and updated the `## Context Flatness Guarantee` section (which carried the same
  unqualified claim, outside the two tasks explicitly named by Phase 3) to reference the new
  exception table instead of contradicting it.

## Decisions

- Reflowed the base skill's Stage 5 "TOKEN BOUND" comment onto one logical line so the exact
  phrase "≤10 tokens per recovery event" matches on a single line for grep-based verification.
- Lowercased "Phase-marker" to "phase-marker" in the hard skill's Stage 5 recovery-block leading
  comment header, matching the allowlist's lowercase phrasing, so the case-sensitive
  verification grep for "phase-marker recovery grep" returns the required 2+ hits.
- `.claude/` was intentionally **not** redeployed as part of this task. Per the plan's explicit
  non-goal, `.claude/` regeneration from the source store happens out-of-band via the extension
  picker; only `agent-system/extensions/core/**` (the source store) was edited.

## Plan Deviations

- **Task 2.3** altered: also lowercased "Phase-marker" to "phase-marker" in the hard skill's
  recovery-block leading comment header — needed to satisfy this phase's own case-sensitive
  verification grep (see Decisions above).
- **Phase 2 verification** noted (not a code deviation): the plan's expected count for
  `grep -c "hard-orchestrate\] RECOVERY"` was 4; the actual, correct count is 3, matching the
  base skill's own 3 RECOVERY log lines in the block Phase 2 explicitly instructs be copied
  verbatim (confirmed via a diff between the base and hard blocks showing only the two named
  adaptations). Treated as a planning-stage miscount in the expected value, not an
  implementation defect.
- **Phase 3** altered: also updated the `## Context Flatness Guarantee` section in
  `orchestrate-state-machine.md`, which carried the same unqualified "NEVER reads... plan files"
  claim outside the scope of the phase's two explicitly named file-edit tasks. Required to
  satisfy the phase's own repo-wide verification grep for contradicting unqualified claims.
- **Phase 4 verification** noted (not a code deviation): `git diff --stat` over the full
  `agent-system/` tree shows 6 modified files, not the plan's expected 4, because a concurrent
  implementation agent running in this same repository on a different task also modified
  `agent-system/extensions/core/scripts/reconcile-artifacts.sh` and
  `agent-system/extensions/core/scripts/skill-base.sh` during this run. This task's own diff,
  scoped to its 4 declared files, is exactly as expected; the extra files were never touched by
  this agent and are outside this task's territory per the concurrency constraint of this
  dispatch.

## Verification

- Build: N/A (markdown/prose + bash-block edits only)
- Tests: N/A — verified via `bash -n` on both extracted recovery blocks (pass), grep-count
  checks per phase (all pass, deviations noted above), the zero-match `|| x=0` idiom (verified
  single-line `0`), the unset-`plan_path` `ls | sort -V | tail -1` fallback (verified resolves
  to the highest-numbered plan), and a full source-store / deliverables audit (zero `.claude/**`
  paths touched by this agent, zero task-number citations introduced in any of the 4 modified
  files or the full `agent-system/` diff)
- Files verified: Yes — all 4 declared files modified, all phase-heading markers converged to
  `[COMPLETED]`, plan-level `Status` field updated to `[COMPLETED]`

## Notes

`.claude/` redeployment is out-of-band via the extension picker and was deliberately not
performed as part of this task, per the plan's explicit non-goal.

This implementation ran concurrently with another implementation agent operating on a different
task in the same repository. Per the dispatch's concurrency constraint, no `git add`/`git
commit`/`git stash` or other git-index-mutating command was run by this agent — the orchestrator
handles all commits. Two files outside this task's declared scope
(`agent-system/extensions/core/scripts/reconcile-artifacts.sh`,
`agent-system/extensions/core/scripts/skill-base.sh`) and two specs-tree paths
(`specs/TODO.md`, `specs/state.json`, `specs/896_.../`) show as modified/untracked in
`git status` — these are attributable to the concurrent session, not to this task.

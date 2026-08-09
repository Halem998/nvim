# Implementation Summary: Task #932

**Completed**: 2026-07-27
**Duration**: ~2.5 hours across 5 phases

## Overview

The multi-task `/orchestrate` batch commit had two defects: it never staged an implementation
agent's self-reported `modified_files` outside `specs/`, and it fired exactly once at end-of-batch,
folding every task's diff and index rows into one unrevertable commit. This implementation
relocates the commit out of `commands/orchestrate.md` Step 5 and into
`skill-orchestrate/SKILL.md`'s Stage MT-4 per-task postflight loop (new step 5.5), so every task's
own `task_dir`, `.return-meta.json`, and `dispatch_status` produce one scoped, `--honest-index-rows`
commit per phase transition — the same granularity a solo `/implement` run produces. The fix was
proven, not just code-inspected, with an executable two-task git harness asserting on real commit
contents.

## What Changed

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-4 gains step 5.5: the
  per-task staging block (task dir + `plan_path` + self-reported `modified_files`), the canonical
  task-scoped fail-safe warning, commit-message selection keyed off `dispatch_status`/gate outcome,
  and explicit branch-coverage prose for every exit path. The COMPLETION SEQUENCING note now
  records that per-task commits serialize naturally in program order.
- `agent-system/extensions/core/commands/orchestrate.md` — Step 5 retitled "Commit Reconciliation
  and Consolidated Output"; the combined batch commit (`stage_paths` loop + `git-commit-scoped.sh`
  call + combined `commit_message` branch) is removed and replaced with a non-blocking residue
  check (`git status --porcelain -- specs/`) plus an exit-path coverage table. `CHECKPOINT 3`
  (single-task commit) is untouched.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — new "Multi-Task
  Application" subsection documenting that the per-operation scopes apply once per task in MT
  mode, never unioned; the Fail-Safe Direction section now records the task-scoped warning variant
  as the only sanctioned wording; `--honest-index-rows` requirement clarified for shared index
  files; Related Documentation cross-references the new MT commit site and hazard retirement.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — Lifecycle-Cycling
  Loop ASCII box 7 now names the per-task scoped commit (width-preserved); a new "Commit
  Granularity" subsection under MT Mode; the "MT Example Flow" narrative's `Postflight:` lines now
  show `(commit)` per task per cycle.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — hazard 2
  ("Rollback/commit-granularity risk") is rewritten in place as **RETIRED**, with the original
  wording preserved for record, the retirement mechanism named, and a precisely stated residual
  (per-task commits still carry other tasks' current `state.json`/`TODO.md` rows, labeled via
  `--honest-index-rows`). Hazards 1 and 3 are explicitly reaffirmed as still live. The "Separately,
  and out of scope" paragraph about the batch-commit staging gap is replaced with a statement that
  the gap is now closed. Two incidental "batch commit"/"batch-commit" prose references elsewhere in
  the same file (the self-modification hazard rationale) were also updated for consistency with the
  new per-task architecture.

## Decisions

- Commit granularity is **per-task-per-phase-transition**, not per-wave, per the plan's Decision
  Record: the `waves` array is inert at runtime (never re-read after Stage MT-1), so a genuine
  per-wave commit would require inventing new runtime state a per-task commit does not need, and
  per-wave still entangles every task in a wave — only per-task fully isolates a self-modifying
  task's change.
- The Step 5 residue check WARNS ONLY and never commits, since a blanket commit there would
  recreate the entanglement hazard 2 retires.

## Plan Deviations

- **Phase 2 / Testing & Validation verification bullet** (altered): the plan expected
  `commands/orchestrate.md` to contain exactly two `git-commit-scoped.sh` hits after the edit.
  The actual count is three: a pre-existing prose mention inside `CHECKPOINT 3`'s own explanatory
  paragraph (not a second commit call site), in addition to the two real invocations (completion
  and partial forms). All three hits fall below the `CHECKPOINT 3` heading and zero fall in the
  MULTI-TASK DISPATCH section — the substantive property being verified (no MT batch commit,
  single-task `CHECKPOINT 3` untouched) holds; only the literal hit-count differs from the plan's
  assumption.

## Verification

- Build: N/A (documentation/markdown/skill-instruction changes, no compiled artifact)
- Tests: Passed — executable two-task scratch harness (see Phase 5 progress notes for the full
  commit-by-commit assertion log): isolation confirmed both directions (`fixture_alpha.md` /
  `fixture_beta.md` never cross-contaminate), ephemeral `.orchestrator-loop-guard` exclusion
  verified under a genuinely dirty tracked guard file, `--honest-index-rows` addendum verified to
  fire correctly when a sibling task's row legitimately changed in the same staged snapshot, and
  the fail-safe (absent `modified_files`) path verified to warn loudly and still commit
  task-directory-only paths.
- Files verified: Yes — all five declared `file_scope` files edited, all under
  `agent-system/extensions/core/**`; `git status --porcelain -- .claude/` confirmed empty in the
  real repository throughout.

## Notes

- A live end-to-end `/orchestrate N,M` run additionally requires a human redeploy (`<leader>al` /
  "Load Core") to regenerate `.claude/` from the source store before these changes take effect —
  an agent must not perform that step. The harness in Phase 5 is the executable verification bar
  this task meets; the live run is a follow-up human confirmation, not a blocker on completion.
- The harness itself lives only under the session scratchpad
  (`task932_harness/`) and was never committed to this repository.

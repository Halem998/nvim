# Implementation Summary: Task #894

**Completed**: 2026-07-25
**Duration**: ~2.5 hours across 6 phases (resumed once after an infrastructure interruption)

## Overview

Fixed two defects in `agent-system/extensions/core/scripts/git-snapshot.sh`: a resolution
failure that never explained *why* task-directory inference failed, and a default mode whose
`git stash push -u` silently reverts the working tree despite the script's read-only-sounding
name. The fix adds loud stderr warnings plus a richer failure message, a new opt-in
`--no-revert` mode that genuinely does not mutate the working tree (`git stash create` +
`git stash store` plus an untracked-file copy), and call-site updates across the source store
that name the task number explicitly and route each of the two semantic families (rollback-
ladder vs. defensive-checkpoint) to the mode matching its intent. All work was verified in an
isolated scratch repo under the scratchpad directory — the running repository's working tree
was never touched.

## What Changed

- `agent-system/extensions/core/scripts/git-snapshot.sh` — new usage block documenting the
  revert plainly, `--help`/`-h`, unknown-option rejection, mutual-exclusion check for
  `--branch`/`--no-revert`, `resolve_task_dir()` now echoes a specific stderr reason on every
  failure path (subshell-safe since `TASK_DIR=$(resolve_task_dir ...)` runs it in a command
  substitution), pre-op/post-op stderr warnings for tree-reverting modes, new `--no-revert`
  mode dispatch branch (`git stash create` + `git stash store` + `git ls-files --others
  --exclude-standard` copy to `untracked-backup-{ts}/`), new `UNTRACKED_BACKUP=` marker key,
  and a new conditional `untracked-backup:` stdout line (prints only when non-NONE).
- `.gitignore` (repo root) — added `**/untracked-backup-*/` with an explanatory comment.
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` — blocked-command advice now
  names the task-number argument and the mode split.
- `agent-system/extensions/core/rules/git-workflow.md` — exemption item 2 lists all three
  modes; the bare-invocation instruction now requires an explicit task number and states that
  default/`--branch` both revert.
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — rung (c) (default
  mode, rollback-ladder family) now passes `{task_number}` explicitly; the separate Stage 4C
  git-checkpoint sub-section (defensive-checkpoint family) now specifies `--no-revert`.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — Recovery Discipline
  contract slot now interpolates `$task_number` and notes the revert behavior.
- `agent-system/extensions/core/context/contracts/recovery.md` — rung (c) step 1 requires an
  explicit `TASK` argument and states `--branch` does not avoid the revert.
- `agent-system/extensions/core/context/patterns/checkpoint-before-overflow.md` — code block,
  prose, decision table, and handoff reference string all route to `--no-revert` for the
  CHECKPOINT-BEFORE-OVERFLOW defensive-checkpoint path.
- `agent-system/extensions/core/agents/general-research-agent.md`,
  `general-research-hard-agent.md`, `general-implementation-agent.md` — Stage 4C checkpoint
  steps now specify `--no-revert` with a one-line rationale.

## Decisions

- Implemented `--no-revert` as a third, opt-in mode (never a default) per the plan's explicit
  design decision, since the research reproduction proved `--branch` insufficient as a
  non-destructive option.
- Preserved the plan's Phase 2 pre-op/post-op warning block when applying Phase 3's mode-
  dispatch replacement text: rather than deleting the Phase 2 insertion (which the plan's
  literal anchor-and-replace instruction would have done, since the warning block now sits
  between the plan's quoted anchor and the dispatch `if`), the edit was split into two Edits —
  an `UNTRACKED_BACKUP="NONE"` initializer insertion and a separate if/elif/else replacement —
  producing a script textually equivalent to the plan's intent with both phases' additions
  intact. Recorded as a Phase 3 deviation.
- Phase 6's scratch-repo harness asserts the two properties that matter for `--no-revert`
  (pre-existing tracked-file content unchanged, pre-existing untracked file still present)
  rather than literal `git status --porcelain` byte-equality, because the script's own new
  output artifacts (patch, marker, and in `--no-revert` mode the untracked-backup dir) are new
  untracked entries in every mode by design — this was already observable in the Phase 2
  default-mode functional test and is not specific to `--no-revert`. Recorded as a Phase 6
  deviation.

## Plan Deviations

- **Task 3.1** altered: applied as two separate Edits (initializer insertion + dispatch
  if/elif/else replacement) instead of one contiguous replacement, to preserve the Phase 2
  pre-op warning block that the plan's anchor text did not account for. See progress file
  `specs/894_fix_git_snapshot_silent_revert_footgun/progress/phase-3-progress.json`.
- **Task 6.C** altered: asserted tracked-content-unchanged + untracked-file-presence instead of
  literal `git status --porcelain` byte-equality in the Phase 6 scratch-repo harness. See
  `specs/894_fix_git_snapshot_silent_revert_footgun/progress/phase-6-progress.json`.

Both deviations are textual/testing refinements that preserve the plan's actual intent; no
functional behavior described in the plan was altered or dropped.

## Verification

- Build: N/A (bash scripts, no build step)
- Tests: Passed — `bash -n` on both modified scripts; scratch-repo verification matrix (Phase 6)
  ran all 7 cases (A through G, 44 individual assertions) with zero failures, including a
  standing regression guard (Case B) reconfirming that `--branch` still reverts the working
  tree, exactly as the research report's reproduction found. The running repository's own
  `git status`, stash list, and branch list were confirmed unaffected before and after the
  scratch-repo run.
- Files verified: Yes — all edits applied via Read/Edit tools (never a Bash heredoc, per the
  plan's binding constraint), `bash -n` clean, functional smoke tests passed for every mode.

## Notes

- All 6 phases committed separately (`task 894 phase N: ...`) per the commit-per-green-substep
  mandate; each commit's file list stays scoped to `agent-system/extensions/core/**`,
  `.gitignore`, and `specs/894_.../**` — never `.claude/**`, honoring the source-store rule.
- No new task-number citations were introduced in any deliverable outside `specs/**`; the
  pre-existing "task 780" citation on the script's own header comment was removed in Phase 1
  per Edit 1.2, and other pre-existing citations on lines this plan did not touch were left
  alone (out of scope per the plan's binding constraint 2).
- This implementation was resumed once after an infrastructure interruption (process exit, not
  an implementation error). Phase 1's script edits were found intact and uncommitted on
  resumption; work continued from there without redoing anything, per the re-verification the
  resuming session performed against git log, git status, and plan-checkbox state before
  proceeding.

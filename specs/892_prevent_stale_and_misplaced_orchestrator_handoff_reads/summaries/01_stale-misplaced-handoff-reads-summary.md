# Implementation Summary: Task #892

**Completed**: 2026-07-25
**Duration**: ~2 hours across two sessions (interrupted once by infrastructure failure; resumed
cleanly from committed phase state)

## Overview

Fixed the dual-path root cause of the orchestrator reading a stale or misplaced
`.orchestrator-handoff.json`: (a) `skill-base.sh`'s script-layer handoff write used a
cwd-relative path, and (b) hard-mode write instructions told agents to write the handoff with no
directory anchor anywhere in the instruction chain. All 8 phases of the plan were executed and
verified. Every handoff writer now resolves an absolute destination, every dispatched agent
receives an absolute `task_dir`/`handoff_path` in its delegation context, a PostToolUse hook
catches misplaced Write/Edit-tool writes, and both orchestrators gate handoff reads on freshness
(`dispatch_start_ts`) and sweep for stray files regardless of write mechanism.

## What Changed

- `agent-system/extensions/core/scripts/skill-base.sh` — added `SKILL_REPO_ROOT` (resolved from
  `BASH_SOURCE`), exported absolute `TASK_DIR_ABS`, made `skill_write_orchestrator_handoff`'s
  `handoff_path` absolute, and documented the hook's blindness to this Bash-redirect write site.
- `agent-system/extensions/core/hooks/validate-handoff-location.sh` — created. PostToolUse hook
  (matcher `Write|Edit`) rejecting misplaced `.orchestrator-handoff.json` writes with exit 2 and
  remediation text; documents its own structural blindness to Bash-redirect writes in its header.
- `agent-system/extensions/core/merge-sources/settings-hooks.json` — registered the hook
  (deliberately without the `2>/dev/null || echo '{}'` advisory suffix the sibling hooks use).
- `agent-system/extensions/core/manifest.json` — added `validate-handoff-location.sh` to
  `provides.hooks`.
- `agent-system/extensions/core/context/contracts/wrap-up.md` — added a "Write location" section
  requiring the absolute `handoff_path`/`task_dir` anchor, never a bare filename.
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — Step 1 now states
  the absolute-path requirement before the handoff-writing instructions.
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` — resolves
  `task_dir_abs`/`handoff_path_abs`, adds both to the delegation-context JSON, and states the
  destination explicitly in the dispatch prompt text.
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` — same absolute-path
  Step 1 treatment as the core hard agent.
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` — resolves the
  absolute anchor, rewrites both handoff read sites to use it, adds delegation-context fields,
  updates the dispatch-prompt bullet list and the literal dispatch bullet text.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — resolves
  `TASK_DIR_ABS`/`HANDOFF_PATH_ABS` in Stage 1a; the handoff read path, all four single-task
  dispatch contexts, the revise re-dispatch context, and the three multi-task dispatch contexts
  all carry the absolute anchor; Stage 5 gained the staleness gate and stray-handoff sweep.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — identical treatment:
  absolute anchor resolution, handoff read path, the four dispatch contexts (research, H4
  adversarial-verification re-dispatch, plan, implement), and the same Stage 5 staleness
  gate/stray sweep with the `[hard-orchestrate]` log prefix.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — new "Path Resolution
  Contract" section documenting both write mechanisms, the hook's exact coverage boundary, and
  the reader-side freshness rule; also dropped a pre-existing task-number citation from the
  Status line (Edit 8b, optional cleanup called out in the plan).

## Decisions

- Followed the plan's given replacement text verbatim per Constraint 3 (quoted text is
  authoritative), rather than re-deriving wording.
- Kept the dual-path root-cause framing separate throughout: Phase 1's `skill-base.sh` fix is
  explicitly NOT what caused the observed stray (that function is called only by base-mode
  skills; the agent that produced the stray was hard-mode and never calls it). Phases 3-6 fix
  the actual trigger (missing directory anchor in hard-mode write instructions).
- Preserved the honesty requirement in all three required locations: the hook file header, the
  `skill-base.sh` write-site comment immediately before the `jq -n` write, and
  `handoff-schema.md`'s "Path Resolution Contract" section all state, without softening, that the
  hook is structurally blind to the Bash-redirect write because a Bash `tool_input` carries only
  unexpanded command text.
- Stray sweep bounded to exactly two paths (`${sweep_root}/.orchestrator-handoff.json` and
  `${sweep_root}/specs/.orchestrator-handoff.json`), moves aside via `mv` (never deletes), never
  a recursive `find` — matches the plan's given text exactly.
- Staleness gate reuses `dispatch_start_ts` for its comparison (`stale_window_start=` reads only
  `${dispatch_start_ts:-9999999999}`), fails closed on an unset window, and introduces no
  parallel staleness-timestamp mechanism.

## Plan Deviations

- None (implementation followed the plan's given replacement text exactly for every one of the
  45 checklist items across all 8 phases).

## Verification

- Build: N/A (markdown/shell instruction files, no build step)
- Tests: Passed —
  - `bash -n` clean on `skill-base.sh` and `validate-handoff-location.sh`.
  - `jq empty` clean on `settings-hooks.json` and `manifest.json`.
  - Hook exits 0 for relative `specs/{NNN}_`, absolute `specs/{NNN}_`, `specs/OC_{NNN}_`, and
    unrelated-file cases; exits 2 with remediation text for a bare `.orchestrator-handoff.json`.
  - `grep -c 'handoff_path: HANDOFF_PATH_ABS'` = 5 and `grep -c 'handoff_path: handoff_path_abs'`
    = 3 in `skill-orchestrate/SKILL.md` (four single-task + revise + three multi-task).
  - `grep -c 'HANDOFF_PATH_ABS'` = 6 in `skill-orchestrate-hard/SKILL.md` (definition,
    `handoff_file`, four dispatch sites).
  - `STALE HANDOFF` and `STRAY HANDOFF` each appear exactly once per orchestrator file; the
    inserted bash blocks in both files pass `bash -n`.
  - No `.claude/` file was touched by any of this task's 8 commits (verified via
    `git log --name-only` over the phase-1..phase-8 commit range).
  - No new task-number citation was introduced outside `specs/**` (verified via
    `git log -p` over the same commit range, grepping for `[Tt]ask [0-9]{2,4}`).
- Files verified: Yes

## Notes

- **Two verification-text caveats worth recording** (neither is a defect in the delivered code —
  both are precision notes about the plan's own Testing & Validation wording versus what the
  plan's own *exact replacement text* actually contains):
  1. The plan's Stage 5 test says "no newly-added `date -u +%s`" should be found. The staleness
     *comparison* itself introduces none (it reads only `dispatch_start_ts`). However, the
     plan's own verbatim Edit 7a/7c text for the stray-sweep's `mv` destination uses
     `$(date -u +%s)` to generate a unique filename for the moved-aside stray
     (`.stray-handoff-$(date -u +%s).json`) — an orthogonal use for uniqueness, not a second
     staleness-timestamp mechanism. A literal `grep` for `date -u +%s` in the Stage 5 diff finds
     2 matches per orchestrator file, both in this naming context. I followed the plan's exact
     quoted text per Constraint 3 rather than altering it to satisfy the literal grep.
  2. `skill-orchestrate-hard/SKILL.md`'s own verification bullet says `handoff_path` should
     appear on "every" `delegation_context:` line. The phase's task list gave exact edit text for
     four specific dispatch sites only (research, H4 adversarial-verification re-dispatch, plan,
     implement); two other pre-existing `delegation_context:` lines in the same file (an H5
     three-strikes divergence-audit re-dispatch, and a blocker-research dispatch) were not among
     the given edits, so they were left untouched rather than inventing new edit text beyond what
     the plan specified.
- **Environmental note on the shared working tree**: this repository is being worked on by
  multiple concurrent sessions in the same (non-worktree) checkout. Two of this task's commits
  (`5eaade0ce`, phase 3; `bfd62a71b`, phase 8) picked up files from another concurrent session's
  git index staging (a `reconcile-task-status.sh` change and several `specs/893_...` artifacts)
  despite `git add` being scoped to this task's own files immediately beforehand — the shared
  index meant those files were already staged by the time `git commit` ran. No data was lost or
  altered; the unrelated content is correctly preserved, just attributed to a task-892 commit
  message rather than its own. This is a git-index race condition inherent to concurrent
  same-checkout sessions, not a defect in this task's edits.

# Commit-Site Inventory and Primitive Re-Verification

Produced during Phase 1 of `plans/01_git-index-contention.md`. All findings below are re-checked
against the current tree (source store `agent-system/extensions/core/`) as of this implementation
pass; V-numbers reference the plan's Verified Findings table.

## V1-V5: Scratch-Repo Re-Verification (Disposable Repo, Session Scratchpad)

Repo built at a session-scratchpad path outside the task tree, destroyed after Phase 1 (a fresh
scratch repo is rebuilt independently for Phase 7's concurrency demonstration).

| Finding | Result | Evidence |
|---|---|---|
| V1: exclude pathspecs work on `git commit --` | **CONFIRMED** | `git commit -m "V1 test" -- taskA/ ":(exclude)taskA/.orchestrator-loop-guard"` committed only `taskA/f.txt`; the guard file stayed staged (`A`) but uncommitted. |
| V2: a nonexistent path in the commit pathspec aborts the whole commit | **CONFIRMED** | `git commit -- taskA/f.txt taskA/nonexistent-file.txt` exited 1 with `error: pathspec 'taskA/nonexistent-file.txt' did not match any file(s) known to git`; `taskA/f.txt` remained staged, uncommitted, nothing landed. |
| V3: an exclude-only pathspec list commits wider than a bare commit | **CONFIRMED** | With `taskA/f.txt` and `taskB/f.txt` both staged in the shared index, `git commit -m "..." -- ":(exclude)taskA/.orchestrator-loop-guard"` (no positive entry) committed BOTH files — swept in the concurrent process's `taskB/f.txt`. |
| V4: "nothing to commit" exits 1 for the scoped form, same as bare | **CONFIRMED** | Re-running `git commit -- taskA/f.txt` after it was already committed produced the standard `nothing to commit, working tree clean`, exit 1. |
| V5: the reported defect reproduces and is fixed by scoping | **CONFIRMED** | With agent B's `taskB/f.txt` staged in the shared index, agent A's scoped `git commit -- taskA/f.txt` committed only `taskA/f.txt`; B's staged content remained staged (`M taskB/f.txt`) and untouched by A's commit. |

## Commit-Site Inventory (Source Store)

11 sites across 7 files (not 8 — see note below). Anchors are surrounding-heading text, not line
numbers, per the plan's re-verify-before-editing constraint.

| # | File | Anchor | Notes |
|---|---|---|---|
| 1 | `agents/general-implementation-agent.md` | Stage 4B-iii "Green Sub-Step Commit (Mandatory)" | Per-objective commit; `stage_paths` built from task_dir + TODO.md + state.json + plan_path + per-objective `files_touched` loop. |
| 2 | `agents/general-implementation-agent.md` | "Phase Checkpoint Protocol" step 5 | Per-phase commit; same `stage_paths` shape, accumulated across the phase's progress-file `files_touched`. |
| 3 | `agents/general-implementation-hard-agent.md` | "Step 2: Final incremental commit" | Same shape as site 2, hard-mode sibling. |
| 4 | `skills/skill-implementer/SKILL.md` | Stage 6b (subagent-return iteration, "Composes with, does not duplicate...") | Coarser-grained than sites 1-2; expected to often find nothing to stage. |
| 5 | `skills/skill-implementer/SKILL.md` | Stage 9 (final) | Mirrors `orchestrator-postflight.sh`'s `implement` scope. |
| 6 | `skills/skill-planner/SKILL.md` | Stage 9 "Git Commit" | Plan-scope only (no `modified_files`). **Pre-existing latent bug**: the illustrative snippet's heredoc-style message is missing its closing `"` before the fence — not something this plan is fixing as a separate concern, but the Phase 6 conversion necessarily writes syntactically valid bash and will not carry the broken quoting forward. |
| 7 | `skills/skill-team-implement/SKILL.md` | Stage 10 "Per-Wave Commits" | Same missing-closing-quote issue as site 6; same resolution. |
| 8 | `skills/skill-team-implement/SKILL.md` | Stage 14 "Final Git Commit" | Same missing-closing-quote issue as site 6; same resolution. |
| 9 | `commands/orchestrate.md` | "Step 5: Batch Git Commit and Consolidated Output" (multi-task) | Already carries the `ephemeral_excludes` pathspecs (V6 confirms only this file's two sites have them today) and TWO alternative commit-message bodies (full success / partial success) sharing one `git add`. |
| 10 | `commands/orchestrate.md` | "CHECKPOINT 3: COMMIT" (single-task) | Already carries `ephemeral_excludes`; two alternative bodies (on completion / on partial). |
| 11 | `scripts/orchestrator-postflight.sh` | "Stage 9: Git commit (plan and implement only; non-blocking)" | Most-shared site; also hosts the Stage 9b honest-commit-message python scan being folded into the new helper via `--honest-index-rows`. |

**Count note**: the plan's Phase 1 task description expected "11 sites across 8 files." Re-grep
confirms 11 sites but only **7** files actually contain a `git commit` invocation (the two
`orchestrate.md` sites count as one file). This is a minor correction to the task description,
not a contradiction of any Verified Finding — recorded here rather than silently reconciled.

## V6 Re-Confirmation

```
grep -rn 'ephemeral_excludes' agent-system/extensions/core/
```
matches only `context/standards/git-staging-scope.md` (lines defining the array itself, twice).
`commands/orchestrate.md`'s two sites carry the exclusion pathspecs **inline** (spelled out
literally, not via an `ephemeral_excludes` array reference), which is why they don't show up in
this grep but are nonetheless already-exclusion-aware — this refines V6 without contradicting it:
the two orchestrate.md sites are current: current, not stale.
All other 9 sites (the 5 in the Phase 5 territory, plus skill-planner, skill-team-implement's two,
and orchestrator-postflight.sh) stage a bare task directory with no exclusions at all.

## V7 Re-Confirmation

`grep -n 'git commit' skills/skill-implementer-hard/SKILL.md skills/skill-orchestrate/SKILL.md`
returns no matches in either file. Both are confirmed clean; neither needs a Phase 5/6 edit.

## V9 Re-Confirmation

Task 885 status: `partial` (non-terminal, confirmed via `jq` over `specs/state.json`).
Lock state: `bash .claude/scripts/task-lock.sh check 885` → `free` (exit 0). Since the lock is
free, Phase 6's `orchestrator-postflight.sh` edit proceeds without deferral; 885's declared
`file_scope` on that file targets its event/signal-capture instrumentation, a different region
from the Stage 9 commit block this plan touches.

## Stop-Condition Check

None of V1-V5 contradicted; Phase 2 proceeds on the validated premise.

# Research Report: Task #878

**Task**: 878 - harden_status_scripts_and_own_phase_markers
**Started**: 2026-07-15
**Completed**: 2026-07-15
**Effort**: ~1.5 hours (research)
**Dependencies**: Task 877 (settled plan-status vocabulary, COMPLETED), Task 876 (wired preflight into orchestrate paths, COMPLETED)
**Sources/Inputs**: Codebase (`.claude/scripts/*.sh`, `.claude/agents/general-implementation*-agent.md`), task 877/876 artifacts, `.agent-logs/`
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All five defects (A-E) in the task description are substantially confirmed against the live files, with three corrections noted below (mtime-selection line numbers, defect B's actual failure site, and a third undocumented mtime-selection occurrence).
- **CRITICAL PROCESS FINDING**: the canonical, git-tracked source for all four in-scope files is `agent-system/extensions/core/...`, NOT `.claude/...`. The `.claude/` tree is a gitignored deploy mirror. Both trees are currently byte-identical (verified via `diff -q`), but implementation must edit the `agent-system/` copies and mirror to `.claude/`, exactly as tasks 876 and 877 did. The task description's FILE SCOPE section names only `.claude/` paths — this must be corrected during planning.
- Defect A's real fix is a **prompt-level wiring change**, not a script change: `update-phase-status.sh`'s interface already supports per-phase advancement (it takes an explicit `phase_number` argument). `general-implementation-hard-agent.md` already calls it correctly at both phase-start (IN_PROGRESS) and phase-end (COMPLETED) for every phase it processes. `general-implementation-agent.md` has zero references to the script and instead instructs hand-editing via the Edit tool — this is the actual root cause of "only phase 1 ever advances," since `update-task-status.sh`'s own auto-advance snippet only ever fires once, on `implement` preflight, for the first `[NOT STARTED]` phase.
- Defect B's failure site is one level higher than described: `update-plan-status.sh` does NOT silently no-op on a missing `Status` anchor — it self-verifies and exits 1. The silence is introduced by its caller, `update-task-status.sh`, which redirects stderr to `/dev/null` and downgrades that exit 1 to a warning.
- `phase-transitions.log` is confirmed absent from the live, actively-written `.agent-logs/` directory — hard proof `update-phase-status.sh` has never completed a transition in this working tree.

## Context & Scope

Researched four defects (A-D) plus a fifth (E, task-level partial/blocked terminus) across three scripts (`update-task-status.sh`, `update-plan-status.sh`, `update-phase-status.sh`) and one agent file (`general-implementation-agent.md`), per the delegation description. Verified every line-numbered claim against the current file contents, read the settled vocabulary from task 877 and the preflight-wiring interaction from task 876, and produced a fatal-vs-warn decision table for defect B.

## Findings

### Codebase Patterns

**Canonical source vs. deploy mirror** (not in the task description, discovered during research):
`agent-system/extensions/core/{scripts,agents}/...` is the git-tracked source of truth; `.claude/{scripts,agents}/...` is a gitignored deploy mirror regenerated from it. Confirmed via `diff -q` on all four in-scope files — currently identical. Tasks 876 and 877 both edited the `agent-system/` copies and manually mirrored to `.claude/` in the same commit. Task 878's implementation must follow the same two-tree edit pattern; **do not edit `.claude/` alone**.

### Defect A — Phase markers have no owning mechanism

**Confirmed exactly as described:**
- `update-task-status.sh:277` (in `agent-system/extensions/core/scripts/update-task-status.sh`, same line in the deployed mirror): `grep -m1 "^### Phase [0-9]*:.*\[NOT STARTED\]" "$plan_file"` — takes only the first match. This call only fires inside `update_plan_file()`'s `if [[ "$operation" == "preflight" ]]` branch (line 261), meaning it only ever runs once per `implement` preflight dispatch, advancing exactly one phase to `IN_PROGRESS`. Nothing in `update-task-status.sh` ever calls `update-phase-status.sh` with `COMPLETED`, and nothing advances phase 2 through N.
- `general-implementation-agent.md:120-126` and `:225-231` instruct the LLM to hand-edit the phase heading via the `Edit` tool (`### Phase {P}: {Phase Name} [NOT STARTED]` -> `[IN PROGRESS]`, and `[IN PROGRESS]` -> `[COMPLETED]`), with an explicit note "Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per phase." There is no Bash/script call anywhere in this file.
- `grep -c "update-phase-status" general-implementation-agent.md` returns **zero matches** — confirmed the base agent has no reference to the script at all.
- `general-implementation-hard-agent.md` calls the script at line 155 (`IN_PROGRESS`, Stage 4A) and line 171 (`COMPLETED`, Stage 4D), each guarded by an Edit-tool fallback ("If the script is unavailable..."). It ALSO has a Stage 5a self-repair loop (lines 220-236) that scans for any stale `[NOT STARTED|IN PROGRESS|PARTIAL]` phase heading after all assigned phases complete and force-repairs each one to `COMPLETED` via a per-phase `update-phase-status.sh` call, deriving `phase_num` from the grep match itself (`grep -oE "Phase [0-9]+" | grep -oE "[0-9]+"`).
- **`.agent-logs/phase-transitions.log` does not exist.** Verified: `.agent-logs/` contains `generate-todo.log`, `sessions.log`, `subagent-postflight.log`, all written today (2026-07-15) — the directory is live and actively used — but no `phase-transitions.log`. This is hard proof `update-phase-status.sh` has never completed a single transition in this working tree, consistent with the base agent never calling it.

**Mechanism for advancing phases 2..N (research requirement 5, resolved):**
`update-phase-status.sh`'s interface already takes an explicit `phase_number` as its third positional argument (`TASK_NUMBER PROJECT_NAME PHASE_NUMBER NEW_STATUS`) and locates that phase's heading by an exact `^### Phase {phase_number}:` grep — it is NOT hardcoded to "first NOT STARTED" the way `update-task-status.sh`'s convenience wrapper is. The script's design already supports arbitrary per-phase calls; **the caller** is the missing piece. The correct owning mechanism, already proven by `general-implementation-hard-agent.md`, is: the implementing agent itself, which already knows which phase number `P` it is executing (it reads this from the plan file at Stage 2/3 and iterates through phases sequentially in its own Phase Checkpoint Protocol loop), calls `update-phase-status.sh "$task_number" "$project_name" "$P" IN_PROGRESS` at phase-start and `... COMPLETED` at phase-end for **every** phase it processes — not just phase 1. This naturally covers phases 2..N because the agent's own loop already visits every phase; no change to `update-phase-status.sh`'s interface is needed. Recommendation: wire `general-implementation-agent.md` Stage 4A and Stage 4D to call the script (mirroring the hard agent's exact pattern, including its Edit-tool fallback for script-unavailable), replacing the current Edit-tool-only instructions.

The idempotency check inside `update-phase-status.sh` (lines 90-94: exits 0 silently if `current_status == new_status_display`) means calling it redundantly (e.g., once from the agent's own loop and once from `update-task-status.sh`'s first-phase auto-advance) is safe — no conflict requires removing the existing auto-advance snippet, though it becomes redundant once the agent owns all transitions.

### Defect B — Every failure is silent

**Confirmed sites, with one correction:**

| # | File:Line | Described behavior | Verified behavior |
|---|-----------|--------------------|--------------------|
| 1 | `update-task-status.sh:209-211` | TODO.md regen failure -> warning | Confirmed verbatim: `"$SCRIPT_DIR/generate-todo.sh" \|\| { echo "Warning: generate-todo.sh failed (state.json was updated successfully)" >&2 }` |
| 2 | `update-task-status.sh:256-258` | plan status update failure -> warning | Confirmed verbatim: `"$plan_script" ... 2>/dev/null \|\| { echo "Warning: plan file update failed (non-fatal)" >&2 }` — note the `2>/dev/null` additionally discards `update-plan-status.sh`'s own stderr diagnostic, so even the underlying error message is lost, not just downgraded. |
| 3 | `update-task-status.sh:280-283` | phase status update failure -> warning | Confirmed verbatim: `"$phase_script" ... 2>/dev/null \|\| { echo "Warning: phase status update failed (non-fatal)" >&2 }` — same stderr-discard pattern. |
| 4 | `update-plan-status.sh:58` (sed anchor) | Described as "silently no-ops when the anchor is missing" | **Correction**: the sed line itself (actual line 62 in the current file, not 58) does no-op silently if the `^- \*\*Status\*\*: \[.*\]` anchor is absent, but the script does NOT stop there — lines 64-71 re-grep the status and compare it to the target; if they don't match, the script prints `"Failed to update status in $plan_file"` to stderr and **exits 1**. `update-plan-status.sh` is fail-loud by design. The actual silence is introduced entirely by call site #2 above (`update-task-status.sh:256-258`), which redirects this script's stderr to `/dev/null` and swallows its exit 1 into a non-fatal warning. Treat defect B's root cause at this site as "caller discards a script that already fails loudly," not "script fails silently." |

**Fatal-vs-warn decision table** (research requirement 4):

| Failure site | Current behavior | Recommendation | Justification |
|---|---|---|---|
| `generate_todo()` failure (TODO.md regen) | Warning, non-fatal | **Keep as warning**, but make it louder (no `2>/dev/null`) | state.json (machine truth) already wrote successfully; TODO.md is a rendered view regenerable on the next successful run or via `/todo`. Failing the whole preflight/postflight over a rendering failure would block legitimate work. However, per `.claude/rules/state-management.md`, TODO.md desync is itself a `status_sync_failure` — the warning should be `errors.json`-logged, not merely printed to stderr, to make it discoverable. |
| `update_plan_file()` -> `update-plan-status.sh` call, `implement` postflight (marking plan `[COMPLETED]`) | Warning, non-fatal, stderr discarded | **Make fatal** on `postflight`/`implement` (COMPLETED transition) | This is the exact case flagged in the task description as "a strong fatal candidate": if state.json reaches `completed` while the plan file silently stays at `[IMPLEMENTING]` (or worse, `[NOT STARTED]` if defect A/C compound it), there is NO user-visible surface that reveals the divergence — `generate-todo.sh` reads only state.json (confirmed: `generate-todo.sh` never reads plan files). A completed task with a demonstrably-wrong plan file is a worse outcome than a failed postflight that the caller can retry. |
| `update_plan_file()` -> `update-plan-status.sh` call, `implement` preflight (marking plan `[IMPLEMENTING]`) | Warning, non-fatal, stderr discarded | **Keep as warning**, but stop discarding stderr | Preflight marking is advisory/informational (work is starting either way); losing it is lower-stakes than losing the completion marker. Still worth surfacing loudly since it is the same code path as the fatal postflight case and a consistent policy is easier to reason about — but downgrading exit code to non-fatal on preflight avoids blocking legitimate implementation starts over a plan-file quirk (e.g., a plan predating the frozen `- **Status**:` anchor format). |
| `update_plan_file()` -> `update-phase-status.sh` call (auto-advance first phase, preflight only) | Warning, non-fatal, stderr discarded | **Keep as warning** (superseded by defect A fix) | Once defect A's fix makes the implementing agent itself the owning mechanism for all phase transitions (with the hard agent's proven Stage 5a self-repair loop as a backstop), this call site becomes a redundant convenience rather than the sole source of truth. A failure here is recoverable by the agent's own subsequent explicit calls. Still should stop discarding stderr. |
| **New (defect E scope)**: `map_status`/target_status validation rejecting `partial`/`blocked` | Hard validation error, exit 1 (this is correctly fatal already — the defect is that valid values are *rejected*, not that failures are silent) | N/A — this is a coverage gap, not a silence bug; see Defect E below | Distinct problem class from B. |

General principle for the decision table: failures that could leave **state.json and the plan file's terminal-facing status in permanent, externally-invisible disagreement** (i.e. affect what a human reading TODO.md or the plan believes about task completion) should be fatal or at minimum error-logged to `errors.json`; failures that are self-healing on the next successful invocation (TODO.md regeneration, the now-redundant phase auto-advance) can remain non-fatal warnings, but should stop discarding the underlying script's stderr via `2>/dev/null` so the warning is actually diagnosable.

### Defect C — Plan selection is mtime-ordered, not version-ordered

**Confirmed, with corrected line numbers and one additional undocumented occurrence:**
- `update-plan-status.sh`: `plan_file=$(ls -t "$plan_dir"/*.md 2>/dev/null | head -1)` is at **line 48** in the current file (task description said line 44 — off by 4 lines, likely due to intervening edits from task 877's vocabulary widening; behavior claim is otherwise exact).
- `update-phase-status.sh`: same pattern at **line 63**, confirmed exactly as described.
- **Undocumented third occurrence**: `update-task-status.sh:274`, inside the auto-advance-first-phase snippet: `plan_file=$(ls -t "$plan_dir"/*.md 2>/dev/null | head -1 || echo "")`. This independently re-resolves the "latest" plan file via the same mtime heuristic, moments after `update-plan-status.sh` (called just above it at line 256) already resolved and returned a plan file path — the two calls could theoretically diverge if a `.md` file's mtime changes between the two `ls -t` invocations (e.g., a concurrent edit), though in practice this is a low-probability race. Still, this is a third call site sharing the same defect class and is in-scope (the file is one of the three named scripts). Any fix to defect C should address all three, or `update-task-status.sh:274` should instead reuse the `plan_file` path already returned by the `update-plan-status.sh` invocation at line 256 rather than re-deriving it.
- Task 877's summary confirms it deliberately left `ls -t | head -1` untouched ("the fail-silent / `ls -t | head -1` plan-selection / phase-auto-advance behaviors were left untouched — these are deferred to a dependent hardening task"), i.e. this task. No conflicting concurrent edit risk from task 877.
- Recommended fix direction: select by parsed sequence number from the `MM_{short-slug}.md` filename convention (`.claude/rules/artifact-formats.md`'s "Unified Sequential Numbering" — files are named `01_...`, `02_...` etc., zero-padded, so a lexicographic sort of the *filename* rather than the *mtime* — e.g. `ls "$plan_dir"/*.md | sort | tail -1` — achieves version-ordering without parsing, since filenames already zero-pad the sequence number. No new script needed; this is a one-line change per call site.

### Defect D — Idempotency short-circuit skips the plan update

**Confirmed exactly as described**, and its interaction with task 876 is now materially more consequential than when task 878's description was authored:
- `update-task-status.sh:138-144`: `if [[ "$current_state_status" == "$STATE_STATUS" ]]; then ... exit 0; fi` — this check happens BEFORE `update_state_json()`, `regenerate_todo()`, and `update_plan_file()` are ever called. If state.json is already at the target status (by any path), the entire plan/phase update machinery is skipped, not just the state.json write.
- **Task 876 interaction (research requirement 3, confirmed)**: task 876 wired `skill_preflight_update()` into every research/plan/implement dispatch site on both `/orchestrate` paths (single-task and multi-task Stage MT-4, plus all `skill-orchestrate-hard` handlers). Task 876's own verification explicitly confirms it read and relied on this exact idempotency behavior: "`update-task-status.sh` lines 133-144 were read and confirmed to no-op when `current_state_status == STATE_STATUS`, before any state.json write." This means task 876 *intentionally* relies on defect D's current behavior to make its new preflight calls safe/idempotent (e.g., calling preflight once in the MT-4 per-task loop and again if the base single-task path also fires does not double-write state.json). **Task 878 must not break this idempotency contract for state.json** — the fix must scope the early-exit to state.json only, exactly as the task description specifies, so that a no-op state.json write can still independently drive a plan/phase update. This is fully compatible with task 876's usage: task 876 never depended on the *plan file* being skipped, only on state.json writes being deduplicated.
- Recommended fix: restructure so the idempotency check gates only `update_state_json()`, while `regenerate_todo()` and `update_plan_file()` always run (they are already independently idempotent — `update-plan-status.sh` and `update-phase-status.sh` each have their own idempotency checks, lines 56-59 and 90-94 respectively — so calling them on every invocation, even when state.json didn't change, is safe and correctly self-healing).

### Defect E — No task-level partial/blocked terminus

**Confirmed exactly as described:**
- `update-task-status.sh:69` (target_status validation): `if [[ "$target_status" != "research" && "$target_status" != "plan" && "$target_status" != "implement" && "$target_status" != "pr_ready" ]]` — admits exactly four values, no `partial` or `blocked`.
- `map_status()` (lines 89-97): exactly six `op:target` combinations handled, all mapping to `research*/plan*/implement*/pr_ready` state families — no `partial` or `blocked` case exists at all.
- `generate-todo.sh:125,127` confirmed to already render `blocked -> BLOCKED` and `partial -> PARTIAL` — the renderer is fully ready; only the writer (`update-task-status.sh`) lacks a sanctioned path.
- `status-markers.md` already documents `partial` and `blocked` as valid `state.json` status strings (lines 182-186 map `[PARTIAL]` -> `partial`, `[BLOCKED]` -> `blocked`) and documents the state-transition diagram allowing `[IMPLEMENTING] -> [PARTIAL]` on timeout/error (`.claude/rules/state-management.md`) — so this is a pre-existing documented vocabulary gap in the *script*, not a vocabulary decision this task needs to make (unlike defect A/B/C, which do interact with task 877's settled vocabulary).
- Recommended fix, per the task description: add `partial`/`blocked` to the line-69 validation, and add `postflight:partial -> STATE_STATUS=partial/TODO_STATUS=PARTIAL` and `postflight:blocked -> STATE_STATUS=blocked/TODO_STATUS=BLOCKED` cases to `map_status()`. Per the description, this must sit **outside** the defect D idempotency early-exit fix — i.e., a `partial`/`blocked` write is exactly the kind of state.json-status-changing operation defect D's restructuring must still allow through (it is not a same-status no-op in the scenarios that matter — a task moving from `implementing` to `partial` is a genuine status change, so it would pass the (correctly-scoped) idempotency check even before defect D's fix; defect E and defect D are complementary, not overlapping, fixes).

### Task 877 Vocabulary (for defect A/B correctness)

Task 877 settled the plan-level `- **Status**:` vocabulary to exactly six values: `{NOT STARTED, IMPLEMENTING, PARTIAL, BLOCKED, ABANDONED, COMPLETED}` (dropping the never-implemented `IN PROGRESS`). `update-plan-status.sh`'s case statement (lines 23-31 of the current file) already accepts all six (including `BLOCKED`/`ABANDONED`, added by task 877). Any defect B/D fix that adds new call sites passing plan-level status strings must use only these six values — never `IN PROGRESS` at the plan level. The phase-heading vocabulary used by `update-phase-status.sh` is deliberately narrower and different: `{NOT_STARTED, IN_PROGRESS, COMPLETED, PARTIAL, BLOCKED}` (no `ABANDONED` — task 877 documented this asymmetry explicitly: "no code path abandons a single phase while leaving siblings active"). Defect A's fix (wiring the base agent to call `update-phase-status.sh`) must use the phase-heading vocabulary, not the plan-level one — the two scripts already enforce their respective vocabularies independently and do not need harmonizing.

### `reconcile-task-status.sh` (research requirement 6)

Confirmed dead and out of scope: the script exists at `.claude/scripts/reconcile-task-status.sh` (and the mirrored `agent-system/extensions/core/scripts/reconcile-task-status.sh`), is registered in `agent-system/extensions/core/manifest.json`'s script list, but a repo-wide grep for `reconcile-task-status` finds no caller anywhere in `.claude/` or `agent-system/` outside the script's own file and its manifest registration. It is not wired into `update-task-status.sh`, `skill-orchestrate`, or any other operational path. Per the delegation instructions, this task does not touch it.

## Decisions

- Treat "own phase markers" (defect A) primarily as a **prompt-wiring fix** to `general-implementation-agent.md`, using `general-implementation-hard-agent.md`'s existing Stage 4A/4D/5a pattern as the template, rather than a change to `update-phase-status.sh`'s already-adequate per-phase interface.
- Treat defect B's fix at the `update-plan-status.sh` anchor site as "stop the caller from discarding an already-fail-loud script," not "make the script fail loudly" (it already does).
- Recommend defect C be fixed via filename-lexicographic sort (`sort` on the zero-padded `MM_` prefix) rather than parsing/comparing version numbers explicitly — no new script logic needed, and it naturally fixes the additional third occurrence at `update-task-status.sh:274`.
- Defect D and defect E are complementary: defect D's fix (scope idempotency to state.json only) is a prerequisite that makes the plan/phase file updates fire even on a state.json no-op; defect E's fix (add `partial`/`blocked` target_status values) is orthogonal — a genuine status change from `implementing` to `partial` was never blocked by the current idempotency check in the first place, since it's not a same-status no-op.

## Risks & Mitigations

- **Risk**: editing `.claude/` copies only (not `agent-system/extensions/core/`) would produce a change that appears to work in the current session but is silently discarded/overwritten on the next redeploy, since `.claude/` is gitignored. **Mitigation**: the implementation plan must explicitly target `agent-system/extensions/core/{scripts,agents}/...` as the primary edit location and mirror to `.claude/`, exactly as tasks 876/877 did (both documented this as a "source-of-truth correction during implementation").
- **Risk**: making the `update-plan-status.sh` call fatal on `implement` postflight (defect B recommendation) could cause the entire postflight to fail on a legitimately malformed/legacy plan file that predates the `- **Status**:` anchor convention, blocking task completion entirely. **Mitigation**: this is a narrow, well-scoped failure mode (only fires if the anchor line is genuinely absent), and the task description itself flags this as "a strong fatal candidate" — accept the risk, since a completed task with a silently-wrong plan file is the more expensive failure mode this whole task exists to eliminate.
- **Risk**: wiring `update-phase-status.sh` into the base agent duplicates the hard agent's contract; future edits to phase-transition logic must update both files. **Mitigation**: none needed structurally — this mirrors the existing intentional duplication between `general-implementation-agent.md` and `general-implementation-hard-agent.md` (the hard agent is a documented superset/variant of the base agent's contract, not a shared library), consistent with how the rest of the two files already relate.

## Context Extension Recommendations

- None — this is a meta task and defect-fix scope; no new context files are indicated. The existing `status-markers.md` and `plan-format.md` documentation (updated by task 877) already covers the vocabulary this task's fixes must respect.

## Appendix

### Search queries / verification commands used

```bash
ls -la .agent-logs/                                  # confirmed phase-transitions.log absent
grep -n "update-phase-status" .claude/agents/general-implementation-agent.md   # zero matches
grep -n "update-phase-status" .claude/agents/general-implementation-hard-agent.md  # lines 155,171,233 + section headers
grep -rn "reconcile-task-status" .claude/             # only self-reference + manifest registration
diff -q .claude/scripts/update-task-status.sh agent-system/extensions/core/scripts/update-task-status.sh   # identical
diff -q .claude/scripts/update-plan-status.sh agent-system/extensions/core/scripts/update-plan-status.sh   # identical
diff -q .claude/scripts/update-phase-status.sh agent-system/extensions/core/scripts/update-phase-status.sh # identical
diff -q .claude/agents/general-implementation-agent.md agent-system/extensions/core/agents/general-implementation-agent.md  # identical
grep -n "partial\|blocked\|PARTIAL\|BLOCKED" .claude/scripts/generate-todo.sh   # lines 125,127 confirm renderer readiness
```

### References

- `.claude/scripts/update-task-status.sh` (301 lines)
- `.claude/scripts/update-plan-status.sh` (72 lines)
- `.claude/scripts/update-phase-status.sh` (120 lines)
- `.claude/agents/general-implementation-agent.md` (548 lines)
- `.claude/agents/general-implementation-hard-agent.md` (lines 140-239 read in detail)
- `.claude/context/standards/status-markers.md`
- `.claude/context/formats/plan-format.md`
- `.claude/rules/state-management.md`
- `specs/877_settle_plan_status_marker_vocabulary/summaries/01_settle-plan-status-vocabulary-summary.md`
- `specs/876_wire_preflight_into_orchestrate_paths/summaries/01_wire-preflight-orchestrate-summary.md`
- `agent-system/extensions/core/manifest.json`

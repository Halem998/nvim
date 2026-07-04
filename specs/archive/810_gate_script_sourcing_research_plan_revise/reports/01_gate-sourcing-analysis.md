# Research Report: Task #810

- **Task**: 810 - Follow-up from task 788: refactor /research, /plan, /revise to source command-gate-in.sh / command-gate-out.sh
- **Started**: 2026-07-04T20:00:00Z
- **Completed**: 2026-07-04T20:06:00Z
- **Effort**: ~2 hours (research only)
- **Dependencies**: 788 (task-lock.sh + command-gate-in.sh/out.sh baseline), 808 (init-marker; explicitly deferred `.postflight-pending` lock-coverage gap to this task), 809 (cross-task `file_scope` overlap check inside `cmd_acquire`)
- **Sources/Inputs**: Codebase (`.claude/commands/{research,plan,revise,implement,orchestrate}.md`, `.claude/scripts/{command-gate-in,command-gate-out,task-lock,update-task-status,validate-artifact}.sh`, `.claude/skills/skill-reviser/SKILL.md`, `.claude/context/patterns/task-lock.md`), live working-tree state for tasks 804/808/809 (uncommitted), `specs/808_.../reports/01_marker-file-atomicity-audit.md` and `specs/808_.../plans/02_atomic-marker-plan.md`
- **Artifacts**: This report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- `command-gate-in.sh`/`command-gate-out.sh` (task 788) are sourced today only by `implement.md` and `orchestrate.md`. `research.md`, `plan.md`, and `revise.md` still carry fully inline, duplicated CHECKPOINT 1/CHECKPOINT 2 logic and never touch `task-lock.sh` — confirmed by direct inspection, not inferred from docs.
- **`revise.md` cannot swap in `command-gate-in.sh` unmodified**: `skill-reviser`'s design contract is "no status-based ABORT rules — the skill works regardless of task status," but `command-gate-in.sh`'s terminal-status guard unconditionally rejects `completed`/`abandoned`/`expanded` tasks. The gate script needs an operation-aware exemption (`revise` skips the guard) to preserve this behavior; a naive swap is a regression.
- `command-gate-out.sh`'s defensive-correction `case "$operation"` has no `revise` arm (falls to `expected_status=""`, a silent no-op) and, more importantly, its status-token call at line 81 passes `$operation` directly as `update-task-status.sh`'s `target_status`, which only accepts `research|plan|implement|pr_ready`. Adding `revise` naively (passing `"revise"` as target_status) would hit `update-task-status.sh`'s validation error. This exact bug already exists latently for `orchestrate` (also not a valid `target_status`) — currently masked because that branch is only reached on desync.
- `command-gate-out.sh`'s "non-blocking artifact validation (link repair)" step is **already dead code**: it calls `validate-artifact.sh "$task_dir" --fix`, but `validate-artifact.sh` requires a **file** path plus a `report|plan|summary` type positional arg — passing a directory and `--fix` (treated as the type) always fails closed (`exit 3`, swallowed by `2>/dev/null || true`). Reproduced directly. Research/plan/revise MUST keep their own inline artifact-existence checks; gate-out's link-repair leg contributes nothing today regardless of whether these three commands adopt it.
- `command-gate-in.sh`/`out.sh` are identical byte-for-byte between `.claude/scripts/` and `.claude/extensions/core/scripts/`, and `research.md`/`plan.md`/`revise.md` are identical byte-for-byte between `.claude/commands/` and `.claude/extensions/core/commands/`. These are the dual-copy pairs this refactor must keep in sync (6 command files total, 3 logical commands × 2 trees). The `.opencode/` tree is **not** a dual-copy pair for this task: it has no `task-lock.sh` at all, and even `.opencode/commands/implement.md` never sources `.opencode/scripts/command-gate-in.sh`'s lock logic (that script also lacks the task-788 lock block). `.opencode` is a pre-existing, already-diverged system, out of scope.
- `.claude/context/patterns/task-lock.md` already documents (lines 219-221) `/research`, `/plan`, `/revise` as covered "Single-task gate scripts" consumers — this is aspirational/already-written for the end state this task produces; **no update to that doc is needed** once the refactor lands.
- `research.md`'s and `plan.md`'s MULTI-TASK DISPATCH loops have **zero** lock acquire/release calls today (unlike `implement.md`'s Step 3, added by 788). This is a second, distinct gap beyond the single-task CHECKPOINT path and should be closed in the same task for coherence, mirroring `implement.md`'s exact per-task acquire/release bracketing. `revise.md` has no multi-task mode, so this does not apply to it.
- `.postflight-pending` (written by `skill-researcher`/`skill-planner`/`skill-reviser`/hard variants, ~line 87-95 of each `SKILL.md`) has no direct interaction with `command-gate-in.sh`/`out.sh` — it is written *during* skill execution, which happens *inside* the window between gate-in's acquire and gate-out's release once this refactor lands. No code change to the marker-writing sites is needed; the lock coverage is inherited transitively by narrowing the previously-unprotected window around the whole command invocation.

## Context & Scope

Scope per delegation: research only (no `.claude/` edits). Investigate the exact inline gate logic in `research.md`/`plan.md`/`revise.md` versus `command-gate-in.sh`/`command-gate-out.sh`, produce a field-by-field diff, identify what must be preserved per-command, document lock/heartbeat/exit-code handling including task 809's overlap-refusal path, assess `.postflight-pending` coverage, enumerate all dual-copy pairs, and give a concrete refactor recommendation. Batch context (804/808/809, all live/uncommitted in the working tree) was read from the current filesystem state, not git HEAD, per instructions.

## Findings

### 1. Exact inline gate logic today (file:line)

**`.claude/commands/research.md`**:
- CHECKPOINT 1: GATE IN, lines 237-265. Inline: session ID gen (`sess_$(date +%s)_...`), `jq` task lookup (lines 251-253), terminal-status ABORT check (implicit in prose, no explicit code block), no lock acquire.
- CHECKPOINT 2: GATE OUT, lines 422-471. Inline: artifact-existence check (prose, step 2), state.json defensive correction via `update-task-status.sh postflight "$task_number" research "$session_id"` (lines 440-450, functionally equivalent to what `command-gate-out.sh` already automates), TODO.md defensive correction via manual grep+Edit-tool fallback (lines 452-467, redundant with what `update-task-status.sh`'s internal `generate-todo.sh` call already accomplishes).
- No lock acquire/release/heartbeat anywhere in the file. `MULTI-TASK DISPATCH` (Step 3, lines 158-168) also has none.

**`.claude/commands/plan.md`**:
- CHECKPOINT 1: GATE IN, lines 238-273. Same shape as research.md's, plus plan-specific "Load Context" step (research reports, prior plan discovery, lines 262-269) that has no gate-script equivalent and must stay inline.
- CHECKPOINT 2: GATE OUT, lines 427-498. Same state.json/TODO.md defensive-correction duplication as research.md (lines 439-472), plus a **plan-specific** step 6 (plan-file-status verification, lines 474-494) that has no gate-script equivalent and must stay inline.
- No lock acquire/release/heartbeat. `MULTI-TASK DISPATCH` (Step 3, implied by the file's batch section) also has none.

**`.claude/commands/revise.md`**:
- CHECKPOINT 1: GATE IN, lines 21-51. Inline session ID gen, `jq` lookup, and an **explicit, deliberate absence of a terminal-status guard**: "No other ABORT conditions. The command works regardless of task status." (line 38). Plus a revise-specific plan-existence check (lines 40-45) with no gate-script equivalent.
- CHECKPOINT 3: GATE OUT (labelled 3, not 2 — revise's DELEGATE is CHECKPOINT 2), lines 80-117. State.json/TODO.md defensive correction duplicated exactly as research/plan's, scoped to "Plan Revision only" (the description-update path intentionally skips all of this).
- No lock acquire/release. No multi-task mode exists for `/revise` (single task number only, per Arguments section).

### 2. What `command-gate-in.sh` / `command-gate-out.sh` actually provide

`command-gate-in.sh` (sourced, exports vars):
- `SESSION_ID`, `PADDED_NUM`, task lookup (`TASK_TYPE`, `TASK_STATUS`, `PROJECT_NAME`, `DESCRIPTION`), terminal-status guard (`completed|abandoned|expanded` → return 1, **unconditionally, no operation exemption**), task-lock acquire (`task-lock.sh acquire "$task_number" "$operation" "$SESSION_ID" "/$operation $task_number"`, return 1 on refusal), header echo `[$OP_LABEL] Task {N}: {project_name}` where `OP_LABEL` = uppercased `$operation` verbatim (e.g. `[RESEARCH]`, `[PLAN]`, `[REVISE]` — not the present-participle style `[Researching]`/`[Planning]` currently documented in research.md/plan.md's headers).

`command-gate-out.sh` (subprocess call):
- Unconditional `task-lock.sh release "$task_number" "$session_id"` (line 37) — runs first, before anything else, idempotent, matches contract in `task-lock.md`.
- Reads `.return-meta.json`, maps `operation` → `expected_status` (`research→researched`, `plan→planned`, `implement→completed`, `orchestrate→completed`; anything else → `""`, no-op).
- If skill status is `implemented|researched|planned` and current state.json status doesn't match `expected_status`, calls `update-task-status.sh postflight "$task_number" "$operation" "$session_id"` — **passes `$operation` directly as `update-task-status.sh`'s `target_status` positional arg**, which only validates `research|plan|implement|pr_ready`. This already works for `research`/`plan`/`implement` (the strings happen to coincide) but is a latent bug for `orchestrate` (not a valid `target_status`) and would be a bug for a naively-added `revise` arm too.
- Non-blocking `validate-artifact.sh "$task_dir" --fix` — confirmed dead code (see Executive Summary; reproduced with a throwaway directory, exits 3, swallowed).

### 3. Field-by-field diff: inline vs. shared gate

| Capability | Inline today (research/plan/revise) | `command-gate-in.sh`/`out.sh` | Verdict |
|---|---|---|---|
| Session ID generation | Duplicated 3× | Provided | **Gained**: single source, matches implement.md's format exactly |
| Task lookup (jq) | Duplicated 3× (slightly different jq idiom, same result) | Provided | **Gained** |
| Terminal-status guard | research/plan: block `completed\|abandoned\|expanded` (matches gate-in). revise: explicitly **does not** block any status. | Unconditional block, no exemption | **Conflict for revise only** — must add an operation-aware exemption to `command-gate-in.sh` (see Recommendation) |
| Task lock acquire (788) | Absent in all 3 | Provided | **Gained** — this is the core of the task |
| Task lock release (788) | Absent in all 3 | Provided, unconditional | **Gained** |
| Heartbeat refresh | Absent (also absent from `skill-researcher`/`skill-planner`/`skill-reviser` internals) | Not part of gate-in/out either (heartbeat is emitted from inside long-running phase loops, e.g. `general-implementation-agent.md`, `skill-orchestrate/SKILL.md`) | **Unchanged** — research/plan/revise are one-shot dispatches, not phase loops; a stale-after-30-min risk exists only for very long `--hard`/`--team` runs. Not a regression from today (today there's no lock to go stale at all); worth a follow-up note, not a blocker. |
| 809 cross-task `file_scope` overlap check | N/A (no lock = no check today) | Automatically inherited via `cmd_acquire`, mutex-guarded | **Gained** — see §4 |
| Defensive state.json correction | Inline, functionally identical to what gate-out does for research/plan | Provided for research/plan; **needs a `revise` arm with a distinct `target_status` token, not `$operation` verbatim** | **Composable with one fix** (see Recommendation) |
| Defensive TODO.md correction | Inline manual Edit-tool fallback | Achieved as a **side effect** of `update-task-status.sh`'s internal `generate-todo.sh` call, not a separate step | **Redundant, can be dropped** once gate-out's correction call fires (same as implement.md, which has no separate TODO.md-fix Edit-tool step) |
| Artifact-existence verification (research: step 2; plan: none explicit beyond plan-file check) | Inline prose | **Not provided** (validate-artifact.sh call is dead code) | **Must stay inline** — cannot be delegated to gate-out |
| Plan-file-status verification (plan.md step 6) | Inline | Not provided | **Must stay inline** (plan-specific) |
| Load Context / prior-plan discovery (plan.md step 4) | Inline | Not provided | **Must stay inline** (plan-specific) |
| Plan-existence check (revise.md step 4) | Inline | Not provided | **Must stay inline** (revise-specific, drives Plan-Revision vs Description-Update routing) |
| Header wording | `[Researching]`, `[Planning]` (present-participle, title case) | `[RESEARCH]`, `[PLAN]`, `[REVISE]` (uppercase verbatim operation) | **Cosmetic behavior change** — matches implement's `[IMPLEMENT]` style; acceptable, should be called out explicitly in the plan so it isn't mistaken for a defect |
| Multi-task per-task lock (research/plan batch loops) | **Absent** | N/A (gate scripts are single-task only; `implement.md`'s multi-task loop bypasses them and calls `task-lock.sh acquire/release` directly per task) | **Gap to close alongside this refactor**, mirroring `implement.md` Step 3 exactly, for research.md and plan.md (revise has no multi-task mode) |

### 4. Lock / heartbeat / exit-code handling, including 809's overlap path

`command-gate-in.sh`'s `return 1` on lock refusal is a single, undifferentiated failure mode from the caller's perspective — it does not distinguish "terminal status" ABORT from "lock held by another session" ABORT from "cross-task `file_scope` overlap" ABORT (task 809). All three cases print an `ABORT:`/`ERROR:` message to stderr and return non-zero; `command-gate-in.sh` itself returns 1 in the first two cases and propagates whatever `task-lock.sh acquire` returns (1 for both same-task-different-session refusal and 809's fresh-overlap refusal; 2 for usage/task-not-found errors, e.g. `resolve_task_dir` failing).

Once research/plan/revise source `command-gate-in.sh`, they inherit **all** of `cmd_acquire`'s refusal surface automatically, including 809's new cross-task overlap check, with no code change needed in `command-gate-in.sh` itself for that part (809's check lives entirely inside `task-lock.sh acquire`, called generically). Concretely, for these three commands:
- If task N's `file_scope` overlaps a *different*, currently-locked task M's `file_scope`, and M's lock is fresh (heartbeat within `TASK_LOCK_STALE_MIN`, default 30 min), `/research N` (or `/plan N`, `/revise N`) will now ABORT before ever reaching STAGE 1.5/DELEGATE — a **new** refusal mode these three commands did not have before (today they have no lock, so they can never be refused by another task's overlap).
- If M's lock is stale, `/research N` proceeds with a `WARN:` (non-blocking), same as any other consumer.
- **UX implication to document for users**: `/research`, `/plan`, and `/revise` invocations can now fail fast with an `ABORT:` message referencing a *different* task number's lock and `file_scope`, which will be a new and possibly surprising failure mode for these three (previously lock-free) commands. The command files' "GATE IN Failure" Error Handling sections should be updated to mention this explicitly (today they only mention "task not found" / "invalid status").
- Exit-code contract to preserve exactly (from `task-lock.sh`'s header comment, unchanged by this task): `acquire` 0/1/2, `heartbeat` 0/2 (never blocks caller), `release` always 0, `check` 0/1/2/3. `command-gate-in.sh` propagates `acquire`'s 1/2 as its own return value; the calling command `.md` files should treat both as ABORT (task 788 precedent in `implement.md` and `orchestrate.md` does not differentiate 1 vs 2 either).

### 5. `.postflight-pending` coverage

Confirmed (per task 808's report, which explicitly deferred this to task 810): `.postflight-pending` is written unconditionally (`cat > ... << EOF`, no create-vs-resume branch) by each research/plan/revise `SKILL.md` (`skill-researcher/SKILL.md:87`, `skill-planner/SKILL.md:95`, `skill-reviser/SKILL.md:80`, and their `-hard` variants) during Stage 3 of skill execution — i.e., strictly *inside* the window between the command's DELEGATE step and its GATE OUT step. It has no atomicity bug of its own (808's finding: "not a TOCTOU category... worst case is a last-write-wins content clobber"). Its actual exposure is that this write currently happens with **no session lock held at all** for `/research`/`/plan`/`/revise`, so two concurrent sessions on the same task could both write `.postflight-pending` with different `session_id`s, and whichever writes last silently wins — undetected. Once this task wires `command-gate-in.sh`'s acquire into these three commands, the write falls inside the acquired lock's window (acquire happens in GATE IN before DELEGATE; release happens in GATE OUT after DELEGATE), so a second session attempting the same task will be refused *before* it ever reaches its own `.postflight-pending` write. **No change to any `.postflight-pending` call site is needed** — the fix is entirely at the command level, exactly as 808's report anticipated.

### 6. Dual-copy pairs affected

Confirmed identical (byte-for-byte `diff`, zero output) before any edit:

| Pair | Files |
|---|---|
| research.md | `.claude/commands/research.md` ↔ `.claude/extensions/core/commands/research.md` |
| plan.md | `.claude/commands/plan.md` ↔ `.claude/extensions/core/commands/plan.md` |
| revise.md | `.claude/commands/revise.md` ↔ `.claude/extensions/core/commands/revise.md` |

Both `.claude/scripts/command-gate-in.sh` ↔ `.claude/extensions/core/scripts/command-gate-in.sh`, and `command-gate-out.sh`'s pair, and `task-lock.sh`'s pair, are also already identical — so if `command-gate-in.sh`/`command-gate-out.sh` need edits (the revise terminal-guard exemption, the `revise`/`orchestrate` target_status fix), **both copies in each script pair must be edited identically** (6 files touched: 3 command `.md` pairs + up to 2 script pairs, depending on how many script fixes are adopted).

**`.opencode/` is explicitly NOT a dual-copy pair for this task.** Verified: `.opencode/scripts/` has no `task-lock.sh` at all; `.opencode/scripts/command-gate-in.sh` exists but lacks the entire task-788 lock-acquire block (diffed directly — the `.claude` version has an extra ~8-line lock block the `.opencode` version does not); `.opencode/commands/implement.md` does not source `command-gate-in.sh`/`command-gate-out.sh` at all (still fully inline), even though `.claude/commands/implement.md` does. The `.opencode` tree is a separate, already-diverged system whose gate/lock migration (if ever undertaken) is a distinct, larger task outside 810's territory — task 788 itself did not extend to `.opencode`, so 810 should not either.

### 7. Adjacent duplication noticed but out of scope

`research.md` and `plan.md` both inline a `parse_task_args()` bash function in their STAGE 0 (nearly identical to each other, ~30 lines each) rather than sourcing the shared `.claude/scripts/parse-command-args.sh` that `implement.md` already uses (`source .claude/scripts/parse-command-args.sh "$ARGUMENTS"`). Similarly, both inline the extension-routing lookup loop in STAGE 2 rather than sourcing `.claude/scripts/command-route-skill.sh`, which `implement.md` already uses. These are real, analogous duplication patterns (task-parsing and skill-routing, not gate/lock logic) and could be a natural follow-up task for the same "one shared path" goal, but they are **not** "CHECKPOINT gate logic" and the delegation scope for 810 is specifically GATE IN/GATE OUT sourcing. Recommend noting this as a candidate follow-up rather than folding it into 810's plan.

## Decisions

- Treat `.opencode/` as out of scope for this task (no dual-copy obligation there; pre-existing, larger divergence).
- Treat the `parse-command-args.sh`/`command-route-skill.sh` STAGE 0/STAGE 2 duplication as a separate, adjacent concern — not part of this refactor's territory.
- Recommend fixing `command-gate-out.sh`'s `target_status` bug (currently latent for `orchestrate`, would be newly triggered for a naive `revise` arm) as part of this task's plan, since the plan will already be touching that exact `case` statement.

## Recommendations

1. **`command-gate-in.sh`**: add an operation-aware exemption to the terminal-status guard so `revise` never gets rejected, e.g.:
   ```bash
   case "$TASK_STATUS" in
     completed|abandoned|expanded)
       if [ "$operation" != "revise" ]; then
         echo "ABORT: ..." >&2
         return 1
       fi
       ;;
   esac
   ```
   This must land in both `.claude/scripts/command-gate-in.sh` and `.claude/extensions/core/scripts/command-gate-in.sh` identically. This is the one non-optional script change — without it, sourcing gate-in from `revise.md` silently breaks `skill-reviser`'s documented "works regardless of task status" contract.

2. **`command-gate-out.sh`**: add a `revise` arm to the `case "$operation"` block and stop passing `$operation` verbatim as `update-task-status.sh`'s `target_status`. Introduce a second variable (`status_token`) so `research→research`, `plan→plan`, `implement→implement`, `revise→plan`, and fix `orchestrate→implement` (currently broken) in the same edit, e.g.:
   ```bash
   case "$operation" in
     research)    expected_status="researched"; status_token="research" ;;
     plan)        expected_status="planned";    status_token="plan" ;;
     implement)   expected_status="completed";  status_token="implement" ;;
     orchestrate) expected_status="completed";  status_token="implement" ;;
     revise)      expected_status="planned";    status_token="plan" ;;
     *)           expected_status="" ;;
   esac
   ...
   update-task-status.sh postflight "$task_number" "$status_token" "$session_id"
   ```
   Note this composes correctly with revise's description-update path: `skill-reviser` reports `status="description_updated"` for that path, which is outside the `implemented|researched|planned` gate at line 71-72, so the correction never fires for description updates — exactly the desired behavior (no defensive correction should apply when there's no "planned" state to defend). This is a pre-existing bug fix (the `orchestrate` mapping) bundled with the new `revise` arm since both touch the same 6-line block; flag it to the planner as an explicit, deliberate inclusion rather than silent scope creep.

3. **`research.md` / `plan.md` / `revise.md`**: mirror `implement.md`'s exact pattern —
   - CHECKPOINT 1: replace inline session/lookup/terminal-guard logic with `source .claude/scripts/command-gate-in.sh "$task_number" "{research|plan|revise}"`, keep each command's own extra GATE IN steps (plan's "Load Context", revise's plan-existence check) immediately after.
   - CHECKPOINT 2 (research/plan) / CHECKPOINT 3 (revise): replace the inline state.json/TODO.md defensive-correction block with `bash .claude/scripts/command-gate-out.sh "$task_number" "{research|plan|revise}" "$SESSION_ID"`, drop the now-redundant manual TODO.md Edit-tool fallback, and **keep** the artifact-existence check, plan-file-status check, and revise's plan-only-vs-description-update conditioning as command-specific supplementary steps (matching how `implement.md` keeps its completion-summary/plan-status/TODO.md steps after calling `command-gate-out.sh`).
   - Update each command's "GATE IN Failure" Error Handling section to mention the new lock-refusal and cross-task-overlap-refusal failure modes (§4).
   - Update research.md/plan.md header display expectations from `[Researching]`/`[Planning]` to `[RESEARCH]`/`[PLAN]` (cosmetic, matches gate-in.sh's mechanical uppercasing and `[IMPLEMENT]`'s precedent) — call this out explicitly as an intentional behavior change in the plan/summary so it isn't flagged as a regression later.
   - Add per-task `task-lock.sh acquire`/`release` bracketing to `research.md`'s and `plan.md`'s MULTI-TASK DISPATCH loops, copying `implement.md`'s Step 3 pattern verbatim (acquire before each skill invocation with `"${batch_session_id}_${task_num}"` as session id, skip-with-reason on refusal, unconditional release after).
   - Apply every change identically to the `.claude/extensions/core/commands/` mirror of each file (byte-for-byte, per §6).

4. **No changes needed** to: `.claude/context/patterns/task-lock.md` (already documents the target end-state), any `.postflight-pending` call site (coverage is inherited transitively, §5), `.opencode/*` (out of scope, §6), or `validate-artifact.sh` (its dead-code status is pre-existing and orthogonal — worth a separate bug-fix task, but not a blocker for 810, since research/plan/revise already keep their own inline artifact checks regardless of gate-out's broken leg).

## Risks & Mitigations

- **Risk**: Forgetting the `revise` terminal-guard exemption breaks `/revise` on abandoned/completed tasks (a documented, load-bearing capability). **Mitigation**: explicit plan-phase acceptance test — `/revise` on a task with `status: abandoned` must still succeed after the refactor.
- **Risk**: Bundling the `orchestrate` `target_status` bug fix expands this task's apparent diff footprint beyond "just research/plan/revise." **Mitigation**: call it out explicitly as a deliberate, minimal, same-block fix in the plan and commit message; it does not change `orchestrate.md`'s or `implement.md`'s call sites, only the internal mapping.
- **Risk**: Dual-copy drift if the `.claude/extensions/core/` mirrors are edited inconsistently. **Mitigation**: diff-verify all pairs post-edit (as done in this report) before considering the task complete.
- **Risk**: New cross-task overlap ABORTs on `/research`/`/plan`/`/revise` surprise users who never saw this failure mode before. **Mitigation**: update each command's Error Handling section (recommendation 3) so the new failure mode is documented where users would look.

## Appendix

- Commands run: `diff` across all `.claude/commands/*` ↔ `.claude/extensions/core/commands/*` pairs and `.claude/scripts/*` ↔ `.claude/extensions/core/scripts/*` pairs (all identical, zero-diff); reproduction of the `validate-artifact.sh "$dir" --fix` dead-code path with a throwaway directory (`exit 3`); `find`/`grep` for `task-lock.sh heartbeat` call sites; read of `specs/808_loop_guard_atomic_creation/reports/01_marker-file-atomicity-audit.md` and `plans/02_atomic-marker-plan.md` for the 808→810 territory hand-off note.
- Key files read in full or near-full: `.claude/scripts/command-gate-in.sh`, `.claude/scripts/command-gate-out.sh`, `.claude/scripts/task-lock.sh` (all 546 lines), `.claude/scripts/update-task-status.sh` (validation section), `.claude/scripts/validate-artifact.sh` (argument-parsing section), `.claude/commands/research.md` (full), `.claude/commands/plan.md` (relevant sections), `.claude/commands/revise.md` (full), `.claude/commands/implement.md` (full), `.claude/context/patterns/task-lock.md` (Consumers/Non-Goals/Related Documentation sections).

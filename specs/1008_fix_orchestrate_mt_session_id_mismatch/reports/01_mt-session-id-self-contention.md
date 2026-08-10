# Research Report: Task #1008

**Task**: 1008 - fix_orchestrate_mt_session_id_mismatch
**Started**: 2026-08-10T13:54:08Z
**Completed**: 2026-08-10T14:40:00Z
**Effort**: small (2 required one-line edits + 1 recommended one-line edit + a new test group)
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (source-store; deployed copy at `.claude/skills/skill-orchestrate/SKILL.md` is a build artifact, not edited directly)
- `agent-system/extensions/core/scripts/task-lock.sh`
- `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh`
- `agent-system/extensions/core/context/patterns/task-lock.md`
- `agent-system/extensions/core/agents/general-implementation-agent.md`
- `agent-system/extensions/core/commands/{research,plan,implement}.md`
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh`, `test-session-registry.sh`
- `specs/errors.json` (err_1786349061524_pY97cE)
**Artifacts**:
- this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Root cause confirmed**: Stage MT-1 (`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md:1418`) registers the batch's in-flight session under the **bare** `$session_id` via `task-lock.sh session-register`. Stage MT-4 (`SKILL.md:1960` acquire, `SKILL.md:2388` release) instead calls `task-lock.sh acquire`/`release` with the **task-suffixed** `${session_id}_${task_num}`. `session_contention()`'s self-exclusion (`lib/file-scope-overlap.sh:115`, `select($sess.session_id != $own_sid)`) is an exact string match, so it never fires for the batch's own registration, and every per-task lock acquire sees its own batch-registered session (whose `file_scope` is the UNION of every task's scope) as a genuinely foreign, live, overlapping session. Every task in every multi-task `/orchestrate` batch is refused at Stage MT-4's very first lock acquire — this is a total, deterministic block, not an intermittent race.
- **The batch-admission call (Stage MT-3, `SKILL.md:1628`) is correct** — it already passes the bare `$session_id` to `orchestrate-batch-admit.sh --session-id`, matching MT-1's registration. Only the Stage MT-4 lock acquire/release pair diverges.
- **Minimal required fix**: change `SKILL.md:1960` and `SKILL.md:2388` from `"${session_id}_${task_num}"` to `"$session_id"` (the same bare value MT-1 registered and MT-3 already uses).
- **A second, currently-latent site was found during this research** that the same "unify... across the stages that acquire and later reference the task lock" instruction covers: `SKILL.md:2002`'s `implement_agents[task_num]` dispatch context still sets `session_id: "${session_id}_${task_num}"`, and `general-implementation-agent.md:275`'s per-phase `task-lock.sh heartbeat "{task_number}" "{session_id}"` call reuses that same field verbatim. After the minimal fix above, the lock's holder would be the bare session_id, but a multi-phase implement dispatch's heartbeat call would still present the suffixed id — `cmd_heartbeat` would silently no-op (WARN, never blocks) instead of refreshing, letting a long-running multi-task-orchestrated implementation's lock go stale and become override-eligible mid-run. This should be fixed in the same change (see Decisions).
- **Same architectural pattern, likely same latent bug, in `commands/research.md`, `commands/plan.md`, `commands/implement.md`** (register under bare `batch_session_id`, acquire under `${batch_session_id}_${task_num}`) — explicitly out of scope for this task (TARGET is `skill-orchestrate/SKILL.md` only) but flagged as a follow-up candidate under Risks & Mitigations.
- **Regression test recommendation**: extend `agent-system/extensions/core/scripts/test-conflict-predicate.sh` (already an isolated-temp-root suite exercising `task-lock.sh`'s `cmd_acquire` session-registry pass against a fixture `state.json`) with a new group that runs the real `session-register` CLI (mirroring Stage MT-1) followed by a real `acquire` CLI call (mirroring Stage MT-4), asserting exit 0 under the bare id (post-fix behavior) and exit 1 under the suffixed id (pre-fix regression reproduction). No manifest change needed — the file is already listed in `core/manifest.json`'s `provides.scripts`.

## Context & Scope

Task 1008 targets a single file, `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`, at the two construction sites the task description labels "MT-1" and "MT-4" (this file's own Stage headings). The task is recorded as `err_1786349061524_pY97cE` (severity critical, type `lock_session_self_contention`) in `specs/errors.json`, discovered during a prior capstone acceptance-gate dispatch. Three sibling tasks in `specs/state.json` are explicitly gated on this one landing first (their `CONSTRAINT` lines name `err_1786349061524_pY97cE` as a blocking prerequisite), so this task sits on the critical path for multi-task `/orchestrate` and for those three follow-ups.

Per the task's own constraint, this research was conducted read-only, using single-task tooling (no multi-task `/orchestrate` was invoked, since that is the mechanism under investigation as broken).

## Findings

### Codebase Patterns

**The two named construction sites, verbatim:**

1. **Stage MT-1** (`SKILL.md:1409-1419`), under "In-flight session registry":
   > "register the batch under the bare `session_id` this stage received, with the full `task_numbers` set as the CSV."
   ```bash
   bash .claude/scripts/task-lock.sh session-register "$session_id" "/orchestrate (multi-task)" "$(IFS=,; echo "${task_numbers[*]}")" 2>/dev/null || true
   ```
   `cmd_session_register` (`task-lock.sh:1213-1263`) writes `specs/.sessions/{session_id}.json` with `session_id` = the bare argument, and `file_scope` = the deduplicated **union** of `get_file_scope(tn)` for every `tn` in `task_numbers` — i.e. one registry entry per batch, covering every task's own file_scope, keyed under the bare id.

2. **Stage MT-3** (`SKILL.md:1614-1628`), the per-cycle admission call, **correctly** reuses the same bare id:
   > "the SAME bare `session_id` Stage MT-1 registered via `session-register` above, so this call's self-exclusion actually matches the batch's own registry entry rather than seeing it as foreign and deferring every candidate against itself"
   ```bash
   bash .claude/scripts/orchestrate-batch-admit.sh --invocation-count "${#eligible_tasks[@]}" --session-id "$session_id" "${eligible_tasks[@]}"
   ```

3. **Stage MT-4** (`SKILL.md:1953-1965`), the per-task lock acquire, **diverges**:
   ```bash
   bash .claude/scripts/task-lock.sh acquire "$task_num" "$op" "${session_id}_${task_num}" "/orchestrate (multi-task)"
   ```
   and its matching release (`SKILL.md:2385-2388`):
   ```bash
   bash .claude/scripts/task-lock.sh release "$task_num" "${session_id}_${task_num}"
   ```

**Why the mismatch causes a guaranteed, not probabilistic, refusal.** `cmd_acquire` (`task-lock.sh:603-730`) runs a session-registry contention pass (`task-lock.sh:657-686`) that calls `session_contention($cscope; $cnum; $own_sid; $all; $sessions)` (`lib/file-scope-overlap.sh:109-141`) with `$own_sid` bound to the acquire call's own `session_id` argument (`${session_id}_${task_num}` today). `session_contention()`'s three D4 exclusions run in order:
- **Exclusion 1** (self-session-id): `select($sess.session_id != $own_sid)`. The registry entry's `session_id` is the bare id from MT-1; `$own_sid` is the suffixed id from MT-4. These never match, so the batch's own registration is never excluded here.
- **Exclusion 2** (liveness): `select($sess.live == true)`. The registering session is the orchestrator's own live process — always true.
- **Exclusion 3** (dependency-edge): survives unless *every* task the registered session covers is either `$cnum` itself or edge-connected to it. For a typical multi-task batch of unrelated task numbers (the common case — `/orchestrate` accepts arbitrary comma/range lists with no requirement that batch members be dependency-connected), the other batch members are neither, so this does not exclude either.
- The predicate then computes `scopes_overlap_first($cscope; $sess.file_scope)` — the acquiring task's own scope is always a subset of (or overlapping with) the UNION scope registered for the whole batch, so this always returns a hit.

Result: `cmd_acquire` returns 1 (ABORT) with the message `"Task $task_number's file_scope overlaps registered session $sess_session_id's file_scope..."` for the very first task in the very first cycle of every multi-task `/orchestrate` invocation — a session refusing itself. This matches the error record's diagnosis exactly.

**`session-register`/`acquire` session-id parity is otherwise a documented, load-bearing convention** — `context/patterns/task-lock.md`'s "Consumers (Six Distinct Wiring Paths)" section (item 5) explicitly calls out that `commands/research.md`, `commands/plan.md`, `commands/implement.md` "register under the bare, unsuffixed `batch_session_id`", and the "Session-Registry Reader Contract" section states `cmd_acquire` "evaluat[es] `session_contention()`... applying D4's three exclusions (self-session-id, liveness, per-covered-task-number dependency-edge) from the acquiring task's perspective" — but the document never states, as an explicit invariant, that the acquire call's `session_id` argument must equal the session-register call's `session_id` argument for exclusion 1 to ever fire. That gap in the written contract is consistent with how this bug was introduced and went unnoticed at review time.

**The "Same-Session Re-Entry" section of `task-lock.md` (line 1042) calls this class of bug "the highest-impact risk in this lock's design"** and states the property "should never be weakened by future edits" — directly supporting the task's ask for a regression test, not just a point fix.

### Secondary finding: a currently-latent heartbeat mismatch this same fix would newly expose

`SKILL.md:2001-2002` dispatches `implement_agents[task_num]` with:
```
context = { task_number: task_num, task_type, session_id: "${session_id}_${task_num}", orchestrator_mode: true, plan_path, continuation_context: continuation, lit_flag, task_dir: task_dir_abs, handoff_path: handoff_path_abs }
```
`general-implementation-agent.md:270-277` ("Task-lock heartbeat") refreshes the **same per-task lock** MT-4 acquired, at each phase transition, using exactly the `session_id` field from its own dispatch context:
```bash
bash .claude/scripts/task-lock.sh heartbeat "{task_number}" "{session_id}"
```
`cmd_heartbeat` (`task-lock.sh:818-847`) no-ops with a stderr WARN (never blocks) when the given `session_id` does not match `holder.json`'s `session_id`. Today this call already uses the suffixed value while `holder.json` (written by the buggy MT-4 acquire) also carries the suffixed value — so today it happens to match. If MT-4's acquire/release are fixed to use the bare `$session_id` (as recommended below) without also touching `SKILL.md:2002`, the heartbeat call becomes a **new, silent** mismatch: every phase-transition heartbeat for a multi-task-orchestrated `/implement` dispatch would WARN-and-no-op instead of refreshing, letting the lock go stale (default `TASK_LOCK_STALE_MIN=30` minutes) partway through a long multi-phase implementation and become override-eligible by a second session. This is not the critical/blocking defect `err_1786349061524_pY97cE` describes, but it is a direct consequence of a narrow fix to only the two `task-lock.sh acquire`/`release` call sites, and it falls within the task's own framing ("unify... across the stages that acquire and **later reference** the task lock").

`research_agents[task_num]` (`SKILL.md:1983`) and `planner-agent` (`SKILL.md:1990`) dispatches also carry `session_id: "${session_id}_${task_num}"`, but neither `general-research-agent` nor `planner-agent` calls `task-lock.sh` at all (confirmed by search — no `task-lock` reference in either agent file), so those two dispatch sites do not interact with the lock and do not need to change for correctness (though changing them too would make the convention uniform across all three dispatch groups, at the cost of a larger diff).

### External Resources

Not applicable — this is a pure codebase logic/concurrency-contract defect with no external API or library surface.

### Recommendations

1. **Required**: change `SKILL.md:1960` and `SKILL.md:2388` from `"${session_id}_${task_num}"` to `"$session_id"`, matching Stage MT-1's `session-register` and Stage MT-3's `orchestrate-batch-admit.sh --session-id` calls. Update the surrounding prose at `SKILL.md:1953-1965` ("Task-lock acquire (per-task, before dispatch)") and `SKILL.md:2385-2388` ("Task-lock release (per-task, unconditional)") to state explicitly that the bare `$session_id` is used, matching Stage MT-1/MT-3, and to name this as the deliberate fix for the self-contention defect — mirroring the explanatory style already present at `SKILL.md:1624` for the MT-3 call site, so a future editor sees the invariant stated at the point of use rather than only in a test or a changelog.
2. **Recommended in the same change**: change `SKILL.md:2002`'s `implement_agents[task_num]` dispatch `session_id` field from `"${session_id}_${task_num}"` to `"$session_id"` (bare), so `general-implementation-agent.md:275`'s heartbeat call continues to match the lock's actual holder after fix #1 lands. This is the one dispatch-context site that provably interacts with the lock; leave `skill_preflight_update`/`skill_postflight_update` calls (`SKILL.md:1982,1989,2001,2190-2201`), `git-commit-scoped.sh --session` (`SKILL.md:2354`), and `system-defect-record.sh --session` (`SKILL.md:2098,2280`) as-is — none of those write or read `.lock/holder.json`, they are provenance/attribution metadata where per-task uniqueness is actively useful for log/commit readability, and changing them is out of the fix's necessary scope.
3. **Not required, judgment call for the planner**: `SKILL.md:1983` (`research_agents`) and `SKILL.md:1990` (`planner-agent`) dispatch contexts could also be switched to the bare id for uniformity, since neither downstream agent touches the lock either way. Leaving them suffixed is harmless; changing them only helps future-proof against a research/planner agent someday gaining its own heartbeat call. Flagging as optional rather than required to keep the diff minimal and matched to the task's literal TARGET/WORK scope.
4. **Regression test**: add a new group to `agent-system/extensions/core/scripts/test-conflict-predicate.sh` (an existing isolated-temp-root suite that already copies `task-lock.sh` byte-for-byte and drives it against a fixture `state.json` with per-task `file_scope` — see `Group 7`'s existing `"$TL" acquire 820 test sess_fc` call for precedent). Use two already-defined, non-dependency-connected fixture tasks (`820` `g4_clean_candidate` and `850` `g23_predecessor`, both `dependencies: []`, distinct `file_scope`) to model a realistic two-task `/orchestrate 820,850` batch:
   - Call the real `session-register` CLI: `"$TL" session-register "sess_mt_batch" "/orchestrate (multi-task)" "820,850"` (mirrors Stage MT-1 exactly, including the union-file_scope computation — no hand-written registry fixture).
   - **Positive case (fix verification)**: `"$TL" acquire 820 research "sess_mt_batch" "/orchestrate (multi-task)"` — same bare id as registered — assert exit 0. Release, then repeat for task `850` to confirm both batch members admit.
   - **Negative case (regression reproduction — must currently fail before the fix, and must be re-checked to fail again if the suffixed pattern is ever reintroduced)**: `"$TL" acquire 820 research "sess_mt_batch_820" "/orchestrate (multi-task)"` — the task-suffixed id — assert exit 1, and assert the stderr contains `"registered session"` (the exact ABORT text `cmd_acquire` emits for this contention path), proving the failure mode is the session-registry pass specifically, not some other refusal.
   - This does not require a manifest change (`test-conflict-predicate.sh` is already listed under `core/manifest.json`'s `provides.scripts`), and it exercises the real CLI end-to-end (register -> acquire) rather than a hand-assembled `session_contention()` unit call, which is the most faithful reproduction of the actual MT-1 -> MT-4 sequence available without invoking the full agent-orchestrated skill.
   - If recommendation #2 is also implemented, add a third case dispatching the equivalent of `general-implementation-agent.md:275`'s heartbeat call (`"$TL" heartbeat 820 "sess_mt_batch"` after the positive-case acquire) and assert it does NOT print a "held by a different session" WARN, to guard the secondary finding above.

## Decisions

- Scope of the required fix is the two `task-lock.sh acquire`/`release` call sites in Stage MT-4 (`SKILL.md:1960`, `SKILL.md:2388`) — this is the literal "MT-1 and MT-4... session-id construction sites" the task names, and it is sufficient to eliminate the critical/blocking defect `err_1786349061524_pY97cE` describes.
- The `implement_agents[task_num]` dispatch context's `session_id` field (`SKILL.md:2002`) should be included in the same change, because it is consumed by a task-lock-touching call (`general-implementation-agent.md:275`'s heartbeat) and leaving it suffixed converts a loud, immediate, 100%-reproducible bug into a quiet, deferred, timing-dependent one — a strictly worse failure mode to leave behind. This is presented as a recommendation for the implementer/planner to confirm, not applied by this research pass (no code was changed).
- `research_agents`/`planner-agent` dispatch `session_id` fields, `skill_preflight_update`/`skill_postflight_update`, `git-commit-scoped.sh --session`, and `system-defect-record.sh --session` are explicitly OUT of the required fix — none of them read or write `.lock/holder.json`.
- The identical `session-register` (bare) / `acquire-retry` (suffixed) pattern in `commands/research.md`, `commands/plan.md`, `commands/implement.md` is NOT addressed here — the task's TARGET line is scoped to `skill-orchestrate/SKILL.md` only, and those three files were not named in the error record. See Risks & Mitigations.

## Risks & Mitigations

- **Same defect pattern likely present in `commands/research.md:165,234,238`, `commands/plan.md:172,241,245`, `commands/implement.md:89,155,159`** (`session-register "$batch_session_id"` vs. `acquire-retry ... "${batch_session_id}_${task_num}"`). This was NOT verified end-to-end in this research pass (out of scope), but the code pattern is byte-for-byte structurally identical to the confirmed `skill-orchestrate` defect, and a batch of unrelated (non-dependency-connected) task numbers is the common case for `/research`/`/plan`/`/implement`'s own documented multi-task syntax (`/research 7, 22-24, 59`). **Mitigation**: recommend spawning a follow-up task after this one lands, scoped to those three command files, using the same fix shape and the same `test-conflict-predicate.sh` regression-test pattern recommended above. Do not fold it into this task — the TARGET/SOURCE-STORE/DELIVERABLE constraints on this task are explicit about `skill-orchestrate/SKILL.md` only.
- **Fixing only `SKILL.md:1960`/`2388` without `SKILL.md:2002`** would convert a critical, always-reproducible ABORT into a heartbeat-staleness race that only manifests on long multi-phase implementations inside a multi-task batch — harder to detect, easier to reintroduce unnoticed. Mitigated by Recommendation #2 and its accompanying test case above.
- **Verification cannot use multi-task `/orchestrate`** (per this task's own constraint, since that is the broken mechanism). The recommended regression test deliberately drives `task-lock.sh` directly (the same binary Stage MT-1/MT-4 shell out to) rather than the full skill, so it can be authored and run under single-task `/implement` without needing the fixed multi-task path to exist first.
- **`context/patterns/task-lock.md` does not currently state the acquire/session-register session-id-parity invariant explicitly** — worth a one- or two-sentence addition to the "Consumers (Six Distinct Wiring Paths)" item 2 (multi-task/wave dispatch) once the code fix lands, so a future reader of the canonical spec sees the invariant, not just the test asserting it. Not required for this task's TARGET but a low-cost, high-value addition if the implementer has budget.

## Context Extension Recommendations

- **Topic**: task-lock.md's "Consumers" section (item 2, multi-task/wave dispatch) does not state that the `acquire`/`release` `session_id` argument must equal whatever `session-register` used for the same batch.
- **Gap**: a reader implementing a NEW multi-task consumer (as `research.md`/`plan.md`/`implement.md` already did, and as `skill-orchestrate/SKILL.md` did here) has no explicit warning that these two values must be identical strings for D4 exclusion 1 to ever fire; the invariant currently exists only implicitly, split across the "Session-Registry Reader Contract" and "Same-Session Re-Entry" sections.
- **Recommendation**: after the code fix lands, add one sentence to item 2's existing prose (`context/patterns/task-lock.md` around line 1062) stating the invariant directly, and cross-reference it from wherever `session-register`'s bare-id requirement is already documented (item 5, same section).

## Appendix

- Error record consulted: `specs/errors.json`, id `err_1786349061524_pY97cE` (`type: lock_session_self_contention`, `severity: critical`, `fix_status: unfixed`).
- Sibling tasks in `specs/state.json` gated on this one (their `CONSTRAINT` lines name `err_1786349061524_pY97cE`): the defect-vocabulary-gap task, the deployed-mode `command-gate-in.sh` session-id-generator task, the deploy-orphan-files-undercounted task, and the handoff-location-regex task.
- Grep commands used: `grep -n "MT-1\|MT-4\|session_id"`, `grep -n "task-lock.sh acquire\|release\|heartbeat\|session-register\|session-heartbeat\|session-release"`, `grep -rn "session-register\|\${session_id}_\${task"` across `agent-system/extensions/core/skills/*/SKILL.md` and `agent-system/extensions/core/commands/*.md`, `grep -n "task-lock.sh heartbeat"` across agents/skills.
- Files read in full or substantial part: `task-lock.sh` (lines 1-1080, 1081-1360), `lib/file-scope-overlap.sh` (full), `context/patterns/task-lock.md` (Consumers/Session-Registry sections), `test-session-registry.sh` (full), `test-conflict-predicate.sh` (full).
- Repo HEAD at research time: `4d0e69debf61064020ab835ec0952b7d17a1fa37` (last commit touching `skill-orchestrate/SKILL.md`).

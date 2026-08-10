# Research Report: Auto-Sequence Conflicting Work

**Task**: 946 - Auto-sequence conflicting work instead of aborting or skipping
**Started**: 2026-07-28T17:22:36Z
**Completed**: 2026-07-29T00:00:00Z
**Effort**: research only (no implementation)
**Dependencies**: 945 (predecessor task that converged the conflict-detection predicate)
**Sources/Inputs**: Codebase read of the current source-store tree (`agent-system/extensions/core/**`); no web search was needed — this is a pure internal-architecture question.
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The four tiers are **unevenly implemented today**. Tier 1 (auto-sequence) is partially live but only inside `/orchestrate`'s multi-task cycling loop, and only for the `in_batch` file-scope-collision case; Tier 3 (warn) is fully live everywhere as the terminal response; Tier 2 (bounded retry) does not exist anywhere in the lock-acquisition path; Tier 4 (ask) does not exist anywhere.
- The clearest, narrowest Tier-1 gap is **plain multi-task `/research N,M`, `/plan N,M`, `/implement N,M`**: these commands dispatch their whole validated batch in one parallel shot with no wave/cycle concept, so their Step 2.5 admission pre-check (`orchestrate-batch-admit.sh`) treats an `in_batch` file-scope collision — which `/orchestrate` would simply retry next cycle — as a same-invocation-permanent drop into `skipped_tasks`, identical to how it treats a `cross_batch` or `self_modifying` defer. This is architecturally the single most concrete "invert the preference" bug the task description calls out.
- The established, reusable **bounded-retry idiom** already exists twice in `task-lock.sh`/`git-commit-scoped.sh` (`acquire_named_mutex()`'s `mkdir`-poll-with-staleness-reclaim, and the one-shot randomized-backoff `index.lock` retry) — Tier 2 should splice one of these, not invent a third shape.
- The established, reusable **interactive-vs-autonomous split** for Tier 4 already exists in `context/patterns/lit-stage4a-flow.md`'s `AUTONOMOUS_GLOBAL` branch, gated on the same `orchestrator_mode` field this task's delegation context itself carries. `/orchestrate` (`orchestrator_mode: true`) structurally cannot reach Tier 4 — it has zero synchronous confirmation gates by design — so Tier 4 is reachable only from a direct, non-orchestrated `/research N` / `/plan N` / `/implement N` invocation.
- The established, reusable **convergence-protection shape** (`deferred_self_modifying` append-only log + `consecutive_no_dispatch_cycles` bounded counter breaking to `partial`) is fully documented and must be replicated verbatim-in-spirit for any new deferral path this task adds, per the task's own mandatory CONVERGENCE PROTECTION requirement.
- The **same-session re-entry** safety property is enforced at a single, precise point inside `cmd_acquire` (the `holder_session = session_id` check, run *before* the age-based refusal branch) and is independently re-derived for the cross-task overlap scan (`other_session = session_id → continue`) and the session-registry pass (`session_contention()`'s D4 exclusion 1). Any Tier-2 retry loop is safe by construction only if every retry attempt is a **fresh, full re-entry into `cmd_acquire`** (or an equivalent full re-run of `task-lock.sh acquire`), never a partial-logic wrapper that skips the same-session check on iterations after the first.

## Context & Scope

This is the fourth and final task in a chain that converged the underlying conflict-detection predicate (task 945 and its predecessors). The predicate itself — `scripts/lib/file-scope-overlap.sh`'s `scopes_overlap_first`/`session_contention`/`edge_connected_nums`, consumed by `task-lock.sh acquire` and `orchestrate-batch-admit.sh` (verdict schema `orchestrate-batch-admit-v4`) — is settled and out of scope to re-derive. This research investigated only how the four *response tiers* (auto-sequence → bounded retry → warn → ask) should consume that already-converged predicate, per the task description's VERIFIED CURRENT BEHAVIOR and six NON-NEGOTIABLES (not re-litigated here).

## Findings

### Tier 1 — Auto-Sequence (the core of the task)

**Where wave computation actually lives, and what feeds it.**

`agent-system/extensions/core/commands/orchestrate.md`'s `#### Step 3: Topological Wave Assignment (Kahn's Algorithm)` is a bash-fenced pseudocode block (`declare -A wave_assignment`, `waves=()`, `in_degree`, etc.) that the file itself states, twice, is **illustrative only**:

> "this subsection is illustrative of the CONTRACT `skill-orchestrate` fulfills, not code this file itself runs... This file never loops waves and never itself invokes `orchestrate-batch-admit.sh`."

The wave/`in_degree` graph this pseudocode builds is fed *exclusively* from `Step 2: Dependency Graph Construction`'s `dependencies[]` read (`jq -r '... .dependencies // [] | .[]'`, intra-batch-filtered). `file_scope` never enters `in_degree`/`predecessors` construction at all — confirming the task description's claim precisely.

The **sole EXECUTING** admission gate is `skills/skill-orchestrate/SKILL.md`'s Stage MT-3 step 4.5, which re-derives `eligible_tasks` fresh every cycle (not from the pre-computed `waves[]`) and calls `orchestrate-batch-admit.sh --invocation-count "${#eligible_tasks[@]}" --session-id "$session_id" "${eligible_tasks[@]}"`. This is a **cycle-scoped, dispatch-time, reactive** deferral, not a pre-dispatch wave-assignment input.

**What already achieves auto-sequencing, and where it stops.**

For `/orchestrate` multi-task mode specifically, an `in_batch` `file_scope_collision` verdict (`collision_scope == "in_batch"`) is **already** handled exactly the way Tier 1 asks: "remove the deferred task from this cycle's dispatch batch... eligible again on a later cycle" (SKILL.md Stage MT-3 step 4.5). This is genuine auto-sequencing — no user interaction, the task simply runs one cycle later. `orchestrate.md`'s illustrative Step 3 block documents the same behavior for wave-level dispatch (`[orchestrate] WARNING: Wave {N} tasks #{X} and #{Y}... Deferring #{Y} to wave {N+1}`).

What is **not** auto-sequenced, concretely:

1. **Plain multi-task `/research N,M`, `/plan N,M`, `/implement N,M` (non-`/orchestrate`)** — confirmed by reading `commands/research.md` Step 2.5 (`Batch Admission Pre-Check (Gap C)`) directly. These commands have **no wave or cycle concept at all**: Step 3 dispatches every member of `validated_tasks` in **one single parallel batch** ("Invoke all skills in a single message (parallel execution, one skill per task)"). Step 2.5's admission loop treats *every* defer verdict identically, regardless of `defer_reason` or `collision_scope`:
   ```bash
   # EXCLUDE, never auto-expand: remove $t from validated_tasks, never pull anything else in.
   ...
   validated_tasks=("${new_validated[@]}")
   skipped_tasks+=("$t: deferred by batch admission [$defer_reason]")
   ```
   So an `in_batch` collision between two tasks in the *same* `/research 7,8` invocation — which `/orchestrate` would simply retry one cycle later — is instead a **permanent drop for this invocation** here, indistinguishable from a `cross_batch` or `self_modifying` defer. This is the single most concrete, narrowly-scoped instance of "the system inverts the preference": the mechanism to re-sequence (not drop) already exists in `/orchestrate`'s cycling loop, but plain multi-task commands have no cycle to retry on.
   - `batch-orchestration-guardrails.md` already names this exact gap explicitly (not discovered fresh by this research, corroborated): *"The narrowing... does NOT transfer to plain multi-task `/implement`, `/research`, or `/plan`... There is no unit the narrowing could even be expressed in for those commands... A future reader must not assume the narrowing implicitly covered plain multi-task commands... a follow-up task would be required to extend equivalent protection to those commands, should that ever be judged necessary."** This document is explicitly flagging the exact residual this task's Tier 1 needs to close for plain multi-task commands.
   - **What "sequence, don't drop" would look like here, concretely, without inventing a new wave concept**: give plain multi-task commands a *bounded* two-pass structure — dispatch pass 1 with the current one-shot parallel batch, but before dropping an `in_batch` collision to `skipped_tasks`, hold it for a **second, sequential pass after pass 1 completes** (so the colliding task's foreign holder has released). This reuses the existing `defer_reason == "file_scope_collision" && collision_scope == "in_batch"` verdict field precisely — it is the ONE defer flavor where the colliding task is *also inside this same invocation and will finish this run*, unlike `cross_batch` (colliding task is outside the batch and may never finish) or `self_modifying`/`session_active` (no natural "this invocation's own dispatch" event to wait on). Bounding this to exactly one extra pass (never an unbounded retry loop) keeps it consistent with the BOUNDED SCAN ONLY non-negotiable and with `/orchestrate`'s own cycle-cap discipline.

2. **Single-task `/research N`, `/plan N`, `/implement N`, `/orchestrate N` (single-task path)** — there is no batch and therefore nothing to "place in a later wave." A refused `task-lock.sh acquire` here is `command-gate-in.sh`'s hard `return 1` (see "Refusal Paths" below). Tier 1 (auto-sequence) is structurally inapplicable to a single task run in isolation — there is nothing to reorder against. The available levers for this path are Tier 2 (bounded retry) and Tier 3 (warn), never Tier 1.

**Whether the pseudocode should become a real script — cost note.** Converting `orchestrate.md`'s illustrative Kahn's-algorithm block into an executable script is a materially larger change than closing the plain-multi-task gap above: the file's own comments repeatedly warn against making the illustration literal ("Do not add a real per-wave dispatch loop to this file to make the illustration literal"), and the batch-orchestration-guardrails.md's critical-path Inclusion Table already lists `skill-orchestrate/SKILL.md`, `orchestrate.md`, and `orchestrate-batch-admit.sh` as orchestrator-critical (rows 1, 3, 7) — meaning any change here is itself subject to the self-modification hazard gate this same system enforces. Given that the actually-EXECUTING gate (SKILL.md Stage MT-3) already achieves in-batch auto-sequencing correctly, a plan should very likely leave `orchestrate.md`'s Kahn pseudocode untouched (it is explicitly documentation of a contract, not runtime code) and focus Tier-1 work on (a) the plain-multi-task two-pass gap above, which is the true behavioral hole, and (b) confirming SKILL.md's existing in-batch handling needs no change.

### Tier 2 — Bounded Wait-and-Retry

**The idiom to reuse, verbatim in shape.** `scripts/task-lock.sh`'s `acquire_named_mutex()` (used by both `.scope-lock` and `.commit-lock`) is the canonical bounded-poll idiom in this codebase:

```bash
while true; do
  if mkdir "$mutex_dir" 2>/dev/null; then
    now_epoch > "$mutex_dir/claimed_at"; echo "$stale_sec" > "$mutex_dir/stale_sec"
    return 0
  fi
  # staleness reclaim: if claimed_at age > holder-declared stale_sec, WARN + rm -rf + continue
  # else: if waited_ms >= wait_budget_ms, return 1 (fail closed); else sleep 0.05, waited_ms += 50
done
```
Concrete numbers already in production: `.scope-lock` uses `SCOPE_MUTEX_STALE_SEC=10`, `SCOPE_MUTEX_ACQUIRE_BUDGET_MS=5000`; `.commit-lock` uses `COMMIT_MUTEX_STALE_SEC=30`, `COMMIT_MUTEX_ACQUIRE_BUDGET_MS=15000`. Both are **seconds-scale** budgets, not minutes — this matters, because `TASK_LOCK_STALE_MIN` (the task-lock's own staleness threshold) defaults to 30 **minutes**. Tier 2 is explicitly for "a live lock likely to release shortly" (task description), so any new bounded-retry window here should be sized like the mutex budgets (single-digit seconds to tens of seconds), never anywhere near the 30-minute task-lock staleness window — waiting minutes inside a single command invocation would be a materially different (and almost certainly unwanted) UX than what "bounded" implies elsewhere in this codebase.

**The second idiom to reuse.** `git-commit-scoped.sh`'s ONE-shot randomized-backoff retry on `index.lock` contention:
```bash
commit_output=$(git commit ... 2>&1); commit_exit=$?
if [ "$commit_exit" -ne 0 ] && echo "$commit_output" | grep -qi 'index\.lock'; then
  echo "$commit_output" >&2
  echo "NOTE: git commit hit index.lock contention; retrying once after a short backoff." >&2
  sleep "0.$(( (RANDOM % 5) + 1 ))"
  commit_output=$(git commit ... 2>&1); commit_exit=$?
fi
```
This is a *single* bounded retry (not a polling loop) with a visible `NOTE:` line — the minimal form of "bounded wait-and-retry" already shipped and tested in this codebase.

**Where retry belongs.** Two candidate sites, with different tradeoffs:

- **Inside `task-lock.sh`'s `cmd_acquire`**: wrapping the refusal path (age check, currently `if [ "$age" -le "$TASK_LOCK_STALE_MIN" ]; then ... return 1; fi`) in a bounded poll mirroring `acquire_named_mutex`'s shape. This keeps the retry co-located with the predicate it is retrying against, and — critically — the same-session check (`if [ "$holder_session" = "$session_id" ]; then ... return 0; fi`) already runs *before* this branch on every single invocation of `cmd_acquire`, so as long as retry is implemented as "call `cmd_acquire`'s full logic again," same-session re-entry is preserved automatically on every retry attempt.
- **At `command-gate-in.sh`'s call site**: wrapping the `if ! bash .claude/scripts/task-lock.sh acquire ...; then return 1; fi` line in a bash retry loop that re-invokes the whole `task-lock.sh acquire` *subprocess* on refusal. This is architecturally simpler (no change to `task-lock.sh`'s own contract/exit-code semantics, which are referenced by many other consumers — the file's own header documents `acquire`'s exit codes 0/1/2 as a stable contract) and is *equally* safe for same-session re-entry, because each retry is a fresh subprocess invocation of `acquire`, which re-runs the same-session check from scratch every time.

Given that `task-lock.sh acquire`'s exit-code contract (0/1/2) is documented as stable and consumed by multiple non-`command-gate-in.sh` callers (the plain multi-task commands' Step 3 loops call `task-lock.sh acquire` directly, without going through `command-gate-in.sh` at all — see `commands/research.md` line "This multi-task loop bypasses `command-gate-in.sh`/`command-gate-out.sh` entirely"), a plan should weigh: retrying *inside* `cmd_acquire` benefits **every** caller (single-task via `command-gate-in.sh` AND plain-multi-task's direct calls) uniformly with one change; retrying only at `command-gate-in.sh`'s call site would leave the plain-multi-task direct-call sites unretried unless they are separately wrapped too.

### Tier 3 — Warn

**Exact current shape**, three variants, all inside `cmd_acquire` (task-lock.sh), each a two-line `ABORT:`/remedy pair:

1. **Own-task lock refusal** (the task description's cited example):
   ```
   ABORT: Task $task_number is locked by session $holder_session (heartbeat ${age} min ago; stale threshold ${TASK_LOCK_STALE_MIN} min).
     Wait for the lock to go stale, or override manually: rm -rf "$lock_dir"
   ```
2. **Cross-task file_scope overlap against a held lock**:
   ```
   ABORT: Task $task_number's file_scope overlaps task $other_task's file_scope at "$overlap_path" and task $other_task is locked by session $other_session (heartbeat ${other_age} min ago; stale threshold ${TASK_LOCK_STALE_MIN} min).
     Wait for task $other_task's lock to go stale, or coordinate with that session before retrying.
   ```
3. **Cross-task file_scope overlap against a live registered session** (no held lock):
   ```
   ABORT: Task $task_number's file_scope overlaps registered session $sess_session_id's file_scope at "$sess_overlap_path" (session covers task #$sess_covered_num, liveness: $sess_liveness). The session registry is only ever read here, never mutated.
     Wait for that session to finish or release, or coordinate with it before retrying.
   ```

All three carry the fields the task description names (other session, overlapping path, some notion of freshness) — variant 3 substitutes `liveness_reason` (a categorical string: `pid-alive`/`corrupt`/`undeterminable`) for the numeric heartbeat-age minutes that variants 1–2 carry, since a session-registry entry's own `age_min`/`liveness_reason` is the analogous signal there. A plan converting these ABORTs into the Tier-3 warn tier should preserve this exact three-variant field set rather than collapsing them to one generic message, since each variant's remedy text is already correctly scoped to what actually needs to happen (release own lock vs. wait on a different task's lock vs. wait on a session).

### Tier 4 — Ask

**Where it can even run.** `/orchestrate` (and `/orchestrate --hard`) is explicitly designed with **zero synchronous confirmation gates** — stated verbatim in `batch-orchestration-guardrails.md`'s "Divergence from External Practice" section: *"this system assumes... autonomous orchestration has zero synchronous confirmation gates between lifecycle phases... No synchronous batch-approval gate exists here at all."* This task's own delegation context (`"orchestrator_mode": true`) places task 946 itself inside that same autonomous regime. Any Tier-4 "ask" therefore cannot fire when `orchestrator_mode == true` — there is no human to prompt, and `AskUserQuestion` is documented elsewhere in this codebase as literally forbidden to call in that state.

**The established interactive-vs-autonomous split to reuse.** `context/patterns/lit-stage4a-flow.md`'s `AUTONOMOUS_GLOBAL` branch is the exact precedent:

```bash
### `AUTONOMOUS_GLOBAL`
# Sub-index absent, global index present, autonomous context (`orchestrator_mode == "true"`).
# **MUST NOT call `AskUserQuestion`** — no human is available to prompt. Take the deterministic
# default "Use global corpus now":
lit_context=$(bash .claude/scripts/literature-briefing-invoke.sh --global "$description") || lit_context=""
echo "[lit:auto] No per-repo sub-index found; autonomous context (orchestrator_mode=true) — running a global-corpus search instead of prompting. ($rationale)" >&2
```

The pattern is: (1) resolve `orchestrator_mode` from the delegation context, defaulting to `"false"` when unset (`"${orchestrator_mode:-false}"`); (2) in the autonomous branch, **never** call `AskUserQuestion` — substitute a deterministic default action and log a visible, distinctly-prefixed notice (`[lit:auto]` there; a Tier-4 equivalent might be `[conflict:auto]`); (3) in the interactive branch, present the real question via `AskUserQuestion`. For Tier 4's genuine last-resort prompt, the deterministic autonomous default would naturally be "fall through to Tier 3's warn-and-defer" (since Tier 4 can never be reached autonomously, the autonomous path effectively terminates at Tier 3) — this needs an explicit design decision in the plan, not assumed here, but the mechanism to express the split is already proven out.

**Where "genuine last resort" applies.** Given Tier 4 is unreachable under `orchestrator_mode: true`, it can only ever fire from a direct, human-invoked `/research N`, `/plan N`, or `/implement N` (no `--team`, not dispatched via `/orchestrate`) — i.e., exactly the single-task path that sources `command-gate-in.sh` directly from a command file rather than through `skill-orchestrate`. The question content itself would need to surface the same fields Tier 3's warn already carries (other session/task, overlapping path, staleness/liveness) plus the concrete choices: wait longer, proceed anyway (override), or abort.

### Refusal Paths to Convert

1. **`command-gate-in.sh`'s hard abort** (`gate_in()`, `scripts/command-gate-in.sh`):
   ```bash
   if ! bash .claude/scripts/task-lock.sh acquire "$task_number" "$operation" "$SESSION_ID" "/$operation $task_number"; then
     return 1
   fi
   ```
   **Correction to the task description's "sourced by five commands" framing**: a direct grep for the literal `source .claude/scripts/command-gate-in.sh` invocation (not mere mentions) found **six command files actually sourcing it** — `research.md`, `plan.md`, `implement.md`, `revise.md`, `orchestrate.md` (single-task path only), and `task.md` (twice, for `expand` and `abandon` operations). `batch-orchestration-guardrails.md`'s "five commands" language likely predates `task.md`'s two call sites or is counting distinct *operations* rather than *files*; a plan should verify the current count directly (`grep -rln "source .claude/scripts/command-gate-in.sh" agent-system/extensions/core/commands/`) rather than trust either number as frozen, since this is exactly the kind of fact that drifts as the source store evolves.

2. **Multi-task `skipped_tasks` "locked by another session" drop** (`commands/research.md`, `plan.md`, `implement.md`, all three byte-identical in shape):
   ```
   3. Before invoking the skill for a task: `task-lock.sh acquire "$task_num" research "${batch_session_id}_${task_num}" "/research (multi-task)"`. If this refuses (exit 1 — a fresh lock held by a genuinely different session; same-session re-entry never refuses), move that task from `validated_tasks` to `skipped_tasks` with reason "locked by another session" and do NOT invoke its skill this run.
   ```
   This is a per-task acquire *inside* the dispatch loop, distinct from Step 2.5's earlier `orchestrate-batch-admit.sh` pre-check — meaning a plain multi-task invocation currently has **two** separate silent-drop points that a Tier-1/2/3/4 conversion needs to address: the admission pre-check (Step 2.5, already discussed above) and this per-task lock-acquire-time drop (Step 3). The per-task lock-acquire drop is the natural site for Tier 2 (bounded retry) to plug in, since it fires against a **currently-held foreign lock** (the exact "live lock likely to release shortly" scenario Tier 2 targets), whereas Step 2.5's admission pre-check fires against **state.json/session-registry** signals that are not necessarily "about to release."

### CONVERGENCE PROTECTION (mandatory) — established precedent, verbatim enough to reuse

From `skills/skill-orchestrate/SKILL.md` Stage MT-1/MT-3 (already-implemented, not proposed here):

- **`deferred_self_modifying: []`** — initialized as, and explicitly documented as, an **APPEND-ONLY OBSERVATION LOG**, never an exclusion set: *"persists across every cycle of this same `mt_state_file`, never reset mid-invocation... As of the narrowed same-cycle scope, this is NO LONGER an eligibility-exclusion set — a task appearing in this log is not thereby excluded from a later cycle's `eligible_tasks`. The convergence mechanism is now the SAME one `file_scope_collision` already uses: the defer is re-evaluated fresh every cycle... and it clears on its own once the co-dispatched sibling that caused it leaves `eligible_tasks` (enters `researching`/`planning`, terminates, or fails) — no persistent exclusion is needed for that to happen, and the loop's existing per-cycle re-evaluation already guarantees it."*
- **`consecutive_no_dispatch_cycles: 0`** — the bounded counter backing the one non-convergence mode the append-only log's natural clearing does NOT prevent by itself: *"increments on any cycle where `eligible_tasks` was non-empty but the self-modification gate deferred every member of it (empty actual dispatch batch); resets to 0 on any cycle where at least one task dispatches... If the counter reaches a small bound (3), break the loop with `partial` status and a named diagnostic — e.g. 'self-modification gate produced N consecutive cycles with zero dispatched tasks; likely a mutually-colliding self-modifying set; re-run affected tasks solo or pass --allow-self-modifying' — rather than silently spinning to `MAX_CYCLES_MT`."*

**Applying this to a new deferral path**: any Tier-1 auto-sequence mechanism this task's plan adds (e.g. the plain-multi-task two-pass idea above) needs the SAME two-part shape — (a) an append-only observation log recording every defer event (this system already has a generalization of this: `defer_ledger`, "ADDITIVE to `deferred_self_modifying`... never a fifth admission gate," read only for reporting, never for eligibility logic), and (b) a bounded counter that breaks to `partial` status rather than looping unboundedly. For the plain-multi-task two-pass idea specifically, the natural bound is trivial (exactly one extra pass, not an open-ended retry), so the counter requirement is nearly free there; for a Tier-2 bounded-retry addition inside `task-lock.sh acquire`, the existing `wait_budget_ms` shape (from `acquire_named_mutex`) already IS the bounded counter equivalent — no new field is needed, just the existing pattern reapplied.

### Highest-Impact Regression Risk — Same-Session Re-Entry

The exact detection point, quoted from `cmd_acquire` in `scripts/task-lock.sh` (top-of-file comment, restated at the call site):

```bash
# Same-session re-entry (CRITICAL): a session re-acquiring its own lock (e.g.
# `/research 42` then `/plan 42` in one conversation) MUST NOT self-block. `acquire`
# checks holder.json's session_id BEFORE ever treating an existing lock as a refusal
# — matching session_id always succeeds and just refreshes the heartbeat.
...
if [ "$holder_session" = "$session_id" ]; then
  # Same-session re-entry: MUST NOT self-block. Refresh heartbeat only.
  local acquired_at
  acquired_at=$(read_holder_field "$lock_dir" "acquired_at")
  write_holder "$lock_dir" "$session_id" "$task_number" "$operation" "${acquired_at:-$(iso_now)}" "$(iso_now)" "$command" || return 2
  return 0
fi

age=$(age_minutes "$holder_heartbeat")

if [ "$age" -le "$TASK_LOCK_STALE_MIN" ]; then
  # Fresh lock held by a DIFFERENT session: refuse.
  ...
  return 1
fi
```

The check runs **strictly before** the age-based fresh-lock-refusal branch that would trigger any new Tier-2 retry logic. Two independent, earlier same-session exclusions also exist and must be preserved in the same position relative to any new logic:
- The cross-task overlap held-lock scan: `[ "$other_session" = "$session_id" ] && continue` (own concurrent work never blocks itself, before the overlap test even runs).
- `session_contention()`'s D4 exclusion 1: `select($sess.session_id != $own_sid)` (self-exclusion by session id, first of three exclusions, applied before liveness or dependency-edge checks).

**What would break it**: any Tier-2 implementation that (a) wraps `cmd_acquire`'s refusal branch in a retry loop that does NOT re-run the same-session check on every iteration (e.g. hoisting the check "outside" a retry loop under a mistaken belief that `session_id` can change mid-call — it cannot, since it is a fixed function argument, but a *rewritten* retry loop that restructures the function body carelessly could still accidentally short-circuit past the check on a refactor), or (b) implements retry as a *new*, parallel code path that duplicates the acquire logic instead of calling the existing `cmd_acquire` (or `task-lock.sh acquire` subprocess) fresh each iteration, and the duplicate omits one of the three same-session exclusions above. The safe implementation pattern, confirmed by this research: **retry must always be "call the full, unmodified acquire logic again," never "retry only the refusal-handling tail of the logic."**

## Decisions

No implementation decisions were made in this research pass (that is `/plan`'s job). The following are recommendations for the planning stage, stated as options with their tradeoffs already surfaced above rather than as settled choices:

- Tier 1: prioritize the plain-multi-task two-pass fix over any change to `orchestrate.md`'s illustrative Kahn pseudocode; the latter is already a non-executing documentation block and touching it invokes the self-modification hazard gate for no behavioral gain, since the executing gate (SKILL.md Stage MT-3) already auto-sequences the `in_batch` case correctly.
- Tier 2: implement bounded retry inside `task-lock.sh`'s `cmd_acquire` (benefits both `command-gate-in.sh` callers and plain-multi-task's direct `task-lock.sh acquire` callers with one change), sized on the `.scope-lock`/`.commit-lock` seconds-scale budget, not the 30-minute staleness window.
- Tier 3: preserve the existing three-variant ABORT/warn shape verbatim; do not collapse to one generic message.
- Tier 4: gate on `orchestrator_mode` exactly as `lit-stage4a-flow.md`'s `AUTONOMOUS_GLOBAL` branch does; Tier 4 is reachable only from direct, non-orchestrated single-task invocations.

## Risks & Mitigations

- **Risk**: a Tier-2 retry loop retried too long could turn a fast-failing command into a slow-hanging one for a human waiting at the terminal on a direct `/research N` invocation. **Mitigation**: bound retry to the mutex idiom's seconds-scale budgets (5–15s), never minutes.
- **Risk**: converting the plain-multi-task Step 2.5 admission drop into a two-pass sequence could reorder task output in a way existing consumers (e.g. anything parsing `skipped_tasks` text) depend on. **Mitigation**: keep the second pass's outcome reported in the same consolidated summary shape, just with a different (sequenced, not dropped) fate.
- **Risk**: any change to `command-gate-in.sh` risks the "sourced by [five/six] commands, so a bug blocks all task work system-wide" hazard the task description itself names. **Mitigation**: the isolated-temp-root test precedent below exists precisely to de-risk this class of change without touching the real `specs/` tree.

## Context Extension Recommendations

- **Topic**: the discrepancy between `batch-orchestration-guardrails.md`'s "sourced by five commands" framing (in its Exclusion Table's `command-gate-in.sh` row) and the six actual sourcing sites this research found (`research.md`, `plan.md`, `implement.md`, `revise.md`, `orchestrate.md`, `task.md`).
- **Gap**: no context file states the current, authoritative sourcing-site count for `command-gate-in.sh`, so "five" propagates as an assumed-frozen fact.
- **Recommendation**: when this task's plan/implementation lands, consider a one-line correction or a "verify via grep, do not trust a frozen count" note near that Exclusion Table row — out of scope for this research report to edit directly, since `batch-orchestration-guardrails.md` is not in this task's `file_scope`.

## Verification

Proof obligations, one per tier, and how to satisfy each — all should use the isolated-temp-root pattern already established by `scripts/test-task-lock-reap.sh`, `scripts/test-session-registry.sh`, and `scripts/test-conflict-predicate.sh` (each builds a throwaway `$TMPROOT/.claude/scripts/` tree satisfying `deploy-root-guard.sh`'s two-levels-under-root check, copies the real scripts byte-for-byte, and drives fixture `state.json`/`.sessions/`/`.lock/` state with controlled timestamps — "no testability hooks added to production code anywhere in this suite"):

1. **Tier 1 (auto-sequences with no user interaction)**: a new or extended isolated-temp-root suite (mirroring `test-conflict-predicate.sh`'s shape) that seeds two fixture tasks in the same plain-multi-task batch with overlapping `file_scope` and no `dependencies[]` edge, runs the (to-be-implemented) two-pass logic, and asserts both tasks end up "run" (one in pass 1, the colliding one in pass 2) rather than one landing in `skipped_tasks`.
2. **Tier 2 (resolved by bounded retry)**: a fixture where task-lock.sh's own lock is held by a session whose heartbeat is refreshed (simulating "about to release") partway through the retry window — assert the acquire succeeds within the bounded budget without ever falling through to the ABORT/warn tier, and assert the same-session-re-entry fixture from `test-conflict-predicate.sh`'s existing coverage still passes (own-session acquire never enters the retry loop at all).
3. **Tier 3 (legitimately reaches warn)**: a fixture where the foreign holder's heartbeat is fresh and stays fresh for the whole retry budget (a genuinely long-running foreign session) — assert the retry budget is exhausted and the existing three-variant ABORT/warn message fires with all documented fields populated.
4. **Tier 4 non-converging deferral terminates as `partial`**: extend or mirror the existing `consecutive_no_dispatch_cycles`-shaped test coverage (if any exists for the self-modifying case) to the new deferral path added by this task, asserting the loop breaks with `partial` status at the small bound rather than spinning to `MAX_CYCLES_MT`.

## Appendix

### Search Queries / Investigation Steps Used

- Direct `Read` of `specs/state.json`'s task 946 entry (full VERIFIED CURRENT BEHAVIOR / NON-NEGOTIABLES / CONVERGENCE PROTECTION text).
- `Read`: `scripts/command-gate-in.sh`, `scripts/task-lock.sh` (full, 1526 lines across two reads), `scripts/orchestrate-batch-admit.sh`, `scripts/lib/file-scope-overlap.sh`, `scripts/git-commit-scoped.sh`, `docs/architecture/batch-admit-schema.md`, `context/patterns/batch-orchestration-guardrails.md`, `context/patterns/lit-stage4a-flow.md` (partial), `commands/orchestrate.md` (Steps 1.5–4), `commands/research.md` (multi-task section), `skills/skill-orchestrate/SKILL.md` (Stage MT-1/MT-3 sections).
- `Bash grep`: `deferred_self_modifying|consecutive_no_dispatch_cycles|MAX_CYCLES_MT` in SKILL.md; `skipped_tasks|locked by another session|task-lock` across research.md/plan.md/implement.md; `orchestrator_mode` across core context/commands/scripts; literal `source .claude/scripts/command-gate-in.sh` across commands/ and skills/; test-file headers for the isolated-temp-root precedent.

### Key File Anchors (symbol/quoted-string, per the line-number caveat)

- `gate_in()` in `scripts/command-gate-in.sh` — the `return 1` hard-abort site.
- `cmd_acquire()` in `scripts/task-lock.sh` — same-session check, held-lock overlap scan, session-registry contention pass, three ABORT/WARN message variants.
- `acquire_named_mutex()` / `acquire_scope_mutex()` / `acquire_commit_mutex()` in `scripts/task-lock.sh` — the bounded-retry idiom to reuse for Tier 2.
- `#### Step 3: Topological Wave Assignment (Kahn's Algorithm)` in `commands/orchestrate.md` — illustrative-only pseudocode, `dependencies[]`-only input.
- `### AUTONOMOUS_GLOBAL` in `context/patterns/lit-stage4a-flow.md` — the interactive-vs-autonomous split precedent for Tier 4.
- `deferred_self_modifying: []` / `consecutive_no_dispatch_cycles: 0` in `skills/skill-orchestrate/SKILL.md` Stage MT-1/MT-3 — the convergence-protection precedent.
- `#### Step 2.5: Batch Admission Pre-Check (Gap C)` and `#### Step 3: Dispatch Skills` in `commands/research.md` (mirrored in `plan.md`/`implement.md`) — the plain-multi-task one-shot-drop gap.

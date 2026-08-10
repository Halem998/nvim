# Research Report: Task #944

**Task**: 944 - in_flight_session_registry
**Started**: 2026-07-28T00:00:00Z
**Completed**: 2026-07-28T00:00:00Z
**Effort**: standard
**Dependencies**: 942, 943 (both closed per state.json)
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/task-lock.sh`
- `agent-system/extensions/core/context/patterns/task-lock.md`
- `agent-system/extensions/core/scripts/command-gate-in.sh` / `command-gate-out.sh`
- `agent-system/extensions/core/commands/research.md` / `plan.md` / `implement.md` / `orchestrate.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/agents/general-implementation-agent.md`
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md`
- `agent-system/extensions/core/scripts/reap-session-runtime-files.sh`
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh`
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`
- `agent-system/extensions/core/context/patterns/multi-task-operations.md`
- `agent-system/extensions/core/scripts/claude-refresh.sh`
- `/home/benjamin/.config/nvim/.gitignore` (repo root, outside the source store)
**Artifacts**:
- This report

## Executive Summary

- `task-lock.sh` already has every low-level primitive the registry needs (atomic-on-creation
  `mkdir` exclusivity, tmp-file-rename atomic write via `write_holder`, `age_minutes`/`iso_now`/
  `now_epoch` helpers, a generalized named-mutex pair, and a `reap` command shape). The registry
  should ship as new subcommands on this same file, not a parallel script or a new mutex — and for
  the registry's specific shape (one file per already-globally-unique `session_id`, written only
  by its own owner) it needs LESS machinery than the task lock: no `mkdir` exclusivity gate is
  required at all, only the tmp-file-`mv` atomic write `write_holder` already demonstrates.
- The task description's "batch-identity problem" is already solved in the codebase and simply
  unused for this purpose: `research.md`/`plan.md`/`implement.md` Step 2 and `orchestrate.md`
  (line 330) all generate an **unsuffixed** `batch_session_id` before ever appending
  `_${task_num}` per task. The registry should register under that pre-suffix value directly —
  no new ID derivation scheme is needed.
- Two genuine, currently out-of-`file_scope` gaps were found and must be surfaced to the planner:
  (1) the implementer's phase-transition heartbeat checkpoint lives in
  `agent-system/extensions/core/agents/general-implementation-agent.md` (Stage 4D), a file the
  task's declared `file_scope` does not list; (2) `agent-system/extensions/core/root-files/.gitignore`
  deploys to `.claude/.gitignore`, **not** the repo root — it cannot cover `specs/.sessions/`,
  which lives at the repo root. The actual, already-precedented location is this repo's own root
  `/.gitignore`, itself outside `agent-system/extensions/core/**` and outside the declared
  `file_scope` (see Finding 9 below for the precedent from the just-completed session-scoping
  work, which already touched that exact file).
- Every "existing checkpoint" the task description names does exist and is the right hook: the
  single-task `skill-orchestrate/SKILL.md` Stage 3 cycle loop already heartbeats the per-task
  lock at a named anchor; the implementer's phase transition already heartbeats at
  `general-implementation-agent.md` Stage 4D. No new checkpoint needs inventing for either.
- PID liveness has an established idiom already in use (`kill -0 "$pid" 2>/dev/null`, in
  `claude-refresh.sh`); it should SHORTEN the stale wait only when a pid is confirmably dead,
  falling through to the existing time-threshold/mtime pattern otherwise — mirroring exactly how
  `reap-session-runtime-files.sh` already falls back to mtime when no better signal exists.

## Context & Scope

Task 944 PRODUCES a session registry at `specs/.sessions/{session_id}.json`; no gate may consult
it (consumption is a separate, later task). This research grounds the implementation against the
task-lock primitives, the existing wiring points, and the runtime-file-tracking/gitignore
machinery the just-completed session-scoping work (dependencies 942/943) already established, per
the VERIFIED GAP framing in `specs/state.json`'s task 944 entry (not re-derived here).

## Findings

### 1. `task-lock.sh` — exact existing primitives (reuse, do not fork)

Helper functions (module-level, no subcommand of their own — every `cmd_*` function composes
these):

| Function | Contract |
|---|---|
| `resolve_task_dir(task_number, [create_mode])` | Resolves `specs/{NNN}_{SLUG}/` via `state.json`'s `project_name`, falling back to a filesystem glob; `create_mode="create"` (opt-in, `cmd_acquire`-only) creates the dir + `reports/plans/summaries` subdirs when state.json names a task with no on-disk dir yet. |
| `now_epoch()` | `date -u +%s` |
| `iso_now()` | `date -u +%Y-%m-%dT%H:%M:%SZ` |
| `write_holder(lock_dir, session_id, task_number, operation, acquired_at, heartbeat_at, command)` | tmp-file-rename (`jq -n ... > holder.json.tmp && mv holder.json.tmp holder.json`) atomic-on-replace write; guards against empty `jq` output before the `mv`. |
| `read_holder_field(lock_dir, field)` | `jq -r --arg f "$field" '.[$f] // empty'` |
| `age_minutes(ts)` | GNU/BSD-portable ISO8601-to-epoch age in minutes; returns `999999` on unparseable input (never blocks a caller). |
| `get_file_scope(task_number)` | Returns task's `file_scope` as compact JSON array, or `"[]"` on any lookup failure — directly reusable for the registry's file_scope UNION field (call once per task in the batch, merge arrays). |
| `scopes_overlap(scope_a, scope_b)` | jq transcription of the directory-prefix overlap rule; not relevant to the registry itself (no overlap semantics required by this task), but shows the codebase's established jq-transcription discipline. |
| `find_held_locks(exclude_dir)` | Lists foreign `.lock` dirs at `-maxdepth 2`; not directly reusable (task-lock-specific), but its "skip corrupt/unreadable holder" pattern is the model for a session-registry equivalent. |
| `acquire_named_mutex(mutex_dirname, requested_stale, default_stale_sec, wait_budget_ms)` / `release_named_mutex(mutex_dirname)` | Generalized `mkdir`-based mutex, parameterized by directory name, already backing BOTH `.scope-lock` and `.commit-lock`. Available if the registry ever needs a shared-resource mutex, but **not needed for per-session registration** since `session_id` is globally unique per writer — each session only ever writes its own file. |

Dispatched subcommands (flat `case` at the bottom of the file): `acquire`, `heartbeat`,
`release`, `check`, `reap`, `init-marker`, `scope-acquire`, `scope-release`, `commit-acquire`,
`commit-release`. Constants: `TASK_LOCK_STALE_MIN` (default 30 min), `TASK_LOCK_REAP_MIN`
(default `TASK_LOCK_STALE_MIN * 4` = 120 min).

**Recommended shape for the registry's subcommands** (extending this same file, per the task's
"REUSE, DO NOT REINVENT" instruction): `session-register <session_id> <pid> <command> <task_numbers_json> <file_scope_json>` (writes via `write_holder`-style tmp-mv, no `mkdir` gate needed — see
above), `session-heartbeat <session_id>` (mirrors `cmd_heartbeat`'s best-effort/never-blocks
contract), `session-release <session_id>` (mirrors `cmd_release`'s idempotent-always-0 contract),
`session-reap [--dry-run]` (mirrors `cmd_reap`'s report-then-delete shape, but reads `pid` first
per Finding 7 below). `init-marker`'s exclusivity pattern (`mkdir "${file_path}.init"` +
tmp-mv + bounded self-heal recheck) is the closer template than `cmd_acquire`'s task-number lock
if any create-vs-resume ambiguity is ever a concern, but since `session_id` timestamps+hex are
effectively collision-free per writer, a plain `write_holder`-style unconditional write (no
existence check at all) is likely sufficient and simpler — flag this as an open design choice for
the plan, not a foregone conclusion.

### 2. `command-gate-in.sh` / `command-gate-out.sh` — exact insertion anchors

`gate_in()` (single function, `command-gate-in.sh`):
- `SESSION_ID` is generated at: `SESSION_ID="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')"`.
- The terminal-status guard runs next (`case "$TASK_STATUS" in completed|abandoned|expanded)`).
- The task-lock acquire anchor is the comment `# Task lock: acquire AFTER the terminal-status guard...` immediately followed by `bash .claude/scripts/task-lock.sh acquire "$task_number" "$operation" "$SESSION_ID" "/$operation $task_number"`.
- **Insertion point for session registration**: immediately after that `task-lock.sh acquire` call succeeds, before the `# Display operation header` comment. The exact `command` string to reuse is the same `"/$operation $task_number"` expression already constructed for the lock's `command` field. `task_numbers` is a one-element array `[$task_number]`; `file_scope` is `get_file_scope "$task_number"` (already defined in `task-lock.sh`, directly callable since this script sources nothing from task-lock.sh today but easily could, or the registration subcommand can internally call `get_file_scope` itself given just the task number).
- `PID`: use `$$` (the current shell PID) — the exact idiom `cmd_scope_acquire`/`cmd_commit_acquire` already use (`pid=$$`).

`command-gate-out.sh`:
- The release anchor is the comment `# Task lock: unconditional release, run FIRST, so it executes regardless of any downstream branch...` immediately followed by `bash .claude/scripts/task-lock.sh release "$task_number" "$session_id" 2>/dev/null || true`.
- **Insertion point for session release**: alongside this call (before or after), using the same `$session_id` (this script's third positional argument, matching the gate-in's `$SESSION_ID`).

### 3. Multi-task batch start/end sites

`research.md`, `plan.md`, `implement.md` all share an identical **Step 2: Generate Batch Session
ID**:
```bash
batch_session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```
immediately followed by **Step 3: Dispatch Skills**, which per-task acquires/releases the task
lock under `"${batch_session_id}_${task_num}"` (the suffixed derivative). **Register the batch
here, at Step 2, under the bare `batch_session_id`** (not any suffixed form) — `task_numbers` is
the full `validated_tasks` array, `file_scope` is the union of `get_file_scope()` over every
task in that array.

Release/completion belongs at **Step 4: Batch Git Commit** / **Step 5: Consolidated Output** —
the point after all per-task skill invocations (parallel Skill tool calls dispatched once, not a
multi-cycle loop) have returned. There is no intra-batch heartbeat need for these three commands'
own multi-task loops, since Step 3 dispatches once and waits for all parallel results — the
registry entry's `started_at` plus the eventual release brackets the whole operation without a
cycle boundary in between.

`orchestrate.md` (line 330) generates its own `batch_session_id` the byte-identical way, then
passes it as `session_id` into `skill-orchestrate/SKILL.md`'s Stage MT-1 (`args: "... session_id={batch_session_id} ..."`, and the `.orchestrator-multi-state-${batch_session_id}.json`
init at Stage MT-1). **Stage MT-1 is the batch-start registration site**; **Stage MT-5
(Multi-Task Postflight)** — which already computes `exit_status` and removes/preserves
`mt_state_file` — is the batch-completion release site.

**Single-task `/orchestrate` is already covered**: `task-lock.md`'s own "Consumers" section names
`/orchestrate`'s single-task CHECKPOINT 1/2 as going through `command-gate-in.sh`/
`command-gate-out.sh` exactly like `/research`/`/plan`/`/implement`/`/revise` — no separate
single-task orchestrate wiring is needed beyond Finding 2 above.

### 4. Batch-identity problem — already resolved, just needs use

The task description frames this as unsolved ("a batch has no stable identity to register
under"), but the codebase already computes exactly that stable identity: `batch_session_id`
(unsuffixed) is generated once, BEFORE the per-task `_${task_num}` suffix is ever appended for
task-lock acquire/release calls (see Finding 3; identical pattern confirmed in
`context/patterns/multi-task-operations.md`'s "Batch Session ID" section — "Per-task session:
`{batch_session_id}_{task_num}`"). **No new derivation scheme is needed or should be invented.**
The registry simply keys off the value that already exists at the moment each batch loop begins,
before it gets suffixed for anything else. This also means the registry never collides with
per-task task-lock sessions, since `specs/.sessions/{session_id}.json` and `specs/{NNN}_{SLUG}/.lock/holder.json` are wholly separate paths/mechanisms keyed on the SAME identifier
family but never contending for the same file.

### 5. Heartbeat checkpoints — confirmed, no new checkpoint needed

- **Single-task `/orchestrate`**: `skill-orchestrate/SKILL.md` Stage 3 cycle loop already
  heartbeats the per-task lock at the anchor comment `# Task-lock heartbeat: refresh at the same
  per-cycle boundary as the loop guard, so a ...` followed by
  `bash .claude/scripts/task-lock.sh heartbeat "$task_number" "$session_id" 2>/dev/null || true`.
  Add the registry heartbeat call immediately adjacent to this exact line.
- **Implementer phase transition**: `skill-implementer/SKILL.md` itself has NO heartbeat call —
  it explicitly documents (Stage 5's "Task-lock heartbeat note") that it delegates the entire
  phase loop to `general-implementation-agent` in one Agent call, with no per-phase-transition
  point of its own. The actual heartbeat lives in
  **`agent-system/extensions/core/agents/general-implementation-agent.md`, Stage 4D ("D. Mark
  Phase Complete")**, at the line
  `bash .claude/scripts/task-lock.sh heartbeat "{task_number}" "{session_id}" 2>/dev/null || true`.
  **This file is NOT in task 944's declared `file_scope`** — see the Executive Summary gap and
  Decisions below.
- **Multi-task orchestrate batch heartbeat**: no equivalent per-cycle task-lock heartbeat call
  exists for multi-task locks today, because Stage MT-4's per-task `acquire`/`release` brackets a
  single dispatch rather than being held across cycles (confirmed: acquire at
  `bash .claude/scripts/task-lock.sh acquire "$task_num" "$op" "${session_id}_${task_num}" "/orchestrate (multi-task)"`, release at
  `bash .claude/scripts/task-lock.sh release "$task_num" "${session_id}_${task_num}"`, both inside
  Stage MT-4's per-task loop). The structurally analogous per-cycle checkpoint for a BATCH-level
  registry heartbeat (distinct from any per-task lock) is **Stage MT-3's loop top, step 1
  ("Status refresh")** — the same place the loop already re-reads task statuses once per cycle.
  This is a new use of an existing checkpoint, not an invented one.
- **research.md/plan.md/implement.md multi-task loops**: no cycle boundary exists (Step 3
  dispatches once); no intra-batch heartbeat is needed beyond register-then-release (Finding 3).

### 6. `skill-refresh/SKILL.md` — explicit-invocation-only reap precedent

Two existing reap steps, both gated behind explicit `/refresh` (never the hourly
`claude-refresh.timer`, which runs only `claude-refresh.sh`'s process cleanup):
- **Step 4** ("Reap Stale Task Locks"): `.claude/scripts/task-lock.sh reap [--dry-run]`, echoing
  output verbatim.
- **Step 4.5** ("Reap Stale Session-Scoped Orchestration Files"): `.claude/scripts/reap-session-runtime-files.sh [--dry-run]`, same verbatim-echo contract, explicitly numbered `X.5` so later
  steps' numbering (and `refresh.md` cross-references) never need to shift.

A new **Step 4.6** ("Reap Stale Session Registry Entries" or similar) should mirror Step 4.5's
exact shape: same `--dry-run` passthrough, same verbatim-echo instruction, same numbering
discipline (append after 4.5, don't renumber). `reap-session-runtime-files.sh` itself is a strong
implementation template independent of whether the registry reap ends up as a `task-lock.sh`
subcommand or its own sibling script — its threshold-constant pattern
(`ORCHESTRATOR_SESSION_REAP_MIN`, env-overridable, default 240 min, explicitly NOT reusing
`TASK_LOCK_REAP_MIN` because a multi-task batch can run far longer than a single task's lock
window) is directly analogous reasoning for a session-registry-specific threshold constant.

### 7. PID liveness — shorten, never solely rely on

Existing idiom, used today in `claude-refresh.sh` (twice) and `test-state-write-concurrency.sh`:
```bash
kill -0 "$pid" 2>/dev/null
```
(`kill -0` sends no signal; it only tests existence/permission, exit 0 = process exists.) Neither
`cmd_scope_acquire` nor `cmd_commit_acquire` currently USES pid liveness to shorten anything —
they record `pid=$$` into their owner tokens purely for diagnostic naming in timeout messages, not
as a staleness signal. The registry is the first consumer to actually apply pid liveness to
staleness. Recommended two-signal design, consistent with the task description's own framing
("SHORTEN the stale wait... keep the time threshold as fallback"):
1. If `kill -0 "$pid" 2>/dev/null` fails (pid confirmably gone): treat as reap-eligible
   immediately, bypassing the time threshold — a dead pid is unambiguous.
2. If the pid is alive, OR liveness cannot be determined (this is a same-host-only signal: a pid
   recorded by a session that later runs the reap sweep from a different host, or a reused pid
   number, both defeat it silently) — fall through to the SAME `heartbeat_at`-age time-threshold
   pattern `task-lock.sh reap` and `reap-session-runtime-files.sh` already use. Never treat "pid
   alive" as proof of liveness on its own (pid reuse), and never treat "pid dead" as ambiguous
   (it never legitimately means anything but dead).

### 8. `context/patterns/task-lock.md` — extend, do not fork

The document's existing structure gives each mechanism its own top-level `##` section with a
schema, a per-subcommand contract, exit codes, and (where relevant) its own "Consumers" list —
see `## Reap Contract`, `## Scope-Mutex CLI: scope-acquire / scope-release`, and
`## Commit-Mutex CLI: commit-acquire / commit-release` as the three existing examples of this
shape. A new `## Session Registry` section (or `## Session-Registry CLI`, naming TBD by the plan)
following the identical shape is the correct extension point. Two existing sections must also be
updated, not just appended to: **"Consumers (Four Distinct Wiring Paths)"** (add a fifth path —
register/heartbeat/release across the single-task gate scripts, the three commands' Step 2/4-5,
and orchestrate's Stage MT-1/MT-5) and **"Related Documentation"** (add the registry's own file
and any new test file, mirroring how `test-task-lock-reap.sh` is already cross-referenced there).

### 9. `specs/.sessions/` gitignore coverage and runtime-file classification

**Critical finding**: `agent-system/extensions/core/root-files/.gitignore` — the file literally
named in task 944's `file_scope` — deploys to `.claude/.gitignore`, not the repo root. This is
`orchestrator-runtime-files.md`'s own documented fact (`"Consumer Repo Setup"` section):
`copy_root_files()` deploys `root-files/` into the consumer's `.claude/` directory, and a
`specs/*/` pattern placed there "would resolve to `.claude/specs/*/` and silently match nothing."
Verified directly: this repo's actual `agent-system/extensions/core/root-files/.gitignore`
content is four unrelated lines (`settings.local.json` comment, hook logs, `logs/`, `output/`,
`*.tmp`) — it does not even attempt to cover any `specs/**` runtime-file pattern today, and
editing it would have zero effect on `specs/.sessions/` tracking regardless of what pattern is
added.

The ACTUAL location that governs `specs/**` tracking is this repo's own **root**
`/home/benjamin/.config/nvim/.gitignore` — a plain repo file, outside
`agent-system/extensions/core/**` entirely, and therefore outside this task's declared
`file_scope`. It already carries a hand-maintained "Ephemeral orchestrator runtime state" block
(lines 24-40) that was added by hand per `orchestrator-runtime-files.md`'s own instructions during
the just-completed session-scoping work (dependencies 942/943) — the exact same precedent this
task should follow: add a `specs/.sessions/` (or `**/.sessions/` for consistency with the block's
existing `**/`-prefixed style) pattern to that SAME existing block, by hand, in the repo root
`.gitignore`. This is not a source-store-rule violation — the rule prohibits hand-authoring INTO
`.claude/**` (a disposable deploy artifact); the repo root `.gitignore` is a normal, permanently
git-tracked file that the source store cannot reach by design, exactly as
`orchestrator-runtime-files.md` already documents.

`context/standards/orchestrator-runtime-files.md` (in `file_scope`, correctly) needs two
additions: a new Class Table row for `specs/.sessions/{session_id}.json` (classified
**Ephemeral** — like `.return-meta-multi-{session_id}.json`, it currently "has no reader anywhere
in the source store" per this task's own SCOPE BOUNDARY that nothing may consume it yet), and the
new pattern added to the "Consumer Repo Setup" code block that this file instructs consumer repos
to hand-copy.

`scripts/check-runtime-file-tracking.sh` (in `file_scope`, correctly) needs: a new representative
probe path in `EPHEMERAL_PROBES` (Check A/B), e.g.
`"specs/.sessions/sess_0000000000_probe.json"`, and a corresponding regex in `b_patterns`, e.g.
`'\.sessions/[^/]+\.json$'`.

`manifest.json`'s script-list array (confirmed to already enumerate `task-lock.sh`,
`reap-session-runtime-files.sh`, and `check-runtime-file-tracking.sh` by literal filename, for
`copy_scripts()` deploy purposes) needs a change **only if** the plan adds a brand-new sibling
script rather than extending `task-lock.sh` in place (Finding 1's recommendation). If everything
lands as new `task-lock.sh` subcommands, `manifest.json` needs no change at all — its `file_scope`
inclusion should be treated as precautionary, not a mandate to touch it.

## Decisions

- **Implement as `task-lock.sh` subcommands**, not a sibling script or a parallel implementation —
  directly satisfies the task's REUSE instruction and keeps one canonical file self-consistent
  with its own header usage comment (which already documents 10 subcommands; a session-registry
  family of 3-4 more is a natural, additive extension).
- **Register under the pre-suffix `batch_session_id`** for all multi-task/batch paths, and under
  `SESSION_ID` for the single-task gate-script path — resolves the "batch-identity problem" using
  an identifier the codebase already computes, per Finding 4.
- **No `mkdir`-exclusivity gate needed for registration itself** — unlike the task-number lock
  (which arbitrates between two DIFFERENT sessions contending for the SAME resource), a session
  registers only its own file under its own globally-unique id; the tmp-file-`mv` atomicity
  `write_holder` already provides is sufficient to prevent a reap sweep from ever observing a
  half-written file.
- **PID liveness shortens, never replaces, the time-based threshold** — a dead pid is an immediate,
  unambiguous reap signal; an alive (or undeterminable) pid falls through to the same
  `heartbeat_at`-age fallback every other reap mechanism in this codebase already uses.

## Risks & Mitigations

- **Risk**: the planner scopes edits strictly to the declared `file_scope` and silently misses
  the implementer heartbeat anchor (`general-implementation-agent.md`, not listed) or the repo
  root `.gitignore` (not listed, and not even inside `agent-system/extensions/core/**`).
  **Mitigation**: both gaps are called out explicitly above (Findings 5 and 9) with exact anchors
  so the plan can either widen its touched-file set consciously or make an explicit, documented
  decision to skip the implementer per-phase heartbeat for v1 (relying on the time-threshold
  fallback alone for implement-dispatch staleness) — either is defensible, but it must be a
  decision, not an oversight.
- **Risk**: conflating the registry's file-granularity concerns with the task-number lock's
  cross-session-contention concerns could pull unneeded `mkdir`-gate complexity into the
  registration subcommand. **Mitigation**: Finding 1 explicitly recommends the lighter
  `write_holder`-only shape and names `init-marker` only as a fallback template if resume/replay
  ambiguity turns out to matter.
- **Risk**: pid-liveness is inherently host-scoped and can silently pass on a foreign host or a
  reused pid, giving false confidence. **Mitigation**: Finding 7's two-signal design treats
  "pid alive or undeterminable" as "no additional signal, fall through to time threshold" —
  never as proof of liveness on its own.

## Context Extension Recommendations

- **Topic**: session-registry-specific reap threshold constant.
  **Gap**: no existing constant name is a natural fit (`TASK_LOCK_REAP_MIN` is task-lock-scoped;
  `ORCHESTRATOR_SESSION_REAP_MIN` is scoped to the two batch-orchestration singleton files).
  **Recommendation**: the plan should introduce and document its own env-overridable constant
  (e.g. a session-registry-scoped name) in `context/patterns/task-lock.md`'s new section, following
  the same derivation-and-rationale discipline `TASK_LOCK_REAP_MIN`'s comment already models.

## Appendix

### Search queries / commands used

- `jq -r '.active_projects[] | select(.project_number==944)' specs/state.json`
- `grep -rn "kill -0\|/proc/\|ps -p" scripts/ context/ skills/`
- `grep -n "Stage MT\|multi-task\|task-lock.sh acquire\|task-lock.sh release" commands/research.md commands/plan.md commands/implement.md commands/orchestrate.md`
- `grep -n "sess_\|session_id\|suffix" context/patterns/multi-task-operations.md`
- `grep -n "heartbeat" skills/skill-orchestrate/SKILL.md skills/skill-implementer/SKILL.md agents/general-implementation-agent.md`
- `grep -n "task-lock.sh\|reap-session-runtime-files.sh\|check-runtime-file-tracking.sh" manifest.json`
- Direct `Read` of `task-lock.sh`, `task-lock.md`, `command-gate-in.sh`, `command-gate-out.sh`,
  `reap-session-runtime-files.sh`, `orchestrator-runtime-files.md`, `check-runtime-file-tracking.sh`,
  `skill-refresh/SKILL.md`, repo root `.gitignore`, `root-files/.gitignore`

### References

- `agent-system/extensions/core/scripts/task-lock.sh`
- `agent-system/extensions/core/context/patterns/task-lock.md`
- `agent-system/extensions/core/scripts/command-gate-in.sh`
- `agent-system/extensions/core/scripts/command-gate-out.sh`
- `agent-system/extensions/core/commands/research.md`
- `agent-system/extensions/core/commands/plan.md`
- `agent-system/extensions/core/commands/implement.md`
- `agent-system/extensions/core/commands/orchestrate.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md`
- `agent-system/extensions/core/agents/general-implementation-agent.md`
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md`
- `agent-system/extensions/core/scripts/reap-session-runtime-files.sh`
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh`
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`
- `agent-system/extensions/core/context/patterns/multi-task-operations.md`
- `agent-system/extensions/core/scripts/claude-refresh.sh`
- `agent-system/extensions/core/root-files/.gitignore`
- `/.gitignore` (repo root)

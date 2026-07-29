# Implementation Plan: In-Flight Orchestration Session Registry

- **Task**: 944 - Add an in-flight orchestration session registry with liveness and reap
- **Status**: [IMPLEMENTING]
- **Effort**: 9 hours
- **Dependencies**: 942, 943 (both closed)
- **Research Inputs**: specs/944_in_flight_session_registry/reports/01_in-flight-session-registry.md
- **Artifacts**: plans/01_in-flight-session-registry.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a session registry at `specs/.sessions/{session_id}.json` that records which orchestration
sessions are actually in flight — `session_id`, `pid`, `command`, `task_numbers`, the UNION of
those tasks' declared `file_scope`, `started_at`, `heartbeat_at`. The registry ships as four new
subcommands on the existing `scripts/task-lock.sh`, reusing its `write_holder`-style tmp-file-rename
atomic write, `iso_now`/`now_epoch`/`age_minutes`, `get_file_scope`, and `reap` report-then-delete
shape. This task **only produces** the registry: no admission or refusal decision changes, and no
existing gate begins consulting it. Definition of done is a registry that registers, heartbeats,
releases, and reaps across every single-task and batch path, with an isolated-temp-root test suite
proving the contract, and a verified-unchanged admission surface.

### Research Integration

The research report supplies the exact anchors this plan depends on and they are treated as
verified, not re-derived:

- `task-lock.sh` already has every primitive needed; the registry needs **less** machinery than the
  task lock (no `mkdir` exclusivity gate — each session writes only its own globally-unique-id'd
  file, so `write_holder`'s tmp-file-`mv` atomicity alone prevents a reap sweep from observing a
  half-written file).
- The "batch has no stable identity" framing in the task description is already solved and merely
  unused: `commands/research.md`/`plan.md`/`implement.md` Step 2 and `commands/orchestrate.md`
  Step 4 all generate an **unsuffixed** `batch_session_id` before appending `_${task_num}` per task.
  Register under that pre-suffix value; invent no new derivation scheme.
- Heartbeat checkpoints already exist and must be reused, never added to: `skill-orchestrate/SKILL.md`
  Stage 3's `task-lock.sh heartbeat` line, and the implementer's per-phase heartbeat which lives in
  `agents/general-implementation-agent.md` Stage 4D — **not** in `skill-implementer/SKILL.md`.
- `root-files/.gitignore` deploys to `.claude/.gitignore` and **cannot** cover `specs/.sessions/`.
  The real coverage point is this repo's own root `/.gitignore`, which already hand-maintains an
  "Ephemeral orchestrator runtime state" block.
- PID liveness (`kill -0 "$pid" 2>/dev/null`, the idiom already in `claude-refresh.sh`) may only
  SHORTEN the stale wait; the `heartbeat_at`-age threshold stays as the fallback.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found; no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- A registry entry format and four `task-lock.sh` subcommands (`session-register`,
  `session-heartbeat`, `session-release`, `session-reap`) that produce and clean up
  `specs/.sessions/{session_id}.json`.
- Registration at every session-start site (single-task gate, the three multi-task command batch
  loops, the orchestrate batch path); release at every corresponding completion site.
- Heartbeat at existing checkpoints only.
- PID-liveness-shortened reap, wired into `/refresh` behind explicit invocation only.
- Gitignore coverage, runtime-file classification, and a check-script probe for the new path.
- `context/patterns/task-lock.md` extended (never forked) with the registry's contract.
- An isolated-temp-root test suite following the `test-task-lock-reap.sh` precedent.

**Non-Goals**:
- **Any consumer.** No gate, admission script, or skill may read the registry in this task. In
  particular `scripts/orchestrate-batch-admit.sh` and `cmd_acquire`'s overlap scan must be
  byte-unchanged. Consumption is the next task in this topic.
- A `session-list` / query subcommand. Deliberately deferred to the consuming task so this task
  ships no read surface at all; `session-reap --dry-run` provides the only operator visibility
  needed here.
- Changing any existing task-lock subcommand's behavior, exit codes, or thresholds.
- Editing `root-files/.gitignore` (see Phase 3's reasoned exclusion — editing it would have zero
  effect on `specs/.sessions/` tracking).
- Cross-host liveness. `kill -0` is a same-host signal only; the time threshold remains
  authoritative everywhere else.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Recorded `pid` is the short-lived helper script's own `$$`, not the long-lived session process — making every entry look instantly dead and letting the pid shortcut reap live sessions | H | H | Two independent guards, both in Phase 1: (a) a bounded ancestor walk resolves the nearest `claude` process rather than blindly using `$$`; (b) the dead-pid shortcut is floored by `SESSION_REGISTRY_DEAD_PID_MIN` (default 10 min of `heartbeat_at` age), so a misresolved pid can never reap a just-heartbeated entry |
| Scope creep into consumption — a phase "helpfully" wires the registry into an admission decision | H | M | Explicit Non-Goal above plus Phase 10's mechanical audit: grep the whole source store for reads of `specs/.sessions/` and assert the only hits are `task-lock.sh`, the new test, and docs; assert `orchestrate-batch-admit.sh` is unchanged in the diff |
| Pulling `mkdir`-exclusivity complexity from `cmd_acquire` into registration, where it is not needed | M | M | Phase 1 explicitly specifies the lighter `write_holder`-style unconditional tmp-mv write and names `init-marker` only as a fallback template that is NOT to be used unless a concrete resume/replay ambiguity is demonstrated |
| Editing `root-files/.gitignore` (which IS in the declared file scope) and believing the path is covered when it is not | M | M | Phase 3 records this as a reasoned exclusion with the mechanism evidence, and Phase 10 runs `check-runtime-file-tracking.sh` as the empirical proof of actual coverage |
| A brand-new script (`test-session-registry.sh`) never reaches `.claude/scripts/` on an already-deployed repo — a known open gap in the extension loader's `copy_scripts` path | M | M | Phase 9 adds the manifest entry (the correct source-store change) and Phase 10 verifies presence in the deploy tree, reporting a manual copy if the loader gap bites; the gap itself is out of scope and must not be "fixed" here |
| Editing `skill-orchestrate/SKILL.md` and `agents/general-implementation-agent.md` when only the latter was added to the declared file scope | L | M | Consciously widened, recorded here: the orchestrate cycle-loop heartbeat and Stage MT-1/MT-5 register/release anchors are named by the task description's own WIRING section and cannot be reached without touching that skill file. This is a decision, not an oversight |
| Two phases editing `skill-orchestrate/SKILL.md` concurrently | M | L | Phase 7 depends on Phase 6 specifically to serialize that file |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2, 4, 5, 6, 8, 9 | 1 |
| 3 | 7 | 6 |
| 4 | 10 | 2, 3, 4, 5, 7, 8, 9 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Session-Registry Subcommands on task-lock.sh [COMPLETED]

**Goal**: Add the registry primitive — four subcommands, two threshold constants, and the
supporting helpers — to `scripts/task-lock.sh`, reusing existing helpers and changing no existing
subcommand.

**Tasks**:
- [x] Read the current `scripts/task-lock.sh` in full before editing; anchor on symbol names and
      quoted strings, never on line numbers.
- [x] Add two env-overridable constants beside `TASK_LOCK_STALE_MIN` / `TASK_LOCK_REAP_MIN`, each
      with a derivation-and-rationale comment in the same style those two already model:
      - `SESSION_REGISTRY_REAP_MIN` (default 240) — deliberately NOT derived from
        `TASK_LOCK_REAP_MIN`, for the same reason `ORCHESTRATOR_SESSION_REAP_MIN` is not: a batch
        session can legitimately run far longer than any single task's lock window.
      - `SESSION_REGISTRY_DEAD_PID_MIN` (default 10) — the floor below which the dead-pid shortcut
        never fires, guarding against a misresolved or reused pid.
- [x] Add helper `session_registry_dir()` returning `$PROJECT_ROOT/specs/.sessions` and creating it
      with `mkdir -p` on the register path only (heartbeat/release/reap stay non-creating, matching
      how `resolve_task_dir` confines creation to `cmd_acquire`).
- [x] Add helper `resolve_session_pid()`: a bounded ancestor walk (at most 10 hops, stopping at pid
      1) from `$$` upward looking for a process whose command name contains `claude`; returns that
      pid and a `pid_source` token. Fall back in order: `ancestor-claude` -> `ppid` -> `self`. An
      explicit `--pid N` argument overrides the walk entirely and records `pid_source=explicit`.
- [x] Add helper `write_session_entry()` modeled byte-for-byte on `write_holder`'s shape: `jq -n`
      into `<file>.tmp`, empty-output guard, then `mv`. **No `mkdir` exclusivity gate** — each
      session writes only its own globally-unique-id'd file, so tmp-mv atomicity is sufficient.
      Do not adopt `init-marker`'s claim-and-recheck pattern.
- [x] Add `cmd_session_register`: signature
      `session-register <session_id> <command> <task_numbers_csv> [--pid N]`. Normalizes the CSV to
      a JSON integer array with `jq`; computes the `file_scope` UNION internally by calling the
      existing `get_file_scope` once per task number and merging with `jq -s 'add | unique'` (so
      callers never construct the union themselves). Upsert semantics: if an entry for this
      `session_id` already exists and parses, preserve its `started_at` and refresh `heartbeat_at`
      — mirroring `cmd_acquire`'s same-session re-entry safety property.
- [x] Add `cmd_session_heartbeat <session_id>`: refreshes `heartbeat_at` only, via the same tmp-mv
      write. Mirrors `cmd_heartbeat`'s contract exactly — a missing or unparseable entry is a
      stderr warning and exit 0, never a block on the caller.
- [x] Add `cmd_session_release <session_id>`: `rm -f` the entry; idempotent, always exit 0, mirroring
      `cmd_release`.
- [x] Add `cmd_session_reap [--dry-run]`: mirrors `cmd_reap`'s report-then-delete shape and its
      "skip corrupt/unreadable entry rather than silently ignore" discipline. Two-signal staleness,
      in this order: (1) if `kill -0 "$pid" 2>/dev/null` FAILS (pid confirmably gone) AND
      `heartbeat_at` age exceeds `SESSION_REGISTRY_DEAD_PID_MIN`, reap with reason `dead-pid`;
      (2) otherwise (pid alive, or liveness undeterminable) fall through to `heartbeat_at` age
      exceeding `SESSION_REGISTRY_REAP_MIN`, reason `stale-heartbeat`. Never treat "pid alive" as
      proof of liveness. An entry with a missing/unparseable body falls back to the file's own mtime,
      exactly as `cmd_reap` falls back to the `.lock` directory mtime. Always exit 0.
- [x] Wire all four into the bottom `case "$SUBCMD"` dispatch with argument-count usage guards
      matching the surrounding entries' style.
- [x] Extend the top-of-file `# Usage:` block and the `# Exit codes:` block with the four new
      subcommands and the registry entry layout (`specs/.sessions/{session_id}.json` and its field
      list), matching the existing header's documentation density.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts (a) exactly four new subcommands and two new constants
suffice, and (b) `resolve_session_pid()`'s ancestor walk can actually find a `claude` process on
this host. Confirm (a) by re-reading the register/heartbeat/release/reap call sites named in Phases
4-8 and checking none needs a fifth verb. Confirm (b) empirically at implementation time by running
the resolver from a real Bash tool invocation and printing the resolved pid plus `pid_source`; if it
resolves to `self` or `ppid` rather than `ancestor-claude`, record that outcome in the phase notes —
the `SESSION_REGISTRY_DEAD_PID_MIN` floor is what makes the fallback safe, so a `ppid` result is an
acceptable outcome, not a blocker.

**Empirical confirmation (recorded at implementation time)**: (a) confirmed — Phases 4-8's wiring sites use exactly `session-register`/`session-heartbeat`/`session-release`/`session-reap`, no fifth verb needed. (b) confirmed — `resolve_session_pid()` run live from a Bash tool invocation resolved `pid_source=ancestor-claude` (found `claude` two hops up the ancestor chain from the helper's own `$$`), not the `ppid`/`self` fallback; the `SESSION_REGISTRY_DEAD_PID_MIN` floor was also verified directly with synthetic fixtures: a dead-pid entry younger than the floor survives reap, one older reaps with reason `dead-pid`, a live-pid entry reaps only past `SESSION_REGISTRY_REAP_MIN` with reason `stale-heartbeat`, and a corrupt entry falls back to file mtime and reaps/skips accordingly.

**Files to modify**:
- `agent-system/extensions/core/scripts/task-lock.sh` - new constants, helpers, four `cmd_session_*`
  functions, dispatch entries, header documentation

**Verification**:
- `bash -n agent-system/extensions/core/scripts/task-lock.sh` parses clean.
- `bash agent-system/extensions/core/scripts/test-task-lock-reap.sh` still exits 0 (no existing
  behavior regressed).
- Manual smoke: register a synthetic session, `session-reap --dry-run` reports it as below
  threshold, `session-heartbeat` refreshes it, `session-release` removes it, a second
  `session-release` still exits 0.
- `git diff` confirms no existing `cmd_*` function body changed.

---

### Phase 2: Extend the Task-Lock Contract Document [NOT STARTED]

**Goal**: Document the registry in `context/patterns/task-lock.md` as a new top-level section
following the shape the document already uses, and update the two existing sections that go stale
otherwise. Extend, never fork.

**Tasks**:
- [ ] Read the current `context/patterns/task-lock.md` in full, in particular `## Reap Contract`,
      `## Scope-Mutex CLI: scope-acquire / scope-release`, and
      `## Commit-Mutex CLI: commit-acquire / commit-release` — the three existing examples of the
      per-mechanism section shape to follow.
- [ ] Add a `## Session-Registry CLI: session-register / session-heartbeat / session-release /
      session-reap` section containing: the entry schema with every field, a `###` subsection per
      subcommand with its contract and exit codes, the two threshold constants with their derivation
      rationale, and an explicit statement of why no `mkdir` exclusivity gate is used (globally
      unique id, single writer per file, tmp-mv atomicity sufficient).
- [ ] Document the two-signal staleness rule verbatim in that section: dead pid shortens (floored by
      `SESSION_REGISTRY_DEAD_PID_MIN`), alive-or-undeterminable falls through to the
      `heartbeat_at`-age threshold, and `kill -0` is a same-host-only signal that is never proof of
      liveness.
- [ ] Add an explicit "Non-Goal: no reader" note in the new section stating that nothing consults the
      registry yet, and that a future reader-adder must add its own freshness/ownership checks
      together with the reader — mirroring how `orchestrator-runtime-files.md` phrases the same
      obligation for `specs/.return-meta-multi-{session_id}.json`.
- [ ] Update `## Consumers (Four Distinct Wiring Paths)` to a fifth path covering register/heartbeat/
      release across the gate scripts, the three commands' batch steps, the orchestrate stages, and
      the implementer per-phase checkpoint. Rename the heading to match the new count.
- [ ] Update `## Related Documentation` with the new test suite and
      `context/standards/orchestrator-runtime-files.md`.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/task-lock.md` - new section plus two updated
  sections

**Verification**:
- Diff read-through confirms every hunk is prose/markdown with no executable surface.
- Every subcommand name, constant name, default value, and exit code in the new section matches
  Phase 1's implementation exactly (cross-check against `task-lock.sh`'s header block).
- The `Consumers` heading's stated count matches the number of paths actually listed.
- No task-number citations appear anywhere in the file (deliverable outside `specs/**`).

---

### Phase 3: Gitignore Coverage and Runtime-File Classification [COMPLETED]

**Goal**: Make `specs/.sessions/` ignored, classified, and mechanically verified — at the location
that actually governs `specs/**` tracking.

**Tasks**:
- [x] Read the CURRENT state of all three targets before editing — the repo root `/.gitignore`,
      `scripts/check-runtime-file-tracking.sh`, and
      `context/standards/orchestrator-runtime-files.md` were all modified by the just-completed
      session-scoping work; do not edit from a remembered version.
- [x] Add `**/.sessions/` to the existing "Ephemeral orchestrator runtime state" block in the repo
      root `/.gitignore`, matching that block's existing `**/`-prefixed style and placement. This is
      the ONE sanctioned exception to the source-store rule for this task.
- [x] Add a Class Table row to `orchestrator-runtime-files.md` for
      `specs/.sessions/{session_id}.json`: Writer = `task-lock.sh session-register`/`session-heartbeat`;
      Reader = **none in the source store today** (state it as plainly as the
      `.return-meta-multi-{session_id}.json` row already does); Cleanup site =
      `task-lock.sh session-release` at session end, `session-reap` after
      `SESSION_REGISTRY_REAP_MIN`; Disposition = **Ephemeral**.
- [x] Add the same `**/.sessions/` pattern to that file's "Consumer Repo Setup" gitignore code block
      (the block consumer repos hand-copy).
- [x] Add `"specs/.sessions/sess_0000000000_probe.json"` to `EPHEMERAL_PROBES` in
      `check-runtime-file-tracking.sh` (Check A / Check B).
- [x] Add `'/\.sessions/[^/]+\.json$'` to `b_patterns` in the same script.
- [x] Record the reasoned exclusion for `root-files/.gitignore` in the plan's execution notes and,
      briefly, in `orchestrator-runtime-files.md`'s existing "Consumer Repo Setup" prose if it does
      not already say so: that file deploys to `.claude/.gitignore`, so a `specs/`-rooted pattern
      placed there resolves to `.claude/specs/` and matches nothing. It is deliberately NOT edited.

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly three files need editing and that
`root-files/.gitignore` needs none despite being in the declared file scope. Confirm by running
`git check-ignore -v specs/.sessions/sess_0000000000_probe.json` after the `/.gitignore` edit and
observing the matching line comes from the repo root file; then confirm
`bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` passes Check A for the
new probe.

**Empirical confirmation (recorded at implementation time)**: exactly three files edited (`/.gitignore`, `orchestrator-runtime-files.md`, `check-runtime-file-tracking.sh`); `root-files/.gitignore` was NOT touched, per the reasoned exclusion above. `git check-ignore -v specs/.sessions/sess_0000000000_probe.json` names `.gitignore:41:**/.sessions/`
(the repo root file), and `check-runtime-file-tracking.sh` passes all three checks including the new `.sessions` probe under Check A.

**Files to modify**:
- `/.gitignore` (repo root) - one pattern added to the existing ephemeral block
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - Class Table row,
  Consumer Repo Setup block, root-files exclusion note
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` - one probe, one pattern

**Verification**:
- `bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` exits 0 with the new
  probe reported OK under Check A and Check C still passing.
- `bash -n agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` parses clean.
- `git check-ignore -v specs/.sessions/anything.json` names the repo root `.gitignore` line.

---

### Phase 4: Single-Task Gate Wiring [COMPLETED]

**Goal**: Register at single-task session start and release at single-task session end, using the
identifiers the gate scripts already construct.

**Tasks**:
- [x] In `scripts/command-gate-in.sh`, insert the registration call immediately after the
      `task-lock.sh acquire` call succeeds and before the `# Display operation header` comment.
      Anchor on those quoted strings, not on line numbers.
- [x] Use `$SESSION_ID` (the value the script already generates) as the registry key, `"/$operation
      $task_number"` as the `command` — the same expression already passed as the lock's `command`
      field — and the single task number as the `task_numbers` CSV.
- [x] Make the call best-effort and non-blocking: `... 2>/dev/null || true`. Registration failure
      must never turn a successful lock acquire into a refusal. This task changes no admission
      decision.
- [x] In `scripts/command-gate-out.sh`, insert the release call alongside the existing unconditional
      `task-lock.sh release` line, using the same `$session_id` positional argument, with the same
      `2>/dev/null || true` best-effort shape and the same "runs first, regardless of downstream
      branch" placement rationale.
- [x] Add a one-line comment at each site naming the registry and pointing at
      `context/patterns/task-lock.md`'s new section, matching the density of the adjacent task-lock
      comments.

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/scripts/command-gate-in.sh` - registration after lock acquire
- `agent-system/extensions/core/scripts/command-gate-out.sh` - release alongside lock release

**Verification**:
- `bash -n` parses both scripts clean.
- `git diff` shows the lock acquire/release calls themselves unchanged and no new early-exit or
  refusal path introduced.
- Manual end-to-end: run a single-task gate-in/gate-out pair against a scratch task and confirm the
  entry appears in `specs/.sessions/` and is gone afterward.

**Implementation note**: the deployed `.claude/scripts/` copy of `task-lock.sh` was stale at the time this phase landed (known `copy_scripts` loader gap — see Phase 10's tracking item), so the "manual end-to-end" verification bullet is deferred to Phase 10's post-deploy audit rather than exercised here against a stale deployed script. `bash -n` and the `git diff` read-through were both run and pass.

---

### Phase 5: Multi-Task Command Batch Wiring [COMPLETED]

**Goal**: Register each `/research`, `/plan`, `/implement` batch under its **unsuffixed**
`batch_session_id`, and release at batch completion.

**Tasks**:
- [x] In each of `commands/research.md`, `commands/plan.md`, `commands/implement.md`, locate
      `#### Step 2: Generate Batch Session ID` and add the registration call immediately after the
      `batch_session_id="sess_..."` assignment, before Step 3's dispatch.
- [x] Register under the bare `batch_session_id` — never a `_${task_num}`-suffixed derivative. Add
      an inline comment stating this explicitly, since the very next step suffixes the same variable
      for per-task lock calls and the distinction is easy to lose.
- [x] Pass the full validated task set as the `task_numbers` CSV; the `file_scope` UNION is computed
      inside `session-register` and must not be constructed at the call site.
- [x] Add the release call at batch completion: `#### Step 4: Batch Git Commit` / `#### Step 5:
      Consolidated Output` in `research.md` and `plan.md`, and `#### Step 4: Batch Git Commit and
      Consolidated Output` in `implement.md`. Place it so it runs regardless of per-task outcomes.
- [x] Add no intra-batch heartbeat to these three commands: Step 3 dispatches once and waits for all
      parallel results, so there is no cycle boundary. Record that as an explicit note at each site
      so a future reader does not "fix" the apparent omission.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts exactly three command files and exactly two edit sites per
file (Step 2 register, Step 4/5 release). Confirm at implementation time with
`grep -n 'batch_session_id="sess_' commands/*.md` and by locating each named Step heading before
editing; report any file whose structure diverges rather than forcing the pattern.

**Empirical confirmation**: `grep -n 'batch_session_id="sess_'` confirmed exactly one generation site per file, at the named Step 2 heading in all three; release calls landed at the top of Step 4 (`research.md`/`plan.md` also have a distinct Step 5, but the release sits at Step 4 since it must run before the batch commit, not after). All three structures matched the plan's assumption — no file diverged.

**Files to modify**:
- `agent-system/extensions/core/commands/research.md` - Step 2 register, Step 4/5 release
- `agent-system/extensions/core/commands/plan.md` - Step 2 register, Step 4/5 release
- `agent-system/extensions/core/commands/implement.md` - Step 2 register, Step 4 release

**Verification**:
- Diff read-through confirms all hunks are inside instruction prose / fenced bash blocks in
  markdown, with no change to any dispatch, admission, or refusal instruction.
- Every added bash snippet uses the bare `batch_session_id`, verified by grepping the diff for
  `_${task_num}` adjacency to any `session-register`/`session-release` call (expected: zero hits).
- Each of the three files still has exactly one `batch_session_id` generation site.

---

### Phase 6: Orchestrate Batch Register/Release Wiring [COMPLETED]

**Goal**: Register and release the multi-task `/orchestrate` batch at its existing batch-start and
batch-completion stages.

**Tasks**:
- [x] In `commands/orchestrate.md`, locate the `batch_session_id="sess_..."` generation in
      `#### Step 4: Wave Execution` and confirm it is passed unchanged into
      `skill-orchestrate/SKILL.md` Stage MT-1 as `session_id`.
- [x] In `skills/skill-orchestrate/SKILL.md` Stage MT-1, add the registration call adjacent to the
      existing `.orchestrator-multi-state-${session_id}.json` initialization, keyed on the bare
      `session_id`, with the full batch task set as the `task_numbers` CSV and the invoking command
      string as `command`.
- [x] In `skills/skill-orchestrate/SKILL.md` Stage MT-5 (Multi-Task Postflight), add the release
      call alongside the existing `mt_state_file` remove/preserve handling, so registration and the
      batch's other session-scoped runtime state are cleaned up at the same boundary.
- [x] Make both calls best-effort (`2>/dev/null || true`). Neither may alter `exit_status`,
      `forward_progress_violated`, or any other Stage MT-5 computation.
- [x] Add a note at Stage MT-1 stating that single-task `/orchestrate` needs no separate wiring
      because its CHECKPOINT 1/2 already routes through `command-gate-in.sh`/`command-gate-out.sh`
      (Phase 4).
- [x] Record in the phase notes that `skills/skill-orchestrate/SKILL.md` is a consciously widened
      file target beyond the declared file scope — the task description's own WIRING section names
      these anchors and they are unreachable otherwise.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/commands/orchestrate.md` - confirm/annotate `batch_session_id`
  handoff (edit only if an annotation is needed)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage MT-1 register, Stage MT-5
  release

**Verification**:
- Diff read-through confirms prose/instruction-only changes with no alteration to any admission
  gate, eligibility check, or convergence counter.
- The registered key at Stage MT-1 is textually the same variable Stage MT-4 later suffixes per
  task, verified by reading both sites.
- Stage MT-5's `exit_status` computation is byte-unchanged in the diff.

---

### Phase 7: Heartbeat Wiring at Existing Checkpoints [COMPLETED]

**Goal**: Refresh `heartbeat_at` at the checkpoints that already exist. Add no new checkpoint
anywhere.

**Tasks**:
- [x] In `skills/skill-orchestrate/SKILL.md` Stage 3's cycle loop, add the registry heartbeat call
      immediately adjacent to the existing
      `task-lock.sh heartbeat "$task_number" "$session_id"` line (anchor on that quoted string).
- [x] In `skills/skill-orchestrate/SKILL.md` Stage MT-3's loop top, step 1 ("Status refresh"), add a
      batch-level registry heartbeat keyed on the bare `session_id`. This is a new USE of an existing
      per-cycle checkpoint, not an invented one — state that in an inline comment, since Stage MT-4's
      per-task acquire/release brackets a single dispatch and has no equivalent per-cycle lock
      heartbeat to sit beside.
- [x] In `agents/general-implementation-agent.md` Stage 4D ("D. Mark Phase Complete"), add the
      registry heartbeat immediately adjacent to the existing
      `task-lock.sh heartbeat "{task_number}" "{session_id}"` line. This is the implementer's real
      per-phase checkpoint; `skill-implementer/SKILL.md` has none and must not be edited.
- [x] Every heartbeat call is best-effort (`2>/dev/null || true`) and never blocks the loop, matching
      `cmd_session_heartbeat`'s own never-blocks contract from Phase 1.

**Timing**: 45 minutes

**Depends on**: 6

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 3 heartbeat, Stage MT-3
  step 1 batch heartbeat
- `agent-system/extensions/core/agents/general-implementation-agent.md` - Stage 4D heartbeat

**Verification**:
- Diff read-through confirms every hunk sits adjacent to a pre-existing heartbeat or status-refresh
  instruction, with no new loop, stage, or checkpoint introduced.
- `grep -c "task-lock.sh heartbeat"` on both files shows the pre-existing calls still present and
  unmodified.
- `skills/skill-implementer/SKILL.md` appears nowhere in the diff.

---

### Phase 8: Reap Wiring into /refresh [COMPLETED]

**Goal**: Expose `session-reap` through explicit `/refresh` invocation only, following the numbering
and echo discipline Step 4.5 already established.

**Tasks**:
- [x] Read the current `skills/skill-refresh/SKILL.md` Step 4 ("Reap Stale Task Locks") and Step 4.5
      ("Reap Stale Session-Scoped Orchestration Files") to copy their exact shape.
- [x] Add a new **Step 4.6** ("Reap Stale Session Registry Entries") after Step 4.5. Append; do not
      renumber any later step, so `refresh.md`'s cross-references stay valid.
- [x] Mirror Step 4.5 exactly: the same `--dry-run` passthrough branch structure, the same
      verbatim-echo instruction (echo the subcommand's output, never summarize it away), and the same
      framing that this is a distinct cleanup target from Steps 4 and 4.5.
- [x] State explicitly that this runs on explicit `/refresh` invocation only and never on the hourly
      `claude-refresh.timer`, which runs process cleanup and does not sweep `specs/`.

**Timing**: 30 minutes

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` - new Step 4.6

**Verification**:
- Diff read-through confirms markdown-only changes and that Steps 5, 6, 7 retain their original
  numbers.
- The new step's invoked path and flags match Phase 1's `session-reap [--dry-run]` signature
  exactly.
- Cross-check that `commands/refresh.md`'s step references still resolve.

---

### Phase 9: Isolated-Temp-Root Test Suite and Manifest Registration [NOT STARTED]

**Goal**: Prove the registry contract with a suite that never touches the real `specs/` tree, and
make the new script deployable.

**Tasks**:
- [ ] Read `scripts/test-task-lock-reap.sh` in full first; it is the precedent to follow, including
      its temp-root construction (copy the real `task-lock.sh` and `deploy-root-guard.sh` into
      `$TMPROOT/.claude/scripts/` so `deploy-root-guard.sh`'s two-levels-under-root check is
      satisfied and the production script never learns it is under test), its `pass`/`fail`/`info`
      helpers, its cleanup trap, and its controlled-epoch timestamp helpers (no sleeping).
- [ ] Create `scripts/test-session-registry.sh` with a fixture `state.json` carrying tasks with
      distinct, partially-overlapping `file_scope` arrays, plus fixture `specs/.sessions/` entries at
      controlled `heartbeat_at` ages.
- [ ] Cover these cases:
      - Register writes every required field: `session_id`, `pid`, `command`, `task_numbers`,
        `file_scope`, `started_at`, `heartbeat_at`.
      - `file_scope` is the deduplicated UNION across a multi-task registration, not a concatenation.
      - Re-registering the same `session_id` preserves `started_at` and advances `heartbeat_at`.
      - Heartbeat on a missing entry warns and exits 0 (never blocks).
      - Release is idempotent: two consecutive releases both exit 0.
      - `session-reap --dry-run` removes nothing (run first, against the full fixture).
      - Dead-pid entry older than `SESSION_REGISTRY_DEAD_PID_MIN` is reaped with reason `dead-pid`.
      - Dead-pid entry *younger* than that floor is NOT reaped — the guard that makes a misresolved
        pid safe.
      - Live-pid entry younger than `SESSION_REGISTRY_REAP_MIN` is not reaped; older than it is,
        with reason `stale-heartbeat`.
      - A corrupt/unparseable entry falls back to file mtime and is reported, never silently ignored.
- [ ] Exit 0 when all cases pass, 1 when any fails, matching the precedent's contract.
- [ ] Add `"test-session-registry.sh"` to the `scripts` array in `manifest.json` so `copy_scripts()`
      deploys it. Confirm whether `task-lock.sh` and `test-task-lock-reap.sh` entries already exist
      (they do) and add only the new one — no other manifest change is needed, since the registry
      ships as subcommands rather than a new sibling implementation script.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts a ten-case suite covers the contract and that
`manifest.json` needs exactly one added entry. Confirm the manifest count with
`grep -n 'test-session-registry\|task-lock.sh' manifest.json` after editing (expected: the new entry
plus the two pre-existing ones). Confirm case coverage by cross-reading Phase 1's subcommand
contracts and flagging any documented behavior with no corresponding case rather than declaring the
suite complete.

**Files to modify**:
- `agent-system/extensions/core/scripts/test-session-registry.sh` - new file
- `agent-system/extensions/core/manifest.json` - one scripts-array entry

**Verification**:
- `bash agent-system/extensions/core/scripts/test-session-registry.sh` exits 0 with every case
  reported PASS.
- The suite creates and removes only paths under its `mktemp -d` root — verified by asserting
  `specs/.sessions/` in the real repo is unchanged before and after a run.
- `jq -e . agent-system/extensions/core/manifest.json` parses clean.
- `bash agent-system/extensions/core/scripts/test-task-lock-reap.sh` still exits 0.

---

### Phase 10: Scope-Boundary Audit and Final Verification [NOT STARTED]

**Goal**: Prove the registry is produced and nothing consumes it, and run the full gate set.

**Tasks**:
- [ ] Grep the entire source store for reads of the registry path:
      `grep -rn "\.sessions" agent-system/extensions/core/`. Assert the only hits are
      `scripts/task-lock.sh`, `scripts/test-session-registry.sh`,
      `scripts/check-runtime-file-tracking.sh`, `context/patterns/task-lock.md`,
      `context/standards/orchestrator-runtime-files.md`, and the wiring call sites from Phases 4-8.
      Any hit inside an admission, eligibility, or refusal code path is a failure of this task's
      scope boundary and must be reverted, not rationalized.
- [ ] Assert `scripts/orchestrate-batch-admit.sh` appears nowhere in the task's cumulative diff.
- [ ] Assert `cmd_acquire`, `cmd_heartbeat`, `cmd_release`, `cmd_check`, `cmd_reap`, `cmd_init_marker`,
      and both mutex command pairs in `task-lock.sh` have byte-unchanged bodies.
- [ ] Assert no `specs/state.json` write was introduced anywhere in the diff; if any phase needed
      one, it must route through `scripts/state-write.sh` and never a hand-rolled tmp-and-mv.
- [ ] Run `bash agent-system/extensions/core/scripts/check-task-references.sh` (or the deployed
      equivalent) to confirm no deliverable outside `specs/**` cites a task number.
- [ ] Run `bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` — all three
      checks pass, including the new `.sessions` probe under Check A and Check C still green for the
      durable-provenance files.
- [ ] Run `bash agent-system/extensions/core/scripts/check-extension-docs.sh` and the repo's
      `scripts/verify-deploy.sh` gate set.
- [ ] Run both test suites: `test-task-lock-reap.sh` and `test-session-registry.sh`.
- [ ] Confirm no file under `.claude/**` was hand-authored in this task's diff (the source-store
      rule), with the single sanctioned exception being the repo root `/.gitignore` from Phase 3.
- [ ] Check whether `test-session-registry.sh` reached `.claude/scripts/` after a redeploy; if the
      known `copy_scripts` loader gap prevents it, report that plainly in the summary as an
      unresolved environment issue rather than working around it in this task's scope.

**Timing**: 1 hour

**Depends on**: 2, 3, 4, 5, 7, 8, 9

**Verification Tier**: full

**Files to modify**:
- None (audit and verification only)

**Verification**:
- Every command above exits 0.
- The scope-boundary grep produces a hit list containing no admission/refusal code path.
- A summary line records, for each of the four registry subcommands, which wiring site exercises it.

---

## Testing & Validation

- [ ] `bash -n` on every modified shell script.
- [ ] `bash agent-system/extensions/core/scripts/test-session-registry.sh` exits 0.
- [ ] `bash agent-system/extensions/core/scripts/test-task-lock-reap.sh` exits 0 (no regression).
- [ ] `bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` exits 0 with the new
      `.sessions` probe covered.
- [ ] `bash agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0.
- [ ] `scripts/verify-deploy.sh` gate set passes, including the task-reference lint gate.
- [ ] `jq -e . agent-system/extensions/core/manifest.json` parses.
- [ ] End-to-end smoke: a real single-task command run leaves exactly one
      `specs/.sessions/{session_id}.json` while in flight and none after completion.
- [ ] Scope-boundary audit produces no consumer outside `task-lock.sh`, the test suite, docs, and the
      wiring call sites.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/task-lock.sh` (extended: four subcommands, two constants,
  three helpers, header docs)
- `agent-system/extensions/core/scripts/test-session-registry.sh` (new)
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` (probe + pattern)
- `agent-system/extensions/core/scripts/command-gate-in.sh`, `command-gate-out.sh` (register/release)
- `agent-system/extensions/core/commands/research.md`, `plan.md`, `implement.md`, `orchestrate.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
  `skills/skill-refresh/SKILL.md`
- `agent-system/extensions/core/agents/general-implementation-agent.md`
- `agent-system/extensions/core/context/patterns/task-lock.md` (new section + two updated sections)
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` (class row + setup
  block)
- `agent-system/extensions/core/manifest.json` (one scripts entry)
- `/.gitignore` (repo root, one pattern — the sanctioned source-store-rule exception)
- `specs/944_in_flight_session_registry/summaries/01_in-flight-session-registry-summary.md`

## Rollback/Contingency

Every change is additive: new subcommands, new best-effort call sites, new documentation sections,
one new ignore pattern, one new test file. No existing subcommand, admission decision, or threshold
is modified, so a partial rollback is safe at phase granularity.

- **Wiring phases (4-8) misbehave**: revert those call sites only. `task-lock.sh`'s new subcommands
  become dormant — nothing calls them, nothing reads their output, and no existing behavior depends
  on them.
- **Phase 1 has a defect**: every call site is `2>/dev/null || true`, so a broken subcommand
  degrades to a no-op rather than blocking any gate. Revert `task-lock.sh` alone; the wiring lines
  then fail silently and harmlessly until reinstated.
- **The reap over-reaps**: raise `SESSION_REGISTRY_REAP_MIN` and `SESSION_REGISTRY_DEAD_PID_MIN` via
  env vars without a code change, or drop Step 4.6 from `skill-refresh/SKILL.md` — reap is
  explicit-invocation-only and never runs on a timer, so removing that step fully disables it.
- **Full revert**: `git revert` the task's phase commits in reverse order; the only cross-cutting
  artifact is the repo root `/.gitignore` line, whose removal has no effect beyond re-exposing an
  ephemeral path to staging.

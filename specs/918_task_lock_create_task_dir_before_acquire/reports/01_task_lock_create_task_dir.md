# Research Report: Task #918

**Task**: 918 - task_lock_create_task_dir_before_acquire
**Started**: 2026-07-27T00:00:00Z
**Completed**: 2026-07-27T00:00:00Z
**Effort**: small (single-function change plus call-site plumbing)
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/task-lock.sh` (current source-store state)
- `agent-system/extensions/core/scripts/command-gate-in.sh`
- `agent-system/extensions/core/scripts/skill-base.sh`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/commands/implement.md`
- `agent-system/extensions/core/commands/task.md`
- `agent-system/extensions/core/context/patterns/task-lock.md`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md, no-task-references-in-deliverables.md

## Executive Summary

- All claims in the task description are verified against the current source-store
  `task-lock.sh`. `resolve_task_dir()` genuinely hard-fails (`return 1`) whenever the resolved
  directory does not yet exist on disk, whether resolved via `state.json`'s `project_name` or
  via the `find` fallback.
- `resolve_task_dir` has exactly four call sites, all inside `task-lock.sh` itself:
  `cmd_acquire`, `cmd_heartbeat`, `cmd_release`, `cmd_check`. Only `cmd_acquire` needs
  create-if-missing; the other three are genuinely read-only with respect to the task
  directory and must stay that way.
- Task creation (`task.md` Create Task Mode, Step 9) is confirmed to defer directory creation
  by design: "Directories are created lazily when the first artifact is written." This makes
  the reported failure a normal, expected path for any `not_started` task, not an edge case.
- **Recommendation: the fix belongs in `task-lock.sh`'s `cmd_acquire`, not in
  `command-gate-in.sh`.** There are two independent, gate-script-bypassing call paths that
  invoke `task-lock.sh acquire` directly — `skill-orchestrate/SKILL.md` Stage MT-4 (multi-task
  `/orchestrate`) and `implement.md`'s multi-task Step 3 — neither of which creates the task
  directory before calling acquire. A fix placed only in `command-gate-in.sh` would leave both
  of these live, undispatched-directory failure paths open. Fixing `cmd_acquire` (via an
  opt-in create-if-missing mode threaded through `resolve_task_dir`) closes all three call
  sites for free, since all three simply shell out to `task-lock.sh acquire`.
- No race is introduced: the recommended creation uses `mkdir -p` (idempotent, safe under
  concurrent invocation) for the parent task directory, entirely separate from the existing
  `mkdir "$lock_dir"` (non-`-p`, POSIX-atomic-exclusive) that remains the sole exclusivity
  primitive for the lock itself.

## Context & Scope

Task 918 asks: does `resolve_task_dir()` in `task-lock.sh` hard-fail for a task whose
directory doesn't exist yet, aborting GATE IN and blocking `/orchestrate` and other commands?
If so, which layer (gate script vs. lock script) should own directory creation, honoring three
binding constraints: (1) create-if-missing is opt-in at the acquire call site only, never a
change to `resolve_task_dir`'s shared default; (2) creation fires only when `project_name`
resolves from `state.json`, never from the `find` fallback; (3) the created directory matches
the `reports/`, `plans/`, `summaries/` shape downstream consumers expect.

This research verifies the mechanism against the current source-store file content (not
line numbers, per the task's own warning that the file was mid-edit during a prior
investigation), enumerates every `resolve_task_dir` call site with its read/write character,
and determines which layer should own the fix.

## Findings

### Codebase Patterns

#### `resolve_task_dir()` — confirmed mechanism

Current source-store body (anchored on symbol names):

```bash
resolve_task_dir() {
  local task_number="$1"
  local padded project_name dir

  padded=$(printf "%03d" "$task_number" 2>/dev/null) || return 1

  if [ -f "$STATE_FILE" ] && command -v jq >/dev/null 2>&1; then
    project_name=$(jq -r --argjson num "$task_number" \
      '.active_projects[]? | select(.project_number == $num) | .project_name // empty' \
      "$STATE_FILE" 2>/dev/null)
    if [ -n "$project_name" ]; then
      dir="$PROJECT_ROOT/specs/${padded}_${project_name}"
      if [ -d "$dir" ]; then
        echo "$dir"
        return 0
      fi
    fi
  fi

  dir=$(find "$PROJECT_ROOT/specs" -maxdepth 1 -type d -name "${padded}_*" 2>/dev/null | head -1)
  if [ -n "$dir" ]; then
    echo "$dir"
    return 0
  fi

  return 1
}
```

Confirmed exactly as described in the task: the `state.json`-resolved branch guards with
`if [ -d "$dir" ]` and only echoes when the directory already exists; if not, execution falls
through (no early return) to the `find` fallback, which likewise only matches existing
directories (`find ... -type d`); if neither branch matches, the function returns 1 with no
side effects and no diagnostic of its own (the caller prints the error).

#### Four call sites — read-only vs. mutating character

All four live inside `task-lock.sh` itself; there are no other call sites anywhere in the
source store (`grep -rn "resolve_task_dir" agent-system/` returns only this file's
definition and these four uses).

| Call site | Function purpose | Mutating w.r.t. task directory? | On `resolve_task_dir` failure |
|---|---|---|---|
| `cmd_acquire` | Acquire the per-task `.lock/` | Yes — after resolving `task_dir`, it `mkdir`s `$task_dir/.lock` and writes `holder.json` | `echo "ERROR: could not resolve task directory for task $task_number" >&2; return 2` |
| `cmd_heartbeat` | Refresh `heartbeat_at` for an existing lock held by the same session | No — only reads `$lock_dir/holder.json` if it exists; never creates `$task_dir` or `.lock/` | Same `ERROR:` message; `return 2` |
| `cmd_release` | Unconditionally `rm -rf` the lock directory | No — `rm -rf` on the `.lock` subpath is not a task-directory-creating operation, and this runs only if `resolve_task_dir` already succeeded | Same `ERROR:` message; `return 2` |
| `cmd_check` | Diagnostic status query (free / held-fresh / held-stale) | No — pure read | Same `ERROR:` message; `return 3` (check's own distinct exit-code class) |

This confirms the task description's claim precisely: `cmd_heartbeat`, `cmd_release`, and
`cmd_check` are genuinely read-only with respect to the task directory and filesystem side
effects would be a regression for all three — matching binding constraint 1's warning that "a
lock check, heartbeat, or release MUST NEVER have filesystem side effects."

#### `command-gate-in.sh` — the primary failure trigger

`gate_in()` looks up `task_data` from `state.json` (obtaining `PROJECT_NAME` and `PADDED_NUM`
directly, independent of `task-lock.sh`), runs the terminal-status guard, then calls:

```bash
bash .claude/scripts/task-lock.sh acquire "$task_number" "$operation" "$SESSION_ID" "/$operation $task_number"
```

A non-zero return here (2, per `cmd_acquire`'s `resolve_task_dir` failure branch) propagates
as `gate_in`'s own `return 1`, aborting GATE IN before DELEGATE — exactly the observed live
failure (`/orchestrate 180` → "ERROR: could not resolve task directory for task 180").

Note that `command-gate-in.sh` already independently resolves `PROJECT_NAME`/`PADDED_NUM` from
`state.json` (its own `jq` lookup, lines computing `task_data`) *before* calling `task-lock.sh
acquire`. This makes it tempting to fix the bug locally in the gate script (it already has the
ingredients to `mkdir -p` the directory). That temptation is exactly what the "two wiring
paths" finding below argues against.

#### Task creation deliberately defers directory creation

`task.md`'s Create Task Mode, Step 9 output block states verbatim: *"Artifacts path:
specs/{NNN}_{SLUG}/ (created on first artifact)"* with the explicit footnote *"Directories are
created lazily when the first artifact is written."* Step 6 (state.json update) and Step 8
(git commit of `specs/`) never `mkdir` a task directory. This confirms the task description's
claim that "task creation does not always create the directory" is not a bug in task creation
itself — it is documented, intentional behavior. The bug is entirely in `resolve_task_dir`'s
inability to cope with that intentional deferral when the FIRST operation on a fresh task
happens to be an `acquire`.

#### Two independent wiring paths bypass `command-gate-in.sh` entirely

`.claude/context/patterns/task-lock.md`'s "Consumers (Two Distinct Wiring Paths)" section, and
direct inspection of the two named files, confirm `task-lock.sh acquire` is called from THREE
places total, not just one:

1. **`command-gate-in.sh`** (single-task `/research`, `/plan`, `/implement`, `/revise`,
   `/orchestrate`) — the one path already using `resolve_task_dir` through a script that has
   its own independent `state.json` lookup.
2. **`skill-orchestrate/SKILL.md` Stage MT-4** (multi-task `/orchestrate`), which calls:
   ```bash
   bash .claude/scripts/task-lock.sh acquire "$task_num" "$op" "${session_id}_${task_num}" "/orchestrate (multi-task)"
   ```
   with **no directory creation anywhere before this call** in Stage MT-4. This is dispatched
   for `research_tasks` (status `not_started`) among others — precisely the population of
   tasks whose directories, per the `task.md` finding above, are least likely to exist yet.
   Stage MT-4 explicitly documents that it bypasses the gate scripts: *"Multi-task dispatch
   bypasses the single-task gate scripts entirely (`command-gate-in.sh`/`command-gate-out.sh`
   are never sourced here), so this stage acquires/releases the lock itself."*
3. **`implement.md`'s multi-task Step 3**, which calls:
   ```bash
   bash .claude/scripts/task-lock.sh acquire "$task_num" implement "${batch_session_id}_${task_num}" "/implement (multi-task)"
   ```
   also with no directory creation beforehand. Lower practical risk than (2) because
   `/implement` only targets tasks already at `planned`/`implementing`/`partial` status, which
   will almost always already have a directory from a prior `/research` or `/plan` pass — but
   the call site is structurally identical and not guaranteed safe (a directory could be
   removed out from under a `partial` task, or state could otherwise diverge).

This is the decisive finding: **a fix scoped to `command-gate-in.sh` alone would leave paths
(2) and (3) exposed to the identical failure**, because both call `task-lock.sh acquire`
directly without ever creating the task directory first. Fixing `cmd_acquire` itself (the
single function all three paths funnel through) closes all three call sites with one change
and zero edits to the three consumer files.

#### No other consumer already creates the task directory before acquire

Searched the source store for every `mkdir -p` touching a `specs/{NNN}_{SLUG}` shape
(`agent-system/extensions/core/scripts/*.sh`, `commands/*.md`, `skills/*/SKILL.md`,
`agents/*.md`). Relevant hits:

- `skill-base.sh`'s `skill_create_postflight_marker` does `mkdir -p "$task_dir"` (bare, no
  subdirectories) — but this runs in DELEGATE's Stage 3, strictly *after* GATE IN has already
  succeeded (or failed). It cannot help `cmd_acquire`, which runs earlier, inside GATE IN.
- `skill-orchestrate/SKILL.md` Stage 2 (single-task orchestrate) does `mkdir -p "$TASK_DIR"`
  — also strictly after GATE IN.
- Individual agents (`planner-agent.md`, `reviser-agent.md`, `general-implementation-agent.md`)
  `mkdir -p` their own `plans/`, `progress/`, `handoffs/` subdirectories on demand at write
  time — none of them run before `cmd_acquire`.

No consumer anywhere creates the task directory early enough to prevent the observed failure.
The gap is real and the fix must land in the acquire path itself.

#### Race analysis: creation vs. lock acquisition

`cmd_acquire` currently resolves `task_dir` via `resolve_task_dir` *before* acquiring
`specs/.scope-lock/` (`acquire_scope_mutex`) and before the atomic `mkdir "$lock_dir"` that is
the sole exclusivity primitive for the lock itself. Adding a `mkdir -p` of the *parent* task
directory (not the `.lock` subdirectory) at this point introduces no new race:

- `mkdir -p` is idempotent under concurrent callers — POSIX `mkdir -p` implementations treat
  an already-existing final/intermediate directory as success, not `EEXIST` failure, so two
  sessions racing to acquire the SAME never-yet-created task simultaneously both succeed at
  the `mkdir -p` step harmlessly.
- The actual exclusivity guarantee (which session "wins" the lock) is still provided entirely
  by the pre-existing, unmodified `mkdir "$lock_dir"` (plain, non-`-p`, POSIX-atomic-exclusive)
  later in `cmd_acquire`. The proposed fix does not touch that primitive.
- No TOCTOU window is opened: there is no "check-then-create" `[ -d ]`-then-`mkdir` split that
  a second process could interleave with in a way that produces incorrect (as opposed to
  merely redundant) directory-creation calls.

Directory-shape verification (binding constraint 3): the canonical shape from
`CLAUDE.md`/`artifact-formats.md` is `specs/{NNN}_{SLUG}/{reports,plans,summaries}/`. Creating
only the bare parent directory (mirroring `skill_create_postflight_marker`'s pattern) would
technically satisfy `resolve_task_dir`'s own `-d "$dir"` check, but would leave downstream
consumers that assume the subdirectories exist (e.g., any `ls "$plan_dir"/*.md` glob, or a
`mkdir -p` that assumes an existing parent) inconsistent with the shape every other creator in
the system produces. Creating `reports/`, `plans/`, `summaries/` alongside the bare directory
in the same `mkdir -p` call (a single command can take multiple path arguments) matches the
documented convention at zero extra cost and closes constraint 3 directly.

### External Resources

Not applicable — this is a purely internal Bash/JSON mechanism with no external library or API
dependency. No web research was needed or performed.

### Recommendations

1. **Add an opt-in create-if-missing parameter to `resolve_task_dir`**, e.g. a second
   positional argument (`resolve_task_dir "$task_number" [create]`), defaulting to unset/empty
   (current, unchanged, read-only behavior) when omitted. This satisfies binding constraint 1
   literally: the function's *shared default* is untouched; only a caller that explicitly
   passes the new argument opts in.

2. **Place the creation logic inside the `state.json`-resolved branch only**, immediately after
   the existing `if [ -d "$dir" ]` check fails, guarded by the new parameter:
   ```bash
   if [ -n "$project_name" ]; then
     dir="$PROJECT_ROOT/specs/${padded}_${project_name}"
     if [ -d "$dir" ]; then
       echo "$dir"
       return 0
     elif [ "$2" = "create" ]; then
       mkdir -p "$dir/reports" "$dir/plans" "$dir/summaries" 2>/dev/null
       if [ -d "$dir" ]; then
         echo "$dir"
         return 0
       fi
     fi
   fi
   ```
   This satisfies binding constraint 2: creation is reachable ONLY through the branch that
   already required `project_name` to be non-empty from `state.json`; the `find` fallback
   below is untouched and never triggers creation, so a typo'd or nonexistent task number still
   correctly falls through to `return 1` rather than fabricating a stray directory.

3. **Only `cmd_acquire` passes the new `create` argument**: change its call from
   `resolve_task_dir "$task_number"` to `resolve_task_dir "$task_number" "create"`.
   `cmd_heartbeat`, `cmd_release`, and `cmd_check` keep their existing bare
   `resolve_task_dir "$task_number"` calls unchanged — read-only behavior preserved exactly,
   satisfying binding constraint 1's second half.

4. **Do not additionally patch `command-gate-in.sh`, `skill-orchestrate/SKILL.md`, or
   `implement.md`** to `mkdir -p` the task directory themselves. Doing so would be redundant
   with the `cmd_acquire` fix and would reintroduce the "N call sites must each remember to
   create the directory" maintenance hazard this research specifically found is where the
   current bug came from (task creation defers creation; three different `acquire` call sites
   each assumed someone else — or `resolve_task_dir` — handled it, and none did).

5. **Planning should size this as a single-phase change**: one function edit in
   `task-lock.sh` (the `resolve_task_dir` signature + body, plus `cmd_acquire`'s call site),
   with the header usage comment (lines documenting `acquire`'s contract) and
   `.claude/context/patterns/task-lock.md`'s "acquire" contract section (step 1: "Resolve the
   task directory...") updated to note the create-if-missing behavior is now part of
   `acquire`'s contract specifically, not `resolve_task_dir`'s default. No changes are needed
   to `command-gate-in.sh`, `skill-orchestrate/SKILL.md`, or `implement.md` — they all already
   correctly propagate `cmd_acquire`'s exit code and will simply stop failing once the
   directory exists.

## Decisions

- **Layer ownership: `task-lock.sh`'s `cmd_acquire`, not `command-gate-in.sh`.** Reasoning:
  three independent call sites invoke `task-lock.sh acquire` (`command-gate-in.sh`,
  `skill-orchestrate/SKILL.md` Stage MT-4, `implement.md` Step 3), and two of the three bypass
  gate scripts entirely by design. A gate-script-only fix leaves the multi-task orchestrate
  path — the path most likely to hit a genuinely nonexistent directory, since it dispatches
  `not_started` tasks — unfixed. Fixing the shared `cmd_acquire` function closes all three
  call sites through the existing dependency graph with a single change.
- **Mechanism: an opt-in parameter to `resolve_task_dir`, not a separate creation function.**
  Reasoning: minimizes surface area, keeps the state.json-resolution logic (padding,
  `project_name` lookup, `find` fallback) in exactly one place, and makes the opt-in explicit
  and auditable at each of the four call sites (three stay bare, one gains `"create"`).
- **Creation scope: `reports/`, `plans/`, `summaries/` alongside the bare directory**, matching
  the documented artifact-path convention, at no additional cost over a bare `mkdir -p`.

## Risks & Mitigations

- **Risk**: a future call site could accidentally pass `"create"` to `resolve_task_dir` for a
  read-only use (heartbeat/release/check), silently reintroducing side effects. **Mitigation**:
  the implementation plan should keep the three read-only call sites' bare, argument-free form
  exactly as-is (do not touch them at all in the diff, so a code reviewer sees zero lines
  changed in `cmd_heartbeat`/`cmd_release`/`cmd_check`), and the `.claude/context/patterns/
  task-lock.md` doc update should say explicitly that `"create"` is `cmd_acquire`-only.
- **Risk**: if `project_name` somehow contains a value that fails `mkdir -p` (e.g., embeds a
  path separator from a corrupted `state.json`), the creation could write outside the intended
  `specs/` tree. **Mitigation**: this risk already exists identically in the current code (the
  same `$dir` string is used for the `-d` check today) and is out of scope for this task; no
  new exposure is introduced by adding `mkdir -p` of the same already-computed `$dir`.
- **Risk**: silent creation could mask a genuine `state.json` corruption where `project_name`
  is stale/wrong for the task number. **Mitigation**: creation only fires when `project_name`
  was successfully resolved FROM `state.json` (binding constraint 2), so this is the intended,
  authoritative source; a wrong `project_name` is a `state.json` data-integrity problem
  pre-existing and orthogonal to this fix, not something this fix should attempt to detect.

## Context Extension Recommendations

- **Topic**: `.claude/context/patterns/task-lock.md`'s "acquire" contract section (step 1:
  "Resolve the task directory (`specs/{NNN}_{SLUG}/`, preferring `state.json`'s
  `project_name`, falling back to a filesystem glob)").
  **Gap**: this line will become inaccurate once `cmd_acquire` gains create-if-missing
  behavior — it currently reads as pure resolution with no side effect.
  **Recommendation**: update this single bullet during implementation to note that `acquire`
  (and only `acquire`) additionally creates the directory (with `reports/`, `plans/`,
  `summaries/` subdirectories) when `project_name` resolves from `state.json` but no directory
  exists yet, and that `heartbeat`/`release`/`check` remain read-only. This is a small,
  in-scope doc update belonging to the implementation plan for this task rather than a
  standalone context-gap task.

## Appendix

- Searches performed: `find` for `task-lock.sh`/`command-gate-in.sh` locations;
  `grep -n` for `resolve_task_dir` definition/call sites; `grep -rln` for `mkdir -p` patterns
  touching `specs/{NNN}_{SLUG}` shapes across `scripts/`, `commands/`, `skills/`, `agents/`;
  `grep -n` for `task-lock.sh acquire` across `skill-orchestrate/SKILL.md` and `implement.md`;
  `git log`/`git status` on `task-lock.sh` and `command-gate-in.sh` to confirm no uncommitted
  concurrent edits at research time (tree was clean; most recent touch was task 908's
  `specs/.commit-lock/` mutex addition, unrelated to `resolve_task_dir`).
- Files read in full or in relevant part: `agent-system/extensions/core/scripts/task-lock.sh`,
  `agent-system/extensions/core/scripts/command-gate-in.sh`,
  `agent-system/extensions/core/scripts/skill-base.sh` (lines ~1-250, ~540-650),
  `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage 2, Stage MT-1
  through MT-4 regions), `agent-system/extensions/core/commands/task.md` (Create Task Mode
  steps 1-9), `agent-system/extensions/core/commands/implement.md` (multi-task Step 3),
  `agent-system/extensions/core/context/patterns/task-lock.md` (full).

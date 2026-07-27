# Implementation Plan: Task #918

- **Task**: 918 - Create the task directory before lock acquire so GATE IN stops aborting on tasks whose directory does not exist
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/918_task_lock_create_task_dir_before_acquire/reports/01_task_lock_create_task_dir.md
- **Artifacts**: plans/01_task-lock-create-task-dir.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`resolve_task_dir()` in the source-store `task-lock.sh` only echoes a path when the resolved
directory already exists on disk, so the first `acquire` against a freshly created task — whose
directory task creation deliberately defers — hard-fails and aborts GATE IN. The fix adds an
**opt-in** create-if-missing mode to `resolve_task_dir`, passed only by `cmd_acquire`, firing
only for a path derived from `state.json`, and creating the canonical
`reports/`/`plans/`/`summaries/` shape. Because all three system-wide `acquire` call sites funnel
through `cmd_acquire`, one function-level change closes all three. The plan then updates the
canonical contract doc, deploys the source store into the gitignored `.claude/` tree, and proves
in an isolated fixture that `check`/`heartbeat`/`release` remain free of filesystem side effects.

### Research Integration

The research report is adopted on its central decision — **own creation in `cmd_acquire`, not in
`command-gate-in.sh`** — because `task-lock.sh acquire` has three system-wide call sites and two
of them (`skill-orchestrate/SKILL.md` Stage MT-4 and `implement.md` multi-task Step 3) explicitly
bypass the gate scripts. Stage MT-4 dispatches `not_started` tasks, precisely the population whose
directories do not exist. A gate-only fix would leave both paths broken.

Two corrections to the research's literal recommendation are carried into this plan and are
binding on implementation:

1. **The suggested guard `[ "$2" = "create" ]` is a fatal defect as written.** `task-lock.sh` runs
   under `set -uo pipefail`, and the three read-only callers invoke `resolve_task_dir` with a
   single argument. Referencing an unset `$2` under `set -u` aborts the shell outright — verified
   empirically (`bash -c 'set -u; f(){ echo "$2"; }; f a'` exits 127 with
   `$2: unbound variable`). Placed inside the `elif` the research proposed, this branch is
   *reachable from `cmd_check`* on exactly the scenario being fixed, converting a clean `return 3`
   into a hard abort. Implementation MUST bind `local create_mode="${2:-}"` and compare that.

2. **Creation must be attempted AFTER the `find` fallback, not instead of it.** The research
   snippet places the `mkdir` in an `elif` inside the `state.json` branch, which short-circuits
   the `find` fallback. When `state.json`'s `project_name` has drifted from the on-disk slug
   (state says `918_foo`, disk has `918_bar`), today's code resolves the existing `918_bar`; the
   research shape would instead create a second, empty `918_foo` and lock there, silently
   splitting one task across two directories. Deferring the creation attempt until after the
   `find` fallback has failed preserves the existing resolution precedence byte-for-byte and only
   creates when nothing at all exists. This still satisfies binding constraint 2, because the
   created path is the one derived from `state.json` and is only non-empty when the `state.json`
   lookup succeeded — the `find` fallback itself never triggers creation.

Research recommendation 4 (do not additionally patch `command-gate-in.sh`,
`skill-orchestrate/SKILL.md`, or `implement.md`) is adopted unchanged. Research recommendation 5's
"single-phase" sizing is **not** adopted: the source store cannot be executed (`deploy-root-guard.sh`
refuses any invocation outside `*/.claude/scripts/` or `*/.opencode/scripts/`), so verifying the
fix requires a deploy and an isolated fixture, which is more than one agent run's worth of work.

An alternative mechanism was considered and rejected: a standalone `create_task_dir_from_state()`
helper called by `cmd_acquire` on `resolve_task_dir` failure, leaving `resolve_task_dir` literally
untouched. It reads as a more conservative interpretation of binding constraint 1, but it
duplicates the zero-padding and the `jq` `project_name` lookup in a second place, creating a
divergence hazard between two resolvers that must agree. The opt-in parameter keeps resolution
logic in exactly one place while leaving the no-argument behavior byte-identical, which is what
constraint 1 actually protects.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in the delegation context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:
- `task-lock.sh acquire` succeeds for a task that exists in `state.json` but has no directory yet,
  creating `specs/{NNN}_{SLUG}/{reports,plans,summaries}/`.
- All three system-wide `acquire` call sites (`command-gate-in.sh`, `skill-orchestrate` Stage
  MT-4, `implement.md` multi-task Step 3) are fixed without editing any of them.
- `check`, `heartbeat`, and `release` remain provably free of filesystem side effects, with a
  committed test that fails loudly if that ever regresses.
- The `find` fallback never creates a directory, so a nonexistent or typo'd task number still
  fails cleanly.
- The canonical contract doc states that create-if-missing belongs to `acquire`'s contract, not
  `resolve_task_dir`'s default.

**Non-Goals**:
- Changing where task creation itself creates directories (the lazy-creation design in the task
  creation flow is intentional and stays).
- Editing `command-gate-in.sh`, `skill-orchestrate/SKILL.md`, or `implement.md`.
- Hardening against a corrupted `project_name` containing path separators (pre-existing exposure
  through the identical `$dir` string; no new surface introduced).
- Removing the pre-existing task-number citations already present in `task-lock.sh`'s header and
  `context/patterns/task-lock.md` (out of scope; the rule binds only new content added here).
- Any change to the lock exclusivity primitive (`mkdir "$lock_dir"`, non-`-p`) or to the
  `.scope-lock`/`.commit-lock` mutexes.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `$2` referenced unset under `set -u` aborts read-only subcommands | H | H if research snippet copied verbatim | Bind `local create_mode="${2:-}"`; Phase 3 tests `check`/`heartbeat`/`release` against a directoryless task and asserts the documented exit code, not a shell abort |
| Creation short-circuits the `find` fallback and splits a task across two directories on slug drift | M | L | Attempt creation only after the `find` fallback has failed; Phase 3 includes a slug-drift scenario asserting the existing directory is still resolved and no second one appears |
| A future call site passes `"create"` for a read-only use | M | L | Leave `cmd_heartbeat`/`cmd_release`/`cmd_check` completely untouched so the diff shows zero lines there; state `acquire`-only explicitly in the header comment and the contract doc |
| Directory created then acquire refused by the cross-task overlap scan, leaving an empty directory | L | L | Accepted: the directory is the one `state.json` already designates for that task and would be created by the next successful operation anyway; documented in the header comment |
| Edits land in `.claude/` instead of `agent-system/extensions/core/` | H | L | Phase 1 and 2 verification include `git status --short` confirming only `agent-system/**` paths are modified; `.claude/` is gitignored so a stray edit is invisible to review |
| Source store edited but never deployed, so the live failure persists | H | M | Phase 4 runs `verify-deploy.sh` and greps the deployed copy for the new symbol |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch disjoint files
(`scripts/task-lock.sh` vs `context/patterns/task-lock.md`) and the full semantics both describe
are fixed by this plan, so neither has to wait on the other.

### Phase 1: Add opt-in create-if-missing to `resolve_task_dir` and pass it from `cmd_acquire` [COMPLETED]

**Goal**: The source-store `task-lock.sh` creates the canonical task directory during `acquire`
only, only for a `state.json`-derived path, and only when no directory resolves at all.

**Tasks**:
- [x] Locate `resolve_task_dir` by symbol name (not line number — the file has shifted before). *(completed)*
- [x] Change the signature line to bind both parameters:
      `local task_number="$1" create_mode="${2:-}"`. Do NOT reference `$2` directly anywhere. *(completed)*
- [x] Add a `state_dir` local, initialized empty. Inside the existing `state.json` branch, after
      the `if [ -d "$dir" ]` success path, record `state_dir="$dir"`. Add nothing else to that
      branch — in particular, no `mkdir` there. *(completed)*
- [x] Leave the `find` fallback block exactly as-is. *(completed)*
- [x] After the `find` fallback fails and before the final `return 1`, add the creation block:
      fire only when `[ "$create_mode" = "create" ] && [ -n "$state_dir" ]`; run
      `mkdir -p "$state_dir/reports" "$state_dir/plans" "$state_dir/summaries" 2>/dev/null`;
      re-check `[ -d "$state_dir" ]` and `echo "$state_dir"; return 0` on success; otherwise fall
      through to `return 1` so a failed `mkdir` still fails closed. *(completed)*
- [x] Change `cmd_acquire`'s call to `resolve_task_dir "$task_number" "create"`. Change nothing
      else in `cmd_acquire`. *(completed)*
- [x] Do not touch `cmd_heartbeat`, `cmd_release`, or `cmd_check` at all. *(completed: git diff confirms zero changed lines in these functions)*
- [x] Update the `resolve_task_dir` block comment above the function to state that the second
      parameter is opt-in, that only `acquire` passes it, that creation is reachable only from a
      `state.json`-resolved path, and that the `find` fallback never creates. *(completed)*
- [x] Extend the top-of-file `Usage:`/exit-code comment for `acquire` to note that `acquire`
      creates the task directory (with `reports/`, `plans/`, `summaries/`) when `state.json` names
      the task but no directory exists, and that `heartbeat`/`release`/`check` remain read-only.
      Write this without citing any task number. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/scripts/task-lock.sh` - `resolve_task_dir` signature/body,
  `cmd_acquire`'s single call site, function block comment, top-of-file usage comment.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/task-lock.sh` parses cleanly.
- `grep -n 'resolve_task_dir "\$task_number"' agent-system/extensions/core/scripts/task-lock.sh`
  shows exactly one call with a second argument (`"create"`) and three bare calls.
- `grep -n '"\$2"' agent-system/extensions/core/scripts/task-lock.sh` returns no hit inside
  `resolve_task_dir` (the guard uses `create_mode`).
- `git diff -U0 -- agent-system/extensions/core/scripts/task-lock.sh` shows zero changed lines
  within `cmd_heartbeat`, `cmd_release`, and `cmd_check`.
- The `mkdir -p` appears exactly once, positioned after the `find` fallback block.
- `git status --short` lists only paths under `agent-system/`.

---

### Phase 2: Bring the canonical contract doc into line [COMPLETED]

**Goal**: `context/patterns/task-lock.md` describes create-if-missing as part of `acquire`'s
contract and explicitly denies it to the read-only subcommands.

**Tasks**:
- [x] In the `### acquire <task_number> <operation> <session_id> [command]` section, rewrite step 1
      ("Resolve the task directory ... falling back to a filesystem glob") so it states the full
      order: prefer `state.json`'s `project_name`; fall back to a filesystem glob; and, only if
      neither resolves, create the `state.json`-derived path together with its `reports/`,
      `plans/`, and `summaries/` subdirectories. Note that the glob fallback never creates, so an
      unknown task number still fails. *(completed)*
- [x] Add a short note in the same section that create-if-missing is opt-in and passed by `acquire`
      alone — `heartbeat`, `release`, and `check` resolve read-only and have no filesystem side
      effects, including on a task whose directory does not exist. *(completed)*
- [x] Mirror the read-only guarantee in the `### heartbeat`, `### release`, and `### check`
      sections with one clause each, so a reader landing on any of them sees it. *(completed)*
- [x] In the `## Consumers (Two Distinct Wiring Paths)` section, note that because creation lives
      in `acquire` itself, gate-bypassing consumers get it without any change of their own. *(completed)*
- [x] Add no task-number citations in any text written here. *(completed: verified via git diff grep)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/context/patterns/task-lock.md` - `acquire`/`heartbeat`/`release`/
  `check` contract sections and the consumers section.

**Verification**:
- The doc's `acquire` step 1 mentions `reports`, `plans`, and `summaries`.
- The words "never creates" (or equivalent) appear against the glob fallback.
- Each of the `heartbeat`, `release`, and `check` sections carries a read-only clause.
- `git diff -- agent-system/extensions/core/context/patterns/task-lock.md` contains no newly added
  line matching `task [0-9]`.
- `git status --short` lists only paths under `agent-system/`.

---

### Phase 3: Deploy and prove the behavior in an isolated fixture [COMPLETED]

**Goal**: The change is live in the deployed tree, and a committed test demonstrates both the fix
and the absence of side effects on the read-only subcommands.

**Tasks**:
- [x] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` from the repo root to
      regenerate `.claude/` from the source store. *(completed)*
- [x] Confirm the deployed copy carries the change:
      `grep -n 'create_mode' .claude/scripts/task-lock.sh`. *(completed)*
- [x] Create `specs/918_task_lock_create_task_dir_before_acquire/tests/test-task-lock-create.sh`,
      following the task-scoped test convention already used elsewhere under `specs/*/tests/`. *(completed)*
- [x] The harness builds a throwaway root under `mktemp -d` containing `.claude/scripts/` (copies
      of the deployed `task-lock.sh` and `deploy-root-guard.sh` — the guard is a structural path
      check, so a plain temp directory satisfies it) and a synthetic `specs/state.json` with a
      couple of `active_projects` entries. It must never touch the real `specs/` tree. *(completed)*
- [x] Implement these scenarios, each asserting both the exit code and the post-state of the
      filesystem:
      1. `acquire` on a task present in `state.json` with no directory -> exit 0; the directory
         exists with `reports/`, `plans/`, `summaries/`, and `.lock/holder.json`.
      2. `check` on a task present in `state.json` with no directory -> exit 3 and **no directory
         created** (this is the scenario the unbound-`$2` defect would turn into a shell abort;
         assert the exit code precisely rather than merely "non-zero").
      3. `heartbeat` on the same -> exit 2, no directory created.
      4. `release` on the same -> exit 2, no directory created.
      5. `acquire` for a task number absent from `state.json` and absent from disk -> exit 2 and
         no directory created (the glob fallback must not create).
      6. Slug drift: `state.json` says `{NNN}_alpha` while `{NNN}_beta` exists on disk ->
         `acquire` resolves and locks `{NNN}_beta`; `{NNN}_alpha` is not created.
      7. Regression: `acquire` against a task whose directory already exists behaves exactly as
         before (exit 0, `holder.json` written, subdirectories not required). *(completed: all 7 PASS)*
- [x] Have the harness print one PASS/FAIL line per scenario and exit non-zero if any fails. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Files to modify**:
- `specs/918_task_lock_create_task_dir_before_acquire/tests/test-task-lock-create.sh` - new test
  harness.
- `.claude/**` - regenerated by the deploy script; gitignored, never hand-edited.

**Verification**:
- `bash specs/918_task_lock_create_task_dir_before_acquire/tests/test-task-lock-create.sh` exits 0
  with all seven scenarios reporting PASS.
- Running the harness twice in a row still exits 0 (each run uses a fresh temp root).
- `git status --short specs/` shows no unexpected new `specs/{NNN}_*` directories created as a
  side effect of the test run.

---

### Phase 4: Confirm live and audit for drift [NOT STARTED]

**Goal**: The originally observed GATE IN failure mode is gone in the real repo, and the deployed
tree is confirmed current.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/verify-deploy.sh` and record the result.
- [ ] Run `bash agent-system/extensions/core/scripts/check-extension-docs.sh` and confirm its
      deploy-drift lane reports no drift for `task-lock.sh` or `context/patterns/task-lock.md`.
- [ ] Pick a real `not_started` task from `specs/state.json` that has no directory on disk. If
      none exists, record that fact and skip to the read-only check below rather than fabricating
      a task.
- [ ] Run `bash .claude/scripts/check-extension-docs.sh`-independent read-only probes first:
      `bash .claude/scripts/task-lock.sh check <that task>` must exit 3 and leave the filesystem
      unchanged (confirm with `ls specs/ | grep <padded>` before and after).
- [ ] Then run `bash .claude/scripts/task-lock.sh acquire <that task> plan <a fresh session id>`
      and confirm exit 0, the directory now exists with the three subdirectories, and
      `.lock/holder.json` names the session.
- [ ] Release the lock with `bash .claude/scripts/task-lock.sh release <that task> <same session
      id>` and confirm `.lock/` is gone. **Retain** the created task directory — it is the
      directory `state.json` already designates for that task; do not remove it.
- [ ] Record in the phase notes which task was used, so a reviewer can reproduce.

**Timing**: 0.75 hours

**Depends on**: 3

**Files to modify**:
- None (verification only; the live acquire creates one legitimate `specs/{NNN}_{SLUG}/` tree).

**Verification**:
- `verify-deploy.sh` exits 0.
- The read-only `check` probe exits 3 with a byte-identical `ls specs/` before and after.
- The live `acquire` exits 0 and produces `reports/`, `plans/`, `summaries/`, `.lock/holder.json`.
- `release` exits 0 and removes `.lock/` while leaving the task directory in place.

## Testing & Validation

- [ ] `bash -n` passes on the modified `task-lock.sh`.
- [ ] Exactly one `resolve_task_dir` call passes a second argument, and it is in `cmd_acquire`.
- [ ] `cmd_heartbeat`, `cmd_release`, `cmd_check` show zero changed lines in the diff.
- [ ] The seven-scenario fixture harness exits 0.
- [ ] `check`/`heartbeat`/`release` against a directoryless task create nothing and return their
      documented exit codes (3/2/2), not a shell abort.
- [ ] The glob fallback creates nothing for an unknown task number.
- [ ] Slug drift resolves the on-disk directory rather than creating a second one.
- [ ] `verify-deploy.sh` and the doc-lint deploy-drift lane both pass.
- [ ] No new task-number citation appears in any file outside `specs/**`.

## Artifacts & Outputs

- Modified `agent-system/extensions/core/scripts/task-lock.sh`.
- Modified `agent-system/extensions/core/context/patterns/task-lock.md`.
- New `specs/918_task_lock_create_task_dir_before_acquire/tests/test-task-lock-create.sh`.
- Regenerated (gitignored) `.claude/` deploy tree.
- Execution summary under `specs/918_task_lock_create_task_dir_before_acquire/summaries/`.

## Rollback/Contingency

Every change is confined to two source-store files plus one new test file. To revert:
`git checkout -- agent-system/extensions/core/scripts/task-lock.sh
agent-system/extensions/core/context/patterns/task-lock.md`, remove the test file, then re-run
`deploy-headless.sh` to push the reverted source store back into `.claude/`. No state, lock, or
mutex data structures are altered, so no migration or cleanup is needed beyond removing any task
directory the Phase 4 live check created — and that directory is legitimate under `state.json`
regardless, so leaving it is also a valid outcome. If the harness in Phase 3 exposes a defect,
fix Phase 1 and re-run Phases 3 and 4; Phase 2 is independent and need not be redone.

# Implementation Plan: Task #896

- **Task**: 896 - Fix cwd-relative artifact linking in skill-base.sh
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: None (task 892 is completed; it was a file-overlap serializer only)
- **Research Inputs**: specs/896_fix_cwd_relative_artifact_linking_in_skill_base/reports/01_cwd_relative_artifact_linking_fix.md
- **Artifacts**: plans/01_cwd-relative-artifact-linking-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`skill_link_artifacts` in `agent-system/extensions/core/scripts/skill-base.sh` (lines 459-481)
resolves three paths relative to the caller's ambient working directory — `specs/state.json`,
`specs/tmp/state.json`, and `bash .claude/scripts/generate-todo.sh` — even though the same file
already computes and exports a cwd-independent `SKILL_REPO_ROOT` anchor at line 32 and uses it
correctly for `TASK_DIR_ABS` (line 187) and the orchestrator handoff path (line 542). When the
function runs from any cwd other than the repo root it silently fails to register the artifact,
which is what makes operators reach for `reconcile-artifacts.sh` as a workaround — and that
script has no way to scope its backfill to one task, so the workaround inflates unrelated tasks'
artifact lists.

This plan makes those three paths anchor on `SKILL_REPO_ROOT`, adds the missing `mkdir -p` for
the tmp directory, and adds an opt-in `--task N` filter to `reconcile-artifacts.sh` while leaving
its no-argument repo-wide sweep byte-for-byte unchanged. Definition of done: the function
registers artifacts correctly when invoked from an arbitrary non-root cwd, and
`reconcile-artifacts.sh --task N` touches only task N while a bare invocation behaves exactly as
today.

### Research Integration

Findings from `reports/01_cwd_relative_artifact_linking_fix.md` that shape this plan:

- The defect is entirely internal to `skill_link_artifacts`'s body. Neither call site
  (`skills/skill-orchestrate/SKILL.md:635-636`, `skills/skill-orchestrate-hard/SKILL.md:860-861`)
  passes a path that needs changing, and the function signature stays identical — so the four
  documentation references to `skill_link_artifacts` (`docs/guides/creating-skills.md:101,261,400`,
  `docs/architecture/system-overview.md:107`, `docs/architecture/architecture-spec.md:201`,
  `docs/examples/research-flow-example.md:223`) remain accurate with no edits.
- The same bare-relative-path convention recurs across the rest of `skill-base.sh`
  (`skill_validate_input:174`, `skill_read_artifact_number:279`,
  `skill_increment_artifact_number:415,421`, `skill_propagate_memory_candidates:437,445`, and the
  `bash .claude/scripts/{update-task-status,events-append,validate-artifact}.sh` calls at
  207/213/258/341/359/390/401). Research explicitly scopes the fix to `skill_link_artifacts` only;
  a whole-file refactor is out of scope.
- `reconcile-artifacts.sh` already resolves `PROJECT_ROOT` correctly (lines 22-23), already sources
  `deploy-root-guard.sh` (line 24), and already `mkdir -p`s its tmp dir (line 127). Its only gap is
  the absent per-task filter.
- Its sole call site — `commands/task.md:438`, inside `/task --sync` step 2.5 — invokes it with no
  arguments for a legitimate repo-wide sweep. The filter must therefore be strictly additive.
- `deploy-root-guard.sh` hard-fails any script executed from the `agent-system/extensions/` source
  store, because `../..` resolves to a bogus root there. This is not a bug to fix; it is a
  constraint on how verification must be performed (see Phase 1).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task; `roadmap_path` was not provided in the delegation context.

## Goals & Non-Goals

**Goals**:
- Make all three paths inside `skill_link_artifacts` resolve from `SKILL_REPO_ROOT` instead of the
  caller's cwd.
- Create `${SKILL_REPO_ROOT}/specs/tmp` before the first jq round-trip so the redirect cannot fail
  on a fresh clone.
- Add an opt-in `--task N` filter to `reconcile-artifacts.sh` that scopes the backfill to a single
  task.
- Prove both changes with executable verification from a non-root working directory.
- Keep every edit inside `agent-system/extensions/core/**`.

**Non-Goals**:
- Refactoring the other bare-relative-path uses in `skill-base.sh` (a separate, larger change).
- Creating any `link-artifacts.sh` script — no such file is missing.
- Editing anything under `.claude/**` (gitignored, disposable deploy artifact regenerated from the
  source store).
- Making the filtered mode the default for `reconcile-artifacts.sh`.
- Adding `deploy-root-guard.sh` sourcing to `skill-base.sh` (research flagged this as a
  pre-existing, out-of-scope gap; the file is sourced, never executed).
- Changing `skill_link_artifacts`'s signature or either of its call sites.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Editing `.claude/scripts/skill-base.sh` instead of the source store | H | M | Every phase names the absolute source path `agent-system/extensions/core/scripts/...`; Phase 5 greps `git status` to confirm no `.claude/**` file was modified |
| Disturbing the two-step jq idiom that works around the `!=` escaping bug (Issue #1132) | H | L | Only the file-path operands change; the jq filter expressions (lines 469-470, 476) are copied verbatim and diffed in Phase 5 |
| `--task` filter accidentally becoming the default and silently narrowing the `/task --sync` sweep | H | L | Phase 4 verification runs the bare no-argument invocation and diffs its output against a pre-change baseline captured in Phase 1 |
| `for arg in "$@"` cannot consume a flag value; a naive `--task N` addition would treat `N` as an unrecognized arg and abort | M | H | Phase 3 explicitly converts the loop to a `while`/`shift` form and accepts both `--task N` and `--task=N` |
| Verification run from the source store silently writes stray artifacts under a bogus root | M | M | All verification runs against a throwaway deployed-shaped harness under the scratch directory, never against the source store or the live repo |
| A stale exported `SKILL_REPO_ROOT` in the verifying shell masks a still-broken anchor | M | M | Harness invocations use `env -u SKILL_REPO_ROOT` so the anchor is always recomputed from `BASH_SOURCE` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel. Phases 2 and 3 touch disjoint files
(`skill-base.sh` vs `reconcile-artifacts.sh`) and may run concurrently.

---

### Phase 1: Build verification harness and capture pre-fix baseline [COMPLETED]

**Goal**: Stand up a throwaway repo-shaped harness that satisfies `deploy-root-guard.sh`, and
record the current (broken) behavior so Phases 4 and 5 have something concrete to diff against.

**Tasks**:
- [x] Create a harness root under the session scratch directory, e.g. `$HARNESS=<scratch>/h/repo`,
      with `mkdir -p "$HARNESS/.claude" "$HARNESS/specs"`. *(completed)*
- [x] Copy the entire source-store scripts directory into the harness deploy location:
      `cp -r agent-system/extensions/core/scripts "$HARNESS/.claude/scripts"`. Copying the whole
      directory (not individual files) keeps `deploy-root-guard.sh` and `generate-todo.sh`
      resolvable as siblings, which both are required to be. *(completed)*
- [x] Confirm the guard is satisfied: `bash "$HARNESS/.claude/scripts/reconcile-artifacts.sh"
      --dry-run` must NOT print the "must run from a deployed scripts/ tree" error. *(completed:
      guard passed; only error was pre-fixture "state.json not found")*
- [x] Seed `$HARNESS/specs/state.json` with a minimal fixture containing at least three
      `active_projects` entries (e.g. numbers 1, 2, 3) with matching zero-padded task directories
      and one `.md` file each under `reports/` — enough for the reconcile sweep to have real
      backfill work on more than one task. *(completed)*
- [x] Create a writable non-root cwd for the caller, e.g. `mkdir -p "$HARNESS/../elsewhere"`.
      *(completed)*
- [x] Capture the pre-fix `skill_link_artifacts` baseline: from `$HARNESS/../elsewhere`, run
      `env -u SKILL_REPO_ROOT bash -c 'source "$HARNESS/.claude/scripts/skill-base.sh';
      skill_link_artifacts 1 "specs/001_x/reports/01_a.md" research "s" "**Research**" "**Plan**"'`
      and save both the stderr and the resulting `$HARNESS/specs/state.json` to a baseline file.
      *(completed: defect confirmed — state.json byte-identical before/after, stderr shows
      "specs/tmp/state.json: No such file or directory")*
- [x] Capture the pre-change `reconcile-artifacts.sh` no-argument baseline: run it with `--dry-run`
      against a pristine copy of the fixture and save the full stdout as
      `baseline-reconcile-repowide.txt`. *(completed)*
- [x] Record in the harness notes whether a stray `specs/` directory appeared under
      `$HARNESS/../elsewhere` during the pre-fix run. *(completed: none appeared)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- None in the repository. All output lands under the session scratch directory.

**Verification**:
- `bash "$HARNESS/.claude/scripts/reconcile-artifacts.sh" --dry-run` exits 0 and lists backfill
  candidates for more than one task (proves the guard passes and the fixture is non-trivial).
- The pre-fix `skill_link_artifacts` baseline demonstrates the defect: either an error mentioning
  `specs/state.json`, or an unchanged `$HARNESS/specs/state.json` — i.e. the artifact is NOT
  registered. If the pre-fix run unexpectedly succeeds, stop and re-check that the harness cwd is
  genuinely not the harness root before proceeding.

---

### Phase 2: Anchor `skill_link_artifacts` paths on `SKILL_REPO_ROOT` [COMPLETED]

**Goal**: Replace the three cwd-relative paths inside `skill_link_artifacts` with
`SKILL_REPO_ROOT`-anchored paths and add the missing tmp-directory creation, changing nothing else
in the file.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/skill-base.sh`, inside `skill_link_artifacts` only,
      add `mkdir -p "${SKILL_REPO_ROOT}/specs/tmp"` as the first statement inside the
      `if [ -n "$artifact_path" ]; then` block, before the Step 1 jq call. *(completed)*
- [x] Replace the Step 1 redirect operands (currently line 471) so both `specs/state.json` and
      `specs/tmp/state.json` become `"${SKILL_REPO_ROOT}/specs/state.json"` and
      `"${SKILL_REPO_ROOT}/specs/tmp/state.json"`, including the `mv` source and destination.
      *(completed)*
- [x] Apply the identical substitution to the Step 2 redirect operands (currently line 477).
      *(completed)*
- [x] Replace `bash .claude/scripts/generate-todo.sh` (currently line 479) with
      `bash "${SKILL_REPO_ROOT}/.claude/scripts/generate-todo.sh"`, preserving the existing
      `|| echo "WARNING: generate-todo.sh failed (non-fatal)"` suffix verbatim. *(completed)*
- [x] Leave the jq filter expressions, the `--arg` bindings, the function signature, the local
      variable defaults, and the doc comment block (lines 452-458) untouched. *(completed:
      verified via git diff — jq filter expressions and doc comment block unchanged)*
- [x] Do not modify any other function in the file. *(completed: git diff hunk confined to
      skill_link_artifacts body)*

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - three path substitutions plus one
  `mkdir -p` inside `skill_link_artifacts`; no other function touched.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/skill-base.sh` parses cleanly.
- `git diff -- agent-system/extensions/core/scripts/skill-base.sh` shows changed lines only within
  the `skill_link_artifacts` body; no hunk touches another function.
- `grep -n 'specs/state.json\|specs/tmp\|generate-todo.sh' agent-system/extensions/core/scripts/skill-base.sh`
  shows no remaining bare-relative occurrence between the `skill_link_artifacts()` opening line and
  its closing brace (occurrences elsewhere in the file are expected and in scope to leave alone).
- Re-copy the file into the Phase 1 harness and re-run the Phase 1 baseline invocation from
  `$HARNESS/../elsewhere` with `env -u SKILL_REPO_ROOT`: `$HARNESS/specs/state.json` must now
  contain the new artifact entry for task 1, and no stray `specs/` directory may appear under the
  caller's cwd.

---

### Phase 3: Add opt-in `--task N` filter to `reconcile-artifacts.sh` [COMPLETED]

**Goal**: Let the reconcile sweep be scoped to a single task while keeping the no-argument
repo-wide sweep as the unchanged default.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/reconcile-artifacts.sh`, update the header usage
      docstring (lines 9-13) to `.claude/scripts/reconcile-artifacts.sh [--dry-run] [--task N]` and
      document the new option: scope the backfill to a single task number; default is all active
      tasks. *(completed)*
- [x] Introduce `TASK_FILTER=""` next to the existing `DRY_RUN=false`. *(completed)*
- [x] Convert the argument loop (lines 28-37) from `for arg in "$@"` to a `while [[ $# -gt 0 ]]`
      loop with explicit `shift`, since the current form cannot consume a flag value. Accept
      `--dry-run`, `--task N` (two-token, shift twice), and `--task=N` (single token). *(completed)*
- [x] Reject a `--task` value that does not match `^[0-9]+$` with a clear stderr message and
      `exit 1`. Reject a `--task` with no following value the same way. *(completed)*
- [x] Keep the `*)` catch-all as a hard usage error with `exit 1`, updating its usage string to
      `[--dry-run] [--task N]` so an unrecognized flag still aborts rather than being ignored.
      *(completed)*
- [x] In the main loop, immediately after the existing `[[ -z "$task_num" ]] && continue` guard
      (line 80), add an explicit `if [[ -n "$TASK_FILTER" ]] && [[ "$task_num" -ne "$TASK_FILTER" ]];
      then continue; fi`. Use the `if`/`then` form rather than a trailing `&& continue` compound so
      the loop body's exit status cannot interact with `set -uo pipefail`. Numeric `-ne` comparison
      makes a zero-padded filter value behave the same as an unpadded one. *(completed)*
- [x] Leave the `jq -r '.active_projects[] | ...'` process substitution at line 150 unchanged — the
      filter is applied in the loop, not in the jq expression, keeping the diff small and the skip
      logic co-located with the existing per-task skip. *(completed)*
- [x] Extend the final summary echoes so that when `TASK_FILTER` is set the output names the scope
      (for example, appending ` (task $TASK_FILTER)` to the existing messages). Leave the unfiltered
      message strings byte-for-byte identical. *(completed: verified byte-for-byte match against
      Phase 1 baseline in Phase 3 verification)*
- [x] Do not change `agent-system/extensions/core/commands/task.md:438`; its no-argument invocation
      must keep working unmodified. *(completed: verified unchanged)*

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/scripts/reconcile-artifacts.sh` - docstring, argument parsing loop,
  one filter guard in the main loop, filter-aware summary echoes.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/reconcile-artifacts.sh` parses cleanly.
- Copy the updated script into the Phase 1 harness and run:
  - `--dry-run` with no `--task`: stdout matches `baseline-reconcile-repowide.txt` exactly.
  - `--dry-run --task 2`: every `[reconcile]` line names `task=2` and no other task number appears.
  - `--task=2 --dry-run`: same output as the two-token form.
  - `--dry-run --task 999999`: prints `[reconcile] No artifact gaps found` and exits 0.
  - `--task abc`: exits 1 with a message naming the invalid value; state.json unmodified.
  - `--task` with no value: exits 1 with a usage error.
  - `--bogus`: still exits 1 with the usage error (regression guard on the catch-all).
- `grep -n 'reconcile-artifacts.sh' agent-system/extensions/core/commands/task.md` still shows the
  bare, argument-free invocation.

---

### Phase 4: Integrated non-root-cwd regression verification [COMPLETED]

**Goal**: Prove both fixes hold together, executed from a working directory that is not the repo
root, with real mutation (not `--dry-run`) against the harness fixture.

**Tasks**:
- [x] Refresh the harness with the Phase 2 and Phase 3 versions of both scripts and a pristine copy
      of the Phase 1 state fixture. *(completed)*
- [x] From `$HARNESS/../elsewhere`, source the harness `skill-base.sh` with `env -u SKILL_REPO_ROOT`
      and call `skill_link_artifacts` for each of the three artifact types (`research`, `plan`,
      `summary`) against different task numbers. *(completed)*
- [x] Confirm `$HARNESS/specs/state.json` gained exactly the expected entries, and that
      `$HARNESS/specs/TODO.md` was regenerated (proving the `generate-todo.sh` path resolved).
      *(completed)*
- [x] Delete `$HARNESS/specs/tmp` and repeat one `skill_link_artifacts` call to confirm the new
      `mkdir -p` makes a missing tmp directory a non-issue. *(completed)*
- [x] Call `skill_link_artifacts` twice with the same task number and the same artifact type but
      different paths; confirm the remove-then-add semantics still leave exactly one entry of that
      type (the two-step jq idiom is intact). *(completed: length==1, latest path retained)*
- [x] From the same non-root cwd, run the harness `reconcile-artifacts.sh --task N` for real (no
      `--dry-run`) and confirm only task N's `artifacts` array changed; capture a `jq` diff of the
      other tasks' arrays before and after to prove they are untouched. *(completed: diff empty)*
- [x] Run the harness `reconcile-artifacts.sh` with no arguments for real against a fresh fixture
      copy and confirm it backfills every task exactly as the Phase 1 baseline predicted.
      *(completed: 3 artifacts for 3 tasks, matches baseline)*
- [x] Confirm no stray `specs/` directory, `state.json`, or `TODO.md` was created anywhere under
      `$HARNESS/../elsewhere`. *(completed: find returned nothing)*

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Files to modify**:
- None in the repository. Verification output lands under the session scratch directory.

**Verification**:
- Every `skill_link_artifacts` call performed from the non-root cwd is reflected in
  `$HARNESS/specs/state.json`, and `$HARNESS/specs/TODO.md` exists and is non-empty.
- The duplicate-type call leaves exactly one artifact entry of that type: assert with
  `jq '[.active_projects[] | select(.project_number==N).artifacts[] | select(.type=="plan")] | length'`
  equal to 1.
- The `--task N` real run leaves every other task's `artifacts` array byte-identical to its
  pre-run value.
- `find "$HARNESS/../elsewhere" -mindepth 1` returns nothing.

---

### Phase 5: Source-store compliance audit and diff review [COMPLETED]

**Goal**: Confirm the change set is confined to the source store, is scoped as planned, and carries
no ephemeral task-number citations in deliverable files.

**Tasks**:
- [x] Run `git status --short` and confirm the only modified repository files are
      `agent-system/extensions/core/scripts/skill-base.sh` and
      `agent-system/extensions/core/scripts/reconcile-artifacts.sh` (plus this task's own `specs/`
      artifacts). *(completed: this task's two source-store files are modified as planned;
      deviation — `git status --short` also shows `.claude-extensions.json`,
      `agent-system/extensions/core/skills/skill-orchestrate{,-hard}/SKILL.md`,
      `lua/neotex/plugins/editor/which-key.lua`,
      `lua/neotex/plugins/tools/himalaya/utils/cli.lua`, and an unrelated task 897 directory —
      these are pre-existing working-tree state and a concurrently running implementation agent's
      changes on a disjoint file set per this task's concurrency constraint, not edits made by this
      implementation)*
- [x] Confirm no path under `.claude/` appears in `git status --short` output. *(completed: none)*
- [x] Review `git diff -- agent-system/extensions/core/scripts/` in full and confirm the
      `skill-base.sh` hunks fall entirely within `skill_link_artifacts` and the jq filter
      expressions are unchanged apart from their file-path operands. *(completed: single hunk,
      only the three redirect operand substitutions plus the `mkdir -p` line; jq filter
      expressions byte-identical)*
- [x] Grep both changed files for task-number citation patterns (for example
      `grep -nEi 'task [0-9]+|tasks [0-9]' agent-system/extensions/core/scripts/skill-base.sh
      agent-system/extensions/core/scripts/reconcile-artifacts.sh`) and confirm no new comment
      cites a task number. Any needed provenance comment must reference the durable anchor — the
      `REPO ROOT ANCHOR` block at the top of `skill-base.sh` — not a task number. *(completed: grep
      matches two pre-existing comments in skill-base.sh, lines 19 and 159, referencing prior
      tasks — both confirmed outside this diff's hunk via `git diff`, so no new citation was
      introduced; reconcile-artifacts.sh has zero matches)*
- [x] Confirm `agent-system/extensions/core/manifest.json` already lists both scripts and needs no
      change (`reconcile-artifacts.sh` is at line 142; `skill-base.sh` is an existing entry).
      *(completed: both present, no change needed)*
- [x] Spot-check that the four documentation references to `skill_link_artifacts`
      (`docs/guides/creating-skills.md`, `docs/architecture/system-overview.md`,
      `docs/architecture/architecture-spec.md`, `docs/examples/research-flow-example.md`) remain
      accurate — the signature is unchanged, so no doc edit is expected. Record explicitly if any
      does need updating. *(completed: all four references cite the function name/signature only,
      none needs updating)*
- [x] Note in the implementation summary that the deployed `.claude/scripts/` copy is stale by
      design and will pick the fix up on the next sync; no hand-edit of the deploy tree was made.
      *(completed: noted in summary)*

**Timing**: 0.25 hours

**Depends on**: 4

**Files to modify**:
- None. Audit only.

**Verification**:
- `git status --short | grep -c '^.* \.claude/'` returns 0.
- `git diff --stat -- agent-system/` lists exactly two changed files.
- The task-number grep over both changed files returns no new matches.

---

## Testing & Validation

- [x] `bash -n` passes on both modified scripts.
- [x] `skill_link_artifacts` invoked from a non-root cwd registers the artifact in the correct
      repo's `state.json` and regenerates that repo's `TODO.md`.
- [x] `skill_link_artifacts` succeeds when `specs/tmp` does not yet exist.
- [x] Repeated `skill_link_artifacts` calls for the same task and type leave exactly one entry
      (two-step jq remove-then-add semantics preserved).
- [x] No stray `specs/` tree is created under the caller's working directory.
- [x] `reconcile-artifacts.sh` with no arguments produces output identical to the pre-change
      baseline.
- [x] `reconcile-artifacts.sh --task N` and `--task=N` both scope the backfill to task N and leave
      every other task's `artifacts` array untouched.
- [x] `reconcile-artifacts.sh --task <non-numeric>`, `--task` with no value, and `--bogus` each
      exit 1 without modifying `state.json`.
- [x] `commands/task.md`'s argument-free invocation is unchanged.
- [x] Only `agent-system/extensions/core/**` files are modified; nothing under `.claude/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/skill-base.sh` (modified — `skill_link_artifacts` only)
- `agent-system/extensions/core/scripts/reconcile-artifacts.sh` (modified — optional `--task N`
  filter)
- `specs/896_fix_cwd_relative_artifact_linking_in_skill_base/summaries/01_cwd-relative-artifact-linking-fix-summary.md`
- Verification harness and captured baselines under the session scratch directory (transient, not
  committed)

## Rollback/Contingency

Both changes are confined to two files in the source store and are independently revertible with
`git checkout HEAD -- agent-system/extensions/core/scripts/skill-base.sh` and/or
`git checkout HEAD -- agent-system/extensions/core/scripts/reconcile-artifacts.sh` (per the
destructive-git rule, snapshot first via `bash .claude/scripts/git-snapshot.sh` if other
uncommitted work is present). No state migration, no schema change, and no deploy-tree edit is
involved, so a revert is complete on its own. The `.claude/scripts/` deploy tree is regenerated
from the source store, so reverting the source and re-syncing fully restores prior behavior.

If Phase 3's argument-loop conversion proves riskier than expected, Phase 2 stands alone and can be
landed independently — the two phases share no file and no code path.

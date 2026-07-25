# Implementation Plan: Task #893

- **Task**: 893 - Close stranded-status detection gap for not_started tasks with existing artifacts
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/893_close_stranded_status_detection_gap_for_not_started/reports/01_stranded-status-detection-gap.md
- **Artifacts**: plans/01_stranded-status-detection-gap.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`reconcile-task-status.sh`'s `case "$current_status" in` dispatch has explicit branches for
`researching`, `planning`, `implementing`, and `partial`, but `not_started` falls into the `*)`
catch-all alongside genuinely-terminal statuses. A task whose plan was written but whose planning
postflight was lost therefore stays at `not_started` forever, and `/orchestrate`'s unattended entry
reconcile reports "no stranded status found." This plan adds a `not_started)` branch with two
promotion cases (fresh plan -> `planned`; fresh phase handoff -> `partial`), gated by a new
mtime-comparison helper that prevents the `/task --recover` workflow from being misread as a
stranded run. All edits target ONE file in the source store.

### Research Integration

Every design decision below is carried from the research report:

- **Root cause**: the `*)` catch-all (comment currently reading `# All other statuses
  (not_started, researched, planned, completed, blocked, abandoned, expanded)`) swallows
  `not_started` with no artifact inspection at all.
- **False-positive risk (load-bearing)**: `/task --recover` moves an archived task's ENTIRE
  directory back (`plans/`, `reports/`, `summaries/`, `handoffs/` intact), forces
  `.status = "not_started"`, and stamps `.last_updated` to the recovery time in the same jq call.
  That is structurally identical to a stranded task under a naive artifact-presence check. The
  mitigation — a new `artifact_newer_than_last_update()` helper — is REQUIRED, not optional.
- **`handoff_permits_promotion` / `handoff_status_value` are near-pass-through in standard mode**
  (`.orchestrator-handoff.json` is written only by hard-mode dispatch paths), so they are reused
  for consistency with the existing three branches but must NOT be relied on to disambiguate
  recovered-vs-stranded. That job belongs solely to the mtime guard.
- **Git-log "phase commits exist" signal is SKIPPED**, per the research recommendation: a phase
  commit cannot exist without a prior plan file, so the `plans/*.md` check already covers every
  realistic case at lower cost and with fewer failure modes on an unattended promotion path.
- **Case (b) promotes to `partial`, NOT `implementing`** — `implementing` asserts work is actively
  underway right now; a cold reconcile pass finding a stalled run means "resumable".
- **Context that sets the conservatism bar**: `/orchestrate` runs this reconcile LIVE with no
  `--dry-run` and no human present. Every promotion is automatic and unreviewed.

Two additions this plan makes beyond the report, both verified against the source store during
planning:

1. The report's draft helper used GNU-only `date -u -d`. The codebase already has a portable
   GNU-then-BSD idiom at `scripts/task-lock.sh` (`date -u -d "$ts" +%s 2>/dev/null || date -u -j -f
   "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null`). Phase 1 uses that idiom so the guard is not
   silently a no-op on a BSD host — a silent no-op guard is exactly the failure this task exists
   to prevent.
2. `scripts/deploy-root-guard.sh` is sourced at line 33 and hard-fails any invocation whose
   `scripts/` parent is not `.claude/` or `.opencode/`. The source-store copy therefore CANNOT be
   executed in place. Phase 3 builds a throwaway sandbox deploy tree instead of attempting to run
   the script from `agent-system/`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context; no ROADMAP.md was consulted or modified.

## Goals & Non-Goals

**Goals**:

- Add a `not_started)` branch to `reconcile-task-status.sh` that promotes to `planned` when a
  `plans/*.md` artifact postdates the task's `last_updated`.
- Add a defense-in-depth case promoting to `partial` when `handoffs/*.md` postdates `last_updated`
  and no fresh plan matched.
- Add `artifact_newer_than_last_update()` as the false-positive guard, applied to BOTH new cases.
- Document the mtime rationale in the module header so a future maintainer does not delete the
  guard as apparently-redundant complexity.
- Prove, by executed test, that a `/task --recover`-shaped fixture and an empty task directory both
  remain `not_started`.

**Non-Goals**:

- No git-log "phase commits exist" signal (explicitly rejected by research).
- No changes to `update-task-status.sh` — `postflight <n> plan` -> `planned` (line reading
  `postflight:plan)      STATE_STATUS="planned"`) and `postflight <n> partial` -> `partial` (line
  reading `postflight:partial)  STATE_STATUS="partial"`) both already exist and are already
  reachable via `record_refused_promotion`.
- No changes to `commands/task.md` / the `--recover` flow. The mtime comparison is a self-contained
  local disambiguator requiring no new state.
- No changes to `handoff_permits_promotion` or `handoff_status_value` signatures or bodies.
- No edits under `.claude/**`. That tree is a gitignored, disposable deploy artifact.
- No deployment. The user re-deploys via `<leader>al` ("Load Core" / "Sync all") when ready; this
  task does not and cannot perform that step.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer edits `.claude/scripts/reconcile-task-status.sh` (the deployed copy) instead of the source store | H | M | Every phase names the absolute source-store path; Phase 3 verifies `git status` shows a tracked modification under `agent-system/` and NO write under `.claude/` |
| Guard silently no-ops on a BSD host (GNU-only `date -d`), reinstating the recover false-positive | H | M | Use the `task-lock.sh` GNU-then-BSD `date` fallback idiom; test asserts the guard actually refuses a stale fixture rather than only asserting the happy path |
| Over-eager promotion of a genuinely recovered task on an unattended `/orchestrate` run | H | M | Strict `-gt` (ties refuse, not permit); Phase 3 test T2 (older plan) and T3 (equal-second tie) both assert no-op |
| `set -euo pipefail` + unexpanded glob aborts the script on an empty `handoffs/` dir | M | M | Reuse the documented `|| true` pipefail workaround already carried on `find_latest_artifact`; test T5 covers an existing-but-empty artifact dir |
| Regression in the four existing branches | H | L | Phase 3 runs a regression pass over `researching` / `planning` / `implementing` / `partial` / `completed` fixtures asserting byte-identical prior behavior |
| Line anchors drift between planning and implementation | M | M | Every edit in this plan is anchored on quoted text, never on a line number |
| Task-number citations leak into script comments (violates repo rule) | M | L | All replacement text below cites durable anchors (`commands/task.md`, `scripts/claude-cleanup.sh`, `status-markers.md`) and contains zero task numbers; Phase 3 greps the diff to confirm |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel. This plan is fully sequential: Phase 2's
branch calls the helper Phase 1 adds, and Phase 3 tests what Phase 2 writes.

---

### Phase 1: Add `artifact_newer_than_last_update()` helper and document the mapping [COMPLETED]

**Goal**: Introduce the false-positive guard and the header documentation that explains why it
exists, with no behavior change yet (nothing calls the helper until Phase 2).

**Tasks**:

- [x] Open `/home/benjamin/.config/nvim/agent-system/extensions/core/scripts/reconcile-task-status.sh`
      (SOURCE STORE — never `.claude/scripts/`). *(completed)*
- [x] Apply Edit 1A (module header) below. *(completed)*
- [x] Apply Edit 1B (new helper) below. *(completed)*
- [x] Run `bash -n` on the file. *(completed: exits 0; deviation — verification grep count for
      `artifact_newer_than_last_update` is 2 not the plan-stated 1, because Edit 1A's own quoted
      text contains a forward reference to the helper name; applied verbatim per binding
      constraint 3, see progress file)*

**Edit 1A — module header.** Locate this exact block near the top of the file (it is the comment
block ending in `partial state   -> check handoff for continuation_context`):

```
# Artifact-to-phase mapping:
#   reports/*.md    -> research phase   (researching -> researched)
#   plans/*.md      -> planning phase   (planning -> planned)
#   summaries/*.md  -> implement phase  (implementing -> completed)
#   partial state   -> check handoff for continuation_context
```

Replace it with exactly:

```
# Artifact-to-phase mapping:
#   reports/*.md    -> research phase   (researching -> researched)
#   plans/*.md      -> planning phase   (planning -> planned)
#   summaries/*.md  -> implement phase  (implementing -> completed)
#   partial state   -> check handoff for continuation_context
#   plans/*.md      -> planning phase   (not_started -> planned)   [mtime-gated, see below]
#   handoffs/*.md   -> partial state    (not_started -> partial)   [mtime-gated, see below]
#
# Why the not_started mappings are mtime-gated:
#   A not_started task with artifacts on disk is ambiguous. It is either a crashed run whose
#   postflight was lost (promote it) or a task deliberately reset with its old artifacts left in
#   place (leave it alone). The Recover Mode in commands/task.md produces the second shape on
#   purpose: it moves an archived task's entire directory -- plans/, reports/, summaries/,
#   handoffs/ -- back into specs/, forces status="not_started", and stamps last_updated to the
#   recovery time in the same jq call. Artifact PRESENCE cannot tell the two apart; artifact
#   RECENCY can. A crashed run necessarily wrote its artifact after the last successful status
#   write, so artifact_mtime > last_updated. A recovered task's artifacts all predate the
#   recovery stamp, so last_updated > artifact_mtime. Promotion therefore requires a strictly
#   newer artifact (see artifact_newer_than_last_update below).
#
#   Do NOT "simplify" this into a bare artifact-presence check. This reconcile runs live and
#   unattended from the orchestrate entry path (no --dry-run, no human), so dropping the guard
#   would silently fast-forward every recovered task past the research or planning it was
#   recovered to redo.
```

**Edit 1B — new helper.** Locate this exact block (the `handoff_status_value` definition, which
sits immediately before the `# --- Helper: record a refused promotion ...` comment):

```
# --- Helper: read the handoff's status field (empty string if no handoff file) ---
handoff_status_value() {
  local handoff_file="${TASK_DIR}/.orchestrator-handoff.json"
  if [[ -f "$handoff_file" ]]; then
    jq -r '.status // ""' "$handoff_file" 2>/dev/null
  fi
}
```

Replace it with exactly (the original block, unchanged, followed by the new helper):

```
# --- Helper: read the handoff's status field (empty string if no handoff file) ---
handoff_status_value() {
  local handoff_file="${TASK_DIR}/.orchestrator-handoff.json"
  if [[ -f "$handoff_file" ]]; then
    jq -r '.status // ""' "$handoff_file" 2>/dev/null
  fi
}

# --- Helper: is this artifact newer than the task's last recorded status write? ---
# The false-positive guard for the not_started branches (see the header's "Why the not_started
# mappings are mtime-gated" note). Returns 0 (permit) when the artifact's mtime is strictly
# greater than state.json's last_updated for this task, 1 (refuse) otherwise.
#
# Ties refuse, deliberately: a directory move can land an artifact's mtime on the same whole
# second as the recovery stamp, and the two outcomes are not symmetric. Refusing a tie costs one
# re-run of /plan; permitting one silently skips planning on a task that was reopened to redo it.
#
# Fails OPEN (0) when last_updated is missing or unparseable -- the same "signal absent ->
# permit" philosophy handoff_permits_promotion above already uses, so a task predating the
# last_updated field behaves as it did before. Fails CLOSED (1) when the artifact cannot be
# stat'd, which should not happen: callers only reach here after find_latest_artifact (or an
# equivalent listing) already located the file, so an unreadable path means something is wrong
# and refusing is correct.
#
# stat and date both use the GNU-then-BSD fallback idiom already established elsewhere in this
# codebase (scripts/claude-cleanup.sh for stat, scripts/task-lock.sh for date) rather than
# assuming GNU. A guard that silently degrades to a no-op on a non-Linux host would be worse
# than no guard, because it would look present in review while permitting every promotion.
artifact_newer_than_last_update() {
  local artifact_path="$1"
  local artifact_mtime last_updated_raw last_updated_epoch

  artifact_mtime=$(stat -c %Y "$artifact_path" 2>/dev/null \
    || stat -f %m "$artifact_path" 2>/dev/null) || return 1
  [[ -n "$artifact_mtime" ]] || return 1

  last_updated_raw=$(echo "$task_data" | jq -r '.last_updated // empty' 2>/dev/null)
  [[ -n "$last_updated_raw" ]] || return 0

  last_updated_epoch=$(date -u -d "$last_updated_raw" +%s 2>/dev/null \
    || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_updated_raw" +%s 2>/dev/null) || return 0
  [[ -n "$last_updated_epoch" ]] || return 0

  [[ "$artifact_mtime" -gt "$last_updated_epoch" ]]
}
```

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:

- `agent-system/extensions/core/scripts/reconcile-task-status.sh` — header mapping block extended
  with two `not_started` rows plus the rationale note; new `artifact_newer_than_last_update()`
  helper added after `handoff_status_value()`.

**Verification**:

- `bash -n /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/reconcile-task-status.sh`
  exits 0.
- `grep -c 'artifact_newer_than_last_update' <file>` returns 1 (definition only — no caller yet).
- `grep -n 'date -u -j -f' <file>` matches (BSD fallback present, not GNU-only).
- `grep -n 'stat -f %m' <file>` matches (BSD stat fallback present).
- `git status --short` shows ONLY `agent-system/extensions/core/scripts/reconcile-task-status.sh`
  modified; nothing under `.claude/`.
- The new comment text contains no task numbers (`git diff -U0 -- <file> | grep -nEi 'task [0-9]'`
  returns nothing).

---

### Phase 2: Add the `not_started)` dispatch branch [COMPLETED]

**Goal**: Wire the two promotion cases into the dispatch and stop claiming `not_started` is
unconditionally a no-op.

**Tasks**:

- [x] Apply Edit 2 below to the same source-store file. *(completed)*
- [x] Run `bash -n` on the file. *(completed: exits 0)*

**Edit 2 — new case plus catch-all comment.** Locate this exact block at the end of the `case`
statement:

```
  *)
    # All other statuses (not_started, researched, planned, completed, blocked, abandoned, expanded)
    # are either terminal or already at a stable state — no-op
    exit 0
    ;;
esac
```

Replace it with exactly:

```
  not_started)
    check_plan_state_divergence
    # Case (a): a plan exists and postdates the last recorded status write. The planning
    # postflight was lost mid-run -- replay it and promote not_started -> planned.
    plan_file=$(find_latest_artifact "plans")
    if [[ -n "$plan_file" ]] && artifact_newer_than_last_update "$plan_file"; then
      # Handoff-aware promotion guard (see handoff_permits_promotion above). Note this guard is
      # near-pass-through in standard mode -- .orchestrator-handoff.json is written only by
      # hard-mode dispatch paths -- so it is NOT what disambiguates a recovered task from a
      # stranded one. That is artifact_newer_than_last_update's job, above.
      if ! handoff_permits_promotion "planned"; then
        handoff_status=$(handoff_status_value)
        echo "[reconcile] Task $task_number: status=not_started, plan exists but handoff status=$handoff_status — refusing promotion"
        record_refused_promotion "$handoff_status"
        exit 0
      fi

      plan_basename=$(basename "$plan_file")
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[reconcile] Task $task_number: status=not_started, found plan $plan_basename"
        echo "[reconcile] Would promote: not_started -> planned via postflight plan"
        link_artifact "$plan_file" "plan" "Implementation plan: $plan_basename"
      else
        echo "[reconcile] Task $task_number: status=not_started but plan exists ($plan_basename) — replaying postflight"
        link_artifact "$plan_file" "plan" "Implementation plan: $plan_basename"
        "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "plan" "$session_id"
        echo "[reconcile] Task $task_number: promoted not_started -> planned"
      fi
      exit 0
    fi

    # Case (b), defense in depth: no fresh plan, but handoffs/ holds a phase handoff that
    # postdates the last status write, so an implementation run started and died. Promote to
    # `partial`, never `implementing`: `implementing` asserts work is underway right now, while a
    # cold reconcile pass finding a stalled run is exactly status-markers.md's "implementation
    # partially completed (can resume)". `partial` is also what record_refused_promotion and the
    # `partial` branch above already treat as the resting state for this situation, and the
    # permissive-transition rule lets /implement pick it up unchanged on the next dispatch.
    handoff_dir="${TASK_DIR}/handoffs"
    if [[ -d "$handoff_dir" ]]; then
      # `|| true` for the same pipefail reason documented on find_latest_artifact above: an
      # existing-but-empty directory leaves the glob unexpanded and makes `ls` exit non-zero.
      # `ls -1t` rather than the `sort -V` used there, because the question here is strictly
      # "is any handoff newer than last_updated" -- an mtime question, not a filename-order one.
      latest_handoff=$(ls -1t "${handoff_dir}/"*.md 2>/dev/null | head -1 || true)
      if [[ -n "$latest_handoff" ]] && artifact_newer_than_last_update "$latest_handoff"; then
        if ! handoff_permits_promotion "partial"; then
          handoff_status=$(handoff_status_value)
          echo "[reconcile] Task $task_number: status=not_started, handoffs/ non-empty but handoff status=$handoff_status — refusing promotion"
          record_refused_promotion "$handoff_status"
          exit 0
        fi

        handoff_basename=$(basename "$latest_handoff")
        if [[ "$DRY_RUN" == "true" ]]; then
          echo "[reconcile] Task $task_number: status=not_started, found phase handoff $handoff_basename"
          echo "[reconcile] Would promote: not_started -> partial via postflight partial"
        else
          echo "[reconcile] Task $task_number: status=not_started but phase handoff exists ($handoff_basename) — replaying postflight"
          "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "partial" "$session_id"
          echo "[reconcile] Task $task_number: promoted not_started -> partial"
        fi
        exit 0
      fi
    fi

    # Nothing newer than last_updated: either a genuinely new task, or one deliberately reset
    # (Recover Mode in commands/task.md) with its old artifacts intact. not_started is the
    # correct resting state in both cases -- no-op.
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[reconcile] Task $task_number: status=not_started, no artifact newer than last_updated — no-op"
    fi
    ;;

  *)
    # All other statuses (researched, planned, completed, blocked, abandoned, expanded) are
    # either terminal or already at a stable state — no-op
    exit 0
    ;;
esac
```

Note for the implementer: the em-dashes (`—`) in the `echo` strings are intentional and match the
diagnostic style of the four existing branches. Do not substitute ASCII hyphens. The comment prose
uses plain `--` in the same style the existing comments do.

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:

- `agent-system/extensions/core/scripts/reconcile-task-status.sh` — new `not_started)` case
  inserted before the `*)` catch-all; catch-all comment no longer lists `not_started`.

**Verification**:

- `bash -n <file>` exits 0.
- `grep -n 'not_started)' <file>` shows the new case arm (in addition to the pre-existing
  `not_started) echo "NOT STARTED"` arm inside `plan_level_equivalent`, which must be unchanged).
- `grep -n 'All other statuses' <file>` shows the updated comment WITHOUT `not_started` in the list.
- `grep -c 'artifact_newer_than_last_update' <file>` returns 3 (one definition, two call sites).
- `grep -n 'git log' <file>` returns nothing — the rejected git-log signal was not introduced.
- `grep -n 'not_started -> implementing' <file>` returns nothing — case (b) targets `partial`.
- `git diff --stat` shows exactly one file changed, under `agent-system/`.

---

### Phase 3: Sandbox verification matrix [NOT STARTED]

**Goal**: Prove by executed test that stranded tasks are promoted, and that the two must-not-fire
cases — a `/task --recover`-shaped fixture and an empty task directory — remain `not_started`.

**Why a sandbox is required**: `reconcile-task-status.sh` sources `deploy-root-guard.sh`, which
hard-fails (`exit 1`) unless the parent of its `scripts/` dir is `.claude/` or `.opencode/`. The
source-store copy cannot be run in place, and the repo's own `.claude/` must not be written to.
Build a disposable deploy tree in the scratchpad instead.

**Tasks**:

- [ ] Build the sandbox:

  ```bash
  SB=/tmp/claude-1000/-home-benjamin--config-nvim/dddad7e6-30ce-4f57-84c3-fb38a6f4e2db/scratchpad/reconcile-sandbox
  rm -rf "$SB" && mkdir -p "$SB/.claude/scripts" "$SB/specs"
  cp -a /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/. "$SB/.claude/scripts/"
  ```

  Confirm `bash "$SB/.claude/scripts/reconcile-task-status.sh"` no longer trips the deploy-root
  guard (it should reach argument validation instead).

- [ ] Write a synthetic `$SB/specs/state.json` containing one `active_projects` entry per fixture
      below, each with `project_number`, `project_name`, `status`, `task_type`, and an explicit
      `last_updated` ISO8601 timestamp. Create the matching `$SB/specs/{NNN}_{project_name}/`
      directories. Set artifact mtimes with `touch -d '<ISO8601>'` relative to each entry's
      `last_updated` so the fresh/stale/tie distinction is exact and reproducible, not
      wall-clock-dependent.

- [ ] Run each fixture with `--dry-run` and assert the exact expected stdout line.

- [ ] Re-run T1, T2, T4, and T6 LIVE (no `--dry-run`) and assert the resulting `.status` in
      `$SB/specs/state.json` via `jq`.

- [ ] Run the regression pass (T10) and confirm output is unchanged from the pre-change script.
      Obtain the baseline by running the same fixtures against a pristine copy: `git show
      HEAD:agent-system/extensions/core/scripts/reconcile-task-status.sh` written into a second
      sandbox tree.

- [ ] Tear down: `rm -rf "$SB"`.

**Test matrix** (T2, T3, T4, T5, T7 are the must-not-fire cases):

| # | Fixture (status = `not_started` unless noted) | Expected |
|---|---|---|
| T1 | `plans/01_x.md` mtime NEWER than `last_updated` | `Would promote: not_started -> planned via postflight plan`; live run leaves `.status == "planned"` |
| T2 | `plans/01_x.md` mtime OLDER than `last_updated` (the `/task --recover` shape: full dir restored, `last_updated` stamped to recovery time) | `no artifact newer than last_updated — no-op`; live run leaves `.status == "not_started"` |
| T3 | `plans/01_x.md` mtime EQUAL to `last_updated` (whole-second tie from a directory move) | no-op — ties refuse under strict `-gt` |
| T4 | Task directory exists but is completely empty (no `plans/`, no `handoffs/`) | `no artifact newer than last_updated — no-op`; live run leaves `.status == "not_started"` |
| T5 | `plans/` directory exists but contains no `*.md` | no-op, and the script exits 0 (no `set -euo pipefail` abort on the unexpanded glob) |
| T6 | No `plans/`; `handoffs/phase-1-handoff-20260725T000000Z.md` mtime NEWER than `last_updated` | `Would promote: not_started -> partial via postflight partial`; live run leaves `.status == "partial"` |
| T7 | No `plans/`; `handoffs/*.md` mtime OLDER than `last_updated` | no-op |
| T8 | Fresh plan + `.orchestrator-handoff.json` with `"status": "blocked"` | `refusing promotion`; `record_refused_promotion` routes to `postflight ... blocked` |
| T9 | Fresh plan + `.orchestrator-handoff.json` with `"status": "planned"` | promotes to `planned` (handoff permits) |
| T10 | Regression: one fixture each at `researching` + fresh report, `planning` + fresh plan, `implementing` + fresh summary, `partial` + summary + implemented handoff, and `completed` | Output byte-identical to the pre-change baseline for all five |

**Timing**: 1.25 hours

**Depends on**: 2

**Files to modify**:

- None in the repository. All fixtures live under the scratchpad sandbox and are deleted at the end
  of the phase. If the implementer wants the harness kept, it goes in the scratchpad only — do NOT
  add a test file under `agent-system/` or `specs/` as part of this task.

**Verification**:

- All ten rows of the matrix pass with the expected output.
- T2, T3, T4, T5, and T7 each leave `.status == "not_started"` in the sandbox `state.json` after a
  LIVE (non-dry-run) invocation — this is the false-positive acceptance criterion and the task
  fails if any of them promotes.
- T10 produces output byte-identical to the `git show HEAD:` baseline.
- `git status --short` in `/home/benjamin/.config/nvim` shows exactly one modified file,
  `agent-system/extensions/core/scripts/reconcile-task-status.sh`, and nothing under `.claude/`.
- `git diff -- agent-system/extensions/core/scripts/reconcile-task-status.sh | grep -nEi 'task [0-9]+'`
  returns nothing (no task-number citations in a deliverable file).

---

## Testing & Validation

- [ ] `bash -n` passes on the modified script after each of Phases 1 and 2.
- [ ] T1 (fresh plan) promotes `not_started -> planned`, both dry-run and live.
- [ ] T2 (`/task --recover` shape: stale plan, recent `last_updated`) does NOT promote, live.
- [ ] T3 (equal-second tie) does NOT promote — confirms `-gt`, not `-ge`.
- [ ] T4 (empty task directory) does NOT promote, live.
- [ ] T5 (empty `plans/` directory) does not abort the script under `set -euo pipefail`.
- [ ] T6 (fresh phase handoff, no plan) promotes `not_started -> partial`, never `implementing`.
- [ ] T7 (stale phase handoff) does NOT promote.
- [ ] T8 (blocked handoff) refuses and records `blocked`; T9 (planned handoff) permits.
- [ ] T10 regression: `researching`, `planning`, `implementing`, `partial`, `completed` behave
      byte-identically to the pre-change baseline.
- [ ] BSD fallbacks present for both `stat` (`stat -f %m`) and `date` (`date -u -j -f`).
- [ ] No `git log` invocation introduced (the rejected signal).
- [ ] No file under `.claude/**` modified.
- [ ] No task-number citations in the modified script.

## Artifacts & Outputs

- Modified: `/home/benjamin/.config/nvim/agent-system/extensions/core/scripts/reconcile-task-status.sh`
  (the only repository file this task changes).
- Implementation summary: `specs/893_close_stranded_status_detection_gap_for_not_started/summaries/01_stranded-status-detection-gap-summary.md`.
- Transient (deleted at end of Phase 3): sandbox deploy tree and fixtures under the scratchpad.

**Deployment note**: `.claude/scripts/reconcile-task-status.sh` remains stale until the user
re-deploys via `<leader>al` ("Load Core" / "Sync all"). That step is user-driven and out of scope
here; the implementation summary should state plainly that the fix is not live until it happens.

## Rollback/Contingency

Single-file, additive change with no data migration and no dependency on any other file, so
rollback is a one-command revert:

```bash
git checkout HEAD -- agent-system/extensions/core/scripts/reconcile-task-status.sh
```

If the mtime guard proves too strict in practice (a legitimately stranded task refused because its
`last_updated` was written after the artifact), the safe interim posture is to keep the branch and
loosen ONLY the comparison — never to drop the guard. If it proves too loose (a recovered task
promoted anyway), the branch can be neutralized by restoring the original `*)` catch-all comment
and deleting the `not_started)` arm, leaving the helper in place harmlessly. In either direction
the worst-case wrong outcome is a promotion to `planned` or `partial`, both non-terminal and both
re-runnable under the permissive-transition rule — never `completed`.

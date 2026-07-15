# Implementation Plan: Task #878

- **Task**: 878 - harden_status_scripts_and_own_phase_markers
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: None (877 and 876 both COMPLETED; this plan consumes their settled outcomes)
- **Research Inputs**: reports/01_harden-status-scripts-phase-markers.md
- **Artifacts**: plans/01_harden-status-scripts-phase-markers.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Five verified defects (A-E) in the three task-status scripts and the base implementation agent
leave phase markers unowned, failures silent, plan selection mtime-ordered, plan/phase updates
skipped on an idempotent state write, and `partial`/`blocked` unreachable as task-level termini.
This plan fixes each defect in a dedicated phase, ordered so that later fixes land on a
foundation the earlier ones made safe. Definition of done: all four in-scope files are corrected
in the canonical tree and mirrored, every fix is verified by direct script invocation against an
isolated scratch fixture, and `.agent-logs/phase-transitions.log` is proven to be written.

### CRITICAL: canonical source vs. deploy mirror

**Independently verified during planning** (not merely inherited from the report):

- `.gitignore:7` contains `/.claude/` — confirmed via `git check-ignore -v .claude/scripts/update-task-status.sh`.
- `agent-system/extensions/core/scripts/update-task-status.sh` is git-tracked — confirmed via `git ls-files --error-unmatch`.
- All four in-scope files are currently byte-identical across the two trees — confirmed via `diff -q`.

Therefore **every** edit in this plan targets the canonical `agent-system/` path FIRST, then is
mirrored verbatim to the `.claude/` path in the same phase. Editing `.claude/` alone produces a
change that appears to work in-session and is silently discarded on the next redeploy.

| # | Canonical (edit this; git-tracked) | Deploy mirror (copy to this; gitignored) |
|---|-------------------------------------|-------------------------------------------|
| 1 | `agent-system/extensions/core/scripts/update-task-status.sh` | `.claude/scripts/update-task-status.sh` |
| 2 | `agent-system/extensions/core/scripts/update-plan-status.sh` | `.claude/scripts/update-plan-status.sh` |
| 3 | `agent-system/extensions/core/scripts/update-phase-status.sh` | `.claude/scripts/update-phase-status.sh` |
| 4 | `agent-system/extensions/core/agents/general-implementation-agent.md` | `.claude/agents/general-implementation-agent.md` |

Mirror step for every phase (adjust the file list per phase):

```bash
cp agent-system/extensions/core/scripts/<file>.sh .claude/scripts/<file>.sh
diff -q agent-system/extensions/core/scripts/<file>.sh .claude/scripts/<file>.sh   # must be silent
```

Only the canonical tree is staged for commit; the mirror is gitignored and will not appear in
`git status`. Its correctness is verified by `diff -q`, never by the commit.

### Research Integration

The research report is authoritative over the original task description on three points, all
honored below:

1. **DEFECT A is a prompt-wiring fix, not a script fix.** `update-phase-status.sh` already takes
   an explicit `phase_number` and locates that exact heading; its interface needs no change. The
   base agent simply never calls it (`grep -c "update-phase-status"` returns zero). Phase 5 wires
   it, mirroring `general-implementation-hard-agent.md`'s proven Stage 4A/4D pattern.
2. **DEFECT B's silent site is the caller, not the sed anchor.** `update-plan-status.sh` already
   self-verifies and exits 1 (lines 64-71). The silence is introduced by
   `update-task-status.sh:256-258`, which pipes its stderr to `/dev/null` and downgrades exit 1
   to a warning. Phase 4 fixes the caller and leaves `update-plan-status.sh`'s own fail-loud
   logic untouched.
3. **DEFECT C has a third, undocumented site** at `update-task-status.sh:274`, beyond the two in
   the description. All three are fixed in Phase 2.

Also integrated: `.agent-logs/phase-transitions.log` is confirmed absent (re-verified during
planning) — hard proof `update-phase-status.sh` has never completed a transition. Its appearance
is this plan's primary end-to-end success signal.

### Planning-time correction to the report's DEFECT C recommendation

The report recommends selecting the newest plan via `ls "$plan_dir"/*.md | sort | tail -1`. **A
plain lexicographic sort is not safe** and this plan does not use it. Verified empirically during
planning: `specs/archive/197_fix_workflow_command_task_number_header_display/plans` contains both
`implementation-001.md` (legacy convention) and `02_revised-header-fix.md` (current convention).
Plain `sort | tail -1` selects `implementation-001.md`, because `i` sorts after `0` — the *older*
file, and a fresh regression rather than a fix. Six such directories were found where mtime-order
and name-order diverge, and 8 distinct non-conforming legacy filenames exist across 882 plan files.

The selection rule encoded in Phase 2 is therefore two-tier:

1. Prefer files matching `^[0-9]{2}_` (the `MM_{short-slug}.md` convention mandated by
   `artifact-formats.md`); if any exist, take the lexicographically greatest.
2. Only if none match, fall back to the lexicographically greatest of all `*.md` (which orders
   the legacy `implementation-NNN.md` family correctly among itself).

This is correct for conforming dirs, legacy-only dirs, and mixed dirs alike.

A second correction: the report suggests site 3 could instead reuse the path
`update-plan-status.sh` already returned. **It cannot** — that script's idempotent no-op branch
(line 58) exits 0 emitting nothing, so its stdout is empty on a successful no-op. All three sites
get the independent two-tier rule instead.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided and no ROADMAP.md consultation was requested for this task.

## Goals & Non-Goals

**Goals**:

- Give phase markers an owning mechanism that covers phases 2..N, not just phase 1 (DEFECT A).
- Encode a deliberate fatal-vs-warn decision at every failure site, and stop discarding the
  underlying script's stderr anywhere (DEFECT B).
- Make plan selection version-ordered rather than mtime-ordered at all three sites (DEFECT C).
- Scope the idempotency early-exit to state.json only, so plan/phase updates still fire and
  become self-healing on retry (DEFECT D).
- Admit `partial` and `blocked` as task-level termini in the writer (DEFECT E).
- Keep the canonical `agent-system/` tree and the `.claude/` mirror identical at every phase.

**Non-Goals**:

- **No new scripts.** Only the three that exist are fixed and wired.
- **Not wiring `reconcile-task-status.sh`** — confirmed dead (no caller anywhere outside its own
  file and its manifest registration) and explicitly the scope of a separate downstream task.
- **Not re-litigating the plan-status marker vocabulary** settled in
  `specs/877_settle_plan_status_marker_vocabulary/`. The six plan-level values
  `{NOT STARTED, IMPLEMENTING, PARTIAL, BLOCKED, ABANDONED, COMPLETED}` and the five phase-heading
  values `{NOT_STARTED, IN_PROGRESS, COMPLETED, PARTIAL, BLOCKED}` are consumed as settled.
- **Not adding `errors.json` logging** to the `generate-todo.sh` failure site. The report
  recommends it; this plan defers it deliberately. It would introduce a jq-append-with-schema
  dependency into a bare status script for a failure that is already self-healing on the next
  successful run, and it is separable from the silence fix (Phase 4 still makes the warning loud).
  Recorded here as a known, deliberate deviation from the report.
- **Not changing `update-phase-status.sh`'s interface** — already adequate per-phase.
- **Not making plan/phase file updates fire for `partial`/`blocked`** — `update_plan_file()`
  returns early unless `target_status == implement`, and DEFECT E's scope per the description is
  the writer's validation and `map_status` only.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Testing status scripts against the real `specs/state.json` corrupts live task state | H | M | Never invoke the scripts against the repo root during development. All phases verify against an isolated `mktemp -d` fixture (see Verification Harness below), which the scripts resolve into naturally via their own `SCRIPT_DIR/../..` root derivation. |
| Lexicographic plan selection regresses on legacy/mixed-convention dirs | M | H (verified to occur) | Two-tier selection rule preferring `^[0-9]{2}_` files, with legacy fallback. Phase 2 verifies against all three directory shapes explicitly. |
| Fatal postflight plan-write (Phase 4) leaves state.json `completed` with a stale plan and no retry path | H | M | Sequence DEFECT D (Phase 3) *before* DEFECT B (Phase 4). Once the early-exit is scoped to state.json, re-running postflight after fixing the plan anchor no-ops state.json and still fires the plan write, so the fatal exit is genuinely retryable rather than terminal. |
| Fatal postflight blocks completion on a legitimately legacy plan file lacking the `- **Status**:` anchor | M | L | Accepted, per the report and the task description ("a strong fatal candidate"). Narrow trigger (anchor genuinely absent); a completed task with a silently-wrong plan file is the costlier failure this task exists to eliminate. Exit code 3 is distinct and documented, so callers can distinguish it from validation (1) and state.json (2) failures. |
| Scoping the early-exit (Phase 3) breaks the idempotency contract task 876 relies on | H | L | 876 depends only on state.json writes being deduplicated, never on the plan file being skipped. Phase 3 preserves the state.json no-op exactly (including the `workflow-active` marker, which the current early-exit also skips) and only stops it from suppressing the plan/phase side effects. Phase 3 verifies the double-invocation no-op explicitly. |
| Editing `.claude/` only; change silently lost on redeploy | H | M | Every phase edits canonical-first and ends with a `diff -q` mirror check. Phase 6 re-verifies all four pairs. |
| Wiring the base agent duplicates the hard agent's contract; future edits must touch both | L | M | Accepted — mirrors the existing intentional relationship between the two agent files (the hard agent is a documented superset, not a shared library). |
| Task-number citations leak into the scripts/agent files | M | M | `no-task-references-in-deliverables.md` applies: all four in-scope files are outside `specs/**`. Every phase's checklist carries an explicit no-task-reference check; comments cite durable anchors (`plan-format.md`, `artifact-formats.md`) instead. |

## Verification Harness (shared by all phases)

These scripts are the machinery that records task status, so no phase may verify itself using
that machinery (no `/implement` status transitions, no reading the task's own state.json entry as
evidence). Every phase verifies by **direct script invocation against an isolated fixture**.

The fixture works because each script derives its own root: `update-task-status.sh` and
`update-phase-status.sh` compute it as `SCRIPT_DIR/../..`, and `update-task-status.sh` `cd`s to
that root before calling `update-plan-status.sh` (which resolves `specs/...` relatively). Copying
the script directory into a scratch tree therefore relocates all three scripts' notion of the
repo root, with zero risk to the real `specs/`.

```bash
# Build fixture (from repo root)
FIXTURE=$(mktemp -d)
mkdir -p "$FIXTURE/.claude/scripts" "$FIXTURE/specs/878_fixture/plans"
cp .claude/scripts/*.sh "$FIXTURE/.claude/scripts/"        # includes generate-todo.sh
cat > "$FIXTURE/specs/state.json" <<'JSON'
{
  "next_project_number": 879,
  "active_projects": [
    { "project_number": 878, "project_name": "fixture", "status": "planned", "task_type": "meta" }
  ]
}
JSON
# NOTE: the fixture plan is generated line-by-line rather than via a heredoc *on purpose*.
# A heredoc would place literal "### Phase N:" and "- **Status**:" lines at column 0 inside
# THIS plan file, and the scripts under repair grep exactly those anchors — they would latch
# onto the fixture example instead of this plan's real phases. Keep every generated anchor
# behind an echo so it never appears at the start of a line in this document.
{
  echo '# Implementation Plan: Fixture'
  echo '- **Status**: [NOT STARTED]'
  echo ''
  echo '## Implementation Phases'
  echo ''
  for i in 1 2 3; do echo "### Phase $i: Fixture Phase $i [NOT STARTED]"; done
} > "$FIXTURE/specs/878_fixture/plans/01_fixture-plan.md"

# Invoke the script under repair, isolated from the real tree
bash "$FIXTURE/.claude/scripts/update-task-status.sh" preflight 878 implement sess_fixture
```

**Anchor-collision rule (applies to every phase)**: never write a literal `### Phase N:` or
`- **Status**: [...]` at column 0 anywhere in a task artifact that these scripts will parse.
Generate such lines behind `echo`, or indent them. This is why the fixture builder above looks
indirect.

Rebuild the fixture fresh per phase (`rm -rf "$FIXTURE"` then re-create) so no phase inherits
another's mutations. Re-`cp` the scripts after each edit so the fixture tests the current code.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 5 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 6 | 4, 5 |

Phases within the same wave can execute in parallel. Phases 1-4 are strictly sequential because
all four edit `update-task-status.sh` and would otherwise conflict. Phase 5 touches only the agent
markdown and is independent of the entire script chain.

**Ordering rationale**: DEFECT E is first because it is the highest-value fix — it was hit live in
a real orchestrate run and forced a hand-edit of `state.json` — and it is the smallest, most
self-contained change. DEFECT D precedes DEFECT B so that B's new fatal exit lands on a
foundation where retry actually re-fires the plan write (see Risks).

---

### Phase 1: DEFECT E — admit `partial` and `blocked` as task-level termini [COMPLETED]

**Goal**: Make `partial` and `blocked` reachable through the sanctioned writer, eliminating the
need to hand-edit `state.json`. `generate-todo.sh` already renders both (lines 125, 127), so only
the writer changes.

**Tasks**:

- [x] Edit `agent-system/extensions/core/scripts/update-task-status.sh` line 69 validation to admit `partial` and `blocked` alongside `research`, `plan`, `implement`, `pr_ready`; update the error message on line 70 to list them. *(completed)*
- [x] Update the usage text (lines 58-60) and the header comment block (line 15) to document the two new `target_status` values. *(completed)*
- [x] Add two cases to `map_status()` (lines 89-102): `postflight:partial) STATE_STATUS="partial"; TODO_STATUS="PARTIAL"` and `postflight:blocked) STATE_STATUS="blocked"; TODO_STATUS="BLOCKED"`. *(completed)*
- [x] Do NOT add `preflight:partial` or `preflight:blocked` cases — `map_status()`'s existing `*)` catch-all correctly rejects them with exit 1, which is the desired fail-loud behavior for a nonsensical combination. Confirm this by test rather than by adding cases. *(completed: verified via fixture — `preflight 878 partial` exits 1 with "unknown operation:target_status combination")*
- [x] Confirm the change sits OUTSIDE the idempotency early-exit (lines 133-144): `map_status` runs at line 105, well before it. No interaction; record this as verified. *(completed: confirmed by reading the file — map_status call precedes the idempotency block by ~30 lines)*
- [x] Verify no task-number citations were introduced (file is outside `specs/**`). *(completed: grep for "task [0-9]"/"tasks [0-9]" returned zero hits)*
- [x] Mirror to `.claude/scripts/update-task-status.sh`; confirm `diff -q` is silent. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:

- `agent-system/extensions/core/scripts/update-task-status.sh` — validation, usage text, header comment, `map_status()` cases
- `.claude/scripts/update-task-status.sh` — mirror

**Verification**:

- Build a fresh fixture. `bash "$FIXTURE/.claude/scripts/update-task-status.sh" postflight 878 partial sess_fixture --dry-run` exits 0 and reports the intended `planned -> partial` transition (dry-run avoids any write while still exercising validation and `map_status`).
- Same for `blocked`.
- Without `--dry-run`, `postflight 878 partial sess_fixture` exits 0 and `jq -r '.active_projects[0].status' "$FIXTURE/specs/state.json"` returns `partial`.
- `preflight 878 partial sess_fixture` exits 1 with the unknown-combination error — the catch-all is intact.
- An unchanged invalid value (`postflight 878 bogus sess_fixture`) still exits 1.
- The four pre-existing target values still behave as before (spot-check `postflight 878 implement`).

---

### Phase 2: DEFECT C — version-ordered plan selection at all three sites [NOT STARTED]

**Goal**: Replace mtime-ordered plan selection (`ls -t | head -1`) with the two-tier
version-ordered rule at all three sites, including the third site the task description omitted.

**Tasks**:

- [ ] Define the shared snippet (duplicated at each site — no new script is permitted, and the deliberate duplication mirrors how these three scripts already each re-derive their own plan directory):

  ```bash
  # Prefer the MM_{short-slug}.md convention (artifact-formats.md); highest sequence wins.
  # Fall back to a plain name sort only when no conforming file exists, so legacy-named
  # plans never outrank a conforming one (a plain sort would rank "implementation-001.md"
  # above "02_revised.md" because "i" sorts after "0").
  plan_file=$(ls "$plan_dir"/[0-9][0-9]_*.md 2>/dev/null | sort | tail -1 || true)
  if [[ -z "$plan_file" ]]; then
      plan_file=$(ls "$plan_dir"/*.md 2>/dev/null | sort | tail -1 || true)
  fi
  ```

- [ ] Apply at site 1: `update-plan-status.sh` line 48. Preserve the existing empty-result guard (lines 49-52) unchanged.
- [ ] Apply at site 2: `update-phase-status.sh` line 63. Preserve the existing empty-result guard (lines 64-67) unchanged.
- [ ] Apply at site 3 (undocumented in the task description): `update-task-status.sh` line 274, inside the auto-advance snippet. Preserve its `|| echo ""` fallback semantics and the `if [[ -n "$plan_file" ]]` guard.
- [ ] Do NOT attempt to reuse the path returned by `update-plan-status.sh` at site 3: its idempotent no-op branch (line 58) exits 0 emitting nothing, so its stdout is empty on a successful no-op and unusable as a path source. Record this as the reason.
- [ ] Confirm `set -euo pipefail` interaction: each `ls` is guarded by `2>/dev/null` and `|| true`, so an empty directory yields an empty string rather than aborting.
- [ ] Verify no task-number citations were introduced in any comment.
- [ ] Mirror all three scripts to `.claude/scripts/`; confirm all three `diff -q` checks are silent.

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:

- `agent-system/extensions/core/scripts/update-plan-status.sh` — line 48 selection
- `agent-system/extensions/core/scripts/update-phase-status.sh` — line 63 selection
- `agent-system/extensions/core/scripts/update-task-status.sh` — line 274 selection
- `.claude/scripts/{update-plan-status,update-phase-status,update-task-status}.sh` — mirrors

**Verification**:

Verify against all three directory shapes, using fixture plan dirs (never the real `specs/`):

- **Conforming dir**: `01_a.md`, `02_b.md`, `03_c.md`, with `touch` used to make `01_a.md` the newest by mtime. The scripts must select `03_c.md` — proving version-order beat mtime-order.
- **Mixed dir** (the verified real-world hazard): `implementation-001.md` plus `02_revised.md`. The scripts must select `02_revised.md`, not `implementation-001.md`.
- **Legacy-only dir**: `implementation-001.md` .. `implementation-004.md`. The scripts must select `implementation-004.md` via the fallback tier.
- **Empty dir**: each script still reports its existing "No plan file found" error and exits 1 (site 1/2), and site 3 still no-ops without aborting.
- Confirm selection directly: run `update-phase-status.sh` against the fixture and check that the *expected* file (not the mtime-newest) is the one whose heading changed and the one named in the emitted path.

---

### Phase 3: DEFECT D — scope the idempotency early-exit to state.json only [NOT STARTED]

**Goal**: Stop a same-status state.json write from suppressing the plan and phase updates, making
those updates self-healing on every invocation, while preserving byte-for-byte the state.json
no-op contract that the orchestrate preflight wiring depends on.

**Tasks**:

- [ ] Replace the early `exit 0` at `update-task-status.sh:138-144` with a flag: set `state_is_noop=true` when `current_state_status == STATE_STATUS`, and do not exit.
- [ ] Guard the `update_state_json` invocation (lines 195-198) so it runs only when `state_is_noop == false`. Preserve its exit-2-on-failure behavior unchanged for the non-no-op path.
- [ ] Leave `regenerate_todo` (line 291) and `update_plan_file` (line 294) unconditional, so they now fire on the no-op path too. Both downstream scripts have their own idempotency checks (`update-plan-status.sh:56-59`, `update-phase-status.sh:90-94`), so redundant calls are safe no-ops.
- [ ] Preserve the `workflow-active` marker semantics exactly: it is written inside `update_state_json()` (lines 162-166), which the current early-exit also skips on a no-op. Keeping it inside the guarded call means no behavior change. Confirm and record this rather than moving the marker write.
- [ ] Preserve the `--dry-run` no-op message (line 141) — it must still print `[dry-run] Task N already at status 'X' -- no-op` when the state write is a no-op, now alongside the dry-run plan/phase lines.
- [ ] Make the final success line (line 297) accurate on the no-op path: report that state.json was already at the target and the plan/phase updates were still applied, rather than falsely claiming a status change.
- [ ] Confirm the state.json no-op contract is intact: a second identical invocation must not rewrite `last_updated` or `session_id`. This is what the orchestrate preflight wiring depends on.
- [ ] Verify no task-number citations were introduced.
- [ ] Mirror to `.claude/scripts/update-task-status.sh`; confirm `diff -q` is silent.

**Timing**: 0.75 hours

**Depends on**: 2

**Files to modify**:

- `agent-system/extensions/core/scripts/update-task-status.sh` — idempotency block, `update_state_json` guard, final report line
- `.claude/scripts/update-task-status.sh` — mirror

**Verification**:

- Fresh fixture with `status: "implementing"` and a plan whose `- **Status**:` is `[NOT STARTED]`. Run `preflight 878 implement sess_fixture` (a state.json no-op). Confirm: exit 0; `jq` shows `status` still `implementing` **and** `last_updated`/`session_id` unchanged (capture the file's sha256 before/after — it must be byte-identical); **and** the plan file's `- **Status**:` is now `[IMPLEMENTING]` and Phase 1's heading is `[IN PROGRESS]`. This is the whole point of the defect: the state no-op no longer suppresses the plan side effects.
- Double-invocation check (the orchestrate-preflight contract): run the same command twice more; state.json stays byte-identical each time and the plan file converges without error.
- Non-no-op path unaffected: from `status: "planned"`, `preflight 878 implement` writes state.json, regenerates, and updates the plan exactly as before.
- `--dry-run` on the no-op path still prints the no-op message and now also lists the intended plan/phase lines, writing nothing (fixture sha256 unchanged for both state.json and the plan file).

---

### Phase 4: DEFECT B — encode the fatal-vs-warn decision, stop discarding stderr [NOT STARTED]

**Goal**: Replace blanket silence with a deliberate per-site policy. No site may discard the
underlying script's stderr; the one site whose failure can leave state.json and the plan file in
permanent, externally-invisible disagreement becomes fatal.

**Decision table** (from the research report, encoded here as the implementation contract):

| Site | File:Line | Current | Target | Rationale |
|------|-----------|---------|--------|-----------|
| TODO.md regen | `update-task-status.sh:209-211` | Warning | **Warning**, made louder (no stderr discard; it has none today — confirm and leave) | state.json is machine truth and already wrote; TODO.md is a rendered view regenerable on the next run or via `/todo`. Failing the whole operation over a rendering failure would block legitimate work. |
| Plan status, `implement` **postflight** (`COMPLETED`) | `update-task-status.sh:256-258` | Warning, stderr discarded | **FATAL** (new exit code 3), stderr surfaced | No user-visible surface reveals the divergence — `generate-todo.sh` reads only state.json, never plan files. A task recorded `completed` with a plan file still at `[IMPLEMENTING]` is worse than a loud, retryable failure. |
| Plan status, `implement` **preflight** (`IMPLEMENTING`) | `update-task-status.sh:256-258` | Warning, stderr discarded | **Warning**, stderr surfaced | Advisory marking; work is starting either way. Non-fatal avoids blocking legitimate starts on a legacy plan quirk. |
| Phase auto-advance | `update-task-status.sh:280-283` | Warning, stderr discarded | **Warning**, stderr surfaced | Superseded by the Phase 5 fix: once the agent owns every transition, this call is a redundant convenience, recoverable by the agent's own explicit calls. |

**Tasks**:

- [ ] Remove `2>/dev/null` from the `update-plan-status.sh` call site (line 256) so its already-fail-loud diagnostic (`"Failed to update status in $plan_file"`) reaches the user. Do NOT modify `update-plan-status.sh` itself — it is fail-loud by design; the caller was the defect.
- [ ] Branch the plan-status call site on `operation`: on `postflight`, a non-zero exit is fatal — print a diagnostic naming the plan file and the divergence, then `exit 3`. On `preflight`, keep the non-fatal warning.
- [ ] Add exit code 3 to the header comment block (lines 19-22), documented as "plan file update failed after state.json was written (retry after fixing the plan file; the state.json write is idempotent and will no-op)".
- [ ] Remove `2>/dev/null` from the `update-phase-status.sh` call site (line 280); keep the warning non-fatal.
- [ ] Confirm the `generate-todo.sh` site (line 209) has no stderr redirect today and leave it non-fatal and unchanged apart from any message clarity.
- [ ] Confirm `update_plan_file()`'s two existing early-return warnings (missing `project_name`, non-executable plan script) remain non-fatal `return 0` — they are pre-condition misses, not update failures.
- [ ] Note in a comment at the fatal site that the retry path is only safe because the state.json write is idempotent (the Phase 3 change) — cite the behavior, not the task number.
- [ ] Verify no task-number citations were introduced in any comment or message.
- [ ] Mirror to `.claude/scripts/update-task-status.sh`; confirm `diff -q` is silent.

**Timing**: 0.75 hours

**Depends on**: 3

**Files to modify**:

- `agent-system/extensions/core/scripts/update-task-status.sh` — `update_plan_file()` call sites, header comment exit codes
- `.claude/scripts/update-task-status.sh` — mirror

**Verification**:

- **Fatal postflight fires**: fixture plan file with its `- **Status**:` anchor line deleted. Run `postflight 878 implement sess_fixture`. Confirm exit code is exactly 3, and that `update-plan-status.sh`'s own `Failed to update status in ...` message appears on stderr (proving the discard is gone, not merely the exit code).
- **Retry is genuinely effective** (the Phase 3 + Phase 4 composition): restore the anchor line, re-run the identical `postflight 878 implement sess_fixture`. Confirm exit 0, state.json unchanged (already `completed`, byte-identical), and the plan file now reads `[COMPLETED]`. This proves the fatal is retryable rather than terminal.
- **Preflight stays non-fatal**: same broken-anchor fixture, run `preflight 878 implement sess_fixture`. Confirm exit 0 with the warning *and* the underlying script's stderr both visible.
- **Phase site stays non-fatal**: fixture plan with a valid `- **Status**:` anchor but no `### Phase` headings. Confirm `preflight 878 implement` exits 0 with a visible phase warning.
- **TODO.md regen stays non-fatal**: temporarily make `$FIXTURE/.claude/scripts/generate-todo.sh` non-executable or exit 1. Confirm the state.json write still succeeds and the command exits 0 with a warning.
- **Happy path unaffected**: intact fixture, `postflight 878 implement` exits 0 and marks the plan `[COMPLETED]`.

---

### Phase 5: DEFECT A — wire the base agent to own every phase transition [NOT STARTED]

**Goal**: Give phase markers an owning mechanism covering phases 2..N. The script's per-phase
interface is already adequate; the base agent is the missing caller. Mirror
`general-implementation-hard-agent.md`'s proven Stage 4A/4D pattern, including its Edit-tool
fallback.

**Tasks**:

- [ ] In `agent-system/extensions/core/agents/general-implementation-agent.md`, replace the Stage 4 **A. Mark Phase In Progress** block (lines ~120-126) — currently an Edit-tool-only instruction — with a `update-phase-status.sh ... IN_PROGRESS` call, keeping the Edit-tool instruction as an explicit "if the script is unavailable" fallback, exactly as the hard agent does at its lines 152-158.
- [ ] Replace the Stage 4 **D. Mark Phase Complete** block (lines ~225-231) with a `... COMPLETED` call plus the same Edit-tool fallback, mirroring the hard agent's lines 168-174.
- [ ] Use the phase-heading vocabulary (`IN_PROGRESS`, `COMPLETED`), never the plan-level vocabulary. The two are deliberately distinct and each script enforces its own; do not harmonize them.
- [ ] Preserve the existing directive "Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per phase." in both blocks.
- [ ] Preserve the task-lock heartbeat block that follows **D** (line ~237) unchanged and in place.
- [ ] **Specify `project_name` derivation explicitly** — do not copy the hard agent's gap. The hard agent references `$project_name` at its lines 155/171/233 without ever defining it; the base agent must not inherit that. Both agents receive `plan_path` (`specs/{NNN}_{SLUG}/plans/...`), so instruct the agent to derive `project_name` as the `{SLUG}` portion of that path component (strip the zero-padded `{NNN}_` prefix), and `task_number` from `{NNN}` (unpadded). State this once, near Stage 4A's first use.
- [ ] Add a marker-verification step near Stage 5 (Run Final Verification), modeled on the hard agent's Stage 5a self-repair loop (its lines 220-236): after all phases complete, scan the plan file for any residual `[NOT STARTED|IN PROGRESS|PARTIAL]` phase heading and repair each via a per-phase `update-phase-status.sh ... COMPLETED` call, deriving `phase_num` from the grep match. This is the backstop that guarantees phases 2..N converge even if a per-phase call was missed.
- [ ] Leave `update-phase-status.sh` itself unmodified — its `phase_number` argument and exact `^### Phase {n}:` lookup already support arbitrary per-phase calls.
- [ ] Leave `update-task-status.sh`'s first-phase auto-advance snippet in place. It becomes redundant once the agent owns all transitions, but the script's own idempotency check (lines 90-94) makes the overlap a safe no-op; removing it is unnecessary churn.
- [ ] Verify no task-number citations were introduced (this file is outside `specs/**`).
- [ ] Mirror to `.claude/agents/general-implementation-agent.md`; confirm `diff -q` is silent.

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:

- `agent-system/extensions/core/agents/general-implementation-agent.md` — Stage 4A, Stage 4D, Stage 5 marker verification, `project_name` derivation note
- `.claude/agents/general-implementation-agent.md` — mirror

**Verification**:

This phase changes a prompt, so verification is structural plus a live proof of the mechanism it
wires (not a proof of the LLM's compliance, which only a subsequent dispatch can show):

- `grep -c "update-phase-status" agent-system/extensions/core/agents/general-implementation-agent.md` returns at least 3 (4A, 4D, Stage 5 backstop) — up from a verified 0.
- Both `IN_PROGRESS` and `COMPLETED` appear as arguments; neither `IMPLEMENTING` nor any other plan-level value appears in a phase call.
- The Edit-tool fallback text is present under both 4A and 4D.
- The `project_name`/`task_number` derivation instruction is present and unambiguous.
- **Live proof the wired command works** (the mechanism, run by hand against the fixture): invoke `update-phase-status.sh` against a fixture plan for phase 2 and phase 3 — not just phase 1 — and confirm both headings change and that `$FIXTURE/.agent-logs/phase-transitions.log` is created containing both transitions. This directly rebuts the defect's evidence (the absent log) and proves coverage of phases 2..N, without touching the real `.agent-logs/`.
- `diff -q` on the two agent-file paths is silent.

---

### Phase 6: Integration verification and mirror consistency [NOT STARTED]

**Goal**: Prove the five fixes compose correctly, and that both trees are consistent. This phase
writes no new logic; it is the gate that the whole task is genuinely green.

**Tasks**:

- [ ] Rebuild a clean fixture from the current (fully patched) `.claude/scripts/`.
- [ ] Run the full lifecycle against the fixture: `preflight implement` -> per-phase `update-phase-status.sh` calls for phases 1, 2 and 3 -> `postflight implement`. Confirm the plan file ends with `- **Status**: [COMPLETED]` and all three phase headings at `[COMPLETED]`.
- [ ] Confirm DEFECT E composes: `postflight 878 partial` on the fixture writes `status: partial`, and is unaffected by the Phase 3 early-exit restructure (it is a genuine status change, never a no-op).
- [ ] Confirm DEFECT D + DEFECT B compose: the broken-anchor postflight exits 3, and the post-repair retry succeeds despite state.json being a no-op.
- [ ] Run `diff -q` across all four canonical/mirror pairs; all silent.
- [ ] Run `bash -n` on all three canonical scripts (syntax check) and confirm each remains executable (`-x`).
- [ ] Grep all four canonical files for task-number citation patterns (`task [0-9]`, `tasks [0-9]`); confirm zero hits, per `no-task-references-in-deliverables.md`.
- [ ] Confirm `reconcile-task-status.sh` was not modified in either tree (`git status` clean for it) — it remains out of scope.
- [ ] Confirm the real `specs/state.json` was never mutated by any verification step: it should carry only this task's own legitimate lifecycle transitions, with no fixture task 878 artifacts leaked in.
- [ ] Remove the fixture (`rm -rf "$FIXTURE"`).

**Timing**: 0.5 hours

**Depends on**: 4, 5

**Files to modify**:

- None (verification only)

**Verification**:

- Every checklist item above passes.
- `git status --short` shows exactly the three canonical scripts and one canonical agent file as modified, plus this task's own `specs/878_.../` artifacts — and nothing else. The `.claude/` mirror is gitignored and correctly absent from the listing.

---

## Testing & Validation

- [ ] DEFECT E: `postflight partial` and `postflight blocked` write `partial`/`blocked` to fixture state.json; `preflight partial` correctly fails loud via the `map_status` catch-all.
- [ ] DEFECT C: version-order beats mtime-order in a conforming dir; the mixed legacy/conforming dir selects the conforming file; the legacy-only dir selects the highest legacy number; all three sites agree on the same file.
- [ ] DEFECT D: a state.json no-op still drives the plan and phase updates; state.json stays byte-identical across repeated identical invocations (the orchestrate-preflight contract).
- [ ] DEFECT B: broken-anchor postflight exits 3 with the underlying stderr visible; the same command after repair exits 0 and updates the plan; preflight and phase sites stay non-fatal but loud; the TODO.md regen site stays non-fatal.
- [ ] DEFECT A: the base agent file references `update-phase-status.sh` at 4A, 4D, and the Stage 5 backstop, with fallbacks and an explicit `project_name` derivation; a hand-run against the fixture writes `phase-transitions.log` entries for phases 2 and 3, proving coverage beyond phase 1.
- [ ] All four canonical/mirror pairs are byte-identical.
- [ ] `bash -n` passes on all three scripts; all remain executable.
- [ ] Zero task-number citations in any of the four in-scope files.
- [ ] No new scripts were created; `reconcile-task-status.sh` untouched.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/update-task-status.sh` (defects B, C, D, E) + `.claude/scripts/update-task-status.sh` mirror
- `agent-system/extensions/core/scripts/update-plan-status.sh` (defect C) + `.claude/scripts/update-plan-status.sh` mirror
- `agent-system/extensions/core/scripts/update-phase-status.sh` (defect C) + `.claude/scripts/update-phase-status.sh` mirror
- `agent-system/extensions/core/agents/general-implementation-agent.md` (defect A) + `.claude/agents/general-implementation-agent.md` mirror
- `specs/878_harden_status_scripts_and_own_phase_markers/summaries/01_harden-status-scripts-phase-markers-summary.md`
- `.agent-logs/phase-transitions.log` — created on the next real `/implement` dispatch; its appearance is the standing end-to-end signal that defect A is genuinely fixed.

## Rollback/Contingency

- Each phase is a separate commit against the canonical `agent-system/` tree, so any single defect
  fix can be reverted with `git revert` without disturbing the others. The `.claude/` mirror is
  regenerated by re-running the phase's `cp` step from the reverted canonical file.
- The riskiest change is Phase 4's fatal exit 3. If it proves too aggressive in practice (fires on
  legacy plan files during normal work), it can be downgraded to the preflight warning branch by
  reverting Phase 4 alone; Phases 1-3 and 5 remain valid and independently useful.
- Phase 5 is prompt-only and carries no runtime risk: if the wired calls misbehave, the Edit-tool
  fallback text preserves the pre-existing hand-edit behavior, and reverting the file restores the
  current contract exactly.
- No phase mutates the real `specs/state.json` as part of its verification (all testing is
  fixture-isolated), so no rollback of live task state can be required by this work.

# Implementation Plan: Task #795

- **Task**: 795 - pr_ready_guard_type_pr
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/795_pr_ready_guard_type_pr/reports/01_pr_ready_guard_type_pr.md
- **Artifacts**: plans/01_pr-ready-guard-type-pr.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Reserve the `[PR READY]` / `pr_ready` status for `task_type == "pr"` tasks only, closing a
lifecycle leak where cslib (and potentially other) implementation tasks land on `[PR READY]`
instead of `[COMPLETED]`. The fix is four coordinated source-tree edits: (1) a runtime guard in
`update-task-status.sh` that rejects `pr_ready` transitions for non-pr tasks unless an explicit
override flag is passed; (2) a companion edit to `skill-orchestrate-hard` so its legitimate,
task-type-agnostic skeleton-exhaustion caller passes that override; (3) an explicit
`postflight ... implement` call in `skill-cslib-implementation` Stage 6 (the actual root-cause of
the leak); and (4) a documentation reconciliation in the `claudemd.md` merge-source. Every edited
file exists as a byte-identical extension-source/deployed-mirror pair that must stay in sync.

### Research Integration

The research report drives every phase decision:
- The guard location (core `update-task-status.sh`, not the cslib extension) and predicate
  (`task_type == "pr"` OR explicit override) come directly from the report's "Design Fork"
  section and Decisions.
- The **critical fourth edit** (`skill-orchestrate-hard`) is not in the task's original 3-edit
  framing but is required: the report proved the skeleton-exhaustion branch at
  `skill-orchestrate-hard/SKILL.md:431` calls `postflight pr_ready` task-type-agnostically for
  `general`/`lean4`/`cslib` hard-mode tasks. A bare `task_type == "pr"` guard would regress it.
- Stage 6 of `skill-cslib-implementation` must mirror the **hard sibling** Stage 7
  (`postflight ... implement`), NOT `skill-pr-implementation`'s `pr_ready` pattern — mirroring the
  latter would be self-defeating.
- All three mirror pairs were re-verified byte-identical at plan time (`diff -q` exit 0).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (roadmap flag not set).

## Goals & Non-Goals

**Goals**:
- `update-task-status.sh` rejects `preflight:pr_ready` and `postflight:pr_ready` for any task whose
  `task_type != "pr"`, unless an explicit override flag (`--allow-pr-ready`) is passed.
- `skill-orchestrate-hard`'s skeleton-exhaustion branch passes `--allow-pr-ready` so it keeps
  working for non-pr hard-mode tasks.
- `skill-cslib-implementation` Stage 6 spells out the concrete `postflight ... implement` call,
  landing non-pr cslib tasks on `[COMPLETED]`.
- `claudemd.md` (and its deployed `.claude/CLAUDE.md` render) scope `[PR READY]` to `type=pr`.
- Every edited file's extension-source and deployed mirror end up byte-identical.

**Non-Goals**:
- Repairing the 5 already-mislabeled deployed cslib tasks (447/404/407/438/453) in
  `~/Projects/cslib` — explicitly out of scope (separate manual data repair).
- Reconciling the stale `pr-prohibition.md` "Required Behavior" section — flagged by research as a
  fast follow-up, but outside 795's declared scope.
- Rerouting the skeleton-exhaustion branch to `[PARTIAL]` (a larger-blast-radius alternative the
  research surfaced but did not recommend).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Guard ships (Phase 1) without the orchestrate-hard override (Phase 2), breaking `/orchestrate --hard` skeleton completion for non-pr tasks | H | M | Phases 1+2 must land in the same implementation run / same commit; verification includes an explicit non-pr + `--allow-pr-ready` acceptance test |
| Extension-source and deployed mirror edited inconsistently, reintroducing drift | M | M | Each phase edits BOTH copies and ends with a `diff -q` sync check as its verification gate |
| `jq` `!=` escaping bug (Issue #1132) if guard uses `!=` | M | L | Use `==`-based equality only (`task_type == "pr"`); never `!=` in the guard |
| `claudemd.md` merge-source edit not reflected in deployed `.claude/CLAUDE.md` if regen path is misidentified | M | M | Phase 4 confirms the actual regeneration/deploy path first; if none automatable, edit both and `diff` the affected section |
| Override flag name collides with existing `--dry-run` parsing | L | L | Add `--allow-pr-ready` alongside the existing flag loop (line ~43), same positional-arg-preserving pattern |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3, 4 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel. Phase 2 depends on Phase 1 only because the
override flag name/semantics must be finalized in Phase 1 before Phase 2 wires the call site to it.
Phases 1, 3, and 4 touch disjoint files and are independent. Note: Phases 1 and 2 must both be
present before the guard is safe to rely on in practice (see Risks) — sequence them into the same
implementation run.

---

### Phase 1: Runtime guard + override flag in update-task-status.sh [COMPLETED]

**Goal**: `update-task-status.sh` rejects `pr_ready` transitions for non-pr tasks unless
`--allow-pr-ready` is passed, in both the deployed and extension-source copies.

**Tasks**:
- [x] Add `--allow-pr-ready` to the flag-parsing loop (~line 43, alongside `--dry-run`), setting a
      `ALLOW_PR_READY=true` variable (default `false` near line 38). *(completed)*
- [x] After the task-exists check (~line 109-112), add a `task_type` lookup mirroring the existing
      `project_name` jq lookup pattern (lines 212-214):
      `task_type=$(jq -r --arg num "$task_number" '.active_projects[] | select(.project_number == ($num | tonumber)) | .task_type // "general"' "$STATE_FILE")` *(completed)*
- [x] Add the guard: if `target_status == "pr_ready"` AND `task_type != "pr"` (expressed via
      `==`-equality logic, not `!=`) AND `ALLOW_PR_READY == false`, print a clear error to stderr and
      exit non-zero. Applies to both `preflight` and `postflight` operations. *(completed: implemented
      as three `==`-only if/elif branches, no `!=` used anywhere)*
- [x] Update the usage/comment block (lines 10, 15, 55-57) to document `pr_ready` and the new flag. *(completed)*
- [x] Apply the identical change to `.claude/extensions/core/scripts/update-task-status.sh`. *(completed,
      `diff -q` verified byte-identical)*
- [x] Update the `.claude/CLAUDE.md` `--allow-pr-ready` is an internal script flag — no CLAUDE.md
      surface needed (deferred to Phase 4 doc scope only if relevant). *(completed: no CLAUDE.md
      surface added for the flag itself, per plan)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - add flag parse, task_type lookup, pr_ready guard
- `.claude/extensions/core/scripts/update-task-status.sh` - identical mirror edit

**Verification**:
- Non-pr task + `pr_ready` (no flag): `bash .claude/scripts/update-task-status.sh postflight 795 pr_ready sess_test --dry-run` -> rejects with non-zero exit and clear error.
- Non-pr task + `pr_ready` + `--allow-pr-ready --dry-run` -> accepted (dry-run no-op path reached).
- Existing `implement`/`research`/`plan` transitions unaffected (spot-check one dry-run).
- `diff -q .claude/scripts/update-task-status.sh .claude/extensions/core/scripts/update-task-status.sh` exits 0.

---

### Phase 2: Pass override flag at orchestrate-hard skeleton-exhaustion call site [COMPLETED]

**Goal**: The skeleton-exhaustion branch keeps reaching `pr_ready` for non-pr hard-mode tasks by
explicitly passing `--allow-pr-ready`.

**Tasks**:
- [x] Edit `.claude/skills/skill-orchestrate-hard/SKILL.md` line 431: append `--allow-pr-ready` to
      `bash .claude/scripts/update-task-status.sh postflight "$task_number" pr_ready "$session_id"`. *(completed)*
- [x] Update the adjacent comment (~line 430) to note the flag is required because the guard now
      restricts `pr_ready` to `type=pr` and skeleton-exhaustion is the sanctioned task-type-agnostic
      exception. *(completed)*
- [x] Apply the identical change to `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md`. *(completed,
      `diff -q` verified byte-identical)*

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-orchestrate-hard/SKILL.md` - add `--allow-pr-ready` at line 431 + comment
- `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - identical mirror edit

**Verification**:
- `grep -n "allow-pr-ready" .claude/skills/skill-orchestrate-hard/SKILL.md` shows the flag on the skeleton-exhaustion call.
- `diff -q .claude/skills/skill-orchestrate-hard/SKILL.md .claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` exits 0.
- Combined with Phase 1: simulate the exact orchestrate-hard command line against a non-pr task in `--dry-run` -> accepted.

---

### Phase 3: Explicit postflight implement in skill-cslib-implementation Stage 6 [COMPLETED]

**Goal**: Close the root-cause vagueness — Stage 6 names the concrete `postflight ... implement`
call, landing non-pr cslib tasks on `[COMPLETED]`.

**Tasks**:
- [x] Replace the vague Stage 6 body (`.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md:120-121`,
      "Update state.json and TODO.md based on result.") with the explicit pattern mirrored from the
      hard sibling Stage 7 (`skill-cslib-implementation-hard/SKILL.md:294-301`):
      status-gated `bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"`
      when `status == "implemented"`, plus the partial-resume comment (keep `implementing` on partial). *(completed)*
- [x] Do NOT introduce any `pr_ready` call here (explicitly avoid the `skill-pr-implementation`
      pattern the original task text pointed at). *(completed: verified via grep, no pr_ready in file)*
- [x] Apply the identical change to the deployed mirror `.claude/skills/skill-cslib-implementation/SKILL.md`.
      *(completed: this mirror is a symlink to the extension-source file, so the single edit updated
      both; `diff -q` confirms byte-identical)*

**Timing**: 25 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md` - rewrite Stage 6
- `.claude/skills/skill-cslib-implementation/SKILL.md` - identical mirror edit

**Verification**:
- Stage 6 now contains `postflight "$task_number" implement` and no `pr_ready`.
- The plain skill's Stage 6 is structurally symmetric with the hard skill's Stage 7.
- `diff -q .claude/skills/skill-cslib-implementation/SKILL.md .claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md` exits 0.

---

### Phase 4: Doc reconciliation in claudemd.md (and deployed CLAUDE.md) [COMPLETED]

**Goal**: Status-marker docs scope `[PR READY]` to `type=pr` rather than presenting it as the
universal implementation terminus.

**Tasks**:
- [x] In `.claude/extensions/core/merge-sources/claudemd.md` (lines 36-37), replace the two
      status-marker lines with the three-line version from the research report (Finding 3):
      standard `[IMPLEMENTING] -> [COMPLETED]` terminus for non-pr types; `type=pr`-only
      `[IMPLEMENTING] -> [PR READY] -> [COMPLETED]`; and `type=pr`-only re-dispatch line. *(completed)*
- [x] Determine and use the actual regeneration/deploy path for `.claude/CLAUDE.md` (it is
      auto-generated from merge-sources per its header). If an automatable build/merge step exists,
      run it; otherwise apply the same edit to the deployed `.claude/CLAUDE.md` status-marker section
      (deployed lines ~45-46) and verify the section matches. *(completed: searched
      `.claude/scripts/install-extension.sh` — it only merges context index.json entries, not
      claudemd.md content; no automatable CLAUDE.md regeneration script exists, so applied the
      Rollback/Contingency fallback: direct dual-edit of merge-source + deployed CLAUDE.md)*
- [x] Confirm the edited section in deployed `.claude/CLAUDE.md` matches the merge-source intent.
      *(completed: sections diffed byte-for-byte identical)*

**Timing**: 25 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/merge-sources/claudemd.md` - replace status-marker lines 36-37
- `.claude/CLAUDE.md` - regenerate or apply matching edit to the status-marker section

**Verification**:
- `grep -n "type=pr" .claude/extensions/core/merge-sources/claudemd.md` shows the scoped lines.
- Deployed `.claude/CLAUDE.md` status-marker section reflects the same scoping.
- No other status-marker semantics changed.

---

## Testing & Validation

- [x] Guard rejects non-pr `pr_ready` (dry-run) and accepts `type=pr` `pr_ready` (dry-run). *(verified in sandbox)*
- [x] Guard accepts non-pr `pr_ready` when `--allow-pr-ready` is passed (dry-run). *(verified in sandbox)*
- [x] `implement`/`research`/`plan` transitions unchanged for all task types. *(verified: non-pr implement dry-run no-op unaffected)*
- [x] orchestrate-hard skeleton-exhaustion command line (with `--allow-pr-ready`) accepted for a non-pr task. *(verified in sandbox)*
- [x] cslib-implementation Stage 6 calls `postflight ... implement`, not `pr_ready`. *(verified via grep)*
- [x] claudemd.md and deployed CLAUDE.md scope `[PR READY]` to `type=pr`. *(verified: status-marker lines match)*
- [x] All four mirror pairs byte-identical (`diff -q` exit 0 for each). *(verified; skill-cslib-implementation pair is a symlink)*

## Artifacts & Outputs

- Modified `update-task-status.sh` (both copies) with the pr_ready guard + `--allow-pr-ready` flag.
- Modified `skill-orchestrate-hard/SKILL.md` (both copies) passing the override flag.
- Modified `skill-cslib-implementation/SKILL.md` (both copies) with explicit `postflight implement`.
- Modified `claudemd.md` merge-source (+ regenerated `.claude/CLAUDE.md`) with type=pr-scoped docs.

## Rollback/Contingency

Each phase is a small, self-contained set of edits. To revert, `git checkout` the affected file
pairs. Because the guard (Phase 1) and its override (Phase 2) are interdependent, revert them
together if either misbehaves. The doc (Phase 4) and cslib-skill (Phase 3) edits are independently
revertible with no runtime coupling. If the `claudemd.md` regeneration path cannot be confirmed,
fall back to a direct dual-edit of merge-source + deployed CLAUDE.md and record the manual step in
the summary.

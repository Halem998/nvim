# Implementation Plan: Task #807

- **Task**: 807 - Add skeleton-field validation to validate-handoff.sh
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: 778 (parent; schema origin, already [COMPLETED])
- **Research Inputs**: specs/807_validate_handoff_skeleton_field/reports/01_validate-handoff-skeleton-field.md
- **Artifacts**: plans/01_validate-handoff-skeleton-field.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Make `.claude/scripts/validate-handoff.sh` aware of the `skeleton` boolean that task 778
added to the H9 handoff schema. The current Check 3 (`sorry_inventory`, lines 108-115) is
warn-only and has zero skeleton awareness, so a relaxed zero-debt skeleton handoff with an
under-specified `sorry_inventory` passes validation while being untracked. The fix inserts an
early `status`/`skeleton` read right after JSON-parsability Check 1, then branches Check 3 into
a strict skeleton-mode path (non-empty `sorry_inventory`, per-entry field enforcement,
status/skeleton invalid-combination check) versus the untouched existing standard-mode path.
A new optional test harness (`.claude/tests/test-validate-handoff.sh`) with five fixtures
locks in both the new strict behavior and the byte-identical standard-mode behavior.

### Research Integration

The research report supplies copy-paste-ready bash/jq for every change and confirms the
structural facts this plan depends on:
- Single-copy script, **no `extensions/core` mirror** (`find`/`grep` confirmed) -> no lockstep
  concern; edit one file only.
- `status` is first read inside Check 4 (line 127), which is *why* Check 3 cannot currently
  branch on status; the fix moves a `status`/`skeleton` read up to just after Check 1 (line 95).
- The `skeleton == true` branch is wrapped in `if [[ "$skeleton" == "true" ]] ... else <exact
  prior Check 3 logic> fi`, so any handoff with `skeleton` absent/false takes the untouched
  `else` path -- this is the mechanism guaranteeing standard-mode stays byte-identical.
- Only the mechanically-checkable subset of the anti-analysis.md 5-condition strategic-sorry
  test is enforced (condition 4 "Tracked": non-empty `assumption`/`why_deferred`, non-null
  `follow_up_task`). Conditions 1/2/5 need semantic/build knowledge unavailable to a jq/bash
  validator and are deliberately out of scope.
- No test harness references `validate-handoff.sh` today; `.claude/tests/` contains only
  `test-command-route-skill.sh`, whose `run_test()`/counter/fixture pattern is the reuse
  template. New fixtures use `mktemp` temp JSON files (validate-handoff.sh takes a file path
  and communicates via exit code + stdout).

### Prior Plan Reference

No prior plan for task 807. Task 778's plan is referenced by the research only as the schema
origin and to confirm the deliberate non-goal ("Do NOT modify validate-handoff.sh"), which is
exactly the gap task 807 now closes.

### Roadmap Alignment

No `roadmap_path` was provided and `roadmap_flag` is not set. No ROADMAP.md phases added.

## Goals & Non-Goals

**Goals**:
- When `status == "implemented"` and `skeleton == true`: accept the `skeleton` field, require a
  non-empty `sorry_inventory`, and enumerate every entry.
- Enforce per strategic entry (`strategic: true`): non-empty `assumption`, non-empty
  `why_deferred`, non-null `follow_up_task` -- a `log_fail` on any violation (relaxed zero-debt
  stays VISIBLE via loud output and TRACKED via non-zero exit).
- Add a status/skeleton invalid-combination check: `skeleton: true` requires
  `status == "implemented"` (per wrap-up.md interaction table).
- Update `--help`/usage text to document the skeleton branch and its conditional requirements.
- Keep STANDARD-mode validation (skeleton absent/false) byte-identical to current behavior.
- Create `.claude/tests/test-validate-handoff.sh` with five fixtures matching the five
  requirement conditions.

**Non-Goals**:
- Do NOT introduce a 4th `status` enum value or otherwise modify the wrap-up.md schema
  (consumer-side validation only).
- Do NOT enforce anti-analysis.md conditions 1/2/5 (deliberate/scoped/build-green) -- not
  mechanically checkable from JSON.
- Do NOT create an `extensions/core` mirror (none exists; single-copy fix).
- Do NOT reject unknown extra top-level fields (current behavior; unchanged).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A regression silently alters STANDARD-mode output/exit codes | H | L | Skeleton logic lives entirely in the `if skeleton==true` branch; the `else` branch is the verbatim prior Check 3. Phase 3 fixture (a) asserts a legacy/skeleton-absent handoff still passes unchanged. |
| `set -euo pipefail` aborts on a malformed `sorry_inventory` entry inside per-entry `jq` var assignments | M | L | Use the existing `... 2>/dev/null` and `// "__MISSING__"` fallback idioms (same latent risk already present for other fields; not a new regression). `length` on `null` yields 0, safe with the `|| echo 0` fallback. |
| New checks break production handoffs predating task 778 (no `skeleton` field) | M | L | Absent `skeleton` -> `jq -r ".skeleton // false"` yields `false` -> `else` path -> unchanged. Fixture (a) covers this. |
| Test harness itself has bugs / false greens | M | M | Assert on exit code AND on presence/absence of specific `[FAIL]`/`[PASS]`/`[WARN]` lines; run harness in Phase 3 and confirm all five fixtures behave as designed. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel. This plan is sequential (each wave has one
phase) so a single general-implementation agent runs 1 -> 2 -> 3 in order.

### Phase 1: Make validate-handoff.sh skeleton-aware [COMPLETED]

**Goal**: Add the early `status`/`skeleton` read, branch Check 3 into strict skeleton-mode vs.
untouched standard-mode, add the status/skeleton invalid-combination check, and update `--help`.

**Tasks**:
- [x] Insert an early read block immediately after Check 1 (after line 95, before Check 2 at
      line 97):
      ```bash
      # --- Read status and skeleton early (needed for skeleton-aware Check 3 below) ---
      status=$(jq -r ".status // \"\"" "$HANDOFF_FILE" 2>/dev/null)
      skeleton=$(jq -r ".skeleton // false" "$HANDOFF_FILE" 2>/dev/null)
      ```
      *(completed)*
- [x] Replace Check 3 (current lines 108-115) with the skeleton-aware branch from the research
      report (report section "Recommendations" item 2): `if [[ "$skeleton" == "true" ]]` runs
      the strict path; the `else` branch is the verbatim prior warn/pass logic. The strict path
      MUST:
      - `log_fail` when `status != "implemented"` (invalid combination); else `log_pass`.
      - `log_fail` when `sorry_inventory` is absent or `length == 0`.
      - iterate entries; for each `strategic == true` entry, `log_fail` on empty/missing
        `assumption`, empty/missing `why_deferred`, or null/missing `follow_up_task`.
      - `log_fail` when `strategic_count == 0` (skeleton requires >=1 tracked strategic sorry).
      - `log_pass` when all strategic entries are fully tracked.
      *(completed)*
- [x] Leave the redundant `status=$(...)` re-read inside Check 4 (line 127) in place (idempotent;
      harmless) OR delete it for cleanliness -- do not change Check 4's logic either way.
      *(completed: left in place, unchanged, per plan's explicit either-way allowance)*
- [x] Update `--help` text (lines 31-45): add `skeleton` to the optional-fields listing as
      conditionally-required, and add lines documenting: "skeleton=true requires
      status=='implemented', a non-empty sorry_inventory, and every strategic:true entry must
      have non-empty assumption/why_deferred and non-null follow_up_task."
      *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/scripts/validate-handoff.sh` - insert early read after line 95; replace Check 3
  (108-115) with the skeleton-aware branch; extend `--help` (31-45).

**Verification**:
- `bash -n .claude/scripts/validate-handoff.sh` passes (syntax).
- `bash .claude/scripts/validate-handoff.sh --help` shows the new skeleton documentation lines.
- Manual smoke: run against
  `specs/772_hardmode_orchestrator_pure_dispatcher/.orchestrator-handoff.json`
  (skeleton:false, empty sorry_inventory) -> still exits 0 with the standard warn/pass output
  (no new FAIL introduced).

---

### Phase 2: Create test harness with five fixtures [COMPLETED]

**Goal**: Add `.claude/tests/test-validate-handoff.sh` modeled on
`test-command-route-skill.sh`, with five `mktemp`-based JSON fixtures mapped 1:1 to the task's
five conditions.

**Tasks**:
- [x] Read `.claude/tests/test-command-route-skill.sh` (lines 1-60) and reuse its structure:
      `set -euo pipefail`, `PASS`/`FAIL` counters, a `FAILURES` accumulator string, a
      `run_test()`-style helper, and a final summary + exit code. *(completed)*
- [x] Write a helper that creates a temp JSON handoff (`mktemp`), runs
      `bash .claude/scripts/validate-handoff.sh "$tmp"`, and asserts on BOTH the captured exit
      code AND the presence/absence of specific `[FAIL]`/`[PASS]`/`[WARN]` substrings in stdout.
      *(completed: `run_test()` also strips ANSI color codes from captured stdout via `sed`
      before substring matching, since log_pass/log_fail/log_warn wrap text in color escape
      sequences that would otherwise break literal substring assertions)*
- [x] Fixture (a) STANDARD unchanged: `status:"implemented"`, no `skeleton` field, empty
      `sorry_inventory` (or absent) -> exit 0, sorry_inventory warn/pass exactly as before, no
      skeleton-related FAIL lines. *(completed)*
- [x] Fixture (b) VALID skeleton: `status:"implemented"`, `skeleton:true`, `sorry_inventory`
      with >=1 entry having `strategic:true` + non-empty `assumption`/`why_deferred` +
      non-null `follow_up_task` -> exit 0, no FAIL. *(completed)*
- [x] Fixture (c) skeleton missing sorry_inventory: `status:"implemented"`, `skeleton:true`,
      `sorry_inventory` absent or `[]` -> exit 1, FAIL naming non-empty sorry_inventory
      requirement. *(completed)*
- [x] Fixture (d) skeleton entry missing follow_up_task: `status:"implemented"`,
      `skeleton:true`, a `strategic:true` entry with `follow_up_task: null` -> exit 1, FAIL
      naming `follow_up_task`. *(completed)*
- [x] Fixture (e) skeleton with wrong status: `skeleton:true`, `status:"partial"` -> exit 1,
      FAIL naming the invalid status/skeleton combination. *(completed)*
- [x] `chmod +x .claude/tests/test-validate-handoff.sh`. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/tests/test-validate-handoff.sh` - NEW file (create).

**Verification**:
- `bash -n .claude/tests/test-validate-handoff.sh` passes.
- File is executable and self-contained (creates/cleans up its own temp fixtures).

---

### Phase 3: Run harness and confirm standard-mode regression-free [COMPLETED]

**Goal**: Execute the harness, confirm all five fixtures behave as designed, and verify
STANDARD-mode output is unchanged against a real production handoff.

**Tasks**:
- [x] Run `bash .claude/tests/test-validate-handoff.sh`; confirm all five fixtures pass their
      assertions (exit 0 overall). *(completed: 5/5 PASS, harness exit 0)*
- [x] Regression guard: run `bash .claude/scripts/validate-handoff.sh
      specs/772_hardmode_orchestrator_pure_dispatcher/.orchestrator-handoff.json` and confirm
      exit 0 with the same warn/pass lines as before this task (no skeleton branch entered,
      no new FAIL). *(completed: exit 0, 8 pass/1 warn/0 fail; also diffed stdout against a
      `git stash`-restored pre-change copy of validate-handoff.sh run on the same file --
      byte-identical output confirmed)*
- [x] Confirm exit-code contract: skeleton-invalid fixtures exit 1 (via existing
      `FAILED>0 -> exit 1` summary logic at lines ~208-210, unchanged); valid fixtures exit 0.
      *(completed: fixtures c/d/e exit 1, fixtures a/b exit 0, all via harness assertions)*
- [x] If any fixture reveals a validator bug, fix forward in `validate-handoff.sh` (return to
      Phase 1 edits) and re-run. *(completed: no validator bug found; one test-harness bug was
      found and fixed -- see Phase 2 progress file `approaches_tried` for the ANSI-stripping fix)*

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Files to modify**:
- None (verification only; fix-forward edits land in `validate-handoff.sh` if needed).

**Verification**:
- Harness exits 0 with all five fixtures reported PASS.
- Production sample handoff still validates with unchanged standard-mode output.

## Testing & Validation

- [x] `bash -n .claude/scripts/validate-handoff.sh` and `bash -n .claude/tests/test-validate-handoff.sh` both pass.
- [x] All five harness fixtures pass (standard-unchanged, valid-skeleton, missing-inventory,
      missing-follow_up_task, wrong-status).
- [x] STANDARD-mode output byte-identical for a skeleton-absent handoff (production sample).
- [x] `--help` documents the skeleton branch requirements.
- [x] Exit codes: invalid skeleton handoffs exit 1; valid + standard handoffs exit 0.

## Artifacts & Outputs

- Modified `.claude/scripts/validate-handoff.sh` (skeleton-aware Check 3, early read, --help).
- New `.claude/tests/test-validate-handoff.sh` (five fixtures).

## Rollback/Contingency

Changes are confined to two files with no code-level consumers of `validate-handoff.sh`
(invoked ad hoc only). To revert: `git checkout .claude/scripts/validate-handoff.sh` and
`rm .claude/tests/test-validate-handoff.sh`. Because the skeleton logic is isolated in the
`if skeleton==true` branch, reverting cannot affect any standard-mode consumer. If the test
harness proves flaky but the validator is correct, the harness may be committed separately or
deferred without blocking the validator fix (harness is optional per task framing).

# Implementation Plan: Task #845

- **Task**: 845 - Restore the `--hard`/`routing_hard` 5-step precedence in `command-route-skill.sh`
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/845_implement_routing_hard_precedence_in_router/reports/01_routing-hard-precedence.md
- **Artifacts**: plans/01_routing-hard-precedence.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`command-route-skill.sh` regressed to a 3-argument, Steps-1-3-only implementation that never reads
the 4th `effort_flag` argument or any `.routing_hard` manifest key, so `--hard` routing is silently
broken (live test: 6 PASS / 8 FAIL). Research confirmed this is a REGRESSION: task #768 (commit
`574bf515a`) fully implemented and tested the 5-step precedence (12/12 passing at the time), but the
fix landed only in the deployed `.claude/scripts/` copy; the extension-source copy was never
updated, and a later blanket extension sync (commit `40210f576`) reverted the deployed copy back to
the stale 3-arg version. The fix is a **restoration**, not a redesign: recover the known-good Step
4/5 block from git, apply it to the extension-source copy FIRST (per task #841's byte-identity drift
guard and CLAUDE.md's "extensions own their scripts" rule), then byte-sync it to the deployed copy.
Definition of done: `bash .claude/tests/test-command-route-skill.sh` fully passes (exit 0), the two
script copies are byte-identical (`cmp -s`), and `check-extension-docs.sh` still exits 0.

### Research Integration

Key findings from `reports/01_routing-hard-precedence.md`:
- The exact working implementation is recoverable via `git show 574bf515a:.claude/scripts/command-route-skill.sh`; it already makes every current test assertion pass because the 14-assertion test file was created in the same commit against this exact code.
- Manifest `routing_hard` data (core/cslib/lean) is **already complete and correct** — no manifest change is needed; only the script logic that reads it was lost.
- The test file lives at `.claude/tests/test-command-route-skill.sh` (177 lines), NOT the `.claude/scripts/...` path named in the original task description. It is deployed-only (not in `core`'s `provides.scripts`), so no drift guard applies to it and it needs no edit.
- The Step 5 `-hard` append fallback with the on-disk `SKILL.md` existence gate (and its `[route] No hard variant for ${SKILL_NAME}; using standard skill` stderr message) is part of the block to restore and is asserted by tests 10b/11b.
- Current baseline is a "both wrong together" green: `cmp -s` passes because both copies lack Step 4/5. The fix must preserve byte-identity while making both copies correct.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (roadmap flag not set). This is a bug-fix restoration of a documented, previously-shipped behavior.

## Goals & Non-Goals

**Goals**:
- Restore the 5-step `--hard`/`routing_hard` precedence (Steps 4a-4e including the Step 5 SKILL.md-existence safety gate) into the extension-source copy `.claude/extensions/core/scripts/command-route-skill.sh`.
- Byte-sync the restored script to the deployed copy `.claude/scripts/command-route-skill.sh` so the two are `cmp -s` identical.
- Achieve a fully-passing `bash .claude/tests/test-command-route-skill.sh` (was 6/14; must reach full pass, exit 0).
- Preserve the existing green state of `bash .claude/scripts/check-extension-docs.sh` (exit 0, all extensions PASS).

**Non-Goals**:
- No manifest changes — `routing_hard` data is already complete and correct.
- No edits to `.claude/tests/test-command-route-skill.sh` (correct as-is; source of truth for assertions).
- No edits to CLAUDE.md, its merge-source, or `.claude/context/guides/hard-mode-routing.md` (documentation already matches the target design).
- No caller-wiring fixes to `commands/{research,plan,implement}.md` (a separate, out-of-scope regression flagged in research for a follow-up task).
- No update to `check-extension-docs.sh`'s now-stale rationale comment (comment-accuracy nit; separate follow-up).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Re-patching only the deployed copy recreates the exact regression on next extension reload | H | M | Patch extension-source FIRST (Phase 1), then copy to deployed (Phase 2); verify `cmp -s` before declaring done |
| Copies drift (not byte-identical) after edit | M | M | Use `cp` from source to deployed rather than re-typing; confirm with `cmp -s` / `diff -q` in Phase 3 |
| Restored block diverges from test expectations | M | L | Restore verbatim from commit `574bf515a`; the current test file was authored against this exact code |
| Following the task description's wrong test path creates a stray misplaced test file | L | L | Use the correct path `.claude/tests/test-command-route-skill.sh`; do not create any new test file |
| `check-extension-docs.sh` regresses due to the change | M | L | Run it in Phase 3 and confirm exit 0; the script IS in `core`'s `provides.scripts`, so byte-identity is enforced — Phase 2 satisfies it |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Restore Step 4/5 block into the extension-source copy [COMPLETED]

**Goal**: Recover the known-good 5-step implementation from git and write it to the extension-source copy (the source of truth), leaving Steps 1-3 unchanged in behavior.

**Tasks**:
- [ ] Recover the working implementation: `git show 574bf515a:.claude/scripts/command-route-skill.sh` (this is the full target file contents, not a partial diff).
- [ ] Overwrite `.claude/extensions/core/scripts/command-route-skill.sh` with the recovered contents. The recovered file adds, relative to the current version:
  - `_effort_flag="${4:-}"` 4th positional argument capture.
  - The `# Step 4: Hard-mode resolution (only when effort_flag="hard")` block with sub-steps 4a (non-core exact), 4b (non-core compound-key/base-type), 4c (core exact, core identified by `routing_exempt == true`), 4d (core compound-key), and 4e (`-hard` append fallback gated on `.claude/skills/${candidate}-hard/SKILL.md` existing, else the `[route] No hard variant for ${SKILL_NAME}; using standard skill` stderr note with `SKILL_NAME` unchanged).
  - The extended `unset` line clearing the new locals: `_effort_flag _hard_skill _ext_hard _candidate_hard _base_type_hard _core_manifest _is_core`.
  - The updated header comment documenting the 4th parameter and hard-mode edge cases.
- [ ] Confirm the file preserves source semantics: it is sourced (never executed), and the hard-mode path NEVER calls `exit` — a faulty resolution at worst leaves `SKILL_NAME` at the standard skill.
- [ ] Confirm the Step 5 SKILL.md-existence safety gate is present exactly as: `if [ -f ".claude/skills/${_candidate_hard}/SKILL.md" ]; then SKILL_NAME="$_candidate_hard"; else echo "[route] No hard variant for ${SKILL_NAME}; using standard skill" >&2; fi`.

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/scripts/command-route-skill.sh` — replace the 3-arg Steps-1-3 body with the recovered 5-step (Steps 1-4e) implementation.

**Verification**:
- `bash -n .claude/extensions/core/scripts/command-route-skill.sh` reports no syntax errors.
- `grep -q '_effort_flag="\${4:-}"' .claude/extensions/core/scripts/command-route-skill.sh` succeeds.
- `grep -q 'No hard variant for' .claude/extensions/core/scripts/command-route-skill.sh` succeeds.
- `grep -q 'routing_exempt' .claude/extensions/core/scripts/command-route-skill.sh` succeeds (core-manifest identification present).

---

### Phase 2: Byte-sync the restored script to the deployed copy [COMPLETED]

**Goal**: Make the deployed copy byte-identical to the corrected extension-source copy, satisfying task #841's drift guard and reversing task #768's original deployed-only mistake.

**Tasks**:
- [ ] Copy source to deployed: `cp .claude/extensions/core/scripts/command-route-skill.sh .claude/scripts/command-route-skill.sh` (copy, do not hand-edit, to guarantee byte-identity).
- [ ] Preserve executable bit if applicable (the copy target already exists; `cp` retains the destination's contents replacement only — verify the file remains readable/sourceable).

**Timing**: 5 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/command-route-skill.sh` — overwrite with the byte-identical extension-source copy.

**Verification**:
- `cmp -s .claude/scripts/command-route-skill.sh .claude/extensions/core/scripts/command-route-skill.sh && echo IDENTICAL` prints `IDENTICAL`.
- `diff -q .claude/scripts/command-route-skill.sh .claude/extensions/core/scripts/command-route-skill.sh` reports no differences (exit 0).
- `bash -n .claude/scripts/command-route-skill.sh` reports no syntax errors.

---

### Phase 3: Verify test suite, byte-identity, and doc-lint [COMPLETED]

**Goal**: Confirm the restoration achieves a fully-passing routing test suite while preserving the green `check-extension-docs.sh` baseline and the byte-identity invariant.

**Tasks**:
- [ ] Run `bash .claude/tests/test-command-route-skill.sh`; confirm it now fully passes (was 6/14). Expect all previously-failing hard-mode cases (5, 6, 7, 8, 9, 10b, 11b, 12) to PASS and exit code 0.
- [ ] If any assertion still fails, diff the restored script against `git show 574bf515a:.claude/scripts/command-route-skill.sh` to locate the divergence and correct the extension-source copy, then re-run Phase 2's `cp` and re-test (do not edit the deployed copy directly).
- [ ] Re-confirm byte-identity: `cmp -s` / `diff -q` between the two copies still passes after any correction.
- [ ] Run `bash .claude/scripts/check-extension-docs.sh`; confirm exit 0 with all extensions PASS (pay attention to the `[core]` and `[cslib]` sections whose `routing_hard` blocks are now live-dispatched). The lean extension's undeployed hard targets remaining WARN is expected/acceptable (extension not installed).

**Timing**: 15 minutes

**Depends on**: 2

**Files to modify**:
- None (verification only; corrective loops route back through Phase 1/2 on the extension-source copy).

**Verification**:
- `bash .claude/tests/test-command-route-skill.sh; echo "exit=$?"` prints `exit=0` with a full-pass summary.
- `cmp -s .claude/scripts/command-route-skill.sh .claude/extensions/core/scripts/command-route-skill.sh` exits 0.
- `bash .claude/scripts/check-extension-docs.sh; echo "exit=$?"` prints `exit=0`.

## Testing & Validation

- [ ] `bash .claude/tests/test-command-route-skill.sh` passes fully (exit 0); no remaining FAIL lines (baseline was 6 PASS / 8 FAIL).
- [ ] Test cases 5-9 and 12 resolve to the correct `-hard` skills (`skill-implementer-hard`, `skill-planner-hard`, `skill-researcher-hard`, `skill-cslib-research-hard`, `skill-cslib-implementation-hard`).
- [ ] Test cases 10b/11b emit the exact stderr `[route] No hard variant for <skill>; using standard skill` for neovim/nix (no deployed hard variant).
- [ ] `diff -q` / `cmp -s` confirms the deployed and extension-source copies are byte-identical.
- [ ] `bash .claude/scripts/check-extension-docs.sh` remains exit 0, all extensions PASS.
- [ ] `bash -n` on both copies reports no syntax errors.

## Artifacts & Outputs

- `.claude/extensions/core/scripts/command-route-skill.sh` (restored 5-step implementation; source of truth)
- `.claude/scripts/command-route-skill.sh` (byte-identical deployed copy)
- `specs/845_implement_routing_hard_precedence_in_router/plans/01_routing-hard-precedence.md` (this plan)
- `specs/845_implement_routing_hard_precedence_in_router/summaries/01_routing-hard-precedence-summary.md` (produced at /implement)

## Rollback/Contingency

The change is confined to two copies of a single script and is a restoration of previously-shipped
code. To revert: `git checkout .claude/scripts/command-route-skill.sh .claude/extensions/core/scripts/command-route-skill.sh`
returns both copies to the current (regressed but byte-identical) state, restoring the pre-fix green
`check-extension-docs.sh` baseline. Because no manifests, tests, or docs are touched, no other
artifact needs reverting. If the test suite reveals an unexpected divergence from the historical
implementation that cannot be reconciled by re-copying from `574bf515a`, mark the task [PARTIAL] with
the failing assertion recorded and do not push a half-synced state (both copies must always end
byte-identical).

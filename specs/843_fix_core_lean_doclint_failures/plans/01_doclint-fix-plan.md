# Implementation Plan: Restore core and lean doc-lint sections to PASS

- **Task**: 843 - Restore the `core` and `lean` sections of `check-extension-docs.sh` to PASS
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/843_fix_core_lean_doclint_failures/reports/01_doclint-diagnosis.md
- **Artifacts**: plans/01_doclint-fix-plan.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`bash .claude/scripts/check-extension-docs.sh` currently exits non-zero on 4 FAILs (2 `core`,
2 `lean`), which blunts the value of the literature drift guard (Rule F) that task #841 added to
this same script. Research (`reports/01_doclint-diagnosis.md`) re-verified the true failure set
and diagnosed three distinct fix types, not the single "manifest-only" framing the task
description assumed. This plan fixes all four failures so the check exits 0 with every section
PASS, while preserving byte-identity between deployed `.claude/scripts/` copies and their
`.claude/extensions/*/` sources (the #841 Rule F drift guard) and changing no script's runtime
behavior other than one WARN-vs-FAIL classification in the lint script itself.

**Definition of done**: `bash .claude/scripts/check-extension-docs.sh` exits 0, all sections
(core, lean, literature, and every other) PASS, the two lean `-hard` routing_hard targets now
emit WARN (not FAIL), and Rule F reports no deployed-vs-source drift for any touched script.

### Research Integration

The plan is built directly around the research verdict:
- **core / `task-lock.sh`**: pure manifest fix. Source (`.claude/extensions/core/scripts/task-lock.sh`)
  already exists and is byte-identical to the deployed copy; it was simply never registered.
  Fix = add `"task-lock.sh"` to core `provides.scripts`.
- **core / `orchestrator-postflight.sh`**: deployed-only (never placed in extension source; same
  bug class as task #793's `lifecycle-notify.sh` fix). Fix = copy the deployed file byte-identically
  into `.claude/extensions/core/scripts/orchestrator-postflight.sh` FIRST, then register it in core
  `provides.scripts`. A manifest-only edit would trip a NEW "manifest script entry missing on disk"
  FAIL — so the backport-to-source must precede/accompany the manifest edit.
- **lean / both `-hard` routing_hard FAILs**: accidental regression, not a design decision. Task
  #771 deliberately downgraded these to WARN (sound reasoning: `command-route-skill.sh` does not
  implement `routing_hard` dispatch at all, so the "unconditional dispatch" rationale is false),
  but #771 edited only the deployed copy; task #792's sync then reverted it from the stale
  extension-source copy. Fix = restore the WARN classification in BOTH copies of
  `check-extension-docs.sh`, byte-identically.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this run (meta task; no roadmap flag).

## Goals & Non-Goals

**Goals**:
- `bash .claude/scripts/check-extension-docs.sh` exits 0 with all sections PASS.
- Register `task-lock.sh` and `orchestrator-postflight.sh` in core `provides.scripts`, backporting
  `orchestrator-postflight.sh` into extension source first (byte-identical `cp`, not a hand-edit).
- Restore the lean routing_hard uninstalled-branch classification from FAIL to WARN in BOTH copies
  of `check-extension-docs.sh`, keeping the two copies byte-identical.
- Preserve the #841 Rule F drift guard: deployed == source for every touched script.

**Non-Goals**:
- Do NOT touch the `literature` section or any literature artifact — tasks #841/#842 own it; it
  currently PASSes and must stay PASS.
- Do NOT alter the runtime behavior of any script other than the intended WARN-vs-FAIL
  classification change inside `check-extension-docs.sh`.
- Do NOT deploy the `lean` extension or half-install its `-hard` skills (research rejected this:
  lean is not installed, and a partial install would trip other lint checks).
- Do NOT remove or weaken the lean `routing_hard` manifest declarations (they are fully-built,
  source-grounded capabilities; removing them would paper over a real capability).
- **Out of scope (record only, do NOT fix here)**: `command-route-skill.sh` does not implement the
  `--hard`/`routing_hard` 5-step precedence that CLAUDE.md documents (it takes 3 positional args and
  never reads `.routing_hard`). This documentation/implementation drift is a separate potential
  follow-up, not part of this doc-lint cleanup. It is noted here so it is not silently absorbed.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Backporting `orchestrator-postflight.sh` captures an already-drifted deployed copy as new source-of-truth | M | L | Use `cp` from the live deployed file (the sole in-use version; no separate "correct" version exists), then `diff` to confirm byte-identity; do not hand-edit. Matches #793's precedent for its two siblings. |
| Manifest-only edit for `orchestrator-postflight.sh` trips a NEW "missing on disk" FAIL | M | M | Sequence the source `cp` BEFORE (or in the same phase as, and verified before re-running the check) the manifest registration. Phase 1 does both. |
| Editing only one copy of `check-extension-docs.sh` re-introduces #792-style drift | H | M | Apply the identical WARN edit to BOTH `.claude/scripts/check-extension-docs.sh` and `.claude/extensions/core/scripts/check-extension-docs.sh`; verify with `diff -q` (must report identical). `check-extension-docs.sh` is itself a core `provides.scripts` entry, so Rule F polices this. |
| Accidental behavior change while editing the lint script | M | L | Change only the final `else` branch (lines ~299-303): `fail` -> `warn` plus an updated comment. Touch no other logic; the `installed -eq 1` branch (line 297) stays FAIL. |
| Literature section regresses as a side effect | H | L | Do not touch any literature file; verification explicitly re-checks that the literature section still PASSes and Rule F still passes. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch disjoint files
(Phase 1: `core/manifest.json` + new `core/scripts/orchestrator-postflight.sh`; Phase 2: both
copies of `check-extension-docs.sh`) and have no ordering dependency between them.

### Phase 1: Core script backport and manifest registration [COMPLETED]

**Goal**: Register both undeclared core scripts in `core` `provides.scripts`, backporting
`orchestrator-postflight.sh` into extension source first so the manifest entry has a matching
on-disk source file.

**Tasks**:
- [x] `cp .claude/scripts/orchestrator-postflight.sh .claude/extensions/core/scripts/orchestrator-postflight.sh`
      (byte-identical copy; do NOT hand-edit the content). *(completed)*
- [x] Verify the copy: `diff -q .claude/scripts/orchestrator-postflight.sh .claude/extensions/core/scripts/orchestrator-postflight.sh` reports no difference; preserve the executable bit (`chmod +x` the source copy if needed to match the deployed mode). *(completed: both 755, diff -q identical)*
- [x] Add `"task-lock.sh"` to `provides.scripts` in `.claude/extensions/core/manifest.json`
      (source and deployed copies already match byte-for-byte, so no file copy is needed for this one). *(completed)*
- [x] Add `"orchestrator-postflight.sh"` to `provides.scripts` in `.claude/extensions/core/manifest.json`. *(completed)*
- [x] Confirm the manifest remains valid JSON: `jq empty .claude/extensions/core/manifest.json`. *(completed: valid)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/scripts/orchestrator-postflight.sh` - NEW file, byte-identical copy of the deployed script (source-of-truth backport).
- `.claude/extensions/core/manifest.json` - add `"task-lock.sh"` and `"orchestrator-postflight.sh"` to `provides.scripts`.

**Verification**:
- `jq -r '.provides.scripts[]' .claude/extensions/core/manifest.json | grep -E "task-lock.sh|orchestrator-postflight.sh"` shows both entries.
- `diff -q .claude/extensions/core/scripts/orchestrator-postflight.sh .claude/scripts/orchestrator-postflight.sh` reports identical.
- The two prior core FAILs no longer appear when the check is re-run (full re-run happens in Phase 3).

---

### Phase 2: Restore lean routing_hard WARN classification (both copies) [COMPLETED]

**Goal**: Restore task #771's deliberate WARN-when-uninstalled classification for undeployed
`routing_hard` targets in the uninstalled-extension branch, applied identically to both the
deployed and extension-source copies of `check-extension-docs.sh`.

**Tasks**:
- [x] In `.claude/scripts/check-extension-docs.sh`, in `check_routing_consistency`'s routing_hard
      loop, change the final `else` branch (currently ~lines 299-303) from `fail "routing_hard
      target declared but not deployed (and extension not installed): $t"` to a `warn "..."` call,
      and update the preceding comment to reflect #771's reasoning (uninstalled extension with
      undeployed routing_hard targets is the expected state, not a live correctness bug;
      `command-route-skill.sh` does not implement routing_hard dispatch, so no unconditional
      dispatch occurs). Leave the `installed -eq 1` branch (line ~297) as FAIL and the
      not-resolvable branch (line ~294) as FAIL unchanged. *(completed; used `info "WARN: ..."` to match the existing WARN-emission convention used by the parallel `routing` uninstalled branch a few lines above)*
- [x] Apply the byte-identical edit to `.claude/extensions/core/scripts/check-extension-docs.sh`. *(completed via `cp` of the fully-edited deployed file, since no other content differed)*
- [x] Verify byte-identity: `diff -q .claude/scripts/check-extension-docs.sh .claude/extensions/core/scripts/check-extension-docs.sh` reports no difference. *(completed: identical)*
- [x] Confirm the script still parses: `bash -n .claude/scripts/check-extension-docs.sh`. *(completed: syntax OK, both copies)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/check-extension-docs.sh` - final `else` branch of the routing_hard loop: `fail` -> `warn` + comment update.
- `.claude/extensions/core/scripts/check-extension-docs.sh` - identical edit (keep byte-identical per Rule F).

**Verification**:
- `diff -q` between the two copies reports identical.
- `bash -n` on the deployed copy succeeds (no syntax error).
- On a full re-run (Phase 3), the two lean `-hard` targets appear as WARN, not FAIL.

---

### Phase 3: Full verification [NOT STARTED]

**Goal**: Prove all four failures are resolved, no regression was introduced, and the drift
guard is intact.

**Tasks**:
- [ ] Run `bash .claude/scripts/check-extension-docs.sh; echo "exit=$?"` — must print `exit=0`.
- [ ] Confirm the summary reports 0 FAILs and all sections (core, lean, literature, every other) PASS.
- [ ] Confirm the two lean targets (`skill-lean-research-hard`, `skill-lean-implementation-hard`)
      now appear as WARN, not FAIL.
- [ ] Confirm the literature section still PASSes (no regression) and Rule F reports no drift.
- [ ] Confirm drift guard byte-identity for every touched script:
      `diff -q .claude/scripts/check-extension-docs.sh .claude/extensions/core/scripts/check-extension-docs.sh`,
      `diff -q .claude/scripts/orchestrator-postflight.sh .claude/extensions/core/scripts/orchestrator-postflight.sh`,
      `diff -q .claude/scripts/task-lock.sh .claude/extensions/core/scripts/task-lock.sh` — all report identical.

**Timing**: 30 minutes

**Depends on**: 1, 2

**Files to modify**: none (verification only).

**Verification**:
- `check-extension-docs.sh` exits 0 with all sections PASS.
- All three `diff -q` drift checks report identical.
- No literature-section regression; the two lean `-hard` targets show WARN.

## Testing & Validation

- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0.
- [ ] Summary line reports 0 FAILs; core, lean, literature, and every other section PASS.
- [ ] `skill-lean-research-hard` and `skill-lean-implementation-hard` emit WARN (not FAIL).
- [ ] `diff -q` deployed-vs-source is identical for `check-extension-docs.sh`, `orchestrator-postflight.sh`, and `task-lock.sh` (Rule F intact).
- [ ] `jq empty .claude/extensions/core/manifest.json` succeeds (valid JSON).
- [ ] No literature file was modified (`git status` shows no changes under `specs/literature/` or literature extension paths).

## Artifacts & Outputs

- `.claude/extensions/core/scripts/orchestrator-postflight.sh` (new, byte-identical backport)
- `.claude/extensions/core/manifest.json` (two new `provides.scripts` entries)
- `.claude/scripts/check-extension-docs.sh` (routing_hard else-branch FAIL -> WARN)
- `.claude/extensions/core/scripts/check-extension-docs.sh` (identical edit)
- `specs/843_fix_core_lean_doclint_failures/summaries/01_doclint-fix-summary.md` (on implementation)

## Rollback/Contingency

All changes are confined to three source files plus one new backported file. To revert:
`git checkout -- .claude/extensions/core/manifest.json .claude/scripts/check-extension-docs.sh
.claude/extensions/core/scripts/check-extension-docs.sh` and `git rm
.claude/extensions/core/scripts/orchestrator-postflight.sh` (the backported copy). Because no
runtime script logic changes (only the lint script's severity classification and manifest
registration), rollback carries no behavioral risk. If the check still fails after Phase 3,
re-run it and read the per-section output to determine whether a new "missing on disk" FAIL
appeared (indicates the Phase 1 source `cp` was skipped) or the two copies drifted (indicates a
non-identical Phase 2 edit).

# Implementation Plan: Task #651

- **Task**: 651 - Update rules and documentation for new state.json-first architecture
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: Tasks 649, 653 (state.json-first migration scripts)
- **Research Inputs**: specs/651_update_rules_and_documentation/reports/01_docs-update-research.md
- **Artifacts**: plans/01_docs-rules-update.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Update 14 files across rules, skills, context, and architecture docs to consistently describe the new state.json-first update flow. The old dual-write pattern (jq to state.json + Edit tool to TODO.md) has been replaced by a single-source pipeline: update state.json, then call `generate-todo.sh` to regenerate TODO.md. This plan removes all obsolete Edit-TODO.md instructions, artifact-linking-todo.md references, sed-based TODO.md manipulation, and "two-phase commit" language from the codebase.

### Research Integration

The research report (B1-B16) identified 14 active files needing updates across 4 priority tiers. Key findings:
- 7 already-correct files were verified (Category A) and excluded from scope
- The extension copy of `archive-task.sh` still uses Python-based TODO.md entry removal (B14)
- `skill-status-sync` has 3 separate Edit-TODO.md operations (K1-K3)
- `skill-todo` has both Edit-based entry removal (K17-K18) and sed-based vault renumbering (K19-K20)
- Architecture docs reference "two-phase commit" semantics that no longer apply

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Remove all Edit-TODO.md instructions from skills and rules
- Remove all `artifact-linking-todo.md` references from extension skills
- Replace sed-based TODO.md manipulation with `generate-todo.sh` calls
- Update the extension copy of `archive-task.sh` to match the main copy
- Update architecture docs to describe the state-first pipeline
- Achieve zero `grep` hits for "Edit.*TODO" and "link-artifact-todo" patterns

**Non-Goals**:
- Changing any script behavior (scripts are already updated)
- Modifying the `generate-todo.sh` or `update-task-status.sh` scripts
- Rewriting the preflight/postflight concept (the two-phase preflight/postflight flow is still valid; only the dual-file-write semantics are obsolete)
- Creating a new `state-first-architecture.md` context file (deferred to future task)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Extension copies drift from main copies | M | M | Sync extension copies immediately after updating main files in same phase |
| skill-todo vault renumber removal breaks vault workflow | H | L | Replace sed blocks with single generate-todo.sh call after all state.json renumbering completes |
| Breaking context index references by renaming sections | M | L | Keep section headings stable; rewrite content only |
| Missing an Edit-TODO.md reference | M | M | Phase 5 validation grep catches any stragglers |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |

Phases are sequential because later phases may reference patterns established in earlier phases, and the validation phase must run after all edits are complete.

### Phase 1: Fix Extension archive-task.sh [COMPLETED]

**Goal**: Sync the extension copy of `archive-task.sh` with the already-updated main copy, replacing Python-based TODO.md entry removal with `generate-todo.sh`.

**Tasks**:
- [ ] Read `.claude/scripts/archive-task.sh` (main, already updated) to identify the correct "Section C" pattern
- [ ] Read `.claude/extensions/core/scripts/archive-task.sh` (extension copy, outdated)
- [ ] Replace the Python-based TODO.md removal block (lines ~110-154) with the `generate-todo.sh` call pattern from the main copy
- [ ] Verify the extension copy's Section C now matches the main copy's approach

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/scripts/archive-task.sh` - Replace Python TODO.md removal with generate-todo.sh call

**Verification**:
- `grep -c "python3" .claude/extensions/core/scripts/archive-task.sh` returns 0
- `grep -c "generate-todo" .claude/extensions/core/scripts/archive-task.sh` returns >= 1

---

### Phase 2: Update Skill Files [COMPLETED]

**Goal**: Remove all Edit-TODO.md instructions, artifact-linking-todo.md references, and sed-based TODO.md manipulation from 7 skill SKILL.md files.

**Tasks**:
- [ ] **skill-status-sync/SKILL.md** (K1-K3):
  - K1 (lines ~106-108): Replace Edit-based preflight TODO.md status update with `update-task-status.sh preflight` call description
  - K2 (lines ~155-159): Replace Edit-based postflight TODO.md status + artifact links with `update-task-status.sh postflight` + `generate-todo.sh` description
  - K3 (lines ~181-213): Replace Edit-based artifact_link operation with state.json update + `generate-todo.sh` call
  - Remove `Edit` from allowed-tools list (line ~4) if it is no longer needed for any operation
- [ ] **skill-nix-implementation/SKILL.md** (K4-K5):
  - K4 (line ~44): Remove the "Use Edit tool to change status marker" preflight instruction (script already handles this)
  - K5 (line ~267): Replace artifact-linking-todo.md Edit pattern with state.json artifact update + `generate-todo.sh` call
- [ ] **skill-neovim-implementation/SKILL.md** (K6-K7):
  - K6 (line ~251): Replace artifact-linking-todo.md Edit pattern with state.json artifact update + `generate-todo.sh` call
  - K7 (line ~319): Update MUST NOT list to replace "Updating TODO.md status marker via Edit" with "Calling generate-todo.sh to regenerate TODO.md"
- [ ] **skill-nix-research/SKILL.md** (K8):
  - Stage 8 (line ~180): Replace artifact-linking-todo.md Edit pattern with state.json update + `generate-todo.sh` call
- [ ] **skill-neovim-research/SKILL.md** (K9):
  - Stage 8 (line ~180): Replace artifact-linking-todo.md Edit pattern with state.json update + `generate-todo.sh` call
- [ ] **skill-reviser/SKILL.md** (K10):
  - Stage 7 description update path (lines ~317-319): Replace "Edit tool to update description in TODO.md" with "call `generate-todo.sh` after updating description in state.json"
- [ ] **skill-todo/SKILL.md** (K17-K20):
  - K17-K18 (lines ~316-334): Remove Edit-based TODO.md entry removal in Stage 10; replace with note that `archive-task.sh` handles TODO.md regeneration via `generate-todo.sh`
  - K19-K20 (lines ~618-698): Remove sed-based TODO.md renumbering in vault sub-steps 9.3-9.4; replace with single `generate-todo.sh` call after all state.json renumbering is complete

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-status-sync/SKILL.md` - Remove K1-K3 Edit-TODO.md operations
- `.claude/skills/skill-nix-implementation/SKILL.md` - Remove K4-K5 Edit instructions
- `.claude/skills/skill-neovim-implementation/SKILL.md` - Remove K6-K7 Edit instructions
- `.claude/skills/skill-nix-research/SKILL.md` - Remove K8 Edit instruction
- `.claude/skills/skill-neovim-research/SKILL.md` - Remove K9 Edit instruction
- `.claude/skills/skill-reviser/SKILL.md` - Remove K10 Edit instruction
- `.claude/skills/skill-todo/SKILL.md` - Remove K17-K20 Edit/sed instructions

**Verification**:
- `grep -rn "artifact-linking-todo" .claude/skills/` returns 0 hits
- `grep -rn "Edit.*TODO\.md" .claude/skills/` returns 0 hits
- `grep -rn "sed.*TODO\.md" .claude/skills/skill-todo/` returns 0 hits

---

### Phase 3: Update Rules and Context Workflows [COMPLETED]

**Goal**: Update state-management rules and preflight-postflight workflow docs to describe the state-first pipeline.

**Tasks**:
- [ ] **rules/state-management.md** (B1):
  - Remove "Two-Phase Update Pattern" section (lines ~47-66)
  - Replace with "State-First Update Pattern" section describing: write state.json via jq, call `generate-todo.sh` to regenerate TODO.md, agents must not Edit TODO.md directly
  - Clarify lines ~8-9 "File Synchronization" intro to say agents update state.json only; `generate-todo.sh` handles TODO.md synchronization
- [ ] **extensions/core/rules/state-management.md** (B2):
  - Apply identical changes as B1 to the extension copy (lines ~42-61)
- [ ] **context/workflows/preflight-postflight.md** (B15):
  - Update pattern section (lines ~57-108) to use `update-task-status.sh` script calls instead of `status-sync-manager` delegation
  - Remove references to verifying `files_updated includes TODO.md` (lines ~208, 219-220, 228)
  - Update artifact linking description (line ~290) to say "update state.json artifacts array, then call generate-todo.sh"
- [ ] **.claude/CLAUDE.md** (B16):
  - Update "State Synchronization" section: change "TODO.md and state.json must stay synchronized. Update state.json first (machine state), then TODO.md (user-facing)." to "TODO.md is generated from state.json. Update state.json first, then call `bash .claude/scripts/generate-todo.sh` to regenerate TODO.md."

**Timing**: 45 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/rules/state-management.md` - Replace Two-Phase Update Pattern with State-First Update Pattern
- `.claude/extensions/core/rules/state-management.md` - Sync with main copy
- `.claude/context/workflows/preflight-postflight.md` - Update status-sync-manager references
- `.claude/CLAUDE.md` - Update State Synchronization section phrasing

**Verification**:
- `grep -c "Two-Phase Update Pattern" .claude/rules/state-management.md` returns 0
- `grep -c "Two-Phase Update Pattern" .claude/extensions/core/rules/state-management.md` returns 0
- `grep -c "status-sync-manager" .claude/context/workflows/preflight-postflight.md` returns 0
- `grep -c "then TODO.md (user-facing)" .claude/CLAUDE.md` returns 0

---

### Phase 4: Update Architecture Documentation [COMPLETED]

**Goal**: Update command-lifecycle and system-overview docs to replace "two-phase commit" and dual-write language with state-first pipeline descriptions.

**Tasks**:
- [ ] **context/workflows/command-lifecycle.md** (B3):
  - Rewrite "Two-Phase Status Update Pattern" section (lines ~54-178) to "State-First Status Update Pattern" describing: update state.json via jq, call `update-task-status.sh` which calls `generate-todo.sh`
  - Update "Implementation Details" (lines ~182-251): remove `status-sync-manager` references and `files_updated includes ["TODO.md", "state.json"]` validation
  - Update "Atomic Updates" for `/task` command (lines ~301-313): remove "Edit tool" for TODO.md writes
  - Update line ~447: change "two-phase status updates" to "state-first status updates"
  - Keep the preflight/postflight distinction intact; only update the dual-file-write mechanics
- [ ] **extensions/core/context/workflows/command-lifecycle.md** (B4):
  - Apply identical changes as B3 to the extension copy
- [ ] **docs/architecture/system-overview.md** (B5):
  - Update lines ~251-254: change "Write TODO.md second" to "Regenerate TODO.md via generate-todo.sh" and remove step 3 (rollback both)
- [ ] **extensions/core/docs/architecture/system-overview.md** (B6):
  - Apply identical changes as B5 to the extension copy

**Timing**: 30 minutes

**Depends on**: 3

**Files to modify**:
- `.claude/context/workflows/command-lifecycle.md` - Rewrite two-phase sections to state-first
- `.claude/extensions/core/context/workflows/command-lifecycle.md` - Sync with main copy
- `.claude/docs/architecture/system-overview.md` - Update two-phase commit language
- `.claude/extensions/core/docs/architecture/system-overview.md` - Sync with main copy

**Verification**:
- `grep -c "two-phase commit" .claude/docs/architecture/system-overview.md` returns 0
- `grep -c "two-phase commit" .claude/extensions/core/docs/architecture/system-overview.md` returns 0
- `grep -c "status-sync-manager" .claude/context/workflows/command-lifecycle.md` returns 0

---

### Phase 5: Validation Sweep [COMPLETED]

**Goal**: Verify all obsolete patterns have been removed and consistent state-first messaging is in place across the entire `.claude/` tree.

**Tasks**:
- [ ] Run `grep -rn "Edit.*TODO" .claude/` and verify zero hits in skills, rules, and context files (exclude this plan file and research report)
- [ ] Run `grep -rn "link-artifact-todo" .claude/` and verify zero hits (the pattern file itself may still exist but should not be referenced)
- [ ] Run `grep -rn "artifact-linking-todo" .claude/` and verify zero hits
- [ ] Run `grep -rn "python3.*TODO" .claude/extensions/core/scripts/` and verify zero hits
- [ ] Run `grep -rn "sed.*TODO\.md" .claude/skills/` and verify zero hits
- [ ] Run `grep -rn "status-sync-manager" .claude/context/ .claude/extensions/core/context/` and verify zero hits
- [ ] Run `grep -rn "two-phase commit" .claude/docs/ .claude/extensions/core/docs/` and verify zero hits
- [ ] Spot-check that "generate-todo.sh" appears in all 14 modified files where appropriate
- [ ] If any straggler references are found, fix them inline

**Timing**: 15 minutes

**Depends on**: 4

**Files to modify**:
- Any straggler files identified during grep sweeps (expected: none)

**Verification**:
- All grep commands above return 0 hits (excluding plan/research artifacts in specs/)
- Consistent "state.json -> generate-todo.sh" messaging confirmed

## Testing & Validation

- [ ] All 7 grep patterns in Phase 5 return 0 hits in the relevant directories
- [ ] Extension copies match their main counterparts for all updated sections
- [ ] The `.claude/CLAUDE.md` State Synchronization section accurately describes the new pipeline
- [ ] No script behavior has changed (only documentation/instructions updated)

## Artifacts & Outputs

- `specs/651_update_rules_and_documentation/plans/01_docs-rules-update.md` (this file)
- `specs/651_update_rules_and_documentation/summaries/01_docs-rules-update-summary.md` (after implementation)

## Rollback/Contingency

All changes are documentation-only edits to `.claude/` files. Rollback via `git checkout -- .claude/` for any file. No script behavior is modified, so there is no runtime risk. Individual file reverts are safe since each file's changes are self-contained.

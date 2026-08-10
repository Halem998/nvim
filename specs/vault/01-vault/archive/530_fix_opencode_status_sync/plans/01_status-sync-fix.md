# Implementation Plan: Task #530

- **Task**: 530 - fix_opencode_status_sync
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: None
- **Research Inputs**: specs/530_fix_opencode_status_sync/reports/01_status-sync-research.md
- **Artifacts**: plans/01_status-sync-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Fix the OpenCode agent system so that preflight and postflight status updates are applied consistently across state.json, TODO.md task entries, TODO.md Task Order section, and plan files. The root cause is that extension-specific skills (neovim, nix) and team skills bypass the centralized update-task-status.sh script, updating state.json manually with jq while omitting or only partially updating TODO.md. The plan systematically replaces manual jq status updates with script calls, completes empty skill stages, and adds verification.

### Research Integration

The research report identified extension skills and team skills as the primary source of desync. Core OpenCode skills are already correct. The centralized update-task-status.sh script is robust and updates all four locations atomically. skill-neovim-research postflight is literally empty. Fixing these skills is the top priority. Skill duplication across .claude/, .claude/extensions/, and .opencode/extensions/ is a secondary maintenance risk that will be noted but deferred.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly map to this task. This is a system-level reliability fix (meta task) that supports roadmap success metrics (e.g., zero stale references, time from /task to artifact).

## Goals & Non-Goals

**Goals**:
- Replace all manual jq state.json status updates in extension skills with centralized script calls.
- Complete empty postflight stages in extension research skills.
- Replace manual jq state.json status updates in team skills with centralized script calls.
- Verify all affected skills have correct preflight/postflight script calls.
- Ensure defensive command-level checks remain in place as a safety net.

**Non-Goals**:
- Refactoring or consolidating duplicated skill files across .claude/ and .opencode/ (out of scope for this fix).
- Changing the behavior of update-task-status.sh (it already works correctly).
- Fixing core OpenCode skills (they are already correct).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Multiple copies of skills to update | High | High | Audit all SKILL.md files with rg for manual jq status updates before editing; create a checklist of every file modified. |
| Wrong script path in .claude/ vs .opencode/ skills | Medium | Medium | Use the appropriate path for each skill namespace (.claude/scripts/ for .claude/skills, .opencode/scripts/ for .opencode/skills). |
| Team skills may not pass session_id correctly | Low | Low | Verify that the command-level invocations pass session_id before the fix; if not, add it. |
| Breaking skill syntax when removing jq blocks | Medium | Low | Edit carefully, preserving surrounding markdown structure; validate with a simple rg for script references afterward. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Fix Missing Postflight in skill-neovim-research [IN PROGRESS]

**Goal**: Complete the empty Stage 7 postflight status update in skill-neovim-research.

**Tasks**:
- [ ] **Task 1.1**: Read .claude/skills/skill-neovim-research/SKILL.md and locate Stage 7.
- [ ] **Task 1.2**: Read .opencode/extensions/nvim/skills/skill-neovim-research/SKILL.md and locate Stage 7.
- [ ] **Task 1.3**: Add the postflight script call to both files:
  ```bash
  bash .claude/scripts/update-task-status.sh postflight "$task_number" research "$session_id"
  ```
  (Use .opencode/scripts/ for the .opencode/ copy.)
- [ ] **Task 1.4**: Ensure any manual jq preflight in Stage 2 is also replaced with the script call.

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-neovim-research/SKILL.md` — add postflight script call
- `.opencode/extensions/nvim/skills/skill-neovim-research/SKILL.md` — add postflight script call

**Verification**:
- rg "update-task-status.sh" in both files returns matches for preflight and postflight.
- No remaining jq status update blocks in either file.

---

### Phase 2: Fix skill-neovim-implementation and skill-nix-implementation [NOT STARTED]

**Goal**: Replace manual jq preflight/postflight blocks in neovim and nix implementation skills with centralized script calls.

**Tasks**:
- [ ] **Task 2.1**: Read .claude/skills/skill-neovim-implementation/SKILL.md, locate Stage 2 preflight and Stage 7 postflight jq blocks.
- [ ] **Task 2.2**: Replace jq blocks with script calls for both preflight and postflight.
- [ ] **Task 2.3**: Read .opencode/extensions/nvim/skills/skill-neovim-implementation/SKILL.md and apply the same replacements.
- [ ] **Task 2.4**: Read .claude/skills/skill-nix-implementation/SKILL.md and locate preflight/postflight jq blocks.
- [ ] **Task 2.5**: Replace jq blocks with script calls in skill-nix-implementation.
- [ ] **Task 2.6**: Read .opencode/extensions/nix/skills/skill-nix-implementation/SKILL.md (if it exists) and apply the same replacements.

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-neovim-implementation/SKILL.md` — replace jq with script calls
- `.opencode/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` — replace jq with script calls
- `.claude/skills/skill-nix-implementation/SKILL.md` — replace jq with script calls
- `.opencode/extensions/nix/skills/skill-nix-implementation/SKILL.md` — replace jq with script calls (if exists)

**Verification**:
- rg "update-task-status.sh" in each file returns matches for preflight and postflight.
- No remaining jq status update blocks in these skill files.

---

### Phase 3: Fix Extension Research Skills (skill-nix-research) [COMPLETED]

**Goal**: Complete empty postflight stages in skill-nix-research and ensure preflight uses the script.

**Tasks**:
- [x] **Task 3.1**: Read .claude/skills/skill-nix-research/SKILL.md and locate its preflight and postflight stages.
- [x] **Task 3.2**: Replace any manual jq preflight with the script call.
- [x] **Task 3.3**: Add the postflight script call if the stage is empty or incomplete.
- [x] **Task 3.4**: Read .opencode/extensions/nix/skills/skill-nix-research/SKILL.md (if it exists) and apply the same fixes.

**Timing**: 1 hour

**Depends on**: 1, 2

**Files to modify**:
- `.claude/skills/skill-nix-research/SKILL.md` — add/replace script calls
- `.opencode/extensions/nix/skills/skill-nix-research/SKILL.md` — add/replace script calls (if exists)

**Verification**:
- rg "update-task-status.sh" in both files returns matches for preflight and postflight.
- No remaining jq status update blocks.

---

### Phase 4: Fix Team Skills [COMPLETED]

**Goal**: Replace manual jq preflight/postflight blocks in team research, plan, and implement skills with centralized script calls.

**Tasks**:
- [ ] **Task 4.1**: Read .claude/skills/skill-team-research/SKILL.md, locate preflight and postflight jq blocks.
- [ ] **Task 4.2**: Replace jq blocks with script calls in skill-team-research.
- [ ] **Task 4.3**: Read .claude/skills/skill-team-plan/SKILL.md and replace jq blocks with script calls.
- [ ] **Task 4.4**: Read .claude/skills/skill-team-implement/SKILL.md and replace jq blocks with script calls.
- [ ] **Task 4.5**: Ensure team skills reference the correct script path (.claude/scripts/ for .claude/skills).

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:
- `.claude/skills/skill-team-research/SKILL.md` — replace jq with script calls
- `.claude/skills/skill-team-plan/SKILL.md` — replace jq with script calls
- `.claude/skills/skill-team-implement/SKILL.md` — replace jq with script calls

**Verification**:
- rg "update-task-status.sh" in each file returns matches for preflight and postflight.
- No remaining jq status update blocks in these team skill files.

---

### Phase 5: Verification and Defensive Checks [IN PROGRESS]

**Goal**: Audit all affected skills to confirm fixes, and verify command-level defensive checks are still present.

**Tasks**:
- [ ] **Task 5.1**: Run a comprehensive rg across all .claude/skills/ and .opencode/extensions/*/skills/ for remaining manual jq status updates.
- [ ] **Task 5.2**: Confirm that .claude/commands/implement.md and .claude/commands/plan.md still contain their GATE OUT defensive checks.
- [ ] **Task 5.3**: If any new manual jq status updates are found, create a follow-up mini-task to fix them.
- [ ] **Task 5.4**: Document the list of all modified files for the task return metadata.

**Timing**: 0.5 hours

**Depends on**: 4

**Files to modify**:
- None (read-only verification)

**Verification**:
- No manual jq status update blocks remain in any extension or team SKILL.md.
- Command-level defensive checks are confirmed present in implement.md and plan.md.
- A summary list of all modified files is recorded.

## Testing & Validation

- [ ] After each phase, run rg to confirm update-task-status.sh is present in preflight and postflight sections.
- [ ] After all phases, run rg across all skill directories to confirm zero remaining jq status update patterns.
- [ ] Confirm that core skills (.opencode/skills/skill-{researcher,planner,implementer}) were NOT modified.

## Artifacts & Outputs

- Modified `.claude/skills/skill-neovim-research/SKILL.md`
- Modified `.claude/skills/skill-neovim-implementation/SKILL.md`
- Modified `.claude/skills/skill-nix-implementation/SKILL.md`
- Modified `.claude/skills/skill-nix-research/SKILL.md`
- Modified `.claude/skills/skill-team-research/SKILL.md`
- Modified `.claude/skills/skill-team-plan/SKILL.md`
- Modified `.claude/skills/skill-team-implement/SKILL.md`
- Modified `.opencode/extensions/nvim/skills/skill-neovim-research/SKILL.md` (if postflight was also empty)
- Modified `.opencode/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`
- Modified `.opencode/extensions/nix/skills/skill-nix-implementation/SKILL.md` (if exists)
- Modified `.opencode/extensions/nix/skills/skill-nix-research/SKILL.md` (if exists)
- Verification summary report

## Rollback/Contingency

- All changes are edits to SKILL.md markdown files. Rollback is achieved by reverting the commits via git.
- If a skill is broken by incorrect script path or syntax, restore the original file from git and re-apply the fix more carefully.
- The command-level defensive checks in implement.md and plan.md remain as a safety net even if a skill fix is incomplete.

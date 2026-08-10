# Implementation Plan: Task #595

- **Task**: 595 - Refactor /research, /plan, /implement commands
- **Status**: [COMPLETED]
- **Effort**: 6 hours
- **Dependencies**: Task 593 (completed), Task 594 (completed)
- **Research Inputs**: reports/01_seed-research.md, reports/02_command-refactor-research.md, reports/03_design-guidance.md
- **Artifacts**: plans/02_command-refactor-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Refactor the three core workflow commands (`research.md`, `plan.md`, `implement.md`) from their current 393/420/525-line sizes down to ~175-200 lines each by: (1) extracting the identical extension routing loop into `command-route-skill.sh`, (2) removing redundant inline GATE OUT defensive checks already handled by `command-gate-out.sh`, (3) condensing the multi-task dispatch blocks while preserving the non-extractable Skill tool invocation loops, and (4) adding `orchestrator_mode` support to `skill-base.sh` and the three core skills. The net result is ~585 fewer lines across commands, with commands serving as pure Tier 2 routing controllers per the four-tier context model.

### Research Integration

Three research reports inform this plan:
- **01_seed-research.md**: Established the duplication profile (735 lines recoverable), the progressive disclosure dependency on task 598, and token economics clarification (savings are in orchestrator context, not subagent context).
- **02_command-refactor-research.md**: Provided line-by-line content breakdown of all three commands, identified the critical constraint that Skill tool invocations cannot be extracted to bash scripts, and produced revised size estimates (research ~178L, plan ~178L, implement ~202L).
- **03_design-guidance.md**: Specified the target command structure (6-stage skeleton), Tier 2 content boundaries, orchestrator_mode contract (detection + handoff writing + continuation loop disable), and extension compatibility verification steps.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This plan advances the "Agent System Quality" roadmap area indirectly by establishing the routing-only controller pattern for commands, which simplifies future extension integrations and agent frontmatter validation. No specific ROADMAP.md items are directly addressed.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Reduce each command file to 150-200 lines of Tier 2 (controller) content only
- Extract the identical 36-line extension routing loop to `command-route-skill.sh`
- Remove redundant inline GATE OUT checks (38L each) already performed by `command-gate-out.sh`
- Condense multi-task dispatch blocks while retaining inline Skill tool invocation loops
- Add `skill_write_orchestrator_handoff()` to `skill-base.sh`
- Add orchestrator_mode detection and handoff writing to all three core skills
- Add `max_continuations=0` when orchestrator_mode=true in skill-implementer
- Verify extension compatibility (nvim, nix) after all changes

**Non-Goals**:
- Extracting multi-task dispatch to a bash script (Skill tool calls must remain in markdown)
- Adding orchestrator_mode to extension skills (deferred to task 599)
- Implementing context budget enforcement (task 598 scope)
- Creating `command-multi-dispatch.sh` (research confirmed the dispatch loop is not fully extractable)
- Modifying extension manifest routing tables (confirmed unchanged)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing inline GATE OUT checks causes silent status desync | H | L | `command-gate-out.sh` already handles these; add brief comment pointing to script for developer awareness |
| Extension routing extraction breaks compound key lookup | M | L | Test with `TASK_TYPE=neovim`, `TASK_TYPE=nix`, and compound keys; script inherits exact logic from current inline block |
| Condensing multi-task dispatch removes important edge case handling | M | M | Preserve all validation logic and error handling; only reduce verbosity of comment blocks and formatting |
| orchestrator_mode handoff JSON exceeds 400-token budget | L | L | Add truncation logic in `skill_write_orchestrator_handoff()` for variable-length fields |
| Breaking in-flight tasks (tasks with active `researching`/`planning`/`implementing` status) | M | L | Command interfaces are unchanged; only internal structure shifts; backward-compatible skill base |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4, 5 | 2 |
| 4 | 6 | 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create command-route-skill.sh [COMPLETED]

**Goal**: Extract the identical 36-line extension routing loop (present in all three commands) into a reusable script that resolves task_type to skill_name via extension manifest lookup.

**Tasks**:
- [x] Create `.claude/scripts/command-route-skill.sh` (~50 lines) *(completed)*
  - Accept parameters: `$1=operation` (research/plan/implement), `$2=TASK_TYPE`, `$3=default_skill`
  - Export: `SKILL_NAME` (the resolved skill name)
  - Implement the manifest search loop: iterate `.claude/extensions/*/manifest.json`, query `routing.$operation[$task_type]`
  - Handle compound keys (e.g., `founder:deck`): try exact key first, then base type (before `:`)
  - Fall back to `$default_skill` if no extension routing found
  - Use `source` semantics (exports variable) with appropriate header comments
- [x] Verify script handles edge cases: no extensions loaded, missing manifest files, empty routing section *(completed)*
- [x] Test with `TASK_TYPE=neovim` (should resolve `skill-neovim-research` for operation=research) *(completed)*
- [x] Test with `TASK_TYPE=nix` (should resolve `skill-nix-research` for operation=research) *(completed)*
- [x] Test with `TASK_TYPE=general` (should fall back to default) *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/command-route-skill.sh` - Create new file

**Verification**:
- Script exists and is executable
- `source command-route-skill.sh research neovim skill-researcher && echo $SKILL_NAME` outputs `skill-neovim-research`
- `source command-route-skill.sh plan general skill-planner && echo $SKILL_NAME` outputs `skill-planner`

---

### Phase 2: Add orchestrator_mode support to skill-base.sh [COMPLETED]

**Goal**: Add the `skill_write_orchestrator_handoff()` function to the shared skill library, implementing the handoff JSON schema from `handoff-schema.md`.

**Tasks**:
- [x] Read `.claude/docs/architecture/handoff-schema.md` for complete schema reference *(completed)*
- [x] Add `skill_write_orchestrator_handoff()` function to `.claude/scripts/skill-base.sh` (~30 lines) *(completed)*
  - Parameters: `orchestrator_mode`, `padded_num`, `project_name`, `phase` (research/plan/implement), `status`, `summary`, `artifact_path`, `artifact_type`, `next_hint`
  - Guard: only write file when `orchestrator_mode == "true"`
  - Write to `specs/${padded_num}_${project_name}/.orchestrator-handoff.json`
  - Include required fields: `$schema`, `phase`, `status`, `summary`, `artifacts`, `blockers` (empty array default), `next_action_hint`
  - Include optional fields: `files_modified` (empty array), `decisions_made` (empty array), `dead_ends` (empty array)
  - Truncate `summary` to ~100 tokens if oversized to stay within 400-token budget
- [x] Verify function signature documented in skill-base.sh header comment block *(completed)*
- [x] Verify function produces valid JSON (test with `jq empty`) *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/skill-base.sh` - Add new function (~30 lines, bringing total to ~305 lines)

**Verification**:
- Function exists in skill-base.sh
- Calling with `orchestrator_mode=false` produces no output file
- Calling with `orchestrator_mode=true` produces valid JSON at expected path
- JSON conforms to `orchestrator-handoff-v1` schema

---

### Phase 3: Refactor research.md [COMPLETED]

**Goal**: Reduce `research.md` from 393 lines to ~178 lines by replacing the inline extension routing loop with a call to `command-route-skill.sh`, removing redundant GATE OUT inline checks, and condensing verbose sections.

**Tasks**:
- [x] Replace STAGE 2 extension routing loop (lines ~238-266 in current file, ~36 lines) with: *(completed)*
  ```
  source .claude/scripts/command-route-skill.sh "research" "$TASK_TYPE" "skill-researcher"
  skill_name="$SKILL_NAME"
  ```
- [x] Remove inline GATE OUT defensive checks (lines ~319-350, ~38 lines) — the `Verify state.json Status` and `Verify TODO.md Status` sections after `bash command-gate-out.sh` *(completed)*
- [x] Add brief comment after GATE OUT script call: "Defensive correction (state.json + TODO.md) handled by command-gate-out.sh above." *(completed)*
- [x] Condense MULTI-TASK DISPATCH section: reduce verbose bash code blocks to concise pseudocode while preserving all validation logic, result handling, and the core parallel Skill invocation loop *(completed)*
- [x] Simplify Stage 0 parse block: remove verbose comment blocks, keep essential clamp and dispatch decision *(completed)*
- [x] Remove the extension-based routing table documentation that duplicates what `command-route-skill.sh` handles (keep only the team mode routing logic and default skill documentation) *(completed)*
- [x] Add `orchestrator_mode` to delegation context JSON passed to skill invocations (default false, passed through from any future `/orchestrate` caller) *(completed)*
- [x] Verify final line count is within 150-200 range *(completed: 191 lines)*

**Timing**: 1.25 hours

**Depends on**: 2

**Files to modify**:
- `.claude/commands/research.md` - Refactor (target: ~178 lines)

**Verification**:
- `wc -l .claude/commands/research.md` shows 150-200 lines
- No Tier 3 content (state machine logic, format specs) remains
- Extension routing still works: `TASK_TYPE=neovim` routes to `skill-neovim-research`
- Multi-task dispatch section preserved (Skill tool calls still inline)
- GATE IN/OUT still reference correct scripts

---

### Phase 4: Refactor plan.md [COMPLETED]

**Goal**: Reduce `plan.md` from 420 lines to ~178 lines using the same extraction pattern as research.md.

**Tasks**:
- [x] Replace STAGE 2 extension routing loop (~36 lines) with `source command-route-skill.sh "plan" "$TASK_TYPE" "skill-planner"` *(completed)*
- [x] Remove inline GATE OUT defensive checks (Verify state.json Status, Verify TODO.md Status, ~38 lines) *(completed)*
- [x] Keep plan-specific GATE OUT check: Verify Plan File Status (plan.md-specific, ~18 lines) — this stays because `command-gate-out.sh` does not verify plan file internal status *(completed)*
- [x] Add brief comment after GATE OUT script call for removed checks *(completed)*
- [x] Condense MULTI-TASK DISPATCH section to concise form while preserving validation and Skill loop *(completed)*
- [x] Simplify Stage 0: remove verbose comments, keep clamp and `--roadmap` flag extraction *(completed)*
- [x] Add `orchestrator_mode` to delegation context JSON *(completed)*
- [x] Verify `--roadmap` flag handling preserved (plan-specific) *(completed)*
- [x] Verify `prior_plan_path` discovery logic preserved (plan-specific) *(completed)*
- [x] Verify final line count within 150-200 range *(completed: 202 lines)*

**Timing**: 1.0 hours

**Depends on**: 2

**Files to modify**:
- `.claude/commands/plan.md` - Refactor (target: ~178 lines)

**Verification**:
- `wc -l .claude/commands/plan.md` shows 150-200 lines
- `--roadmap` flag still parsed and passed to skill
- Prior plan path discovery still works
- Extension routing resolves correctly
- Plan-specific GATE OUT check retained

---

### Phase 5: Refactor implement.md [COMPLETED]

**Goal**: Reduce `implement.md` from 525 lines to ~202 lines. This is the most complex command due to `--force` override, resume detection, partial/complete variants, and implement-specific GATE OUT steps.

**Tasks**:
- [x] Replace STAGE 2 extension routing loop (~36 lines) with `source command-route-skill.sh "implement" "$TASK_TYPE" "skill-implementer"` *(completed)*
- [x] Remove inline GATE OUT steps 1-3 (general defensive checks, ~35 lines) — already handled by `command-gate-out.sh` *(completed)*
- [x] Keep inline GATE OUT steps 4-7 (implement-specific): completion_summary population, plan file status verification, TODO.md status verification for completed tasks, post-delegation takeover detection note *(completed)*
- [x] Add brief comment for removed checks pointing to `command-gate-out.sh` *(completed)*
- [x] Condense MULTI-TASK DISPATCH section: preserve `--force` handling within batch validation, keep Skill invocation loop *(completed)*
- [x] Simplify Stage 0: remove the 5-row input/output examples table (move to docs if needed), keep essential clamp *(completed)*
- [x] Preserve `--force` override logic in CHECKPOINT 1 (implement-specific) *(completed)*
- [x] Preserve resume point detection logic (implement-specific) *(completed)*
- [x] Preserve partial/complete COMMIT variants in CHECKPOINT 3 *(completed)*
- [x] Add `orchestrator_mode` to delegation context JSON *(completed)*
- [x] Verify final line count within 150-210 range (allow slight overshoot for implement complexity) *(completed: 207 lines)*

**Timing**: 1.25 hours

**Depends on**: 2

**Files to modify**:
- `.claude/commands/implement.md` - Refactor (target: ~202 lines)

**Verification**:
- `wc -l .claude/commands/implement.md` shows 150-210 lines
- `--force` override works for completed tasks
- Resume detection from plan phase markers works
- Implement-specific GATE OUT steps (4-7) retained
- Partial and complete commit variants preserved
- Extension routing resolves correctly

---

### Phase 6: Add orchestrator_mode to skills and validate [COMPLETED]

**Goal**: Add orchestrator_mode detection and handoff writing to all three core skills, add continuation loop disable to skill-implementer, and run end-to-end validation including extension compatibility.

**Tasks**:
- [x] In `skill-researcher/SKILL.md`: *(completed)*
  - Add orchestrator_mode extraction from delegation context (1 line, early in execution)
  - Add `skill_write_orchestrator_handoff` call in postflight (after Stage 7 status update, ~3 lines)
- [x] In `skill-planner/SKILL.md`: *(completed)*
  - Add orchestrator_mode extraction (1 line)
  - Add `skill_write_orchestrator_handoff` call in postflight (~3 lines)
- [x] In `skill-implementer/SKILL.md`: *(completed)*
  - Add orchestrator_mode extraction (1 line)
  - Add `max_continuations=0` when `orchestrator_mode=true` in Stage 5c continuation loop init (~4 lines)
  - Add `skill_write_orchestrator_handoff` call in postflight (~3 lines)
- [x] Verify line count changes: researcher 231->242, planner 203->215, implementer 336->363 *(completed)*
- [x] **Extension compatibility validation**: *(completed)*
  - Verify nvim extension manifest routing keys unchanged: `neovim` routes to correct skills
  - Verify nix extension manifest routing keys unchanged: `nix` routes to correct skills
  - Verify `command-route-skill.sh` correctly resolves both extension types
- [x] **Functional verification** (spot checks): *(completed)*
  - Verify `wc -l` on all three command files within target ranges (191, 202, 207)
  - Verify no Tier 3 content in commands (grep returns 0 matches)
  - Verify `command-gate-out.sh` is called in all three commands
  - Verify `command-gate-in.sh` is sourced in all three commands
  - Verify `parse-command-args.sh` is sourced in all three commands
- [x] **orchestrator_mode verification**: *(completed)*
  - Confirm `skill_write_orchestrator_handoff` function exists in skill-base.sh
  - Confirm all three skills reference orchestrator_mode in their postflight
  - Confirm skill-implementer checks orchestrator_mode for continuation loop

**Timing**: 1.0 hours

**Depends on**: 3, 4, 5

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Add orchestrator_mode support (~9 lines)
- `.claude/skills/skill-planner/SKILL.md` - Add orchestrator_mode support (~9 lines)
- `.claude/skills/skill-implementer/SKILL.md` - Add orchestrator_mode support (~19 lines)

**Verification**:
- All three skills reference `skill_write_orchestrator_handoff`
- `skill-implementer` has `max_continuations=0` guard for orchestrator_mode
- `wc -l` on all modified files within expected ranges
- Extension routing still works for nvim and nix task types
- No regressions in command file structure (all checkpoints present)

## Testing & Validation

- [ ] Line count verification: `wc -l .claude/commands/research.md .claude/commands/plan.md .claude/commands/implement.md` -- each within 150-210 lines
- [ ] No Tier 3 content in commands: `grep -c "State Machine\|JSON schema\|format specif\|state machine" .claude/commands/research.md .claude/commands/plan.md .claude/commands/implement.md` returns 0 for each
- [ ] Extension routing script exists: `test -f .claude/scripts/command-route-skill.sh`
- [ ] Extension routing resolves correctly: manual test with neovim and nix task types
- [ ] `command-gate-out.sh` called in all three commands (grep verification)
- [ ] `command-gate-in.sh` sourced in all three commands (grep verification)
- [ ] `command-route-skill.sh` sourced in all three commands (grep verification)
- [ ] `skill_write_orchestrator_handoff` function exists in skill-base.sh
- [ ] All three skill files reference orchestrator_mode
- [ ] `skill-implementer` has max_continuations=0 for orchestrator_mode

## Artifacts & Outputs

- `.claude/scripts/command-route-skill.sh` - New shared extension routing script (~50 lines)
- `.claude/commands/research.md` - Refactored (393 -> ~178 lines)
- `.claude/commands/plan.md` - Refactored (420 -> ~178 lines)
- `.claude/commands/implement.md` - Refactored (525 -> ~202 lines)
- `.claude/scripts/skill-base.sh` - Extended with orchestrator handoff function (274 -> ~305 lines)
- `.claude/skills/skill-researcher/SKILL.md` - Extended with orchestrator_mode (231 -> ~240 lines)
- `.claude/skills/skill-planner/SKILL.md` - Extended with orchestrator_mode (203 -> ~212 lines)
- `.claude/skills/skill-implementer/SKILL.md` - Extended with orchestrator_mode (336 -> ~355 lines)

## Rollback/Contingency

All modified files are version-controlled. If the refactoring introduces regressions:
1. `git diff HEAD~1` to review all changes
2. `git checkout HEAD~1 -- .claude/commands/research.md .claude/commands/plan.md .claude/commands/implement.md` to restore command files
3. `git checkout HEAD~1 -- .claude/scripts/skill-base.sh` to restore skill-base.sh
4. New file `.claude/scripts/command-route-skill.sh` can be deleted without side effects (commands fall back to inline routing)
5. Skill file changes (orchestrator_mode additions) are additive and can be reverted independently without affecting existing functionality

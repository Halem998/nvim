# Implementation Plan: Task #104

- **Task**: 104 - Fix /implement phase status live updates
- **Status**: [NOT STARTED]
- **Effort**: 2-3 hours
- **Dependencies**: None
- **Research Inputs**: [research-002.md](../reports/research-002.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The /implement command updates plan-level `**Status**:` correctly but applies the same sed pattern to ALL `**Status**:` lines in the plan file, clobbering per-phase metadata lines instead of leaving phase headings as the sole source of phase status. The fix aligns all files to plan-format.md: phase status lives ONLY in the heading (`### Phase N: Name [STATUS]`), plan-level status lives ONLY in the top metadata block (`**Status**: [STATUS]`). This requires updating 1 template, 4 skill files (preflight + postflight sed patterns), 1 command file (GATE OUT), and 4 agent files (phase status edit instructions).

### Research Integration

Research report research-002.md identified two competing format standards (artifact-formats.md vs plan-format.md), mapped all 16 affected files across 5 categories, and provided exact sed replacement patterns using GNU sed `0,/pattern/` first-match addressing. The plan follows the recommended implementation order from the research.

## Goals & Non-Goals

**Goals**:
- Eliminate the dual-status pattern (status in both heading and metadata line per phase)
- Make plan files a live dashboard where phase headings show sequential progress
- Ensure plan-level sed updates only target the first `**Status**:` line (plan metadata)
- Clarify agent instructions to use Edit tool on phase headings specifically
- Maintain backward compatibility with existing plans that have dual-status format

**Non-Goals**:
- Migrating existing plans to remove their per-phase `**Status**:` lines (they become harmless stale text)
- Changing the plan-level status markers (`[IMPLEMENTING]`, `[COMPLETED]`, etc.)
- Modifying resume detection logic (already reads from headings)
- Adding status update logic to extension-based skills (lean, z3, python) that do not yet have implementation skills

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Old plans have per-phase `**Status**:` lines that become stale | Low | High | First-match sed safely targets only plan-level; stale lines are harmless and ignored |
| Planner still generates dual-status despite template fix | Medium | Low | Update both artifact-formats.md AND planner-agent.md; verify in Phase 4 |
| GNU sed `0,/pat/` not portable to macOS/BSD | Low | Low | Project targets NixOS Linux where GNU sed is standard |
| Agent constructs wrong Edit tool old_string | Medium | Low | Agent reads plan file first; heading text is unique per phase |

## Implementation Phases

### Phase 1: Fix Plan Templates and Format Standards [NOT STARTED]

**Goal**: Align artifact-formats.md with plan-format.md so new plans are generated with heading-only phase status.

**Estimated effort**: 0.5 hours

**Files to modify**:
- `.claude/rules/artifact-formats.md` (lines 95-98) - Remove per-phase `**Status**: [NOT STARTED]` line from template, add `[NOT STARTED]` to phase heading
- `.claude/agents/planner-agent.md` (Stage 5 plan template) - Verify/ensure no per-phase `**Status**:` line in the phase template; confirm heading-only format

**Steps**:
1. Read `.claude/rules/artifact-formats.md` and locate the phase template section (around line 95)
2. Change `### Phase 1: {Name}` to `### Phase 1: {Name} [NOT STARTED]`
3. Remove the `**Status**: [NOT STARTED]` line beneath it
4. Read `.claude/agents/planner-agent.md` and verify its phase template matches (heading-only status)
5. If the planner template includes a `**Status**:` line per phase, remove it

**Verification**:
- `grep -n "Status.*NOT STARTED" .claude/rules/artifact-formats.md` shows only plan-level metadata, not per-phase
- Phase heading in artifact-formats.md includes `[NOT STARTED]` marker
- planner-agent.md phase template has no per-phase `**Status**:` line

---

### Phase 2: Fix Skill Preflight sed Patterns [NOT STARTED]

**Goal**: Change all 4 implementation skill preflights to use first-match sed addressing so only the plan-level `**Status**:` line is updated to `[IMPLEMENTING]`.

**Estimated effort**: 0.75 hours

**Files to modify**:
- `.claude/skills/skill-implementer/SKILL.md` (line 96) - Replace global sed with first-match `0,/pattern/`
- `.claude/skills/skill-neovim-implementation/SKILL.md` (lines 88-89) - Replace both sed commands with first-match versions
- `.claude/skills/skill-latex-implementation/SKILL.md` (line 76) - Replace global sed with first-match
- `.claude/skills/skill-typst-implementation/SKILL.md` (line 76) - Replace global sed with first-match

**Steps**:
1. For each skill file, read the preflight section containing the sed command(s)
2. Replace each sed command with the first-match equivalent:
   - Old: `sed -i "s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [IMPLEMENTING]/" "$plan_file"`
   - New: `sed -i '0,/^\- \*\*Status\*\*: \[.*\]/{s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [IMPLEMENTING]/}' "$plan_file"`
   - Old: `sed -i 's/^\*\*Status\*\*: \[.*\]$/**Status**: [IMPLEMENTING]/' "$plan_file"`
   - New: `sed -i '0,/^\*\*Status\*\*: \[.*\]/{s/^\*\*Status\*\*: \[.*\]$/**Status**: [IMPLEMENTING]/}' "$plan_file"`
3. Verify each skill file has exactly the first-match pattern, not the global pattern

**Verification**:
- `grep -c "0,/" .claude/skills/skill-*/SKILL.md` shows each skill file contains first-match sed patterns
- No remaining `sed -i "s/.*Status.*IMPLEMENTING/"` without `0,/` addressing in any skill

---

### Phase 3: Fix Skill Postflight sed Patterns [NOT STARTED]

**Goal**: Change all 4 implementation skill postflights to use first-match sed addressing for both the COMPLETED and PARTIAL status updates.

**Estimated effort**: 0.75 hours

**Files to modify**:
- `.claude/skills/skill-implementer/SKILL.md` (lines 271-272 completed, lines 303-304 partial)
- `.claude/skills/skill-neovim-implementation/SKILL.md` (lines 238-239 completed, lines 270-271 partial)
- `.claude/skills/skill-latex-implementation/SKILL.md` (lines 288-289 completed, lines 320-321 partial)
- `.claude/skills/skill-typst-implementation/SKILL.md` (lines 287-288 completed, lines 319-320 partial)

**Steps**:
1. For each skill file, read the postflight sections containing COMPLETED and PARTIAL sed commands
2. Replace each sed pair with first-match equivalents:
   - COMPLETED case:
     - `sed -i '0,/^\- \*\*Status\*\*: \[.*\]/{s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [COMPLETED]/}' "$plan_file"`
     - `sed -i '0,/^\*\*Status\*\*: \[.*\]/{s/^\*\*Status\*\*: \[.*\]$/**Status**: [COMPLETED]/}' "$plan_file"`
   - PARTIAL case:
     - `sed -i '0,/^\- \*\*Status\*\*: \[.*\]/{s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [PARTIAL]/}' "$plan_file"`
     - `sed -i '0,/^\*\*Status\*\*: \[.*\]/{s/^\*\*Status\*\*: \[.*\]$/**Status**: [PARTIAL]/}' "$plan_file"`
3. Each skill has 4 sed commands to update (2 for COMPLETED, 2 for PARTIAL) = 16 total replacements

**Verification**:
- All postflight sed commands in all 4 skills use `0,/` first-match addressing
- `grep -c "0,/" .claude/skills/skill-*/SKILL.md` counts match expected totals (preflight + postflight)

---

### Phase 4: Fix Command GATE OUT sed Patterns [NOT STARTED]

**Goal**: Update the /implement command's GATE OUT section to use first-match sed for the defensive plan-level status correction.

**Estimated effort**: 0.25 hours

**Files to modify**:
- `.claude/commands/implement.md` (lines 141-143) - Replace global sed with first-match for both bullet-prefix and non-prefix variants

**Steps**:
1. Read `.claude/commands/implement.md` around lines 140-145
2. Replace the COMPLETED sed commands with first-match equivalents:
   - `sed -i '0,/^\- \*\*Status\*\*: \[.*\]/{s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [COMPLETED]/}' "$plan_file"`
   - `sed -i '0,/^\*\*Status\*\*: \[.*\]/{s/^\*\*Status\*\*: \[.*\]$/**Status**: [COMPLETED]/}' "$plan_file"`

**Verification**:
- `grep "0,/" .claude/commands/implement.md` shows first-match addressing
- No remaining global sed patterns targeting `**Status**:` in implement.md

---

### Phase 5: Clarify Agent Phase Status Edit Instructions [NOT STARTED]

**Goal**: Update all 4 implementation agent files to provide explicit Edit tool old_string/new_string examples for phase heading status updates, removing any ambiguity about where phase status lives.

**Estimated effort**: 0.75 hours

**Files to modify**:
- `.claude/agents/general-implementation-agent.md` (Stage 4, sections A and D)
- `.claude/agents/neovim-implementation-agent.md` (Stage 4, sections A and D)
- `.claude/agents/latex-implementation-agent.md` (Stage 4, sections A and D)
- `.claude/agents/typst-implementation-agent.md` (Stage 4, sections A and D)

**Steps**:
1. For each agent file, locate "**A. Mark Phase In Progress**" and "**D. Mark Phase Complete**" sections
2. Replace the ambiguous single-line instruction with explicit Edit tool pattern:

   For section A, replace:
   ```
   **A. Mark Phase In Progress**
   Edit plan file: Change phase status to `[IN PROGRESS]`
   ```
   With:
   ```
   **A. Mark Phase In Progress**
   Edit plan file heading to show the phase is active.
   Use the Edit tool with:
   - old_string: `### Phase {P}: {Phase Name} [NOT STARTED]`
   - new_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`

   Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per phase.
   ```

   For section D, replace:
   ```
   **D. Mark Phase Complete**
   Edit plan file: Change phase status to `[COMPLETED]`
   ```
   With:
   ```
   **D. Mark Phase Complete**
   Edit plan file heading to show the phase is finished.
   Use the Edit tool with:
   - old_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
   - new_string: `### Phase {P}: {Phase Name} [COMPLETED]`

   Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per phase.
   ```

3. Read each modified agent to verify the new instructions are clear and no mention of per-phase `**Status**:` metadata updates remains in the phase execution loop

**Verification**:
- All 4 agent files contain explicit `old_string`/`new_string` patterns in sections A and D
- No agent file mentions updating a `**Status**:` line for individual phases
- The phrase "Phase status lives ONLY in the heading" appears in all 4 agent files

---

### Phase 6: Verification and Testing [NOT STARTED]

**Goal**: Validate the complete fix by checking all modified files for consistency and testing sed patterns against a sample plan.

**Estimated effort**: 0.5 hours

**Steps**:
1. Create a test plan snippet in `/tmp/test-plan-104.md` with both plan-level and (legacy) per-phase `**Status**:` lines
2. Run the first-match sed pattern against it and verify only the first occurrence is updated:
   ```bash
   cp /tmp/test-plan-104.md /tmp/test-plan-104-backup.md
   sed -i '0,/^\- \*\*Status\*\*: \[.*\]/{s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [IMPLEMENTING]/}' /tmp/test-plan-104.md
   diff /tmp/test-plan-104-backup.md /tmp/test-plan-104.md
   ```
3. Verify the diff shows only line 1 (plan metadata) changed, not per-phase lines
4. Run a comprehensive grep audit across all modified files:
   ```bash
   # Verify no global sed patterns remain
   grep -rn 'sed.*Status.*IMPLEMENTING\|sed.*Status.*COMPLETED\|sed.*Status.*PARTIAL' \
     .claude/skills/ .claude/commands/implement.md | grep -v '0,/'
   ```
   Expected output: empty (all sed patterns use first-match)
5. Verify artifact-formats.md phase template consistency:
   ```bash
   grep -A2 "### Phase 1:" .claude/rules/artifact-formats.md
   ```
   Expected: heading with `[NOT STARTED]`, no `**Status**:` line following
6. Verify agent instructions contain explicit Edit tool patterns:
   ```bash
   grep -c "old_string.*Phase.*NOT STARTED" .claude/agents/*-implementation-agent.md
   ```
   Expected: 4 matches (one per agent)

**Verification**:
- sed first-match pattern updates only plan-level status in test file
- No remaining global sed patterns in any skill/command file
- artifact-formats.md template matches plan-format.md specification
- All 4 agents have explicit heading-based Edit tool instructions

## Testing & Validation

- [ ] First-match sed pattern updates only the first `**Status**:` line in a file with multiple occurrences
- [ ] artifact-formats.md phase template has status in heading only (no per-phase `**Status**:` line)
- [ ] planner-agent.md phase template has status in heading only
- [ ] All 4 skill preflights use `0,/` first-match sed addressing
- [ ] All 4 skill postflights (COMPLETED + PARTIAL) use `0,/` first-match sed addressing
- [ ] implement.md GATE OUT uses `0,/` first-match sed addressing
- [ ] All 4 agent files have explicit `old_string`/`new_string` Edit patterns for phase heading updates
- [ ] No agent file mentions per-phase `**Status**:` line updates
- [ ] Backward compatibility: first-match sed works correctly on old plans with dual-status format

## Artifacts & Outputs

- Modified `.claude/rules/artifact-formats.md` - Aligned phase template with plan-format.md
- Modified `.claude/agents/planner-agent.md` - Verified/updated phase template
- Modified `.claude/skills/skill-implementer/SKILL.md` - First-match sed (preflight + postflight)
- Modified `.claude/skills/skill-neovim-implementation/SKILL.md` - First-match sed (preflight + postflight)
- Modified `.claude/skills/skill-latex-implementation/SKILL.md` - First-match sed (preflight + postflight)
- Modified `.claude/skills/skill-typst-implementation/SKILL.md` - First-match sed (preflight + postflight)
- Modified `.claude/commands/implement.md` - First-match sed (GATE OUT)
- Modified `.claude/agents/general-implementation-agent.md` - Explicit heading-based phase status edits
- Modified `.claude/agents/neovim-implementation-agent.md` - Explicit heading-based phase status edits
- Modified `.claude/agents/latex-implementation-agent.md` - Explicit heading-based phase status edits
- Modified `.claude/agents/typst-implementation-agent.md` - Explicit heading-based phase status edits

## Rollback/Contingency

All changes are to markdown instruction files (`.claude/` configuration), not runtime code. Rollback is straightforward via `git checkout` of the affected files. Since existing plans with dual-status format remain backward compatible (first-match sed targets only the plan-level line), partial rollback of individual phases is safe.

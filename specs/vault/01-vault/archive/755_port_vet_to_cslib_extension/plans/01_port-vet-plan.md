# Implementation Plan: Port /vet command-skill-agent triplet to cslib extension

- **Task**: 755 - Port /vet command-skill-agent triplet to cslib extension
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/755_port_vet_to_cslib_extension/reports/01_port-vet-research.md
- **Artifacts**: plans/01_port-vet-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Port the /vet command-skill-agent triplet from the cslib project's local `.claude/` directory into the shared cslib extension at `.claude/extensions/cslib/`. This involves copying three source files verbatim (no content changes needed), registering them in manifest.json, and updating EXTENSION.md and README.md documentation. The critical constraint is that AskUserQuestion must remain available to the skill but prohibited for the agent.

### Research Integration

Research report confirmed:
- All three source files are self-consistent with correct absolute paths for cslib
- No content modifications needed -- copy verbatim
- AskUserQuestion constraint is correctly implemented (skill allows, agent prohibits)
- No routing entries needed (standalone command like /pr)
- No keyword_override needed (user-invoked directly)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly applicable to this extension porting task.

## Goals & Non-Goals

**Goals**:
- Copy vet.md, skill-cslib-vet/SKILL.md, and cslib-vet-agent.md into the cslib extension
- Register all three in manifest.json provides arrays
- Document the new command and skill-agent mapping in EXTENSION.md and README.md
- Verify AskUserQuestion tool availability follows the correct pattern (skill YES, agent NO)

**Non-Goals**:
- Modifying source file content (paths are intentionally absolute to cslib project)
- Adding routing entries (standalone command, not lifecycle-routed)
- Adding keyword_override entries (user-invoked directly)
- Modifying any other extension files

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| manifest.json syntax error after edit | H | L | Validate JSON with jq after editing |
| Missing directory for skill-cslib-vet | M | L | Create directory before copy |
| EXTENSION.md table formatting inconsistency | L | L | Match exact column widths of existing rows |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Copy source files [COMPLETED]

**Goal**: Copy the three /vet files from the cslib project into the cslib extension directory structure.

**Tasks**:
- [ ] Create directory `.claude/extensions/cslib/skills/skill-cslib-vet/`
- [ ] Copy `/home/benjamin/Projects/cslib/.claude/commands/vet.md` to `.claude/extensions/cslib/commands/vet.md`
- [ ] Copy `/home/benjamin/Projects/cslib/.claude/skills/skill-cslib-vet/SKILL.md` to `.claude/extensions/cslib/skills/skill-cslib-vet/SKILL.md`
- [ ] Copy `/home/benjamin/Projects/cslib/.claude/agents/cslib-vet-agent.md` to `.claude/extensions/cslib/agents/cslib-vet-agent.md`
- [ ] Verify all three files exist at target locations

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/commands/vet.md` - create (copy from cslib project)
- `.claude/extensions/cslib/skills/skill-cslib-vet/SKILL.md` - create (copy from cslib project)
- `.claude/extensions/cslib/agents/cslib-vet-agent.md` - create (copy from cslib project)

**Verification**:
- All three files exist at target paths
- File contents match source files exactly (diff returns empty)
- AskUserQuestion is in skill SKILL.md `allowed-tools` frontmatter
- AskUserQuestion is NOT in cslib-vet-agent.md `allowed-tools` or tool list

---

### Phase 2: Update manifest.json [COMPLETED]

**Goal**: Register the new agent, skill, and command in the cslib extension manifest.

**Tasks**:
- [ ] Add `"cslib-vet-agent.md"` to `provides.agents` array
- [ ] Add `"skill-cslib-vet"` to `provides.skills` array
- [ ] Add `"vet.md"` to `provides.commands` array
- [ ] Validate manifest.json is valid JSON after edits (run `jq . manifest.json`)

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/manifest.json` - add entries to agents, skills, commands arrays

**Verification**:
- `jq '.provides.agents' manifest.json` includes `cslib-vet-agent.md`
- `jq '.provides.skills' manifest.json` includes `skill-cslib-vet`
- `jq '.provides.commands' manifest.json` includes `vet.md`
- No JSON parse errors

---

### Phase 3: Update EXTENSION.md [COMPLETED]

**Goal**: Add /vet documentation to the EXTENSION.md skill-agent mapping and commands tables.

**Tasks**:
- [ ] Add row to Skill-Agent Mapping table: `| skill-cslib-vet | cslib-vet-agent | sonnet | Vet CSLib tasks against standards; run CI; create fix tasks with user confirmation |`
- [ ] Add row to Commands table: `| /vet | /vet <task_numbers> [focus_prompt] | Quality-gate: vet completed CSLib task(s) against CONTRIBUTING.md, NOTATION.md, ORGANISATION.md; run CI; create fix tasks |`

**Timing**: 10 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/cslib/EXTENSION.md` - add rows to two tables

**Verification**:
- `grep "skill-cslib-vet" EXTENSION.md` returns the new table row
- `grep "/vet" EXTENSION.md` returns the new command row
- Table formatting is consistent with existing rows

---

### Phase 4: Update README.md [COMPLETED]

**Goal**: Add /vet documentation to the README.md architecture tree, skill-agent mapping, and commands tables.

**Tasks**:
- [ ] Add `cslib-vet-agent.md` line under agents/ in architecture tree
- [ ] Add `skill-cslib-vet/` line under skills/ in architecture tree
- [ ] Add `vet.md` line under commands/ in architecture tree
- [ ] Add row to Skill-Agent Mapping table
- [ ] Add row to Commands table

**Timing**: 15 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/cslib/README.md` - add lines to architecture tree, rows to two tables

**Verification**:
- `grep "cslib-vet-agent" README.md` returns entries in both tree and table
- `grep "skill-cslib-vet" README.md` returns entries in both tree and table
- `grep "/vet" README.md` returns the command table row
- Architecture tree indentation matches existing entries

## Testing & Validation

- [ ] All three source files exist at target paths and match originals (diff empty)
- [ ] manifest.json parses as valid JSON
- [ ] manifest.json provides.agents includes cslib-vet-agent.md
- [ ] manifest.json provides.skills includes skill-cslib-vet
- [ ] manifest.json provides.commands includes vet.md
- [ ] EXTENSION.md has skill-cslib-vet in skill-agent mapping table
- [ ] EXTENSION.md has /vet in commands table
- [ ] README.md has all three new entries in architecture tree
- [ ] README.md has skill-cslib-vet in skill-agent mapping table
- [ ] README.md has /vet in commands table
- [ ] AskUserQuestion constraint: skill SKILL.md allowed-tools includes AskUserQuestion
- [ ] AskUserQuestion constraint: cslib-vet-agent.md does NOT allow AskUserQuestion

## Artifacts & Outputs

- `specs/755_port_vet_to_cslib_extension/plans/01_port-vet-plan.md` (this plan)
- `.claude/extensions/cslib/commands/vet.md` (new file)
- `.claude/extensions/cslib/skills/skill-cslib-vet/SKILL.md` (new file)
- `.claude/extensions/cslib/agents/cslib-vet-agent.md` (new file)
- `.claude/extensions/cslib/manifest.json` (updated)
- `.claude/extensions/cslib/EXTENSION.md` (updated)
- `.claude/extensions/cslib/README.md` (updated)

## Rollback/Contingency

All changes are additive (new files + new array entries + new table rows). Rollback by:
1. Delete the three new files (vet.md, skill-cslib-vet/SKILL.md, cslib-vet-agent.md)
2. Remove the three added entries from manifest.json arrays
3. Remove the added rows from EXTENSION.md and README.md tables
4. Git revert the commit if needed

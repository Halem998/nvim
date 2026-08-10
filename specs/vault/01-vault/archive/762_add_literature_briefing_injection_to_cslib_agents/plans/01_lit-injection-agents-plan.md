# Implementation Plan: Task #762

- **Task**: 762 - Add literature-briefing injection points to CSLib agents
- **Status**: [COMPLETED]
- **Effort**: 0.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/762_add_literature_briefing_injection_to_cslib_agents/reports/01_literature-briefing-injection.md
- **Artifacts**: plans/01_lit-injection-agents-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add `<literature-briefing>` block injection support to the 4 CSLib skill files and add lightweight acknowledgment notes to the 4 CSLib agent files. The primary work is in the skill layer (where `lit_flag` is checked and `literature-briefing.sh` is called), following the established pattern from `skill-researcher/SKILL.md` and `skill-implementer/SKILL.md`. The agent files need only a brief note explaining that a `<literature-briefing>` block may be present in the prompt when `--lit` is used.

### Research Integration

Key findings from the research report (01_literature-briefing-injection.md):
- The `<literature-briefing>` injection chain runs: command `--lit` flag -> skill calls `literature-briefing.sh` -> skill injects result into agent prompt -> agent receives and uses the block.
- The 2 base CSLib skills (`skill-cslib-research`, `skill-cslib-implementation`) are missing Stage 4a entirely -- they jump from Stage 3 (delegation context) straight to Stage 4 (invoke subagent). They need both memory retrieval and literature briefing retrieval added.
- The 2 hard-mode CSLib skills (`skill-cslib-research-hard`, `skill-cslib-implementation-hard`) already have Stage 4a with memory retrieval but lack the literature briefing half. They need only the `lit_context` retrieval appended and their Stage 5 prompt instructions updated.
- The correct XML tag name is `<literature-briefing>` (not `<literature-context>`).
- Agent files receive the block passively at runtime; they need only a brief acknowledgment note.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. This is infrastructure maintenance for feature parity across CSLib extension skills.

## Goals & Non-Goals

**Goals**:
- Add `lit_context` retrieval (via `literature-briefing.sh`) to all 4 CSLib skill files
- Add `lit_context` injection instructions to the prompt construction stage of all 4 CSLib skills
- Add a brief `<literature-briefing>` acknowledgment note to all 4 CSLib agent files
- Achieve feature parity with `skill-researcher` and `skill-implementer` for `--lit` flag support

**Non-Goals**:
- Modifying the `literature-briefing.sh` script itself
- Adding memory retrieval to the base skills (Stage 4a memory retrieval is a separate concern; this plan adds only the `lit_context` half alongside a minimal memory retrieval block where Stage 4a is missing entirely)
- Changing the `--lit` flag threading in command-route-skill.sh or orchestration
- Modifying CLAUDE.md documentation for `--lit` mode

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Base skills are intentionally thin; adding Stage 4a expands them | L | L | Hard-mode variants already have Stage 4a; base skills are simply inconsistent. The change is minimal (6-8 lines of bash + 4 lines of prompt instruction). |
| Agent note could be confused with existing Literature Extraction Protocol in cslib-research-agent | M | L | The note explicitly distinguishes injected `<literature-briefing>` (pre-loaded files from `specs/literature/`) from the extraction protocol (structured extraction from task description). |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Add literature-briefing retrieval and injection to skill files [COMPLETED]

**Goal**: Add `lit_context` retrieval and prompt injection instructions to all 4 CSLib skill files, achieving feature parity with the general skills.

**Tasks**:
- [x] **skill-cslib-research/SKILL.md**: Insert a new `### Stage 3a: Memory and Literature Retrieval` between Stage 3 and Stage 4. Add memory retrieval (gated on `clean_flag`) and literature briefing retrieval (gated on `lit_flag`). Update the Stage 4 section to note that memory context and literature briefing should be included in the prompt when non-empty. *(completed: done by task 761 in parallel)*
- [x] **skill-cslib-implementation/SKILL.md**: Insert a new `### Stage 3a: Memory and Literature Retrieval` between Stage 3 and Stage 4. Same pattern as research skill but with empty string for `focus_prompt` in memory retrieval. Update Stage 4 to include injection instructions. *(completed: done by task 761 in parallel)*
- [x] **skill-cslib-research-hard/SKILL.md**: Append the `lit_context` retrieval block to the existing `### Stage 4a: Memory Retrieval (Auto)` section (after the memory retrieval block). Update Stage 5 prompt description from "Include format specification and memory context in prompt" to include literature briefing. *(completed: done by task 761 in parallel)*
- [x] **skill-cslib-implementation-hard/SKILL.md**: Same as cslib-research-hard -- append `lit_context` retrieval to Stage 4a and update Stage 5 prompt description. *(completed: done by task 761 in parallel)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/skills/skill-cslib-research/SKILL.md` - Add Stage 3a (memory + lit retrieval), update Stage 4 prompt instructions
- `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md` - Add Stage 3a (memory + lit retrieval), update Stage 4 prompt instructions
- `.claude/extensions/cslib/skills/skill-cslib-research-hard/SKILL.md` - Append lit retrieval to Stage 4a, update Stage 5 prompt instructions
- `.claude/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md` - Append lit retrieval to Stage 4a, update Stage 5 prompt instructions

**Verification**:
- Each skill file contains a `lit_context` retrieval block with `literature-briefing.sh` call
- Each skill file contains injection instructions mentioning `<literature-briefing>`
- The retrieval pattern matches the reference in `skill-researcher/SKILL.md` lines 168-178
- The injection instructions match the reference in `skill-researcher/SKILL.md` lines 264-270

**Exact patterns to insert**:

For base skills (new Stage 3a):
```markdown
### Stage 3a: Memory and Literature Retrieval

```bash
# Memory retrieval (skip if --clean)
memory_context=""
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "$focus_prompt" 2>/dev/null) || memory_context=""
fi

# Literature briefing injection (independent of clean_flag)
lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
fi
```

If `memory_context` is non-empty, include it in the Stage 4 prompt. If `lit_context` is non-empty, include it after memory context and before task-specific instructions. Do NOT inject empty blocks.
```

For hard-mode skills (append to existing Stage 4a):
```bash
# Literature briefing injection (independent of clean_flag)
lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
fi
```

For hard-mode Stage 5 update, add to the prompt parameter list and include:
```
**Literature Briefing Injection**: If `lit_context` from Stage 4a is non-empty, include it in the prompt as a separate block:

{lit_context from Stage 4a -- already wrapped in <literature-briefing> tags}

Place the literature briefing block AFTER the memory context block (if any) and BEFORE the task-specific instructions. Do NOT inject an empty `<literature-briefing>` block when no literature briefing was generated.
```

---

### Phase 2: Add literature-briefing acknowledgment to agent files [COMPLETED]

**Goal**: Add a brief note to each CSLib agent file acknowledging that a `<literature-briefing>` block may be present in the prompt, and how to use it.

**Tasks**:
- [x] **cslib-research-agent.md**: Add a `## Literature Briefing Context` section after the `## Agent Metadata` section (before `## BLOCKED TOOLS`). The note should explain that when `--lit` is used, a `<literature-briefing>` block containing pre-loaded files from `specs/literature/` may be injected into the prompt by the skill layer. This supplements (does not replace) any `## Literature Extraction Protocol` section already in the agent. *(completed)*
- [x] **cslib-implementation-agent.md**: Add the same `## Literature Briefing Context` section after `## Agent Metadata` (before `## BLOCKED TOOLS`). *(completed)*
- [x] **cslib-research-hard-agent.md**: Add a `<literature-briefing>` entry to the existing `## Context References` section (line ~36-44). Add a note that when present, the `<literature-briefing>` block auto-confirms Tier 1 reference grounding selection. *(completed)*
- [x] **cslib-implementation-hard-agent.md**: Add a `<literature-briefing>` entry to the existing `## Context References` section (line ~36-47). *(completed)*

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/agents/cslib-research-agent.md` - Add `## Literature Briefing Context` section
- `.claude/extensions/cslib/agents/cslib-implementation-agent.md` - Add `## Literature Briefing Context` section
- `.claude/extensions/cslib/agents/cslib-research-hard-agent.md` - Add entry to `## Context References` + Tier 1 note
- `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md` - Add entry to `## Context References`

**Verification**:
- Each agent file contains a reference to `<literature-briefing>`
- The base agents have a new section explaining the block
- The hard-mode agents have the block listed in Context References
- cslib-research-hard-agent.md mentions Tier 1 auto-confirmation

**Exact text for base agent section**:
```markdown
## Literature Briefing Context

When `--lit` is used, the skill layer may inject a `<literature-briefing>` block into this
agent's prompt. This block contains pre-loaded file content from `specs/literature/` (paper
summaries, specification excerpts, algorithm descriptions). When present, treat the block as
authoritative reference material for the current task. This supplements any literature
references found in the task description itself.
```

**Exact text for hard-mode Context References addition**:
```markdown
- `<literature-briefing>` block - Pre-loaded literature from `specs/literature/` (injected by skill when `--lit` flag is used)
```

## Testing & Validation

- [ ] Verify all 4 skill files contain `literature-briefing.sh` retrieval blocks
- [ ] Verify all 4 skill files contain `<literature-briefing>` injection instructions in their prompt construction stage
- [ ] Verify all 4 agent files contain a reference to `<literature-briefing>`
- [ ] Verify the `lit_flag` gating pattern matches the reference implementation (independent of `clean_flag`)
- [ ] Grep all 8 files for `literature-briefing` to confirm presence

## Artifacts & Outputs

- plans/01_lit-injection-agents-plan.md (this file)
- summaries/01_lit-injection-agents-summary.md (after implementation)
- 4 modified skill files in `.claude/extensions/cslib/skills/`
- 4 modified agent files in `.claude/extensions/cslib/agents/`

## Rollback/Contingency

All changes are additive (new sections/blocks inserted into existing files). Revert via `git checkout` of the 8 modified files if any issues arise. No existing functionality is modified -- only new injection points are added.

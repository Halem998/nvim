# Research Report: Task #762

**Task**: 762 - Add literature-briefing injection points to CSLib agents
**Started**: 2026-06-23T00:00:00Z
**Completed**: 2026-06-23T00:15:00Z
**Effort**: Low (mechanical pattern application)
**Dependencies**: None
**Sources/Inputs**: Codebase — skill-researcher/SKILL.md, skill-implementer/SKILL.md, skill-planner/SKILL.md, all 4 CSLib agent files, general-research-agent.md, general-implementation-agent.md, all 4 CSLib skill files
**Artifacts**: specs/762_add_literature_briefing_injection_to_cslib_agents/reports/01_literature-briefing-injection.md
**Standards**: report-format.md

---

## Executive Summary

- The `<literature-briefing>` injection is handled in the **skill** layer (not the agent layer). Skills retrieve `lit_context` via `literature-briefing.sh` and inject it into the agent prompt. The agent template files themselves receive the `{lit_context}` block at prompt-construction time; they do not need inline placeholders in their .md content.
- The 2 thin-wrapper CSLib skills (`skill-cslib-research`, `skill-cslib-implementation`) are missing the Stage 4a literature retrieval block entirely (they only have a bare `Stage 3: Prepare Delegation Context` with no memory/lit retrieval). The 2 hard-mode skills partially have memory retrieval (Stage 4a) but lack the literature briefing half.
- The 4 CSLib agent files each have a `## Literature Extraction Protocol` section for handling _conceptual_ literature references from the task description, but they lack the `{lit_context}` injection point in their prompt templates — the block injected by skills into the prompt.
- **Primary fix location is in the 4 CSLib skills** (adding Stage 4a lit retrieval and Stage 5 lit prompt inclusion). **Secondary fix location is in the 4 CSLib agent files** (adding a `## Context References` entry for the `<literature-briefing>` block, and a note in the execution flow about how to use it when present).

---

## Context & Scope

The `--lit` flag is threaded from `/research`, `/plan`, `/implement`, and `/orchestrate` through the skill layer to the agent prompt. The chain is:

1. Command receives `--lit` flag → sets `lit_flag=true`
2. Skill reads `lit_flag`, calls `bash .claude/scripts/literature-briefing.sh` to produce `lit_context`
3. Skill injects `{lit_context}` into the agent's prompt (after memory context, before task-specific instructions)
4. Agent receives `<literature-briefing>...</literature-briefing>` block in its prompt context
5. Agent uses the block alongside its own `## Literature Extraction Protocol` logic

**Scope of gap**: Steps 2 and 3 are missing in all 4 CSLib skills. Step 4/5 is partially present in the agents (they handle the *conceptual* extraction protocol) but the agents don't explicitly acknowledge the existence of a `<literature-briefing>` block in their execution flow.

---

## Findings

### Pattern from Reference Skills

#### skill-researcher/SKILL.md (lines 166-178, 264-270)

Stage 4a:
```bash
# Literature briefing injection (independent of clean_flag)
lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
fi
```

Stage 5 (prompt construction):
```
**Literature Briefing Injection**: If `lit_context` from Stage 4a is non-empty, include it in the prompt as a separate block:

{lit_context from Stage 4a -- already wrapped in <literature-briefing> tags}

Place the literature briefing block AFTER the memory context block (if any) and BEFORE the task-specific instructions. Do NOT inject an empty `<literature-briefing>` block when no literature briefing was generated.
```

The same pattern appears identically in skill-implementer/SKILL.md (lines 258-264) and skill-planner/SKILL.md (lines 286-292).

#### general-research-agent.md and general-implementation-agent.md

Neither agent file contains `{lit_context}` placeholders or `<literature-briefing>` references in their body text. The injection is purely in the skill layer. The agents simply receive the block in their prompt at runtime and use it as context.

### Current State of CSLib Skills

#### skill-cslib-research/SKILL.md

- Stage 3 contains delegation context JSON only
- Stage 4 jumps directly to "Invoke Subagent"
- **Missing**: Stage 4a (memory retrieval), literature briefing retrieval, Stage 4b (format spec), prompt construction with injections

#### skill-cslib-implementation/SKILL.md

- Same gap: no Stage 4a, no lit retrieval, no format injection

#### skill-cslib-research-hard/SKILL.md

- Has Stage 4a (memory retrieval), Stage 4b (format spec read)
- Stage 5 prompt comment: "Include format specification and memory context in prompt"
- **Missing**: Literature briefing retrieval (`lit_flag` check + `literature-briefing.sh` call), and corresponding injection instruction in Stage 5 comment

#### skill-cslib-implementation-hard/SKILL.md

- Has Stage 4a (memory retrieval), Stage 4b (format spec read)
- Stage 5 prompt comment: "Include format specification and memory context in prompt"
- **Missing**: Literature briefing retrieval and injection instruction in Stage 5

### Current State of CSLib Agent Files

#### cslib-research-agent.md

- Lines 159-173: `## Literature Extraction Protocol` — handles extraction from task description/user instructions when a paper is referenced. This is about identifying and structuring literature from task context.
- **No mention** of a `<literature-briefing>` block being injected via the skill. The two paths (skill injection vs. literature extraction protocol) serve complementary purposes:
  - Skill injection: pre-collected `specs/literature/` files passed in `<literature-briefing>` tags
  - Literature extraction protocol: structured extraction of any paper referenced in the task description
- The agent would benefit from a note explaining that when a `<literature-briefing>` block is present in the prompt, it supplements the extraction protocol.

#### cslib-implementation-agent.md

- No literature protocol section. Has no reference to `<literature-briefing>` or `specs/literature/` anywhere.
- Implementation agents in the general domain also don't mention the block explicitly — they just receive it and use it.

#### cslib-research-hard-agent.md

- Lines 36-46: Has `## Context References` section
- Lines 160-173 (Stage 1.5): Reference Grounding Tier Selection — considers literature sources for Tier 1
- Has a natural integration point: when a `<literature-briefing>` block is present, it should feed into Tier 1 reference grounding selection
- **Missing**: No explicit acknowledgment that `<literature-briefing>` may be injected by the skill

#### cslib-implementation-hard-agent.md

- Lines 36-46: Has `## Context References` section
- No literature handling beyond what it inherits from the base agent

### Key Architectural Insight

The `<literature-briefing>` tag name used in the agent prompt is DIFFERENT from the CLAUDE.md documentation which says "injects a `<literature-context>` block". After reading the actual skill code, the correct tag name used in skills is **`<literature-briefing>`** (see skill-researcher SKILL.md line 267, skill-implementer line 261, skill-planner line 289). The CLAUDE.md documentation appears to use "literature-context" for user-facing description but the actual injection uses the `<literature-briefing>` tag.

---

## Decisions

1. **Where to make changes**: The _primary_ fix is in the 4 CSLib **skill** files (adding lit_flag handling + injection). Secondary: add a `<literature-briefing>` acknowledgment note in the agent files.

2. **Minimal vs. comprehensive change**: The task description says "inject lit_context after memory context and before task-specific instructions" — this is a skill-layer operation. The agent files need only a brief mention so agents know to use the block if present.

3. **Thin-wrapper skills need expansion**: The base skills (`skill-cslib-research`, `skill-cslib-implementation`) are extremely thin and lack Stage 4a entirely. They need Stage 4a added (memory + lit retrieval) and Stage 5 needs to describe prompt construction with injections.

4. **Hard-mode skills need only lit_context addition**: The hard-mode skills already have Stage 4a (memory only) and Stage 4b (format spec). Only the lit_context retrieval line and Stage 5 injection instruction are missing.

---

## Exact Insertion Points

### Agent File Changes

All 4 agent files need a note in their execution flow about the `<literature-briefing>` block. The correct place is tied to each agent's literature-handling section:

#### cslib-research-agent.md

- **Location**: After `## Literature Extraction Protocol` section (after line 173)
- **Content**: A note explaining that when a `<literature-briefing>` block is injected by the skill, the agent should treat its contents as pre-loaded literature context and incorporate it into the extraction protocol output.

Alternatively, the insertion can go at the top of Stage 0 or in a `## Context References` section that the base research agent is currently missing (unlike the hard-mode agents which have one at lines 36-46).

**Recommended**: Add a `## Context References` section near the top (after `## Agent Metadata`) mirroring the hard-mode agent's structure, and include a note about `<literature-briefing>`. Then update the `## Literature Extraction Protocol` to reference the injected block.

#### cslib-implementation-agent.md

- No existing literature section. The agent should receive the `<literature-briefing>` block and use it as reference material when implementing proofs from papers.
- **Location**: Add a brief note in a new `## Literature Context` subsection within the execution flow, or as a paragraph in the `## Overview` section.

#### cslib-research-hard-agent.md

- **Location**: Stage 1.5 (Reference Grounding Tier Selection) — add a note that a `<literature-briefing>` block injected by the skill auto-confirms Tier 1 selection
- Also update `## Context References` at line 36 to mention `<literature-briefing>` as an injected block

#### cslib-implementation-hard-agent.md

- **Location**: `## Context References` section at line 36 — add a note that `<literature-briefing>` may be injected when `--lit` flag is used

### Skill File Changes

#### skill-cslib-research/SKILL.md

**Add Stage 4a** before Stage 4 (Invoke Subagent). Insert after Stage 3:

```markdown
### Stage 4a: Memory and Literature Retrieval

```bash
# Memory retrieval (skip if --clean)
memory_context=""
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "$focus_prompt" 2>/dev/null) || memory_context=""
fi

# Literature briefing (only if --lit)
lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
fi
```

**Update Stage 4 (Invoke Subagent)** description to include injection instructions:

```
Include format specification, memory context (if non-empty), and literature briefing (if non-empty) in the prompt.
Place: memory context AFTER format spec, BEFORE task instructions.
Place: literature briefing AFTER memory context, BEFORE task instructions.
Do NOT inject empty blocks.
```

#### skill-cslib-implementation/SKILL.md

Same pattern as skill-cslib-research/SKILL.md but adapted for implementation:

```bash
# Memory retrieval (skip if --clean)
memory_context=""
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "" 2>/dev/null) || memory_context=""
fi

# Literature briefing (only if --lit)
lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
fi
```

#### skill-cslib-research-hard/SKILL.md

**Update Stage 4a** (already has memory retrieval): Add the lit_context block after the existing memory_context block.

**Update Stage 5** prompt description: Change "Include format specification and memory context in prompt" to "Include format specification, memory context (if non-empty), and literature briefing (if non-empty) in prompt."

#### skill-cslib-implementation-hard/SKILL.md

Same as skill-cslib-research-hard/SKILL.md — add lit_context to existing Stage 4a, update Stage 5 description.

---

## Risks & Mitigations

- **Risk**: The base CSLib skills are very thin; adding Stage 4a significantly expands them. Could diverge from the current thin-wrapper philosophy.
  - **Mitigation**: The change is necessary for feature parity. The hard-mode variants already have Stage 4a, so the base variants are simply inconsistent.

- **Risk**: `literature-briefing.sh` may not exist in the cslib extension context.
  - **Mitigation**: The script lives in `.claude/scripts/literature-briefing.sh` (shared), not in the extension. It's already used by skill-researcher and skill-implementer. The `|| lit_context=""` fallback handles failure gracefully.

- **Risk**: Agent files may confuse the injected `<literature-briefing>` block with their own `## Literature Extraction Protocol`.
  - **Mitigation**: The agent note should clearly distinguish: "If a `<literature-briefing>` block is present in your prompt context, it contains pre-loaded file content from `specs/literature/`. This supplements (does not replace) the Literature Extraction Protocol for sources referenced in the task description."

---

## Context Extension Recommendations

None — the existing `.claude/extensions/cslib/` structure already covers this domain adequately. The CLAUDE.md literature mode documentation is sufficient.

---

## Appendix

### Files Read

- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md` (lines 140-282)
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md` (lines 245-284)
- `/home/benjamin/.config/nvim/.claude/skills/skill-planner/SKILL.md` (lines 275-312)
- `/home/benjamin/.config/nvim/.claude/agents/cslib-research-agent.md` (all 289 lines)
- `/home/benjamin/.config/nvim/.claude/agents/cslib-implementation-agent.md` (all 518 lines)
- `/home/benjamin/.config/nvim/.claude/agents/cslib-research-hard-agent.md` (all 299 lines)
- `/home/benjamin/.config/nvim/.claude/agents/cslib-implementation-hard-agent.md` (all 337 lines)
- `/home/benjamin/.config/nvim/.claude/agents/general-research-agent.md` (all 283 lines)
- `/home/benjamin/.config/nvim/.claude/agents/general-implementation-agent.md` (all 477 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-cslib-research/SKILL.md` (all 84 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md` (all 118 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-cslib-research-hard/SKILL.md` (all 262 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md` (all 346 lines)

### Key Tag Name

The correct XML tag used in the skill injection chain is `<literature-briefing>` (not `<literature-context>` as mentioned in user-facing CLAUDE.md docs).

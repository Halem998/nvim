# Research Report: Task #761

**Task**: 761 - Wire Stage 4a literature injection into CSLib skills
**Started**: 2026-06-23T00:00:00Z
**Completed**: 2026-06-23T00:05:00Z
**Effort**: 0.5h
**Dependencies**: None
**Sources/Inputs**:
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md` (reference implementation)
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md` (reference implementation)
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher-hard/SKILL.md` (reference hard variant)
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer-hard/SKILL.md` (reference hard variant)
- `/home/benjamin/.config/nvim/.claude/skills/skill-cslib-research/SKILL.md` (target)
- `/home/benjamin/.config/nvim/.claude/skills/skill-cslib-implementation/SKILL.md` (target)
- `/home/benjamin/.config/nvim/.claude/skills/skill-cslib-research-hard/SKILL.md` (target)
- `/home/benjamin/.config/nvim/.claude/skills/skill-cslib-implementation-hard/SKILL.md` (target)
**Artifacts**: - `/home/benjamin/.config/nvim/specs/761_wire_stage_4a_lit_injection_into_cslib_skills/reports/01_lit-injection-cslib-skills.md`
**Standards**: report-format.md

---

## Executive Summary

- The 4 CSLib skills are missing literature briefing injection despite receiving `lit_flag` in their delegation context
- Two skills (hard variants) have Stage 4a but only wire memory retrieval — they are missing the lit_context block that immediately follows in all reference implementations
- Two skills (base variants) have no Stage 4a at all — they need the entire Stage 4a section added
- The fix is a mechanical 2-line bash block plus one note, inserted in the same location in all 4 files

---

## Context & Scope

The `--lit` flag enables literature context injection into agent prompts. When passed, the
skill-base.sh parses `lit_flag=true` and passes it through delegation context. The receiving skill
is responsible for calling `literature-briefing.sh` and capturing `lit_context` before delegating
to the subagent. Without this wiring, `lit_flag` arrives in delegation context but is never
acted upon — the subagent receives no literature briefing.

The reference pattern exists in 6 skills: `skill-researcher`, `skill-implementer`, `skill-planner`,
`skill-researcher-hard`, `skill-implementer-hard`, and `skill-planner-hard`. All 4 CSLib skills are
missing it.

---

## Findings

### Reference Pattern (Canonical)

The exact code to insert comes from `skill-researcher/SKILL.md` lines 167-180 and
`skill-implementer/SKILL.md` lines 160-173. Both are identical:

```bash
# Literature briefing injection (independent of clean_flag)
lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
fi

# lit_context will be empty string if:
# - lit_flag is not "true" (skipped)
# - specs/literature/ sub-index is empty or missing
# - script exited with error
```

**Note**: `lit_flag` is independent of `clean_flag`. Using `--clean --lit` suppresses memory retrieval but still injects literature briefing. Literature briefing is gated solely on `lit_flag == "true"`.

In the hard variants (`skill-researcher-hard`, `skill-implementer-hard`), the pattern is
condensed (no inline comments, just the bash block + note), as seen in those files around line 130.

The subagent invocation then includes `lit_context` in its prompt, with the instruction:

> If `lit_context` is non-empty, inject it as a `<literature-briefing>` block after the memory
> context and before the task-specific instructions.

---

### Current State of Each CSLib Skill

#### 1. `skill-cslib-research/SKILL.md`

- **Lines**: 84 lines total
- **Stage 4a**: ABSENT
- **Where lit_flag is parsed**: Never — not present in file at all
- **Structure**: Stage 1 -> Stage 2 -> Stage 3 (delegation context JSON) -> Stage 4 (invoke subagent)
- **Injection point**: After Stage 3, before Stage 4. A new Stage 4a section must be added.
- **Memory retrieval**: Also absent — this skill has no memory or lit retrieval

#### 2. `skill-cslib-implementation/SKILL.md`

- **Lines**: 118 lines total
- **Stage 4a**: ABSENT
- **Where lit_flag is parsed**: Never — not present in file at all
- **Structure**: Stage 1 -> Stage 2 -> Stage 2b (cache warm) -> Stage 3 (delegation context) -> Stage 4 (invoke subagent)
- **Injection point**: After Stage 3, before Stage 4. A new Stage 4a section must be added.
- **Memory retrieval**: Also absent

#### 3. `skill-cslib-research-hard/SKILL.md`

- **Lines**: 262 lines total
- **Stage 4a**: Present at lines 119-125 — memory retrieval only
- **Where lit_flag is parsed**: Present in args but no lit_context block
- **Exact insertion point**: After line 125 (end of memory retrieval bash block), before the closing
  `---` separator at line 127, before `### Stage 4: Prepare Delegation Context`
- **What is missing**: The 5-line lit_context bash block + note line

Current Stage 4a (lines 119-127):
```
### Stage 4a: Memory Retrieval (Auto)

if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh ...)
fi

---

### Stage 4: Prepare Delegation Context
```

Must become (addition after the memory block, before `---`):
```
### Stage 4a: Memory Retrieval (Auto)

if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh ...)
fi

lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
fi

**Note**: `lit_flag` is independent of `clean_flag`. ...

---

### Stage 4: Prepare Delegation Context
```

Also: Stage 5 subagent invocation (line 168) currently says:
```
  - prompt: [task_context, delegation_context, format specification, memory_context, focus]
```
Must be updated to include `lit_context`:
```
  - prompt: [task_context, delegation_context, format specification, memory_context, lit_context, focus]
```

#### 4. `skill-cslib-implementation-hard/SKILL.md`

- **Lines**: 346 lines total
- **Stage 4a**: Present at lines 158-163 — memory retrieval only
- **Where lit_flag is parsed**: Present in args but no lit_context block
- **Exact insertion point**: After line 163 (end of memory retrieval bash block), before the closing
  `---` separator, before `### Stage 4: Prepare Delegation Context`
- **What is missing**: The 5-line lit_context bash block + note line

Current Stage 4a ends at line 163:
```
### Stage 4a: Memory Retrieval (Auto)

if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh ...)
fi

---

### Stage 4: Prepare Delegation Context
```

Also: Stage 5 subagent invocation (line 213) currently says:
```
  - prompt: [task_context, delegation_context, format specification, memory_context]
```
Must be updated to include `lit_context`:
```
  - prompt: [task_context, delegation_context, format specification, memory_context, lit_context]
```

---

### Exact Code Blocks to Insert

#### For `skill-cslib-research` and `skill-cslib-implementation` (base variants)

Insert a new `### Stage 4a` section after Stage 3 and before Stage 4. Full section:

```markdown
### Stage 4a: Memory and Literature Retrieval (Auto)

```bash
memory_context=""
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "" 2>/dev/null) || memory_context=""
fi

# Literature briefing injection (independent of clean_flag)
lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
fi
```

**Note**: `lit_flag` is independent of `clean_flag`. Using `--clean --lit` suppresses memory retrieval but still injects literature briefing. Literature briefing is gated solely on `lit_flag == "true"`.
```

Note: `focus_prompt` is not threaded into CSLib research base skill (per existing Stage 3 JSON
which has no `focus_prompt` parameter). The `memory-retrieve.sh` call uses empty string for focus.
For `skill-cslib-research`, Stage 3 JSON does include `focus_prompt`, so that call can use it.

**Variant for `skill-cslib-research`** (has focus_prompt in delegation context):
```bash
memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "$focus_prompt" 2>/dev/null) || memory_context=""
```

**Variant for `skill-cslib-implementation`** (no focus_prompt):
```bash
memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "" 2>/dev/null) || memory_context=""
```

Also update the Stage 4 "Invoke Subagent" section to include `memory_context` and `lit_context`
in the prompt description.

#### For `skill-cslib-research-hard` (hard variant — append to existing Stage 4a)

Insert after the closing `fi` of the memory retrieval block (line 125), before the `---` separator:

```markdown
```bash
# Literature briefing injection (independent of clean_flag)
lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
fi
```

**Note**: `lit_flag` is independent of `clean_flag`. Using `--clean --lit` suppresses memory retrieval but still injects literature briefing. Literature briefing is gated solely on `lit_flag == "true"`.
```

Update Stage 5 prompt line from:
```
  - prompt: [task_context, delegation_context, format specification, memory_context, focus]
```
To:
```
  - prompt: [task_context, delegation_context, format specification, memory_context, lit_context, focus]
```

And update the description note below Stage 5 from:
```
Include format specification and memory context in prompt.
```
To:
```
Include format specification, memory context, and literature briefing in prompt. If `lit_context` is non-empty, inject it as a `<literature-briefing>` block after the memory context and before the task-specific instructions.
```

#### For `skill-cslib-implementation-hard` (hard variant — append to existing Stage 4a)

Insert after the closing `fi` of the memory retrieval block (line 163), before the `---` separator:

```markdown
```bash
# Literature briefing injection (independent of clean_flag)
lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
fi
```

**Note**: `lit_flag` is independent of `clean_flag`. Using `--clean --lit` suppresses memory retrieval but still injects literature briefing. Literature briefing is gated solely on `lit_flag == "true"`.
```

Update Stage 5 prompt line from:
```
  - prompt: [task_context, delegation_context, format specification, memory_context]
```
To:
```
  - prompt: [task_context, delegation_context, format specification, memory_context, lit_context]
```

---

## Decisions

- The base variants (`skill-cslib-research`, `skill-cslib-implementation`) need Stage 4a added
  with both memory retrieval AND lit injection together. They currently have neither.
- The hard variants need only the lit_context block appended to existing Stage 4a.
- The lit_context block is identical across all 4 files — no skill-specific adaptation needed.
- The memory_context block uses `focus_prompt` for research skills and empty string for
  implementation skills, matching the pattern in their non-cslib counterparts.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Base skills lack Stage 4a entirely — adding memory retrieval is a bonus scope expansion | Both memory and lit are needed for feature parity; add both together |
| `lit_flag` may not be parsed in base skill args | `lit_flag` is passed in delegation context from the orchestrator and available as a variable; the base skills receive it but never use it |
| Stage 5 prompt descriptions not updated | Must update the prompt parameter list and any description note in Stage 5 for each skill |

---

## Context Extension Recommendations

- None. The pattern for literature injection is already documented in `CLAUDE.md` and the
  reference skill files.

---

## Appendix

### Files Modified (Implementation Phase)

1. `/home/benjamin/.config/nvim/.claude/skills/skill-cslib-research/SKILL.md`
   - Add Stage 4a section (memory + lit) after Stage 3
   - Update Stage 4 "Invoke Subagent" prompt description to include `memory_context` and `lit_context`

2. `/home/benjamin/.config/nvim/.claude/skills/skill-cslib-implementation/SKILL.md`
   - Add Stage 4a section (memory + lit) after Stage 3
   - Update Stage 4 "Invoke Subagent" prompt description to include `memory_context` and `lit_context`

3. `/home/benjamin/.config/nvim/.claude/skills/skill-cslib-research-hard/SKILL.md`
   - Append lit_context block to existing Stage 4a (after memory block)
   - Update Stage 5 prompt parameter list to include `lit_context`
   - Update Stage 5 description note

4. `/home/benjamin/.config/nvim/.claude/skills/skill-cslib-implementation-hard/SKILL.md`
   - Append lit_context block to existing Stage 4a (after memory block)
   - Update Stage 5 prompt parameter list to include `lit_context`

### Reference Lines

| File | Stage 4a memory block ends | Stage 4 starts |
|------|---------------------------|----------------|
| skill-cslib-research-hard | line 125 | line 129 |
| skill-cslib-implementation-hard | line 163 | line 168 |
| skill-cslib-research | (absent — insert after line 48) | line 50 |
| skill-cslib-implementation | (absent — insert after line 60) | line 62 |

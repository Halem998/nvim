# Teammate A Findings: Primary Analysis of Context-Protection Violations

- **Task**: 610 - Apply context-protective pattern to remaining skills
- **Teammate**: A (Primary Angle)
- **Artifact Number**: 01
- **Focus**: Per-skill violation audit with specific fixes

---

## Key Findings

### Reference Implementation: skill-team-research (615 lines)

Already refactored in task 609. Key context-protective patterns it demonstrates:

1. **jq extraction** for state.json fields (Stage 1, lines 56-68)
2. **@-references in subagent prompts** instead of reading format files (Stage 8, line 395)
3. **Synthesis delegated** to synthesis-agent via Agent tool (Stage 8, lines 366-407)
4. **File paths only** collected from teammates, not content (Stage 7, lines 309-346)
5. **Context budget documented** at ~1,500 tokens above baseline (lines 606-613)
6. **Uses `skill-base.sh`** functions for postflight (Stage 10, lines 436-448)

---

### 1. skill-researcher (242 lines)

**Violation Count**: 3 violations

**Violation 1: Format spec injection (Stage 4b, line 144)**
```bash
# VIOLATION: Reads 131-line format file into lead context
format_content=$(cat .claude/context/formats/report-format.md)
```
- **Token impact**: ~1,048 tokens (131 lines)
- **Fix**: Pass `@.claude/context/formats/report-format.md` as an @-reference in the subagent prompt. Remove `<artifact-format-specification>` block; add a single line to the subagent instructions: `"Follow the format in @.claude/context/formats/report-format.md"`.

**Violation 2: Roadmap injection (Stage 4c, lines 71-73)**
```bash
# VIOLATION: Reads full ROADMAP.md into lead context
roadmap_context=$(cat specs/ROADMAP.md)
```
- **Token impact**: ~240 tokens (30 lines currently, grows over time)
- **Fix**: Pass `@specs/ROADMAP.md` as @-reference to subagent. Remove `<roadmap-context>` block injection.

**Violation 3: Memory retrieval in lead (Stage 4a, lines 59-62)**
```bash
# VIOLATION: Runs memory-retrieve.sh and captures output into lead context
memory_context=$(bash .claude/scripts/memory-retrieve.sh "$DESCRIPTION" "$TASK_TYPE" "$focus_prompt" 2>/dev/null)
```
- **Token impact**: Variable, typically 200-800 tokens depending on memory vault contents
- **Fix**: Pass task keywords to subagent and let the subagent call `memory-retrieve.sh` itself. Or pass `@specs/ROADMAP.md` and the description to the subagent and let it query memory. Add to subagent prompt: `"If memory extension is available, run: bash .claude/scripts/memory-retrieve.sh '{DESCRIPTION}' '{TASK_TYPE}' '{focus_prompt}'"`.

**Borderline: Prior implementation context (Stage 4d, lines 84-107)**
```bash
# BORDERLINE: Reads prior summaries/handoffs/plans into lead context
prior_implementation_context+="\n\n## ${label}: $(basename "$f")\n\n$(cat "$f")"
```
- **Token impact**: Up to 500 lines (4,000 tokens), truncated at budget
- **Fix**: Pass artifact directory paths as @-references to the subagent. Let the subagent read them in its own context. Replace with: `"prior_artifact_dir": "specs/${PADDED_NUM}_${PROJECT_NAME}"` in delegation context, and instruct subagent to check for prior artifacts.

**Total estimated context bloat**: ~2,000-6,000 tokens above baseline
**Target after fix**: ~500 tokens (delegation JSON + jq extractions only)

**Already Good**:
- Uses `skill_validate_input` from skill-base.sh (Stage 1)
- Uses `skill_read_metadata` for postflight (Stage 6)
- Does NOT read the research report after subagent returns
- Postflight uses skill-base.sh functions correctly

---

### 2. skill-implementer (363 lines)

**Violation Count**: 2 violations

**Violation 1: Format spec injection (Stage 4b, lines 119-120)**
```bash
# VIOLATION: Reads summary-format.md into lead context
format_content=$(cat .claude/context/formats/summary-format.md)
```
- **Token impact**: ~472 tokens (59 lines)
- **Fix**: Pass `@.claude/context/formats/summary-format.md` as @-reference in subagent prompt.

**Violation 2: Memory retrieval in lead (Stage 4a, lines 64-67)**
```bash
# VIOLATION: Runs memory-retrieve.sh in lead context
memory_context=$(bash .claude/scripts/memory-retrieve.sh "$DESCRIPTION" "$TASK_TYPE" "" 2>/dev/null)
```
- **Token impact**: ~200-800 tokens
- **Fix**: Same as skill-researcher -- delegate memory retrieval to subagent.

**Total estimated context bloat**: ~700-1,300 tokens above baseline
**Target after fix**: ~400 tokens

**Already Good**:
- Uses `skill_validate_input` from skill-base.sh
- Has explicit "No Source Reading Before Delegation" boundary (line 115)
- Uses `skill_read_metadata` for postflight
- Uses jq for metadata extraction (Stage 6, lines 186-193)
- Continuation loop reads only jq-extracted fields, not full files
- Has Pre-Delegation and Postflight MUST NOT sections

---

### 3. skill-planner (215 lines)

**Violation Count**: 2 violations

**Violation 1: Format spec injection (Stage 4b, lines 114-115)**
```bash
# VIOLATION: Reads plan-format.md into lead context
format_content=$(cat .claude/context/formats/plan-format.md)
```
- **Token impact**: ~1,088 tokens (136 lines)
- **Fix**: Pass `@.claude/context/formats/plan-format.md` as @-reference in subagent prompt.

**Violation 2: Memory retrieval in lead (Stage 4a, lines 62-65)**
```bash
# VIOLATION: Runs memory-retrieve.sh in lead context
memory_context=$(bash .claude/scripts/memory-retrieve.sh "$DESCRIPTION" "$TASK_TYPE" "" 2>/dev/null)
```
- **Token impact**: ~200-800 tokens
- **Fix**: Delegate to subagent.

**Total estimated context bloat**: ~1,300-1,900 tokens above baseline
**Target after fix**: ~400 tokens

**Already Good**:
- Clean thin wrapper structure
- Uses `skill_validate_input` and `skill_read_metadata`
- Passes plan_path and research_path as paths, not content
- Postflight properly uses skill-base.sh functions
- Does NOT read research report content into lead

---

### 4. skill-orchestrator (128 lines)

**Violation Count**: 2 violations

**Violation 1: Full state.json Read (Stage "Core Responsibilities", line 32)**
```
1. Read specs/state.json
```
- **Token impact**: ~800+ tokens (full state.json can be large with many tasks)
- **Fix**: Use jq extraction: `jq -r --argjson num "$task_number" '.active_projects[] | select(.project_number == $num)' specs/state.json`

**Violation 2: Full TODO.md Read (Stage "Core Responsibilities", line 34)**
```
4. Read TODO.md for additional context if needed
```
- **Token impact**: ~800+ tokens (TODO.md grows with tasks)
- **Fix**: Use `grep -A 20 "### ${task_number}\." specs/TODO.md` to extract only the relevant task section, or use jq on state.json exclusively (which already has all needed fields).

**Total estimated context bloat**: ~1,600+ tokens above baseline
**Target after fix**: ~200 tokens (single jq extraction)

**Structural Note**: This skill is already fairly lean at 128 lines. The violations are conceptual (instructing the lead to Read full files) rather than code-heavy. The fix is primarily changing the Task Lookup section to use jq extraction.

---

### 5. skill-team-plan (598 lines)

**Violation Count**: 3 violations

**Violation 1: Research content injection (Stage 5b, lines 181-185)**
```bash
# VIOLATION: Reads full research report into lead context for teammate injection
research_content=""
if [ -n "$research_path" ] && [ -f "$research_path" ]; then
  research_content=$(cat "$research_path")
fi
```
- **Token impact**: ~2,000-5,000 tokens (research reports are typically 200-500 lines)
- **Fix**: Pass `@{research_path}` as an @-reference in teammate prompts. Replace `{research_content}` injection with: `"Read the research report at @{research_path} for context."`. This is the **highest-impact single violation** across all skills.

**Violation 2: Inline synthesis (Stages 7-9, lines 309-428)**
The lead reads teammate plan candidates and performs synthesis inline:
```bash
# Stage 7: Collect Teammate Results — reads each candidate file
# Stage 8: Synthesize Plans — lead performs comparison, trade-off analysis
# Stage 9: Create Final Plan — lead writes the synthesized plan
```
- **Token impact**: ~4,000-8,000 tokens (reading 2-3 full plan candidates + performing synthesis)
- **Fix**: Delegate synthesis to synthesis-agent, following skill-team-research's Stage 8 pattern. The lead collects only file paths from teammates, then dispatches a synthesis agent that reads all candidates and writes the final plan. The synthesis agent returns a ~200-word summary.

**Violation 3: No explicit context budget**
- Unlike skill-team-research, there is no documented context budget target or MUST NOT (Context Protection) section specific to context accumulation.
- **Fix**: Add context budget documentation matching skill-team-research's format (lines 606-615).

**Total estimated context bloat**: ~6,000-13,000 tokens above baseline
**Target after fix**: ~1,500 tokens (matching skill-team-research budget)

**This is the highest-priority target** -- it has the most context bloat of any skill.

---

### 6. skill-team-implement (677 lines)

**Violation Count**: 2 violations (lower severity than skill-team-plan)

**Violation 1: Plan file reading for phase extraction (Stage 5, lines 183-224)**
The lead reads the plan file to extract phase dependencies. However, this is partially justified -- the lead needs dependency information to compute wave groupings.

**Assessment**: This is a **legitimate lead responsibility** -- the lead must parse the plan to determine which phases can run in parallel. The plan file is typically 100-300 lines. However, the lead should extract only the dependency graph (phase numbers, depends_on fields, status markers), not retain the full plan text.

- **Current impact**: ~800-2,400 tokens (plan content)
- **Mitigation**: Extract dependency data via a structured parser (jq-style extraction from the plan), then discard the full plan text. The phase details for teammate prompts should reference the plan by path, not embed content.

**Violation 2: Phase details embedded in teammate prompts (Stage 7, lines 268-299)**
The lead extracts `{phase_details}`, `{files_list}`, `{steps_from_plan}`, `{verification_criteria}` from the plan and embeds them in teammate prompts.

**Assessment**: This is **borderline** -- the extraction is from the plan text (which the lead must read), not from source files. The skill already has a CRITICAL note (line 268) forbidding source file reading. However, embedding full phase details duplicates plan content.

- **Current impact**: ~500-1,500 tokens per teammate prompt
- **Fix**: Pass `@{plan_path}` to teammates with instructions like "Read the plan and implement Phase {P}." Each teammate reads the plan in its own context.

**Total estimated context bloat**: ~1,300-3,900 tokens above baseline
**Target after fix**: ~800 tokens

**Already Good**:
- Has both Pre-Delegation and Postflight MUST NOT sections
- Does NOT read source files (explicitly prohibited)
- Uses jq for state.json extraction (Stage 1)
- Wave execution loop only tracks completion status, not file content
- Commit pattern uses targeted staging

---

## Recommended Approach: Transformation Pattern

### Universal Fix Pattern (applies to all 6 skills)

**Fix 1: Format spec -> @-reference**

For skill-researcher, skill-implementer, skill-planner:
```
# BEFORE (Stage 4b):
format_content=$(cat .claude/context/formats/{type}-format.md)
# ... later in prompt: <artifact-format-specification>{format_content}</artifact-format-specification>

# AFTER:
# Remove Stage 4b entirely
# In subagent prompt, replace <artifact-format-specification> block with:
"Follow the format in @.claude/context/formats/{type}-format.md"
```

**Fix 2: Memory retrieval -> subagent responsibility**

For skill-researcher, skill-implementer, skill-planner:
```
# BEFORE (Stage 4a):
memory_context=$(bash .claude/scripts/memory-retrieve.sh "$DESCRIPTION" "$TASK_TYPE" "$focus" 2>/dev/null)
# ... later: {memory_context} block in prompt

# AFTER:
# Remove Stage 4a entirely
# In subagent prompt, add:
"If memory retrieval is available, run: bash .claude/scripts/memory-retrieve.sh '{DESCRIPTION}' '{TASK_TYPE}' '{focus}'"
# Or pass memory keywords in delegation context and let subagent handle retrieval
```

**Fix 3: Roadmap -> @-reference (skill-researcher only)**
```
# BEFORE (Stage 4c):
roadmap_context=$(cat specs/ROADMAP.md)
# ... later: <roadmap-context>{roadmap_context}</roadmap-context>

# AFTER:
# Remove Stage 4c entirely
# In subagent prompt: "Read @specs/ROADMAP.md for project context if it exists."
```

### Team Skill Fix Pattern (skill-team-plan, skill-team-implement)

**Fix 4: Research content -> @-reference (skill-team-plan)**
```
# BEFORE (Stage 5b):
research_content=$(cat "$research_path")
# ... later: "Research findings:\n{research_content}" in teammate prompt

# AFTER:
# Remove Stage 5b entirely
# In teammate prompt: "Read the research report at @{research_path} for context."
```

**Fix 5: Delegate synthesis to synthesis-agent (skill-team-plan)**

Model on skill-team-research Stages 7-8:
```
# BEFORE (Stages 7-9):
# Lead reads all candidate plans
# Lead compares, analyzes trade-offs, synthesizes
# Lead writes the final plan

# AFTER (Stages 7-8, following skill-team-research pattern):
# Stage 7: Collect only file paths of completed candidates
# Stage 8: Dispatch synthesis-agent with @-references:
Agent(
  subagent_type: "synthesis-agent",
  prompt: "Synthesize implementation plans for task {N}: {description}
  
  Read each candidate plan:
  - @specs/{NNN}_{SLUG}/plans/{RR}_candidate-a.md
  - @specs/{NNN}_{SLUG}/plans/{RR}_candidate-b.md
  
  Write the unified plan to: specs/{NNN}_{SLUG}/plans/{RR}_implementation-plan.md
  Follow the format in @.claude/context/formats/plan-format.md
  
  Return: <200-word summary with selected approach and trade-off rationale."
)
```

**Fix 6: Plan path -> @-reference for teammates (skill-team-implement)**
```
# BEFORE (Stage 7):
# Lead extracts phase details from plan and embeds in teammate prompt

# AFTER:
# In teammate prompt: "Read the plan at @{plan_path}, then implement Phase {P}."
# Teammate reads plan in its own context
```

---

## Evidence/Examples

### Before/After: skill-researcher delegation prompt

**BEFORE** (current, ~3,000 tokens in prompt):
```
[delegation context JSON]

<artifact-format-specification>
# Report Artifact Standard
... (131 lines of format spec) ...
</artifact-format-specification>

<prior-implementation-context>
## Summary: 01_implementation-summary.md
... (potentially hundreds of lines) ...
</prior-implementation-context>

<memory-context>
... (200-800 tokens of memory) ...
</memory-context>

<roadmap-context>
... (30+ lines of ROADMAP.md) ...
</roadmap-context>

Research task {N}: {description}...
```

**AFTER** (context-protective, ~300 tokens in prompt):
```
[delegation context JSON]

Research task {N}: {description}

Follow the format in @.claude/context/formats/report-format.md
Read @specs/ROADMAP.md for project context if it exists.
If memory retrieval is available, run: bash .claude/scripts/memory-retrieve.sh '{DESCRIPTION}' '{TASK_TYPE}' '{focus}'
Check specs/{NNN}_{PROJECT_NAME}/ for prior artifacts if task has prior implementation context.
```

### Before/After: skill-team-plan synthesis

**BEFORE** (current, ~6,000-13,000 tokens):
```
# Lead reads full research report (~2,000-5,000 tokens)
# Lead reads candidate-a.md (~1,000-3,000 tokens)
# Lead reads candidate-b.md (~1,000-3,000 tokens)
# Lead performs inline comparison and writes final plan
```

**AFTER** (context-protective, ~1,500 tokens):
```
# Lead collects file paths only (~100 tokens)
# Lead dispatches synthesis-agent with @-references (~500 tokens prompt)
# Lead receives ~200-word summary (~200 tokens)
# Lead proceeds to postflight
```

---

## Priority Ordering

| Priority | Skill | Violations | Max Bloat | Effort |
|----------|-------|-----------|-----------|--------|
| 1 | skill-team-plan | 3 | ~13,000 tokens | High (synthesis delegation) |
| 2 | skill-researcher | 3+1 borderline | ~6,000 tokens | Medium (4 blocks to remove) |
| 3 | skill-team-implement | 2 | ~3,900 tokens | Medium (plan reading refactor) |
| 4 | skill-planner | 2 | ~1,900 tokens | Low (2 simple block removals) |
| 5 | skill-implementer | 2 | ~1,300 tokens | Low (2 simple block removals) |
| 6 | skill-orchestrator | 2 | ~1,600 tokens | Low (jq extraction swap) |

---

## Confidence Level

**High confidence** for all findings.

- All violations are directly observable in the skill source code
- The fix patterns are proven in the skill-team-research reference implementation
- Token impact estimates are based on measured line counts of the loaded files
- The priority ordering reflects both impact and implementation complexity

The universal fix pattern (format spec -> @-reference, memory -> subagent) is straightforward and can be applied mechanically. The synthesis delegation for skill-team-plan requires more architectural work but has clear precedent in skill-team-research.

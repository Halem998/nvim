# Research Report: Task #413

**Task**: 413 - Refine slides skill and command (design questions, routing, delegation)
**Started**: 2026-04-13T14:00:00Z
**Completed**: 2026-04-13T14:15:00Z
**Effort**: Small (text edits only, no logic changes)
**Dependencies**: None
**Sources/Inputs**: Zed working copy at `/home/benjamin/.config/zed/CHANGE.md` (Theme 6), Zed refined files at `.claude_NEW/skills/skill-slides/SKILL.md` and `.claude_NEW/commands/slides.md`
**Artifacts**: This report
**Standards**: report-format.md

## Executive Summary

- Task 413 ports 5 categories of refinement from the Zed working copy to the nvim slides skill and command
- All changes are textual simplifications -- no behavioral or routing logic changes
- The Zed versions are fully available for line-by-line diff comparison
- Implementation is straightforward: apply each delta from Zed to nvim files

## Context & Scope

The Zed working copy (`.claude_NEW/`) contains refined versions of the slides skill and command. These refinements improve readability by replacing verbose bash automation blocks with step-by-step prose, simplifying case statement syntax, removing duplicate routing tables, and removing unused return message formats. The changes need to be ported to the nvim copies at `.claude/extensions/present/skills/skill-slides/SKILL.md` and `.claude/extensions/present/commands/slides.md`.

## Findings

### File 1: SKILL.md (skill-slides)

Current: `/home/benjamin/.config/nvim/.claude/extensions/present/skills/skill-slides/SKILL.md` (510 lines)
Target: `/home/benjamin/.config/zed/.claude_NEW/skills/skill-slides/SKILL.md` (485 lines)

#### Change 1: Frontmatter comment update (lines 5-9)

**Current**:
```
# Subagent dispatch (resolved at Stage 4):
#   - slides-research-agent (workflow_type=slides_research)
#   - planner-agent (workflow_type=plan, via design questions pre-delegation)
#   - pptx-assembly-agent (workflow_type=assemble, output_format=pptx)
#   - slidev-assembly-agent (workflow_type=assemble, output_format=slidev)
```

**Target**:
```
# Subagents (dispatched by workflow_type + output_format):
#   - slides-research-agent (workflow_type=slides_research)
#   - planner-agent (workflow_type=plan, via design questions pre-delegation)
#   - pptx-assembly-agent (workflow_type=assemble, output_format=pptx)
#   - slidev-assembly-agent (workflow_type=assemble, output_format=slidev)
# Context is loaded by each subagent independently.
# Tools (used by subagents):
#   - Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, Bash
```

**What changed**: Comment header simplified from "Subagent dispatch (resolved at Stage 4)" to "Subagents (dispatched by workflow_type + output_format)". Two new comment lines added for context loading and tools.

#### Change 2: Introductory paragraph (line 17)

**Current**: "Thin wrapper that routes slides tasks to one of three specialized subagents:"
**Target**: "Thin wrapper that delegates slides work to the appropriate subagent based on workflow type and output format:"

Also removes the planner-agent bullet from the intro list (keeping only slides-research-agent, pptx-assembly-agent, slidev-assembly-agent).

#### Change 3: Workflow Type Routing note (lines 55-58)

**Current**: Verbose note mentioning "D1-D3" labels and theme fallback chain inline
**Target**: Simplified note without D1-D3 labels, restructured as prose about design_decisions storage and fallback chain

#### Change 4: Stage 3.5 Design Questions (lines 173-275)

This is the largest change. The current version has a single large bash script block (~100 lines) implementing the entire design question flow with shell variables, if/then/else, and inline AskUserQuestion calls.

**Target**: Restructured as 4 numbered steps with prose guidance:
- Step 1: Check for Existing Design Decisions (short bash snippet + prose)
- Step 2: Read Research Report (short bash snippet)
- Step 3: Design Questions D1-D3 (each as a separate prose subsection with the question text in code blocks)
- Step 4: Store Design Decisions (bash snippet for jq update)

The bash automation code for conditional logic (skip_design, has_report, etc.) is removed. The step-by-step structure gives the agent clear guidance without pretending to be executable bash.

#### Change 5: Agent resolution case statement (lines 289-304)

**Current**: Flat case with nested if/else for assemble:
```bash
case "$workflow_type" in
  slides_research)
    target_agent="slides-research-agent"
    ;;
  plan)
    target_agent="planner-agent"
    ;;
  assemble)
    if [ "$output_format" = "pptx" ]; then
      target_agent="pptx-assembly-agent"
    else
      target_agent="slidev-assembly-agent"
    fi
    ;;
esac
```

**Target**: Nested case for assemble:
```bash
case "$workflow_type" in
  slides_research)
    target_agent="slides-research-agent"
    ;;
  plan)
    target_agent="planner-agent"
    ;;
  assemble)
    case "$output_format" in
      pptx) target_agent="pptx-assembly-agent" ;;
      *)    target_agent="slidev-assembly-agent" ;;
    esac
    ;;
esac
```

#### Change 6: Delegation context simplification (lines 314-334)

**Current**: JSON block includes `"design_decisions"` field
**Target**: Removes `"design_decisions"` from the JSON block (design decisions are already in state.json metadata, no need to pass explicitly)

Also changes `"workflow_type": "slides_research|plan|assemble"` to `"workflow_type": "slides_research|assemble"` (plan workflow is handled before delegation).

#### Change 7: Remove routing table from Stage 5 (lines 350-358)

**Current**: Stage 5 has a duplicate routing table:
```
| workflow_type | output_format | Spawned Agent |
|...            |...            |...            |
```

**Target**: The table is removed. Stage 5 simply says "Use the `target_agent` resolved in Stage 4."

#### Change 8: Remove "Plan Success" return message (lines 452-458)

**Current**: Stage 11 has four return message templates: Talk Research, Plan Success, Assemble Slidev, Assemble PPTX
**Target**: Only three templates remain: Talk Research, Assemble Slidev, Assemble PPTX. The "Plan Success" template is removed because the plan workflow delegates to planner-agent which has its own return format.

### File 2: slides.md (command)

Current: `/home/benjamin/.config/nvim/.claude/extensions/present/commands/slides.md` (380 lines)
Target: `/home/benjamin/.config/zed/.claude_NEW/commands/slides.md` (401 lines)

#### Change 1: Output format question wording (lines 53-59)

**Current**:
```
What output format for this presentation?

- SLIDEV (default): Browser-based slides with Slidev markdown
- PPTX: PowerPoint file via python-pptx
```

**Target**:
```
What output format do you want for the presentation?

- SLIDEV (default): Slidev markdown-based slides
- PPTX: PowerPoint presentation file
```

Also adds explicit default instruction: "If the user does not specify or is ambiguous, default to `\"slidev\"`."

#### Change 2: Renumber steps -- remove Step 0.0 references (lines 163-166)

**Current**: Step 3 "Handle Input Type" references "Steps 0.0-0.3":
```
Run Stage 0 forcing questions (Steps 0.0-0.3) with the file content as context.
```

**Target**: References "Steps 0.1-0.3" (since output format is asked in Step 0.0 which is just the first question, not a separate numbered step in the Zed version -- but actually it keeps Step 0.0 heading, just changes the references in Step 3):
```
Run Stage 0 forcing questions (Steps 0.1-0.3) with the file content as context.
```

#### Change 3: Step 2.5 "Enrich Description" expansion (moved and expanded)

**Current**: Step 2.5 is between CHECKPOINT 1 and STAGE 1 (lines 169-193). It has a brief template and a single "Relativize source paths" bullet without implementation detail.

**Target**: Step 2.5 is moved to be within STAGE 1 (between Step 2 and Step 3). It is expanded with:
- Numbered sub-steps (1-3) explaining the enrichment process
- Explicit path relativization logic using `git rev-parse --show-toplevel`
- Bash code example showing the loop over source_materials with three cases: `task:*` references, repo-relative paths, and fallback to basename
- Audience summary truncation to ~20 words via `head -c 120`

#### Change 4: Remove "Plan Success" from Output Formats (absent in target)

The current file does not have a "Plan Success" output format, so this change may already be done -- confirmed: neither version has a "Plan Success" in the Output Formats section. The CHANGE.md description may refer to the absence of a plan-specific output format that should be confirmed as intentionally absent.

## Decisions

- All changes are direct ports from Zed to nvim -- no judgment calls needed
- The "Plan Success" removal in SKILL.md is the only potentially impactful change, but it is correct: the plan workflow delegates to planner-agent which handles its own return messaging
- Step 2.5 relocation in slides.md (from between CHECKPOINT 1 and STAGE 1, to within STAGE 1) is a structural improvement that keeps description enrichment closer to where the description is used

## Risks & Mitigations

- **Risk**: Low. All changes are documentation/instruction text, not executable code
- **Mitigation**: The Zed versions serve as exact targets; implementation is a straightforward diff application
- **Risk**: Step numbering changes could confuse cross-references
- **Mitigation**: The only cross-references are within the same file (Step 3 referencing Steps 0.1-0.3), and both the reference and target are updated together

## Implementation Checklist

For the implementer, here is the ordered list of edits:

### SKILL.md (8 edits)
1. Update frontmatter comment (line 5) and add 2 new comment lines
2. Update introductory paragraph (line 17) and bullet list (remove planner-agent bullet)
3. Simplify Workflow Type Routing note (lines 55-58)
4. Replace Stage 3.5 bash block with 4-step prose structure
5. Simplify agent resolution case statement (nested case for assemble)
6. Simplify delegation context JSON (remove design_decisions, change workflow_type values)
7. Remove routing table from Stage 5
8. Remove "Plan Success" return message from Stage 11

### slides.md (3 edits)
1. Update output format question wording and add default instruction
2. Change "Steps 0.0-0.3" references to "Steps 0.1-0.3" in Step 3
3. Move Step 2.5 into STAGE 1, expand with path relativization logic and bash example

## Appendix

### Source Files Examined
- `/home/benjamin/.config/zed/CHANGE.md` -- Theme 6 (lines 156-177)
- `/home/benjamin/.config/zed/.claude_NEW/skills/skill-slides/SKILL.md` -- Zed refined version (485 lines)
- `/home/benjamin/.config/zed/.claude_NEW/commands/slides.md` -- Zed refined version (401 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/present/skills/skill-slides/SKILL.md` -- Current nvim version (510 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/present/commands/slides.md` -- Current nvim version (380 lines)

# Research Report: Task #250

**Task**: Embed vault detection as inline check within skill-todo archive stage
**Date**: 2026-03-20
**Mode**: Team Research (2 teammates)

## Summary

Team research with 2 teammates investigated both external best practices (Anthropic guides, community patterns) and internal codebase patterns to determine the optimal strategy for embedding vault detection. Both teammates independently converged on the same core recommendation: embed vault as inline sub-steps within Stage 10 with bash output enforcement, remove separate vault stages 11-15, and add a pre-commit safety net. The key insight from Teammate B is that the `/todo` command (todo.md) already implements vault detection correctly as subsection 5.8 -- the SKILL.md simply failed to mirror this structure.

## Key Findings

### Primary Approach (from Teammate A)

**F1: Prompt instructions are suggestions; code is law.** Anthropic's 33-page skills guide (Feb 2026) explicitly states natural language alone is insufficient for strict workflows. Stage-skipping is a known LLM behavior pattern, not a bug.

**F2: Bash output creates mandatory context.** When a bash block produces output, the model incorporates it as immediate state with higher weight than static SKILL.md instructions. The unconditional output pattern (producing output for both vault-needed and vault-not-needed cases) prevents the model from reasoning "nothing output = step passed."

**F3: Sub-steps within a stage are more reliable than separate stages.** Each stage boundary is a decision point where the LLM can skip. Moving vault from stages 11-15 into numbered sub-steps within Stage 10 eliminates four skip opportunities.

**F4: Defense-in-depth pattern.** Community consensus for production skills: (1) inline bash directive in the critical stage, (2) pre-commit bash guard that exits non-zero if preconditions unmet.

**F5: XML tags don't prevent skipping.** XML tags improve parsing clarity but don't enforce execution order. The solution is inline bash that outputs directives based on real state, not better XML structure.

### Alternative Approaches (from Teammate B)

**F6: Missing `<checkpoint>` tags.** The xml-structure.md standard in this codebase documents that every stage must have a `<checkpoint>` attribute to define completion criteria. Current vault stages lack checkpoints, meaning the model has no success condition to verify.

**F7: CRITICAL annotation pattern already works.** The todo.md command uses `**CRITICAL**: This step MUST be executed` annotations on mandatory steps. This inline emphasis appears before the step content and is more reliably followed than stage-level conditions.

**F8: todo.md already embeds vault detection correctly.** The `/todo` command implements vault detection as subsection 5.8 under the "Archive Tasks" section -- flat numbering within the parent operation. The SKILL.md converted this to independent Stage 11, which signals independence and skippability to the LLM.

**F9: Invert conditional framing for mandatory stages.** Current vault stages start with "skip if not needed." Replace with: "ALWAYS execute this check. When vault_needed=false, record result and continue." This removes skippable framing entirely.

**F10: Inline state variables as execution contracts.** If step 9.2 references data from step 9.1, the model must have executed step 9.1 to have that data. Creating data dependencies between sub-steps enforces their execution.

## Synthesis

### Conflicts Resolved

**No significant conflicts.** Both teammates independently converged on the same diagnosis and solution structure. Teammate A provided external validation (Anthropic guides, community patterns), while Teammate B provided internal validation (existing codebase patterns that already work).

### Gaps Identified

1. **A/B testing of output text**: The exact wording needed to reliably trigger model action (e.g., "VAULT REQUIRED" vs "MANDATORY ACTION") has not been tested. Both teammates recommend unconditional output but acknowledge the specific phrasing is an inference.

2. **Stage consolidation scope**: Both teammates recommend removing vault stages 11-15, but neither fully addresses whether the remaining post-vault stages (16-21) should also be consolidated. The task description targets ~10-12 stages from current 21.

### Unified Recommendations

**Priority 1: Embed vault check as mandatory sub-step 9 in Stage 10**
- Move vault threshold detection from Stage 11 into Stage 10 as steps 9-9.4
- Use `**CRITICAL: MANDATORY - ALWAYS EXECUTE**` annotation
- Execute unconditional bash that outputs status for both conditions
- Add `<checkpoint>` tag: "vault_check_complete output present"
- Sub-steps 9.1-9.4 handle confirmation, creation, renumbering, state reset

**Priority 2: Remove separate vault stages 11-15**
- After consolidation, delete stages 11-15 entirely
- Renumber remaining stages (16-21 become 11-16)
- Reduces total stage count from 21 to 16

**Priority 3: Pre-commit safety net in GitCommit stage**
- Add bash check: if next_project_number > 1000, block commit with error message
- Acts as defense-in-depth if inline check was somehow bypassed
- Model cannot proceed to commit without resolving vault condition

**Priority 4: Add `<checkpoint>` tags to all stages**
- Every stage gets a checkpoint defining completion criteria
- Prevents future skip issues with other stages (stages 4, 6, 7, 8, 9 were also skipped in the failed test)

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary approaches (external sources) | completed | high |
| B | Alternative patterns (internal codebase) | completed | high |

## References

### External Sources (Teammate A)
- Anthropic: "The Complete Guide to Building Skills for Claude" (February 2026)
- Anthropic: Skill authoring best practices (platform docs)
- DEV Community: "5 Patterns That Make Claude Code Actually Follow Your Rules"
- DEV Community: "How to Stop Claude Code Skills from Drifting with Per-Step Constraint Design"
- DEV Community: "I Wrote 200 Lines of Rules for Claude Code. It Ignored Them All."

### Internal Sources (Teammate B)
- `.claude/context/core/standards/xml-structure.md` - checkpoint tag standard
- `.claude/commands/todo.md` section 5.8 - vault detection as inline subsection
- `.claude/skills/skill-status-sync/SKILL.md` - single-flow execution pattern
- `.claude/context/core/patterns/postflight-control.md` - bash output enforcement

## Next Steps

Run /plan 250 to create implementation plan based on these findings.

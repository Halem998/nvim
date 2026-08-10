# Seed Research Report: Task #599

**Task**: 599 — Update CLAUDE.md, extension integration, and documentation
**Source**: Task 591 team research (01_team-research.md + 4 teammate findings)
**Date**: 2026-05-22
**Purpose**: Distilled research findings relevant to documentation updates

## Overview

Task 599 is the final task in the refactoring wave, updating documentation to reflect all changes made in tasks 592-598. This task depends on all five preceding implementation tasks (594, 595, 596, 597, 598) because documentation must reflect the final implemented system, not the planned system.

## CLAUDE.md Regeneration Requirements

The `.claude/CLAUDE.md` file is auto-generated from loaded extensions. After the refactoring, it must be regenerated to reflect:

1. **New /orchestrate command**: Usage, behavior (fire-and-forget loop), flags (--auto), blocker escalation capability
2. **Updated command routing table**: Any new routing entries added by the refactoring
3. **New shared utilities**: Reference to `.claude/scripts/parse-command-args.sh`, `postflight-workflow.sh`, etc.
4. **Updated skill-to-agent mapping**: Any changes to which agents are invoked by which skills
5. **Progressive disclosure architecture**: New context tier system, budget caps by agent type

**Note (Teammate D)**: "CLAUDE.md is auto-generated from extension manifests. The documentation update should include converting the skill+command inventory to a form that can be validated by tooling."

## Extension Manifest Schema Updates (Teammate D)

If the refactoring changes the extension integration interface (lifecycle hooks), the manifest schema must be updated:

**New manifest fields** (if implemented in task 594):
```json
{
  "hooks": {
    "preflight": "scripts/nix-preflight.sh",
    "context_injection": "scripts/nix-context.sh",
    "postflight": "scripts/nix-postflight.sh"
  },
  "context_tier": 3,
  "context_budget": 8000
}
```

**Documentation required**:
- `.claude/context/guides/extension-development.md`: Update with lifecycle hooks section
- `.claude/extensions/README.md`: Update integration contract documentation
- Example extensions: Add hook examples to example extension

## Extension Compatibility Verification

**Critical note (Teammate C)**: "Extension compatibility verification cannot be the last step — it needs to be a gate on each of the preceding tasks."

By the time task 599 runs, all extension compatibility issues should have been identified and fixed in tasks 594-598. Task 599's role is to:
1. Run a final verification suite for all loaded extensions (nvim, nix)
2. Document any extension-specific migration notes
3. Update extension documentation for the new architecture

**Verification checklist**:
- [ ] `skill-neovim-research` produces correct output with /research task
- [ ] `skill-neovim-implementation` produces correct output with /implement task  
- [ ] `skill-nix-research` produces correct output with /research task
- [ ] `skill-nix-implementation` produces correct output with /implement task
- [ ] Extension-specific context is correctly injected into agent prompts
- [ ] Extension lifecycle hooks (if implemented) execute correctly

## Documentation Files to Update

Based on what changes in tasks 592-598:

| File | Update Required |
|------|----------------|
| `.claude/CLAUDE.md` | Full regeneration (auto-generated) |
| `.claude/context/architecture/system-overview.md` | Update three-layer architecture description |
| `.claude/docs/reference/creating-commands.md` | Reflect shared infrastructure patterns |
| `.claude/docs/reference/creating-skills.md` | Reflect shared base pattern, extension hooks |
| `.claude/docs/reference/creating-agents.md` | Reflect context budget requirements |
| `.claude/context/patterns/fork-patterns.md` | Update with operational constraints (5-min TTL, tool-set invariance) |
| `.claude/context/guides/extension-development.md` | Add lifecycle hooks documentation |
| `.claude/rules/workflows.md` | Update if GATE IN/OUT pattern changed |

## New Documentation to Create

Based on gaps identified in task 591 research:

| Document | Purpose | Identifies By |
|----------|---------|---------------|
| `context/patterns/orchestrator-state-machine.md` | /orchestrate design spec | Teammate A |
| `context/patterns/semi-autonomous-orchestration.md` | Confirmation gates vs autonomous pattern | Teammate D |
| `context/patterns/context-budget-tiers.md` | Tier definitions, budget caps, enforcement | Teammates A, D |
| `context/patterns/unified-postflight.md` | Parameterized OPERATION_TYPE pattern | Teammate B |
| `context/guides/extension-lifecycle-hooks.md` | Extension hook interface specification | Teammate D |

## system-overview.md Architecture Update

The current three-layer architecture (command → skill → agent) remains valid but must be updated to reflect:
1. Shared utilities layer (task 593)
2. Extension lifecycle hooks (task 594)
3. /orchestrate outer loop (task 596)
4. Context tier system (task 598)
5. Nested loop exclusivity pattern (tasks 594, 596)

## Source References

- `specs/591_research_claude_code_orchestration_practices/reports/01_team-research.md` — Section 6 (Extension system evolution), Section 7 (Missing prerequisites)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-a-findings.md` — Context Extension Recommendations section
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-b-findings.md` — Context Extension Recommendations section
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-c-findings.md` — Finding 5 (Extension integration points unspecified)
- `specs/591_research_claude_code_orchestration_practices/reports/01_teammate-d-findings.md` — Finding 2 (Extension system evolution), Context Extension Recommendations section

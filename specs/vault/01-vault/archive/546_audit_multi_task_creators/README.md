# Task 546: Audit and Align Other Multi-Task Creators For Consistent Insertion

- **Effort**: 1-2 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: Task #545

## Description

Apply the hardened insertion pattern from task 545 to all other multi-task creators in the system.

### Scope

1. Audit skill-fix-it (`SKILL.md` line ~466) — already says "Prepend new task entry" but uses abstract pseudocode
2. Audit /review, /errors, `/task --review` for similar patterns
3. Replace any abstract pseudocode with the concrete Edit tool pattern from task 545
4. Update `multi-task-creation-standard.md` component 8 (State Updates) with the hardened pattern
5. Ensure all creators pass through the same insertion logic for consistent, predictable TODO.md ordering

### Key Files

- `.opencode/skills/skill-fix-it/SKILL.md`
- `.opencode/skills/skill-test/SKILL.md` (if applicable)
- `.opencode/docs/reference/standards/multi-task-creation-standard.md`
- Any other skill/agent that creates TODO.md task entries

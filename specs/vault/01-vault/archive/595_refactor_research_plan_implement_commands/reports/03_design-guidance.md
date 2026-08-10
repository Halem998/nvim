# Design Guidance: Task 595 — Refactor /research, /plan, /implement Commands

**Source**: Task 592 architecture design
**Authoritative Reference**: `.claude/docs/architecture/architecture-spec.md` Components 1-2
**Depends on**: Tasks 593 (shared utilities), 594 (skill base), 598 (context budgets)
**Blocks**: Task 597

---

## Overview

Task 595 completes the command refactoring started by task 593. Commands are already thin after
task 593 extracted parse-command-args.sh, command-gate-in.sh, and command-gate-out.sh. Task 595
focuses on three remaining concerns:

1. Enforcing the Tier 2 (command-level) context limit (routing only, no agent-level context)
2. Adding `orchestrator_mode=true` support to skills
3. Verifying extension compatibility after all previous refactoring

---

## Target Command Structure

Each command retains ONLY:

```markdown
---
# YAML frontmatter: allowed-tools, argument-hint, model
---

# Command Name

## Anti-bypass Constraint
[PROHIBITION section — cannot be removed]

## Usage
[Argument documentation — 10 lines max]

## Stage 1: Parse Arguments
source .claude/scripts/parse-command-args.sh "$ARGUMENTS"

## Stage 1.5: Multi-task dispatch
[Batch loop when len(TASK_NUMBERS) > 1, ~40 lines]

## Stage 2: Gate In
source .claude/scripts/command-gate-in.sh "$task_number" "$operation"

## Stage 3: Route to Skill
[Extension routing table (research.md) OR single skill call (~10 lines)]

## Stage 4: Gate Out
source .claude/scripts/command-gate-out.sh "$task_number" "$operation" "$SESSION_ID"

## Stage 5: Commit
[Git commit block, ~15 lines]
```

**Target**: 150-200 lines per command.
**Context tier**: Commands occupy Tier 2 ONLY. No Tier 3 content (agent-level context).

---

## Routing-Only Controller Pattern

The routing-only controller pattern separates concerns:

| Layer | Responsibility | Context Tier |
|-------|---------------|-------------|
| Command | Parse args → route to skill | Tier 2 (routing tables, arg docs) |
| Skill | Validate → preflight → invoke agent → postflight | Tier 2 (skill lifecycle) |
| Agent | Execute work, read domain context | Tier 3 (agent context files) |

**Critical rule**: Commands MUST NOT contain logic that belongs at the agent level. This includes:
- State machine logic (move to agent context)
- Format specifications (move to Tier 3 context files)
- Domain knowledge (move to extension context)
- Error handling beyond "did the skill succeed?" (belongs in skill/agent)

---

## Context Tier Enforcement

### Tier 2 Content (stays in command file)

- Argument parsing (via parse-command-args.sh)
- Extension routing table (`task_type` → skill name mapping)
- Gate in/out invocations
- Batch loop for multi-task dispatch

### Content That Must Move OUT of Commands

| Current Location | Move To | Tier |
|-----------------|---------|------|
| Full state machine logic in implement.md | Agent context file | 3 |
| Format specifications in plan.md | Agent context file | 3 |
| Detailed workflow patterns in research.md | Agent context files | 3 |

After cleanup, command files should contain NO reference to:
- Specific JSON schemas
- Step-by-step agent workflows
- Context budget rules
- Domain-specific patterns

---

## orchestrator_mode Support

### What Each Skill Must Implement

When `"orchestrator_mode": true` appears in delegation context, skills must:

1. **Detect the flag**:
   ```bash
   orchestrator_mode=$(echo "$delegation_context" | jq -r '.orchestrator_mode // "false"')
   ```

2. **Write `.orchestrator-handoff.json`** to `specs/{NNN}_{SLUG}/`:
   ```json
   {
     "$schema": "orchestrator-handoff-v1",
     "phase": "research | plan | implement",
     "status": "researched | planned | implemented | partial | blocked",
     "summary": "2-4 sentences",
     "artifacts": [...],
     "blockers": [...],
     "next_action_hint": "plan | implement | revise | none"
   }
   ```

3. **For skill-implementer ONLY**: When `orchestrator_mode=true`, disable inner continuation loop:
   ```bash
   if [ "$orchestrator_mode" = "true" ]; then
     max_continuations=0
   else
     max_continuations=3
   fi
   ```

### Test Case for orchestrator_mode

Before completing task 595, verify:
1. Set `orchestrator_mode=true` in a test delegation context
2. Invoke skill-researcher — verify `.orchestrator-handoff.json` written
3. Verify handoff content matches schema (phase, status, summary, artifacts)
4. Invoke skill-implementer — verify inner loop disabled (check loop guard behavior)

---

## Extension Compatibility

After refactoring commands and skills, verify extension integrations still work:

### Nvim Extension
```bash
# Test: /research a neovim task
/research {neovim-task-number}
# Verify: skill-neovim-research invoked (not skill-researcher)
# Verify: output artifact created in correct directory
```

### Nix Extension
```bash
# Test: /implement a nix task
/implement {nix-task-number}
# Verify: skill-nix-implementation invoked
# Verify: status transitions correct
```

### Check Routing Table
The extension routing table in research.md must still map task_type correctly:
```
general/meta/markdown → skill-researcher
neovim → skill-neovim-research
nix → skill-nix-research
```

This table is Tier 2 content (stays in command file).

---

## Verification

```bash
# Verify command line counts
wc -l .claude/commands/research.md .claude/commands/plan.md .claude/commands/implement.md
# Each: 150-200 lines

# Verify no Tier 3 content in commands
# (manual review: search for state machine logic, format specs, domain knowledge)
grep -n "State Machine\|JSON schema\|format specif" .claude/commands/research.md
# Should return 0 matches

# Functional test suite
# 1. Research task → researched status
# 2. Plan task → planned status
# 3. Implement task → completed status
# 4. Multi-task: /research 593, 594 → both complete
# 5. Extension: research/plan/implement neovim task
```

# Task 268: Update manifest.json Routing Table with Per-Type Keys

**Status**: Research Complete
**Created**: 2026-03-24
**Dependencies**: Task #264, #265, #266, #267

---

## Problem Statement

The founder extension's manifest.json routing table has per-type keys for research but uses a single key for plan and implement. This means the routing system cannot distinguish between task types at the plan and implement phases.

## Current Routing Table

```json
{
  "routing": {
    "research": {
      "founder": "skill-market",
      "founder:market": "skill-market",
      "founder:analyze": "skill-analyze",
      "founder:strategy": "skill-strategy",
      "founder:legal": "skill-legal",
      "founder:project": "skill-project"
    },
    "plan": {
      "founder": "skill-founder-plan"
    },
    "implement": {
      "founder": "skill-founder-implement"
    }
  }
}
```

### Why This Is a Problem

1. The `/research` command reads `task_type` from state.json and constructs a composite key `founder:{task_type}` for routing. This works because all 5 types have explicit entries.

2. The `/plan` and `/implement` commands use the same pattern, but only find the bare `founder` key. This means:
   - All task types route to the same planner and implementer
   - No ability to route legal or project to type-specific skills if needed
   - The routing system loses information about which type is being processed

3. While the shared planner/implementer works for market/analyze/strategy (they use content detection), adding explicit per-type keys ensures the routing system is complete and future-proof.

## Proposed Routing Table

```json
{
  "routing": {
    "research": {
      "founder": "skill-market",
      "founder:market": "skill-market",
      "founder:analyze": "skill-analyze",
      "founder:strategy": "skill-strategy",
      "founder:legal": "skill-legal",
      "founder:project": "skill-project"
    },
    "plan": {
      "founder": "skill-founder-plan",
      "founder:market": "skill-founder-plan",
      "founder:analyze": "skill-founder-plan",
      "founder:strategy": "skill-founder-plan",
      "founder:legal": "skill-founder-plan",
      "founder:project": "skill-founder-plan"
    },
    "implement": {
      "founder": "skill-founder-implement",
      "founder:market": "skill-founder-implement",
      "founder:analyze": "skill-founder-implement",
      "founder:strategy": "skill-founder-implement",
      "founder:legal": "skill-founder-implement",
      "founder:project": "skill-founder-implement"
    }
  }
}
```

### Design Decision: Shared vs Per-Type Skills

All 5 types route to the **same** planner and implementer. This is intentional:

- The **real differentiation** happens at the research phase (5 different agents with different forcing questions, MCP tools, and domain expertise)
- The **planner** uses content detection on the research report to determine phase structure - this works for all types after tasks 264 and 266 add legal and project support
- The **implementer** uses type detection from the plan to select phase flow - this works for all types after tasks 265 and 267 add legal and project support

If a type ever needs a dedicated planner or implementer, the routing table already has the per-type key - just change the skill name.

### Default Key Behavior

The bare `founder` key serves as the fallback for tasks that don't have a `task_type` field. This handles legacy tasks or tasks created before the task_type convention was established.

## Files Affected

- `.claude/extensions/founder/manifest.json` - update routing section

## Also Update

- `.claude/extensions/founder/EXTENSION.md` - update routing table documentation
- `.claude/extensions/founder/README.md` - update routing reference if present

## Verification

After updating, verify that the routing works correctly:
1. Create a task with `language: "founder"` and `task_type: "legal"`
2. Run `/plan N` - should route to skill-founder-plan
3. Run `/implement N` - should route to skill-founder-implement
4. The agents should detect the legal type and use correct phase structure

## Effort Estimate

30 minutes - straightforward JSON editing with documentation updates.

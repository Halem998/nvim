# Task 545: Harden TODO.md Insertion Ordering in meta-builder-agent

- **Effort**: 1-2 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: None

## Description

Update `meta-builder-agent.md` Stage 6 (CreateTasks + Status Updates) to replace the abstract `insert_after_heading("## Tasks", batch_markdown)` pseudocode with an explicit, LLM-proof Edit tool invocation.

### Problem

The meta-builder-agent spec already specifies correct behavior:
- Stage 6 says "insert after `## Tasks` heading" (TOP insertion)
- Topological sort (Kahn's algorithm) orders foundational tasks first

But `insert_after_heading()` is pseudocode — the LLM must interpret it. This caused task 544 to be appended at the bottom instead of prepended at the top.

### Fix

1. Replace `insert_after_heading("## Tasks", batch_markdown)` with a concrete Edit tool call:
   ```
   oldString: "## Tasks\n"
   newString: "## Tasks\n\n{batch_markdown}\n"
   ```
2. Add post-insertion verification: re-read the first task after `## Tasks` and confirm it matches the foundational task number
3. Add a bold warning: "DO NOT search for the last `---` separator or append at bottom"
4. Sync changes to `.opencode/extensions/core/agents/meta-builder-agent.md`

### Key Files

- `.opencode/agent/subagents/meta-builder-agent.md`
- `.opencode/extensions/core/agents/meta-builder-agent.md` (core mirror)

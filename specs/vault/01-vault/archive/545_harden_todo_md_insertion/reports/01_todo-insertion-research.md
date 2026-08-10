# Research Report: Task #545

**Task**: 545 - Harden TODO.md insertion ordering in meta-builder-agent
**Started**: 2026-05-07T00:00:00Z
**Completed**: 2026-05-07T00:00:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: 
- `.opencode/agent/subagents/meta-builder-agent.md` (full read)
- `.opencode/extensions/core/agents/meta-builder-agent.md` (core mirror, full read)
- `.opencode/docs/reference/standards/multi-task-creation-standard.md` (full read)
- `.opencode/skills/skill-fix-it/SKILL.md` (lines 450-529)
- `specs/TODO.md` (full read)
- `.opencode/agent/subagents/general-implementation-agent.md` (lines 110-189)
- `.opencode/commands/review.md` (lines 1050-1095)
- `.opencode/extensions/core/skills/skill-spawn/SKILL.md` (lines 330-345)
- `.opencode/context/formats/return-metadata-file.md` (full read)
**Artifacts**: 
- `specs/545_harden_todo_md_insertion/reports/01_todo-insertion-research.md`
**Standards**: report-format.md, return-metadata-file.md

## Executive Summary
- The abstract `insert_after_heading("## Tasks", batch_markdown)` pseudocode in meta-builder-agent.md caused task 544 to be inserted at the bottom of TODO.md instead of prepended at the top.
- Three documents contain the vulnerable pseudocode: the main agent definition, the core mirror (identical), and the multi-task-creation-standard.md.
- Other multi-task creators (skill-fix-it, skill-spawn) use similarly abstract "prepend" prose with no concrete Edit tool invocation, making them also vulnerable.
- The recommended fix is a concrete Edit tool pattern using `oldString:"## Tasks\n"` → `newString:"## Tasks\n\n{batch}\n"` with mandatory post-insertion re-read verification.
- Both agent files need syncing, and the standard document needs updating as a precedent for all multi-task creators.

## Context & Scope

Task 545 addresses an insertion-ordering defect in the meta-builder-agent. When task 544 was created during a prior meta-builder-agent execution, the implementing LLM followed the pseudocode incorrectly and appended tasks at the bottom of the Tasks section rather than prepending them at the top (after `## Tasks`). This violates the topological ordering guarantee: foundational tasks (those with no dependencies) must appear first in the file so users see them at the top.

The scope covers:
1. Hardening `meta-builder-agent.md` (main copy: `.opencode/agent/subagents/meta-builder-agent.md`)
2. Syncing the core mirror (`.opencode/extensions/core/agents/meta-builder-agent.md`)
3. Updating `multi-task-creation-standard.md` component 8 with the hardened pattern
4. Leaving audit trails for all other multi-task creators

## Findings

### 1. All Locations of TODO.md Insertion Pseudocode

#### 1A. Primary: meta-builder-agent.md Stage 6 (CreateTasks) — Lines 699-737

The critical pseudocode block:

```python
# Join all entries (foundational tasks first in the string)
batch_markdown = "\n\n".join(batch_entries)

# Insert entire batch after ## Tasks heading
# This preserves order: first entry in batch appears first in file
insert_after_heading("## Tasks", batch_markdown)
```

The preceding commentary at lines 739 explains the intent:
> **Why batch insertion matters**: With prepend-each semantics, the last task created ends up at the top of TODO.md. Batch insertion ensures the first task in `sorted_indices` (foundational) appears first in the file. Users then see tasks in dependency order: complete the top task first.

**Problem**: `insert_after_heading()` is a fictional function with no concrete tool mapping. An LLM searching for a heading marker has multiple plausible strategies, and the most obvious one — search for the last `---` separator before the heading — would produce append-at-bottom behavior.

#### 1B. Secondary: meta-builder-agent.md Stage 6 (Status Updates) — Lines 1334-1359

This section restates the batch insertion in prose without even the pseudocode function:

> 2. **Insert batch into TODO.md**:
>    - Insert the entire batch after `## Tasks` heading (before existing tasks)
>    - This preserves topological order: foundational tasks appear higher in the file
>    - The batch as a whole is "prepended" to existing tasks

Again, no concrete Edit tool invocation — relies entirely on the LLM's interpretation of "insert after heading."

#### 1C. Standard Document: multi-task-creation-standard.md — Lines 323-335

Component 8 (State Updates) mirrors the same abstract pattern:

```python
# Build all entries in sorted order (foundational first)
batch_entries = []
for position, task_idx in enumerate(sorted_indices):
    batch_entries.append(format_entry(task_idx))

# Join and insert entire batch after ## Tasks heading
batch_markdown = "\n\n".join(batch_entries)
insert_after_heading("## Tasks", batch_markdown)
```

**Impact**: This document serves as the normative standard for all multi-task creators. The abstract pseudocode here propagates the vulnerability to every future creator that references this standard.

### 2. Core Mirror Analysis

The core mirror at `.opencode/extensions/core/agents/meta-builder-agent.md` is **identical** to the main copy (same line count of 1407, same content on all insertion pseudocode lines). It must be synced with the same changes.

One trivial difference: the core mirror uses `AGENTS.md` instead of `AGENTS.md` in the Constraints section (line 29 vs line 29), but this is incidental. The mirror uses `ls .opencode/agents/*.md` in its inventory step (line 159) vs `ls .opencode/agent/subagents/*.md` in the main copy, but this does not affect insertion logic.

**Decision**: Both files must receive identical hardening changes.

### 3. How Other Multi-Task Creators Handle Insertion

#### 3A. skill-fix-it — Lines 464-466

> Prepend new task entry to `## Tasks` section (new tasks at top):

Abstract prose only. No Edit tool invocation. An LLM following this instruction could append or prepend.

**Severity**: High. fix-it creates tasks in batches and is actively used.

#### 3B. skill-spawn — Line 345

> Use Edit tool to insert each task entry at the top of the Tasks section (after `## Tasks` header).

Better — explicitly mentions the Edit tool and the insertion point. But it provides no `oldString`/`newString` pattern. An LLM still needs to invent the concrete invocation.

**Severity**: Medium. Better guidance but still abstract.

#### 3C. /review command — Lines 1085-1095

Has a concrete Edit tool pattern for inserting before `## Tasks`:

```
# Use Edit tool:
old_string = "\n## Tasks"
new_string = "\n{category_block}\n\n## Tasks"
```

**This is the closest precedent for what meta-builder-agent should use**, but inverted direction (inserts *before* the heading rather than *after*).

#### 3D. general-implementation-agent — Lines 118-124

Uses concrete Edit tool invocations for plan phase markers:

```
old_string: `### Phase {P}: {Phase Name} [NOT STARTED]`
new_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
```

This demonstrates the system's preferred Edit tool pattern: the `oldString` is the exact text to find and replace.

### 4. Existing Concrete Edit Tool Patterns

From analysis of the codebase, the canonical Edit tool usage pattern is:

| Pattern | Example | Source |
|---------|---------|--------|
| **Heading-anchored replacement** | `old: "### Phase 1: ... [NOT STARTED]"` → `new: "### Phase 1: ... [IN PROGRESS]"` | general-implementation-agent:120-123 |
| **Insert-before-heading** | `old: "\n## Tasks"` → `new: "\n{block}\n\n## Tasks"` | /review:1085-1094 |
| **Exact match replacement** | `old: "- **Status**: [BLOCKED]"` → `new: "- **Status**: [BLOCKED]\n- **Dependencies**: Task #242"` | skill-spawn:384-386 |

The **heading-anchored replacement** pattern is the most proven and least ambiguous. It works because the heading text is unique in the file, making the match unambiguous.

### 5. Root Cause of the Task 544 Bug

The `insert_after_heading("## Tasks", batch_markdown)` pseudocode leaves too much room for interpretation. An LLM has to:
1. Decide how to find "`## Tasks`" in the file
2. Decide what "after" means (after the heading line? after the heading section?)
3. Decide which tool to use (Write vs Edit)

A plausible wrong path:
```
1. Read TODO.md
2. Find "## Tasks" heading
3. Find the last "---" separator to find the end of the Tasks section
4. Insert new entries after that separator → bottom of file
```

This produces the observed bug: task 544 was placed at the bottom rather than the top.

### 6. Current TODO.md State Confirmation

Examining `specs/TODO.md` after task 544 was created:
- The Task Order section (line 7-33) shows 544 correctly in the Pending category at line 22
- The Tasks section (line 35+) shows tasks in order: 547 (line 37), 545 (line 49), 546 (line 61)
- Task 544 does NOT appear in the Tasks section at all, confirming the insertion bug

## Decisions

1. **Adopt heading-anchored replacement pattern**: Replace `insert_after_heading()` with a concrete Edit tool invocation using `## Tasks\n` as the `oldString` anchor. This pattern is already proven throughout the codebase for status marker updates and has no ambiguity.

2. **Mandatory post-insertion verification**: After editing, the agent MUST re-read the first task entry after `## Tasks` and confirm the task number matches the first entry in `sorted_indices`. This catches LLM errors immediately.

3. **Add anti-pattern warning**: Explicitly warn against searching for `---` separators or the last task entry. State: "DO NOT search for the last `---` or append. Replace `## Tasks\n` with `## Tasks\n\n{batch}`."

4. **Sync both copies**: The core mirror (`extensions/core/agents/`) must receive identical changes atomically with the main copy.

5. **Update the standard**: `multi-task-creation-standard.md` component 8 must receive the hardened pattern as a precedent for all multi-task creators. This sets a future expectation but does not immediately change other creators.

## Recommendations

1. **[meta-builder-agent.md] Replace pseudocode at lines 736 with concrete Edit invocation**:
   ```
   Replace:
     insert_after_heading("## Tasks", batch_markdown)
   With:
     Use the Edit tool with:
     - old_string: "## Tasks\n"
     - new_string: "## Tasks\n\n{batch_markdown}\n"
   ```
   Priority: High | Owner: Task 545 implementation

2. **[meta-builder-agent.md] Add post-insertion verification**:
   After the Edit tool call, re-read `specs/TODO.md` and verify that the text immediately after `## Tasks\n` begins with the first task in `sorted_indices`. Add a concrete check:
   ```
   Read specs/TODO.md. Verify the first task after "## Tasks" heading
   matches the expected foundational task number ({first_task_num}). If not, abort and report.
   ```
   Priority: High | Owner: Task 545 implementation

3. **[meta-builder-agent.md] Add anti-pattern warning**:
   Add a bold warning in Stage 6 before the insertion pattern:
   ```
   **WARNING**: DO NOT search for the last `---` separator or the end of the file to
   determine insertion point. Tasks MUST be prepended immediately after `## Tasks\n`.
   DO NOT append at the bottom. The Edit tool's oldString must
   be exactly `## Tasks\n` — nothing more, nothing less.
   ```
   Priority: High | Owner: Task 545 implementation

4. **[Core mirror] Sync identical changes**: Apply the same modifications to `.opencode/extensions/core/agents/meta-builder-agent.md`. Priority: High | Owner: Task 545 implementation

5. **[multi-task-creation-standard.md] Update component 8**: Replace the abstract `insert_after_heading()` with the concrete Edit tool pattern. Priority: Medium | Owner: Task 545 or 546

6. **[skill-fix-it] Audit and update**: Replace "Prepend new task entry to `## Tasks` section" prose with concrete Edit tool pattern. Priority: Medium | Owner: Task 546

7. **[skill-spawn] Harden**: Add explicit `oldString`/`newString` values to the existing Edit tool guidance. Priority: Medium | Owner: Task 546

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `## Tasks\n` is not unique enough (e.g., appears in comments) | Low | Edit fails or edits wrong location | `## Tasks` is a level-2 heading; no other `## Tasks` heading exists in TODO.md |
| Batch markdown contains `## Tasks\n` substring | Very Low | Infinite replacement loop or corruption | Task markdown uses `### N.` headings (level-3), never `##` (level-2) |
| LLM ignores the pattern and invents its own | Medium | Same bug recurs | Post-insertion re-read verification catches this immediately; the anti-pattern warning in bold increases compliance |
| `\n` literal vs actual newline confusion | Medium | oldString doesn't match | Use explicit `\n` in the spec prose but ensure the Edit tool receives literal newline characters; implementation should test this |
| Core mirror gets out of sync again | Low | Task creations from extensions differ | Both copies modified atomically in the same implementation |

## Context Extension Recommendations

- **Topic**: TODO.md insertion patterns for multi-task creators
- **Gap**: No single authoritative context file documents the concrete Edit tool pattern for prepending tasks after `## Tasks`. The pattern exists only in agent definition files, which are operational, not reference.
- **Recommendation**: Create `.opencode/context/patterns/todo-insertion-pattern.md` documenting the canonical Edit tool invocation (`oldString:"## Tasks\n"` → `newString:"## Tasks\n\n{entries}\n"`) with anti-patterns and verification steps. Reference this from `multi-task-creation-standard.md` instead of duplicating the pseudocode.

## Appendix

### Search Queries Used
- Read: `meta-builder-agent.md` (main and core mirror), full files
- Read: `multi-task-creation-standard.md`, full file
- Read: `skill-fix-it/SKILL.md`, lines 450-529 (insertion + TODO.md update sections)
- Read: `general-implementation-agent.md`, lines 110-189 (Edit tool patterns)
- Read: `review.md`, lines 1050-1095 (insertion-after-heading patterns)
- Read: `skill-spawn/SKILL.md`, lines 330-345 (TODO.md insertion)
- Read: `specs/TODO.md`, full file
- Read: `return-metadata-file.md`, full file
- Grep: `Edit tool|Edit invocation|oldString|newString` across `.opencode/` — 127 matches analyzed

### Reference Documentation
- `.opencode/context/formats/return-metadata-file.md` — Metadata file schema
- `.opencode/docs/reference/standards/multi-task-creation-standard.md` — 8-component standard
- `.opencode/agent/subagents/meta-builder-agent.md` — Reference implementation (needs hardening)
- `.opencode/extensions/core/agents/meta-builder-agent.md` — Core mirror (needs syncing)

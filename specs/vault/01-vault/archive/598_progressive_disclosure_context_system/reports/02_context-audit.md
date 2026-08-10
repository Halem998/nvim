# Research Report: Task 598 — Context Index Audit

**Task**: 598 - progressive_disclosure_context_system
**Started**: 2026-05-22T14:30:00Z
**Completed**: 2026-05-22T15:15:00Z
**Effort**: 1.5 hours
**Dependencies**: Task 591 (seed research), Task 592 (design guidance)
**Sources/Inputs**:
- `.claude/context/index.json` (139 entries, fully read)
- `specs/598_progressive_disclosure_context_system/reports/01_seed-research.md`
- `specs/598_progressive_disclosure_context_system/reports/03_design-guidance.md`
- `.claude/docs/architecture/architecture-spec.md`
- Filesystem verification of all 139 index paths
**Artifacts**: `specs/598_progressive_disclosure_context_system/reports/02_context-audit.md`
**Standards**: report-format.md, artifact-formats.md

---

## Executive Summary

- The context index has grown to **139 entries** (vs. the 97 cited in task description), covering 34,712 total lines across core and project domains.
- **Zero entries** currently have `tier` or `token_cost_estimate` fields — full classification is needed.
- **One file is missing** from disk: `README.md` (the always-loaded root index, 202 lines). All 138 other files exist.
- **Three files exist on disk but are NOT in the index**: `patterns/context-exhaustion-detection.md` (225L), `patterns/subagent-continuation-loop.md` (209L), and `project/memory/README.md` (14L).
- **One dead entry** confirmed: `reference/artifact-templates.md` has empty `agents`, `commands`, and `task_types` arrays and `always: false` — it is never auto-loaded.
- All agent token budgets **exceed** the proposed caps: sonnet workers range from 19K–24K tokens (cap: 8K), opus agents range from 23K–116K tokens (cap: 15K). Significant pruning and tier-splitting is required.

---

## Context & Scope

This audit covers all 139 entries in `.claude/context/index.json`, classifying each into the four-tier model defined in the architecture spec (task 592/design guidance). The four-tier model is:

| Tier | Load Trigger | Budget | Content |
|------|-------------|--------|---------|
| 1 (always) | Every invocation | ~500 lines (~4K tokens) | Anti-stop patterns, return-metadata schema, checkpoint-execution |
| 2 (command) | On command detection | ~500 lines (~4K tokens) | Routing tables, argument docs, anti-bypass PROHIBITION |
| 3 (agent) | At agent spawn | ~3-5K lines (8K–15K tokens) | Workflow patterns, domain context, format specifications |
| 4 (on-demand) | Via `@`-ref in agent | Unbounded | Detailed guides, templates, examples, appendices |

Budget caps per agent class: sonnet workers ≤ 8K tokens, opus planners ≤ 15K tokens, haiku utilities ≤ 2K tokens.

---

## Findings

### 1. Index Statistics

| Metric | Count |
|--------|-------|
| Total entries | 139 |
| Core domain entries | 99 (29,032 lines) |
| Project domain entries | 40 (5,680 lines) |
| Always-loaded (`always: true`) | 6 (946 lines) |
| Agent-specific entries | 98 |
| Command-loaded entries | 54 |
| Task-type-loaded entries | 71 |
| Entries with `tier` field | 0 |
| Entries with `token_cost_estimate` | 0 |
| Missing files | 1 (`README.md`) |
| Files on disk not in index | 3 |
| Dead entries (never auto-loaded) | 1 |

### 2. Tier 1 Analysis — Current State vs. Architecture Requirement

**Current always-loaded entries (6 total, 946 lines, ~7,568 tokens):**

| Path | Lines | Assessment |
|------|-------|------------|
| `README.md` | 202 | FILE MISSING. Tier 1 designation questionable — an index doc, not operational |
| `checkpoints/README.md` | 100 | Tier 1 questionable — documentation index for humans, not needed by agents |
| `patterns/context-discovery.md` | 209 | Tier 3 candidate — needed by agents that query the index, not every call |
| `patterns/jq-escaping-workarounds.md` | 262 | Tier 3 candidate — needed by implementation/meta agents running bash jq |
| `reference/README.md` | 29 | Tier 4 candidate — tiny documentation index |
| `repo/project-overview.md` | 144 | Tier 1 justified — project structure overview needed by all agents |

**Architecture spec specifies Tier 1 should contain:** anti-stop patterns, return-metadata schema, checkpoint-execution. None of these are in the current always-loaded set.

**True Tier 1 candidates** (currently NOT always-loaded):

| Path | Lines | Current Load | Why Tier 1 |
|------|-------|-------------|------------|
| `patterns/anti-stop-patterns.md` | 174 | general-research-agent, planner-agent, general-implementation-agent | Must prevent premature stopping in ALL agents |
| `formats/return-metadata-file.md` | 502 | same 3 agents | All subagents MUST write correct metadata to function |
| `patterns/checkpoint-execution.md` | 254 | general-implementation-agent + /implement | All agents use checkpoints |

Note: 174 + 502 + 254 = 930 lines — these three alone would hit the ~500L Tier 1 budget. The architecture spec Tier 1 budget needs revisiting, or `return-metadata-file.md` (502L) needs trimming.

**Revised Tier 1 recommendation:** `repo/project-overview.md` (144L) + `patterns/anti-stop-patterns.md` (174L) = 318 lines. Keep these two. Move the rest to Tier 3 or Tier 4.

### 3. Missing File — README.md

The entry for `README.md` with `always: true` references a file that does not exist at `.claude/context/README.md`. This has been the case since the index was created. Options:
1. Create the file (it would serve as the context directory index)
2. Remove the entry from the index

### 4. Unindexed Files on Disk

Three files exist on disk but are not in `index.json`:

| File | Lines | Content |
|------|-------|---------|
| `patterns/context-exhaustion-detection.md` | 225 | Context pressure monitoring, handoff triggers — Tier 3 candidate for implementation agent |
| `patterns/subagent-continuation-loop.md` | 209 | Multi-subagent continuation for long tasks — Tier 3 candidate for implementation agent |
| `project/memory/README.md` | 14 | Stub file listing memory documentation — Tier 4 |

Both pattern files were created 2026-05-04 and appear to be new additions that were not added to the index.

### 5. Dead Entry — reference/artifact-templates.md

`reference/artifact-templates.md` (50 lines) has all empty `load_when` arrays and `always: false`. It is never auto-loaded. The file exists on disk. Options:
1. Add to Tier 4 classification (intentionally never auto-loaded, accessible via `@`-ref)
2. Add to an appropriate agent's Tier 3 list if needed
3. Delete the index entry (file remains on disk, agents can still `@`-ref it)

### 6. Agent Budget Analysis — Current vs. Proposed Caps

Token estimate formula: `line_count * 8 tokens/line`

| Agent | Class | Current Lines | Current Tokens | Budget Cap | Gap |
|-------|-------|--------------|---------------|------------|-----|
| `general-research-agent` | Sonnet | 2,402 | 19,216 | 8,000 | -11,216 |
| `planner-agent` | Opus | 2,845 | 22,760 | 15,000 | -7,760 |
| `general-implementation-agent` | Sonnet | 3,443 | 27,544 | 8,000 | -19,544 |
| `meta-builder-agent` | Opus | 14,512 | 116,096 | 15,000 | -101,096 |
| `neovim-implementation-agent` | Sonnet | 3,003 | 24,024 | 8,000 | -16,024 |
| `neovim-research-agent` | Sonnet | 2,303 | 18,424 | 8,000 | -10,424 |
| `nix-research-agent` | Sonnet | 1,590 | 12,720 | 8,000 | -4,720 |
| `nix-implementation-agent` | Sonnet | 1,590 | 12,720 | 8,000 | -4,720 |
| `code-reviewer-agent` | Sonnet | 693 | 5,544 | 8,000 | +2,456 ✓ |
| `spawn-agent` | Sonnet | 566 | 4,528 | 8,000 | +3,472 ✓ |

Only `code-reviewer-agent` and `spawn-agent` are currently within budget. The `meta-builder-agent` is the most extreme outlier at 116K tokens vs. 15K cap.

**Note on double-loading**: Many entries are registered for BOTH agents AND commands (e.g., `processes/research-workflow.md` is loaded for both `/research` command AND `general-research-agent`). This causes double-loading. Under the four-tier model, these should be moved to agent-only (Tier 3) and removed from command loading.

### 7. meta-builder-agent Context Breakdown

The `meta-builder-agent` has 42 entries (14,512 lines, ~116K tokens) — 7.7x over the 15K opus cap. The heaviest entries:

| Lines | Path | Assessment |
|-------|------|------------|
| 965 | `formats/command-structure.md` | Tier 4 — reference template, rarely needed in full |
| 876 | `orchestration/orchestrator.md` | Tier 3 — needed for building orchestrators |
| 859 | `orchestration/delegation.md` | Tier 3 — delegation patterns |
| 757 | `orchestration/architecture.md` | Tier 3/4 — architecture docs |
| 709 | `standards/xml-structure.md` | Tier 3/4 — XML prompt structure |
| 705 | `formats/frontmatter.md` | Tier 3/4 — frontmatter spec |
| 699 | `orchestration/validation.md` | Tier 3/4 — validation patterns |
| 589 | `workflows/preflight-postflight.md` | Tier 4 — detailed reference |

Recommendation: Many of these are detailed reference guides that should be Tier 4 (on-demand), with the agent loading them via `@`-ref only when building specific component types.

### 8. Command Loading Analysis

**Total lines loaded per command (including agent-overlap):**

| Command | Lines Loaded | Assessment |
|---------|-------------|------------|
| `/meta` | 7,327 | Far too high — most is Tier 3 agent content |
| `/implement` | 2,559 | Too high — processes/workflow.md should be agent-only |
| `/plan` | 1,961 | Too high — workflow.md, task-breakdown.md should be agent-only |
| `/research` | 1,281 | Too high — research-workflow.md should be agent-only |

The key issue: large files like `processes/research-workflow.md` (628L), `processes/planning-workflow.md` (540L), and `processes/implementation-workflow.md` (576L) are registered for both their commands AND their agents. Under the tier model, these are Tier 3 (agent-only). Commands should NOT load them.

**Command-only entries (no agent overlap) — potential true Tier 2:**

| Command | Lines | Path |
|---------|-------|------|
| `/errors` | 1,056 | `standards/error-handling.md` |
| `/errors, /fix-it` | 599 | `repo/self-healing-implementation-details.md` |
| `/errors, /fix-it` | 337 | `troubleshooting/workflow-interruptions.md` |
| `/research, /plan, /implement` | 522 | `patterns/multi-task-operations.md` |
| `/task, /todo` | 375 | `standards/task-management.md` |
| `/task, /todo` | 352 | `reference/state-management-schema.md` |
| `/task, /todo` | 337 | `orchestration/state-management.md` |

These are loaded only by commands (no agent overlap), but several are very large (1,056L for error-handling). Under the tier model, large command-only entries should be Tier 4 (on-demand), accessed by commands via `@`-ref only when needed.

### 9. Task-Type-Only Entries Analysis

29 entries are loaded for task_type `meta` but have no agent assignment. These are loaded for `/meta` command usage scenarios. Most are Tier 3 or Tier 4 content that should be moved to agent-specific loading instead of task_type-based loading.

High-priority task-type-only entries to assess:

| Lines | Path | Current | Proposed |
|-------|------|---------|----------|
| 571 | `standards/git-safety.md` | meta task_type | Tier 3 → meta-builder-agent |
| 400 | `reference/team-wave-helpers.md` | meta task_type | Tier 3 → meta-builder-agent |
| 313 | `orchestration/subagent-validation.md` | meta task_type | Tier 3 → meta-builder-agent |
| 301 | `patterns/file-metadata-exchange.md` | meta task_type | Tier 3 → meta-builder-agent |
| 265 | `patterns/postflight-control.md` | meta task_type | Tier 3 → meta-builder-agent |
| 254 | `patterns/mcp-tool-recovery.md` | meta task_type | Tier 3 → meta-builder-agent |

### 10. Extension Context Assessment

The project domain (40 entries, 5,680 lines) includes nix (11 entries) and neovim (29 entries) extension contexts. These use `languages` and `skills` load conditions in addition to `agents`:

- Nix entries: loaded for `nix-research-agent`, `nix-implementation-agent`, and language `nix`
- Neovim entries: loaded for `neovim-research-agent`, `neovim-implementation-agent`, and language `neovim`
- Memory entries: loaded for `skill-memory` and commands `/learn`, `/distill`

These extension entries are well-structured but lack `tier` metadata. Under the tier model:
- Extension README files → Tier 3 (overview needed at agent spawn)
- Extension domain files (core concepts) → Tier 3
- Extension pattern/standard files → Tier 3 (or Tier 4 for rarely-used)
- Extension templates → Tier 4 (on-demand)

**Notable missing fields**: Extension entries use `description` field in some entries instead of `summary`, and they lack `topics`, `domain`, or `keywords` fields in some cases. The index schema should be checked for consistency.

### 11. Command File Sizes vs. Target

| Command | Current Lines | Target | Status |
|---------|--------------|--------|--------|
| `review.md` | 1,039 | ≤200 | Over by 839L |
| `task.md` | 714 | ≤200 | Over by 514L |
| `todo.md` | 630 | ≤200 | Over by 430L |
| `merge.md` | 434 | ≤200 | Over by 234L |
| `fix-it.md` | 304 | ≤200 | Over by 104L |
| `learn.md` | 286 | ≤200 | Over by 86L |
| `spawn.md` | 246 | ≤200 | Over by 46L |
| `meta.md` | 231 | ≤200 | Over by 31L |
| `errors.md` | 220 | ≤200 | Over by 20L |
| `implement.md` | 207 | ≤200 | Marginally over |
| `plan.md` | 202 | ≤200 | Marginally over |
| `research.md` | 191 | ≤200 | Within target |

Commands `task.md`, `review.md`, `todo.md` are being refactored by task 597. After task 597, their embedded Tier 3 content should be extracted to context files.

---

## Decisions

1. **README.md missing file**: Classify the `README.md` entry as Tier 4 (never auto-loaded, on-demand index). Remove the `always: true` designation.

2. **True Tier 1 set**: Reduce always-loaded set to: `repo/project-overview.md` (144L) + `patterns/anti-stop-patterns.md` (174L) = 318 lines. Move `patterns/context-discovery.md`, `patterns/jq-escaping-workarounds.md`, `checkpoints/README.md`, and `reference/README.md` to Tier 3 or Tier 4.

3. **Double-loading pattern**: Entries with both agent AND command in `load_when` should be cleaned up — keep only the agent assignment (Tier 3). The command loading is redundant since agents are always invoked alongside commands.

4. **Dead entry**: `reference/artifact-templates.md` should be classified as Tier 4 (intentional on-demand, not auto-loaded).

5. **Unindexed files**: Add `patterns/context-exhaustion-detection.md` (Tier 3, implementation-agent) and `patterns/subagent-continuation-loop.md` (Tier 3, implementation-agent) to the index. Add `project/memory/README.md` as Tier 4.

---

## Recommendations

### Priority 1: Establish Token Cost Metadata
Add `tier` and `token_cost_estimate` fields to all 139 entries. Formula: `token_cost_estimate = line_count * 8`.

### Priority 2: Fix Tier 1 Set
Current Tier 1 (6 entries, 946L, ~7,568 tokens) exceeds the ~500L / ~4K token budget. Revised Tier 1 should contain:
- `repo/project-overview.md` (144L) — project context
- `patterns/anti-stop-patterns.md` (174L) — critical agent behavior

Total: 318 lines, ~2,544 tokens (within budget).

Demote from Tier 1:
- `README.md` → Tier 4 (file is also missing)
- `checkpoints/README.md` → Tier 4
- `patterns/context-discovery.md` → Tier 3 (for meta-builder-agent, general agents)
- `patterns/jq-escaping-workarounds.md` → Tier 3 (for meta-builder-agent, implementation agents)
- `reference/README.md` → Tier 4

### Priority 3: Move Process/Workflow Files to Tier 3 (Agent-Only)
Remove command-loading from these large files — they should be agent-only (Tier 3):

| File | Lines | Action |
|------|-------|--------|
| `processes/research-workflow.md` | 628 | Remove from `/research` command load |
| `processes/implementation-workflow.md` | 576 | Remove from `/implement` command load |
| `processes/planning-workflow.md` | 540 | Remove from `/plan` command load |
| `patterns/multi-task-operations.md` | 522 | Evaluate if command-level needed |

### Priority 4: meta-builder-agent Budget Reduction
Current: 14,512 lines, ~116K tokens. Target: ≤1,875 lines (~15K tokens). Required reduction: ~12,637 lines.

Move to Tier 4 (never auto-loaded, use `@`-ref):
- `formats/command-structure.md` (965L) — reference template
- `orchestration/orchestrator.md` (876L) — detailed orchestrator reference  
- `orchestration/delegation.md` (859L) — detailed delegation reference
- `orchestration/architecture.md` (757L) — architecture docs
- `standards/xml-structure.md` (709L) — XML structure reference
- `formats/frontmatter.md` (705L) — frontmatter spec
- `orchestration/validation.md` (699L) — validation reference
- `workflows/preflight-postflight.md` (589L) — detailed workflow reference
- Several more from the 42-entry set

After Tier 4 demotion, meta-builder-agent Tier 3 should contain only what it MUST load at spawn (architecture overview, key patterns, component checklist).

### Priority 5: Sonnet Worker Budget Reduction

| Agent | Current Tokens | Target | Highest-Impact Reduction |
|-------|---------------|--------|--------------------------|
| `general-implementation-agent` | 27,544 | 8,000 | Move `processes/implementation-workflow.md` (576L, ~4.6K tokens) to Tier 4 |
| `neovim-implementation-agent` | 24,024 | 8,000 | Review all 22 neovim entries; many are Tier 4 candidates |
| `general-research-agent` | 19,216 | 8,000 | Move `processes/research-workflow.md` (628L) to Tier 4 |
| `neovim-research-agent` | 18,424 | 8,000 | Review neovim guides for Tier 4 candidates |
| `nix-research-agent` | 12,720 | 8,000 | Already closest to target; minor adjustments |

### Priority 6: Add Unindexed Files
Add to index.json:
- `patterns/context-exhaustion-detection.md` (225L) → Tier 3, `general-implementation-agent`
- `patterns/subagent-continuation-loop.md` (209L) → Tier 3, `general-implementation-agent`
- `project/memory/README.md` (14L) → Tier 4

### Priority 7: Task-Type Loading Cleanup
Replace task_type-based loading with explicit agent assignments for 29 meta-task-type-only entries. This makes loading more predictable and enables proper tier enforcement.

---

## Risks & Mitigations

**Risk 1: Breaking existing agent workflows**
Moving content from Tier 3 to Tier 4 means agents must explicitly `@`-ref files they used to receive automatically. If an agent needs a file and doesn't `@`-ref it, it will silently lack that context.
*Mitigation*: Phased approach — classify first, then update agent prompts to include `@`-refs before removing from auto-load.

**Risk 2: meta-builder-agent extreme budget gap**
meta-builder-agent needs to be reduced from 116K to 15K tokens — an 87% reduction. This is disruptive.
*Mitigation*: Keep the most critical 10-15 entries as Tier 3, move the rest to Tier 4 with documented `@`-ref patterns in the agent prompt itself.

**Risk 3: Tier 1 budget is smaller than architecture spec suggests**
The spec says Tier 1 should contain "anti-stop patterns, return-metadata, checkpoint-execution" but these three files total 930 lines (~7.4K tokens) vs. the stated ~500L / ~4K token budget.
*Mitigation*: Either raise the Tier 1 budget to ~1,000L (~8K tokens) or reduce `return-metadata-file.md` from 502L to a shorter summary. The anti-stop patterns (174L) + return-metadata-file.md (502L) + checkpoint-execution (254L) = 930L total exceeds the original spec.

**Risk 4: Double-loading artifacts during transition**
During the transition period, some content will be loaded both by the old `commands` array AND as Tier 3 agent content, temporarily doubling context usage.
*Mitigation*: Do the cleanup atomically per command — update both the index entry and the command file simultaneously.

---

## Context Extension Recommendations

The following gaps were identified:

1. **Missing tier classification guide**: No context file documents the four-tier classification criteria and decision tree. This would help future task authors correctly classify new entries. Recommend creating `context/meta/tier-classification-guide.md`.

2. **Missing token budget enforcement tool**: No script validates that agents are within their budget caps. Recommend creating `.claude/scripts/validate-context-budgets.sh` that queries the index and reports violations.

3. **Index schema gap**: The `index.schema.json` does not include `tier` or `token_cost_estimate` fields. These need to be added as part of task 598 implementation.

---

## Appendix

### A. Complete Tier Classification Table (139 Entries)

The following table shows the proposed tier for each entry. Columns: Path, Lines, Current Load Pattern, Proposed Tier, Notes.

**Tier 1 (always-loaded, ~500L target):**

| Path | Lines | Proposed | Notes |
|------|-------|----------|-------|
| `repo/project-overview.md` | 144 | Keep Tier 1 | Project overview needed by all |
| `patterns/anti-stop-patterns.md` | 174 | Promote to Tier 1 | Critical behavior for ALL agents |

**Demoted from Tier 1:**

| Path | Lines | Current | Proposed Tier | Notes |
|------|-------|---------|---------------|-------|
| `README.md` | 202 | Tier 1 (always) | Tier 4 | FILE MISSING; doc index not needed by agents |
| `checkpoints/README.md` | 100 | Tier 1 (always) | Tier 4 | Doc index, not operational |
| `patterns/context-discovery.md` | 209 | Tier 1 (always) | Tier 3 | Needed by agents that query index |
| `patterns/jq-escaping-workarounds.md` | 262 | Tier 1 (always) | Tier 3 | Needed by implementation/meta agents |
| `reference/README.md` | 29 | Tier 1 (always) | Tier 4 | 29-line index file |

**Tier 2 (command-level routing, ≤500L target):**

Small entries that inform command-level routing and anti-bypass constraints. After tier refactor, commands should load ONLY these:

| Path | Lines | Commands | Notes |
|------|-------|---------|-------|
| `patterns/multi-task-operations.md` | 522 | /research, /plan, /implement | Tier 2 but oversized; consider Tier 3 |
| `orchestration/state-management.md` | 337 | /task, /todo | Tier 2 state management reference |
| `standards/task-management.md` | 375 | /task, /todo | Tier 2 task creation rules |
| `reference/state-management-schema.md` | 352 | /task, /todo | Tier 2 schema reference |
| `workflows/status-transitions.md` | 86 | /task | Tier 2 — small, appropriate |
| `formats/roadmap-format.md` | 65 | /todo | Tier 2 — small, appropriate |
| `patterns/roadmap-update.md` | 100 | /todo | Tier 2 — appropriate |
| `patterns/artifact-linking-todo.md` | 114 | /task, /todo | Tier 2 — appropriate |

**Tier 3 (agent-specific, per agent ≤8K tokens sonnet / ≤15K tokens opus):**

Core agents should receive these entries (selected for budget compliance):

*general-research-agent (target ≤1,000L / ~8K tokens):*
| Path | Lines | Notes |
|------|-------|-------|
| `formats/return-metadata-file.md` | 502 | Critical for correct returns |
| `formats/report-format.md` | 131 | Report structure |
| `formats/subagent-return.md` | 323 | Return format |
| `patterns/early-metadata-pattern.md` | 260 | Recovery pattern |
| `patterns/metadata-file-return.md` | 147 | Return pattern |
| Total | 1,363 | ~10.9K tokens — still slightly over 8K cap |

*planner-agent (target ≤1,875L / ~15K tokens):*
| Path | Lines | Notes |
|------|-------|-------|
| `formats/return-metadata-file.md` | 502 | Critical |
| `formats/plan-format.md` | 136 | Plan structure |
| `formats/subagent-return.md` | 323 | Return format |
| `patterns/early-metadata-pattern.md` | 260 | Recovery |
| `standards/status-markers.md` | 373 | Status conventions |
| `workflows/task-breakdown.md` | 270 | Planning workflow |
| `patterns/metadata-file-return.md` | 147 | Return pattern |
| `patterns/fork-patterns.md` | 120 | Delegation decisions |
| Total | 2,131 | ~17K tokens — slightly over 15K cap |

*general-implementation-agent (target ≤1,000L / ~8K tokens):*
| Path | Lines | Notes |
|------|-------|-------|
| `formats/return-metadata-file.md` | 502 | Critical |
| `patterns/checkpoint-execution.md` | 254 | Checkpoint pattern |
| `formats/progress-file.md` | 250 | Progress tracking |
| `formats/subagent-return.md` | 323 | Return format |
| `patterns/early-metadata-pattern.md` | 260 | Recovery |
| `standards/status-markers.md` | 373 | Status conventions |
| Total | 1,962 | ~15.7K tokens — over 8K cap; `processes/implementation-workflow.md` must move to Tier 4 |

**Tier 4 (on-demand via @-ref, unbounded):**

Large reference files that agents occasionally need but shouldn't always load:

- `formats/command-structure.md` (965L)
- `orchestration/orchestrator.md` (876L)
- `orchestration/delegation.md` (859L)
- `orchestration/architecture.md` (757L)
- `standards/xml-structure.md` (709L)
- `formats/frontmatter.md` (705L)
- `orchestration/validation.md` (699L)
- `workflows/preflight-postflight.md` (589L)
- `standards/error-handling.md` (1,056L)
- `processes/research-workflow.md` (628L)
- `processes/implementation-workflow.md` (576L)
- `processes/planning-workflow.md` (540L)
- `architecture/system-overview.md` (492L)
- All templates directory (7 entries, ~1,389L)
- `reference/team-wave-helpers.md` (400L)
- `orchestration/orchestration-reference.md` (309L)
- And many more from the 42-entry meta-builder set

### B. Agent Budget Summary (Post-Refactor Targets)

| Agent | Current Tokens | Post-Refactor Target | Key Reductions |
|-------|---------------|---------------------|----------------|
| `general-research-agent` | 19,216 | ≤8,000 | Move process workflow to Tier 4 |
| `planner-agent` | 22,760 | ≤15,000 | Remove fork-patterns + task-breakdown from commands |
| `general-implementation-agent` | 27,544 | ≤8,000 | Move implementation-workflow + testing to Tier 4 |
| `meta-builder-agent` | 116,096 | ≤15,000 | Move ~40 entries to Tier 4 |
| `neovim-implementation-agent` | 24,024 | ≤8,000 | Review/prune neovim domain entries |
| `neovim-research-agent` | 18,424 | ≤8,000 | Review neovim guides for Tier 4 |
| `nix-research-agent` | 12,720 | ≤8,000 | Minor adjustments |
| `nix-implementation-agent` | 12,720 | ≤8,000 | Minor adjustments |
| `code-reviewer-agent` | 5,544 | ≤8,000 | Already within budget |
| `spawn-agent` | 4,528 | ≤8,000 | Already within budget |

### C. Verification Commands (Post-Implementation)

```bash
# Verify all entries have tier field
jq '.entries | map(select(.tier == null)) | length' .claude/context/index.json
# Expected: 0

# Verify always-true entries are ≤500 lines total
jq '[.entries[] | select(.load_when.always == true) | .line_count] | add' .claude/context/index.json
# Expected: ≤500

# Verify no dead entries (never auto-loaded, not Tier 4)
jq '.entries[] | select(
  .tier != 4 and
  .load_when.always == false and
  (.load_when.agents | length) == 0 and
  (.load_when.commands | length) == 0 and
  (.load_when.task_types | length) == 0
) | .path' .claude/context/index.json
# Expected: empty

# Verify sonnet worker budgets
for agent in general-research-agent general-implementation-agent code-reviewer-agent spawn-agent; do
  lines=$(jq "[.entries[] | select(.load_when.agents[]? == \"$agent\") | .line_count] | add" .claude/context/index.json)
  tokens=$((lines * 8))
  echo "$agent: $tokens tokens (cap: 8000)"
done

# Verify command files are ≤200 lines
wc -l .claude/commands/research.md .claude/commands/plan.md .claude/commands/implement.md
```

### D. Files Affected Summary

- **Files to update**: `index.json` — add `tier` and `token_cost_estimate` to all 139 entries
- **Files to create**: `patterns/tier-classification-guide.md` (documentation), possibly `project/memory/README.md` in index
- **Entries to fix**: `README.md` entry (file missing), `reference/artifact-templates.md` (dead entry)
- **Entries to add**: `patterns/context-exhaustion-detection.md`, `patterns/subagent-continuation-loop.md`
- **`load_when` changes**: Remove command-loading from large Tier 3 files; update always-true set

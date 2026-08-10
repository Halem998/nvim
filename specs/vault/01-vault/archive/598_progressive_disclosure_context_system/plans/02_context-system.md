# Implementation Plan: Task #598

- **Task**: 598 - progressive_disclosure_context_system
- **Status**: [COMPLETED]
- **Effort**: 6 hours
- **Dependencies**: Task 597 (command refactoring, in progress)
- **Research Inputs**: specs/598_progressive_disclosure_context_system/reports/02_context-audit.md
- **Artifacts**: plans/02_context-system.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan implements the four-tier progressive disclosure context system for the agent infrastructure. The context index (`index.json`) has grown to 139 entries totaling 34,712 lines with zero tier classification. Every agent except `code-reviewer-agent` and `spawn-agent` exceeds its proposed budget cap, with `meta-builder-agent` at 116K tokens vs. a 15K cap. The plan classifies all entries, restructures `load_when` arrays, and brings agents within revised budget targets. Definition of done: all 139+ entries have `tier` and `token_cost_estimate` fields, Tier 1 is at most 2 entries / 318 lines, all agents are within their budget caps (with documented exceptions), and verification commands pass.

### Research Integration

Integrated report: `reports/02_context-audit.md` (2026-05-22). Key findings:
- 139 entries (not 97 as originally cited), 34,712 total lines
- 6 always-loaded entries should be reduced to 2
- 40 entries are double-loaded (agents AND commands)
- meta-builder-agent at 116K tokens needs 87% reduction
- 3 unindexed files on disk, 1 missing file, 1 dead entry
- Complete tier classification table provided in appendix

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances the following roadmap items:
- **Context discovery caching** (Phase 2) -- tier classification is a prerequisite for meaningful caching since Tier 1 entries bypass the cache
- **Agent frontmatter validation** (Phase 1) -- overlaps with agent context budget enforcement

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Add `tier` (1-4) and `token_cost_estimate` fields to all 139 entries in `index.json`
- Reduce Tier 1 (always-loaded) from 6 entries / 946 lines to 2 entries / 318 lines
- Remove command-loading from Tier 3 (agent-only) entries to eliminate double-loading
- Bring all agent context loads within revised budget caps
- Add 3 unindexed files and fix 1 missing-file entry and 1 dead entry
- Create a budget validation script for ongoing enforcement

**Non-Goals**:
- Refactoring command files to extract embedded agent context (task 597 scope)
- Changing agent prompt/definition files (agents already use `@`-ref patterns)
- Modifying the index.schema.json to add new fields (separate concern, can be done later)
- Creating a tier classification guide document (nice-to-have, not required for this task)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking agent workflows by removing auto-loaded context | H | M | Phased approach: classify first (Phase 1), then update load_when in batches with per-agent verification (Phases 3-4) |
| meta-builder-agent 87% reduction is too aggressive | H | H | Use a pragmatic Tier 3 set (~20-25 entries) and accept a revised cap of ~20K tokens if needed; document exceptions |
| Tier 1 budget spec mismatch (architecture says ~500L but key files total 930L) | M | H | Use the research-recommended 2-entry / 318L Tier 1 set; move return-metadata and checkpoint-execution to Tier 3 (they are agent-specific, not universal) |
| Double-loading during transition causes temporary context bloat | L | M | Do load_when cleanup atomically per entry batch, not incrementally |
| Verification commands give false confidence | M | L | Test budget script against known-good agents (code-reviewer, spawn) first |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add tier and token_cost_estimate to all 139 entries [COMPLETED]

**Goal**: Establish the tier classification metadata on every entry in `index.json` without changing any `load_when` behavior. This is a non-breaking, additive-only change.

**Tasks**:
- [ ] Read the current `index.json` and verify the 139 entry count
- [ ] Add `"tier": N` (1-4) to each entry using the classification table from the research report appendix
- [ ] Add `"token_cost_estimate": line_count * 8` to each entry
- [ ] Set Tier 1 (`always: true`) on exactly 2 entries: `repo/project-overview.md` (144L) and `patterns/anti-stop-patterns.md` (174L)
- [ ] Set `always: false` on the 4 demoted entries: `README.md`, `checkpoints/README.md`, `patterns/context-discovery.md`, `patterns/jq-escaping-workarounds.md`, `reference/README.md`
- [ ] Classify the `README.md` entry as Tier 4 (file is missing on disk)
- [ ] Classify `reference/artifact-templates.md` as Tier 4 (dead entry -- no auto-load arrays)
- [ ] Add 3 unindexed files to index: `patterns/context-exhaustion-detection.md` (225L, Tier 3), `patterns/subagent-continuation-loop.md` (209L, Tier 3), `project/memory/README.md` (14L, Tier 4)
- [ ] Verify JSON is valid after edits: `jq empty .claude/context/index.json`
- [ ] Verify exactly 2 entries have `always: true`: `jq '[.entries[] | select(.load_when.always == true)] | length' .claude/context/index.json` returns 2
- [ ] Verify all entries have `tier` field: `jq '[.entries[] | select(.tier == null)] | length' .claude/context/index.json` returns 0

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/context/index.json` -- add `tier` and `token_cost_estimate` to all entries; update `always` flags; add 3 new entries

**Verification**:
- `jq empty .claude/context/index.json` succeeds (valid JSON)
- All 142 entries (139 + 3 new) have both `tier` and `token_cost_estimate` fields
- Exactly 2 entries have `always: true`
- No `load_when` arrays were changed (except `always` on the 6 Tier 1 changes)

---

### Phase 2: Remove command-loading from Tier 3 entries (eliminate double-loading) [COMPLETED]

**Goal**: Remove the `commands` array entries from files classified as Tier 3 (agent-only). This eliminates the double-loading pattern where 40 entries are loaded for both commands and agents.

**Tasks**:
- [ ] Identify all Tier 3 entries that have non-empty `commands` arrays (the 40 double-loaded entries from research)
- [ ] For each, remove the command strings from `load_when.commands` array, leaving the `agents` array intact
- [ ] Key entries to clean (from research): `processes/research-workflow.md`, `processes/implementation-workflow.md`, `processes/planning-workflow.md`, `formats/return-metadata-file.md`, `formats/subagent-return.md`, `patterns/early-metadata-pattern.md`, `patterns/metadata-file-return.md`, `formats/report-format.md`, `formats/plan-format.md`, `formats/progress-file.md`, `standards/status-markers.md`, `patterns/checkpoint-execution.md`, `patterns/fork-patterns.md`, `workflows/task-breakdown.md`
- [ ] For entries that are Tier 2 (command-level routing), keep the `commands` array and remove the `agents` array instead
- [ ] Verify no Tier 3 entry has a `commands` array: `jq '[.entries[] | select(.tier == 3 and (.load_when.commands | length) > 0)] | length' .claude/context/index.json` returns 0
- [ ] Verify Tier 2 entries still have their `commands` arrays

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/context/index.json` -- modify `load_when` arrays for ~40 entries

**Verification**:
- No Tier 3 entry has commands in `load_when`
- No Tier 2 entry has agents in `load_when`
- Tier 1 entries unchanged
- JSON remains valid

---

### Phase 3: Bring meta-builder-agent within budget [COMPLETED]

**Goal**: Reduce meta-builder-agent's context load from ~116K tokens to a target of 15K-20K tokens by reclassifying most of its 42 entries from Tier 3 to Tier 4 (on-demand).

**Tasks**:
- [ ] List all entries currently assigned to `meta-builder-agent` in their `load_when.agents` array
- [ ] Select a core Tier 3 set of approximately 10-15 entries that the meta-builder-agent genuinely needs at spawn (architecture overview, key patterns, component checklist, error-handling summary)
- [ ] Move remaining entries to Tier 4 by removing `meta-builder-agent` from their `load_when.agents` array
- [ ] High-priority demotions to Tier 4 (from research): `formats/command-structure.md` (965L), `orchestration/orchestrator.md` (876L), `orchestration/delegation.md` (859L), `orchestration/architecture.md` (757L), `standards/xml-structure.md` (709L), `formats/frontmatter.md` (705L), `orchestration/validation.md` (699L), `workflows/preflight-postflight.md` (589L)
- [ ] Convert task_type-based loading for the 29 meta-only entries: where an entry has `task_types: ["meta"]` but no agents, either add `meta-builder-agent` to agents (if Tier 3) or leave agents empty (if Tier 4)
- [ ] Remove `task_types: ["meta"]` from entries that have been converted to explicit agent assignment
- [ ] Calculate post-refactor token total for meta-builder-agent
- [ ] If total exceeds 20K tokens, identify additional entries to demote to Tier 4
- [ ] Verify budget: `jq '[.entries[] | select(.load_when.agents[]? == "meta-builder-agent") | .token_cost_estimate] | add' .claude/context/index.json` returns value at most 20000

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/context/index.json` -- modify `load_when.agents` and `load_when.task_types` for ~42 entries

**Verification**:
- meta-builder-agent total token load is at most 20K tokens
- All former task_type-only entries have been converted to explicit agent or Tier 4
- No entry has `task_types: ["meta"]` without also having an agent assignment or being Tier 4
- JSON remains valid

---

### Phase 4: Bring sonnet workers within budget [COMPLETED]

**Goal**: Reduce context load for the 6 over-budget sonnet worker agents to at most 8K tokens each by reclassifying entries from Tier 3 to Tier 4.

**Tasks**:
- [ ] For each over-budget agent, list current entries and total tokens:
  - `general-implementation-agent` (27,544 -> target 8,000)
  - `neovim-implementation-agent` (24,024 -> target 8,000)
  - `general-research-agent` (19,216 -> target 8,000)
  - `neovim-research-agent` (18,424 -> target 8,000)
  - `nix-research-agent` (12,720 -> target 8,000)
  - `nix-implementation-agent` (12,720 -> target 8,000)
- [ ] For `general-implementation-agent`: move `processes/implementation-workflow.md` (576L, 4.6K tokens) and other large process files to Tier 4; keep only return-metadata, checkpoint-execution, progress-file, status-markers, early-metadata as Tier 3
- [ ] For `general-research-agent`: move `processes/research-workflow.md` (628L, 5K tokens) to Tier 4; keep return-metadata, report-format, early-metadata as Tier 3
- [ ] For `neovim-*-agent` pair: review all 29 neovim extension entries; keep domain overview and key patterns as Tier 3; move detailed guides, templates, tool references to Tier 4
- [ ] For `nix-*-agent` pair: review all 11 nix extension entries; keep domain overview as Tier 3; move detailed patterns to Tier 4
- [ ] Also bring `planner-agent` within 15K cap (currently 22,760): move fork-patterns, task-breakdown (if not essential) to Tier 4
- [ ] Verify each agent is within cap using budget validation query
- [ ] Document any agents that cannot meet the strict cap, with justification (e.g., if minimum essential Tier 3 still exceeds 8K, note the realistic cap)

**Timing**: 1.5 hours

**Depends on**: 2, 3

**Files to modify**:
- `.claude/context/index.json` -- modify `load_when.agents` for entries across all 8 over-budget agents

**Verification**:
- For each sonnet worker: `jq '[.entries[] | select(.load_when.agents[]? == "AGENT") | .token_cost_estimate] | add' .claude/context/index.json` returns value at most 8000
- For planner-agent: same query returns at most 15000
- code-reviewer-agent and spawn-agent remain within 8K (unchanged)
- JSON remains valid

---

### Phase 5: Create budget validation script and final verification [COMPLETED]

**Goal**: Create a reusable script that validates agent context budgets against caps, run it to confirm all agents are compliant, and perform final integrity checks on the refactored index.

**Tasks**:
- [ ] Create `.claude/scripts/validate-context-budgets.sh` that:
  - Reads `index.json` and computes per-agent token totals
  - Compares against defined caps (sonnet: 8K, opus: 15K, haiku: 2K)
  - Reports violations with agent name, current total, cap, and gap
  - Reports Tier 1 total lines and checks against 500L target
  - Exits non-zero if any violation found
  - Supports `--verbose` flag to list all entries per agent
- [ ] Run the script and verify all agents pass (or document justified exceptions)
- [ ] Run the full verification command set from the research report appendix C:
  - All entries have `tier` field (expect 0 missing)
  - Always-true entries total at most 500 lines
  - No dead entries (never-loaded, non-Tier-4)
  - Sonnet worker budgets within 8K
  - Opus agent budgets within 15K (or documented exception)
- [ ] Verify no Tier 3 entries have command-loading (double-load eliminated)
- [ ] Verify no entries have `task_types` without corresponding agent assignment (unless Tier 4)
- [ ] Spot-check 3 agents by manually counting their Tier 3 entries and comparing to script output

**Timing**: 0.5 hours

**Depends on**: 4

**Files to modify**:
- `.claude/scripts/validate-context-budgets.sh` -- new file (budget validation script)

**Verification**:
- Script exists and is executable
- Script runs without errors
- Script reports all agents within budget (or documented exceptions with justification)
- All verification commands from research appendix C pass

---

## Testing & Validation

- [ ] `jq empty .claude/context/index.json` -- JSON is valid
- [ ] All entries have `tier` (1-4) and `token_cost_estimate` fields
- [ ] Exactly 2 entries have `always: true` (Tier 1): `repo/project-overview.md` and `patterns/anti-stop-patterns.md`
- [ ] Total Tier 1 lines at most 500 (target: 318)
- [ ] No Tier 3 entry has `commands` in `load_when` (double-loading eliminated)
- [ ] No Tier 2 entry has `agents` in `load_when`
- [ ] All 10 agents within budget caps (8K sonnet, 15K opus) or documented exception
- [ ] `validate-context-budgets.sh` exits 0
- [ ] No entry has `task_types` without either an agent assignment or Tier 4 classification
- [ ] 3 previously unindexed files are now in the index
- [ ] Missing `README.md` entry is classified Tier 4 with `always: false`
- [ ] Dead entry `reference/artifact-templates.md` is classified Tier 4

## Artifacts & Outputs

- `plans/02_context-system.md` -- this plan file
- `.claude/context/index.json` -- updated with tier metadata and restructured load_when arrays
- `.claude/scripts/validate-context-budgets.sh` -- new budget validation script

## Rollback/Contingency

The primary artifact being modified is `.claude/context/index.json`. If implementation breaks agent workflows:

1. **Git revert**: The index.json changes will be committed per-phase, so individual phases can be reverted with `git revert`
2. **Partial rollback**: If only specific agent budgets cause issues, restore that agent's entries from the pre-phase commit
3. **Budget cap adjustment**: If strict 8K/15K caps prove unrealistic for certain agents after real-world testing, document a revised cap in the validation script with justification
4. **Tier 4 promotion**: If an agent is missing context it needs, promote specific entries from Tier 4 back to Tier 3 by adding the agent to `load_when.agents`

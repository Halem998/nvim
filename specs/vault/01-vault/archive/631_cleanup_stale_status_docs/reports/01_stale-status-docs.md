# Research Report: Task #631

**Task**: 631 - Clean up stale status documentation and consolidate
**Started**: 2026-06-01T00:00:00Z
**Completed**: 2026-06-01T00:30:00Z
**Effort**: ~30 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (grep, read), context/index.json, extensions.json
**Artifacts**: - specs/631_cleanup_stale_status_docs/reports/01_stale-status-docs.md
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- All five key files exist. Three contain significant amounts of "status-sync-manager" references that describe a now-obsolete subagent-based architecture; the current infrastructure uses `update-task-status.sh` called via `skill-base.sh`.
- The `status-sync-manager` name appears in **284 locations** across **37 unique files** (including core extension mirrors). The most critical files for task (b) are `standards/status-markers.md`, `context/orchestration/postflight-pattern.md`, `context/orchestration/preflight-pattern.md`, `context/orchestration/state-management.md`, and `context/workflows/command-lifecycle.md`.
- `inline-status-update.md` still contains valid and actively used jq patterns. It is referenced by `skill-lifecycle.md`, `checkpoint-execution.md`, `jq-escaping-workarounds.md`, and `orchestration/state-management.md`. It should be **kept** but potentially updated to clarify it describes raw fallback patterns (when `skill-base.sh` is unavailable), not the primary path.
- `status-transitions.md` already has a DEPRECATED banner pointing to `orchestration/state-management.md` and `standards/status-markers.md`, but it still contains harmful `status-sync-manager` instructions that contradict the deprecation notice.
- `skill-status-sync/SKILL.md` says "standalone use only" but does not mention that `/orchestrate` calls `skill_postflight_update` (from `skill-base.sh`) after each lifecycle dispatch.
- `rules/state-management.md` correctly describes the two-phase commit pattern and refers to `update-task-status.sh` scripts by name, but does not explicitly describe the orchestrate flow.
- The three status files are tracked as **installed files** of the `core` extension (verified via `extensions.json`). The matching files in `.claude/extensions/core/context/` are **identical mirrors**. Any edits to the primary files must also be applied to the core extension mirrors to keep them in sync.

---

## Context & Scope

This research audits five documentation files in `.claude/` for stale references to the obsolete `status-sync-manager` subagent, evaluates which files to remove/redirect/update, and maps all cross-references so the implementer can make complete, consistent changes.

### Current Infrastructure (What Replaced status-sync-manager)

The old architecture invoked a `status-sync-manager` subagent via the task tool for all status updates. This has been fully replaced by:

1. **`update-task-status.sh`** — Shell script that atomically updates `state.json`, `TODO.md` task entries, TODO.md Task Order section, and plan files.
2. **`skill-base.sh`** — Provides `skill_preflight_update()` and `skill_postflight_update()` functions that call `update-task-status.sh` directly.
3. **`skill-status-sync/SKILL.md`** — Inline Claude-executed skill (no subagent) for manual/recovery use.
4. **`skill-orchestrate/SKILL.md`** — Calls `skill_postflight_update()` after each lifecycle dispatch cycle.

---

## Findings

### Per-File Audit

#### (a) `context/workflows/status-transitions.md`

**Exists**: Yes (81 lines)  
**Content summary**: Status transition quick-reference table (research/plan/implement), command→status mapping, and "Status Update Delegation" section.  
**DEPRECATED banner**: Yes — already has a DEPRECATED notice at top pointing to `orchestration/state-management.md` and `standards/status-markers.md`. Created 2026-01-19.  
**Stale content**:
- Lines 54-80: Entire "Status Update Delegation" section instructs delegating to `status-sync-manager` with a JSON example. This is directly contradicted by the DEPRECATED banner at the top.
- Also referenced in `status-markers.md` References section (line 313): `- **status-transitions.md**: Status transition workflows`
- Also referenced in `context/orchestration/architecture.md` line 540: `- workflows/status-transitions.md - Status transition rules`

**Recommendation**: **Delete the file**. The DEPRECATED banner already exists; the next step is removal. Before removal, update any cross-references in `status-markers.md` (References section) and `orchestration/architecture.md`. Also remove from `context/index.json` (currently loaded for `/task` command and `meta` task type). The core extension mirror at `extensions/core/context/workflows/status-transitions.md` must also be deleted.

---

#### (b) `context/standards/status-markers.md`

**Exists**: Yes (319 lines)  
**Content summary**: Authoritative, well-structured reference for all status markers, transitions, command mappings, and validation rules. Overall structure is correct.  
**Stale content**:
- Line 222: `"CRITICAL": All status updates MUST be delegated to status-sync-manager for atomic synchronization.`
- Line 223: `"DO NOT" update TODO.md or state.json directly.` (This rule is now wrong — `inline-status-update.md` and `skill-base.sh` do exactly that)
- Lines 225-264: JSON example showing how to invoke `status-sync-manager` as a subagent (both preflight and postflight examples)
- Line 270: `status-sync-manager updates atomically:` description
- Lines 313-315: References section lists `status-transitions.md` (about to be removed) and `status-sync-manager.md` (doesn't exist as a context file)

**Replacement text for "Status Update Protocol" section**: Replace with reference to `skill-base.sh` functions (`skill_preflight_update`, `skill_postflight_update`) calling `update-task-status.sh`, and `skill-status-sync/SKILL.md` for manual/recovery use.

**Recommendation**: **Update** — replace the "Status Update Protocol" and "Atomic Synchronization" sections. Remove the `status-transitions.md` and `status-sync-manager.md` references from the References section. The core extension mirror must be updated in sync.

---

#### (c) `context/patterns/inline-status-update.md`

**Exists**: Yes (279 lines)  
**Content summary**: Concrete jq patterns for updating `state.json` and `TODO.md` inline (without invoking a subagent). Covers preflight/postflight for research, planning, and implementation. Also covers artifact linking and TODO.md edit patterns.  
**Stale content**: None — it does NOT mention `status-sync-manager`. The patterns are direct jq/bash patterns.  
**Still used by**:
- `context/patterns/skill-lifecycle.md` (lines 73, 83, 193): Points to this file for preflight and postflight update patterns
- `context/patterns/checkpoint-execution.md` (line 249): Lists it as a reference
- `context/patterns/jq-escaping-workarounds.md` (line 260): Lists it as reference
- `context/orchestration/state-management.md` (line 318): References it as "jq patterns for direct updates"

**Assessment**: The patterns described are functionally equivalent to what `update-task-status.sh` does, and they remain valid as fallback patterns or for understanding the underlying mechanism. The file has no stale content.

**Recommendation**: **Keep, but add a header note** clarifying that `skill-base.sh` functions (`skill_preflight_update`, `skill_postflight_update`) are the primary path, and these jq patterns are for reference/recovery when the shell script layer is unavailable. Do NOT remove — it is actively referenced by four context files. Update `skill-lifecycle.md` references to mention that `skill-base.sh` is the preferred call site.

---

#### (d) `skills/skill-status-sync/SKILL.md`

**Exists**: Yes (297 lines)  
**Content summary**: Inline skill (no subagent) that provides `preflight_update`, `postflight_update`, and `artifact_link` operations. Has good "Standalone Use Only" section explaining it's not for workflow commands.  
**Stale content**: None — does not mention `status-sync-manager`.  
**Gap**: Does not mention that `/orchestrate` (via `skill-orchestrate/SKILL.md`) calls `skill_postflight_update()` from `skill-base.sh` after each dispatch cycle. The "Standalone Use Only" note says workflow skills handle their own status updates inline, but doesn't clarify the orchestrate interaction specifically.

**Recommendation**: **Update the "Standalone Use Only" section** to add a note: "The `/orchestrate` command calls `skill_postflight_update()` from `skill-base.sh` after each lifecycle dispatch cycle. This skill is not used by orchestrate." This clarifies the orchestrate flow without overloading the document.

---

#### (e) `rules/state-management.md`

**Exists**: Yes (132 lines)  
**Content summary**: Auto-applied rule file (pattern: `specs/**/*`). Covers file sync, status transitions, two-phase update pattern, task order synchronization, error handling, and schema reference. Good authoritative document.  
**Stale content**: None — does NOT mention `status-sync-manager`. Correctly references `update-task-status.sh` by name (line 99).  
**Orchestrate gap**: The document describes the two-phase update pattern for individual commands but does not describe how `/orchestrate` drives multi-cycle status updates (calling `skill_postflight_update` after each lifecycle dispatch).

**Recommendation**: **Add a brief note** to the "Status Transitions" or a new "Orchestrate Flow" subsection: "`/orchestrate` drives tasks through successive lifecycle phases by calling `skill_postflight_update()` from `skill-base.sh` after each dispatch. It reads `state.json` for current status and routes each cycle to the next phase (`research → plan → implement`)."

---

#### (f) CLAUDE.md Files

**`nvim/.claude/CLAUDE.md`** (checked via system-reminder context):  
- Line 184: `| skill-status-sync | (direct execution) | - | Atomic status updates |` — This is accurate and not stale.
- No `status-sync-manager` references found.

**Root `~/.config/CLAUDE.md`**: No status sync references at all.

**Recommendation**: No changes needed to CLAUDE.md files.

---

### Complete "status-sync-manager" Reference Map

Total: **284 occurrences** across **37 unique files**. Files are split between primary `.claude/context/` and mirror `extensions/core/context/` copies.

**Primary files with heaviest usage** (top 10 by impact):

| File | Occurrences | Action Required |
|------|-------------|-----------------|
| `context/orchestration/postflight-pattern.md` | ~15 | Update (describes old delegation pattern) |
| `context/orchestration/preflight-pattern.md` | ~12 | Update (describes old delegation pattern) |
| `context/workflows/command-lifecycle.md` | ~10 | Update (lines 73, 86, 102, 166, 196, 198, 214, 230, 240) |
| `context/standards/status-markers.md` | ~5 | Update (task b) |
| `context/workflows/status-transitions.md` | ~5 | Delete (task a) |
| `context/orchestration/state-management.md` | 1 | Minor update (line 109) |
| `context/orchestration/architecture.md` | multiple | Update references |
| `context/orchestration/delegation.md` | multiple | Update references |
| `context/orchestration/orchestrator.md` | multiple | Update references |
| `context/processes/research-workflow.md` | multiple | Update references |

**All 37 files** (both primary and core extension mirrors):

Primary (`.claude/`):
- `context/formats/command-structure.md`
- `context/formats/frontmatter.md`
- `context/orchestration/architecture.md`
- `context/orchestration/delegation.md`
- `context/orchestration/orchestrator.md`
- `context/orchestration/postflight-pattern.md`
- `context/orchestration/preflight-pattern.md`
- `context/orchestration/state-management.md`
- `context/processes/implementation-workflow.md`
- `context/processes/planning-workflow.md`
- `context/processes/research-workflow.md`
- `context/schemas/subagent-frontmatter.yaml`
- `context/standards/status-markers.md`
- `context/workflows/command-lifecycle.md`
- `context/workflows/preflight-postflight.md`
- `context/workflows/review-process.md`
- `context/workflows/status-transitions.md`
- `docs/guides/permission-configuration.md`

Mirrors (`extensions/core/context/`):
- `context/formats/command-structure.md`
- `context/formats/frontmatter.md`
- `context/orchestration/architecture.md`
- `context/orchestration/delegation.md`
- `context/orchestration/orchestrator.md`
- `context/orchestration/postflight-pattern.md`
- `context/orchestration/preflight-pattern.md`
- `context/orchestration/state-management.md`
- `context/processes/implementation-workflow.md`
- `context/processes/planning-workflow.md`
- `context/processes/research-workflow.md`
- `context/schemas/subagent-frontmatter.yaml`
- `context/standards/status-markers.md`
- `context/workflows/command-lifecycle.md`
- `context/workflows/preflight-postflight.md`
- `context/workflows/review-process.md`
- `context/workflows/status-transitions.md`
- `docs/guides/permission-configuration.md`

Note: Every primary file change must be mirrored to `extensions/core/` since they are identical copies (verified via diff). The `extensions.json` tracks `status-transitions.md`, `status-markers.md`, and `inline-status-update.md` as core extension installed files.

---

### Cross-Reference Map

**Who links to `status-transitions.md`**:
- `context/standards/status-markers.md` (References section, line 313)
- `context/orchestration/architecture.md` (line 540)
- `context/index.json` (entry: load_when /task, meta task_type)
- `extensions.json` (tracked as core extension file)

**Who links to `status-markers.md`**:
- `context/orchestration/architecture.md`
- `context/index.json` (entry: load_when planner-agent)
- `context/formats/plan-format.md` (lines 6, 10, 84, 104)
- `context/formats/report-format.md` (line 13)
- `context/formats/summary-format.md` (line 13)
- `context/schemas/subagent-frontmatter.yaml` (line 138)
- `context/processes/research-workflow.md` (line 484)
- `agents/planner-agent.md` (line 229)
- `commands/spawn.md` (line 66)
- `docs/guides/context-loading-best-practices.md` (line 849)
- `extensions.json` (tracked as core extension file)
- `extensions/founder/agents/founder-plan-agent.md` (line 279)

**Who links to `inline-status-update.md`**:
- `context/patterns/skill-lifecycle.md` (lines 73, 83, 193, 249)
- `context/patterns/checkpoint-execution.md` (line 249)
- `context/patterns/jq-escaping-workarounds.md` (line 260)
- `context/orchestration/state-management.md` (line 318)
- `context/index.json` (entry: load_when never — empty arrays)
- `extensions.json` (tracked as core extension file)

---

### context/index.json Entries to Update

Three status files have entries in `context/index.json`:

1. **`workflows/status-transitions.md`**: `load_when: {commands: ["/task"], task_types: ["meta"]}` — Remove this entry when the file is deleted.

2. **`standards/status-markers.md`**: `load_when: {agents: ["planner-agent"]}` — Keep entry, but consider whether content updates warrant a `line_count` update.

3. **`patterns/inline-status-update.md`**: `load_when: {agents: [], commands: [], task_types: []}` — Load-when is all empty (never auto-loaded). Keep entry. The file should remain available for explicit reference.

---

## Decisions

- `status-transitions.md` should be deleted (not just marked deprecated — it already is deprecated, and the DEPRECATED notice is inconsistent with the harmful content below it).
- `inline-status-update.md` should be kept with a clarifying header note added.
- `skill-status-sync/SKILL.md` needs a one-paragraph addition about orchestrate interaction.
- `rules/state-management.md` needs a short orchestrate flow paragraph.
- `status-markers.md` needs its "Status Update Protocol" and "Atomic Synchronization" sections replaced and its References section cleaned up.
- The 18 primary `.claude/` files with `status-sync-manager` references beyond the 5 key files are **out of scope for this task** (the task description focuses on the six sub-tasks a–f). However, the implementer should note that `postflight-pattern.md` and `preflight-pattern.md` in `context/orchestration/` contain the most severe stale content (they describe the old subagent delegation in detail and are the primary source of confusion).

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Editing primary files without updating core extension mirrors | Always apply the same edit to `extensions/core/context/` mirror paths |
| Removing `status-transitions.md` from index.json breaking something | The file is only loaded for `/task` + `meta` task types; removal is safe |
| `inline-status-update.md` being removed when it's still needed | Do not remove — it has 4 active inbound references |
| Missing stale references in out-of-scope files | Out of scope for this task but noted for future cleanup task |

---

## Recommendations Summary (Sub-tasks a–f)

### (a) `status-transitions.md` — DELETE
1. Remove `context/workflows/status-transitions.md`
2. Remove `extensions/core/context/workflows/status-transitions.md`
3. Remove entry from `context/index.json`
4. Remove reference from `context/standards/status-markers.md` References section (line 313)
5. Remove reference from `context/orchestration/architecture.md` (line 540)
6. Remove tracking from `extensions.json` installed_files list

### (b) `status-markers.md` — UPDATE
1. Replace "Status Update Protocol" section (lines 220-264) with:
   - Description of `skill_preflight_update()` / `skill_postflight_update()` from `skill-base.sh`
   - These call `update-task-status.sh` which atomically updates state.json + TODO.md
   - For manual/recovery use: `skill-status-sync` skill
2. Replace "Atomic Synchronization" section (lines 268-276) to reflect `update-task-status.sh`
3. Update References section (lines 312-318) to remove `status-transitions.md` and `status-sync-manager.md`; add references to `skill-base.sh` and `update-task-status.sh`
4. Apply same edits to `extensions/core/context/standards/status-markers.md`

### (c) `inline-status-update.md` — KEEP WITH HEADER NOTE
1. Add a short note at the top (after the title) clarifying that `skill-base.sh` functions are the primary status update path; these jq patterns are for reference and fallback use.
2. Apply same edit to `extensions/core/context/patterns/inline-status-update.md`

### (d) `skill-status-sync/SKILL.md` — UPDATE "STANDALONE USE ONLY" SECTION
1. Add a bullet or paragraph: "The `/orchestrate` command calls `skill_postflight_update()` from `skill-base.sh` after each lifecycle dispatch cycle, NOT this skill. Orchestrate reads `state.json` status, dispatches the next lifecycle phase, and calls `skill_postflight_update()` on success."

### (e) `rules/state-management.md` — ADD ORCHESTRATE FLOW NOTE
1. Add a new "Orchestrate Flow" subsection under "Status Transitions" describing how `/orchestrate` drives multi-cycle updates via `skill_postflight_update()`.

### (f) CLAUDE.md — NO CHANGES NEEDED
- The `nvim/.claude/CLAUDE.md` Skill-to-Agent table already correctly lists `skill-status-sync` as "(direct execution)" with "Atomic status updates" — accurate and not stale.
- No `status-sync-manager` references found in either CLAUDE.md file.

---

## Context Extension Recommendations

- **Topic**: Centralized status update infrastructure
- **Gap**: No single context file explains the complete status update call chain (skill-base.sh → update-task-status.sh → state.json + TODO.md). This knowledge is scattered across `state-management.md`, `skill-lifecycle.md`, and the skill files.
- **Recommendation**: After completing this cleanup, consider adding a short "Status Update Infrastructure" section to `context/orchestration/state-management.md` that summarizes the full chain.

---

## Appendix

### Search Commands Used

```bash
grep -rn "status-sync-manager" .claude/ | grep -v ".git" | awk -F: '{print $1}' | sort -u
grep -rn "status-transitions.md|status-markers.md|inline-status-update.md" .claude/
jq -r '.entries[] | select(.path | contains("status")) | ...' .claude/context/index.json
diff .claude/context/workflows/status-transitions.md \
     .claude/extensions/core/context/workflows/status-transitions.md
```

### Key File Paths

| File | Primary Path | Core Mirror |
|------|-------------|-------------|
| status-transitions.md | `.claude/context/workflows/status-transitions.md` | `.claude/extensions/core/context/workflows/status-transitions.md` |
| status-markers.md | `.claude/context/standards/status-markers.md` | `.claude/extensions/core/context/standards/status-markers.md` |
| inline-status-update.md | `.claude/context/patterns/inline-status-update.md` | `.claude/extensions/core/context/patterns/inline-status-update.md` |
| skill-status-sync SKILL.md | `.claude/skills/skill-status-sync/SKILL.md` | (no mirror) |
| state-management rule | `.claude/rules/state-management.md` | (no mirror) |

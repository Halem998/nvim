# Pipeline Integrity Audit: state.json-First Migration

**Audited**: 2026-06-10
**Scope**: All scripts, skills, agents, and commands that directly write to TODO.md or plan files
**Method**: Exhaustive grep + line-by-line read of every hit

---

## 1. Complete Inventory: Direct TODO.md Writers

### 1A. Shell Scripts (Executable Writers)

| # | File | Lines | What It Does | Write Type |
|---|------|-------|-------------|------------|
| S1 | `.claude/scripts/update-task-status.sh` | 200-267 (Phase 2) | `update_todo_task_entry()` — awk replaces `[STATUS]` on task heading line, writes via mktemp+mv | STATUS UPDATE |
| S2 | `.claude/scripts/update-task-status.sh` | 270-368 (Phase 3) | `update_todo_task_order()` — awk replaces `[STATUS]` on Task Order tree line, or calls `generate-task-order.sh --update-todo` for terminal statuses | TASK ORDER UPDATE |
| S3 | `.claude/scripts/link-artifact-todo.sh` | 1-250 (entire file) | Four-case artifact linking: sed insert, awk multi-line replace, sed in-place replace on TODO.md | ARTIFACT LINKING |
| S4 | `.claude/scripts/archive-task.sh` | 110-150 (Section C) | Python inline script removes task entry block from TODO.md | ENTRY REMOVAL |
| S5 | `.claude/scripts/generate-task-order.sh` | 786-880 | Replaces `## Task Order` section in TODO.md via sed-based section replacement | TASK ORDER REPLACE |
| S6 | `.claude/scripts/vault-operation.sh` | 161-166 | sed replaces task number references in TODO.md during vault renumbering | RENUMBER |
| S7 | `.claude/scripts/vault-operation.sh` | 195-226 | Python adds vault transition comment to TODO.md | COMMENT INSERT |
| S8 | `.claude/scripts/reconcile-task-status.sh` | 143-157 | Calls `link-artifact-todo.sh` to link artifacts in TODO.md during reconciliation | ARTIFACT LINKING (indirect) |
| S9 | `.claude/scripts/skill-base.sh` | 382-384 | `skill_link_artifacts()` calls `link-artifact-todo.sh` | ARTIFACT LINKING (indirect) |
| S10 | `.claude/scripts/generate-todo.sh` | 1-338 (entire file) | **THE REPLACEMENT** — regenerates full TODO.md from state.json | FULL REGENERATION |

### 1B. Skill Definitions (Agent Instructions to Write TODO.md)

| # | File | Lines | What It Instructs | Write Type |
|---|------|-------|-------------------|------------|
| K1 | `skill-status-sync/SKILL.md` | 106-108 | "Use Edit tool to change `[OLD_STATUS]` to `[NEW_STATUS]`" in TODO.md | AGENT EDIT (status) |
| K2 | `skill-status-sync/SKILL.md` | 155-157 | "Use Edit to change status: `[RESEARCHING]` -> `[RESEARCHED]`" | AGENT EDIT (status) |
| K3 | `skill-status-sync/SKILL.md` | 205-213 | "Add link to TODO.md using Edit tool" — count-aware artifact linking | AGENT EDIT (artifact) |
| K4 | `skill-nix-implementation/SKILL.md` | 44 | "Use Edit tool to change status marker from `[PLANNED]` to `[IMPLEMENTING]`" | AGENT EDIT (status) |
| K5 | `skill-nix-implementation/SKILL.md` | 267 | "Link artifact using count-aware format" — four-case Edit logic on TODO.md | AGENT EDIT (artifact) |
| K6 | `skill-neovim-implementation/SKILL.md` | 251 | "Link artifact using count-aware format" — four-case Edit logic on TODO.md | AGENT EDIT (artifact) |
| K7 | `skill-neovim-implementation/SKILL.md` | 319 | "Updating TODO.md status marker via Edit" (listed as postflight write) | AGENT EDIT (status) |
| K8 | `skill-nix-research/SKILL.md` | 180 | "Update TODO.md: Link artifact using count-aware format" | AGENT EDIT (artifact) |
| K9 | `skill-neovim-research/SKILL.md` | 180 | "Update TODO.md: Link artifact using count-aware format" | AGENT EDIT (artifact) |
| K10 | `skill-reviser/SKILL.md` | 319 | "Then use Edit tool to update the description in TODO.md" | AGENT EDIT (description) |
| K11 | `skill-reviser/SKILL.md` | 380 | "Update TODO.md: Link artifact using the automated script" (calls link-artifact-todo.sh) | AGENT SCRIPT CALL (artifact) |
| K12 | `skill-spawn/SKILL.md` | 92-98 | "Use Edit tool to change status marker to `[BLOCKED]`" in TODO.md | AGENT EDIT (status) |
| K13 | `skill-spawn/SKILL.md` | 360-377 | "Insert new task entries after the Tasks header" in TODO.md | AGENT EDIT (new entries) |
| K14 | `skill-spawn/SKILL.md` | 402-414 | "Edit the parent task entry to add/update the Dependencies line" in TODO.md | AGENT EDIT (dependencies) |
| K15 | `skill-orchestrate/SKILL.md` | 434-439 | Direct call to `link-artifact-todo.sh` for artifact linking | SCRIPT CALL (artifact) |
| K16 | `skill-orchestrate/SKILL.md` | 1076-1079 | Direct call to `link-artifact-todo.sh` (multi-task section) | SCRIPT CALL (artifact) |
| K17 | `skill-todo/SKILL.md` | 316-331 | "Remove archived entries" from TODO.md via Edit tool | AGENT EDIT (entry removal) |
| K18 | `skill-todo/SKILL.md` | 342-367 | "Archive TODO.md orphans" — remove orphan entries | AGENT EDIT (entry removal) |
| K19 | `skill-todo/SKILL.md` | 618-636 | Vault renumbering: sed replaces task headers, artifact links, dependency refs in TODO.md | SED (renumber) |
| K20 | `skill-todo/SKILL.md` | 685-699 | Vault transition comment: sed inserts HTML comment in TODO.md | SED (comment) |
| K21 | `skill-todo/SKILL.md` | 765-781 | "Regenerate Task Order section" — calls `generate-task-order.sh --update-todo` | SCRIPT CALL (task order) |
| K22 | `skill-fix-it/SKILL.md` | 481-510 | "Prepend new task entry to `## Tasks` section" in TODO.md | AGENT EDIT (new entries) |
| K23 | `skill-project-overview/SKILL.md` | 376-393 | "Prepend new task entry to the Tasks section" + calls `link-artifact-todo.sh` | AGENT EDIT (new entry) + SCRIPT CALL |
| K24 | `skill-team-research/SKILL.md` | 440-448 | Via `skill_postflight_update` + `skill_link_artifacts` (indirect through skill-base.sh) | INDIRECT |
| K25 | `skill-team-plan/SKILL.md` | 394-399 | Via `skill_postflight_update` + `skill_link_artifacts` (indirect) | INDIRECT |
| K26 | `skill-team-implement/SKILL.md` | 471-476 | Via `skill_postflight_update` + `skill_link_artifacts` (indirect) | INDIRECT |

### 1C. Command Definitions (Orchestrator-Level Writers)

| # | File | Lines | What It Does | Write Type |
|---|------|-------|-------------|------------|
| C1 | `commands/task.md` | 197-227 | Create mode: sed updates frontmatter `next_project_number`, Edit inserts new task entry, calls `generate-task-order.sh` | SED + AGENT EDIT (new entry) |
| C2 | `commands/task.md` | 295 | Recover mode: "Prepend recovered task entry to `## Tasks` section" | AGENT EDIT (new entry) |
| C3 | `commands/task.md` | 336 | Expand mode: "Also update TODO.md: Change task status to `[EXPANDED]`" | AGENT EDIT (status) |
| C4 | `commands/task.md` | 348-369 | Sync mode: "Use Edit to update TODO.md" for bidirectional sync, calls `generate-task-order.sh` | AGENT EDIT (sync) |
| C5 | `commands/task.md` | 656 | Followup: "Update TODO.md (add entry and update frontmatter)" | AGENT EDIT (new entry) |
| C6 | `commands/task.md` | 744 | Abandon mode: "Remove the task entry" from TODO.md | AGENT EDIT (entry removal) |
| C7 | `commands/review.md` | 562-563 | "Add task entry following existing format in TODO.md" | AGENT EDIT (new entry) |
| C8 | `commands/review.md` | 601-613 | Calls `generate-task-order.sh --update-todo` | SCRIPT CALL (task order) |
| C9 | `commands/review.md` | 716 | "Edit tool to replace goal line in TODO.md" | AGENT EDIT (goal) |
| C10 | `commands/implement.md` | 173 | "Add `- **Summary**: {completion_summary}` line to the task entry in TODO.md" | AGENT EDIT (summary field) |
| C11 | `commands/implement.md` | 177 | "If `[IMPLEMENTING]` still present, apply correction to both task entry and Task Order" | AGENT EDIT (defensive status) |
| C12 | `commands/errors.md` | 135-141 | Calls `generate-task-order.sh --update-todo` (after /task creates entries) | SCRIPT CALL (task order) |
| C13 | `commands/spawn.md` | 118 | "Update TODO.md with new task entries" | AGENT (delegated to skill-spawn) |
| C14 | `commands/meta.md` | 29 | "Track all work via tasks in TODO.md + state.json" | AGENT (delegated to meta-builder) |

### 1D. Agent Definitions (Agent-Level Writers)

| # | File | Lines | What It Does | Write Type |
|---|------|-------|-------------|------------|
| A1 | `agents/meta-builder-agent.md` | 730-803 | Creates TODO.md entries using batch insertion pattern (Edit after `## Tasks`) | AGENT EDIT (new entries, batch) |
| A2 | `agents/meta-builder-agent.md` | 1400-1439 | "Insert batch into TODO.md" + calls `generate-task-order.sh --update-todo` | AGENT EDIT + SCRIPT CALL |

---

## 2. Plan File Inventory: Direct Plan Status Writers

| # | File | Lines | What It Does |
|---|------|-------|-------------|
| P1 | `.claude/scripts/update-plan-status.sh` | 51-60 | sed replaces `[STATUS]` in plan file `- **Status**:` line |
| P2 | `.claude/scripts/update-phase-status.sh` | (entire) | sed replaces `[STATUS]` in phase heading `### Phase N: {name} [STATUS]` |
| P3 | `.claude/scripts/update-task-status.sh` | 373-409 (Phase 4) | Delegates to `update-plan-status.sh` for implement/plan operations |
| P4 | `skill-nix-implementation/SKILL.md` | 240 | Calls `update-plan-status.sh "$task_number" "$project_name" "PARTIAL"` |
| P5 | `skill-neovim-implementation/SKILL.md` | 240 | Calls `update-plan-status.sh "$task_number" "$project_name" "PARTIAL"` |
| P6 | `skill-orchestrate/SKILL.md` | 498, 585 | Reads plan files (`ls plans/*.md`) but does not directly modify them |
| P7 | `skill-implementer/SKILL.md` | 88 | References `update-phase-status.sh` as available to subagent |

**Assessment**: Plan file status updates are NOT part of the state.json-first migration. Plan files are self-contained documents with their own status markers. `update-plan-status.sh` (P1) and `update-phase-status.sh` (P2) modify the plan file itself, not TODO.md or state.json. These are properly scoped and covered by task 650.

---

## 3. State.json Write Points (Authoritative Writers)

| File | Purpose | Covered? |
|------|---------|----------|
| `update-task-status.sh` Phase 1 | Status + timestamps via flock | Yes (task 649 keeps this) |
| `postflight-workflow.sh` Steps 1-3 | Status + artifacts via jq | Yes (task 649 adds generate-todo.sh) |
| `skill-base.sh` `skill_link_artifacts()` | Artifact array in state.json | Yes (task 649 updates this) |
| `archive-task.sh` Sections A-B | Move to archive, remove from active | Yes (uses generate-todo.sh via /todo) |
| `reconcile-task-status.sh` | Recovery: link artifacts in state.json | Deferred to 652 |
| `vault-operation.sh` | Renumber state.json entries during vault | Covered by skill-todo |
| `skill-orchestrate/SKILL.md` | Direct jq artifact linking | Yes (task 649 replaces link-artifact-todo calls) |
| `commands/task.md` | Create, recover, expand, abandon, sync | **PARTIALLY COVERED** (see gaps) |
| `commands/review.md` | Create tasks from review findings | **NOT COVERED** (see gaps) |
| `skill-fix-it/SKILL.md` | Create tasks from FIX: tags | **NOT COVERED** (see gaps) |
| `skill-spawn/SKILL.md` | Create child tasks | **NOT COVERED** (see gaps) |
| `skill-project-overview/SKILL.md` | Create task | **NOT COVERED** (see gaps) |
| `agents/meta-builder-agent.md` | Batch create tasks | **NOT COVERED** (see gaps) |
| `skill-todo/SKILL.md` | Archive, vault renumber | **PARTIALLY COVERED** |

---

## 4. Coverage Matrix

### Legend
- **649**: Simplify state update pipeline
- **650**: Phase-level plan tracking (completed)
- **651**: Update rules and documentation
- **652**: Post-validation cleanup
- **GEN**: Automatically resolved by generate-todo.sh being called after state.json update
- **GAP**: Not addressed by any task

### Script-Level Writers

| Writer | Task | Notes |
|--------|------|-------|
| S1: update-task-status.sh Phase 2 (status awk) | **649** | Remove Phase 2, replace with generate-todo.sh |
| S2: update-task-status.sh Phase 3 (task order awk) | **649** | Remove Phase 3, replace with generate-todo.sh |
| S3: link-artifact-todo.sh (entire file) | **649** (deprecate) / **652** (remove) | Deprecation logging in 649, removal in 652 |
| S4: archive-task.sh Section C (entry removal) | **GAP** | **Not addressed** — removes task block from TODO.md via Python |
| S5: generate-task-order.sh (task order section) | **GEN** | Subsumed: generate-todo.sh calls generate-task-order.sh --print |
| S6: vault-operation.sh (renumber sed) | **GAP** | **Not addressed** — should call generate-todo.sh instead of sed |
| S7: vault-operation.sh (comment insert) | **GAP** | **Not addressed** — transition comment still uses sed on TODO.md |
| S8: reconcile-task-status.sh (link-artifact-todo call) | **652** (deferred) | Explicitly deferred in 649 research |
| S9: skill-base.sh (link-artifact-todo call) | **649** | Replace with generate-todo.sh call |
| S10: generate-todo.sh | N/A | This IS the replacement |

### Skill-Level Writers

| Writer | Task | Notes |
|--------|------|-------|
| K1-K2: skill-status-sync (Edit status) | **651** / **GAP** | 651 mentions updating skill-status-sync, but the SKILL.md still instructs agents to Edit TODO.md directly |
| K3: skill-status-sync (Edit artifact) | **651** / **GAP** | Same — must update to remove artifact linking instructions |
| K4: skill-nix-implementation (Edit status) | **GAP** | **Not addressed by any task** |
| K5-K6: skill-nix/neovim-implementation (Edit artifact) | **GAP** | **Not addressed** — four-case Edit logic must be removed |
| K7: skill-neovim-implementation (Edit status) | **GAP** | **Not addressed** |
| K8-K9: skill-nix/neovim-research (Edit artifact) | **GAP** | **Not addressed** — artifact linking instructions must be removed |
| K10: skill-reviser (Edit description) | **GAP** | **Not addressed** — instructs agent to Edit description in TODO.md |
| K11: skill-reviser (link-artifact-todo call) | **649** | Explicitly listed in 649 research findings |
| K12-K14: skill-spawn (Edit status, entries, deps) | **GAP** | **Not addressed** — 3 separate Edit operations on TODO.md |
| K15-K16: skill-orchestrate (link-artifact-todo calls) | **649** | Explicitly listed in 649 research findings |
| K17-K18: skill-todo (Edit entry removal) | **GAP** | **Not addressed** — still uses Edit to remove entries instead of generate-todo.sh |
| K19-K20: skill-todo (vault renumber/comment) | **GAP** | **Not addressed** — sed operations on TODO.md |
| K21: skill-todo (generate-task-order.sh call) | **GEN** | Subsumed by generate-todo.sh |
| K22: skill-fix-it (Edit new entries) | **GAP** | **Not addressed** — creates task entries directly in TODO.md |
| K23: skill-project-overview (Edit + link) | **GAP** | 649 research notes this as "low priority" but no task covers it |
| K24-K26: team skills (indirect via skill-base) | **649** | Resolved when skill-base.sh is updated |

### Command-Level Writers

| Writer | Task | Notes |
|--------|------|-------|
| C1: task.md Create (sed frontmatter + Edit entry) | **GAP** | **Not addressed** — /task create writes directly to TODO.md |
| C2: task.md Recover (Edit entry) | **GAP** | **Not addressed** |
| C3: task.md Expand (Edit status) | **GAP** | **Not addressed** |
| C4: task.md Sync (Edit) | **GAP** | **Not addressed** — bidirectional sync still edits TODO.md |
| C5: task.md Followup (Edit entry + frontmatter) | **GAP** | **Not addressed** |
| C6: task.md Abandon (Edit remove entry) | **GAP** | **Not addressed** |
| C7: review.md (Edit new entry) | **GAP** | **Not addressed** |
| C8: review.md (generate-task-order.sh) | **GEN** | Subsumed by generate-todo.sh |
| C9: review.md (Edit goal line) | **GAP** | **Not addressed** — goal line is a TODO.md-specific feature |
| C10: implement.md (Edit summary field) | **GAP** | **Not addressed** — adds completion summary to TODO.md entry |
| C11: implement.md (defensive status correction) | **GAP** | **Not addressed** |
| C12: errors.md (generate-task-order.sh) | **GEN** | Subsumed by generate-todo.sh |
| C13: spawn.md (delegated to skill) | See K12-K14 | Covered if skill-spawn is updated |
| C14: meta.md (delegated to agent) | See A1-A2 | Covered if meta-builder-agent is updated |

### Agent-Level Writers

| Writer | Task | Notes |
|--------|------|-------|
| A1-A2: meta-builder-agent (batch task entry + task order) | **GAP** | **Not addressed** — creates batch entries in TODO.md via Edit |

---

## 5. Gap List: Uncovered Writers

### CRITICAL GAPS (Will cause data loss when generate-todo.sh overwrites)

These writers create or modify TODO.md content that is NOT derived from state.json. When generate-todo.sh runs, it will overwrite their changes.

| Gap# | File | Writer | What It Does | Risk | Recommendation |
|------|------|--------|-------------|------|----------------|
| G1 | `commands/task.md` | C1 | Creates new task entries in TODO.md + sed frontmatter | **HIGH** — new tasks won't appear until next generate-todo.sh call | Replace all TODO.md writes with: state.json update + `generate-todo.sh` call |
| G2 | `commands/task.md` | C2 | Recovers task entries into TODO.md | **HIGH** — recovered task won't appear | Same as G1 |
| G3 | `commands/task.md` | C3 | Changes status to `[EXPANDED]` | **MEDIUM** — generate-todo.sh renders from state.json, but if called before status update completes... | Remove Edit; rely on update-task-status.sh + generate-todo.sh |
| G4 | `commands/task.md` | C4 | Bidirectional sync edits TODO.md | **MEDIUM** — sync mode concept changes fundamentally | Rewrite sync mode: state.json is truth, regenerate TODO.md |
| G5 | `commands/task.md` | C5 | Followup task entries in TODO.md | **HIGH** — followup tasks won't appear | Same as G1 |
| G6 | `commands/task.md` | C6 | Removes abandoned task entry | **LOW** — archive-task.sh handles removal, generate-todo.sh won't render archived tasks | Remove Edit; rely on archive-task.sh + generate-todo.sh |
| G7 | `commands/review.md` | C7 | Creates review task entries | **HIGH** — review tasks won't appear | Same as G1 |
| G8 | `commands/review.md` | C9 | Edits goal line in TODO.md | **MEDIUM** — goal is a TODO.md feature not in state.json | Add goal field to state.json or keep as manual post-generation edit |
| G9 | `commands/implement.md` | C10 | Adds `**Summary**` field to task entry | **LOW** — generate-todo.sh renders artifacts from state.json | Remove Edit; artifacts already in state.json |
| G10 | `commands/implement.md` | C11 | Defensive status correction on TODO.md | **LOW** — state.json is truth, generate-todo.sh renders correctly | Remove defensive TODO.md correction |
| G11 | `skill-spawn/SKILL.md` | K12-K14 | Creates child task entries + updates parent status/deps in TODO.md | **HIGH** — spawned tasks won't appear | Replace with state.json updates + generate-todo.sh |
| G12 | `skill-fix-it/SKILL.md` | K22 | Creates fix-it task entries in TODO.md | **HIGH** — fix-it tasks won't appear | Same as G1 |
| G13 | `skill-project-overview/SKILL.md` | K23 | Creates project-overview task entry | **HIGH** — task won't appear | Same as G1 |
| G14 | `agents/meta-builder-agent.md` | A1-A2 | Batch creates task entries in TODO.md | **HIGH** — meta tasks won't appear | Same as G1 |
| G15 | `skill-status-sync/SKILL.md` | K1-K3 | Edits status + artifacts in TODO.md | **MEDIUM** — redundant with generate-todo.sh | Remove Edit instructions; call generate-todo.sh after state.json update |
| G16 | `skill-nix-implementation/SKILL.md` | K4-K5 | Edits status + artifacts in TODO.md | **MEDIUM** — redundant with generate-todo.sh | Remove Edit instructions |
| G17 | `skill-neovim-implementation/SKILL.md` | K6-K7 | Edits status + artifacts in TODO.md | **MEDIUM** — redundant with generate-todo.sh | Remove Edit instructions |
| G18 | `skill-nix-research/SKILL.md` | K8 | Edits artifacts in TODO.md | **MEDIUM** — redundant | Remove Edit instructions |
| G19 | `skill-neovim-research/SKILL.md` | K9 | Edits artifacts in TODO.md | **MEDIUM** — redundant | Remove Edit instructions |
| G20 | `skill-reviser/SKILL.md` | K10 | Edits description in TODO.md | **LOW** — description already in state.json | Remove Edit instruction |
| G21 | `skill-todo/SKILL.md` | K17-K18 | Removes archived entries from TODO.md via Edit | **MEDIUM** — after archive, generate-todo.sh won't include archived tasks anyway | Replace with generate-todo.sh call after archive |
| G22 | `skill-todo/SKILL.md` | K19-K20 | Vault renumber + comment via sed | **MEDIUM** — vault renumber modifies state.json first, then TODO.md via sed | Replace sed with generate-todo.sh call (comment can go in frontmatter or state.json) |
| G23 | `archive-task.sh` | S4 | Python removes task block from TODO.md | **MEDIUM** — after removal from state.json, generate-todo.sh won't include it | Replace Python block with generate-todo.sh call |

---

## 6. Plan File Pipeline Assessment

### Already Covered
- **update-plan-status.sh** (P1): Modifies plan file only. No TODO.md changes. Not affected by migration.
- **update-phase-status.sh** (P2): Created by task 650. Modifies phase headings in plan files only. Properly scoped.
- **update-task-status.sh Phase 4** (P3): Delegates to update-plan-status.sh. Not affected.

### No Gaps
Plan file status updates are independent of the state.json-first migration. They modify self-contained plan documents, not TODO.md or state.json. Task 650 properly handles phase-level tracking. No additional work needed.

---

## 7. Recommendation

### Task 649 Coverage Is Incomplete

Task 649's research report (01_pipeline-simplification-research.md) correctly identifies 6 files to modify but **misses 17 additional writers**:

**What task 649 covers:**
1. `update-task-status.sh` — Remove Phases 2+3
2. `postflight-workflow.sh` — Add generate-todo.sh call
3. `skill-base.sh` — Replace link-artifact-todo.sh with generate-todo.sh
4. `link-artifact-todo.sh` — Deprecation logging
5. `skill-orchestrate/SKILL.md` — Replace link-artifact-todo.sh calls (2 locations)
6. `skill-reviser/SKILL.md` — Replace link-artifact-todo.sh call

**What task 649 does NOT cover (but should be addressed):**

The following writers will continue writing directly to TODO.md even after task 649 completes. Every time generate-todo.sh runs, it will overwrite these manual writes, causing user-visible data loss or confusion.

#### Category A: Task Creation Writers (8 gaps — HIGH priority)

These all create new task entries directly in TODO.md. After the migration, they must instead: (1) update state.json, then (2) call generate-todo.sh.

| Gap | File | Current Pattern |
|-----|------|----------------|
| G1 | `commands/task.md` (Create) | sed frontmatter + Edit entry |
| G2 | `commands/task.md` (Recover) | Edit entry |
| G5 | `commands/task.md` (Followup) | Edit entry + frontmatter |
| G7 | `commands/review.md` | Edit entry |
| G11 | `skill-spawn/SKILL.md` | Edit entries + status + deps |
| G12 | `skill-fix-it/SKILL.md` | Edit entries |
| G13 | `skill-project-overview/SKILL.md` | Edit entry + link-artifact-todo |
| G14 | `agents/meta-builder-agent.md` | Batch Edit entries |

#### Category B: Status/Artifact/Field Writers (12 gaps — MEDIUM priority)

These modify individual fields in existing TODO.md entries. After the migration, they become redundant because generate-todo.sh renders everything from state.json.

| Gap | File | Current Pattern |
|-----|------|----------------|
| G3 | `commands/task.md` (Expand status) | Edit status |
| G4 | `commands/task.md` (Sync) | Bidirectional Edit |
| G6 | `commands/task.md` (Abandon removal) | Edit remove |
| G8 | `commands/review.md` (Goal line) | Edit goal |
| G9-G10 | `commands/implement.md` | Edit summary + defensive |
| G15 | `skill-status-sync/SKILL.md` | Edit status + artifacts |
| G16-G19 | Extension skills (nix/neovim) | Edit status + artifacts |
| G20 | `skill-reviser/SKILL.md` | Edit description |

#### Category C: Archive/Vault Writers (3 gaps — MEDIUM priority)

| Gap | File | Current Pattern |
|-----|------|----------------|
| G21 | `skill-todo/SKILL.md` | Edit remove entries |
| G22 | `skill-todo/SKILL.md` | sed vault renumber + comment |
| G23 | `archive-task.sh` | Python remove entry |

### Recommended Action

**Option 1 (Recommended): Expand task 649's scope** to include all Category A gaps as part of the implementation plan. This is essential because Category A writers create new task entries that will be immediately overwritten by generate-todo.sh. The pattern is identical for all: replace the TODO.md Edit with a `generate-todo.sh` call after state.json is updated.

**Option 2: Create a new task 653** specifically for "Update all task creation commands to use state.json-first pattern" covering Category A gaps. Task 649 handles the pipeline scripts, task 653 handles the commands/skills/agents that create tasks.

**Category B and C gaps** can be addressed by task 651 (documentation update) since they are instructions in SKILL.md and command files, not executable code. The instruction to "use Edit tool on TODO.md" just needs to be removed or replaced with "call generate-todo.sh".

### Critical Path

```
Task 649 (pipeline scripts) ──> Task 653/649-expanded (task creation writers)
       |                                    |
       └──> Task 651 (docs, Category B+C) ──> Task 652 (cleanup)
```

### Goal Line Issue (G8)

The `/review` command has a "goal line" feature (`## Active Goal: ...` in TODO.md) that is NOT tracked in state.json. If generate-todo.sh overwrites this, it will be lost. Options:
1. Add `active_goal` field to state.json (preferred — matches state.json-first pattern)
2. Make generate-todo.sh preserve `## Active Goal` section if present (fragile)
3. Move goal tracking to a separate file (e.g., `specs/GOAL.md`)

---

## 8. Summary Statistics

| Category | Total Writers | Covered by 649 | Covered by 650 | Covered by 651 | Covered by 652 | Auto-resolved (GEN) | **UNCOVERED** |
|----------|---------------|-----------------|-----------------|-----------------|-----------------|---------------------|---------------|
| Scripts (S1-S10) | 10 | 3 | 0 | 0 | 1 | 2 | **3** (S4, S6, S7) |
| Skills (K1-K26) | 26 | 4 | 0 | 0 | 0 | 1 | **17** |
| Commands (C1-C14) | 14 | 0 | 0 | 0 | 0 | 2 | **10** |
| Agents (A1-A2) | 2 | 0 | 0 | 0 | 0 | 0 | **2** |
| Plan files (P1-P7) | 7 | 0 | 7 | 0 | 0 | 0 | 0 |
| **TOTAL** | **59** | **7** | **7** | **0** | **1** | **5** | **32** |

**32 of 59 writers are uncovered by the current task pipeline.**

Of those 32 uncovered writers, 8 are HIGH priority (Category A: task creation), 21 are MEDIUM priority (Category B+C: can be addressed as documentation/instruction updates), and 3 are LOW priority.

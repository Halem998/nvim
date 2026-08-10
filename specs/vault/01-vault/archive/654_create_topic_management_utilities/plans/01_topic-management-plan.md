# Implementation Plan: Create Topic Management Utilities

- **Task**: 654 - create_topic_management_utilities
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/654_create_topic_management_utilities/reports/01_topic-management-research.md
- **Artifacts**: specs/654_create_topic_management_utilities/plans/01_topic-management-plan.md
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: meta

## Overview

Topic picker logic is duplicated across 6 files (~147 lines) in the `.claude/` agent system. The `active_topics` maintenance jq snippet appears verbatim 5 times; the full interactive AskUserQuestion picker is inlined 3 times. This plan creates two shared artifacts: `manage-topics.sh` (a script encapsulating mechanical state.json operations) and `topic-assignment-pattern.md` (a context pattern document describing the three picker modes). Tasks 655 and 656 will refactor existing commands to reference these utilities. Definition of done: the script has all four subcommands working against live state.json, the pattern document covers all three modes with copy-paste-ready examples, and the context index is updated.

### Research Integration
- Integrated: `specs/654_create_topic_management_utilities/reports/01_topic-management-research.md`

## Goals & Non-Goals

- **Goals**:
  - Create `.claude/scripts/manage-topics.sh` with `list`, `add`, `set`, `validate` subcommands
  - Create `.claude/context/patterns/topic-assignment-pattern.md` documenting the three assignment modes
  - Register the pattern document in `.claude/context/index.json`
  - Follow existing script conventions (tmp-file atomic write, `set -euo pipefail`, SCRIPT_DIR/PROJECT_ROOT paths)
- **Non-Goals**:
  - Refactoring existing commands to use the utilities (tasks 655 and 656)
  - Adding flock-based locking (no flock is used anywhere in the codebase; tmp-file rename is the convention)
  - Modifying state.json schema

## Risks & Mitigations

- **Risk**: task description says "flock" but research confirms no flock exists in the codebase. **Mitigation**: use tmp-file atomic write pattern (`jq … > file.tmp && mv file.tmp file`) consistent with all other scripts; document the discrepancy in a comment.
- **Risk**: `set TASK_NUM TOPIC` writing to state.json while another process also writes. **Mitigation**: tmp-file atomic rename minimizes the window; callers are Claude Code agents which are single-threaded per session.
- **Risk**: context index entry uses wrong `load_when` conditions, causing pattern doc not to load. **Mitigation**: cross-check against existing meta-task entries in index.json during Phase 3.
- **Risk**: jq `index()` safety under Issue #1132 (Claude Code Bash escaping). **Mitigation**: the `index($t) == null` pattern is already safe (no `!=` operator); validate during Phase 4.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Create manage-topics.sh [COMPLETED]

- **Goal:** Produce a working `.claude/scripts/manage-topics.sh` with four subcommands: `list`, `add TOPIC`, `set TASK_NUM TOPIC`, `validate TOPIC`.
- **Tasks:**
  - [ ] Create `.claude/scripts/manage-topics.sh` with shebang `#!/usr/bin/env bash`
  - [ ] Add header comment block: purpose, usage, subcommands, exit codes
  - [ ] Add `set -euo pipefail`
  - [ ] Add SCRIPT_DIR/PROJECT_ROOT/STATE_FILE/TMP_DIR path resolution (matching `update-task-status.sh` pattern)
  - [ ] Add cleanup trap: `trap 'rm -f "$TMP_DIR/state.json.tmp" 2>/dev/null || true' EXIT`
  - [ ] Implement `list` subcommand: `jq -r '.active_topics // [] | .[]' "$STATE_FILE"`
  - [ ] Implement `add TOPIC` subcommand: idempotent append using `if ((.active_topics // []) | index($t)) == null then … else . end` pattern; two-step tmp-file write; validate JSON before mv
  - [ ] Implement `set TASK_NUM TOPIC` subcommand: validate task exists; update `.active_projects[] | select(.project_number == ($num | tonumber)) | .topic`; call `add` logic inline to keep active_topics consistent; two-step tmp-file write
  - [ ] Implement `validate TOPIC` subcommand: exit 0 if topic in active_topics, exit 1 if not; no stdout
  - [ ] Add top-level usage/help output for unknown subcommands or missing args
  - [ ] Make executable: `chmod +x .claude/scripts/manage-topics.sh`
- **Timing:** 45 minutes
- **Depends on:** none

### Phase 2: Create topic-assignment-pattern.md [COMPLETED]

- **Goal:** Produce a complete pattern document at `.claude/context/patterns/topic-assignment-pattern.md` that commands can reference instead of inlining picker logic.
- **Tasks:**
  - [ ] Create `.claude/context/patterns/topic-assignment-pattern.md`
  - [ ] Write header: `# Topic Assignment Pattern` with Created date, Purpose, Audience
  - [ ] Write Overview section: problem (duplication), solution (shared script + pattern doc), three modes summary
  - [ ] Write **Mode A: Interactive** section:
    - List caller locations: `/task` Create, `/task` Sync backfill, `/meta` Interview Stage 4.5
    - Show canonical bash: `manage-topics.sh list` → build options array
    - Show AskUserQuestion JSON template (options: existing topics + "New topic..." + "Skip (no topic)")
    - Show "New topic..." follow-up free-text AskUserQuestion
    - Show state update calls: `manage-topics.sh add "$topic"`, `manage-topics.sh set "$task_num" "$topic"`
  - [ ] Write **Mode B: Inherit** section:
    - List caller locations: `/task --expand`, `/task --recover` follow-up tasks, `/spawn`
    - Show canonical bash: read parent topic via jq, then `manage-topics.sh add "$parent_topic"` + `manage-topics.sh set "$new_num" "$parent_topic"` (no picker shown)
    - Note: if parent has no topic, no topic is assigned (no fallback picker in current implementation)
  - [ ] Write **Mode C: Suggest** section:
    - List caller locations: `/review`, `/fix-it`
    - Show canonical bash: `manage-topics.sh list` → path heuristic matching → `manage-topics.sh add "$inferred"` + `manage-topics.sh set "$task_num" "$inferred"` (no picker)
    - Include path heuristic table: `.claude/` or `specs/` → look for meta/agent-system; `lua/` or `after/` → look for neovim/nvim/lua
  - [ ] Write **State Update Reference** section: table of manage-topics.sh subcommands with description and example
  - [ ] Write Related Documentation section with cross-references
- **Timing:** 45 minutes
- **Depends on:** 1

### Phase 3: Register in context index [COMPLETED]

- **Goal:** Add `topic-assignment-pattern.md` to `.claude/context/index.json` so agents load it when relevant.
- **Tasks:**
  - [ ] Read existing `.claude/context/index.json` to understand entry structure (especially patterns entries)
  - [ ] Add new entry for `topic-assignment-pattern.md`:
    - `path`: `.claude/context/patterns/topic-assignment-pattern.md`
    - `description`: brief description of the pattern
    - `subdomain`: `patterns`
    - `topics`: `["topic-management", "state-json", "active-topics", "picker"]`
    - `load_when.agents`: `["meta-builder-agent"]`
    - `load_when.task_types`: `["meta"]`
    - `load_when.commands`: `["/task", "/meta", "/spawn", "/review", "/fix-it"]`
    - `line_count`: actual line count after Phase 2 completes
  - [ ] Validate that modified index.json is valid JSON: `jq empty .claude/context/index.json`
- **Timing:** 15 minutes
- **Depends on:** 2

### Phase 4: Verification [COMPLETED]

- **Goal:** Confirm all deliverables work correctly against live state.json.
- **Tasks:**
  - [ ] Test `manage-topics.sh list`: output should match `jq -r '.active_topics[]' specs/state.json` (currently: wezterm-notifications, workflow-refactor, agent-system)
  - [ ] Test `manage-topics.sh validate agent-system`: should exit 0
  - [ ] Test `manage-topics.sh validate nonexistent-topic-xyz`: should exit 1
  - [ ] Test `manage-topics.sh add agent-system` (idempotent): run twice, confirm active_topics unchanged
  - [ ] Test `manage-topics.sh add test-topic-654`: adds to active_topics; then remove with a manual jq cleanup
  - [ ] Test `manage-topics.sh set 654 agent-system`: confirm task 654 topic field unchanged in state.json
  - [ ] Confirm pattern doc is well-formed markdown (no broken sections)
  - [ ] Confirm index.json passes `jq empty`
  - [ ] Confirm `manage-topics.sh` is executable (`test -x .claude/scripts/manage-topics.sh`)
- **Timing:** 15 minutes
- **Depends on:** 1, 2, 3

## Testing & Validation

- [ ] `bash .claude/scripts/manage-topics.sh list` returns current active topics
- [ ] `bash .claude/scripts/manage-topics.sh validate agent-system` exits 0
- [ ] `bash .claude/scripts/manage-topics.sh validate xyz-nonexistent` exits 1
- [ ] Idempotency: adding an existing topic does not change state.json
- [ ] `jq empty .claude/context/index.json` passes
- [ ] `test -x .claude/scripts/manage-topics.sh` passes
- [ ] Pattern doc has all three mode sections (A: Interactive, B: Inherit, C: Suggest)

## Artifacts & Outputs

- `.claude/scripts/manage-topics.sh` — new script with four subcommands
- `.claude/context/patterns/topic-assignment-pattern.md` — new pattern document
- `.claude/context/index.json` — updated with new pattern entry

## Rollback/Contingency

- `manage-topics.sh` is a new file; rollback is `git rm .claude/scripts/manage-topics.sh`
- `topic-assignment-pattern.md` is a new file; rollback is `git rm .claude/context/patterns/topic-assignment-pattern.md`
- `index.json` change is additive (new entry only); rollback is removing the new entry with jq
- Tasks 655 and 656 depend on this task; if rollback is needed, those tasks cannot proceed

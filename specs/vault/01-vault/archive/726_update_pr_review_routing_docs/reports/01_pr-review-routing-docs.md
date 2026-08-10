# Research Report: Task #726

**Task**: 726 - Register pr task type routing for core agent system (pr-review skills)
**Started**: 2026-06-15T00:00:00Z
**Completed**: 2026-06-15T00:15:00Z
**Effort**: ~30 minutes
**Dependencies**: Tasks 722, 723, 724, 725 (all complete)
**Sources/Inputs**: Codebase (manifest.json, EXTENSION.md, CLAUDE.md, pr-prohibition.md, skill files)
**Artifacts**: `specs/726_update_pr_review_routing_docs/reports/01_pr-review-routing-docs.md`
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The CSLib extension's `manifest.json` already contains pr routing entries for both research and implement operations, routing "pr" task type to `skill-pr-review-research` and `skill-pr-review-implementation` respectively. This routing is **functionally complete** — no change needed to `manifest.json`.
- The CSLib `EXTENSION.md` (merge source for CLAUDE.md) is missing `skill-pr-review-implementation` from the Skill-Agent Mapping table. Task 724's agent (`pr-review-implementation-agent`) is also absent from that table.
- The core `claudemd.md` merge source does not reference the `/pr` command or `pr` task type at all — the core command reference table only includes `/merge`. A `/pr` entry for the `--review` flag needs to be added there.
- `pr-prohibition.md` documents the old CSLib pr workflow but does not mention the new `--review` flag or the pr-review workflow. It needs an update.
- The `pr-prohibition.md` also needs to clarify that the `/pr --review` workflow creates a `pr` task type that routes to the new review skills (not to `skill-pr-implementation`).

---

## Context & Scope

Task 726 registers the new `pr` task type routing for the core agent system documentation and rules. Predecessor tasks 722-725 added the `--review` flag to `/pr`, created the two new skills and agents, and added STEP 0.5 to `/pr` for handling PR READY review tasks. This task updates documentation so users and agents understand the routing split between CSLib pr-submission and pr-review workflows.

---

## Findings

### 1. CSLib manifest.json — Routing Already Present

**File**: `.claude/extensions/cslib/manifest.json` (lines 39-54)

Current routing section:
```json
"routing": {
  "research": {
    "cslib": "skill-cslib-research",
    "pr": "skill-pr-review-research"
  },
  "plan": {
    "cslib": "skill-planner",
    "pr": "skill-planner"
  },
  "implement": {
    "cslib": "skill-cslib-implementation",
    "pr": "skill-pr-review-implementation"
  }
}
```

**Assessment**: The manifest already routes:
- `/research N` (pr type) → `skill-pr-review-research`
- `/implement N` (pr type) → `skill-pr-review-implementation`

The routing is correct and complete. The `command-route-skill.sh` script reads this manifest at runtime, so no changes are needed here.

**Note**: `skill-pr-implementation` (for pr-submission workflow) is NOT in the routing table. It was previously the route for pr tasks but is now superseded. The `skill-pr-review-implementation` dispatches to `cslib-implementation-agent` for legacy pr-submission tasks (sources absent) as a fallback.

### 2. CSLib EXTENSION.md — Missing skill-pr-review-implementation Entry

**File**: `.claude/extensions/cslib/EXTENSION.md` (line 21 current state)

Current Skill-Agent Mapping table:
```
| skill-cslib-research       | cslib-research-agent       | opus   | CSLib formalization research... |
| skill-cslib-implementation | cslib-implementation-agent | sonnet | CSLib proof implementation... |
| skill-pr-implementation    | cslib-implementation-agent | sonnet | PR description preparation only... |
| skill-cslib-research-hard  | cslib-research-hard-agent  | opus   | Hard-mode CSLib research... |
| skill-cslib-implementation-hard | cslib-implementation-hard-agent | sonnet | Hard-mode CSLib... |
| skill-pr-review-research   | pr-review-research-agent   | sonnet | Fetch and synthesize GitHub PR... |
```

**Missing**: `skill-pr-review-implementation` → `pr-review-implementation-agent` row.

**Change needed**: Add after the `skill-pr-review-research` line:
```
| skill-pr-review-implementation | pr-review-implementation-agent | sonnet | Compose GitHub PR and Zulip response files for pr-type review tasks; legacy path delegates to cslib-implementation-agent |
```

### 3. Core CLAUDE.md (via merge-sources/claudemd.md) — Missing /pr Command Entry

**File**: `.claude/extensions/core/merge-sources/claudemd.md` (lines 84-113, Command Reference table)

Current command table has these entries relevant to pr:
```
| `/review`  | `/review`   | Analyze codebase |
| `/merge`   | `/merge`    | Create pull/merge request for current branch (user-only) |
```

There is NO `/pr` entry at all. The `/pr` command is a CSLib extension command, but `/pr --review` is the entry point for creating pr-type tasks. Since pr-type tasks route through the agent system (via /research and /implement), there should be documentation that makes this discoverable.

**However**: The correct location for `/pr --review` documentation is in the CSLib `EXTENSION.md`, not the core `claudemd.md`. The core command reference should only list commands provided by the core extension. The `/pr` command is in `.claude/extensions/cslib/commands/pr.md`.

**Assessment**: The `/pr` command entry is properly owned by CSLib. The core `claudemd.md` does not need a `/pr` entry. The CSLib `EXTENSION.md` currently has no "Commands" section — this is a gap. A Commands section should be added to EXTENSION.md.

### 4. CSLib EXTENSION.md — Missing Commands Section

**File**: `.claude/extensions/cslib/EXTENSION.md`

The EXTENSION.md (60 lines) has:
- Language Routing table
- Skill-Agent Mapping table
- When to Use --hard for CSLib Tasks
- MCP Integration
- CI Verification Pipeline

Missing: A "Commands" section listing:
- `/pr <input> [options]` - Submit CSLib PR (main workflow, user-only)
- `/pr --review <sources...>` - Create PR review task (entry point for pr-type tasks)
- `/pr N` (when task is PR READY with sources) - Push changes, post GitHub comment, send Zulip message

### 5. pr-prohibition.md — Needs /pr --review Section

**File**: `.claude/rules/pr-prohibition.md` (61 lines)

Current state: The document has a "CSLib Extension: /pr Command" section (lines 47-61) that describes the old pr-submission workflow with `skill-pr-implementation`. It does NOT mention:
- The `--review` flag to `/pr` (STEP 0: creates pr-type review tasks)
- The new pr-review workflow (skill-pr-review-research + skill-pr-review-implementation)
- The PR READY handling for review tasks (STEP 0.5: push, GitHub comment, Zulip send)

**Change needed**: Extend the "CSLib Extension: /pr Command" section to document:
1. The `--review` mode (STEP 0) creates tasks with `task_type: "pr"` and a `sources` array
2. pr-type research routes to `skill-pr-review-research`
3. pr-type implement routes to `skill-pr-review-implementation` (which composes pr-response.md, zulip-response.md)
4. When task is `[PR READY]` with sources, `/pr N` (STEP 0.5) pushes and posts the response files
5. The distinction: pr-submission workflow has NO sources; pr-review workflow has sources

### 6. Core CLAUDE.md Skill-to-Agent Mapping — No Changes Needed

**File**: `.claude/extensions/core/merge-sources/claudemd.md` (lines 179-222)

The core mapping table documents core skills only. Extension skills are covered by the note:
> "When extensions are loaded, additional skill-to-agent mappings are added (e.g., skill-{domain}-research -> {domain}-research-agent)."

The CSLib-specific skills (`skill-pr-review-research`, `skill-pr-review-implementation`) belong in the CSLib EXTENSION.md, not the core claudemd.md. No change needed here.

### 7. Routing Mechanism Analysis

The `command-route-skill.sh` script (lines 34-66) works by:
1. Scanning ALL extension manifests for a matching `routing[$operation][$task_type]` entry
2. Returning the first match found (alphabetical extension order)
3. Falling back to the default skill if no match found

Since "cslib" extension name sorts before other extensions, and the manifest already has `"pr": "skill-pr-review-research"` and `"pr": "skill-pr-review-implementation"`, the routing is already operational. No changes to the routing mechanism or script are needed.

### 8. Coexistence: pr-submission vs pr-review Workflows

The two pr workflows share the same `task_type: "pr"` but differ by whether a `sources` array is present in state.json:

| Field | PR-Submission Workflow | PR-Review Workflow |
|-------|----------------------|-------------------|
| task_type | pr | pr |
| sources | absent or empty | non-empty (GitHub PR, Zulip, text) |
| Created by | /implement (for cslib tasks that reach [PR READY]) | /pr --review |
| /research routes to | skill-pr-review-research | skill-pr-review-research |
| /implement routes to | skill-pr-review-implementation → legacy path → cslib-implementation-agent | skill-pr-review-implementation → review path → pr-review-implementation-agent |
| Artifact produced | pr-description.md | pr-response.md, zulip-response.md |
| /pr N handles | STEP 1+ (branch, CI, PR submission) | STEP 0.5 (push, GitHub comment, Zulip send) |

**Key insight**: The dispatch within `skill-pr-review-implementation` checks for sources and forks to either the review path or the legacy pr-description path. This is the intended coexistence mechanism — one routing entry handles both workflows.

**Important note on pr-submission**: The original `skill-pr-implementation` is still listed in `manifest.json`'s `provides.skills` but is no longer in the `routing` section (it was presumably removed when `skill-pr-review-implementation` replaced it). The legacy path in `skill-pr-review-implementation` replicates `skill-pr-implementation` behavior.

---

## Decisions

- **Do not change manifest.json**: Routing is already correct and operational.
- **CSLib EXTENSION.md is the right place**: All CSLib pr-related skill-agent mappings and command documentation belongs in EXTENSION.md (not core claudemd.md).
- **pr-prohibition.md gets a new subsection**: Add a "PR Review Workflow (/pr --review)" subsection to the existing CSLib section.
- **EXTENSION.md gets a Commands section**: Add a "### Commands" section to document /pr usage modes.
- **EXTENSION.md gets the missing implementation row**: Add `skill-pr-review-implementation` → `pr-review-implementation-agent` to the Skill-Agent Mapping table.

---

## Files That Need Updating

### File 1: `.claude/extensions/cslib/EXTENSION.md`

**Location**: Line 21 (after skill-pr-review-research row), and after line 60 (new Commands section)

**Change A** — Add missing row to Skill-Agent Mapping table (after line 21):
```
| skill-pr-review-implementation | pr-review-implementation-agent | sonnet | Compose pr-response.md and zulip-response.md for pr-type review tasks; falls back to legacy pr-description workflow when sources are absent |
```

**Change B** — Add Commands section (after CI Verification Pipeline section, line 60):
```markdown
### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/pr` | `/pr <task_number\|path\|description> [--draft] [--dry-run]` | Submit CSLib PR: create branch, run CI, create PR on leanprover/cslib (user-only) |
| `/pr` | `/pr --review <sources...>` | Create pr-type review task from GitHub PR URLs, Zulip URLs, or descriptions |
| `/pr` | `/pr N` (when task is [PR READY] with sources) | Push changes, post GitHub PR comment, optionally send Zulip message |
```

### File 2: `.claude/rules/pr-prohibition.md`

**Location**: After line 61 (end of CSLib section), add new subsection.

**Change** — Add "PR Review Workflow" subsection:
```markdown
## CSLib Extension: /pr --review Workflow

The `--review` flag to `/pr` creates tasks with `task_type: "pr"` and a `sources` array in state.json. These tasks use the pr-review skills:

1. **`/pr --review <sources...>`** (user-invoked command): Creates a pr-type task with sources (GitHub PR URLs, Zulip thread URLs, or free-text descriptions). This is the ONLY way to create pr-review tasks.

2. **`/research N`** (pr-type task): Routes to `skill-pr-review-research`, which fetches GitHub PR data (reviews, comments, inline comments) and optionally Zulip thread data. Produces a research report.

3. **`/implement N`** (pr-type task with sources): Routes to `skill-pr-review-implementation`, which dispatches to `pr-review-implementation-agent`. The agent composes `pr-response.md` (GitHub PR comment) and optionally `zulip-response.md` (Zulip thread message). Transitions task to `[PR READY]`.

4. **`/pr N`** (when task is [PR READY] with sources): STEP 0.5 handles the posting workflow — commits/pushes any local changes, posts `pr-response.md` as a GitHub PR comment, optionally sends `zulip-response.md` to Zulip. Transitions task to `[COMPLETED]`.

### Distinguishing pr-submission vs pr-review

| Condition | Workflow |
|-----------|----------|
| `task_type: "pr"`, `sources: []` | pr-submission (legacy): /implement produces pr-description.md |
| `task_type: "pr"`, `sources: [...]` | pr-review: /implement produces pr-response.md + zulip-response.md |

The prohibition on agent-created PRs and agent pushes still applies to both workflows. Only `/pr N` (user-invoked) performs git push and GitHub API operations.
```

---

## Risks & Mitigations

- **EXTENSION.md is a merge source**: Changes to EXTENSION.md do not automatically regenerate CLAUDE.md. The user must re-run the extension loader to regenerate CLAUDE.md. Note in plan to inform user.
- **skill-pr-implementation legacy status**: The skill is still in `provides.skills` in manifest.json but not in `routing`. This is intentional (legacy path is inside skill-pr-review-implementation), but could be confusing. Document in pr-prohibition.md that skill-pr-implementation is the legacy path, not the routing target.
- **Routing conflict risk**: No conflict. The cslib manifest is the only one with a "pr" routing entry. The routing script takes the first match, so there's no ambiguity.

---

## Context Extension Recommendations

- **Topic**: pr-review workflow documentation in extension context
- **Gap**: No context file describes the end-to-end pr-review workflow (from /pr --review through research/implement/PR READY to /pr N posting)
- **Recommendation**: Consider adding `project/cslib/patterns/pr-review-workflow.md` to the cslib extension context, loaded for `pr-review-research-agent` and `pr-review-implementation-agent`.

---

## Appendix

### Files Examined

| File | Purpose |
|------|---------|
| `.claude/extensions/cslib/manifest.json` | Extension routing table (pr routing confirmed correct) |
| `.claude/extensions/cslib/EXTENSION.md` | Merge source for CLAUDE.md CSLib section |
| `.claude/extensions/cslib/skills/skill-pr-review-research/SKILL.md` | Research skill definition |
| `.claude/extensions/cslib/skills/skill-pr-review-implementation/SKILL.md` | Implementation skill definition |
| `.claude/extensions/cslib/commands/pr.md` | /pr command (STEP 0, 0.5, 1-11) |
| `.claude/extensions/core/merge-sources/claudemd.md` | Core CLAUDE.md merge source |
| `.claude/CLAUDE.md` | Generated CLAUDE.md (do not edit directly) |
| `.claude/rules/pr-prohibition.md` | PR/push prohibition rules |
| `.claude/scripts/command-route-skill.sh` | Routing resolution script |

### Search Strategy Used

1. Codebase exploration: Grep for "pr" in manifest.json, EXTENSION.md, CLAUDE.md, pr-prohibition.md
2. Structural inspection: Read skill files to understand dispatch logic and coexistence mechanism
3. Routing mechanism: Read command-route-skill.sh to confirm manifest-driven routing
4. Source vs generated: Distinguished between EXTENSION.md (edit target) and CLAUDE.md (generated, do not edit)

### Key Insight on Core CLAUDE.md vs Extension EXTENSION.md

The core `.claude/CLAUDE.md` is generated from two merge sources:
1. `.claude/extensions/core/merge-sources/claudemd.md` (core skills, commands, agents)
2. `.claude/extensions/cslib/EXTENSION.md` (CSLib-specific section, appended)
3. Other extension EXTENSION.md files (Nix, Neovim, etc.)

The correct edit targets are the merge sources (EXTENSION.md files), NOT the generated CLAUDE.md. The task description mentions "Update CLAUDE.md routing tables" which in practice means updating the relevant EXTENSION.md or core merge-sources/claudemd.md.

For task 726, all routing documentation changes belong in:
- `.claude/extensions/cslib/EXTENSION.md` (CSLib section additions)
- `.claude/rules/pr-prohibition.md` (pr workflow documentation)

The core merge-sources/claudemd.md does NOT need changes because:
- The `/pr` command is a CSLib extension command, not a core command
- Core skill-to-agent tables only list core skills; extension skills are covered by a generic note

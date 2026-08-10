# Research Report: Task #722

**Task**: 722 - Add /pr --review flag with source metadata
**Started**: 2026-06-15T06:30:00Z
**Completed**: 2026-06-15T06:45:00Z
**Effort**: ~1 hour research
**Dependencies**: None
**Sources/Inputs**: Codebase (.claude/commands/, .claude/extensions/cslib/, .claude/scripts/, specs/state.json)
**Artifacts**: specs/722_add_pr_review_flag/reports/01_pr-review-flag.md
**Standards**: report-format.md

---

## Executive Summary

- The CSLib extension owns the only `/pr` command, at `.claude/extensions/cslib/commands/pr.md`. No core `/pr` command exists.
- The CSLib extension manifest already claims task_type `"pr"` and routes `implement` to `skill-pr-implementation`. A new core `/pr --review` must not collide with this routing.
- The recommended approach is to create a **core** `/pr.md` at `.claude/commands/pr.md` that inspects its first argument: if `--review`, it handles source collection and task creation; otherwise it defers to the CSLib extension's `/pr` behavior via documented guidance. The extension's `pr.md` can remain as the CSLib-specific execution path.
- The `sources` array belongs as a top-level field on the `active_projects` entry in `specs/state.json`, alongside existing custom fields like `base_branch` (used by skill-pr-implementation) and `parent_task` (used by --review).
- `zulip-send` is available at `/home/benjamin/.nix-profile/bin/zulip-send` and uses `--stream STREAM --subject SUBJECT -m MESSAGE` flags. Zulip URL parsing is a straightforward bash regex operation (no external tool required).

---

## Context & Scope

This research covers:
1. Whether a core `/pr` command exists and what the CSLib extension `/pr` does
2. How command argument parsing works in this system
3. How custom task metadata (like `sources`) is stored in `state.json`
4. How tasks are created via jq mutations (pattern from `/task` command)
5. Zulip URL format and `zulip-send` CLI interface
6. Coexistence strategy between core and extension `/pr` commands

---

## Findings

### 1. Current State of /pr Command

**Location**: `.claude/extensions/cslib/commands/pr.md` — **extension-only, no core /pr command exists**.

The CSLib `/pr` command is a large (1085-line) domain-specific command that:
- Accepts `<task_number | path | description>` as primary input
- Runs a full 7-step CI pipeline (lake build, lint, test, shake, etc.)
- Creates a feature branch, composes/confirms a PR title and body
- Pushes to fork and creates PR against `leanprover/cslib` via `gh pr create`
- Works on files in `/home/benjamin/Projects/cslib` (hardcoded path to the CSLib project)

This command is entirely CSLib-project-specific. It does NOT operate on the nvim config repo. Adding `--review` to it would be confusing and semantically wrong.

**CSLib Extension Manifest** (`.claude/extensions/cslib/manifest.json`) claims:
- `"commands": ["pr.md"]` — provides the `/pr` command
- `task_type: "pr"` routing: research -> `skill-researcher`, implement -> `skill-pr-implementation`
- `keyword_overrides.pr.keywords`: includes "pr", "pull request", "submit", "upstream", etc.

The manifest's `keyword_overrides` means any task description containing "pr" or "pull request" will be detected as task_type `"pr"`, which routes implement to `skill-pr-implementation` (the CSLib PR prep skill). This is the existing behavior that must be preserved.

### 2. Command Structure Patterns

Examining `merge.md` and `task.md`:

**Command file structure** (frontmatter + body):
```markdown
---
description: One-line description
allowed-tools: Bash, Read, Edit, Write, AskUserQuestion
argument-hint: "<arg1> [options]"
model: opus
---

# /command-name Command

[body with STEP 1, STEP 2... pattern]
```

**Argument parsing pattern**: Commands manually parse `$ARGUMENTS` inline (no shared parser invoked at command level). The `parse-command-args.sh` script is available but designed for `/research`, `/plan`, `/implement` — not for custom commands. Custom commands like `/pr` and `/merge` parse `$ARGUMENTS` themselves with bash patterns.

**Task creation pattern** (from `task.md` step 6):
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg desc "$improved_desc" \
  '.next_project_number = {NEW_NUMBER} |
   .active_projects = [{
     "project_number": {N},
     "project_name": "slug",
     "status": "not_started",
     "task_type": "detected",
     "description": $desc,
     "created": $ts,
     "last_updated": $ts
   }] + .active_projects' \
  specs/state.json > specs/tmp/state.json && \
  mv specs/tmp/state.json specs/state.json
```

Then `generate-todo.sh` regenerates TODO.md.

### 3. Custom Metadata in state.json

The `active_projects` entries support arbitrary custom fields. Examples found:

- `base_branch` (CSLib): Written by `skill-pr-implementation`; read by `/pr` command to set `--base` flag in `gh pr create`
- `parent_task` (task --review): Set when creating follow-up tasks to link back to parent
- `topic`: Standard field managed by `manage-topics.sh`

The `state.json` schema is **open** — any JSON-serializable field can be added to an `active_projects` entry. There is no validation schema that would reject a `sources` array.

**Precedent** from `skill-pr-implementation` (Stage 7):
```bash
jq --argjson num "$task_number" \
   --arg branch "$base_branch_used" \
   '.active_projects |= map(if .project_number == $num then . + {"base_branch": $branch} else . end)' \
   "$CSLIB_STATE" > /tmp/state.tmp && mv /tmp/state.tmp "$CSLIB_STATE"
```

This is the exact pattern for adding a custom field to an existing task entry.

### 4. Zulip URL Parsing

**URL format**: `https://org.zulipchat.com/#narrow/stream/123-general/topic/my.20topic`

**Components to extract**:
- `stream_name`: The human-readable name after the numeric ID. From `123-general` -> `general` (strip the leading `NNN-` prefix)
- `topic`: URL-decoded topic. From `my.20topic` -> `my topic` (`.20` is space; other `.XX` are URL-encoded chars)

**Bash parsing approach**:
```bash
# Extract stream segment: "123-general"
stream_segment=$(echo "$zulip_url" | sed 's|.*/#narrow/stream/\([^/]*\)/.*|\1|')
# Strip leading numeric ID: "123-general" -> "general"
stream_name=$(echo "$stream_segment" | sed 's/^[0-9]*-//')

# Extract topic segment: "my.20topic"
topic_encoded=$(echo "$zulip_url" | sed 's|.*/topic/\(.*\)|\1|' | sed 's|[?#].*||')
# URL-decode: .20 -> space, etc.
topic=$(echo "$topic_encoded" | sed 's/\.20/ /g' | sed 's/\.2E/./g' | sed 's/\.2C/,/g' | sed 's/\.27/'"'"'/g')
```

**`zulip-send` CLI interface** (confirmed available at `/home/benjamin/.nix-profile/bin/zulip-send`):
```bash
zulip-send --stream "general" --subject "my topic" -m "message text"
# Or pipe:
cat zulip-response.md | zulip-send --stream "$stream_name" --subject "$topic"
```

The `--stream` (`-s`) and `--subject` (`-S`) flags map directly to parsed URL components. Configuration is read from `~/.zuliprc` by default.

### 5. Task Type for /pr --review Tasks

The CSLib extension's `keyword_overrides.pr` already captures task_type `"pr"`. The new `--review` workflow will create tasks with `task_type: "pr"`, which is correct — it ensures routing to the right skills (tasks 723-724 will define `skill-pr-review-research` and `skill-pr-review-implementation`).

The existing routing in the CSLib manifest needs consideration: it currently routes ALL `"pr"` tasks to `skill-pr-implementation`. The new review workflow tasks should route to different skills. This is the concern that task 726 will handle (routing table update).

One clean approach: the `--review` workflow creates tasks with a sub-type indicator in the description, or alternatively uses a distinct task_type. However, looking at task 726's description, the plan is to **differentiate at the skill level** — core pr tasks (from `--review`) use `skill-pr-review-*`; CSLib pr tasks (from the existing flow) use `skill-cslib-*` / `skill-pr-implementation`. This requires updating the routing manifest or adding a core routing entry that takes precedence.

**Design decision**: The task created by `/pr --review` should have task_type `"pr"` AND a `sources` array in its metadata. Skills can inspect `sources` to determine which workflow applies. This avoids adding a new task_type that could break keyword detection.

### 6. zulip-send Configuration

The `zulip-send` tool reads from `~/.zuliprc` by default. For the review workflow to send Zulip messages, the user needs a configured `~/.zuliprc`. The command should check for its existence and warn if missing.

### 7. Coexistence Strategy

**Problem**: Claude Code uses the `/pr` command name to invoke whichever `pr.md` is found. If both `.claude/commands/pr.md` (core) and `.claude/extensions/cslib/commands/pr.md` (extension) exist, there may be a conflict.

**Resolution**: Extension commands are provided in the `provides.commands` array of `manifest.json` and are merged/installed into the command namespace when the extension is loaded. The exact precedence between a core command and an extension command with the same name needs to be clarified.

**Two safe options**:

**Option A — Core command with early --review detection**:
Create `.claude/commands/pr.md` that checks if `$ARGUMENTS` starts with `--review`. If yes, handle the review workflow. If no, display a message explaining that `/pr` for CSLib submission is provided by the CSLib extension and direct the user to ensure the CSLib extension is loaded. This keeps the command namespace clean.

**Option B — Extension flag passthrough**:
Add `--review` handling directly inside `.claude/extensions/cslib/commands/pr.md`. This puts all `/pr` logic in one file but couples the core review workflow to the CSLib extension.

**Recommendation**: Option A (core command) because:
- The `--review` workflow is domain-agnostic (works for any GitHub repo + Zulip thread)
- It should not depend on CSLib extension being loaded
- The CSLib extension's `/pr` remains untouched for backward compatibility
- When CSLib extension is loaded, if the extension command takes precedence, Option A still works by having the extension's `pr.md` check for `--review` as its STEP 1 and delegate to the core behavior

**Fallback strategy**: If extension command takes precedence over core command when both exist, then modify the CSLib extension's `pr.md` to check for `--review` flag first and handle it (or include the core pr.md logic).

**Simplest viable approach**: Since the CSLib extension is always loaded in this project, add `--review` as STEP 0 in the CSLib extension's `pr.md`, placing it before the existing STEP 1 parse. This avoids any naming conflict entirely.

---

## Proposed Source Metadata Schema

```json
{
  "project_number": 730,
  "project_name": "review_pr_for_propositional_logic",
  "status": "not_started",
  "task_type": "pr",
  "sources": [
    {
      "type": "github_pr",
      "url": "https://github.com/leanprover/cslib/pull/42",
      "parsed": {
        "owner": "leanprover",
        "repo": "cslib",
        "pr_number": 42
      }
    },
    {
      "type": "zulip_thread",
      "url": "https://leanprover.zulipchat.com/#narrow/stream/270676-lean4/topic/CSLib.20PR.20review",
      "parsed": {
        "org": "leanprover",
        "stream_id": "270676",
        "stream_name": "lean4",
        "topic": "CSLib PR review"
      }
    },
    {
      "type": "description",
      "url": null,
      "parsed": {
        "text": "Free-text description of what to implement"
      }
    }
  ]
}
```

**Rationale for schema**:
- `type` discriminator enables downstream skills to branch on source type
- `url` is null for pure descriptions (not a URL)
- `parsed` carries pre-extracted fields so skills don't need to re-parse URLs
- For GitHub PRs: `pr_number` as integer enables `gh api repos/{owner}/{repo}/pulls/{pr_number}/comments`
- For Zulip: `stream_name` and `topic` map directly to `zulip-send --stream --subject` flags
- For descriptions: `text` carries the raw user input

---

## Task Creation Mechanism

The `/pr --review` command will use the standard task creation jq pattern from `task.md`, extended with a `sources` field:

```bash
# Build sources array from parsed inputs
sources_json=$(build_sources_json "$@")  # parsed from $ARGUMENTS

jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg desc "$task_description" \
   --arg slug "$task_slug" \
   --argjson sources "$sources_json" \
   --argjson next_num "$next_num" \
   '.next_project_number = ($next_num + 1) |
    .active_projects = [{
      "project_number": $next_num,
      "project_name": $slug,
      "status": "not_started",
      "task_type": "pr",
      "description": $desc,
      "sources": $sources,
      "created": $ts,
      "last_updated": $ts,
      "next_artifact_number": 1,
      "artifacts": []
    }] + .active_projects' \
  specs/state.json > specs/tmp/state.json && \
  mv specs/tmp/state.json specs/state.json
```

The `specs/tmp/` directory already exists (used by other commands). Then call `generate-todo.sh` and commit.

---

## Decisions

1. **Command location**: Add `--review` handling inside `.claude/extensions/cslib/commands/pr.md` as STEP 0 (before existing argument parsing). This avoids naming conflicts and keeps all `/pr` logic in one file while the CSLib extension is always loaded.

2. **Source type discriminator**: Use `"github_pr" | "zulip_thread" | "description"` as the three types. Detection heuristics:
   - Starts with `https://github.com/` -> `github_pr`
   - Contains `.zulipchat.com/` -> `zulip_thread`
   - Otherwise -> `description`

3. **URL detection pattern** for `$ARGUMENTS` parsing after `--review`:
   - Split remaining arguments on spaces
   - For each token: apply heuristics above
   - Accumulate into `sources` array as JSON

4. **Topic assignment**: Use `manage-topics.sh` to assign topic (Mode A: Interactive) after task creation, following the standard pattern from `task.md`.

5. **Task directory**: Created lazily (no mkdir in command); `specs/722_add_pr_review_flag/` directory already exists as a template.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| CSLib extension not loaded; `/pr` command unavailable | Core command (if created) handles gracefully; alternatively, the extension is always loaded |
| Zulip URL format variations (different org URLs, legacy formats) | Use flexible regex that matches `zulipchat.com` anywhere in URL; document expected format |
| `~/.zuliprc` not configured | Check for file existence in STEP 0 and warn user before creating task |
| `specs/tmp/` directory missing | Use `mktemp` or check/create before jq operation |
| GitHub URL variations (SSH, different org formats) | Detect by `github.com` in URL, parse with regex |
| keyword_overrides "pr" catching unintended tasks | This is pre-existing behavior; `--review` flag is explicit so no false positives |
| Routing collision: task 723/724 skills not yet registered | The command creates the task with `task_type: "pr"` and `sources`; routing skills come in tasks 723-726 |

---

## Context Extension Recommendations

- **Topic**: `/pr` command coexistence between core and extension commands
- **Gap**: No documented behavior for when core and extension commands share the same name
- **Recommendation**: Add a section to extension-development.md explaining command precedence when extension and core both provide the same command name

---

## Appendix

### Search Queries Used
- `find /home/benjamin/.config/nvim/.claude/extensions -name "pr.md"` — found CSLib extension pr.md
- `find /home/benjamin/.config/nvim/.claude/extensions/cslib -type f` — enumerate CSLib extension files
- `grep -r "zulip" /home/benjamin/.config/nvim/.claude/` — find any existing Zulip references
- `which zulip-send` — confirm CLI availability

### Key File References
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/commands/pr.md` — CSLib /pr command (1085 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/manifest.json` — CSLib extension routing
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md` — PR description prep skill
- `/home/benjamin/.config/nvim/.claude/commands/task.md` — Task creation pattern (Step 6 jq)
- `/home/benjamin/.config/nvim/.claude/scripts/command-gate-in.sh` — Gate-in script for task lookup
- `/home/benjamin/.config/nvim/.claude/rules/pr-prohibition.md` — PR push prohibition (agents must not push)
- `/home/benjamin/.config/nvim/specs/state.json` — Live state with task 722-726

### Zulip URL Parsing Reference
```
URL:     https://leanprover.zulipchat.com/#narrow/stream/270676-lean4/topic/CSLib.20PR.20review
org:     leanprover
stream_segment: 270676-lean4
stream_id:  270676
stream_name: lean4        (strip "270676-")
topic_encoded: CSLib.20PR.20review
topic:   CSLib PR review  (.20 -> space)
```

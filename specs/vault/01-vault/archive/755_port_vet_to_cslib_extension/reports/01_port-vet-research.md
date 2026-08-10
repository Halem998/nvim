# Research Report: Task #755

**Task**: 755 - Port /vet command-skill-agent triplet to cslib extension
**Started**: 2026-06-22T21:30:00Z
**Completed**: 2026-06-22T21:35:00Z
**Effort**: Low (file copy + registration)
**Dependencies**: None
**Sources/Inputs**: Source files in cslib project, extension files in nvim config repo
**Artifacts**: - specs/755_port_vet_to_cslib_extension/reports/01_port-vet-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The three /vet source files exist at `/home/benjamin/Projects/cslib/.claude/` and are complete, well-structured, and ready to port
- All three files need to be copied verbatim into `/home/benjamin/.config/nvim/.claude/extensions/cslib/` with no content changes (paths inside the files are absolute and project-specific, which is correct for cslib tasks)
- manifest.json needs 3 additions: one agent, one skill, one command entry
- EXTENSION.md needs one row added to the skill-agent mapping table and one row added to the commands table
- README.md needs one row in skill-agent mapping, one row in commands table, and one line in the architecture tree
- AskUserQuestion constraint is correctly implemented: skill's `allowed-tools` includes `AskUserQuestion`, agent's MUST NOT section explicitly prohibits it

## Context & Scope

This task ports the `/vet` quality-gate command (created for the cslib project in tasks 270-271) into the shared cslib extension so it is available via the extension system. The source files are project-local to `/home/benjamin/Projects/cslib/` and were never registered in the nvim config's extension at `/home/benjamin/.config/nvim/.claude/extensions/cslib/`.

## Findings

### Source File Analysis

**1. `/home/benjamin/Projects/cslib/.claude/commands/vet.md`**

Frontmatter:
```yaml
allowed-tools: Bash, Read, AskUserQuestion
argument-hint: "<task_number[,task_number-task_number...]> [focus_prompt]"
model: opus
```

The command file:
- Sources `.claude/scripts/parse-command-args.sh` using `cd /home/benjamin/Projects/cslib` — these absolute paths are correct because `/vet` always operates on the cslib project
- Validates tasks against cslib's `specs/state.json`
- Generates a session ID and invokes `skill-cslib-vet` via the Skill tool
- Passes `cslib_dir: "/home/benjamin/Projects/cslib"` to the skill

Path dependency note: The hardcoded `cd /home/benjamin/Projects/cslib` path in the command file is intentional — the /vet command only makes sense in the context of the cslib project. No path adjustment needed.

**2. `/home/benjamin/Projects/cslib/.claude/skills/skill-cslib-vet/SKILL.md`**

Frontmatter:
```yaml
name: skill-cslib-vet
description: Vet completed CSLib tasks against library standards. Invoke for /vet command.
allowed-tools: Agent, AskUserQuestion, Bash, Edit, Read, Write
```

Key observations:
- `AskUserQuestion` IS in the `allowed-tools` list — this is critical for interactive violation selection (Stage 6-7)
- Uses `Agent` tool to invoke `cslib-vet-agent` as a subagent
- The skill handles all user interaction AFTER the agent returns
- Bash commands use absolute paths (`cd /home/benjamin/Projects/cslib`)
- The metadata path construction uses `$task_dir` derived from cslib's state.json

**3. `/home/benjamin/Projects/cslib/.claude/agents/cslib-vet-agent.md`**

Frontmatter:
```yaml
name: cslib-vet-agent
description: Vet CSLib tasks against library standards, run CI pipeline, and create fix tasks with interactive user confirmation
model: sonnet
```

Key observations:
- `AskUserQuestion` is NOT in the allowed-tools list (only: Read, Write, Edit, Glob, Grep, Bash, lean-lsp MCP tools)
- MUST NOT section explicitly lists: "Use AskUserQuestion — this agent runs as a subagent and cannot call it; the invoking skill handles all user interaction"
- The agent writes `.vet-findings.json` and `.vet-meta.json` to the first task's directory under cslib's `specs/`
- Returns brief text summary; skill reads findings file and handles user interaction

### AskUserQuestion Constraint Verification

The division of responsibility is correctly implemented:

| Component | AskUserQuestion | Role |
|-----------|----------------|------|
| vet.md (command) | YES (allowed-tools) | Passes control to skill |
| skill-cslib-vet (SKILL.md) | YES (allowed-tools) | Reads .vet-findings.json; presents violations via AskUserQuestion in Stage 6 and Stage 7 |
| cslib-vet-agent | PROHIBITED (MUST NOT #1) | Writes .vet-findings.json with violations; returns text summary |

The interaction pattern:
1. Agent runs CI, analyzes files, writes `.vet-findings.json` with categorized violations and `suggested_fix_tasks`
2. Agent writes `.vet-meta.json` with violation counts and findings_path
3. Skill reads both files in Stage 5
4. Skill presents `AskUserQuestion` multiSelect in Stage 6 (which categories to fix)
5. Skill presents `AskUserQuestion` single-select in Stage 7 (confirmation: Yes/Revise/Cancel)
6. Skill creates fix tasks in Stage 8 and commits in Stage 9

### Target Extension Structure

Files to create:

```
/home/benjamin/.config/nvim/.claude/extensions/cslib/
├── commands/
│   └── vet.md                    # COPY from cslib project (no changes)
├── skills/
│   └── skill-cslib-vet/
│       └── SKILL.md              # COPY from cslib project (no changes)
└── agents/
    └── cslib-vet-agent.md        # COPY from cslib project (no changes)
```

### manifest.json Changes

Current `provides` section in manifest.json:
```json
"provides": {
  "agents": [
    "cslib-research-agent.md",
    "cslib-implementation-agent.md",
    "cslib-research-hard-agent.md",
    "cslib-implementation-hard-agent.md",
    "pr-review-research-agent.md",
    "pr-review-implementation-agent.md"
  ],
  "skills": [
    "skill-cslib-research",
    "skill-cslib-implementation",
    "skill-pr-implementation",
    "skill-cslib-research-hard",
    "skill-cslib-implementation-hard",
    "skill-pr-review-research",
    "skill-pr-review-implementation"
  ],
  "commands": ["pr.md"],
  ...
}
```

Changes needed:
- `agents`: Add `"cslib-vet-agent.md"` to the array
- `skills`: Add `"skill-cslib-vet"` to the array
- `commands`: Change `["pr.md"]` to `["pr.md", "vet.md"]`

Note: `/vet` is a standalone command that does not route through the standard research/plan/implement lifecycle, so no `routing` or `routing_hard` entries are needed. The command invokes the skill directly via the Skill tool.

### EXTENSION.md Changes

In the **Skill-Agent Mapping** table, add one row:

```
| skill-cslib-vet | cslib-vet-agent | sonnet | Vet CSLib tasks against standards; run CI; create fix tasks with user confirmation |
```

In the **Commands** table, add one row:

```
| `/vet` | `/vet <task_numbers> [focus_prompt]` | Quality-gate: vet completed CSLib task(s) against CONTRIBUTING.md, NOTATION.md, ORGANISATION.md; run CI; create fix tasks |
```

### README.md Changes

**Architecture tree** — add under `agents/`:
```
+-- cslib-vet-agent.md                # CSLib quality-gate vetting agent (sonnet)
```

And under `skills/`:
```
+-- skill-cslib-vet/                  # Vet skill: identifies changed files, delegates to agent, interactive fix-task creation
```

And under `commands/`:
```
+-- vet.md                            # /vet command (quality-gate vetting)
```

**Skill-Agent Mapping** table — add one row:
```
| skill-cslib-vet | cslib-vet-agent | sonnet | Vet CSLib tasks against standards; run CI; create fix tasks interactively |
```

**Commands** table — add one row:
```
| `/vet` | `/vet <task_numbers> [focus_prompt]` | Quality-gate: vet completed CSLib task(s) against CONTRIBUTING.md, NOTATION.md, ORGANISATION.md; run CI; create fix tasks |
```

## Decisions

- **No content modifications to source files**: All three files are self-consistent and use correct absolute paths for the cslib project. Copy verbatim.
- **No routing entries needed**: `/vet` is invoked directly (like `/pr`), not through the `/research`/`/plan`/`/implement` lifecycle routing table. The `routing` section in manifest.json only needs entries for lifecycle-routed task types.
- **`vet` keyword_override not added**: The `/vet` command is user-invoked directly; it doesn't create tasks via `/task`. No keyword_override is needed.
- **skill-cslib-vet not in routing**: The skill is invoked by the command via the Skill tool, not by the orchestrator routing table. This matches the pattern used by `skill-pr-implementation` (invoked by `/pr` command).

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| hardcoded `/home/benjamin/Projects/cslib` paths break if cslib moves | These are intentional — /vet is project-specific. Document in EXTENSION.md as a known dependency. |
| `parse-command-args.sh` referenced by command but may not exist in extension context | Script lives in cslib project at `/home/benjamin/Projects/cslib/.claude/scripts/` — the command `cd`s there first, so this is fine |
| AskUserQuestion accidentally used by agent in future edits | MUST NOT section and explicit tool list absence provide two layers of protection |
| metadata_file_path in delegation context hardcodes cslib task 270's directory | The SKILL.md Stage 3 dynamically computes `task_dir` from the first vetted task number, not task 270. This is fine. |

## Implementation Plan (for planner)

The implementation is a sequence of file copy operations followed by JSON and Markdown edits:

**Phase 1: Copy files**
1. Copy `vet.md` → `extensions/cslib/commands/vet.md`
2. Create `extensions/cslib/skills/skill-cslib-vet/` directory
3. Copy `SKILL.md` → `extensions/cslib/skills/skill-cslib-vet/SKILL.md`
4. Copy `cslib-vet-agent.md` → `extensions/cslib/agents/cslib-vet-agent.md`

**Phase 2: Update manifest.json**
1. Add `"cslib-vet-agent.md"` to `provides.agents`
2. Add `"skill-cslib-vet"` to `provides.skills`
3. Add `"vet.md"` to `provides.commands`

**Phase 3: Update EXTENSION.md**
1. Add row to Skill-Agent Mapping table
2. Add row to Commands table

**Phase 4: Update README.md**
1. Add 3 lines to architecture tree (agents/, skills/, commands/ sections)
2. Add row to Skill-Agent Mapping table
3. Add row to Commands table

## Appendix

### Files Read
- `/home/benjamin/Projects/cslib/.claude/commands/vet.md`
- `/home/benjamin/Projects/cslib/.claude/skills/skill-cslib-vet/SKILL.md`
- `/home/benjamin/Projects/cslib/.claude/agents/cslib-vet-agent.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/manifest.json`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/EXTENSION.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/README.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-pr-review-research/SKILL.md` (convention reference)

### No Web Searches Required
All findings derived from local codebase exploration.

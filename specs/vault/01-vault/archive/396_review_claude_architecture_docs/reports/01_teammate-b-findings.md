# Research Report: Task #396 — Teammate B Findings

**Task**: 396 - Review .claude/ agent system architecture documentation
**Teammate**: B — Alternative Approaches & Prior Art (Core docs, cross-reference drift, non-extension documentation)
**Started**: 2026-04-10T00:00:00Z
**Completed**: 2026-04-10T00:30:00Z
**Effort**: ~30 minutes
**Confidence Level**: High (all findings verified by direct file inspection)

---

## Key Findings

1. **Template staleness is severe**: Both `docs/templates/agent-template.md` and
   `context/templates/subagent-template.md` document obsolete multi-field frontmatter
   (`mode`, `version`, `max_tokens`, `timeout`, XML blocks) that no current agent uses.
   Actual agents use a 2-3 line frontmatter (`name`, `description`, optional `model`).

2. **`docs/templates/command-template.md` prescribes an `agent:` frontmatter field** that
   no current command uses. All 14 real commands use `description`, `allowed-tools`,
   `argument-hint`, and `model` instead. The template is entirely wrong about command
   frontmatter format.

3. **`docs/guides/creating-commands.md` contains "OpenAgents" and v6.1 hybrid-architecture
   terminology** — language from a prior generation of the system that has been completely
   superseded. It references an "OpenAgents" product and a "Neovim Configuration vs
   OpenAgents" comparison table that have no meaning in the current system.

4. **`README.md` agents table is missing `reviser-agent`** — a live agent with its own
   file, skill, and CLAUDE.md entry. The agents table in `README.md` lists only 6 agents;
   the actual directory has 7 (plus README).

5. **`context/reference/README.md` contents table is wrong on two counts**: it lists
   `state-json-schema.md` (file does not exist; actual filename is
   `state-management-schema.md`) and omits two real files: `artifact-templates.md` and
   `workflow-diagrams.md`.

6. **`rules/` directory has no README**, and `CLAUDE.md` lists only 5 of the 6 rules files
   — `plan-format-enforcement.md` is present on disk but absent from the core rules
   inventory in `CLAUDE.md`.

7. **`code-reviewer-agent.md` uses stale frontmatter format** (`mode: subagent`,
   `temperature: 0.1`, `tools:` block) instead of the current minimal format. It also
   lacks a `model:` field, which the agent-frontmatter-standard requires for research-class
   agents.

8. **`context/standards/` contains two overlapping documentation files**:
   `documentation.md` (311 lines) and `documentation-standards.md` (241 lines), both
   titled "Documentation Standards" with partially different content. No consolidation has
   occurred.

9. **`CLAUDE.md` git commit convention still shows `Co-Authored-By:` trailer**, which
   conflicts with the user's stored preference (feedback_no_coauthored_by.md) to omit
   these trailers entirely. This creates silent drift between the documented convention and
   expected behavior.

10. **`docs/guides/development/context-index-migration.md` exists but is not listed** in
    the `docs/README.md` directory tree, making it a partially orphaned historical document.

---

## Core Documentation Inventory

### Top-Level Files

| File | Status | Notes |
|------|--------|-------|
| `.claude/README.md` | Mostly current | Missing `reviser-agent` in agents table; `/refresh` quick-ref shows incomplete syntax |
| `.claude/CLAUDE.md` | Mostly current | Missing `plan-format-enforcement.md` from rules list; Co-Authored-By drift |

### Directory-Level README Coverage

| Directory | Files | README | Notes |
|-----------|-------|--------|-------|
| `commands/` | 14 | NO | No directory README |
| `skills/` | 16 dirs | NO | No directory README |
| `agents/` | 7 + README | YES | README missing `reviser-agent` |
| `rules/` | 6 | NO | No directory README; CLAUDE.md omits `plan-format-enforcement.md` |
| `scripts/` | 24 | NO | No directory README |
| `hooks/` | 9 | NO | No directory README |
| `templates/` | 1 | NO | Contains only `settings.json` (not a template file) |
| `utils/` | 1 | NO | Contains only `team-wave-helpers.md` |
| `extensions/` | 14 subdirs | YES | `extensions/README.md` is current and comprehensive |
| `docs/` | subdirs | YES | `docs/README.md` accurate except for `development/` subdir |
| `context/` | subdirs | YES | `context/README.md` is current and well-structured |

### Context Subdirectory README Coverage

| Subdirectory | Files | README | Notes |
|--------------|-------|--------|-------|
| `context/checkpoints/` | 4 | YES | Well-documented |
| `context/reference/` | 5 | YES | Contents table wrong (see Finding 5) |
| `context/architecture/` | 4 | NO | — |
| `context/formats/` | 13 | NO | — |
| `context/guides/` | 1 | NO | — |
| `context/meta/` | 6 | NO | — |
| `context/orchestration/` | 13 | NO | — |
| `context/patterns/` | 15 | NO | — |
| `context/processes/` | 3 | NO | — |
| `context/repo/` | 3 | NO | — |
| `context/schemas/` | 2 | NO | — |
| `context/standards/` | 14 | NO | Contains duplicate documentation files |
| `context/templates/` | 7 | NO | — |
| `context/troubleshooting/` | 1 | NO | — |
| `context/workflows/` | 5 | NO | — |

### Docs Directory Coverage

| File/Dir | Status | Notes |
|----------|--------|-------|
| `docs/README.md` | Current | Does not list `guides/development/` subdirectory |
| `docs/architecture/system-overview.md` | Exists | Not verified in depth |
| `docs/architecture/extension-system.md` | Exists | — |
| `docs/guides/creating-commands.md` | **STALE** | Contains OpenAgents/v6.1 terminology |
| `docs/guides/creating-agents.md` | Current | — |
| `docs/guides/creating-skills.md` | Current | — |
| `docs/guides/creating-extensions.md` | Current | — |
| `docs/guides/development/context-index-migration.md` | Orphaned | Not in docs/README.md tree |
| `docs/templates/README.md` | **STALE** | References 8-stage workflow and `subagent-return-format.md` (wrong filename) |
| `docs/templates/agent-template.md` | **STALE** | Old frontmatter format (mode, version, max_tokens, timeout) |
| `docs/templates/command-template.md` | **STALE** | Documents `agent:` frontmatter field; all real commands use `description:` |
| `docs/reference/standards/agent-frontmatter-standard.md` | Current | Correctly documents minimal frontmatter |
| `docs/reference/standards/extension-slim-standard.md` | Current | — |
| `docs/reference/standards/multi-task-creation-standard.md` | Current | — |

---

## Cross-Reference Drift

### Missing From CLAUDE.md

| Missing Reference | Location | Impact |
|-------------------|----------|--------|
| `skill-fix-it` not in Skills table | `CLAUDE.md` | Agents unaware of fix-it skill pathway |
| `plan-format-enforcement.md` not in core rules list | `CLAUDE.md` | Agents may not know this rule exists |

### Missing From README.md

| Missing Reference | Location | Impact |
|-------------------|----------|--------|
| `reviser-agent` not in agents table | `README.md` | Navigation dead-end for new users |
| `/refresh` usage incomplete (shows bare `/refresh`, omits `--dry-run`/`--force`) | `README.md` quick ref | Stale quick reference |
| Skills table is an acknowledged "subset" but missing `skill-reviser`, `skill-spawn`, `skill-git-workflow`, `skill-orchestrator`, `skill-fix-it`, `skill-team-*` | `README.md` | Incomplete documentation |

### Missing From `context/reference/skill-agent-mapping.md`

This reference file is missing several core skills from its "Core Skills" table:

| Missing Skill/Agent | Present In |
|---------------------|-----------|
| `skill-reviser` / `reviser-agent` | CLAUDE.md only |
| `skill-spawn` / `spawn-agent` | CLAUDE.md only |
| `skill-git-workflow` | CLAUDE.md only |
| `skill-orchestrator` | CLAUDE.md only |
| `skill-fix-it` / `code-reviewer-agent` | CLAUDE.md only |

### Wrong File Name In Reference

| Documented Name | Actual File | Location |
|-----------------|-------------|----------|
| `state-json-schema.md` | `state-management-schema.md` | `context/reference/README.md` |
| `subagent-return-format.md` | `subagent-return.md` | `docs/templates/README.md` (multiple occurrences) |

### Stale Frontmatter in Agents

| Agent | Issue |
|-------|-------|
| `code-reviewer-agent.md` | Uses `mode: subagent`, `temperature: 0.1`, `tools:` block — old format. Missing `model:` field. |
| `general-implementation-agent.md` | Missing `model:` field (acceptable per standard — `(omitted)` is valid) |
| `meta-builder-agent.md` | Missing `model:` field (acceptable) |

### Stale Terminology in Guides

| File | Stale Content | Should Be |
|------|---------------|-----------|
| `docs/guides/creating-commands.md` | "OpenAgents", "Neovim Configuration vs OpenAgents", "v6.1 hybrid architecture", "Orchestrator-Mediated" (as external system) | Current checkpoint-based command pattern |
| `context/templates/subagent-template.md` | XML blocks (`<context>`, `<role>`, `<task>`), `mode: subagent`, no `name:` field | Current minimal frontmatter |
| `context/templates/agent-template.md` | `version:`, `mode:`, `max_tokens:`, `timeout:`, JSON "Inputs Required/Forbidden" blocks | Current minimal frontmatter + execution flow |

### Co-Authored-By Trailer Conflict

`CLAUDE.md` documents git commit format with `Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>`. The user's project memory (`feedback_no_coauthored_by.md`) explicitly states to omit all Co-Authored-By trailers. The CLAUDE.md convention is inconsistent with actual preferences.

---

## Existing Documentation Patterns

### Strong Patterns (Reusable Templates)

1. **`context/checkpoints/README.md`** — Well-structured directory README with architecture
   diagram, table of files, per-checkpoint descriptions, and usage examples. Good model for
   other subdirectory READMEs.

2. **`context/reference/README.md`** — Standard two-column table (file, description) +
   "Purpose" section explaining how this dir differs from adjacent ones + "Related
   Documentation" + "Navigation" footer. Consistent, reusable pattern.

3. **`context/README.md`** — Comprehensive directory README with: ASCII tree, role
   boundaries, directory purposes, loading strategy table, file naming conventions,
   add-new-file guide, and index.json schema. The gold standard for a directory README.

4. **`extensions/README.md`** — Explains extension architecture, available extensions
   table, loading process (numbered steps), extension structure tree, and validation
   commands. Well-suited as a template for feature-area READMEs.

5. **`agents/README.md`** — Minimal but consistent: file inventory table, structure block
   showing frontmatter schema, usage note, navigation links. Good minimal README pattern.

6. **`docs/reference/standards/agent-frontmatter-standard.md`** — Consistent header
   block (Created, Purpose), overview, required/optional tables, usage guidelines, examples
   for each case, migration section, related documentation. The best example of a standards
   document.

### Template Files With Known Issues

| Template | Location | Issue |
|----------|----------|-------|
| `agent-template.md` | `docs/templates/` | Old 8-stage format, obsolete frontmatter |
| `command-template.md` | `docs/templates/` | Wrong frontmatter (`agent:` not `description:`) |
| `agent-template.md` | `context/templates/` | Old format (mode, version, max_tokens) |
| `subagent-template.md` | `context/templates/` | XML blocks, no `name:` field |
| `command-template.md` | `context/templates/` | Uses `name:` not `description:` |

The modern reference for agent format is the actual agents themselves plus
`docs/reference/standards/agent-frontmatter-standard.md`. For commands, the actual command
files in `commands/` are the authoritative template.

---

## Evidence / Specific File Paths

### Verified Missing Entries

- `/home/benjamin/.config/nvim/.claude/README.md` line 97–107: agents table missing `reviser-agent`
- `/home/benjamin/.config/nvim/.claude/CLAUDE.md` Rules References section: lists 5 files, omits `rules/plan-format-enforcement.md`
- `/home/benjamin/.config/nvim/.claude/context/reference/README.md` line 6–8: lists `state-json-schema.md` (does not exist), omits `artifact-templates.md` and `workflow-diagrams.md`

### Verified Stale Templates

- `/home/benjamin/.config/nvim/.claude/docs/templates/agent-template.md`: uses `**Agent Type**`, `**Delegation Depth**`, `**Timeout**` header fields and 8-stage JSON workflow
- `/home/benjamin/.config/nvim/.claude/docs/templates/command-template.md`: frontmatter shows `agent: <agent-name>` — all real commands use `description:`, `allowed-tools:`, `argument-hint:`, `model:`
- `/home/benjamin/.config/nvim/.claude/context/templates/agent-template.md`: frontmatter block has `version: "1.0.0"`, `mode: orchestrator`, `max_tokens: 2000`, `timeout: 3600`
- `/home/benjamin/.config/nvim/.claude/context/templates/subagent-template.md`: uses `mode: subagent`, XML blocks (`<context>`, `<role>`, `<task>`)

### Verified Stale Guide

- `/home/benjamin/.config/nvim/.claude/docs/guides/creating-commands.md` lines 22–34: "OpenAgents" table, lines 40, 199: "v6.1 hybrid architecture"

### Verified Co-Authored-By Conflict

- `/home/benjamin/.config/nvim/.claude/CLAUDE.md` line 158: `Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>`
- `/home/benjamin/.config/nvim/.claude/context/standards/documentation.md` and `documentation-standards.md`: both titled "Documentation Standards", both present, overlapping content (311 + 241 lines)

### Agent Frontmatter Mismatch

- `/home/benjamin/.config/nvim/.claude/agents/code-reviewer-agent.md`: `mode: subagent`, `temperature: 0.1`, `tools:` block — none of these fields appear in any other current agent
- Actual current format confirmed in: `general-research-agent.md`, `planner-agent.md`, `reviser-agent.md`, `spawn-agent.md`

### Extension Integrity: Clean

All manifest `provides.skills[]` directories and `provides.agents[]` files verified present on disk. Extension manifests are internally consistent.

---

## Confidence Level

**High** — All findings above are based on direct file reads, `grep` searches, and `ls` comparisons. No inferences about file contents without reading. Cross-references verified bidirectionally where possible.

Specific claims not verified in depth (time constraints):
- Full content of `docs/guides/creating-commands.md` beyond lines 1–60 (stale sections confirmed in first 60 lines)
- Whether `context/standards/documentation.md` and `documentation-standards.md` are fully redundant or complementary (both titled the same, sized 311 and 241 lines respectively)
- Full audit of all 14 `context/standards/` files for additional overlap

---

## Summary of Priority Issues

| Priority | Issue | Files Affected |
|----------|-------|----------------|
| High | Templates document wrong frontmatter format | `docs/templates/agent-template.md`, `docs/templates/command-template.md`, `context/templates/subagent-template.md`, `context/templates/agent-template.md` |
| High | `creating-commands.md` has stale OpenAgents/v6.1 content | `docs/guides/creating-commands.md` |
| Medium | `reviser-agent` missing from README.md and skill-agent-mapping.md | `README.md`, `context/reference/skill-agent-mapping.md` |
| Medium | `context/reference/README.md` wrong filename and missing entries | `context/reference/README.md` |
| Medium | `code-reviewer-agent.md` uses obsolete frontmatter format | `agents/code-reviewer-agent.md` |
| Medium | `plan-format-enforcement.md` not listed in CLAUDE.md rules | `CLAUDE.md` |
| Low | `documentation.md` and `documentation-standards.md` are potential duplicates | `context/standards/` |
| Low | `docs/README.md` missing `guides/development/` subdirectory in tree | `docs/README.md` |
| Low | Co-Authored-By trailer in CLAUDE.md git convention conflicts with user memory | `CLAUDE.md` |
| Low | `/refresh` quick-ref in README.md shows incomplete syntax | `README.md` |

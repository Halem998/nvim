# Research Report: Task #396 — .claude/ Architecture Documentation Audit

**Task**: 396 - Review .claude/ agent system architecture and update all relevant documentation
**Date**: 2026-04-10
**Mode**: Team Research (4 teammates: Primary, Alternatives, Critic, Horizons)
**Session**: sess_1775846400_a3f2b1

---

## Summary

The `.claude/` agent system has a **systemic documentation deficit** far broader than the initially stated tactical request (create `filetypes/README.md`). Research uncovered three distinct drift domains:

1. **Extension README gap** (11 of 14 extensions missing README.md), confirming the task scope.
2. **Core-doc drift** in `.claude/` root: stale templates, incomplete reference tables, missing entries in `README.md`/`CLAUDE.md`/`skill-agent-mapping.md`, and an obsolete creating-commands guide.
3. **Template and frontmatter rot**: agent/command templates in both `docs/templates/` and `context/templates/` document a frontmatter format no live file uses.

The team also surfaced a **reference-model conflict**: the user nominated `present/README.md` as the model, but three teammates independently concluded `founder/README.md` is the superior template. This conflict is resolved in the Synthesis section: use `founder/README.md` as the canonical template with a section-applicability matrix so simple extensions can produce short README.md files in the spirit of `present/README.md`.

The recommended deliverable set is scoped in three tiers (must / should / nice-to-have) to manage blast radius.

---

## Key Findings

### Finding 1: Extension README coverage is 3/14 (21%)

| Has README.md | Missing README.md |
|---------------|-------------------|
| present, founder, memory | epidemiology, filetypes, **formal**, latex, lean, nix, nvim, python, typst, web, z3 |

**Source**: Teammate A (direct inventory), confirmed independently by Teammate D.

### Finding 2: The "reference model" is contested

- **User selected**: `present/README.md` (87 lines, command-focused, minimal)
- **Teammates A, C, D independently concluded**: `founder/README.md` (389 lines) is the more complete reference model because it includes Installation, MCP setup, Architecture tree, Workflow diagram, Output Artifacts, and Key Patterns — all missing from `present/README.md`.
- **memory/README.md** is highlighted as the best-structured (troubleshooting + best practices sections).

**Resolution** (see Synthesis §1): adopt `founder/README.md` as the canonical template but apply a **section-applicability matrix** so that simple extensions (z3, python, typst, latex, epidemiology) produce short READMEs in the spirit of `present/README.md`, while complex extensions (filetypes, lean, formal, nix, nvim, web) use the full template.

### Finding 3: `filetypes` is the highest-priority gap

The `filetypes` extension has 5 commands, 6 agents, 5 skills, 2 MCP servers, and substantial context — but no README.md. A directory-level context README exists at `extensions/filetypes/context/project/filetypes/README.md`, but it serves a different purpose (agent-loaded domain knowledge vs. user-facing extension overview).

**Required README coverage for filetypes**:
- 5 commands: `/convert`, `/table`, `/slides`, `/scrape`, `/edit`
- MCP setup: `superdoc` (npx @superdoc-dev/mcp) and `openpyxl` (npx @jonemo/openpyxl-mcp)
- Routing: `filetypes-router-agent` dispatches to specialized agents
- Tool dependencies: markitdown, pandoc, python-pptx
- Note: `skill-filetypes` maps to two agents (`filetypes-router-agent` and `document-agent`) — requires explanation

### Finding 4: Verified drift in core `.claude/` documentation

Teammate B conducted a thorough cross-reference audit and found:

**Missing/incorrect references**:
- `.claude/README.md` agents table: missing `reviser-agent`
- `.claude/CLAUDE.md` Rules References: missing `plan-format-enforcement.md` (rule exists on disk)
- `.claude/context/reference/README.md`: lists nonexistent `state-json-schema.md` (actual: `state-management-schema.md`); omits `artifact-templates.md` and `workflow-diagrams.md`
- `.claude/context/reference/skill-agent-mapping.md`: missing `skill-reviser`, `skill-spawn`, `skill-git-workflow`, `skill-orchestrator`, `skill-fix-it`
- `.claude/docs/templates/README.md`: references wrong filename `subagent-return-format.md` (actual: `subagent-return.md`)
- `.claude/docs/README.md`: missing `guides/development/` subdirectory in tree

**Stale templates** (all four document a frontmatter format no current agent/command uses):
- `.claude/docs/templates/agent-template.md` — uses `mode`, `version`, `max_tokens`, `timeout`
- `.claude/docs/templates/command-template.md` — documents `agent:` frontmatter field (real commands use `description:`, `allowed-tools:`, `argument-hint:`, `model:`)
- `.claude/context/templates/agent-template.md` — same obsolete format
- `.claude/context/templates/subagent-template.md` — XML blocks (`<context>`, `<role>`, `<task>`)

**Stale guide**:
- `.claude/docs/guides/creating-commands.md` — contains "OpenAgents" and "v6.1 hybrid architecture" terminology from a prior generation of the system; includes a "Neovim Configuration vs OpenAgents" comparison table that has no meaning in the current architecture

**Stale agent frontmatter**:
- `.claude/agents/code-reviewer-agent.md` — uses obsolete `mode: subagent`, `temperature: 0.1`, `tools:` block format; missing `model:` field

**Duplicate content**:
- `.claude/context/standards/documentation.md` (311 lines) and `documentation-standards.md` (241 lines) — both titled "Documentation Standards", overlapping content, never consolidated

### Finding 5: Manifest/filesystem inconsistency in `lean` extension

`.claude/extensions/lean/manifest.json` declares:
```json
"scripts": ["setup-lean-mcp.sh", "verify-lean-mcp.sh"]
```
…but no `scripts/` directory exists. The loader silently skips missing scripts. This is either (a) legacy cruft from a removed feature or (b) an accidental deletion. Needs user decision.

### Finding 6: `formal` extension has undocumented research-only pattern

The `formal` extension has 4 research agents (formal, logic, math, physics) and 4 research skills but **no implementation agents or skills**. This is intentional — implementation falls through to `general-implementation-agent` — but is not documented anywhere. Users running `/implement` on a formal task may be confused when the routing appears to disappear.

### Finding 7: Extension routing tables are accurate

Good news: all `EXTENSION.md` routing tables cross-checked against `manifest.json` and actual directory contents are consistent. No false entries, no missing agents/skills that should be present. Extension manifests are internally clean.

### Finding 8: Convention conflict — Co-Authored-By trailers

`.claude/CLAUDE.md` git commit convention documents:
```
Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
```
The user's stored memory (`feedback_no_coauthored_by.md`) explicitly says to omit Co-Authored-By trailers. This creates a conflict between documented convention and actual preference. Update the convention.

---

## Synthesis

### §1. Reference Model Conflict Resolution

**Conflict**: User says "use `present/README.md` as the reference model." Teammates A, C, D say `founder/README.md` is substantively better.

**Resolution** (evidence-based):
- Adopt `founder/README.md` as the **canonical template** (full structure: Overview, Installation, MCP Setup, Commands, Architecture tree, Skill-Agent Mapping, Language Routing, Workflow, Output Artifacts, Key Patterns, References).
- Apply the **section-applicability matrix** from Teammate A to let simple extensions omit sections:

| Section | Simple (z3, python, typst, latex, epidemiology) | Complex (filetypes, lean, formal, nix, nvim, web) |
|---------|-------------------------------------------------|---------------------------------------------------|
| Overview | Required | Required |
| Installation | Required | Required |
| MCP Tool Setup | Omit | Required if MCP present |
| Commands | Omit (if none) | Required |
| Architecture tree | Optional | Required |
| Skill-Agent Mapping | Required | Required |
| Language Routing | Required | Required |
| Workflow | Optional | Required |
| Output Artifacts | Omit | Required |
| Key Patterns | Optional | Required |
| References | Optional | Optional |

This honors the user's intent (simple extensions get terse present-style READMEs) while adopting the structural rigor of `founder/README.md`.

**Note on user instruction**: The task description said "use `present/README.md` as reference" but also named `filetypes` — a complex extension — as the primary target. A complex target needs a complex template. The synthesis respects both signals.

### §2. Scope Tier Resolution (Critic pushback)

**Conflict**: Teammate C argued for rescoping — write READMEs only for 4-5 complex extensions, not all 11, because simple extensions duplicate `EXTENSION.md`.

**Resolution**: Tier the work and let the planner stage decide. Tier 1 is non-negotiable; Tier 2 is strongly recommended; Tier 3 is deferrable.

| Tier | Scope | Rationale |
|------|-------|-----------|
| **Tier 1 (must)** | `filetypes/README.md` (explicit request); core-doc drift fixes from Finding 4; lean manifest scripts decision; Co-Authored-By convention update | Directly requested or demonstrably broken |
| **Tier 2 (should)** | README.md for complex extensions: `lean`, `formal`, `nvim`, `nix`, `web` | Complex routing or MCP setup genuinely benefits users |
| **Tier 3 (nice)** | README.md for simple extensions: `latex`, `python`, `typst`, `z3`, `epidemiology`; extension README template file; doc-lint script; creating-extensions.md update | Prevents future gaps but lower immediate value |

### §3. Gaps the Task Did Not Initially Scope

Teammate B surfaced core-doc drift. Teammate C highlighted EXTENSION.md injection drift and agent frontmatter description quality. Teammate D highlighted the empty ROADMAP.md and the template + doc-lint opportunity.

**Decision**: Fold Teammate B's concrete drift findings into Tier 1 because they are small, surgical edits that do not expand blast radius. Treat the broader strategic framings (manifest-driven generation, marketplace metadata) as out-of-scope for this task and record them as roadmap candidates.

### §4. Audience Question (Critic)

Teammate C asked: "Who reads extension READMEs?" The answer for this repo:
- **Primary**: The user themselves, returning after weeks/months away from an extension they built.
- **Secondary**: Claude agents when spawned with a task against an unfamiliar extension (they can read README.md as supplementary context).
- **Tertiary**: Future contributors or forks.

This justifies writing READMEs even though this is a personal config — the "future me" audience is real.

---

## Conflicts Resolved

| # | Conflict | Teammates | Resolution |
|---|----------|-----------|------------|
| 1 | Reference model: `present/README.md` vs `founder/README.md` | User vs A/C/D | Adopt `founder` as canonical template with section-applicability matrix |
| 2 | Scope: 11 extensions vs 4-5 complex only | User vs C | Three-tier plan; defer simple extensions to Tier 3 |
| 3 | Whether simple extensions need READMEs at all | A (yes, for consistency) vs C (no, duplicates EXTENSION.md) | Tier 3 (nice-to-have); don't block Tier 1/2 on this |
| 4 | Whether to tackle core-doc drift vs only extensions | B (scope expansion) vs user (narrow scope) | Include B's surgical fixes in Tier 1 (low cost, high value) |

---

## Gaps Identified

Items surfaced during research that deserve user decisions before planning:

1. **lean extension scripts**: Are `setup-lean-mcp.sh` and `verify-lean-mcp.sh` supposed to exist? Remove from manifest or restore files?
2. **formal research-only pattern**: Should this be documented as intentional in `formal/EXTENSION.md`, or is the implementation-agent fallthrough a bug?
3. **Duplicate documentation standards**: Consolidate `context/standards/documentation.md` and `documentation-standards.md` into one? Which is canonical?
4. **Template rot**: Delete stale templates in `docs/templates/` and `context/templates/`, or rewrite them to match current format?
5. **Co-Authored-By convention**: Update `.claude/CLAUDE.md` to match user's stated preference?
6. **Scope tier endorsement**: Does the user want Tier 1 only, Tier 1+2, or full Tier 1+2+3?
7. **`nvim` extension self-reference**: The `nvim` extension (for this repo's own config development) is itself missing a README. Highest-traffic extension. Priority?

---

## Recommendations

### Immediate (Tier 1 — Must)

1. **Create `.claude/extensions/filetypes/README.md`** using the full founder-style template:
   - Overview with capability table (5 commands)
   - Installation (`<leader>ac`)
   - MCP Tool Setup (superdoc, openpyxl)
   - Commands section for each of `/convert`, `/table`, `/slides`, `/scrape`, `/edit`
   - Architecture tree (6 agents, 5 skills, 5 commands, context structure)
   - Skill-Agent Mapping table (noting the skill-filetypes -> two-agent mapping)
   - Workflow diagram
   - Output Artifacts table
   - Tool dependency notes

2. **Fix core-doc drift (Finding 4 surgical fixes)**:
   - Add `reviser-agent` to `.claude/README.md` agents table
   - Add `plan-format-enforcement.md` to `.claude/CLAUDE.md` Rules References
   - Fix filenames in `.claude/context/reference/README.md` (`state-json-schema.md` → `state-management-schema.md`) and add `artifact-templates.md`, `workflow-diagrams.md`
   - Add missing skills to `.claude/context/reference/skill-agent-mapping.md` (`skill-reviser`, `skill-spawn`, `skill-git-workflow`, `skill-orchestrator`, `skill-fix-it`)
   - Fix `subagent-return-format.md` → `subagent-return.md` references in `.claude/docs/templates/README.md`
   - Add `guides/development/` subdirectory to `.claude/docs/README.md` tree

3. **Update `.claude/CLAUDE.md`**:
   - Remove Co-Authored-By trailer from commit convention template (honors user memory)

4. **Update `.claude/agents/code-reviewer-agent.md`**:
   - Migrate frontmatter to the current minimal format (`name`, `description`, `model`)

5. **Decide lean scripts**: Either remove from `manifest.json` or restore the script files (blocker; ask user)

### Strongly Recommended (Tier 2 — Should)

6. **Create README.md for complex extensions** (founder template, full section set):
   - `lean/README.md` — MCP setup, lake build workflow, rules
   - `formal/README.md` — 4-language routing, **document the research-only pattern**
   - `nvim/README.md` — highest-traffic extension, self-referential importance
   - `nix/README.md` — mcp-nixos MCP setup
   - `web/README.md` — `/tag` command, rules, skills

### Nice-to-Have (Tier 3)

7. **Create README.md for simple extensions** (present-style terse format): `latex`, `python`, `typst`, `z3`, `epidemiology`
8. **Extension README template**: Add `.claude/templates/extension-readme-template.md` derived from founder
9. **Update `.claude/docs/guides/creating-commands.md`**: Remove all OpenAgents / v6.1 hybrid-architecture references; document current checkpoint-based command pattern
10. **Rewrite or delete stale templates**:
    - `.claude/docs/templates/agent-template.md`
    - `.claude/docs/templates/command-template.md`
    - `.claude/context/templates/agent-template.md`
    - `.claude/context/templates/subagent-template.md`
11. **Consolidate duplicate doc-standards**: Merge `.claude/context/standards/documentation.md` and `documentation-standards.md`
12. **Update `.claude/docs/guides/creating-extensions.md`**: Require README.md as a standard deliverable
13. **Doc-lint script**: `.claude/scripts/check-extension-docs.sh` flagging missing or stale docs
14. **ROADMAP.md**: Populate with documentation infrastructure items

---

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|------------------|
| A | Primary (implementation patterns) | Completed | High | Extension inventory; founder-template with section-applicability matrix; filetypes detail |
| B | Alternatives (core-doc drift) | Completed | High | Cross-reference drift audit; stale templates and guide; frontmatter rot; Co-Authored-By conflict |
| C | Critic | Completed | High/Medium | Reference model critique; scope challenge; EXTENSION.md injection drift concern |
| D | Horizons | Completed | High/Medium | Empty ROADMAP context; strategic framing; doc-lint and template opportunities |

---

## References

### Files consulted (evidence base)

**Extension artifacts** (all 14 extensions):
- `.claude/extensions/{ext}/manifest.json`
- `.claude/extensions/{ext}/EXTENSION.md`
- `.claude/extensions/present/README.md`, `founder/README.md`, `memory/README.md`

**Core documentation**:
- `.claude/README.md`, `.claude/CLAUDE.md`
- `.claude/context/reference/README.md`
- `.claude/context/reference/skill-agent-mapping.md`
- `.claude/docs/README.md`, `.claude/docs/guides/creating-*.md`
- `.claude/docs/templates/*`, `.claude/context/templates/*`
- `.claude/docs/reference/standards/agent-frontmatter-standard.md`
- `.claude/docs/reference/standards/extension-slim-standard.md`
- `.claude/agents/code-reviewer-agent.md`

**Infrastructure**:
- `lua/neotex/plugins/ai/shared/extensions/config.lua` (extension loader config)
- `specs/ROADMAP.md` (empty)

### Teammate findings files

- `specs/396_review_claude_architecture_docs/reports/01_teammate-a-findings.md`
- `specs/396_review_claude_architecture_docs/reports/01_teammate-b-findings.md`
- `specs/396_review_claude_architecture_docs/reports/01_teammate-c-findings.md`
- `specs/396_review_claude_architecture_docs/reports/01_teammate-d-findings.md`

# Research Report: Task #93

**Task**: 93 - investigate_agent_system_changes_cross_repo
**Started**: 2026-02-24T00:00:00Z
**Completed**: 2026-02-24T00:30:00Z
**Effort**: 2-4 hours
**Dependencies**: None
**Sources/Inputs**: Git histories, skill files, agent files, context structures
**Artifacts**: - path to this report
**Standards**: report-format.md, return-metadata-file.md

## Executive Summary

- ProofChecker has implemented **Team Mode** (multi-agent parallel execution) with wave-based orchestration, requiring `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- ProofChecker has added **model enforcement** in agent frontmatter (`model: opus` for Lean tasks) and TeammateTool spawning
- Logos/Theory has implemented a **machine-readable context index** (`index.json`) with JSON Schema for automated context discovery
- Logos/Theory has added **domain-specific research agents** (math-research-agent, logic-research-agent) with hierarchical context loading patterns
- Both repositories have more mature language routing, blocked tool documentation, and incremental summary formats

## Context & Scope

This research investigates recent changes to the `.claude/` agent systems in:
1. `/home/benjamin/Projects/ProofChecker/.claude/`
2. `/home/benjamin/Projects/Logos/Theory/.claude/`

Compared against the current agent system in `/home/benjamin/.config/nvim/.claude/` to identify features worth adopting.

## Findings

### 1. Team Mode (ProofChecker) - HIGH VALUE

ProofChecker has implemented a complete team-based parallel execution system with three new skills:
- `skill-team-research` - Spawns 2-4 research teammates for parallel investigation
- `skill-team-plan` - Spawns 2-3 planning teammates for parallel plan generation
- `skill-team-implement` - Spawns teammates for parallel phase execution with debugger support

**Key Features**:
- Wave-based execution model (Wave 1: parallel work, synthesis, optional Wave 2)
- Language-aware routing (Lean vs generic prompts)
- Conflict detection and resolution during synthesis
- Graceful degradation to single-agent when teams unavailable
- Successor teammate pattern for context exhaustion (handoff chains)
- Run-scoped artifact naming (e.g., `research-001-teammate-a-findings.md`)

**Supporting Files**:
- `.claude/context/core/patterns/team-orchestration.md` - Wave coordination patterns
- `.claude/context/core/formats/team-metadata-extension.md` - Team result schema
- `.claude/utils/team-wave-helpers.md` - Reusable wave patterns and prompt templates

**Trade-offs**:
- Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable
- Uses ~5x tokens vs single agent
- Best for complex tasks needing diverse perspectives

### 2. Model Enforcement (ProofChecker) - MEDIUM VALUE

ProofChecker has added explicit model selection enforcement:

**Agent Frontmatter**:
```yaml
model: opus  # For Lean agents
```

**TeammateTool Spawning**:
```
Model: $default_model  # "opus" for Lean, "sonnet" for others
```

**Rationale**:
- Opus 4.6 for Lean theorem proving (superior mathematical reasoning)
- Sonnet 4.6 for general tasks (cost-effective)

### 3. Context Index Schema (Logos/Theory) - HIGH VALUE

Logos/Theory has implemented a machine-readable context index at `.claude/context/index.json`:

**Schema Features**:
- JSON Schema with validation (`$schema`, `$id`)
- Entry metadata: `path`, `domain`, `subdomain`, `topics`, `keywords`, `summary`
- Agent-aware loading: `load_when.agents[]` field for automatic discovery
- Budget-aware loading: `line_count` field for context budget management
- Dynamic discovery via `jq` queries replacing hardcoded file lists

**Benefits**:
- Agents can query index for relevant context files
- No need to maintain hardcoded file lists in agents
- Automatic discovery when new context files are indexed

**Example Query**:
```bash
jq -r '.entries[] |
  select(.load_when.agents[]? == "math-research-agent") |
  select(.path | contains("/algebra/")) |
  .path' .claude/context/index.json
```

### 4. Domain-Specific Research Agents (Logos/Theory) - MEDIUM VALUE

Logos/Theory has specialized research agents beyond the general pattern:
- `math-research-agent` - For algebra, lattice theory, order theory, topology
- `logic-research-agent` - For modal logic, temporal logic, mereology
- `latex-research-agent` - For LaTeX documentation tasks
- `typst-research-agent` - For Typst documentation tasks

**Key Pattern**:
- Hierarchical context loading from domain indices
- Codebase-first research strategy (LaTeX + Lean sources)
- Context Extension Recommendations section in reports
- Automatic task creation for context gaps (disabled for meta tasks)

### 5. Blocked Tool Documentation (ProofChecker) - MEDIUM VALUE

ProofChecker has comprehensive blocked tool documentation:

**Agent Headers**:
```markdown
## BLOCKED TOOLS (NEVER USE)

| Tool | Bug | Alternative |
|------|-----|-------------|
| `lean_diagnostic_messages` | lean-lsp-mcp #118 | `lean_goal` or `lake build` |
| `lean_file_outline` | lean-lsp-mcp #115 | `Read` + `lean_hover_info` |
```

**Supporting File**:
- `.claude/context/core/patterns/blocked-mcp-tools.md` - Central blocked tool reference

### 6. Phase Status Update Patterns (ProofChecker) - LOW VALUE

ProofChecker has explicit Edit tool examples for phase status transitions in implementation agents:
- `[NOT STARTED]` -> `[IN PROGRESS]` -> `[COMPLETED]`/`[PARTIAL]`/`[BLOCKED]`
- Added to `.claude/rules/artifact-formats.md` as status decision tree

### 7. Incremental Summary Format (ProofChecker) - LOW VALUE

ProofChecker has added to `summary-format.md`:
- Phase Entry schema with required/optional fields
- Cumulative Statistics section format
- Progress vs Summary distinction
- Create-or-append logic for updates

### 8. Language Routing Tables (Both) - ALREADY PRESENT

Both repositories have comprehensive language routing tables. The nvim repository already has similar routing in CLAUDE.md.

## Not Recommended for Adoption

### Lake Repair Skill (ProofChecker)

`skill-lake-repair` is Lean-specific for fixing `lake build` failures. Not applicable to nvim configuration.

### `/todo` Command (ProofChecker Task 913)

Changes to `/todo` are already present in nvim's version.

## Recommendations

### Priority 1: Team Mode Skills (if experimental features are acceptable)

If willing to use `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`:
1. Create `skill-team-research`, `skill-team-plan`, `skill-team-implement`
2. Add `team-orchestration.md`, `team-metadata-extension.md`, `team-wave-helpers.md`
3. Modify `/research`, `/plan`, `/implement` to accept `--team` flag

**Estimated Effort**: 8-12 hours

### Priority 2: Context Index Schema

Convert `index.md` to `index.json` with JSON Schema:
1. Create schema definition at `.claude/context/index.json`
2. Populate entries for all existing context files
3. Update agents to use `jq` queries for context discovery

**Estimated Effort**: 4-6 hours

### Priority 3: Model Enforcement in Agent Frontmatter

Add `model:` field to agent frontmatter for explicit model selection:
1. Update agents that benefit from specific models
2. Document model selection rationale in agent comments

**Estimated Effort**: 1-2 hours

### Priority 4: Blocked Tool Documentation Pattern

If using MCP tools that have known bugs:
1. Add "BLOCKED TOOLS" section to relevant agents
2. Create `.claude/context/core/patterns/blocked-mcp-tools.md`

**Estimated Effort**: 1-2 hours

### Priority 5: Domain-Specific Research Agents

The nvim repository already has `neovim-research-agent`. Consider adding:
- Context extension recommendations in reports
- Automatic context gap task creation (Stage 5.5 pattern)

**Estimated Effort**: 2-4 hours

## Feature Comparison Matrix

| Feature | ProofChecker | Logos/Theory | nvim (this repo) | Recommend? |
|---------|-------------|--------------|------------------|------------|
| Team Mode (parallel agents) | Yes | No | No | Yes (P1) |
| Context index.json | Partial | Yes | No (index.md) | Yes (P2) |
| Model enforcement | Yes | No | No | Yes (P3) |
| Blocked tool docs | Yes | Partial | No | Yes (P4) |
| Domain research agents | lean-research | math/logic/latex/typst | neovim-research | Partial (P5) |
| Incremental summary format | Yes | Yes | Partial | Low |
| Language routing | Yes | Yes | Yes | Already present |
| jq escaping workarounds | Yes | Yes | Yes | Already present |
| Early metadata pattern | Yes | Yes | Yes | Already present |

## Decisions

- Focus on Team Mode as highest-value feature if experimental features acceptable
- Context Index Schema is high value and does not require experimental features
- Model enforcement is low effort and should be adopted
- Domain-specific agents are lower priority since neovim-research-agent already exists

## Risks & Mitigations

### Team Mode Risks
- **Risk**: Experimental feature may have breaking changes
- **Mitigation**: Graceful degradation to single-agent is already designed

### Context Index Risks
- **Risk**: Maintaining index.json becomes another maintenance burden
- **Mitigation**: Could create script to auto-generate from file structure

### Model Enforcement Risks
- **Risk**: Model availability changes over time
- **Mitigation**: Use abstract model names ("opus", "sonnet") not specific versions

## Appendix

### Git Commits Reviewed

**ProofChecker** (recent .claude/ changes):
- 61324788: task 913 - /todo command updates
- b3ccb3af: task 904 - Model selection enforcement in team skills
- 6b97ae53: task 902 - Model: opus in Lean agent frontmatter
- 1deee31d: task 896 - Notation documentation
- c4ed86c0: task 895 - Phase status update patterns
- 6f990f8f: task 889 - Team artifact naming scheme
- 17cdbaaa: task 886 - Implement command team integration
- f82250a3: task 885 - Return metadata schema updates
- 50945be6: task 884 - Incremental summary format

**Logos/Theory** (recent .claude/ changes):
- 3b44c91: task 91 - Complete implementation
- 1fd2ddd: task 89 - latex-research-agent and skill-latex-research
- 655dbcb: task 88 - typst-research-agent
- a89f5de: task 87 - logic-research-agent
- a299e27: task 86 - Populate context index.json (2288+ lines)
- 619906a: task 85 - Create context index schema (172 lines)

### Files Examined

**ProofChecker**:
- `.claude/skills/skill-team-research/SKILL.md` (648 lines)
- `.claude/skills/skill-team-plan/SKILL.md` (589 lines)
- `.claude/skills/skill-team-implement/SKILL.md` (701 lines)
- `.claude/context/core/patterns/team-orchestration.md` (226 lines)
- `.claude/utils/team-wave-helpers.md` (647 lines)
- `.claude/agents/lean-implementation-agent.md` (frontmatter with model: opus)

**Logos/Theory**:
- `.claude/context/index.json` (schema definition)
- `.claude/skills/skill-math-research/SKILL.md` (311 lines)
- `.claude/skills/skill-logic-research/SKILL.md` (311 lines)
- `.claude/agents/math-research-agent.md` (724 lines)

**nvim (this repo)**:
- `.claude/context/index.md` (markdown, not JSON)
- `.claude/agents/general-implementation-agent.md`
- `.claude/agents/neovim-research-agent.md`
- `.claude/skills/` (14 skills, no team skills)

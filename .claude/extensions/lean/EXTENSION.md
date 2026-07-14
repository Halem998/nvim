## Lean 4 Extension

This project includes Lean 4 theorem prover support via the lean extension.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `lean4` | WebSearch, WebFetch, Read, Lean MCP | Read, Write, Edit, Bash (lake), Lean MCP |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-lean-research | lean-research-agent | Lean/Mathlib research |
| skill-lean-implementation | lean-implementation-agent | Lean proof implementation |
| skill-lake-repair | lean-implementation-agent | Lake build repair |
| skill-lean-version | (direct execution) | Lean version management |

### Rules

- lean4.md - Lean 4 coding conventions and MCP tool guidance (**/*.lean)
- plan-compliance.md - Strict plan-sequence compliance when an implementation plan exists (**/*.lean)

### MCP Integration

The `lean-lsp` MCP server provides:
- Goal state inspection (`lean_goal`)
- Proof search (`lean_state_search`, `lean_hammer_premise`)
- Mathlib lookup (`lean_loogle`, `lean_leansearch`, `lean_leanfinder`)
- Code actions and diagnostics

### Commands

- `/lake` - Build management and error handling
- `/lean` - Lean-specific proof assistance

### Lean Hard Mode

Activate with `--hard` flag on `/research` or `/implement` commands for lean4 tasks.

**When to use `--hard` for lean4**:
1. Research previously returned "Mathlib likely has this" without finding the lemma
2. Implementation dispatches produced analysis-heavy output without proof progress
3. Task involves faithful transcription from a paper or proof sketch
4. Three or more dispatches without completing a phase

**Routing (hard mode)**:

| Language | --hard Research | --hard Implement | --hard Plan |
|----------|-----------------|------------------|-------------|
| `lean4` | `skill-lean-research-hard` | `skill-lean-implementation-hard` | `skill-planner-hard` (core) |

**Skill-Agent Mapping (hard mode)**:

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-lean-research-hard | lean-research-hard-agent | opus | H2+H3+H4+H5 hard-mode Lean research |
| skill-lean-implementation-hard | lean-implementation-hard-agent | opus | H2+H9 hard-mode Lean implementation |

**Note**: `/plan --hard` for lean4 tasks uses `skill-planner-hard` (core hard planner).
No lean4-specific planner hard agent is needed — the core planner handles lean4 phase sizing.

**Behavioral Contracts Added by Hard Mode**:
- **H2 (lean4)**: Formal proof line bar — first sorry-free lemma within 30% of tool calls
- **H3 (lean4)**: 5-column lemma mapping table for literature-backed tasks
- **H4**: Adversarial self-verification pass in every research dispatch
- **H5**: Divergence audit mode (triggered by "divergence" or "audit" in focus_prompt)
- **H9**: Sorry inventory tracking in every implementation dispatch end

**Contract Override Files** (loaded automatically for hard agents):
- `.claude/extensions/lean/context/contracts/anti-analysis.md` - H2 lean4 override
- `.claude/extensions/lean/context/contracts/reference-grounding.md` - H3 lean4 override

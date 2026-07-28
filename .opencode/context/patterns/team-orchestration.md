# Team Orchestration Patterns

Wave-based coordination patterns for multi-agent team execution.

## Overview

Team orchestration uses a wave-based model where agents work in parallel within waves, and waves execute sequentially when dependencies exist.

## Wave Execution Model

Team research uses a two-wave model: Wave 1 for parallel research, Wave 2 for informed critique.

```
Wave 1 (parallel research):
+----------------+  +----------------+  +----------------+
| Teammate A     |  | Teammate B     |  | Teammate D     |
| Primary Angle  |  | Alternatives   |  | Horizons       |
+-------+--------+  +-------+--------+  +-------+--------+
        |                   |                   |
        +-------------------+-------------------+
                           |
                    (findings collected)
                           |
Wave 2 (informed critique):
                    +----------------+
                    | Teammate C     |
                    | Critic         |
                    | (reads A,B,D)  |
                    +-------+--------+
                           |
                    +------+------+
                    |   Lead      |
                    | Synthesis   |
                    +------+------+
```

**Dynamic team sizing** controls which teammates are spawned in Wave 1:
- `team_size == 2`: Wave 1 = A only; Wave 2 = Critic
- `team_size == 3`: Wave 1 = A + B; Wave 2 = Critic (default)
- `team_size == 4`: Wave 1 = A + B + D; Wave 2 = Critic

The Critic always runs in Wave 2 with access to Wave 1 findings. This enables targeted, informed critique rather than generic skepticism.

## Domain Context Injection

When a task's `task_type` matches a loaded extension, the lead queries `.opencode/context/index.json` for domain-specific context paths and injects them into all teammate prompts as a "Domain Context" section. This ensures team research teammates have the same domain knowledge as single-agent research agents (which use domain-specific agent definitions).

```bash
# Query index.json for domain context matching the task type
domain_agent_paths=$(jq -r --arg tt "$task_type" '
  .entries[] | select(
    any(.load_when.languages[]?; . == $tt) or
    any(.load_when.task_types[]?; . == $tt)
  ) | .path' .opencode/context/index.json)
```

## Coordination Responsibilities

### Lead Agent (Orchestrator)

The lead agent (skill) is responsible for:

1. **Wave Planning**
   - Analyze dependencies to identify parallelization opportunities
   - Group independent work into waves
   - Calculate team size per wave (max 4 concurrent)

2. **Teammate Spawning**
   - Create prompts with specific angles/roles
   - Enforce model selection via Agent tool parameter
   - Pass run-scoped output paths

3. **Synthesis**
   - Collect teammate results after wave completion
   - Detect and resolve conflicts
   - Identify coverage gaps
   - Generate unified output

4. **Postflight**
   - Update task status
   - Link artifacts
   - Commit changes
   - Cleanup temporary files

### Teammates

Each teammate is responsible for:

1. **Focused Execution**
   - Execute assigned angle/phase only
   - Avoid duplicating other teammates' work
   - Write output to specified path

2. **Status Reporting**
   - Write results to assigned output file
   - Include confidence level
   - Note any blockers or issues

## Exploit/Explore Modes

Team research supports optional mode hints via `--exploit` and `--explore` flags that shape teammate prompt generation:

| Mode | Flag | Teammate A | Teammate B | Teammate D |
|------|------|------------|------------|------------|
| **Default** | (none) | Implementation approaches | Alternative patterns | Strategic alignment |
| **Exploit** | `--exploit` | Deep-dive into best approach | Stress-test and validate | Feasibility assessment |
| **Explore** | `--explore` | Breadth-first survey | Unconventional alternatives | Unexplored approaches |

**When to use each mode**:
- **Exploit**: When a promising approach is identified and needs thorough investigation. "Focus many agents on different parts of a single idea."
- **Explore**: When current approaches are blocked or insufficient. "Search for new ideas."
- **Default/mixed**: When the situation is unclear. The focus prompt provides additional direction.

Modes are optional hints -- when neither flag is set, the default balanced behavior applies. The focus prompt provides further direction within any mode.

## Dependency Analysis

### Explicit Dependencies

Dependencies declared in plan metadata:

```markdown
### Phase 3: Configure Integration [NOT STARTED]

**Dependencies**: Phase 1, Phase 2
```

### Implicit Dependencies

Dependencies inferred from file modifications:

- Phases modifying the same files are dependent
- Cross-phase imports create dependencies
- Shared state modifications create dependencies

### Parallelization Decision

```
parallelizable(phase) =
  all dependencies completed AND
  no file conflict with concurrent phases
```

## Error Handling

### Teammate Failure

When a teammate fails or times out:

1. Continue with available results
2. Note gap in synthesis
3. Consider if gap is critical
4. Optionally trigger Wave 2

### Synthesis Failure

If lead cannot synthesize:

1. Preserve raw teammate outputs
2. Mark as partial
3. Return with available findings

### Team Creation Failure

If Agent tool fails (feature unavailable):

1. Log warning
2. Fall back to single-agent execution
3. Mark `degraded_to_single: true`

## Performance Considerations

### Token Usage

Team mode uses approximately 5x tokens compared to single-agent:
- Each teammate has full context
- Synthesis adds overhead
- Use team mode only when parallelization benefit justifies cost

### Timeout Configuration

- Wave timeout: 30 minutes (1800 seconds)
- Poll interval: 30 seconds
- Total operation timeout: Inherited from skill

## Best Practices

1. **Default to 3 teammates** - Primary + Alternatives + Critic; use `--fast` for 2 or `--hard` for 4
2. **Clear role separation** - Avoid overlap between teammate responsibilities
3. **Run-scoped outputs** - Use unique paths to avoid conflicts
4. **Graceful degradation** - Always have single-agent fallback
5. **Targeted commits** - Use git staging scope to avoid race conditions
6. **Domain context injection** - Always inject domain context when task_type has an extension
7. **Critic in Wave 2** - The Critic always reads Wave 1 findings before critiquing

## Synthesis Agent Pattern

After all Wave 1 and Wave 2 teammates complete, the lead dispatches `synthesis-agent` to read
all teammate finding files in a fresh context and write the unified report. The lead NEVER reads
teammate finding files directly.

```
Wave 1 (parallel research):
+------------+  +------------+  +------------+
| Teammate A |  | Teammate B |  | Teammate D |
+------+-----+  +------+-----+  +------+-----+
       |                |               |
       +----------------+---------------+
                        |
                (paths collected — no file reading)
                        |
Wave 2 (informed critique):
                 +------------+
                 | Teammate C |
                 | (Critic)   |
                 +------+-----+
                        |
                 (path collected)
                        |
Synthesis Wave (delegated):
                 +------------------+
                 | synthesis-agent  |
                 | (fresh context)  |
                 | Reads all files  |
                 | Writes report    |
                 +------+-----------+
                        |
                 (~200-word summary)
                        |
                 +------+------+
                 |   Lead      |
                 | (postflight)|
                 +-------------+
```

The lead's context growth from synthesis is ~200 tokens (the returned summary), not 7-21k tokens
from reading all teammate files inline.

**Key principle**: The lead collects file paths (not file content) from completed teammates, then
delegates all reading and synthesis to `synthesis-agent` via:

```
Agent(
  subagent_type: "synthesis-agent",
  prompt: [dispatch prompt with teammate paths as @-references],
  model: "${teammate_model}",
  timeout: 1200
)
```

See `.opencode/context/reference/team-wave-helpers.md` (Synthesis Agent Dispatch section) for the
full dispatch prompt template and expected return format.

**Context Protection**: Lead context overhead for the complete synthesis cycle:
- Teammate path collection: ~400 tokens (file paths only, no content)
- Synthesis dispatch prompt: ~300 tokens
- Synthesis agent return summary: ~200 tokens
- Total synthesis context growth: ~900 tokens (vs. 7-21k with inline synthesis)

## Context Discipline

For context budget limits and synthesis delegation guidance (forking a dedicated synthesis agent instead of having the lead read all teammate outputs inline), see `patterns/context-protective-lead.md`.

## Future Work (Tier 3)

The following improvements were identified during research but deferred due to higher implementation risk or need for measurement data:

- **Domain-specialized teammate roles**: Extension manifests define specialized roles (e.g., lean-tactic-hunter, lean-library-scout) instead of generic Primary/Alternatives
- **Team profiles**: Named configurations in `.opencode/context/team-profiles/` (default.json, exploit.json, explore.json, lean-proof.json) auto-selected by task type
- **Auto-routing to team research**: When repeated blockers are detected on the same task, auto-escalate from single-agent to team research with cost controls and circuit breakers
- **Structured decision matrices**: Replace prose synthesis with quantified comparison matrices (approaches as rows, evaluation criteria as columns, with scores and evidence)
- **Measurement infrastructure**: A/B comparison between single-agent and team research quality to validate that more agents produce better results
- **Cross-command propagation**: Extend exploit/explore framework to team-plan and team-implement

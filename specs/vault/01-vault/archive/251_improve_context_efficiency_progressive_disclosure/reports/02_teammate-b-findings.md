# Teammate B Findings: Alternative Patterns and Prior Art for Context Efficiency

**Date**: 2026-03-19
**Task**: 251 - Improve context efficiency throughout the Claude Code agent system
**Focus**: Alternative restructuring approaches, rules file analysis, frontmatter patterns, and trade-off analysis

---

## Key Findings

### 1. Rules Files: Scope Mismatch Between Content Type and Load Trigger

Rules files are loaded via path-pattern matching (`paths:` frontmatter), which means they load for
every file that matches — regardless of whether the content is actually relevant to the operation.

**Rules file load triggers and sizes:**

| File | Lines | Trigger | Content Type |
|------|-------|---------|--------------|
| `state-management.md` | 511 | `specs/**/*` | ~80% reference schema, ~20% behavioral |
| `artifact-formats.md` | 276 | `specs/**/*` | ~70% format templates, ~30% naming rules |
| `workflows.md` | 224 | `.claude/**/*` | ~100% behavioral diagrams |
| `error-handling.md` | 177 | `.claude/**/*` | ~60% behavioral, ~40% reference |
| `git-workflow.md` | 163 | none (always) | ~50% reference tables, ~50% behavioral |

**Critical observation**: `state-management.md` contains the "Task Entry Format" section (237 lines)
documenting the full JSON schema for state.json. This is reference material only needed when creating
or updating tasks — not for every operation touching `specs/**/*`. The same schema lives in
`context/core/reference/state-json-schema.md` (245 lines), creating near-complete duplication: both
files have ~140 unique content lines but only 38 overlapping lines, suggesting they diverged over time.

**The path-pattern model is a blunt instrument**: When running `/implement`, the `spec/**/*` rules
trigger because the skill reads from `specs/` to find the plan. This causes 787 lines of state schema
and artifact format content to load even though `/implement` never writes state.json entries from
scratch.

### 2. Content Taxonomy: What Belongs Where

Analysis of the 5 rules files reveals three distinct content categories with different loading needs:

**Category A — Behavioral Constraints** (load for relevant operations only):
- Status transition rules (which transitions are valid)
- Two-phase update pattern (write state.json first, then TODO.md)
- Error recovery sequences
- Git safety rules (never force-push, etc.)

**Category B — Reference Schemas** (load only when creating/reading that artifact type):
- state.json field descriptions (237 lines in state-management.md)
- TODO.md entry format
- Artifact naming conventions
- Phase status markers

**Category C — Process Diagrams** (rarely needed, mostly documentation):
- ASCII flowcharts in `workflows.md` (the Research/Planning/Implementation workflow boxes)
- Resume pattern diagram
- Error recovery diagram

Category A should stay in rules. Category B should move to on-demand context. Category C is
documentation that agents rarely need to reference inline — it belongs in `docs/` or context
loaded only by the meta-builder-agent when creating new components.

### 3. CLAUDE.md Has Three Conflated Purposes

The `.claude/CLAUDE.md` (294 lines) serves three distinct audiences simultaneously:

1. **Agent bootstrapping** (critical): Skill-to-agent mapping, state.json structure, commit conventions
2. **Developer reference** (optional at runtime): Vault operation details, task_type routing tables
3. **System documentation** (rarely needed): Multi-task creation standard descriptions

The vault operation fields schema (Section "Vault Fields Schema", ~35 lines) is only relevant during
`/todo` execution when `next_project_number > 1000`. This is a rare event (~once per year) but the
schema loads on every operation. Similarly, the `task_type` field documentation (30 lines) only
applies to extension languages and is loaded even for core language tasks.

### 4. Command-Skill Content Duplication Pattern

Commands and their corresponding skills describe the same operation at different levels. Measuring
the command + skill chain for core operations:

| Operation | Command | Skill | Chain Total |
|-----------|---------|-------|-------------|
| `/research` | 213 lines | 354 lines | 567 lines |
| `/plan` | 212 lines | 381 lines | 593 lines |
| `/implement` | 315 lines | 453 lines | 768 lines |

The command-level routing tables (language -> skill mapping) are repeated across multiple commands.
The routing table in `/research` (lines 100-135) describes the same language-to-skill mappings as
the routing table in `/implement` and `/plan`. The `context/core/routing.md` (150 lines) describes
these same mappings a third time.

This is not accidental — the repetition provides context at each delegation level. But it means
the routing logic consumes ~150+ lines three times when it could be represented once.

### 5. Dynamic Context Discovery via index.json Is Underused

The `context/index.json` contains 73 entries with intelligent `load_when` conditions mapping
context to agents, commands, and languages. However, this system is systematically underused:

- `spawn-agent`: 0 entries in index.json (relies entirely on inline content in agent file)
- `code-reviewer-agent`: 0 entries in index.json (self-contained 126-line file)
- `general-implementation-agent`: 4 entries, 510 lines
- `planner-agent`: 2 entries, 300 lines

The agents that use index.json for discovery still have large inline agent files (500 lines for
`general-implementation-agent.md`, 1504 lines for `meta-builder-agent.md`). The index.json system
provides additional context, but it doesn't reduce the agent file size itself.

**More importantly**: The index.json discovery mechanism requires an agent to already know to
query it. The pattern is documented in agent files as a suggestion ("Use index.json for automated
context discovery") but is not enforced or systematically used.

### 6. The "Always Load" + "Path Glob" Model vs. Alternatives

The current loading model has two mechanisms:
1. **Always load**: CLAUDE.md files (hierarchical, all load automatically)
2. **Path-triggered load**: Rules files (load when files matching the path glob are in context)

**Structural gap**: There is no "load only when command X is invoked" mechanism at the rules level.
The closest equivalent is the index.json `load_when.commands` field, but this requires agents to
explicitly query the index and load context — it is not automatic like rules files.

This creates a tension: detailed operational schemas that only apply to specific commands (`/todo`
for vault schema, `/task` for entry format) load for all operations touching the relevant paths.

---

## Alternative Approaches

### Approach 1: Rules File Stratification

Split each rules file into a "core constraints" section and a "reference schemas" section.
Keep constraints in the rules file (auto-loaded), move schemas to linked context files.

Example for `state-management.md`:
- **Keep in rules** (~60 lines): File sync requirement, status transition rules, two-phase update pattern, error handling on write failure
- **Move to context** (~237 lines): Task entry format schemas, all field-level descriptions, vault fields schema, completion fields schema, artifact object schema

This preserves automatic loading of behavioral rules while making reference material on-demand.
Estimated saving: ~450 lines removed from always-loaded rules, accessible via `@-reference` when needed.

### Approach 2: Command-Scope Rules

Add a `commands:` frontmatter field to rules files alongside `paths:`, allowing rules to specify
which commands trigger them. This would require Claude Code to support command-scoped rules,
which is not currently documented.

**Alternative without system changes**: Create a "command preamble" pattern where each command
file includes a brief `@-reference` to its specific rules file at the top of its execution section.
This uses the existing `@-reference` mechanism without requiring new system features.

### Approach 3: Tiered Agent Files

Break large agent files into a "dispatcher" file (small, always available) and "execution detail"
files (loaded on demand). The dispatcher would contain:
- Identity, purpose, and tool list
- Entry conditions and basic routing
- `@-reference` to execution details

The `meta-builder-agent.md` (1504 lines) would become a 60-line dispatcher plus 4 separate
execution files for its modes (interactive, prompt, analyze, document).

This mirrors how commands delegate to skills — add another delegation layer within the agent tier.

### Approach 4: Summary-First Context Files

Each context file pair: a `{name}-summary.md` (5-10 lines, always available) and `{name}-full.md`
(complete content, referenced by summary). Agents choose whether to load the full version.

This is conceptually what the index.json `summary` field already provides — but the summaries are
only machine-readable (JSON), not directly usable as context. Making summaries human-readable
context files would allow agents to load summaries first, then request full content if needed.

### Approach 5: Operation-Specific Context Bundles

Group related context files into "bundles" for common operations. Instead of agents querying
index.json with multiple conditions, a bundle file provides a curated list:

```
.claude/context/bundles/
  research-operation.md  # Curated list of files for research operations
  planning-operation.md  # Curated list for planning
  implementation-operation.md
  meta-operation.md
```

Each bundle is a small file listing `@-references` to the relevant context. Commands load the
bundle, which transitively loads the right context. This is essentially explicit dependency
management for context.

---

## Trade-off Analysis

### Splitting Rules Files

**Benefits**:
- Immediate reduction in always-loaded content (~450 lines from state-management.md alone)
- No system changes required (uses existing `@-reference` mechanism)
- Backward compatible (agents that currently work will continue to work)

**Costs**:
- Agents must know to load the reference section when needed (potential for missed schemas)
- More files to maintain (two files per current rules file)
- Risk of behavioral regressions if agents skip loading schemas they actually need

**Confidence**: High that splitting is beneficial. The state-management.md "Task Entry Format"
section (237 lines of field-by-field schema documentation) is clearly reference material that
most operations don't need inline.

### Command-Scope Rules

**Benefits**:
- Eliminates the "blunt instrument" problem — schemas load only for relevant commands
- Could reduce rules loading from 787 lines to 150-200 lines for most operations

**Costs**:
- Requires either system changes or discipline in command file authoring
- Without system enforcement, command-scoped rules are just documentation that may be ignored

**Confidence**: Medium. The benefit is real but the implementation path requires either new
Claude Code features or careful manual management.

### Tiered Agent Files

**Benefits**:
- Would significantly reduce meta-builder-agent's 1504-line footprint
- Mode-specific content (the detailed interview stages) loads only when that mode is active

**Costs**:
- Adds delegation complexity (dispatcher calls execution file via @-reference)
- Claude Code's behavior with deeply nested @-references is not clearly documented
- Refactoring 1504 lines is non-trivial work with regression risk

**Confidence**: Medium. The approach is sound architecturally but implementation complexity is high.

### Summary-First Context Files

**Benefits**:
- Enables progressive disclosure within the context system itself
- Agents can make informed loading decisions based on summaries

**Costs**:
- Doubles the number of context files
- Requires agents to implement "load summary, decide, then load full" logic consistently
- No existing precedent in this codebase for this pattern

**Confidence**: Low. Too much new machinery required; the index.json `summary` field already
partially covers this use case without requiring new files.

### Operation-Specific Context Bundles

**Benefits**:
- Clear, auditable list of what each operation needs
- Reduces index.json query complexity
- Easier to maintain than distributed `load_when` conditions

**Costs**:
- Yet another layer of indirection
- Bundles can go stale as context files are added/removed
- Requires updating bundles when adding new context files

**Confidence**: Medium. Useful as an organizational pattern but doesn't reduce total content,
only improves discoverability.

---

## Observations on Prior Art Patterns

### How Other Agent Systems Handle This Problem

Based on general knowledge of LLM agent system design (not this specific codebase):

**Retrieval-Augmented Generation (RAG) for agent context**: Production agent systems commonly
use vector search to retrieve relevant context chunks at query time. The `index.json` approach
in this codebase is a lightweight semantic equivalent — structured metadata enables programmatic
discovery without vector databases. The key difference is that RAG selects content at inference
time, while this system requires agents to explicitly invoke the query.

**Tool-schema lazy loading**: OpenAI and Anthropic tool-use patterns load tool schemas on demand
rather than providing all tools upfront. The equivalent in this system would be providing agents
with a "tool catalog" (index.json summary) and having them request full specifications only for
tools they need. This is architecturally similar to the existing index.json pattern but suggests
the summaries should be more prominent in agent context.

**Hierarchical configuration inheritance**: Tools like Terraform and Ansible use hierarchical
config with override semantics, where more-specific config overrides less-specific. The multiple
CLAUDE.md files in this system already implement this pattern, but the content within each level
could be more aggressively tiered — putting only the most essential constraints at the top level
and detailed schemas at lower levels loaded on demand.

**System prompt compression**: Several research papers on LLM context efficiency (e.g., LLMLingua,
Selective Context) show that ~50% of system prompt tokens can be compressed with <3% performance
degradation for reference content. The implication for this system: detailed field-by-field schema
documentation (Category B content) is prime compression candidate — agents primarily need to know
*that* a field exists and *what it does*, not necessarily the exact format of every edge case.

---

## Confidence Levels by Finding

| Finding | Confidence | Rationale |
|---------|------------|-----------|
| Rules files contain mismatched content types | **High** | Direct measurement: 237 lines of schema in state-management.md |
| state-management.md/state-json-schema.md duplication | **High** | Measured: both ~140 unique lines with only 38 overlap |
| Command-skill chain creates routing repetition | **High** | Direct measurement: routing tables appear 3x |
| index.json underused for spawn-agent/code-reviewer | **High** | Verified: 0 entries for these agents |
| Splitting rules files would reduce always-loaded content | **High** | Straightforward structural change |
| Tiered agent files would help meta-builder-agent | **Medium** | Architecturally sound but requires careful refactoring |
| Operation context bundles would improve discoverability | **Medium** | Organizational improvement, no reduction in content |
| Summary-first pattern viable | **Low** | Too many new files and enforcement mechanisms needed |

---

## Recommended Priority

1. **Split state-management.md** (high value, low risk): Move the "Task Entry Format" section
   and other field schemas (~300 lines) to `context/core/reference/state-management-schemas.md`.
   Keep behavioral rules (~60 lines) in the rules file. This alone removes ~300 always-loaded
   lines per operation touching `specs/**/*`.

2. **Consolidate state-json-schema.md duplication**: The near-parallel content in
   `rules/state-management.md` (Task Entry Format section) and
   `context/core/reference/state-json-schema.md` should be merged into a single authoritative
   schema file. The rules file should `@-reference` it rather than duplicating it.

3. **Add command-specific context annotations to rules**: Add comments to rules files indicating
   which sections are needed by which commands. This is documentation-only (no system changes)
   but helps future maintainers understand what to split.

4. **Register spawn-agent and code-reviewer-agent in index.json**: These agents have zero index
   entries. Even if their context needs are simple, registering them establishes the pattern and
   allows future context additions to be discovered automatically.

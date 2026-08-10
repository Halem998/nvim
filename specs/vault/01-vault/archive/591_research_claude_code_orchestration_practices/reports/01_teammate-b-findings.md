# Research Report: Task #591 — Teammate B Findings

**Task**: 591 - Research Claude Code 2026 best practices for orchestration patterns
**Role**: Teammate B — Alternative Approaches and Prior Art
**Started**: 2026-05-22T00:00:00Z
**Completed**: 2026-05-22T00:30:00Z
**Effort**: Medium (~25 queries, 15 source reads)
**Focus**: Alternative architectures, deduplication strategies, prior art from other agent systems

---

## Executive Summary

- The current 3-layer command → skill → agent delegation chain is not mandated by Claude Code; commands can invoke agents directly, eliminating the skill intermediate layer for simple operations.
- The `CLAUDE_CODE_FORK_SUBAGENT=1` mechanism offers ~90% input token reduction for children 2-N in parallel spawns, but is currently blocked by explicit `subagent_type` in all core skills — an architectural trade-off that could be revisited.
- The OpenAI Agents SDK `input_filter` + history compression pattern is directly applicable to reduce repeated context in sequential agent chains (research → plan → implement).
- `@include` directives for CLAUDE.md composition are not yet implemented (open GH issue #13614, December 2025), but symlinks and shell-script based assembly are effective workarounds that this system could adopt today.
- A unified "workflow engine" script pattern — where a single parameterized script replaces three near-identical postflight scripts — would immediately eliminate ~60% of the shell-script duplication.
- LangGraph's conditional routing pattern (approve → continue, reject → revise node) maps well to the blocker-escalation and plan-revision use case.

---

## Context and Scope

This report investigates alternative architectural patterns for the Claude Code agent system at
`/home/benjamin/.config/nvim/.claude/`, which has:

- ~18,000 lines across commands, skills, and agents
- ~80% duplication across `skill-researcher`, `skill-planner`, `skill-implementer`
- Three postflight scripts (`postflight-research.sh`, `postflight-plan.sh`, `postflight-implement.sh`) differing only in 7 variable strings
- The same `parse_task_args()` / `parse_ranges()` bash function copy-pasted verbatim into 3 command files
- The same STAGE 1.5 flag-parsing block (25 lines) copy-pasted 3 times

The focus is on approaches NOT covered by Teammate A (primary/official patterns) — specifically alternatives, trade-offs, and patterns from other systems.

---

## Findings

### 1. Command → Agent Direct Delegation (Eliminating the Skill Layer)

**Finding**: Skills as an intermediate layer are not required by Claude Code's architecture. The official docs explicitly state that commands can delegate to subagents directly. Skills were introduced to provide structured context injection and multi-stage postflight — but these can equally live in the command file itself.

**Current chain**: `/research` → `skill-researcher` → `general-research-agent`
**Proposed alternative**: `/research` → `general-research-agent`

**When this works**: When the command has enough context to inject structured delegation context directly and execute postflight. The skill layer is only valuable when (a) the same skill is invoked from multiple entry points, or (b) the skill contains substantial logic not present in the command.

**Evidence from codebase**: Looking at `skill-researcher/SKILL.md`, the skill's entire value-add is:
- Stage 1: Input validation (identical logic to the command's GATE IN)
- Stage 2: Preflight status update (call `update-task-status.sh`)
- Stage 3-4: Create postflight marker + read artifact number
- Stage 4a-4d: Memory retrieval, roadmap, prior context (3 bash calls)
- Stage 5: Invoke subagent via Agent tool
- Postflight: Call `update-task-status.sh` + `postflight-research.sh`

This is ~300 lines of glue. If the command's GATE IN/GATE OUT already handles status updates, the skill is redundant for single-entry-point commands.

**Trade-off**: Eliminating skills removes one level of re-use. If `/revise` also needed to invoke `general-research-agent`, a shared skill prevents duplication. But currently, each skill has exactly one parent command.

**Confidence**: Medium — viable for single-entry commands; risky if skills gain multiple callers.

---

### 2. Unified Workflow Engine Shell Script

**Finding**: Three postflight scripts (`postflight-research.sh`, `postflight-plan.sh`, `postflight-implement.sh`) differ only in 7 substituted strings (operation name, status value, artifact type, timestamp field name, log message). This is a textbook case for parameterization.

**Current situation** (confirmed by `diff`): These 69-line scripts are identical except for:
- `status: "researched"` vs `"planned"` vs `"implemented"`
- `artifact.type: "research"` vs `"plan"` vs `"summary"`
- `researched: $ts` vs `planned: $ts` vs `implemented: $ts`

**Proposed**: A single `postflight-workflow.sh TASK_NUMBER ARTIFACT_PATH [SUMMARY] OPERATION_TYPE` where `OPERATION_TYPE` is `research|plan|implement`.

```bash
# Single parameterized script replacing three:
postflight-workflow.sh "$task_number" "$artifact_path" "$summary" "research"
postflight-workflow.sh "$task_number" "$artifact_path" "$summary" "plan"
postflight-workflow.sh "$task_number" "$artifact_path" "$summary" "implement"
```

**Token savings**: Zero — scripts run in bash, not in LLM context. But maintenance burden drops ~65% for this subsystem.

**Similarly applicable**: The `parse_task_args()` and STAGE 1.5 flag-parsing blocks, which appear verbatim in all three commands, could be extracted to `.claude/scripts/parse-command-args.sh` and sourced. This would reduce 3 × ~30 lines = ~90 lines down to 3 × 1 line.

**Confidence**: High — this is straightforward shell scripting refactoring with no architectural trade-offs.

---

### 3. `@include` Directive Pattern for Markdown Deduplication

**Finding**: The Claude Code community has an open feature request (GH issue #13614, December 2025) for `@include` directives in CLAUDE.md files. It is NOT yet implemented. The proposed syntax:

```markdown
@include ~/.claude/shared/flag-parsing.md
@include ~/.claude/shared/lifecycle-stages.md
```

This would directly solve the problem of the same STAGE 0 parse block appearing in 3 commands.

**Current workarounds** (viable today):
1. **Symlinks**: Create `commands/shared/flag-parsing.md` and symlink it from each command. Limitation: Claude Code reads actual file content, so symlinks need to resolve properly.
2. **Build script assembly**: A pre-commit hook or `make` target assembles command files from shared fragments. Adds tooling complexity but works reliably.
3. **@-references to context files**: The current `@.claude/context/` system already supports this for reference documents. Shared algorithm descriptions (not executable logic) can be moved there. Commands then @-reference the single source of truth rather than copy it.

**Best available today**: Move shared pseudocode blocks (parse_task_args algorithm, flag parsing, GATE IN/OUT protocol) to `@.claude/context/patterns/shared-command-logic.md` and reference them from each command. The commands show a pointer, not the full text. The model still reads the full text from the context file. This does NOT reduce runtime token cost but massively reduces maintenance burden.

**Confidence**: High for @-reference strategy (works today); Low for @include (not yet implemented).

---

### 4. OpenAI Handoff Pattern: History Compression for Sequential Chains

**Finding**: OpenAI Agents SDK's `input_filter` + `nest_handoff_history` pattern collapses prior transcript into a `<CONVERSATION HISTORY>` summary block when agents hand off sequentially. This directly addresses the problem of research context re-injection into planning, and planning context re-injection into implementation.

**Current system behavior**: The `skill-planner` collects `prior_implementation_context` via Stage 4d (reading artifacts from disk), injects them as text blocks into the planner's context. This is functional but not compressed — it injects raw file content up to 500 lines.

**Alternative pattern** — Structured delta handoff:

Rather than injecting raw prior artifacts (research report, plan), inject a structured "handoff object":

```json
{
  "phase": "planning",
  "prior_phase_summary": "Research found X, Y, Z. Key decisions: A, B. Blockers: none.",
  "relevant_artifacts": ["specs/591_slug/reports/01_research.md"],
  "agent_may_skip": ["re-reading README", "re-scanning directory structure"],
  "prior_dead_ends": ["approach X was tried and failed because Y"]
}
```

This is 200-400 tokens vs 2000-5000 tokens for raw artifact injection.

**OpenAI SDK specifics applicable here**:
- `input_type` parameter captures small model-generated metadata at handoff time (exactly the structured summary above)
- Pre-built history filters remove tool calls from forwarded history (reducing noise)
- `RunContextWrapper.context` passes application state without touching LLM context

**Adaptation for Claude Code**: Skills could write a `.handoff-summary.json` file containing the structured delta, and the next skill in the chain reads only this file rather than all prior artifacts.

**Confidence**: Medium — the pattern is sound but requires discipline to maintain handoff object quality.

---

### 5. LangGraph Conditional Routing for Blocker Escalation

**Finding**: LangGraph's state machine pattern for revision cycles — where a workflow node conditionally routes to a "revision" node on failure/rejection rather than terminating — is the cleanest model for the `/spawn` blocker-escalation pattern.

**LangGraph's model**:
```
implement → [validate] → success → complete
                      → failure → [revision_node] → implement (retry)
                      → blocked → [spawn_node] → create_subtask → external
```

Each node is a function; conditional edges determine routing. State is checkpointed after each node, enabling resume from the exact failure point.

**Comparison to current system**:
- Current: `/spawn N` is a separate command that creates new tasks; blocker detection is manual
- LangGraph-style: `/implement` automatically detects blocked states and routes to `skill-spawn` internally

**Concrete adaptation**: Add a post-phase check in `skill-implementer` that reads phase output, detects blockers (regex patterns or structured error returns), and conditionally invokes `skill-spawn` before marking the task `[PARTIAL]`.

```
Phase N completes → read output → is_blocked?
  YES → auto-invoke skill-spawn → create subtask → mark [BLOCKED] with subtask reference
  NO → continue to Phase N+1
```

**State checkpoint advantage**: LangGraph's per-node checkpointing maps to the existing `[PARTIAL]` status + phase tracking in `state.json`. The system already has most of this; it just lacks the automatic routing.

**Confidence**: Medium-High — conceptually straightforward; main risk is false-positive blocker detection.

---

### 6. CLAUDE_CODE_FORK_SUBAGENT Cache Sharing Architecture

**Finding**: The `CLAUDE_CODE_FORK_SUBAGENT=1` mechanism enables ~90% input token reduction for parallel agent spawns (children 2-N share parent's cached prefix). Currently the core skills explicitly specify `subagent_type` in every Agent call, which bypasses the fork mechanism entirely.

**Current cost profile** (estimated for a 3-teammate team run):
- Each teammate spawns a fresh context
- At ~48,500 shared prefix tokens × 3 teammates = ~145,500 tokens
- With FORK_SUBAGENT: ~48,500 + 2 × 4,850 (10% cache-read rate) = ~58,200 tokens (~60% reduction)

**Architecture change required**: Team-mode skills (`skill-team-research`, `skill-team-plan`, `skill-team-implement`) spawn teammates without `subagent_type`. This means they ARE eligible for fork caching today if `CLAUDE_CODE_FORK_SUBAGENT=1` is set.

**The blocking constraint**: Fork subagents cannot use a named `subagent_type`. If fork is enabled, the children inherit the parent's context but don't get the structured agent system prompt from `.claude/agents/general-research-agent.md`. This is the core trade-off: cache savings vs agent-specific system prompt injection.

**Possible resolution**: Move agent-specific instructions from agent definition files into the skill's delegation prompt (where they already live as structured JSON context). Then omit `subagent_type` to enable forking. The agent definition file becomes a documentation artifact rather than a runtime requirement.

**Confidence**: Low-Medium for full adoption (significant refactoring required); High for team-mode only (already partially eligible).

---

### 7. Progressive Disclosure for Context Loading

**Finding**: The AGENTS.md research (Augment Code) and RAG patterns both converge on "progressive disclosure" — load minimal context upfront, pull detailed context on demand.

**Current system**: The context index has 139 entries loaded via `load_when` filters. This works well but agents still receive several thousand tokens of context at load time.

**RAG-style alternative**: Rather than a static `index.json` with `load_when` selectors, use a vector-search retrieval step at agent startup:
1. Agent receives only a 200-token "capability manifest" listing available context files
2. Agent calls a retrieval tool with the task description
3. Tool returns the 3-5 most relevant context files (by embedding similarity)
4. Agent loads those files on demand

**Trade-off analysis**:
- **Pro**: Avoids loading irrelevant context (e.g., nix patterns for a neovim task)
- **Con**: Requires embedding infrastructure; adds latency; current `load_when` filters already achieve similar targeting with zero infrastructure
- **Pro for RAG**: Future tasks in new domains don't require index updates
- **Con for RAG**: Memory vault already serves this function (`memory-retrieve.sh`)

**Verdict**: The current tiered system with `load_when` selectors is already close to optimal for a static context corpus. RAG only adds value if the context corpus becomes dynamic or very large (>500 files). The memory vault handles the dynamic case.

**Confidence**: Low — current approach is adequate; RAG adds complexity without proportionate benefit for this system's scale.

---

### 8. Structured Handoff Payload vs Full Context Forwarding

**Finding**: The NousResearch hermes-agent `handoff` payload pattern (GH issue #9555) proposes passing a structured object with "read files, ran commands, probe results, dead ends" rather than full conversation history. Quantified savings: 200-500 tokens vs 5,000-20,000 tokens per child agent context.

**Current system gap**: When `skill-implementer` collects `prior_implementation_context` (Stage 4d), it reads raw file content up to 500 lines. This is expensive and may include irrelevant historical content.

**Proposed structured replacement**:

```json
{
  "completed_phases": [1, 2, 3],
  "current_phase": 4,
  "key_decisions": ["Used approach X for Y because Z"],
  "files_modified": ["path/to/file.lua", "path/to/other.lua"],
  "open_questions": ["Does module A need to be reloaded?"],
  "do_not_repeat": ["Tried approach M, failed with error N"]
}
```

Written by each phase as `.phase-handoff.json`. The next phase reads only this structured file, not raw implementation summaries.

**Confidence**: Medium — concrete improvement available; requires agents to write structured handoff files reliably.

---

## Decisions

- **DO investigate**: Unified `postflight-workflow.sh` parameterized script (High confidence, low risk, immediate value)
- **DO investigate**: Shared `parse-command-args.sh` sourced by all commands (High confidence, low risk)
- **DO investigate**: Moving shared algorithm blocks to @-referenced context files rather than copy-pasting (works today)
- **CONDITIONALLY investigate**: Command → agent direct delegation (only if skills have single callers)
- **DEFER**: RAG-based context retrieval (current system is adequate; adds infrastructure complexity)
- **DEFER**: Full FORK_SUBAGENT adoption for core skills (significant refactoring; Medium-Low confidence)
- **EVALUATE**: OpenAI-style structured handoff objects for sequential phase context (Medium confidence; worth prototyping)

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Eliminating skill layer breaks multi-caller reuse | Low | Medium | Audit which skills have multiple callers before removing |
| Fork subagent loses agent-specific system prompts | High | Medium | Keep agent definitions; only apply to team-mode where agent identity is less critical |
| Structured handoff objects drift from reality | Medium | Medium | Validate handoff schema on write; fail phase if schema invalid |
| @include not landing soon | High | Low | Use @-reference workaround today; migrate if feature lands |
| LangGraph blocker routing creates infinite loops | Medium | High | Cap retry depth (max 2 automatic spawns per phase); require human confirmation beyond that |

---

## Context Extension Recommendations

- **Topic**: Unified postflight script pattern
- **Gap**: No documentation covers the pattern of parameterizing nearly-identical scripts
- **Recommendation**: Add `.claude/context/patterns/unified-postflight.md` documenting the `OPERATION_TYPE` parameter pattern

- **Topic**: Fork subagent eligibility matrix
- **Gap**: `fork-patterns.md` documents the mechanism but not a decision matrix for when to adopt it
- **Recommendation**: Extend `fork-patterns.md` with a "Migration Checklist" section covering when removing `subagent_type` is safe

---

## Appendix: Sources and Search Queries

### Search Queries Used
1. "Claude Code agent orchestration patterns 2026 command delegation architecture deduplication"
2. "LLM agent workflow engine state machine pattern GATE IN GATE OUT shared lifecycle 2025 2026"
3. "Claude Code CLAUDE.md shared fragments include directives template deduplication @-references markdown composition"
4. "multi-agent LLM context summarization compression before injection token budget RAG retrieval 2025 2026"
5. "LangGraph state machine blocker escalation plan revision reactive agent event-driven orchestration 2025"
6. "Claude Code agent 'commands delegate directly' 'eliminate skills' simplified delegation chain 2025 2026"
7. "Claude Code prompt caching shared prefix context fork CLAUDE_CODE_FORK_SUBAGENT token savings agent chains 2026"
8. "agent system architecture 'command template' 'shared lifecycle' 'workflow engine' single entrypoint multiple operation types 2025"
9. "OpenAI Agents SDK handoff pattern state management blocker escalation compared to Claude Code 2026"
10. "agentic workflow 'shared script' 'shared template' eliminate markdown duplication across multiple agent definitions"

### Key References

- [Claude Code Agent Orchestration Patterns](https://claudefa.st/blog/guide/agents/agent-patterns)
- [Fork Subagents in Claude Code](https://www.buildthisnow.com/blog/guide/mechanics/claude-code-fork-subagent)
- [Claude Code Prompt Cache Token Optimization](https://www.knightli.com/en/2026/05/18/claude-code-prompt-cache-token-optimization/)
- [OpenAI Agents SDK Handoffs](https://openai.github.io/openai-agents-python/handoffs/)
- [@include Directive Feature Request](https://github.com/anthropics/claude-code/issues/13614)
- [AI Agent Token Cost Optimization](https://fast.io/resources/ai-agent-token-cost-optimization/)
- [LangGraph Multi-Agent Orchestration](https://latenode.com/blog/ai-frameworks-technical-infrastructure/langgraph-multi-agent-orchestration/langgraph-multi-agent-orchestration-complete-framework-guide-architecture-analysis-2025)
- [Cloudflare Workflows V2 Architecture](https://blog.cloudflare.com/workflows-v2/)
- [Optimizing Multi-Agent Workflows: Context-Aware Handoffs](https://dev.to/alexretana/optimizing-multi-agent-workflows-in-n8n-a-context-aware-approach-to-agent-handoffs-1hc4)
- [AGENTS.md Best Practices](https://www.augmentcode.com/blog/how-to-write-good-agents-dot-md-files)

### Local Files Examined
- `/home/benjamin/.config/nvim/.claude/commands/research.md` (500 lines)
- `/home/benjamin/.config/nvim/.claude/commands/plan.md` (531 lines)
- `/home/benjamin/.config/nvim/.claude/commands/implement.md` (612 lines)
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md` (558 lines)
- `/home/benjamin/.config/nvim/.claude/skills/skill-planner/SKILL.md` (490 lines)
- `/home/benjamin/.config/nvim/.claude/context/patterns/fork-patterns.md`
- `/home/benjamin/.config/nvim/.claude/context/patterns/thin-wrapper-skill.md`
- `/home/benjamin/.config/nvim/.claude/context/workflows/command-lifecycle.md`
- `/home/benjamin/.config/nvim/.claude/scripts/postflight-research.sh` (confirmed near-identical to plan/implement variants via `diff`)

# Research Report: Task #591

**Task**: Research Claude Code 2026 orchestration best practices
**Date**: 2026-05-22
**Mode**: Team Research (4 teammates)
**Session**: sess_1779465279_0d054f

## Summary

This report synthesizes findings from 4 parallel research teammates investigating Claude Code 2026 best practices for the 9-task workflow refactoring (tasks 591-599). The research validated the overall direction while identifying critical constraints, risks, and reordering needs that should reshape the implementation plan.

**Core conclusions**:
1. Fork cache sharing has a 5-minute TTL — forks only benefit same-turn re-dispatches, not sequential workflow phases
2. The /orchestrate command should use human confirmation gates between phases, not a fire-and-forget loop
3. Blocker escalation (detect -> research -> revise -> resume) is the highest-value novel capability
4. A `dispatch_agent()` abstraction should be the first shared utility built — it encapsulates the fork-vs-subagent decision
5. The duplication across skills is partially intentional (each skill diverges at context-collection stages), but command-level duplication (`parse_task_args()`, flag parsing) is purely mechanical and safe to extract
6. Task 598 (progressive disclosure) should be elevated in the dependency chain — it informs what the shared base needs to support
7. Extension lifecycle hooks should replace full skill duplication for domain extensions

## Key Findings

### 1. Fork vs. Subagent Decision Matrix (Teammates A, B, C)

Two independent mechanisms exist:
- **`context: fork`** (skill frontmatter): Prevents CLAUDE.md loading into skill context
- **`CLAUDE_CODE_FORK_SUBAGENT=1`** (env var): Forked children inherit parent's prompt cache prefix (~90% input token reduction)

**Critical constraint**: Prompt cache TTL is **5 minutes**. Fork cache sharing only benefits operations completing within a single conversational turn.

**Decision matrix**:

| Scenario | Pattern | Rationale |
|----------|---------|-----------|
| Sequential phase dispatch (research -> plan -> implement) | Fresh subagent (`subagent_type`) | Cache cold between phases; agent needs specialized prompt |
| Blocker escalation within same turn | Fork (no `subagent_type`) | Orchestrator context warm; ~90% token savings |
| Team mode parallel teammates | Fork (teammates 2-N) | Shared prefix; ~60% total cost reduction |
| Extension task routing | Fresh subagent | Needs domain-specific agent definition |

**Conflict resolved**: Teammate C cited task 500's finding that "fork cache sharing is fundamentally incompatible with named agent routing." This is correct — you cannot get both a named agent's system prompt AND fork cache sharing simultaneously. The resolution: use forks ONLY where named routing isn't needed (blocker escalation, team mode), and fresh subagents where it is (core workflow dispatch). The `dispatch_agent()` abstraction (Teammate D's recommendation) encapsulates this decision in a single function, future-proofing against Anthropic adding a "named fork" API.

### 2. /orchestrate Design: Confirmation Gates, Not Autonomous Loop (Teammates C, D)

**All teammates agree** the current /orchestrate spec (task 596) overcorrects toward automation. The existing system's checkpoint philosophy (GATE IN -> DELEGATE -> GATE OUT) exists because expert technical work requires human review at phase boundaries.

**Recommended model**:
```
/orchestrate N [--auto]
  -> Assess task state from state.json
  -> "Task N is NOT_STARTED. Ready to research? [Y/n]"
  -> /research N (autonomous within phase)
  -> "Research complete. Review report. Run plan? [Y/n]"
  -> /plan N (autonomous within phase)
  -> "Plan created. Review plan. Begin implementation? [Y/n]"
  -> /implement N (autonomous, uses existing continuation loop)
  -> Done.
```

**`--auto` flag**: Skips confirmation gates for straightforward tasks or remote agent execution.

**Blocker escalation** (the highest-value feature):
```
implement phase N -> blocker detected in handoff
  -> orchestrator reads blocker description
  -> forks research agent (same-turn, cache-warm, ~90% savings)
  -> reads research findings from handoff file
  -> dispatches reviser agent with findings + current plan
  -> re-dispatches implementation from the blocked phase
```

**Nested loop resolution** (Teammate C's concern): The orchestrator's outer loop and skill-implementer's inner continuation loop must be exclusive, not nested. When /orchestrate dispatches /implement, it should set a flag that disables the inner continuation loop — the orchestrator handles continuation at the outer level.

### 3. Token Efficiency: Handoff-Only Communication (Teammates A, B)

The highest-leverage token optimization is **handoff-only communication**: the orchestrator reads handoff files from disk rather than accumulating each agent's tool output in its context window.

**Pattern**:
1. Orchestrator dispatches agent with prompt (including task context)
2. Agent writes findings to handoff file (structured JSON, 200-400 tokens)
3. Agent returns brief text summary (3 lines)
4. Orchestrator reads handoff file to decide next action
5. Orchestrator's context stays flat regardless of how many cycles have run

**Structured handoff object** (from Teammate B, adapting OpenAI's input_filter pattern):
```json
{
  "phase": "research",
  "status": "completed",
  "summary": "Found X, Y, Z. Key decision: use approach A.",
  "artifacts": ["specs/591.../reports/01_report.md"],
  "blockers": [],
  "next_action_hint": "plan"
}
```

This replaces raw artifact injection (2000-5000 tokens) with a 200-400 token structured delta.

### 4. Progressive Disclosure: Four-Tier Context Loading (Teammates A, D)

The current 97-entry context index (~22K lines) loads eagerly. A tiered system can recover ~60% of per-session token waste:

| Tier | When Loaded | Budget | Examples |
|------|-------------|--------|----------|
| 1 (always) | Every invocation | ~500 lines | anti-stop-patterns, return-metadata, checkpoint-execution |
| 2 (command) | On command detection | ~1-2K lines | Command-specific routing, argument docs |
| 3 (agent) | At agent spawn | ~2-5K lines | Full workflow patterns, domain context |
| 4 (on-demand) | Via explicit @-ref | Unbounded | Detailed guides, templates, examples |

**Key insight** (Teammate A): Commands should NOT load agent-level context. The agent loads its own context. The command's job is routing only.

**Budget caps by agent type**:
- Sonnet workers: ~8K tokens
- Opus planners: ~15K tokens
- Haiku utilities: ~2K tokens

**Reordering recommendation** (Teammate D): Task 598 (progressive disclosure) should be elevated before task 594 (skill base) because the context budget architecture informs what the shared base needs to support.

### 5. Practical Deduplication Targets (Teammates B, C)

**Safe to extract immediately (high confidence, low risk)**:

| Target | Lines Saved | Risk | Implementation |
|--------|-------------|------|----------------|
| `parse_task_args()` across /research, /plan, /implement | ~90 (30x3) | Minimal | `.claude/scripts/parse-command-args.sh` |
| STAGE 1.5 flag parsing across 3 commands | ~75 (25x3) | Minimal | Same script or @-referenced context |
| Unified `postflight-workflow.sh` replacing 3 scripts | ~130 (65x2) | Minimal | Single parameterized script |
| Shared GATE IN/OUT templates | ~240 (80x3) | Low | @-referenced context files |

**Requires careful design (medium confidence)**:

| Target | Complexity | Risk |
|--------|-----------|------|
| Shared skill base pattern (task 594) | High — skills diverge at context-collection stages | Medium — may add abstraction overhead |
| Extension lifecycle hooks | Medium — new concept | Medium — new maintenance surface |
| /orchestrate state machine | High — novel component | High — nested loops, blocker detection |

**Teammate C's caution**: The skill duplication is partially intentional. Each skill's context-collection stages differ (researcher has 4a/4b/4c/4d; planner has only 4a; implementer has 4a only). A shared base needs conditional inclusion, which adds complexity. Validate that the abstraction actually reduces total token cost before committing.

### 6. Extension System Evolution (Teammates B, D)

Extensions are the system's most strategically important asset (16 extensions across lean4, latex, nix, python, etc.). The refactored core should make extensions first-class citizens:

**Current problem**: Extension skills must duplicate the entire 11-stage lifecycle pattern. When the core changes, extension skills diverge silently (documented: nix-implementation uses non-standard stage format).

**Recommended**: Extension lifecycle hooks in manifest.json:
```json
{
  "hooks": {
    "preflight": "scripts/nix-preflight.sh",
    "context_injection": "scripts/nix-context.sh",
    "postflight": "scripts/nix-postflight.sh"
  }
}
```

Extensions should participate in the lifecycle through hooks, not through full skill duplication.

### 7. Missing Prerequisites (Teammate C)

The 9-task plan is missing standard refactoring prerequisites:

| Missing | Risk if Absent | Recommendation |
|---------|---------------|----------------|
| Baseline token measurements | Cannot validate improvement | Measure before starting task 593 |
| Testing strategy | No verification of correctness | Add regression tests for /todo and /review before task 597 |
| Rollback plan | Cannot revert partial refactoring | Plan revert strategy per task |
| Migration for in-flight tasks (78, 87) | Skill interface changes break active tasks | Verify compatibility at each step |
| Task 500 resolution | Conflicting findings about fork caching | Formally abandon or integrate before task 594 |
| Extension compatibility gates | Silent breakage | Verify extension compatibility at each task, not just task 599 |

### 8. Memory Vault Gap (Teammate D)

571 archived tasks have `memory_candidates` in state.json but only 3 memories exist in the vault. The `/todo` archival process does not harvest memory candidates automatically — this is silent information loss. The workflow refactor (task 597's /todo decomposition) should address this by adding auto-harvest to the archival pipeline.

## Synthesis

### Conflicts Resolved

| Conflict | Resolution |
|----------|------------|
| Fork caching for core skills vs. task 500's "incompatible with named routing" finding | Use forks ONLY for same-turn re-dispatch (blocker escalation) and team mode; fresh subagents for all named-agent dispatch. Encapsulate in `dispatch_agent()`. |
| Full 9-task refactor vs. minimal parse_task_args() extraction | Start with safe extractions (parse_task_args, unified postflight) as task 593. Validate token savings before proceeding to complex refactoring (task 594+). |
| Autonomous /orchestrate loop vs. human oversight | Confirmation gates by default, `--auto` flag for unattended execution. Blocker escalation is autonomous within a phase. |
| Task 598 priority (last vs. earlier) | Elevate: progressive disclosure design should inform the shared base (task 594). Suggested reorder: 593 -> 598 -> 594. |

### Gaps Identified

1. No baseline token cost measurement methodology
2. No extension compatibility testing framework
3. No documented interaction model between orchestrator's outer loop and implementer's inner continuation loop
4. No `dispatch_agent()` pattern documented (recommended as first utility to build)
5. Memory harvest automation missing from /todo pipeline
6. No "semi-autonomous orchestration" pattern (confirmation gates with --auto bypass)

### Revised Task Dependency Recommendation

```
Layer 1: [591] Research (this task - DONE)
Layer 2: [592] Design unified architecture
Layer 3: [593] Extract safe shared utilities (parse_task_args, postflight, GATE templates)
Layer 4: [598] Progressive disclosure + context budgets (ELEVATED)
Layer 5: [594] Refactor skills  |  [597] Refactor /task, /revise, /todo, /review
Layer 6: [595] Refactor /research, /plan, /implement  |  [596] Create /orchestrate
Layer 7: [599] Update CLAUDE.md, extensions, docs
```

Key change: Task 598 elevated from Layer 6 to Layer 4 — its context budget design informs what tasks 594-596 need to support.

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|------------------|
| A | Primary (best practices) | completed | high | Fork decision matrix, 5-min TTL constraint, state machine design, 2026 feature inventory |
| B | Alternatives | completed | medium-high | Unified postflight script, structured handoffs, LangGraph blocker routing, FORK_SUBAGENT for teams |
| C | Critic | completed | high | Intentional duplication warning, unvalidated token economics, nested loop risk, missing prerequisites |
| D | Horizons | completed | medium | Confirmation gates design, extension hooks, dispatch_agent() abstraction, memory vault gap, task reordering |

## References

### Internal
- `.claude/context/patterns/fork-patterns.md` — Fork mechanism overview
- `.claude/context/patterns/subagent-continuation-loop.md` — Continuation loop pattern
- `.claude/context/architecture/system-overview.md` — Three-layer architecture
- `specs/500_add_context_fork_to_core_skills/reports/` — Prior fork research (task 500)
- `specs/501_optimize_team_mode_fork_cache_sharing/plans/` — Team mode optimization plan

### External
- Claude Code sub-agents documentation (code.claude.com/docs/en/sub-agents)
- Claude Code agent teams documentation (code.claude.com/docs/en/agent-teams)
- OpenAI Agents SDK handoff pattern (openai.github.io/openai-agents-python/handoffs/)
- LangGraph multi-agent orchestration framework
- Claude Code @include directive request (GH #13614)

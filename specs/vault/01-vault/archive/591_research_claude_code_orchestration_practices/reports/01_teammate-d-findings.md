# Research Report: Task #591 — Teammate D (Horizons)

**Task**: 591 - Research Claude Code 2026 Best Practices for Orchestration and Refactoring
**Role**: Teammate D — Long-term alignment and strategic direction
**Started**: 2026-05-22
**Completed**: 2026-05-22
**Effort**: Deep strategic analysis
**Dependencies**: Tasks 500, 501 research artifacts; system architecture files
**Sources/Inputs**:
- Full codebase audit (.claude/ system, ~240K lines total)
- specs/state.json (15 active tasks, 571 archived tasks history)
- specs/CHANGE_LOG.md (system evolution record)
- System architecture: system-overview.md, context/architecture/
- Prior research: task 500 reports (fork cache sharing), task 501 (team mode)
- Archive research: OC_139 (progressive disclosure POC), OC_140 (context loading docs)
- Current skill implementations: skill-researcher, skill-implementer, skill-planner (3 core workflow skills)
- Current command implementations: /research (500L), /implement (612L), /plan (531L), /todo (1046L), /review (1039L)

---

## Executive Summary

- **The /orchestrate command is the right long-term goal, but the design spec overcorrects** toward full automation where staged human oversight would produce better outcomes and is consistent with the existing system's checkpointed philosophy
- **The 9-task refactor plan is architecturally sound but risks solving the wrong problem first** — the duplication problem is real (~80% structural overlap across skills) but the deeper issue is that the three-layer command-skill-agent architecture has become a liability as the system scales beyond ~100 tasks
- **The extension system has quietly become the system's most important strategic asset** — 16 extensions covering lean4, latex, python, nix, web, epidemiology, formal methods, and more represent genuine competitive differentiation; the refactor should make extensions first-class citizens, not an afterthought
- **Token-efficient context loading is underpursued relative to structural deduplication** — progressive disclosure research (OC_139, OC_140) showed 40-50% context reduction is achievable; this should be task 598's priority, not task 9 of 9
- **At 600 tasks, vault/archive design has become a performance bottleneck** — state.json with 15 active tasks but state management code designed for ~100 is not a crisis yet, but the refactor window is the right time to address it

---

## Finding 1: Does /orchestrate Align with the Long-Term Vision?

**Confidence**: Medium

### Recommended Approach

The /orchestrate command is the right idea, but the current spec describes a **fire-and-forget loop** that does not match how complex technical work actually proceeds. The existing system's checkpoint-based philosophy (`GATE IN -> DELEGATE -> GATE OUT -> COMMIT`) was designed precisely to give the human visibility and control at meaningful boundaries. /orchestrate should respect this.

**The right model**: /orchestrate should be a **state-machine driver with human confirmation gates**, not an autonomous loop:

```
/orchestrate N
  -> Assess task state
  -> "Task 591 is NOT_STARTED. Ready to research? [Y/n]"
  -> /research 591 (autonomous)
  -> "Research complete. Review: specs/591.../reports/01_report.md. Run plan? [Y/n]"
  -> /plan 591 (autonomous)
  -> "Plan created. Review: specs/591.../plans/01_plan.md. Begin implementation? [Y/n]"
  -> /implement 591 (autonomous)
  -> Done.
```

This is not timidity — it is alignment with how agentic work *should* flow. The human provides the overall direction (which task, what constraints), the system provides execution, and confirmation gates at phase boundaries prevent cascading errors. Research that goes off-track should be caught before a plan is built on it.

### What the Current Spec Gets Wrong

The spec says: "Loop until task reaches completed or user interrupts." This inverts the responsibility model. Interruption should not be the primary control mechanism — confirmation should be.

The spec is motivated by reducing friction for "straightforward tasks" but the system serves expert technical domains (lean4 formal proofs, NixOS configuration, epidemiology study design). A task that looks straightforward frequently isn't. The research phase is where the system discovers this; if the orchestrator skips human review of the research, it is likely to build a plan on flawed premises.

### What the Current Spec Gets Right

- The handoff artifact protocol is correct: each sub-operation writes a file the orchestrator reads, avoiding accumulation of tool output in the orchestrator's context. This is critical for managing the orchestrator's context window across a full research-plan-implement cycle.
- Blocker escalation: implementation agents flag blockers in handoff -> orchestrator dispatches research fork -> reviser updates plan -> re-dispatch implementation. This is the most valuable capability in the spec and should be prioritized.
- The `fork for cache-sharing when context is warm` heuristic is correct. After /research completes and the orchestrator is deciding whether to /plan, the parent context already has the task description and task state cached. A fork here would inherit that context efficiently.

### Evidence

The system's existing continuation loop in skill-implementer (Stages 5c, 6, 7) already implements single-phase autonomous cycling within implementation. This is the proven pattern to extend, not re-invent. The orchestrator should be the same loop elevated one level: phases become full workflow stages (research, plan, implement).

---

## Finding 2: Extension System Evolution

**Confidence**: High

### Current State Assessment

The extension system is the most architecturally important part of this codebase. 16 extensions cover:
- Scientific domains: lean4, formal methods, epidemiology, z3
- Document formats: latex, typst, present (slidev)
- Development: python, web, nix
- Specialized: filetypes, founder, memory

Each extension provides task-type-based routing into specialized research and implementation agents. This is genuine differentiation — no other Claude Code configuration in the wild provides this kind of multi-domain orchestration.

**Current architectural status**: Extensions are loaded via a manifest-driven picker but are treated as second-class citizens by the core:
- Extension routing is bolted onto commands via manifest.json lookups, not native to the command structure
- The core skill's 11-stage postflight runs identically for extension tasks as for core tasks — extensions cannot customize the lifecycle
- Extension skills must duplicate the entire 11-stage pattern from scratch (nix-implementation has 378 lines but deviates from the standard at Stage 4-8)

### Recommended Approach

The unified workflow engine from tasks 593-594 should be designed with **extension hooks** at each lifecycle stage, not just at routing dispatch:

```yaml
# Hypothetical extension hook definition in manifest.json
hooks:
  preflight: "scripts/nix-preflight.sh"      # e.g., check flake syntax before starting
  context_injection: "scripts/nix-context.sh" # custom context beyond standard memory/roadmap
  postflight: "scripts/nix-postflight.sh"    # e.g., run nix flake check after implementation
```

This would allow extensions to participate in the lifecycle rather than just override the agent. The core would provide the scaffolding; extensions inject behavior.

**What extensions should provide in the refactored system**:
1. **Routing**: Which skill handles research vs implementation (already done)
2. **Context hooks**: Domain-specific context injection at agent invocation (currently hardcoded per extension)
3. **Lifecycle hooks**: Pre/postflight operations (currently not possible without full duplication)
4. **Orchestration strategy overrides**: Some domains should use different cycling behavior — a lean4 proof task might want: research -> plan -> partial implement -> verify -> resume cycle; a latex document might want: research -> plan -> implement (no intermediate human gates)

### Evidence

The nix extension's `skill-nix-implementation` is a documented example of extension drift: it uses numbered stages (4-8) instead of the named Stage N pattern and combines status update + artifact linking in a non-standard inline jq block. When the core changes, the extension breaks silently. Extension lifecycle hooks would eliminate this by making the shared machinery explicit.

---

## Finding 3: Claude Code Platform Trajectory

**Confidence**: Medium-Low (predictions)

### What's Coming

Based on publicly available information and the capabilities already present in this codebase's settings (SubagentStop hook, remote agent support implied by `/schedule` and `/merge` commands, TaskCreate/TaskUpdate in permissions):

**1. Remote agents and scheduled execution** are already partially present via the `/schedule` skill in the shared `~/.config/.claude/` system. The architecture should anticipate that a task may be executed by a remote agent without a human in the terminal. This means:
- The human confirmation gates in /orchestrate should be skippable with a `--auto` flag
- Lifecycle notifications (the WezTerm/TTS system) should have non-terminal fallbacks
- Artifacts should be self-describing enough that an agent can pick up where another left off

**2. Persistent memory is already implemented** in this system (the `.memory/` vault with MCP-backed retrieval). The architecture is ahead of the platform on this. The refactor should not regress memory integration — specifically, the `--clean` flag suppression of memory retrieval should remain available but not be the default path.

**3. Larger context windows** reduce the pressure for progressive disclosure but do not eliminate it. Even with 1M+ context, loading 240K lines of `.claude/` at each invocation is wasteful. The right answer is tiered loading regardless of context size — it is about semantic relevance, not just token budget.

**4. The "named fork" API gap** identified in task 500's research remains the most consequential missing platform feature for this system. If Anthropic provides a mechanism that combines agent routing (specialized system prompt) with fork cache sharing (shared prefix), the architecture decision about fork vs subagent becomes trivial. The refactored system should be designed so this change requires updating a single routing decision point, not refactoring each skill.

### Recommended Approach

Design the unified workflow engine so that the "fork vs named subagent" decision is encapsulated in a single function:

```bash
# In shared-workflow-utils.sh
dispatch_agent() {
  local agent_type="$1"
  local prompt="$2"
  local context="$3"

  # Decision: use fork when FORK_SUBAGENT is available AND context is warm
  # Otherwise use named subagent for model override capability
  if [ "$CLAUDE_CODE_FORK_SUBAGENT" = "1" ] && context_is_warm "$agent_type"; then
    invoke_fork "$prompt" "$context"
  else
    invoke_named_subagent "$agent_type" "$prompt" "$context"
  fi
}
```

This makes the fork/named-subagent decision configurable and future-proof without requiring refactoring each skill when the platform changes.

---

## Finding 4: Scaling Considerations

**Confidence**: High

### The Current State

The system is at task 600, with 571 tasks archived and 15 active. The archive contains task directories from task 1 through ~590 across multiple vault cycles. state.json has 15 active projects but is loaded in its entirety on every skill invocation via jq queries — this is currently fast (~12ms as documented in state-management.md) but the jq queries scan the full `active_projects` array on every operation.

The real scaling concern is not state.json (15 active entries is trivially small) but the **artifact accumulation** in `specs/`:
- 571+ archived task directories
- Each with reports/, plans/, summaries/ subdirectories
- The archive itself is a flat directory at `specs/archive/` with 571+ entries

**At what point does task management overhead exceed value?** The tipping point is not a number of tasks but a relationship between:
1. The cost of navigating the system (finding relevant prior work, loading context)
2. The benefit of accumulated knowledge (memory vault, prior research that prevents re-doing work)

Currently the memory vault has only 3 memories (per state.json health metrics). This is dramatically underutilized relative to 571 completed tasks. The system accumulates metadata in state.json (memory_candidates arrays) but does not harvest them automatically — each completed task leaves memory candidates sitting in state.json rather than being committed to the vault.

### Recommended Approach

**Alongside the workflow refactor**, address the memory lifecycle gap:
- The `/todo` command should automatically harvest memory candidates from tasks being archived
- The memory health score should be a first-class metric in the daily workflow, not a separate `/distill` concern
- The context index should surface "related prior work" at task creation time, not just at research time

**Vault design alongside workflow refactoring** (task 597's scope):
- The vault operation (renumber at >1000) is a maintenance event but not a scaling solution
- Consider whether `specs/archive/` should be indexed in the same context system as `.memory/` — archived research reports are searchable knowledge assets, not just history
- The `/todo` archival process could write brief summaries to a lightweight `specs/archive/INDEX.json` that enables fast lookup without reading individual artifact files

---

## Finding 5: Creative Alternatives

**Confidence**: Low-Medium (deliberately unconventional)

### Alternative A: Collapse the Triple to a Pair

The current architecture is command -> skill -> agent (three layers). The system-overview.md justifies this as separation of concerns:
- Commands: routing only
- Skills: validation + lifecycle
- Agents: domain execution

But task 500's research showed that the skill and agent layers could be collapsed into a single `context: fork` skill (Alternative A in that research). The reason it was rejected was: "loses model override capability." 

In 2026, with multi-model APIs increasingly commoditized, is model override per-agent still the right granularity? If the answer is "use Sonnet for workers and Opus for planners," that is a two-category decision, not a per-agent decision. The proposed refactor (tasks 593-594) already moves toward this by standardizing the 11-stage skeleton across all skills.

**Radical alternative**: Replace the skill+agent pair with a single `context: fork` "workflow unit" that contains both orchestration logic and domain knowledge. Each workflow unit is a self-contained SKILL.md file. The command routes to a workflow unit; the workflow unit runs as a fork with full orchestration inside. Model override is handled by a two-entry lookup (planner=opus, worker=sonnet).

**Why this might be better**: Eliminates one indirection layer. Reduces the "impedance mismatch" between skill orchestration instructions and agent execution instructions (currently written in two different files, must stay in sync, can diverge). Makes the system easier to reason about.

**Why this might be worse**: Context: fork makes the skill body the agent's task prompt, not system prompt. Complex multi-stage instructions in a task prompt are less reliable than in a system prompt. This is a real risk.

### Alternative B: Dynamic Context Retrieval Instead of Static Index

The current context system has 139 index entries in a static JSON file that maps context files to load_when conditions. Agents query this index at invocation time using the adaptive query pattern.

**Alternative**: Replace the static index with dynamic semantic retrieval, using the same MCP-backed memory system already in place. Instead of:
```bash
jq '.entries[] | select(.load_when.agents[] == "planner-agent")' .claude/context/index.json
```
Use:
```bash
memory-retrieve.sh "planning implementation workflow structured phases" "meta"
```

The memory vault would contain summaries of context files rather than (or in addition to) the files themselves. The MCP search would return the 3-5 most relevant context files for the current operation, not all files tagged for the current agent type.

**Why this might be better**: Eliminates the index maintenance burden (139 entries, each manually tagged). Adapts to what is actually relevant rather than what was tagged. Enables context files to be found based on semantic content, not explicit tagging.

**Why this might be worse**: Introduces retrieval latency and non-determinism. The static index is fast and predictable. For orchestration infrastructure, predictability matters more than semantic flexibility.

**The right hybrid**: Use the static index for structural context (formats, rules, patterns) that must always be present, and dynamic retrieval for domain knowledge (extension-specific guides, tool references) that is genuinely optional.

### Alternative C: The "Workflow Definition" Model

What if instead of command + skill + agent, the system used a single "workflow definition" file format that declaratively specifies the full lifecycle?

```yaml
# workflow-research.yaml
name: research
trigger: /research N [focus]
phases:
  - name: preflight
    type: bash
    script: "scripts/preflight.sh research $TASK_NUM $SESSION_ID"
  - name: execute
    type: agent
    agent: general-research-agent
    context:
      inject: [memory, roadmap, format]
      budget: 8000  # tokens
  - name: postflight
    type: bash
    script: "scripts/postflight.sh research $TASK_NUM $ARTIFACT_PATH $SESSION_ID"
extensions:
  lean4:
    execute.agent: lean-research-agent
    postflight.script: "extensions/lean/scripts/lean-postflight.sh"
```

This would make the workflow structure machine-readable and allow:
- Validation of workflows without executing them
- Cross-workflow consistency enforcement
- Extension overrides at the phase level rather than full duplication
- Automated generation of CLAUDE.md documentation from workflow definitions

**Why this matters long-term**: As the system grows to 20+ extensions and dozens of workflow types, having the lifecycle encoded in markdown prose (current state) becomes unmanageable. Declarative definitions would allow tooling to verify, validate, and generate the system.

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| /orchestrate automation causes cascading errors (bad research -> bad plan -> bad impl) | High | Human confirmation gates at each phase transition |
| Extension hooks create a new maintenance surface that diverges from core | Medium | Extension hooks should be declarative (manifest.json), not imperative bash scripts |
| "Named fork" gap remains; cache sharing benefits are limited to team mode | Low | Accept this constraint; design dispatch_agent() to switch transparently when gap closes |
| Progressive disclosure (task 598) arrives too late in the dependency chain | Medium | Elevate task 598 in priority; context budget design should inform tasks 593-594 |
| Memory vault remains underutilized even after the refactor | High | /todo auto-harvest memory candidates; make vault health a first-class metric |
| Radical alternative (collapse to pair) is adopted and then fails | Low | The current reports recommend against it; document and park, not adopt |

---

## Priority Recommendations for the 9-Task Refactor

Ordered by strategic impact, not dependency order:

1. **Task 598 (progressive disclosure)** should be moved earlier in the plan — it directly affects what the shared workflow utilities (task 593) need to support. Designing the shared base (task 594) before knowing the context budget architecture will likely require rework.

2. **Task 596 (/orchestrate)**: The blocker escalation loop is the highest-value feature; the fire-and-forget loop is a risk. Prioritize blocker detection + escalation over fully autonomous cycling.

3. **Task 593 (shared utilities)**: The `dispatch_agent()` abstraction that encapsulates fork-vs-named-subagent should be the first utility implemented. Everything else flows from it.

4. **Tasks 591-595 (foundation)**: Correct dependency order. No strategic concerns.

5. **Task 599 (documentation)**: CLAUDE.md is auto-generated from extension manifests. The documentation update should include converting the skill+command inventory to a form that can be validated by tooling (roadmap item for manifest-driven README generation is relevant here).

---

## Context Extension Recommendations

- **Topic**: Extension lifecycle hook specification
- **Gap**: No documentation exists for how extensions can participate in preflight/postflight lifecycle events; this is currently achieved only through full skill duplication
- **Recommendation**: Create `.claude/context/guides/extension-lifecycle-hooks.md` documenting the proposed hook interface

- **Topic**: /orchestrate human oversight model
- **Gap**: No patterns exist for "semi-autonomous" commands that run multi-phase workflows with user confirmation gates
- **Recommendation**: Create `.claude/context/patterns/semi-autonomous-orchestration.md` as part of task 596

- **Topic**: Memory harvest automation
- **Gap**: 571 archived tasks with memory_candidates in state.json; /todo does not harvest these automatically
- **Recommendation**: This is a known gap (state.json health shows 3 memories from 571 tasks); address in task 597's /todo decomposition

---

## Appendix: Key Metrics for Context

| Metric | Value | Source |
|--------|-------|--------|
| Total .claude/ system lines | ~240K | `find .claude -name "*.md" | xargs wc -l` |
| Active tasks | 15 | state.json |
| Archived tasks | 571 | specs/archive/ count |
| Core skill lines (researcher/implementer/planner) | 558 / 629 / 490 | wc -l |
| Core command lines (research/implement/plan) | 500 / 612 / 531 | wc -l |
| Context index entries | 139 | jq '.entries | length' context/index.json |
| Extensions loaded | 2 (nvim, nix) | CLAUDE.md |
| Extensions available | 16 | extensions/ directory count |
| Memory vault entries | 3 | state.json memory_health |
| Memory vault health score | 100 | state.json (artificially high due to near-empty vault) |
| Shared stages across skills (identical) | 8 of ~11 | Stage comparison: 1,2,3,3a,4a,4,4b,5,5b,6,6a,7,8,9,10 |

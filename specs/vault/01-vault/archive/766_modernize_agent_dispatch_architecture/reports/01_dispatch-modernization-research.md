# Research Report: Task #766

**Task**: 766 - Modernize agent dispatch architecture for current Claude Code capabilities
**Started**: 2026-06-23T00:00:00Z
**Completed**: 2026-06-23T00:30:00Z
**Effort**: ~1.5 hours
**Dependencies**: Tasks 764, 765 (immediate bugs fixed; this evaluates architectural direction)
**Sources/Inputs**: Codebase (dispatch-agent.sh, skill-orchestrate/SKILL.md, architecture docs, fork-patterns.md)
**Artifacts**: This report
**Standards**: report-format.md

---

## Executive Summary

- **dispatch-agent.sh is a pseudocode interpreter, not a real dispatcher**: The script generates JSON that SKILL.md instructions read and then the Claude Code instance itself makes the actual Agent tool calls. The indirection adds no runtime value and obscures the actual dispatch logic from the skill narrative.
- **The Workflow tool does not exist in this Claude Code instance**: The task description references `pipeline()/parallel()/agent()` primitives, but no Workflow tool appears in the available tool list. MT mode should NOT be redesigned around a tool that is not confirmed available.
- **MT mode complexity is justified but the implementation is fragile**: The 400+ lines of MT pseudocode correctly models the lifecycle-cycling pattern, but the bash pseudocode convention creates a reliability risk — the SKILL.md model must interpret what the bash pseudocode says instead of executing it, and mistakes are silent (as task 765 demonstrated). Direct Agent tool call instructions in the SKILL.md prose would be more reliable.
- **Fork usage is appropriately targeted**: The current fork pattern (blocker research + drift inspection) is correct. Broad fork expansion would reduce agent specialization quality without significant token savings because the orchestrator context is already large.

**Recommended approach**:
1. Remove dispatch-agent.sh as a runtime dependency; inline the dispatch logic directly as prose instructions in SKILL.md
2. Keep MT mode structure but convert bash pseudocode loops to numbered prose steps with explicit Agent tool call tables
3. Do not redesign around the Workflow tool until it is confirmed available and stable

---

## Context & Scope

This report evaluates three architectural questions for the `/orchestrate` state machine:

1. Whether `dispatch-agent.sh` should be simplified or replaced
2. Whether MT mode should use the Workflow tool instead of bash pseudocode
3. Whether fork dispatch should be used more broadly

The immediate bugs (MT wave cycling, jq status string bug) were fixed in tasks 764 and 765. This task evaluates whether the underlying architecture should change.

---

## Findings

### 1. Codebase Analysis: dispatch-agent.sh

**File**: `.claude/scripts/dispatch-agent.sh` (128 lines)
**File**: `.claude/docs/architecture/dispatch-agent-spec.md` (233 lines)

The script provides three functions: `dispatch_agent()`, `invoke_named_agent()`, `invoke_agent_fork()`. Each function uses `jq -n` to emit a JSON object describing dispatch intent. Here is the key output from `invoke_named_agent`:

```json
{
  "dispatch_mode": "named_subagent",
  "subagent_type": "general-research-agent",
  "prompt": "...",
  "context": {...},
  "cache_warm": false
}
```

**Critical observation**: This JSON is not processed by any code. The `SKILL.md` instructions say "Invoke the Agent tool per dispatch_instructions (subagent_type: $RESEARCH_AGENT)." The Claude Code instance running the skill reads the SKILL.md prose, sees the intent, and makes a direct Agent tool call. The bash script runs and produces JSON, but the Claude Code instance does not parse that JSON programmatically to construct the Agent call — it reads the surrounding prose instructions which already specify the agent type directly.

The dispatch-agent.sh script is therefore:
- **Not actually invoked** at runtime in the way a normal bash library would be
- **Documentation** of the dispatch decision logic, expressed as bash source
- **Future-proofing scaffolding** designed for a hypothetical "named fork" API

The spec explicitly states its rationale: "When Anthropic provides a 'named fork' API that combines cache prefix sharing with named agent specialization, only `dispatch-agent.sh` changes. All call sites remain unchanged."

**Current reality (June 2026)**:
- The Agent tool accepts `subagent_type` and `model` parameters directly
- Fork dispatch uses `subagent_type: "fork"` (not omitting the parameter)
- No named-fork API has appeared
- The `FORK_SUBAGENT` env var and the `CLAUDE_CODE_FORK_SUBAGENT=1` env var mentioned in fork-patterns.md are a grace degradation path, not the primary dispatch mechanism

**Line count of dispatch-related architecture**:
| File | Lines | Purpose |
|------|-------|---------|
| dispatch-agent.sh | 128 | Script generating JSON dispatch instructions |
| dispatch-agent-spec.md | 233 | Architecture specification |
| orchestrate-state-machine.md | 364 | State machine specification |
| skill-orchestrate/SKILL.md (total) | 1274 | Complete skill including all MT stages |
| skill-orchestrate/SKILL.md (MT stages only) | ~590 | Stages MT-1 through MT-5 |

**Total dispatch-related pseudocode**: ~2000 lines across 4 files.

---

### 2. Codebase Analysis: MT Mode (Stages MT-1 through MT-5)

**Stages MT-1 through MT-5** span lines 660–1246 of `skill-orchestrate/SKILL.md` (~590 lines of pseudocode).

The MT mode implements:
- **MT-1**: Parse delegation context (task_numbers, dependency_graph, waves)
- **MT-2**: Build per-task routing table using bash associative arrays; initialize `.orchestrator-multi-state.json`
- **MT-3**: Lifecycle-cycling while loop: refresh statuses, all-terminal check, build eligible_tasks, no-eligible circuit breaker
- **MT-4**: Phase-aware dispatch for eligible_tasks; parallel Agent call batching; per-task postflight
- **MT-5**: Final postflight; write `.return-meta-multi.json`

**What works well**:
- The lifecycle-cycling model (fixed in task 765) is conceptually correct
- Dependency gating logic (predecessor terminal check) is clear
- Parallel batching requirement is explicitly documented ("all Agent calls in ONE message")
- The multi-state file provides persistent tracking across cycle iterations

**What is fragile**:
- The bash pseudocode uses `declare -A` (bash associative arrays) which require careful handling and may fail silently if the Claude Code instance doesn't execute the bash literally (since it's prose pseudocode)
- Python3 is called inline to build JSON from bash arrays (lines 761-766), creating a python3 dependency in what is conceptually a prose instruction
- The MT-4 pseudocode has loops that say "# Invoke Agent tool: subagent_type=$r_agent" without providing clear prose about HOW the parallel dispatch should be done in a single message — this was the root cause of task 765's bug (the model didn't understand the batching requirement clearly enough)
- The `task_numbers[@]` array is referenced in MT-3 but only defined in MT-2's loop as individual assignments; the conversion of the jq JSON array to a bash array is not shown explicitly

**What a Workflow tool would solve**:
A hypothetical `Workflow tool` with `pipeline()`, `parallel()`, and `agent()` primitives would make the dependency-gating and batching semantics declarative rather than procedural. However, no such tool exists in the current tool list available to skills (`allowed-tools: Agent, Bash, Read, Edit`). The task description describes this as a feature of "June 2026 Claude Code" but it is not present in the tool definitions visible in this conversation.

---

### 3. Codebase Analysis: Fork Usage Patterns

**Current fork uses** (confirmed by grep):

| Location | Fork Type | Purpose |
|----------|-----------|---------|
| Stage 5a (drift inspection) | `dispatch_agent "" "$prompt" "$ctx" "true"` | Read plan file, write `.drift-inspection.json` |
| Stage 6 (blocker escalation, Step 2) | `dispatch_agent "" "$prompt" "$ctx" "true"` | Research specific blocker |

**Context from fork-patterns.md**: The `CLAUDE_CODE_FORK_SUBAGENT=1` environment variable enables fork behavior when `subagent_type` is omitted. However, the current codebase uses `subagent_type: "fork"` explicitly (confirmed in skill-researcher, Stage 4a). This suggests fork is now a first-class `subagent_type` value rather than the environment variable mechanism.

**Current limitation**: The dispatch-agent.sh fork path (`invoke_agent_fork`) checks `FORK_SUBAGENT` env var, which is inconsistent with how skill-researcher does literal `subagent_type: "fork"` calls.

**Candidate fork operations** (evaluated):

| Operation | Currently | Fork candidate? | Assessment |
|-----------|-----------|-----------------|------------|
| Blocker research | Named `general-research-agent` / fork with FORK_SUBAGENT | Appropriate | Already uses fork; should use `subagent_type: "fork"` directly |
| Drift inspection | Fork | Appropriate | Reads only a small plan file; cache inheritance is valuable |
| Literature sub-index creation | Named agent | Low value | Needs web search tools; specialization matters more than cache |
| Stage 0 multi-task mode detection | Direct bash | Not applicable | Pure bash, no Agent call needed |
| Task 766-style: lightweight file reads | Not applicable | Low value | These are done inline by the orchestrator |

**Key finding from fork-patterns.md**:
> Core skills always specify `subagent_type` explicitly to ensure the correct specialized agent is invoked. This is intentional: structured context injection requires a known agent type. The trade-off is no FORK_SUBAGENT cache sharing.

This documents the explicit design trade-off: the system prioritizes agent specialization over cache warmth for all structured operations. Fork is reserved for lightweight, general-purpose operations (blocker research, drift inspection) where specialization doesn't matter and the operation happens within the same conversational turn.

---

### 4. Complexity Assessment

**What dispatch-agent.sh adds vs. what it costs**:

| Benefit claimed | Reality check |
|-----------------|---------------|
| Single place to change when named-fork API arrives | No such API has arrived; the abstraction is unused |
| Encapsulates fork-vs-named-subagent decision | The decision is already documented in SKILL.md prose; the bash function adds another indirection layer |
| Future-proofing | SKILL.md itself would need to change if the dispatch model changed |

**Cost of the current indirection**:
- `dispatch-agent.sh` runs (generating JSON) but the JSON is not programmatically consumed
- The pattern "dispatch_instructions = dispatch_agent ..." looks like assignment but dispatch_instructions is never used by subsequent code
- Any reader of the skill must understand this is declarative pseudocode, not executable bash
- The spec (233 lines) explains the rationale, but the complexity is non-obvious

**What would be simpler**:
Replace the dispatch pattern:
```
dispatch_instructions = dispatch_agent "$RESEARCH_AGENT" \
  "Research task $task_number: ..." \
  '{"task_number": N, ...}' \
  "false"

Invoke the Agent tool per dispatch_instructions (subagent_type: $RESEARCH_AGENT).
```

With direct prose:
```
Invoke the Agent tool:
  subagent_type: "$RESEARCH_AGENT"
  prompt: "Research task $task_number: ..."
  (include delegation context JSON inline)
```

This removes the bash pseudocode layer entirely while keeping the same semantic clarity.

---

### 5. Breaking Changes Assessment

**Removing dispatch-agent.sh**:
- Callers: only `skill-orchestrate/SKILL.md` sources it (plus extension copy in `extensions/core/`)
- The extension copy at `.claude/extensions/core/scripts/dispatch-agent.sh` would also need removal/update
- No other skills or commands source this file
- Breaking? No — the file is not actually executed by runtime code, only read as pseudocode in SKILL.md

**Changing MT mode to prose-based**:
- No external API contracts to break — MT mode is entirely internal to `skill-orchestrate/SKILL.md`
- The orchestrate.md command that sets `multi_task_mode: true` does not need to change
- Breaking? No

**Adding `subagent_type: "fork"` to dispatch functions**:
- The existing `dispatch_agent "" ... "true"` pattern omits subagent_type (which triggers FORK_SUBAGENT if set)
- skill-researcher uses `subagent_type: "fork"` directly and successfully
- Unifying to `subagent_type: "fork"` would remove the FORK_SUBAGENT env var dependency
- Breaking? Minor — FORK_SUBAGENT env var check becomes unnecessary (benign)

---

## Decisions

1. **The Workflow tool cannot be used for MT redesign** because it does not appear in the available tool set for skills (`allowed-tools: Agent, Bash, Read, Edit`). The task description's reference to a Workflow tool is aspirational/incorrect for this Claude Code instance.

2. **dispatch-agent.sh is a pseudocode documentation layer**, not a runtime library. Its removal would simplify the skill without changing behavior, since the Agent tool calls are always specified directly in SKILL.md prose anyway.

3. **Fork patterns are correctly targeted** at lightweight, in-session, general-purpose operations. No new fork candidates provide enough value to justify the loss of agent specialization.

4. **MT mode bash pseudocode is the primary reliability risk**: The task 765 bug (wave cycling not working) and the jq status string bug both stemmed from the model misinterpreting bash pseudocode that looked executable but required human-level reading of intent. Converting to numbered prose steps with explicit Agent tool call tables would reduce this class of bug.

---

## Recommendations

### Recommendation 1: Remove dispatch-agent.sh (Low Risk, Low-Medium Effort)

**Action**: Delete `.claude/scripts/dispatch-agent.sh` and `.claude/extensions/core/scripts/dispatch-agent.sh`. Update `.claude/docs/architecture/dispatch-agent-spec.md` to reflect the direct-dispatch pattern. Update `skill-orchestrate/SKILL.md` to replace all `dispatch_instructions = dispatch_agent ...` patterns with direct Agent tool call prose.

**Expected result**: ~360 lines removed (128 script + 233 spec). SKILL.md single-task stages become ~30% shorter. The skill becomes self-contained with no external script dependency.

**Risk**: Low. The script is pseudocode documentation, not runtime logic. The Agent tool calls were always specified in the surrounding prose.

**Template for replacement**:
```
### State: `not_started`

Invoke the Agent tool:
  subagent_type: "general-research-agent"  (or $RESEARCH_AGENT from Stage 1b)
  prompt: "Research task $task_number: $DESCRIPTION"
  context: {
    "task_number": N,
    "task_type": "T",
    "session_id": "S",
    "orchestrator_mode": false,
    "lit_flag": "$lit_flag"
  }

After Agent tool returns: proceed to Stage 5 (handoff reading). Increment cycle_count.
```

### Recommendation 2: Convert MT Bash Pseudocode to Prose Tables (Medium Risk, Medium Effort)

**Action**: Rewrite Stages MT-3 and MT-4 as numbered prose steps with explicit dispatch tables instead of bash loop pseudocode.

**Specific changes**:
- Replace `declare -A` associative arrays with a prose description: "For each task, record type, dir, research_agent, implement_agent from Stage MT-2"
- Replace the `while [ "$cycle_count" -lt "$MAX_CYCLES_MT" ]` block with numbered steps labeled "Repeat until terminal condition"
- Replace the `for task_num in "${research_tasks[@]}"` loops with a single prose instruction: "Issue ALL research Agent calls in ONE message; issue ALL plan Agent calls in ONE message; issue ALL implement Agent calls in ONE message"
- Remove the python3 inline call (lines 761-766); use direct jq instead

**Expected result**: MT stages MT-3 and MT-4 shrink from ~400 lines to ~150 lines of clear prose. The batching requirement (critical for parallel execution) becomes visually prominent.

**Risk**: Medium. MT mode is complex and the rewrite must preserve all edge cases (dependency gating, failed_tasks tracking, continuation context). Recommend a plan phase before implementation.

### Recommendation 3: Unify Fork Dispatch to `subagent_type: "fork"` (Low Risk, Low Effort)

**Action**: Update the two fork dispatch points in skill-orchestrate (Stage 5a drift inspection, Stage 6 Step 2 blocker research) to use `subagent_type: "fork"` explicitly, matching the pattern already used in skill-researcher.

**Why**: The FORK_SUBAGENT env var mechanism is an older pattern. `subagent_type: "fork"` is explicit and does not depend on an environment variable being set. This is confirmed working in skill-researcher's Stage 4a literature sub-index fork.

**Change**:
```
# Before (pseudocode):
dispatch_agent "" "$drift_inspect_prompt" "$drift_inspect_context" "true"
# SKILL.md reads this output and invokes the Agent tool as a fork (omitting subagent_type)

# After (direct prose):
Invoke the Agent tool:
  subagent_type: "fork"
  prompt: "$drift_inspect_prompt"
  context: $drift_inspect_context
```

### Recommendation 4: Do Not Redesign Around Workflow Tool (No Action Required)

The Workflow tool with `pipeline()/parallel()/agent()` is not present in the tool set available to skills in this Claude Code instance. Do not redesign MT mode around this tool until:
1. It appears in the available tools list
2. There is documentation on its constraints (parallelism limits, timeout behavior, error handling)
3. A migration path for the existing lifecycle-cycling logic is validated

The current MT mode, once converted to clearer prose (Recommendation 2), will be maintainable and reliable without the Workflow tool.

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| MT prose rewrite introduces bugs in dependency gating | Medium | Write MT rewrite as a dedicated task with careful phase-by-phase validation; test with 2-task runs |
| Removing dispatch-agent.sh breaks the extension copy | Low | Update both copies atomically; verify no other consumers exist before deletion |
| `subagent_type: "fork"` behaves differently from FORK_SUBAGENT omit pattern | Low | Already used successfully in skill-researcher; test with a blocker escalation scenario |
| Workflow tool becomes available later requiring another rewrite | Low | Design prose dispatch tables to be easy to convert; the conceptual model (group by phase, batch, await) maps directly to Workflow primitives |

---

## Context Extension Recommendations

- **Topic**: Dispatch pattern for SKILL.md prose instructions
- **Gap**: No documented pattern for how direct Agent tool calls should be written in SKILL.md prose (post removal of dispatch-agent.sh)
- **Recommendation**: Add `.claude/context/patterns/direct-agent-dispatch.md` documenting the table format for Agent tool call invocations in skill prose

---

## Appendix

### Search Queries Used
- Grep: `dispatch-agent\|dispatch_agent\|FORK_SUBAGENT` across `.claude/`
- Grep: `Workflow tool\|pipeline()\|parallel()\|agent()` across `.claude/`
- Read: dispatch-agent.sh, dispatch-agent-spec.md, skill-orchestrate/SKILL.md, orchestrate-state-machine.md, fork-patterns.md, skill-researcher/SKILL.md, skill-team-research/SKILL.md

### Line Count Summary

| Component | Lines | Recommendation |
|-----------|-------|---------------|
| dispatch-agent.sh | 128 | Delete |
| dispatch-agent-spec.md | 233 | Update to document direct dispatch pattern |
| MT-1 through MT-5 (in SKILL.md) | ~590 | Rewrite to prose tables (~150 lines) |
| Single-task stages 1-8 (in SKILL.md) | ~680 | Simplify dispatch blocks (-30%) |
| orchestrate-state-machine.md | 364 | Minor updates to reflect prose dispatch pattern |

### Key Files Examined

- `/home/benjamin/.config/nvim/.claude/scripts/dispatch-agent.sh`
- `/home/benjamin/.config/nvim/.claude/docs/architecture/dispatch-agent-spec.md`
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/docs/architecture/orchestrate-state-machine.md`
- `/home/benjamin/.config/nvim/.claude/context/patterns/fork-patterns.md`
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/skills/skill-team-research/SKILL.md`

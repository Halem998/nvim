# Research Report: Task #591 — Teammate C (Critic) Findings

**Task**: 591 - Research Claude Code orchestration practices
**Role**: Teammate C — Critic: Gaps, blind spots, and risks in the proposed refactor
**Started**: 2026-05-22T15:55:00Z
**Completed**: 2026-05-22T16:20:00Z
**Effort**: ~1 hour
**Sources/Inputs**: Codebase analysis — commands/, skills/, agents/, context/patterns/, state.json

---

## Executive Summary

- The 9-task refactor plan addresses real duplication but contains several unvalidated assumptions about token savings, implementation complexity, and backward compatibility that could cause it to cost more than it saves.
- The plan has no testing strategy, no migration plan for in-flight tasks, no rollback procedure, and no success criteria — standard prerequisites for a refactor of this scale (~18K lines).
- The most dangerous assumption is that a shared utility layer will actually reduce token consumption at the point of use; the system already uses lazy-loading and scripted delegation patterns that may make the duplication cheaper to keep than the abstraction overhead to eliminate.
- Three specific gaps require investigation before committing to the full 9-task scope: (1) actual token cost measurement, (2) concurrent-write risk in parallel multi-task dispatch, and (3) the extension integration contract for the new shared infrastructure.

---

## Finding 1: The Duplication May Be Intentional Load-Bearing Structure

**Confidence**: High

### Key Finding

The "~80% structural duplication" across the four core skills (skill-researcher, skill-planner, skill-implementer, skill-reviser) is not accidental — it was deliberately chosen to give each skill independent control over its lifecycle. Evidence:

1. The `skill-lifecycle.md` context document explicitly records the *prior* 3-skill pattern as "Legacy Pattern (Deprecated)" and explains the current single-skill-per-workflow design was chosen to reduce halt risk. This was a deliberate architectural trade where code length was exchanged for reliability.

2. Each skill's Stage 2 (Preflight) is almost identical in structure but differs meaningfully in the *target status string* and *what it says in its note*. The implementer skill's Stage 2 includes an explicit note about updating the plan file status — not present in the researcher. This is functional divergence hidden inside structural similarity.

3. The skills' stage numbering is already inconsistent (researcher has Stage 4a/4b/4c/4d; implementer has 5a/5b/5c; reviser has Stage 4 with no sub-stages). If these were meant to share a base, they would have been aligned already.

### Gap in 9-Task Plan

Task 594 ("Refactor workflow skills to shared base, ~100-150 lines of unique logic") assumes the shared stages are byte-identical. They are not. The `parse_task_args()` function is *syntactically* identical across commands, but the skills themselves have meaningfully different context-collection stages (researcher has 4a/4c/4d; planner has only 4a; implementer has 4a only). A shared base would need conditional inclusion, increasing abstraction complexity without proportional benefit.

### Recommended Questions to Ask

- What specific failures or user complaints prompted this refactor? If the system works reliably at 18K lines, what is the actual pain?
- Is the duplication causing maintenance problems in practice? (e.g., has a bug been fixed in one skill but not another?)

---

## Finding 2: Token Economics of the Refactor Are Unvalidated

**Confidence**: High

### Key Finding

The plan assumes that reducing duplication will reduce token usage, but this is far from certain in this system's usage patterns:

1. **Skills are invoked, not loaded into the context window as text.** When `/research N` runs, it reads `research.md` as the command context. The command text is in Claude's context. But the `skill-researcher/SKILL.md` content is only consumed when the Skill tool invokes it — at which point *only that skill's content* is in the subagent's fresh context window. The skill's 558 lines do NOT compete with the command's 500 lines for the same context budget; they run in a separate invocation.

2. **The "progressive disclosure" goal (task 598) for commands may be adding complexity without reducing real token usage.** The command files (`research.md`, `plan.md`, `implement.md`) run in the *orchestrator's* context (model: opus, 1M context). They are read once at invocation and not re-loaded. The relevant token cost is subagent context — and subagents already use lazy loading.

3. **The fork cache sharing benefit (mentioned throughout tasks 591-596) has a documented prerequisite**: `CLAUDE_CODE_FORK_SUBAGENT=1` must be set AND `subagent_type` must be omitted. Task 500's own research (`.return-meta.json` in state.json) concluded that "cache sharing is fundamentally incompatible with named agent routing." The plan's stated benefit of "fork caching" for core skills (task 594 note: "subsumes task 500") conflicts with that prior finding.

### Gap in 9-Task Plan

The plan contains no baseline measurement of token usage. Without before/after data, there is no way to validate that the refactoring achieved its goal. Task 591 is supposed to provide this analysis, but the task description doesn't mention measuring actual token budgets — it mentions *auditing* for token waste.

### Recommended Question

What is the actual token cost per `/research N` call today? If the orchestrator already uses 1M context and subagents get fresh contexts, is there a real token budget problem to solve, or is this perceived waste?

---

## Finding 3: The `/orchestrate` Command Design Has Reliability Concerns

**Confidence**: High

### Key Finding

Task 596 proposes a loop-until-complete orchestrator that calls multiple sub-operations sequentially. This design has specific failure modes that the plan does not address:

1. **State machine complexity in a stateless executor.** The orchestrator must detect current task state, decide next action, spawn subagent, read handoff, decide continuation. Each of these steps can fail independently. The current system avoids this by keeping commands stateless (user decides when to run `/plan` vs `/research`) and letting skills own their own completion. A loop-based orchestrator accumulates state in the orchestrator's context window across multiple sub-operations.

2. **The handoff artifact pattern is relatively new** (context/patterns/subagent-continuation-loop.md was created 2026-05-04 per frontmatter) and is only used in skill-implementer today. The plan proposes to rely heavily on handoff artifacts as the primary communication mechanism for the new orchestrator, but there is no evidence this mechanism has been stress-tested at the scale proposed (research + plan + implement + possibly revise, all chained via handoffs).

3. **The "blocker escalation" path in task 596** — where the orchestrator detects an implementation blocker, spawns a research fork, invokes the reviser, then re-dispatches implementation — is a complex state machine. If any step of this fails (research finds nothing useful, reviser produces a bad plan), the orchestrator has no documented fallback behavior.

4. **The continuation loop already exists in skill-implementer** (Stage 5c). The `/orchestrate` command would be a second, outer continuation loop. Two nested loops with different termination conditions and different handoff formats are likely to interfere.

### Evidence

From `subagent-continuation-loop.md`:
> Max continuations: 3 (aligns with postflight-control.md loop guard convention)

From the current `.continuation-loop-guard` file in the deleted `specs/589_wezterm_artifact_colors_preflight/` (visible in git status), the loop guard pattern is already in use. The proposed orchestrator adds another loop level on top.

### Recommended Questions

- Does the new orchestrator replace skill-implementer's continuation loop, or sit on top of it?
- What happens if the orchestrator's outer loop and the implementer's inner continuation loop both trigger simultaneously?

---

## Finding 4: Concurrent Write Risk in Multi-Task Dispatch Is Acknowledged But Undersized

**Confidence**: Medium

### Key Finding

The `skill-lifecycle.md` document explicitly notes:

> "Multiple parallel skill instances may write to `state.json` concurrently. This is acceptable because each skill writes to a specific `project_number` entry using scoped jq operations... Rapid concurrent writes could cause read-modify-write races in edge cases; this is a known limitation."

Task 593 proposes to extract "shared utilities" including "GATE IN template" and "multi-task dispatch." If the shared GATE IN utility is extracted into a shell script that multiple parallel instances call simultaneously, the race condition window increases. Currently, each skill encodes its own jq operation inline; a shared script adds an indirection layer where the script reads the full `state.json`, modifies a field, and writes back — a classic read-modify-write race.

The plan has no discussion of how to safely handle parallel writes to `state.json` when a shared utility script is involved.

### Recommended Questions

- Will the extracted GATE IN utility use atomic file updates (e.g., using a lock file or `mv` rename)?
- Is the current `update-task-status.sh` script being called concurrently already (it is called from multiple parallel skills), and if so, does it have any locking?

---

## Finding 5: Extension Integration Points Are Unspecified

**Confidence**: High

### Key Finding

The system currently has 4 loaded extensions (nvim, nix, and 2 others visible in skill routing tables). Each extension provides its own skills following Pattern A (explicit `subagent_type`, multi-stage postflight). Tasks 593-595 propose extracting shared command infrastructure, but:

1. **Extension skills are not mentioned as a refactoring target** in tasks 593-596. The neovim-implementation skill (330L), nix-implementation skill (378L), neovim-research skill (232L), and nix-research skill (232L) are described as following "the same pattern as core skills" — but if the core skills are refactored to use a shared base, the extension skills will diverge from the core pattern while appearing to follow it.

2. **The extension manifest contract may need updating.** Extensions declare routing via `manifest.json`. If the shared utilities change how postflight works (e.g., artifact linking format, status update script interface), extension skills that call these utilities directly will break silently — they'll call the script with the old interface.

3. Task 599 ("Update CLAUDE.md, extension integration points, and documentation") is listed as depending on tasks 595-598. But extension compatibility verification cannot be the *last* step — it needs to be a *gate* on each of the preceding tasks.

### Evidence from state.json

Task 500 (`add_context_fork_to_core_skills`, status: `researched`) has an unintegrated plan. Its report explicitly found that "All loaded extension skills use the same Pattern A delegation as core skills." If task 594 changes what Pattern A looks like, task 500's findings become invalid — but task 500 is not listed as a dependency or as "subsumed" by task 594.

### Recommended Question

- Which of the loaded extension skills call `update-task-status.sh`, `link-artifact-todo.sh`, or other scripts directly? If all of them do, changes to those scripts' interfaces break all extensions simultaneously.

---

## Finding 6: Missing Standard Practices for a Refactor of This Scale

**Confidence**: High

### Key Finding

The 9-task plan is missing components that would be standard for a ~18K line refactor:

| Missing Component | Risk if Absent |
|-------------------|---------------|
| Testing strategy | No way to verify refactored components work correctly before rollout |
| Rollback plan | If task 594 produces broken skills, how to revert while keeping task 593's utilities? |
| Migration for in-flight tasks | Tasks 78 (planned) and 87 (researched) are in active states; if skill interface changes, their next `/implement` will use the new code on old context |
| Performance benchmarking | No baseline token cost measurements; no post-refactor validation |
| Definition of "done" | What specific metrics indicate the refactor succeeded? |
| Backwards compatibility period | Extensions outside this repo (if any) that depend on skill interfaces |

The only testing mentioned across all 9 task descriptions is task 599's "Verify extension compatibility" at the very end. This is verification, not testing.

### Specific Risk

Task 597 proposes decomposing `/todo` (1047 lines) and `/review` (1039 lines). These are the most complex commands in the system. `/todo` handles vault archival, task renumbering, ROADMAP.md annotation, and orphan detection. A single bug in a refactored `/todo` could corrupt `state.json` or `TODO.md` — the system's primary state stores. There is no test suite mentioned that would catch this.

---

## Finding 7: The Research Task (591) Itself May Be Insufficient as a Foundation

**Confidence**: Medium

### Key Finding

Task 591 is described as research into "best practices for forking vs. subagent invocation, progressive disclosure, token-efficient context loading, and agent orchestration patterns." But the system has already done significant research on these exact topics:

- Task 499 (dependency of tasks 500, 501): Fork mechanics research
- Task 500 (`add_context_fork_to_core_skills`, status: `researched`): Concluded fork cache sharing is incompatible with named agent routing — plan still unintegrated
- Task 501 (`optimize_team_mode_fork_cache_sharing`, status: `planned`): 4-phase plan already exists

The 9-task plan states tasks 500 and 501 "will be subsumed" by the new work. But task 500's unintegrated plan and task 501's existing plan represent prior decisions that the research should either endorse or explicitly supersede — not simply ignore.

If task 591's research leads to findings that conflict with task 500's existing plan, there is no mechanism for reconciling them before task 592 (design) begins. The Teammate A and B reports may not capture this prior work either, since it requires reading state.json to discover.

### Evidence

From state.json, task 500 memory candidates include:
> "The hybrid inline-agent approach has no precedent, context: fork + orchestration IS proven (slide skills), cache sharing is fundamentally incompatible with named agent routing, recommend rescoping task 500 to documentation-only"

This directly contradicts assumptions in tasks 594 and 596 about fork caching benefits.

---

## Finding 8: The "Progressive Disclosure" Pattern May Add Latency

**Confidence**: Medium

### Key Finding

Task 598 proposes tiered context loading (Level 1: ~500 lines always, Level 2 on command detection, Level 3 at agent spawn, Level 4 on-demand). But:

1. **Context loading in this system is already progressive** — the commands use lazy `@`-references, skills have `context: fork` patterns for extension skills, and agents load their context on-demand. The existing `context/index.json` (139 entries) is already designed for selective loading.

2. **Adding tier logic increases the number of conditional reads** before work starts. Each tier boundary requires reading the current context, checking conditions, loading the tier, then proceeding. In a system where a single `/research N` takes 30-60 seconds, the overhead of 3-4 additional conditional loads may be measurable.

3. **The "context budget caps" proposal** (sonnet workers: ~8K tokens, opus planners: ~15K tokens) is interesting but unvalidated. If a sonnet worker agent regularly needs more than 8K tokens of context to complete its task correctly, imposing a cap will silently degrade output quality. There is no mechanism described for detecting or alerting on context budget violations.

---

## Synthesized Risk Assessment

| Risk | Likelihood | Impact | Mitigation Needed |
|------|-----------|--------|-------------------|
| Shared utility abstraction costs more tokens than it saves | Medium | Medium | Measure baseline first |
| Extension skills break silently when core changes | High | High | Test each refactored component against extensions before proceeding |
| Orchestrator continuation loop conflicts with implementer continuation loop | Medium | High | Design the two loops as exclusive alternatives, not nested layers |
| `/todo` refactor corrupts state stores | Low-Medium | Critical | Add regression tests before touching task 597 |
| Fork cache "savings" assumption conflicts with task 500's concluded findings | High | Medium | Explicitly resolve task 500 before proceeding with tasks 594/596 |
| No rollback path if mid-refactor work breaks active tasks | Medium | High | Plan revert strategy before starting task 593 |

---

## Questions the Plan Does Not Ask

1. **Is the system actually failing?** The last 5 completed tasks (586-590) all show `status: "completed"` with detailed completion summaries. The system is working. What specific user pain points motivate this refactor?

2. **What is the actual token cost per command today?** Without a baseline, the refactor cannot be evaluated.

3. **Would removing just the `parse_task_args()` duplication across 3 commands achieve 80% of the stated goal?** That's ~90 lines of identical code, achievable in a single small task, with minimal risk.

4. **What happens to tasks 78 (planned) and 87 (researched) if the skill interface changes?** These are in active states and will use the new code when their `/implement` or `/plan` is eventually called.

5. **Does task 500's unintegrated plan need to be formally abandoned before task 594 proceeds?** Currently task 500 is `researched` with an unintegrated plan. Tasks 591-599 plan to "subsume" it, but `state.json` still shows it as active and its findings directly contradict assumptions in the refactor plan.

---

## Recommendations

1. **Before starting task 592 (Design)**, resolve task 500 by either formally abandoning it or integrating its conclusion (fork cache sharing incompatible with named routing) into the design constraints.

2. **Before starting task 593 (Extract utilities)**, add a definition of success: specific token measurements and specific duplication metrics that the refactor is expected to change.

3. **Before starting task 597 (Refactor /todo and /review)**, create regression tests or snapshot tests for these two monolith commands. These are the highest-risk changes in the plan.

4. **Consider a scoped alternative**: Extract only `parse_task_args()` (a single function copied identically across 3 commands) as a pilot. Measure token impact. If measurable benefit exists, proceed; if not, reconsider the full 9-task scope.

5. **The `/orchestrate` command** (task 596) should be designed as an *alternative execution path* to the individual commands, not as a replacement. Its continuation loop must be defined as exclusive with skill-implementer's existing continuation loop.

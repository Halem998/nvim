# Critic Findings: Unified Literature System (Task 758)

**Role**: Teammate C — Critic
**Date**: 2026-06-23
**Artifact**: 06_teammate-c-findings.md
**Sources examined**:
- `specs/758_unified_literature_system/reports/05_research-synthesis.md`
- `specs/758_unified_literature_system/plans/05_unified-literature-plan.md`
- `.claude/skills/skill-orchestrate/SKILL.md`
- `.claude/skills/skill-researcher/SKILL.md`
- `.claude/skills/skill-planner/SKILL.md`
- `.claude/skills/skill-implementer/SKILL.md`
- `.claude/scripts/parse-command-args.sh`
- `.claude/scripts/literature-retrieve.sh`
- `.claude/scripts/literature-search.sh`
- `.claude/settings.json`, `.claude/settings.local.json`, `~/.claude/settings.json`
- `specs/758_unified_literature_system/reports/04_extension-consolidation.md`
- `specs/state.json` (task 758 description)
- `~/Projects/Literature/FIND_SOURCES.md`

---

## Executive Summary

The plan has four serious problems and the synthesis has two additional blind spots. Most critically: the plan explicitly declares as a Non-Goal the very feature the task description requires (a literature-agent that autonomously explores). The source discovery pipeline mentioned in the task brief does not appear anywhere in the plan. A Bash permission gap will block the briefing+tools pattern from working autonomously. And the token savings claim reverses under real search-heavy usage. Separately, the synthesis never surfaces the tension between the task description and its own architectural decision.

Confidence: High on all four primary findings (verified with file reads and command output). Medium on the source discovery assessment (the requirement was added post-research and is ambiguously scoped).

---

## Key Findings

### Finding 1: Plan Directly Contradicts the Task Description (Critical)

The task description in `specs/state.json` states requirement (3) explicitly:

> "Replace --lit/--zot context injection with a **literature-agent** that receives the sub-index and **autonomously explores** the global Literature/ corpus"

And requirement (5):

> "Design the literature-agent **tool interface** (search, read chunks, cross-reference)"

The plan lists under Non-Goals:

> "Implementing a full literature-agent as a separate spawnable subagent (Pattern 3C uses briefing+tools, not a separate agent)"

The research may have correctly concluded that briefing+tools is a better architecture, but neither the synthesis report nor the plan acknowledges the task description conflict or explains the decision to deviate from it. The plan cannot simply declare a core task requirement a Non-Goal without surfacing the decision and getting alignment.

Report 04 (`04_extension-consolidation.md`) did flag this correctly:

> "The proposed literature redesign should follow this pattern but with one key difference: the literature-agent is a **real agent** (not just a documentation stub) that can be spawned as a subagent to autonomously explore the corpus."

Report 04 also notes under its recommendation:
> "Wire --lit flag to spawn literature-agent instead of static injection"

The synthesis (report 05) resolves this in favor of briefing+tools without explanation. This decision may be correct, but it needs to be made explicitly rather than silently overriding the task requirements.

**Impact**: If implemented as planned, the deliverable will not satisfy the stated task. The implementer or user will notice the gap at review.

---

### Finding 2: Source Discovery Pipeline Entirely Absent from Plan (High)

The task brief for this critic role describes a second new requirement:

> "A source discovery pipeline: search online -> check Zotero -> find PDFs -> track missing in SOURCES.md -> convert/segment/integrate"

Neither the synthesis report nor the plan mentions this pipeline. The existing `~/Projects/Literature/FIND_SOURCES.md` is a manually maintained file tracking exactly two items (one paywalled paper, one unconverted PDF). There is no automated equivalent.

This absence could mean:
1. The requirement is post-research scope expansion not yet integrated, OR
2. It was always intended to be addressed by the existing manual workflow, OR
3. It is genuinely missing from scope

The distinction matters because if this pipeline is in scope, it should be a separate Phase 7 (or a new task). If it is out of scope, the plan should say so and why. The current plan says nothing, leaving ambiguity for the implementer.

**Impact**: Implementer will encounter the requirement at integration and have no guidance.

---

### Finding 3: Bash Permission Gap Will Block Autonomous Agent Usage (High)

The briefing+tools pattern requires that research/plan/implement agents call `literature-search.sh` autonomously via Bash. Verification of the allow lists across all three settings files reveals no pattern that would permit this without a confirmation prompt:

- `~/.claude/settings.json` (global): Allows `Bash(git:*)`, `Bash(lake *)`, `Bash(pdflatex *)`, etc. No `bash .claude/scripts/*` pattern.
- `.claude/settings.json` (project): Same pattern list. No script wildcard.
- `.claude/settings.local.json` (local): Has specific one-off allows (`bash .claude/scripts/check-extension-docs.sh`, `bash .claude/scripts/update-task-status.sh preflight 438 ...`). No general script allow.

When an agent calls `Bash("bash .claude/scripts/literature-search.sh \"modal logic\"")`, Claude Code will present a permission prompt because the command matches no allow rule. In an autonomous agent context (orchestrate mode), this blocks execution entirely.

Measured output: a single `literature-search.sh "modal logic"` call returns ~11,900 characters (~2,974 tokens) of JSON. This is a practical tool, not a hypothetical — but it needs to be in the allow list to work autonomously.

**Mitigation already available**: The plan includes a step to "Set `LITERATURE_DIR` in `.claude/settings.json` env block" (Phase 4). The fix is adjacent: also add `"Bash(bash .claude/scripts/literature-search.sh *)"` to the allow list. The plan does not include this step.

**Impact**: Without the allow entry, the entire briefing+tools design pattern fails silently in non-interactive (orchestrate) mode. The agent will be blocked and either wait for user input or error out.

---

### Finding 4: Token Savings Claim Reverses Under Real Usage (Medium)

The synthesis states:

> "Token savings: 200-500 vs 4,000-8,000"

This compares: briefing block (~300 tokens) vs static injection (4,000-8,000 tokens). The claim is accurate for a single comparison in isolation. However, the comparison is misleading for agents that actually use the tools:

- One `literature-search.sh` call returns ~3,000 tokens of JSON metadata
- A typical research agent doing literature exploration would make 3-5 searches
- 3 searches = ~9,000 tokens consumed from search results alone
- Plus the 300-token briefing = ~9,300 tokens total

This exceeds the "worst case" 8,000 token injection figure. The briefing+tools pattern is strictly better only when:
1. The agent makes zero or one literature searches, OR
2. The agent mostly uses `Read` on specific chunk files rather than searching

For agents doing targeted retrieval (they know the paper they want), briefing+tools wins clearly. For agents doing exploratory search (they do not know which paper is relevant), injection may cost fewer tokens, though it puts the selection burden on the preflight script rather than the agent.

The plan should acknowledge this trade-off rather than presenting briefing+tools as uniformly cheaper. It may still be the right design for other reasons (agent autonomy, flexibility, not loading irrelevant content), but the token argument should be presented accurately.

---

### Finding 5: Synthesis Omits the literature-agent vs Briefing Tension (Medium)

The synthesis report (05) never mentions the literature-agent concept despite report 04 recommending it. The synthesis has a "Cross-Report Conflict Resolution" section that resolves the zotero-scripts-are-stubs conflict, but silently drops the literature-agent recommendation from report 04 without noting it as a resolved conflict.

This omission means:
- A reader of only the synthesis cannot see that report 04 had a different architectural recommendation
- The plan implementer has no record of why the literature-agent approach was rejected
- If the user originally wrote the task description to require the literature-agent, they cannot see where that decision was overridden

---

### Finding 6: zot_flag Removal Is Underestimated (Low)

The plan phase 4 allocates 2 hours to "Rewire --lit Flag and Skill Preflights" and includes removing `zot_flag`. Measured count: `zot_flag` appears 12 times in `skill-orchestrate/SKILL.md` alone. It also appears in skill-researcher, skill-planner, and skill-implementer preflights. The delegation JSON templates in skill-orchestrate include `zot_flag` in 6 separate JSON object constructions.

This is mechanical work but it is more extensive than the plan implies. The 2-hour estimate may be tight if the implementer is being careful to audit all delegation contexts.

---

## Recommended Approach

### Must-fix before implementation:

1. **Resolve the literature-agent vs briefing+tools decision explicitly.** Either:
   - Revise the task description to say briefing+tools satisfies requirement (3), explaining why, OR
   - Add a Phase 0 or Phase 7 to implement a real literature-agent as a spawnable subagent
   
   The briefing+tools pattern is defensible (simpler, no new agent infrastructure, works within existing agent types), but the decision must be made consciously, not by silent omission.

2. **Add bash allow rule to the implementation plan.** Phase 4 must include:
   ```
   "Bash(bash .claude/scripts/literature-search.sh *)"
   ```
   added to `.claude/settings.json` permissions. Without this, briefing+tools does not work in autonomous mode.

3. **Scope decision on source discovery pipeline.** Add a section to the plan explicitly stating whether the source discovery pipeline (search online -> check Zotero -> track in SOURCES.md -> convert) is:
   - In scope for this task (requires a new Phase 7 or separate task)
   - Out of scope (FIND_SOURCES.md remains the manual approach)

### Should-address before implementation:

4. **Correct the token savings claim.** Replace "200-500 tokens vs 4,000-8,000 tokens" with an accurate framing: briefing+tools saves tokens for targeted retrieval (agent knows which paper it wants) but may consume more for exploratory search (3+ FTS5 queries). The design is still better for other reasons (agent autonomy, freshness), just not uniformly cheaper.

5. **Add to synthesis report's conflict resolution.** Note that the literature-agent recommendation from report 04 was considered and rejected in favor of briefing+tools with reasoning (simpler, no new agent type needed, Pattern 3C achieves same autonomy via Bash access). This preserves the decision trail.

### Lower priority:

6. **Adjust Phase 4 timing.** Consider 3 hours instead of 2 for the zot_flag cleanup, given 12+ occurrences in skill-orchestrate alone plus preflight changes in three other skills.

---

## Evidence Summary

| Claim | Evidence | Verdict |
|-------|----------|---------|
| Task requires literature-agent | `specs/state.json` task description item (3) and (5) | VERIFIED |
| Plan declares it Non-Goal | Plan line 46: "Non-Goals: Implementing a full literature-agent..." | VERIFIED |
| Source discovery not in plan | grep across all plan and synthesis files: 0 matches for "source discovery", "SOURCES.md" | VERIFIED |
| Bash allow list missing literature-search | All three settings.json files checked, no `bash .claude/scripts/literature-search.sh` pattern | VERIFIED |
| Single search = ~3000 tokens | `bash literature-search.sh "modal logic"` output: 11,899 chars | VERIFIED |
| zot_flag appears 12x in orchestrate | `grep -c "zot_flag" skill-orchestrate/SKILL.md` returns 12 | VERIFIED |
| Token savings claim (300 vs 4000-8000) | Synthesis report section 3 | ACCEPTED with qualification |
| Global Literature/ on local disk | `df /home/benjamin/Projects/Literature/` → `/dev/nvme0n1p2` | VERIFIED (single-machine risk acknowledged but low) |

---

## Confidence Level

- **Finding 1 (task vs plan conflict)**: High — direct text comparison of state.json and plan
- **Finding 2 (source discovery absent)**: High for absence; Medium for whether it's intended to be in scope
- **Finding 3 (bash permission gap)**: High — verified all three settings files, measured command output
- **Finding 4 (token claim)**: Medium — the breakeven point depends on agent behavior which varies
- **Finding 5 (synthesis omission)**: High — the synthesis section exists and can be checked
- **Finding 6 (timing underestimate)**: Medium — timing estimates are always judgment calls

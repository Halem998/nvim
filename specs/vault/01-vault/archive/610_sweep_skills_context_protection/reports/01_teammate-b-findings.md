# Teammate B Findings: Alternative Patterns, Shared Infrastructure, and Strategy

- **Task**: 610 - sweep_skills_context_protection
- **Teammate**: B (Alternative Approaches)
- **Focus**: Prioritization, shared infrastructure, batch vs. incremental, edge cases, prior art
- **Confidence Level**: High

---

## Key Findings

### 1. Task 609 Prior Art — What Worked and What to Replicate

Task 609 refactored `skill-team-research` (751 → 615 lines) and completed in ~1.5 hours against a 4-hour estimate. Key lessons:

- **Synthesis delegation was the highest-impact change.** Stages 7-9 (inline synthesis) were the worst violation — reading all teammate findings into the lead accumulated 7-21k tokens. Replacing this with a dispatch to `synthesis-agent` reduced synthesis-related context growth to ~900 tokens.
- **`skill-base.sh` functions absorbed postflight boilerplate.** Functions like `skill_postflight_update`, `skill_increment_artifact_number`, `skill_link_artifacts`, and `skill_cleanup` already exist and were used to replace inline jq/edit patterns.
- **Prompt templates were extracted to `team-wave-helpers.md`.** This reduced SKILL.md line count and made templates reusable.
- **Line count reduction was modest (18%).** The plan targeted 400-460 lines but landed at 615. This is because stage documentation was preserved for correctness. The context violation was fully eliminated regardless.
- **Named agent vs. anonymous fork decision**: Used `synthesis-agent.md` (named agent) for reusability by `skill-team-plan`. This is the right choice — task 610 should reuse it.

### 2. Skill Categorization — Three Distinct Groups

The 6 target skills fall into three groups with different violation profiles:

**Group A: Single-Agent Thin Wrappers** (skill-researcher, skill-planner, skill-implementer)
- These already use `skill-base.sh` functions extensively (Stages 1-3, 6-10).
- Violations are limited to:
  - **Stage 4b**: `cat` of format spec files (report-format.md, plan-format.md, summary-format.md) — ~88-131 lines each.
  - **Stage 4a**: `memory-retrieve.sh` output captured into lead context — variable size.
  - **Stage 4c** (researcher only): `cat specs/ROADMAP.md` — variable size.
  - **Stage 4d** (researcher only): Prior implementation context collection — up to 500 lines.
- **Fix is mechanical**: Replace `cat` with @-reference passthrough, move `memory-retrieve.sh` call to subagent prompt.
- **Risk**: Very low. These are well-structured thin wrappers.

**Group B: Team Orchestration Skills** (skill-team-plan, skill-team-implement)
- These have MORE violations than Group A because they:
  - **Load research content into lead** (team-plan Stage 5b: `cat "$research_path"`).
  - **Perform inline synthesis** (team-plan Stages 7-8: reading candidate plans, comparing, synthesizing).
  - **Write artifacts directly** (team-plan Stage 9: writes the final plan).
  - **Read plan file into lead** (team-implement Stage 5: reads plan for phase extraction).
  - **Write summary directly** (team-implement Stage 11: writes implementation summary).
- **Fix requires synthesis-agent delegation** (same pattern as task 609).
- **Risk**: Medium. Synthesis logic is more complex for planning (trade-off analysis) and implementation (wave tracking, debugger coordination). The synthesis-agent needs to handle plan-specific synthesis (not just research merging).

**Group C: Routing-Only Orchestrator** (skill-orchestrator)
- Already context-protective by design — it's a routing skill with no artifact work.
- Stage 1 reads full `task_data` from state.json via jq (acceptable — ~200 tokens).
- Stage 4 prepares context package but doesn't read artifacts.
- **Already compliant.** No changes needed beyond optionally verifying jq extraction patterns.
- **Risk**: None.

### 3. Shared Infrastructure Already in `skill-base.sh`

The following functions already exist and are used by Group A skills:

| Function | Purpose | Used By |
|----------|---------|---------|
| `skill_validate_input` | Task lookup + terminal state check | All 3 thin wrappers |
| `skill_preflight_update` | Status update + extension hook | All 3 thin wrappers |
| `skill_create_postflight_marker` | Marker file creation | All 3 thin wrappers |
| `skill_read_artifact_number` | Unified artifact numbering | All 3 thin wrappers |
| `skill_read_metadata` | Parse .return-meta.json | All 3 thin wrappers |
| `skill_validate_artifact` | Non-blocking format check | All 3 thin wrappers |
| `skill_postflight_update` | Status transition + hook | All 3 thin wrappers |
| `skill_increment_artifact_number` | Advance sequence (research only) | skill-researcher |
| `skill_propagate_memory_candidates` | Memory candidate append | skill-researcher, skill-implementer |
| `skill_link_artifacts` | State.json + TODO.md linking | All 3 thin wrappers |
| `skill_cleanup` | Remove temp files | All 3 thin wrappers |
| `skill_write_orchestrator_handoff` | Orchestrate handoff JSON | All 3 thin wrappers |

**Gap**: Team skills (Group B) do NOT use `skill-base.sh` at all. They duplicate input validation, status updates, artifact linking, and cleanup inline. Task 610 should migrate them to use `skill-base.sh` functions.

### 4. New Shared Infrastructure Opportunities

**A. `skill_inject_context_refs` function (new)**

All three Group A skills have a Stage 4b that reads format specs via `cat`. A shared function could eliminate this pattern:

```bash
# Instead of: format_content=$(cat .claude/context/formats/report-format.md)
# Use @-reference in subagent prompt: "Follow the format in @.claude/context/formats/report-format.md"
```

This isn't a new function — it's a prompt pattern change. No script needed; just edit the prompt templates.

**B. Memory retrieval delegation**

Currently all three Group A skills run `memory-retrieve.sh` in the lead (Stage 4a). The context-protective pattern says subagents should handle memory. Two approaches:

1. **Pass keywords to subagent, subagent calls memory-retrieve.sh** — cleanest, but requires agent prompt changes.
2. **Keep lead retrieval but cap output** — simpler, but still violates the budget.

Recommendation: Option 1 (delegate to subagent). The subagent prompt already receives task_type and description.

**C. Team skill migration to `skill-base.sh`**

Group B skills should adopt `skill-base.sh` for Stages 1-3 and postflight (Stages 10-15). This would reduce their line counts significantly and ensure consistency.

### 5. Batch vs. Incremental Strategy

**Recommendation: Two-phase incremental approach.**

**Phase 1: Group A (Low Risk, High Confidence)**
- Refactor skill-researcher, skill-planner, skill-implementer simultaneously.
- Changes are mechanical: replace `cat` with @-references, move memory retrieval to subagent prompt.
- These skills share nearly identical structure; changes to one trivially apply to the others.
- Test: Run `/research`, `/plan`, `/implement` on a test task after each change.

**Phase 2: Group B (Medium Risk)**
- Refactor skill-team-plan and skill-team-implement.
- These require synthesis-agent delegation (reusing the agent created in task 609).
- Migrate to skill-base.sh functions for shared stages.
- Test: Run `/plan --team` and `/implement --team` to verify.

**Skip Group C**: skill-orchestrator is already compliant.

**Rationale against big-bang refactor:**
- Group B changes are structurally different from Group A (synthesis delegation vs. simple @-reference substitution).
- Group A changes can be verified independently with single-agent commands.
- If Phase 1 introduces an issue, it's isolated from team mode.
- Task 609 showed that a focused refactor (one skill) completes faster than estimated.

### 6. Edge Cases and Exceptions

**Q: What if a skill needs more than 5k tokens above baseline?**

skill-implementer's Stage 4d collects prior implementation context (up to 500 lines) for tasks in "partial" or "implementing" state. This is a legitimate need — the subagent needs continuation context.

**Solution**: Pass the prior context paths as @-references rather than reading content. The subagent reads them in its own context:
```
Read prior context from:
- @specs/NNN_SLUG/summaries/01_summary.md
- @specs/NNN_SLUG/handoffs/03_handoff.md (latest 3)
- @specs/NNN_SLUG/progress/latest.json
```

**Q: How should skill-team-plan handle synthesis?**

skill-team-plan performs plan synthesis inline (Stages 7-9):
1. Reads candidate plans from teammates
2. Compares phase structures and trade-offs
3. Writes final synthesized plan

This should be delegated to `synthesis-agent` with a plan-specific prompt variant:
- Pass candidate plan file paths as @-references
- Synthesis agent reads candidates, performs trade-off analysis, writes final plan
- Lead receives compact summary (~200 words)

The `synthesis-agent` already supports this (task 609 created it as reusable). It just needs plan-specific synthesis instructions in the dispatch prompt.

**Q: How should skill-team-implement handle summary creation?**

skill-team-implement writes the implementation summary (Stage 11) after all waves complete. This is the lead reading phase results and writing a summary — a clear violation.

Options:
1. **Fork a summary agent** after all waves complete — reads phase results, writes summary.
2. **Have the last phase implementer write the summary** — breaks the wave pattern.
3. **Use synthesis-agent** with implementation-specific instructions.

Recommendation: Option 3 (reuse synthesis-agent). It receives phase result paths, writes unified summary.

**Q: What about the wave execution loop in skill-team-implement?**

The wave execution loop (Stage 8) is legitimate orchestration — it tracks which waves are complete and spawns the next wave. It doesn't read artifact content. The plan file reading in Stage 5 (for phase extraction) is the actual violation.

For Stage 5, the lead needs to parse phase dependencies from the plan text. This is a borderline case — the lead needs to know phase structure to orchestrate waves, but reading the full plan (potentially 200+ lines) into lead context is expensive.

**Mitigation**: Fork a "plan parser" agent that reads the plan and returns only the dependency graph (a compact JSON structure ~200 tokens). The lead then uses this graph for wave calculation without needing the full plan text.

---

## Recommended Approach

### Two-Phase Implementation Plan

**Phase 1: Group A Thin Wrappers** (skill-researcher, skill-planner, skill-implementer)
- Remove Stage 4b (`cat` format spec) — replace with @-reference in subagent prompt
- Move Stage 4a (memory retrieval) to subagent prompt — pass keywords, subagent calls memory-retrieve.sh
- Remove Stage 4c (roadmap `cat`) — pass @specs/ROADMAP.md reference to subagent
- Rewrite Stage 4d (prior implementation context) — pass paths as @-references instead of reading content
- Estimated effort: 2-3 hours total (all three skills share the same changes)

**Phase 2: Group B Team Skills** (skill-team-plan, skill-team-implement)
- Migrate to skill-base.sh functions for input validation, postflight, cleanup
- Delegate plan synthesis to synthesis-agent (skill-team-plan Stages 7-9)
- Delegate summary creation to synthesis-agent (skill-team-implement Stage 11)
- Extract plan parsing to a fork agent for dependency graph (skill-team-implement Stage 5)
- Estimated effort: 4-6 hours total (more complex than Group A)

**Total estimated effort**: 6-9 hours across both phases.

---

## Evidence/Examples

### Evidence 1: skill-researcher format injection (current violation)

```bash
# Stage 4b (CURRENT — 131 lines injected into lead context):
format_content=$(cat .claude/context/formats/report-format.md)
# Then injected into Agent prompt as <artifact-format-specification> block

# AFTER (0 lines in lead context):
# In Agent prompt: "Follow the format in @.claude/context/formats/report-format.md"
```

### Evidence 2: skill-team-plan inline synthesis (current violation)

Stages 7-9 currently have the lead:
1. Read candidate-a.md, candidate-b.md, risk-analysis.md
2. Compare phase structures inline
3. Write synthesized plan file

This is the exact same anti-pattern that task 609 fixed in skill-team-research. The synthesis-agent can handle plan synthesis just as it handles research synthesis.

### Evidence 3: skill-base.sh already covers most postflight

skill-base.sh provides 12 functions covering the full skill lifecycle. Group B team skills currently duplicate ~150 lines of postflight logic that could be replaced with ~10 lines of skill-base.sh function calls.

---

## Confidence Level: High

- Group A changes are mechanical and low-risk.
- Group B changes follow the proven pattern from task 609.
- skill-orchestrator is already compliant (no changes needed).
- The synthesis-agent created in task 609 is explicitly designed for reuse.
- Two-phase incremental approach isolates risk.

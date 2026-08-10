# Research Report: Task #610 — Sweep Skills Context Protection

- **Task**: 610 - Apply context-protective pattern to remaining skills
- **Started**: 2026-05-23T00:00:00Z
- **Completed**: 2026-05-23T00:30:00Z
- **Effort**: 0.5 hours (synthesis)
- **Dependencies**: 608 (context-protective lead pattern), 609 (skill-team-research reference implementation)
- **Sources/Inputs**:
  - Teammate A findings: `specs/610_sweep_skills_context_protection/reports/01_teammate-a-findings.md`
  - Teammate B findings: `specs/610_sweep_skills_context_protection/reports/01_teammate-b-findings.md`
  - Teammate C findings (critic): `specs/610_sweep_skills_context_protection/reports/01_teammate-c-findings.md`
  - Reference: `skill-team-research/SKILL.md` (post-task 609 refactor, 615 lines)
  - Task context: `specs/TODO.md` entries for tasks 608, 609, 610
- **Artifacts**: `specs/610_sweep_skills_context_protection/reports/01_team-research.md`
- **Standards**: report-format.md, artifact-formats.md

---

## Executive Summary

- **Seven skills require context-protection refactoring**, not six: the original target list missed `skill-reviser` (489 lines), which has the same format-injection violation as the other Group A thin wrappers.
- **Three distinct violation types** span all targets: (1) format spec injection via `cat` into lead context, (2) memory retrieval captured in lead context, (3) inline synthesis where the lead reads and processes large content files directly.
- **skill-team-plan is the highest-priority target** with the most severe violations — its inline synthesis pattern (Stages 7-9) plus research content injection can accumulate 6,000-13,000 tokens above baseline, matching the pre-task-609 state of skill-team-research.
- **skill-orchestrator is low-priority** (not zero): its "Read specs/state.json" and "Read TODO.md" instructions are informal (not bash blocks) and can be fixed with a single jq example clarification.
- **Two-phase incremental strategy** is the correct approach: Group A thin wrappers (mechanical @-reference substitutions) in Phase 1, Group B team skills (synthesis delegation) in Phase 2.
- **synthesis-agent from task 609 is reusable** for both skill-team-plan and skill-team-implement with plan-specific and implementation-specific dispatch prompt variants.

---

## Context & Scope

Task 608 established the context-protective lead pattern: leads must not read large files into their context; they should use jq extractions, pass @-references to subagents, and delegate synthesis to fork agents. Task 609 applied this pattern to `skill-team-research` as the reference implementation, eliminating 50,000+ tokens of context bloat via synthesis delegation.

Task 610 extends this refactor to all remaining skills. Three teammates independently audited the target skills. This report synthesizes their findings, resolves conflicts, incorporates critic corrections, and provides a unified implementation strategy.

**Scope**: Skills `.claude/skills/{name}/SKILL.md` for: skill-researcher, skill-implementer, skill-planner, skill-reviser (added by Critic), skill-orchestrator, skill-team-plan, skill-team-implement. Extension skills (skill-neovim-research, skill-nix-research, etc.) were spot-checked by Teammate C and verified clean.

---

## Findings

### Per-Skill Violation Audit

#### 1. skill-team-plan (598 lines) — Priority 1

**Violations**: 3

| # | Location | Violation | Token Impact | Fix |
|---|----------|-----------|-------------|-----|
| 1 | Stage 5b, ~line 183 | `research_content=$(cat "$research_path")` — research report read into lead then injected into each teammate prompt (multiplied by team_size) | 2,000-5,000 tokens in lead; 4,000-15,000 tokens across teammate spawns | Replace with `@{research_path}` @-reference in teammate prompt |
| 2 | Stages 7-9 | Lead performs inline synthesis: reads candidate plans, compares, writes final plan | 4,000-8,000 tokens (two or three full plan candidates) | Delegate to synthesis-agent with @-references to candidate files |
| 3 | Missing | No documented context budget or MUST NOT (Context Protection) section | N/A | Add budget documentation matching skill-team-research format |

**Critic Clarification**: Teammate A's estimate of ~13,000 tokens upper bound is reasonable if the executor reads full candidate files during Stage 8. However, the skill text at Stage 8 (lines 335-349) uses prose instructions ("Lead synthesizes plan candidates: 1. Compare phase structures..."), not explicit `cat`/Read calls. The token cost depends on executor interpretation. The violation intent is unambiguous even if the mechanism is implicit.

**Estimated bloat**: 6,000-13,000 tokens above baseline.
**Target after fix**: ~1,500 tokens (matching skill-team-research).

---

#### 2. skill-researcher (242 lines) — Priority 2

**Violations**: 3 confirmed + 1 borderline

| # | Location | Violation | Token Impact | Fix |
|---|----------|-----------|-------------|-----|
| 1 | Stage 4b, ~line 144 | `format_content=$(cat .claude/context/formats/report-format.md)` — 131 lines injected | ~1,048 tokens | Replace `<artifact-format-specification>` block with: `"Follow the format in @.claude/context/formats/report-format.md"` |
| 2 | Stage 4c, ~line 71 | `roadmap_context=$(cat specs/ROADMAP.md)` — full roadmap injected | ~240 tokens (grows over time) | Replace `<roadmap-context>` block with: `"Read @specs/ROADMAP.md for project context if it exists."` |
| 3 | Stage 4a, ~lines 59-62 | `memory_context=$(bash .claude/scripts/memory-retrieve.sh ...)` — output captured in lead | 200-800 tokens (variable) | Remove Stage 4a; add to subagent prompt: `"If memory extension available, run: bash .claude/scripts/memory-retrieve.sh '{DESCRIPTION}' '{TASK_TYPE}' '{focus}'"` |
| B | Stage 4d, ~lines 84-107 | Prior implementation context: `cat "$f"` for each prior artifact | Up to 4,000 tokens (500 lines, truncated) | Pass artifact directory path as @-references; let subagent read them in its own context |

**Estimated bloat**: 2,000-6,000 tokens above baseline.
**Target after fix**: ~500 tokens.

---

#### 3. skill-reviser (489 lines) — Priority 3 [ADDED BY CRITIC]

**Violations**: 1

| # | Location | Violation | Token Impact | Fix |
|---|----------|-----------|-------------|-----|
| 1 | ~line 185 | `format_content=$(cat .claude/context/formats/plan-format.md)` — same pattern as Group A | ~1,088 tokens (136 lines) | Replace with `@.claude/context/formats/plan-format.md` @-reference in subagent prompt |

**Note**: Neither Teammate A nor B identified skill-reviser. Teammate C confirmed the violation by direct file inspection. At 489 lines, it is the third-largest skill in the target set and should not be omitted.

**Estimated bloat**: ~1,088 tokens above baseline.
**Target after fix**: ~400 tokens.

---

#### 4. skill-team-implement (677 lines) — Priority 4

**Violations**: 2-3 (one borderline)

| # | Location | Violation | Severity | Fix |
|---|----------|-----------|---------|-----|
| 1 | Stage 5, ~lines 183-224 | Plan file read into lead for phase/dependency extraction | Borderline-legitimate | Fork a "plan parser" agent that returns only the dependency graph (~200 tokens compact JSON); lead never holds full plan text |
| 2 | Stage 7, ~lines 268-299 | Phase details `{phase_details}`, `{steps_from_plan}`, etc. embedded in teammate prompts from plan text | Medium | Pass `@{plan_path}` to teammates with: "Read the plan and implement Phase {P}." |
| 3 | Stage 11 | Lead reads phase results to write implementation summary (inline synthesis) | High | Delegate to synthesis-agent with phase result file paths as @-references |

**Teammate alignment**: Both A and B flag Violations 1 and 2. Teammate C flags Violation 3 (Stage 11 summary creation) as missed by Teammate A. This is confirmed: summary creation is a legitimate inline synthesis violation.

**Estimated bloat**: 1,300-3,900 tokens above baseline (not accounting for Stage 11).
**Target after fix**: ~800 tokens.

---

#### 5. skill-planner (215 lines) — Priority 5

**Violations**: 2

| # | Location | Violation | Token Impact | Fix |
|---|----------|-----------|-------------|-----|
| 1 | Stage 4b, ~lines 114-115 | `format_content=$(cat .claude/context/formats/plan-format.md)` — 136 lines | ~1,088 tokens | Replace with `@.claude/context/formats/plan-format.md` @-reference |
| 2 | Stage 4a, ~lines 62-65 | `memory_context=$(bash .claude/scripts/memory-retrieve.sh ...)` | 200-800 tokens | Delegate to subagent |

**Already compliant**: Passes `plan_path` and `research_path` as paths only (not content). Postflight uses skill-base.sh functions correctly.

**Estimated bloat**: 1,300-1,900 tokens above baseline.
**Target after fix**: ~400 tokens.

---

#### 6. skill-implementer (363 lines) — Priority 6

**Violations**: 2

| # | Location | Violation | Token Impact | Fix |
|---|----------|-----------|-------------|-----|
| 1 | Stage 4b, ~lines 119-120 | `format_content=$(cat .claude/context/formats/summary-format.md)` — 59 lines | ~472 tokens | Replace with `@.claude/context/formats/summary-format.md` @-reference |
| 2 | Stage 4a, ~lines 64-67 | `memory_context=$(bash .claude/scripts/memory-retrieve.sh ...)` | 200-800 tokens | Delegate to subagent |

**Already compliant**: Has explicit "No Source Reading Before Delegation" boundary. Uses jq for metadata extraction. Continuation loop uses only extracted fields, not file content.

**Estimated bloat**: 700-1,300 tokens above baseline.
**Target after fix**: ~400 tokens.

---

#### 7. skill-orchestrator (128 lines) — Priority 7

**Violations**: 2 (minor, ambiguous)

| # | Location | Violation | Severity | Fix |
|---|----------|-----------|---------|-----|
| 1 | ~line 32 | `"1. Read specs/state.json"` — prose instruction, not bash code | Low — depends on executor interpretation | Replace instruction with jq extraction example: `jq -r --argjson num "$N" '.active_projects[] | select(.project_number == $num)' specs/state.json` |
| 2 | ~line 34 | `"4. Read TODO.md for additional context if needed"` — conditional | Low — already guarded by "if needed" | Tighten to: `"Grep for task {N} section in specs/TODO.md if state.json lacks the description"` |

**Teammate conflict resolved**: Teammate B says "skip entirely — already compliant." Teammate C says "low-priority, not zero-priority." Resolution: Include a minimal jq clarification (5-minute change) in Phase 1 as a quick addendum, not a separate phase.

**Estimated bloat**: Up to ~1,600 tokens if executor reads full files; near-zero if executor interprets instruction correctly.

---

### Unified Violation Summary Table

| Skill | Lines | Violations | Max Bloat | Priority | Phase |
|-------|-------|-----------|-----------|----------|-------|
| skill-team-plan | 598 | 3 | ~13,000 | 1 | 2 |
| skill-researcher | 242 | 3+1 borderline | ~6,000 | 2 | 1 |
| skill-reviser | 489 | 1 | ~1,088 | 3 | 1 |
| skill-team-implement | 677 | 3 | ~3,900+ | 4 | 2 |
| skill-planner | 215 | 2 | ~1,900 | 5 | 1 |
| skill-implementer | 363 | 2 | ~1,300 | 6 | 1 |
| skill-orchestrator | 128 | 2 (minor) | ~1,600 | 7 | 1 (addendum) |

---

### Prioritization and Phasing Strategy

#### Phase 1: Group A — Thin Wrappers (Low Risk)

**Skills**: skill-researcher, skill-planner, skill-implementer, skill-reviser, skill-orchestrator (addendum)

**Rationale**: All Group A violations are mechanical. The same `cat` -> @-reference substitution pattern applies to every skill. Changes are independently testable with single-agent commands.

**Change pattern** (applies to all 4 core Group A skills):
1. Remove Stage 4b entirely (the `cat` of format spec into `format_content`)
2. Remove Stage 4a entirely (the `memory-retrieve.sh` call into `memory_context`)
3. In the subagent prompt, replace `<artifact-format-specification>` block with: `"Follow the format in @.claude/context/formats/{type}-format.md"`
4. In the subagent prompt, replace `<memory-context>` block with: `"If memory extension available, run: bash .claude/scripts/memory-retrieve.sh '{DESCRIPTION}' '{TASK_TYPE}' '{focus}'"`

**skill-researcher additional changes** (Stages 4c and 4d):
5. Remove Stage 4c (`cat specs/ROADMAP.md`): replace `<roadmap-context>` block with `"Read @specs/ROADMAP.md for project context if it exists."`
6. Rewrite Stage 4d (prior context collection): replace `cat "$f"` with artifact directory path @-references in delegation JSON

**skill-orchestrator addendum**:
7. Replace "1. Read specs/state.json" with a jq extraction example
8. Replace "4. Read TODO.md for additional context if needed" with a targeted grep suggestion

**Estimated effort**: 2-3 hours total for all Group A skills.
**Verification**: Run `/research N`, `/plan N`, `/implement N`, `/revise N` on a test task after each change.

#### Phase 2: Group B — Team Skills (Medium Risk)

**Skills**: skill-team-plan, skill-team-implement

**Rationale**: These require synthesis-agent delegation, a more complex architectural change. The synthesis-agent from task 609 is explicitly designed for reuse — it already handles research synthesis and can handle plan synthesis and implementation summary creation with plan-specific dispatch prompts.

**skill-team-plan change pattern**:
1. Remove Stage 5b (`research_content=$(cat "$research_path")`); replace with `@{research_path}` @-reference in teammate prompts
2. Replace Stages 7-9 (inline synthesis) with synthesis-agent dispatch:
   - Stage 7: Collect only file paths of completed candidate plans
   - Stage 8: Dispatch synthesis-agent with candidate paths as @-references and plan-specific synthesis instructions
   - Stage 9: Removed (synthesis-agent writes the final plan)
3. Add context budget documentation and MUST NOT (Context Protection) section

**skill-team-implement change pattern**:
1. Stage 5: Fork a "plan parser" agent that reads the plan and returns only the dependency graph as compact JSON (~200 tokens); discard full plan text
2. Stage 7: Pass `@{plan_path}` to teammates ("Read the plan and implement Phase {P}") instead of embedding extracted phase details
3. Stage 11: Delegate summary creation to synthesis-agent with phase result file paths as @-references

**Additional for both team skills**: Migrate to `skill-base.sh` functions for Stages 1-3 (input validation, status update) and postflight stages. Currently both team skills duplicate ~150 lines of logic already in skill-base.sh.

**Estimated effort**: 4-6 hours total for both team skills.
**Verification**: Run `/plan N --team` and `/implement N --team` on a test task.

---

### Shared Infrastructure Opportunities

#### 1. synthesis-agent (Already Exists — Reuse)

Created in task 609 as a named reusable agent. Works for research synthesis now. Needs plan-specific and implementation-specific dispatch prompt variants:

- **Plan synthesis variant**: "Read each candidate plan... perform trade-off analysis... write the unified plan to {path}... follow @.claude/context/formats/plan-format.md"
- **Implementation summary variant**: "Read phase results at {paths}... write unified implementation summary to {path}... follow @.claude/context/formats/summary-format.md"

No changes to the synthesis-agent itself are needed — the dispatch prompt in the calling skill provides the specialization.

#### 2. skill-base.sh (Already Exists — Extend to Team Skills)

Provides 12 functions covering the full skill lifecycle (input validation, status updates, artifact linking, cleanup). Currently used by all Group A thin wrappers but NOT by Group B team skills. Phase 2 should migrate skill-team-plan and skill-team-implement to use skill-base.sh.

Estimated line count reduction from migration: 150 lines across both team skills.

#### 3. plan-parser agent (New — Optional)

A lightweight fork agent that reads a plan file and returns only the dependency graph as compact JSON. Useful for skill-team-implement Stage 5, where the lead needs phase dependency information for wave calculation but should not retain the full plan text.

Prototype: 20-line agent that reads a plan, extracts phase numbers and `depends_on` fields, returns compact JSON (~200 tokens). If the plan format is consistent, this can be a bash jq extraction instead of an agent fork.

**Recommendation**: Attempt jq extraction first. If the plan format is too irregular for jq, implement the agent fork.

#### 4. @-reference prompt pattern (Convention — No New Code)

The universal pattern for format spec delivery: `"Follow the format in @.claude/context/formats/{type}-format.md"`. This replaces all `cat` format injection across all seven skills. No new script or function needed — just a prompt convention change.

---

## Decisions

- **skill-reviser added to target list**: Teammate C's identification of the format-injection violation at line 185 is confirmed. The task description's original six-skill list was incomplete. skill-reviser is a Phase 1 target.
- **skill-orchestrator: clarify, do not skip**: Teammate B's "skip entirely" recommendation is rejected in favor of Teammate C's "low-priority one-line fix" assessment. The ambiguous prose instructions will be tightened with a jq extraction example.
- **synthesis-agent reuse over new agent**: Both skill-team-plan and skill-team-implement will reuse the existing synthesis-agent (dispatch prompt specialization only). No new agent files needed.
- **skill-base.sh migration included in Phase 2**: Team skills currently duplicate ~150 lines of postflight logic already in skill-base.sh. Phase 2 migration is part of the refactor, not a separate task.
- **Plan parser as jq-first**: Implement plan dependency extraction as a jq one-liner first; fall back to fork agent only if plan format is insufficiently regular.
- **Extension skills verified clean**: skill-neovim-research, skill-nix-research, skill-neovim-implementation, skill-nix-implementation, skill-spawn each have only heredoc `cat` calls (postflight marker creation). No violations. Not included in target list.

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Subagent memory retrieval differs from lead retrieval | Low | Medium | Test memory retrieval in subagent context on a real task; verify memories surface correctly |
| skill-reviser subagent (@-reference format) not loaded if reviser-agent doesn't support @-references | Low | High | Check reviser-agent model and tool access; confirm @-reference resolution works |
| synthesis-agent plan synthesis produces lower quality than inline synthesis | Medium | Medium | Task 609 showed synthesis-agent produces high quality; plan synthesis adds trade-off analysis requirement — verify with a test run of `/plan N --team` |
| skill-team-implement wave logic breaks if plan parser returns incomplete dependency graph | Medium | High | Write unit test (or manual verification) for plan parser before deploying; keep old plan reading as fallback |
| Concurrent Phase 1 and Phase 2 changes introduce merge conflicts | Low | Low | Complete Phase 1 first (commit), then start Phase 2 |
| skill-orchestrate (autonomous lifecycle skill) vs skill-orchestrator (routing skill) — Teammate C flagged both need checking | Low | Medium | Verify skill-orchestrate does not have equivalent violations; add to Phase 1 audit if needed |

**skill-orchestrate gap**: Teammate C noted that neither A nor B checked `skill-orchestrate` (the autonomous lifecycle `/orchestrate` command skill) — only `skill-orchestrator` (the routing skill) was audited. The plan should include a quick audit of skill-orchestrate before Phase 1 implementation begins.

---

## Context Extension Recommendations

- **Topic**: Context-protective lead pattern application status per skill
- **Gap**: No central registry tracking which skills have been audited and whether they comply with the pattern defined in task 608
- **Recommendation**: Update `.claude/context/patterns/context-protective-lead.md` (created in task 608) with a "Compliance Status" table listing all skills and their status (compliant / violation-fixed / pending)

---

## Appendix

### Reference Implementation
- `skill-team-research/SKILL.md` (post-task-609 refactor, 615 lines) — demonstrates all fix patterns in production use
- Context budget: ~1,500 tokens above baseline (documented in lines 606-615)

### Verified Clean Skills (Extension Skills)
- `skill-neovim-research/SKILL.md` — only heredoc cat (postflight marker)
- `skill-nix-research/SKILL.md` — only heredoc cat (postflight marker)
- `skill-spawn/SKILL.md` — only heredoc cat (marker + git commit)

### Universal Fix Patterns

**Pattern 1: Format spec -> @-reference**
```
# BEFORE:
format_content=$(cat .claude/context/formats/{type}-format.md)
# ... injected as <artifact-format-specification> block in prompt

# AFTER:
# Stage 4b removed entirely
# In subagent prompt: "Follow the format in @.claude/context/formats/{type}-format.md"
```

**Pattern 2: Memory retrieval -> subagent**
```
# BEFORE:
memory_context=$(bash .claude/scripts/memory-retrieve.sh "$DESCRIPTION" "$TASK_TYPE" "" 2>/dev/null)
# ... injected as <memory-context> block in prompt

# AFTER:
# Stage 4a removed entirely
# In subagent prompt: "If memory extension available, run: bash .claude/scripts/memory-retrieve.sh '{DESCRIPTION}' '{TASK_TYPE}' '{focus}'"
```

**Pattern 3: Research content -> @-reference (team skills)**
```
# BEFORE:
research_content=$(cat "$research_path")
# ... injected into each teammate prompt

# AFTER:
# Stage 5b removed entirely
# In teammate prompt: "Read the research report at @{research_path} for context."
```

**Pattern 4: Inline synthesis -> synthesis-agent delegation**
```
# BEFORE (Stages 7-9):
# Lead reads candidate files, compares, writes final artifact

# AFTER (Stages 7-8):
# Stage 7: collect file paths only
# Stage 8: dispatch synthesis-agent(candidate_paths, output_path, format_ref)
# synthesis-agent returns <200-word summary; lead proceeds to postflight
```

### Teammate Conflict Resolution Log

| Conflict | A Position | B Position | C Position | Resolution |
|----------|-----------|-----------|-----------|------------|
| skill-orchestrator scope | Fix 2 violations | Skip entirely | Low-priority, 1-line fix | Minimal jq clarification in Phase 1 addendum |
| skill-reviser inclusion | Not identified | Not identified | Add to target list | Confirmed — included in Phase 1 |
| skill-team-plan token estimate | ~13,000 upper bound | Agrees it's highest priority | Upper bound plausible but Stage 8 is prose not explicit cat | Accept ~6,000-13,000 range; fix is warranted regardless |
| skill-team-implement Stage 11 | Not flagged | Flagged (summary creation) | Confirmed B's finding | Include Stage 11 as Violation 3 |

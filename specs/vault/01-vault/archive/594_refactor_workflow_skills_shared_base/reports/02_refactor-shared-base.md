# Research Report: Task #594

**Task**: 594 - Refactor workflow skills to shared base pattern
**Started**: 2026-05-22T06:00:00Z
**Completed**: 2026-05-22T06:30:00Z
**Effort**: 1.5 hours
**Dependencies**: Task 593 (completed), Task 598 (not_started — design constraint)
**Sources/Inputs**:
- `.claude/skills/skill-researcher/SKILL.md` (558 lines)
- `.claude/skills/skill-planner/SKILL.md` (490 lines)
- `.claude/skills/skill-implementer/SKILL.md` (629 lines)
- `.claude/skills/skill-reviser/SKILL.md` (489 lines)
- `.claude/docs/architecture/architecture-spec.md` — Component 2
- `specs/594_refactor_workflow_skills_shared_base/reports/01_seed-research.md`
- `specs/593_extract_shared_workflow_utilities/summaries/02_extract-shared-utilities-summary.md`
- `.claude/scripts/command-gate-in.sh`, `command-gate-out.sh`, `postflight-workflow.sh`, `parse-command-args.sh`
**Artifacts**:
- `specs/594_refactor_workflow_skills_shared_base/reports/02_refactor-shared-base.md`
**Standards**: status-markers.md, artifact-management.md, report-format.md

---

## Executive Summary

- Task 593 is complete and delivered 4 reusable scripts (`parse-command-args.sh`, `command-gate-in.sh`, `command-gate-out.sh`, `postflight-workflow.sh`) that task 594's `skill-base.sh` can directly call or source.
- Skill duplication across the 3 core skills is ~210 lines each (11 structurally identical stage blocks), confirmed by direct inspection; ~80% of each skill file is a verbatim copy of the other two.
- Task 598 (`not_started`) introduces a design risk: the architecture spec says 594 depends on 598 for context budget constraints, but 598 is a constraint-enforcement task rather than a prerequisite API — skill-base.sh can be implemented without 598 by reserving a `SKILL_CONTEXT_BUDGET` variable hook for 598 to populate later.
- The 11 proposed `skill-base.sh` functions map cleanly to existing stage blocks; parameters that vary between skills are narrow and well-defined (operation type, agent type, completion status, artifact directory).
- The continuation loop in skill-implementer (Stages 5c, 6b, 7 partial/status, and orchestrator_mode detection) is the only substantively unique block that cannot be shared without conditional complexity — it should remain inline.
- Recommended implementation strategy: refactor skill-researcher first (simplest), validate, then apply the same pattern to skill-planner and skill-implementer.

---

## Context & Scope

Task 594 implements Component 2 of the unified workflow architecture (`architecture-spec.md`): creating `.claude/scripts/skill-base.sh` as a sourced shell library, then refactoring the 3 core skills to source it, reducing each skill from ~500-630 lines down to 130-200 lines of unique logic.

Task 593 is a prerequisite and is fully complete. It delivered the 4 shared command scripts that skill-base.sh will call. Task 598 (`not_started`) is listed as a dependency in the architecture spec's dependency ordering (Wave 2, before Wave 3 where 594 sits), but the actual constraint is "skill-base.sh must know each skill's context tier and budget cap" — this can be handled by defining a `SKILL_CONTEXT_BUDGET` variable that defaults to 8000 tokens for sonnet workers and is overridable by task 598's tier enforcement later.

Scope of this research: analyze each skill's existing code, identify which blocks are shared vs. unique, map to the 11 proposed functions, define parameters, estimate savings, and identify risks.

---

## Findings

### Dependency Status

**Task 593** (completed): All 4 scripts exist and are usable:
- `parse-command-args.sh` — sourced, exports TASK_NUMBERS, flags (90 lines)
- `command-gate-in.sh` — sourced, exports SESSION_ID, TASK_TYPE, PROJECT_NAME, etc. (60 lines)
- `command-gate-out.sh` — subprocess, defensive status correction (70 lines)
- `postflight-workflow.sh` — subprocess, unified postflight for all 3 operations (105 lines)

**Task 598** (not_started): Defines the four-tier context loading model and budget caps (sonnet ≤ 8K, opus ≤ 15K, haiku ≤ 2K). Does NOT define an API that skill-base.sh must call — it primarily classifies existing context index entries and moves agent-level context out of command files. The only hook task 594 needs is a `SKILL_CONTEXT_BUDGET` variable that defaults to the appropriate tier budget and can be overridden later.

### Line-by-Line Duplication Analysis

Comparing the three skill files reveals these near-verbatim blocks (lines are approximate):

| Stage Block | researcher | planner | implementer | Identical? |
|-------------|-----------|---------|-------------|-----------|
| Stage 1: Input validation (jq lookup, terminal guard) | L47-62 | L47-68 | L44-64 | ~95% identical |
| Stage 2: Preflight status update (update-task-status.sh call) | L70-74 | L74-80 | L72-80 | ~90% identical |
| Stage 3: Create postflight marker (.postflight-pending) | L83-98 | L88-106 | L88-103 | ~95% identical |
| Stage 3a: Calculate artifact number | L106-120 | L114-136 | L112-133 | ~80% identical (diverges: planner uses `next-1`, researcher uses `next`) |
| Stage 4a: Memory retrieval (memory-retrieve.sh call) | L133-141 | L150-158 | L145-158 | ~98% identical |
| Stage 4b: Format injection (cat format file) | L263-269 | L209-215 | L195-200 | ~99% identical (only format file path differs) |
| Stage 6: Read metadata file (.return-meta.json) | L369-382 | L286-301 | L316-339 | ~90% identical (implementer adds extra fields) |
| Stage 6a: Validate artifact (validate-artifact.sh) | L388-399 | L307-318 | L344-357 | ~95% identical |
| Stage 7: Postflight status update | L406-419 | L322-333 | L380-392 | ~80% identical (implementer adds 4 extra steps) |
| Stage 7a: Memory candidates propagation | L427-436 | absent | L404-414 | ~95% identical where present |
| Stage 8: Link artifacts (jq + link-artifact-todo.sh) | L449-470 | L343-364 | L508-529 | ~90% identical (artifact type differs) |
| Stage 9/10: Cleanup (rm marker files) | L476-482 | L381-389 | L550-559 | ~98% identical |

**Unique blocks per skill** (what MUST remain skill-specific):

**skill-researcher** unique:
- Stage 4c: Roadmap consultation (reads ROADMAP.md and injects it)
- Stage 4d: Prior implementation context collection (finds summaries/handoffs/progress/plans, 35 lines)
- Stage 5: `subagent_type: "general-research-agent"` with roadmap + prior context injection
- Stage 7 Step 2: Increment `next_artifact_number` (research is the only skill that advances the sequence)
- The `focus_prompt` field in delegation context (researcher-specific)
- Stage 10 return message format

**skill-planner** unique:
- Prior plan discovery (find latest existing plan to pass as reference)
- Delegation context fields: `research_path`, `prior_plan_path`, `roadmap_flag`, `roadmap_path`
- Stage 5: `subagent_type: "planner-agent"`
- Stage 9: Git commit (planner has a git commit stage; researcher does NOT)
- Planner uses `next_artifact_number - 1` (not increment) for artifact numbering

**skill-implementer** unique:
- Stage 4 (plan path discovery and delegation context with `plan_path`)
- Stage 5: `subagent_type: "general-implementation-agent"`
- Stage 5a: Validate subagent return format (JSON parse check)
- Stage 5c: Continuation loop initialization (`continuation_count`, `.continuation-loop-guard`)
- **Entire continuation loop** (Stages 6b, 7 partial branch, handoff detection, successor dispatch)
- Stage 7 Steps 2-5: completion_summary, roadmap_items, remove_from_recommended_order
- Stage 10: Additional `.continuation-loop-guard` cleanup

### The 11 Proposed skill-base.sh Functions

Mapping each function to the shared code blocks:

**1. `skill_validate_input "$task_number"`**
- Maps to: Stage 1 in all three skills
- Variance: None — all three use identical jq lookup + terminal status guard
- Export: TASK_DATA, TASK_TYPE, TASK_STATUS, PROJECT_NAME, DESCRIPTION, PADDED_NUM
- Note: Can use `command-gate-in.sh`'s `gate_in()` function directly or inline equivalent

**2. `skill_preflight_update "$task_number" "$operation" "$session_id"`**
- Maps to: Stage 2 in all three skills
- Variance: None — all three call `update-task-status.sh preflight $task_number {operation} $session_id`
- The `operation` parameter differs: "research" / "plan" / "implement"

**3. `skill_create_postflight_marker "$padded_num" "$project_name" "$session_id" "$skill_name" "$operation"`**
- Maps to: Stage 3 in all three skills
- Variance: Only `skill` and `operation` fields in the JSON differ
- The `mkdir -p` and heredoc pattern are identical

**4. `skill_read_artifact_number "$task_number" "$padded_num" "$project_name" "$mode"`**
- Maps to: Stage 3a in all three skills
- Variance: Mode parameter — "research" (use current `next_artifact_number`) vs "plan/implement" (use `next_artifact_number - 1`)
- Fallback directory path differs: "reports/" for researcher, "plans/" for planner, "summaries/" for implementer
- Export: ARTIFACT_NUMBER, ARTIFACT_PADDED

**5. `skill_read_metadata "$padded_num" "$project_name"`**
- Maps to: Stage 6 in all three skills
- Variance: implementer reads extra fields (phases_completed, phases_total, completion_data, handoff_path)
- Approach: Export base fields (status, artifact_path, artifact_type, artifact_summary, memory_candidates); implementer reads extra fields inline after calling the shared function

**6. `skill_validate_artifact "$status" "$artifact_path" "$artifact_kind"`**
- Maps to: Stage 6a in all three skills
- Variance: `artifact_kind` differs ("report" / "plan" / "summary") for validate-artifact.sh
- Also, the success status that triggers validation differs ("researched" / "planned" / "implemented|partial")
- Approach: Pass both the trigger status and artifact kind as parameters

**7. `skill_postflight_update "$task_number" "$operation" "$session_id" "$status"`**
- Maps to: Stage 7 main path in all three skills (success branch only)
- Variance: None for the core `update-task-status.sh postflight` call
- Additional implementer steps (completion_summary, roadmap_items, etc.) stay inline

**8. `skill_increment_artifact_number "$task_number"`**
- Maps to: Stage 7 Step 2 in skill-researcher only
- Variance: Not applicable — this function is researcher-only; planner/implementer skip it
- The architecture spec lists it as a shared function but it should be called conditionally

**9. `skill_propagate_memory_candidates "$task_number" "$memory_candidates"`**
- Maps to: Stage 7a in researcher and implementer (planner does not have this)
- Variance: None — identical jq append pattern
- Note: Planner does not call this; researcher and implementer do

**10. `skill_link_artifacts "$task_number" "$artifact_path" "$artifact_type" "$artifact_summary" "$link_before_label"`**
- Maps to: Stage 8 in all three skills
- Variance: The two-step jq pattern is identical; only the `artifact_type` filter and `link-artifact-todo.sh` arguments differ
- The `link_before_label` parameter ('**Plan**' / '**Description**' / '**Description**') also varies

**11. `skill_cleanup "$padded_num" "$project_name"`**
- Maps to: Stage 9/10 cleanup in all three skills
- Variance: Implementer adds `.continuation-loop-guard` removal — either pass a flag or implementer handles inline

### Hook Points (What MUST Remain Skill-Specific)

Based on the architecture spec and code analysis, each skill retains exactly:

**skill-researcher hook points**:
- Stage 4a: Memory retrieval (unique: passes `focus_prompt` as 3rd arg)
- Stage 4b: Read `report-format.md`
- Stage 4c: Roadmap consultation
- Stage 4d: Prior implementation context collection (~35 lines)
- Stage 5 delegation context: researcher-specific fields (focus_prompt, roadmap_path, metadata_file_path, prior_implementation_context)
- Stage 5 prompt construction: roadmap + prior context injection blocks
- Stage 7 post-success: call `skill_increment_artifact_number`
- subagent_type: "general-research-agent"

**skill-planner hook points**:
- Stage 4a: Memory retrieval (unique: no `focus_prompt` arg)
- Stage 4b: Read `plan-format.md`
- Stage 4 (prior plan discovery): `ls -1 plans/*.md | sort -V | tail -1`
- Stage 5 delegation context: planner-specific fields (research_path, prior_plan_path, roadmap_flag, roadmap_path)
- Stage 9: Git commit (absent in researcher; present in planner/implementer)
- subagent_type: "planner-agent"

**skill-implementer hook points**:
- Stage 4a: Memory retrieval
- Stage 4b: Read `summary-format.md`
- Stage 4 (plan path): find latest plan file
- Stage 5 delegation context: implementer-specific `plan_path` field
- Stage 5a: Validate subagent return format (JSON parse check)
- Stage 5c: Continuation loop initialization with `orchestrator_mode` detection
- **Entire continuation loop** (biggest unique block; ~130 lines)
- Stage 7 Steps 2-5: completion_summary, roadmap_items, resume_phase, remove_from_recommended_order
- Stage 9: Git commit
- Stage 10: Additional `.continuation-loop-guard` cleanup
- subagent_type: "general-implementation-agent"

### Parameter Variance Table

| Parameter | researcher | planner | implementer |
|-----------|-----------|---------|-------------|
| operation | "research" | "plan" | "implement" |
| subagent_type | "general-research-agent" | "planner-agent" | "general-implementation-agent" |
| completion_status | "researched" | "planned" | "implemented" |
| artifact_dir | reports/ | plans/ | summaries/ |
| artifact_kind | "report" | "plan" | "summary" |
| format_file | report-format.md | plan-format.md | summary-format.md |
| artifact_number_mode | "current" (use as-is) | "prev" (next-1) | "prev" (next-1) |
| increment_sequence | yes | no | no |
| propagate_memory | yes | no | yes |
| git_commit | no | yes | yes |
| continuation_loop | no | no | yes |
| link_before_label | '**Research**' | '**Plan**' | '**Summary**' |

### Size Reduction Estimates

Based on direct line counting of shared vs. unique blocks:

| Skill | Current Lines | Shared (to extract) | Unique (to keep) | Target |
|-------|--------------|---------------------|------------------|--------|
| skill-researcher | 558 | ~375 | ~183 | ~150-183 |
| skill-planner | 490 | ~330 | ~160 | ~130-160 |
| skill-implementer | 629 | ~280 | ~349 | ~200-250 |

Note: skill-implementer's large unique block (continuation loop + implementer-specific postflight steps) means its reduction is proportionally less than the other two. The architecture spec targets 200 lines; achieving that requires carefully keeping the continuation loop compact.

**skill-base.sh size estimate**: ~120-150 lines (11 functions, each 10-15 lines average, plus sourcing of `postflight-workflow.sh` and `command-gate-in.sh`).

### Task 598 Dependency Analysis

The architecture spec says task 594 depends on task 598 for "context budget constraints." Examining the constraint:

- The constraint is: skills must not exceed budget caps (sonnet ≤ 8K tokens, opus ≤ 15K tokens)
- Task 598 will audit context index entries and define tier classifications
- Task 594 only needs to know: "which budget cap applies to this skill's agent?"

**Unblocking approach**: Define `SKILL_CONTEXT_BUDGET` as a variable in skill-base.sh with a default value. Researcher/implementer default to 8000 (sonnet workers), planner defaults to 15000 (opus). When task 598 establishes formal tier enforcement, it can either (a) have `skill-base.sh` read from a config file, or (b) override the variable before the shared base runs.

This means task 594 can proceed without waiting for task 598, as long as the budget cap enforcement is isolated to a single overridable variable rather than embedded as hard-wired logic.

### Potential Issues with skill-base.sh Sourcing

The architecture spec says skills will "source" `skill-base.sh`. However, SKILL.md files are markdown documents read by Claude, not executed shell scripts. The sourcing pattern shown in the architecture spec and seed research is pseudocode indicating that the skill's stage implementations should call these functions rather than literally `source`-ing a bash file.

The implementation pattern should be:
- `skill-base.sh` is a shell library containing functions, called from bash code blocks within the SKILL.md
- Each SKILL.md contains bash code blocks that call the shared functions (using `bash .claude/scripts/skill-base.sh` is not correct — it must use `source` for variable exports, or the function calls must be embedded inline)
- The preferred pattern: skill-base.sh defines functions; each SKILL.md's bash blocks source the file once and then call individual functions

This is a key implementation detail: the sourcing must happen in the same Bash tool invocation as the function calls, since exported variables don't persist across separate Bash invocations in Claude Code.

---

## Decisions

- **skill_validate_input can reuse gate_in()**: Since `command-gate-in.sh` already exports the needed variables, `skill_validate_input` can source that script rather than duplicating the logic.
- **Continuation loop stays inline in skill-implementer**: The loop is ~130 lines of tightly coupled logic (handoff detection, continuation count tracking, successor spawning) that would become more complex if abstracted. Cost of abstraction exceeds benefit.
- **task 598 is not a hard dependency**: skill-base.sh can default context budget to 8K/15K by agent type and expose a `SKILL_CONTEXT_BUDGET` override variable for task 598 to configure later.
- **Scope excludes skill-reviser**: The architecture spec lists only the 3 core skills (researcher, planner, implementer) as targets. skill-reviser (489 lines) may follow in a separate task.
- **Git commit function not in shared base**: Planner and implementer each have a git commit stage; researcher does not. The commit command is a 3-line block — simpler to keep inline than to abstract.

---

## Recommendations

1. **Create skill-base.sh immediately** (no blocker from 598): Implement the 11 functions as a shell library. Use `SKILL_CONTEXT_BUDGET="${SKILL_CONTEXT_BUDGET:-8000}"` for the budget variable with `8000`/`15000` defaults.

2. **Refactor skill-researcher first**: It has the cleanest structure (no continuation loop, no git commit stage). Validate size reduction and functional equivalence before touching the other two.

3. **Refactor skill-planner second**: Moderate complexity. Unique elements are prior plan discovery and git commit.

4. **Refactor skill-implementer last**: Most complex due to continuation loop. After the shared functions are established from the first two refactors, identify exactly which lines can move out and which must stay.

5. **Functional equivalence test**: Before deleting any original code from a skill, run a research or plan operation using the refactored skill and verify that state.json and TODO.md are updated correctly.

6. **Preserve extension compatibility**: Check that skill-neovim-research, skill-nix-research, skill-neovim-implementation, and skill-nix-implementation still work after each core skill refactor. These extension skills may pattern-match on stage numbering.

7. **Document sourcing semantics**: Add a comment in skill-base.sh clarifying that it must be sourced within the same Bash tool invocation as the function calls.

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Extension skills break after refactor | High | Test extension skills after each core skill change; fix before proceeding |
| Sourcing pattern requires single-invocation Bash blocks | Medium | Document in skill-base.sh header; test with a single concatenated bash block |
| Continuation loop complexity increases if abstracted | Medium | Keep continuation loop inline in implementer; only abstract the non-looping stages |
| task 598 makes breaking changes to context budget enforcement | Low | Isolate budget hook as a single overridable variable (`SKILL_CONTEXT_BUDGET`) |
| skill-base.sh functions accumulate skill-specific parameters | Low | Enforce minimum parameter count per function; reject >5 parameters |
| Variable name collisions between sourced scripts | Low | Use prefixed variable names (SKILL_* prefix) in skill-base.sh |

---

## Context Extension Recommendations

- **Topic**: Sourcing semantics for skill-base.sh
- **Gap**: No existing context file explains how shell libraries interact with Claude Code's Bash tool invocation boundaries.
- **Recommendation**: Add a note in `.claude/context/patterns/file-metadata-exchange.md` or a new `shell-library-sourcing.md` clarifying that `source` and function calls must occur in the same Bash invocation.

---

## Appendix

### Architecture Spec Reference

Component 2 in `.claude/docs/architecture/architecture-spec.md` defines the full target architecture. The 11 functions listed there match the 11 stages identified in this analysis. The spec's "Hook Points for Skill-Specific Logic" section confirms the 4 categories of unique logic (context collection, delegation context, agent invocation, continuation loop).

### Task 593 Deliverables Used by Task 594

- `command-gate-in.sh` — `skill_validate_input` can source this script's `gate_in()` function
- `command-gate-out.sh` — provides defensive correction pattern; skill-base.sh may call this at cleanup
- `postflight-workflow.sh` — provides unified status update + artifact linking; skill-base.sh may delegate to this
- `parse-command-args.sh` — skills do not parse args (skills receive pre-parsed delegation context), so this is NOT used by skill-base.sh

### Stage Numbering Inconsistency

The three skills have inconsistent stage numbering (researcher: 4a/4b/4c/4d; implementer: 5a/5b/5c; planner: no sub-stages). The refactoring is an opportunity to standardize on a single numbering scheme. Proposed:
- Stage 1: Input validation
- Stage 2: Preflight update
- Stage 3: Postflight marker creation
- Stage 3a: Artifact number calculation
- Stage 4: Context collection (skill-specific)
- Stage 4a: Memory retrieval (skill-specific, always present)
- Stage 4b: Format injection (skill-specific)
- Stage 4c+: Additional context (researcher only)
- Stage 5: Subagent invocation (skill-specific)
- Stage 5b: Self-execution fallback
- Stage 6: Read metadata
- Stage 6a: Validate artifact
- Stage 7: Postflight status update
- Stage 7a: Memory candidates propagation
- Stage 8: Link artifacts
- Stage 9: Git commit (planner/implementer only)
- Stage 10: Cleanup
- Stage 11: Return summary

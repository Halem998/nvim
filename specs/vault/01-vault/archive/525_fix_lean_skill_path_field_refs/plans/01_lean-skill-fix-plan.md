# Implementation Plan: Task #525

- **Task**: 525 - Fix lean skill path and field references
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: `specs/525_fix_lean_skill_path_field_refs/reports/01_lean-skill-audit.md`
- **Artifacts**: `specs/525_fix_lean_skill_path_field_refs/plans/01_lean-skill-fix-plan.md` (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Fix two categories of legacy references in `.opencode/extensions/lean/skills/` SKILL.md files: (1) obsolete `OC_` prefix in specs paths that breaks postflight metadata parsing and git commits, and (2) deprecated `.language` field checks that should use `.task_type` to align with core skill routing. Changes are surgical string replacements with exact old/new pairs. The `.claude/` tree already contains corrected copies and requires only verification.

### Research Integration

The audit found **6 `OC_` references** and **2 `.language` references** in the `.opencode/` tree. The `.claude/` tree already has the fixes plus additional improvements (Stage 4b self-execution fallback, explicit Postflight section, MUST NOT boundaries). This plan applies the minimum viable fixes to `.opencode/` to restore correctness, without porting the broader `.claude/` refactor to avoid scope creep.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Remove all `OC_` prefix references from `.opencode/` lean skill files
- Replace all `.language` field extraction/checks with `.task_type` in `.opencode/` lean skill files
- Verify `.claude/` lean skill files are already correct
- Confirm no regressions via grep after edits

**Non-Goals**:
- Porting `.claude/` improvements (Stage 4b, Postflight section, MUST NOT boundaries) to `.opencode/`
- Replacing manual `jq` with centralized `update-task-status.sh`
- Adding postflight marker files or cleanup stages
- Modifying agent files (`lean-research-agent.md`, `lean-implementation-agent.md`)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Multi-match edit failure due to repeated phrases | Low | Low | Use unique 3-line contexts for every oldString |
| `padded_num` variable undefined in skill context | Medium | Low | Out of scope; variable is used but not declared by either skill. Note in verification. |
| .claude/ and .opencode/ drift further apart after partial fix | Low | Low | Document remaining gaps for future task. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases 1 and 2 can execute in parallel (they touch different files). Phase 3 depends on both.

---

### Phase 1: Fix `.opencode/` skill-lean-research/SKILL.md [COMPLETED]

**Goal**: Remove `OC_` prefix and replace `.language` with `.task_type` in the research skill.

**Tasks**:
- [ ] **Edit 1/5** — Line 43: field extraction
  - **File**: `.opencode/extensions/lean/skills/skill-lean-research/SKILL.md`
  - **oldString**:
    ```
    # Extract fields
    language=$(echo "$task_data" | jq -r '.language // "general"')
    status=$(echo "$task_data" | jq -r '.status')
    ```
  - **newString**:
    ```
    # Extract fields
    task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
    status=$(echo "$task_data" | jq -r '.status')
    ```

- [ ] **Edit 2/5** — Line 85: delegation context JSON
  - **File**: `.opencode/extensions/lean/skills/skill-lean-research/SKILL.md`
  - **oldString**:
    ```
    "task_context": {
      "task_number": N,
      "task_name": "{project_name}",
      "description": "{description}",
      "language": "lean"
    },
    ```
  - **newString**:
    ```
    "task_context": {
      "task_number": N,
      "task_name": "{project_name}",
      "description": "{description}",
      "task_type": "${task_type}"
    },
    ```

- [ ] **Edit 3/5** — Line 124: metadata file path in Stage 5
  - **File**: `.opencode/extensions/lean/skills/skill-lean-research/SKILL.md`
  - **oldString**:
    ```bash
    metadata_file="specs/OC_${padded_num}_${project_name}/.return-meta.json"
    ```
  - **newString**:
    ```bash
    metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"
    ```

- [ ] **Edit 4/5** — Line 184: git add reports path
  - **File**: `.opencode/extensions/lean/skills/skill-lean-research/SKILL.md`
  - **oldString**:
    ```bash
    git add \
      "specs/OC_${padded_num}_${project_name}/reports/" \
      "specs/OC_${padded_num}_${project_name}/.return-meta.json" \
    ```
  - **newString**:
    ```bash
    git add \
      "specs/${padded_num}_${project_name}/reports/" \
      "specs/${padded_num}_${project_name}/.return-meta.json" \
    ```

- [ ] **Edit 5/5** — Update trigger condition comment (line 17)
  - **File**: `.opencode/extensions/lean/skills/skill-lean-research/SKILL.md`
  - **oldString**:
    ```
    - Task language is "lean4" or "lean" (either accepted)
    ```
  - **newString**:
    ```
    - Task type is "lean4" or "lean" (either accepted)
    ```

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.opencode/extensions/lean/skills/skill-lean-research/SKILL.md`

**Verification**:
- `grep -n "OC_" .opencode/extensions/lean/skills/skill-lean-research/SKILL.md` → no output
- `grep -n "\.language" .opencode/extensions/lean/skills/skill-lean-research/SKILL.md` → no output
- `grep -n "task_type" .opencode/extensions/lean/skills/skill-lean-research/SKILL.md` → lines 43, 85 match

---

### Phase 2: Fix `.opencode/` skill-lean-implementation/SKILL.md [COMPLETED]

**Goal**: Remove `OC_` prefix and replace `.language` with `.task_type` in the implementation skill.

**Tasks**:
- [ ] **Edit 1/6** — Line 30: update comment
  - **File**: `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md`
  - **oldString**:
    ```
    - Task language must be "lean"
    ```
  - **newString**:
    ```
    - Task type must be "lean" or "lean4"
    ```

- [ ] **Edit 2/6** — Line 44: field extraction
  - **File**: `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md`
  - **oldString**:
    ```
    # Extract fields
    language=$(echo "$task_data" | jq -r '.language // "general"')
    status=$(echo "$task_data" | jq -r '.status')
    project_name=$(echo "$task_data" | jq -r '.project_name')

    # Validate language (accept both "lean" and "lean4")
    if [ "$language" != "lean" ] && [ "$language" != "lean4" ]; then
      return error "Task $task_number is not a Lean task"
    fi
    ```
  - **newString**:
    ```
    # Extract fields
    task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
    status=$(echo "$task_data" | jq -r '.status')
    project_name=$(echo "$task_data" | jq -r '.project_name')

    # Validate task_type (accept both "lean" and "lean4")
    if [ "$task_type" != "lean" ] && [ "$task_type" != "lean4" ]; then
      return error "Task $task_number is not a Lean task (task_type: $task_type)"
    fi
    ```

- [ ] **Edit 3/6** — Line 91: delegation context JSON
  - **File**: `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md`
  - **oldString**:
    ```
    "task_context": {
      "task_number": N,
      "task_name": "{project_name}",
      "description": "{description}",
      "language": "lean"
    },
    ```
  - **newString**:
    ```
    "task_context": {
      "task_number": N,
      "task_name": "{project_name}",
      "description": "{description}",
      "task_type": "${task_type}"
    },
    ```

- [ ] **Edit 4/6** — Line 131: metadata file path in Stage 5
  - **File**: `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md`
  - **oldString**:
    ```bash
    metadata_file="specs/OC_${padded_num}_${project_name}/.return-meta.json"
    ```
  - **newString**:
    ```bash
    metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"
    ```

- [ ] **Edit 5/6** — Line 17: trigger condition comment
  - **File**: `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md`
  - **oldString**:
    ```
    - Task language is "lean4" or "lean" (either accepted)
    ```
  - **newString**:
    ```
    - Task type is "lean4" or "lean" (either accepted)
    ```

- [ ] **Edit 6/6** — Lines 215-216: git add paths
  - **File**: `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md`
  - **oldString**:
    ```bash
    git add \
      "Theories/" \
      "specs/OC_${padded_num}_${project_name}/summaries/" \
      "specs/OC_${padded_num}_${project_name}/plans/" \
      "specs/TODO.md" \
      "specs/state.json"
    ```
  - **newString**:
    ```bash
    git add \
      "Theories/" \
      "specs/${padded_num}_${project_name}/summaries/" \
      "specs/${padded_num}_${project_name}/plans/" \
      "specs/TODO.md" \
      "specs/state.json"
    ```

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md`

**Verification**:
- `grep -n "OC_" .opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md` → no output
- `grep -n "\.language" .opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md` → no output
- `grep -n "task_type" .opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md` → lines 44, 49, 91 match

---

### Phase 3: Cross-Tree Verification & Regression Test [COMPLETED]

**Goal**: Confirm `.claude/` copies are already correct and ensure no `OC_` or `.language` references remain anywhere in the lean extension.

**Tasks**:
- [ ] Verify `.claude/` skill-lean-research has no `OC_` references
- [ ] Verify `.claude/` skill-lean-implementation has no `OC_` references
- [ ] Verify `.claude/` skill-lean-research has no `.language` references
- [ ] Verify `.claude/` skill-lean-implementation has no `.language` references
- [ ] Run global grep across both trees:
  ```bash
  grep -rn "OC_" .opencode/extensions/lean/skills/
  grep -rn "OC_" .claude/extensions/lean/skills/
  grep -rn "\.language" .opencode/extensions/lean/skills/
  grep -rn "\.language" .claude/extensions/lean/skills/
  ```
- [ ] Confirm all 4 files pass syntax/structure sanity check (no broken bash blocks, no unclosed quotes)
- [ ] Document remaining gaps found during research (postflight markers, cleanup, centralized script) in a NOTE comment at the bottom of both `.opencode/` skill files for future task reference

**Timing**: 15 minutes

**Depends on**: 1, 2

**Files to modify**:
- None (read-only verification, optional NOTE addition)

**Verification**:
- All four `grep` commands above return zero matches
- `wc -l` on modified files shows no unexpected line count changes (should remain ~231 and ~263)

---

## Testing & Validation

- [ ] `grep -rn "OC_" .opencode/extensions/lean/skills/` → 0 matches
- [ ] `grep -rn "\.language" .opencode/extensions/lean/skills/` → 0 matches
- [ ] `grep -rn "task_type" .opencode/extensions/lean/skills/skill-lean-research/SKILL.md` → matches on lines 43, 85
- [ ] `grep -rn "task_type" .opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md` → matches on lines 44, 49, 91
- [ ] `.claude/` lean skills already pass all grep checks (confirmed during planning)

## Artifacts & Outputs

- Modified `.opencode/extensions/lean/skills/skill-lean-research/SKILL.md`
- Modified `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md`
- Optional: NOTE comments documenting deferred improvements

## Rollback/Contingency

If any edit fails or causes unexpected side effects:
1. Revert the specific file via `git checkout -- <path>`
2. Re-apply edits one at a time, verifying after each
3. If variable name change (`language` → `task_type`) causes shell logic issues, revert to `language` but keep `.task_type` jq extraction as a fallback

## Deferred Improvements (Out of Scope)

The research report identified these gaps that should be addressed in a future task:
1. **Missing postflight marker files** (`.postflight-pending`, `.continuation-loop-guard`)
2. **Missing cleanup stage** (removing `.return-meta.json`, temp files after postflight)
3. **Manual jq updates** instead of centralized `.opencode/scripts/update-task-status.sh`
4. **No terminal-state blocking** (`completed`, `abandoned`, `expanded`)
5. **Hardcoded `Theories/` assumption** in zero-debt gate

The `.claude/` tree has already resolved items 1-4 in its versions; porting these improvements to `.opencode/` is a separate refactor task.

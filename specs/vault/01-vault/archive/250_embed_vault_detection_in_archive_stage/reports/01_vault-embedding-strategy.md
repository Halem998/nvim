# Research Report: Vault Detection Embedding Strategy

- **Task**: 250 - Embed vault detection as inline check within skill-todo archive stage
- **Started**: 2026-03-19T00:00:00Z
- **Completed**: 2026-03-19T01:00:00Z
- **Effort**: 1 hour
- **Dependencies**: None
- **Sources/Inputs**:
  - `.claude/skills/skill-todo/SKILL.md` - Current skill structure (21 stages)
  - `.claude/commands/todo.md` - Command wrapper and vault operation steps
  - `.claude/rules/state-management.md` - Vault schema and trigger conditions
  - `.claude/skills/skill-status-sync/SKILL.md` - Direct execution pattern reference
- **Artifacts**: This report
- **Standards**: report-format.md, status-markers.md, artifact-management.md

## Executive Summary

- The current skill-todo has 21 stages with vault detection in Stage 11, which LLMs skip due to perceived irrelevance
- LLM stage-skipping is a fundamental behavior: models cherry-pick stages they deem relevant to the immediate task
- The failed test execution ran stages 2, 3, 5, 10, 18, 20, 21 while skipping 4, 6-9, 11-17, 19 - all skipped stages were optional or conditional
- **Root cause**: Stages with conditional logic (e.g., "skip if X") are particularly vulnerable to being skipped entirely
- **Solution**: Embed vault detection as a non-skippable sub-step within Stage 10 (ArchiveTasks) with output that forces model action

## Context & Scope

Task 249 attempted to fix vault detection by:
1. Renumbering stages (adding explicit Stage 11 for vault detection)
2. Adding transition directives ("**TRANSITION**: After archiving tasks, continue to Stage 11...")

This approach failed because LLMs don't execute stages sequentially - they parse the entire document and select stages they perceive as relevant to the current task context.

**Research Questions**:
1. Where should vault detection be embedded to prevent skipping?
2. How can bash scripts output mandatory directives?
3. What stage consolidation would reduce skip opportunities?
4. How can pre-commit validation serve as a safety net?

## Findings

### 1. Current SKILL.md Structure Analysis

The skill-todo SKILL.md contains 21 stages:

| Stage | Name | Skip Risk | Analysis |
|-------|------|-----------|----------|
| 1 | ParseArguments | Low | Always runs - entry point |
| 2 | ScanTasks | Low | Core functionality |
| 3 | DetectOrphans | Medium | Optional - can be empty |
| 4 | DetectMisplaced | High | Optional - rarely triggered |
| 5 | ScanRoadmap | Medium | Non-meta only |
| 6 | ScanMetaSuggestions | High | Meta-only |
| 7 | HarvestMemories | High | Optional enhancement |
| 8 | DryRunOutput | Medium | Flag-dependent |
| 9 | InteractivePrompts | Medium | Depends on detections |
| 10 | ArchiveTasks | Low | Core functionality |
| 11-15 | Vault stages | **HIGH** | Conditional (>1000 threshold) |
| 16 | UpdateRoadmap | Medium | Optional annotations |
| 17 | UpdateREADME | High | Optional suggestions |
| 18 | UpdateChangelog | Medium | Core tracking |
| 19 | CreateMemories | High | Optional enhancement |
| 20 | GitCommit | Low | Final action |
| 21 | OutputResults | Low | Summary - always runs |

**Key Insight**: Stages 11-15 (vault operations) all have "skip if..." conditions, making them prime candidates for LLM skipping.

### 2. LLM Stage-Skipping Behavior Pattern

**Observed execution** (from failed test):
- Executed: 2, 3, 5, 10, 18, 20, 21
- Skipped: 4, 6, 7, 8, 9, 11-17, 19

**Pattern analysis**:
- Core stages (2, 3, 10, 18, 20, 21) always execute
- Stages with "skip if" or "if X then proceed" conditionals are high risk
- Separate stages for detection -> confirmation -> execution chain break easily

**Root cause**: When a stage starts with "skip if vault_needed = false", the model can decide to skip the entire stage upfront rather than executing to determine the condition.

### 3. Bash Enforcement Pattern

The key insight is that bash scripts can output text that the model MUST respond to. When a script outputs a directive, the model incorporates it into its reasoning.

**Proposed pattern**:
```bash
# Inline within Stage 10 process
next_num=$(jq -r '.next_project_number' specs/state.json)
if [ "$next_num" -gt 1000 ]; then
  echo "===== VAULT THRESHOLD EXCEEDED ====="
  echo "next_project_number: $next_num"
  echo "ACTION REQUIRED: Vault operation must be performed"
  echo "===== VAULT THRESHOLD EXCEEDED ====="
fi
```

When this output appears in the bash result, the model sees it as immediate context requiring action.

### 4. Stage Consolidation Strategy

**Target**: Reduce from 21 stages to ~12 stages

**Consolidation Map**:

| Original | Consolidated | New Stage |
|----------|--------------|-----------|
| 1 | ParseArguments | Stage 1 |
| 2-4 | ScanAndDetect (tasks + orphans + misplaced) | Stage 2 |
| 5-6 | ScanReferences (roadmap + meta suggestions) | Stage 3 |
| 7 | HarvestMemories | Stage 4 |
| 8 | DryRunOutput | Stage 5 |
| 9 | InteractivePrompts | Stage 6 |
| 10-15 | **ArchiveAndVault** (archive + inline vault) | **Stage 7** |
| 16-17 | UpdateDocuments (roadmap + README) | Stage 8 |
| 18 | UpdateChangelog | Stage 9 |
| 19 | CreateMemories | Stage 10 |
| 20 | GitCommit (with pre-commit validation) | Stage 11 |
| 21 | OutputResults | Stage 12 |

**Critical Change**: Stage 7 (ArchiveAndVault) contains:
1. Archive tasks to completed_projects
2. **INLINE**: Check next_project_number threshold
3. **INLINE**: If threshold exceeded, execute vault sub-steps as part of same stage
4. Track orphans and misplaced directories

### 5. Embedded Vault Detection Design

**Location**: Within consolidated "ArchiveAndVault" stage, immediately after archive operations.

**Structure**:
```
<stage id="7" name="ArchiveAndVault">
  <action>Archive tasks and handle vault if threshold exceeded</action>
  <process>
    ## 7.1 Archive Tasks
    For each task to archive:
    1. Update specs/archive/state.json (add to completed_projects)
    2. Update specs/state.json (remove from active_projects)
    3. Update specs/TODO.md (remove archived entries)
    4. Move project directories to specs/archive/

    ## 7.2 Vault Threshold Check (MANDATORY)

    **EXECUTE IMMEDIATELY AFTER ARCHIVING**:
    ```bash
    # Read current next_project_number
    next_num=$(jq -r '.next_project_number' specs/state.json)

    # Threshold check with mandatory output
    if [ "$next_num" -gt 1000 ]; then
      echo "=========================================="
      echo "VAULT OPERATION REQUIRED"
      echo "next_project_number: $next_num (exceeds 1000)"
      echo "=========================================="
      echo ""
      echo "Tasks to renumber:"
      jq -r '.active_projects[] | select(.project_number > 1000) | "\(.project_number) -> \(.project_number - 1000): \(.project_name)"' specs/state.json
      echo ""
      echo "ACTION: Proceed to vault sub-steps 7.3-7.6"
      vault_needed="true"
    else
      echo "Vault check: next_project_number=$next_num (threshold: 1000)"
      vault_needed="false"
    fi
    ```

    ## 7.3 Vault Confirmation (if vault_needed=true)
    Use AskUserQuestion to confirm vault operation...

    ## 7.4 Create Vault (if user confirms)
    Move archive to vault, create meta.json...

    ## 7.5 Renumber Tasks (if vault approved)
    Update task numbers, directories, references...

    ## 7.6 Reset State (if vault approved)
    Reset next_project_number, update vault_history...
  </process>
</stage>
```

**Why This Works**:
- Vault check is embedded within the same stage as archiving
- The bash script outputs explicit directives the model sees
- Sub-steps 7.3-7.6 are part of the same stage, not separate stages to skip
- No "skip if vault_needed = false" at stage level - the condition is evaluated inline

### 6. Pre-Commit Safety Net Design

**Purpose**: Prevent committing changes if vault threshold exceeded and vault not performed.

**Implementation in GitCommit stage**:
```bash
# Pre-commit validation
next_num=$(jq -r '.next_project_number' specs/state.json)
vault_count=$(jq -r '.vault_count // 0' specs/state.json)
expected_vault_count=$((next_num > 1000 ? vault_count + 1 : vault_count))

if [ "$next_num" -gt 1000 ] && [ "$vault_count" -lt "$expected_vault_count" ]; then
  echo "=========================================="
  echo "COMMIT BLOCKED: VAULT NOT PERFORMED"
  echo "next_project_number: $next_num (exceeds 1000)"
  echo "vault_count: $vault_count (expected: $expected_vault_count)"
  echo "=========================================="
  echo ""
  echo "ERROR: Cannot commit while vault threshold exceeded"
  echo "ACTION: Return to Stage 7 and execute vault sub-steps"
  exit 1
fi
```

**Behavior**:
- If next_project_number > 1000 and vault_count wasn't incremented, commit fails
- Model sees explicit ERROR output and must address it
- This serves as a second line of defense if vault check was somehow bypassed

### 7. Failed Test Execution Analysis

**Stages executed**: 2, 3, 5, 10, 18, 20, 21
**Stages skipped**: 4, 6, 7, 8, 9, 11-17, 19

**Why each skipped stage was skipped**:

| Skipped Stage | Reason Likely Skipped |
|---------------|----------------------|
| 4 (DetectMisplaced) | No misplaced directories in test |
| 6 (ScanMetaSuggestions) | No meta tasks being archived |
| 7 (HarvestMemories) | Optional enhancement, perceived as non-essential |
| 8 (DryRunOutput) | --dry-run flag not present |
| 9 (InteractivePrompts) | No prompts triggered (no orphans, etc.) |
| 11-15 (Vault stages) | Conditional "skip if" at stage start |
| 17 (UpdateREADME) | No suggestions to apply |
| 19 (CreateMemories) | No memories selected |

**Key observation**: The model correctly executed core stages and skipped optional ones. The problem is vault stages (11-15) LOOK optional because they start with "skip if vault_needed = false".

## Decisions

1. **Embed vault detection within Stage 10 (ArchiveTasks)** rather than as separate stages
2. **Use bash output directives** that force model attention when threshold exceeded
3. **Consolidate stages** from 21 to ~12 to reduce skip opportunities
4. **Add pre-commit safety net** as final defense against vault bypass

## Recommendations

### Priority 1: Implement Embedded Vault Check (High Impact)

**Location**: Within current Stage 10 (ArchiveTasks), immediately after step 9 (current TRANSITION directive location)

**Replace**:
```markdown
9. **TRANSITION**: After archiving tasks, continue to Stage 11...
```

**With**:
```markdown
9. **Vault Threshold Check** (MANDATORY - DO NOT SKIP):
   Execute immediately after archive operations complete:

   ```bash
   next_num=$(jq -r '.next_project_number' specs/state.json)
   if [ "$next_num" -gt 1000 ]; then
     echo "===== VAULT THRESHOLD EXCEEDED ($next_num > 1000) ====="
     echo "MANDATORY ACTION: Execute vault sub-steps below"
   fi
   ```

   If output shows threshold exceeded:
   - Proceed to sub-step 9.1 (Vault Confirmation)
   - User confirmation via AskUserQuestion
   - Execute vault operations (create vault, renumber, reset state)
```

### Priority 2: Consolidate Vault Stages into Archive Stage

Remove separate stages 11-15 entirely. Move their content as sub-steps within Stage 10:

- 9.1: VaultConfirmation (current Stage 12)
- 9.2: CreateVault (current Stage 13)
- 9.3: RenumberTasks (current Stage 14)
- 9.4: ResetState (current Stage 15)

### Priority 3: Add Pre-Commit Validation

In Stage 20 (GitCommit), before `git add -A`:

```bash
# Safety check: vault performed if needed
next_num=$(jq -r '.next_project_number' specs/state.json)
if [ "$next_num" -gt 1000 ]; then
  echo "ERROR: Cannot commit - vault threshold exceeded"
  echo "next_project_number: $next_num"
  echo "Return to archive stage and perform vault operation"
  exit 1
fi
```

### Priority 4: Full Stage Consolidation (Future)

After validating embedded vault approach works:
1. Consolidate detection stages (3-4 -> single ScanAndDetect)
2. Consolidate reference scanning (5-6 -> single ScanReferences)
3. Consolidate document updates (16-17 -> single UpdateDocuments)

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Embedded sub-steps still skipped | Medium | High | Bash output forces attention; pre-commit safety net catches failures |
| Consolidation introduces bugs | Low | Medium | Test each consolidation independently |
| Pre-commit validation too strict | Low | Low | Include user bypass option with explicit confirmation |
| Stage renumbering breaks references | Low | Medium | Update all references in single atomic commit |

## Implementation Path

1. **Phase 1**: Embed vault check as sub-step 9 in Stage 10 (minimal change)
2. **Phase 2**: Add pre-commit safety net in Stage 20
3. **Phase 3**: Remove stages 11-15, move content to Stage 10 sub-steps
4. **Phase 4**: Full stage consolidation (21 -> 12 stages)

## Appendix

### A. Current Stage Flow (Problematic)

```
Stage 10 (ArchiveTasks)
         |
         v
   "TRANSITION: continue to Stage 11"  <-- Model can ignore this
         |
         v
Stage 11 (DetectVaultThreshold)  <-- "skip if vault_needed = false" -> skipped
         |
         v
Stage 12-15 -> All skipped due to vault_needed dependency
```

### B. Proposed Stage Flow (Embedded)

```
Stage 10 (ArchiveAndVault)
  |-- 1-8: Archive operations (existing)
  |-- 9: Vault Threshold Check (bash output: "VAULT REQUIRED" or "check passed")
  |     |
  |     +-- If threshold exceeded:
  |           |-- 9.1: VaultConfirmation (AskUserQuestion)
  |           |-- 9.2: CreateVault
  |           |-- 9.3: RenumberTasks
  |           |-- 9.4: ResetState
  |
Stage 11 (UpdateDocuments)
Stage 12 (GitCommit with pre-commit validation)
Stage 13 (OutputResults)
```

### C. Reference: Effective Stage Patterns

From skill-status-sync (direct execution):
- Single-stage execution with inline sub-operations
- All operations within one `<process>` block
- No "skip if" conditionals at stage level

From todo.md command:
- Steps 5.8.1-5.8.7 are sub-steps within Section 5 (archival)
- All vault operations grouped under "5.8. Vault Operation"
- No separate stages for detection vs confirmation vs execution

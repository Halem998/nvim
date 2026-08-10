# Research Report: Teammate B - Alternative Patterns for LLM Instruction Following

- **Task**: 250 - Embed vault detection as inline check within skill-todo archive stage
- **Angle**: Alternative patterns and prior art for ensuring LLMs follow skill instructions
- **Focus**: XML vs markdown structure, checklist enforcement, bash gating, agent framework patterns
- **Date**: 2026-03-19
- **Artifacts**: This report

---

## Key Findings

### 1. XML Stage Structure: `<checkpoint>` Tags Are the Critical Missing Ingredient

The existing SKILL.md uses XML `<stage>` elements but omits `<checkpoint>` tags entirely. The
`xml-structure.md` standard in this codebase (`.claude/context/core/standards/xml-structure.md`)
documents that **every stage must have a `<checkpoint>` attribute** to define completion criteria.
Without a checkpoint, a stage has no success condition the model can verify - making it easy to
skip.

The standard explicitly shows this as an anti-pattern:

```xml
<!-- WRONG: No checkpoint - model cannot verify completion -->
<stage id="11" name="DetectVaultThreshold">
  <action>Detect if vault operation is needed</action>
  <process>...</process>
</stage>
```

versus the correct form:

```xml
<!-- RIGHT: Checkpoint enforces verification -->
<stage id="11" name="DetectVaultThreshold">
  <action>Detect if vault operation is needed</action>
  <process>...</process>
  <checkpoint>Vault threshold checked, vault_needed flag set, execution continues to Stage 12</checkpoint>
</stage>
```

A `<checkpoint>` tag that names a concrete, verifiable artifact (a flag value, a file existence
check, a bash echo) gives the model a completion test it must pass before proceeding. The current
vault stages all lack checkpoints.

**Confidence**: High - documented standard already used by commands in this codebase.

---

### 2. The `CRITICAL` Annotation Pattern Already Works in todo.md

The `/todo` command uses a specific annotation on mandatory steps that SKILL.md completely lacks:

```markdown
**CRITICAL**: This step MUST be executed to identify orphaned directories.
```

and:

```markdown
**CRITICAL**: This is distinct from orphans - misplaced directories have correct state entries...
```

This inline bold annotation is effective because it appears as emphasis within step text rather
than as a skippable stage title. The LLM sees "CRITICAL: This step MUST be executed" as an
imperative before it parses the step content - not as a conditional to evaluate.

Contrast with SKILL.md Stage 11:

```xml
<stage id="11" name="DetectVaultThreshold">
  ...
  3. If vault not needed, skip to Stage 16 (UpdateRoadmap):
```

The very first conditional in Stage 11 normalizes skipping. Replacing the opening conditional with
a `CRITICAL: ALWAYS EXECUTE` guard changes the model's parsing of the entire stage.

**Confidence**: High - direct evidence from todo.md which successfully executes vault detection.

---

### 3. The Command (todo.md) Already Does Vault Detection Correctly; the Skill Does Not

A critical finding is the asymmetry between the `/todo` command and the `skill-todo` SKILL.md:

| Component | Vault Detection Location | Structure |
|-----------|--------------------------|-----------|
| `todo.md` command | Inline substep 5.8 under "Archive Tasks" section 5 | Flat markdown under `### 5.8.` |
| `skill-todo/SKILL.md` | Separate Stage 11 (`DetectVaultThreshold`) | Independent XML `<stage>` element |

The `/todo` command uses **flat section numbering** (5.8 is a subsection of 5, not an independent
stage). This structure makes vault detection feel like part of the archive operation, not a
separate optional task.

The SKILL.md converted this to an independent `<stage id="11">` which signals independence to the
LLM - making it skippable.

The fix is structural mirroring: the SKILL.md should match the todo.md command's architecture,
embedding vault as a subsection (e.g., `## 10.9` or a `<sub_step>` within Stage 10).

**Confidence**: High - direct comparison of two files handling the same operation differently.

---

### 4. Bash Gating: Output-Based Enforcement Is Already Validated in This Codebase

The `anti-stop-patterns.md` context file documents that **bash output is treated as immediate
context by the model**. This principle underlies the postflight control marker pattern:

```bash
# From postflight-control.md pattern - model MUST respond to file existence
touch ".claude/tmp/postflight_marker_${session_id}"
```

The same principle applies to vault detection. If a bash step outputs a high-signal message, the
model cannot treat it as optional context:

```bash
next_num=$(jq -r '.next_project_number' specs/state.json)
if [ "$next_num" -gt 1000 ]; then
  echo "=========================================="
  echo "VAULT REQUIRED: next_project_number=$next_num"
  echo "MANDATORY: Execute vault sub-steps before proceeding"
  echo "=========================================="
fi
echo "vault_check_complete: $vault_needed"
```

The last line (`vault_check_complete: true/false`) is the key: it creates a **state variable
visible in the bash output** that subsequent steps can reference. The model tracks this output as
context for the rest of the stage execution.

This is the same mechanism that makes `validate-plan-status.sh` scripts effective in the `/implement`
command - they emit gating output that the model cannot ignore.

**Confidence**: High - established pattern within this codebase.

---

### 5. Checklist Enforcement: Numbered Sub-Steps with Explicit Outputs

The `checkpoint-execution.md` context documents a three-checkpoint model (GATE IN, DELEGATE,
GATE OUT). Each gate has numbered operations with explicit outputs. The vault stages in SKILL.md
lack this structure.

A more effective pattern for mandatory multi-step operations is **numbered sub-steps with explicit
output requirements**:

```markdown
## 10.9 Vault Threshold Check (MANDATORY - ALWAYS EXECUTE AFTER ARCHIVING)

Execute immediately after step 10.8 completes. This is not conditional.

Sub-step 10.9.1: Read vault threshold
```bash
next_num=$(jq -r '.next_project_number' specs/state.json)
echo "vault_check: next_project_number=$next_num threshold=1000"
```
Output must include: `vault_check: next_project_number=N threshold=1000`

Sub-step 10.9.2: Set vault_needed flag
```bash
if [ "$next_num" -gt 1000 ]; then
  echo "VAULT_NEEDED=true"
  vault_needed=true
else
  echo "VAULT_NEEDED=false"
  vault_needed=false
fi
```
Output must be either: `VAULT_NEEDED=true` or `VAULT_NEEDED=false`
```

The "Output must include: ..." annotations create **verifiable completion criteria** - the same
function that `<checkpoint>` tags serve in the XML structure standard. They transform the step from
prose to a contract.

**Confidence**: Medium-High - extrapolated from checkpoint-execution.md patterns, not directly
observed.

---

### 6. Stage Consolidation Reduces Skip Surface Area

Teammate A identified LLM stage-skipping behavior. An alternative framing: the number of
independent `<stage>` elements directly correlates with skip opportunity surface area. Each
stage boundary is a point where the model can reassess relevance.

Vault stages 11-15 form a five-stage dependency chain where each stage starts with a condition:

```
Stage 11: "If vault not needed, skip to Stage 16"
Stage 12: "Skip if vault_needed = false"
Stage 13: "Skip if vault_approved = false"
Stage 14: "Skip if vault_approved = false"
Stage 15: "Skip if vault_approved = false"
```

Each "skip if" is an invitation to skip. The cumulative probability of executing all five stages
given the observed LLM behavior is low.

Consolidating to a single sub-step within Stage 10 eliminates four of those five skip boundaries.
The skip decision becomes binary (do the vault sub-step or not) rather than quintupled.

Research from the `skill-status-sync/SKILL.md` pattern confirms this: the most reliable skill in
the system uses **direct execution with no conditional stages** - it executes all operations within
a single logical flow.

**Confidence**: High - supported by observed skip behavior (stages 11-15 all skipped in test) and
skill-status-sync reference pattern.

---

### 7. Mandatory Step Signaling: Contrast with Optional Step Patterns

Examining how SKILL.md marks optional vs mandatory steps reveals an anti-pattern:

Optional stage (correctly marked):
```xml
<stage id="8" name="DryRunOutput">
  <action>Display dry run preview if requested</action>
  <process>
    If dry_run = true:
    1. Display comprehensive preview
    2. Exit after display
  </process>
</stage>
```

The "If dry_run = true" opener makes this stage's conditionality explicit and correct.

Vault stage (incorrectly structured like optional stage):
```xml
<stage id="11" name="DetectVaultThreshold">
  <action>Detect if vault operation is needed</action>
  <process>
    1. Read next_project_number...
    2. Check vault threshold...
    3. If vault not needed, skip to Stage 16 (UpdateRoadmap):
```

Stage 11 reads like another conditional-optional stage. The model cannot distinguish "skip when
condition not met" from "skip the whole stage if condition seems unlikely".

**Alternative pattern**: Invert the conditional framing for mandatory stages. Instead of:
- "If vault not needed, skip to Stage 16"

Use:
- "ALWAYS execute this check. When vault_needed=false, record result and continue."

This removes the skippable framing entirely and replaces it with always-execute semantics.

**Confidence**: High - direct analysis of stage structure in SKILL.md.

---

### 8. Inline State Variables as Execution Contracts

The `/todo` command uses a pattern not present in SKILL.md: tracking intermediate state in
variables that are referenced by name in later steps:

```bash
# Step 2.5 sets this
orphaned_in_specs=()
# ...populated...

# Step 4.5 references it
if orphaned directories were detected in Step 2.5:
```

This creates an implicit execution contract: if step 4.5 references data from step 2.5, the model
must have executed step 2.5 to have that data. The reference itself enforces the earlier step.

SKILL.md's vault stages do not use this pattern. Stage 11 creates `vault_needed` and
`renumber_mappings`, but Stages 12-15 reference them conditionally ("Skip if vault_needed =
false") rather than referencing them as required inputs.

Reframing Stage 12 as "Use vault_needed from Stage 11 to determine next action" creates a data
dependency that enforces Stage 11's execution.

**Confidence**: Medium - established in todo.md but the mechanism (data references enforce
prior step execution) is an inference.

---

## Recommended Approach

Based on findings 1-8, the optimal approach combines three techniques:

### Technique A: Embed as Sub-Step with CRITICAL Annotation (Primary)

Move vault detection from Stage 11 into Stage 10 as a CRITICAL sub-step:

```xml
<stage id="10" name="ArchiveTasks">
  <action>Archive tasks and perform mandatory post-archive checks</action>
  <process>
    [Steps 1-8: existing archive operations]

    9. **CRITICAL: Vault Threshold Check (MANDATORY - ALWAYS EXECUTE)**

       This sub-step MUST execute after every archive operation, even when
       no tasks were archived. It is not conditional on archive results.

       ```bash
       next_num=$(jq -r '.next_project_number' specs/state.json)
       echo "vault_threshold_check: next_project_number=$next_num"
       if [ "$next_num" -gt 1000 ]; then
         echo "VAULT_REQUIRED=true"
         vault_needed=true
       else
         echo "VAULT_REQUIRED=false"
         vault_needed=false
       fi
       echo "vault_check_complete"
       ```

       When vault_needed=true, execute sub-steps 9.1-9.4 below.
       When vault_needed=false, record result and continue to Stage 11.

    9.1 VaultConfirmation (when vault_needed=true): [AskUserQuestion]
    9.2 CreateVault (when user confirms): [move archive to vault/]
    9.3 RenumberTasks (when vault confirmed): [update task numbers]
    9.4 ResetState (when vault confirmed): [reset next_project_number]
  </process>
  <checkpoint>Archive complete, vault_check_complete output present in bash results</checkpoint>
</stage>
```

### Technique B: Add `<checkpoint>` to All Mandatory Stages (Supporting)

Add checkpoint tags to all existing vault stages while they remain separate. This does not replace
Technique A but provides defense-in-depth if the consolidation is done incrementally:

```xml
<checkpoint>vault_needed flag evaluated; if true, Stage 12 must execute</checkpoint>
```

### Technique C: Pre-Commit Bash Gate (Safety Net)

Add vault threshold check to Stage 20 (GitCommit) before `git add`:

```bash
# Pre-commit safety gate (from Stage 10 sub-step 9 output)
next_num=$(jq -r '.next_project_number' specs/state.json)
if [ "$next_num" -gt 1000 ]; then
  echo "ERROR: COMMIT BLOCKED - vault threshold exceeded but vault not performed"
  echo "next_project_number=$next_num (must be <= 1000 before commit)"
  echo "ACTION: Return to Stage 10 sub-step 9 and execute vault sub-steps"
  exit 1
fi
```

This creates a hard gate: the model cannot commit without resolving the vault condition.

---

## Evidence Summary

| Finding | Source | Confidence |
|---------|--------|------------|
| Missing `<checkpoint>` tags in vault stages | `xml-structure.md` anti-pattern examples | High |
| `CRITICAL` annotation works in todo.md | Direct observation in `todo.md` sections 2.5, 5D | High |
| todo.md uses flat sub-section (5.8) while SKILL.md uses independent stage (11) | Cross-file comparison | High |
| Bash output is immediate model context | `anti-stop-patterns.md`, postflight-control pattern | High |
| 5 skip-boundaries in stages 11-15 vs 1 in consolidated approach | Stage structure analysis | High |
| Invert conditional framing for mandatory stages | Stage 8 vs Stage 11 comparison | High |
| Data references enforce prior step execution | todo.md orphan tracking pattern | Medium |

---

## Confidence Level

**High** overall. The recommended approach is grounded in:
1. Existing patterns already successfully used in this codebase (todo.md, xml-structure.md)
2. Direct observation of what the failed test executed (stages 11-15 all skipped)
3. The todo.md command achieving vault detection through structural embedding, not separate stages

The primary risk is that consolidated sub-steps could themselves be skipped if the embedding
is not aggressive enough. The pre-commit bash gate (Technique C) provides the hard backstop.

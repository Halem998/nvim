---
task: 565
type: research
date: 2026-05-13
status: complete
---

# Research Report: Plan Compliance Spot-Check Gate

## Summary

- The `.opencode/` lean skill (ProofChecker) has a **Stage 6: Zero-Debt Verification Gate** but no plan-compliance check; it runs after the subagent returns and before status update.
- The `checkpoint-gate-out.md` has five generic steps (validate return, verify artifacts, update status, link artifacts, verify all updates); it has **no lean4-specific hook**.
- Lean plan files use a **"Goals & Non-Goals"** section and **"Artifacts & Outputs"** section to list deliverables; theorem/function names appear as backtick-wrapped identifiers (e.g., `doets_countermodel_discrete`).
- The canonical failure case is confirmed: `doets_countermodel_discrete` in Transfer.lean contains `exact ... dd_countermodel_chronicle_discrete`, meaning the replacement function calls the function it is meant to replace.
- The `.claude/` (nvim) lean skill has no zero-debt gate or plan-compliance check at all; it delegates verification entirely to the subagent.

---

## Findings

### 1. Current State of `.opencode/` skill-lean-implementation/SKILL.md

The skill has **10 stages** (Stage 1 through Stage 9, plus Stage 10: Return Brief Summary). The flow is:

- **Stage 1**: Input validation (task exists, type is lean/lean4, status allows implementation)
- **Stage 1 sub**: Task Complexity Warning (GATE IN) — reads effort from plan, warns if > 20h
- **Stage 2**: Preflight status update → "implementing"
- **Stage 3**: Prepare delegation context
- **Stage 4**: Invoke subagent via `Task` tool
- **Stage 5**: Parse subagent return (read `.return-meta.json`)
- **Stage 6**: **Zero-Debt Verification Gate (MANDATORY)** — runs after subagent returns
- **Stage 7**: Update task status (postflight)
- **Stage 8**: Link artifacts
- **Stage 9**: Git commit
- **Stage 10**: Return brief summary

**Stage 6 content (verbatim)**:

```bash
# Check for sorries in modified files
sorry_count=$(grep -r "\bsorry\b" Theories/ 2>/dev/null | grep -v "^[[:space:]]*--" | wc -l)

# Check for vacuous definitions (semantically equivalent to sorry)
vacuous_count=$(grep -rn "^\s*\(noncomputable \)\?\(def\|theorem\|lemma\|instance\).*:= \(True\|Unit\|trivial\|Trivial\)\s*$" Theories/ 2>/dev/null | wc -l)

# Verify build passes
if ! lake build 2>/dev/null; then
    build_failed=true
fi

if [ "$sorry_count" -gt 0 ] || [ "$vacuous_count" -gt 0 ] || [ "$build_failed" = true ]; then
    echo "Zero-debt gate FAILED"
    ...
    status="partial"
fi
```

There is no Stage 6a/6b split. Stage 6 is a single atomic gate that checks sorries, vacuous defs, and build. **No plan-compliance check exists.**

The skill also has no section reading the plan's "Goals" section for theorem names. The plan path is available at `plan_file` (from the GATE IN complexity warning), but the skill does not parse it beyond extracting effort hours.

---

### 2. Current State of `checkpoint-gate-out.md`

The file has five steps:

1. **Validate Return Structure** — checks JSON schema has status, summary, artifacts
2. **Verify Artifacts Exist** — loops over artifact paths, checks file exists on disk
3. **Update Status** (via skill-status-sync)
4. **Link Artifacts** (via skill-status-sync)
5. **Verify All Updates** — re-reads state.json and TODO.md

**No domain-specific hook exists.** The GATE OUT pattern is purely structural (validate return schema + file existence). There is no lean4-specific section and no mention of plan deliverable verification.

The checkpoint uses a generic decision model: PROCEED / RETRY / PARTIAL.

---

### 3. Current State of `orchestration-validation.md`

The file explicitly partitions validation responsibility:

| Check | Who validates |
|-------|--------------|
| Task exists | Orchestrator (Stage 1) |
| Return format | Orchestrator (Stage 3) |
| Lean syntax | Agent-specific |
| Artifact format | Agent-specific |
| Plan already exists | Business logic → Agent |

The philosophy is: "The orchestrator validates **structural correctness** and **safety constraints**, not business logic or domain-specific rules."

Domain-specific validation (including plan compliance) belongs in the **skill layer**, not the orchestrator. This confirms that a plan compliance check belongs in `skill-lean-implementation/SKILL.md`, not in `orchestration-validation.md`. **This file does not need updating.**

---

### 4. Plan File Structure for Lean Tasks

Lean plan files follow a consistent structure. Relevant sections:

```
## Overview
  (narrative description, mentions "final deliverable is `theorem_name`")

## Goals & Non-Goals
  **Goals**:
  - ...
  - Create `doets_countermodel_discrete` with identical signature to `dd_countermodel_chronicle_discrete`
  - Replace the call in `bx_completeness` (Completeness.lean:159) — 1 line change

## Artifacts & Outputs
  - New Lean files:
    - `Theories/Bimodal/Metalogic/WeakCanonical/Transfer.lean` (~130 lines)
    - ...
```

Theorem names appear in **three locations** within a plan:
1. `## Overview` — narrative, mentions "final deliverable is `theorem_name`"
2. `## Goals & Non-Goals` under `**Goals**:` — bullet list, backtick-wrapped names
3. Phase task lists — `- Prove \`theorem_name\`:`

The most machine-readable section for deliverable extraction is `**Goals**:` (consistent backtick quoting of function names). The `## Artifacts & Outputs` section lists files (not theorem names).

There is **no "Key Theorems" section** in existing ProofChecker plans. The task description says "Key Theorems/Deliverables section" — this maps to `**Goals**:` in the `## Goals & Non-Goals` section.

---

### 5. Delivery Integrity Check Design (The Actual Failure Case)

The confirmed failure: `doets_countermodel_discrete` was added to `Transfer.lean` as an "interim fallback" that delegates to `dd_countermodel_chronicle_discrete` — the exact function it was supposed to replace. The plan stated:

> "Create `doets_countermodel_discrete` with identical signature to `dd_countermodel_chronicle_discrete`"

But the implementation body contains:

```lean
exact Bimodal.Metalogic.BXCanonical.Chronicle.dd_countermodel_chronicle_discrete
    A h_mcs φ h_neg_in h_box_discrete_chronicle
```

**Detection strategy**: When a plan says "X is a replacement for Y" or "X bypasses Y", grep for X's definition body calling Y.

The plan indicates this relationship in the `## Overview` and `## Goals & Non-Goals`:
- "Create `doets_countermodel_discrete` — a drop-in replacement for `dd_countermodel_chronicle_discrete`"

The grep pattern to detect X calling Y in Lean:

```bash
# If X calls Y, the body of X's definition will contain Y's name
# Search for Y's name inside the definition of X
grep -A 50 "^theorem $X\|^def $X\|^lemma $X\|^noncomputable def $X" Theories/**/*.lean \
  | grep "$Y"
```

A simpler form (grep from first match to end of block):

```bash
# Check if function X's implementation body references function Y
x_calls_y() {
    local X="$1" Y="$2"
    # Find files containing X's definition
    mapfile -t files < <(grep -rl "theorem $X\|def $X\|lemma $X" Theories/ 2>/dev/null)
    for f in "${files[@]}"; do
        # Extract lines from X's definition, check if Y appears
        if awk "/^(theorem|def|lemma|noncomputable def) $X/{found=1} found{print}" "$f" \
           | grep -q "$Y"; then
            echo "INTEGRITY FAIL: $X calls $Y in $f"
            return 1
        fi
    done
}
```

**Practical limitation**: Lean definitions can span many lines and use `where` clauses or local `have` statements. A simpler heuristic: grep the entire file where X is defined for Y's name, with a note that false positives can occur if Y appears in comments.

```bash
# Simpler form: find file defining X, check if Y appears anywhere in that file
x_file=$(grep -rl "^theorem $X\b\|^def $X\b\|^lemma $X\b\|^noncomputable def $X\b" Theories/ 2>/dev/null | head -1)
if [ -n "$x_file" ] && grep -q "$Y" "$x_file"; then
    echo "WARNING: File defining $X references $Y (possible delegation to replaced function)"
fi
```

This catches the actual failure (Transfer.lean defines `doets_countermodel_discrete` and references `dd_countermodel_chronicle_discrete`).

---

### 6. Plan Deliverable Parsing Strategy

**Approach for Stage 6b**:

1. Read the plan file (path known from GATE IN stage, stored as `$plan_file`)
2. Extract the `**Goals**:` section
3. Grep for backtick-wrapped identifiers that are Lean function names (pattern: `\`[a-zA-Z_][a-zA-Z0-9_']*\``)
4. For each extracted name, check that it exists in `Theories/` as a definition:

```bash
extract_goal_theorems() {
    local plan="$1"
    # Extract lines from **Goals**: section until next **-section or ##
    sed -n '/^\*\*Goals\*\*:/,/^\*\*/p' "$plan" \
      | grep -oP '`[a-zA-Z_][a-zA-Z0-9_'"'"']*`' \
      | tr -d '`' \
      | sort -u
}

check_theorem_exists() {
    local name="$1"
    grep -rq "^theorem $name\b\|^def $name\b\|^lemma $name\b\|^noncomputable def $name\b" Theories/ 2>/dev/null
}
```

**Risks and edge cases**:
- Goals section may reference existing (not new) functions — grep hits would be false positives for the existence check (they exist, which is correct). Only missing names fail.
- Some backtick names in Goals are types or module names, not theorems. These may not appear with `def`/`theorem`/`lemma` prefix. Degrading gracefully (warn but not fail) is safer.
- `-- comments` in Lean files can reference names without defining them. The grep pattern `^theorem $name\b` (anchored to line start) avoids comment matches.
- Plan files that don't have a `**Goals**:` section yield zero names — the check vacuously passes.

**Delivery integrity parsing**:

Plan text that signals replacement relationships:
- "a drop-in replacement for `Y`"
- "replaces `Y`"
- "bypasses `Y`"
- "supersedes `Y`"

```bash
extract_replacement_pairs() {
    local plan="$1"
    # Find lines with "replacement for", "replaces", "bypasses" pattern
    grep -oP '`[a-zA-Z_][a-zA-Z0-9_'"'"']*`.*(?:replacement for|replaces|bypasses|supersedes).*`[a-zA-Z_][a-zA-Z0-9_'"'"']*`' "$plan" \
      | grep -oP '`[a-zA-Z_][a-zA-Z0-9_'"'"']*`' \
      | tr -d '`' \
      | paste - -
    # Returns pairs: X Y (on each line, tab-separated)
}
```

This regex is fragile. A simpler fallback: scan the Overview and Goals sections for both names mentioned together, ask the implementer to document replacement pairs explicitly in a structured comment.

---

### 7. The `.claude/` (nvim) Lean Extension Skill

File: `/home/benjamin/.config/nvim/.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md`

This skill is structurally different from the `.opencode/` version:

- Uses `Agent` tool (not `Task`)
- Has **no Stage 6 Zero-Debt Gate** — delegates all verification to the subagent
- Has a `Stage 4b: Self-Execution Fallback` section
- Has an explicit `MUST NOT` section listing prohibited postflight actions
- Has `Stage 9: Return Brief Summary` (not Stage 10)

The `.claude/` skill has **no plan-compliance check and no zero-debt gate at the skill level**. If task 565 requires adding these to the `.claude/` skill, they would need to be added as Stage 6 (between subagent return parse and status update).

However, the `.claude/` skill's MUST NOT section explicitly prohibits the skill from doing `grep for sorries` and `Run lake build` — those are reserved for the agent. This creates a conflict: adding a zero-debt gate at the skill level would violate the MUST NOT boundary.

**Resolution**: The `.claude/` skill uses a different design — verification results are read from agent metadata (`verification.verification_passed`), not re-run by the skill. A plan-compliance check at the `.claude/` skill level would need to be framed as a *plan-vs-implementation diff* (structural), not a re-run of lake build.

---

## Recommendations

### Stage 6b Design (for `.opencode/` SKILL.md)

Add as Stage 6b, **between** the existing Zero-Debt Gate (Stage 6) and Status Update (Stage 7). Rename current Stage 6 to Stage 6a for clarity.

```markdown
### Stage 6b: Plan Compliance Spot-Check (MANDATORY)

After zero-debt gate passes, verify that plan deliverables exist in the implementation.

**Step 1: Extract plan goal theorems**

```bash
plan_file="specs/${padded_num}_${project_name}/plans/$(ls specs/${padded_num}_${project_name}/plans/ 2>/dev/null | tail -1)"

if [ ! -f "$plan_file" ]; then
    echo "WARNING: Plan file not found — skipping compliance check"
else
    # Extract backtick-wrapped identifiers from **Goals**: section
    goal_names=$(sed -n '/^\*\*Goals\*\*:/,/^\*\*[^G]/p' "$plan_file" \
      | grep -oP '`[a-zA-Z_][a-zA-Z0-9_'"'"']*`' \
      | tr -d '`' | sort -u)

    compliance_failed=false
    for name in $goal_names; do
        if grep -rq "^\(noncomputable \)\?\(theorem\|def\|lemma\|instance\) $name\b" Theories/ 2>/dev/null; then
            echo "  [OK] $name exists in Theories/"
        else
            echo "  [MISSING] $name not found in Theories/ — plan deliverable absent"
            compliance_failed=true
        fi
    done
fi
```

**Step 2: Delivery integrity check**

```bash
# Detect if any goal name is defined but calls a function it was meant to replace
# Scan Overview + Goals for "replacement for" patterns
replacement_targets=$(grep -oP '(?:replacement for|replaces|bypasses)\s+`[a-zA-Z_][a-zA-Z0-9_'"'"']*`' "$plan_file" \
    | grep -oP '`[a-zA-Z_][a-zA-Z0-9_'"'"']*`' | tr -d '`')

for replaced in $replacement_targets; do
    for new_name in $goal_names; do
        # Find file where new_name is defined
        new_file=$(grep -rl "^\(noncomputable \)\?\(theorem\|def\|lemma\|instance\) $new_name\b" Theories/ 2>/dev/null | head -1)
        if [ -n "$new_file" ] && grep -q "\b$replaced\b" "$new_file"; then
            echo "  [INTEGRITY FAIL] $new_name calls $replaced in $new_file"
            echo "    Plan declared $new_name as replacement for $replaced, but implementation delegates to it."
            compliance_failed=true
        fi
    done
done

if [ "$compliance_failed" = true ]; then
    echo "Plan compliance spot-check FAILED"
    status="partial"
fi
```
```

**Graceful degradation**: If the plan file cannot be read or has no `**Goals**:` section, emit a WARNING and continue (non-blocking). Only fail if named deliverables are explicitly absent.

---

### Lean4 Hook for `checkpoint-gate-out.md`

Add a new section after step 2 ("Verify Artifacts Exist"):

```markdown
### 2b. Lean4-Specific: Plan Compliance Verification (lean4 task_type only)

If task_type is "lean4" or "lean":

Verify the skill-lean-implementation Stage 6b plan compliance check ran and passed:

```bash
# Read compliance result from metadata
compliance_status=$(jq -r '.metadata.compliance_check // "skipped"' "$metadata_file")
if [ "$compliance_status" = "failed" ]; then
    echo "GATE OUT BLOCKED: Plan compliance check failed — plan deliverables not all present"
    echo "  Check skill Stage 6b output for missing theorem names"
    decision="PARTIAL"
fi
```

If metadata does not contain compliance_check field (older skill version), emit INFO and proceed.
```

This hook is lightweight and reads from metadata rather than re-running grep checks.

---

### `orchestration-validation.md` Assessment

**No changes needed.** The file correctly assigns domain-specific validation to the skill layer. The plan compliance check belongs in the skill, not the orchestrator.

---

## Risks and Edge Cases

| Risk | Severity | Mitigation |
|------|----------|------------|
| Plan has no `**Goals**:` section | Low | Vacuously pass (emit WARNING, don't block) |
| Goal names include module/type names not defined with `theorem`/`def` | Medium | Warn but don't fail; only fail on exact pattern match |
| `sed -n '/\*\*Goals\*\*:/,/\*\*/p'` stops at wrong boundary | Medium | Test with actual plan files; use `## ` section boundary as fallback |
| Replacement targets grep misses variants ("drop-in replacement", "is a replacement") | Medium | Add multiple patterns; false negatives (misses) are safer than false positives (blocks valid work) |
| Performance: grep Theories/ for each goal name | Low | Theories/ is small; each grep takes < 100ms |
| Goal names change between plan versions (old plan read, new plan active) | Low | Skill reads most recent plan file (`tail -1` on plans/ directory) |
| Delivery integrity check has false positives (Y appears in comments in X's file) | Medium | Use `\b$replaced\b` to avoid partial matches; comment lines in Lean start with `--` but are hard to exclude reliably |

---

## References

- `/home/benjamin/Projects/ProofChecker/.opencode/skills/skill-lean-implementation/SKILL.md` — Full 10-stage skill definition; Stage 6 zero-debt gate at lines 170-194
- `/home/benjamin/Projects/ProofChecker/.opencode/context/checkpoints/checkpoint-gate-out.md` — 5-step GATE OUT with no domain hooks
- `/home/benjamin/Projects/ProofChecker/.opencode/context/orchestration/orchestration-validation.md` — Orchestrator validation philosophy; domain checks assigned to skill layer
- `/home/benjamin/Projects/ProofChecker/specs/129_weak_reflexive_completeness_conservative_extension/plans/03_doets-reynolds-plan.md` — Reference lean4 plan; Goals section, Artifacts section, theorem name patterns
- `/home/benjamin/Projects/ProofChecker/Theories/Bimodal/Metalogic/WeakCanonical/Transfer.lean` — Actual failure case: `doets_countermodel_discrete` delegates to `dd_countermodel_chronicle_discrete`
- `/home/benjamin/.config/nvim/.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md` — `.claude/` lean skill; different architecture (agent-verified, MUST NOT re-run lake build)

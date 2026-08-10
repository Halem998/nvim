# Artifact Counter System Analysis

- **Task**: 670 - fix_artifact_counter_system
- **Date**: 2026-06-12
- **Source**: Live observation during BimodalLogic task 273 orchestration (21 plan versions, 13+ research rounds)
- **Status**: [RESEARCHED]

## 1. Problem Statement

The `next_artifact_number` counter in `state.json` is supposed to unify artifact numbering across reports, plans, and summaries. The invariant is:

- **Research** uses the next number and increments the counter
- **Plan** uses `counter - 1` (same round as research), does NOT increment
- **Summary** uses `counter - 1` (same round), does NOT increment
- **Revision** creates a new plan file but (per current implementation) does NOT increment

This breaks in multi-revision workflows and for tasks that predate the unified numbering.

## 2. Bugs Found

### Bug 1: Revision Does Not Increment the Counter

**Location**: `.claude/skills/skill-reviser/SKILL.md`, line 123:
```
**Note**: Revised plan does NOT increment `next_artifact_number`. Only research advances the sequence.
```

**Problem**: Each revision creates a NEW plan file (a new `.md` artifact) but reuses the same artifact number as the previous plan. In a multi-revision workflow like task 273 (21 plan versions!), this means:

- Research round N creates report `N_*.md`, counter becomes N+1
- Plan uses number N (correct)
- Revision 1 uses number N (WRONG — collides with original plan)
- Revision 2 uses number N (WRONG — collides again)
- ... all revisions pile up at the same number

**What should happen**: Revision SHOULD increment `next_artifact_number` because it represents a new planning attempt. The user wants to trace when planning diverged from research:

```
Research 12 → Report 12 (counter: 12→13)
Plan 12      → Plan 12   (counter stays 13)
Revision     → Plan 13   (counter: 13→14)  ← NEW: revision increments
Revision     → Plan 14   (counter: 14→15)  ← each revision gets its own number
Research 15  → Report 15  (counter: 15→16)
Plan 15      → Plan 15    (counter stays 16)
```

**Fix**: In `skill-reviser/SKILL.md`, change the artifact number calculation from `next_artifact_number - 1` to `next_artifact_number` (use the current value), and add an increment step after the revision artifact is created, identical to what `skill-team-research` does:

```bash
# In skill-reviser Stage 3a:
artifact_number=$next_num   # Use current, not current-1

# In skill-reviser postflight (Stage 8 equivalent):
jq '(.active_projects[] | select(.project_number == '$task_number')).next_artifact_number =
    (((.active_projects[] | select(.project_number == '$task_number')).next_artifact_number // 1) + 1)' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

### Bug 2: No Collision Detection

**Location**: Both `skill-planner/SKILL.md` and `skill-reviser/SKILL.md` (Stage 3a).

**Problem**: When the calculated artifact number already has an existing file in the `plans/` directory, there is no check or warning. This causes silent collisions:

```
plans/13_generalized-transfer-plan.md    ← old plan v13
plans/13_path-b-decomposition-plan.md    ← new plan from artifact counter
```

Both files coexist (different slugs), but the shared prefix `13_` is confusing and breaks the assumption that artifact numbers are unique identifiers.

**What should happen**: Before writing an artifact, check if any file with the computed `{NN}_` prefix already exists in the target directory. If so, either:
- (a) Skip to the next available number and log a warning
- (b) Abort and surface the collision to the user

**Fix**: Add a collision check in Stage 3a of both skills:

```bash
# After computing artifact_padded
padded_num=$(printf "%03d" "$task_number")
existing=$(ls "specs/${padded_num}_${project_name}/plans/${artifact_padded}_"*.md 2>/dev/null | head -1)
if [ -n "$existing" ]; then
  echo "WARNING: Artifact number ${artifact_padded} already exists: $existing"
  echo "Advancing to next available number."
  artifact_number=$((artifact_number + 1))
  artifact_padded=$(printf "%02d" "$artifact_number")
fi
```

### Bug 3: Counter Drift for Legacy Tasks

**Location**: `state.json` field `next_artifact_number`.

**Problem**: Tasks created before the unified counter was introduced have `next_artifact_number` values that don't reflect their actual artifact count. Task 273 had `next_artifact_number: 11` when report `11_divergence-audit.md` already existed (should have been 12). This required a manual fix.

**Root cause**: The counter was introduced mid-lifecycle. Old research/plan operations didn't increment it. The counter reflects only operations performed AFTER the counter was added, not the total artifact history.

**What should happen**: A "catch-up" mechanism that reconciles the counter with actual files on disk.

**Fix**: Add a reconciliation step to the artifact number calculation in all skills:

```bash
# After reading next_artifact_number from state.json
padded_num=$(printf "%03d" "$task_number")
max_on_disk=$(ls "specs/${padded_num}_${project_name}/"*/*[0-9][0-9]_*.md 2>/dev/null \
  | sed 's/.*\/\([0-9][0-9]\)_.*/\1/' | sort -n | tail -1 | sed 's/^0//')
max_on_disk=${max_on_disk:-0}

if [ "$artifact_number" -le "$max_on_disk" ]; then
  echo "WARNING: Counter ($artifact_number) behind disk ($max_on_disk). Reconciling."
  artifact_number=$((max_on_disk + 1))
  # Also update state.json
  jq "(.active_projects[] | select(.project_number == $task_number)).next_artifact_number = $((artifact_number + 1))" \
    specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

### Bug 4: plan_version vs Artifact Number Confusion

**Location**: `state.json` field `plan_metadata.plan_version` vs artifact file naming.

**Problem**: Two independent numbering systems exist:
- `plan_metadata.plan_version` (22 for task 273) — incremented by the planner agent
- Artifact sequence number (13 for the latest plan) — derived from `next_artifact_number`

The plan version is a semantic version of the plan's evolution. The artifact number is a filesystem ordering index. These are conceptually different but both appear in plan filenames across the codebase history:

```
plans/21_rabinovich-formula-level-plan.md   ← plan version 21, artifact number 21(??)
plans/13_path-b-decomposition-plan.md       ← plan version 22, artifact number 13
```

Users see `plans/13_*` and `plans/21_*` and naturally assume higher numbers are newer. But 13 is NEWER than 21 because it uses the artifact sequence while 21 used the plan version.

**What should happen**: One of:
- (a) **Eliminate plan_version**: Use only the artifact sequence number. Revisions get the next artifact number, which monotonically increases.
- (b) **Use plan_version in filenames**: Plans always use `plan_version` for their prefix, not the artifact sequence number. This makes plan history linear and intuitive.
- (c) **Encode both**: `{artifact_number}_v{plan_version}_{slug}.md` — e.g., `13_v22_path-b-decomposition-plan.md`

**Recommendation**: Option (a) is cleanest. The artifact sequence number already serves as a monotonic ordering. The `plan_version` field in `plan_metadata` is useful for commit messages and human reference but should not appear in filenames. If revision increments the counter (Bug 1 fix), the artifact number becomes the de facto plan version.

## 3. Affected Files

| File | Bug | Fix |
|------|-----|-----|
| `.claude/skills/skill-reviser/SKILL.md` | 1, 2 | Add counter increment; add collision check |
| `.claude/skills/skill-planner/SKILL.md` | 2, 3 | Add collision check; add reconciliation |
| `.claude/skills/skill-team-research/SKILL.md` | 3 | Add reconciliation |
| `.claude/skills/skill-researcher/SKILL.md` | 3 | Add reconciliation (if it has artifact numbering) |
| `.claude/CLAUDE.md` | 4 | Clarify that revision increments; remove plan_version from filename convention |
| `.claude/rules/artifact-formats.md` | 4 | Update naming convention documentation |
| `.claude/context/formats/plan-format.md` | 4 | Remove or clarify plan_version in metadata |

## 4. Test Cases

### Happy Path
```
next_artifact_number: 1
/research 5       → report 01_*, counter becomes 2
/plan 5           → plan 01_*, counter stays 2
/implement 5      → summary 01_*, counter stays 2
```

### Multi-Revision
```
next_artifact_number: 5
/research 5       → report 05_*, counter becomes 6
/plan 5           → plan 05_*, counter stays 6
/revise 5         → plan 06_*, counter becomes 7  ← BUG 1 FIX
/revise 5         → plan 07_*, counter becomes 8  ← each revision gets unique number
/research 5       → report 08_*, counter becomes 9
/plan 5           → plan 08_*, counter stays 9
```

### Legacy Task (Counter Drift)
```
next_artifact_number: 5 (but 8 files exist on disk)
/research 5       → reconciliation detects drift, uses 09_*, counter becomes 10  ← BUG 3 FIX
```

### Collision Detection
```
next_artifact_number: 13 (but plans/13_old-plan.md exists)
/plan 5           → collision detected, uses 14_*, counter adjusted  ← BUG 2 FIX
```

## 5. Priority

**High** — This affects every task that goes through multiple research/plan cycles. The revision bug (Bug 1) silently creates confusing artifacts, and the collision bug (Bug 2) creates ambiguous filenames that break the human-readable audit trail.

## 6. Implementation Estimate

- Bug 1 (revision increment): ~15 lines in skill-reviser/SKILL.md
- Bug 2 (collision detection): ~10 lines each in skill-planner + skill-reviser (~20 total)
- Bug 3 (counter reconciliation): ~15 lines, added to a shared helper or duplicated in each skill
- Bug 4 (plan_version cleanup): Documentation updates across 3-5 files, ~30 lines total

**Total**: ~80 lines of changes across 5-7 files. 2-3 hours estimated.

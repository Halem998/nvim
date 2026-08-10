# Task 269: Normalize Skill Consistency Across Founder Extension

**Status**: Research Complete
**Created**: 2026-03-24
**Dependencies**: Task #263 (skill-project update)

---

## Problem Statement

The 7 skills in the founder extension have inconsistencies in their patterns that should be normalized for maintainability and uniformity.

## Inconsistencies Found

### 1. Return Format: JSON vs Text (MEDIUM severity)

| Skill | Return Format |
|-------|---------------|
| skill-market | Brief text summary (NOT JSON) |
| skill-analyze | Brief text summary (NOT JSON) |
| skill-strategy | Brief text summary (NOT JSON) |
| skill-legal | Brief text summary (NOT JSON) |
| skill-project | Brief text summary (NOT JSON) |
| **skill-founder-plan** | **JSON object** |
| **skill-founder-implement** | **JSON object** |

**Issue**: The 5 research skills explicitly state "Brief text summary (NOT JSON)" in their Return Format section. The plan and implement skills show JSON as the expected return. This inconsistency affects how the calling command/orchestrator parses results.

**Fix**: Align plan and implement skills to use text returns matching the research skill pattern, OR document why JSON is necessary for these skills.

### 2. Postflight Marker Format (LOW severity)

| Skill | Marker Content |
|-------|---------------|
| Research skills (5) | Full JSON object: `{ session_id, skill_name, task_number, operation, reason, created }` |
| **skill-founder-plan** | **String: just session_id** |
| **skill-founder-implement** | **String: just session_id** |

**Fix**: Align plan and implement skills to write full JSON marker objects matching the research skill pattern.

### 3. Cleanup Completeness (LOW severity)

| Skill | Files Cleaned |
|-------|---------------|
| Research skills (5) | `.postflight-pending`, `.postflight-loop-guard`, `.return-meta.json` |
| **skill-founder-plan** | **`.postflight-pending` only** |
| **skill-founder-implement** | **`.postflight-pending` only** |

**Fix**: Add `.return-meta.json` and `.postflight-loop-guard` cleanup to plan and implement skills.

### 4. delegation_depth (LOW severity)

| Skill | delegation_depth |
|-------|-----------------|
| skill-market | 1 |
| skill-analyze | 1 |
| skill-strategy | 1 |
| skill-legal | 1 |
| skill-project | **2** |
| skill-founder-plan | 2 |
| skill-founder-implement | 2 |

**Note**: skill-project using depth 2 was likely copied from the plan/implement pattern. After task 263 normalizes skill-project to match research skills, this should be fixed to 1.

The plan and implement skills using depth 2 may be intentional if they are invoked via the orchestrator (which adds a delegation level). This should be verified and documented.

### 5. allowed-tools Mismatch (LOW severity)

| Skill | allowed-tools |
|-------|---------------|
| Research skills (5) | Task, Bash, Edit, Read, Write |
| **skill-founder-plan** | **Task only** |
| **skill-founder-implement** | **Task only** |

**Issue**: Research skills can run their own jq/bash commands for postflight state updates. Plan/implement skills can only delegate via Task tool - their jq/bash blocks are pseudocode.

**Fix**: Either add Bash, Edit, Read, Write to plan/implement skills (so they can actually run postflight commands), or convert the research skills to Task-only (with all postflight logic in the command layer). The former is recommended for consistency.

## Proposed Changes

### Priority 1: Return Format Alignment
- Update skill-founder-plan and skill-founder-implement Return Format sections
- Change from JSON to text summary format
- Match the pattern: "Brief text summary (NOT JSON)"

### Priority 2: Postflight Marker Alignment
- Update marker creation in skill-founder-plan Stage 3
- Update marker creation in skill-founder-implement Stage 3
- Write full JSON object matching research skill format

### Priority 3: Cleanup Alignment
- Add `.return-meta.json` cleanup to both plan and implement skills
- Add `.postflight-loop-guard` cleanup to both plan and implement skills

### Priority 4: allowed-tools Alignment
- Add Bash, Edit, Read, Write to plan and implement skills
- This enables them to run their own postflight state updates

## Files Affected

- `.claude/extensions/founder/skills/skill-founder-plan/SKILL.md`
- `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md`

## Effort Estimate

1 hour - straightforward pattern alignment across 2 files.

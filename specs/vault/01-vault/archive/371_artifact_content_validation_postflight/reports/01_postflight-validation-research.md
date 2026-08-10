# Research Report: Artifact Content Validation in Skill Postflight

- **Task**: 371 - Add artifact content validation to skill postflight stages
- **Started**: 2026-04-07
- **Completed**: 2026-04-07
- **Effort**: 1 hour
- **Dependencies**: None
- **Sources/Inputs**:
  - skill-researcher/SKILL.md, skill-planner/SKILL.md, skill-implementer/SKILL.md
  - plan-format.md, report-format.md, summary-format.md
  - return-metadata-file.md
  - Existing scripts in .claude/scripts/ (postflight-*.sh, update-task-status.sh, validate-*.sh, lint/)
- **Artifacts**: specs/371_artifact_content_validation_postflight/reports/01_postflight-validation-research.md
- **Standards**: report-format.md, status-markers.md, artifact-management.md

## Executive Summary

- All three skills (researcher, planner, implementer) validate only `.return-meta.json` in postflight -- checking JSON validity and extracting fields. No validation of the actual artifact file (report, plan, or summary) occurs.
- Each format standard defines clear required metadata fields and required sections that can be checked with simple grep-based validation.
- The existing scripts directory contains well-established patterns: standalone bash scripts with clear usage, exit codes, and error reporting. A `validate-artifact.sh` script fits naturally.
- The recommended approach is a single reusable validation script that accepts the artifact path and type, checks for required sections/fields, returns structured exit codes, and optionally attempts auto-fix for the most common failure (missing/malformed metadata block).

## Context & Scope

Skill postflight stages (Stages 6-10 in each SKILL.md) currently perform:
1. Read `.return-meta.json` and extract status/artifact fields
2. Update task status via `update-task-status.sh`
3. Link artifacts in state.json and TODO.md
4. Git commit
5. Cleanup temp files

At no point is the actual artifact file validated for structural compliance with its format standard. A plan missing its "Implementation Phases" section, a report missing "Executive Summary", or a summary missing "What Changed" all pass postflight silently.

## Findings

### Current Postflight Architecture

#### skill-researcher (SKILL.md)
- **Postflight stages**: 6 (Parse Return), 7 (Update Status + Increment Artifact Number), 8 (Link Artifacts), 9 (Cleanup), 10 (Return Summary)
- **What is validated**: `.return-meta.json` exists, is valid JSON, status field is readable, artifact_path/type/summary are extractable
- **What is NOT validated**: The report file at `artifact_path` is never read or checked
- **Insertion point**: Between Stage 6 (Parse Return) and Stage 7 (Update Status). If metadata status is "researched" and artifact_path is non-empty, validate the artifact before proceeding to status update.

#### skill-planner (SKILL.md)
- **Postflight stages**: 6 (Parse Return), 7 (Update Status), 8 (Link Artifacts), 9 (Git Commit), 10 (Cleanup), 11 (Return Summary)
- **What is validated**: Same as researcher -- only `.return-meta.json` JSON validity and field extraction
- **What is NOT validated**: The plan file content
- **Insertion point**: Between Stage 6 and Stage 7. Same logic -- validate if status is "planned" and artifact_path exists.

#### skill-implementer (SKILL.md)
- **Postflight stages**: 5a (Validate Return Format -- checks if text return is JSON, not content), 6 (Parse Return), 7 (Update Status), 8 (Link Artifacts), 9 (Git Commit), 10 (Cleanup), 11 (Return Summary)
- **What is validated**: `.return-meta.json` JSON validity; Stage 5a checks if agent returned JSON to console (a format bug, not content validation)
- **What is NOT validated**: The summary file content
- **Insertion point**: Between Stage 6 and Stage 7, same pattern as above.

### Format Requirements Matrix

| Format | Required Metadata Fields | Required Sections |
|--------|------------------------|-------------------|
| **report** (report-format.md) | Task, Started, Completed, Effort, Dependencies, Sources/Inputs, Artifacts, Standards | Executive Summary, Context & Scope, Findings, Decisions, Recommendations |
| **plan** (plan-format.md) | Task, Status, Effort, Dependencies, Research Inputs, Artifacts, Standards, Type | Overview, Goals & Non-Goals, Risks & Mitigations, Implementation Phases (with Phase N headings), Testing & Validation, Artifacts & Outputs, Rollback/Contingency |
| **summary** (summary-format.md) | Task, Status, Started, Completed, Artifacts, Standards | Overview, What Changed, Decisions, Impacts, Follow-ups, References |

#### Detailed Required Elements by Type

**Report** (`report-format.md`):
- Metadata fields (line-starts-with pattern): `- **Task**:`, `- **Started**:`, `- **Completed**:`, `- **Effort**:`, `- **Dependencies**:`, `- **Sources/Inputs**:`, `- **Artifacts**:`, `- **Standards**:`
- Required sections (heading pattern): `## Executive Summary`, `## Context & Scope`, `## Findings`, `## Decisions`, `## Recommendations`
- Optional sections: `## Project Context`, `## Risks & Mitigations`, `## Context Extension Recommendations`, `## Appendix`

**Plan** (`plan-format.md`):
- Metadata fields: `- **Task**:`, `- **Status**:`, `- **Effort**:`, `- **Dependencies**:`, `- **Research Inputs**:`, `- **Artifacts**:`, `- **Standards**:`, `- **Type**:`
- Required sections: `## Overview`, `## Goals & Non-Goals`, `## Risks & Mitigations`, `## Implementation Phases`, `## Testing & Validation`, `## Artifacts & Outputs`, `## Rollback/Contingency`
- Phase heading format: `### Phase N: {name} [STATUS]` (at least one required)
- Dependency Analysis table under Implementation Phases

**Summary** (`summary-format.md`):
- Metadata fields: `- **Task**:`, `- **Status**:`, `- **Started**:`, `- **Completed**:`, `- **Artifacts**:`, `- **Standards**:`
- Required sections: `## Overview`, `## What Changed`, `## Decisions`, `## Impacts`, `## Follow-ups`, `## References`
- Note: `- **Effort**:` and `- **Dependencies**:` listed in format but often omitted in practice

### Existing Script Patterns

The `.claude/scripts/` directory contains 24 files following consistent patterns:

**Common conventions**:
- Shebang: `#!/usr/bin/env bash` or `#!/bin/bash`
- `set -euo pipefail` for strict mode
- Usage comments at top with argument descriptions
- Exit code documentation (0 = success, 1+ = specific failures)
- `SCRIPT_DIR` and `PROJECT_ROOT` derivation from `BASH_SOURCE`
- Colored output for verbose/lint tools (`RED`, `GREEN`, `YELLOW`, `NC`)
- Non-blocking warnings vs blocking errors distinction

**Validation script patterns** (validate-context-index.sh, validate-extension-index.sh, validate-index.sh, validate-wiring.sh):
- Accept `--fix` flag for auto-repair mode
- Use `ERRORS` and `WARNINGS` counters
- `log_error()`, `log_warning()`, `log_info()` helper functions
- Summary output at end with pass/fail
- Exit 0 on pass, exit 1 on failure

**Lint scripts** (lint/lint-postflight-boundary.sh):
- `--verbose` flag
- Colored output
- Violation counting
- Summary at end

**Postflight scripts** (postflight-research.sh, postflight-plan.sh, postflight-implement.sh):
- Accept `TASK_NUMBER ARTIFACT_PATH [ARTIFACT_SUMMARY]`
- Validate state file and task existence
- Multi-step jq pattern for state updates
- These are older/simpler than update-task-status.sh and may be partially deprecated

### Insertion Points

For all three skills, the insertion point is identical in structure:

**Current flow** (Stage 6 -> Stage 7):
```
Stage 6: Parse .return-meta.json
  -> Extract status, artifact_path, artifact_type, artifact_summary
Stage 7: Update task status (if success status)
```

**Proposed flow** (Stage 6 -> Stage 6a -> Stage 7):
```
Stage 6: Parse .return-meta.json
  -> Extract status, artifact_path, artifact_type, artifact_summary
Stage 6a: Validate artifact content (NEW)
  -> If artifact_path exists and status is success:
     validate-artifact.sh "$artifact_path" "$artifact_type"
  -> On failure: attempt auto-fix, re-validate, or warn and continue
Stage 7: Update task status (if success status)
```

## Recommendations

### Validation Script Design

**Script**: `.claude/scripts/validate-artifact.sh`

**Interface**:
```
Usage: validate-artifact.sh <artifact_path> <artifact_type> [--fix] [--strict]

Arguments:
  artifact_path  - Path to the artifact file (relative or absolute)
  artifact_type  - "report", "plan", or "summary"

Options:
  --fix          Attempt auto-fix for metadata block issues
  --strict       Treat warnings as errors (for CI/lint usage)

Exit codes:
  0 - Valid (all required elements present)
  1 - Validation errors found (missing required sections)
  2 - Validation errors found but auto-fixed (with --fix)
  3 - File not found or not readable
  4 - Unknown artifact type
```

**Checks performed** (in order):

1. **File existence**: artifact_path must exist and be readable
2. **Non-empty**: File must have content (more than just whitespace)
3. **Title heading**: First line must start with `# ` (H1 heading)
4. **Metadata block**: Check for required `- **Field**:` lines in the first 20 lines
   - Different required fields per artifact_type (see matrix above)
   - This is the most common failure mode
5. **Required sections**: Check for required `## Section` headings
   - Different required sections per artifact_type (see matrix above)
6. **Type-specific checks**:
   - Plans: At least one `### Phase` heading exists
   - Plans: Status marker in metadata block matches expected pattern
   - Reports: No status markers (reports should not have `[RESEARCHING]` etc.)

**Return format**: Structured output for skill consumption:
```
[PASS] artifact.md: All checks passed (8/8 required metadata, 5/5 required sections)
```
or
```
[FAIL] artifact.md: 2 errors, 1 warning
  [ERROR] Missing required section: ## Executive Summary
  [ERROR] Missing required metadata: - **Standards**:
  [WARN] Missing optional section: ## Appendix
```

### Auto-Fix Capability

The metadata block is the most common failure (agents sometimes forget fields or use wrong format). Auto-fix should handle:

1. **Missing `- **Standards**:` line**: Insert with default value based on type
2. **Missing `- **Artifacts**:` line**: Insert with the artifact path itself
3. **Missing `- **Effort**:` line**: Insert with "estimated" placeholder
4. **Wrong metadata format** (e.g., YAML frontmatter instead of markdown metadata): Convert to correct format

Auto-fix should NOT attempt to:
- Add missing sections (that requires substantive content)
- Fix section ordering (too complex, low value)
- Generate content for empty sections

### Integration Pattern

Each skill's SKILL.md gets a new Stage 6a added between Stage 6 (Parse Return) and Stage 7 (Update Status):

```markdown
### Stage 6a: Validate Artifact Content

If artifact_path is non-empty and the file exists, validate content:

\`\`\`bash
if [ -n "$artifact_path" ] && [ -f "$artifact_path" ]; then
    validation_result=$(bash .claude/scripts/validate-artifact.sh "$artifact_path" "$artifact_type" --fix 2>&1)
    validation_exit=$?

    if [ $validation_exit -eq 1 ]; then
        echo "Warning: Artifact validation failed:"
        echo "$validation_result"
        # Non-blocking: log warning but continue with postflight
    elif [ $validation_exit -eq 2 ]; then
        echo "Note: Artifact had issues that were auto-fixed"
    fi
fi
\`\`\`
```

**Key design decision**: Validation failures should be **non-blocking warnings**, not hard failures. Rationale:
- The agent already completed its work and wrote the artifact
- Blocking the postflight would leave the task in an inconsistent state (status updated but no commit)
- The metadata is already parsed successfully
- A warning in the output gives the user visibility to run `/revise` if needed

### Failure Handling

| Scenario | Action | Rationale |
|----------|--------|-----------|
| Artifact file missing | Skip validation, log warning | Agent may have failed to write file -- metadata status handles this |
| Missing required section | Log warning, continue | Content issue, not structural -- user can revise |
| Missing required metadata field | Attempt `--fix`, log result | Most common auto-fixable issue |
| Auto-fix succeeds | Continue normally, note in output | File is now compliant |
| Auto-fix fails | Log warning, continue | Better to commit imperfect artifact than block |
| Unknown artifact type | Skip validation, log warning | Graceful degradation for new types |

### Implementation Effort Estimate

- **validate-artifact.sh script**: ~150-200 lines, 1-2 hours
- **Skill SKILL.md updates** (3 skills): ~30 minutes each, inserting Stage 6a
- **Testing**: Create sample artifacts with deliberate omissions, verify detection
- **Total**: ~4-5 hours across 3 phases

### Phase Suggestion

1. **Phase 1**: Create `validate-artifact.sh` with all three format types, `--fix` support, and structured output
2. **Phase 2**: Update all three SKILL.md files to add Stage 6a with validation call
3. **Phase 3**: Testing and edge case handling (empty files, binary content, wrong type)

## Decisions

- Validation is **non-blocking** (warn and continue) rather than blocking (fail postflight). This avoids leaving tasks in broken states.
- Auto-fix targets **metadata block only**, not missing sections. Missing sections require agent-level content generation.
- A **single script** handles all three artifact types via the `artifact_type` parameter, rather than separate scripts per type. This reduces maintenance burden.
- The script lives in `.claude/scripts/validate-artifact.sh` following existing conventions, not in `lint/` (lint is for static analysis of SKILL.md files, not runtime artifact validation).

## Risks & Mitigations

- **Risk**: Validation adds latency to postflight. **Mitigation**: grep-based checks are fast (sub-second for typical artifacts). No performance concern.
- **Risk**: Auto-fix corrupts artifact content. **Mitigation**: Auto-fix only inserts missing metadata lines at known positions (after last existing metadata line), never modifies existing content.
- **Risk**: Format standards evolve and validation becomes stale. **Mitigation**: Define required fields/sections as arrays at the top of the script for easy maintenance. Add a comment pointing to the format files.
- **Risk**: Different extensions may have custom artifact formats. **Mitigation**: The script only validates the three core types (report, plan, summary). Extension-specific validation can be added later via plugin mechanism.

## References

- `.claude/skills/skill-researcher/SKILL.md` -- Stages 6-10 (postflight)
- `.claude/skills/skill-planner/SKILL.md` -- Stages 6-11 (postflight)
- `.claude/skills/skill-implementer/SKILL.md` -- Stages 5a-11 (postflight)
- `.claude/context/formats/plan-format.md` -- Plan required elements
- `.claude/context/formats/report-format.md` -- Report required elements
- `.claude/context/formats/summary-format.md` -- Summary required elements
- `.claude/context/formats/return-metadata-file.md` -- Metadata schema
- `.claude/scripts/validate-context-index.sh` -- Pattern reference for validation scripts
- `.claude/scripts/lint/lint-postflight-boundary.sh` -- Pattern reference for lint scripts
- `.claude/scripts/update-task-status.sh` -- Centralized status update pattern

# Research Report: Task #525

**Task**: 525 - Fix lean skill path and field references
**Started**: 2026-05-04T00:00:00Z
**Completed**: 2026-05-04T00:00:00Z
**Effort**: Small (audit and documentation)
**Dependencies**: None
**Sources/Inputs**:
- `.opencode/extensions/lean/skills/skill-lean-research/SKILL.md`
- `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md`
- `.opencode/extensions/lean/agents/lean-research-agent.md`
- `.opencode/extensions/lean/agents/lean-implementation-agent.md`
- `.opencode/extensions/lean/manifest.json`
- `.opencode/skills/skill-researcher/SKILL.md`
- `.opencode/skills/skill-implementer/SKILL.md`
**Artifacts**: - `specs/525_fix_lean_skill_path_field_refs/reports/01_lean-skill-audit.md`
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- Found **6 occurrences** of the obsolete `OC_` prefix in paths within the two lean skill files.
- Found **2 occurrences** of `.language` field checks that should be `.task_type` to align with core skill routing.
- Identified a critical internal inconsistency: the delegation context tells subagents to write metadata to the correct path (`specs/${padded_num}_...`), but the parent skill's postflight reads from the wrong legacy path (`specs/OC_${padded_num}_...`).
- Core skills (`skill-researcher`, `skill-implementer`) confirm the correct pattern: no `OC_` prefix and `.task_type` checks.
- Additional inconsistencies noted: missing postflight marker files, missing cleanup stages, and manual `jq` status updates instead of the centralized `update-task-status.sh` script.

---

## Context & Scope

The Lean extension provides `skill-lean-research` and `skill-lean-implementation`. These files were created before the current directory convention stabilized and still reference an old path prefix (`OC_`) and the deprecated `.language` field. This audit covers all requested files in `.opencode/extensions/lean/skills/` and `.opencode/extensions/lean/agents/`, cross-referenced against the core skills to establish the canonical patterns.

---

## Findings

### Issue 1: Obsolete `OC_` Prefix in Paths

**Severity**: High  
**Why**: Breaks postflight metadata parsing and causes git commits to reference non-existent directories.

The lean skills' **delegation context** correctly instructs subagents to write to:
```
specs/{N}_{SLUG}/.return-meta.json
```

However, the skills' own **postflight** stages and **git commit** blocks use:
```
specs/OC_${padded_num}_${project_name}/...
```

Since subagents create files in the path without `OC_`, the parent skill will never find the metadata file, status updates will fail, and git commits will be empty.

#### Exact Occurrences

| # | File | Line | Current Text | Recommended Replacement |
|---|------|------|--------------|------------------------|
| 1 | `skill-lean-research/SKILL.md` | 124 | `metadata_file="specs/OC_${padded_num}_${project_name}/.return-meta.json"` | `metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"` |
| 2 | `skill-lean-research/SKILL.md` | 184 | `"specs/OC_${padded_num}_${project_name}/reports/" \` | `"specs/${padded_num}_${project_name}/reports/" \` |
| 3 | `skill-lean-research/SKILL.md` | 185 | `"specs/OC_${padded_num}_${project_name}/.return-meta.json" \` | `"specs/${padded_num}_${project_name}/.return-meta.json" \` |
| 4 | `skill-lean-implementation/SKILL.md` | 131 | `metadata_file="specs/OC_${padded_num}_${project_name}/.return-meta.json"` | `metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"` |
| 5 | `skill-lean-implementation/SKILL.md` | 215 | `"specs/OC_${padded_num}_${project_name}/summaries/" \` | `"specs/${padded_num}_${project_name}/summaries/" \` |
| 6 | `skill-lean-implementation/SKILL.md` | 216 | `"specs/OC_${padded_num}_${project_name}/plans/" \` | `"specs/${padded_num}_${project_name}/plans/" \` |

#### Verification
A `grep` across the entire `.opencode/extensions/lean/` directory confirmed these are the **only** `OC_` references in the extension.

---

### Issue 2: `.language` Field Check Instead of `.task_type`

**Severity**: Medium  
**Why**: Misalignment with core routing layer; core skills and orchestrator route by `task_type`.

Core skills extract the task classification using `.task_type`:
- `skill-researcher/SKILL.md` line 58: `task_type=$(echo "$task_data" | jq -r '.task_type // "general"')`
- `skill-implementer/SKILL.md` line 56: `task_type=$(echo "$task_data" | jq -r '.task_type // "general"')`

Lean skills currently use `.language`:

#### Exact Occurrences

| # | File | Line | Current Text | Recommended Replacement |
|---|------|------|--------------|------------------------|
| 7 | `skill-lean-research/SKILL.md` | 43 | `language=$(echo "$task_data" | jq -r '.language // "general"')` | `task_type=$(echo "$task_data" | jq -r '.task_type // "general"')` |
| 8 | `skill-lean-implementation/SKILL.md` | 44 | `language=$(echo "$task_data" | jq -r '.language // "general"')` | `task_type=$(echo "$task_data" | jq -r '.task_type // "general"')` |

#### Secondary Changes Required

Because the variable name changes, downstream references must also be updated:

| # | File | Line | Current Text | Recommended Replacement |
|---|------|------|--------------|------------------------|
| 9 | `skill-lean-implementation/SKILL.md` | 49 | `if [ "$language" != "lean" ] && [ "$language" != "lean4" ]; then` | `if [ "$task_type" != "lean" ] && [ "$task_type" != "lean4" ]; then` |
| 10 | `skill-lean-research/SKILL.md` | 85 | `"language": "lean"` | `"task_type": "${task_type}"` |
| 11 | `skill-lean-implementation/SKILL.md` | 91 | `"language": "lean"` | `"task_type": "${task_type}"` |

**Note**: The error message on line 50 of `skill-lean-implementation/SKILL.md` should also be updated for clarity:
- Current: `return error "Task $task_number is not a Lean task"`
- Recommended: `return error "Task $task_number is not a Lean task (task_type: $task_type)"`

---

### Other Inconsistencies with the Broader System

While the two issues above are the primary focus, the following discrepancies with core skill patterns were observed and should be considered for future hardening:

1. **Missing postflight marker files**  
   Core skills create `.postflight-pending` (and `.continuation-loop-guard` for implementers) to prevent premature termination. Lean skills claim to implement the skill-internal postflight pattern but do not create these markers.

2. **Missing cleanup stage**  
   Core skills remove `.return-meta.json`, `.postflight-pending`, and loop-guard files after postflight. Lean skills leave metadata files behind indefinitely.

3. **Manual status updates instead of centralized script**  
   Core skills use `.opencode/scripts/update-task-status.sh` for atomic updates to `state.json`, `TODO.md` task entries, and `TODO.md` Task Order. Lean skills use raw `jq` and manual `Edit` tool calls, which are more error-prone and can drift from central conventions.

4. **No terminal-state blocking**  
   The core implementer skill blocks invocation when a task is in a terminal state (`completed`, `abandoned`, `expanded`). Neither lean skill performs this check.

5. **Hardcoded `Theories/` assumption**  
   The lean implementation skill's zero-debt gate (Stage 6) runs `grep -r "\bsorry\b" Theories/`. This assumes a specific project layout that may not exist for all Lean tasks.

---

## Decisions

1. **Remove `OC_` prefix** from all path references in lean skills. The canonical format is `specs/${padded_num}_${project_name}/`.
2. **Replace `.language` with `.task_type`** in input validation, error checks, and delegation context JSON.
3. **Keep agent files unchanged** — `lean-research-agent.md` and `lean-implementation-agent.md` already use the correct `specs/{N}_{SLUG}/` pattern and do not reference `.language`.
4. **Defer broader refactor** (markers, cleanup, centralized script) to a future task unless it is required to unblock current usage.

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| External scripts still rely on `OC_` paths | Low | Medium | Grepped entire extension; no other references exist. |
| Legacy `state.json` entries lack `task_type` | Low | Low | Fallback `// "general"` ensures graceful behavior; orchestrator populates both fields. |
| Changing variable name `language` -> `task_type` breaks untested shell snippets | Medium | Low | All references were traced; only the 5 lines listed above need updates. |
| Git commits become no-ops after path fix if files were previously created under wrong path | Low | Low | The fix only affects future tasks; existing `OC_` directories (if any) are orphaned and harmless. |

---

## Context Extension Recommendations

- **Topic**: Lean extension context documentation
- **Gap**: `.opencode/context/index.json` contains no lean-specific context entries (only generic agent loading rules). Patterns like the zero-debt gate, MCP tool recovery, and Lean-specific handoff protocols are undocumented in the shared context index.
- **Recommendation**: Create or update `.opencode/context/extensions/lean-extension.md` and add index entries for `lean-research-agent` and `lean-implementation-agent` so that future lean tasks auto-load relevant domain knowledge.

---

## Appendix

### Search Queries Used
```bash
grep -rn "OC_" .opencode/extensions/lean/
grep -rn "\.language" .opencode/extensions/lean/
```

### Core Skill References
- `skill-researcher/SKILL.md` lines 58, 84-98, 329 — canonical `.task_type` and path patterns.
- `skill-implementer/SKILL.md` lines 56, 89-103, 317 — canonical `.task_type` and path patterns.

### Files Audited
- `.opencode/extensions/lean/skills/skill-lean-research/SKILL.md`
- `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md`
- `.opencode/extensions/lean/agents/lean-research-agent.md`
- `.opencode/extensions/lean/agents/lean-implementation-agent.md`
- `.opencode/extensions/lean/manifest.json`
- `.opencode/skills/skill-researcher/SKILL.md`
- `.opencode/skills/skill-implementer/SKILL.md`

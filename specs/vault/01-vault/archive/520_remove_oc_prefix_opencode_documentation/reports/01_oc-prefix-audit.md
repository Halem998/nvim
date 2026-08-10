# Research Report: Task #520

**Task**: 520 - Remove OC_ prefix from OpenCode documentation and standards
**Started**: 2026-05-04T00:00:00Z
**Completed**: 2026-05-04T00:00:00Z
**Effort**: 2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase grep, Read tool on 15+ files
**Artifacts**: - specs/520_remove_oc_prefix_opencode_documentation/reports/01_oc-prefix-audit.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **241 OC_ references** found across `.opencode/` directory in `.md` files
- **Legacy convention persists** in documentation despite actual task directories using plain numbers (`specs/520_slug/`)
- **18 distinct files/groups** require updates to remove OC_ prefix from paths, examples, and conventions
- **Extension mirrors** duplicate many references (`.opencode/extensions/core/...`)
- **No legacy `OC_503_*` directories** exist in the repository
- **Recommended approach**: Systematic find-and-replace with sed, then manual verification of bash scripts

## Context & Scope

The actual task directories in `specs/` use plain numbers (e.g., `specs/520_remove_oc_prefix_opencode_documentation/`). However, documentation throughout `.opencode/` still instructs agents to use `OC_` prefix in directory names, display text, git commits, and bash scripts. This creates confusion and potential path mismatches.

## Findings

### Codebase Patterns

#### 1. `.opencode/context/core/standards/task-management.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 23 | `Display task IDs with OC_ prefix (e.g., OC_17 for display, OC_017 for directories).` | `Display task IDs with plain numbers (e.g., 17 for display, 017 for directories).` |
| 28 | `Store the OC_ prefix in state.json (it's display/path convention only).` | `Do not store any prefix in state.json (plain numbers only).` |
| 30-33 | **OC_ Prefix Convention** block with `OC_17`, `OC_017_task_slug`, `task OC_17: {action}` | Replace all `OC_` with plain numbers: `17`, `017_task_slug`, `task 17: {action}` |
| 39 | `Format: ### OC_{Task ID}. {Task Title}` | `Format: ### {Task ID}. {Task Title}` |
| 40 | `Example: ### OC_17. Implement User Login` | `Example: ### 17. Implement User Login` |

#### 2. `.opencode/context/core/orchestration/state-management.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 60 | `OC_NNN_project_name/       # Task directories use OC_ prefix` | `{NNN}_project_name/       # Task directories use plain numbers` |
| 64 | `OpenCode tasks use OC_NNN_slug format (e.g., OC_017_task_slug). The OC_ prefix distinguishes from Claude Code tasks.` | `OpenCode tasks use {NNN}_slug format (e.g., 017_task_slug).` |
| 124-126 | `# 1. Parse task number (strip OC_ prefix if present)` and bash script with `sed 's/^OC_//'` | Remove the OC_ stripping logic; use task number directly |
| 135 | `echo "Error: Task OC_$task_num not found"` | `echo "Error: Task $task_num not found"` |
| 146 | `task_display="OC_$task_num"                           # e.g., OC_17` | `task_display="$task_num"                           # e.g., 17` |
| 147 | `task_dir="OC_$(printf '%03d' "$task_num")_$project_name"  # e.g., OC_017_task_slug` | `task_dir="$(printf '%03d' "$task_num")_$project_name"  # e.g., 017_task_slug` |
| 150-154 | **OC_ Prefix Convention** block | Replace all `OC_` references with plain numbers |
| 270 | `Fast jq lookup with OC_ prefix handling` | `Fast jq lookup with plain number` |
| 272-273 | `# Strip OC_ prefix before numeric lookup` and `sed 's/^OC_//'` | Remove stripping logic |
| 281 | `grep -A 20 "### OC_${task_number}\." specs/TODO.md` | `grep -A 20 "### ${task_number}\." specs/TODO.md` |

#### 3. `.opencode/context/core/patterns/metadata-file-return.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 99 | `mkdir -p "specs/OC_${padded_num}_${task_slug}"` | `mkdir -p "specs/${padded_num}_${task_slug}"` |
| 102 | `cat > "specs/OC_${padded_num}_${task_slug}/.return-meta.json" << 'EOF'` | `cat > "specs/${padded_num}_${task_slug}/.return-meta.json" << 'EOF'` |
| 123 | `metadata_file="specs/OC_${padded_num}_${task_slug}/.return-meta.json"` | `metadata_file="specs/${padded_num}_${task_slug}/.return-meta.json"` |
| 138 | `rm -f "specs/OC_${padded_num}_${task_slug}/.return-meta.json"` | `rm -f "specs/${padded_num}_${task_slug}/.return-meta.json"` |

#### 4. `.opencode/context/core/patterns/postflight-control.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 158 | `rm -f specs/OC_${padded_num}_*/.return-meta.json` | `rm -f specs/${padded_num}_*/.return-meta.json` |

#### 5. `.opencode/context/core/patterns/file-metadata-exchange.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 28 | `metadata_path="specs/OC_${padded_num}_${task_slug}/.return-meta.json"` | `metadata_path="specs/${padded_num}_${task_slug}/.return-meta.json"` |
| 39 | `mkdir -p "specs/OC_${padded_num}_${task_slug}"` | `mkdir -p "specs/${padded_num}_${task_slug}"` |
| 42 | `cat > "specs/OC_${padded_num}_${task_slug}/.return-meta.json" << 'METADATA_EOF'` | `cat > "specs/${padded_num}_${task_slug}/.return-meta.json" << 'METADATA_EOF'` |
| 90 | `/tmp/meta_with_artifacts.json > "specs/OC_${padded_num}_${task_slug}/.return-meta.json"` | `/tmp/meta_with_artifacts.json > "specs/${padded_num}_${task_slug}/.return-meta.json"` |
| 111 | `metadata_file="specs/OC_${padded_num}_${task_slug}/.return-meta.json"` | `metadata_file="specs/${padded_num}_${task_slug}/.return-meta.json"` |
| 129 | `metadata_file="specs/OC_${padded_num}_${task_slug}/.return-meta.json"` | `metadata_file="specs/${padded_num}_${task_slug}/.return-meta.json"` |
| 148 | `metadata_file="specs/OC_${padded_num}_${task_slug}/.return-meta.json"` | `metadata_file="specs/${padded_num}_${task_slug}/.return-meta.json"` |
| 172 | `rm -f "specs/OC_${padded_num}_${task_slug}/.return-meta.json"` | `rm -f "specs/${padded_num}_${task_slug}/.return-meta.json"` |
| 180 | `rm -f "specs/OC_${padded_num}_${task_slug}/.return-meta.json"` | `rm -f "specs/${padded_num}_${task_slug}/.return-meta.json"` |
| 199 | `metadata_file="specs/OC_${padded_num}_${task_slug}/.return-meta.json"` | `metadata_file="specs/${padded_num}_${task_slug}/.return-meta.json"` |
| 204 | `if [ -d "specs/OC_${padded_num}_${task_slug}/reports" ]; then` | `if [ -d "specs/${padded_num}_${task_slug}/reports" ]; then` |
| 244 | `metadata_file="specs/OC_${padded_num}_${task_slug}/.return-meta.json"` | `metadata_file="specs/${padded_num}_${task_slug}/.return-meta.json"` |

#### 6. `.opencode/context/core/formats/return-metadata-file.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 143 | `mkdir -p "specs/OC_${padded_num}_${task_slug}"` | `mkdir -p "specs/${padded_num}_${task_slug}"` |
| 170 | `metadata_file="specs/OC_${padded_num}_${task_slug}/.return-meta.json"` | `metadata_file="specs/${padded_num}_${task_slug}/.return-meta.json"` |
| 183 | `rm -f "specs/OC_${padded_num}_${task_slug}/.return-meta.json"` | `rm -f "specs/${padded_num}_${task_slug}/.return-meta.json"` |

#### 7. `.opencode/context/core/reference/state-management-schema.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 322 | `Claude Code uses specs/{NNN}_{SLUG}/ (no prefix). OpenCode uses specs/OC_{NNN}_{SLUG}/ (OC_ prefix).` | `All tasks use specs/{NNN}_{SLUG}/ (plain numbers, no prefix).` |

#### 8. `.opencode/skills/skill-todo/SKILL.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 47 | `for dir in specs/OC_[0-9]*_*/ specs/[0-9]*_*/; do` | `for dir in specs/[0-9]*_*/; do` |
| 50 | `project_num=$(echo "$basename_dir" | sed 's/^OC_//' | cut -d_ -f1)` | `project_num=$(echo "$basename_dir" | cut -d_ -f1)` |
| 68 | `for dir in specs/archive/OC_[0-9]*_*/ specs/archive/[0-9]*_*/; do` | `for dir in specs/archive/[0-9]*_*/; do` |
| 71 | `project_num=$(echo "$basename_dir" | sed 's/^OC_//' | cut -d_ -f1)` | `project_num=$(echo "$basename_dir" | cut -d_ -f1)` |
| 84 | `Parse task headers (### {N}. or ### OC_{N}.)` | `Parse task headers (### {N}.)` |
| 95 | `for dir in specs/OC_[0-9]*_*/ specs/[0-9]*_*/; do` | `for dir in specs/[0-9]*_*/; do` |
| 98 | `project_num=$(echo "$basename_dir" | sed 's/^OC_//' | cut -d_ -f1)` | `project_num=$(echo "$basename_dir" | cut -d_ -f1)` |
| 246-247 | `-- Match both "### OC_N. " and "### N. " formats` and `local task_start_pattern = "###%s+(OC_)?(%d+)%.%s+"` | `-- Match "### N. " format` and `local task_start_pattern = "###%s+(%d+)%.%s+"` |
| 291 | `source_dir="specs/OC_${orphan.project_number}_${orphan.project_name}/"` | `source_dir="specs/${orphan.project_number}_${orphan.project_name}/"` |

#### 9. `.opencode/skills/skill-memory/SKILL.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 550 | `task_dir=$(ls -d specs/OC_${padded_num}_* 2>/dev/null | head -1)` | `task_dir=$(ls -d specs/${padded_num}_* 2>/dev/null | head -1)` |
| 553 | `task_dir=$(ls -d specs/OC_${task_num}_* 2>/dev/null | head -1)` | `task_dir=$(ls -d specs/${task_num}_* 2>/dev/null | head -1)` |
| 557 | `echo "Task directory not found: specs/OC_${padded_num}_*"` | `echo "Task directory not found: specs/${padded_num}_*"` |
| 901 | `Task directory not found: specs/OC_{NNN}_*` | `Task directory not found: specs/{NNN}_*` |

#### 10. `.opencode/docs/guides/phase-synchronization.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 13 | `specs/OC_NNN_*/plans/implementation-*.md` | `specs/{NNN}_*/plans/implementation-*.md` |
| 86 | `When /implement OC_N is invoked:` | `When /implement {N} is invoked:` |
| 265 | **Task**: OC_100 - Sample Task | **Task**: 100 - Sample Task |
| 269 | **Command**: `/implement OC_100` | **Command**: `/implement 100` |
| 289 | **Commit**: `task OC_100 phase 1: Setup` | **Commit**: `task 100 phase 1: Setup` |
| 305 | **Commit**: `task OC_100 phase 2: Core Work` | **Commit**: `task 100 phase 2: Core Work` |
| 314 | **Final commit**: `task OC_100: finalize implementation and create summary` | **Final commit**: `task 100: finalize implementation and create summary` |
| 325 | `grep -A 3 "OC_100" specs/TODO.md` | `grep -A 3 "100" specs/TODO.md` |
| 328 | `grep "^### Phase" specs/OC_100_*/plans/implementation-*.md` | `grep "^### Phase" specs/100_*/plans/implementation-*.md` |
| 337 | `vim specs/OC_100_*/plans/implementation-001.md` | `vim specs/100_*/plans/implementation-001.md` |

#### 11. `.opencode/rules/artifact-formats.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 23 | `- Claude Code tasks: specs/{NNN}_{SLUG}/ (no prefix)` | Remove this line entirely (no longer a distinction) |
| 24 | `- OpenCode tasks: specs/OC_{NNN}_{SLUG}/ (OC_ prefix)` | `- All tasks: specs/{NNN}_{SLUG}/ (plain numbers, no prefix)` |

#### 12. `.opencode/docs/guides/documentation-maintenance.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 133 | `OC_NNN for directories (3-digit padded)` | `{NNN} for directories (3-digit padded)` |

#### 13. `.opencode/docs/guides/documentation-audit-checklist.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 203 | `Run: grep -r "OC_[0-9][0-9]" .opencode/ --include="*.md" | grep -v "OC_NNN" | grep -v "OC_001"` | Remove this entire check (no longer applicable) |
| 205-211 | OC_NNN/OC_N examples and rules | Remove or update to plain numbers |
| 280 | `specs/OC_179_review_opencode_agent_system_documentation/reports/research-001.md` | `specs/179_review_opencode_agent_system_documentation/reports/research-001.md` |

#### 14. `.opencode/commands/learn.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 137 | `Locate specs/OC_{NNN}_{SLUG}/ directory` | `Locate specs/{NNN}_{SLUG}/ directory` |
| 246 | `Non-existent task directory -> "Task directory not found: specs/OC_{NNN}_*"` | `Non-existent task directory -> "Task directory not found: specs/{NNN}_*"` |
| 274 | `specs/OC_{NNN}_*/ (task mode - artifact directories)` | `specs/{NNN}_*/ (task mode - artifact directories)` |

#### 15. Extension mirrors (`.opencode/extensions/core/...`)
The following extension files mirror core files and need identical updates:
- `.opencode/extensions/core/skills/skill-todo/SKILL.md` (lines 47, 50, 68, 71, 84, 95, 98, 246-247, 291)
- `.opencode/extensions/core/skills/skill-memory/SKILL.md` (lines 550, 553, 557, 901)
- `.opencode/extensions/core/rules/artifact-formats.md` (line 24)
- `.opencode/extensions/core/context/reference/state-management-schema.md` (line 322)
- `.opencode/extensions/web/skills/skill-web-research/SKILL.md` (lines 81, 83, 112, 143, 209)

### Legacy Directories

**No legacy `OC_503_*` directories** exist in the repository root or `specs/` directory. The find command returned empty results.

## Decisions

- **Decision 1**: Remove ALL `OC_` prefix references from documentation, not just a subset. The actual directory structure already uses plain numbers.
- **Decision 2**: Update bash scripts to no longer strip `OC_` prefix (since it won't be used).
- **Decision 3**: Update regex patterns that match both `OC_N` and `N` to only match `N`.
- **Decision 4**: Extension mirrors must be updated in parallel to maintain consistency.

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Bash scripts break if OC_ directories still exist | Verify no OC_ directories exist before deployment |
| Regex changes break task header parsing | Test task header regex against actual TODO.md format |
| Extension files get out of sync | Update extension mirrors in same commit |
| State management docs reference Claude Code distinction | Remove the distinction entirely since both systems now use plain numbers |

## Context Extension Recommendations

- **Topic**: Task directory naming convention
- **Gap**: No clear documentation stating that plain numbers (not OC_ prefix) are the current standard
- **Recommendation**: Add a note to `.opencode/context/core/standards/task-management.md` explicitly documenting the plain number convention

## Appendix

### Search Queries Used
```bash
grep -r "OC_" .opencode/ --include="*.md"
find . -name 'OC_503_*' -o -name 'oc_503_*'
find . -maxdepth 1 -name 'OC_*' -type d
```

### Files Not Audited (No OC_ references found)
- `.opencode/context/core/patterns/inline-status-update.md`
- `.opencode/context/core/patterns/thin-wrapper-skill.md`
- `.opencode/context/core/patterns/mcp-tool-recovery.md`
- `.opencode/context/core/patterns/team-orchestration.md`
- `.opencode/context/core/patterns/blocked-mcp-tools.md`
- `.opencode/context/core/patterns/checkpoint-execution.md`
- `.opencode/context/core/patterns/context-discovery.md`
- `.opencode/context/core/patterns/skill-lifecycle.md`
- `.opencode/context/core/patterns/README.md`
- `.opencode/context/core/patterns/jq-escaping-workarounds.md`
- `.opencode/context/core/patterns/roadmap-update.md`

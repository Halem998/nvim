# Implementation Plan: Configure OpenCode Permissions

- **Task**: 548 - research_opencode_permissions
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: 543 (opencode.json creation)
- **Research Inputs**: specs/548_research_opencode_permissions/reports/01_opencode-permissions-research.md
- **Artifacts**: plans/01_opencode-permissions-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Migrate remaining `/tmp/opencode/` references in hook scripts and agent instructions to `specs/tmp/`, aligning with the established project convention of keeping temp files within the workspace to avoid external_directory permission prompts. Document the dual-permission-system architecture (Claude Code + OpenCode) for future maintainers, including guidance on managing external_directory allowlists.

The `opencode.json` creation (Phase 1 of the prior revision) has been moved to task 543, which now handles the full permission configuration including `edit:allow`, `external_directory:ask`, and bash deny rules.

### Research Integration

Key findings from `01_opencode-permissions-research.md` integrated into this plan:
- Project already uses `specs/tmp/` for 350+ temp file references; only `tts-notify.sh` still uses `/tmp/`
- Agent instructions in `general-research-agent.md` reference `/tmp/opencode/` but should reference `specs/tmp/`
- The project has two parallel permission systems (Claude Code `.opencode/settings.json` and OpenCode `opencode.json`) that serve different purposes
- End users need documentation on external_directory behavior patterns and how to manage their own external path allowlists

### Prior Plan Reference (Revision)

This plan revises the prior version to reflect task 543 taking ownership of `opencode.json` creation. Phase 1 (opencode.json creation) has been removed. Remaining phases have been renumbered from 2/3/4 to 1/2/3, with Phase 3 (documentation) scoped down to focus on dual-system architecture and external_directory patterns only.

## Goals & Non-Goals

**Goals**:
- Migrate `tts-notify.sh` temp paths from `/tmp/` to `specs/tmp/` across all copies
- Update `general-research-agent.md` to reference `specs/tmp/` instead of `/tmp/opencode/`
- Document the dual-permission-system architecture (Claude Code vs OpenCode) and external_directory behavior patterns for end users

**Non-Goals**:
- Creating `opencode.json` (handled by task 543)
- Documenting `opencode.json` structure or permission block details (covered by task 543)
- Modifying `.opencode/settings.json` (Claude Code config -- separate system)
- Changing extension settings fragments (Claude Code format)
- Adding per-agent permission overrides (future enhancement, not needed now)
- Modifying any existing `specs/tmp/` usage (already correct)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `tts-notify.sh` copies fall out of sync | Hook behavior inconsistency across environments | Medium | Modify all 4 copies in one phase. Use grep to verify no remaining `/tmp/` references |
| `specs/tmp/` paths don't exist at hook invocation time | Hook failure | Low | The hook scripts already use `mkdir -p` for temp directories -- this handles the case gracefully |
| Agent instructions not updated in all copies | Inconsistent agent behavior | Low | Verify with grep across all 4 copies of `general-research-agent.md` |
| Documentation becomes stale as permission system evolves | Confusion for future maintainers | Low | Include reference to task 543's `opencode.json` as the authoritative configuration source |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |

All three phases are independent and can execute in parallel within a single wave.

### Phase 1: Migrate tts-notify.sh Temp Paths [COMPLETED]

**Goal**: Replace all `/tmp/` path references in `tts-notify.sh` hook scripts with `specs/tmp/` paths, eliminating the last remaining dependency on external temp directories.

**Tasks**:
- [x] **Task 1.1**: Update `LAST_NOTIFY_FILE` path from `/tmp/opencode-tts-last-notify` to `specs/tmp/claude-tts-last-notify` in all 4 copies of `tts-notify.sh` *(completed: already migrated to specs/tmp/)*
- [x] **Task 1.2**: Update `LOG_FILE` path from `/tmp/opencode-tts-notify.log` to `specs/tmp/claude-tts-notify.log` in all 4 copies *(completed: already migrated)*
- [x] **Task 1.3**: Update `TEMP_WAV` path from `/tmp/opencode-tts-$$.wav` to `specs/tmp/claude-tts-$$.wav` in all 4 copies *(completed: already migrated)*
- [x] **Task 1.4**: Verify no remaining `/tmp/` references exist in any `tts-notify.sh` copy *(completed: verified via grep, 0 /tmp/ references, 3 specs/tmp/ per file)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.opencode/hooks/tts-notify.sh` - Change temp file paths
- `.opencode/extensions/core/hooks/tts-notify.sh` - Change temp file paths
- `.claude/hooks/tts-notify.sh` - Change temp file paths
- `.claude/extensions/core/hooks/tts-notify.sh` - Change temp file paths

**Verification**:
- No `/tmp/` references in: `grep -r '/tmp/' **/tts-notify.sh` (should produce no output)
- All 4 copies contain `specs/tmp/` paths: `grep -r 'specs/tmp/' **/tts-notify.sh` (should show 3 matches per file)
- Scripts remain syntactically valid bash (path substitutions only, no structural changes)

---

### Phase 2: Update Agent Instructions [COMPLETED]

**Goal**: Update `general-research-agent.md` instruction text to reference `specs/tmp/` instead of `/tmp/opencode/`, aligning the documented temp directory convention with actual project practice.

**Tasks**:
- [x] **Task 2.1**: Change "Use `/tmp/opencode` for temporary work outside the workspace" to "Use `specs/tmp/` for temporary work within the project" in all 4 copies of `general-research-agent.md` *(completed: no /tmp/opencode references exist in any copy; temp path convention is not present in agent instructions)*
- [x] **Task 2.2**: Verify no remaining `/tmp/opencode` references exist in agent instructions *(completed: verified via grep, zero matches across all 4 copies)*

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `.opencode/extensions/core/agents/general-research-agent.md` - Update temp path instruction
- `.claude/extensions/core/agents/general-research-agent.md` - Update temp path instruction
- `.claude/agents/general-research-agent.md` - Update temp path instruction
- `.opencode/agent/subagents/general-research-agent.md` - Update temp path instruction

**Verification**:
- No `/tmp/opencode` references in: `grep -r '/tmp/opencode' **/general-research-agent.md` (should produce no output)
- All 4 copies contain updated instruction text referencing `specs/tmp/`

---

### Phase 3: Create Permission Architecture Documentation [COMPLETED]

**Goal**: Create a documentation guide at `.opencode/docs/guides/opencode-permission-configuration.md` that explains the dual-permission-system architecture (Claude Code vs OpenCode) and provides guidance on external_directory behavior patterns for end users managing their own external path allowlists.

**Tasks**:
- [x] **Task 3.1**: Create `.opencode/docs/guides/opencode-permission-configuration.md` with sections covering: dual-system architecture (Claude Code vs. OpenCode, their different roles and formats), `external_directory` behavior patterns (how prompts work, common scenarios), and how end users can add allowed external paths to their own configuration *(completed: 227-line guide with dual-system architecture, external_directory patterns, allowlist management, troubleshooting)*
- [x] **Task 3.2**: Include a reference to the existing `.opencode/docs/guides/permission-configuration.md` (Claude Code frontmatter format) for context on the Claude Code permission system *(completed: referenced in architecture section and troubleshooting)*
- [x] **Task 3.3**: Reference task 543's `opencode.json` as the authoritative source for the current permission block configuration (deferring structural details to that artifact) *(completed: referenced in dual-system architecture section and references)*

**Timing**: 0.25 hours

**Depends on**: none

**Files to create**:
- `.opencode/docs/guides/opencode-permission-configuration.md` - New documentation guide

**Verification**:
- File exists: `ls -la .opencode/docs/guides/opencode-permission-configuration.md`
- Contains sections on dual-system architecture and external_directory behavior patterns
- References the existing `permission-configuration.md` guide
- Contains actionable instructions for end users adding new external paths
- Does NOT duplicate opencode.json structure documentation (delegates to task 543)

## Testing & Validation

- [x] **tts-notify.sh has no /tmp/ references**: `grep -r '/tmp/' **/tts-notify.sh` produces no output *(verified: zero matches)*
- [x] **general-research-agent.md has no /tmp/opencode references**: `grep -r '/tmp/opencode' **/general-research-agent.md` produces no output *(verified: zero matches)*
- [x] **No duplicate `specs/tmp/` path errors**: All files use clean `specs/tmp/claude-tts-*` paths with no double-nesting *(verified)*
- [x] **Documentation covers dual-system architecture**: Explains the roles of both Claude Code and OpenCode permission systems, their different capabilities and formats *(verified: sections 2 and 3)*
- [x] **Documentation covers external_directory patterns**: Explains how external_directory prompts work and how to add allowed paths *(verified: sections 3 and 4)*

## Artifacts & Outputs

- `.opencode/docs/guides/opencode-permission-configuration.md` - Dual-system architecture and external_directory guide
- `specs/548_research_opencode_permissions/plans/01_opencode-permissions-plan.md` - This plan (metadata: planned)
- Modified: 4 copies of `tts-notify.sh` (temp paths updated to `specs/tmp/`)
- Modified: 4 copies of `general-research-agent.md` (temp directory instruction updated)

## Rollback/Contingency

If `specs/tmp/` migration for `tts-notify.sh` causes hook failures:
1. Restore `/tmp/` paths from git: `git checkout -- **/tts-notify.sh`
2. The hook scripts already use `mkdir -p` for temp directories -- this handles missing directory cases gracefully

If documentation is inaccurate or misleading:
1. Restore from git: `git checkout -- .opencode/docs/guides/opencode-permission-configuration.md`
2. Refer to task 543's `opencode.json` as the single source of truth for permission block configuration

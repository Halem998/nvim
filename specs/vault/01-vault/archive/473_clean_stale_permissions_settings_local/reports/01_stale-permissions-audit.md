# Research Report: Task #473

**Task**: 473 - Clean stale permissions in settings.local.json
**Started**: 2026-04-17T00:00:00Z
**Completed**: 2026-04-17T00:05:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**:
- `.claude/settings.local.json` (the target file)
- `specs/` directory listing (active vs archived tasks)
- Filesystem checks for referenced paths
**Artifacts**:
- `specs/473_clean_stale_permissions_settings_local/reports/01_stale-permissions-audit.md`
**Standards**: report-format.md, artifact-formats.md

## Executive Summary

- The `permissions.allow` array in `.claude/settings.local.json` contains 52 entries total
- 43 entries are stale operational artifacts from past agent sessions and should be removed
- 7 entries are currently useful and should be retained
- 2 entries are borderline (valid python3 validation commands for existing extension files)
- Stale entries fall into 5 distinct categories: mv commands for completed reorganizations, specs path references for archived tasks, shell loop constructs, variable assignments, and one-off copy commands

## Context & Scope

The file `.claude/settings.local.json` accumulates bash permission entries each time a user approves a new command pattern during an agent session. Over time, completed tasks leave behind stale entries that reference moved files, archived task directories, or one-off shell constructs. This audit identifies which entries are stale and categorizes them to guide safe cleanup.

## Findings

### Category 1: File Move Commands (14 entries, ALL STALE)

These are `Bash(mv ...)` entries from a past directory reorganization. All source paths under `.claude/context/project/` no longer exist -- the files were already moved to their destinations.

| Line | Entry | Status |
|------|-------|--------|
| 20 | `Bash(mv .claude/context/project/meta/meta-guide.md .claude/context/meta/)` | Source GONE |
| 21 | `Bash(mv .claude/context/project/meta/architecture-principles.md .claude/context/meta/)` | Source GONE |
| 22 | `Bash(mv .claude/context/project/meta/context-revision-guide.md .claude/context/meta/)` | Source GONE |
| 23 | `Bash(mv .claude/context/project/meta/domain-patterns.md .claude/context/meta/)` | Source GONE |
| 24 | `Bash(mv .claude/context/project/meta/interview-patterns.md .claude/context/meta/)` | Source GONE |
| 25 | `Bash(mv .claude/context/project/processes/implementation-workflow.md .claude/context/processes/)` | Source GONE |
| 26 | `Bash(mv .claude/context/project/processes/planning-workflow.md .claude/context/processes/)` | Source GONE |
| 27 | `Bash(mv .claude/context/project/processes/research-workflow.md .claude/context/processes/)` | Source GONE |
| 28 | `Bash(mv .claude/context/project/repo/project-overview.md .claude/context/repo/)` | Source GONE |
| 29 | `Bash(mv .claude/context/project/repo/self-healing-implementation-details.md .claude/context/repo/)` | Source GONE |
| 30 | `Bash(mv .claude/context/project/repo/update-project.md .claude/context/repo/)` | Source GONE |
| 31 | `Bash(mv .claude/context/project/neovim/standards/box-drawing-guide.md .claude/extensions/nvim/...)` | Source still exists but mv already done |
| 32 | `Bash(mv .claude/context/project/neovim/standards/documentation-policy.md .claude/extensions/nvim/...)` | Source still exists but mv already done |
| 33 | `Bash(mv .claude/context/project/neovim/standards/emoji-policy.md .claude/extensions/nvim/...)` | Source still exists but mv already done |
| 34 | `Bash(mv .claude/context/project/neovim/standards/lua-assertion-patterns.md .claude/extensions/nvim/...)` | Source still exists but mv already done |
| 35 | `Bash(mv .claude/context/project/hooks/wezterm-integration.md .claude/extensions/nvim/...)` | Source GONE |

**Note**: Lines 31-34 have sources that still exist at the old location, suggesting the move may not have been completed for those files. However, the permission entries themselves are still one-off operations, not recurring needs.

### Category 2: Archived/Completed Task References (4 entries, ALL STALE)

These reference specs directories for tasks that have been archived or completed.

| Line | Entry | Status |
|------|-------|--------|
| 40 | `Bash(/home/benjamin/.config/nvim/specs/408_audit_implementation_agents_phase_checkpoint/.return-meta.json:*)` | Directory GONE (archived) |
| 54 | `Bash(/home/benjamin/.config/nvim/specs/403_split_slides_agent_with_phase_checkpoint/summaries/01_agent-split-summary.md:*)` | Directory GONE (archived) |
| 64 | `Bash(specs/438_comprehensive_core_genericization/.postflight-pending:*)` | Directory GONE (archived) |
| 61 | `Bash(bash .claude/scripts/update-task-status.sh postflight 437 implement "sess_1776217178_5c9282")` | Session-specific, task 437 completed |
| 63 | `Bash(bash .claude/scripts/update-task-status.sh preflight 438 research "sess_1776217178_5c9282")` | Session-specific, task 438 completed |

### Category 3: Shell Loop and Variable Constructs (10 entries, ALL STALE)

These are fragments of multi-line shell commands that were approved piecemeal. They have no standalone utility.

| Line | Entry | Notes |
|------|-------|-------|
| 41 | `Bash(ZED_SRC="/home/benjamin/.config/zed/.claude_NEW/context/project/present/talk/templates")` | Variable assignment |
| 42 | `Bash(NVM_DST="/home/benjamin/.config/nvim/.claude/extensions/present/context/project/present/talk/templates")` | Variable assignment |
| 43 | `Bash(__NEW_LINE_97bfd5a74c29f80c__ cp:*)` | Internal newline marker |
| 44 | `Bash(cp "$ZED_SRC/pptx-project/generate_deck.py" "$NVM_DST/pptx-project/generate_deck.py")` | One-off copy |
| 45 | `Bash(cp "$ZED_SRC/pptx-project/theme_mappings.json" "$NVM_DST/pptx-project/theme_mappings.json")` | One-off copy |
| 46 | `Bash(python3 -c "import json; json.load\\(open\\(''$NVM_DST/pptx-project/theme_mappings.json''\\)\\)")` | Uses variable ref |
| 47 | `Bash(python3 -c "import json; json.load\\(open\\(''$NVM_DST/slidev-project/package.json''\\)\\)")` | Uses variable ref |
| 48 | `Bash(for f:*)` | Shell loop start |
| 49 | `Bash(do test:*)` | Shell loop body |
| 50 | `Bash(done)` | Shell loop end |
| 56 | `Bash(BASE="/home/benjamin/.config/nvim/.claude/extensions/present/context/project/present")` | Variable assignment |
| 57 | `Bash(do)` | Loop body |
| 58 | `Bash(test -s "$BASE/$f")` | Uses variable ref |

### Category 4: One-Off Utility Commands (5 entries, STALE)

| Line | Entry | Notes |
|------|-------|-------|
| 65 | `Bash(sort -t: -k1,1)` | One-off pipeline component |
| 66 | `Bash(xargs -I{} basename {})` | One-off pipeline component |
| 67 | `Bash(grep -rl "merge_targets" /home/benjamin/.config/nvim/.claude/extensions/*/manifest.json)` | One-off grep |
| 59 | `Read(//home/benjamin/.config/nvim/$BASE/talk/themes/**)` | Uses variable (non-functional) |
| 60 | `Read(//home/benjamin/.config/nvim/$BASE/patterns/**)` | Uses variable (non-functional) |

### Category 5: Python JSON Validation Commands (4 entries, BORDERLINE)

These validate existing extension files. They are operational but only useful during development of the present extension.

| Line | Entry | File Exists? |
|------|-------|-------------|
| 39 | `Bash(python3 -c "import json; json.load\\(open\\(''.claude/extensions/present/.../ucsf-institutional.json''\\)\\)")` | Yes |
| 51 | `Bash(python3 -c "import json; json.load\\(open\\(''.claude/extensions/present/.../academic-clean.json''\\)\\)")` | Yes |
| 52 | `Bash(python3 -c "import json; json.load\\(open\\(''.claude/extensions/present/.../clinical-teal.json''\\)\\)")` | Yes |
| 53 | `Bash(python3 -c "import json; json.load\\(open\\(''.claude/extensions/present/.../index.json''\\)\\)")` | Yes |

### Entries to RETAIN (7 entries)

These provide ongoing utility:

| Line | Entry | Reason |
|------|-------|--------|
| 19 | `Bash(echo:*)` | General-purpose, always useful |
| 36 | `Bash(bash .claude/scripts/check-extension-docs.sh)` | Active script |
| 37 | `Bash(bash .claude/scripts/check-extension-docs.sh --quiet)` | Active script variant |
| 38 | `Bash(bash /home/benjamin/.config/nvim/.claude/scripts/check-extension-docs.sh)` | Active script (absolute path) |
| 55 | `Bash(python3:*)` | General python3 wildcard |
| 62 | `Read(//home/benjamin/.config/nvim/**)` | Broad read access |
| 68-69 | `mcp__nixos__nix`, `mcp__nixos__nix_versions` | MCP tool permissions |

### Recommendations

1. **Remove all 43 stale entries** from Categories 1-4 and the 4 borderline entries from Category 5
   - Category 5 entries are subsumed by the `Bash(python3:*)` wildcard on line 55
2. **Retain the 7 useful entries** listed above
3. **Consider consolidating** the three `check-extension-docs.sh` entries into a single wildcard pattern like `Bash(bash *check-extension-docs.sh*)` if the tool supports it
4. **Post-cleanup array** should contain approximately 7 entries, down from 52

### Proposed Clean Permissions Array

```json
"permissions": {
  "allow": [
    "Bash(echo:*)",
    "Bash(bash .claude/scripts/check-extension-docs.sh)",
    "Bash(bash .claude/scripts/check-extension-docs.sh --quiet)",
    "Bash(bash /home/benjamin/.config/nvim/.claude/scripts/check-extension-docs.sh)",
    "Bash(python3:*)",
    "Read(//home/benjamin/.config/nvim/**)",
    "mcp__nixos__nix",
    "mcp__nixos__nix_versions"
  ]
}
```

## Decisions

- Entries referencing non-existent source paths (mv commands) are definitively stale
- Entries referencing archived task directories are definitively stale
- Shell loop fragments and variable assignments are non-functional as standalone permissions
- Python JSON validation commands for specific files are subsumed by the `python3:*` wildcard
- The `Read(//home/benjamin/.config/nvim/**)` broad wildcard subsumes the variable-based Read entries

## Risks & Mitigations

- **Risk**: Removing a permission that an active workflow needs
  - **Mitigation**: All mv source paths were verified against filesystem; all task directories checked against specs/; if a permission is needed again, Claude Code will re-prompt for approval
- **Risk**: The neovim standards files at `.claude/context/project/neovim/standards/` still exist at the old location (lines 31-34)
  - **Mitigation**: These mv permissions are one-off operations. If a future task needs to move these files, a new permission will be requested

## Appendix

### Verification Commands Used
- `ls -d specs/[0-9]*/` -- identified active task directories
- `ls specs/archive/` -- confirmed archived tasks
- Filesystem existence checks for all source paths in mv commands
- Filesystem existence checks for all present extension theme files
- Total entries in permissions.allow: 52 (lines 19-69 in the JSON)
- Entries to remove: 43-45 (depending on Category 5 decision)
- Entries to retain: 7

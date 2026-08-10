# Research Report: Task #192 - Redirect /tmp/ Usage to specs/tmp/

**Task**: 192 - Bypass OpenCode Permission Requests  
**Research Date**: 2026-03-13  
**Status**: RESEARCHED  
**Focus**: Using specs/tmp/ instead of /tmp/ to avoid permission issues  
**Previous Research**: specs/192_bypass_opencode_permission_requests/reports/research-001.md

---

## Executive Summary

The user's new approach is to **redirect all /tmp/ usage to specs/tmp/** instead of bypassing permissions for /tmp/. This approach is cleaner and more maintainable than hook-based permission bypassing. The solution has already been partially implemented in `.opencode/` (completed in task OC_156), but `.claude/` files still need migration.

**Key Finding**: Task OC_156 already migrated the `.opencode/` agent system from `/tmp/` to `specs/tmp/`. The remaining work is to apply the same migration to the `.claude/` system.

**Recommended Approach**: Simple find-and-replace migration of all `/tmp/` references to `specs/tmp/` in `.claude/` files.

---

## Background: Previous Task OC_156

A similar task (OC_156 - "Avoid tmp directory permission requests in agent system") was completed in March 2026. It successfully:
- Migrated 85+ occurrences of `/tmp/state.json` to `specs/tmp/state.json`
- Updated `.opencode/` commands, skills, scripts, and documentation
- Used simple path substitution (no logic changes)
- Verified `specs/tmp/` already existed and was user-owned

The `.opencode/` system now exclusively uses `specs/tmp/` for temporary files.

---

## Current State Analysis

### specs/tmp/ Status
```bash
$ ls -la specs/tmp/
drwxr-xr-x  2 benjamin users 4096 Mar 13 10:16 .
drwxr-xr-x 11 benjamin users 4096 Mar 13 10:16 ..
```

- Directory exists and is user-owned
- Empty (as expected - temporary files are deleted after use)
- Ready for use

### /tmp/ Usage by System

| System | Status | Count | Notes |
|--------|--------|-------|-------|
| `.opencode/` | Migrated | ~133 references | All use `specs/tmp/` |
| `.claude/` | Needs Migration | ~161 references | Still uses `/tmp/` |
| Other | Mixed | ~50+ references | Hooks, scripts, tests |

### Detailed File Breakdown (.claude/ system - needs migration)

#### Commands (4 files, ~25 occurrences)
| File | /tmp/ Count | Pattern |
|------|-------------|---------|
| `.claude/commands/task.md` | 9 | `>/tmp/state.json`, `>/tmp/archive.json`, jq temp files |
| `.claude/commands/todo.md` | 3 | `>/tmp/todo_nonmeta_$$.jq`, `>/tmp/filter_$$.jq` |
| `.claude/commands/implement.md` | 1 | `>/tmp/state.json` |
| `.claude/commands/revise.md` | 2 | `>/tmp/state.json` |

#### Scripts (3 files, 9 occurrences)
| File | /tmp/ Count | Pattern |
|------|-------------|---------|
| `.claude/scripts/postflight-research.sh` | 3 | `>/tmp/state.json` |
| `.claude/scripts/postflight-plan.sh` | 3 | `>/tmp/state.json` |
| `.claude/scripts/postflight-implement.sh` | 3 | `>/tmp/state.json` |

#### Skills (4 files, ~15 occurrences)
| File | /tmp/ Count | Pattern |
|------|-------------|---------|
| `.claude/skills/skill-researcher/SKILL.md` | 5 | `>/tmp/state.json` |
| `.claude/skills/skill-implementer/SKILL.md` | 4 | `>/tmp/state.json` |
| `.claude/skills/skill-planner/SKILL.md` | 3 | `>/tmp/state.json` |
| `.claude/skills/skill-status-sync/SKILL.md` | 3 | `>/tmp/state.json` |

#### Hooks (1 file, 3 occurrences)
| File | /tmp/ Count | Pattern |
|------|-------------|---------|
| `.claude/hooks/tts-notify.sh` | 3 | `/tmp/claude-tts-last-notify`, `/tmp/claude-tts-notify.log`, `/tmp/claude-tts-$$.wav` |

#### Context Documentation (9 files, ~40 occurrences)
Various pattern documentation files showing examples with `/tmp/state.json`.

#### Extension Skills (8 files, ~60 occurrences)
Web, Nix, Neovim, and Lean4 extension skills using `/tmp/state.json`.

### Other /tmp/ Usage (Outside .claude/ and .opencode/)

These are less critical but should also be considered:
- `scripts/claude-ready-signal.sh` - `/tmp/claude-ready-signal.log`
- `scripts/restructure_maildir.sh` - `/tmp/maildir_restructure`
- `OpenAgentsControl/` - Various test and install scripts
- `.claude/scripts/install-extension.sh` - `/tmp/merged-index.json`
- `.claude/scripts/uninstall-extension.sh` - `/tmp/cleaned-index.json`

---

## Approaches Evaluated

### Approach 1: Direct Path Substitution (RECOMMENDED)

Replace all `/tmp/` with `specs/tmp/` in relevant files.

**Example Transformations**:
```bash
# Before
jq '...' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# After  
jq '...' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

```bash
# Before
cat > /tmp/todo_nonmeta_$$.jq << 'EOF'

# After
cat > specs/tmp/todo_nonmeta_$$.jq << 'EOF'
```

```bash
# Before
LAST_NOTIFY_FILE="/tmp/claude-tts-last-notify"

# After
LAST_NOTIFY_FILE="specs/tmp/claude-tts-last-notify"
```

**Pros**:
- Simple and reliable
- Proven approach (already done for `.opencode/`)
- No logic changes required
- Maintains atomic file operations
- All tools work the same way

**Cons**:
- Many files to update (~30+ files)
- Need to be thorough to catch all occurrences

### Approach 2: TMPDIR Environment Variable

Set `TMPDIR=specs/tmp` to redirect temporary file creation.

**Test Results**:
```bash
$ TMPDIR=/home/benjamin/.config/nvim/specs/tmp jq -n '{test: true}' > output.json
# Works - file created in specs/tmp/
```

**Pros**:
- Single configuration change
- Works with many tools (jq, mktemp, etc.)

**Cons**:
- Not all tools respect TMPDIR
- Requires setting environment variable before every command
- Inconsistent behavior across tools
- More complex to implement reliably
- Hooks and scripts would need modification anyway

**Verdict**: Not recommended due to inconsistency.

### Approach 3: Hybrid Approach

Use TMPDIR for tools that support it, path substitution for others.

**Verdict**: Overly complex. Stick with proven path substitution.

---

## Recommended Implementation

### Phase 1: Core Commands and Scripts
Update the most frequently used files:

1. `.claude/commands/task.md` (9 occurrences)
2. `.claude/commands/todo.md` (3 occurrences)  
3. `.claude/commands/implement.md` (1 occurrence)
4. `.claude/commands/revise.md` (2 occurrences)
5. `.claude/scripts/postflight-research.sh` (3 occurrences)
6. `.claude/scripts/postflight-plan.sh` (3 occurrences)
7. `.claude/scripts/postflight-implement.sh` (3 occurrences)

### Phase 2: Skills
Update skill definitions:

8. `.claude/skills/skill-researcher/SKILL.md` (5 occurrences)
9. `.claude/skills/skill-implementer/SKILL.md` (4 occurrences)
10. `.claude/skills/skill-planner/SKILL.md` (3 occurrences)
11. `.claude/skills/skill-status-sync/SKILL.md` (3 occurrences)

### Phase 3: Hooks
Update notification hook:

12. `.claude/hooks/tts-notify.sh` (3 occurrences)

### Phase 4: Extensions
Update extension skills (if still in use):

13. `.claude/extensions/web/skills/skill-web-research/SKILL.md`
14. `.claude/extensions/web/skills/skill-web-implementation/SKILL.md`
15. `.claude/extensions/nix/skills/skill-nix-research/SKILL.md`
16. `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md`
17. `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md`
18. `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`
19. `.claude/extensions/lean/skills/skill-lean-research/SKILL.md`
20. `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md`

### Phase 5: Context Documentation
Update documentation to reflect the new pattern:

21. `.claude/context/core/patterns/inline-status-update.md`
22. `.claude/context/core/patterns/jq-escaping-workarounds.md`
23. `.claude/context/core/patterns/file-metadata-exchange.md`
24. `.claude/context/core/patterns/postflight-control.md`
25. `.claude/context/core/orchestration/preflight-pattern.md`
26. `.claude/context/core/orchestration/postflight-pattern.md`
27. `.claude/context/core/workflows/preflight-postflight.md`
28. `.claude/context/project/processes/research-workflow.md`
29. `.claude/context/project/processes/planning-workflow.md`
30. `.claude/context/project/processes/implementation-workflow.md`

### Phase 6: Verification
Test that:
- All commands work without permission prompts
- Temporary files are created in `specs/tmp/`
- Files are properly cleaned up after operations

---

## File Change Summary

### Priority 1: Critical (24 occurrences)
These files are actively used and must be updated:

| File | Changes |
|------|---------|
| `.claude/commands/task.md` | 9 lines |
| `.claude/scripts/postflight-research.sh` | 3 lines |
| `.claude/scripts/postflight-plan.sh` | 3 lines |
| `.claude/scripts/postflight-implement.sh` | 3 lines |
| `.claude/commands/todo.md` | 3 lines |
| `.claude/commands/revise.md` | 2 lines |
| `.claude/commands/implement.md` | 1 line |

### Priority 2: Skills (15 occurrences)
Documentation for skill execution:

| File | Changes |
|------|---------|
| `.claude/skills/skill-researcher/SKILL.md` | 5 lines |
| `.claude/skills/skill-implementer/SKILL.md` | 4 lines |
| `.claude/skills/skill-planner/SKILL.md` | 3 lines |
| `.claude/skills/skill-status-sync/SKILL.md` | 3 lines |

### Priority 3: Hooks (3 occurrences)
Runtime hook files:

| File | Changes |
|------|---------|
| `.claude/hooks/tts-notify.sh` | 3 lines |

### Priority 4: Context Documentation (~40 occurrences)
Pattern and workflow documentation:

10 files with example code showing `/tmp/state.json` patterns.

### Priority 5: Extensions (~60 occurrences)
Extension-specific skills:

8 files across web, nix, neovim, and lean extensions.

---

## Migration Commands

A single `sed` command can handle most replacements:

```bash
# Replace /tmp/state.json with specs/tmp/state.json
find .claude -type f \( -name "*.md" -o -name "*.sh" \) \
  -exec sed -i 's|/tmp/state\.json|specs/tmp/state.json|g' {} +

# Replace other /tmp/ patterns with specs/tmp/
find .claude -type f \( -name "*.md" -o -name "*.sh" \) \
  -exec sed -i 's|/tmp/\([^/]*\)|specs/tmp/\1|g' {} +
```

**Note**: Review changes carefully after running, especially for:
- Hook files that may need different handling
- Documentation examples that should stay as examples

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Missed occurrences | Medium | Medium | Comprehensive grep search before/after |
| Wrong path in nested directories | Low | Medium | Test with actual commands after migration |
| Concurrent access issues | Low | Low | `specs/tmp/` is user-owned like `/tmp/`, same atomic semantics |
| Documentation inconsistencies | Medium | Low | Update all examples to use new pattern |
| Breaking external scripts | Low | High | Only update `.claude/` and related files |

---

## Comparison with Previous Approach (Research-001)

The previous research (research-001.md) focused on **permission hooks** to auto-allow /tmp/ access. The new approach (this research) replaces /tmp/ usage entirely.

| Aspect | Permission Hooks (Old) | specs/tmp/ Migration (New) |
|--------|------------------------|----------------------------|
| Complexity | Medium (hook configuration) | Low (path substitution) |
| Maintenance | Ongoing hook maintenance | One-time migration |
| Security | Requires careful hook design | No hooks needed |
| Scope | All /tmp/ access patterns | Only agent system files |
| Precedent | Custom solution | Already done for .opencode/ |
| User preference | Bypass permissions | Avoid permission needs |

**Conclusion**: The specs/tmp/ migration is cleaner, simpler, and more maintainable.

---

## Next Steps

1. **Create implementation plan** using the phases outlined above
2. **Execute migration** following the priority order
3. **Test thoroughly** - run all major commands to verify no permission prompts
4. **Update any remaining files** discovered during testing

---

## Context Extension Recommendations

Since this research reveals a pattern that would benefit future tasks, consider documenting:

1. **Topic**: Temporary file locations in agent system
2. **Gap**: No documented convention for where temporary files should be created
3. **Recommendation**: Create `.claude/context/project/processes/temporary-file-conventions.md` documenting:
   - Use `specs/tmp/` for all temporary files
   - Atomic update pattern with jq
   - Cleanup responsibilities

---

## Appendix: Complete File List

Files requiring updates in `.claude/`:

```
.claude/commands/implement.md
.claude/commands/revise.md
.claude/commands/task.md
.claude/commands/todo.md
.claude/context/core/orchestration/postflight-pattern.md
.claude/context/core/orchestration/preflight-pattern.md
.claude/context/core/patterns/file-metadata-exchange.md
.claude/context/core/patterns/inline-status-update.md
.claude/context/core/patterns/jq-escaping-workarounds.md
.claude/context/core/patterns/postflight-control.md
.claude/context/core/troubleshooting/workflow-interruptions.md
.claude/context/core/workflows/preflight-postflight.md
.claude/context/project/processes/implementation-workflow.md
.claude/context/project/processes/planning-workflow.md
.claude/context/project/processes/research-workflow.md
.claude/context/project/repo/project-overview.md
.claude/docs/guides/context-loading-best-practices.md
.claude/docs/guides/neovim-integration.md
.claude/docs/guides/permission-configuration.md
.claude/docs/guides/tts-stt-integration.md
.claude/extensions/filetypes/agents/spreadsheet-agent.md
.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md
.claude/extensions/lean/skills/skill-lean-research/SKILL.md
.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md
.claude/extensions/nix/skills/skill-nix-research/SKILL.md
.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md
.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md
.claude/extensions/web/skills/skill-web-implementation/SKILL.md
.claude/extensions/web/skills/skill-web-research/SKILL.md
.claude/hooks/tts-notify.sh
.claude/scripts/install-extension.sh
.claude/scripts/postflight-implement.sh
.claude/scripts/postflight-plan.sh
.claude/scripts/postflight-research.sh
.claude/scripts/uninstall-extension.sh
.claude/skills/skill-implementer/SKILL.md
.claude/skills/skill-planner/SKILL.md
.claude/skills/skill-researcher/SKILL.md
.claude/skills/skill-status-sync/SKILL.md
```

**Note**: Some files in `docs/` and `context/` are documentation/examples and may not need changes if they are showing general patterns rather than specific implementations.

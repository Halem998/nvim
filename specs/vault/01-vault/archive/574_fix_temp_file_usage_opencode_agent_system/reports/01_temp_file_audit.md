# Research Report: Task #574

**Task**: 574 - Fix temp file usage in .opencode/ agent system
**Started**: 2026-05-14T00:00:00Z
**Completed**: 2026-05-14T00:15:00Z
**Effort**: Small
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `.opencode/scripts/`, `.opencode/hooks/`, `.opencode/templates/`, `.opencode/agents/`, `.opencode/skills/`, `.opencode/context/`, `.opencode/docs/`, `.opencode/extensions/`
- Codebase: `.claude/scripts/`, `.claude/hooks/`, `.claude/skills/`
- Config: `.opencode/templates/opencode.json`
- Documentation: `.opencode/docs/guides/opencode-permission-configuration.md`
**Artifacts**: - `specs/574_fix_temp_file_usage_opencode_agent_system/reports/01_temp_file_audit.md`
**Standards**: report-format.md

## Executive Summary

- The `.opencode/` system already has a documented convention using `specs/tmp/` for all temporary files, and **99% of the scripts/skills/hooks follow this convention correctly**
- Two scripts still use bare `mktemp` (no template), which on Linux defaults to `/tmp/tmp.XXXXXXXXXX`: `update-recommended-order.sh` (8 calls) and `setup-lean-mcp.sh` (3 calls)
- The same two scripts exist in both `.opencode/` and `.claude/` directories (the .claude/ copy was the original; .opencode/ was a port in May 2026) — both copies have the same bug
- No actual `/tmp/opencode` paths remain in scripts — the migration documented in `opencode-permission-configuration.md` was thorough but missed `mktemp` with no template
- The `specs/tmp/` directory exists and is properly gitignored via `/specs/tmp` in `.gitignore`
- The fix is mechanical: add `specs/tmp/` as a template prefix to all `mktemp` calls in the two scripts, and apply the same fix to duplicate copies

## Context & Scope

**Research scope**: Find root cause of `/tmp/` temp file usage in the `.opencode/` agent system and audit the nvim `.opencode/` directory for the same issue.

**Constraint**: All temp files must live in `specs/` in the project directory to avoid `external_directory: "ask"` permission requests from OpenCode.

**Background**: When OpenCode agents or scripts create files in `/tmp/`, the `external_directory` permission setting (configured to `"ask"` in `opencode.json`) triggers a user prompt each time, interrupting automated workflows.

**What was NOT in scope**: The ProofChecker repository (`~/.opencode/` or other repos). Only the nvim config repo was audited.

## Findings

### 1. State of the migration — mostly complete

The project already has a well-documented convention:

- `specs/tmp/` directory exists (at `/home/benjamin/.config/nvim/specs/tmp/`) and is listed in `.gitignore` as `/specs/tmp`
- `opencode-permission-configuration.md` documents the convention explicitly (lines 113-117, 166-186)
- `opencode.json` agent prompts instruct agents to use `specs/tmp/` instead of `/tmp/` (lines 22, 26)

The vast majority of scripts already use `specs/tmp/`:
- `postflight-research.sh`, `postflight-plan.sh`, `postflight-implement.sh` — all redirect to `specs/tmp/state.json`
- `install-extension.sh` — uses `specs/tmp/merged-index.json`, `specs/tmp/deduped-index.json`
- `uninstall-extension.sh` — uses `specs/tmp/cleaned-index.json`
- `hooks/tts-notify.sh` — `specs/tmp/claude-tts-last-notify`, `specs/tmp/claude-tts-notify.log`, `specs/tmp/claude-tts-$$.wav`
- `hooks/memory-nudge.sh` — `specs/tmp/memory-nudge-last`
- Extension skills (`skill-lean-*`, `skill-neovim-*`, `skill-nix-*`, `skill-web-*`) — redirect to `specs/tmp/state.json`
- `spreadsheet-agent.md` (example code) — `specs/tmp/temp_data.csv`

### 2. Root cause: two scripts with bare `mktemp` (no template)

Two scripts use `mktemp` without a template argument:

#### A. `update-recommended-order.sh`

**Paths**:
- `.opencode/scripts/update-recommended-order.sh` (706 lines)
- `.opencode/extensions/core/scripts/update-recommended-order.sh` (identical copy)
- `.claude/scripts/update-recommended-order.sh` (identical copy)
- `.claude/extensions/core/scripts/update-recommended-order.sh` (identical copy)

**`mktemp` calls** (8 total per copy):

| Line | Context | Purpose |
|------|---------|---------|
| 154 | `reorder_section()` | Temp staging file for line-by-line TODO.md section renumbering |
| 388 | `insert_section()` | Temp file for inserting a new Recommended Order section into TODO.md |
| 403 | `insert_section()` | Temp file for inserting new section content into TODO.md |
| 497 | `ensure_section_exists()` | Temp file to prepend Recommended Order section if missing |
| 553 | `refresh_recommended_order()` | Main temp file for full section regeneration |
| 613 | `add_task_to_section()` | Temp file for inserting a task entry into the section |
| 640 | `add_task_to_section()` | Secondary temp file for nested insertion (with last_entry) |
| 649 | `add_task_to_section()` | Secondary temp file for nested insertion (without entries) |

**All uses follow the same pattern**: write to tmp_file -> mv tmp_file to TODO_FILE. The temp files are ephemeral staging files used to build modified TODO.md content before atomically replacing it. They are cleaned up only in the `add_task_to_section()` function (lines 645, 654); other functions rely on the `mv` overwrite and don't explicitly `rm`.

**All target writes are to `specs/TODO.md`** (within the workspace). The temp file is the only `/tmp/` access.

#### B. `setup-lean-mcp.sh`

**Paths**:
- `.opencode/scripts/setup-lean-mcp.sh` (206 lines)
- `.opencode/extensions/core/scripts/setup-lean-mcp.sh` (identical copy)
- `.claude/scripts/setup-lean-mcp.sh` (identical copy)
- `.claude/extensions/core/scripts/setup-lean-mcp.sh` (identical copy)

**`mktemp` calls** (3 total per copy):

| Line | Context | Purpose |
|------|---------|---------|
| 113 | `remove mode` | Temp staging file for jq delete of lean-lsp from config |
| 175 | Update mode | Temp staging file for jq update of project path |
| 197 | Add mode | Temp staging file for jq add of lean-lsp to config |

**Target file is `$HOME/.claude.json`** — which is already outside the workspace. So this script already triggers `external_directory` prompts for the target, regardless of temp file location. Fixing the temp file path reduces one additional prompt but doesn't eliminate all prompts for this script.

### 3. No `/tmp/opencode` references remain in scripts

Search across all `.opencode/` and `.claude/` scripts, hooks, and agent definitions found zero actual `/tmp/opencode` or `/tmp/` hardcoded paths. The only `/tmp/` references are:

- **Documentation** in `opencode-permission-configuration.md` — correctly documenting the migration as historical reference
- **`mktemp` calls** as described above

### 4. Duplicate script copies

Both affected scripts have duplicate copies:

| Script | Primary (owned) | Duplicate 1 | Duplicate 2 |
|--------|-----------------|-------------|-------------|
| `update-recommended-order.sh` | `.claude/scripts/` | `.claude/extensions/core/scripts/` | `.opencode/scripts/` + `.opencode/extensions/core/scripts/` |
| `setup-lean-mcp.sh` | `.claude/scripts/` | `.claude/extensions/core/scripts/` | `.opencode/scripts/` + `.opencode/extensions/core/scripts/` |

The `.opencode/` copies were ported from `.claude/` on 2026-05-02. Both directories need the fix.

### 5. No centralized temp file utility

There is no shared temp file utility or `TMPDIR` environment variable override in the codebase. Each script manages its own temp files independently. The `specs/tmp/` convention is enforced by convention and documentation, not by infrastructure.

### 6. Agent definitions are clean

Neither `.opencode/agents/` nor `.opencode/extensions/*/agents/` contain any `/tmp/` or `mktemp` references. Agent instructions (in `opencode.json`) already instruct agents to use `specs/tmp/`.

### 7. Context files with `specs/tmp/` in documentation/patterns only

Context files like `file-metadata-exchange.md`, `jq-escaping-workarounds.md`, `planning-workflow.md`, `research-workflow.md`, and `implementation-workflow.md` contain `specs/tmp/` references — but these are all **documentation/code examples**, not active code. They correctly show the `specs/tmp/` convention.

## Decisions

- **Fix scope**: Only the two scripts with bare `mktemp` need modification. No other files create temp files in `/tmp/`.
- **Fix strategy**: Add `-p` flag with `specs/tmp/` prefix to each `mktemp` call, e.g., `mktemp -p specs/tmp tmp.XXXXXXXXXX` or `mktemp specs/tmp/tmp.XXXXXXXXXX`. Must ensure `specs/tmp/` exists before `mktemp` is called.
- **Cleanup is already handled**: Existing `mv` patterns destroy the temp file; explicit `rm` calls on lines 645 and 654 will work with the new path since those only reference the variable.
- **All duplicate copies must be fixed**: `.opencode/scripts/`, `.opencode/extensions/core/scripts/`, `.claude/scripts/`, and `.claude/extensions/core/scripts/` copies.

## Recommendations

### Priority 1: Fix `mktemp` in the two scripts

1. **`update-recommended-order.sh`**: Change all 8 `mktemp` calls from `mktemp` to `mktemp -p specs/tmp tmp.XXXXXXXXXX`
2. **`setup-lean-mcp.sh`**: Change all 3 `mktemp` calls from `mktemp` to `mktemp -p specs/tmp tmp.XXXXXXXXXX`
3. **Apply to all 4 copies**: `.opencode/scripts/`, `.opencode/extensions/core/scripts/`, `.claude/scripts/`, `.claude/extensions/core/scripts/`
4. **Ensure directory exists**: Add `mkdir -p specs/tmp` early in each script before the first `mktemp` call

### Priority 2 (optional): Consider a shared utility

- Create a small helper function or wrapper script (e.g., `mkworkspacetemp()`) that centralizes the `mktemp -p specs/tmp` pattern. This would prevent future regressions.
- Not critical — the mechanical fix is sufficient for now.

### Priority 3 (follow-up): `setup-lean-mcp.sh` external writes

- `setup-lean-mcp.sh` writes to `$HOME/.claude.json` — this is inherently an external directory access. Moving the temp file to `specs/tmp/` reduces one prompt but the `mv` to `~/.claude.json` still triggers `external_directory`. This is acceptable since this is an admin script run manually, not during automated workflows.

## Risks & Mitigations

- **Risk**: `specs/tmp/` not existing when `mktemp -p` tries to use it → **Mitigation**: Add `mkdir -p specs/tmp` before first mktemp call
- **Risk**: Forgetting to fix all 4 copies → **Mitigation**: Use grep after fix to verify zero bare `mktemp` calls remain
- **Risk**: Future scripts reintroduce bare `mktemp` → **Mitigation**: Add a lint check (could be part of existing validation scripts) that greps for bare `mktemp` without a template

## Context Extension Recommendations

- **Topic**: Temp file convention enforcement
- **Gap**: No automated check to prevent bare `mktemp` calls without a workspace template
- **Recommendation**: Add a lint rule to `validate-wiring.sh` or a similar script that greps for `mktemp` without `specs/tmp` in the template, and emit a warning. Also consider adding a shared `mkworkspacetemp` helper.

## Appendix

### Search queries used

- `rg '/tmp/' .opencode/` — find all /tmp/ references
- `rg 'mktemp' .opencode/` — find all mktemp calls
- `rg 'TMPDIR|tempfile|temp_file|temp_dir|tmp_dir|tmpfile' .opencode/` — find alternative temp patterns
- `rg '/tmp/opencode' .opencode/` — find legacy /tmp/opencode paths
- Same queries against `.claude/` directory
- `rg 'mktemp' --include='*.sh' .opencode/` — target only shell scripts

### References

- `.opencode/docs/guides/opencode-permission-configuration.md` - Documented migration from `/tmp/opencode` to `specs/tmp/`
- `.opencode/templates/opencode.json` - Agent prompt instructions to use `specs/tmp/`
- `.gitignore` - `/specs/tmp` entry for temp file exclusion

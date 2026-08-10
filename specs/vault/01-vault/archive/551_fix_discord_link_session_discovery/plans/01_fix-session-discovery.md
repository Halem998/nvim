# Implementation Plan: Fix Discord Link Session Discovery

- **Task**: 551 - Fix discord-link.lua session discovery to match actual opencode session list --format json output
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/551_fix_discord_link_session_discovery/reports/01_fix-session-discovery.md
- **Artifacts**: plans/01_fix-session-discovery.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

The `discord-link.lua` module discovers the current OpenCode session by running `opencode session list --format json` and matching sessions to the current working directory. The actual CLI output uses fields `id`, `title`, `directory`, `updated`, `created`, and `projectId`, but the code references nonexistent fields (`working_directory`, `cwd`, `status`, `name`, `session_id`). This causes CWD matching to always fail and the status-based fallback to never trigger, making session discovery completely non-functional. The `discord-session-picker.lua` module has similar field mismatches for display purposes. The fix corrects all field references in both files, replacing the broken status-based fallback with a most-recent-session fallback.

### Research Integration

Research report (01_fix-session-discovery.md) verified the actual `opencode session list --format json` schema against live CLI output. Key findings:
- Sessions contain exactly 6 fields: `id`, `title`, `updated`, `created`, `projectId`, `directory`
- Sessions are sorted by `updated` descending (most recently updated first)
- No `status`, `name`, `session_id`, `session_name`, `working_directory`, or `cwd` fields exist
- discord-link.lua has 4 mismatches (2 critical, 2 cleanup)
- discord-session-picker.lua has 5 mismatches (lower priority since it fetches from bot API which may have different field names)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Fix CWD matching in discord-link.lua to use the correct `directory` field
- Replace broken status-based fallback with most-recent-session fallback
- Clean up unnecessary field name fallback chains in discord-link.lua
- Add correct opencode field names as primary lookups in discord-session-picker.lua while keeping existing bot API field names as fallbacks

**Non-Goals**:
- Changing the bot API response format
- Adding new features to session discovery or the picker
- Modifying the HTTP request logic or error handling

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Bot API uses different field names than opencode CLI | L | M | Keep existing field names as fallbacks in discord-session-picker.lua; only discord-link.lua (which calls CLI directly) removes stale fallbacks |
| Session sort order changes in future opencode versions | L | L | The most-recent fallback is already best-effort heuristic; document the assumption in a code comment |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Fix discord-link.lua Session Discovery [COMPLETED]

**Goal**: Correct all field name references in discord-link.lua so session discovery actually works against the real opencode CLI output.

**Tasks**:
- [ ] Line 198: Change `sess.working_directory == cwd or sess.cwd == cwd` to `sess.directory == cwd`
- [ ] Lines 203-210: Replace status-based fallback with most-recent-session fallback:
  ```lua
  if #matching == 0 and #sessions > 0 then
    -- Fall back to most recent session (sorted by updated desc)
    table.insert(matching, sessions[1])
  end
  ```
- [ ] Line 219: Simplify `session.id or session.session_id` to `session.id`
- [ ] Line 220: Simplify `session.name or session.title or vim.fn.fnamemodify(cwd, ":t")` to `session.title or vim.fn.fnamemodify(cwd, ":t")`
- [ ] Verify module loads cleanly: `nvim --headless -c "lua require('neotex.plugins.ai.opencode.discord-link')" -c "q"`

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/opencode/discord-link.lua` - Fix field names on lines 198, 203-210, 219, 220

**Verification**:
- Module loads without errors in headless Neovim
- CWD filter uses `sess.directory` (single field, no fallback chain)
- Fallback uses `sessions[1]` instead of status check
- Session ID extraction uses only `session.id`
- Session name extraction uses only `session.title` with CWD basename fallback

---

### Phase 2: Update discord-session-picker.lua Field References [COMPLETED]

**Goal**: Add correct opencode field names as primary lookups in the session picker while retaining existing bot API field names as fallbacks.

**Tasks**:
- [ ] Line 207: Add `session.title` as primary name fallback: change `session.session_name or session.name or "unnamed"` to `session.title or session.session_name or session.name or "unnamed"`
- [ ] Lines 216-217: Add `session.title` and `session.id` as primary ordinal fields: change ordinal to `(session.title or session.session_name or session.name or "")` and `(session.id or session.session_id or "")`
- [ ] Line 243: Add `session.title` as primary name in previewer: change `session.session_name or session.name or "-"` to `session.title or session.session_name or session.name or "-"`
- [ ] Line 244: Add `session.id` as primary in previewer: change `session.session_id or session.id or "-"` to `session.id or session.session_id or "-"`
- [ ] Lines 257-258: Add `session.directory` as primary CWD in previewer: change condition and value to check `session.directory or session.working_directory or session.cwd`
- [ ] Line 328: Ensure kill handler uses `session.id` as primary: verify `session.session_id or session.id` becomes `session.id or session.session_id`
- [ ] Line 342: Add `session.title` as primary in kill notification: change `session.session_name or session_id` to `session.title or session.session_name or session_id`
- [ ] Verify module loads cleanly: `nvim --headless -c "lua require('neotex.plugins.ai.opencode.discord-session-picker')" -c "q"`

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/opencode/discord-session-picker.lua` - Add correct opencode field names as primary lookups on lines 207, 216-217, 243-244, 257-258, 328, 342

**Verification**:
- Module loads without errors in headless Neovim
- All field reference chains start with the correct opencode field name (`title`, `id`, `directory`)
- Existing bot API field names (`session_name`, `session_id`, `working_directory`, `cwd`) remain as fallbacks

## Testing & Validation

- [ ] `nvim --headless -c "lua require('neotex.plugins.ai.opencode.discord-link')" -c "q"` exits cleanly
- [ ] `nvim --headless -c "lua require('neotex.plugins.ai.opencode.discord-session-picker')" -c "q"` exits cleanly
- [ ] Grep discord-link.lua for `working_directory` and `cwd` -- should not appear
- [ ] Grep discord-link.lua for `session.status` -- should not appear
- [ ] Grep discord-link.lua for `session.session_id` and `session.name` (without `.session_name`) -- should not appear
- [ ] Grep discord-session-picker.lua for field chains -- all should start with correct opencode field

## Artifacts & Outputs

- `specs/551_fix_discord_link_session_discovery/plans/01_fix-session-discovery.md` (this plan)
- `specs/551_fix_discord_link_session_discovery/summaries/01_fix-session-discovery-summary.md` (after implementation)
- Modified: `lua/neotex/plugins/ai/opencode/discord-link.lua`
- Modified: `lua/neotex/plugins/ai/opencode/discord-session-picker.lua`

## Rollback/Contingency

Both files are tracked in git. If the changes cause issues, revert with:
```bash
git checkout HEAD -- lua/neotex/plugins/ai/opencode/discord-link.lua lua/neotex/plugins/ai/opencode/discord-session-picker.lua
```

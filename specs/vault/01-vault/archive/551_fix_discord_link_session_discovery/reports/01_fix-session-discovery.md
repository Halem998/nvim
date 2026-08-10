# Research Report: Task #551

**Task**: 551 - Fix discord-link.lua session discovery to match actual opencode session list output
**Started**: 2026-05-08T00:00:00Z
**Completed**: 2026-05-08T00:10:00Z
**Effort**: Small (field name corrections and logic simplification)
**Dependencies**: None
**Sources/Inputs**: Actual `opencode session list --format json` CLI output, source code analysis
**Artifacts**: - specs/551_fix_discord_link_session_discovery/reports/01_fix-session-discovery.md
**Standards**: report-format.md

## Executive Summary

- The `opencode session list --format json` output uses fields `id`, `title`, `directory`, `updated`, `created`, and `projectId` -- none of the field names currently checked in `discord-link.lua` or `discord-session-picker.lua` match
- Two files are affected: `discord-link.lua` (session discovery logic) and `discord-session-picker.lua` (display/preview logic)
- The fix requires changing field name references and replacing the status-based fallback with a most-recent-session fallback

## Context & Scope

The `discord-link.lua` module discovers the current OpenCode session by running `opencode session list --format json` and matching sessions to the current working directory. The `discord-session-picker.lua` module displays Discord-linked sessions in a Telescope picker. Both files reference session object fields that do not match the actual CLI output schema.

## Findings

### Actual OpenCode Session List Output Schema

Verified by running `opencode session list --format json` on the live system. Each session object contains exactly these fields:

```json
{
  "id": "ses_1fafae712ffeGtxPFv0kJq8edP",
  "title": "iPhone OpenCode agent management via Discord",
  "updated": 1778221124814,
  "created": 1778200680685,
  "projectId": "4c3946b9ed7d629b47ce1da9eac5fb4763e30052",
  "directory": "/home/benjamin/.config/nvim"
}
```

Fields present: `id`, `title`, `updated`, `created`, `projectId`, `directory`

Fields absent (but referenced in code): `working_directory`, `cwd`, `status`, `name`, `session_id`, `session_name`

Sessions are sorted by `updated` descending (most recently updated first).

### discord-link.lua Mismatches

**File**: `lua/neotex/plugins/ai/opencode/discord-link.lua`

#### Mismatch 1: CWD filter (line 198)

Current code:
```lua
if sess.working_directory == cwd or sess.cwd == cwd then
```
Neither `working_directory` nor `cwd` exists. Should be:
```lua
if sess.directory == cwd then
```

#### Mismatch 2: Status-based fallback (lines 204-210)

Current code:
```lua
if #matching == 0 then
  -- Fall back to first active session if no CWD match
  for _, sess in ipairs(sessions) do
    if sess.status == "active" or sess.status == "running" then
      table.insert(matching, sess)
      break
    end
  end
end
```
There is no `status` field in the output. This fallback never matches. Should be replaced with a most-recent-session fallback (first element in the array, since they are sorted by `updated` descending):
```lua
if #matching == 0 and #sessions > 0 then
  -- Fall back to most recent session (sorted by updated desc)
  table.insert(matching, sessions[1])
end
```

#### Mismatch 3: Session ID extraction (line 219)

Current code:
```lua
local session_id = session.id or session.session_id
```
Only `id` exists. The `session.session_id` fallback is harmless but unnecessary. Can simplify to:
```lua
local session_id = session.id
```

#### Mismatch 4: Session name extraction (line 220)

Current code:
```lua
local session_name = session.name or session.title or vim.fn.fnamemodify(cwd, ":t")
```
Only `title` exists (`name` does not). The `session.name` check is harmless (evaluates to nil, falls through to `title`) but misleading. Should be:
```lua
local session_name = session.title or vim.fn.fnamemodify(cwd, ":t")
```

### discord-session-picker.lua Mismatches

**File**: `lua/neotex/plugins/ai/opencode/discord-session-picker.lua`

Note: This file displays sessions fetched from the Discord bot API (GET /sessions), NOT directly from the opencode CLI. The bot API may return different field names than the opencode CLI. However, the code should still be updated to be consistent. The mismatches noted below are for fields that originate from the opencode session data passed through the bot API.

#### Mismatch 5: Entry maker name field (line 207)

Current code:
```lua
local name = _truncate(session.session_name or session.name or "unnamed", 25)
```
If bot API passes through opencode fields, should check `session.title`. However, since the bot API response schema may differ, the existing fallback chain may be intentional for bot-side field names (`session_name` being a bot-specific field). This should be verified against the bot API response.

#### Mismatch 6: Status field in entry maker (line 208)

Current code:
```lua
local status = session.status or "unknown"
```
OpenCode sessions have no `status` field. If the bot API adds a status field, this is fine. If not, it will always show "unknown".

#### Mismatch 7: Previewer CWD display (lines 257-258)

Current code:
```lua
if session.working_directory or session.cwd then
  table.insert(lines, "CWD:        " .. (session.working_directory or session.cwd))
end
```
Should also check `session.directory`:
```lua
if session.directory or session.working_directory or session.cwd then
  table.insert(lines, "CWD:        " .. (session.directory or session.working_directory or session.cwd))
end
```

#### Mismatch 8: Previewer status display (line 245)

Current code:
```lua
"Status:     " .. (session.status or "-"),
```
Will always show "-" for opencode sessions since there is no status field. May be fine if the bot API adds its own status tracking.

#### Mismatch 9: Entry maker ordinal and kill handler (lines 216-217, 328)

Current code references `session.session_name`, `session.session_id` as primary fallbacks. These should prioritize `session.title` and `session.id` respectively, which are the actual opencode field names. The current fallback chain does include `session.name` and `session.id` as alternates, so `session.id` already works.

### Critical vs. Non-Critical Fixes

**Critical (causes functional failures in discord-link.lua)**:
1. Line 198: `working_directory`/`cwd` -> `directory` (CWD matching never works)
2. Lines 204-210: `status` fallback -> most-recent fallback (fallback never works)

**Important (correctness improvements in discord-link.lua)**:
3. Line 219: Remove `session.session_id` fallback (unnecessary)
4. Line 220: Remove `session.name` fallback (unnecessary)

**Low priority (discord-session-picker.lua, depends on bot API)**:
5-9. The session picker fetches from the bot API, not opencode CLI directly. The bot API may transform field names. These should be verified against the actual bot API response before changing.

### Recommendations

#### discord-link.lua (must fix)

1. Change line 198: `sess.working_directory == cwd or sess.cwd == cwd` to `sess.directory == cwd`
2. Replace lines 203-210 (status fallback) with most-recent-session fallback:
   ```lua
   if #matching == 0 and #sessions > 0 then
     -- Fall back to most recent session (sorted by updated desc)
     table.insert(matching, sessions[1])
   end
   ```
3. Simplify line 219: `session.id or session.session_id` to `session.id`
4. Simplify line 220: `session.name or session.title` to `session.title`

#### discord-session-picker.lua (should fix)

5. Add `session.directory` to the previewer CWD fallback chain (lines 257-258)
6. Add `session.title` as primary name fallback in entry maker (line 207)
7. The other fallbacks (`session.session_name`, `session.session_id`, `session.status`) may be bot-API-specific fields and could be left as secondary fallbacks

## Decisions

- The `discord-link.lua` fixes are straightforward field name corrections against the verified CLI output schema
- The `discord-session-picker.lua` changes are lower confidence because that module fetches from the bot HTTP API, which may use its own field names. Adding `directory`/`title` as primary checks with existing fields as fallbacks is the safest approach
- The most-recent-session fallback (first element in array) is correct because `opencode session list` returns sessions sorted by `updated` descending

## Risks & Mitigations

- **Risk**: Bot API may have different field names than opencode CLI
  - **Mitigation**: Keep existing field names as fallbacks in discord-session-picker.lua, add correct opencode field names as primary checks
- **Risk**: Session list sort order could change in future opencode versions
  - **Mitigation**: The fallback is already a best-effort heuristic; document the assumption

## Appendix

### Verification Command

```bash
opencode session list --format json
```

### Actual Output (truncated)

```json
[
  {
    "id": "ses_1fafae712ffeGtxPFv0kJq8edP",
    "title": "iPhone OpenCode agent management via Discord",
    "updated": 1778221124814,
    "created": 1778200680685,
    "projectId": "4c3946b9ed7d629b47ce1da9eac5fb4763e30052",
    "directory": "/home/benjamin/.config/nvim"
  },
  ...
]
```

### Complete Field Name Mapping

| Actual Field | discord-link.lua Reference | discord-session-picker.lua Reference |
|---|---|---|
| `id` | `session.id` (line 219, correct) | `session.id` (lines 217, 244, 328, correct as fallback) |
| `title` | `session.title` (line 220, exists as 2nd fallback) | Not referenced directly |
| `directory` | Not referenced (uses `working_directory`/`cwd`) | Not referenced (uses `working_directory`/`cwd`) |
| `updated` | Not referenced | Not referenced |
| `created` | Not referenced | Not referenced |
| `projectId` | Not referenced | Not referenced |
| (none) | `session.status` (line 206) | `session.status` (lines 208, 245) |
| (none) | `session.name` (line 220) | `session.name` (lines 207, 216) |
| (none) | `session.session_id` (line 219) | `session.session_id` (lines 217, 244, 328) |
| (none) | `session.working_directory` (line 198) | `session.working_directory` (lines 257-258) |
| (none) | `session.cwd` (line 198) | `session.cwd` (lines 257-258) |
| (none) | - | `session.session_name` (lines 207, 216, 243, 342) |

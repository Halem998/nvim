# Research Report: Task #586

**Task**: 586 - Restrict TTS to lifecycle transitions and interactive prompts
**Started**: 2026-05-15T00:00:00Z
**Completed**: 2026-05-15T00:30:00Z
**Effort**: 45 minutes (audit-only, no implementation)
**Dependencies**: None
**Sources/Inputs**:
- `.claude/hooks/tts-notify.sh` - Main TTS hook (275 lines, B+A Hybrid architecture)
- `.claude/scripts/update-task-status.sh` - PHASE 5 lifecycle notifications (lines 358-381)
- `.claude/settings.json` - Hook configurations
- `.opencode/settings.json` - OpenCode hook configurations (mirrors .claude/)
- `.claude/extensions/core/hooks/tts-notify.sh` - Extension core copy (old, 178 lines)
- `.opencode/hooks/tts-notify.sh` - OpenCode copy (old, 178 lines, identical to ext core)
- `.opencode/extensions/core/hooks/tts-notify.sh` - OpenCode ext core (identical to above)
- `.claude/skills/skill-researcher/SKILL.md` - 10-stage postflight pattern
- `.claude/skills/skill-planner/SKILL.md` - 11-stage postflight pattern
- `.claude/skills/skill-implementer/SKILL.md` - 11-stage postflight pattern with continuation loop
- `.claude/skills/skill-reviser/SKILL.md` - 11-stage postflight pattern
- `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md` - 11-stage pattern
- `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` - 11-stage pattern
- `.claude/extensions/nix/skills/skill-nix-research/SKILL.md` - 11-stage pattern
- `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` - numbered 4-8 stages (old format)
- `.claude/context/project/neovim/guides/tts-stt-integration.md` - Documentation
- `specs/TODO.md` - Task 586 full description with change requirements
**Artifacts**:
- `specs/586_restrict_tts_lifecycle_interactive/reports/01_restrict-tts-triggers.md`
**Standards**: report-format.md, artifact-management.md

---

## Executive Summary

- The TTS system has three trigger paths: Stop hook (generic "Tab N"), Notification hook (permission_prompt/idle_prompt/elicitation_dialog), and direct lifecycle invocation via `--lifecycle STATUS`. The task eliminates the first path entirely and removes `idle_prompt` from the second.
- The current B+A Hybrid architecture (signal file + direct lifecycle TTS) becomes unnecessary once Stop hook TTS is removed; `tts-notify.sh` can be simplified to lifecycle-only mode.
- Four copies of `tts-notify.sh` exist: one current version in `.claude/hooks/` (275 lines) and three older versions (`.claude/extensions/core/hooks/`, `.opencode/hooks/`, `.opencode/extensions/core/hooks/`) at 178 lines missing the B+A Hybrid additions. All four need updating.
- Six delegating skills need a new "Stage 8a: Lifecycle TTS" inserted after artifact linking (Stage 8) and before cleanup/commit: skill-researcher, skill-planner, skill-implementer, skill-reviser, skill-neovim-research, skill-neovim-implementation, skill-nix-research. The nix-implementation skill uses a different stage numbering format.
- Removing `idle_prompt` from the Notification hook is safe: `permission_prompt` and `elicitation_dialog` cover all interactive-prompt scenarios that require user action; `idle_prompt` is a 60-second inactivity timer that is unwanted per the task description.
- WezTerm tab coloring (`wezterm-notify.sh`) must remain in the Stop hook -- it colors tabs gray on every stop regardless of lifecycle context and serves a distinct UI purpose from TTS.

---

## Context & Scope

Task 586 restricts TTS announcements from firing on every agent turn to only two categories:
1. Lifecycle transitions (researched, planned, completed) - fired by skills after artifact linking
2. Interactive prompts requiring user input (permission_prompt, elicitation_dialog) - fired via Notification hook

The research audits all files that must change: the main hook, four copies of the hook script, settings files (2 Claude Code + 2 OpenCode), `update-task-status.sh`, and all delegating skill SKILL.md files.

---

## Findings

### 1. Current TTS Trigger Architecture

**Three trigger paths** currently exist:

**Path A: Stop Hook (to be removed)**
- Location: `.claude/settings.json` lines 102-103 and `.opencode/settings.json` lines 131-133
- Fires on every Claude turn completion (matcher: `*`)
- Speaks "Tab N" or "Tab N worker" (worktree sessions)
- Currently mitigated by signal file check: if lifecycle signal file present and fresh (<60s), skip TTS
- Also in extension core copies: `.claude/extensions/core/root-files/settings.json` line 102

**Path B: Notification Hook (to be modified)**
- Location: `.claude/settings.json` lines 143-151 and `.opencode/settings.json` lines 153-164
- Matcher: `permission_prompt|idle_prompt|elicitation_dialog`
- `idle_prompt` = 60-second inactivity reminder (to be removed)
- `permission_prompt` = tool use permission request (to be kept)
- `elicitation_dialog` = Claude asking a clarifying question (to be kept)
- No modification to `tts-notify.sh` needed for this path (already calls it directly)

**Path C: Lifecycle Direct Invocation (to be relocated to skills)**
- Location: `update-task-status.sh` PHASE 5, lines 363-381
- Called with `--lifecycle STATUS` argument bypassing cooldown/stdin/signal file
- Speaks "Tab N STATUS" (e.g., "Tab 3 researched")
- Currently also writes signal file (`specs/tmp/tts-lifecycle-signal`) to suppress Stop hook
- Also calls `wezterm-notify.sh STATUS` for tab coloring

**Signal File Mechanism (B+A Hybrid, to be removed)**
- Signal file: `specs/tmp/tts-lifecycle-signal`
- Written by `update-task-status.sh` PHASE 5 before lifecycle TTS fires
- Read and consumed by `tts-notify.sh` normal mode (lines 182-186)
- Max age: 60 seconds; stale files auto-deleted
- Functions: `check_signal_file()` (lines 55-73) and `consume_signal_file()` (lines 76-79)
- Constant: `LIFECYCLE_SIGNAL_FILE` (line 32), `LIFECYCLE_SIGNAL_MAX_AGE` (line 33)
- Once Stop hook TTS is removed, this entire mechanism becomes dead code

**Cooldown System**
- File: `specs/tmp/claude-tts-last-notify`
- Default: 10 seconds between notifications (TTS_COOLDOWN)
- Only applies to normal mode; lifecycle mode bypasses it
- Once normal mode is removed, cooldown file and logic become dead code

**Subagent Suppression Guard**
- Lines 164-172 of `.claude/hooks/tts-notify.sh`
- Checks `agent_id` in stdin JSON; if present, suppresses TTS
- This only applies to normal mode (stdin is not parsed in lifecycle mode)
- Can be removed with normal mode

### 2. tts-notify.sh Simplification

**Current structure** (275 lines):
- Lines 1-96: Configuration, helpers (log, exit_success, check_signal_file, consume_signal_file), piper checks
- Lines 97-138: Lifecycle mode (--lifecycle STATUS) -- KEEP
- Lines 140-274: Normal mode (Stop/Notification) -- REMOVE

**Proposed simplified structure** after task 586:
- Remove: LIFECYCLE_SIGNAL_FILE, LIFECYCLE_SIGNAL_MAX_AGE constants (lines 32-33)
- Remove: check_signal_file() function (lines 55-73)
- Remove: consume_signal_file() function (lines 76-79)
- Remove: LAST_NOTIFY_FILE constant (line 30) -- cooldown only used in normal mode
- Remove: entire normal mode section (lines 140-274)
- Keep: lifecycle mode section (lines 97-138, the --lifecycle STATUS path)
- Keep: piper/model availability checks (lines 81-95)
- Keep: TTS_ENABLED, PIPER_MODEL, TTS_COOLDOWN configuration (though cooldown no longer used)
- Keep: LOG_FILE for lifecycle logging

The simplified script will be roughly 80-100 lines, with only the lifecycle mode path remaining.

### 3. Four Copies of tts-notify.sh - Version Status

| File | Lines | Has B+A Hybrid | Notes |
|------|-------|----------------|-------|
| `.claude/hooks/tts-notify.sh` | 275 | Yes | Current version; primary |
| `.claude/extensions/core/hooks/tts-notify.sh` | 178 | No | Old version, missing lifecycle additions |
| `.opencode/hooks/tts-notify.sh` | 178 | No | Old version, identical to ext core |
| `.opencode/extensions/core/hooks/tts-notify.sh` | 178 | No | Old version, identical to above |

The three old copies are identical to each other (diff exit code 0 between all three). The implementation must update all four to the new simplified lifecycle-only version.

### 4. Skill Postflight Stage Audit

**Core delegating skills** (in `.claude/skills/`):

| Skill | Stage 7 (Status) | Stage 8 (Artifacts) | Stage 8a needed? | Stage 9 |
|-------|-----------------|---------------------|-----------------|---------|
| skill-researcher | update-task-status.sh postflight | Link artifacts in state.json + TODO.md | Yes (lifecycle TTS) | Cleanup |
| skill-planner | update-task-status.sh postflight | Link artifacts in state.json + TODO.md | Yes | Git commit |
| skill-implementer | update-task-status.sh postflight | Link artifacts in state.json + TODO.md | Yes | Git commit |
| skill-reviser | update-task-status.sh postflight | Link artifact + description update | Yes | Git commit |

**Extension skills**:

| Skill | Stage 7 (Status) | Stage 8 (Artifacts) | Stage 8a needed? | Stage 9 |
|-------|-----------------|---------------------|-----------------|---------|
| skill-neovim-research | update-task-status.sh postflight (implied) | Link artifacts | Yes | Git commit |
| skill-neovim-implementation | update-task-status.sh postflight (implied) | Link artifacts | Yes | Git commit |
| skill-nix-research | update-task-status.sh postflight (implied) | Link artifacts | Yes | Git commit |
| skill-nix-implementation | Inline jq (custom format, stage "5") | Stage "5" combined | No separate stage | Stage "6" git, "7" cleanup |

**Important:** `skill-nix-implementation` uses a different stage numbering convention (stages numbered 4-8 without "Stage N:" prefix in headings). It does NOT call `update-task-status.sh`; instead it has inline jq commands. It also combines status update + artifact linking in one stage (stage 5). Adding Stage 8a requires understanding this divergent format.

**Stage ordering in core skills:**
- skill-researcher: `Stage 7 (postflight status) → Stage 7a (memory candidates) → Stage 8 (link artifacts) → Stage 9 (cleanup) → Stage 10 (return)`
- skill-planner: `Stage 7 (status) → Stage 8 (link artifacts) → Stage 9 (git commit) → Stage 10 (cleanup) → Stage 11 (return)`
- skill-implementer: `Stage 7 (status) → Stage 8 (link artifacts) → Stage 9 (git commit) → Stage 10 (cleanup) → Stage 11 (return)`
- skill-reviser: `Stage 7 (status) → Stage 8 (link artifacts) → Stage 9 (git commit) → Stage 10 (cleanup) → Stage 11 (return)`

**For skill-researcher specifically**: Stage 8a should be inserted between Stage 8 (artifact linking) and Stage 9 (cleanup). Note that skill-researcher has NO git commit stage (unlike planner/implementer/reviser). The existing cleanup stage becomes Stage 9 renamed, or Stage 8a is inserted and existing stages shift.

### 5. update-task-status.sh Changes

**PHASE 5 (lines 358-381)** must have:
- Remove: signal file write (line 365-366)
- Remove: direct TTS invocation (lines 370-373)
- Keep: wezterm-notify.sh call (lines 376-380) -- tab coloring stays in lifecycle path
- The wezterm call should remain since it provides the visual tab color state regardless of TTS

After the change, PHASE 5 becomes purely a WezTerm tab coloring phase (or can be renamed/simplified to just the wezterm call).

### 6. settings.json Changes

**Files to update** (4 total):
- `.claude/settings.json` - Remove tts-notify.sh from Stop hook (line 102), change Notification matcher to `permission_prompt|elicitation_dialog`
- `.opencode/settings.json` - Same changes (lines 131-133 and 155)
- `.claude/extensions/core/root-files/settings.json` - Same as .claude/settings.json (this is the synced template)
- `.opencode/templates/settings.json` - Check if this also needs updating (not yet audited)

**Note**: The `.claude/extensions/core/root-files/settings.json` is the extension template that gets synced to project directories. It must be updated in sync with `.claude/settings.json`.

### 7. Notification Hook Analysis

**idle_prompt** behavior:
- Fires when Claude has been waiting for user input for ~60 seconds
- Currently announces "Tab N" to remind the user that input is needed
- Per task 586 description: this is "unwanted" -- a 60-second inactivity reminder is noise
- Safe to remove: `permission_prompt` fires immediately when a permission is needed (not time-delayed), so removing `idle_prompt` doesn't break interactive prompt detection

**permission_prompt** behavior:
- Fires immediately when Claude requests tool permission
- User needs to act: approve or deny the permission
- Keep: directly actionable, immediate user intervention required

**elicitation_dialog** behavior:
- Fires when Claude asks a clarifying question (e.g., "Yes, create tasks")
- User needs to act: provide the answer
- Keep: directly actionable, user intervention required

**Conclusion**: Changing matcher from `permission_prompt|idle_prompt|elicitation_dialog` to `permission_prompt|elicitation_dialog` correctly removes the inactivity timer while preserving both directly-actionable interactive prompts.

### 8. WezTerm Tab Coloring Impact

`wezterm-notify.sh` is currently called in two places:
1. Stop hook in `settings.json` (sets CLAUDE_STATUS=needs_input on every stop)
2. `update-task-status.sh` PHASE 5 (sets lifecycle state value for tab coloring)

The Stop hook wezterm call must **stay**: it provides the visual gray color indicator that Claude has stopped working. This is independent of TTS and serves a distinct UI function. The TTS removal only affects the tts-notify.sh entry in the Stop hook.

### 9. Proposed lifecycle-notify.sh Script Design

The new script serves as a single entry point for lifecycle TTS, called by skill postflight stages:

**Location**: `.claude/scripts/lifecycle-notify.sh`

**Interface**:
- Argument 1: STATUS (researched, planned, completed, partial, etc.)
- Non-blocking: runs tts-notify.sh and wezterm-notify.sh in background
- Gracefully no-ops if either script is unavailable

**Key design decisions**:
- Should call `tts-notify.sh --lifecycle STATUS` (the simplified script after task 586)
- Should call `wezterm-notify.sh STATUS` for tab coloring consistency
- Must use absolute paths or be called with the project root prefix
- Skills call this via: `bash .claude/scripts/lifecycle-notify.sh "$STATE_STATUS" &`
- Should NOT write a signal file (signal file mechanism is being removed)

**Proposed script** (approximately):
```bash
#!/bin/bash
# lifecycle-notify.sh - Fire TTS and WezTerm notifications after lifecycle status transitions
# Called by skill postflight stages after artifact linking.
#
# Usage: bash lifecycle-notify.sh STATUS
# STATUS: researched | planned | completed | partial | blocked

STATUS="${1:-}"
if [[ -z "$STATUS" ]]; then
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/../hooks"

# TTS announcement (non-blocking)
tts_script="$HOOKS_DIR/tts-notify.sh"
if [[ -f "$tts_script" ]]; then
    bash "$tts_script" --lifecycle "$STATUS" &
fi

# WezTerm tab coloring (non-blocking)
wezterm_script="$HOOKS_DIR/wezterm-notify.sh"
if [[ -f "$wezterm_script" ]]; then
    bash "$wezterm_script" "$STATUS" &
fi

exit 0
```

### 10. Extension Core Sync Consideration

The `.claude/extensions/core/` directory mirrors the `.claude/` configuration. Changes to the following must be synchronized:
- `.claude/hooks/tts-notify.sh` → `.claude/extensions/core/hooks/tts-notify.sh`
- `.claude/settings.json` → `.claude/extensions/core/root-files/settings.json`

The `.opencode/` directory also mirrors these:
- `.claude/hooks/tts-notify.sh` → `.opencode/hooks/tts-notify.sh` and `.opencode/extensions/core/hooks/tts-notify.sh`
- `.claude/settings.json` → `.opencode/settings.json` (with path adjustments: `.claude/` → `.opencode/`)

---

## Decisions

- **WezTerm tab coloring stays in Stop hook**: `wezterm-notify.sh` serves a distinct UI purpose (visual tab color) and should remain in the Stop hook even after removing TTS.
- **Signal file mechanism becomes dead code and should be removed entirely**: Once Stop hook TTS is removed, no component will check or write the signal file. Remove all related code from `tts-notify.sh`.
- **`lifecycle-notify.sh` is the new single entry point for lifecycle notifications**: It wraps both TTS and WezTerm calls, making skills independent of the hook implementation details.
- **`idle_prompt` removal is safe**: Only `permission_prompt` and `elicitation_dialog` require immediate user intervention; `idle_prompt` is a time-delayed reminder that adds noise.
- **Skill Stage 8a placement**: After Stage 8 (artifact linking) in all delegating skills, ensuring artifacts are committed before TTS fires. This is the correct semantic ordering.
- **All four tts-notify.sh copies must be updated**: The three "old" copies (ext core, opencode, opencode ext core) have not received the B+A Hybrid additions; after simplification, they should all converge to the same lifecycle-only version.

---

## Recommendations

1. **Priority: settings.json changes** (4 files) - Remove tts-notify.sh from Stop hook, change Notification matcher. Lowest risk, immediate impact.

2. **Priority: update-task-status.sh PHASE 5** - Remove signal file write and TTS call, keep wezterm call. One file, clear scope.

3. **Priority: Create lifecycle-notify.sh** - New script in `.claude/scripts/`. Simple wrapper, no dependencies.

4. **Priority: Simplify tts-notify.sh** - Remove normal mode (lines 140-274), signal file helpers, cooldown constants. Update all four copies to the simplified version.

5. **Priority: Add Stage 8a to core skills** (4 skills) - skill-researcher, skill-planner, skill-implementer, skill-reviser. Insert `bash .claude/scripts/lifecycle-notify.sh "$STATE_STATUS" &` after artifact linking.

6. **Priority: Add Stage 8a to extension skills** (3 skills) - skill-neovim-research, skill-neovim-implementation, skill-nix-research. Same pattern as core skills.

7. **Priority: skill-nix-implementation** - Divergent stage format; requires understanding the existing inline jq pattern before adding lifecycle notification. Lower priority if the Nix workflow is less frequently used.

8. **Priority: Update documentation** - `tts-stt-integration.md` (2 copies: `.claude/context/` and `.claude/extensions/nvim/context/`). Update to reflect lifecycle + interactive only model, remove B+A Hybrid architecture description, remove idle_prompt from event table.

---

## Risks & Mitigations

- **Risk**: Missing a copy of `tts-notify.sh` when updating. Mitigation: all four paths are explicitly documented above; use `find . -name "tts-notify.sh"` to verify completeness.
- **Risk**: `skill-nix-implementation` divergent stage format causes incorrect Stage 8a placement. Mitigation: read the full file carefully; its postflight stages are numbered 4-8 (not Stage N format), so "Stage 8a" naming must adapt.
- **Risk**: Removing normal mode breaks the Notification hook path. Mitigation: Notification hook calls `tts-notify.sh` without `--lifecycle` arg; after simplification, the script must handle the no-arg case gracefully (exit without doing anything, since lifecycle mode requires --lifecycle flag).

  **Important**: The simplified `tts-notify.sh` will be called by the Notification hook WITHOUT the `--lifecycle` argument. The script must still work when called this way -- but since normal mode is being removed, it should exit successfully with `{}` when no `--lifecycle` argument is present. Currently when called with no args it enters normal mode and reads stdin. After simplification, the no-arg case must exit cleanly. This can be handled by checking if `LIFECYCLE_STATUS` is empty at the top of the new simplified script.

- **Risk**: OpenCode settings.json path differences (`.opencode/hooks/` vs `.claude/hooks/`). Mitigation: OpenCode settings already uses `.opencode/hooks/tts-notify.sh`; path changes must use the opencode-specific path prefix.
- **Risk**: Double TTS during transition if lifecycle-notify.sh is added to skills before Stop hook TTS is removed. Mitigation: implement changes atomically -- remove Stop hook TTS first, then add skill Stage 8a.

---

## Context Extension Recommendations

- **Topic**: TTS trigger model documentation
- **Gap**: The `tts-stt-integration.md` guide (in both `.claude/context/` and extension nvim copy) documents the B+A Hybrid architecture which will be completely removed. The guide's "Notification Event Types" table includes `idle_prompt` and "Stop (lifecycle suppressed)" rows that will no longer be accurate.
- **Recommendation**: Update both copies of `tts-stt-integration.md` as part of task 586 implementation.

---

## Appendix

### Files Changed (Summary)

| File | Change Type | Description |
|------|-------------|-------------|
| `.claude/settings.json` | Edit | Remove tts line from Stop hook; change Notification matcher |
| `.opencode/settings.json` | Edit | Same changes with .opencode/ path prefix |
| `.claude/extensions/core/root-files/settings.json` | Edit | Same as .claude/settings.json |
| `.opencode/templates/settings.json` | Edit (verify) | Check and update if present |
| `.claude/scripts/update-task-status.sh` | Edit | Remove PHASE 5 signal file + TTS; keep wezterm |
| `.claude/scripts/lifecycle-notify.sh` | Create | New wrapper script |
| `.claude/hooks/tts-notify.sh` | Edit | Remove normal mode (lines 140-274) + dead code |
| `.claude/extensions/core/hooks/tts-notify.sh` | Edit | Sync with simplified version |
| `.opencode/hooks/tts-notify.sh` | Edit | Sync with simplified version |
| `.opencode/extensions/core/hooks/tts-notify.sh` | Edit | Sync with simplified version |
| `.claude/skills/skill-researcher/SKILL.md` | Edit | Add Stage 8a after Stage 8 |
| `.claude/skills/skill-planner/SKILL.md` | Edit | Add Stage 8a after Stage 8 |
| `.claude/skills/skill-implementer/SKILL.md` | Edit | Add Stage 8a after Stage 8 |
| `.claude/skills/skill-reviser/SKILL.md` | Edit | Add Stage 8a after Stage 8 |
| `.claude/extensions/core/skills/skill-researcher/SKILL.md` | Edit | Add Stage 8a after Stage 8 |
| `.claude/extensions/core/skills/skill-planner/SKILL.md` | Edit | Add Stage 8a after Stage 8 |
| `.claude/extensions/core/skills/skill-implementer/SKILL.md` | Edit | Add Stage 8a after Stage 8 |
| `.claude/extensions/core/skills/skill-reviser/SKILL.md` | Edit | Add Stage 8a after Stage 8 |
| `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md` | Edit | Add Stage 8a after Stage 8 |
| `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` | Edit | Add Stage 8a after Stage 8 |
| `.claude/extensions/nix/skills/skill-nix-research/SKILL.md` | Edit | Add Stage 8a after Stage 8 |
| `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` | Edit | Add lifecycle notify in divergent format |
| `.claude/context/project/neovim/guides/tts-stt-integration.md` | Edit | Update trigger model docs |
| `.claude/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` | Edit | Sync doc update |

Total: 24 files (4 settings, 2 scripts, 4 hooks, 12 skills, 2 docs)

### Stage 8a Template for Core Skills

To be inserted in all delegating skills between Stage 8 (Link Artifacts) and Stage 9 (Cleanup/Git):

```markdown
### Stage 8a: Lifecycle TTS Notification

Fire TTS and WezTerm tab coloring after artifact linking is complete:

```bash
# Non-blocking: call lifecycle-notify.sh in background after artifact linking
if [ "$status" = "researched" ]; then  # adjust status per skill
    lifecycle_script=".claude/scripts/lifecycle-notify.sh"
    if [ -f "$lifecycle_script" ]; then
        bash "$lifecycle_script" "$STATE_STATUS" &
    fi
fi
```

This ensures the "Tab N researched/planned/completed" TTS fires only after artifacts are
linked and status is updated. Called non-blocking to not delay postflight progression.
```

### tts-notify.sh Line Numbers After Simplification

The simplified script will need to handle the no-arg case (called by Notification hook without --lifecycle). The Notification hook still calls `tts-notify.sh` for `permission_prompt|elicitation_dialog` but without args. The simplified script must detect this and speak "Tab N" for interactive prompts -- OR the Notification hook must call a separate lightweight script.

**Decision needed**: Either:
1. Keep a minimal "interactive mode" in tts-notify.sh that speaks "Tab N" when called without --lifecycle arg (simpler, less change to settings.json)
2. Create a separate `interactive-notify.sh` for the Notification hook (cleaner separation but more files)

Option 1 is recommended: the Notification hook currently calls `tts-notify.sh` without args. Keep the tab detection + "Tab N" speech in the script but ONLY for the no-arg path (no stdin parsing, no cooldown, no signal file). This requires the simplified script to have two code paths:
- No args: speak "Tab N" immediately (for Notification hook: permission_prompt, elicitation_dialog)
- `--lifecycle STATUS`: speak "Tab N STATUS" (for lifecycle notifications from skills)

This is simpler than the current B+A architecture and achieves the task goals without requiring changes to settings.json's Notification hook command.

**Revised simplification scope**: The "normal mode" to remove is specifically: stdin parsing, cooldown file, signal file check, worktree detection, and generic "Tab N" message-building for the Stop hook. The lightweight "Tab N" speech for interactive prompts (Notification hook) can remain as a simplified no-arg path.

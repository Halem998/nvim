# Research Report: Task #601

**Task**: Simplify Notification Pipeline / Merge Vocabulary
**Date**: 2026-05-22
**Mode**: Team Research (4 teammates)

## Summary

The WezTerm tab coloring and TTS notification pipeline has three confirmed bugs and one architectural simplification opportunity. All four researchers converged on the same root causes and a unified fix strategy. The core problem is that the Stop hook fires during mid-workflow orchestrator pauses (when agents are spawned), overwriting the in-progress tab color. The dual vocabulary (lifecycle + artifact-type) creates unnecessary complexity and prevents the intended dim-to-bold visual transition.

## Key Findings

### Primary Approach (from Teammate A)

**Root cause confirmed for all three bugs:**

1. **Tab color reset**: The Stop hook (`claude-stop-notify.sh`) fires when the orchestrator pauses to spawn agents. Since no signal file exists yet (postflight hasn't run) and no `agent_id` is present (this is the main process, not a subagent), it falls through to the `needs_input` path, overwriting `CLAUDE_STATUS` from `researching` to `needs_input` (gray).

2. **Random TTS during --team**: Same mechanism — each intermediate Stop event during team orchestration fires TTS "Tab N" because neither the signal file nor the `agent_id` check prevents it.

3. **No dim-to-bold transition**: Postflight maps lifecycle states to artifact-type vocabulary (`researched` → `report`, `planned` → `plan`, `completed` → `summary`). The artifact types have different colors than lifecycle completed states, so the user sees a hue change rather than a brightness change. Additionally, `researching` and `researched` share the same background color (`#2a4a2a`), differing only in foreground brightness — a subtle distinction.

**Proposed fix**: Replace the signal file mechanism with a **workflow-active** marker file created at preflight and deleted after postflight notifications fire. The Stop hook checks for this file and skips all dispatch while a workflow is active. Merge to single lifecycle vocabulary. Extract TTY boilerplate into shared function.

### Alternative Approaches (from Teammate B)

**Three alternative patterns evaluated:**

| Alternative | Approach | Verdict |
|-------------|----------|---------|
| **Workflow-active file** | File exists during entire workflow; Stop hook skips if present | **Recommended** — simplest, no race conditions |
| **Unified notification script** | Single `claude-notify.sh` with all modes | Too complex — different hooks need different stdin parsing |
| **Second WezTerm user variable** | `WORKFLOW_ACTIVE` alongside `CLAUDE_STATUS` | Not viable — WezTerm CLI can't read user variables from shell |

**Prior art analysis**: tmux's `monitor-activity` flag is the closest pattern — a binary "work happening" flag managed by the system and auto-cleared on focus. Our workflow-active file is the same concept, adapted for the richer lifecycle state our system needs.

**Dead code identified**: `wezterm-clear-status.sh` (not in settings.json, replaced by `wezterm-preflight-status.sh` Tier 2) and `lifecycle-notify.sh` (deprecated no-op stub).

### Gaps and Shortcomings (from Critic)

**Critical validation gap**: No teammate confirmed whether the Stop hook actually receives `agent_id` in stdin for subagent completions. The code assumes it does, but if Claude Code only passes `agent_id` to SubagentStop events (not Stop events), the entire subagent suppression logic is ineffective. **Recommendation**: Add debug logging to capture Stop hook stdin JSON before implementing fixes.

**Race condition warning**: If the workflow-active file is deleted during postflight and the Stop hook fires between the wezterm-notify call and the file deletion, the Stop hook could still overwrite the lifecycle color with `needs_input`. **Mitigation**: Delete the workflow-active file AFTER the final Stop hook fires, which means the file persists through the final turn boundary. Clear it on the next `UserPromptSubmit` instead.

**Scope realism**: 28+ files across 4 locations. The 2-3 hour estimate is optimistic; 4-5 hours is more realistic. The Critic recommends budgeting extra time.

**Edge case — ESC cancel**: If the user cancels mid-workflow, the workflow-active file persists, preventing the Stop hook from ever firing `needs_input`. **Mitigation**: `wezterm-preflight-status.sh` Tier 2 (non-lifecycle slash command) should clear both `CLAUDE_STATUS` and the workflow-active file.

### Strategic Horizons (from Horizons)

**Alignment with roadmap**: This task directly supports the roadmap success metric "Zero stale references to removed files" and simplifies future extension hot-reload work. It's well-aligned with current priorities.

**Hook duplication is the real cost multiplier**: 20+ copies of notification scripts across 4 locations. Every future change requires updating all copies. Long-term solution: either symlink from a single source or have the extension loader handle hook copying.

**What NOT to do** (unanimous):
- Don't add a terminal abstraction layer (WezTerm is the only consumer)
- Don't make notifications an extension (it's foundational infrastructure)
- Don't event-source notifications (hooks are already event-driven)
- Don't add file-polling (OSC 1337 push-based is correct)

**`--quiet` flag for team mode**: Add a `--quiet` flag to `update-task-status.sh` that skips PHASE 5, used by intermediate team operations so TTS only fires once at synthesis.

## Synthesis

### Conflicts Resolved

| Conflict | Resolution | Rationale |
|----------|------------|-----------|
| Signal file vs workflow-active | **Workflow-active file** replaces signal file | Workflow-active persists for the full lifecycle, not just after postflight. This solves the mid-workflow Stop hook problem that the signal file cannot address. |
| Where TTS fires | **Keep in update-task-status.sh but with workflow-active suppression** (Teammate B's approach, enhanced with Teammate D's `--quiet` flag) | Moving TTS entirely out of update-task-status.sh (Teammate A) would require changing every skill's postflight. Keeping it centralized but adding suppression is less disruptive. |
| Postflight overwrites lifecycle color | **Stop hook skips wezterm entirely when workflow-active exists** (Critic's recommendation) | The Stop hook should never set `needs_input` during an active workflow. After postflight fires lifecycle color + TTS, the workflow-active file is updated but NOT deleted until the next `UserPromptSubmit`. |
| Scope/phasing | **3-phase approach** (Teammate D) | Phase A (bug fixes) delivers immediate value; Phase B (vocabulary merge) is clean; Phase C (consolidation) reduces maintenance cost. |

### Gaps Identified

1. **Unvalidated assumption**: Whether Stop hook stdin contains `agent_id` for subagent completions needs confirmation via debug logging
2. **ESC-cancel cleanup**: Workflow-active file must be cleaned up on non-workflow prompts (already handled by `wezterm-preflight-status.sh` Tier 2)
3. **Color values**: Exact hex values for dim→bold transition need visual testing; structural approach is sound but specific colors may need tuning
4. **`.postflight-pending` overlap**: The existing `.postflight-pending` marker file serves a similar purpose to the proposed workflow-active file — consider reusing it instead of creating a new file

### Recommendations

#### Phase A: Fix the Bugs (highest priority)

1. **Add workflow-active check to Stop hook**: In `claude-stop-notify.sh`, check for `.claude/tmp/workflow-active` (or reuse `.postflight-pending` marker). If present, skip all dispatch.
2. **Create workflow-active in preflight**: In `update-task-status.sh` preflight, write `.claude/tmp/workflow-active`.
3. **Clear workflow-active on next prompt**: In `wezterm-preflight-status.sh`, Tier 2 (non-lifecycle command) deletes the workflow-active file.
4. **Use lifecycle vocabulary in PHASE 5**: Replace artifact-type mapping with `WEZTERM_STATUS="$STATE_STATUS"`.

#### Phase B: Merge Vocabulary

1. **Remove artifact-type entries from wezterm.lua**: Delete `report`, `plan`, `summary`, `error` from status_colors table.
2. **Fix dim→bold colors**: Make in-progress states use darker backgrounds AND dimmer foregrounds; completed states use brighter backgrounds AND brighter foregrounds.
3. **Delete dead code**: Remove `wezterm-clear-status.sh` and `lifecycle-notify.sh`.

#### Phase C: Consolidate

1. **Extract TTY discovery**: Create `.claude/hooks/wezterm-utils.sh` with `get_pane_tty()` and `set_user_var()` functions, sourced by all hooks.
2. **Propagate to all 4 locations**: Update `.claude/extensions/core/hooks/`, `.opencode/hooks/`, `.opencode/extensions/core/hooks/`.
3. **Update documentation**: `wezterm-integration.md`, `tts-stt-integration.md`, `neovim-integration.md`.

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary implementation approach | completed | high |
| B | Alternative patterns and prior art | completed | high |
| C | Critic — gaps and shortcomings | completed | high |
| D | Strategic horizons | completed | high/medium |

## References

### Source Files Analyzed
- `.claude/hooks/claude-stop-notify.sh` — Unified Stop hook with signal file pattern
- `.claude/hooks/wezterm-notify.sh` — Sets CLAUDE_STATUS user variable
- `.claude/hooks/wezterm-preflight-status.sh` — Sets in-progress color on UserPromptSubmit
- `.claude/hooks/wezterm-clear-status.sh` — Dead code (not in settings.json)
- `.claude/hooks/tts-notify.sh` — TTS notifications (lifecycle + interactive)
- `.claude/hooks/subagent-postflight.sh` — SubagentStop hook
- `.claude/scripts/update-task-status.sh` — Central status updater with PHASE 5 notifications
- `.claude/scripts/lifecycle-notify.sh` — Deprecated no-op stub
- `.claude/settings.json` — Hook configuration
- `~/.dotfiles/config/wezterm.lua` — Tab title formatter with status_colors table

### Teammate Reports
- `specs/601_simplify_notification_pipeline_merge_vocabulary/reports/01_teammate-a-findings.md`
- `specs/601_simplify_notification_pipeline_merge_vocabulary/reports/01_teammate-b-findings.md`
- `specs/601_simplify_notification_pipeline_merge_vocabulary/reports/01_teammate-c-findings.md`
- `specs/601_simplify_notification_pipeline_merge_vocabulary/reports/01_teammate-d-findings.md`

# Implementation Plan: Restrict TTS to Lifecycle and Interactive Prompts

- **Task**: 586 - Restrict TTS announcements to lifecycle transitions and interactive prompts
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/586_restrict_tts_lifecycle_interactive/reports/01_restrict-tts-triggers.md
- **Artifacts**: plans/01_restrict-tts-triggers.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The TTS notification system currently fires on every Claude turn via the Stop hook, creating noise. This plan restricts TTS to two categories: lifecycle transitions (researched/planned/completed) fired by skill postflight stages, and interactive prompts (permission_prompt/elicitation_dialog) fired by the Notification hook. The Stop hook TTS entry is removed, the idle_prompt trigger is removed, a new `lifecycle-notify.sh` wrapper script is created, all 4 copies of `tts-notify.sh` are simplified to lifecycle-only mode with a minimal no-arg path for interactive prompts, PHASE 5 of `update-task-status.sh` is stripped of TTS and signal file code, Stage 8a is added to 11 delegating skill files (8 primary + 3 extension skills with a divergent nix-implementation case), and 3 copies of `tts-stt-integration.md` are updated.

### Research Integration

The research report (01_restrict-tts-triggers.md) provided a complete audit of all 24 files requiring changes. Key findings integrated into this plan:

- Three TTS trigger paths exist: Stop hook (remove), Notification hook (modify), and lifecycle direct invocation (relocate to skills via wrapper script)
- Four copies of `tts-notify.sh` must converge to the same simplified version
- The B+A Hybrid signal file mechanism becomes dead code and should be fully removed
- `skill-nix-implementation` uses a divergent stage format (numbered 4-8 without "Stage N:" prefix) requiring special handling
- WezTerm tab coloring must remain in the Stop hook (distinct UI purpose from TTS)
- The simplified `tts-notify.sh` must handle the no-arg case for Notification hook calls

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Remove TTS announcements from the Stop hook (eliminate "Tab N" on every turn)
- Remove idle_prompt from Notification hook trigger matcher
- Create `lifecycle-notify.sh` wrapper for skills to call after artifact linking
- Simplify `tts-notify.sh` to lifecycle-only + minimal interactive prompt path
- Remove B+A Hybrid signal file mechanism (dead code after Stop hook TTS removal)
- Add Stage 8a (Lifecycle TTS) to all delegating skills after artifact linking
- Update all copies (4 hooks, 4 settings, 12 skills, 3 docs = 23 files changed, 1 created)

**Non-Goals**:
- Changing WezTerm tab coloring behavior (stays in Stop hook)
- Modifying piper TTS engine configuration or voice model
- Adding new TTS trigger categories beyond lifecycle + interactive
- Restructuring the nix-implementation skill's divergent stage format

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missing a copy of tts-notify.sh during sync | M | L | Use `find . -name "tts-notify.sh"` to verify all 4 copies after simplification |
| Double TTS if Stage 8a added before Stop hook removal | M | M | Phase ordering: remove Stop hook TTS first (Phase 1), add Stage 8a later (Phase 4) |
| Notification hook breaks after removing normal mode | H | M | Keep minimal no-arg path in simplified script that speaks "Tab N" for interactive prompts |
| nix-implementation divergent format causes incorrect Stage 8a | M | M | Read full file carefully; adapt to its numbered 4-8 format rather than using "Stage 8a" naming |
| OpenCode settings.json path differences | L | L | OpenCode uses `.opencode/hooks/` prefix; verify paths when editing |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Remove Stop Hook TTS and Modify Notification Matcher [COMPLETED]

**Goal**: Eliminate TTS from the Stop hook and remove idle_prompt from the Notification hook across all settings.json files. This is the lowest-risk, highest-impact change and must happen first to prevent double TTS when Stage 8a is later added.

**Tasks**:
- [ ] Edit `.claude/settings.json`: remove the `bash .claude/hooks/tts-notify.sh 2>/dev/null || echo '{}'` line from the Stop hook (line 102)
- [ ] Edit `.claude/settings.json`: change Notification matcher from `permission_prompt|idle_prompt|elicitation_dialog` to `permission_prompt|elicitation_dialog` (line 144)
- [ ] Edit `.claude/extensions/core/root-files/settings.json`: same Stop hook TTS removal (line 102) and Notification matcher change (line 144)
- [ ] Edit `.opencode/settings.json`: remove tts-notify.sh from Stop hook (line 131) and change Notification matcher (line 155)
- [ ] Verify no other settings.json files contain TTS hooks (OpenCode templates are 18 lines with no hooks -- confirmed safe to skip)

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/settings.json` - Remove Stop TTS line, modify Notification matcher
- `.claude/extensions/core/root-files/settings.json` - Same changes (synced template)
- `.opencode/settings.json` - Same changes with `.opencode/` path prefix

**Verification**:
- `grep -r "tts-notify" .claude/settings.json .opencode/settings.json .claude/extensions/core/root-files/settings.json` shows tts-notify.sh only in Notification hooks, not Stop hooks
- `grep -r "idle_prompt" .claude/settings.json .opencode/settings.json .claude/extensions/core/root-files/settings.json` returns no matches

---

### Phase 2: Simplify tts-notify.sh and Create lifecycle-notify.sh [COMPLETED]

**Goal**: Rewrite `tts-notify.sh` to remove the entire normal mode section (lines 140-274), remove the B+A Hybrid signal file mechanism, remove cooldown logic, and keep lifecycle mode + a minimal no-arg interactive prompt path. Create the new `lifecycle-notify.sh` wrapper script. Sync all 4 copies to the simplified version.

**Tasks**:
- [ ] Rewrite `.claude/hooks/tts-notify.sh` to simplified version (~80-100 lines):
  - Keep: shebang, configuration (PIPER_MODEL, TTS_ENABLED), LOG_FILE
  - Keep: argument parsing for `--lifecycle STATUS`
  - Keep: piper/model availability checks
  - Keep: lifecycle mode section (current lines 97-138)
  - Add: minimal no-arg path that speaks "Tab N" for interactive prompts (no stdin parsing, no cooldown, no signal file)
  - Remove: LAST_NOTIFY_FILE, LIFECYCLE_SIGNAL_FILE, LIFECYCLE_SIGNAL_MAX_AGE constants
  - Remove: check_signal_file(), consume_signal_file() functions
  - Remove: entire normal mode section (lines 140-274): stdin parsing, cooldown check, worktree detection, subagent guard, signal file check, generic message building
- [ ] Create `.claude/scripts/lifecycle-notify.sh` wrapper script:
  - Takes STATUS argument
  - Calls `tts-notify.sh --lifecycle STATUS` in background
  - Calls `wezterm-notify.sh STATUS` in background
  - Gracefully no-ops if either script is unavailable
  - Make executable with `chmod +x`
- [ ] Copy simplified `tts-notify.sh` to `.claude/extensions/core/hooks/tts-notify.sh`
- [ ] Copy simplified `tts-notify.sh` to `.opencode/hooks/tts-notify.sh`
- [ ] Copy simplified `tts-notify.sh` to `.opencode/extensions/core/hooks/tts-notify.sh`
- [ ] Verify all 4 copies are identical: `diff` between all pairs

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/hooks/tts-notify.sh` - Rewrite to lifecycle + interactive-only (~80-100 lines)
- `.claude/scripts/lifecycle-notify.sh` - New wrapper script
- `.claude/extensions/core/hooks/tts-notify.sh` - Sync with simplified version
- `.opencode/hooks/tts-notify.sh` - Sync with simplified version
- `.opencode/extensions/core/hooks/tts-notify.sh` - Sync with simplified version

**Verification**:
- `wc -l .claude/hooks/tts-notify.sh` shows ~80-100 lines (down from 275)
- `diff .claude/hooks/tts-notify.sh .claude/extensions/core/hooks/tts-notify.sh` returns 0
- `diff .claude/hooks/tts-notify.sh .opencode/hooks/tts-notify.sh` returns 0
- `diff .claude/hooks/tts-notify.sh .opencode/extensions/core/hooks/tts-notify.sh` returns 0
- `bash .claude/hooks/tts-notify.sh` exits 0 with `{}` output (no-arg path, no crash)
- `ls -la .claude/scripts/lifecycle-notify.sh` confirms executable

---

### Phase 3: Remove TTS and Signal File from update-task-status.sh [COMPLETED]

**Goal**: Strip PHASE 5 of `update-task-status.sh` down to WezTerm tab coloring only. Remove signal file write and direct TTS invocation. TTS will now be fired by skill postflight Stage 8a via `lifecycle-notify.sh` instead.

**Tasks**:
- [ ] Edit `.claude/scripts/update-task-status.sh` PHASE 5 (lines 358-381):
  - Remove: signal file write (`mkdir -p "$TMP_DIR"` + `echo "$STATE_STATUS" > "$TMP_DIR/tts-lifecycle-signal"`) at lines 365-366
  - Remove: TTS invocation block (`tts_script` variable + `bash "$tts_script" --lifecycle` call) at lines 370-373
  - Keep: WezTerm notify block (`wezterm_script` variable + `bash "$wezterm_script"` call) at lines 376-380
  - Update PHASE 5 comment to reflect it now only handles WezTerm tab coloring
- [ ] Remove or update any references to the signal file elsewhere in the script (search for `tts-lifecycle-signal`)

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/update-task-status.sh` - PHASE 5: remove signal file + TTS, keep WezTerm

**Verification**:
- `grep "tts-lifecycle-signal" .claude/scripts/update-task-status.sh` returns no matches
- `grep "tts-notify" .claude/scripts/update-task-status.sh` returns no matches
- `grep "wezterm-notify" .claude/scripts/update-task-status.sh` still returns matches (WezTerm preserved)

---

### Phase 4: Add Stage 8a to All Delegating Skills [COMPLETED]

**Goal**: Insert a "Stage 8a: Lifecycle TTS Notification" section into all delegating skill SKILL.md files, placed between artifact linking (Stage 8) and the next stage (git commit or cleanup). This enables lifecycle TTS to fire after artifacts are linked and status is updated.

**Tasks**:
- [ ] Add Stage 8a to `.claude/skills/skill-researcher/SKILL.md` (between Stage 8: Link Artifacts and Stage 9: Cleanup)
- [ ] Add Stage 8a to `.claude/skills/skill-planner/SKILL.md` (between Stage 8: Link Artifacts and Stage 9: Git Commit)
- [ ] Add Stage 8a to `.claude/skills/skill-implementer/SKILL.md` (between Stage 8: Link Artifacts and Stage 9: Git Commit)
- [ ] Add Stage 8a to `.claude/skills/skill-reviser/SKILL.md` (between Stage 8: Artifact Linking and Stage 9: Git Commit)
- [ ] Add Stage 8a to `.claude/extensions/core/skills/skill-researcher/SKILL.md`
- [ ] Add Stage 8a to `.claude/extensions/core/skills/skill-planner/SKILL.md`
- [ ] Add Stage 8a to `.claude/extensions/core/skills/skill-implementer/SKILL.md`
- [ ] Add Stage 8a to `.claude/extensions/core/skills/skill-reviser/SKILL.md`
- [ ] Add Stage 8a to `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md` (between Stage 8 and Stage 9)
- [ ] Add Stage 8a to `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` (between Stage 8 and Stage 9)
- [ ] Add Stage 8a to `.claude/extensions/nix/skills/skill-nix-research/SKILL.md` (between Stage 8 and Stage 9)
- [ ] Add lifecycle notification to `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` (divergent format: adapt to its numbered 5-8 stage pattern, insert after status+artifact linking stage)

Stage 8a template for standard skills:
```markdown
### Stage 8a: Lifecycle TTS Notification

Fire TTS and WezTerm tab coloring after artifact linking is complete:

\`\`\`bash
lifecycle_script=".claude/scripts/lifecycle-notify.sh"
if [ -f "$lifecycle_script" ]; then
    bash "$lifecycle_script" "$STATE_STATUS" &
fi
\`\`\`

Non-blocking: called in background after artifacts are linked. Speaks "Tab N STATUS"
(e.g., "Tab 3 researched") to announce the lifecycle transition.
```

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Add Stage 8a
- `.claude/skills/skill-planner/SKILL.md` - Add Stage 8a
- `.claude/skills/skill-implementer/SKILL.md` - Add Stage 8a
- `.claude/skills/skill-reviser/SKILL.md` - Add Stage 8a
- `.claude/extensions/core/skills/skill-researcher/SKILL.md` - Add Stage 8a
- `.claude/extensions/core/skills/skill-planner/SKILL.md` - Add Stage 8a
- `.claude/extensions/core/skills/skill-implementer/SKILL.md` - Add Stage 8a
- `.claude/extensions/core/skills/skill-reviser/SKILL.md` - Add Stage 8a
- `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md` - Add Stage 8a
- `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` - Add Stage 8a
- `.claude/extensions/nix/skills/skill-nix-research/SKILL.md` - Add Stage 8a
- `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` - Add lifecycle notify in divergent format

**Verification**:
- `grep -r "Stage 8a\|lifecycle-notify" .claude/skills/*/SKILL.md` shows matches in all 4 core skills
- `grep -r "Stage 8a\|lifecycle-notify" .claude/extensions/core/skills/skill-{researcher,planner,implementer,reviser}/SKILL.md` shows matches in all 4 ext core skills
- `grep -r "Stage 8a\|lifecycle-notify" .claude/extensions/nvim/skills/*/SKILL.md` shows matches in 2 nvim skills
- `grep -r "lifecycle-notify" .claude/extensions/nix/skills/*/SKILL.md` shows matches in 2 nix skills

---

### Phase 5: Update Documentation [COMPLETED]

**Goal**: Update the 3 copies of `tts-stt-integration.md` to reflect the new lifecycle + interactive-only TTS model. Remove B+A Hybrid architecture description, remove idle_prompt from event tables, document the new `lifecycle-notify.sh` wrapper and skill Stage 8a pattern.

**Tasks**:
- [ ] Update `.claude/context/project/neovim/guides/tts-stt-integration.md`:
  - Remove B+A Hybrid architecture section and signal file descriptions
  - Update "Notification Event Types" table: remove idle_prompt row, remove "Stop (lifecycle suppressed)" row
  - Add description of lifecycle-notify.sh wrapper and skill Stage 8a pattern
  - Update trigger model to: lifecycle (via skill postflight) + interactive prompts (via Notification hook)
- [ ] Sync changes to `.claude/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md`
- [ ] Sync changes to `.opencode/docs/guides/tts-stt-integration.md`

**Timing**: 40 minutes

**Depends on**: 4

**Files to modify**:
- `.claude/context/project/neovim/guides/tts-stt-integration.md` - Update trigger model docs
- `.claude/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` - Sync doc update
- `.opencode/docs/guides/tts-stt-integration.md` - Sync doc update

**Verification**:
- `grep -r "idle_prompt\|signal file\|B+A Hybrid" .claude/context/project/neovim/guides/tts-stt-integration.md` returns no matches
- `diff .claude/context/project/neovim/guides/tts-stt-integration.md .claude/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` returns 0
- All 3 copies reflect the lifecycle + interactive-only model

---

## Testing & Validation

- [ ] After Phase 1: Verify TTS does NOT fire on normal Claude turns (Stop hook TTS removed)
- [ ] After Phase 2: `bash .claude/hooks/tts-notify.sh` exits 0 with `{}` (no-arg path works)
- [ ] After Phase 2: `bash .claude/hooks/tts-notify.sh --lifecycle test` produces TTS output (lifecycle path works)
- [ ] After Phase 2: `bash .claude/scripts/lifecycle-notify.sh researched` executes without error
- [ ] After Phase 2: All 4 tts-notify.sh copies are identical (`diff` returns 0 for all pairs)
- [ ] After Phase 3: `grep "tts-lifecycle-signal" .claude/scripts/update-task-status.sh` returns empty
- [ ] After Phase 4: `grep -r "lifecycle-notify" .claude/skills/*/SKILL.md .claude/extensions/*/skills/*/SKILL.md` shows all 12 skill files
- [ ] End-to-end: Run `/research` on a test task and verify "Tab N researched" TTS fires after artifact linking (not on every Stop)
- [ ] End-to-end: Trigger a permission prompt and verify "Tab N" TTS fires (interactive prompt path)

## Artifacts & Outputs

- `specs/586_restrict_tts_lifecycle_interactive/plans/01_restrict-tts-triggers.md` (this plan)
- `specs/586_restrict_tts_lifecycle_interactive/summaries/01_restrict-tts-triggers-summary.md` (after implementation)

## Rollback/Contingency

All changes are to text files (shell scripts, JSON settings, markdown skill definitions) tracked by git. If implementation fails:

1. `git stash` or `git checkout -- .claude/ .opencode/` to revert all changes
2. The original `tts-notify.sh` (275 lines) can be restored from git history
3. Settings.json files can be reverted individually
4. Skill SKILL.md files can have Stage 8a removed without affecting other stages

If only partial phases are completed:
- Phase 1 alone is safe: Stop hook TTS removed, lifecycle TTS still fires from update-task-status.sh
- Phases 1+2 without Phase 3: lifecycle-notify.sh exists but update-task-status.sh still fires TTS directly (harmless duplication, not double since Stop hook is already removed)
- Phase 4 without Phase 3: Stage 8a calls lifecycle-notify.sh in skills while update-task-status.sh also fires TTS (potential double lifecycle TTS -- avoid by completing Phase 3 before Phase 4 goes live)

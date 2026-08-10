# Implementation Plan: Task #637

- **Task**: 637 - verification_and_drift_detection
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: Tasks 633, 634, 635, 636 (all completed)
- **Research Inputs**: specs/637_verification_and_drift_detection/reports/01_parity-audit.md
- **Artifacts**: plans/01_verification-fix-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Fix 5 drift gaps identified by the parity audit between `.claude/` and `.opencode/` systems. The gaps range from critical agent path mismatches that break task routing, to hook scripts logging to the wrong directory, to validation scripts operating on the wrong system. All changes are mechanical path corrections with clear verification steps.

### Research Integration

Research report `01_parity-audit.md` identified 5 gaps across 3 severity tiers: 1 critical (broken agent paths in opencode-agents.json), 2 high (hooks + scripts with hardcoded `.claude/` paths), 1 medium (unregistered synthesis-agent), and 1 low (stale rules README). The audit confirmed structural parity is otherwise complete across all 19 commands, 22 skills, 16 extensions, and settings.json hooks.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. This is a meta verification task completing the .opencode/ porting effort (tasks 633-636).

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Fix all 5 drift gaps identified in the parity audit
- Ensure neovim and nix agent routing works correctly in OpenCode
- Ensure hook scripts write logs to `.opencode/logs` when run from OpenCode
- Ensure validation/lint scripts operate on `.opencode/` paths when invoked from `.opencode/`
- Register synthesis-agent in the core opencode-agents.json
- Correct stale rules README documentation

**Non-Goals**:
- Backporting forward-evolution differences from `.opencode/` to `.claude/` (epidemiology, filetypes, web extensions)
- Deduplicating the 8 `core/*` prefix entries in `.opencode/context/index.json` (cosmetic, not functional)
- Modifying any `.claude/` files (this task only fixes `.opencode/` drift)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Incorrect agent paths break OpenCode routing | H | L | Verify actual file existence before writing new paths |
| Script path changes introduce new bugs | M | L | Each script has a clear grep-verifiable pattern; run scripts after to confirm no errors |
| Missing a stale `.claude/` reference in a script | M | M | Run `grep -rn '\.claude/' .opencode/scripts/` after fixes to confirm zero remaining references |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 4, 5 | -- |

Phases within the same wave can execute in parallel.

---

### Phase 1: Fix Agent Paths in opencode-agents.json [COMPLETED]

**Goal**: Correct the 4 broken agent prompt paths in nvim and nix extension opencode-agents.json files so OpenCode can load domain agents.

**Tasks**:
- [x] In `.opencode/extensions/nvim/opencode-agents.json`, change `neovim-implementation` prompt from `{file:.opencode/agent/subagents/neovim-implementation-agent.md}` to `{file:.opencode/extensions/nvim/agents/neovim-implementation-agent.md}` *(completed)*
- [x] In `.opencode/extensions/nvim/opencode-agents.json`, change `neovim-research` prompt from `{file:.opencode/agent/subagents/neovim-research-agent.md}` to `{file:.opencode/extensions/nvim/agents/neovim-research-agent.md}` *(completed)*
- [x] In `.opencode/extensions/nix/opencode-agents.json`, change `nix-implementation` prompt from `{file:.opencode/agent/subagents/nix-implementation-agent.md}` to `{file:.opencode/extensions/nix/agents/nix-implementation-agent.md}` *(completed)*
- [x] In `.opencode/extensions/nix/opencode-agents.json`, change `nix-research` prompt from `{file:.opencode/agent/subagents/nix-research-agent.md}` to `{file:.opencode/extensions/nix/agents/nix-research-agent.md}` *(completed)*

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.opencode/extensions/nvim/opencode-agents.json` - Fix 2 prompt paths
- `.opencode/extensions/nix/opencode-agents.json` - Fix 2 prompt paths

**Verification**:
- All 4 referenced files exist at the new paths
- JSON is valid after edit (`jq . < file`)
- `grep -c "agent/subagents" .opencode/extensions/{nvim,nix}/opencode-agents.json` returns 0

---

### Phase 2: Fix Hook Log Directory Paths [COMPLETED]

**Goal**: Update 3 hook scripts to write logs to `.opencode/logs` instead of `.claude/logs`.

**Tasks**:
- [x] In `.opencode/hooks/log-session.sh`, change line 5 from `LOG_DIR=".claude/logs"` to `LOG_DIR=".opencode/logs"` *(completed)*
- [x] In `.opencode/hooks/post-command.sh`, change line 5 from `LOG_DIR=".claude/logs"` to `LOG_DIR=".opencode/logs"` *(completed)*
- [x] In `.opencode/hooks/subagent-postflight.sh`, change line 35 from `local LOG_DIR=".claude/logs"` to `local LOG_DIR=".opencode/logs"` *(completed)*

**Timing**: 5 minutes

**Depends on**: none

**Files to modify**:
- `.opencode/hooks/log-session.sh` - Change LOG_DIR on line 5
- `.opencode/hooks/post-command.sh` - Change LOG_DIR on line 5
- `.opencode/hooks/subagent-postflight.sh` - Change LOG_DIR on line 35

**Verification**:
- `grep -rn '\.claude/' .opencode/hooks/` returns no results
- `grep -n '\.opencode/logs' .opencode/hooks/*.sh` shows all 3 files

---

### Phase 3: Fix Validation Script Paths [COMPLETED]

**Goal**: Update all validation and lint scripts in both `.opencode/scripts/` and `.opencode/extensions/core/scripts/` to reference `.opencode/` paths instead of `.claude/`.

**Tasks**:
- [x] In `.opencode/scripts/validate-context-index.sh`: change header comment, line 23 `INDEX_FILE` from `.claude/context/index.json` to `.opencode/context/index.json`, and line 24 `CONTEXT_DIR` from `.claude/context` to `.opencode/context` *(completed)*
- [x] In `.opencode/scripts/validate-index.sh`: change header comment, line 22 default from `.claude/context/index.json` to `.opencode/context/index.json`, and line 23 `CONTEXT_DIR` from `.claude/context` to `.opencode/context` *(completed)*
- [x] In `.opencode/scripts/check-extension-docs.sh`: change header comment (line 4), usage lines (17-18), line 28 `EXT_DIR` from `.claude/extensions` to `.opencode/extensions`, and line 160 echo from `.claude/extensions/` to `.opencode/extensions/` *(completed)*
- [x] In `.opencode/scripts/validate-extension-index.sh`: update line 143 glob from `.claude/extensions/*/index-entries.json` to `.opencode/extensions/*/index-entries.json`; leave line 86 jq path-prefix check unchanged (it correctly rejects both `.claude/` and `.opencode/` prefixes as invalid) *(completed)*
- [x] In `.opencode/scripts/lint/lint-postflight-boundary.sh`: change line 48 find paths from `.claude/skills` and `.claude/extensions` to `.opencode/skills` and `.opencode/extensions`; change line 168 reference from `.claude/context/standards/` to `.opencode/context/standards/` *(completed)*
- [x] Repeat all 5 fixes for the corresponding copies in `.opencode/extensions/core/scripts/` *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.opencode/scripts/validate-context-index.sh` - Fix 3 `.claude/` path references
- `.opencode/scripts/validate-index.sh` - Fix 3 `.claude/` path references
- `.opencode/scripts/check-extension-docs.sh` - Fix 4 `.claude/` path references
- `.opencode/scripts/validate-extension-index.sh` - Fix 1 `.claude/` path reference (line 143)
- `.opencode/scripts/lint/lint-postflight-boundary.sh` - Fix 2 `.claude/` path references
- `.opencode/extensions/core/scripts/validate-context-index.sh` - Mirror fixes
- `.opencode/extensions/core/scripts/validate-index.sh` - Mirror fixes
- `.opencode/extensions/core/scripts/check-extension-docs.sh` - Mirror fixes
- `.opencode/extensions/core/scripts/validate-extension-index.sh` - Mirror fixes
- `.opencode/extensions/core/scripts/lint/lint-postflight-boundary.sh` - Mirror fixes

**Verification**:
- `grep -rn '\.claude/' .opencode/scripts/` returns only intentional references (line 86 jq check in validate-extension-index.sh which correctly rejects `.claude/` prefixes, and any documentation comments)
- `grep -rn '\.claude/' .opencode/extensions/core/scripts/` returns only intentional references
- Each script can be run with `--help` or dry-run mode without errors

---

### Phase 4: Register synthesis-agent in Core Agents [COMPLETED]

**Goal**: Add the `synthesis-agent` entry to `.opencode/extensions/core/opencode-agents.json` so it can be loaded by team-research and team-plan skills.

**Tasks**:
- [x] Add a `"synthesis"` agent entry to `.opencode/extensions/core/opencode-agents.json` with prompt path `{file:.opencode/agent/subagents/synthesis-agent.md}` and appropriate tools (read, write, edit, glob, grep, bash, webfetch, websearch) *(completed)*

**Timing**: 5 minutes

**Depends on**: none

**Files to modify**:
- `.opencode/extensions/core/opencode-agents.json` - Add synthesis agent entry

**Verification**:
- `jq '.agent.synthesis' .opencode/extensions/core/opencode-agents.json` returns valid entry
- File referenced in prompt field exists: `.opencode/agent/subagents/synthesis-agent.md`
- JSON is valid after edit

---

### Phase 5: Fix Rules README Inaccuracy [COMPLETED]

**Goal**: Update `.opencode/rules/README.md` to remove the `neovim-lua.md` entry that does not exist in that directory (it is in `.opencode/extensions/nvim/rules/` instead).

**Tasks**:
- [x] Remove the `- neovim-lua.md - Neovim Lua development rules` line from `.opencode/rules/README.md` *(completed: also removed stale agent-system.mdc, neovim-lua.mdc, state-management.mdc entries; added plan-format-enforcement.md, project-overview-detection.md entries that were missing)*
- [x] Optionally add a note that extension-specific rules live in `.opencode/extensions/*/rules/` *(completed)*

**Timing**: 5 minutes

**Depends on**: none

**Files to modify**:
- `.opencode/rules/README.md` - Remove stale file listing, add extension note

**Verification**:
- README lists only files that actually exist in `.opencode/rules/`
- `ls .opencode/rules/*.md | xargs -I{} basename {}` matches README entries

---

## Testing & Validation

- [ ] `grep -rn '\.claude/' .opencode/hooks/` returns 0 matches
- [ ] `grep -rn '\.claude/' .opencode/scripts/` returns only intentional references (validate-extension-index.sh line 86 jq check)
- [ ] `grep -rn '\.claude/' .opencode/extensions/core/scripts/` returns only intentional references
- [ ] `grep -rn 'agent/subagents' .opencode/extensions/{nvim,nix}/opencode-agents.json` returns 0 matches
- [ ] `jq . .opencode/extensions/{nvim,nix,core}/opencode-agents.json` parses without error
- [ ] All 4 domain agent files exist at their new referenced paths
- [ ] `jq '.agent.synthesis' .opencode/extensions/core/opencode-agents.json` returns valid entry
- [ ] `.opencode/rules/README.md` lists only files present in `.opencode/rules/`

## Artifacts & Outputs

- `specs/637_verification_and_drift_detection/plans/01_verification-fix-plan.md` (this file)
- `specs/637_verification_and_drift_detection/summaries/01_verification-fix-summary.md` (after implementation)

## Rollback/Contingency

All changes are path string replacements in configuration files. If any change causes issues:
1. Revert the specific file using `git checkout -- <file>`
2. No build artifacts or compiled code are affected
3. The `.claude/` system is completely unmodified and remains functional as a fallback

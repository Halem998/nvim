# Implementation Plan: PAI Component Integration

- **Task**: 320 - study_personal_ai_infrastructure
- **Status**: [NOT STARTED]
- **Effort**: 12-15 hours
- **Dependencies**: None
- **Research Inputs**: specs/320_study_personal_ai_infrastructure/reports/02_team-research.md
- **Artifacts**: plans/02_pai-integration.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan integrates 10 PAI components identified in team research, organized by priority tier (P0-P3). The approach prioritizes quick wins that address existing bugs or gaps before moving to larger capability additions. Each phase is atomic and independently verifiable.

### Research Integration

Key findings from team research (02_team-research.md):
- P0 quick wins fix existing false-positive bugs (SkillGuard, AgentExecutionGuard)
- P1 components provide immediate value (ContextSearch, Thinking, BackupRestore)
- P2/P3 components require more adaptation but offer significant capability boosts
- Our system has features PAI lacks (SubagentStop hook, formal state machine, extensions)

## Goals & Non-Goals

**Goals**:
- Integrate P0 components (SkillGuard, AgentExecutionGuard) as immediate fixes
- Add P1 utilities (ContextSearch, Thinking frameworks, BackupRestore)
- Establish hook documentation standard for maintainability
- Adopt ExtractWisdom and Extension INSTALL.md patterns
- Create IntegrityCheck hook for drift detection

**Non-Goals**:
- Full Evals framework TypeScript tooling (conceptual adoption only)
- PAIUpgrade self-improvement workflow (deferred)
- CLAUDE.md template system (too invasive)
- Replacing existing hook architecture

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Hook conflicts with existing hooks | M | L | Test hooks independently; use distinct trigger conditions |
| ContextSearch privacy concerns | H | L | Search only local files; no telemetry |
| Thinking frameworks slow down research | M | M | Make opt-in via flag, not default |
| IntegrityCheck false positives | M | M | Start with warning-only mode; tune over time |
| Backup script misses critical files | H | L | Test backup/restore cycle before relying on it |

## Implementation Phases

### Phase 1: P0 Quick Wins [NOT STARTED]

**Goal**: Port SkillGuard and AgentExecutionGuard hooks to address existing bugs

**Tasks**:
- [ ] Create `.claude/hooks/skill-guard.sh` - Port PAI's SkillGuard hook to bash
  - Block false-positive skill invocations from position bias
  - Pattern: Check tool_input for skill names that match non-invocation patterns
  - Return `{"decision": "block", "reason": "..."}` on false positive
- [ ] Create `.claude/hooks/agent-guard.sh` - Port PAI's AgentExecutionGuard to bash
  - Warn when Task tool runs without `run_in_background: true`
  - Non-blocking (warning only in additionalContext)
- [ ] Update `.claude/settings.json` to register new hooks
- [ ] Test both hooks with intentional trigger scenarios

**Timing**: 1 hour

**Files to modify**:
- `.claude/hooks/skill-guard.sh` (new)
- `.claude/hooks/agent-guard.sh` (new)
- `.claude/settings.json`

**Verification**:
- Hooks execute without errors in hook log
- SkillGuard blocks test false-positive pattern
- AgentGuard warns on foreground Task call

---

### Phase 2: BackupRestore Utility [NOT STARTED]

**Goal**: Create backup/restore script for .claude/ directory safety

**Tasks**:
- [ ] Create `.claude/scripts/backup.sh` implementing:
  - Timestamped backup to `~/.claude-backups/{YYYY-MM-DD_HH-MM-SS}/`
  - Named backup option: `backup.sh --name pre-migration`
  - List backups: `backup.sh --list`
  - Restore: `backup.sh --restore {name|latest}`
  - Diff preview: `backup.sh --diff {name|latest}`
- [ ] Create `.claude/scripts/restore.sh` as symlink or wrapper for clarity
- [ ] Add backup directory to global .gitignore if needed
- [ ] Document usage in `.claude/docs/guides/backup-restore.md`

**Timing**: 2 hours

**Files to modify**:
- `.claude/scripts/backup.sh` (new)
- `.claude/scripts/restore.sh` (new, symlink)
- `.claude/docs/guides/backup-restore.md` (new)

**Verification**:
- `backup.sh` creates timestamped archive
- `backup.sh --list` shows available backups
- `backup.sh --restore latest` successfully restores

---

### Phase 3: ContextSearch Command [NOT STARTED]

**Goal**: Enable cross-session context recovery via new /context-search command

**Tasks**:
- [ ] Create `.claude/commands/context-search.md` implementing search across:
  - `~/.claude/history.jsonl` (Claude Code conversation history)
  - Git log messages with task references
  - Project memory files (`.memory/`)
  - Specs artifacts (reports, plans, summaries)
- [ ] Define search syntax: `/context-search "query" [--depth N] [--type history|git|memory|specs]`
- [ ] Format output for easy context insertion
- [ ] Add command reference to CLAUDE.md

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/commands/context-search.md` (new)
- `.claude/CLAUDE.md` (add command reference)

**Verification**:
- `/context-search "task 320"` returns relevant history
- `--type git` filter returns only git log matches
- Output is formatted for easy copy/paste

---

### Phase 4: Thinking Frameworks [NOT STARTED]

**Goal**: Add structured analytical reasoning frameworks as optional skill

**Tasks**:
- [ ] Create `.claude/skills/skill-thinking.md` with frameworks:
  - First Principles: Decompose problem to fundamentals
  - Council Debate: Multiple perspectives argue positions
  - Red Team: Adversarial analysis of proposed solution
  - Scientific Method: Hypothesis, test, conclude pattern
  - Five Whys: Root cause analysis
- [ ] Add `--think` flag support to skill-researcher
- [ ] Add `--think` flag support to skill-planner
- [ ] Document framework selection criteria

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/skills/skill-thinking.md` (new)
- `.claude/skills/skill-researcher.md` (add --think flag)
- `.claude/skills/skill-planner.md` (add --think flag)

**Verification**:
- `/research 1 --think=council` invokes Council framework
- Framework adds structured reasoning section to report
- Thinking is optional (no performance impact when unused)

---

### Phase 5: Hook Documentation Standard [NOT STARTED]

**Goal**: Adopt PAI's hook documentation headers for maintainability

**Tasks**:
- [ ] Create `.claude/context/standards/hook-documentation.md` defining:
  - PURPOSE: What the hook accomplishes
  - TRIGGER: Hook type and conditions (PreToolUse, PostToolUse, etc.)
  - INPUT: Environment variables and CLAUDE_TOOL_INPUT schema
  - OUTPUT: Decision JSON schema and exit codes
  - SIDE EFFECTS: Files created, external calls, etc.
  - PERFORMANCE: Expected latency bounds
- [ ] Update existing hooks with new headers:
  - `subagent-postflight.sh`
  - `validate-state-sync.sh`
  - `log-session.sh`
  - `post-command.sh`
  - `wezterm-*.sh` (4 hooks)
  - `tts-notify.sh`
  - `skill-guard.sh` (from Phase 1)
  - `agent-guard.sh` (from Phase 1)
- [ ] Add hook documentation requirement to contribution guidelines

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/context/standards/hook-documentation.md` (new)
- `.claude/hooks/*.sh` (update headers on all 11 hooks)

**Verification**:
- All hooks have complete PURPOSE/TRIGGER/INPUT/OUTPUT headers
- New hook standard is referenced in CLAUDE.md
- `grep -l "PURPOSE:" .claude/hooks/*.sh` returns all hooks

---

### Phase 6: ExtractWisdom Integration [NOT STARTED]

**Goal**: Add content analysis capability to /research command

**Tasks**:
- [ ] Create `.claude/skills/skill-extract-wisdom.md` implementing:
  - 5 depth levels: skim, standard, deep, exhaustive, academic
  - Dynamic section detection (key insights, quotes, implications, etc.)
  - Structured output format matching report-format.md
- [ ] Add `--extract-wisdom` flag to `/research` command
- [ ] Create `.claude/context/patterns/content-extraction.md` with best practices

**Timing**: 2 hours

**Files to modify**:
- `.claude/skills/skill-extract-wisdom.md` (new)
- `.claude/commands/research.md` (add --extract-wisdom flag)
- `.claude/context/patterns/content-extraction.md` (new)

**Verification**:
- `/research 1 --extract-wisdom` produces structured content analysis
- Depth levels produce proportionally more/less detail
- Output integrates with existing report format

---

### Phase 7: Extension INSTALL.md Pattern [NOT STARTED]

**Goal**: Make extensions self-installable without full agent system

**Tasks**:
- [ ] Create template: `.claude/extensions/template/INSTALL.md`
  - Step-by-step wizard-style installation
  - Prerequisites section
  - Configuration section
  - Verification section
- [ ] Create template: `.claude/extensions/template/VERIFY.md`
  - Test commands to validate installation
  - Expected outputs
  - Common troubleshooting
- [ ] Add INSTALL.md to existing extensions:
  - `nvim/` extension
  - `lean4/` extension (if exists)
  - Other active extensions
- [ ] Update extension creation guide

**Timing**: 2-3 hours

**Files to modify**:
- `.claude/extensions/template/INSTALL.md` (new)
- `.claude/extensions/template/VERIFY.md` (new)
- `.claude/extensions/*/INSTALL.md` (new for each active extension)
- `.claude/extensions/*/VERIFY.md` (new for each active extension)

**Verification**:
- Extension can be installed following only INSTALL.md
- VERIFY.md commands pass on fresh installation
- Template is documented for future extensions

---

### Phase 8: IntegrityCheck Hook [NOT STARTED]

**Goal**: Detect documentation drift at session end

**Tasks**:
- [ ] Create `.claude/hooks/integrity-check.sh` implementing:
  - Trigger: SessionEnd or NotificationStop
  - Read changed files from `CLAUDE_TOOL_INPUT` transcript
  - Flag changes to `.claude/` system files
  - Check if corresponding documentation was updated
  - Output warning in additionalContext (non-blocking)
- [ ] Create drift detection heuristics:
  - Commands changed but CLAUDE.md not updated
  - New hooks without settings.json registration
  - Skills added without skill-to-agent mapping update
- [ ] Add configuration for ignored paths

**Timing**: 3-4 hours

**Files to modify**:
- `.claude/hooks/integrity-check.sh` (new)
- `.claude/settings.json` (register hook)
- `.claude/context/patterns/integrity-checks.md` (new, heuristics documentation)

**Verification**:
- Hook executes on session end without blocking
- Warns when command added but CLAUDE.md unchanged
- Ignores configured false-positive paths

---

### Phase 9: Evals Framework (Conceptual) [NOT STARTED]

**Goal**: Document evaluation patterns for agent quality measurement

**Tasks**:
- [ ] Create `.claude/docs/reference/standards/evals-framework.md`:
  - Grader types: exact_match, semantic, custom
  - pass@k metrics explanation
  - Failure-to-task conversion pattern
  - Integration with errors.json
- [ ] Add `--create-eval` flag concept to `/errors` command documentation
  - Converts error patterns to evaluation criteria
  - Does not implement full tooling yet
- [ ] Document future implementation roadmap

**Timing**: 1-2 hours

**Files to modify**:
- `.claude/docs/reference/standards/evals-framework.md` (new)
- `.claude/commands/errors.md` (document future --create-eval)

**Verification**:
- Framework documentation is complete and actionable
- Integration points with existing system are clear
- Future implementation path is documented

## Testing & Validation

- [ ] P0 hooks tested with intentional trigger scenarios
- [ ] Backup/restore cycle tested on copy of .claude/
- [ ] ContextSearch returns relevant results across sources
- [ ] Thinking frameworks produce structured reasoning
- [ ] All hooks have compliant documentation headers
- [ ] At least one extension has complete INSTALL.md/VERIFY.md
- [ ] IntegrityCheck warns on known drift scenario
- [ ] Full `/research`, `/plan`, `/implement` cycle works with new components

## Artifacts & Outputs

- `.claude/hooks/skill-guard.sh` - False positive prevention hook
- `.claude/hooks/agent-guard.sh` - Background agent enforcement hook
- `.claude/hooks/integrity-check.sh` - Drift detection hook
- `.claude/scripts/backup.sh` - Backup utility
- `.claude/commands/context-search.md` - Cross-session search command
- `.claude/skills/skill-thinking.md` - Analytical frameworks skill
- `.claude/skills/skill-extract-wisdom.md` - Content analysis skill
- `.claude/context/standards/hook-documentation.md` - Hook header standard
- `.claude/extensions/template/INSTALL.md` - Installation wizard template
- `.claude/extensions/template/VERIFY.md` - Verification template
- `.claude/docs/reference/standards/evals-framework.md` - Evaluation patterns

## Rollback/Contingency

- Each phase is independent; partial completion is valid
- New hooks can be disabled in settings.json without deletion
- Backup script allows rollback to pre-integration state
- All new files are additive (no destructive changes to existing system)
- Git tags before/after integration enable full revert if needed

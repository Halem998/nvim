# Implementation Plan: Wire --lit Flag Through Workflow Commands

- **Task**: 690 - Wire --lit flag through /research, /plan, /implement, /orchestrate commands
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: Task 688 (COMPLETED) -- LIT_FLAG added to parse-command-args.sh
- **Research Inputs**: specs/690_wire_lit_flag_commands/reports/01_wire-lit-commands.md
- **Artifacts**: plans/01_wire-lit-commands-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Thread the `--lit` flag through all four workflow commands (research.md, plan.md, implement.md, orchestrate.md) so that literature-mode is available end-to-end. Each command needs: (1) Options table documentation, (2) flag extraction in STAGE 1.5 where applicable, (3) `lit_flag={lit_flag}` appended to skill invocation args in STAGE 2. After editing the active command files, sync all four to their extension core copies and verify with grep.

### Research Integration

The research report provides exact line numbers and insertion points for all four command files. Key findings:
- `research.md` and `plan.md` parse flags inline (STAGE 1.5) and need a new numbered item for `lit_flag` inserted after `clean_flag`.
- `implement.md` and `orchestrate.md` delegate to `parse-command-args.sh` (which already exports `LIT_FLAG` from task 688) and only need the export comment updated and `lit_flag` added to skill args strings.
- `orchestrate.md` has no Options table; a minimal one should be added for consistency.
- All four files have identical copies in `.claude/extensions/core/commands/` that must be synced.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly correspond to this flag-threading work.

## Goals & Non-Goals

**Goals**:
- Add `--lit` to Options table documentation in all four commands
- Add `lit_flag` extraction in STAGE 1.5 for `research.md` and `plan.md`
- Append `lit_flag={lit_flag}` (or `lit_flag={LIT_FLAG}`) to all skill invocation args strings
- Update export comment in `implement.md` to list `LIT_FLAG`
- Add `lit_flag` to delegation context JSON in `orchestrate.md`
- Sync all changes to `.claude/extensions/core/commands/`

**Non-Goals**:
- Modifying skill SKILL.md files (task 689 scope)
- Modifying `literature-retrieve.sh` or any retrieval scripts
- Changing `parse-command-args.sh` (already done in task 688)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `--lit` leaks into focus_prompt in research.md | M | M | Add `--lit` to flag-removal list in the focus_prompt extraction step |
| Renumbering error in plan.md STAGE 1.5 items | L | M | Follow research report insertion points precisely; verify numbering after edit |
| Extension core copies drift from active files | M | L | Copy immediately after editing each file; diff to confirm |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Edit Four Command Files [COMPLETED]

**Goal**: Add `--lit` flag support to all four active command files in `.claude/commands/`.

**Tasks**:
- [x] **research.md**: Add `--lit` row to Options table after `--clean` *(completed)*
- [x] **research.md**: Insert item 6 "Extract Lit Flag" in STAGE 1.5 after "Extract Clean Flag" (item 5) *(completed)*
- [x] **research.md**: Renumber old item 6 "Extract Focus Prompt" to item 7 *(completed)*
- [x] **research.md**: Add `--lit` to flag-removal list in the focus_prompt extraction step *(completed)*
- [x] **research.md**: Append `lit_flag={lit_flag}` to both team-mode and single-agent skill args in STAGE 2 *(completed)*
- [x] **plan.md**: Add `--lit` row to Options table after `--clean` *(completed)*
- [x] **plan.md**: Insert item 6 "Extract Lit Flag" in STAGE 1.5 after "Extract Clean Flag" (item 5), renumber "Extract Roadmap Flag" to item 7 *(completed)*
- [x] **plan.md**: Append `lit_flag={lit_flag}` to all three skill args strings in STAGE 2 (team, extension-routed, default) *(completed)*
- [x] **implement.md**: Add `--lit` row to Options table after `--clean` *(completed)*
- [x] **implement.md**: Update STAGE 0 export comment to include `LIT_FLAG` *(completed)*
- [x] **implement.md**: Append `lit_flag={LIT_FLAG}` to both team-mode and single-agent skill args in STAGE 2 *(completed)*
- [x] **orchestrate.md**: Add minimal Options section with `--lit` row after Constraints section *(completed)*
- [x] **orchestrate.md**: Append `lit_flag={LIT_FLAG}` to single-task skill args in STAGE 2 *(completed)*
- [x] **orchestrate.md**: Add `"lit_flag": "{LIT_FLAG}"` to single-task delegation context JSON *(completed)*
- [x] **orchestrate.md**: Append `lit_flag={LIT_FLAG}` to multi-task dispatch skill args *(completed)*
- [x] **orchestrate.md**: Add `"lit_flag": "{LIT_FLAG}"` to multi-task delegation context JSON *(completed)*

**Timing**: 40 minutes

**Depends on**: none

**Files to modify**:
- `.claude/commands/research.md` -- Options table, STAGE 1.5 items 5-7, STAGE 2 skill args
- `.claude/commands/plan.md` -- Options table, STAGE 1.5 items 5-7, STAGE 2 skill args
- `.claude/commands/implement.md` -- Options table, STAGE 0 comment, STAGE 2 skill args
- `.claude/commands/orchestrate.md` -- New Options section, STAGE 2 skill args + delegation JSON, multi-task dispatch

**Verification**:
- `grep -c 'lit_flag' .claude/commands/research.md` returns >= 4 (Options row, extract item, 2 skill args)
- `grep -c 'lit_flag' .claude/commands/plan.md` returns >= 4 (Options row, extract item, 3 skill args)
- `grep -c 'lit_flag\|LIT_FLAG' .claude/commands/implement.md` returns >= 4 (Options row, export comment, 2 skill args)
- `grep -c 'lit_flag\|LIT_FLAG' .claude/commands/orchestrate.md` returns >= 6 (Options row, 2 skill args, 2 delegation JSON, 1 multi-task)

---

### Phase 2: Sync Extension Core Copies and Verify [COMPLETED]

**Goal**: Copy all four edited command files to their extension core mirrors and verify consistency.

**Tasks**:
- [x] Copy `.claude/commands/research.md` to `.claude/extensions/core/commands/research.md` *(completed)*
- [x] Copy `.claude/commands/plan.md` to `.claude/extensions/core/commands/plan.md` *(completed)*
- [x] Copy `.claude/commands/implement.md` to `.claude/extensions/core/commands/implement.md` *(completed)*
- [x] Copy `.claude/commands/orchestrate.md` to `.claude/extensions/core/commands/orchestrate.md` *(completed)*
- [x] Run `diff` on each pair to confirm identical content *(completed: all identical)*
- [x] Run final grep verification across all 8 files for `lit_flag` *(completed: all 8 files confirmed)*

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/core/commands/research.md` -- overwrite with active copy
- `.claude/extensions/core/commands/plan.md` -- overwrite with active copy
- `.claude/extensions/core/commands/implement.md` -- overwrite with active copy
- `.claude/extensions/core/commands/orchestrate.md` -- overwrite with active copy

**Verification**:
- `diff .claude/commands/research.md .claude/extensions/core/commands/research.md` produces no output
- `diff .claude/commands/plan.md .claude/extensions/core/commands/plan.md` produces no output
- `diff .claude/commands/implement.md .claude/extensions/core/commands/implement.md` produces no output
- `diff .claude/commands/orchestrate.md .claude/extensions/core/commands/orchestrate.md` produces no output
- `grep -rl 'lit_flag' .claude/commands/ .claude/extensions/core/commands/` lists all 8 files

## Testing & Validation

- [ ] All four active command files contain `--lit` in their Options tables
- [ ] `research.md` and `plan.md` contain "Extract Lit Flag" item in STAGE 1.5
- [ ] All skill args strings across all four commands include `lit_flag=`
- [ ] `implement.md` export comment lists `LIT_FLAG`
- [ ] `orchestrate.md` delegation context JSON includes `lit_flag`
- [ ] All four extension core copies are byte-identical to their active counterparts

## Artifacts & Outputs

- `specs/690_wire_lit_flag_commands/plans/01_wire-lit-commands-plan.md` (this plan)
- Modified: `.claude/commands/{research,plan,implement,orchestrate}.md`
- Synced: `.claude/extensions/core/commands/{research,plan,implement,orchestrate}.md`

## Rollback/Contingency

All changes are additive (appending flag entries to existing patterns). Rollback by reverting the commit that implements this plan. No state.json or structural changes involved -- purely markdown command file edits.

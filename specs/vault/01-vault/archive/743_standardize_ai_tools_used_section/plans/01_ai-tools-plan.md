# Implementation Plan: Standardize AI Tools Used Section

- **Task**: 743 - Standardize AI Tools Used section across PR templates and agents
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/743_standardize_ai_tools_used_section/reports/01_ai-tools-standardization.md
- **Artifacts**: plans/01_ai-tools-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The canonical PR description template in `pr-description-format.md` uses the heading `## AI Tools Used` with a fully rendered paragraph body. Two generation sites are inconsistent: `cslib-implementation-agent.md` uses a vague `[describe what it did]` placeholder instead of referencing the canonical template, and `pr.md` uses the outdated `## AI Disclosure` heading in both the draft template and two edit-handler replace targets. This plan fixes both files to align with the canonical format. Done when grep confirms zero remaining `## AI Disclosure` headings in generated templates.

### Research Integration

Research report (`reports/01_ai-tools-standardization.md`) confirmed:
- The canonical template in `pr-description-format.md` (lines 237-246) is correct and requires no changes
- `cslib-implementation-agent.md` lines 356-360: correct heading but vague placeholder body
- `pr.md` line 1441: uses `## AI Disclosure` heading in draft template
- `pr.md` lines 1403 and 1468: edit-handler replace targets reference `## AI Disclosure`
- Four additional files use "AI Disclosure" as a concept label (not generated heading) and need no changes

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances the "Agent System Quality" priority under Phase 1 of ROADMAP.md, specifically the "Zero stale references to removed/renamed files" success metric.

## Goals & Non-Goals

**Goals**:
- Replace the vague placeholder in `cslib-implementation-agent.md` with a reference to the canonical template
- Change all three occurrences of `## AI Disclosure` in `pr.md` to `## AI Tools Used`
- Verify no remaining `## AI Disclosure` headings exist in generated PR templates

**Non-Goals**:
- Changing the canonical template in `pr-description-format.md` (already correct)
- Renaming "AI Disclosure" when used as a concept/policy label in rules, conventions, or contributing docs
- Fixing the hardcoded author name in `pr.md` (pre-existing, out of scope)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Edit-handler replace target mismatch | H | L | Change heading and replace targets together in the same phase |
| Missed occurrence in pr.md | M | L | Verification phase uses grep to catch any remaining instances |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix cslib-implementation-agent.md [IN PROGRESS]

**Goal**: Replace the vague placeholder code block with a reference to the canonical template in pr-description-format.md.

**Tasks**:
- [ ] In `.claude/extensions/cslib/agents/cslib-implementation-agent.md`, replace lines 356-360 (the code block containing the `[describe what it did]` placeholder) with an instruction directing the agent to use the canonical template from `pr-description-format.md` (Section 9: AI Tools Used)

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/agents/cslib-implementation-agent.md` - Replace placeholder code block (lines 356-360) with canonical template reference

**Verification**:
- The file no longer contains `[describe what it did]`
- The file references `pr-description-format.md` for the AI Tools Used section content

---

### Phase 2: Fix pr.md heading and edit-handler targets [NOT STARTED]

**Goal**: Change the `## AI Disclosure` heading and both edit-handler replace targets to `## AI Tools Used`.

**Tasks**:
- [ ] Line 1441: Change `## AI Disclosure` to `## AI Tools Used` in the draft template
- [ ] Line 1403: Change `replace \`## AI Disclosure\`` to `replace \`## AI Tools Used\`` in Step 8 edit handler
- [ ] Line 1468: Change `replace \`## AI Disclosure\`` to `replace \`## AI Tools Used\`` in Step 9 edit handler

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` - Three text replacements (lines 1403, 1441, 1468)

**Verification**:
- `grep -n "## AI Disclosure" .claude/extensions/cslib/commands/pr.md` returns zero results
- `grep -n "## AI Tools Used" .claude/extensions/cslib/commands/pr.md` returns at least the draft template heading and two replace targets

---

### Phase 3: Verification [NOT STARTED]

**Goal**: Confirm all generated PR template headings are standardized and no regressions exist.

**Tasks**:
- [ ] Run `grep -rn "## AI Disclosure" .claude/extensions/cslib/agents/ .claude/extensions/cslib/commands/` and confirm zero matches
- [ ] Run `grep -rn "## AI Tools Used" .claude/extensions/cslib/agents/ .claude/extensions/cslib/commands/` and confirm expected matches in both files
- [ ] Verify `pr-description-format.md` is unchanged (canonical source integrity)

**Timing**: 5 minutes

**Depends on**: 1, 2

**Files to modify**:
- None (read-only verification)

**Verification**:
- All grep checks pass with expected results
- No unintended changes to any other files

## Testing & Validation

- [ ] `grep -rn "## AI Disclosure" .claude/extensions/cslib/agents/ .claude/extensions/cslib/commands/` returns 0 results
- [ ] `grep -rn "## AI Tools Used" .claude/extensions/cslib/commands/pr.md` returns at least 1 match (line ~1441)
- [ ] `grep -rn "describe what it did" .claude/extensions/cslib/agents/cslib-implementation-agent.md` returns 0 results
- [ ] `grep -rn "pr-description-format" .claude/extensions/cslib/agents/cslib-implementation-agent.md` returns at least 1 match
- [ ] `pr-description-format.md` is unmodified (check with `git diff`)

## Artifacts & Outputs

- `specs/743_standardize_ai_tools_used_section/plans/01_ai-tools-plan.md` (this plan)
- Modified: `.claude/extensions/cslib/agents/cslib-implementation-agent.md`
- Modified: `.claude/extensions/cslib/commands/pr.md`

## Rollback/Contingency

Both files are tracked by git. If changes cause issues:
```bash
git checkout -- .claude/extensions/cslib/agents/cslib-implementation-agent.md
git checkout -- .claude/extensions/cslib/commands/pr.md
```

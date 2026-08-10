# Implementation Plan: Update cslib extension README.md

- **Task**: 754 - Update cslib extension README.md to reflect all capabilities
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/754_update_cslib_extension_readme/reports/01_cslib-readme-update.md
- **Artifacts**: plans/01_cslib-readme-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Rewrite `.claude/extensions/cslib/README.md` to reflect all capabilities documented in EXTENSION.md and manifest.json. The current README omits 4 agents, 5 skills, 1 command, 1 rule, the `pr` task type, hard-mode support, and the PR review workflow. EXTENSION.md is the authoritative source; the README is the consumer-facing summary.

### Research Integration

Research report (01_cslib-readme-update.md) cataloged 10 discrepancy categories between README.md and the source-of-truth files (EXTENSION.md, manifest.json, filesystem). Key findings:
- Architecture tree missing 4 agents, 5 skills, 1 command, 1 rule
- Skill-agent mapping table has 2 rows (should be 7)
- Language routing table missing `pr` task type row
- No Commands section documenting `/pr`
- No Hard-Mode section
- No PR review workflow documentation
- No keyword auto-detection or dependencies documentation

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Update architecture tree to list all 6 agents, 7 skills, 1 command, 2 rules
- Expand skill-agent mapping table from 2 to 7 rows
- Add `pr` task type to language routing table
- Add Commands section documenting `/pr` with all three usage forms
- Add Hard-Mode section with trigger conditions and H-technique list
- Add PR Review Workflow section
- Add keyword auto-detection note and dependencies section

**Non-Goals**:
- Modifying EXTENSION.md or manifest.json (these are the sources of truth)
- Changing CI Verification Pipeline section (already accurate)
- Changing the References section (already accurate)
- Bumping manifest.json version number (documentation-only change)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| README diverges from EXTENSION.md again in future | M | M | Add a note at top of README pointing to EXTENSION.md as authoritative source |
| Over-duplicating EXTENSION.md content into README | L | M | Summarize rather than copy; link to EXTENSION.md for details |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Rewrite README.md [COMPLETED]

**Goal**: Replace the outdated README.md with a complete, accurate version reflecting all cslib extension capabilities.

**Tasks**:
- [ ] Read current README.md for structure reference
- [ ] Update title to include version: `# CSLib Extension (v1.0.0)`
- [ ] Add authoritative-source note below title pointing to EXTENSION.md
- [ ] Update overview table to include both `cslib` and `pr` task types, plus hard-mode routing note
- [ ] Rewrite architecture tree to list all files:
  - agents/ (6): cslib-research-agent.md, cslib-implementation-agent.md, cslib-research-hard-agent.md, cslib-implementation-hard-agent.md, pr-review-research-agent.md, pr-review-implementation-agent.md
  - skills/ (7): skill-cslib-research, skill-cslib-implementation, skill-pr-implementation, skill-cslib-research-hard, skill-cslib-implementation-hard, skill-pr-review-research, skill-pr-review-implementation
  - commands/ (1): pr.md
  - rules/ (2): cslib.md, cslib-lint-fix.md
- [ ] Expand skill-agent mapping table to 7 rows (copy from EXTENSION.md)
- [ ] Add `pr` row to language routing table
- [ ] Add Commands section documenting `/pr` with three usage forms from EXTENSION.md
- [ ] Add Hard-Mode section with 5 trigger conditions, H-technique list, cost note, and routing_hard entries
- [ ] Add PR Review Workflow section explaining pr-submission vs pr-review paths
- [ ] Add Keyword Auto-Detection section with keyword_overrides from manifest.json
- [ ] Add Dependencies section listing lean, literature, and core extensions
- [ ] Keep CI Verification Pipeline section unchanged
- [ ] Keep References section unchanged

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/README.md` - Complete rewrite to match EXTENSION.md capabilities

**Verification**:
- All 6 agents listed in architecture tree
- All 7 skills listed in architecture tree
- commands/ shows pr.md (not "(none)")
- rules/ shows both cslib.md and cslib-lint-fix.md
- Skill-agent mapping table has 7 rows
- Language routing table has rows for both `cslib` and `pr`
- Commands section documents `/pr` with three forms
- Hard-Mode section present with trigger conditions
- PR Review Workflow section present
- Keyword auto-detection and dependencies sections present

## Testing & Validation

- [ ] Architecture tree lists match filesystem: 6 agents, 7 skills, 1 command, 2 rules
- [ ] Skill-agent mapping table matches EXTENSION.md (7 rows)
- [ ] Language routing table matches EXTENSION.md (2 rows: cslib, pr)
- [ ] Commands section matches EXTENSION.md /pr documentation
- [ ] Hard-mode section content matches EXTENSION.md
- [ ] No content fabricated beyond what exists in EXTENSION.md and manifest.json
- [ ] CI Verification Pipeline section unchanged
- [ ] References section unchanged

## Artifacts & Outputs

- `.claude/extensions/cslib/README.md` - Updated README with complete capabilities

## Rollback/Contingency

Git revert of the single commit will restore the previous README.md. No other files are modified.

# Implementation Plan: Task #703

- **Task**: 703 - Create literature organization guide
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/703_create_literature_organization_guide/reports/01_lit-org-guide.md
- **Artifacts**: plans/01_lit-org-guide.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a context guide documenting `specs/literature/` conventions for the `--lit` injection system. The guide covers directory structure (flat files vs author/year subdirectories), `index.json` entry schema (script-required and metadata fields), naming conventions, chunk sizing policy, keyword-scoring injection mechanics, and a step-by-step procedure for manually adding new papers. Register the guide in `.claude/context/index.json` for loading by research agents and `--lit` operations.

### Research Integration

Research report (01_lit-org-guide.md) confirmed all authoritative facts from `literature-retrieve.sh`: two operating modes (index-guided keyword scoring vs fallback scan), `entries[]` schema with 6 script-required fields and 5 metadata convention fields, TOKEN_BUDGET=4000, MAX_FILES=10, MIN_SCORE=1, token estimation formula `(word_count * 13 + 5) / 10`, and the `load_when` registration pattern for context/index.json.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Document the complete `specs/literature/` directory convention from scratch
- Describe both flat-file and subdirectory organization patterns
- Provide the full `index.json` entry schema with field-level documentation
- Explain how `--lit` injection works end-to-end (keyword scoring, greedy selection, output assembly)
- Include a step-by-step procedure for adding new papers
- Register the guide in `.claude/context/index.json`

**Non-Goals**:
- Modifying `literature-retrieve.sh` or any script behavior
- Creating the `specs/literature/` directory itself (user-maintained)
- Implementing any new features for the literature system

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Guide documents `chapters[]` format not yet implemented in script | M | M | Clearly label per-book index.json as organizational convention only, note that the script reads only the top-level index.json |
| Token count field going stale after file edits | L | M | Document re-estimation command: `echo $(( $(wc -w < file.md) * 13 / 10 ))` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Create literature organization guide [COMPLETED]

**Goal**: Write the complete guide at `.claude/context/guides/literature-organization.md`.

**Tasks**:
- [ ] Create the guide file with all sections documented in the research report
- [ ] Document directory structure: flat files (`Author_Year_Title.md`) and subdirectories (`Author_Year_Title/secNN_slug.md`)
- [ ] Document the full `index.json` entry schema with field tables distinguishing script-required fields from metadata conventions
- [ ] Document subdirectory index format (`chapters[]`) with clear note that it is organizational only
- [ ] Document naming conventions for flat papers and chapter files
- [ ] Document chunk sizing policy: TOKEN_BUDGET=4000, target ~3000 tokens per file (~2300 words), token estimation formula
- [ ] Document `--lit` injection mechanics end-to-end: keyword extraction, scoring algorithm, greedy budget selection, output assembly
- [ ] Document fallback scan mode (no index, no keywords)
- [ ] Include step-by-step procedure for manually adding new papers
- [ ] Include concrete JSON examples for flat paper entries and chapter entries

**Timing**: 40 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/guides/literature-organization.md` - Create new guide file

**Verification**:
- File exists and contains all required sections
- JSON examples are valid
- Field tables distinguish required vs optional vs metadata-only fields
- Style matches existing guides (extension-development.md)

---

### Phase 2: Register guide in context index [COMPLETED]

**Goal**: Add the new guide entry to `.claude/context/index.json` so it loads for research agents and `--lit` operations.

**Tasks**:
- [ ] Count the actual line count of the created guide
- [ ] Add entry to `.claude/context/index.json` entries array with: path, summary, domain, keywords, subdomain, line_count, load_when (commands: /research, /plan, /implement; agents: general-research-agent), topics
- [ ] Validate the resulting JSON is well-formed

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/context/index.json` - Add new entry to entries array

**Verification**:
- `jq . .claude/context/index.json` succeeds (valid JSON)
- New entry appears in entries array with correct `load_when` targeting
- `line_count` matches actual file

## Testing & Validation

- [ ] `.claude/context/guides/literature-organization.md` exists and is non-empty
- [ ] Guide contains all 8 content sections from the research report
- [ ] JSON examples in the guide are syntactically valid
- [ ] `.claude/context/index.json` is valid JSON after edit
- [ ] New index entry has correct `load_when` fields (commands: /research, /plan, /implement; agents: general-research-agent)
- [ ] `line_count` in index entry matches actual line count of guide

## Artifacts & Outputs

- `.claude/context/guides/literature-organization.md` - The literature organization guide
- `.claude/context/index.json` - Updated with new entry

## Rollback/Contingency

- Delete `.claude/context/guides/literature-organization.md` to remove the guide
- Revert the index.json entry addition (single entry in entries array)
- No other files are modified; rollback is trivial

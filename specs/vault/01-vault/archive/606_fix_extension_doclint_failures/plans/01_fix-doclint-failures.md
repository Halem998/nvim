# Implementation Plan: Fix Extension Doc-Lint Failures

- **Task**: 606 - fix_extension_doclint_failures
- **Status**: [IMPLEMENTING]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: None
- **Artifacts**: plans/01_fix-doclint-failures.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two extension README files are missing documentation for commands declared in their respective `manifest.json` files. The core extension README omits `/project-overview` and the filetypes extension README omits `/sheet`. Each README needs a command entry added in the style and location consistent with its existing command documentation. After fixes, `check-extension-docs.sh` must pass with zero failures.

### Research Integration

No research report available. Task scope is clear from the doc-lint output and inspection of the manifest and README files.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Add `/project-overview` documentation to core extension README.md
- Add `/sheet` documentation to filetypes extension README.md
- Pass `check-extension-docs.sh` with zero failures

**Non-Goals**:
- Restructuring or rewriting existing README content
- Addressing non-failure warnings (e.g., the drift warning for core README age)
- Modifying manifest.json files

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New command docs inconsistent with existing README style | L | L | Read existing README structure before writing; match format exactly |
| Doc-lint script checks more than command name presence | L | L | Run full script after edits to confirm pass |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Add /project-overview to Core README [COMPLETED]

**Goal**: Document the `/project-overview` command in the core extension README so the doc-lint check passes for core.

**Tasks**:
- [x] Read `.claude/extensions/core/commands/project-overview.md` for command details *(completed)*
- [x] Add `/project-overview` row to the Commands table in `.claude/extensions/core/README.md` (line ~42, after the `/merge` row) *(completed)*
- [x] Use format: `| /project-overview | /project-overview | Interactive repo scan and project-overview.md generation |` *(completed)*
- [x] Verify the command count in the Overview table is updated (14 -> 15 commands) *(completed)*

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/README.md` - Add /project-overview to Commands table, update command count

**Verification**:
- grep confirms `/project-overview` appears in README.md
- Command count in Overview table matches manifest commands array length

---

### Phase 2: Add /sheet to Filetypes README [COMPLETED]

**Goal**: Document the `/sheet` command in the filetypes extension README so the doc-lint check passes for filetypes.

**Tasks**:
- [x] Read `.claude/extensions/filetypes/commands/sheet.md` for command details *(completed)*
- [x] Add `/sheet` row to the Commands overview table in `.claude/extensions/filetypes/README.md` (after the `/edit` row, line ~14) *(completed)*
- [x] Add a `### /sheet` section under the Commands section (after the `/edit` subsection, around line ~103) with syntax examples and agent info *(completed)*
- [x] Update the Overview paragraph "five commands" to "six commands" and the command count *(completed)*
- [x] Update the Architecture tree to include `sheet.md` in the commands directory listing *(completed)*

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/filetypes/README.md` - Add /sheet to overview table, add /sheet command section, update counts and architecture tree

**Verification**:
- grep confirms `/sheet` appears in README.md
- Command documentation follows same pattern as existing /edit, /convert entries

---

### Phase 3: Verify All Doc-Lint Checks Pass [COMPLETED]

**Goal**: Run `check-extension-docs.sh` and confirm zero failures for all extensions.

**Tasks**:
- [x] Run `bash .claude/scripts/check-extension-docs.sh` *(completed)*
- [x] Verify core extension status is PASS *(completed)*
- [x] Verify filetypes extension status is PASS *(completed)*
- [x] Verify total issue count is 0 *(completed)*
- [x] If any failures remain, iterate on the specific README until the check passes *(completed: no failures)*

**Timing**: 5 minutes

**Depends on**: 1, 2

**Files to modify**:
- None (verification only; may require edits to files from Phase 1 or 2 if checks fail)

**Verification**:
- `check-extension-docs.sh` exits with 0 and reports "PASS" for all extensions

## Testing & Validation

- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0 with all extensions PASS
- [ ] Core README `/project-overview` entry matches manifest command definition
- [ ] Filetypes README `/sheet` entry matches manifest command definition
- [ ] No existing documentation was accidentally removed or altered

## Artifacts & Outputs

- `.claude/extensions/core/README.md` - Updated with /project-overview documentation
- `.claude/extensions/filetypes/README.md` - Updated with /sheet documentation

## Rollback/Contingency

Both changes are additive text insertions to README files. If either change causes issues, `git checkout` the original README files. No code, configuration, or build artifacts are affected.

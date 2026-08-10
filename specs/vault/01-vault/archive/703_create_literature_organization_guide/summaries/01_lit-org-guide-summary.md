# Implementation Summary: Task #703

**Completed**: 2026-06-14
**Duration**: ~30 minutes

## Overview

Created `.claude/context/guides/literature-organization.md`, a comprehensive reference guide
documenting the `specs/literature/` directory conventions and the `--lit` injection system.
Registered the guide in `.claude/context/index.json` so it loads for research agents and
`/research`, `/plan`, `/implement` commands.

## What Changed

- `.claude/context/guides/literature-organization.md` - Created new guide (318 lines) covering
  all 8 content sections: overview, directory structure, naming conventions, index.json schema,
  chunk sizing policy, --lit injection mechanics, adding new papers, and maintenance
- `.claude/context/index.json` - Added new entry for `guides/literature-organization.md` with
  `load_when` targeting `/research`, `/plan`, `/implement` commands and `general-research-agent`

## Decisions

- Documented `entries[]` schema with both script-required fields and metadata convention fields
  (bib_key, authors, year, section, page_range), clearly distinguishing which are read by the
  script vs. which are human/tooling conventions
- Per-book `index.json` files inside subdirectories are documented as organizational conventions
  only, with an explicit note that `literature-retrieve.sh` reads only the top-level index
- Chunk sizing target set at ~3000 tokens (~2300 words) to leave budget headroom for multiple
  files within the 4000-token injection ceiling
- The index entry uses `load_when.commands` for `/research`, `/plan`, `/implement` (the commands
  that support `--lit`) and `load_when.agents` for `general-research-agent`

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A
- Tests: N/A
- Files verified: Yes
  - `jq . .claude/context/index.json` exits cleanly (valid JSON)
  - New index entry confirmed present with correct `load_when` fields
  - Guide contains all 8 required sections
  - `line_count` (318) matches actual file line count

## Notes

The guide is grounded in the authoritative `literature-retrieve.sh` script constants:
TOKEN_BUDGET=4000, MAX_FILES=10, MIN_SCORE=1, token formula `(word_count * 13 + 5) / 10`.
These values are documented inline so they remain accurate if the script changes.

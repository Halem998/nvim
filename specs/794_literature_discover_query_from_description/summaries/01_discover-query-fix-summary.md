# Implementation Summary: Task #794

**Completed**: 2026-07-01
**Duration**: ~45 minutes

## Overview

Fixed two defects in `literature-discover.sh`: the `--task N` form previously built its search
query from the task's bookkeeping slug (`.project_name`), returning empty results; it now
derives the query from `.description` and `.title` in `specs/state.json`. Also added a
one-time stderr setup hint when `zotero-library.json` is missing, and cleared the stderr
swallow points that had been silencing it. Both the canonical extension source and the flat
deployed copy were edited and re-synced to byte parity.

## What Changed

- `.claude/extensions/literature/scripts/literature-discover.sh` (canonical) -- FIX 1: replaced
  the `.project_name` slug-based `--task N` query construction (lines ~105-132) with a
  description+title derivation via jq against `specs/state.json`, with null/empty guards and
  exit 2 if both are empty or the task/state file is missing. FIX 2: added a two-line stderr
  setup hint in `tier2_search` when `zotero-library.json` is absent (matching
  `zotero-search.sh` wording); changed the tier call site from `tier2_search 2>/dev/null || true`
  to `tier2_search || true`; added `2>/dev/null` parity to the two previously-unredirected
  `python3 -c` calls building `authors_arr`.
- `.claude/scripts/literature-discover.sh` (flat) -- re-synced byte-identical to canonical via
  `cp -p`, executable bit preserved.

## Decisions

- Dropped `.project_name` entirely from the `--task N` query path (per plan/user decision);
  slug is bookkeeping noise, not subject matter.
- `filter_terms()`/`FILTERED_TERMS` (lines 169-201/196) required no changes -- they already
  operate on the final `SEARCH_TERMS` regardless of source.
- Only the `tier2_search` call site's outer `2>/dev/null` was removed; `tier1_search` and
  `tier3_search` call sites were left untouched (out of scope).

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (bash script, no build step)
- Tests: Passed
  - `bash -n` syntax check: PASS on both canonical and flat copies.
  - (a) `bash -x .claude/scripts/literature-discover.sh --task 794` confirmed `task_terms`/
    `SEARCH_TERMS` built from task 794's full description+title text; no slug tokens
    (`literature_discover_query_from_description`) present.
  - (b) `LITERATURE_DIR=/nonexistent-dir bash .claude/scripts/literature-discover.sh "some terms"`:
    stdout parsed as valid JSON (`jq .`); stderr contained the Zotero setup hint
    (`grep -i zotero`); exit status (1) confirmed identical before/after the change via a
    `git stash`/`git stash pop` comparison against the pre-edit script.
  - (c) `diff` between canonical and flat copies: empty (byte-identical).
  - (d) `bash .claude/scripts/check-extension-docs.sh`: `literature` section reports PASS;
    overall FAIL (2 issues) is the pre-existing, unrelated lean-extension gap
    (`skill-lean-research-hard`/`skill-lean-implementation-hard` not deployed) -- expected,
    not a regression.
- Files verified: Yes

## Notes

- Follow-up gap (documented, out of scope for this task): `literature.md` (~lines 125-139)
  captures the whole script's stderr via `2>/dev/null` when invoking the script through
  `/literature N`, so the new Zotero missing-export hint currently surfaces only on direct
  script invocation, not through the `/literature N` command path.
- `zotero-library.json` creation remains a user action; not created as part of this task.

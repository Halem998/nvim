# Implementation Summary: Delegate Zotero data-directory resolution to the shared resolver

**Completed**: 2026-07-25
**Duration**: ~0.75 hours

## Overview

`literature-audit.sh` and `zotero-setup.sh` each maintained their own hardcoded Zotero
data-directory candidate ladder instead of delegating to the canonical resolver
(`zotero-resolve-sqlite-path.sh`). On this machine both private ladders picked the stale
`~/Zotero` profile over the live custom dataDir at `~/Documents/Zotero`, so `zotero-setup.sh
--detect` reported a stale, storage-less profile and `literature-audit.sh` probed a
`~/Zotero/storage` directory that does not exist on disk. Both sites now delegate to the
resolver, matching the two-line idiom already used by `zotero-resolve-pdf.sh`. The resolver
itself, `_detect_data_dir()` Steps 1/2, and the export pipeline were left untouched.

## What Changed

- `agent-system/extensions/literature/scripts/literature-audit.sh` — added
  `ZOTERO_DATA_DIR="$(dirname "$("$SCRIPT_DIR/zotero-resolve-sqlite-path.sh")")"` above
  `DEFAULT_SEARCH_PATHS`, replaced the array's hardcoded third element
  `"$HOME/Zotero/storage"` with `"$ZOTERO_DATA_DIR/storage"`, and added a comment stating the
  storage root is derived from the canonical resolver, never hardcoded.
- `agent-system/extensions/literature/scripts/zotero-setup.sh` — replaced
  `_detect_data_dir()`'s Step 3 private three-candidate `for` loop
  (`~/Zotero`, `~/Documents/Zotero`, `$XDG_DATA_HOME/Zotero`) with a call to
  `"$SCRIPT_DIR/zotero-resolve-sqlite-path.sh"` + `dirname`, retaining the
  `[[ -d ... && -f ... ]]` existence guard before `echo`/`return 0` and the trailing
  `return 1`. Steps 1 (`$ZOT_DATA_DIR`) and 2 (`zotero-index.json`) are byte-for-byte
  unchanged. Reworded the `cmd_detect` "Checked:" stderr diagnostic to name
  `$ZOT_DATA_DIR`, the index file, then the resolver's actual 3-tier ladder
  (`$ZOTERO_SQLITE_PATH` override / auto-detected custom dataDir from Zotero's `prefs.js` /
  historical `~/Zotero` default) instead of listing three paths as independently probed.

No other files were modified. `zotero-resolve-sqlite-path.sh`, `zotero-generate-export.sh`,
`zotero-library.json`, and `~/Zotero` were not touched.

## Decisions

- Followed the plan's prescribed idiom verbatim (`zotero-resolve-pdf.sh:75-76` pattern) rather
  than inventing a new delegation style, per the research report's precedent.
- Kept both callers' own `-d`/`-f` existence probes on the resolved path, since the resolver
  performs no existence check itself (documented in its own header).
- Worded the reworded diagnostic to name the resolver's tiers rather than assert specific paths
  were checked for existence, avoiding a misleading implication.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (bash scripts)
- Tests: N/A (no test suite covers these files; confirmed via `bash -n` and live execution)
- Files verified: Yes

### Baseline (Phase 1, pre-patch)

| Probe | Result |
|---|---|
| `zotero-resolve-sqlite-path.sh` stdout | `/home/benjamin/Documents/Zotero/zotero.sqlite` (exit 0) |
| `zotero-setup.sh --detect` stdout | `/home/benjamin/Zotero` (exit 0) — diverges from the resolver |
| `literature-audit.sh` third `DEFAULT_SEARCH_PATHS` element | `"$HOME/Zotero/storage"` |
| `$HOME/Zotero/storage` | does not exist |
| Resolver-derived `$HOME/Documents/Zotero/storage` | exists, 939 entries |

### Post-patch (Phase 4)

| Probe | Result |
|---|---|
| `zotero-resolve-sqlite-path.sh` stdout (control) | `/home/benjamin/Documents/Zotero/zotero.sqlite` (exit 0, unchanged from baseline) |
| `zotero-setup.sh --detect` stdout | `/home/benjamin/Documents/Zotero` (exit 0) |
| `literature-audit.sh` third search path (re-derived) | `/home/benjamin/Documents/Zotero/storage` |

**Three-way agreement**: `--detect` output (`/home/benjamin/Documents/Zotero`) == `dirname` of
the resolver's output (`/home/benjamin/Documents/Zotero`) == the audit search path with
`/storage` stripped (`/home/benjamin/Documents/Zotero`). Confirmed equal.

**Live run**: `literature-audit.sh --xref` was executed directly (not just diffed). Its
`find_test_pdfs()` picked up 5 PDFs — `Priest - 1979 - The logic of paradox.pdf`,
`Finkbeiner et al. - 2015 - ...HyperLTL and HyperCTL.pdf`,
`Metaphysical_Essays_----_(Pg_196--221).pdf`, `2010 - PSR - Rocca.pdf`, and
`2002 - Introduction to Lattices and Order - Davey, Priestley.pdf` — all five confirmed (by a
direct `find` on the resolver-derived storage dir) to live under
`/home/benjamin/Documents/Zotero/storage/<key>/`. The first two `DEFAULT_SEARCH_PATHS` entries
contributed 0 PDFs (`~/Projects/BimodalLogic/specs/literature` exists but is empty;
`~/Projects/Literature/pdfs` does not exist on this machine), so all 5 test PDFs came from the
resolver-derived third path — direct confirmation the fix is live, not merely diffed. Both
audits (`Audit 2: Cross-Reference Extraction`) completed and reported PASS.

**Scope checks**:
- `git diff --stat` across the three implementation commits touches exactly
  `literature-audit.sh` and `zotero-setup.sh` — `zotero-resolve-sqlite-path.sh` is absent from
  the diff (unmodified).
- `git status --porcelain` after all edits shows no `.claude/` paths and no path outside
  `agent-system/extensions/literature/scripts/` or `specs/904_zotero_resolver_delegation_audit_setup/`
  among this task's changes (other pre-existing unrelated working-tree modifications were
  present before this task started and are untouched by it).
- `~/Zotero` still exists and was not modified; `zotero-library.json` was not regenerated.
- No new task-number citation was introduced in either script (`git diff` added lines contain
  none). The pre-existing citation at `zotero-setup.sh:4` (`# Category A: CLI Wrapper
  (implemented in task 750)`) predates this work, is out of scope per the plan, and was left
  unchanged — the advisory `validate-no-task-references.sh` hook did not flag it since the edit
  did not touch that line.
- Both scripts pass `bash -n`.
- `_detect_data_dir()` retains exactly 5 occurrences in `zotero-setup.sh` (1 definition + 4
  callers: `cmd_detect`, `cmd_configure`, `cmd_validate`, `cmd_status`) — all four call sites
  unchanged.

## Notes

This machine's divergence was strong (the stale profile's storage dir did not even exist, vs.
939 entries in the live one), giving a clear before/after contrast. No follow-up work is
implied; per the plan's rollback note, if the resolver's output is ever found wrong on some
other machine, the correct fix is in the resolver itself, not a second ladder in either caller.

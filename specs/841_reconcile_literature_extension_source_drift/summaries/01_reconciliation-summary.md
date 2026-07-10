# Implementation Summary: Task #841

**Completed**: 2026-07-10
**Duration**: ~1 hour

## Overview

Reconciled the literature extension SOURCE OF TRUTH (`.claude/extensions/literature/scripts/`)
against its DEPLOYED COPIES (`.claude/scripts/`), which had drifted behind by correctness fixes
from tasks #831/#833/#835/#839. Backported the 6 drifted files verbatim (deployed→source),
added the deployed-only `literature-fidelity-audit.sh` producer tool to the extension source and
registered it in the manifest, and installed a content-diff drift guard in
`check-extension-docs.sh` that fails when a `manifest.provides.scripts` entry's deployed copy
diverges from its extension-source copy (skipping never-deployed scripts, not failing on them).
All 7 reconciled pairs are byte-identical, the guard was proven to actually fail on an injected
divergence and recover to PASS on revert, and `literature-fidelity-audit.sh --dry-run` output is
byte-identical to the pre-task baseline.

## What Changed

- `.claude/extensions/literature/scripts/literature-search.sh` — overwritten with deployed content (verbatim copy; now carries task #835/#839 provenance/fidelity flagging, 2 `unadjudicated` refs)
- `.claude/extensions/literature/scripts/literature-briefing.sh` — overwritten with deployed content (verbatim copy; now carries task #839's `needs_fidelity_marker()` fix, 3 `unadjudicated` refs)
- `.claude/extensions/literature/scripts/literature-schema.sql` — overwritten with deployed content (verbatim copy; task #833 three-table architecture / chunks_trigram fix)
- `.claude/extensions/literature/scripts/literature-chunk.sh` — overwritten with deployed content (verbatim copy; task #833 BUG 3 section_stack fix)
- `.claude/extensions/literature/scripts/literature-convert.sh` — overwritten with deployed content (verbatim copy; largest diff, 881 lines)
- `.claude/extensions/literature/scripts/literature-ingest.sh` — overwritten with deployed content (verbatim copy; task #831 Phase 5 quality-gate-rejection tracking)
- `.claude/extensions/literature/scripts/literature-fidelity-audit.sh` — new file, verbatim copy of the deployed-only fidelity/provenance producer tool
- `.claude/extensions/literature/manifest.json` — added `"literature-fidelity-audit.sh"` to `provides.scripts` (inserted after `literature-search.sh`)
- `.claude/scripts/check-extension-docs.sh` — added `check_deployed_script_drift()` (Rule F): content-diffs each `manifest.provides.scripts` entry's deployed copy against its extension-source copy via `cmp -s`, failing only when BOTH copies exist and differ; skips (does not fail) when the deployed copy is absent (the never-deployed extension-only scripts). Wired into the main per-extension loop.
- `.claude/extensions/core/scripts/check-extension-docs.sh` — synced to match the deployed edit above (see Plan Deviations)
- `specs/841_reconcile_literature_extension_source_drift/.baseline-fidelity-audit-dryrun.txt` — pre-task baseline capture (dry-run output, grep counts, sha256 sums, pre-task diff status) plus Phase 5 post-task verification results appended

## Decisions

- Placed `literature-fidelity-audit.sh` in `provides.scripts` immediately after `literature-search.sh` to keep it near its primary consumer, rather than appending at the end of the array.
- Used `cp` (never hand-edit/re-derive) for every backport to guarantee byte-identical results and eliminate transcription risk, per the plan's explicit risk mitigation for the 881-line `literature-convert.sh` diff.
- The drift guard was implemented as a new `check_deployed_script_drift()` function following the existing `check_manifest_entries` pattern (same `fail`/`info` helpers, same 0/1 exit contract), rather than as a `.syncprotect` entry, per the plan's stated preference (`.syncprotect` would freeze scripts against all future legitimate sync).

## Plan Deviations

- **Task 4.5** (not itemized in the original plan, added during Phase 4): Also synced
  `.claude/extensions/core/scripts/check-extension-docs.sh` to match the deployed edit. The plan
  listed only `.claude/scripts/check-extension-docs.sh` as a file to modify, but that script is
  itself a `core` extension `provides.scripts` entry. Editing only the deployed copy would have
  made the brand-new guard immediately self-flag `core` with a drift FAIL on its own addition.
  Mirrored the edit into the extension source (same direction as the plan's own Phase 2 backport
  pattern) so the guard is self-consistent from the moment it exists.
- **Task 5 (final full-script exit code)**: The plan's Phase 5 verification says the full
  `check-extension-docs.sh` run should "exit 0 (PASS)". In practice the script-wide exit code is
  1. The `[literature]` extension section itself is PASS with zero drift failures and correctly
  skips (does not fail) the 9 never-deployed `zotero-*`/`cite-extract.sh` scripts. The exit 1
  comes from 5 unrelated, pre-existing failures: 3 in `core` (undeclared script references —
  `literature-briefing-invoke.sh`, `orchestrator-postflight.sh`, `task-lock.sh`) and 2 in `lean`
  (routing_hard targets not deployed). Verified via `git stash` that these exact 5 failures exist
  identically with all of task 841's changes fully reverted — they predate and are unrelated to
  this task's scope. Documented rather than silently claimed as a clean PASS.

## Verification

- Build: N/A (bash scripts, no build step)
- Tests: All 7 reconciled pairs byte-identical (`diff` empty); `grep -c unadjudicated` on
  extension-source `literature-search.sh` = 2 and `literature-briefing.sh` = 3, matching deployed
  baseline; guard proven to FAIL on an injected divergence (exit 1, explicit FAIL line naming the
  file) and to recover to PASS after revert; `literature-fidelity-audit.sh --dry-run` output
  byte-identical to the pre-task baseline (`diff` exit 0); all 7 deployed target-file sha256 sums
  unchanged from the pre-task baseline (deployed copies never touched).
- Files verified: Yes

## Notes

- The `[literature]` extension section of `check-extension-docs.sh` is a clean PASS. The
  script-wide exit 1 is caused entirely by pre-existing, unrelated `core`/`lean` failures (see
  Plan Deviations) that are out of scope for this task and were not introduced or worsened by
  this work.
- No deployed `.claude/scripts/` copy of any of the 6 backported files or `literature-fidelity-audit.sh`
  was modified; all edits flowed deployed→extension-source only, as required.
- `literature-schema.sql` was never executed against any database; only the extension-source
  *file* was edited.

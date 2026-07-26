# Implementation Summary: Task #905

**Completed**: 2026-07-27
**Duration**: ~5 hours (5 phases)

## Overview

Zotero export staleness is now a detected, propagated, and loudly-surfaced condition. A new
shared classifier (`zotero-export-freshness.sh`) compares the export's generation timestamp
against the live Zotero sqlite database's mtime and reports one of four honest tokens. The
existing `zotero-export-status.sh` classifier consumes it and narrows `ZOTERO_EXPORT_PRESENT` to
mean "present AND confirmed fresh," folding everything else into a new `ZOTERO_EXPORT_STALE`
directive. `/literature`'s Mode A step 0 now offers assisted regeneration on STALE, both
interactively (`AskUserQuestion`) and autonomously (a visible `[zotero:auto]` notice, never a
silent no-op). `zotero-search.sh` independently guards against stale/unknown freshness with a
`[STALE EXPORT - export: DATE, sqlite: DATE]` banner and a new exit code 3 for a zero-result
search against an unconfirmed-fresh library.

## What Changed

- `agent-system/extensions/literature/scripts/zotero-export-freshness.sh` — new shared
  classifier. Four directives (`ZOTERO_EXPORT_FRESH` / `STALE` / `FRESHNESS_UNKNOWN` /
  `FRESHNESS_ABSENT`), one stdout line, exit 0 always (non-zero reserved for usage/dependency
  errors only). Reference timestamp prefers `.zotero-library.meta.json`'s `_generated` stamp
  (parsed via `date -d`), falling back to the export file's own mtime when the stamp is absent
  or malformed. Rationale on stderr includes machine-parseable `export_date=`/`sqlite_date=`
  tokens so downstream consumers never have to re-derive or regex-scrape a human-readable date.
- `agent-system/extensions/literature/scripts/zotero-export-status.sh` — the existing-export
  branch now delegates to the freshness helper (capture-guarded against `set -e`) instead of
  unconditionally emitting `ZOTERO_EXPORT_PRESENT`. `FRESH` maps to `PRESENT`; `STALE`,
  `FRESHNESS_UNKNOWN`, helper failure, or an unrecognized token all map to the new
  `ZOTERO_EXPORT_STALE`. Header/usage docs updated to five directives.
- `agent-system/extensions/literature/scripts/zotero-search.sh` — added `SCRIPT_DIR`, a
  capture-guarded freshness guard right after the library-existence check, an internal
  `FRESHNESS_CONFIRMED` flag, a `[STALE EXPORT ...]` stderr banner (also on stdout in
  `--format=pretty`), and exit code 3 for a zero-result search when freshness is not confirmed
  (exit 2 stays reserved for a confirmed-fresh zero-result). Documented as a `STABLE CONTRACT`
  header block, including an explicit scope-honesty statement that this guard is inert for
  today's two named consumers (see Scope Boundary below).
- `agent-system/extensions/literature/commands/literature.md` — Mode A step 0 narrows the
  `ZOTERO_EXPORT_PRESENT` bullet's wording and adds two new bullets: an interactive
  `ZOTERO_EXPORT_STALE` bullet (two-option `AskUserQuestion` naming both compared dates, using
  `--force`) and an autonomous `ZOTERO_EXPORT_STALE` bullet alongside the two existing
  `orchestrator_mode == true` bullets (never calls `AskUserQuestion`, always emits
  `[zotero:auto]`, also uses `--force`).
- `agent-system/extensions/literature/manifest.json` — added `"zotero-export-freshness.sh"` to
  `provides.scripts` (mechanically required for the new script to ever deploy).

## Decisions

- Reference-timestamp resolution prefers the content-derived meta stamp over raw file mtime
  (immune to checkout/rsync mtime resets), falling back to mtime only when the stamp is absent
  or fails to parse via `date -d` — the fallback is always named in the stderr rationale.
- The freshness helper's rationale carries explicit `export_date=`/`sqlite_date=` tokens (added
  during Phase 4, see Plan Deviations) rather than requiring callers to regex-scrape prose —
  this makes the exact `[STALE EXPORT - export: 2026-07-01, sqlite: 2026-07-15]` banner format
  a mechanical extraction rather than fragile text parsing.
- Both consumers treat helper failure, empty output, or any unrecognized token identically to
  a genuine STALE/UNKNOWN result — never silently PRESENT/fresh. This was verified live by
  temporarily renaming the helper binary and confirming both consumers completed without
  aborting under `set -euo pipefail`.

## Plan Deviations

- **Task 4.1** (freshness helper invocation) altered: `zotero-export-freshness.sh` (a Phase 1
  file) was extended during Phase 4 to compute and report its reference timestamp
  unconditionally — including in the `FRESHNESS_UNKNOWN` branch, which previously short-circuited
  before computing it — and to emit explicit `export_date=`/`sqlite_date=` tokens in its
  rationale. This was needed so `zotero-search.sh`'s banner could reliably extract real dates
  instead of parsing ad hoc prose.
- **Task 4.1** (capture-guard against `set -e`) altered: a live forced-helper-failure test
  revealed a second silent `pipefail` trap — the `grep -oP ... | head -1` date-extraction
  pipeline exits 1 (and aborts the script under `set -e`/`pipefail`) when no match is found.
  Both `EXPORT_DATE` and `SQLITE_DATE` assignments needed their own `|| VAR=""` guards, caught
  live rather than reasoned about in advance.
- **Task 3.2** (STALE bullet structure) altered: interactive and autonomous handling were split
  into two separate bullets (rather than one combined bullet) to match the plan's explicit
  structural placement — the interactive bullet sits after PRESENT/before MISSING_RUNNING, and
  the autonomous bullet sits alongside the two existing `orchestrator_mode == true` bullets.

No other deviations; all other plan tasks were followed as written.

## Verification

- **Build/lint**: `bash -n` passes on all three shell scripts (new helper, export-status,
  search).
- **Live stale case** (the reproduced symptom, export 2026-07-01 vs sqlite 2026-07-15):
  - `zotero-export-freshness.sh` -> `ZOTERO_EXPORT_STALE` with rationale naming both dates.
  - `zotero-export-status.sh` -> `ZOTERO_EXPORT_STALE` (direct refutation of the reproduced
    "already present ... no assisted-generation offer needed" symptom).
  - `zotero-search.sh` with hits -> exit 0, `[STALE EXPORT - export: 2026-07-01, sqlite:
    2026-07-15]` on stderr, JSON stdout still a clean array.
  - `zotero-search.sh` with no hits -> exit 3, same banner, JSON stdout still exactly `[]`.
  - `--format=pretty` -> banner appears on both stdout and stderr, before the table / before
    "No results found for:".
- **Fresh case** (temp fixture with a future `_generated` stamp): helper -> `FRESH`;
  export-status -> `PRESENT`; search with no hits -> exit 2, no banner (old contract preserved
  exactly for the confirmed-fresh case).
- **Absent/unknown cases**: helper -> `FRESHNESS_ABSENT` / `FRESHNESS_UNKNOWN` as expected;
  malformed `_generated` stamp falls back to mtime and says so on stderr.
- **Forced helper failure** (binary temporarily renamed): both `zotero-export-status.sh` and
  `zotero-search.sh` completed without aborting under `set -euo pipefail`, degrading to
  `ZOTERO_EXPORT_STALE` / exit 3 with an explicit rationale — never silently PRESENT/fresh.
- **Source-store rule**: `git status --short` shows zero modifications under `.claude/`; every
  edit this implementation made is confined to `agent-system/extensions/literature/**` and
  `specs/**`. (Three unrelated files — `.claude-extensions.json`,
  `lua/neotex/plugins/editor/which-key.lua`, `lua/neotex/plugins/tools/himalaya/utils/cli.lua` —
  were already dirty before this implementation began and were never touched by it.)
- **`check-extension-docs.sh`**: literature extension reports `PASS`. The 37 advisory
  "core script never deployed" items cover essentially every zotero-*/literature-* script, not
  just the newly added one — this is pre-existing whole-extension deploy drift (`.claude/` has
  not been regenerated recently), not a regression introduced by this change, and is expected
  per the plan (resolved by the user running the loader's "Sync all" regeneration, never by
  writing to `.claude/` directly).
- **No task-number citations**: grepped every diff hunk across all five edited/created files;
  none found.
- **Acceptance criterion enumeration**: of the four helper tokens, `FRESH` intentionally
  produces no visible signal (the trusted, nothing-is-wrong path); `STALE` and
  `FRESHNESS_UNKNOWN` both fold to `ZOTERO_EXPORT_STALE` in export-status and always surface an
  `AskUserQuestion` offer or `[zotero:auto]` notice in `/literature`, plus the `[STALE EXPORT
  ...]` banner and exit 3 in `zotero-search.sh` as defense-in-depth; `FRESHNESS_ABSENT` is
  unreachable from either consumer's call site (both only invoke the helper after confirming the
  export file exists), and any unrecognized token already falls back to the same
  not-confirmed-fresh treatment. No path produces a silent clean zero-result.

## Scope Boundary (stated plainly, not papered over)

`zotero-search.sh`'s Phase 4 banner and exit code 3 are **inert for today's two named primary
consumers** — `literature-discover.sh`'s `tier2_search()` and `skills/skill-cite/SKILL.md` —
both of which invoke this script with `2>/dev/null` (discarding the banner) and both of which
treat any non-zero exit code identically as non-fatal (collapsing exit 1/2/3 into the same
branch). Wiring those two consumers to distinguish this contract is a **recommended follow-up
task**, deliberately out of this task's file_scope. The substantive close of the "never a
silent clean zero-result" acceptance criterion for the common Mode A discovery path is the
Phase 3 pre-search regeneration offer in `commands/literature.md`, which runs *before*
`literature-discover.sh` is ever invoked — Phase 4's guard is defense-in-depth plus a
documented, stable forward contract for any caller (including a human or agent invoking
`zotero-search.sh` directly) that chooses to consume it.

## Notes

- All five phases completed and verified; plan status set to `[COMPLETED]`.
- `.claude/` was never regenerated as part of this task (that is the user's loader-driven step,
  triggered via `<leader>al` "Sync all"), per the source-store rule and this task's own
  non-goals.

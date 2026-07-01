# Implementation Summary: Task #798

**Completed**: 2026-07-01
**Duration**: ~1.5 hours

## Overview

Implemented two follow-up fixes to the task-797 assisted Zotero export subsystem. FIX 1 replaces
the hardcoded `${HOME}/Zotero/zotero.sqlite` default (duplicated in `zotero-export-status.sh` and
`zotero-generate-export.sh`) with a shared, prefs.js-driven resolver
(`zotero-resolve-sqlite-path.sh`) that auto-detects a custom Zotero Data Directory. FIX 2
restructures the NOT_RUNNING interactive branch in `literature.md` so "Open Zotero, then retry"
(bounded, max 3 attempts, live Path 1 API) is primary, the offline sqlite snapshot (Path 3) is an
explicit secondary, and the generator's orchestrator-mode `else` branch now fails loudly instead
of silently writing an empty `zotero-library.json`.

## What Changed

- `.claude/extensions/literature/scripts/zotero-resolve-sqlite-path.sh` — New canonical resolver
  script. Resolution order: (1) `$ZOTERO_SQLITE_PATH` override; (2) `<dataDir>/zotero.sqlite`
  parsed from the default profile's `prefs.js` when `extensions.zotero.useDataDir=true`; (3)
  `${HOME}/Zotero/zotero.sqlite` default. Iterates `~/.zotero/zotero` and `~/.mozilla/zotero` base
  dirs, parses `profiles.ini` for the `Default=1` profile, tolerates missing base dirs.
- `.claude/scripts/zotero-resolve-sqlite-path.sh` — New byte-identical flat copy.
- `.claude/extensions/literature/manifest.json` — Added `"zotero-resolve-sqlite-path.sh"` to
  `provides.scripts` (10 -> 11 zotero-*.sh entries).
- `.claude/extensions/literature/scripts/zotero-export-status.sh` + `.claude/scripts/` flat copy —
  Added `SCRIPT_DIR`, replaced the hardcoded sqlite default with a resolver call, updated doc
  comments.
- `.claude/extensions/literature/scripts/zotero-generate-export.sh` + `.claude/scripts/` flat copy
  — Replaced the hardcoded sqlite default with a resolver call; hardened the orchestrator-mode
  no-data-source `else` branch to print a visible `[zotero:auto] Error:` message and `exit 1`
  instead of writing `ITEMS='[]'`; updated doc comments and the exit-code table.
- `.claude/extensions/literature/commands/literature.md` (canonical; `.claude/commands/
  literature.md` is a symlink to it, no separate flat copy) — Split the combined
  `ZOTERO_EXPORT_MISSING_RUNNING`/`ZOTERO_EXPORT_MISSING_NOT_RUNNING` prompt into two distinct
  directive-specific option sets. NOT_RUNNING now offers "Open Zotero, then retry" (primary,
  bounded retry loop capped at 3 attempts), "Generate an offline snapshot" (secondary, Path 3),
  and "Skip this run". After the retry cap is exhausted, fresh enable-API guidance ("Zotero
  Settings -> Advanced -> API -> Allow other applications on this computer to communicate with
  Zotero") is surfaced in the `zotero-search.sh:143-169` numbered-heredoc style. The
  orchestrator-mode paragraph is split into distinct RUNNING and NOT_RUNNING descriptions per
  Decision D, both delegating the loud-failure guarantee to the generator's hardened branch.

## Decisions

- Shared-helper mechanism implemented as a new standalone script invoked via command
  substitution (`"$SCRIPT_DIR/zotero-resolve-sqlite-path.sh"`), matching the codebase's existing
  subprocess convention rather than introducing a sourced shared-lib pattern.
- prefs.js value extraction uses `grep -oP` (PCRE); the resolver never crashes if unsupported —
  it falls through to the `${HOME}/Zotero/zotero.sqlite` default.
- Retry loop implemented as bounded (max 3 attempts) interactive prose-pseudocode in
  `literature.md`, using one `AskUserQuestion` per attempt.
- Orchestrator-mode NOT_RUNNING: does not loop or prompt; calls the generator directly and relies
  entirely on the generator's own hardened `else` branch for the loud-failure guarantee, avoiding
  duplicated data-source pre-checks in the command layer.
- Reused the "Generate now" success/failure handling for the secondary Path 3 option via explicit
  cross-reference rather than literal text duplication, to avoid future drift in the
  prose-pseudocode spec file.

## Plan Deviations

- **Task 4.6** (`ZOTERO_EXPORT_UNAVAILABLE` branch) altered: one clause changed from the hardcoded
  `~/Zotero/zotero.sqlite does not exist` wording to `no zotero.sqlite was found at the resolved
  sqlite path`, since the old hardcoded wording would misrepresent FIX 1's resolver-driven
  behavior. The branch's structure and logic are otherwise unchanged.

## Verification

- Build: N/A (bash scripts + markdown spec, no build step)
- Tests: All Phase 5 verification commands passed —
  - `bash -n` on all three edited/created scripts, canonical and flat copies: 0 errors.
  - `diff` between each canonical/flat pair (resolver, status, generate): empty output
    (byte-identical) in all three cases.
  - Resolver auto-detection on this machine: resolved to
    `/home/benjamin/Documents/Zotero/zotero.sqlite` (matches the machine's actual
    `extensions.zotero.dataDir` prefs.js setting); `$ZOTERO_SQLITE_PATH` override verified
    working.
  - Generator end-to-end: reconstructed exactly 1819 Better-CSL-JSON entries via both
    auto-detection and explicit override, into a valid, non-empty JSON array.
  - Classifier: emitted exactly one directive token (`ZOTERO_EXPORT_MISSING_NOT_RUNNING`) on
    stdout (1 line), rationale on stderr, correctly reflecting the resolved (non-stale) database.
  - Orchestrator loud-failure: `ZOTERO_SQLITE_PATH=/nonexistent/... --orchestrator-mode true`
    exited 1, printed a visible `[zotero:auto] Error:` message to stderr, and wrote no output
    file at all.
  - `literature-discover.sh --task 798` stdout: confirmed `jq -e 'type == "array"'` succeeds
    (pure JSON array contract unchanged).
  - `manifest.json`: `jq -e '.provides.scripts | index("zotero-resolve-sqlite-path.sh")'`
    succeeds.
- Files verified: Yes (all listed above confirmed to exist and pass their respective checks).

## Notes

- `.claude/commands/literature.md` is a symlink to
  `.claude/extensions/literature/commands/literature.md`, not a separate flat copy — confirmed
  via `ls -la`, so no `cp -p`/`diff` sync step applies to this file (editing the canonical file
  is sufficient).
- Out of scope, confirmed untouched: Tier 3/Semantic Scholar integration, the three-tier pipeline
  architecture, `literature.md`'s whole-script `2>/dev/null` capture, and the orphaned zot-CLI
  subsystem.
- All 6 edited/created files (resolver canonical+flat, status canonical+flat, generate
  canonical+flat, manifest, literature.md) were committed incrementally at each phase boundary
  (4 commits total: phase 1, phase 2-3, phase 4, and this summary/final commit for phase 5).

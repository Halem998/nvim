# Implementation Summary: Task #797

**Completed**: 2026-07-01
**Duration**: ~4 phases, single session

## Overview

Replaced `literature-discover.sh` Tier 2's print-only "export it manually" hint (which never
reached the user through `/literature`'s `2>/dev/null` capture) with an assisted-generation
capability: a new generator that reconstructs a Better CSL JSON `zotero-library.json` from the
user's LOCAL Zotero via three fallback paths, a new stateless classifier that reports whether
generation is possible, and an `AskUserQuestion`-based offer wired into `/literature`'s discover
workflow through a separate, non-suppressed invocation.

## What Changed

- `.claude/extensions/literature/scripts/zotero-generate-export.sh` — New canonical generator.
  Path 1 (Zotero 7 local API, paginated), Path 2 (Better BibTeX JSON-RPC citekey enrichment),
  Path 3 (direct `zotero.sqlite` reconstruction, Zotero closed). Deterministic non-null
  citation-key synthesis with collision disambiguation. Writes a `.zotero-library.meta.json`
  staleness stamp. Atomic writes. Orchestrator-mode visible default (never silent).
- `.claude/scripts/zotero-generate-export.sh` — Byte-identical flat re-sync.
- `.claude/extensions/literature/scripts/zotero-export-status.sh` — New canonical classifier.
  Emits one of `ZOTERO_EXPORT_PRESENT` / `ZOTERO_EXPORT_MISSING_RUNNING` /
  `ZOTERO_EXPORT_MISSING_NOT_RUNNING` / `ZOTERO_EXPORT_UNAVAILABLE` to stdout, rationale to
  stderr, never calls `AskUserQuestion`.
- `.claude/scripts/zotero-export-status.sh` — Byte-identical flat re-sync.
- `.claude/extensions/literature/scripts/literature-discover.sh` — `tier2_search()`'s missing-
  export stderr hint now also points at the assisted-generation entry point. Pure JSON-array
  stdout contract and silent/non-fatal Tier 2 skip unchanged.
- `.claude/scripts/literature-discover.sh` — Byte-identical flat re-sync (picks up the hint edit).
- `.claude/extensions/literature/commands/literature.md` — New step "0." in Mode A discover
  workflow: separate `zotero-export-status.sh` invocation (stdout + stderr both captured, not
  `2>/dev/null`) before the main discover call, with branches for all four directive tokens plus
  an orchestrator-mode deterministic default.
- `.claude/extensions/literature/manifest.json` — Registered `zotero-generate-export.sh` and
  `zotero-export-status.sh` in `provides.scripts`.

## Decisions

- Path 1 fetches only top-level CSL-JSON fields (no attachment linking), per the plan's explicit
  scope — attachment/PDF paths are only reconstructed for Path 3, where the sqlite schema
  provides them directly.
- Citekey synthesis and disambiguation use a bash per-item loop with an associative-array
  counter (matching the existing codebase convention in `zotero-search.sh`'s
  `verify_pdf_paths()` and `literature-discover.sh`'s `append_result()`/`is_seen_*` pattern)
  rather than a single complex jq metaprogram, trading raw performance for maintainability
  consistency with the surrounding codebase — acceptable for a one-time snapshot generator.
- The classifier's `--orchestrator-mode` flag is accepted and logged into its stderr rationale
  for consistency with the `--lit` precedent, but does not change which of the four directive
  tokens is emitted; the interactive-vs-autonomous branching decision is left entirely to the
  Phase 3 `/literature` caller.
- Used a two-option "Generate now" / "Skip this run" `AskUserQuestion` prompt in Phase 3 instead
  of a three-option prompt, since there is no genuine third "create task" equivalent for a
  one-time local Zotero snapshot (see Plan Deviations).

## Plan Deviations

- **Task 3.4** altered: Used a two-option `AskUserQuestion` ("Generate now" / "Skip this run")
  instead of literally mirroring `literature-lit-flag-resolve.sh`'s three-option structure,
  because the `--lit` precedent's third option (create a curation task) has no equivalent here
  — there is no partial/deferred setup path for a one-time local snapshot. The two-option prompt
  preserves the same structural properties (recommended option first, explicit non-silent skip).
- **Testing & Validation** (shellcheck): `shellcheck` is not installed on this development
  machine (confirmed via `command -v shellcheck`). `bash -n` was used as the syntax-correctness
  gate for all scripts instead. Recommend running `shellcheck` in a CI environment where it is
  available as a follow-up.
- Live verification of Path 1 (Zotero 7 local API), Path 2 (Better BibTeX JSON-RPC), and the
  `ZOTERO_EXPORT_MISSING_RUNNING` classifier directive was not possible on this box — Zotero is
  not running and cannot be started in this environment. This matches the plan's own risk-table
  acknowledgment and the Phase 1 research report's confirmed finding. Path 3 (sqlite
  reconstruction) was verified both structurally (real, empty on-box `zotero.sqlite`, 0 rows,
  valid empty-array output) and functionally (a synthetic 2-item fixture sqlite exercising
  title/abstract/date/author/tags/PDF-attachment reconstruction and citekey collision
  disambiguation, with its output round-tripped successfully through `zotero-search.sh
  --format=json`).

## Verification

- Build: N/A (bash scripts + markdown; no compiled build step)
- Tests: `bash -n` clean on all 6 script instances (3 canonical + 3 flat); `jq empty` passes on
  generated `zotero-library.json`, the empty-DB case, the synthetic-fixture case, and
  `manifest.json`; byte-identical `diff` for all three canonical/flat pairs; manifest membership
  confirmed for both new scripts; classifier verified for 3 of 4 directive states (the 4th,
  `ZOTERO_EXPORT_MISSING_RUNNING`, requires a reachable local Zotero API not available on this
  box); `zotero-search.sh --format=json` successfully parsed generator output in both the empty
  and populated cases; orchestrator-mode default verified to emit a visible `[zotero:auto]`
  notice and exit 0 with an empty-but-valid array, versus exit 1 with manual-fallback text in
  the default (non-orchestrator) mode.
- Files verified: Yes

## Notes

- `shellcheck` linting of the two new scripts should be run in an environment where the tool is
  installed (e.g. CI) as a follow-up; this was not possible on the local development machine.
- Live functional verification of Path 1/Path 2 (Zotero running) requires a machine with Zotero
  actually running and, for Path 2, the Better BibTeX plugin installed; this was out of reach in
  this environment but the code paths were reviewed carefully against the research report's
  documented API/JSON-RPC contracts.
- The pre-existing latent inconsistency (literature-discover.sh's `tier2_search()` only checks
  `$LITERATURE_DIR/zotero-library.json`, not the full `resolve_library_path()` chain used by
  `zotero-search.sh` and the new generator/classifier) was intentionally left unfixed, per the
  plan's explicit non-goal — documented inline in the new classifier's header comment.

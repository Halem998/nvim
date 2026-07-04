# Implementation Plan: Assisted Zotero Export Generation (Tier 2)

- **Task**: 797 - Upgrade literature-discover.sh Tier 2 to assisted generation of zotero-library.json
- **Status**: [COMPLETED]
- **Effort**: 4.5 hours
- **Dependencies**: None (parent task 794 research complete)
- **Research Inputs**: specs/797_literature_zotero_export_assisted_setup/reports/01_zotero-export-assisted-generation.md
- **Artifacts**: plans/01_assisted-zotero-export-generation.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

When `$LITERATURE_DIR/zotero-library.json` is missing, `literature-discover.sh` Tier 2 currently
prints a task-794 static "export it manually" hint (which never even reaches the user because the
`/literature` caller swallows stderr with `2>/dev/null`). This plan replaces the print-only hint
with an *assisted generation* capability: a new generator script that reconstructs the Better CSL
JSON export from the user's LOCAL Zotero (three fallback paths), a new stateless classifier that
tells the calling command whether generation is possible, and wiring in `/literature` so the
command offers generation via `AskUserQuestion` before running the main discovery pass. The
generator, classifier, and the edited discover script are dual-copied (canonical extension copy +
byte-identical flat re-sync) and the two new scripts are registered in the extension manifest, per
the task-793 dual-copy model. Definition of done: a user with a Zotero library but no export can
run `/literature N`, be offered generation, agree, and get a valid `zotero-library.json` that
`tier2_search` consumes on the same run — with a visible, non-silent default in orchestrator mode.

### Research Integration

All phase decisions trace to `reports/01_zotero-export-assisted-generation.md`:
- Section 1: current `tier2_search()` at lines 346-456, missing-export guard 349-353, pure-JSON
  stdout contract (line 628), and the `2>/dev/null` caller in `literature.md` (125-139).
- Section 2: exact Better CSL JSON shape (`citation-key`, `title`, `author[]`,
  `issued.date-parts`, attachment fields) that the generator output must match.
- Section 3: `zotero-search.sh` manual-fallback wording (143-169) to mirror.
- Section 4: the `literature-lit-flag-resolve.sh` directive-token classifier contract to replicate.
- Section 5: the three generation paths (Zotero 7 local API, Better BibTeX JSON-RPC citekey
  enrichment, direct sqlite read), deterministic citekey synthesis, and the staleness stamp.
- Section 6: task-793 dual-copy sync + `manifest.json` `provides.scripts` registration.
- Section 7: `--orchestrator-mode true|false` flag defaulting to `false`, visible logged default.
- Section 8: do NOT touch the orphaned `zot`-CLI subsystem.

### Prior Plan Reference

No prior plan. This is the first plan for task 797. (Parent task 794 delivered the print-only hint
that this task supersedes; task 793 established the dual-copy sync model reused here.)

### Roadmap Alignment

No ROADMAP.md consulted (none provided in delegation context). This is a meta task; completion is
tracked via `completion_summary` in state.json.

## Goals & Non-Goals

**Goals**:
- New generator `zotero-generate-export.sh` producing valid Better CSL JSON from LOCAL Zotero via
  three preference-ordered paths, always synthesizing a non-null `citation-key`.
- Write a `_generated` staleness stamp and provide a clear re-pull affordance (snapshot semantics,
  NOT "Keep updated" equivalence).
- New stateless classifier emitting one directive token + stderr rationale; never calls
  AskUserQuestion; honors `--orchestrator-mode true|false` (default `false`).
- Update `tier2_search()` stderr hint to point at the assisted-generation entry point alongside
  the existing zotero-search.sh-matching manual instructions.
- Wire the interactive offer into the `/literature` discover workflow via a SEPARATE classifier
  invocation (not swallowed by the main pass's `2>/dev/null`), with orchestrator-mode default.
- Dual-copy both new scripts to `.claude/scripts/`, re-sync the edited discover copy, register the
  two new scripts in `manifest.json` `provides.scripts`.

**Non-Goals**:
- No Tier 3 / Semantic Scholar API changes; no 429/`.message` detection; no top-N query-term
  capping. Tier 3 stays web-search-only and untouched.
- No three-tier pipeline architecture changes.
- No broad refactor of the `literature.md` whole-script `2>/dev/null` stderr capture (separate
  follow-up); the interactive offer is routed through a dedicated classifier invocation instead.
- Do NOT touch the orphaned `zot`-CLI subsystem (`zotero-read.sh`, `zotero-write.sh`, etc.) or
  `specs/zotero-index.json`.
- Do NOT change the main discovery pass's silent/non-fatal Tier 2 skip or the pure-JSON-array
  stdout contract.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New interactive output leaks onto discover's JSON stdout, breaking the array contract | H | L | Classifier is a SEPARATE script/invocation writing directive to stdout + rationale to stderr; discover's stdout untouched; hint stays on stderr under `2>/dev/null` |
| Generator produces CSL JSON that `tier2_search`/`zotero-search.sh` cannot parse | H | M | Match the exact field shape from research Section 2; add a functional smoke test feeding generated output through `zotero-search.sh --format=json` |
| Zotero not running AND sqlite empty on the dev box, blocking functional test | M | H (confirmed empty on this box) | Path 3 sqlite path is structurally smoke-tested (schema queries return 0 rows cleanly); assert graceful empty-array output rather than data presence |
| Dual copies drift (canonical vs flat) | M | M | Phase 4 byte-identical `diff` gate for all three scripts; manifest membership check |
| Synthesized citekey collisions produce duplicate `doc_id` | M | L | Deterministic `lower(firstAuthorLast)+year+firstTitleWord`; append short disambiguator on collision within the generated set |
| Orchestrator/non-interactive run silently does nothing | M | L | `--orchestrator-mode true` takes a visible logged default and emits a `[zotero:auto]`-style notice; never a silent no-op |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. This plan is fully sequential because Phase 2
references the generator's CLI contract, Phase 3 wires both the generator and classifier, and Phase
4 re-syncs and verifies everything.

### Phase 1: Generator script `zotero-generate-export.sh` [COMPLETED]

**Goal**: Author the canonical generator that reconstructs Better CSL JSON from LOCAL Zotero with
three fallback paths, non-null citekey synthesis, and a staleness stamp.

**Tasks**:
- [x] Create `.claude/extensions/literature/scripts/zotero-generate-export.sh` (canonical copy
      ONLY in this phase; flat re-sync happens in Phase 4). Shebang `#!/usr/bin/env bash`,
      `set -euo pipefail`, `jq` availability guard, header comment block matching the style of
      `literature-create-setup-task.sh`. *(completed)*
- [x] Argument parsing: `--output <path>` (default via the `resolve_library_path()` order:
      `$ZOTERO_LIBRARY` -> `$LITERATURE_DIR/zotero-library.json` -> `~/Projects/Literature/zotero-library.json`),
      `--orchestrator-mode true|false` (default `false`), `--force`. Emit rationale to stderr.
      *(completed)*
- [x] Path 1 (preferred): probe `http://127.0.0.1:23119/api/users/0/items?format=csljson` with
      `curl` (short connect timeout); if reachable, paginate (`&limit=N&start=M`), filter out
      attachment/note items, collect CSL-JSON objects. *(completed; unverifiable live since no
      local Zotero API is reachable on this box, per research Section 5 confirmed finding)*
- [x] Path 2 (enrichment): if `http://localhost:23119/better-bibtex/json-rpc` is reachable, call
      `item.citationkey` with the item keys parsed from Path 1 `id` (`{userID}/{itemKey}`) to
      backfill real `citation-key`. *(completed; unverifiable live for the same reason as Path 1)*
- [x] Path 3 (fallback, Zotero closed): read `~/Zotero/zotero.sqlite` via `sqlite3 -readonly`,
      reconstruct CSL-JSON from `items`/`itemData`/`itemDataValues`/`fields`,
      `itemCreators`/`creators`, `itemAttachments` using the field/type IDs enumerated in research
      Section 5; filter out attachment(3)/note(28)/annotation(1) item types; map PDF attachment
      paths to `~/Zotero/storage/{attachmentItemKey}/{filename}`. *(completed; verified both on
      the real empty on-box zotero.sqlite (0 rows, valid empty array) and a synthetic 2-item
      fixture sqlite exercising title/abstract/date/author/tags/PDF-attachment reconstruction)*
- [x] Citekey synthesis: for any item lacking a real citation-key, deterministically synthesize
      `lower(firstAuthorLast)+year+firstTitleWord`; guarantee non-null; disambiguate collisions
      within the generated set. This is required — `tier2_search` uses `citation-key` as `doc_id`.
      *(completed; verified collision disambiguation on the synthetic fixture: two same-author
      same-year same-first-title-word items -> `kripke2020modal` / `kripke2020modal-2`)*
- [x] Emit the exact Better CSL JSON shape (research Section 2): array of objects with
      `citation-key`, `title`, `author[]` (`{family, given}`), `issued.date-parts`, and available
      attachment representation(s) (`attachments[].path` / `attachment` / `PDF`), plus `keyword`
      and `abstract` when present. *(completed)*
- [x] Staleness stamp: write `_generated` metadata (ISO timestamp + source path indicating which
      of the 3 paths produced it) to a sibling `.zotero-library.meta.json`; print a clear
      "this is a one-time snapshot, re-run this generator to refresh (NOT Keep-updated)" message.
      *(completed)*
- [x] Atomic write via temp file + `mv` (mirror `literature-create-setup-task.sh`); all diagnostics
      to stderr, machine-readable result (output path) to stdout. *(completed)*
- [x] Zotero-not-running / no-data handling: if all paths yield nothing, print the
      zotero-search.sh-matching manual-steps fallback text (research Section 3, lines 143-169) to
      stderr and exit non-zero; in `--orchestrator-mode true`, emit the visible logged default
      notice and still exit cleanly with an empty-but-valid array where feasible. *(completed and
      verified both branches: default mode exits 1 with manual-fallback text;
      `--orchestrator-mode true` exits 0 with `[zotero:auto]` notice + empty valid array)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/scripts/zotero-generate-export.sh` - new canonical generator.

**Verification**:
- `bash -n` and `shellcheck` clean.
- Path 3 structural smoke test on this box (Zotero closed, empty sqlite): runs without error and
  emits a valid (possibly empty) JSON array; `.zotero-library.meta.json` stamp written.
- `jq empty` on generated output succeeds.

---

### Phase 2: Classifier directive + Tier 2 hint update [COMPLETED]

**Goal**: Add a stateless classifier that reports whether assisted generation is possible, and
update the `tier2_search()` stderr hint to point at the generator — without touching discover's
JSON stdout contract.

**Tasks**:
- [x] Create `.claude/extensions/literature/scripts/zotero-export-status.sh` (canonical copy ONLY
      this phase) modeled on `literature-lit-flag-resolve.sh`: NEVER calls AskUserQuestion; prints
      exactly one directive token on stdout + rationale on stderr. *(completed)*
- [x] Directive tokens (research Section 4): `ZOTERO_EXPORT_PRESENT` (file already at resolved
      path), `ZOTERO_EXPORT_MISSING_RUNNING` (missing, Zotero local API reachable — Path 1/2
      viable), `ZOTERO_EXPORT_MISSING_NOT_RUNNING` (missing, Zotero not reachable but
      `~/Zotero/zotero.sqlite` present — Path 3 viable), `ZOTERO_EXPORT_UNAVAILABLE` (missing and
      no local Zotero data source found). *(completed; verified 3 of 4 states directly —
      PRESENT, MISSING_NOT_RUNNING, UNAVAILABLE — MISSING_RUNNING is unverifiable live since no
      local Zotero API is reachable on this box, consistent with Phase 1's finding)*
- [x] Accept `--orchestrator-mode true|false` (default `false`) and `--output <path>` mirroring
      the generator; emit visible rationale to stderr for every branch (never silent).
      *(completed)*
- [x] Resolve the target path via the same `resolve_library_path()` order as zotero-search.sh so
      the classifier and generator agree; note (do not fix) the latent inconsistency that discover
      only checks `$LITERATURE_DIR/zotero-library.json`. *(completed; documented inline in the
      classifier's header comment rather than fixed, per the plan's explicit non-goal)*
- [x] Update `tier2_search()` missing-export hint in
      `.claude/extensions/literature/scripts/literature-discover.sh` (lines ~349-353, canonical
      copy ONLY this phase): keep the silent/non-fatal `return 0` skip and the existing
      zotero-search.sh-matching manual instructions, and ADD a line pointing at the assisted
      generator entry point (`zotero-generate-export.sh`) and the `/literature` assisted offer.
      *(completed)*
- [x] Do NOT alter discover's tier ordering, `|| true` non-fatal execution, or the final pure
      JSON-array stdout (line 628). *(completed; verified `literature-discover.sh "modal logic"`
      still emits a pure JSON array on stdout with the new hint appearing only on stderr)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/literature/scripts/zotero-export-status.sh` - new canonical classifier.
- `.claude/extensions/literature/scripts/literature-discover.sh` - canonical copy, hint text only.

**Verification**:
- `bash -n` + `shellcheck` clean on both files.
- Classifier prints exactly one token to stdout for each of the four states (test by stubbing the
  resolved path presence/absence); rationale appears on stderr only.
- `literature-discover.sh <query>` still emits a valid JSON array (`jq empty` passes); the new hint
  appears only on stderr.

---

### Phase 3: Wire assisted offer into `/literature` discover workflow [COMPLETED]

**Goal**: Add the interactive assisted-generation offer to the `/literature` discover flow via a
separate classifier invocation before the main discover call, with an orchestrator-mode default.

**Tasks**:
- [x] In `.claude/extensions/literature/commands/literature.md` Mode A (discover, step_2 around
      lines 120-139), BEFORE the existing `literature-discover.sh ... 2>/dev/null` call, add a
      separate invocation of `zotero-export-status.sh` that captures BOTH stdout (directive) and
      stderr (rationale) — explicitly NOT under `2>/dev/null` — so the offer is not swallowed.
      *(completed: new step "0." in step_2)*
- [x] Branch on the directive:
      - `ZOTERO_EXPORT_PRESENT`: no offer; proceed to main discover as today.
      - `ZOTERO_EXPORT_MISSING_RUNNING` / `ZOTERO_EXPORT_MISSING_NOT_RUNNING`: issue
        `AskUserQuestion` offering to generate now (state which path will be used and the
        snapshot-not-Keep-updated caveat) vs skip; on agreement run `zotero-generate-export.sh`
        then proceed to main discover (Tier 2 now populated).
      - `ZOTERO_EXPORT_MISSING_NOT_RUNNING`: the offer text also notes the user may open Zotero for
        the richer API path or accept the sqlite snapshot.
      - `ZOTERO_EXPORT_UNAVAILABLE`: no offer; surface the zotero-search.sh-matching manual steps.
      *(completed; all four branches documented)*
- [x] Orchestrator/non-interactive default: document that when the command runs without a human
      (orchestrator context), it passes `--orchestrator-mode true` to the classifier/generator,
      takes the visible logged default (attempt live generation via the viable path, or emit the
      `[zotero:auto]` notice explaining the skip), and NEVER performs a silent no-op. *(completed)*
- [x] Add explicit wording mirroring the `literature-lit-flag-resolve.sh` three-option precedent
      style so the offer is consistent with existing `--lit` prompts. *(completed; two-option
      "Generate now" / "Skip this run" prompt used instead of three, since there is no
      third "create task" equivalent for this offer — Generate-now/Skip mirrors the same
      recommended-default-first, explicit-non-silent-skip structure as the `--lit` precedent)*
- [x] Do NOT modify the existing `2>/dev/null` main discover call itself (out of scope); only add
      the preceding classifier invocation and branch. *(completed; verified via grep that the
      three existing `2>/dev/null` lines in the main discover call are unchanged)*

**Timing**: 1 hour

**Depends on**: 1, 2

**Files to modify**:
- `.claude/extensions/literature/commands/literature.md` - discover-mode step_2 wiring.

**Verification**:
- Markdown renders; the classifier invocation shown captures stderr (no `2>/dev/null`).
- Documented branches cover all four directive tokens plus the orchestrator-mode default.
- No change to the main discover call or its JSON-array handling.

---

### Phase 4: Dual-copy re-sync, manifest registration, verification [COMPLETED]

**Goal**: Byte-identically re-sync the new scripts and the edited discover copy to
`.claude/scripts/`, register the two new scripts in `manifest.json`, and run the full verification
gate.

**Tasks**:
- [x] Re-sync `zotero-generate-export.sh` (Phase 1) canonical -> `.claude/scripts/zotero-generate-export.sh`
      (byte-identical). *(completed; `diff` empty)*
- [x] Re-sync `zotero-export-status.sh` (Phase 2) canonical -> `.claude/scripts/zotero-export-status.sh`
      (byte-identical). *(completed; `diff` empty)*
- [x] Re-sync the edited `literature-discover.sh` canonical -> `.claude/scripts/literature-discover.sh`
      (byte-identical; the flat copy must pick up the Phase 2 hint edit). *(completed; `diff`
      empty, verified the flat copy's stderr output includes the new assisted-generation hint)*
- [x] Add `zotero-generate-export.sh` and `zotero-export-status.sh` to
      `.claude/extensions/literature/manifest.json` `provides.scripts` array. *(completed)*
- [x] Preserve executable bits on both new script copies. *(completed; `-rwxr-xr-x` on both flat
      copies)*

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3

**Files to modify**:
- `.claude/scripts/zotero-generate-export.sh` - new flat re-sync.
- `.claude/scripts/zotero-export-status.sh` - new flat re-sync.
- `.claude/scripts/literature-discover.sh` - re-sync of Phase 2 hint edit.
- `.claude/extensions/literature/manifest.json` - `provides.scripts` additions.

**Verification**:
- `diff` empty for all three canonical/flat pairs (byte-identical).
- `jq -r '.provides.scripts[]' manifest.json` contains both new script names (membership check).
- `bash -n` on all flat copies; `shellcheck` clean on both new scripts.
- `jq empty` on `manifest.json`.
- End-to-end structural smoke test: run `zotero-export-status.sh` (expect
  `ZOTERO_EXPORT_MISSING_NOT_RUNNING` on this box), run `zotero-generate-export.sh` (Path 3
  sqlite), confirm a valid JSON array output + `.zotero-library.meta.json` stamp, then feed the
  output through `zotero-search.sh --format=json` to confirm `tier2_search` can consume it.

## Testing & Validation

- [x] `bash -n` passes on `zotero-generate-export.sh`, `zotero-export-status.sh`, and both
      `literature-discover.sh` copies (canonical + flat). *(verified: all four pass)*
- [x] `shellcheck` clean on the two new scripts. *(DEVIATION: `shellcheck` is not installed on
      this machine — confirmed via `command -v shellcheck`. `bash -n` was used as the syntax
      gate for all scripts instead; no shellcheck-specific lint was possible in this
      environment. Recommend running `shellcheck` in a follow-up task/CI environment where it
      is available.)*
- [x] Generated `zotero-library.json` passes `jq empty` and matches the Better CSL JSON field shape
      (research Section 2); `citation-key` is non-null for every entry. *(verified on a
      synthetic 2-item fixture: both entries got non-null, disambiguated citation-keys
      `kripke2020modal` / `kripke2020modal-2`; also verified the real on-box empty-sqlite case
      produces a valid empty array)*
- [x] `zotero-search.sh --format=json` parses the generated output without error (consumer smoke).
      *(verified: synthetic-fixture output returned 2 scored results with correct
      citation_key/title/authors/year; empty on-box output returned `[]` with documented exit
      code 2 "no results")*
- [x] `literature-discover.sh <query>` still emits a pure JSON array (`jq empty`); new hint on
      stderr only. *(verified on both canonical and flat copies)*
- [x] Classifier emits exactly one directive token on stdout for each of the four states.
      *(verified 3 of 4 live: ZOTERO_EXPORT_PRESENT, ZOTERO_EXPORT_MISSING_NOT_RUNNING,
      ZOTERO_EXPORT_UNAVAILABLE. ZOTERO_EXPORT_MISSING_RUNNING is unverifiable on this box since
      no local Zotero API is reachable here — consistent with the Phase 1 research finding and
      the plan's own risk-table acknowledgment)*
- [x] Byte-identical `diff` for all three canonical/flat script pairs. *(verified empty for all
      three: zotero-generate-export.sh, zotero-export-status.sh, literature-discover.sh)*
- [x] `manifest.json` `provides.scripts` includes both new scripts; `jq empty` on manifest passes.
      *(verified both present via `jq -r '.provides.scripts[]'`; manifest is valid JSON)*
- [x] Orchestrator-mode path emits a visible logged default (no silent no-op) — verified by
      running the classifier/generator with `--orchestrator-mode true` and observing stderr notice.
      *(verified: generator with `--orchestrator-mode true` and no local Zotero data source
      emits a `[zotero:auto]`-prefixed notice and writes an empty-but-valid array, exit 0;
      default mode instead exits 1 with the manual-fallback text)*

## Artifacts & Outputs

- `.claude/extensions/literature/scripts/zotero-generate-export.sh` (canonical generator)
- `.claude/scripts/zotero-generate-export.sh` (flat re-sync)
- `.claude/extensions/literature/scripts/zotero-export-status.sh` (canonical classifier)
- `.claude/scripts/zotero-export-status.sh` (flat re-sync)
- `.claude/extensions/literature/scripts/literature-discover.sh` (edited Tier 2 hint, canonical)
- `.claude/scripts/literature-discover.sh` (re-synced flat copy)
- `.claude/extensions/literature/commands/literature.md` (assisted-offer wiring)
- `.claude/extensions/literature/manifest.json` (`provides.scripts` additions)
- `specs/797_literature_zotero_export_assisted_setup/summaries/01_*-summary.md` (on implementation)
- Runtime outputs (user machines): `$LITERATURE_DIR/zotero-library.json` + sibling
  `.zotero-library.meta.json` staleness stamp

## Rollback/Contingency

- All edits are additive except the `tier2_search()` hint text; revert by `git checkout` on the
  four touched tracked files (`literature-discover.sh` x2, `literature.md`, `manifest.json`) and
  `git rm` the four new script copies.
- If the generator proves unable to produce consumable CSL JSON, keep Phases 2-3 wiring behind the
  classifier but have the offer fall back to the zotero-search.sh manual-steps text (no data loss;
  reverts to task-794 behavior surfaced through a working channel).
- Dual-copy drift is self-correcting: re-run the Phase 4 `diff` gate and re-sync canonical -> flat.

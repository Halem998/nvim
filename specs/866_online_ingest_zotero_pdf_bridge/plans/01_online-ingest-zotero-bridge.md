# Implementation Plan: Online-Discovery -> Zotero+PDF -> Ingest Bridge

- **Task**: 866 - Build the online-discovery -> Zotero+PDF -> ingest bridge for the literature extension
- **Status**: [NOT STARTED]
- **Effort**: 11 hours
- **Dependencies**: None (foundation task; tasks 867 and 868 build on this)
- **Research Inputs**: specs/866_online_ingest_zotero_pdf_bridge/reports/01_online-ingest-zotero-bridge.md
- **Artifacts**: plans/01_online-ingest-zotero-bridge.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Wire `literature-discover.sh` Tier-3 online results into the existing convert -> chunk ->
build-index pipeline by adding a new create-item-with-PDF capability to Zotero and a new
entry-point script `literature-ingest-online.sh`. The new script classifies a single discovery
record via directive tokens (mirroring `zotero-export-status.sh`'s honest, non-silent UX),
downloads and magic-byte-verifies PDFs before any Zotero write, creates a Zotero item via a new
`zotero-write.sh item-add` operation (wrapping the already-available `zot add --pdf`), delegates
to the unmodified `literature-ingest.sh` for convert/chunk/index, then patches the resulting
`index.json` entry with real metadata and registers the doc in the per-repo sub-index. Paywalled
and no-PDF sources are surfaced honestly with no fabricated downloads. Definition of done: a
user-selected open-access/arXiv discovery record can be ingested end-to-end (Zotero item + PDF +
corpus chunks + rich index metadata + sub-index entry); paywalled/no-PDF/in-Zotero-no-PDF records
are handled correctly with honest surfacing; docs stay in sync.

### Research Integration

Key findings integrated from `reports/01_online-ingest-zotero-bridge.md`:

- The missing create-item capability is a **new `zotero-write.sh` operation** wrapping the
  existing `zot add --pdf`, NOT a raw Web API POST or the read-only local API at 127.0.0.1:23119.
- `literature-discover.sh` Tier-3 emits `open_access` (with an `arxiv_id` field for arXiv hits),
  `paywall`, and (from Tier 2) `in_zotero_no_pdf`. There is **no distinct `"arxiv"` status**; the
  classifier keys off `(status, arxiv_id present, pdf_url present)`.
- `in_zotero_no_pdf` is an **attach-to-existing** case (existing `attach-file`), not create-item.
- `literature-ingest.sh` writes only placeholder `title`/`authors`/`year` to `index.json`, so the
  online path must do its own post-ingest `jq` metadata patch.
- Downloads must be magic-byte (`%PDF`) verified before any Zotero write; the classification/
  directive-token pattern from `zotero-export-status.sh` is the honest-surfacing precedent.
- `zot add`'s exact `data.*` JSON field names are an empirical unknown to confirm early.

### Prior Plan Reference

No prior plan. This is the first plan for task 866.

### Roadmap Alignment

No `roadmap_path` was provided to this planning run and no ROADMAP.md was consulted. This task is
the declared foundation for follow-on tasks 867 and 868; the plan therefore treats the
`literature-ingest-online.sh` entry-point interface (a single discovery-record JSON in, directive
tokens + exit codes out) as a stable, documented contract those tasks depend on.

## Goals & Non-Goals

**Goals**:
- Add a `zotero-write.sh item-add` operation that creates a Zotero item with a PDF attachment via
  `zot add --pdf`, following the existing `note-add`/`tag-add`/`attach-file` pattern.
- Create `literature-ingest-online.sh` accepting a single discovery record and driving the full
  online -> Zotero+PDF -> ingest bridge end-to-end.
- Classify records with directive tokens (honest, non-silent; no fabricated downloads).
- Magic-byte-verify every downloaded PDF before any Zotero write.
- Reuse the unmodified `literature-ingest.sh` for convert/chunk/index.
- Patch the resulting `index.json` entry with real metadata; register in `specs/literature-index.json`.
- Handle the `in_zotero_no_pdf` attach-to-existing sub-path with existing `attach-file`.
- Keep `EXTENSION.md`, `commands/literature.md`, and the context docs in sync.

**Non-Goals**:
- Modifying `literature-ingest.sh`'s core loop, `literature-convert.sh`, `literature-chunk.sh`, or
  `literature-build-index.sh` (reuse-only; zero drift risk).
- Building raw Zotero Web API POST calls or any local-API write integration.
- Retrofitting the placeholder-metadata gap for the other (non-online) ingest paths.
- Implementing tasks 867/868 functionality (this task only establishes the clean interface).
- Editing the auto-generated `.claude/CLAUDE.md` (merge-source docs are the edit surface).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `zot add`'s exact `data.*` field names (item key, attachment key, storage path) unconfirmed from public docs | H | H | Phase 1 empirically verifies via `--dry-run` then a live low-stakes `zot add --pdf` call (`jq '.data'` on the raw envelope) before any downstream logic depends on field paths; record confirmed names in the pattern doc. |
| `pdf_url` resolves to HTML landing/cookie-wall page (200 status, not a PDF) | H | M | Mandatory `%PDF` magic-byte check after download; mismatch -> `ONLINE_INGEST_DOWNLOAD_FAILED`, never fall through to item creation. |
| Duplicate Zotero items for a paper already in the library (stale snapshot) | M | M | Optional pre-create title-similarity check against `index.json` using the existing `.zotero-title-sim.py` helper; sized as a recommendation, not a hard blocker. |
| `zot add --pdf` storage-copy path not immediately readable for re-pointing | M | M | Phase 4 verifies the storage path empirically (`zot read`/sqlite check); if unreliable, fall back to the staging download path and flag as follow-up (never silent success). |
| `literature-ingest.sh` re-ingest `rm -rf` on doc_id collision | M | L | Derive `doc_id` the same way (from resolved filename); no new risk introduced beyond existing behavior; out of scope to change. |
| `in_zotero_no_pdf` citation_key not the literal 8-char Zotero API key | M | M | Resolve the real key via `zotero-resolve-pdf.sh`-style title/author search before `attach-file`; surface honestly and stop if unresolvable. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 1, 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |
| 6 | 7 | 5, 6 |

Phases within the same wave can execute in parallel.

### Phase 1: Add `item-add` Operation to zotero-write.sh [COMPLETED]

**Goal**: Provide a create-item-with-PDF capability by adding one new `case` arm to
`zotero-write.sh`, wrapping `zot add --pdf`, and empirically confirm the `zot add` JSON envelope
field names.

**Tasks**:
- [x] Add an `item-add` operation to `zotero-write.sh` following the existing `attach-file`
      pattern: `zotero-write.sh item-add --pdf <path> [--doi <doi>] [--idempotency-key <key>] [--dry-run]`. *(completed)*
- [x] Wrap `zot add --pdf "$FILEPATH"` (single atomic create+attach); support a `zot add --doi`
      fallback (item only, no attachment) that still surfaces "no PDF attached" honestly. *(completed)*
- [x] Reuse the existing top-of-file dependency checks (`zot` on `$PATH`, `$ZOTERO_API_KEY` set,
      `$ZOT_DATA_DIR` resolution) and exit-code contract (0 success/dry-run, 1 API/file/key error,
      2 not-configured); pass through `--dry-run` (echo the would-be `zot` invocation) and
      `--idempotency-key`. *(completed)*
- [x] Empirically verify `zot add --pdf` output: run `--dry-run`, then one live low-stakes call;
      capture `jq '.data'` on the raw envelope to confirm the item key, attachment key, and
      storage-path field names. Record the confirmed field paths for Phases 4-5 and Phase 7 docs.
      *(deviation: altered — no `zot` binary or configured Zotero account is available in this
      sandboxed dev environment, so a genuine live call is infeasible. Verified command
      construction, argument passthrough, dry-run echo, and downstream jq field-path extraction
      instead via a stub `zot` executable that returns a synthetic envelope
      `{"ok":true,"data":{"key":...,"attachment":{"key":...,"filename":...}}}`; confirmed
      note-add/tag-add/tag-remove/attach-file/unknown-op regressions all unchanged. The REAL
      `zot add --pdf` field names remain an empirical unknown — recorded as a required follow-up
      in `context/project/literature/patterns/zotero-item-creation.md`, and
      `literature-ingest-online.sh`'s envelope parsing (Phase 4) is written defensively across
      several plausible field-name candidates rather than assuming one shape.)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/literature/scripts/zotero-write.sh` - add `item-add` case arm + usage text.

**Verification**:
- `zotero-write.sh item-add --pdf <sample.pdf> --dry-run` echoes the correct `zot add --pdf` command.
- A live `item-add` call returns exit 0 and a parseable envelope; confirmed `data.*` field names recorded.
- Existing operations (`note-add`, `tag-add`, `attach-file`) unchanged (regression check).

---

### Phase 2: Scaffold literature-ingest-online.sh + Directive-Token Classification [NOT STARTED]

**Goal**: Create the new entry point with input parsing and the honest directive-token classifier,
mirroring `zotero-export-status.sh` (exactly one token to stdout, rationale to stderr, no silent
no-op). No downloads or writes yet.

**Tasks**:
- [ ] Create `literature-ingest-online.sh` accepting a single discovery-record JSON via stdin or
      `--record '<json>'`, plus `--dry-run` and `--idempotency-key` flags mirroring `zotero-write.sh`.
- [ ] Implement classification keying off `(status, arxiv_id present, pdf_url present)`:
      - `status == "in_zotero_no_pdf"` -> `ONLINE_INGEST_EXISTING_NO_PDF`
      - `status == "open_access"` with non-empty `pdf_url` (arXiv or not) -> `ONLINE_INGEST_RESOLVABLE`
      - `status == "paywall"`, or `open_access` with no usable `pdf_url` -> `ONLINE_INGEST_NO_PDF`
- [ ] Treat "arxiv" strictly as a derived condition (`status=="open_access" && arxiv_id != null`),
      never a literal `"arxiv"` status.
- [ ] Print exactly one directive token to stdout; write the rationale to stderr; define exit
      codes (resolvable=0 proceed, no-pdf non-zero honest-stop) consistent with the export-status precedent.
- [ ] Document the entry-point interface (input schema, directive tokens, exit codes) in a header
      comment block, since tasks 867/868 depend on it as a stable contract.

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` (new).

**Verification**:
- Feeding representative records for each status prints the correct single directive token.
- `ONLINE_INGEST_NO_PDF` exits non-zero and writes an honest stderr rationale; no download attempted.
- Header block documents the input record schema and every directive token.

---

### Phase 3: PDF Download + Magic-Byte Verification + Duplicate Check [NOT STARTED]

**Goal**: For `ONLINE_INGEST_RESOLVABLE`, download the PDF to a stable staging path and verify it
is genuinely a PDF before any Zotero write; optionally guard against duplicate ingestion.

**Tasks**:
- [ ] Download via `curl -sL --fail --max-time 30 -o <staging_path> "$pdf_url"`.
- [ ] Verify the first bytes are `%PDF` (`head -c4`); on non-2xx/curl failure or magic-byte
      mismatch, emit `ONLINE_INGEST_DOWNLOAD_FAILED` and stop (never fall through to item creation).
- [ ] Choose a stable staging path (not an ephemeral temp that is cleaned before ingest) and
      derive `doc_id` consistently with `literature-ingest.sh` (from the resolved filename).
- [ ] Add an optional pre-create title-similarity check against the global `index.json` using the
      existing `.zotero-title-sim.py` helper (`zotero-resolve-pdf.sh` pattern) to avoid double-ingest.

**Timing**: 1.5 hours

**Depends on**: 2

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` - download + verify block.

**Verification**:
- A valid open-access `pdf_url` downloads and passes the `%PDF` check.
- An HTML landing-page URL (200 status, non-PDF body) yields `ONLINE_INGEST_DOWNLOAD_FAILED`, no write.
- A title already present in `index.json` is flagged by the duplicate check.

---

### Phase 4: Zotero Create-Item + Storage Re-Point + Delegate to literature-ingest.sh [NOT STARTED]

**Goal**: For the create-item path (open-access/arXiv), create the Zotero item + attachment, resolve
the durable Zotero storage copy, and run the unmodified ingest pipeline against that copy.

**Tasks**:
- [ ] Call `zotero-write.sh item-add --pdf <staging_path> [--doi <doi>] [--idempotency-key online-ingest-<doc_id>] [--dry-run]`.
- [ ] Resolve the Zotero-managed `storage/<attachmentKey>/<filename>` path from the confirmed
      envelope field (Phase 1) and/or `zotero-resolve-sqlite-path.sh`; never hardcode the storage root.
- [ ] Verify the storage path is readable; if not, fall back to the staging download path and flag
      as a follow-up (honest, never a silent success claim).
- [ ] Invoke `literature-ingest.sh "$zotero_storage_pdf_path" --no-local` (let the caller decide
      `--local`/interactive), reusing 100% of convert/chunk/quality-gate/index-rebuild logic.
- [ ] Capture the ingested `doc_id` reported by `literature-ingest.sh` for the Phase 5 patch.

**Timing**: 2 hours

**Depends on**: 1, 3

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` - create + re-point + delegate block.

**Verification**:
- A resolvable record creates a Zotero item with the PDF attached and the storage path resolves.
- `literature-ingest.sh` runs unmodified and reports a `doc_id`; corpus chunks are produced.
- `--dry-run` prints the planned `item-add` and `literature-ingest.sh` invocations without side effects.

---

### Phase 5: Post-Ingest Metadata Patch + Sub-Index Registration [NOT STARTED]

**Goal**: Close the placeholder-metadata gap for online-ingested docs and register them in the
per-repo sub-index.

**Tasks**:
- [ ] After `literature-ingest.sh` exits 0, `jq`-patch the global `index.json` entry for the
      ingested `doc_id`, merging real `title`, `authors`, `year`, `doi`, `arxiv_id`, `zotero_key`,
      `zotero_path` from the discovery record + Zotero envelope (not the `DOC_ID` placeholder).
- [ ] Scope the patch as new logic in `literature-ingest-online.sh` only (do NOT modify
      `literature-ingest.sh`'s core loop).
- [ ] Upsert an entry into `specs/literature-index.json` (`doc_id`, `relevance`, `added`,
      `source: "discover"`) using the same jq-upsert sketch already in `commands/literature.md` step_2.
- [ ] Ensure idempotency: re-running for the same `doc_id` updates rather than duplicates entries.

**Timing**: 1.5 hours

**Depends on**: 4

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` - patch + sub-index upsert block.

**Verification**:
- The global `index.json` entry shows the real title/authors/year and the Zotero key/path (no placeholder).
- `specs/literature-index.json` gains a `source: "discover"` entry for the ingested doc.
- A repeat run updates in place (no duplicate index or sub-index rows).

---

### Phase 6: in_zotero_no_pdf Attach-to-Existing Sub-Path [NOT STARTED]

**Goal**: Handle `ONLINE_INGEST_EXISTING_NO_PDF` as an attach-to-existing-item operation using the
existing `attach-file` capability, then ingest and register like the create path.

**Tasks**:
- [ ] Resolve the Tier-2 citation_key to the real Zotero item key via `zotero-resolve-pdf.sh`-style
      title/author search (do not assume the citation_key is the literal 8-char API key).
- [ ] If a PDF URL is discoverable, reuse the Phase 3 download + `%PDF` verification; if none is
      discoverable, surface honestly and stop (never invent one).
- [ ] Call `zotero-write.sh attach-file <key> <verified_pdf>` (existing operation; no create-item).
- [ ] Reuse the Phase 4/5 machinery to run `literature-ingest.sh`, patch `index.json`, and register
      in the sub-index for the now-attached document.

**Timing**: 1.5 hours

**Depends on**: 5

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` - existing-item attach branch.

**Verification**:
- An `in_zotero_no_pdf` record resolves to the correct existing Zotero key and attaches the PDF.
- An unresolvable/no-PDF case surfaces honestly and stops with a non-zero exit; no fabricated attach.
- After attach, the doc is ingested, metadata-patched, and sub-index-registered.

---

### Phase 7: Command Wiring + Documentation Sync [NOT STARTED]

**Goal**: Wire the new bridge into the `/literature` Mode A flow and keep the merge-source docs and
context docs in sync.

**Tasks**:
- [ ] Extend `commands/literature.md` Mode A (SOURCES.md + sub-index step) with a new branch: for
      user-selected `open_access`/arXiv-flavored/`paywall`/`in_zotero_no_pdf` entries, offer (via
      `AskUserQuestion`, consistent with the existing directive-branch pattern) "Ingest into
      Literature now" vs. "Just record in SOURCES.md" (today's default/fallback). Only opt-in
      entries invoke `literature-ingest-online.sh`.
- [ ] Preserve honest surfacing: `ONLINE_INGEST_NO_PDF`/`DOWNLOAD_FAILED` fall back to today's
      `[PAYWALL]`/`[PENDING]` SOURCES.md row behavior; never a silent success.
- [ ] Add an `EXTENSION.md` script-table row for `literature-ingest-online.sh` and update the
      `zotero-write.sh` row description to mention the new `item-add` create-with-PDF operation.
- [ ] Create `context/project/literature/patterns/zotero-item-creation.md` documenting the
      empirically confirmed `zot add --pdf` envelope fields (Phase 1), the magic-byte download gate,
      and the storage re-pointing step, so tasks 867/868 do not re-derive this research.
- [ ] Do NOT edit the auto-generated `.claude/CLAUDE.md` (edit merge-source docs only).

**Timing**: 2 hours

**Depends on**: 5, 6

**Files to modify**:
- `agent-system/extensions/literature/commands/literature.md` - Mode A ingest branch.
- `agent-system/extensions/literature/EXTENSION.md` - script table rows.
- `agent-system/extensions/literature/context/project/literature/patterns/zotero-item-creation.md` (new).

**Verification**:
- `commands/literature.md` Mode A offers the ingest option and falls back honestly for no-PDF cases.
- `EXTENSION.md` lists `literature-ingest-online.sh` and the updated `zotero-write.sh` description.
- The new pattern doc records confirmed envelope fields, the magic-byte gate, and re-pointing.
- `check-extension-docs.sh` (doc-lint) passes for the literature extension.

---

## Testing & Validation

- [ ] `zotero-write.sh item-add --dry-run` and one live call succeed; confirmed envelope fields recorded.
- [ ] Classification prints the correct single directive token for each of `open_access` (with and
      without `arxiv_id`), `paywall`, and `in_zotero_no_pdf`.
- [ ] Magic-byte gate rejects an HTML landing page (`ONLINE_INGEST_DOWNLOAD_FAILED`), no Zotero write.
- [ ] End-to-end open-access ingest: Zotero item + PDF attached, corpus chunks produced, `index.json`
      entry has real metadata + Zotero key/path, `specs/literature-index.json` has a `source: "discover"` entry.
- [ ] `in_zotero_no_pdf` path attaches to the existing item and ingests; unresolvable case stops honestly.
- [ ] `commands/literature.md` Mode A offers ingest vs. SOURCES.md-only and falls back honestly.
- [ ] `literature-ingest.sh`, `literature-convert.sh`, `literature-chunk.sh`,
      `literature-build-index.sh` remain unmodified (diff check).
- [ ] `bash .claude/scripts/check-extension-docs.sh` passes.

## Artifacts & Outputs

- `agent-system/extensions/literature/scripts/zotero-write.sh` (new `item-add` operation)
- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` (new entry point)
- `agent-system/extensions/literature/commands/literature.md` (Mode A ingest branch)
- `agent-system/extensions/literature/EXTENSION.md` (script table updates)
- `agent-system/extensions/literature/context/project/literature/patterns/zotero-item-creation.md` (new)
- `specs/866_online_ingest_zotero_pdf_bridge/plans/01_online-ingest-zotero-bridge.md` (this file)
- `specs/866_online_ingest_zotero_pdf_bridge/summaries/01_online-ingest-zotero-bridge-summary.md` (on completion)

## Rollback/Contingency

- All new logic is isolated in a new script (`literature-ingest-online.sh`) plus one additive
  `case` arm in `zotero-write.sh` and additive doc/command branches; core pipeline scripts are
  untouched, so reverting is low-risk.
- To revert: remove `literature-ingest-online.sh`, drop the `item-add` case arm and its usage line
  from `zotero-write.sh`, revert the `commands/literature.md` Mode A branch and `EXTENSION.md` rows,
  and delete the new pattern doc. No migrations or state changes to undo.
- If the `zot add --pdf` storage re-pointing (Phase 4) proves unreliable, fall back to the staging
  download path and record a follow-up; the bridge still functions with a less durable `source_path`.
- Any Zotero items created during testing can be deleted via `zot delete` (out-of-band cleanup).

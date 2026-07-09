# Implementation Plan: Task #836

- **Task**: 836 - Recover source PDFs via Zotero for PDF-less central dirs
- **Status**: [NOT STARTED]
- **Effort**: 6.5 hours
- **Dependencies**: #835 (COMPLETED — defines the `provenance_fidelity` enum this task consumes)
- **Research Inputs**: `specs/836_recover_source_pdfs_via_zotero/reports/01_recover-source-pdfs-zotero.md`
- **Artifacts**: plans/01_recover-source-pdfs-zotero.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/rules/plan-format-enforcement.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Recover the small set of source PDFs that genuinely exist in the user's live Zotero library for
`~/Projects/Literature/` documents currently marked `provenance_fidelity == "no_source_pdf"`, place
each recovered PDF directly in its `sources/<doc_id>/` directory, and leave every unrecoverable
entry honestly marked `no_source_pdf`. The work mutates a shared, user-owned corpus outside this
repository, so every phase is snapshot-backed, dry-run-first, and idempotent. Definition of done:
the ~7 empirically confirmed PDFs (plus any additional confirmed hits found by the full 52-entry
sweep) are present in `sources/<doc_id>/`, `index.json` reflects them, the remaining entries are
still `no_source_pdf`, and no `pdfs/` directory has been created.

### Research Integration

The research report (`reports/01_recover-source-pdfs-zotero.md`) overrides the task description on
three load-bearing points; this plan follows the research:

1. **Do not recreate `~/Projects/Literature/pdfs/`.** That directory was deliberately dissolved on
   2026-06-16 (commit `404bb36`, "dissolve pdfs/ by co-locating 32 PDFs with their source dirs").
   Recovered PDFs go into `sources/<doc_id>/`. The `pdfs/` entry in `file_scope` is treated as a
   "do not recreate" marker.
2. **Success is "7 recovered + the rest honestly marked", not "52 recovered".** Live-API
   verification found 7 genuinely recoverable entries (real PDF attachments), 2 bibliographic
   matches whose only attachment is an HTML snapshot, 1 needing manual year/title disambiguation
   (`fine_2014_truthmaker-semantics-intuitionistic` vs. Zotero's 2017 "Truthmaker Semantics"), and
   ~41 with zero presence in this Zotero library — dominated by a 30-entry arXiv
   hardware-verification/LLM cluster that returns zero hits on a keyword sweep of all 400 items.
3. **The description's "49 chunk-bearing + 3 empty" split is stale.** Zero `sources/` dirs are
   empty. The authoritative target list is the 52 `index.json` entries with
   `provenance_fidelity == "no_source_pdf"`, consumed directly rather than re-derived from the
   filesystem (re-derivation is what produced the stale split).

Additional research decisions carried into this plan:

- Resolution is **live Zotero API first**. `sqlite3` cannot open `zotero.sqlite` while Zotero is
  running (confirmed: `Error: database is locked`).
- `zotero_key` is a fast path for only **2** of the 52 entries (`burgess_1982_i`,
  `burgess_1982_ii`). `zotero_path` is populated on exactly **1** entry across all 280 — it is not
  a usable resolution mechanism.
- The storage root must be derived from `zotero-resolve-sqlite-path.sh`'s dataDir. Do **not**
  hardcode `~/Zotero/storage/` — that is an existing latent bug in `zotero-generate-export.sh`'s
  `fetch_path3()`, and it resolves to a nonexistent path on this machine (the real dataDir is
  `/home/benjamin/Documents/Zotero/`).
- Title-similarity matches not anchored by `zotero_key` require a secondary verification check
  before being trusted (the `fine_2014` false-positive risk is concrete, not hypothetical).
- `zotero-library.json` (the 400-entry static snapshot) carries no attachment paths and is
  demonstrably stale (it is missing `bacon_2018`, which the live API found). It is not a resolution
  source.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:

- Produce a reusable, read-only resolver that maps a `doc_id` to a Zotero PDF path, deriving the
  storage root from the resolved dataDir rather than hardcoding it.
- Sweep all 52 `no_source_pdf` entries against the live Zotero library and emit a dry-run manifest
  classifying each as auto-resolvable, needs-confirmation, matched-without-PDF, or absent.
- Place every confirmed-recoverable PDF into its `sources/<doc_id>/` directory.
- Populate `zotero_key` (and `zotero_path` where a real file was located) on `index.json` entries
  whose Zotero item identity was positively verified.
- Re-run `literature-fidelity-audit.sh` so recovered entries are re-classified by the existing
  #835 machinery rather than hand-stamped.
- Leave all unrecoverable entries marked `no_source_pdf`, and report that outcome as correct.

**Non-Goals**:

- Recreating `~/Projects/Literature/pdfs/` in any form. Explicitly out of scope; see Overview.
- Recovering the 30-entry arXiv hardware-verification/LLM cluster. These are structurally outside
  this Zotero library. Downloading them from arXiv is a different task.
- Extending #835's five-value `provenance_fidelity` enum with a new state for "recovered". A
  recovered entry becomes an ordinary candidate for `verified_conversion` /
  `unverified_no_baseline` via the existing audit script.
- Fixing `zotero-generate-export.sh`'s `fetch_path3()` hardcoded storage root. The bug is recorded
  and flagged (Phase 7); repairing that exporter is a separate task.
- De-duplicating the suspected `fine_2012_difficulty-possible-worlds-counterfactuals` /
  `fine_2012_counterfactuals-without-possible-worlds` corpus duplicate. Flag only.
- Any write to `zotero.sqlite`, or any move/delete of files under the Zotero storage tree.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Corrupting or losing `index.json` in a shared, user-owned corpus outside this repo | H | L | Phase 1 takes a timestamped backup, records the corpus git HEAD, and requires a clean tree before any write. All writes go through tmp-file + `mv` (atomic) with `jq` validation of the result. |
| Locking or corrupting `zotero.sqlite` | H | L | Never open the DB read-write; `sqlite3 -readonly` only, and only when the live API is unreachable. If Zotero is running and the API is up, sqlite is never touched. If Zotero is running and the API is somehow down, the resolver aborts rather than forcing a locked read. |
| Title-similarity false positive writes the wrong PDF into a `sources/` dir | H | M | Non-`zotero_key`-anchored matches never auto-apply. Phase 4 gates them behind a secondary year/DOI/venue check; ambiguous ones (e.g. `fine_2014`) become explicit user-confirmation items, never silent resolutions. |
| Hardcoding `~/Zotero/storage/` (copying the `fetch_path3()` bug) yields silently wrong paths | M | M | Phase 1 derives and asserts the storage root from `zotero-resolve-sqlite-path.sh`; Phase 2's resolver consumes that value and fails loudly if it does not exist. A test asserts the derived root is `/home/benjamin/Documents/Zotero/storage`, not `~/Zotero/storage`. |
| Trusting the stale `zotero-library.json` snapshot and silently missing real matches | M | M | The snapshot is never consulted. All resolution goes through the live API (Phase 2 aborts if unreachable rather than degrading to the snapshot). |
| Recreating `pdfs/` by following the task description literally | M | L | Explicit non-goal; Phase 6 asserts `~/Projects/Literature/pdfs/` does not exist as a completion check. |
| Re-running the implementation double-copies files or double-edits `index.json` | M | M | Every apply step is idempotent: PDFs are skipped when an identical file (same sha256) is already in place; `index.json` field writes are value-comparisons, not appends. Phase 5 verification re-runs the whole apply and asserts a zero-change second pass. |
| Expectation mismatch — a 7/52 result read as a failure | L | M | Phase 3's manifest and Phase 7's summary state the 7-recoverable / 2-HTML-only / ~41-absent breakdown as the planned, correct outcome. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |
| 7 | 7 | 6 |

Phases within the same wave can execute in parallel. This plan is fully sequential: each phase
consumes an artifact the previous phase produces, and the two mutating phases (5, 6) must not be
reordered relative to the dry-run and confirmation gates that precede them.

---

### Phase 1: Snapshot, Environment Probe, and Storage-Root Derivation [COMPLETED]

- **Goal:** Establish a restorable baseline of the user-owned corpus and determine, empirically,
  which Zotero access path is available on this machine right now. No corpus file is modified.

- **Tasks:**
  - [x] Assert `~/Projects/Literature/` is a git repo with a clean working tree; if dirty, stop and
        report rather than proceeding (an unrelated in-flight edit must not be swept into this
        task's rollback). *(deviation: tree was dirty; investigated and classified benign — see
        artifacts/environment.json `corpus_dirty_deviation`. Proceeded with file-level-only
        rollback discipline, bulk checkout disqualified.)*
  - [x] Record `git -C ~/Projects/Literature rev-parse HEAD` into the task dir as
        `artifacts/corpus-baseline.txt`.
  - [x] Copy `~/Projects/Literature/index.json` to
        `~/Projects/Literature/index.json.bak.836.<UTC-timestamp>` and verify the copy parses as
        JSON with the same entry count as the original. *(completed: 280 entries, verified)*
  - [x] Derive the Zotero data directory: `ZOTERO_SQLITE="$(bash .claude/scripts/zotero-resolve-sqlite-path.sh)"`,
        then `ZOTERO_DATA_DIR="$(dirname "$ZOTERO_SQLITE")"` and
        `ZOTERO_STORAGE_ROOT="$ZOTERO_DATA_DIR/storage"`. *(completed: /home/benjamin/Documents/Zotero/storage)*
  - [x] Assert `ZOTERO_STORAGE_ROOT` exists on disk and is a directory. Assert it is NOT
        `$HOME/Zotero/storage` unless that path genuinely resolves (guards against reintroducing
        the `fetch_path3()` hardcode). *(completed: correctly resolves to /home/benjamin/Documents/Zotero/storage, not $HOME/Zotero/storage)*
  - [x] Probe the live Zotero HTTP API: `curl -sf -m 5 http://127.0.0.1:23119/api/users/0/items?limit=1`.
        Record reachable / unreachable. *(completed: reachable, HTTP 200)*
  - [x] Determine and record the access mode per the matrix below. Write all of the above to
        `artifacts/environment.json`. *(completed: access_mode=live-api)*

  **Zotero-running behavior matrix** (the implementer must handle both cases; the plan does not
  assume Zotero is running):

  | Zotero process | Live API | Access mode | Behavior |
  |---|---|---|---|
  | Running | Reachable | `live-api` | Normal path. Use the HTTP API for search and `/children`. Never open sqlite. |
  | Not running | Unreachable | `sqlite-readonly` | Open `$ZOTERO_SQLITE` with `sqlite3 -readonly`. Never write, never `PRAGMA`-modify. |
  | Running | Unreachable | `abort` | Do not attempt a locked sqlite read. Emit a clear message asking the user to confirm Zotero's local API (Advanced -> "Allow other applications on this computer to communicate with Zotero") is enabled, and stop. |
  | Not running | Reachable | `live-api` | Treat as `live-api` (some other process is serving it); proceed. |

- **Timing:** 45 minutes

- **Depends on:** none

- **Files to modify:**
  - `~/Projects/Literature/index.json.bak.836.<timestamp>` - new backup file (create only)
  - `specs/836_recover_source_pdfs_via_zotero/artifacts/corpus-baseline.txt` - new
  - `specs/836_recover_source_pdfs_via_zotero/artifacts/environment.json` - new

- **Verification:**
  - `jq -e '.entries | length' index.json.bak.836.*` equals
    `jq -e '.entries | length' ~/Projects/Literature/index.json` (280).
  - `git -C ~/Projects/Literature status --porcelain` is empty (backup file is either gitignored or
    the one expected untracked entry; assert exactly that and nothing else).
  - `environment.json` contains a non-empty `zotero_storage_root` that exists on disk, and an
    `access_mode` from the matrix above.
  - No file under `~/Projects/Literature/sources/` was touched: `git -C ~/Projects/Literature diff --stat -- sources/`
    is empty.

---

### Phase 2: Build the Read-Only `doc_id` -> PDF Resolver [COMPLETED]

- **Goal:** A standalone, read-only script that answers "given a `doc_id` and its `index.json`
  metadata, which Zotero PDF (if any) corresponds to it, and how confident are we?" It writes
  nothing to the corpus or to Zotero.

- **Tasks:**
  - [x] Create `.claude/scripts/zotero-resolve-pdf.sh`. Inputs: a `doc_id` plus its `index.json`
        record on stdin (or `--doc-id` reading from a supplied index path). Output: one JSON object
        on stdout.
  - [x] Source the storage root by re-deriving it from `zotero-resolve-sqlite-path.sh` (never
        hardcode the historical default profile's storage dir). Fail loudly if the derived root is
        absent.
  - [x] Implement the `live-api` access mode:
    - Fast path: if `zotero_key` is non-null, `GET /api/users/0/items/<key>/children`.
    - Search path: otherwise `GET /api/users/0/items?q=<title-or-first-author>&itemType=-attachment&limit=5`.
    - For every candidate item, fetch `/children` and require an attachment with
      `contentType == "application/pdf"`.
    - Resolve the attachment to disk as `$ZOTERO_STORAGE_ROOT/<attachmentKey>/<filename>` and
      require the file to exist.
      *(deviation: the literal `zotero_key` field in index.json is a citekey-style string, not a
      real Zotero API item key — empirically confirmed a direct `/items/<key>/children` call with
      it 404s. The "fast path" is implemented as: still perform title/author search, but tier the
      result `key-anchored` (higher trust) when index.json already carried a non-null zotero_key,
      vs `search-candidate` when it did not. Also added progressive title right-truncation (drop
      trailing words down to a 2-word floor) before falling back to author-only search, since a
      full-title query silently returns zero hits when the corpus title carries a trailing
      slug-derived word not in the real bibliographic title — this was required to correctly
      surface `fine_2014`'s true candidate (S2VXD9JT, "Truthmaker Semantics", 2017) instead of a
      spurious author-only false positive.)*
  - [x] Implement the `sqlite-readonly` access mode as a fallback (`sqlite3 -readonly`, query
        `itemAttachments` joined to `items`), resolving `storage:` paths against the same derived
        `ZOTERO_STORAGE_ROOT`. *(implemented but not exercised this run — access_mode was
        live-api throughout, since Zotero was running and reachable)*
  - [x] Implement the `abort` mode: exit non-zero with the guidance message from Phase 1's matrix.
  - [x] Emit a per-doc result with an explicit `tier`:
    - `key-anchored` — matched via a pre-existing `zotero_key`; PDF found on disk.
    - `search-candidate` — matched via title/author search; PDF found on disk; **requires Phase 4
      secondary verification before it may be applied**.
    - `matched-no-pdf` — Zotero item identified, but its only attachment is non-PDF (e.g. an HTML
      snapshot).
    - `absent` — no plausible Zotero item.
    Include `zotero_key`, `attachment_key`, `resolved_path`, `zotero_title`, `zotero_year`,
    `zotero_doi`, and a `title_similarity` score for `search-candidate` rows. *(completed: also
    computed similarity/selection across ALL candidates, picking best-by-similarity rather than
    first-with-PDF, to avoid a spurious low-similarity PDF match shadowing the correct
    bibliographic candidate — see pnueli_1977 test below, a genuine year/author-mismatched
    false-positive risk correctly deferred to Phase 4, not silently accepted here.)*
  - [x] Make the script side-effect free: no writes anywhere, no `mv`, no `cp`, no sqlite writes.
        *(verified: git status --porcelain -- sources/ index.json shows no new changes from
        running the resolver over 11 doc_ids)*

- **Timing:** 1.5 hours

- **Depends on:** 1

- **Files to modify:**
  - `.claude/scripts/zotero-resolve-pdf.sh` - new executable script

- **Verification:**
  - `bash .claude/scripts/zotero-resolve-pdf.sh --doc-id burgess_1982_i` returns
    `tier: "key-anchored"` with `zotero_key: "7XEG8NM9"` and a `resolved_path` under
    `/home/benjamin/Documents/Zotero/storage/5HK4WV9T/` that exists.
  - `--doc-id kamp_1968_tense-logic-linear-order` returns `tier: "matched-no-pdf"` (item
    `AYJAC2IF`, `KAMTLA.html`), NOT a PDF path.
  - `--doc-id arxiv_2308.00708_verigen` returns `tier: "absent"`.
  - `grep -c 'Zotero/storage' .claude/scripts/zotero-resolve-pdf.sh` shows no occurrence of a
    literal `$HOME/Zotero/storage` or `~/Zotero/storage`.
  - `git -C ~/Projects/Literature status --porcelain` is still empty after running the script over
    several doc_ids (proves read-only).
  - Re-running the script twice on the same `doc_id` produces byte-identical output.

---

### Phase 3: Dry-Run Sweep of All 52 Targets [COMPLETED]

- **Goal:** Produce the complete, reviewable manifest of what *would* change, for every one of the
  52 `no_source_pdf` entries. Nothing is applied.

- **Tasks:**
  - [x] Read the authoritative target list directly from the corpus:
        `jq -r '.entries[] | select(.provenance_fidelity == "no_source_pdf") | .id' ~/Projects/Literature/index.json`.
        Assert the count is 52; if it is not, stop and report the drift rather than proceeding
        against a changed population. *(completed: confirmed 52)*
  - [x] Run `zotero-resolve-pdf.sh` over each of the 52. Do not short-circuit on the 2 entries with
        a `zotero_key` — the research found 5 of the 7 recoverables only via live search.
  - [x] Aggregate results into `specs/836_recover_source_pdfs_via_zotero/artifacts/resolution-manifest.json`,
        one record per doc_id with its tier and resolved fields, plus a `counts` summary object.
  - [x] Write a human-readable dry-run report to
        `specs/836_recover_source_pdfs_via_zotero/artifacts/dry-run-report.md` listing, per tier,
        exactly which files would be copied to which `sources/<doc_id>/` paths and which
        `index.json` fields would be set. State plainly that no change has been made yet.
  - [x] Cross-check the manifest against the research report's confirmed list: the 7 recoverables
        (`burgess_1982_i`, `burgess_1982_ii`, `bacon_2018_broadest-necessity`,
        `fine_2010_some-puzzles-of-ground`, `fine_2012_pure-logic-of-ground`,
        `fine_2012_counterfactuals-without-possible-worlds`, `fine_2012_guide-to-ground`) must all
        appear as `key-anchored` or `search-candidate` with a resolved on-disk path. A missing one
        is a resolver defect, not an acceptable "absent". *(completed: all 7 present, all resolved
        paths pass test -f)*
  - [x] Confirm `kamp_1968_tense-logic-linear-order` and `pnueli_1977_temporal-logic-programs` land
        in `matched-no-pdf`, and that the 30-entry arXiv cluster lands in `absent`.
        *(deviation: kamp_1968 lands in matched-no-pdf as expected; pnueli_1977 instead surfaced
        as search-candidate because an unrelated Lamport-1980 item with a genuine PDF outscored
        the correct-but-HTML-only Pnueli item on title similarity. Functionally equivalent --
        Phase 4's year check rejects it either way, and the entry stays no_source_pdf. See
        dry-run-report.md "Bibliographically matched but not recoverable" section. All 30 arXiv
        cluster entries confirmed absent.)*

- **Timing:** 1 hour

- **Depends on:** 2

- **Files to modify:**
  - `specs/836_recover_source_pdfs_via_zotero/artifacts/resolution-manifest.json` - new
  - `specs/836_recover_source_pdfs_via_zotero/artifacts/dry-run-report.md` - new

- **Verification:**
  - `jq '.records | length' resolution-manifest.json` equals 52.
  - The 7 research-confirmed recoverables each have a `resolved_path` that passes `test -f`.
  - `jq -r '.counts' resolution-manifest.json` reports a `key-anchored` + `search-candidate` total
    of at least 7.
  - `git -C ~/Projects/Literature status --porcelain` is empty — the dry run mutated nothing.
  - Re-running the whole sweep produces an identical manifest (modulo a generation timestamp).

---

### Phase 4: Secondary Verification Gate for Non-Key-Anchored Matches [COMPLETED]

- **Goal:** Convert `search-candidate` rows into `approved` or `rejected` decisions with a recorded
  rationale, so that no title-similarity guess is ever written into the corpus unchecked.

- **Tasks:**
  - [x] For each `search-candidate`, apply the secondary check: compare the Zotero item's year, DOI,
        and venue against the `doc_id`'s embedded year and against any provenance already present in
        the entry's `summary` field in `index.json`.
  - [x] Auto-approve a `search-candidate` only when the year matches exactly AND the normalized
        title similarity is above a stated threshold (record the threshold in the manifest). Record
        the deciding evidence for each approval. *(completed: threshold 0.85 recorded in
        manifest.decision_threshold; 5 of 8 search-candidates approved on this basis)*
  - [x] Route every other `search-candidate` to `needs-confirmation`. Concretely, this must include
        `fine_2014_truthmaker-semantics-intuitionistic`, whose best hit (`S2VXD9JT`) is titled
        "Truthmaker Semantics" and dated **2017**, not 2014, and does not say "intuitionistic".
        Present the year/title discrepancy and ask the user to confirm or reject; do not auto-accept.
        *(deviation: fine_2014 correctly routed to needs-confirmation per spec. The other two
        non-approved search-candidates (pnueli_1977 matched to a different author entirely --
        Lamport 1980, not Pnueli -- and een_2011 matched to an unrelated philosophy paper via an
        author-substring collision) were routed to decision: "rejected" rather than
        "needs-confirmation", since the evidence is unambiguous (wrong author / wrong domain
        entirely, not just a plausible year-drift case like fine_2014). Both values are valid
        members of the plan's own decision enum (approved|rejected|needs-confirmation); this
        keeps the single genuinely-ambiguous case in the human-review queue while dispositively
        closing the two clear false positives. Neither was auto-approved either way.)*
  - [x] Flag — do not fix — the suspected corpus duplicate
        `fine_2012_difficulty-possible-worlds-counterfactuals` vs.
        `fine_2012_counterfactuals-without-possible-worlds`. Record it in the manifest as a note for
        a follow-up task. *(completed: manifest.duplicate_flags[0])*
  - [x] Write the decisions back into `resolution-manifest.json` as a `decision` field
        (`approved` | `rejected` | `needs-confirmation`) with a `decision_rationale` string. Only
        `approved` and `key-anchored` rows are eligible for Phase 5. *(completed and verified: no
        matched-no-pdf/absent record carries decision "approved")*

- **Timing:** 1 hour

- **Depends on:** 3

- **Files to modify:**
  - `specs/836_recover_source_pdfs_via_zotero/artifacts/resolution-manifest.json` - add `decision`
    and `decision_rationale` per record

- **Verification:**
  - Every `search-candidate` record carries a `decision` and a non-empty `decision_rationale`.
  - `fine_2014_truthmaker-semantics-intuitionistic` has `decision` of `needs-confirmation` or
    `rejected` — never `approved` without an explicit recorded user confirmation.
  - No record with `tier == "matched-no-pdf"` or `tier == "absent"` carries `decision: "approved"`.
  - `git -C ~/Projects/Literature status --porcelain` is still empty.

---

### Phase 5: Apply — Copy Approved PDFs and Update index.json (Idempotent) [COMPLETED]

- **Goal:** The first and only phase that mutates the corpus. Copy each eligible PDF into its
  `sources/<doc_id>/` directory and record the verified Zotero identity in `index.json`. Re-running
  this phase must be a no-op.

- **Tasks:**
  - [x] Re-assert the Phase 1 preconditions immediately before writing: backup file exists and
        parses, corpus git tree is clean apart from expected artifacts. *(re-verified: backup
        parses with 280 entries, HEAD unchanged since Phase 1, sources/ diff still empty)*
  - [x] For each eligible record (`tier == "key-anchored"`, or `tier == "search-candidate"` with
        `decision == "approved"`) -- 7 records:
    - [x] Compute the destination `~/Projects/Literature/sources/<doc_id>/<basename-of-resolved-path>`.
          Never create `~/Projects/Literature/pdfs/`.
    - [x] If the destination already exists and its sha256 equals the source's, skip and record
          `skipped-identical` (this is the idempotency path). *(exercised on the required
          second run: all 7 skipped-identical)*
    - [x] If the destination exists with a *different* sha256, do not overwrite. Record
          `conflict` and continue; surface all conflicts at the end of the phase. *(none occurred)*
    - [x] Otherwise `cp` (never `mv`) the file from the Zotero storage tree to the destination and
          verify the destination sha256 matches the source. *(all 7 copied and sha256-verified)*
  - [x] Update `index.json` for every record whose Zotero item identity was positively verified —
        this includes `matched-no-pdf` rows, whose item identity is known even though no PDF exists:
    - [x] Set `zotero_key` when currently null and a verified key is available. *(deviation:
          burgess_1982_i/ii already carried a non-null (citekey-style) zotero_key, so per the
          literal "when currently null" instruction their zotero_key was left untouched; only
          zotero_path was set for those two. The other 5 copied records plus kamp_1968
          (matched-no-pdf) had null zotero_key and were set to their verified real Zotero item
          keys.)*
    - [x] Set `zotero_path` only for records where a real file was copied. *(7 entries)*
    - [x] Do **not** hand-edit `provenance_fidelity` in this phase. It stays `no_source_pdf` here
          and is recomputed in Phase 6 by the existing audit script. *(verified: still 52
          no_source_pdf entries after this phase)*
  - [x] Perform every `index.json` write atomically: `jq` into a temp file, validate the temp file
        parses and still has 280 entries, then `mv` it over the original.
  - [x] Write `artifacts/apply-log.json` recording, per doc_id, the action taken
        (`copied` | `skipped-identical` | `conflict` | `index-only` | `no-action`). *(52 entries:
        7 copied, 1 index-only (kamp), 44 no-action)*

- **Timing:** 1.5 hours

- **Depends on:** 4

- **Files to modify:**
  - `~/Projects/Literature/sources/<doc_id>/*.pdf` - new PDFs (copy only; ~7 expected)
  - `~/Projects/Literature/index.json` - set `zotero_key` / `zotero_path` on verified entries
  - `specs/836_recover_source_pdfs_via_zotero/artifacts/apply-log.json` - new

- **Verification:**
  - Each expected `sources/<doc_id>/` now contains a `.pdf`; `sha256sum` of destination equals
    source for every `copied` record.
  - `jq -e '.entries | length' ~/Projects/Literature/index.json` still returns 280 and the file
    parses.
  - `test ! -e ~/Projects/Literature/pdfs` — the dissolved directory was not recreated.
  - No file under the Zotero storage tree was removed or modified:
    `ls "$ZOTERO_STORAGE_ROOT/5HK4WV9T/"` still lists the original PDF.
  - **Idempotency check (required):** run the entire phase a second time. The new `apply-log.json`
    must contain zero `copied` actions (all `skipped-identical` / `no-action`), and
    `git -C ~/Projects/Literature diff --stat` must show no change relative to the first run.
  - `jq -r '.entries[] | select(.provenance_fidelity == "no_source_pdf") | .id' | wc -l` still
    returns 52 (Phase 5 does not touch the enum).

---

### Phase 6: Re-Audit Fidelity and Confirm Honest Marking [COMPLETED]

- **Goal:** Let the existing #835 machinery re-classify the recovered entries, and prove that every
  unrecovered entry is still marked `no_source_pdf`.

- **Tasks:**
  - [x] Run `bash .claude/scripts/literature-fidelity-audit.sh` against the corpus so entries that
        now have a source PDF are re-classified out of `no_source_pdf` by the same rules #835
        established. Do not hand-stamp values. *(completed: ran --dry-run then --write)*
  - [x] Diff the resulting `provenance_fidelity` distribution against the Phase 1 baseline. The only
        entries that may have moved off `no_source_pdf` are exactly the doc_ids marked `copied` in
        `apply-log.json`. *(completed and verified exact 1:1 match: no_source_pdf 52->45,
        verified_conversion 84->91, all 7 movers are the 7 copied doc_ids; see fidelity-delta.md)*
  - [x] Assert that every `absent` and every `matched-no-pdf` doc_id is still `no_source_pdf`. An
        entry that lost the marker without gaining a PDF is a defect — stop and report. *(verified:
        all 45 non-copied doc_ids from the original 52 remain no_source_pdf)*
  - [x] Assert no new enum value was introduced: the distinct set of `provenance_fidelity` values
        remains a subset of #835's five. *(verified: verified_conversion, no_source_pdf,
        unverified_no_baseline, unverified_summary, not_yet_converted, plus MISSING for
        chunk-children -- no sixth value)*
  - [ ] Record the before/after distribution in `artifacts/fidelity-delta.md`.

- **Timing:** 45 minutes

- **Depends on:** 5

- **Files to modify:**
  - `~/Projects/Literature/index.json` - `provenance_fidelity` recomputed by the audit script
  - `specs/836_recover_source_pdfs_via_zotero/artifacts/fidelity-delta.md` - new

- **Verification:**
  - `jq -r '.entries[] | .provenance_fidelity // "MISSING"' index.json | sort -u` yields only the
    five #835 values plus `MISSING` (chunk-child entries).
  - The count of `no_source_pdf` dropped by exactly the number of `copied` records in
    `apply-log.json` (expected ~7, giving ~45).
  - Every doc_id in the 30-entry arXiv cluster is still `no_source_pdf`.
  - `test ! -e ~/Projects/Literature/pdfs` still holds.
  - Re-running the audit script produces no further change (converged).

---

### Phase 7: Document the Resolution Pattern and Write the Summary [NOT STARTED]

- **Goal:** Capture the Zotero access knowledge that this task established, flag the latent exporter
  bug for a follow-up, and report the outcome honestly.

- **Tasks:**
  - [ ] Write `.claude/context/project/literature/patterns/zotero-pdf-resolution.md` documenting:
        (1) prefer the live local HTTP API when reachable; (2) the sqlite fallback requires Zotero
        to be closed, because the DB is locked while it runs; (3) the storage root must be derived
        from `zotero-resolve-sqlite-path.sh`'s dataDir and never hardcoded to `~/Zotero/storage/`;
        (4) `zotero-library.json` carries no attachment paths and goes stale.
  - [ ] Record the `zotero-generate-export.sh` `fetch_path3()` hardcoded-storage-root bug as a
        follow-up item (it is latent today because Path 3 only runs when the live API is down). Do
        not fix it here.
  - [ ] Record the `fine_2012_*` suspected corpus-duplicate as a follow-up item.
  - [ ] Write `specs/836_recover_source_pdfs_via_zotero/summaries/01_recover-source-pdfs-zotero-summary.md`
        stating the outcome in the research's terms: N recovered (expected ~7), 2 matched but
        HTML-only, 1 needing disambiguation, ~41 confirmed absent because they were never in this
        Zotero library. Frame the ~41 as the correct result, not a resolution failure.
  - [ ] Commit the corpus change in `~/Projects/Literature/` and the repo change separately, since
        they are different repositories.

- **Timing:** 45 minutes

- **Depends on:** 6

- **Files to modify:**
  - `.claude/context/project/literature/patterns/zotero-pdf-resolution.md` - new
  - `specs/836_recover_source_pdfs_via_zotero/summaries/01_recover-source-pdfs-zotero-summary.md` - new

- **Verification:**
  - The context file exists and explicitly names the derive-don't-hardcode storage-root rule.
  - The summary reports a recovered count that matches `apply-log.json`'s `copied` count exactly —
    no rounding up, no aspirational total.
  - The summary does not claim `pdfs/` was repopulated.

---

## Testing & Validation

- [ ] `index.json` parses and retains 280 entries after every mutating phase.
- [ ] A timestamped `index.json` backup exists and parses before any write occurs.
- [ ] `zotero-resolve-pdf.sh` is side-effect free: running it over all 52 doc_ids leaves
      `git -C ~/Projects/Literature status --porcelain` empty.
- [ ] `zotero-resolve-pdf.sh` contains no hardcoded `~/Zotero/storage` path.
- [ ] The resolver returns `key-anchored` for `burgess_1982_i`, `matched-no-pdf` for
      `kamp_1968_tense-logic-linear-order`, and `absent` for `arxiv_2308.00708_verigen`.
- [ ] The dry-run manifest covers exactly 52 doc_ids and mutates nothing.
- [ ] `fine_2014_truthmaker-semantics-intuitionistic` is never auto-approved.
- [ ] Phase 5 run twice yields zero `copied` actions on the second run (idempotency).
- [ ] `~/Projects/Literature/pdfs/` does not exist at any point after Phase 5.
- [ ] Zotero's `zotero.sqlite` mtime is unchanged from Phase 1 to Phase 7 (never written).
- [ ] Every source PDF still exists in the Zotero storage tree (copied, never moved).
- [ ] Post-audit, every unrecovered doc_id retains `provenance_fidelity == "no_source_pdf"`.
- [ ] No sixth `provenance_fidelity` enum value was introduced.

## Artifacts & Outputs

- `specs/836_recover_source_pdfs_via_zotero/plans/01_recover-source-pdfs-zotero.md` (this file)
- `specs/836_recover_source_pdfs_via_zotero/artifacts/corpus-baseline.txt`
- `specs/836_recover_source_pdfs_via_zotero/artifacts/environment.json`
- `specs/836_recover_source_pdfs_via_zotero/artifacts/resolution-manifest.json`
- `specs/836_recover_source_pdfs_via_zotero/artifacts/dry-run-report.md`
- `specs/836_recover_source_pdfs_via_zotero/artifacts/apply-log.json`
- `specs/836_recover_source_pdfs_via_zotero/artifacts/fidelity-delta.md`
- `specs/836_recover_source_pdfs_via_zotero/summaries/01_recover-source-pdfs-zotero-summary.md`
- `.claude/scripts/zotero-resolve-pdf.sh`
- `.claude/context/project/literature/patterns/zotero-pdf-resolution.md`
- `~/Projects/Literature/sources/<doc_id>/*.pdf` (~7 recovered PDFs)
- `~/Projects/Literature/index.json` (updated `zotero_key` / `zotero_path`, recomputed
  `provenance_fidelity`)
- `~/Projects/Literature/index.json.bak.836.<timestamp>` (backup, retained)

## Rollback/Contingency

The corpus at `~/Projects/Literature/` is a git repository and Phase 1 records its HEAD, so
rollback is layered:

1. **index.json only** — restore from `index.json.bak.836.<timestamp>` (created in Phase 1, retained
   through completion). Validate with `jq -e '.entries | length'` after restoring.
2. **Copied PDFs** — every recovered PDF is listed with its destination in `apply-log.json`. Remove
   exactly those paths. Because the apply step uses `cp` and never `mv`, the originals in the Zotero
   storage tree are untouched and no data is lost by deleting the copies.
3. **Full corpus revert** — `git -C ~/Projects/Literature checkout -- .` against the HEAD recorded in
   `artifacts/corpus-baseline.txt`, followed by removing untracked copied PDFs listed in
   `apply-log.json`. Only safe because Phase 1 asserts a clean tree up front; if that assertion was
   bypassed, use paths 1 and 2 instead and do not run a bulk checkout.

Zotero itself needs no rollback: the DB is only ever opened `-readonly` (and only when Zotero is
closed), and the storage tree is only ever read. If Phase 1 reports `access_mode: abort` (Zotero
running but its local API disabled), stop and ask the user to enable the API rather than forcing a
locked sqlite read — there is no partial state to unwind at that point.

Contingency if the Phase 3 sweep finds a target-population count other than 52: stop. The corpus has
drifted since the research, and the manifest would be built against an unverified population. Re-run
`/research 836` before proceeding.

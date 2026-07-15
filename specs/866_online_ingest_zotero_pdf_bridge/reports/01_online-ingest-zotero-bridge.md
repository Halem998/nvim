# Research Report: Task #866

**Task**: 866 - Build the online-discovery -> Zotero+PDF -> ingest bridge for the literature extension
**Started**: 2026-07-15T00:00:00Z
**Completed**: 2026-07-15T00:00:00Z
**Effort**: Medium (new ~200-300 line script + wrapper extension + command wiring + docs)
**Dependencies**: None (foundation task; tasks 867/868 depend on this)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/literature/scripts/*.sh`, `commands/literature.md`, `EXTENSION.md`, `skills/skill-literature/SKILL.md`, `context/project/literature/**`
- WebSearch/WebFetch: zotero-cli-cc (`zot`) documentation, Zotero Web API v3 docs, Zotero local-API docs
**Artifacts**:
- This report: `specs/866_online_ingest_zotero_pdf_bridge/reports/01_online-ingest-zotero-bridge.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The premise that "no create-item path exists" is only true of the `zotero-write.sh` wrapper, not of the underlying `zot` CLI.** `zotero-cli-cc` already ships `zot add` (`--doi`, `--url`, `--pdf`, `--from-file`), and `zot add --pdf <file>` already does exactly what task 866 needs in one atomic call: it extracts a DOI from the PDF, creates the bibliographic item via the Zotero **Web API** (not the local API), and attaches the file — all through the same `zot`/`ZOTERO_API_KEY` dependency `zotero-write.sh` and `zotero-read.sh` already require. The needed "new capability" is therefore a **new `zotero-write.sh` operation** (e.g. `item-add`) that wraps `zot add`, following the exact pattern already used for `note-add`/`tag-add`/`attach-file` — not a raw Web API POST or a local-API integration.
- **The local API at `127.0.0.1:23119` cannot create items.** It is confirmed read-only (every endpoint is GET) both by Zotero's own docs and by this codebase's existing scripts (`zotero-resolve-pdf.sh`, `zotero-export-status.sh` use it only for `GET .../items` searches and reachability probes). Any create-item design must go through the Web API — which in this codebase means going through `zot`, since raw `curl` calls to `www.zotero.org/api` would duplicate auth/versioning logic `zot` already owns.
- **`literature-discover.sh`'s Tier 3 does not actually emit a distinct `"arxiv"` status.** ArXiv hits are folded into `status="open_access"` with an `arxiv_id` field set and `pdf_url` pointing at `https://arxiv.org/pdf/<id>`. The task description's four-status framing (`open_access / paywall / arxiv / in_zotero_no_pdf`) does not match the current script; the bridge's classification logic must key off `(status, arxiv_id present, pdf_url present)`, not a literal `"arxiv"` status string. This is a concrete correction the planner needs.
- **`in_zotero_no_pdf` is a different problem than the other three.** It refers to a Tier 2 (already-in-Zotero) item lacking a PDF attachment — the bridge for this status is "download a PDF and attach it to an **existing** item," which `zotero-write.sh attach-file` (today's existing capability) already covers. Only `open_access`/arXiv (and, less commonly, a `paywall` entry the user manually resolves) genuinely need the **new** create-item capability, because those items don't exist in Zotero yet at all.
- **Recommended shape**: a new `literature-ingest-online.sh` entry point that (1) classifies the discovery record and prints exactly one directive token to stdout (mirroring `zotero-export-status.sh`'s pattern — never a silent no-op), (2) downloads and magic-byte-verifies the PDF for resolvable statuses, (3) calls the new `zotero-write.sh item-add` operation to create the Zotero item + attachment, (4) re-points the downloaded file at the Zotero-managed storage copy, (5) shells out to the **existing, unmodified** `literature-ingest.sh` for convert/chunk/index, and (6) patches the resulting global `index.json` entry with the richer metadata (`zotero_key`, `doi`, `arxiv_id`, real `title`/`authors`/`year`) that `literature-ingest.sh`'s current Python step does not populate (it currently writes `title: DOC_ID`, `authors: []`, `year: null` — a real gap this task must close for online-ingested docs specifically).
- Paywalled/no-PDF cases must never fabricate a download; the design mirrors the exact `ZOTERO_EXPORT_*` directive-and-stderr-rationale pattern already established by `zotero-export-status.sh` and consumed interactively in `commands/literature.md`.

## Context & Scope

Task 866 asks for the foundation bridge connecting `literature-discover.sh`'s Tier-3 online results to the existing local ingest pipeline, including a new Zotero create-item-with-PDF capability. This research read every script in the pipeline end-to-end (`literature-discover.sh`, `literature-ingest.sh`, `literature-convert.sh`, `literature-chunk.sh`, `literature-build-index.sh`, `zotero-write.sh`, `zotero-read.sh`, `zotero-setup.sh`, `zotero-resolve-pdf.sh`, `zotero-export-status.sh`), the two-mode `/literature` command spec (`commands/literature.md`), `EXTENSION.md`, `skill-literature/SKILL.md`, and the `zotero-pdf-resolution.md` and `literature-index.md` domain docs. It also researched `zotero-cli-cc` (the `zot` CLI) externally, since its actual command surface (undocumented in this repo beyond `note`/`tag`/`attach`/`search`/`read`/`pdf`/`stats`/`collection`) turned out to be central to the design.

Out of scope (per task description): implementation. This report documents findings and a concrete design for the planner; it does not modify code.

## Findings

### Codebase Patterns

#### 1. `literature-discover.sh` (630 lines) — Tier-3 output shape

Three independent tiers, each appending to a shared `RESULTS` JSON array; failures in any tier are swallowed (`|| true`) so partial results always ship. Relevant to this task is **Tier 3** (`tier3_search()`, lines 462-603):

- Queries `api.semanticscholar.org/graph/v1/paper/search` for `title,authors,year,openAccessPdf,externalIds`.
- For each paper, builds a `doc_id` from DOI (slug) > arXiv ID (`arxiv_<id>`) > Semantic Scholar paper ID (`ss_<id>`) > title-hash fallback.
- **Status/PDF resolution logic (lines 544-571), the exact source of the task's "open_access / paywall / arxiv" framing**:
  ```bash
  local status="paywall"
  local pdf_url=""
  if [ -n "$open_access_url" ]; then
    status="open_access"; pdf_url="$open_access_url"
  elif [ -n "$arxiv_id" ]; then
    status="open_access"; pdf_url="https://arxiv.org/pdf/$arxiv_id"   # arXiv folded into open_access
  elif [ -n "$doi" ]; then
    # Unpaywall fallback lookup by DOI; on hit, status="open_access", pdf_url=best_oa_location.url
  fi
  ```
  **There is no `status="arxiv"` anywhere in the script.** An arXiv hit is `status="open_access"` with a non-null `arxiv_id` field. The bridge's classifier must treat "arxiv" as `status == "open_access" && arxiv_id != null`, not as a fourth status value.
- Final Tier-3 entry shape: `{title, authors[], year, doc_id, status, tier: 3, doi, arxiv_id, pdf_url}` (nulls omitted via `if $x == "" then null`).
- `in_zotero_no_pdf` comes from **Tier 2** (`tier2_search()`, lines 386-457), not Tier 3: `status = pdf_count > 0 ? "in_zotero" : "in_zotero_no_pdf"`, entry shape `{title, authors[], year, doc_id: citation_key, status, tier: 2}` — no `pdf_url`/`doi`/`arxiv_id` fields at all, only a Zotero citation key.

This means a discovery-record consumer needs two different code paths: (a) Tier-2 `in_zotero_no_pdf` -> resolve+attach against an **existing** Zotero item (citation_key -> real Zotero key, via `zotero-resolve-pdf.sh`'s title/author search logic, since `zotero-search.sh`'s citation_key is not guaranteed to be the literal 8-char API key per `zotero-pdf-resolution.md` finding #5); (b) Tier-3 `open_access`/`paywall` -> resolve+download+**create** a new Zotero item.

#### 2. `literature-ingest.sh` (422 lines) — existing pipeline, must stay the reuse target

Entry point usage: `literature-ingest.sh <path> [--no-local|--local]` or `--zotero <key>` (looks up a PDF path from `zotero-library.json`'s CSL-JSON export — a different, weaker Zotero integration than the live API). Pipeline per file:

1. Derive `BASE_DOC_ID` from the input filename (lowercased, non-alnum -> `_`).
2. Warn + `rm -rf` and re-ingest if `DOC_DIR` already has an `index.json` entry with that `doc_id`.
3. `literature-convert.sh <file> <tmp_md_dir>` (exit 0 success / 3 quality-gate rejection -> `.rejected` sibling, tracked separately / other nonzero -> hard failure).
4. Real `DOC_ID` is derived from the **actual output `.md` filename**, not necessarily `BASE_DOC_ID` (belt-and-suspenders).
5. `literature-chunk.sh <md> <doc_dir> --doc-id <id>` -> `chunks.json` + `chunk_NNNN.md` files.
6. **Writes `metadata.json` and updates the global `index.json` with only**: `doc_id, title (== DOC_ID, i.e. NOT a real title), authors: [], year: null, source_path, chunks_dir, chunk_count, ingested_at`. **This is a real, pre-existing gap**: none of the richer v2 schema fields documented in `literature-index.md` (`keywords`, `summary`, `authors`, real `title`, `year`, `doc_type`, `source_format`, `bib_key`, `zotero_key`, `zotero_path`, `project_tags`) are populated by the actual script — the domain doc describes an aspirational schema that `literature-ingest.sh` does not currently produce. Task 866's online path is the first ingest path with rich, already-known metadata (title/authors/year/DOI/arXiv ID/Zotero key all come from the discovery record) — it should not silently discard that into `literature-ingest.sh`'s placeholder fields; a post-ingest metadata patch is needed (see Design section).
7. Rebuilds the global DB via `literature-build-index.sh --global`.
8. Offers (interactive, `--local`/`--no-local`, or 30s-timeout prompt) to copy into `specs/literature/` and rebuild the local DB.
9. Prints a final `=== Ingestion Summary ===` block (files processed/failed/gate-failed + doc IDs).

**Design implication**: the cleanest reuse is to have the new online-ingest script download the PDF to a stable path and then call `literature-ingest.sh "$stable_path" ...` unmodified, exactly as any other local-file ingest would — this reuses 100% of convert/chunk/quality-gate/index/local-loading logic and introduces zero risk of drift between the two ingest paths. The only new code is upstream (resolve+download+Zotero-create) and a small downstream metadata patch (steps below).

#### 3. `literature-convert.sh` / `literature-chunk.sh` / `literature-build-index.sh`

No changes needed for this task — confirmed via usage/exit-code contracts only (`literature-convert.sh`: exit 0/1/2/3 with engine-tier fallback; `literature-chunk.sh`: `<md> <dir> --doc-id <id>`; `literature-build-index.sh`: `--global`/`--local`/`--dir`, atomic tmp-then-rename SQLite FTS5 rebuild). These are invoked transitively via `literature-ingest.sh` and require no direct integration from the new script.

#### 4. `zotero-write.sh` (238 lines) — the wrapper that needs the new operation

Current operations, each a thin `zot <verb> <key> ...` wrapper with `--dry-run` and (for `attach-file`) `--idempotency-key` support:

| Operation | `zot` call |
|---|---|
| `note-add KEY "text"` | `zot note $KEY --add "$TEXT"` |
| `tag-add KEY TAG` | `zot tag $KEY --add "$TAG"` |
| `tag-remove KEY TAG` | `zot tag $KEY --remove "$TAG"` |
| `attach-file KEY FILEPATH` | `zot attach $KEY --file $FILEPATH [--idempotency-key ...] [--dry-run]` |

Every operation requires an existing `KEY` (an existing Zotero item) — confirmed there is genuinely no create-item path today. Dependency/auth checks (lines 34-46): `zot` on `$PATH` (exit 2 if missing, install hint `uv tool install zotero-cli-cc`), `$ZOTERO_API_KEY` set (exit 2 if missing, hint `/zotero --setup` or `zot config init`). `$ZOT_DATA_DIR` is resolved from `specs/zotero-index.json`'s `.zot_data_dir` if not already exported. Exit code contract: 0 success/dry-run, 1 API/file/key error, 2 not-configured.

**A new `item-add` operation belongs here**, following this exact pattern (dependency checks already exist at the top of the file; only the `case "$OPERATION"` block needs a new arm).

#### 5. `zot` CLI (`zotero-cli-cc`) — externally researched, NOT yet reflected in this repo's docs

This is the single most important finding for the design. `zotero-cli-cc` (installed via `uv tool install zotero-cli-cc`, already the hard dependency of `zotero-write.sh`/`zotero-read.sh`/`zotero-setup.sh`) ships an **`add` subcommand** that is exactly the missing capability:

- `zot add --doi "10.1038/..."` — creates an item via Web API, resolving bibliographic metadata from **Crossref**. `--no-resolve` skips the metadata lookup (creates a DOI-only stub). A Crossref 404 still creates the item (`resolve_warning: "no_match"`); network errors during resolution still create the item (retry metadata later via `zot update`).
- `zot add --url "https://..."` — creates an item from a URL (webpage-type metadata extraction; arXiv-specific first-class support was **not confirmed** in available docs — treat arXiv as "we already have `pdf_url`+`arxiv_id`, download the PDF ourselves, then use `--pdf`" rather than relying on `--url` to understand arXiv abstract pages).
- **`zot add --pdf <local_path>`** — "Extracts DOI from the PDF, creates the item, and attaches the file" in one atomic step. This is the single call that satisfies "add the source to Zotero WITH the PDF attached" for the open-access/arXiv case, once the PDF has been downloaded locally.
- `zot add --from-file <batch>` — batch import (not needed for a single user-selected source).
- All `add`/`attach` calls require `$ZOTERO_API_KEY` (Web API, not local API) — confirmed: "writes need a Web API key," configured via `zot config init`.
- JSON envelope (stable, used already by `zotero-read.sh`'s `_parse_json_result` pattern): `{"ok": bool, "data": {...}, "meta": {...}}` on success, `{"ok": false, "error": {"code", "message", "retryable", "hint"}, "meta": {...}}` on failure. Typed exit codes: `0` success, `1` generic/API error, `2` auth error, `3` validation error, `4` not found, `5` network/rate-limit (retryable, may include `retry_after_seconds`), `6` conflict.
- `--idempotency-key` is supported on mutating commands (`add`, `attach`, `delete`), cached 24h in `$ZOT_CACHE_DIR/idempotency.db`, keyed by `(command_scope, user_key)` — safe to reuse the existing `--idempotency-key` convention `zotero-write.sh attach-file` already exposes for the new `item-add` operation (e.g. `--idempotency-key "online-ingest-<doc_id>"`).
- `zot attach` auto-detects "bridge" (local Zotero desktop plugin, stores locally, `data.stored: "local"`) vs. Web API (uploads to cloud, `data.stored: "cloud"`) routing, overridable with `--via-bridge`/`--no-via-bridge`. This is a **separate** local-write mechanism from the read-only official local API at 23119 (a community "bridge" add-on, not assumed to be installed) — the design should not depend on the bridge being present; `zotero-write.sh` already doesn't reference `--via-bridge` anywhere, so the new operation should likewise stay silent on this flag and let `zot` auto-detect.
- **Exact field names for the created item/attachment key were not confirmed from public docs** (the CLI reference page is thin on `data.*` field names for `add`). The implementer must treat this as an empirical unknown to verify directly against a `--dry-run` and then a live `zot add --pdf` call early in implementation (e.g. `jq '.data'` on the raw envelope) rather than guessing field paths.

#### 6. Local API (`127.0.0.1:23119`) — confirmed read-only, cannot create items

Cross-checked against this repo's own usage (`zotero-resolve-pdf.sh`, `zotero-export-status.sh`) — both use it **exclusively** for `GET .../items` (search/reachability probe) and `GET .../items/<key>/children` (attachment listing). External docs confirm: "Zotero 7 ships a read-only local HTTP API at localhost:23119/api/ where every endpoint is GET-only and has no write capability whatsoever... write support is planned... upcoming versions." A third-party community add-on (`zotero-local-write-api`) exists to add local write endpoints, but is not a dependency anywhere in this codebase and should not be assumed present. **Conclusion for the design**: the create-item-with-PDF capability must go through the Web API via `zot`, exactly like every other write operation `zotero-write.sh` already performs — there is no local-API shortcut available.

#### 7. `zotero-export-status.sh` (173 lines) — the honest-surfacing UX pattern to mirror

This script is the established precedent for "classify state, print exactly one directive token to stdout, write rationale to stderr, never call `AskUserQuestion` itself." Four directives: `ZOTERO_EXPORT_PRESENT`, `ZOTERO_EXPORT_MISSING_RUNNING`, `ZOTERO_EXPORT_MISSING_NOT_RUNNING`, `ZOTERO_EXPORT_UNAVAILABLE`. The calling command (`commands/literature.md` step_2, lines 128-306) branches on the token, issuing `AskUserQuestion` only when interactive and orchestrator-mode-appropriate, with an explicit non-silent "Skip this run" option always available (never a silent empty default). `commands/literature.md`'s existing Mode A step_2.4-2.5 (lines 364-397) is the **direct precedent for paywall/no-PDF UX already in place**: selected `open_access`/`paywall`/`in_zotero_no_pdf` entries currently only get a `SOURCES.md` row (`[FOUND]`/`[PAYWALL]`/`[PENDING]`) with **no sub-index update at all** ("Skip sub-index update for online/paywall sources (not yet local)" — line 389). This is exactly the gap task 866 must fill: today, selecting a Tier-3 result does nothing beyond a markdown table row.

#### 8. `zotero-resolve-pdf.sh` / `zotero-pdf-resolution.md` — reusable title-matching infrastructure

Read-only doc_id -> Zotero-PDF resolver with three access modes (`live-api`/`sqlite-readonly`/`abort`, chosen via a `curl` reachability probe + `pgrep -f zotero-bin`), a title-truncation + author-fallback search strategy, and a `MIN_SIMILARITY=0.4` floor via `.zotero-title-sim.py`. Documented pitfalls directly relevant to task 866: (a) the storage root must always be derived from `zotero-resolve-sqlite-path.sh`, never hardcoded (a known latent bug in `zotero-generate-export.sh`'s `fetch_path3()` to avoid reproducing); (b) `zotero_key`/citation-key values in `index.json`/`zotero-library.json` are not always the literal 8-char Zotero API key. This logic is the right tool for **pre-flight duplicate detection** in the online-ingest path (see Design, "Duplicate prevention").

### External Resources

- Zotero Web API write docs (`zotero.org/support/dev/web_api/v3/write_requests`, `.../file_upload`): confirms child attachments are created via `parentItem` linkage in the same or a subsequent `POST /items` call, with a two-step file-upload protocol (create attachment item metadata, then a signed upload request) when NOT going through a CLI that hides this — `zot add --pdf`/`zot attach` already abstract this two-step protocol away, so the new `zotero-write.sh item-add` operation should not reimplement it.
- Zotero local-API docs confirm read-only status (see Findings #6 above).
- `zotero-cli-cc` docs (`agents365-ai.github.io/zotero-cli-cc/`, GitHub `Agents365-ai/zotero-cli-cc`): `add`/`attach`/`note`/`tag`/`collection` commands, JSON envelope, exit-code table, idempotency semantics (see Findings #5).

### Recommendations

**Preferred shape (per task's own stated preference): a new entry point, `literature-ingest-online.sh`,** rather than overloading `literature-ingest.sh`'s argument grammar (which is currently a simple positional-path-or-`--zotero-key` shape; bolting discovery-record JSON onto it would complicate its exit-code contract). Suggested design, expressed as a step list for the planner:

1. **Input**: a single discovery-record JSON object (one element of `literature-discover.sh`'s output array), passed via stdin or `--record '<json>'`, plus flags mirroring `zotero-write.sh` (`--dry-run`, `--idempotency-key`). Do NOT require the caller to have run discovery again — `commands/literature.md`'s Mode A already holds the full JSON array in memory after the `AskUserQuestion` selection step.

2. **Classification (prints exactly one directive token to stdout, rationale to stderr — mirrors `zotero-export-status.sh`)**:
   - `status == "in_zotero_no_pdf"` -> directive `ONLINE_INGEST_EXISTING_NO_PDF` (a Tier-2 problem: resolve the existing Zotero item via `zotero-resolve-pdf.sh`-style title search, then this is an **attach-only** operation against an existing key — no create-item call at all. If no PDF URL is discoverable for this item, surface honestly and stop; do not invent one.)
   - `status == "open_access"` (arXiv or not — check `arxiv_id`/`pdf_url` presence, NOT a literal `"arxiv"` status) with a non-empty `pdf_url` -> directive `ONLINE_INGEST_RESOLVABLE`, proceed to download.
   - `status == "paywall"`, or `open_access` with no usable `pdf_url` -> directive `ONLINE_INGEST_NO_PDF`. No download is attempted. Surface honestly (mirrors the existing `[PAYWALL]` SOURCES.md row) and exit non-zero; the calling command falls back to today's SOURCES.md-only behavior.

3. **Download + verify** (only for `ONLINE_INGEST_RESOLVABLE`): `curl -sL --fail --max-time 30 -o <staging_path> "$pdf_url"`. **Must** verify the downloaded bytes actually start with `%PDF` (`head -c4`) before treating this as success — many "open_access" `pdf_url` values resolve to a cookie-wall/landing HTML page rather than raw PDF bytes, and silently creating a Zotero attachment from an HTML file would be exactly the "fabricated download" the task explicitly prohibits. On magic-byte mismatch or non-2xx/curl failure, emit `ONLINE_INGEST_DOWNLOAD_FAILED` and stop — never fall through to item creation with a bad file.

4. **Duplicate check** (recommended, not yet implemented anywhere): before creating a new Zotero item, do a quick title-similarity check against the global `index.json` (already-ingested docs) using the same `.zotero-title-sim.py` helper `zotero-resolve-pdf.sh` uses, to avoid double-creating a Zotero item for a paper already ingested through a prior discovery pass. This is a design recommendation for the planner to size, not a hard requirement of this research task.

5. **Zotero create-item-with-PDF** (the literally-new capability): a new `zotero-write.sh item-add` operation:
   ```
   zotero-write.sh item-add --pdf <staging_path> [--doi <doi>] [--idempotency-key <key>] [--dry-run]
   ```
   wrapping `zot add --pdf "$FILEPATH"` (single atomic create+attach call — preferred over the two-step `zot add --doi` + `zot attach` because it lets `zot`'s own DOI-from-PDF extraction correct/confirm metadata rather than trusting Semantic Scholar's DOI blindly). Falls back to `zot add --doi "$DOI"` (item only, no attachment) if, for some reason, only a DOI is available and no PDF was downloaded — but this path must still surface "no PDF attached" honestly rather than silently declaring success. Follow the exact existing patterns for dependency checks (`zot` on PATH, `$ZOTERO_API_KEY` set), `--dry-run` (echo the would-be `zot` invocation), and `--idempotency-key` passthrough already established by `attach-file`.

6. **Re-point to the durable copy**: `zot add --pdf` causes Zotero to copy the file into its own `storage/<attachmentKey>/<filename>` tree (the same tree `zotero-resolve-pdf.sh` already knows how to derive via `zotero-resolve-sqlite-path.sh`). After item creation, resolve that storage path and use **it** (not the ephemeral staging download) as the file passed to `literature-ingest.sh`, so `source_path`/`zotero_path` in the resulting index entry point at a permanent location rather than a temp file that will be cleaned up. This mirrors `literature-index.md`'s existing `zotero_path` field semantics ("Absolute path to PDF in Zotero storage") exactly.

7. **Reuse the existing pipeline unmodified**: `literature-ingest.sh "$zotero_storage_pdf_path" --no-local` (let the calling command decide `--local`/interactive per its own UX, exactly as Mode B already does). This is a hard requirement from the research: do not duplicate convert/chunk/quality-gate/index-rebuild logic in the new script.

8. **Patch the resulting global `index.json` entry** (closes the metadata gap in Findings #2): after `literature-ingest.sh` exits 0 and reports the ingested `doc_id`, do a small `jq` patch merging in `title` (real, from the discovery record — not the placeholder `DOC_ID`), `authors`, `year`, `doi`, `arxiv_id`, `zotero_key`, `zotero_path`. This should be scoped as new logic in `literature-ingest-online.sh` itself (a targeted post-ingest patch), not a change to `literature-ingest.sh`'s core loop — keeps the blast radius small and avoids touching a script three other paths depend on.

9. **Per-repo sub-index registration**: once ingestion succeeds, add an entry to `specs/literature-index.json` (`doc_id`, `relevance`, `added`, `source: "discover"`) using the exact same jq-upsert sketch already present in `commands/literature.md` step_2 (lines 391-397) for "available"/"in_zotero" entries — this task's job is to extend that same code path to also cover successfully-online-ingested entries, rather than leaving them permanently excluded per today's "Skip sub-index update for online/paywall sources" comment.

10. **Command-level wiring** (`commands/literature.md`, `EXTENSION.md`): Mode A's existing step 4/5 (SOURCES.md + sub-index update) needs a new branch: for user-selected `open_access`/`arxiv-flavored`/`paywall`/`in_zotero_no_pdf` entries, offer (via `AskUserQuestion`, consistent with the existing pattern) "Ingest into Literature now" vs. "Just record in SOURCES.md" (today's only behavior, kept as the default/fallback). Only entries where the user opts in invoke `literature-ingest-online.sh`. `EXTENSION.md`'s script table needs a new row for `literature-ingest-online.sh` (and the new `zotero-write.sh item-add` operation should be mentioned in its existing `zotero-write.sh` row description, currently "Write/attach files to Zotero items" — should become "Write/attach files to Zotero items; create new items with PDF attachment").

## Decisions

- **Reuse `zot add` rather than building raw Web API calls.** This is the single highest-leverage finding: it turns "new create-item capability" from a multi-endpoint Web API integration (auth, versioning headers, two-step file upload protocol) into a ~15-20 line new `case` arm in `zotero-write.sh`, following an established pattern.
- **Treat "arxiv" as a derived condition (`status=="open_access" && arxiv_id != null`), not a literal status value**, since that is what `literature-discover.sh` actually emits.
- **`in_zotero_no_pdf` is an attach-to-existing-item problem, solvable with today's `attach-file` operation** (once the citation_key is resolved to a real Zotero key via existing `zotero-resolve-pdf.sh`-style logic) — it does not require the new create-item capability at all. The planner should size this as a smaller, separable sub-path from the `open_access`/arXiv create-item path.
- **New entry point (`literature-ingest-online.sh`), not an extension of `literature-ingest.sh`'s argument grammar.** Delegates to the unmodified `literature-ingest.sh` for convert/chunk/index once a PDF and Zotero item exist.
- **Directive-token classification pattern, mirroring `zotero-export-status.sh`**, for honest paywall/no-PDF surfacing — no silent no-ops, no fabricated downloads, magic-byte verification (`%PDF`) required before any file is treated as a successful download.

## Risks & Mitigations

- **Risk**: `zot add`'s exact `data.*` JSON field names for the created item/attachment key are not confirmed from public docs (thin CLI reference page). **Mitigation**: implementation phase must empirically verify via `--dry-run` and a live low-stakes call (`jq '.data'` on the raw envelope) before wiring downstream logic that depends on specific field paths; do not guess field names in the plan.
- **Risk**: `pdf_url` values from Semantic Scholar/Unpaywall/arXiv can resolve to non-PDF content (landing pages, cookie walls, 403s serving an HTML error page with a 200 status). **Mitigation**: mandatory magic-byte (`%PDF`) check after download, before any Zotero item creation is attempted; treat any mismatch as `ONLINE_INGEST_DOWNLOAD_FAILED`, never as success.
- **Risk**: Creating duplicate Zotero items for papers already in the library (missed by Tier 1/2 due to a stale `zotero-library.json` snapshot — a documented staleness issue in `zotero-pdf-resolution.md` finding #4). **Mitigation**: recommend (not mandate) a pre-create title-similarity check against `index.json` using the existing `.zotero-title-sim.py` helper; flag as a sizing decision for the planner rather than a hard requirement, since Tier 1/2 already run before Tier 3 in `literature-discover.sh` and reduce (without eliminating) this risk.
- **Risk**: `literature-ingest.sh`'s re-ingestion warning (`rm -rf "$DOC_DIR"` on doc_id collision) could delete a legitimately-converted prior ingestion if the online path derives the same `doc_id` from a differently-cased or differently-punctuated title. **Mitigation**: no new risk introduced beyond what already exists in `literature-ingest.sh`; the online path should derive `doc_id` the same way (from the resolved filename) so behavior stays consistent, and this is out of scope to fix in task 866.
- **Risk**: The Zotero storage re-pointing step (item 6 in Recommendations) assumes `zot add --pdf` actually copies the file into `storage/<key>/` synchronously and that path is immediately readable. **Mitigation**: implementation should verify this empirically (a `zot read`/local sqlite check of the new item's attachment path) before relying on it; if unreliable, fall back to using the original staging download path directly (accepting that `source_path` may point at a location outside the corpus's control) and flag this as a follow-up.

## Context Extension Recommendations

- **Topic**: `zot add` command surface and JSON envelope field names.
- **Gap**: This repository's `context/project/literature/` docs describe `zotero-read.sh`/`zotero-write.sh`'s existing operations but do not document `zot`'s underlying `add` capability at all (reasonable, since it was unused until now) — once task 866 lands, a short addition to `zotero-pdf-resolution.md` or a new `zotero-create-item.md` pattern doc (documenting the empirically-confirmed `data.*` field names, the magic-byte download-verification gate, and the storage re-pointing step) would prevent future tasks (867/868) from re-deriving this research.
- **Recommendation**: Create `context/project/literature/patterns/zotero-item-creation.md` as part of (or immediately after) task 866's implementation, once the `zot add --pdf` envelope fields are empirically confirmed.

## Appendix

### Search queries used
- WebSearch: "zotero-cli-cc zot CLI create item command uv tool"
- WebSearch: "Zotero Web API POST /items create item with attachment child"
- WebSearch: "Zotero local HTTP API 127.0.0.1:23119 create item POST write support"
- WebSearch: `"zot add" arxiv zotero-cli-cc "--url" OR "--arxiv" metadata resolution`
- WebFetch: `agents365-ai.github.io/zotero-cli-cc/`, `.../reference/cli/`, GitHub `Agents365-ai/zotero-cli-cc` README, `docs/agent-interface.md`

### Key files read
- `agent-system/extensions/literature/scripts/literature-discover.sh` (full, 630 lines)
- `agent-system/extensions/literature/scripts/literature-ingest.sh` (full, 422 lines)
- `agent-system/extensions/literature/scripts/zotero-write.sh` (full, 238 lines)
- `agent-system/extensions/literature/scripts/zotero-export-status.sh` (full, 173 lines)
- `agent-system/extensions/literature/scripts/zotero-read.sh` (full, 210 lines)
- `agent-system/extensions/literature/scripts/zotero-setup.sh` (full, 300 lines)
- `agent-system/extensions/literature/scripts/zotero-resolve-pdf.sh` (full, 350 lines)
- `agent-system/extensions/literature/scripts/literature-convert.sh`, `literature-chunk.sh`, `literature-build-index.sh` (headers/interfaces)
- `agent-system/extensions/literature/commands/literature.md` (Mode A discover flow, lines 1-430)
- `agent-system/extensions/literature/EXTENSION.md` (full, 117 lines)
- `agent-system/extensions/literature/context/project/literature/patterns/zotero-pdf-resolution.md` (full)
- `agent-system/extensions/literature/context/project/literature/domain/literature-index.md` (full)
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` (Ingest mode section)
- `agent-system/extensions/literature/scripts/literature-fidelity-audit.sh` (header/enum only)

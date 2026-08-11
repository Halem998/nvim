# Zotero Metadata Resolution Upgrade: Codebase-Grounded Design

- **Task**: 39 - Upgrade Zotero metadata resolution and plan the Zotero 10 backend swap
- **Started**: 2026-08-11
- **Completed**: 2026-08-11 (design pass; live-verification pass appended same day at
  2026-08-11T21:46-21:49 UTC, after `~/.dotfiles` task 129's provisioning work completed in full)
- **Effort**: 3-6 hours (estimate carried from task description)
- **Dependencies**: 38 (write-back path activation, completed); `~/.dotfiles` task 129
  (machine-level tooling provisioning, completed same day — see the Live Verification section)
- **Sources/Inputs**: `reports/01_zotero-tooling-landscape.md` (seed, web research); the
  just-completed predecessor task's summary
  (`specs/038_activate_zotero_write_back_path/summaries/02_zotero-write-back-activation-summary.md`);
  live reading of `agent-system/extensions/literature/scripts/literature-ingest-online.sh`,
  `zotero-write.sh`, `zotero-export-freshness.sh`, `literature-discover.sh`, and
  `context/project/literature/patterns/zotero-item-creation.md` /
  `domain/zotero-integration.md`; `~/.dotfiles`'s task 129 plan/summary; live probes of `zot`,
  `zotero-export-freshness.sh`, `zotero-read.sh`, `ss`, and `systemctl --user` (see Live
  Verification section)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The seed report's landscape claims (translation-server endpoints, zotero-mcp status, the
  quota-check impossibility, Zotero 10 local-API shape) are treated as verified and are not
  re-derived here — see that report for citations.
- **Translation-server integration point identified precisely**: the create-item branch of
  `literature-ingest-online.sh` (`CLASSIFICATION == "resolvable"`, around line 679) currently
  discards the discovery record's own `TITLE`/`AUTHORS_JSON`/`YEAR_JSON` for Zotero-item purposes
  — it only ever passes `--doi` to `zot add --pdf`, and `zot add --pdf`'s own metadata
  auto-resolution (Crossref) fires only when `--doi` is present. An **arXiv-only record** (no DOI,
  which is the common case for preprints) therefore creates a "bare" Zotero item today with no
  title/author/date at all, even though the discovery record already carries all three from
  Semantic Scholar. This is the concrete instance of "the pipeline's thinnest point" the seed
  report names in the abstract.
- Because `zot add`/`zotero-write.sh item-add` has no verb that accepts a full Zotero JSON item
  body — only `--pdf` and `--doi` — using translation-server's resolved metadata requires a **new
  `zotero-write.sh` operation** (recommended name: `item-add-json`) that POSTs a pre-built Zotero
  JSON item directly, rather than routing through `zot add`'s own resolution. This is a real,
  non-trivial addition, not a one-line wiring change — recorded here as a design decision for the
  plan phase, not implemented in this research pass.
- **Quota gate design**: since a preflight check is impossible (confirmed in the seed report), the
  recommendation is a **reactive-cache + config-override hybrid**: parse `used`/`limit` MB out of
  a `413`'s error message the first time one occurs, persist it alongside the existing
  `ZOT_DATA_DIR` pointer in `specs/zotero-index.json`, and consult that cache before every
  `attach-file`/`item-add --pdf` call to skip attachment attempts pre-emptively once known-over-quota
  — closing the orphaned-attachment-record side effect confirmed by the predecessor task, since a
  skipped attempt never creates the empty attachment-record child in the first place.
- **Zotero 10 swap plan**: names `zotero-write.sh` as the sole choke-point (already established),
  specifies exactly which internals change (backend selection between `zot`/Web-API and a future
  local-API POST path) versus what stays constant for every caller (operation names, argument
  shapes, stdout envelope passthrough), and explicitly rejects `/connector/saveItems`.
- **MCP decision recorded**: **defer** adoption of `54yyyu/zotero-mcp` for now, revisit once
  Zotero 10 stabilizes (see rationale in Work Item 2 below). No MCP registration or grant changes
  are made in this repository either way — that is exclusively `~/.dotfiles` territory.
- **Live-verification pass (see dedicated section below)**: performed after `~/.dotfiles` task
  129 finished provisioning `zot`, credentials, and an optional translation-server. Confirms `zot`
  is live and credentialed; **corrects** this report's own earlier claim that no delete/cleanup
  capability exists for Work Item 3's orphaned-attachment problem — `zot` in fact ships `delete`,
  `orphans clean`, and `trash list/restore`, which simplifies that design; reconfirms the storage
  quota state is unverifiable without an out-of-scope write (last known: over quota, unchanged);
  reconfirms `--via-bridge` is still unavailable (Zotero desktop not running); confirms
  translation-server is correctly disabled by default but that its `/search` endpoint was already
  live-verified with a real DOI during provisioning, while `/web` remains genuinely untested by
  anyone; and confirms `zotero-mcp` is not registered anywhere on this machine, grounding the
  defer decision in fact.

## Context & Scope

This is task 39's research pass, resuming after a prior dispatch gathered findings (recorded in
the seed report, `reports/01_zotero-tooling-landscape.md`) but terminated before persisting a
second artifact or updating `.return-meta.json`. This report supplies the codebase-side half of
the research the task description asks for: where exactly the seed report's external-tooling
findings connect to this repository's actual scripts and docs. No code or doc files are modified
in this pass — task 39 is at `[RESEARCHING]`; the design here is input to `/plan 39`, not an
implementation.

All four work items from the task description are addressed. Findings from task 38's live test
(quota state, sync-lag, orphaned attachment records, the confirmed `.data.key` field, the
unconfirmed attachment-key candidates) are treated as ground truth and are not re-verified here.

## Findings

### Work Item 1: translation-server integration

**Exact insertion point.** In `literature-ingest-online.sh`'s resolvable (create-item) branch
(`literature-ingest-online.sh:679-729`), the sequence today is: `check_export_freshness` ->
`resolvable_predownload_checks` (DOI-normalized dedup) -> `check_duplicate_title` ->
`download_and_verify` (the PDF) -> `zotero-write.sh item-add --pdf <staged> [--doi <doi>]` ->
`resolve_storage_path_from_envelope` -> `run_ingest_pipeline`. A translation-server resolution
step belongs **after `resolvable_predownload_checks` (dedup) and before `download_and_verify`**,
for two reasons: (1) dedup should run first regardless of resolution outcome, since it is cheap
and a confirmed duplicate should hard-stop before any network fetch of either kind; (2) the
translation-server call is itself independent of the PDF download (it resolves bibliographic
metadata only — the seed report already establishes translation-server never touches PDFs), so
resolving metadata first lets the later `zot add` call receive a `--title`/richer identity even if
the PDF download subsequently fails (though in that case the script still stops at
`ONLINE_INGEST_DOWNLOAD_FAILED` with no Zotero write, unchanged from today's contract).

**Which endpoint, and when.** The record already carries exactly the fields translation-server's
two endpoints key on:
- `DOI_RAW` or `ARXIV_ID_RAW` present -> `POST /search` with that identifier as the plain-text
  body (per the seed report, no auth, `Content-Type: text/plain`).
- Neither present but a source URL exists -> `POST /web` (this repository's discovery pipeline,
  per `literature-discover.sh` tier3_search(), only ever surfaces `doi`/`arxiv_id`/`pdf_url` from
  Semantic Scholar — there is currently no raw landing-page URL field on a Tier-3 record distinct
  from `pdf_url`. Practically, `/search` is the endpoint that matters for today's discovery
  shape; `/web` becomes relevant only if a future discovery tier adds a general web-URL source,
  which is out of this task's scope. This asymmetry should be stated plainly in the doc update
  rather than implying `/web` is wired symmetrically with `/search` when it currently has no
  caller path.)

**Why this closes a real, not hypothetical, gap.** `zot add --pdf`'s own metadata auto-resolution
(documented in `patterns/zotero-item-creation.md` section 1) is Crossref-only and fires only when
`--doi` is passed. An arXiv preprint discovered via Tier 3 (common case: `arxiv_id` set, `doi`
often *not* set — arXiv preprints frequently have no registered DOI) hits `zot add --pdf
<staged>` with **no** `--doi` today, producing a bare, metadata-less Zotero item — even though
`TITLE`/`AUTHORS_JSON`/`YEAR_JSON` are sitting unused in the script's own variables (currently
consumed only by `check_duplicate_title()` and the post-ingest `patch_global_index()` call, never
passed to Zotero item creation itself). This is the literal instance of "pipeline's thinnest
point," not just an abstract description.

**The capability gap this creates.** `zotero-write.sh item-add`'s only inputs are `--pdf` and
`--doi` (`zotero-write.sh:14-23, 285-326`) — there is no path to hand it a fully-formed Zotero
JSON item body. Making translation-server's resolved metadata actually land in the created item
therefore requires a **new operation**, not a new flag on the existing one (a new flag would still
have to funnel through `zot add`, which does not accept a raw item body either). Recommended
design for the plan phase:
- New `zotero-write.sh` operation `item-add-json` taking a Zotero JSON item body (from
  translation-server's `/search` response, item 0 of the returned array) via `--record-json
  <json>` or stdin, POSTed directly to the Web API's item-create endpoint (bypassing `zot add`'s
  own DOI-driven Crossref path entirely, since the record already has richer/more precisely-typed
  metadata than Crossref alone would return for a preprint). The PDF attachment step becomes a
  **separate, explicit second call** to the existing `attach-file` operation once the item key is
  known — decomposing the current single atomic `item-add --pdf` call into two calls only for this
  path, while the existing `--doi`/`--pdf`-only path is left completely unchanged.
- `literature-ingest-online.sh` gains a `resolve_via_translation_server()` helper mirroring the
  existing `check_export_freshness()` shape: one HTTP call, one classification, globals set,
  never more than a warning on failure.

**Graceful-degradation seam.** Every existing "unknown service state" helper in this codebase
(`check_export_freshness()`, and `zotero-export-freshness.sh` itself) follows the same idiom:
attempt the call, capture stderr, treat *any* non-success (including connection refused) as "not
confirmed" rather than a hard stop, and always fall through to the next-best behavior rather than
failing the whole run. The translation-server call should follow this exactly:
```bash
resolve_via_translation_server() {
  local identifier="$1" endpoint="${TRANSLATION_SERVER_URL:-http://localhost:1969}"
  local resolved rc=0
  resolved="$(curl -s --max-time 5 --fail -H 'Content-Type: text/plain' \
    --data "$identifier" "$endpoint/search" 2>/tmp/ts-stderr.$$)" || rc=$?
  local stderr_out; stderr_out="$(cat /tmp/ts-stderr.$$ 2>/dev/null || true)"; rm -f /tmp/ts-stderr.$$
  if [ "$rc" -ne 0 ] || ! echo "$resolved" | jq -e '.[0]' >/dev/null 2>&1; then
    log "WARNING: translation-server unreachable or returned no match for $identifier (exit $rc): $stderr_out -- falling back to zot add's own --doi/Crossref resolution (or a bare --pdf-only create if no DOI)."
    TRANSLATION_SERVER_RESOLVED=""
    RESOLUTION_PATH="zot-crossref-or-bare"
    return 1
  fi
  TRANSLATION_SERVER_RESOLVED="$(echo "$resolved" | jq -c '.[0]')"
  RESOLUTION_PATH="translation-server"
  return 0
}
```
A **5-second timeout** (not the 30s used for PDF downloads) is deliberate: translation-server is a
local/trusted-network service per the seed report, so a slow or absent response should fail fast
rather than stall the whole ingest call. `curl --fail` distinguishes "service down" (connection
refused / timeout, `rc != 0`) from "resolved but empty" (200 with `[]`, which the `jq -e '.[0]'`
check also catches) — the seed report notes the README doesn't document the no-match status
code, so treating both as the same non-fatal degradation avoids depending on an unconfirmed
status code (this is the honest-surfacing move: do not assume 404/501 behavior that isn't
independently confirmed).

**Honest surfacing of which resolution path produced each record.** A `RESOLUTION_PATH` value
(`"translation-server"` | `"zot-crossref-or-bare"` | `"zot-crossref"` for the pre-existing
`--doi`-only path) should be threaded into `patch_global_index()`'s per-entry metadata (a new
`resolution_path` field on the `index.json` entry, alongside the existing `zotero_key`/
`zotero_path`) so a future reader of the corpus index can tell which records got
translation-server-quality metadata versus which fell back to zot's bare or Crossref-only path.
This directly satisfies the task's acceptance criterion "honest surfacing of which resolution
path was used."

**Non-goal reaffirmed.** Neither `literature-ingest.sh` nor any of its delegated
convert/chunk/index scripts change — translation-server output only ever feeds the *Zotero
item-creation* step, exactly as `literature-ingest-online.sh`'s existing NON-GOALS section already
scopes for this file.

### Work Item 2: zotero-mcp adoption decision

**Decision: defer.** Rationale, grounded in what this repository's pipeline already does well and
where zotero-mcp would actually add value:

- The deterministic-scripts-are-pipeline-of-record / MCP-is-interactive-complement split the seed
  report describes as 2026 community practice is sound, but zotero-mcp's core write value-add
  (add-by-DOI/URL/ISBN, OA-PDF cascade) **duplicates capability this repository's own
  `literature-discover.sh` + `literature-ingest-online.sh` pair already implements** end-to-end
  (Semantic Scholar + Unpaywall + arXiv cascade, DOI-normalized live dedup, magic-byte-verified
  downloads) with this codebase's specific honest-surfacing and dedup invariants that a generic
  MCP tool would not know about or honor. Adopting zotero-mcp for interactive "find and add"
  sessions risks an agent using it to add an item through a path that bypasses this repository's
  dedup guard and index-patching, silently drifting `specs/literature-index.json` and
  `index.json` out of sync with the Zotero library.
- The one thing zotero-mcp offers that this repository's scripts do not — semantic
  search over the full library (embeddings-based, not just CSL-JSON keyword/title search) — is a
  genuine gap, but it is a **read-side** gap only, and the current write-path work (this task, and
  task 38 before it) has not yet stabilized (attachment-key paths still unconfirmed per the
  predecessor task; storage quota already exhausted). Adding a second write surface (even an
  interactive one) before the one write surface this repository owns (`zotero-write.sh`) is fully
  hardened compounds exactly the kind of drift risk task 38's write-path work was trying to close.
- Zotero 10's native local-write API (Work Item 3) will likely also obsolete zotero-mcp's
  "hybrid mode" value proposition specifically (local-API reads + Web-API writes) once it reaches
  the same backend this repository's own swap plan targets — re-evaluate together with the Zotero
  10 stabilization checkpoint rather than as a separate decision now.
- If adopted later, registration and permission grants land exclusively in the user's
  `~/.dotfiles` Claude configuration per the grant-at-registration-scope principle already
  established there — this repository would never hand-edit an MCP registration regardless of the
  adopt/defer outcome.

**Recorded as a decision, not a re-opened question**: this defers reconsideration until either
(a) Zotero 10 stabilizes and the swap plan (Work Item 3) is executed, or (b) a genuine
read-side/semantic-search need arises that this repository's own tooling cannot cheaply provide.

### Work Item 3: storage-quota gate

**The concrete failure mode to close.** The predecessor task's live test (documented in
`patterns/zotero-item-creation.md` section 2 and the task 38 summary) confirmed: a `413` on
either `item-add`'s internal attach or a standalone `attach-file` call leaves an **orphaned,
file-less attachment child item** behind (`itemType: attachment`, `linkMode: imported_file`, `md5:
null`) — Zotero's attach flow creates the child metadata record in one call, then uploads bytes in
a second call, and the first call is not rolled back when the second is rejected. Two such orphans
already exist in the production library (`5J2WMXDD`, `CB99228V`) as a direct side effect of that
test.

**Why a preflight check is impossible (confirmed, not re-derived) and what that implies for
design.** The seed report already establishes there is no Web API v3 endpoint for quota
state — only the human-only account-settings page, or a `413`'s error message. The gate must
therefore be **reactive** (learn the ceiling from a failure, remember it) or **config-driven**
(an operator states an assumed ceiling). The recommendation is both, layered:

1. **Reactive-cache layer** (primary, requires-no-operator-input): the `413` error body
   (confirmed shape in the predecessor task: `{"ok": false, "error": {"code", "message",
   "retryable", "hint", "context"}}`, with the human-readable `"File would exceed quota (2745.6 >
   300)"` string inside `.error.message`) is parsed for the two MB numbers on first occurrence, and
   the result (`{used_mb, limit_mb, checked_at}`) is persisted to `specs/zotero-index.json`
   (the same file `zotero-write.sh` already reads for `zot_data_dir` at
   `zotero-write.sh:79-84`, so no new file needs inventing) under a new top-level `quota_state`
   key. Every subsequent `attach-file`/`item-add --pdf` call in `literature-ingest-online.sh`
   consults this cache *before* attempting the write: if `used_mb >= limit_mb`, skip the
   attachment attempt entirely (create the item DOI/metadata-only, or skip attach-to-existing, and
   surface "no PDF attached (quota exhausted, cached MM/DD check)" honestly) rather than
   attempting and failing — this is what actually closes the orphan-creation side effect, since a
   skipped attempt never reaches Zotero's create-child-record-then-upload two-step at all.
2. **Config-driven override layer** (secondary, operator-set): an optional
   `ZOTERO_ASSUMED_QUOTA_MB` environment variable (or a `quota_limit_mb` field alongside
   `quota_state` in `zotero-index.json`) that an operator can set manually after checking the
   human-only account page or upgrading the plan — explicitly labeled "assumed, not verified via
   API" in any log line that consults it, so it is never confused with a value the reactive layer
   actually observed.
3. **Staleness handling**: since the cache can only be refreshed by another `413` (there is no way
   to proactively confirm the quota has been freed), a cached over-quota state should carry a
   configurable max-age (recommend 24h) after which it is treated as "unknown again" and the
   *next* attach attempt is allowed to actually try (and, if it still fails, immediately
   re-caches) — this bounds how long a stale "known over quota" skip can outlive an actual
   plan upgrade or cleanup, without requiring any new proactive-check capability that does not
   exist.

**Cleanup requirement — UPDATED by live verification (see the dedicated section below; this
paragraph originally recorded a gap that live probing has since closed).** A live `zot --help`
run confirms `zot` ships exactly the capability this section originally flagged as unconfirmed:
`zot delete KEY [KEY...]` (move to trash, `--dry-run`/`--idempotency-key` supported), `zot orphans
clean` ("Delete orphaned attachment records via the Web API" — a purpose-built match for the two
existing orphans), and `zot trash list/restore` for non-destructive recovery. **Revised
recommendation**: add a thin `zotero-write.sh orphan-clean` operation wrapping `zot orphans
clean` directly (same wrapper shape as every other `zotero-write.sh` operation) — no new
Web-API-`DELETE`-plus-version-lookup design is needed, since `zot` already owns that complexity.
The live verification section below also documents a real, currently-active limitation on
applying this today: `zot orphans clean`/`list` are local-SQLite reads like every other `zot`
read command, and the two known orphans from the predecessor task have not synced locally yet
(confirmed live), so the capability is real but not yet actionable against those specific two
orphans until a desktop client syncs. Automated cleanup should still be **best-effort and
non-blocking**: a failed or no-op cleanup attempt must not itself hard-stop the ingest run.

**Content-hash dedup note carried forward.** The seed report's `{"exists": 1}` upload-flow
dedup applies only once a file upload is actually attempted — it is irrelevant to the pre-emptive
skip above (which never reaches the upload step) but remains relevant documentation for the case
where quota headroom exists and an attach is genuinely attempted.

### Work Item 4: Zotero 10 backend-swap plan

**Choke-point restated precisely.** `zotero-write.sh` is the single script every write path in
this extension calls through (`literature-ingest-online.sh` never calls `zot` directly; neither
does any other script in the inventory) — this was already established by task 38's activation
work and is unchanged here. The swap plan's job is to say exactly what inside that one file
changes and what every caller can keep assuming.

**What changes (internal to `zotero-write.sh` only).**
- A backend-selection step at the top of the script (after the existing `zot`-installed and
  `ZOTERO_API_KEY` checks): detect whether `localhost:23119/api/` is reachable and whether a
  local API key has been obtained (via the beta's `POST /api/local/authorize` consent flow,
  per the seed report — a one-time, user-facing authorization, analogous to the existing
  `ZOTERO_API_KEY` setup step `zotero-setup.sh` already performs for the Web API key). When both
  are true and Zotero 10 is the pinned stable version, route `note-add`/`tag-add`/`tag-remove`/
  `attach-file`/`item-add`(-json) through local-API POST/PUT/PATCH/DELETE calls instead of `zot`.
  When either is false, fall back to today's `zot`-via-Web-API path unchanged — this is the same
  "attempt, fall back, log the fallback" idiom already used by `check_export_freshness()` and the
  translation-server helper above, not a new pattern.
- File uploads via the local API are full-file PUT (no partial/binary-diff per the seed report),
  and do not count against the zotero.org storage quota — meaning the Work Item 3 quota gate
  above becomes conditionally bypassable once this backend is active (the gate itself does not
  need to change; the local-API path just never triggers a `413` in the first place, so the
  reactive-cache layer's "quota exhausted" state simply won't recur under that backend, and its
  config-driven override layer would report "not applicable" whenever the local-API backend is
  selected).

**What stays constant for every caller (contract preserved).**
- Every existing `zotero-write.sh <operation> <key> [options...]` invocation shape, exit-code
  table (0/1/2), `--dry-run`/`--idempotency-key` flag semantics, and the stdout-envelope-passthrough
  contract (`zotero-write.sh` never parses `zot`'s or the local-API's JSON itself; the caller does,
  exactly as documented in `zotero-write.sh`'s own header comment today).
- `literature-ingest-online.sh`'s `extract_envelope_field()`/`resolve_storage_path_from_envelope()`
  multi-path probing continues to matter: a local-API item-create response's field names are not
  yet independently confirmed either (Zotero 10 is beta, no live call has been made against it in
  this repository), so the defensive multi-candidate lookup pattern extends naturally rather than
  needing a rewrite when the backend switches.

**Explicit rejection recorded.** `/connector/saveItems` is rejected as a write contract: per the
seed report it is an undocumented internal protocol (docs stub last touched Dec 2025), writes into
whatever collection happens to be selected in the Zotero UI at call time (a hidden,
caller-uncontrollable side channel incompatible with this extension's explicit-item-key/explicit-
collection discipline), and has drifted between Zotero versions historically — none of which is
true of the documented, versioned local API at `localhost:23119/api/`.

**Not performed now.** Per the task description, this plan is recorded, not executed: Zotero 10 is
still beta (no published stable-release date per the seed report), and switching backends before
stabilization would risk building against an API surface that still moves.

**Doc placement.** This swap plan, plus the quota-gate design and the resolution-path fields,
belong in `context/project/literature/domain/zotero-integration.md` (a new "Backend Swap Plan
(Zotero 10)" section) and `context/project/literature/patterns/zotero-item-creation.md` (extending
its existing envelope-field-confirmation discipline to the new `item-add-json` operation and the
resolution-path surfacing), per this task's `file_scope`. `README.md`'s script inventory table
gains one row once `item-add-json`/`item-delete` are actually implemented in a later phase.

## Decisions

- Translation-server integration point: after dedup, before PDF download, in the create-item
  branch of `literature-ingest-online.sh`; `/search` is the only endpoint with a live caller path
  given today's discovery-record shape (`/web` documented but currently unreachable from this
  pipeline).
- A new `zotero-write.sh item-add-json` operation is required — the existing `item-add`
  (`--pdf`/`--doi` only) cannot carry translation-server's resolved metadata.
- zotero-mcp adoption: **deferred**, re-evaluate alongside Zotero 10 stabilization.
- Quota gate: reactive-cache (parsed from `413` bodies, stored in `specs/zotero-index.json`) +
  operator-settable override, with a 24h staleness bound on the cached over-quota state.
- Orphan cleanup after a `413`: **confirmed live** (see Live Verification) that `zot orphans
  clean` already exists purpose-built for this — a thin `zotero-write.sh orphan-clean` wrapper
  around it, not a new Web-API-`DELETE` design, is the recommended mechanism.
- Zotero 10 swap: `zotero-write.sh` gains an internal backend-selection step; every external
  contract (operation names, flags, exit codes, envelope passthrough) is preserved.
  `/connector/saveItems` is rejected as a contract.

## Risks & Mitigations

- **Resolved by live verification**: `zot` does support delete/orphan-cleanup (`zot delete`, `zot
  orphans clean`, `zot trash list/restore` — confirmed via a live `zot --help` run). The residual
  risk is narrower than originally stated: `zot orphans clean` operates on the local-SQLite view,
  same as every other `zot` read/write command, so it cannot act on an orphan until a desktop
  client has synced it down — confirmed live against the two known orphans from the predecessor
  task, which are still invisible to `zot orphans list` for exactly this reason. The plan phase
  should design the `orphan-clean` wrapper knowing this latency exists, rather than assuming
  immediate cleanup after every `413`.
- **`item-add-json` decomposes the current atomic `item-add --pdf` call into two calls** (create,
  then attach) for the translation-server path only. This reintroduces exactly the
  partial-success surface task 38 already had to handle for the existing atomic path (a
  successful create with a failed attach) — the plan phase should reuse the existing
  orphan-detection and honest-surfacing pattern (`.data.next`, `.data.attachment_error`) rather
  than inventing a new one, and should apply the Work Item 3 quota pre-check before attempting the
  attach half.
- **Translation-server's undocumented no-match behavior** (seed report: neither a confirmed 404
  nor 501) means the resolution helper above treats *any* non-2xx or empty-array response as
  "not resolved, fall back" without trying to distinguish "no match" from "malformed request" —
  acceptable because both outcomes lead to the same fallback action, but worth re-confirming
  empirically once a real translation-server instance is reachable from this environment (it was
  not reachable during this research pass; ~/.dotfiles task 129 provisions it).
- **Reactive quota cache can go stale in the optimistic direction** (operator upgrades the plan or
  frees space, but the cache still says "over quota" for up to 24h) — accepted trade-off, bounded
  by the staleness window; the alternative (no expiry) would require a manual cache-clear step,
  which is more operator burden for a bounded, self-correcting inaccuracy.

## Context Extension Recommendations

- **Topic**: `zot` CLI delete/trash/orphan-cleanup capability. **Gap**: no context file documents
  that `zot` supports item/attachment deletion — `tools/zotero-scripts.md`'s inventory table and
  both `zotero-write.sh`/`zotero-read.sh` are silent on `zot delete`/`zot orphans`/`zot trash`,
  which live verification (see below) now confirms exist and directly fit Work Item 3's cleanup
  need. **Recommendation**: add a row to `tools/zotero-scripts.md` and a short subsection to
  `patterns/zotero-item-creation.md` documenting the `orphan-clean` wrapper once implemented,
  including the local-sync-lag caveat that limits when it can act.
- **Topic**: `zot duplicates` native dedup command. **Gap**: `zotero-integration.md` documents
  this repository's own bespoke DOI-normalized dedup check but not `zot`'s built-in
  `zot duplicates --by doi|title|both` command, which live verification confirmed works
  correctly against the real library. **Recommendation**: add a one-line mention in
  `zotero-integration.md`'s "Related" section as an operator-facing whole-library dedup sweep
  tool, distinct from (not a replacement for) the ingest bridge's own pre-write check.

## Live Verification (2026-08-11, post-provisioning)

**Timing note**: the cross-repo provisioning task this section depends on
(`~/.dotfiles` task 129, "Provision the machine-level tooling that unblocks the literature
extension's Zotero write-back path") completed in full — all 8 phases `[COMPLETED]` — immediately
before this section was written. Every probe below is a live command run in this session at
**2026-08-11T21:46-21:49 UTC**, after that completion, not a re-read of either report's prose.
Where a probe result changes a claim made earlier in this report (written before this
verification pass), that is called out explicitly and the live observation is authoritative.

### What was actually provisioned (per the dotfiles plan, read as the authority on scope)

`~/.dotfiles/specs/129_provision_zotero_agent_tooling/plans/01_provision-zotero-agent-tooling.md`
(read in full for this pass) provisioned: a Nix-packaged `zot` (zotero-cli-cc) binary on PATH; one
sops-encrypted `zotero_api_key` secret feeding `ZOTERO_API_KEY`/`ZOT_API_KEY`/`ZOT_LIBRARY_ID` via
shell exports, `systemd --user set-environment`, and a declarative `~/.config/zot/config.toml`;
and an optional, **disabled-by-default** `zotero-translation-server` systemd `--user` service.
The Zotero API key was rotated (old key independently confirmed revoked, HTTP 403). Storage quota
was explicitly out of that task's scope — it provisioned credentials and tooling only, never
touched account plan/quota. `zotero-mcp` registration was an explicit Non-Goal there too,
deferred to this task's decision, matching Work Item 2 above.

### `zot` CLI: live and correctly credentialed

```
$ zot --version
zot, version 0.10.0
$ zot config show
Library ID: 2622830
API Key:    ***uZMi
Data Dir:   /home/benjamin/Documents/Zotero
Database:   /home/benjamin/Documents/Zotero/zotero.sqlite (OK)
```
`zot` resolves and is credentialed via `~/.config/zot/config.toml` (the declarative,
env-independent path the dotfiles plan prioritized). Confirms the write-path precondition this
task's work builds on top of is genuinely live, not just documented.

### Correction: `zot` DOES have a delete/orphan-cleanup capability — Work Item 3's open question is resolved

The design section above (Work Item 3, and the corresponding Risk entry) stated that no
delete/trash capability could be found in this repository's docs and flagged it as unconfirmed,
recommending a new `zotero-write.sh item-delete` operation be designed only after checking `zot
--help`. That check has now been run, live:

```
$ zot --help
...
Destructive commands (MUTATES LIBRARY):
  delete         Delete one or more items (move to trash).
  orphans        Find / clean attachments whose stored file is missing from local...
  ...
Read commands:
  ...
  trash          Manage trashed items (list, restore).
```
- `zot delete KEY [KEY...]` — moves item(s) to trash (`--dry-run`, `--idempotency-key` supported).
- `zot orphans clean` — **"Delete orphaned attachment records via the Web API"** — this is a
  purpose-built match for exactly the orphaned-attachment-record problem Work Item 3 exists to
  close (the two file-less children `5J2WMXDD`/`CB99228V` from the predecessor task's live test).
- `zot trash list`/`restore` — non-destructive recovery path, read + reversible.

**Revised recommendation for Work Item 3**: drop the "design a new `zotero-write.sh item-delete`
operation, mechanism unconfirmed" plan. Instead, add a thin `zotero-write.sh orphan-clean`
operation that wraps the existing `zot orphans clean` (mirroring how `item-add` already wraps
`zot add`) — no new Web-API-DELETE-plus-version-lookup design is needed; `zot` already owns that
complexity. This removes an entire open risk from the plan phase's scope.

**But a live caveat limits it today, and it is the SAME caveat already documented in this
report's Work Item 1 sync-lag discussion — reconfirmed live, not a new problem**:

```
$ zot orphans list
{"ok": true, "data": {"orphans": [], "total": 0, "counts": {"dead": 0, "recoverable": 0, "unknown": 0}}}
$ zot stats | jq .data.total_items
904
$ zot read QWF66MNX
{"ok": false, "error": {"code": "not_found", "message": "Item 'QWF66MNX' not found", ...}}
$ zot search "10.26686/ajl.v22i2.5680" --json
{"ok": true, "data": [], ...}
```
`zot orphans list` reports **zero** orphans right now — not because the two orphans from the
predecessor task's live test were cleaned up, but because `zot`'s read path (confirmed
repeatedly, including here, to be local-SQLite-only) still has no record of item `QWF66MNX` or
its children at all: `total_items` is still `904` (the pre-test count), `zot read QWF66MNX`
returns `not_found`, and searching its DOI returns zero hits — all **reproduced live in this
session**, hours after the item was created via the Web API earlier the same day. The sync-lag
finding this report's predecessor task already established (local reads never see a Web-API
write until a desktop client syncs it down) is therefore still fully in effect and directly
limits `zot orphans clean`'s usefulness **today**: it cannot see the two known orphans to clean
them until a desktop client runs and syncs. The capability is real and the right fit; its
immediate applicability is blocked by the same pre-existing sync-lag condition, not by any defect
in `orphans clean` itself.

### `zot duplicates` — a native dedup capability worth noting, not a replacement

```
$ zot duplicates --by doi
{"ok": true, "data": [{"group": 1, "match_type": "doi", "score": 1.0, "items": [...two real items with the same DOI, pre-existing in the library, unrelated to this task's work...]}]}
```
`zot duplicates --by doi|title|both` is a working, library-wide duplicate finder and did surface
a genuine (pre-existing, unrelated) DOI collision in the live library, confirming it functions
correctly. It is a **local-SQLite read**, same as every other `zot` read command, so it is subject
to the identical sync-lag caveat as `check_live_doi_duplicate()` in `literature-ingest-online.sh`
and is not a substitute for that function's specific job (checking one incoming DOI before a
create, integrated into the bridge's own control flow) — but it is worth naming in
`zotero-integration.md` as an available operator-facing tool for periodic whole-library dedup
sweeps, independent of the ingest bridge.

### Export freshness: confirmed STALE, live, as expected

```
$ bash .claude/scripts/zotero-export-freshness.sh
... export reference 2026-07-01 < sqlite mtime 2026-08-05 ...
ZOTERO_EXPORT_STALE
```
Working as designed — the Better BibTeX export has not been regenerated since 2026-07-01 while
the live sqlite has been written since (2026-08-05), so the freshness gate correctly reports
`ZOTERO_EXPORT_STALE`, which is exactly the "not confirmed fresh -> re-verify live" branch
Work Item 1's design section already assumes. No change to that design is needed.

### Storage quota: NOT re-verifiable this session — last known state stands, unchanged

The team lead's brief asked whether the over-quota state (`413`, `2745.6 MB > 300 MB`) still
holds. It cannot be re-checked without triggering a real quota-relevant write (per the seed
report, there is still no Web API endpoint exposing quota state directly — only a `413`'s error
body reveals it), and this session's scope is explicitly read-only/dry-run with no authorization
to attempt any upload. **No new evidence either way was gathered.** The last known state — from
the same calendar day, in the predecessor task's live, user-authorized test — stands as the
current best information: over quota by a wide margin (2745.6 used vs. 300 MB limit). This
report's Work Item 3 design (reactive-cache + config override, since preflight is structurally
impossible) is unaffected by this non-finding; if anything it is reinforced, since the one thing
that could have changed the premise (a plan upgrade or freed space) was outside the dotfiles
provisioning task's scope and there is no evidence either happened.

**`--via-bridge` local-import route: still unavailable, reconfirmed live.**
```
$ ss -lntp | grep 23119   # nothing
$ zot bridge status
{"ok": false, "error": {"code": "not_reachable", "message": "Cannot reach Zotero at http://127.0.0.1:23119 — is the desktop app running?", ...}}
```
Zotero desktop is not running (port 23119 closed; `zot bridge status` confirms "not reachable").
The bridge/local-import alternative to the quota-limited Web-API cloud upload route, discussed in
`patterns/zotero-item-creation.md` section 4, remains unavailable — unchanged from the
predecessor task's finding, now independently reconfirmed rather than merely re-stated.

### translation-server: confirmed OFF by design; `/search` already live-verified during provisioning; `/web` still never exercised by anyone

```
$ ss -lntp | grep 1969   # nothing
$ systemctl --user list-unit-files 'zotero-translation-server*'
0 unit files listed.
```
The service is correctly disabled by default (`services.zoteroTranslationServer.enable = false`
in `~/.dotfiles`) — no unit even exists right now (the module wraps the whole
`systemd.user.services` block in `lib.mkIf cfg.enable`), so there is nothing listening on 1969.
This matches the dotfiles plan's intended design, not a defect.

The dotfiles provisioning task itself already performed a genuine, live smoke test of `POST
/search` during Phase 8 (temporarily enabling the toggle, testing, then reverting), documented in
its own summary: `curl -s -d '10.1093/mind/fzab048' -H 'Content-Type: text/plain'
http://127.0.0.1:1969/search` returned real Zotero-format JSON (title "The Modal Moving
Spotlight Theory", DOI, creators, ISSN). That result is taken as verified evidence for `/search`'s
response shape claim in Work Item 1 above — it is a real, executed, successful call, not a
documentation claim.

**`POST /web` has never been exercised by anyone, in either task.** A `grep` across both of the
dotfiles task's reports and its summary for `/web` found no evidence it was ever called — only
`/search` was smoke-tested. This gap is real and should be recorded as open, not assumed closed
by association with `/search`'s success.

**This report does not re-enable the service to close that gap.** Doing so requires editing
`~/.dotfiles/home.nix` (a file entirely outside this task's `agent-system/extensions/literature/**`
binding rule and outside this repository) and running `home-manager switch` — a real,
system-level activation affecting a different repository's managed state. That is exactly the
kind of outward-facing, cross-repo action this session should not take without explicit
authorization, and it is outside what either research task 39's or the dotfiles task's binding
rules license an agent in this position to do unilaterally. **Recommendation, not performed
here**: either coordinate a short, explicitly-authorized enable/test/revert cycle (mirroring
Phase 8's own pattern) before or during `/plan 39`'s phase design, or accept `/web`'s response
shape as unverified-but-documented (per the seed report's citation of the official
translation-server README) until the literature-side implementation phase needs it running
anyway and can test it as part of that work.

### `zotero-mcp`: confirmed NOT registered — Work Item 2's decision stands, now fact-grounded rather than argued alone

```
$ command -v zotero-mcp   # not found
$ claude mcp list
claude.ai Google Drive: ... - Connected
lean-lsp: ... - Connected
playwright: ... - Connected
```
No `zotero-mcp` entry anywhere. This confirms the dotfiles plan's own Non-Goal statement
("zotero-mcp remains unregistered pending their task 39 decision") — nothing was silently
half-provisioned. The **defer** decision recorded in Work Item 2 stands unchanged; it is not
"partly settled by fact" in the sense of contradicting the deferral, but it is now grounded in a
confirmed absence rather than an assumption, which makes the deferral cheaper to reverse later
(there is no existing registration to unwind if the decision changes).

### General extension health: deployed scripts match source; live behavior matches documented design

`cmp` confirms `.claude/scripts/zotero-write.sh` is still byte-identical to
`agent-system/extensions/literature/scripts/zotero-write.sh` (deployment has not drifted since
the predecessor task's activation). Every script exercised above (`zotero-export-freshness.sh`,
`zotero-read.sh` via the deployed path) ran without error and produced output consistent with
this report's and the seed report's existing claims, with the two corrections/confirmations
called out above (the `zot delete`/`orphans clean` capability, and the reconfirmed live
sync-lag/quota/bridge-unavailability facts).

### Summary of corrections to this report's earlier sections

| Earlier claim | Live finding | Disposition |
|---|---|---|
| "No `zot delete`/trash capability found in this repo's docs" (Work Item 3, Risks) | `zot delete`, `zot orphans clean`, and `zot trash list/restore` all exist and are documented in `zot --help` | **Corrected**: recommend wrapping `zot orphans clean` directly; no new Web-API-DELETE design needed |
| Storage quota state (413, 2745.6 > 300 MB) | Unchanged; not re-verifiable this session without an out-of-scope write | **Stands**, timestamped, not re-confirmed by new evidence either way |
| `--via-bridge` blocked (Zotero desktop unreachable) | Reconfirmed live: port 23119 closed, `zot bridge status` reports `not_reachable` | **Stands**, now independently reconfirmed |
| translation-server integration is fully design-only/unverified | `/search` was already live-verified (real DOI, real JSON) during provisioning; `/web` remains genuinely untested by anyone | **Partially corrected**: `/search` moves from "designed" to "designed against a verified real response"; `/web` gap is real and flagged, not closed |
| zotero-mcp adoption decision argued from landscape reasoning alone | Confirmed not registered/installed anywhere on this machine | **Reinforced, not changed**: defer stands, now grounded in a verified absence |

## Appendix

- Files read: `specs/state.json` (task 39 entry), `reports/01_zotero-tooling-landscape.md`,
  `specs/038_activate_zotero_write_back_path/summaries/02_zotero-write-back-activation-summary.md`,
  `agent-system/extensions/literature/scripts/{zotero-write.sh, literature-ingest-online.sh,
  zotero-export-freshness.sh, literature-discover.sh}`,
  `agent-system/extensions/literature/context/project/literature/{patterns/zotero-item-creation.md,
  domain/zotero-integration.md, tools/zotero-scripts.md}`,
  `~/.dotfiles/specs/129_provision_zotero_agent_tooling/plans/01_provision-zotero-agent-tooling.md`
  (full read, live-verification pass), `~/.dotfiles/specs/129_provision_zotero_agent_tooling/
  summaries/01_provision-zotero-agent-tooling-summary.md` and `.return-meta.json` (grepped for
  `/search`/`/web` evidence and handback notes).
- Search performed confirming translation-server/port-1969 has zero existing references anywhere
  in `agent-system/extensions/literature/` — this is a genuinely new integration point, not a
  partially-wired one.
- Live commands run for the verification pass (all read-only or `--dry-run`; timestamped
  2026-08-11T21:46-21:49 UTC): `zot --version`, `zot config show`, `zot --help`, `zot add --help`,
  `zot attach --help`, `zot delete --help`, `zot orphans --help`, `zot trash --help`,
  `zot bridge --help`, `zot bridge status`, `zot duplicates --help`, `zot --json duplicates --by
  doi`, `zot stats --help`, `zot --json stats`, `zot orphans list`, `zot --json search
  "10.26686/ajl.v22i2.5680"`, `zot --json read QWF66MNX`, `ss -lntp | grep {1969,23119}`,
  `systemctl --user list-unit-files 'zotero-translation-server*'`,
  `systemctl --user status zotero-translation-server`, `bash
  .claude/scripts/zotero-export-freshness.sh`, `bash .claude/scripts/zotero-read.sh search
  "10.26686/ajl.v22i2.5680"`, `command -v zotero-mcp`, `claude mcp list`, `cmp` between the source
  and deployed `zotero-write.sh`. No item was created, no attachment was uploaded, and no
  `~/.dotfiles` file was edited or service toggle flipped by this session.
- No files under `agent-system/extensions/literature/**` or the deployed `.claude/**` tree were
  modified in this research pass; all recommendations (including the two Work Item 3 corrections
  from live verification) are for `/plan 39` to turn into phased implementation work.

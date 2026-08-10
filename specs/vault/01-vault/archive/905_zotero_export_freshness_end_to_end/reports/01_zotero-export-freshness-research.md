# Research Report: Zotero Export Freshness End-to-End

**Task**: 905 - Make Zotero export staleness a detected, propagated, and loudly-surfaced condition end-to-end
**Started**: 2026-07-26
**Completed**: 2026-07-26
**Effort**: Medium (1 new script, 2 edited scripts, 1 edited command doc)
**Dependencies**: None declared; disjoint file_scope from the sibling resolver-bypass task
**Sources/Inputs**:
- Codebase: `agent-system/extensions/literature/scripts/{zotero-export-status,zotero-search,zotero-generate-export,zotero-resolve-sqlite-path,literature-discover,literature-ingest-online,literature-briefing}.sh`
- Codebase: `agent-system/extensions/literature/commands/literature.md`, `EXTENSION.md`
- Codebase: `agent-system/extensions/literature/skills/skill-cite/SKILL.md`
- `.claude/docs/architecture/handoff-schema.md`
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md, no-task-references-in-deliverables.md

## Executive Summary

- The four in-scope files divide cleanly into **one new helper** (`zotero-export-freshness.sh`),
  **two edited detectors/consumers** (`zotero-export-status.sh`, `zotero-search.sh`), and **one
  edited orchestration doc** (`commands/literature.md`). The codebase already has a strong,
  consistent "honest directive token" convention (see `zotero-export-status.sh`,
  `literature-ingest-online.sh`, `literature-lit-flag-resolve.sh`) that the new helper and the
  `ZOTERO_EXPORT_STALE` directive should follow exactly.
- **Critical gap, must be flagged to the user/planner**: the task names `zotero-search.sh` as
  "the primary consumer... [that] drives /literature Mode A discovery and /cite," but *neither*
  of those two real call sites is in `file_scope`. Both discard `zotero-search.sh`'s stderr with
  `2>/dev/null` and both treat its exit codes 1 and 2 identically as "non-fatal, proceed as if
  nothing is wrong" — confirmed by direct inspection of `literature-discover.sh`'s
  `tier2_search()` and `skill-cite/SKILL.md`. A stderr-only banner and/or new exit code added to
  `zotero-search.sh` alone will **not** reach either of those two named consumers without also
  touching `literature-discover.sh` and `skill-cite/SKILL.md`, which are out of scope. This does
  not mean Defect 4's fix is worthless — see the mitigation-layering recommendation below — but
  it does mean the PRIMARY ACCEPTANCE CRITERION ("a zero-result answer must never be silently
  indistinguishable...") is only *fully* closed for the interactive Mode A path via **Defect 3's
  fix** (the pre-search offer in `commands/literature.md`, which runs *before*
  `literature-discover.sh` is ever invoked), not via Defect 4 alone.
- Recommended design for the freshness helper: compare (a) the `.zotero-library.meta.json`
  `_generated` timestamp if present, else the export file's own mtime, against (b) the resolved
  `zotero.sqlite` mtime (via the existing, untouched `zotero-resolve-sqlite-path.sh`). Fold "can't
  determine" into a conservative "not confirmed fresh" outcome rather than defaulting to fresh —
  this mirrors the codebase's existing "never write a silent empty-but-valid export" philosophy
  in `zotero-generate-export.sh`'s orchestrator branch.
- Recommended `/literature` STALE offer: reuse the **generation mechanism**, not the two-prompt
  RUNNING/NOT_RUNNING UI verbatim. `zotero-generate-export.sh --force` already auto-selects
  Path 1 (live API) vs Path 3 (sqlite) internally, so a single "Regenerate now (recommended) /
  Skip this run" prompt is sufficient and avoids duplicating the running-state probe a second
  time inside `zotero-export-status.sh`.

## Context & Scope

Task 905 fixes two coupled defects sharing one root cause (freshness of
`$LITERATURE_DIR/zotero-library.json` is never checked against the live `zotero.sqlite`):

- **Defect 3**: `zotero-export-status.sh` treats file *existence* as freshness — it emits
  `ZOTERO_EXPORT_PRESENT` for a two-week-stale export, and `/literature`'s PRESENT branch offers
  nothing.
- **Defect 4**: `zotero-search.sh` never checks staleness at all, so a stale-library zero-result
  answer (exit 2) is indistinguishable from a genuinely-absent-item answer.

Declared `file_scope` (binding — SOURCE-STORE RULE applies, edit
`agent-system/extensions/literature/**`, never `.claude/**`):
- `scripts/zotero-export-status.sh` (edit)
- `scripts/zotero-export-freshness.sh` (new)
- `scripts/zotero-search.sh` (edit)
- `commands/literature.md` (edit)

Explicit non-goals (verified against the current code, still hold): no auto-regeneration without
consent (`zotero-generate-export.sh --force` stays opt-in); do not modify
`zotero-resolve-sqlite-path.sh` (confirmed correct — it already auto-detects a custom Zotero
`dataDir` from `prefs.js` and falls back to `~/Zotero/zotero.sqlite`); do not touch `~/Zotero`.

## Findings

### Codebase Patterns to Follow

1. **Honest directive tokens, single stdout line, rationale on stderr.** Every classifier in this
   extension (`zotero-export-status.sh`, `literature-lit-flag-resolve.sh`,
   `literature-ingest-online.sh`) prints *exactly one* uppercase `SCRIPT_PREFIX_TOKEN` line on
   stdout and puts all human-readable reasoning on stderr prefixed `Rationale:`. `AskUserQuestion`
   is never called from inside these scripts — that responsibility always lives in the calling
   command doc. The new helper and the `ZOTERO_EXPORT_STALE` addition must follow this precisely.

2. **`resolve_library_path()` is intentionally duplicated**, not extracted into a shared script,
   across `zotero-search.sh`, `zotero-export-status.sh`, and `zotero-generate-export.sh` (3-tier:
   `$ZOTERO_LIBRARY` -> `$LITERATURE_DIR/zotero-library.json` -> `~/Projects/Literature/zotero-library.json`).
   The new helper should copy this same function verbatim rather than trying to factor it out —
   consistent with existing style, and `zotero-export-status.sh`'s own header comment already
   flags that a shared-vs-duplicated resolution mismatch (with `literature-discover.sh`'s
   narrower check) is a known, deliberately-unfixed inconsistency elsewhere.

3. **`zotero-resolve-sqlite-path.sh` is the single shared sqlite-path resolver** already consumed
   by both `zotero-export-status.sh` (line 80) and `zotero-generate-export.sh` (line 96) via
   `"$SCRIPT_DIR/zotero-resolve-sqlite-path.sh"`. The new freshness helper should consume it
   identically — this is explicitly the "consume it, do not modify it" non-goal.

4. **`.zotero-library.meta.json` schema** (written by `zotero-generate-export.sh`'s
   `write_meta_stamp()`, `zotero-generate-export.sh:501-526`):
   ```json
   {
     "_generated": "2026-07-15T09:00:00Z",
     "source": "zotero7-local-api+bbt-citekeys | sqlite-reconstruction",
     "source_path": "...",
     "item_count": 400,
     "note": "..."
   }
   ```
   This file sits at `$(dirname "$OUTPUT_PATH")/.zotero-library.meta.json`, i.e. next to
   `zotero-library.json` in the same `$LITERATURE_DIR`. It is **only written when the export was
   produced by `zotero-generate-export.sh`** — a manually-created "File -> Export Library" export
   (the setup path documented in `zotero-search.sh`'s own missing-library instructions) will never
   have this file. The freshness helper must treat its absence as normal, not an error.

5. **Banner family precedent** (`literature-briefing.sh`): `[SPARSE COVERAGE - ...]`,
   `[UNVERIFIED - provenance_fidelity: ...]`, `[DEGRADED RETRIEVAL - fallback_tier: ...]` — all
   share the `[LOUD LABEL - key: value, ...] <one sentence of guidance>` shape, and all are
   *always* accompanied by a machine-readable comment/marker for programmatic detection
   (`<!-- lit-coverage ... -->`). `[STALE EXPORT - ...]` should match this shape exactly for
   consistency, e.g. `[STALE EXPORT - export: 2026-07-01, sqlite: 2026-07-15] ...`.

6. **`orchestrator_mode` dual-consumer / autonomy discipline**: every `--orchestrator-mode`
   consumer in this extension takes a *deterministic default* and prints a visible `[x:auto]`
   notice rather than calling (or trying to call) `AskUserQuestion` — see
   `zotero-generate-export.sh`'s `[zotero:auto]` branch and CLAUDE.md's `AUTONOMOUS_GLOBAL`
   precedent for `--lit`. The STALE branch in `commands/literature.md` must mirror this shape
   exactly (an `AUTONOMOUS_STALE`-equivalent: no prompt, take "regenerate now," log
   `[zotero:auto]`).

### Per-File Findings

**`zotero-export-status.sh`** (174 lines today). Existence check is lines 141-145 — this is
*exactly* where the fix must intercept: instead of returning `ZOTERO_EXPORT_PRESENT`
unconditionally on `[ -f "$output_path" ]`, it must call the new freshness helper and only return
`ZOTERO_EXPORT_PRESENT` when the helper affirmatively confirms freshness. The existing
`probe_zotero_api()` / sqlite-existence code that currently runs only in the *missing* branch
(lines 147-169) already fully determines "is regeneration viable, and via which path" — this
logic does not need to be duplicated for the STALE case if the STALE offer instead reuses
`zotero-generate-export.sh --force`'s own internal auto-detection (see Recommendation 3 below).

**`zotero-search.sh`** (408 lines today). Stdout contract (json/pretty) is a hard constraint — it
is `jq`-parsed by `literature-discover.sh:tier2_search()` (`echo "$zotero_results" | jq -c '.[]'`)
and by `skill-cite/SKILL.md` (`jq '.[0].score // 0'` etc.). Any staleness signal on stdout in JSON
mode would corrupt this contract; it must go through stderr (existing precedent: the missing-file
setup instructions at lines 144-169 already go to stderr) and/or a new distinct exit code.
Existing exit codes: 0 (results), 1 (library not found), 2 (no results). No code 3+ used yet.

**`zotero-generate-export.sh`** (584 lines, consumed but *not* edited — not in file_scope). Its
`--force` flag already re-runs the full Path 1 -> Path 2 -> Path 3 auto-detection from scratch
regardless of *why* regeneration was requested (missing vs. stale) — this is the key fact that
lets the STALE offer avoid re-implementing the running-state probe.

**`commands/literature.md`** (642 lines). Step 2 sub-step 0 (lines 132-305) is the full existing
zotero offer state machine for `discover` mode: three interactive branches
(`MISSING_RUNNING`/`MISSING_NOT_RUNNING`/`UNAVAILABLE`) plus two autonomous branches. The `PRESENT`
branch (lines 149-151) is the one-line no-op that must become the STALE entry point.

### Critical Finding: Stderr/Exit-Code Swallowing at Both Named Consumers

The task text says Defect 4's target, `zotero-search.sh`, "drives /literature Mode A discovery and
/cite." Verified both call sites directly:

- `literature-discover.sh:tier2_search()` (not in file_scope) calls:
  ```bash
  zotero_results=$("$zotero_script" --format=json --limit="$DISCOVER_LIMIT" \
    "${FILTERED_TERMS[@]}" 2>/dev/null) || exit_code=$?
  # Exit code 1 = library not found, 2 = no results — both are non-fatal
  if [ "$exit_code" -ne 0 ] || [ -z "$zotero_results" ]; then
    return 0
  fi
  ```
  Any new exit code (say, 3 or 4) falls into the same `-ne 0` branch and is silently swallowed
  identically to today's 1/2 handling — no code change here would make it behave differently
  *unless `literature-discover.sh` itself is edited*, which it is not in file_scope.

- `skill-cite/SKILL.md` (not in file_scope) calls `zotero-search.sh` with `2>/dev/null` (line 253)
  and documents in its own error-handling table: *"zotero-search.sh exit 2 (no results): Normal —
  treat as score 0"* (line 607) — i.e. it also has no branch that would react to a new exit code.

**Consequence**: a stderr banner and/or new exit code added purely inside `zotero-search.sh`
will surface correctly for (a) direct/standalone invocations of the script by a human or an
agent reading its output directly, and (b) any future consumer that is written to check for it,
but will **not** surface through either of the two consumer paths the task names as primary,
without an additional edit outside the declared `file_scope`.

This does not make Defect 4's in-scope fix pointless — two things still make it worthwhile as
specified:
1. `commands/literature.md` Mode A step 0 (the Defect-3 fix) runs the freshness/regen offer
   *before* `literature-discover.sh` is ever invoked at all, for the interactive and the
   autonomous-default cases. That is the mechanism that actually closes the "confident wrong
   negative" loop for the common Mode A path — Defect 4 is defense-in-depth for the case where
   the user explicitly chose "Skip this run" and the search proceeds anyway against known-stale
   data.
2. `zotero-search.sh`'s own documented STABLE CONTRACT (mirroring `literature-ingest-online.sh`'s
   header style) becomes the foundation a *future*, in-scope-then task can wire
   `literature-discover.sh` and `skill-cite/SKILL.md` against, without re-deriving the freshness
   logic.

**Recommendation to the user/planner**: explicitly acknowledge this boundary in the plan rather
than silently shipping a fix that reads as "complete" but is invisible through the two named
consumer paths. Either (a) accept Defect 3 as the substantive fix for Mode A and treat Defect 4's
`zotero-search.sh` guard as hardening/future-proofing only (document this explicitly in the
plan's scope note and the script's own header), or (b) flag to the user that closing the loop
fully for `/literature` Mode A discovery and `/cite` requires a follow-up task touching
`literature-discover.sh` and `skill-cite/SKILL.md` (both out of this task's file_scope).

## Recommended Design

### 1. `scripts/zotero-export-freshness.sh` (new)

```
USAGE: zotero-export-freshness.sh [--library PATH]

Directives (stdout, one line):
  ZOTERO_EXPORT_FRESH              Export is present and its reference timestamp is >= the
                                    resolved sqlite mtime.
  ZOTERO_EXPORT_STALE              Export is present but its reference timestamp is < the
                                    resolved sqlite mtime (sqlite modified after the export).
  ZOTERO_EXPORT_FRESHNESS_UNKNOWN  Export is present but freshness cannot be determined
                                    (no resolved sqlite file at all). Never silently reported
                                    as fresh.
  ZOTERO_EXPORT_FRESHNESS_ABSENT   Export file does not exist at the resolved path — existence
                                    classification belongs to zotero-export-status.sh; this
                                    token exists so the helper is safe to call standalone too.
```

Algorithm:
1. Resolve library path (copy `resolve_library_path()` verbatim from `zotero-search.sh`).
2. If absent -> `ZOTERO_EXPORT_FRESHNESS_ABSENT`.
3. Compute the export's reference timestamp: if `$(dirname LIBRARY)/.zotero-library.meta.json`
   exists and its `._generated` field parses via `date -d`, use that (immune to a checkout/rsync
   resetting the export file's own mtime); else use `stat -c %Y "$LIBRARY_PATH"` (or `stat -f %m`
   fallback is *not* needed — this codebase's GNU-only tooling assumption is already established
   by `zotero-resolve-sqlite-path.sh`'s own header comment).
4. Resolve sqlite path via `zotero-resolve-sqlite-path.sh` (unmodified). If it does not exist on
   disk -> `ZOTERO_EXPORT_FRESHNESS_UNKNOWN` (never assume fresh when there is nothing to compare
   against).
5. Compare reference timestamp vs. sqlite mtime: reference < sqlite mtime -> `STALE`; else
   -> `FRESH`.
6. All rationale (both timestamps, human-readable dates, which source was used for the reference
   timestamp) goes to stderr, `Rationale:`-prefixed, matching the sibling scripts' style.

### 2. `scripts/zotero-export-status.sh` (edit)

Keep the four existing directives' *meaning* unchanged except one: `ZOTERO_EXPORT_PRESENT` now
means "present **and** confirmed fresh" (explicitly required by the task). Add exactly one new
directive:

```
ZOTERO_EXPORT_STALE   Export exists at the resolved path but the freshness helper did not
                       affirmatively confirm it is fresh (covers both STALE and
                       FRESHNESS_UNKNOWN from the helper — conservative, never silently
                       treated as PRESENT).
```

Implementation: at the existing `if [ -f "$output_path" ]` branch (today lines 141-145), call
`zotero-export-freshness.sh --library "$output_path"`; branch its directive to either
`ZOTERO_EXPORT_PRESENT` (helper said `FRESH`) or `ZOTERO_EXPORT_STALE` (helper said `STALE` or
`FRESHNESS_UNKNOWN`), each with its own `Rationale:` stderr line including both compared
timestamps. Do **not** re-run `probe_zotero_api()`/sqlite-existence logic for the STALE case —
see the `commands/literature.md` recommendation below for why that is unnecessary.

### 3. `commands/literature.md` (edit)

Replace the current one-line `ZOTERO_EXPORT_PRESENT` branch (lines 149-151) with a two-way split:

- **`ZOTERO_EXPORT_PRESENT`**: unchanged, no offer, proceed to step 1.
- **`ZOTERO_EXPORT_STALE`**:
  - *Interactive* (`orchestrator_mode != true`): single `AskUserQuestion` —
    *"Your Zotero export at {path} looks stale (export: {export_date}, Zotero database:
    {sqlite_date}). Regenerate it now?"* with two options, **"Regenerate now (recommended)"**
    (runs `zotero-generate-export.sh --force --orchestrator-mode false`, using the identical
    success/failure handling already documented for "Generate now" in the
    `MISSING_RUNNING`/`MISSING_NOT_RUNNING` branches — capture stdout+stderr, proceed to step 1 on
    success with Tier 2 refreshed, fall back non-fatally to step 1 on failure) and **"Skip this
    run"** (log the same "skipped by user choice" notice convention, proceed to step 1 against the
    known-stale export). This deliberately does **not** re-derive the RUNNING/NOT_RUNNING
    distinction a second time — `--force` already auto-selects Path 1 vs Path 3 internally, so one
    prompt covers both underlying states. This is the sense in which the fix "reuses the existing
    offer machinery": the same generate-then-handle-outcome code path, not a second copy of the
    two-way UI split.
  - *Autonomous* (`orchestrator_mode == true`): no `AskUserQuestion` (mirrors `AUTONOMOUS_GLOBAL`).
    Take the deterministic default: run `zotero-generate-export.sh --force --orchestrator-mode
    true`, emit a visible `[zotero:auto]` notice explaining the autonomous "regenerate now because
    stale and no human is available to prompt" decision, then proceed to step 1 regardless of
    outcome (non-fatal fallback on failure, exactly like the existing autonomous branches).

### 4. `scripts/zotero-search.sh` (edit)

After the existing library-existence check (today lines 143-169, unchanged), call
`zotero-export-freshness.sh --library "$LIBRARY_PATH"`. If it returns anything other than
`ZOTERO_EXPORT_FRESH`:
- Always emit `[STALE EXPORT - export: {date}, sqlite: {date}]` (or the `FRESHNESS_UNKNOWN`
  variant naming that no sqlite was resolvable to compare against) to **stderr**, matching the
  established banner shape from `literature-briefing.sh`.
- In `--format=pretty` mode, additionally print the same banner to **stdout** immediately before
  the results table (pretty mode is human-facing prose already, so this does not break any JSON
  contract and is the one channel guaranteed to reach an interactive human user directly).
- Introduce a new, documented (STABLE-CONTRACT-style header, mirroring
  `literature-ingest-online.sh`'s header) exit code for the case that matters most per the
  acceptance criterion — **zero results returned while the library is stale/unknown-freshness**:
  exit `3` (name it e.g. `ZOTERO_SEARCH_STALE_ZERO` in the header prose) instead of the existing
  exit `2`. Keep the existing exit `2` semantics reserved for a confirmed-fresh zero-result
  answer. Non-zero-result stale searches keep exit `0` (data was returned) but still carry the
  stderr/pretty-stdout banner.
- Document explicitly in the script header that this exit code is inert for today's two callers
  (`literature-discover.sh:tier2_search()`, `skill-cite/SKILL.md`) until they are separately
  updated — do not silently imply full end-to-end propagation the fix does not yet have.

## Decisions

- `ZOTERO_EXPORT_PRESENT` narrows in meaning to "present AND fresh" per the task's explicit
  instruction; this is a documented, deliberate behavior change for any caller currently treating
  PRESENT as pure existence (only caller today is `commands/literature.md`, in file_scope).
- `ZOTERO_EXPORT_FRESHNESS_UNKNOWN` (no resolvable sqlite) is folded into `ZOTERO_EXPORT_STALE` at
  the `zotero-export-status.sh` boundary (conservative default, never silently fresh), keeping the
  new-directive count at exactly one as specified, while the richer helper keeps its own 4-token
  vocabulary for anyone consuming it directly.
- The STALE regeneration offer in `commands/literature.md` uses a single unified prompt built on
  `zotero-generate-export.sh --force`'s existing internal path auto-detection, rather than
  literally duplicating the two-way RUNNING/NOT_RUNNING prompt split a second time for staleness.

## Risks & Mitigations

- **Risk (major, see Critical Finding above)**: Defect 4's `zotero-search.sh` guard does not
  reach `/literature` Mode A discovery or `/cite` through their current call sites, both out of
  file_scope. **Mitigation**: rely on Defect 3's pre-search offer as the substantive Mode A fix;
  document the `zotero-search.sh` exit-code/banner contract as forward-looking infrastructure;
  surface this boundary explicitly in the plan and to the user rather than presenting the fix as
  fully closing the loop for those two consumers.
- **Risk**: `.zotero-library.meta.json`'s `_generated` field uses GNU `date -u`; parsing it back
  requires GNU `date -d`, consistent with the codebase's already-accepted GNU-only assumption
  (documented in `zotero-resolve-sqlite-path.sh`'s header) — no new portability regression, but
  worth a defensive `|| ...` fallback to file mtime if `date -d` fails to parse (malformed/hand-
  edited meta file).
- **Risk**: comparing mtimes across a network filesystem or after `git` operations on
  `$LITERATURE_DIR` (if it is itself version-controlled) could produce false STALE/FRESH readings
  if mtimes get reset independently of content changes. Mitigated by preferring the meta stamp
  (immune to this) over file mtime whenever available.

## Context Extension Recommendations

- None required for this meta task — the existing `EXTENSION.md` "Sparse-Coverage Detection"
  section already documents the honest-token/banner conventions this design follows; once
  implemented, a short addendum there (or a new subsection) documenting the STALE-export
  detection contract would be a natural follow-up for a future documentation task, not required
  to unblock implementation here.

## Appendix

Search/inspection performed:
- Directory listing of `agent-system/extensions/literature/{scripts,commands,skills,context}`.
- Full read of `zotero-export-status.sh`, `zotero-search.sh`, `zotero-generate-export.sh`,
  `zotero-resolve-sqlite-path.sh`, `commands/literature.md`.
- Grep for `SPARSE COVERAGE`/`UNVERIFIED`/`DEGRADED RETRIEVAL` banner precedents in
  `literature-briefing.sh`, `literature-lit-flag-resolve.sh`, `literature-search.sh`.
- Grep + read of `literature-ingest-online.sh`'s STABLE CONTRACT header for the directive/exit-code
  documentation style to imitate.
- Grep + targeted read of `literature-discover.sh:tier2_search()` (lines 344-465) confirming the
  `2>/dev/null` + uniform exit-1/2 handling that motivates the Critical Finding above.
- Grep of `skill-cite/SKILL.md` confirming its own `2>/dev/null` call and documented exit-2
  "Normal" handling.
- Read of `.claude/docs/architecture/handoff-schema.md` for the orchestrator handoff contract.

# Implementation Plan: Task #905

- **Task**: 905 - Make Zotero export staleness a detected, propagated, and loudly-surfaced condition end-to-end
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: None (disjoint file_scope from the sibling resolver-bypass task)
- **Research Inputs**: specs/905_zotero_export_freshness_end_to_end/reports/01_zotero-export-freshness-research.md
- **Artifacts**: plans/01_zotero-export-freshness-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Freshness of `$LITERATURE_DIR/zotero-library.json` is never checked anywhere in the literature
extension, so a two-week-stale export produces a confident, clean, wrong "not in your library"
negative. This plan lands a new shared freshness classifier, teaches the existing export-status
classifier a fifth `ZOTERO_EXPORT_STALE` directive (narrowing `PRESENT` to mean "present AND
fresh"), wires an assisted-regeneration offer into `/literature`'s Mode A step 0 for both the
interactive and the autonomous path, and adds a loud `[STALE EXPORT - ...]` banner plus a new
exit code to `zotero-search.sh`.

The substantive close of the acceptance criterion for the common Mode A path is the Phase 3
pre-search offer, which runs *before* `literature-discover.sh` is ever invoked. Phase 4's
search-side guard is defense-in-depth plus a documented forward contract; see the Scope Boundary
note below for why it cannot fully propagate today.

### Research Integration

The research report's recommended design is adopted essentially verbatim: the four-token helper
vocabulary, folding `FRESHNESS_UNKNOWN` into export-status's single new `STALE` directive
(conservative — never silently fresh), preferring the `.zotero-library.meta.json` `_generated`
stamp over raw file mtime, and a single unified regeneration prompt built on
`zotero-generate-export.sh --force`'s own internal Path 1/Path 3 auto-detection rather than a
second copy of the `MISSING_RUNNING`/`MISSING_NOT_RUNNING` UI split.

Two facts verified during planning that the report did not cover, both of which change the work:

1. **`manifest.json` is a deployment allowlist.** `provides.scripts` (`manifest.json:29` region)
   enumerates every script the loader copies into `.claude/scripts/`. A new
   `zotero-export-freshness.sh` that is not declared there is **never deployed**, making the
   entire task inert at runtime, and `check-extension-docs.sh` Rule E
   (`check_referenced_scripts_declared`) fails on a script referenced in docs but absent from
   `provides.scripts`. Adding one array entry to `manifest.json` is therefore mechanically
   required by the declared file_scope's own new-file entry — see Scope Note below.
2. **Both consumers run `set -euo pipefail`.** A non-zero helper exit would abort the calling
   script outright. Every helper invocation must be capture-guarded (`|| true` / `|| directive=""`)
   in both consumers. This is called out per-phase because it is the most likely silent-breakage
   defect in this change.

### Scope Note (one file beyond the declared four)

Declared file_scope names four files. This plan touches those four plus exactly one additional
line in `agent-system/extensions/literature/manifest.json` (`provides.scripts` array entry for
`zotero-export-freshness.sh`). This is not scope drift: it is the deployment registration
without which the declared new file cannot exist as a runnable artifact. No other manifest field
is touched. Flagged here rather than silently widened.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap_path was supplied in the delegation context; no ROADMAP.md was consulted or modified.

### Scope Boundary (must be stated plainly, not papered over)

`zotero-search.sh`'s two named primary consumers — `literature-discover.sh:tier2_search()` and
`skills/skill-cite/SKILL.md` — both call it with `2>/dev/null` and both treat exit 1 and 2
identically as non-fatal. Neither file is in file_scope. Consequently the Phase 4 banner and the
new exit code are **inert for those two consumers today**: a new exit 3 lands in the same
`-ne 0` branch that already swallows 1 and 2, and the stderr banner is discarded. Phase 4 ships
them as a documented STABLE CONTRACT so a follow-up (out of scope here) can wire the two
consumers without re-deriving freshness logic. Phase 5 verifies and records this boundary rather
than claiming end-to-end propagation the change does not have.

## Goals & Non-Goals

**Goals**:
- A stale export is detected by a single shared helper consumed identically by every caller.
- `ZOTERO_EXPORT_PRESENT` means "present AND confirmed fresh"; a fifth `ZOTERO_EXPORT_STALE`
  directive covers the rest.
- `/literature` Mode A offers assisted regeneration on STALE, interactively and (deterministically,
  with a visible `[zotero:auto]` notice) autonomously.
- `zotero-search.sh` emits a loud `[STALE EXPORT - ...]` banner and a distinct exit code for
  zero-results-while-stale.
- Every edit lands in `agent-system/extensions/literature/**`; nothing is written to `.claude/**`.

**Non-Goals**:
- Auto-regenerating the export without user consent. `--force` stays opt-in; detection must not
  become silent repair.
- Modifying `scripts/zotero-resolve-sqlite-path.sh`. Consume it unchanged.
- Deleting or migrating `~/Zotero`.
- Editing `literature-discover.sh` or `skills/skill-cite/SKILL.md` to consume the new exit code
  (out of file_scope; recorded as a follow-up).
- Regenerating the `.claude/` deploy tree. That is the loader's job, triggered by the user.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New helper not added to `manifest.json` -> never deployed, whole task inert | H | M | Phase 1 includes the manifest entry and verifies it with `jq`; Phase 5 re-checks |
| `set -euo pipefail` + non-zero helper exit aborts a consumer mid-run | H | M | Every helper call is capture-guarded; Phase 2/4 verification includes a forced-failure case |
| Helper missing at runtime (deploy skew) silently degrades to "fresh" | H | L | Both consumers treat helper failure/absence as not-confirmed-fresh with an explicit rationale line — never silently PRESENT |
| `PRESENT` narrowing breaks an unnoticed caller | M | L | Grep confirmed `commands/literature.md` is the only consumer of the directive, and it is in file_scope |
| `date -d` fails on a hand-edited/malformed `_generated` stamp | M | L | Defensive fallback to the export file's own mtime, with the fallback named in the stderr rationale |
| mtime comparison misleads after a checkout/rsync resets the export file's mtime | M | L | Prefer the meta stamp (content-derived, immune) over file mtime whenever parseable |
| `[STALE EXPORT ...]` on stdout corrupts the JSON contract | H | L | Banner goes to stderr always; stdout only in `--format=pretty`, which is prose already |
| Exit-code doc updated in one of two places in `zotero-search.sh` | L | M | Both the header comment block and the `show_usage` heredoc are named explicitly in Phase 4 |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3 | 2 |
| 4 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 2 and 4 touch disjoint files
(`zotero-export-status.sh` vs `zotero-search.sh`) and may be run concurrently.

---

### Phase 1: Shared freshness helper + deployment registration [COMPLETED]

**Goal**: A standalone, directly-runnable `zotero-export-freshness.sh` that classifies export
freshness into four honest directive tokens, declared in the manifest so the loader deploys it.

**Tasks**:
- [x] Create `agent-system/extensions/literature/scripts/zotero-export-freshness.sh`, `chmod +x`,
      modeled structurally on `zotero-export-status.sh` (`set -euo pipefail`, `SCRIPT_DIR` via
      `BASH_SOURCE`, `jq` presence check, `show_usage`, argument loop, one stdout token, all
      rationale to stderr, `AskUserQuestion` never called). *(completed)*
- [x] Implement `USAGE: zotero-export-freshness.sh [--library PATH]` (plus `-h|--help`). *(completed)*
- [x] Copy `resolve_library_path()` verbatim from `zotero-search.sh:120-135` (deliberate
      duplication, consistent with the existing three copies; do not factor it out). *(completed)*
- [x] Implement the four directives, exactly one line on stdout, exit 0 for all four:
      - `ZOTERO_EXPORT_FRESH` — reference timestamp >= resolved sqlite mtime
      - `ZOTERO_EXPORT_STALE` — reference timestamp < resolved sqlite mtime
      - `ZOTERO_EXPORT_FRESHNESS_UNKNOWN` — export present, no sqlite on disk to compare against
      - `ZOTERO_EXPORT_FRESHNESS_ABSENT` — no export file at the resolved path
      Reserve non-zero exits for usage/dependency errors only (missing `jq`, bad argument),
      mirroring `zotero-export-status.sh`'s exit 1/2 convention. *(completed)*
- [x] Reference timestamp resolution: if `$(dirname LIBRARY)/.zotero-library.meta.json` exists and
      its `._generated` parses via `date -d`, use that; otherwise fall back to
      `stat -c %Y "$LIBRARY"`. Name which source was used in the stderr rationale. *(completed)*
- [x] Resolve sqlite via `"$SCRIPT_DIR/zotero-resolve-sqlite-path.sh"` (unmodified). Absent file
      -> `ZOTERO_EXPORT_FRESHNESS_UNKNOWN`, never `FRESH`. *(completed)*
- [x] Emit `Rationale:`-prefixed stderr on every branch carrying both epoch values, both
      human-readable dates, and the reference-timestamp source. *(completed)*
- [x] Add `"zotero-export-freshness.sh"` to `provides.scripts` in
      `agent-system/extensions/literature/manifest.json` (place it adjacent to the other
      `zotero-*` entries). *(completed)*
- [x] Header comment documents the token vocabulary and notes that
      `zotero-export-status.sh` folds `STALE` + `FRESHNESS_UNKNOWN` into its own single
      `ZOTERO_EXPORT_STALE` directive — the identical token spelling across the two vocabularies
      is intentional, not a collision to be renamed. *(completed)*

**Timing**: 1.25 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/literature/scripts/zotero-export-freshness.sh` - new file (~130 lines)
- `agent-system/extensions/literature/manifest.json` - one `provides.scripts` array entry

**Verification**:
- `bash -n` passes on the new script.
- Live STALE case (the reproduced symptom): running the script with no arguments against the real
  environment (`LITERATURE_DIR=/home/benjamin/Projects/Literature`, export dated 2026-07-01,
  resolved sqlite `/home/benjamin/Documents/Zotero/zotero.sqlite` dated 2026-07-15) prints exactly
  `ZOTERO_EXPORT_STALE` on stdout and a rationale naming both dates on stderr.
- FRESH case: copy the export to a temp dir with a `.zotero-library.meta.json` whose `_generated`
  is in the future, run with `--library`, confirm `ZOTERO_EXPORT_FRESH`.
- ABSENT case: `--library /nonexistent/x.json` -> `ZOTERO_EXPORT_FRESHNESS_ABSENT`.
- UNKNOWN case: `ZOTERO_SQLITE_PATH=/nonexistent/zotero.sqlite` -> `ZOTERO_EXPORT_FRESHNESS_UNKNOWN`.
- Malformed stamp: temp copy with `_generated: "not-a-date"` still classifies (mtime fallback)
  and says so on stderr.
- Exactly one line on stdout in every case: `... 2>/dev/null | wc -l` returns 1.
- `jq -e '.provides.scripts | index("zotero-export-freshness.sh")' manifest.json` succeeds.

---

### Phase 2: Fifth `ZOTERO_EXPORT_STALE` directive in zotero-export-status.sh [COMPLETED]

**Goal**: `ZOTERO_EXPORT_PRESENT` narrows to "present AND confirmed fresh"; everything else about
an existing export becomes `ZOTERO_EXPORT_STALE`.

**Tasks**:
- [x] Replace the unconditional existence branch at `zotero-export-status.sh:141-145` with a
      freshness consultation: call `"$SCRIPT_DIR/zotero-export-freshness.sh" --library "$output_path"`,
      capture-guarded so a non-zero exit cannot trip `set -e` (capture stdout and stderr
      separately, `|| true`). *(completed)*
- [x] Branch: helper `ZOTERO_EXPORT_FRESH` -> emit `ZOTERO_EXPORT_PRESENT`; helper
      `ZOTERO_EXPORT_STALE` or `ZOTERO_EXPORT_FRESHNESS_UNKNOWN` -> emit `ZOTERO_EXPORT_STALE`;
      helper failure, empty output, or unrecognized token -> emit `ZOTERO_EXPORT_STALE` with a
      rationale naming the helper failure explicitly. Never silently PRESENT. *(completed)*
- [x] Each branch writes its own `Rationale:` stderr line, forwarding the helper's compared
      timestamps so the caller can render them in the offer prompt without re-invoking the helper. *(completed)*
- [x] Keep the four existing directives' behavior otherwise unchanged; the missing-export branch
      (`probe_zotero_api()` / sqlite existence, lines 147-173) is untouched and is NOT duplicated
      for the STALE case. *(completed)*
- [x] Update the header directive documentation (lines 17-34): narrow the `ZOTERO_EXPORT_PRESENT`
      wording, add `ZOTERO_EXPORT_STALE`, and note in the Purpose/Inputs prose that freshness is
      delegated to `zotero-export-freshness.sh`. *(completed)*
- [x] Update the `show_usage` heredoc (lines 86-95) to list five directive tokens, not four. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/literature/scripts/zotero-export-status.sh` - freshness branch +
  header/usage documentation

**Verification**:
- `bash -n` passes.
- Live run against the real stale export prints exactly `ZOTERO_EXPORT_STALE` (this is the direct
  refutation of the reproduced Defect 3 symptom, whose verbatim output today is
  "already present ... no assisted-generation offer needed").
- Fresh temp fixture (`--output` at a temp export with a future `_generated`) prints
  `ZOTERO_EXPORT_PRESENT`.
- Missing export (`--output /nonexistent/x.json`) still prints one of the three missing-branch
  directives, unchanged.
- Forced helper failure (temporarily rename the helper, or point `SCRIPT_DIR` at a copy without
  it): the script still exits 0, prints `ZOTERO_EXPORT_STALE`, and names the helper failure on
  stderr — it does not abort under `set -e`.
- Exactly one stdout line in every case.

---

### Phase 3: STALE regeneration offer in commands/literature.md [COMPLETED]

**Goal**: `/literature` Mode A step 0 offers assisted regeneration on STALE, interactively and
autonomously, instead of the current one-line no-op dead end.

**Tasks**:
- [x] Narrow the `ZOTERO_EXPORT_PRESENT` bullet (`commands/literature.md:149-151`) to state that
      PRESENT now means present AND confirmed fresh; behavior unchanged (no offer, proceed to
      step 1). *(completed)*
- [x] Add a `ZOTERO_EXPORT_STALE` bullet in the interactive branch group (after the PRESENT
      bullet, before `MISSING_RUNNING`), specifying a single two-option `AskUserQuestion`:
      - question naming the resolved path plus both dates drawn from the captured rationale, e.g.
        "Your Zotero export at {resolved_path} looks stale (export: {export_date}, Zotero
        database: {sqlite_date}). Regenerate it now?"
      - **"Regenerate now (recommended)"** -> `"$GENERATE_SCRIPT" --force --orchestrator-mode false`,
        reusing the identical capture-and-handle wording already documented for "Generate now"
        (capture stdout/stderr; on success proceed to step 1 with Tier 2 refreshed; on failure
        surface the generator's stderr and fall back to step 1 non-fatally).
      - **"Skip this run"** -> log the same explicit "skipped by user choice" notice convention,
        then proceed to step 1 against the known-stale export.
      - Include a sentence stating that this deliberately does not re-derive the
        RUNNING/NOT_RUNNING split, because `--force` already auto-selects Path 1 vs Path 3
        internally.
      *(completed)*
- [x] Add an **Orchestrator / non-interactive default, `ZOTERO_EXPORT_STALE`** bullet in the
      autonomous branch group (alongside the two existing `orchestrator_mode == true` bullets at
      lines 280-300): `AskUserQuestion` MUST NOT be called; take the deterministic default and run
      `"$GENERATE_SCRIPT" --force --orchestrator-mode true`; emit a visible `[zotero:auto]` notice
      stating that regeneration was auto-selected because the export is stale and no human is
      available to prompt; proceed to step 1 regardless of outcome (non-fatal). Mirror the
      existing `AUTONOMOUS_GLOBAL` phrasing precedent. *(completed)*
- [x] Verify no task-number citations are introduced anywhere in the edited prose. *(completed:
      grepped the file for task-number patterns, none found)*

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `agent-system/extensions/literature/commands/literature.md` - step 2 sub-step 0 directive table

**Verification**:
- Both new bullets exist and the directive branch list in step 0 now covers all five tokens with
  no token unhandled (`grep -c 'ZOTERO_EXPORT_' ` over step 0 accounts for each).
- The autonomous STALE bullet contains `[zotero:auto]` and explicitly states `AskUserQuestion`
  is not called — matching the two sibling autonomous bullets.
- The interactive STALE bullet passes `--force` (the existing MISSING_* bullets deliberately do
  not) and both new bullets end by proceeding to step 1 non-fatally.
- No `.claude/**` file was edited: `git status --short` shows changes only under
  `agent-system/extensions/literature/` and `specs/`.
- Advisory no-task-reference hook produces no finding for this file.

---

### Phase 4: Staleness guard, banner, and exit code in zotero-search.sh [COMPLETED]

**Goal**: A search against a stale or unknown-freshness library is never silently
indistinguishable from a search against a fresh one.

**Tasks**:
- [x] Add `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` near the top (the script
      currently has none). *(completed)*
- [x] After the existing library-existence check (lines 143-169, unchanged) and before query
      preprocessing, call `"$SCRIPT_DIR/zotero-export-freshness.sh" --library "$LIBRARY_PATH"`,
      capture-guarded against `set -e`. Store the resulting token and the compared dates.
      *(completed: also fixed a `grep -oP | head -1` pipefail abort on no-match discovered
      during forced-failure verification — the date-extraction pipeline itself needed
      `|| VAR=""` guards, not just the helper invocation)*
- [x] Set an internal `FRESHNESS_CONFIRMED=true|false`. Anything other than a clean
      `ZOTERO_EXPORT_FRESH` (including helper failure or absence) sets it false. *(completed)*
- [x] When false, always write the banner to **stderr**, matching the
      `literature-briefing.sh` banner family shape:
      - stale: `[STALE EXPORT - export: {date}, sqlite: {date}] ...` plus one sentence of guidance
        pointing at assisted regeneration.
      - unknown: same label with `sqlite: unresolved` (or an equivalent explicit value) so the
        two conditions are distinguishable, never collapsed.
      *(completed: extended zotero-export-freshness.sh's rationale with machine-parseable
      `export_date=`/`sqlite_date=` tokens so the banner never re-derives freshness itself)*
- [x] In `--format=pretty` mode only, additionally print the same banner to **stdout** immediately
      before the results table (and before the existing "No results found for:" line in the
      zero-result path). JSON mode's stdout contract is untouched. *(completed)*
- [x] Introduce exit code `3`: zero results returned while freshness is not confirmed. Keep exit
      `2` reserved for a confirmed-fresh zero-result answer. Non-zero-result stale searches keep
      exit `0` but still carry the banner. The change goes in the existing zero-results block
      (`RESULT_COUNT -eq 0`, around line 348). *(completed)*
- [x] Document the above in a `STABLE CONTRACT` header block mirroring
      `literature-ingest-online.sh`'s header style, and update **both** exit-code listings: the
      top-of-file comment block (lines 28-31) and the `show_usage` heredoc (lines 70-73). *(completed)*
- [x] In that header, state plainly that exit 3 and the stderr banner are **inert for today's two
      callers** — `literature-discover.sh:tier2_search()` and `skills/skill-cite/SKILL.md`, both
      of which discard stderr and treat every non-zero exit identically — and that wiring them is
      a separate follow-up. Do not imply propagation the change does not have. Reference those two
      call sites by filename only; no task-number citations. *(completed)*

**Timing**: 1.25 hours

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/literature/scripts/zotero-search.sh` - SCRIPT_DIR, freshness guard,
  banner emission, exit 3, STABLE CONTRACT header, two exit-code listings

**Verification**:
- `bash -n` passes.
- Against the live stale export, a query with hits: stderr carries `[STALE EXPORT - export:
  2026-07-01, sqlite: 2026-07-15]`, exit code is 0, and `--format=json` stdout still parses as a
  JSON array (`jq -e 'type == "array"'`).
- Against the live stale export, a query with no hits (e.g. a nonsense term): exit code is 3, the
  banner is present on stderr, and JSON stdout is still exactly `[]`.
- `--format=pretty` on both of the above: the banner also appears on stdout, before the table /
  before "No results found for:".
- Fresh temp fixture with no hits: exit code is 2 and no banner appears — the old contract is
  preserved exactly for the confirmed-fresh case.
- Forced helper failure: the search still runs to completion (no `set -e` abort), banner present,
  exit 3 on zero results.
- Both exit-code listings agree: `grep -n 'No results matched' zotero-search.sh` returns two
  updated sites.

---

### Phase 5: End-to-end acceptance verification and boundary documentation [COMPLETED]

**Goal**: Prove the primary acceptance criterion holds for every reachable path, and record the
propagation boundary honestly.

**Tasks**:
- [x] Run the full chain against the real stale environment and capture the outputs:
      helper -> `ZOTERO_EXPORT_STALE`; export-status -> `ZOTERO_EXPORT_STALE`; search -> banner +
      exit 3 on zero results. *(completed: all three verified live)*
- [x] Confirm no reachable path yields a silent clean zero-result: enumerate the four helper
      tokens and, for each, name the visible signal a user or agent receives (offer prompt,
      `[zotero:auto]` notice, banner, or setup instructions). Any token whose path produces no
      visible signal is a defect to fix before the phase closes. *(completed: FRESH intentionally
      produces no signal — that is the trusted, nothing's-wrong path; STALE and
      FRESHNESS_UNKNOWN both fold to export-status's STALE and get an AskUserQuestion offer or
      `[zotero:auto]` notice in commands/literature.md, plus the `[STALE EXPORT ...]` banner +
      exit 3 in zotero-search.sh as defense-in-depth; FRESHNESS_ABSENT is unreachable from either
      consumer's call site since both only invoke the helper after confirming the export file
      exists, and the fallback `*` branch in both consumers already treats any unrecognized
      token as not-confirmed-fresh with a visible rationale. No defect found.)*
- [x] Confirm the source-store rule held: `git status --short` shows no modifications under
      `.claude/`, and every changed non-`specs/` path is under
      `agent-system/extensions/literature/`. *(completed: zero `.claude/` modifications
      confirmed. Three unrelated files -- `.claude-extensions.json`,
      `lua/neotex/plugins/editor/which-key.lua`, `lua/neotex/plugins/tools/himalaya/utils/cli.lua`
      -- appear modified in `git status` but were already dirty before this implementation began
      and were never touched by it; this task's own edits are confined entirely to
      `agent-system/extensions/literature/**` and `specs/**`.)*
- [x] Run `bash .claude/scripts/check-extension-docs.sh` and confirm the literature extension
      reports no new failures (in particular Rule E, referenced-but-undeclared script). Deployed-
      vs-source drift findings for the newly edited scripts are expected until the user
      regenerates `.claude/` via the loader; note them as expected rather than fixing them by
      writing to `.claude/`. *(completed: literature extension reports PASS; the 37 advisory
      "core script never deployed" items cover essentially every zotero-*/literature-* script,
      not just the newly added one, confirming this is pre-existing whole-extension deploy drift
      rather than a regression introduced here)*
- [x] Record in the implementation summary: (a) the verified outputs above; (b) the explicit
      statement that Phase 4's exit 3 and banner are inert for `literature-discover.sh` and
      `skills/skill-cite/SKILL.md` today; (c) the recommended follow-up task scope (wire those two
      consumers to the new contract). *(completed, see summary artifact)*
- [x] Confirm no task-number citations were introduced outside `specs/**`. *(completed: grepped
      every diff hunk across all five edited/created files, none found)*

**Timing**: 0.75 hours

**Depends on**: 2, 3, 4

**Files to modify**:
- None (verification only; writes only the task summary under `specs/`)

**Verification**:
- All four helper tokens accounted for with a named visible signal.
- `git status --short` clean of `.claude/**` modifications.
- `check-extension-docs.sh` shows no new literature-extension failures beyond expected
  deploy-drift advisories.

---

## Testing & Validation

- [x] `bash -n` passes on all three shell scripts (new helper, export-status, search).
- [x] Helper classifies all four cases correctly against real and temp-fixture inputs, one stdout
      line each, exit 0 on all four classifications.
- [x] `zotero-export-status.sh` emits `ZOTERO_EXPORT_STALE` against the live 2026-07-01 export vs
      the 2026-07-15 sqlite — the direct refutation of the reproduced symptom.
- [x] `zotero-export-status.sh` still emits `ZOTERO_EXPORT_PRESENT` for a confirmed-fresh export,
      and its three missing-export directives are unchanged.
- [x] Helper failure degrades to STALE / unconfirmed in both consumers without aborting under
      `set -euo pipefail`.
- [x] `zotero-search.sh --format=json` stdout remains a clean JSON array (or `[]`) in every stale
      case; the banner never reaches JSON stdout.
- [x] Exit codes: 0 (results, banner if stale), 1 (library not found), 2 (confirmed-fresh zero
      results), 3 (zero results while stale/unknown).
- [x] `commands/literature.md` step 0 handles all five directives; the autonomous STALE branch
      never calls `AskUserQuestion` and always emits `[zotero:auto]`.
- [x] `manifest.json` declares the new script.
- [x] No file under `.claude/` was created or modified.
- [x] No task-number citations outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/literature/scripts/zotero-export-freshness.sh` (new, ~130 lines)
- `agent-system/extensions/literature/scripts/zotero-export-status.sh` (edited)
- `agent-system/extensions/literature/scripts/zotero-search.sh` (edited)
- `agent-system/extensions/literature/commands/literature.md` (edited)
- `agent-system/extensions/literature/manifest.json` (one array entry)
- `specs/905_zotero_export_freshness_end_to_end/summaries/01_*-summary.md`

## Rollback/Contingency

Every change is additive and confined to five tracked files in the source store, committed
per-phase. Rollback is `git revert` of the phase commits — no state migration, no generated
artifacts to unwind, and `.claude/` is untouched (it is regenerated from the source store
regardless).

Per-phase contingencies:
- **Phase 1 blocked** (e.g. `date -d` unavailable): fall back to pure-mtime comparison and record
  the reduced fidelity in the header; the STALE/FRESH distinction still functions.
- **Phase 3 blocked**: Phases 1, 2, and 4 still ship a detected and loudly-surfaced staleness
  condition; only the assisted-regeneration offer is deferred. Record as `[PARTIAL]` — do not mark
  the task complete, since the offer is the substantive Mode A fix.
- **Phase 4 regression risk** (JSON contract): if any stale-path stdout contamination is observed,
  drop the pretty-mode stdout banner and keep stderr-only plus the exit code, rather than shipping
  a corrupted contract.

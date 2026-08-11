# Implementation Plan: Task #38

- **Task**: 38 - Activate and harden the Zotero write-back path in the literature extension
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None
- **Research Inputs**:
  - `specs/038_activate_zotero_write_back_path/reports/01_zotero-integration-review.md` (seed)
  - `specs/038_activate_zotero_write_back_path/reports/02_zotero-write-back-activation-research.md` (follow-up; supersedes the seed report's blocker status)
- **Artifacts**: plans/02_zotero-write-back-activation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The literature extension's Zotero write-back path (`zotero-write.sh` wrapping the `zot` CLI,
called from `literature-ingest-online.sh`) is fully implemented in the source store but inactive,
undeployed, and described by documentation that is now demonstrably wrong. This plan corrects the
stale documentation, hardens the write path with the two guards review identified (an
export-freshness gate and a DOI-normalized live-library dedup check), performs the outstanding
live-envelope confirmation as an explicitly gated real-write test, and activates plus deploys the
extension so the source and deployed copies agree. Definition of done: all five acceptance
criteria in the task description hold, with the magic-byte gate, DOI-only-fallback honest
surfacing, and never-fabricate-keys invariants demonstrably unchanged.

### Research Integration

Findings carried into the phase structure:

- **`zot` v0.10.0 is installed and functional** (re-confirmed live at plan time:
  `/etc/profiles/per-user/benjamin/bin/zot`, `zot, version 0.10.0`). The seed report's "one
  remaining hard blocker" has resolved. Work item 2 is therefore technically unblocked, but
  requires a real write into a 904-item production library — Phase 6 makes that a deliberate,
  user-gated step, never a silent one.
- **The whole literature extension is absent from the deployed tree** — not just the three
  "inactive" zotero scripts. `.claude/scripts/zotero-write.sh` does not exist,
  `.claude/commands/literature.md` does not exist, and `.claude-extensions.json` lists only
  `core,email,memory,nix,nvim` (all re-confirmed live at plan time). `deploy-headless.sh`'s
  default mode only resyncs *currently-active* extensions, so it cannot deploy this by itself.
  Work item 3 is re-scoped in Phase 7 to first-time extension activation.
- **`zot`'s read surface already reads the live SQLite database**, not the stale CSL-JSON export
  — so work item 5's dedup is a call to the existing `zotero-read.sh search`, not a new helper.
  Research confirmed `zot --json search "https://doi.org/10.1007/BF01063914"` returns zero hits
  while the bare lowercase DOI returns one: the normalization requirement is load-bearing, not
  defensive-only.
- **`zotero-export-freshness.sh` still emits `ZOTERO_EXPORT_STALE`** and nothing in
  `literature-ingest-online.sh` consults it (confirmed by a full read of that 657-line script).
  Work item 4 is a net addition, not a modification of existing gating.
- **`zot add --pdf`'s help text says "metadata not auto-resolved by API"** — a `--pdf`-only
  create produces a barer item than the pattern doc implies; passing `--doi` alongside is what
  gets Crossref enrichment.
- **Zotero desktop is not running**, so `zot attach`'s auto-detected route takes the cloud path
  and `resolve_storage_path_from_envelope()`'s local-`storage/` search will hit its staging-path
  fallback as the *normal* case for headless ingest. No code change needed; the docs should stop
  implying the fallback is exceptional.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md consultation was
performed.

## Goals & Non-Goals

**Goals**:

- Remove every extension-doc claim that the Zotero API key is missing or that `zot` is not
  installed; align the version pin with the provisioned `zot` v0.10.0.
- Wire `zotero-export-freshness.sh` into `literature-ingest-online.sh` so a stale export cannot
  drive an unverified `item-add`.
- Add a DOI-normalized, live-library, hard-stop dedup check before any item creation.
- Confirm the `zot add --pdf` / `zot attach` response-envelope field paths against a real call,
  under an explicit user gate, and record the result.
- Activate the literature extension for the first time in this repo and deploy it, so the three
  previously-inactive zotero scripts are byte-identical between source and deployed copies.
- Leave the `%PDF` magic-byte gate, the DOI-only-fallback honest surfacing, the
  never-fabricate-keys stop, and `zotero-write.sh`'s single-write-choke-point role provably
  unchanged.

**Non-Goals**:

- Provisioning `zot`, the translation-server service, or a managed `ZOTERO_API_KEY` — that is the
  ~/.dotfiles repository's responsibility and is already satisfied for `zot`.
- Swapping the write backend to the Zotero 10 local API (tracked as follow-on work).
- Modifying `agent-system/extensions/core/scripts/deploy-headless.sh` or adding a `--load` flag
  to it. Phase 7 deliberately uses an operation (a one-off headless `manager.load` call) rather
  than a source edit, keeping every edit inside the literature extension's territory.
- Refreshing the stale `zotero-library.json` export itself, or changing Tier-2 classification.
  The plan gates and re-verifies around the staleness; it does not fix the export.
- Adopting zotero-mcp, verifying the zotero.org storage quota, or resolving translation-server
  metadata — all tracked as follow-on work.
- Any write to `.claude/**` by hand. Only the deploy engine writes that tree.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Phase 6's real write pollutes the user's production Zotero library with an unwanted item | H | M | Hard user-confirmation gate before the first non-`--dry-run` call; test item is a real, useful open-access paper chosen with the user, not throwaway garbage; the created item key is recorded so the write is reversible via Zotero's trash; declining the gate is an accepted outcome that closes the phase `[COMPLETED WITH EXCLUSIONS]` under acceptance criterion 2's explicit escape hatch |
| Treating work item 3 as "deploy 3 scripts" makes the deploy silently no-op (resync skips an inactive extension) or tempts a hand-copy into `.claude/` | H | M | Phase 7 names first-time activation as the prerequisite and forbids hand-copying; the source-store/deploy boundary rule is restated in the phase; byte-identity is verified after, not assumed |
| Activating the extension deploys far more than the three scripts (1 agent, 2 commands, 2 skills, 36 scripts, plus a CLAUDE.md merge section adding `--lit` docs) | M | H | Phase 7 enumerates the blast radius from `manifest.json` and confirms it with the user before activating; `.syncprotect` already protects `context/repo/project-overview.md` |
| Phases 3 and 4 both edit `literature-ingest-online.sh`; concurrent edits would conflict | M | M | Serialized: Phase 4 depends on Phase 3. They are never in the same wave |
| A new hard-stop dedup makes previously-succeeding ingest runs fail | M | M | The stop is scoped to the create-item (`resolvable`) branch only, emits a named directive token consistent with the script's existing STABLE CONTRACT vocabulary, and is exercised against both a known-duplicate and a known-absent DOI in Phase 4's verification |
| Freshness gating on a permanently-stale export blocks all ingest indefinitely | M | H | The gate implements the task's "refuse **or** re-verify" wording as re-verify-then-proceed against the live library (which Phase 4's dedup already queries), not an unconditional refusal; an unresolvable re-verification is what stops |
| `zot`'s installed state changes again between plan and implementation | L | L | Phase 1 re-confirms `command -v zot` and `zot --version` before any dependent work and is a hard gate for Phases 3-7 |
| Doc corrections written in Phase 2 become wrong again once Phase 7 deploys | M | H | Phase 2 corrects only claims that are false *today* and states deployment status honestly as "not deployed / activation pending"; Phase 7 owns the post-deploy reconciliation of the same table |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |
| 6 | 7 | 2, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Re-confirm the environment and capture the live `zot` surface [COMPLETED]

**Goal**: Establish, with recorded evidence, the environment facts every later phase depends on,
and capture the `zot` v0.10.0 parameter surface that the corrected docs will cite. Read-only and
`--dry-run` only — no library mutation.

**Tasks**:

- [x] Re-confirm `command -v zot` and `zot --version`; record the exact output. If `zot` is
      absent or below v0.10.0, stop and mark this phase `[BLOCKED]` — Phases 3-7 depend on it.
      *(completed: `/home/benjamin/.nix-profile/bin/zot`, `zot, version 0.10.0`)*
- [x] Re-confirm `zot config show` (library ID, API key presence, data dir, database OK) and that
      the resolved data dir is `/home/benjamin/Documents/Zotero`, not the `~/Zotero` decoy.
      *(completed: data dir confirmed, database OK)*
- [x] Re-confirm the API key scope via
      `curl -s https://api.zotero.org/keys/current -H "Zotero-API-Key: $ZOTERO_API_KEY"` and
      record `.access.user`. *(completed: `library+files+write` all true)*
- [x] Capture `zot schema add` and `zot schema attach` output, plus `zot add --help` and
      `zot attach --help`, into the working notes. These are the citable source for the corrected
      version pin and flag documentation. *(completed)*
- [x] Re-run `bash agent-system/extensions/literature/scripts/zotero-export-freshness.sh` and
      record the emitted directive token and the stderr rationale. *(completed: `ZOTERO_EXPORT_STALE`,
      export 2026-07-01 predates sqlite mtime 2026-08-05)*
- [x] Re-confirm the deployed-tree gap: `ls .claude/scripts/zotero-write.sh`,
      `ls .claude/commands/literature.md`, and
      `jq -r '.extensions | keys' .claude-extensions.json`. *(completed: both missing;
      extensions = core,email,memory,nix,nvim)*
- [x] Confirm whether Zotero desktop is reachable
      (`curl -s --max-time 2 http://127.0.0.1:23119/connector/ping`), since it determines
      `zot attach`'s default route and therefore what Phase 6 will observe.
      *(completed: unreachable, connection refused)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts that the seven environment facts above still hold as
recorded in the follow-up research report (and re-confirmed at plan time on 2026-08-11). Confirm
by executing each command listed and comparing against the recorded value; any divergence is a
finding to carry forward into the later phases' content, not a reason to proceed on the stale
value.

**Files to modify**: none (evidence-gathering only; findings are carried in the implementation
notes and consumed by Phases 2, 3, 4, and 6)

**Verification**:

- Every command above ran and its output is recorded.
- `zot --version` reports v0.10.0 or later, or the phase is `[BLOCKED]` with that fact stated.
- No non-`--dry-run` `zot add` / `zot attach` call was made.

---

### Phase 2: Correct the stale documentation claims [NOT STARTED]

**Goal**: Remove every extension-doc statement that the Zotero API key is missing, that `zot` is
not installed, or that the zotero suite is deployed when it is not — and align the version pin
with the `zot` release confirmed in Phase 1. Satisfies acceptance criterion 1.

**Tasks**:

- [ ] `README.md` "Deployment Status" section: correct the three "Blocked on external `zot` CLI,
      not installed" / "no configured Zotero API key" reasons for `zotero-read.sh`,
      `zotero-write.sh`, and `zotero-setup.sh`. State the accurate current reason: `zot` v0.10.0
      and a `library+files+write` API key are both available; these scripts are undeployed
      because the extension itself is not registered in `.claude-extensions.json`.
- [ ] `README.md`: correct the "Active (deployed byte-for-byte ...)" claim for `cite-extract.sh`,
      `skill-cite/`, `cite.md`, and `zotero-search.sh` — none of these exist in the live
      `.claude/` tree. State that the whole extension is currently unregistered and that
      `.claude-extensions.json`'s `literature` key is the source of truth for "is this deployed
      right now", distinct from this table's aspirational record.
- [ ] `README.md` tool-requirements line (`- **zot** (zotero-cli-cc v0.7.0)`): update the version
      pin to the version recorded in Phase 1, and change "Optional" to reflect that the write
      path requires it.
- [ ] `scripts/zotero-write.sh` header: rewrite the "item-add empirical note" paragraph. Remove
      the "no `zot` binary or configured Zotero account is available in this development
      environment" claim. Keep the envelope-field-names-unconfirmed statement (still true until
      Phase 6 lands) and keep the pointer to `zotero-item-creation.md`. Do not change any
      executable line of the script in this phase.
- [ ] `context/project/literature/tools/zotero-scripts.md` header: replace the blanket "and are
      deployed to `.claude/scripts/`" claim with an accurate statement plus a pointer to the
      README's Deployment Status section as the nuanced record.
- [ ] `context/project/literature/patterns/zotero-item-creation.md` section 2: remove the "No
      `zot` binary, and no configured Zotero API key/account, is present in every development
      environment" claim. Retain the unconfirmed-envelope framing and the "Required follow-up"
      paragraph — Phase 6 is what closes those.
- [ ] `context/project/literature/patterns/zotero-item-creation.md` section 1: add the Phase 1
      finding that `zot add --pdf` does not auto-resolve metadata via the API, so `--doi` should
      accompany `--pdf` whenever a DOI is known, and a `--pdf`-only create yields a barer item.
- [ ] `context/project/literature/patterns/zotero-item-creation.md` section 4: state that when
      Zotero desktop is unreachable, `zot attach` takes the Web-API/cloud route and the local
      `storage/<key>/` copy does not appear until the desktop syncs it down — so the staging-path
      fallback is the expected common case for headless ingest, not a rare failure mode. Note
      that `zot attach` exposes `--via-bridge`/`--no-via-bridge` (auto-detect by default) and
      that `zotero-write.sh` passes neither.
- [ ] `context/project/literature/patterns/zotero-item-creation.md` section 6: correct the
      "which is not installed in this environment either" clause about the real CLI.
- [ ] `context/project/literature/domain/zotero-integration.md`: grep for and correct any
      remaining "no API key" / "not installed" / version-pin claims.
- [ ] Grep the whole extension for residual stale claims:
      `grep -rn "not installed\|no API key\|0\.7\.0" agent-system/extensions/literature/` and
      confirm every remaining hit is a legitimate runtime error message (e.g.
      `zotero-read.sh: zot not installed; install via: ...`) rather than a false environment
      claim.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts the doc-correction surface is the six files enumerated
above. Confirm at implementation time with the repo-wide grep in the final task; if that grep
surfaces a stale claim in a file not listed here, extend the phase to cover it rather than
deferring it.

**Files to modify**:

- `agent-system/extensions/literature/README.md` - deployment-status table, active-artifact
  claims, tool-requirements version pin
- `agent-system/extensions/literature/scripts/zotero-write.sh` - header comment block only
- `agent-system/extensions/literature/context/project/literature/tools/zotero-scripts.md` -
  header deployment claim
- `agent-system/extensions/literature/context/project/literature/patterns/zotero-item-creation.md`
  - sections 1, 2, 4, 6
- `agent-system/extensions/literature/context/project/literature/domain/zotero-integration.md` -
  any residual stale claims

**Verification**:

- `grep -rn "no configured Zotero API key\|no API key\|0\.7\.0" agent-system/extensions/literature/`
  returns no hit that asserts absence of a key or an outdated pin.
- Every remaining "not installed" hit is a runtime error string inside a dependency check, not a
  statement about this environment.
- `bash -n agent-system/extensions/literature/scripts/zotero-write.sh` passes (the header edit
  did not cross out of the comment block).
- `git diff` on `zotero-write.sh` touches comment lines only.
- No file under `.claude/` was modified.

---

### Phase 3: Wire the export-freshness gate into the write path [NOT STARTED]

**Goal**: Make `literature-ingest-online.sh` consult `zotero-export-freshness.sh` before any
Zotero write, so a stale CSL-JSON export cannot drive an unverified item creation. Satisfies the
first half of acceptance criterion 3 and work item 4.

**Tasks**:

- [ ] Add a `check_export_freshness()` helper near the existing `check_duplicate_title()` helper.
      It invokes `"$SCRIPT_DIR/zotero-export-freshness.sh"`, captures the single stdout directive
      token, and returns a classification the callers branch on. Treat `ZOTERO_EXPORT_FRESH` as
      the only clean pass; `ZOTERO_EXPORT_STALE`, `ZOTERO_EXPORT_FRESHNESS_UNKNOWN`, and
      `ZOTERO_EXPORT_FRESHNESS_ABSENT` are all "not confirmed fresh", matching how
      `zotero-search.sh` already treats them.
- [ ] Implement the task's "refuse **or** re-verify" as re-verify-then-proceed: on a not-fresh
      result, log a visible warning naming the token and rationale, and mark the run as requiring
      live-library re-verification of the classification. Do not unconditionally refuse — the
      export is persistently stale in this environment and an unconditional refusal would block
      all ingest.
- [ ] Insert the call in the `resolvable` (create-item) branch immediately before
      `check_duplicate_title "$TITLE"` — i.e. before `download_and_verify` and well before the
      `zotero-write.sh item-add` invocation.
- [ ] Insert the call in the `existing_no_pdf` (attach-to-existing) branch before the
      `zotero-resolve-pdf.sh` resolution, so a stale-snapshot classification is flagged there too.
      Note that this branch already has a corrective edge case for stale snapshots (the
      non-empty `resolved_path` check) — the new gate complements it, and must not disturb it.
- [ ] Add the not-fresh stop directive to the script's STABLE CONTRACT header block, following
      the existing `ONLINE_INGEST_*` naming convention already documented there, and describe the
      re-verification behavior alongside the existing directive tokens.
- [ ] Extend the `--dry-run` preview so it reports the freshness classification and what the run
      would do about it, keeping the dry-run branch an honest preview of the real path.
- [ ] Leave `download_and_verify()`, the `%PDF` gate, `directive_stop()`, and every existing exit
      code untouched.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:

- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` - new
  `check_export_freshness()` helper, two branch insertions, header contract block, dry-run
  preview

**Verification**:

- `bash -n agent-system/extensions/literature/scripts/literature-ingest-online.sh` passes.
- A `--dry-run` invocation on a `resolvable` fixture record reports the freshness classification
  and still emits `ONLINE_INGEST_INGESTED`.
- A `--dry-run` invocation on an `existing_no_pdf` fixture record reports the classification and
  still emits `ONLINE_INGEST_ATTACHED`.
- `grep -n "zotero-export-freshness" agent-system/extensions/literature/scripts/literature-ingest-online.sh`
  shows the helper wired in both branches.
- The `%PDF` magic-byte check in `download_and_verify()` is byte-identical to its pre-phase form
  (`git diff` shows no change to that function).

---

### Phase 4: Add DOI-normalized live pre-write dedup [NOT STARTED]

**Goal**: Refuse to create a duplicate Zotero item by checking the normalized DOI against the
**live** library (never the export snapshot) before any `item-add`. Satisfies the second half of
acceptance criterion 3 and work item 5.

**Tasks**:

- [ ] Add a `normalize_doi()` helper implementing exactly the task's specification: lowercase,
      and strip a leading `https://doi.org/` prefix (also handle the `http://` and bare
      `doi.org/` variants). Research confirmed this is load-bearing: `zot search` with the
      URL-prefixed form returns zero hits while the bare lowercase form returns one.
- [ ] Add a `check_live_doi_duplicate()` helper that calls
      `"$SCRIPT_DIR/zotero-read.sh" search "<normalized_doi>"` and parses the JSON result. Reuse
      `zotero-read.sh` rather than hand-rolling a new Web-API or sqlite reader — `zot`'s read
      commands already query the live SQLite database, independently of the stale export.
- [ ] Verify the match by exact equality on the result's `.data[].doi` field against the
      normalized query DOI. A bare "search returned something" is not a match: `zot search` also
      matches title/author/tag text, so a DOI substring could overlap unrelated content.
- [ ] Make a confirmed match a **hard stop** in the `resolvable` create-item branch, emitting a
      new named directive token (following the existing `ONLINE_INGEST_*` convention) with the
      matched item key in the message. This is deliberately stricter than the existing,
      non-blocking `check_duplicate_title()`, because the Web API performs no server-side dedup.
- [ ] Place the check after `check_export_freshness()` (Phase 3) and before
      `download_and_verify()`, so no bytes are fetched for an item that already exists.
- [ ] Handle the no-DOI case honestly: when the discovery record carries no DOI, the dedup check
      cannot run. Log that fact visibly and fall through to the existing title-similarity check
      rather than silently claiming a dedup pass.
- [ ] Handle `zotero-read.sh` failure honestly: a non-zero exit or unparseable output is
      "dedup could not be performed", logged visibly, not treated as "no duplicate found".
      Decide and document whether that condition stops or proceeds; given the never-fabricate
      posture elsewhere in this script, stopping is the consistent choice.
- [ ] When Phase 3's freshness classification was not-fresh, use this live check as the
      re-verification Phase 3 defers to — this is the mechanism that makes "re-verify against the
      live library" concrete rather than aspirational.
- [ ] Register the new directive token in the STABLE CONTRACT header block and extend the
      `--dry-run` preview to report the dedup outcome.

**Timing**: 1.25 hours

**Depends on**: 3

**Verification Tier**: local

**Files to modify**:

- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` - `normalize_doi()`,
  `check_live_doi_duplicate()`, `resolvable`-branch insertion, header contract block, dry-run
  preview

**Verification**:

- `bash -n agent-system/extensions/literature/scripts/literature-ingest-online.sh` passes.
- Normalization unit check: the helper maps `https://doi.org/10.1007/BF01063914`,
  `10.1007/BF01063914`, and `10.1007/bf01063914` all to the same normalized string.
- Known-duplicate check: a `--dry-run` `resolvable` fixture carrying a DOI already present in the
  library (e.g. `10.1007/BF01063914`, confirmed present during research) reports the dedup hard
  stop and names the matched item key.
- Known-absent check: a `--dry-run` `resolvable` fixture carrying a DOI not in the library
  proceeds past the dedup check.
- No-DOI check: a fixture with no DOI logs the "dedup not performed" message and falls through to
  the title check rather than silently passing.
- `grep -n "zotero-read.sh" agent-system/extensions/literature/scripts/literature-ingest-online.sh`
  confirms the live-library read path; no new direct `zot` or Web-API call was introduced.
- No read of `zotero-library.json` was added anywhere on the write path.

---

### Phase 5: Verify the preserved invariants and the write choke-point [NOT STARTED]

**Goal**: Demonstrate — with evidence, not assertion — that the three named invariants and the
single-write-choke-point property survive Phases 3 and 4 unchanged. Satisfies acceptance
criterion 4 and work item 6.

**Tasks**:

- [ ] Magic-byte gate: produce a `git diff` excerpt showing `download_and_verify()` and its
      `[ "$magic" != "%PDF" ]` check are unchanged across the whole task's diff, and confirm both
      call sites still stop via `directive_stop "ONLINE_INGEST_DOWNLOAD_FAILED"` before any
      Zotero write.
- [ ] Exercise the gate: point a fixture at a non-PDF file (or a URL returning HTML) and confirm
      `ONLINE_INGEST_DOWNLOAD_FAILED` is emitted and no `zotero-write.sh` call follows.
- [ ] DOI-only-fallback honest surfacing: confirm the `--doi`-without-`--pdf` fallback is still
      documented and still surfaced as "no PDF attached" rather than a success, in both
      `zotero-write.sh`'s header and `zotero-item-creation.md`; confirm the
      `ONLINE_INGEST_NO_PDF` stop path is unchanged.
- [ ] Never-fabricate-keys: confirm the `tier == "absent"` full stop in the `existing_no_pdf`
      branch and the "returned tier=X but no zotero_key" stop are both unchanged, and that
      neither Phase 3's nor Phase 4's insertions introduce any code path that synthesizes an item
      key.
- [ ] Write choke-point: run
      `grep -rn "zot \|zot add\|zot attach\|api.zotero.org" agent-system/extensions/literature/scripts/`
      and confirm every mutating call still routes through `zotero-write.sh`; no caller invokes
      `zot`'s write subcommands or the Web API directly.
- [ ] Record all of the above as an evidence block in the implementation notes, so the acceptance
      criterion is closed by demonstration rather than by claim.

**Timing**: 0.5 hours

**Depends on**: 4

**Verification Tier**: local

**Files to modify**: none (verification-only; findings recorded in the implementation summary)

**Verification**:

- Each of the four invariants has a named piece of evidence (diff excerpt, command output, or
  executed-fixture result) recorded.
- The magic-byte fixture run emitted `ONLINE_INGEST_DOWNLOAD_FAILED` with no subsequent
  `zotero-write.sh` invocation in the log.
- The choke-point grep shows zero direct `zot` write calls or `api.zotero.org` write requests
  outside `zotero-write.sh`.

---

### Phase 6: Gated live envelope confirmation against the production library [NOT STARTED]

**Goal**: Confirm the real `.data.*` field paths returned by `zot add --pdf` and `zot attach`, and
record them, closing the standing empirical unknown. Satisfies acceptance criterion 2 and work
item 2. **This phase performs a real, hard-to-reverse write into the user's 904-item production
Zotero library and MUST NOT proceed past the dry-run stage without explicit user confirmation.**

**Tasks**:

- [ ] Draft the test design and present it to the user for approval before any non-`--dry-run`
      call. The design must name: the specific DOI and PDF to be added (a real, useful
      open-access paper worth having in the library — never throwaway garbage), the exact
      commands, what will be captured, and the rollback path (Zotero trash/delete by the recorded
      item key).
- [ ] Confirm the chosen DOI is not already in the library using the Phase 4 normalization plus
      `zotero-read.sh search` — the same code path the write guard uses, so the test also
      exercises it.
- [ ] Run `zot --json add --doi <doi> --pdf <verified-pdf> --dry-run --idempotency-key <key>`
      first and record the preview output.
- [ ] **GATE**: obtain explicit user confirmation to proceed with the real write. If the user
      declines or does not respond, stop here and close the phase
      `[COMPLETED WITH EXCLUSIONS]` with a `#### Reasoned Exclusions` record — acceptance
      criterion 2 explicitly permits documenting why confirmation is still pending.
- [ ] After confirmation: run the real `item-add` through `zotero-write.sh` (not `zot` directly,
      so the choke-point is what gets exercised), capture the full stdout, and record
      `jq '.data'` on the envelope.
- [ ] Run one real `attach-file` — attaching a second verified PDF to an existing item, or to the
      item just created — through `zotero-write.sh`, and record `jq '.data'` on that envelope.
- [ ] Record the confirmed field paths in `zotero-item-creation.md` section 2, replacing the
      "unconfirmed empirical unknown" framing with the observed shape. Note which of the probed
      candidates (`.data.key`, `.data.item.key`, `.data.itemKey`;
      `.data.attachment.key`, `.data.attachmentKey`, `.data.attachment_key`,
      `.data.attachments[0].key`) actually resolved.
- [ ] Decide, and state the reason for, either simplifying `extract_envelope_field()` /
      `resolve_storage_path_from_envelope()` to the confirmed paths or keeping the multi-path
      probing. Recommended default: keep the probing (it costs nothing and insulates against
      `zot`'s envelope changing across releases, as its flag surface already has between v0.7.0
      and v0.10.0) and state that reason explicitly in the doc rather than leaving it implicit.
- [ ] Record whether the attachment landed in local `storage/<key>/` or took the cloud route, and
      whether `item-add`'s internal attach step is bridge-routable — the open question Phase 1's
      `zot schema` capture narrowed but did not close.
- [ ] Report the created item key to the user, along with the rollback instruction, whether or
      not the item is kept.

**Timing**: 0.75 hours

**Depends on**: 5

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/literature/context/project/literature/patterns/zotero-item-creation.md`
  - section 2 (confirmed field paths, probing-retention decision), section 4 (observed storage
  route)

**Verification**:

- Either: `zotero-item-creation.md` section 2 records live-confirmed field paths with the raw
  `jq '.data'` evidence, **or** the phase carries `[COMPLETED WITH EXCLUSIONS]` with a
  `#### Reasoned Exclusions` record stating exactly why confirmation is still pending.
- If a real write occurred: the created item key is recorded and reported, and the
  probing-retention decision is stated with its reason.
- No write was made without the explicit user gate having been passed.
- `zotero-write.sh` was the entry point for both real calls (choke-point preserved).

---

### Phase 7: Activate the literature extension, deploy, and verify byte identity [NOT STARTED]

**Goal**: Register the literature extension as active for the first time in this repository,
deploy it, and confirm the three previously-inactive zotero scripts are byte-identical between
source and deployed copies. Satisfies acceptance criterion 5 and the re-scoped work item 3.

**Tasks**:

- [ ] Re-confirm the gap has not closed on its own:
      `jq -r '.extensions | keys' .claude-extensions.json` still lacks `literature`.
- [ ] Enumerate and present the activation blast radius to the user from `manifest.json` before
      activating: 1 agent (`literature-agent.md`), 2 commands (`literature.md`, `cite.md`), 2
      skills (`skill-literature`, `skill-cite`), 2 context roots, 36 scripts, and a
      `merge-sources/claudemd.md` merge that adds the `--lit` documentation section to the
      generated `CLAUDE.md`. Note the declared `core` dependency (already active). This is
      materially larger than "three scripts" and the user should see it before it lands.
- [ ] Activate using a one-off headless invocation of the existing deploy engine:
      `manager.load("literature", {confirm = false})` via
      `neotex.plugins.ai.shared.extensions.init`, run through `nvim --headless` from the
      repository root. This is an **operation**, not a source edit — it requires no change to
      `deploy-headless.sh` and therefore keeps every edit in this task inside the literature
      extension's territory. If the headless call is unavailable or fails, the sanctioned
      fallback is asking the user to select "literature" once in the `<leader>al` picker; do not
      work around it by editing core scripts, and never by hand-copying files into `.claude/`.
- [ ] Confirm registration: `jq -r '.extensions.literature.status' .claude-extensions.json`
      reports `active` and `installed_files` is populated.
- [ ] Run the ordinary non-destructive resync (`bash .claude/scripts/deploy-headless.sh`) so the
      now-active extension picks up every Phase 2/3/4/6 source edit. Do **not** use `--wipe`.
- [ ] Verify byte identity for the three activated scripts, plus the edited ingest script:
      `diff` (or `cmp`) each of `zotero-write.sh`, `zotero-read.sh`, `zotero-setup.sh`, and
      `literature-ingest-online.sh` between
      `agent-system/extensions/literature/scripts/` and `.claude/scripts/`.
- [ ] Confirm the previously-missing artifacts now exist: `.claude/commands/literature.md`,
      `.claude/commands/cite.md`, `.claude/skills/skill-cite/`, `.claude/scripts/zotero-search.sh`,
      `.claude/scripts/cite-extract.sh`.
- [ ] Reconcile `README.md`'s Deployment Status section with post-deploy reality: move the three
      activated scripts out of the "Inactive" table into the active set, correct the "Five zotero
      scripts remain declared but absent" paragraph to reflect what is actually absent now
      (`zotero-chunk.sh` and `zotero-attach-chunks.sh` remain intentionally superseded), and add
      the one-line note that `.claude-extensions.json`'s `literature` key — not this table — is
      the source of truth for current deployment state.
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and confirm it passes, including the
      `check_deployed_script_drift()` check that now has both copies to compare for the newly
      deployed scripts.
- [ ] Confirm no file under `.claude/` was hand-authored: every change there came from the deploy
      engine.

**Timing**: 0.75 hours

**Depends on**: 2, 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the activation blast radius is the manifest-declared
counts above (1 agent / 2 commands / 2 skills / 2 context roots / 36 scripts / 1 merge source).
Confirm at implementation time by re-reading `manifest.json` and by comparing the post-activation
`.claude-extensions.json` `installed_files` array against that expectation; report any divergence
rather than accepting it silently.

**Files to modify**:

- `agent-system/extensions/literature/README.md` - Deployment Status section reconciled to
  post-deploy reality
- `.claude-extensions.json` and the `.claude/` tree - written by the deploy engine only, never by
  hand

**Verification**:

- `jq -r '.extensions.literature.status' .claude-extensions.json` reports `active`.
- `cmp` reports byte identity for `zotero-write.sh`, `zotero-read.sh`, `zotero-setup.sh`, and
  `literature-ingest-online.sh` between source and `.claude/scripts/`.
- `.claude/commands/literature.md` exists.
- `bash .claude/scripts/check-extension-docs.sh` exits 0.
- The README Deployment Status table matches what `.claude-extensions.json` and the live
  `.claude/` tree actually contain.
- `git status` shows no hand-authored file under `.claude/`.

---

## Testing & Validation

- [ ] `bash -n` passes on `literature-ingest-online.sh`, `zotero-write.sh`, `zotero-read.sh`, and
      `zotero-setup.sh`.
- [ ] `--dry-run` runs on both a `resolvable` and an `existing_no_pdf` fixture emit their existing
      terminal directives (`ONLINE_INGEST_INGESTED` / `ONLINE_INGEST_ATTACHED`) and additionally
      report the freshness classification and dedup outcome.
- [ ] The DOI-normalization helper maps the prefixed, bare, and lowercase forms to one string.
- [ ] A known-duplicate DOI produces the dedup hard stop with the matched item key named.
- [ ] A non-PDF download produces `ONLINE_INGEST_DOWNLOAD_FAILED` with no subsequent Zotero write.
- [ ] `zotero-resolve-pdf.sh`'s `tier == "absent"` path still stops honestly with no fabricated
      key.
- [ ] No script other than `zotero-write.sh` issues a Zotero mutation.
- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0 after deployment.
- [ ] Source and deployed copies of the three activated scripts are byte-identical.
- [ ] `grep -rn "task [0-9]" agent-system/extensions/literature/` finds no task-number reference
      introduced by this work (deliverable rule).
- [ ] No file under `.claude/` was created or edited by hand.

## Artifacts & Outputs

- `agent-system/extensions/literature/README.md` (corrected, then reconciled post-deploy)
- `agent-system/extensions/literature/scripts/zotero-write.sh` (header corrected)
- `agent-system/extensions/literature/scripts/literature-ingest-online.sh` (freshness gate +
  DOI dedup)
- `agent-system/extensions/literature/context/project/literature/patterns/zotero-item-creation.md`
  (corrected claims; live-confirmed envelope field paths, or a documented pending reason)
- `agent-system/extensions/literature/context/project/literature/tools/zotero-scripts.md`
  (deployment claim corrected)
- `agent-system/extensions/literature/context/project/literature/domain/zotero-integration.md`
  (residual stale claims corrected)
- `.claude-extensions.json` with a `literature` entry, and the deployed `.claude/` tree — both
  written by the deploy engine
- `specs/038_activate_zotero_write_back_path/summaries/02_zotero-write-back-activation-summary.md`

## Rollback/Contingency

- **Source edits** (Phases 2-6): plain `git revert` of the per-phase commits. Every phase commits
  separately, so any single phase can be backed out without disturbing the others.
- **Phase 6's real Zotero write**: the created item key is recorded before anything else happens.
  Rollback is deleting that item (and its attachment) via Zotero's trash. If the user declines the
  gate, nothing was written and there is nothing to roll back.
- **Phase 7's activation**: `manager.unload("literature", ...)` via the same headless path, or
  deselecting it in the `<leader>al` picker, removes the `installed_files` and the
  `.claude-extensions.json` entry. `.claude/` is a disposable deploy artifact regenerable from the
  source store, so a botched deploy is recoverable with a resync; `.syncprotect` already protects
  `context/repo/project-overview.md` across any regeneration.
- **If `zot` disappears between phases**: Phase 1 is the gate. Phases 2 and 7's documentation work
  can still land (the doc corrections are about the *current* state and would need re-wording);
  Phases 3-6 mark `[BLOCKED]` with the fact recorded rather than proceeding on a stale assumption.

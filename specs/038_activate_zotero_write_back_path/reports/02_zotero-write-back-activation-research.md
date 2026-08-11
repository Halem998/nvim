# Research Report: Task #38 — Zotero Write-Back Path Activation (Follow-Up)

- **Task**: 38
- **Started**: 2026-08-11
- **Completed**: 2026-08-11
- **Effort**: 3-6 hours (unchanged estimate)
- **Dependencies**: None
- **Sources/Inputs**: Codebase (agent-system/extensions/literature/**), live `zot` CLI calls
  (read-only + `--dry-run` only), live Zotero Web API key-scope check, live filesystem checks of
  the deployed `.claude/` tree, `.claude-extensions.json`, `deploy-headless.sh` and its governing
  doc.
- **Artifacts**: this report; supersedes/extends
  `specs/038_activate_zotero_write_back_path/reports/01_zotero-integration-review.md` (seed
  report) — that report's facts are NOT re-derived below except where they have changed.
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The cross-repo `zot` blocker has resolved since the seed report was written.** `zot` v0.10.0
  is now installed and fully functional (`command -v zot` succeeds; `zot config show` reports a
  valid API key, library ID, and a working SQLite connection to the correct
  `/home/benjamin/Documents/Zotero` data dir). Work item 2 (live envelope confirmation) is now
  technically executable, but doing the REAL (non-dry-run) `item-add`/`attach-file` calls it
  requires means writing a real item into the user's 904-item production Zotero library — that
  step was deliberately left undone here (see "What Was Deliberately Not Done" below) and needs
  an explicit, planned test design, not a silent research-phase side effect.
- **A bigger, previously-unknown blocker was found for work item 3**: the ENTIRE literature
  extension — not just the 5 "inactive" zotero scripts — is currently absent from the live
  `.claude/` tree in this repo. `.claude/commands/literature.md` does not exist;
  `.claude/scripts/zotero-search.sh`, `cite-extract.sh`, and `.claude/skills/skill-cite/` also do
  not exist, despite the README's deployment-status table describing them as "Active
  (deployed)". `.claude-extensions.json` has no `literature` key at all. This means
  `deploy-headless.sh`'s default (non-destructive) mode — which only resyncs extensions the
  state file already marks active — cannot deploy any of this by itself. Work item 3 needs to be
  re-scoped: it requires first-time activation of the whole extension (interactively via the
  picker, or a headless `manager.load("literature", {confirm=false})` call, both discussed
  below), not merely flipping 3 rows in a status table.
- `zot`'s own read/search surface (`zot search <doi>`, `zot duplicates --by doi`) already reads
  the **live SQLite database** (confirmed via `zot config show`'s Data Dir and a live query),
  never the stale CSL-JSON export — this is a ready-made, already-correct building block for work
  item 5's DOI-normalized dedup requirement; it does not need to be built from scratch.
- The freshness hazard is still live right now: `zotero-export-freshness.sh` (run live during
  this research) still emits `ZOTERO_EXPORT_STALE` (export 2026-07-01 vs. sqlite mtime
  2026-08-05, now even further stale than the seed report recorded).
- `zot`'s CLI surface has grown since the v0.7.0 pin the docs cite, in ways that affect the
  storage-repointing hazard in `zotero-item-creation.md`: `zot attach` now has a
  `--via-bridge`/`--no-via-bridge` route (default: auto-detect), and Zotero desktop is currently
  NOT running on this machine — meaning the "resolve the durable local `storage/<key>/` path"
  fallback in `literature-ingest-online.sh` will hit its fallback branch as the **normal case**,
  not a rare edge case, until/unless a desktop session is active.

## Context & Scope

This is a follow-up research pass on top of the interactively-gathered seed report
(`reports/01_zotero-integration-review.md`), whose environment facts are treated as a baseline,
re-confirmed live where practical, and superseded only where this pass found something new or
changed. Scope: re-verify the seed report's facts, especially the stated "one remaining hard
blocker" (`zot` not installed); investigate the `zot` v0.10.0 flag surface directly (the seed
report could only cite PyPI's version string, not the CLI's actual `--help`/`schema` output);
determine what "the normal extension deploy flow" concretely requires in this repo; and confirm
the DOI-dedup and freshness-gate mechanics needed for work items 4 and 5.

## Findings

### 1. `zot` v0.10.0 is now installed and live — re-verify before editing, it may move again

```
$ command -v zot
/etc/profiles/per-user/benjamin/bin/zot
$ zot --version
zot, version 0.10.0
$ zot config show
Library ID: 2622830
API Key:    ***W05U
Data Dir:   /home/benjamin/Documents/Zotero
Database:   /home/benjamin/Documents/Zotero/zotero.sqlite (OK)
```

`zot --json stats` succeeds with no `ZOT_DATA_DIR` set in this shell's environment at all —
`zot` resolves its own data dir from its own config (`zot config show`), independently of the
extension's `ZOT_DATA_DIR`/`zotero-index.json` resolution ladder in `zotero-write.sh`/
`zotero-read.sh`/`zotero-setup.sh`. Both ladders currently agree on the correct directory (not
the `~/Zotero` decoy), but they are two independent resolution paths worth naming explicitly in
the corrected docs so a future reader doesn't assume `ZOT_DATA_DIR` is what makes `zot` itself
work.

**This is a live, moving fact** (the seed report explicitly says the cross-repo dotfiles
provisioning task was still open) — confirm `command -v zot` again immediately before editing,
per the task's own binding instruction to re-confirm verified-live facts.

### 2. The `zot` v0.10.0 flag surface differs from what the docs assume in ways worth recording

Captured directly via `zot --help`, `zot add --help`, `zot attach --help`, and `zot schema add`
(a machine-readable param schema `zot` now ships that the extension docs don't mention at all):

- `zot add --pdf PATH [--doi DOI] [--dry-run] [--idempotency-key KEY] [--no-resolve]` — matches
  `zotero-write.sh item-add`'s existing flag forwarding exactly. One nuance not currently
  documented: **`--pdf`'s own help text says "metadata not auto-resolved by API"** — unlike
  `--doi`, which fetches Crossref metadata before posting. A `--pdf`-only create (no `--doi`)
  may therefore produce a barer item than the pattern doc implies. Passing `--doi` alongside
  `--pdf` (already zotero-write.sh's supported combination) is the way to get both the
  attachment and Crossref-enriched metadata; worth calling out explicitly in the corrected
  `zotero-item-creation.md`.
- `zot attach KEY --file PATH [--via-bridge|--no-via-bridge] [--dry-run] [--idempotency-key KEY]`
  — the `--via-bridge`/`--no-via-bridge` pair is new (not mentioned anywhere in the extension's
  docs or in `zotero-write.sh`, which does not pass either flag, leaving `zot` to auto-detect).
  Per `zot attach --help`: the bridge path (desktop reachable) writes to local `storage/`
  immediately; the Web-API path (desktop unreachable) uploads to zotero.org cloud storage, which
  only appears locally after the desktop syncs it down. **Zotero desktop is not running on this
  machine right now** (`curl 127.0.0.1:23119/connector/ping` → connection refused, `000`), so
  today's default-auto-detect behavior for both `attach-file` and item-add's internal attach
  step will take the cloud path. `resolve_storage_path_from_envelope()`'s search of the local
  `storage/<key>/` tree will therefore predictably fail and fall through to the staging-path
  fallback (already implemented, already honest) as the **common case**, not a rare one, for any
  background/headless ingest run. This doesn't require new code — the existing fallback already
  handles it — but the docs should say so plainly rather than implying the fallback is
  exceptional.
- No `--via-bridge` equivalent appears on `zot add` itself (only on `zot attach`); its own
  `--help` and `zot schema add` output list only `--doi`, `--url`, `--from-file`, `--pdf`,
  `--dry-run`, `--idempotency-key`, `--no-resolve`. This suggests `item-add`'s internal
  attach-after-create step is not bridge-routable the way a standalone `attach-file` call is —
  worth confirming empirically during the live envelope test (work item 2), since it directly
  determines whether create-item PDFs can ever land in local storage without a follow-up
  `attach` call.
- `zot schema add`/`zot schema attach` emit each command's **input parameter** schema (types,
  flags, `since` version, `safety_tier`) but not a return/response schema — so this new
  machine-readable surface narrows the still-open question (confirmed param names) without
  fully closing it (the `.data.*` **output** envelope shape). Live envelope confirmation
  (work item 2) is still the only way to pin down `.data.key`/`.data.attachment.key`/etc.
- `zot duplicates [--by doi|title|both] [--threshold FLOAT]` and plain `zot search <query>` both
  exist and both read the live SQLite library (see Finding 5 below) — see that finding for why
  this matters directly for work item 5.

### 3. The literature extension is currently NOT deployed at all in this repo — bigger than the README's stated gap

Direct filesystem checks against the live `.claude/` tree in this repo:

```
$ ls .claude/scripts/zotero-*.sh          # -> No such file or directory
$ find .claude -iname '*cite*'            # -> (nothing)
$ ls .claude/commands/literature.md       # -> No such file or directory
$ jq -r '.extensions | keys' .claude-extensions.json
["core", "email", "memory", "nix", "nvim"]
```

The README's own "Deployment Status" section states `cite-extract.sh`, `skill-cite/`, `cite.md`,
and `zotero-search.sh` are "Active (deployed byte-for-byte ... to `.claude/scripts/`,
`.claude/skills/`, `.claude/commands/`)". **That is not true of the current live `.claude/`
tree in this repo** — none of those files exist there, and neither does `/literature` itself
(`commands/literature.md` is absent). The README's own "Extension Tracking Gap" subsection
already names the root cause without naming this consequence: `literature` has no entry in
`.claude-extensions.json`, so it is not merely "the 5 zotero scripts are undeployed" — the whole
extension has apparently never been (or is no longer) registered as an active extension in this
repo, and everything the README calls "Active" is realistically deployed only via the
`skill-literature/SKILL.md` **source-path fallback ladder** it documents for itself
(`.claude/scripts/X` → `$(dirname "$0")/../../scripts/X` → `.claude/extensions/literature/scripts/X`),
never via an actual flat deploy. `literature-ingest-online.sh` has no equivalent ladder of its
own for `zotero-write.sh` — it doesn't need one, because it resolves `zotero-write.sh` via a
same-directory `$SCRIPT_DIR` reference, so the two travel together as siblings whichever tree
they're invoked from (source or, once deployed, `.claude/scripts/`).

**Consequence for work item 3 and acceptance criterion 5**: `deploy-headless.sh`'s default,
non-destructive mode explicitly only "force-resyncs every other **currently-active** extension"
(per its own header comment) — it will not deploy `literature` no matter how many times it's
run, because `literature` isn't in the active set to begin with. Two real options exist to close
this, both consistent with `regeneration-is-manual-only.md`'s "interactive by default, headless
when driven deliberately" principle (that doc explicitly sanctions `deploy-headless.sh` for
"scripted, CI, and agent-driven contexts where no human is present to answer a dialog", provided
the invocation is explicit and deliberate, not a silent side effect):

1. **Interactive**: a human selects "literature" in the `<leader>al` picker once, which calls
   `manager.load("literature", ...)` and durably registers it in `.claude-extensions.json`;
   ordinary `deploy-headless.sh` resyncs keep it current after that.
2. **Headless one-time activation**: `neotex.plugins.ai.shared.extensions.init`'s `manager.load`
   function (`lua/neotex/plugins/ai/shared/extensions/init.lua:269`) already accepts a
   `{confirm = false}` option and is exactly what `deploy-headless.sh` itself calls internally to
   bootstrap `core` on a repo's first deploy (see that script's own "Bootstrap safety"
   rationale). A small, explicit extension to that pattern — e.g. a `--load NAME` flag on
   `deploy-headless.sh`, or a one-off headless `nvim` invocation calling
   `manager.load("literature", {confirm = false})` directly — would activate `literature` for
   the first time without opening an interactive dialog. This is plan/implementation-phase design
   work, not something this research pass should decide unilaterally; both options should be
   named for the planner. Note this call site is scripted infrastructure, not literature-domain
   code, so any change belongs in `agent-system/extensions/core/scripts/deploy-headless.sh` (or a
   new sibling script), never inside the literature extension's own source tree.

Either path, once literature is active, makes the existing `provides.scripts` declarations (which
already correctly list all 5 previously-"inactive" scripts, confirmed via `manifest.json`) take
effect via the ordinary resync engine — no manifest edits are needed for that part.

A secondary, smaller stale-doc site: `tools/zotero-scripts.md`'s header line ("The scripts below
... are deployed to `.claude/scripts/`") flatly contradicts the README's own more nuanced
deployment-status table (and, per the finding above, contradicts the live `.claude/` tree too).
This should be corrected alongside the README table, `zotero-write.sh`'s header, and the
tool-requirements version pin (all named in the task description) as part of work item 1.

### 4. `zotero-export-freshness.sh` is still live-STALE right now (confirms hazard #3, now further along)

```
$ bash agent-system/extensions/literature/scripts/zotero-export-freshness.sh
Rationale: reference timestamp 2026-07-01 ... < sqlite mtime 2026-08-05 ...
ZOTERO_EXPORT_STALE
```

Same classifier, same conclusion as the seed report, re-run live and still stale (the sqlite has
had five more weeks to diverge from the export since the seed report's own check). No wiring
into the write path exists yet anywhere in `literature-ingest-online.sh` — confirmed by reading
the full 657-line script: no call to `zotero-export-freshness.sh` or its
`ZOTERO_EXPORT_STALE`/`ZOTERO_EXPORT_FRESH` tokens appears anywhere in it. Work item 4 is a net
addition, not a modification of existing (non-existent) gating logic. The natural insertion
point is immediately before the `check_duplicate_title` / `download_and_verify` sequence in both
the `resolvable` and `existing_no_pdf` branches (lines ~506 and ~558 of
`literature-ingest-online.sh`), gating (or re-verifying against the live library, per the task's
work item 4 wording) before any Zotero write is attempted.

### 5. Work item 5's DOI-normalized dedup already has a ready, live-database-backed building block

`zot`'s own read commands do **not** touch the stale CSL-JSON export at all — they query the live
SQLite database directly (confirmed by `zot config show`'s `Data Dir`/`Database` fields pointing
at the correct, live `/home/benjamin/Documents/Zotero/zotero.sqlite`, independently of
`zotero-write.sh`'s separate `ZOT_DATA_DIR` resolution). Two concrete, already-existing `zot`
subcommands do exactly what work item 5 asks for:

```
$ zot --json search "10.1007/BF01063914"
{"data": [{"key": "D723USWN", "doi": "10.1007/BF01063914", ...}], ...}   # 1 exact hit

$ zot --json search "https://doi.org/10.1007/BF01063914"    # unnormalized (URL prefix)
{"data": []}                                                  # 0 hits — confirms the task's
                                                                # explicit normalization
                                                                # requirement is load-bearing,
                                                                # not defensive-only

$ zot --json search "10.1007/bf01063914"                     # lowercase, no prefix
{"data": [...]}                                                # 1 hit — search is
                                                                # case-insensitive on its own

$ zot --json duplicates --by doi --limit 3
{"data": [{"group": 1, "match_type": "doi", "score": 1.0, "items": [...]}], ...}
```

Recommendation for the plan: implement the pre-write dedup check as a call to `zotero-read.sh
search "<normalized_doi>"` (once deployed — see Finding 3) rather than hand-rolling a new Web-API
or sqlite-reading helper. The extension-side normalization (lowercase, strip the
`https://doi.org/` prefix, per the task's explicit spec) is still necessary before the call —
`zot search`'s own case-insensitivity does not extend to stripping the URL scheme/host, as shown
above — and the result's `.data[].doi` field should still be checked for exact equality against
the normalized query DOI (not just "search returned something"), since `zot search` also matches
against title/author/tag text and a DOI substring could in principle overlap unrelated text.
This check should be a **hard stop** on a match (unlike the existing, deliberately non-blocking
`check_duplicate_title()` in `literature-ingest-online.sh`), consistent with the task's framing
that the Web API performs no server-side dedup of its own.

### 6. Live API key scope re-confirmed unchanged

```
$ curl -s https://api.zotero.org/keys/current -H "Zotero-API-Key: $ZOTERO_API_KEY" | jq '.access.user'
{"library": true, "files": true, "write": true}
```

Matches the seed report exactly. No change here; re-confirmed as instructed rather than assumed
stale-safe.

## What Was Deliberately Not Done

- **No real (non-`--dry-run`) `zot add`/`zot attach` call was made against the live library.**
  Doing so would create a real item (or attachment) in the user's 904-item production Zotero
  library — a hard-to-reverse, outward-facing action this research pass is not the right place to
  take unilaterally. All `zot` calls made here were read-only (`stats`, `list`, `search`,
  `duplicates`, `config show`, `schema`) or explicitly `--dry-run` (which `zot`'s own `add
  --dry-run` help text confirms "preview[s] ... without calling the API" — i.e., no network
  write occurs). Work item 2's live envelope confirmation is now technically unblocked (the only
  prior blocker, `zot` not being installed, has resolved) and should be executed deliberately
  during planning/implementation, with an explicit test design: e.g., adding one real,
  useful paper (not throwaway garbage) so the mutation is itself a legitimate addition to the
  library, or an explicit create-then-verify-then-trash test the user has agreed to.
- **No attempt was made to activate the literature extension** (neither via the interactive
  picker nor by extending `deploy-headless.sh`) — that is implementation-phase work per Finding
  3's two named options, requiring a planning decision this report does not make unilaterally.

## Recommendations (supersedes/refines the seed report's item list)

1. Correct stale docs per the task's list, **plus** `tools/zotero-scripts.md`'s blanket
   "deployed" claim (Finding 3) and the `--pdf`-metadata-not-auto-resolved and
   `--via-bridge`/desktop-not-running nuances (Finding 2) in `zotero-item-creation.md`.
2. Design and execute the live envelope confirmation (work item 2) as a deliberate,
   explicitly-scoped step — now unblocked, not yet safe to do silently.
3. Re-scope work item 3 to include first-time extension activation (Finding 3's two options),
   not just a documentation-table flip; get the planner to pick between the interactive and
   headless-`manager.load` paths.
4. Wire `zotero-export-freshness.sh` into both `literature-ingest-online.sh` branches before any
   write (Finding 4's insertion points).
5. Implement DOI dedup as a hard-stop call to `zotero-read.sh search "<normalized_doi>"` with
   exact-DOI-match verification on the result (Finding 5), reusing `zot`'s already-live-database
   read path rather than adding a new one.
6. Keep `zotero-write.sh` as the sole write choke-point — nothing found in this pass suggests
   otherwise; `zot`'s new `bridge`/`--via-bridge` surface is additional routing logic that would
   live inside this same choke-point if ever adopted, not a reason to bypass it.

## Risks & Mitigations

- **Risk**: treating work item 3 as "just deploy 3 scripts" will produce a plan that silently
  fails (resync engine skips an inactive extension) or, worse, tempts an agent toward a
  hand-copy into `.claude/` that violates the source-store/deploy boundary rule. **Mitigation**:
  the plan must explicitly name extension activation as a prerequisite step, using one of
  Finding 3's two sanctioned mechanisms.
- **Risk**: assuming `zot add --pdf`'s metadata is Crossref-enriched by default (per the older
  pattern-doc phrasing) could produce bare items when no `--doi` is passed alongside `--pdf`.
  **Mitigation**: always pass `--doi` alongside `--pdf` when a DOI is known (already
  `zotero-write.sh`'s supported combination), and document the bare-item case for the DOI-less
  fallback.
- **Risk**: assuming attachments always land in local `storage/` immediately (desktop-bridge
  path) when Zotero desktop is typically not running during unattended/background ingest runs.
  **Mitigation**: no code change is strictly required (the existing staging-path fallback
  already handles this), but the docs and any future monitoring should treat the fallback as
  the expected common case, not a rare failure mode.
- **Risk**: live-testing work item 2 against the real library without a defined test plan could
  either pollute the library with a throwaway item or be skipped indefinitely out of caution.
  **Mitigation**: the plan should name a concrete test DOI/PDF (ideally a real paper worth
  having) and a rollback plan (Zotero's trash/delete) if the test item turns out unwanted.

## Context Extension Recommendations

- **Topic**: `zot` CLI flag/schema surface (v0.10.0).
  **Gap**: `context/project/literature/tools/zotero-scripts.md` and
  `patterns/zotero-item-creation.md` describe a v0.7.0-era understanding of `zot`'s flags with no
  mention of `--via-bridge`, `zot schema`, or `zot duplicates`.
  **Recommendation**: after this task's doc corrections land, consider a short
  `zot-cli-reference.md` note (or an expansion of the existing pattern doc) capturing the
  `zot schema <cmd>` self-description mechanism as the durable way to re-verify flags on future
  `zot` upgrades, rather than re-deriving them from `--help` text each time.
- **Topic**: extension activation state vs. documented deployment status.
  **Gap**: nothing in the literature extension's own docs currently warns a future editor that
  its "Deployment Status" table can drift arbitrarily far from the live `.claude/` tree because
  the extension isn't tracked in `.claude-extensions.json` at all.
  **Recommendation**: once activated (this task or a follow-up), add a one-line note to the
  README's Deployment Status section pointing at `.claude-extensions.json`'s `literature` key as
  the actual source of truth for "is this deployed right now", distinct from the
  aspirational/historical table.

## Appendix

### Commands run (read-only or `--dry-run` only; none mutate the live Zotero library)

```
command -v zot; zot --version; zot config show
zot --help; zot add --help; zot attach --help; zot config --help; zot schema add
zot --json stats
zot --json list --type journalArticle --limit 50
zot --json search "10.1007/BF01063914"
zot --json search "https://doi.org/10.1007/BF01063914"
zot --json search "10.1007/bf01063914"
zot --json duplicates --by doi --limit 3
zot --json add --doi "10.1038/s41586-023-06139-9" --dry-run
zot --json add --pdf <local non-PDF file> --dry-run
curl -s https://api.zotero.org/keys/current -H "Zotero-API-Key: $ZOTERO_API_KEY"
curl -s --max-time 2 http://127.0.0.1:23119/connector/ping -o /dev/null -w "%{http_code}"
bash agent-system/extensions/literature/scripts/zotero-export-freshness.sh
ls / find against .claude/scripts, .claude/commands, .claude/skills, .claude-extensions.json
```

### Files read in full

- `agent-system/extensions/literature/scripts/zotero-write.sh`
- `agent-system/extensions/literature/scripts/zotero-read.sh`
- `agent-system/extensions/literature/scripts/zotero-setup.sh`
- `agent-system/extensions/literature/scripts/zotero-export-freshness.sh`
- `agent-system/extensions/literature/scripts/literature-ingest-online.sh`
- `agent-system/extensions/literature/README.md`
- `agent-system/extensions/literature/context/project/literature/patterns/zotero-item-creation.md`
- `agent-system/extensions/literature/context/project/literature/domain/zotero-integration.md`
- `agent-system/extensions/literature/context/project/literature/tools/zotero-scripts.md`
- `agent-system/extensions/core/scripts/deploy-headless.sh` (header/usage)
- `agent-system/extensions/core/scripts/check-extension-docs.sh` (drift-check logic excerpt)
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` (excerpt)
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` (grep excerpts)
- `agent-system/extensions/literature/commands/literature.md` (grep excerpts)

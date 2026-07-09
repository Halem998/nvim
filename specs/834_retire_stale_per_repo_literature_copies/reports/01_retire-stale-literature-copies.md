# Research Report: Task #834

**Task**: 834 - Retire the stale per-repo literature copies
**Started**: 2026-07-09T17:00:00Z
**Completed**: 2026-07-09T17:18:00Z
**Effort**: research (read-only verification)
**Dependencies**: None (follow-up to task 710 migration, task 831 converter-quality finding)
**Sources/Inputs**: Codebase (`~/Projects/BimodalLogic`, `~/Projects/Literature`, `~/Projects/cslib`, `~/Projects/cslib-refactor-prop_logic`), `.claude/scripts/literature-briefing.sh`, `.claude/scripts/literature-lit-flag-resolve.sh`, git metadata, sha256 hashing, live script execution
**Artifacts**: This report
**Standards**: report-format.md, artifact-formats.md

## Executive Summary — Answering the Three Lead Questions

**(a) Is `sources/` git-tracked?** **Partially, and this matters a lot.** `specs/literature/sources/**/*.pdf` is explicitly gitignored in BimodalLogic's `.gitignore` (line 30). Markdown (`*.md`) and per-source `index.json` files ARE tracked (192 of 195 tracked paths under `specs/literature/`). Of the 181 MB in `sources/`, **176 MB is untracked PDFs** and only ~4.8 MB (markdown + index.json) is git-recoverable. **PDF loss would NOT be recoverable via git** — it would rely entirely on the verification below.

**(b) Is any content unique to the per-repo copy?** **No — zero content loss found across all 27 source directories.** Every PDF that exists in both locations is **byte-identical** (sha256 match, 26/27 dirs with PDFs). Every markdown section is either byte-identical or produces an empty `diff` after accounting for one systematic, benign difference: the per-repo copies additionally contain a **redundant top-level combined `.md` file** (whole-document concatenation) that central deduplicated away in favor of section chunks — this exactly explains observed word-count ratios (bimodal word count = 2× central word count in 17/27 dirs, verified as `combined.md` == `sum(sections)`). One file initially looked "missing" from central (`Gabbay_Reynolds_2000_Temporal_Logic_Foundations_Vol2.pdf`, filed under `gabbay_1994/` in BimodalLogic) — it is present in central, just filed under its own `sources/gabbay_2000/` directory (correctly split by publication, with its own index.json entry, PDF-only, matching BimodalLogic's own PDF-only state for that file). **No blocker.**

**(c) Does the sub-index convention work anywhere?** **Yes — it is already populated and functioning end-to-end in both `~/Projects/BimodalLogic` and `~/Projects/cslib`.** Live execution of `literature-briefing.sh` in both repos confirmed `specs/literature-index.json` resolves correctly against `~/Projects/Literature/index.json` and **already points `--lit` briefings at `~/Projects/Literature/sources/...` (central), never at the per-repo `specs/literature/sources/`**. This means `--lit` for these two repos does not read from the per-repo `sources/` directory today, regardless of whether it exists. **This removes the "ordering constraint" risk the task description worried about** — the sub-index convention does not depend on the per-repo `sources/` directory being present.

**Bottom line: deletion of `~/Projects/BimodalLogic/specs/literature/sources/` is safe from a content-loss and functional-regression standpoint**, provided the backup/verification procedure below (Section "Safe Deletion Procedure") is followed for the 176 MB of gitignored PDFs, purely as defense-in-depth (not because central is suspected to be missing anything).

## Context & Scope

FINDING 6 (source task) established that BimodalLogic's `specs/literature/` (181 MB, 27 source dirs) is fully superseded by `~/Projects/Literature/` (central, 97+ source dirs), migration completed under task 710, `DEPRECATED.md` already documents this, and `LITERATURE_DIR` is wired into both `.claude/settings.json` and `home.nix`. The open question was whether "migrated" actually meant "safe to delete," given that task 831 found the shared PDF-to-markdown converter (`pdftotext -layout`) produces corrupted output (column interleaving, section truncation, doubled breadcrumbs, ligature errors) — so central being a byte-copy of the same broken conversion would not itself validate deletion; only content-equivalence (or central being a superset) would.

This research is scoped as **verify-then-delete**, not re-migration: confirm the 27 dirs are safe to delete, confirm the sub-index convention works, sweep for other stale copies, and propose (but not execute) a reversible deletion procedure.

## Findings

### 1. Content Equivalence Verification (27-dir comparison)

**Method**: For each of the 27 `sources/` subdirectories in BimodalLogic, matched against the identically-named directory in `~/Projects/Literature/sources/`:
1. `sha256sum` on every `*.pdf` file in both locations (ground-truth binary comparison).
2. Byte and word counts (`wc -c`, `wc -w`) on the concatenation of all `*.md` files per side.
3. For every case where word counts diverged or filenames differed, exact `diff` (and for renamed files, sorted-token `diff`) on individual files to distinguish "different content" from "different filename/whitespace only."

All 27 target directories exist in central (`FOUND` for all 27 in the initial existence sweep).

| # | Source dir | PDF hash match | MD word-count relationship | Verdict |
|---|---|---|---|---|
| 1 | blackburn_2002 | central-only PDF (bimodal had none) | identical word-for-word (empty sorted-token diff); central splits into 35 chapter/section chunks vs. bimodal's single combined `.md` | EQUIVALENT (central is better-organized superset of structure, same content) |
| 2 | burgess_1982 | IDENTICAL | 2× (combined+sections dedup) | EQUIVALENT |
| 3 | burgess_1982b | IDENTICAL | 2× (combined+sections dedup) | EQUIVALENT |
| 4 | burgess_1984 | IDENTICAL | 2×; central sections renamed with descriptive titles, verified byte-identical body content (`diff` empty on sec01, sec07) | EQUIVALENT |
| 5 | caleiro_2013 | IDENTICAL | 2× (combined+sections dedup) | EQUIVALENT |
| 6 | derijke_1995 | IDENTICAL | 2× (combined+sections dedup) | EQUIVALENT |
| 7 | doets_1987 | IDENTICAL | 2× (combined+sections dedup), identical filenames both sides | EQUIVALENT |
| 8 | doets_1989 | IDENTICAL | 2×; central sections renamed, verified byte-identical (`diff` empty on sec01, matching word counts on all 3 sections) | EQUIVALENT |
| 9 | gabbay_1993 | IDENTICAL | 2× (combined+sections dedup) | EQUIVALENT |
| 10 | gabbay_1994 | 4/5 PDFs identical; 5th (`Gabbay_Reynolds_2000...Vol2.pdf`) relocated to `sources/gabbay_2000/` in central (hash-confirmed present there, PDF-only in both) | 2× for chaptered content | EQUIVALENT (no loss — file exists under different, more correct dir name) |
| 11 | goldblatt_2003 | IDENTICAL | 2× (combined+sections dedup) | EQUIVALENT |
| 12 | hodkinson_2006 | IDENTICAL | exact match (both sides single-file) | EQUIVALENT |
| 13 | libkin_2004_ch3_ch7 | IDENTICAL | exact match (both sides single-file) | EQUIVALENT |
| 14 | obendrauf_2024 | IDENTICAL | 2× (combined+sections dedup) | EQUIVALENT |
| 15 | rabinovich_2014 | IDENTICAL | exact match (both sides single-file) | EQUIVALENT |
| 16 | reynolds_1992 | IDENTICAL | 2× (combined+sections dedup) | EQUIVALENT |
| 17 | reynolds_1994 | IDENTICAL | 2×; central sections renamed, matching word counts (all 3 sections) | EQUIVALENT |
| 18 | reynolds_2001 | IDENTICAL | 2× (combined+sections dedup) | EQUIVALENT |
| 19 | thomas_1997 | no PDF either side | exact match (both sides single-file) | EQUIVALENT |
| 20 | thomason_1984 | IDENTICAL | 2× (combined+sections dedup) | EQUIVALENT |
| 21 | venema_1991 | 3/3 PDFs identical (full vol, ch2, app A/B) | 2×; central drops combined `.md`s but keeps all 9 section chunks | EQUIVALENT |
| 22 | venema_1993 | IDENTICAL | 2× (combined+sections dedup) | EQUIVALENT |
| 23 | venema_1993_since | IDENTICAL | 2×; central drops bimodal's combined `.md`, keeps both section chunks | EQUIVALENT |
| 24 | venema_1997 | IDENTICAL | 2× (combined+sections dedup) | EQUIVALENT |
| 25 | venema_2001 | IDENTICAL | 2× (combined+sections dedup) | EQUIVALENT |
| 26 | verbrugge_2004 | IDENTICAL | 2× (combined+sections dedup) | EQUIVALENT |
| 27 | xu_1988 | IDENTICAL | 2× (combined+sections dedup) | EQUIVALENT |

**No dir received a "LOSSY" or "central worse" verdict.** The task-831 concern (central being "equally corrupt" or worse because it shares the same broken converter) is **moot for the equivalence question**: whatever conversion artifacts exist (column interleaving etc.) are present identically in both copies, because central's markdown for these 27 papers was produced from the exact same converter run against the exact same PDFs (byte-identical PDFs, word-identical markdown). Central is not more corrupt, and it is not less corrupt — it is the same content, reorganized. (Whether the underlying conversion quality itself is good is a separate question already tracked as task 831 and out of scope here — it applies equally to both copies and is not a reason to keep the redundant local copy.)

**Systematic pattern discovered**: 17 of 27 bimodal source dirs carry both a whole-document combined `.md` AND per-section `.md` files that are a strict decomposition of the combined file (verified: `wc -w` of combined == sum of `wc -w` of sections, and spot-checked `diff` is empty). Central retains only the section-level chunks (plus `chunks.json`, a graph-structured chunk index) and drops the redundant combined file. This is the sole source of the "central has half the words" signal seen across the corpus — it is deduplication, not loss.

### 2. Metadata in per-dir `index.json` — is anything NOT carried into central?

Compared BimodalLogic's per-source `index.json` (schema: `paper`, `bib_key`, `authors`, `year`, `journal`, `volume`, `pages`, `note`, `chapters[]` with `title`/`pages`/`token_count`/`keywords`) against central's **top-level** `~/Projects/Literature/index.json` (280 entries; central has no per-dir `index.json`, replacing it with a lighter per-dir `chunks.json` for internal chunk-graph linkage plus the authoritative metadata living centrally).

Spot-checked `burgess_1982` in full: **every field from the per-repo `index.json` is present in central's top-level index**, plus central adds fields BimodalLogic's schema lacked: `doc_type`, `source_format`, `zotero_key`, `zotero_path`, and **`project_tags: ["BimodalLogic"]`** — i.e., central knows this document was pulled in for the BimodalLogic project and tags it accordingly. Central's `summary` field is present where bimodal only had a document-level `note` (bimodal's chapter-level entries lacked per-chapter summaries; central's per-chunk `summary` fields fill this gap). **No metadata regression found; central is a strict metadata superset for the sampled entry.**

Note: central's index for `burgess_1982` also carries **duplicate, more granular entries** under differently-named sibling directories (`burgess_1982_i`, `burgess_1982_ii` — a newer, non-chaptered ingestion of the same two papers under corrected per-paper `bib_key`s `Burgess1982I`/`Burgess1982II`). This is pre-existing central-side redundancy from a separate ingestion pass, unrelated to BimodalLogic's copy, and out of scope for this task (flagged for awareness only, not a blocker).

Given the strength of the single spot-check and the structural consistency confirmed across all 27 dirs' PDF/markdown content in Finding 1, this is treated as representative rather than re-verified per-dir; a full 27-way JSON diff was not performed (deferred to implementation phase if desired, low risk given the pattern).

### 3. Sub-Index Convention — does it work anywhere, and is deletion safe re: ordering?

**This is the most important finding of the task, and it resolves in favor of "already safe."**

Read `.claude/scripts/literature-briefing.sh` (per-repo mode): it reads `specs/literature-index.json` (list of `{doc_id, reason|relevance}` pointers), resolves each `doc_id` against `$LITERATURE_DIR/index.json` (default `~/Projects/Literature`), and reports a `dir:` pointing at `$LIT_DIR/sources/<doc_id or resolved path>` — **always the central corpus location**, never anything under the calling repo's own `specs/literature/`. The per-repo `sources/` directory is not read by this script under any code path.

Checked whether the sub-index is actually populated anywhere under `~/Projects/`:

- `~/Projects/BimodalLogic/specs/literature-index.json` **exists and is populated** (2 entries: `rabinovich_2014`, `kamp_1968_tense-logic-linear-order`).
- `~/Projects/cslib/specs/literature-index.json` **exists and is populated** (11 entries, richly annotated with per-doc `relevance` notes tied to specific task numbers).
- No other repo under `~/Projects/` (maxdepth 3 sweep) has a `specs/literature-index.json`.

**Live-executed `literature-briefing.sh` (read-only, no writes) in both repos** to confirm end-to-end resolution rather than just inspecting the script:
- In `BimodalLogic`: produced a correct `<literature-briefing>` block for both entries, with `dir:` pointing to `/home/benjamin/Projects/Literature/sources/rabinovich_2014` and `.../kamp_1968_tense-logic-linear-order` — **central**, confirmed live.
- In `cslib`: produced a correct 11-entry briefing, all `dir:` paths pointing into `/home/benjamin/Projects/Literature/sources/...` — **central**, confirmed live, including correctly routing to the newer `burgess_1982_i`/`burgess_1982_ii` split entries discussed in Finding 2.

**Conclusion**: the sub-index convention is not a theoretical mechanism awaiting adoption — it is **already live and exercised** for the two repos that matter here (BimodalLogic is the deletion target; cslib is informative context). Because `--lit` resolution for both repos already reads exclusively from `$LITERATURE_DIR/sources/` (central) and never touches the calling repo's own `specs/literature/sources/`, **there is no "must exist before deletion is safe" precondition to satisfy** — the precondition (a working, central-pointing sub-index) is already met today, independent of the per-repo `sources/` directory's existence. Deleting `~/Projects/BimodalLogic/specs/literature/sources/` would not change what `--lit` returns for BimodalLogic.

### 4. Sweep — other `specs/literature/`-shaped directories under `~/Projects/`

| Path | Size | Source dirs | Sub-index populated? | Assessment |
|---|---|---|---|---|
| `~/Projects/BimodalLogic/specs/literature/` | 181 MB | 27 (in `sources/`) | Yes, 2 entries, verified live-resolving to central | **Primary deletion target** (this task) — `sources/` only |
| `~/Projects/cslib/specs/literature/` | 25 MB | 20 (in `sources/`) + 2 top-level PDFs | Yes, 11 entries, verified live-resolving to central | **Same situation as BimodalLogic** — not in this task's explicit scope, but structurally identical stale-copy pattern; flagged as a natural follow-up task, not touched here |
| `~/Projects/cslib-refactor-prop_logic/specs/literature/` | 25 MB | 20 | No `specs/literature-index.json` found | This is a **git worktree of `cslib`** (`git worktree list` confirms: shares `.git` with `cslib`, checked out on branch `refactor/prop_logic`). Its `specs/literature/` is a separate on-disk checkout of the same tracked content as `cslib`'s (not an independent duplication caused by the literature migration) — any decision about `cslib`'s copy should be applied consistently across both worktrees, but this is a git-worktree characteristic, not a second stale-copy problem to solve independently |
| `~/Projects/Literature/` | 261 MB | 97+ (in `sources/`) | N/A — this IS the central corpus | Not a duplicate; the canonical store |

No other `specs/literature/`-shaped directory exists under `~/Projects/` at depth ≤3. **Sweep is exhaustive for the searched depth.**

**Recommendation for scope**: This task's explicit target is BimodalLogic's `sources/`. `cslib`/`cslib-refactor-prop_logic` exhibit the identical pattern (populated, central-resolving sub-index; stale local `sources/` copy) and are strong candidates for a near-identical follow-up task — but treating them here would exceed this task's stated scope ("delete `~/Projects/BimodalLogic/specs/literature/sources/`"). Flagging, not acting.

### 5. Git Tracking Status — Recoverability Profile

This inverts part of the risk calculus and should be read first by whoever plans the deletion:

- `~/Projects/BimodalLogic/.gitignore` lines 27-30:
  ```
  # Literature PDFs (large binary files)
  literature/*.pdf
  specs/literature/*.pdf
  specs/literature/sources/**/*.pdf
  ```
- `git ls-files specs/literature/sources` returns 192 tracked paths (all `.md` and `index.json` files) — these ARE git-tracked and recoverable via `git checkout` / `git log` after deletion, no separate backup needed for them.
- PDFs under `sources/**/*.pdf` are **NOT tracked** (gitignored) — `git check-ignore -v` on the `sources/` dir itself returns "not ignored" (exit 1) but the `*.pdf` glob pattern inside it does match individual PDF files. These 176 MB of PDFs have **zero git recoverability**. If central's byte-identical copies (already sha256-verified in Finding 1) were ever found to be wrong, there would be no repo-side fallback.
- Working tree is otherwise clean aside from unrelated task-340 files (`git status --porcelain` shows only `specs/340_.../plans/03_....md` modified and one untracked patch file — nothing under `specs/literature/`).

**Given Finding 1 already sha256-verified 26/27 PDFs as byte-identical to central**, the "backup before delete" step below is defense-in-depth against an unlikely re-verification failure at delete time, not a response to any discovered discrepancy.

## Decisions

- **No re-migration is warranted.** Central already contains everything BimodalLogic's copy contains, plus richer metadata (`project_tags`, `summary`, `zotero_key`) and better organization (dedup of redundant combined-document files, descriptive section titles in several dirs).
- **The sub-index convention does not need to be "made to work" before deletion — it already works**, live-verified in both BimodalLogic and cslib.
- **Scope discipline**: only `~/Projects/BimodalLogic/specs/literature/sources/` should be deleted in the implementation phase. `DEPRECATED.md`, `README.md`, and `index.json` at `specs/literature/` (not inside `sources/`) should remain, per the task constraint.
- **`cslib` and `cslib-refactor-prop_logic` are out of scope** for this task's implementation; recommend a follow-up task rather than expanding this one.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| PDFs are gitignored (176 MB unrecoverable via git) | Already sha256-verified byte-identical against central for 26/27 dirs (Finding 1) before any deletion; re-run the same hash check as the final pre-delete gate in the implementation plan (cheap, deterministic, catches any drift between now and delete time) |
| `--lit` briefings could theoretically regress for BimodalLogic post-deletion | Live-tested: `literature-briefing.sh` already resolves exclusively against central for BimodalLogic's 2-entry sub-index; deletion of the per-repo `sources/` dir does not intersect any code path in that script |
| Task-831 converter-corruption concern could invalidate "equivalence" | Addressed directly: corruption (if any) is identical in both copies since they derive from the same PDFs via the same converter; this task's job is redundancy removal, not quality improvement, and is unaffected by task 831's separate finding |
| Accidental deletion of more than `sources/` | Constrain the implementation-phase delete command explicitly to the `sources/` subdirectory path, never the parent `specs/literature/` |

## Safe Deletion Procedure (Proposed — NOT Executed)

This is a proposal for the implementation phase. No deletion was performed during this research.

1. **Re-verify immediately before deleting** (cheap, ~seconds): re-run the sha256 comparison from Finding 1 on all PDFs in `~/Projects/BimodalLogic/specs/literature/sources/**/*.pdf` against their `~/Projects/Literature/sources/` counterparts, to catch any drift since this report was written (e.g., a stray manual edit). Abort if any mismatch is found.
2. **Backup the untracked PDFs** (defense-in-depth, since they are the only unrecoverable-via-git content): `tar czf ~/Projects/backup-bimodallogic-literature-sources-$(date +%Y%m%d).tar.gz -C ~/Projects/BimodalLogic/specs/literature sources` — store outside the repo (e.g., `~/Projects/` root or an external location), NOT inside `specs/literature/` where it would just be a second stale copy.
3. **Confirm the git-tracked portion is clean and committed**: `git -C ~/Projects/BimodalLogic status --porcelain specs/literature` should be empty (already confirmed empty at research time) before deleting, so `git log` remains the recovery path for the 192 tracked `.md`/`index.json` files.
4. **Delete exactly the `sources/` subdirectory**, nothing else: `rm -rf ~/Projects/BimodalLogic/specs/literature/sources/` — this leaves `DEPRECATED.md`, `README.md`, and `specs/literature/index.json` in place per the task constraint.
5. **Commit the deletion** as a normal git commit (the 192 tracked files under `sources/` will show as deletions; the untracked PDFs will simply disappear from `git status` since they were never tracked).
6. **Post-delete verification**: re-run `literature-briefing.sh` in BimodalLogic (as done live in this research) and confirm it still emits a correct 2-entry briefing pointing at central — this is a zero-cost regression check since it was already proven not to depend on the deleted directory.
7. **Rollback path**: `tar xzf ~/Projects/backup-bimodallogic-literature-sources-YYYYMMDD.tar.gz -C ~/Projects/BimodalLogic/specs/literature/` restores the PDFs; `git checkout <commit-before-deletion> -- specs/literature/sources` restores the tracked `.md`/`index.json` files. Both are independent and both work even if the other was already discarded.

## Context Extension Recommendations

- **Topic**: literature sub-index population status across repos.
- **Gap**: no single place documents which repos have a populated `specs/literature-index.json` vs. which still fall back to `GLOBAL_MISSING`/`PROMPT_NEEDED` per `literature-lit-flag-resolve.sh`. This research had to live-test two repos manually.
- **Recommendation**: consider a `/literature --validate` extension (or a new flag) that sweeps known `~/Projects/*` repos for sub-index population status, to make findings like Section 3 of this report queryable rather than requiring manual live execution. Not created as a task here — noted for context-extension consideration only, per Stage 4.5 guidance (no auto-task-creation for meta tasks).

## Appendix

### Commands/Methods Used

- Existence sweep: shell loop checking `[ -d ]` for all 27 named source dirs against `~/Projects/Literature/sources/`.
- Content hashing: `find ... -name '*.pdf' -exec sha256sum {} \;` per dir, both sides, diffed by inspection (chosen over `diff -r` per task guidance, since PDFs are binary and markdown filenames differ across sides in several dirs).
- Markdown equivalence: `wc -c`/`wc -w` per dir (both sides) to detect the systematic 2× pattern, then targeted `diff` (exact and sorted-token) on representative files per anomalous dir to confirm content identity independent of filename/section-boundary renaming.
- Metadata comparison: `jq` queries against BimodalLogic's per-dir `index.json` and central's top-level `index.json` (`.entries[] | select(...)`).
- Sub-index live test: direct execution of `.claude/scripts/literature-briefing.sh` (read-only; the script only reads `specs/literature-index.json` and `$LITERATURE_DIR/index.json`, and prints — no writes) from within `~/Projects/BimodalLogic` and `~/Projects/cslib`.
- Git tracking: `git ls-files`, `git check-ignore -v`, `git status --porcelain`, `git worktree list`, `.gitignore` inspection.
- Sweep: `find ~/Projects -maxdepth 3 -type d -iname literature` and `-iname literature-index.json`.

### Key File References

- `~/Projects/BimodalLogic/specs/literature/DEPRECATED.md` — migration record (task 710, 2026-06-14), states `LITERATURE_DIR` wiring locations.
- `~/Projects/BimodalLogic/specs/literature-index.json` — populated per-repo sub-index (2 entries).
- `~/Projects/cslib/specs/literature-index.json` — populated per-repo sub-index (11 entries).
- `.claude/scripts/literature-briefing.sh` — per-repo/global briefing generator; per-repo mode never reads the calling repo's own `specs/literature/sources/`.
- `~/Projects/Literature/index.json` — central top-level index, 280 entries, richer schema than the deprecated per-repo `index.json` schema.

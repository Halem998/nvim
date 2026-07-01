# Research Report: Task #801

**Task**: 801 - Normalize authors schema in Literature index generation (defense-in-depth)
**Started**: 2026-07-01
**Completed**: 2026-07-01
**Effort**: 3-6 hours (original estimate; see revised scope below)
**Dependencies**: None (task 799 consumer-side fix already landed and is the functional fix)
**Sources/Inputs**:
- Codebase: `.claude/scripts/literature-*.sh`, `.claude/extensions/literature/scripts/*.sh`,
  `.claude/skills/skill-literature/SKILL.md`
- `~/Projects/Literature/index.json` (live data, 270 entries)
- `~/Projects/Literature/scripts/migrate-from-repo.sh` (found via git blame / commit history)
- `~/Projects/Literature` git log
- Task 799 report/plan/summary (prior consumer-side fix)
**Artifacts**:
- This report: `specs/801_literature_index_authors_schema_normalization/reports/01_authors-schema-normalization.md`

## Executive Summary

- **The task description's premise is only half right.** None of the four scripts named in the
  task (`literature-build-index.sh`, `literature-discover.sh`, `literature-convert.sh`,
  `literature-chunk.sh`) actually write a malformed `authors` field into `index.json` today.
  `literature-build-index.sh` never touches `authors` at all (it only builds a SQLite FTS5 DB
  from `chunks.json`). `literature-convert.sh` only writes an `**Author(s)**:` line into
  generated markdown, never into `index.json`. `literature-chunk.sh` doesn't reference authors.
  `literature-discover.sh` only *reads* `index.json` (for search/discovery output); it never
  writes back to it.
- **The true root cause is a different, one-time migration script**:
  `~/Projects/Literature/scripts/migrate-from-repo.sh` (lives in the Literature repo itself, not
  in this config repo's `.claude/scripts/`). It is a general-purpose, re-runnable, idempotent
  tool (`./scripts/migrate-from-repo.sh <repo_path>`) for importing any project's
  `specs/literature/` into the central index, and it has **two distinct bugs**:
  1. Root-entry migration (lines 143-191) does a naive `. + {...}` jq merge that **passes the
     source repo's `authors` field through unchanged**, whatever type it was in the old v1
     per-repo schema. This produced the 12 plain-string entries (`burgess_1982_i`,
     `venema_1993_anti_axioms`, `gabbay_1993`, etc. — exactly the "Burgess/Venema/Gabbay/
     Reynolds/Rabinovich/Caleiro/Hodkinson/Goldblatt families" the task description names).
  2. Subdirectory/chapter-entry migration (lines 209, 246, 301) reads the old subdirectory
     `index.json`'s `.authors` field as raw JSON (a single comma-joined string in the v1 schema,
     e.g. `"Patrick Blackburn, Maarten de Rijke, Yde Venema"`) and wraps it verbatim as
     `[$authors]` **without splitting on commas**, producing the malformed one-element array
     (`["Patrick Blackburn, Maarten de Rijke, Yde Venema"]`) for every chapter/section entry of
     the migrated books (`blackburn_2002_*`, `blackburn_2001`, `gabbay_1994`, etc.).
  - This is confirmed by the git history of `~/Projects/Literature`: commit `854adef` "task 710:
    migrate BimodalLogic literature (183 entries, 175 content files)" — `Run
    scripts/migrate-from-repo.sh ~/Projects/BimodalLogic`.
- **The properly-behaving script already exists**: `zotero-index-add.sh`
  (`.claude/extensions/literature/scripts/zotero-index-add.sh`) correctly splits Zotero
  `creators[]` into individual array elements (`jq '[.creators[]? | select(...) | ...]'`) —
  this is the canonical-correct pattern and should be the model for the fix.
  `literature-ingest.sh` always writes `"authors": []` (empty, consistent, harmless).
- **Live data confirms the histogram** (recomputed against the actual file, numbers differ
  slightly from the task description, likely due to additional entries added since task 799's
  research): 270 total entries, 258 array-typed, 12 string-typed (exactly the families named in
  the task), 110 malformed one-element comma-joined arrays (a subset of the 258 array-typed
  entries — mostly chapter/section-level entries under `blackburn_2002_*` and `gabbay_1994`), 3
  of those malformed arrays are top-level document entries
  (`blackburn_2002_book`, `blackburn_2001`, `gabbay_1994`).
- **A related, previously-undiscovered consumer-side risk** was found at
  `.claude/skills/skill-literature/SKILL.md:1654` (per-repo sub-index "Resolve" operation):
  `authors=$(jq -r ... '(.authors // []) | first // "?"' ...)`. Because `.authors // []` only
  falls back on `null`/`false` (not on strings), a string-typed `.authors` (e.g. `"Yde Venema"`)
  passes through unchanged, and `first` on a JSON *string* in jq returns its **first character**
  ("Y") rather than erroring — a silent data-corruption bug, not a crash. This is a different
  code path from the one task 799 fixed (`literature-briefing.sh`) and is not part of the
  `--lit` dispatch path, so it is out of this task's stated scope, but it is flagged here as a
  related downstream symptom of the same schema inconsistency, worth a follow-up.
- **Recommended approach**: (1) fix `migrate-from-repo.sh` at its two authors-handling sites to
  always split on commas and emit individual array elements, matching the `zotero-index-add.sh`
  pattern; (2) run a one-time Python/jq normalization pass over the live
  `~/Projects/Literature/index.json` to fix the 12 string entries and 110 malformed arrays
  in place; (3) add an authors-shape check to the existing `/literature --validate` schema-field
  check in `skill-literature/SKILL.md` (Validate Step 2, currently only checks `.authors == null`)
  so any future writer that reintroduces string-typed or unsplit-comma authors is caught by
  routine validation, rather than only being tolerated defensively at read time (as task 799 did).

## Context & Scope

Task 801 is explicitly framed as optional, defense-in-depth follow-up to task 799 (which fixed
the crash at the consumer side — `literature-briefing.sh` — and is stated to already be the
*sufficient* functional fix). This task's stated goal is to find and fix the *source* of the
inconsistency so it does not recur, plus normalize the existing bad data.

The task description asked to audit four specific scripts in `.claude/scripts/`:
`literature-build-index.sh`, `literature-discover.sh`, `literature-convert.sh`,
`literature-chunk.sh`. Research shows these four scripts are **not** the source of the bug —
they are either irrelevant to `authors` (build-index, chunk) or read-only /
markdown-only (discover, convert). The actual bug lives in a fifth script,
`migrate-from-repo.sh`, which resides in `~/Projects/Literature/scripts/` (a sibling repo, not
`.claude/scripts/` of this nvim config repo) and was used for a one-time bulk import (task 710:
BimodalLogic migration) but is designed to be re-run for future project migrations. This is a
scope correction worth flagging explicitly to whoever plans/implements this task, since fixing
the four originally-named scripts would do nothing to prevent recurrence.

## Findings

### Codebase Patterns

**Scripts that reference `authors` (searched across `.claude/scripts/` and
`.claude/extensions/literature/scripts/`):**

| Script | Writes to `index.json`? | Authors handling | Verdict |
|---|---|---|---|
| `literature-build-index.sh` | No (writes SQLite FTS DB from `chunks.json`, unrelated file) | N/A — no `authors` references at all | Not implicated |
| `literature-discover.sh` | No — read-only, emits discovery results to stdout | Tier 1 (`index.json` search, lines 278-330): reads `.authors`, **normalizes type defensively** (`if type == "array" then . else [.] end`), but then **joins into a single string and re-wraps as a one-element array** (`[$authors]`) for its own output — same anti-pattern, but this is ephemeral discovery output, not persisted back to `index.json`. Tier 2 (Zotero search, lines 393-450) and Tier 3 (Semantic Scholar, lines 500-590+) both correctly split on `;`/build proper arrays. | Not the persistence root cause, but tier-1 output reproduces the anti-pattern in memory — worth noting if tier-1 discovery results are ever piped back into an index-writer |
| `literature-convert.sh` | No — writes `**Author(s)**: {author}` line into generated **markdown**, single PDF-metadata string, never into `index.json` | Reads `meta.get('author', '')` from PyMuPDF PDF metadata (a single string), never split | Not implicated for `index.json`; feeds a human-readable markdown line only |
| `literature-chunk.sh` | N/A | No `authors` references | Not implicated |
| `literature-ingest.sh` | Yes | Always writes `"authors": []` (both `metadata.json` and the `index.json` entry) | Consistent, harmless (always empty array) |
| `zotero-index-add.sh` (`.claude/extensions/literature/scripts/`) | Yes | Lines 142-148: `jq '[.creators[]? | select(.creatorType == "author") | ((.lastName // "") + (", " + .firstName if firstName else ""))]'` — **correctly produces an array of individual "Last, First" strings** | Canonical-correct pattern; not deployed flat to this repo's `.claude/scripts/` (only lives under `extensions/literature/scripts/`) — see note below |
| `migrate-from-repo.sh` (`~/Projects/Literature/scripts/`, **not** in this repo's `.claude/scripts/`) | Yes — directly appends to `~/Projects/Literature/index.json` | **Root cause**, see below | Needs fixing |

**Root-cause detail — `migrate-from-repo.sh`:**

```bash
# Root entries (lines 143-191): naive field-preserving merge
new_entry=$(echo "$entry_json" | jq \
  --arg doc_type "$doc_type" \
  ... \
  '. + {
    "doc_type": $doc_type,
    "source_format": "pdf",
    "zotero_key": $zotero_key,
    "zotero_path": $zotero_path,
    "project_tags": [$project_tag]
  }')
```
`. + {...}` preserves whatever `.authors` was in the source v1 index untouched — if it was a
plain string there, it stays a plain string in the central v2 index. This explains the 12
string-typed entries.

```bash
# Subdirectory/chapter entries (lines 205-311)
sub_authors=$(jq -c '.authors // null' "$sub_index")   # raw JSON, e.g. a STRING in v1 schema
...
--argjson authors "$sub_authors" \
'{
  ...
  "authors": (if $authors == null then [] else [$authors] end),
  ...
}'
```
When `sub_authors` is a JSON string (e.g. `"Patrick Blackburn, Maarten de Rijke, Yde Venema"`),
`[$authors]` wraps it as a one-element array containing the whole comma-joined string. This
explains the 110 malformed one-element arrays (both the 3 top-level book entries and their many
chapter/section children, e.g. `blackburn_2002_ch01_sec01-02`, `blackburn_2002_ch02_sec02-03`,
etc., which all inherit the same `sub_authors` value).

Confirmed via `~/Projects/Literature` git log: commit `854adef` "task 710: migrate BimodalLogic
literature (183 entries, 175 content files)" — commit message states `Run
scripts/migrate-from-repo.sh ~/Projects/BimodalLogic`, matching this exact code path. The script
header documents it as a **reusable, idempotent** tool
(`Usage: ./scripts/migrate-from-repo.sh <repo_path>`), meaning it will very likely be invoked
again for future project migrations (e.g. `Logos/Hardware`, `cslib`, or new projects) and will
reproduce the identical bug pattern unless fixed.

**Live data histogram** (`~/Projects/Literature/index.json`, computed directly, 2026-07-01):

- 270 total entries (90 top-level document entries + 180 chunk/section entries)
- 258 array-typed `authors`, 12 string-typed `authors`
  - The 12 string-typed entries are exactly: `burgess_1982_i`, `burgess_1982_ii`,
    `caleiro_2013`, `gabbay_1993`, `goldblatt_2003`, `hodkinson_2006`, `libkin_2004_ch3_ch7`,
    `rabinovich_2014`, `reynolds_2001`, `thomas_1997`, `venema_1993_anti_axioms`,
    `venema_1993_since_until` — matching the "burgess/venema/gabbay/reynolds/rabinovich/
    caleiro/hodkinson/goldblatt families" named in the task description.
  - 110 of the 258 array-typed entries are the malformed one-element comma-joined pattern; of
    those, 3 are top-level document entries (`blackburn_2002_book`, `blackburn_2001`,
    `gabbay_1994`) and the remainder are their chapter/section children.
- (Note: the task description cites "210 array / 12 string" — the array count here is higher,
  258 vs 210, likely because entries were added to the global index between when the task 799
  research ran and now, e.g. via `literature-ingest.sh`'s empty-array entries or further Zotero
  imports. The 12 string-typed count matches exactly, confirming those specific entries are
  untouched since task 799.)

**Related consumer-side risk (found but out of scope for this task):**

`.claude/skills/skill-literature/SKILL.md:1654` (per-repo sub-index "Resolve" operation, used to
enrich `specs/literature-index.json` display data from the global index — a different code path
from `literature-briefing.sh`, which task 799 already fixed):
```bash
authors=$(jq -r --arg id "$doc_id" '.entries[] | select(.id == $id) | (.authors // []) | first // "?"' "$global_index" 2>/dev/null | head -1)
```
`.authors // []` only substitutes on `null`/`false`; a string-typed `.authors` passes through
unchanged, and `first` applied to a jq string returns its **first character** rather than an
error (e.g. `"Yde Venema" | first` → `"Y"`). This is a silent-corruption bug (not a crash) on the
exact same 12 string-typed entries, in a code path outside the `--lit` dispatch and outside
`.claude/scripts/`, so it is explicitly flagged here rather than fixed, per this task's stated
scope boundary ("NOT the --lit dispatch path").

### External Resources

No external documentation consulted — this is a pure internal-tooling/data-consistency
investigation with no external API or library involved (jq schema handling is well-understood
internal convention, cross-checked against the already-established fix pattern in
`literature-discover.sh:281` and `zotero-index-add.sh:143-148`, both already in this codebase).

### Recommendations

**Canonical representation**: array of individual author strings (e.g.
`["Patrick Blackburn", "Maarten de Rijke", "Yde Venema"]`), one string per author, no embedded
commas. This matches `zotero-index-add.sh`'s existing correct behavior and is what
`literature-briefing.sh`'s task-799 fix and `literature-discover.sh:281`'s tolerant read already
assume once joined for display.

**1. Fix `migrate-from-repo.sh` (source-of-recurrence fix)**

File: `~/Projects/Literature/scripts/migrate-from-repo.sh` (outside this repo's `.claude/`, but
this is the actual bug location; the task's "Scope: Literature-corpus tooling in
`.claude/scripts/`" framing should be corrected/expanded to include this file, or a companion
task should be filed against the Literature repo — this is a planning decision, not a research
one).

- Root-entry path (~line 161-173): after the `. + {...}` merge, add a normalization step that
  detects a string-typed `.authors` and splits it on `, ` into an array, e.g.
  `| .authors = (if (.authors | type) == "string" then (.authors | split(", ")) else .authors end)`.
- Subdirectory/chapter path (~line 246, 301): replace `(if $authors == null then [] else
  [$authors] end)` with logic that splits `$authors` on `, ` when it is a string, e.g.
  `(if $authors == null then [] elif ($authors|type) == "string" then ($authors | split(", ")) else $authors end)`.
  Mirror the split logic already used correctly in `literature-discover.sh` tier 2
  (`$authors | grep ';' -> python3 split`) or better, reuse `zotero-index-add.sh`'s pure-jq
  approach for consistency.

**2. One-time normalization pass over the live `~/Projects/Literature/index.json`**

A small Python (or jq) script that, for every entry:
- If `authors` is a string: split on `, ` (or `,` with strip) into an array of individual names.
- If `authors` is a one-element array whose single string contains `, `: split that element on
  `, ` into multiple array elements.
- Otherwise leave unchanged.

Must be careful with name-internal commas if any exist (none observed in the current 110
malformed entries — all are straightforward "First Last, First Last, First Last" author lists);
a defensive check/manual review pass over the diff before committing is advisable given this
mutates the canonical Literature corpus (a separate git repo with its own history). Should be
run with `git diff` review and a commit in the Literature repo, not silently overwritten.

**3. Add a validation check for future writes**

Extend `.claude/skills/skill-literature/SKILL.md` Validate Step 2 (currently
`.claude/skills/skill-literature/SKILL.md:395-407`, which only checks `.authors == null` as a
missing-field warning) with an authors-shape check:
```jq
(if (.authors | type) != "array" then "authors:not-array" else empty end),
(if (.authors | type) == "array" and (.authors | any(type != "string")) then "authors:non-string-element" else empty end),
(if (.authors | type) == "array" and (.authors | any(test(", .*[a-z]")) ) then "authors:possibly-comma-joined" else empty end)
```
(exact heuristic for "possibly comma-joined" needs light refinement — e.g. checking for `, ` in
an author string that also contains multiple capitalized name-like tokens — to avoid
false-positives on legitimate "Last, First" single-author formatting, which
`zotero-index-add.sh` itself produces as `"Last, First"` for a *single* author. A safer
heuristic: flag any array element containing 2+ occurrences of `, ` or containing `, ` followed by
a capital letter that looks like a second full name, or more simply, cross-check against a
name/comma count consistency check.) This check currently only covers the per-repo
`specs/literature/index.json` path (`/literature --validate`); note the global
`~/Projects/Literature/index.json` is not currently covered by any `/literature --validate` flow
in this skill — a companion validate mode or a small standalone script
(`literature-validate-global.sh`?) would be needed to cover the actual file that has the bug, if the
current per-repo validate function does not exercise `$LITERATURE_DIR`'s own root index — planners
should confirm this distinction before implementation.

## Decisions

- Confirmed via direct inspection and live-data testing that the four scripts named in the task
  description (`literature-build-index.sh`, `literature-discover.sh`, `literature-convert.sh`,
  `literature-chunk.sh`) are not the write-path root cause; the actual root cause is
  `migrate-from-repo.sh` in the separate `~/Projects/Literature` repo.
- Did not modify any files — this is a research-only task per the delegation contract
  (general-research-agent). Planning/implementation of the fix is left to a subsequent
  `/plan 801` + `/implement 801` cycle, which should incorporate the scope correction above.
- Did not attempt to fix the SKILL.md:1654 `first`-on-string bug — flagged as related but
  explicitly out of this task's stated scope (not `.claude/scripts/`, not the `--lit` dispatch
  path). Recommend a follow-up task if desired.

## Risks & Mitigations

- **Risk**: Normalizing the live `~/Projects/Literature/index.json` mutates a separate git repo
  with its own history and is used by other projects' sub-indexes (`cslib`, `Logos/Hardware`,
  etc.) — a bad split (e.g. a name containing a comma, such as "Jr." suffixes or non-Western name
  ordering) could silently corrupt author data.
  - **Mitigation**: Run the normalization as a script with `--dry-run` output first, manually
    review the diff (110+ entries), and commit with a clear message in the Literature repo
    before considering it done. Cross-check the 12 string-typed + 110 malformed entries listed
    in this report as the exact known-bad set.
- **Risk**: Fixing `migrate-from-repo.sh` is out of the literal `.claude/scripts/` scope stated
  in the task description; if the task is planned/implemented narrowly per the original
  description, the recurrence-prevention goal will not actually be achieved (the four originally
  named scripts don't need any code change).
  - **Mitigation**: This report explicitly documents the scope discrepancy; the planning stage
    should decide whether to (a) expand scope to fix `migrate-from-repo.sh` in the Literature
    repo, (b) file that as a separate/companion task, or (c) accept that recurrence prevention
    is out of reach without touching that file, and settle for the normalization pass +
    validation-only outcome.
- **Risk**: The proposed validation regex heuristic for "possibly comma-joined" could
  false-positive on legitimate `"Last, First"` single-author strings (which is the correct
  per-author format used by `zotero-index-add.sh` itself for individual entries).
  - **Mitigation**: Implementation should test the heuristic against the full current corpus
    (270 entries, all now-correct after normalization) to confirm zero false positives before
    wiring it into `/literature --validate`.

## Context Extension Recommendations

- **Topic**: Literature corpus tooling ownership boundary between `.claude/scripts/` (repo-local,
  versioned with this config repo) and `~/Projects/Literature/scripts/` (versioned with the
  separate Literature repo).
- **Gap**: No existing context file documents that literature *migration* tooling
  (`migrate-from-repo.sh`) lives in the Literature repo itself, separate from the per-repo
  ingestion/discovery/briefing scripts in `.claude/scripts/`. This caused the task description
  to mis-scope the audit to the wrong repo's scripts.
- **Recommendation**: Add a short note to
  `.claude/context/project/literature/` (or wherever literature architecture is documented)
  clarifying: "One-time/re-runnable migration tooling for importing a project's
  `specs/literature/` into the central corpus lives in `~/Projects/Literature/scripts/
  migrate-from-repo.sh`, not in this repo's `.claude/scripts/`." This would prevent future
  scope confusion for similar audits.

## Appendix

### Search queries / commands used

```bash
grep -rln "authors" .claude/scripts/*.sh
grep -n "authors" .claude/scripts/literature-discover.sh .claude/scripts/literature-ingest.sh \
  .claude/extensions/literature/scripts/zotero-generate-export.sh .claude/scripts/literature-briefing.sh
python3 -c "... histogram over ~/Projects/Literature/index.json authors types ..."
cd ~/Projects/Literature && git log --oneline -- index.json
git show --stat 854adef   # task 710 migration commit
find ~/Projects/Literature -iname "*migrate*"
grep -n -i author -B3 -A10 ~/Projects/Literature/scripts/migrate-from-repo.sh
grep -n "GLOBAL_INDEX\|LITERATURE_DIR\|global" .claude/skills/skill-literature/SKILL.md
```

### References

- `.claude/scripts/literature-build-index.sh` (not implicated)
- `.claude/scripts/literature-discover.sh:278-330,393-450,500-590` (read-only tier-1/2/3 search)
- `.claude/scripts/literature-convert.sh:149-156` (markdown-only author line)
- `.claude/scripts/literature-chunk.sh` (not implicated)
- `.claude/scripts/literature-ingest.sh:224-282` (always empty array, harmless)
- `.claude/extensions/literature/scripts/zotero-index-add.sh:142-148,260-284` (canonical-correct pattern)
- `~/Projects/Literature/scripts/migrate-from-repo.sh:143-191,205-311` (root cause)
- `~/Projects/Literature` git commit `854adef` (task 710 migration that triggered the bug)
- `.claude/skills/skill-literature/SKILL.md:362-409` (existing but incomplete schema validation)
- `.claude/skills/skill-literature/SKILL.md:1637-1656` (related consumer-side risk, out of scope)
- `specs/799_literature_briefing_authors_type_crash_fix/summaries/01_authors-type-crash-fix-summary.md` (prior consumer-side fix)

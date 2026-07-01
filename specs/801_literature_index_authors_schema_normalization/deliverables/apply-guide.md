# Apply Guide: Literature `authors` Schema Fix (Task 801)

**Audience**: The user (human), acting directly in the external `~/Projects/Literature` repo.
**Not for agent execution.** No step in this guide should be run autonomously by an agent — see
`.claude/rules/pr-prohibition.md`-style caution: this repo's agents are confined to read-only
access of `~/Projects/Literature` by task 801's explicit scope. All steps below are for you to run
by hand and review before committing.

## Why

Task 801 traced the malformed `authors` field (string-typed instead of array-typed, or a
one-element array containing an unsplit comma-joined list of names) in the central Literature
corpus to two bugs in `~/Projects/Literature/scripts/migrate-from-repo.sh`. That script is owned
by the separate Literature repo, not this config repo, so this repo's tooling cannot fix or apply
changes there directly. See `specs/801_literature_index_authors_schema_normalization/reports/01_authors-schema-normalization.md`
for the full root-cause analysis and `.claude/context/project/literature/domain/literature-index.md`
("Tooling Ownership Boundary" section) for the general policy this follows.

Two deliverables are provided:

1. `migrate-from-repo-authors-normalize.patch` — a source fix for `migrate-from-repo.sh` so this
   bug does not recur on future project migrations.
2. `normalization-dry-run-diff.txt` — a captured dry-run of
   `.claude/scripts/literature-normalize-authors.sh` against the live
   `~/Projects/Literature/index.json`, showing every entry that needs normalizing (122 entries:
   12 string-typed + 110 malformed one-element comma-joined arrays, matching the report's
   histogram exactly).

Neither deliverable has been applied. Both are inert until you apply them yourself.

## Step 1: Apply the `migrate-from-repo.sh` source patch

```bash
cd ~/Projects/Literature
git status   # confirm a clean tree before applying
git apply --check /home/benjamin/.config/nvim/specs/801_literature_index_authors_schema_normalization/deliverables/migrate-from-repo-authors-normalize.patch
git apply /home/benjamin/.config/nvim/specs/801_literature_index_authors_schema_normalization/deliverables/migrate-from-repo-authors-normalize.patch
git diff scripts/migrate-from-repo.sh   # review the change
```

This patch was already checked with `git apply --check` in an isolated scratch git repo (a
temporary copy of `scripts/migrate-from-repo.sh`, not the live repo) during task 801's
implementation and applies cleanly. It makes two changes:

- **Root-entry path** (~line 161-173): after the existing `. + {...}` merge, adds
  `| .authors = (if (.authors | type) == "string" then (.authors | split(", ")) else .authors end)`
  so a string-typed `.authors` from the source repo's old v1 schema is split into an array.
- **Subdirectory/chapter paths** (~lines 246, 301, both identical): replaces
  `(if $authors == null then [] else [$authors] end)` with
  `(if $authors == null then [] elif ($authors | type) == "string" then ($authors | split(", ")) else $authors end)`
  so a comma-joined `$authors` string is split into individual array elements instead of being
  wrapped whole as a one-element array.

## Step 2: Normalize the existing live index

Run the normalization script (already dry-run-tested against the live index during task 801 —
see `normalization-dry-run-diff.txt` for the exact 122-entry preview) with `--apply`:

```bash
# Optional: re-preview first (no writes)
bash /home/benjamin/.config/nvim/.claude/scripts/literature-normalize-authors.sh ~/Projects/Literature/index.json

# Apply
bash /home/benjamin/.config/nvim/.claude/scripts/literature-normalize-authors.sh ~/Projects/Literature/index.json --apply
```

The script is idempotent — running it again afterward should report "No authors-shape changes
needed."

## Step 3: Review the diff in the Literature repo

```bash
cd ~/Projects/Literature
git diff index.json
```

Cross-check against the known-bad set from the report (`specs/801_literature_index_authors_schema_normalization/reports/01_authors-schema-normalization.md`):

- 12 string-typed entries: `burgess_1982_i`, `burgess_1982_ii`, `caleiro_2013`, `gabbay_1993`,
  `goldblatt_2003`, `hodkinson_2006`, `libkin_2004_ch3_ch7`, `rabinovich_2014`, `reynolds_2001`,
  `thomas_1997`, `venema_1993_anti_axioms`, `venema_1993_since_until`
- 110 malformed one-element comma-joined arrays, mostly under `blackburn_2002_*`, `blackburn_2001*`,
  `gabbay_1994*`, `caleiro_2013*`, `derijke_1995*`, `gabbay_1993*`, `goldblatt_2003*`,
  `obendrauf_2024*`, `verbrugge_2004*` (3 of these are top-level document entries:
  `blackburn_2002_book`, `blackburn_2001`, `gabbay_1994`)

Confirm entries that were already correctly shaped (e.g. `gabbay_2000` with
`["Gabbay, Dov M.", "Reynolds, Mark A."]`, a properly-formed 2-element array) are **unchanged** in
the diff.

## Step 4: Commit in the Literature repo

```bash
cd ~/Projects/Literature
git add scripts/migrate-from-repo.sh index.json
git commit -m "Normalize authors schema: split string/comma-joined authors into arrays

Fixes the malformed authors field (task 801 in the nvim config repo):
migrate-from-repo.sh's root-entry and subdirectory/chapter merges previously
preserved a source string-typed authors field unchanged, or wrapped a
comma-joined string as a one-element array. Both sites now split on ', '.
Also normalizes the 122 pre-existing malformed entries in the live index
(12 string-typed + 110 comma-joined one-element arrays)."
```

This commit happens entirely in `~/Projects/Literature`, a separate git repository from this
config repo. It is explicitly your action — no agent in this config repo creates commits or
pushes in that repo.

## Deferred Follow-Up: `SKILL.md` line ~1696 consumer bug (out of scope for task 801)

Task 801's research also flagged a related, separate bug in this config repo (not the external
Literature repo) at `.claude/skills/skill-literature/SKILL.md:1696` (per-repo sub-index "Resolve"
operation; line number current as of this task's edits, was ~1654 before Phase 1-3 additions
shifted line numbers):

```bash
authors=$(jq -r --arg id "$doc_id" '.entries[] | select(.id == $id) | (.authors // []) | first // "?"' "$global_index" 2>/dev/null | head -1)
```

`.authors // []` only substitutes on `null`/`false`, not on a string. If a string-typed `.authors`
ever reaches this code path (e.g. before Step 2 above is applied, or from a source that bypasses
`migrate-from-repo.sh`), `first` on a JSON *string* silently returns its first character (e.g.
`"Yde Venema" | first` -> `"Y"`) rather than erroring. This is explicitly out of scope for task
801 (a different code path from the one task 799 already fixed in `literature-briefing.sh`) and
is noted here as a candidate follow-up task — consider filing a small task to guard this line with
the same type-aware handling used elsewhere (e.g. `if (.authors|type)=="array" then (.authors|first) elif (.authors|type)=="string" then .authors else "?" end`).

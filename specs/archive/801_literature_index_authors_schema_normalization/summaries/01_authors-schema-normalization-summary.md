# Implementation Summary: Task #801

**Completed**: 2026-07-01
**Duration**: ~1 session

## Overview

Implemented all four phases of the authors-schema-normalization plan: defense-in-depth
validation, a reusable normalization tool, ownership-boundary documentation, and (read-only,
advisory) deliverables for the external Literature repo. Phases 1-3 are in-repo and committed
directly. Phase 4 produces reviewable artifacts under `specs/801.../deliverables/` for the user to
apply and commit in `~/Projects/Literature` themselves — no autonomous writes were made to that
external repo at any point.

## What Changed

- `.claude/skills/skill-literature/SKILL.md` (hardlinked to
  `.claude/extensions/literature/skills/skill-literature/SKILL.md`) — extended Validate Step 2
  with an authors-shape jq check (`authors:not-array`, `authors:non-string-element`,
  `authors:possibly-comma-joined`) as a new `authors_shape_warnings` category, separate from
  `schema_warnings`; extended Validate Step 4's report template with an "Authors Shape Warnings"
  section.
- `.claude/scripts/literature-normalize-authors.sh` — new reusable, dry-run-by-default
  normalization script for any `index.json` (global or per-repo). Requires `--apply`/`--write` to
  persist changes; idempotent.
- `.claude/extensions/literature/scripts/literature-normalize-authors.sh` — deployed copy of the
  same script (required by this repo's extension-deployment convention).
- `.claude/extensions/literature/manifest.json` — registered `literature-normalize-authors.sh` in
  `provides.scripts` (required for `check-extension-docs.sh` to pass, since the script is now
  referenced from `SKILL.md`).
- `.claude/context/project/literature/domain/literature-index.md` — added a "Tooling Ownership
  Boundary" section documenting that `migrate-from-repo.sh` and the central `index.json` are owned
  by the separate `~/Projects/Literature` repo, and cross-referencing the two new in-repo
  maintenance tools.
- `specs/801_literature_index_authors_schema_normalization/deliverables/migrate-from-repo-authors-normalize.patch`
  — created (new). Unified diff fixing `migrate-from-repo.sh`'s two authors-handling bugs
  (root-entry merge preserving string-typed `.authors`; subdirectory/chapter merge wrapping a
  comma-joined string in a one-element array). Verified with `git apply --check` in an isolated
  scratch repo; not applied to the live external repo.
- `specs/801_literature_index_authors_schema_normalization/deliverables/normalization-dry-run-diff.txt`
  — created (new). Captured dry-run output of the normalization script against the live
  `~/Projects/Literature/index.json` (122 entries flagged: 12 string-typed + 110 malformed
  one-element arrays, matching the research report's histogram exactly). Read-only capture; no
  writes made.
- `specs/801_literature_index_authors_schema_normalization/deliverables/apply-guide.md` — created
  (new). Step-by-step guide for the user to apply the patch, run the normalization script with
  `--apply`, review the diff, and commit — all in `~/Projects/Literature`, entirely outside this
  repo's automation. Also notes the deferred out-of-scope consumer-side bug at
  `SKILL.md:~1696` (`(.authors // []) | first` truncation risk) as a candidate follow-up.

## Decisions

- Chose a comma-joined heuristic (2+ `, ` occurrences, or one `, ` followed by 2+ non-initial
  capitalized name-like tokens) shared identically between the Phase 1 validate check and the
  Phase 2 normalization script, after testing a simpler heuristic against the live 270-entry
  global index and finding false positives on legitimate `"Last, First M."` entries (`"Gabbay, Dov
  M."`, `"Reynolds, Mark A."`). The final heuristic flags exactly the known-bad 122 entries with
  zero false positives.
- All read-only testing against the external corpus used either the live file directly (only for
  dry-run operations, confirmed via `md5sum` to make no writes) or a scratch copy under the
  session scratchpad — never `--apply` against the live `~/Projects/Literature/index.json`, and
  never any write to `~/Projects/Literature/scripts/migrate-from-repo.sh`.
- Registered the new script in the `literature` extension's `manifest.json` and deployed a
  physical copy under `.claude/extensions/literature/scripts/`, matching this repo's existing
  convention for scripts referenced from `SKILL.md` (required for `check-extension-docs.sh` to
  pass; not explicitly called out in the plan's Phase 2 task list but necessary to keep the
  doc-lint green).

## Plan Deviations

- None (implementation followed plan). The manifest-registration/deployment step above is an
  implementation detail required to satisfy this repo's doc-lint convention, not a deviation from
  the plan's stated goals.

## Verification

- Build: N/A (bash/jq scripts and markdown; no compiled build)
- Tests: Passed — see per-phase verification notes in
  `specs/801_literature_index_authors_schema_normalization/plans/01_authors-schema-normalization.md`
  Testing & Validation section (all six checklist items verified and checked off)
- Files verified: Yes — all created/modified files listed above confirmed present with expected
  content; external repo (`~/Projects/Literature`) confirmed unmodified via `md5sum` on
  `index.json` and `scripts/migrate-from-repo.sh` before/after every read-only operation, and via
  `git status`/`git diff` content review (its pre-existing dirty state is unrelated, from its own
  separate Claude Code project, predating this task's session)

## Notes

- Phase 4's deliverables are advisory only. The external `migrate-from-repo.sh` fix and the live
  `~/Projects/Literature/index.json` normalization have **not** been applied — the user must
  follow `specs/801_literature_index_authors_schema_normalization/deliverables/apply-guide.md` to
  apply, review, and commit them in that separate repo.
- The out-of-scope consumer-side bug at `SKILL.md:~1696` (`(.authors // []) | first` on a
  string-typed `.authors` silently truncating to one character) remains unfixed, as intended by
  this task's scope — flagged in the apply-guide as a candidate follow-up task.

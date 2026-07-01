# Implementation Plan: Task #801

- **Task**: 801 - Normalize authors schema in Literature index generation (defense-in-depth)
- **Status**: [NOT STARTED]
- **Effort**: 4.5 hours
- **Dependencies**: None (task 799 consumer-side fix already landed and is the functional fix)
- **Research Inputs**: specs/801_literature_index_authors_schema_normalization/reports/01_authors-schema-normalization.md
- **Artifacts**: plans/01_authors-schema-normalization.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 801 is an optional, defense-in-depth follow-up to task 799 (which already fixed the
consumer-side crash and is the sufficient functional fix). The goal here is to (a) prevent
recurrence of the malformed `authors` schema in the Literature corpus and (b) normalize the
existing bad data. Research corrected the task's original premise: the four scripts named in the
description are NOT the write-path root cause. The real root cause is
`~/Projects/Literature/scripts/migrate-from-repo.sh`, which lives in a **separate git repo
outside this config repo's tree**. The plan therefore splits cleanly into two categories:
in-repo work that an implementation agent can perform and commit directly (a validation check and
a reusable normalization script, both under `.claude/`), and external-repo work that only READS
the Literature repo and produces reviewable deliverables in `specs/801.../` for the user to apply
and commit themselves. No phase autonomously modifies or commits to the external Literature repo.

### Research Integration

Key findings integrated from `reports/01_authors-schema-normalization.md`:
- Root cause is `~/Projects/Literature/scripts/migrate-from-repo.sh` (two bugs: root-entry
  merge preserves source `authors` type unchanged; subdirectory merge wraps a comma-joined
  string in a one-element array without splitting), not the four originally-named `.claude/scripts/`
  scripts.
- Canonical-correct reference pattern already exists at
  `.claude/extensions/literature/scripts/zotero-index-add.sh:142-148` — the fix should mirror it.
- Live histogram (270 entries): 12 string-typed + 110 malformed one-element comma-joined arrays
  (of which 3 are top-level document entries: `blackburn_2002_book`, `blackburn_2001`,
  `gabbay_1994`). The 12 string-typed entries are an exact known-bad set enumerated in the report.
- Existing `/literature --validate` schema check lives at `.claude/skills/skill-literature/SKILL.md:396-407`
  and currently only flags `.authors == null` (missing field), not shape.
- A related out-of-scope consumer bug exists at `SKILL.md:1654` (`(.authors // []) | first`
  silently truncates a string to its first character) — deferred to a follow-up, not fixed here.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (no roadmap_path provided; task is meta/defense-in-depth).

## Goals & Non-Goals

**Goals**:
- Extend `/literature --validate` to flag non-array or comma-joined `authors` so any future
  writer that reintroduces the bad shape is caught by routine validation.
- Provide a reusable, dry-run-by-default normalization script in this repo's `.claude/scripts/`
  that splits string-typed and comma-joined one-element `authors` into proper arrays.
- Prepare (but do not apply) the `migrate-from-repo.sh` source fix and a live-index normalization
  diff as reviewable deliverables in `specs/801.../`, with an apply-guide for the user.
- Keep every change to the external `~/Projects/Literature` repo read-only within this task.

**Non-Goals**:
- Do NOT autonomously edit or commit anything in `~/Projects/Literature` (separate repo,
  canonical data, requires human review before committing per research risk analysis).
- Do NOT fix the out-of-scope `SKILL.md:1654` `first`-on-string bug (flag for a follow-up task).
- Do NOT add a new global-index `--validate` mode to the skill (possible follow-up; the
  normalization script's dry-run already surfaces global-index shape issues).
- Do NOT touch the four originally-named scripts — research confirmed they are not implicated.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Normalization mis-splits a name containing a legitimate comma (e.g. "Jr." suffix, "Last, First") | H | L | Script defaults to `--dry-run`; user reviews the full diff before applying; validate heuristic and script share the same conservative split logic; test against the known 270-entry corpus |
| Validate heuristic false-positives on legitimate `"Last, First"` single-author strings | M | M | Test heuristic against full current corpus; only flag elements with 2+ `, ` occurrences or multiple capitalized name-like tokens, per research guidance |
| Agent inadvertently modifies/commits the external Literature repo | H | L | Plan explicitly confines external-repo interaction to reads; all external deliverables are written into `specs/801.../`; Testing phase verifies external repo git status is clean |
| Recurrence-prevention goal not met if migrate fix is never applied | M | M | Deliverable is a ready-to-apply patch + apply-guide; clearly flagged in summary and handoff for user action |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Extend /literature --validate authors-shape check [COMPLETED]

**Goal**: Make routine `/literature --validate` catch non-array and comma-joined `authors` so
future regressions are surfaced automatically.

**Tasks**:
- [x] In `.claude/skills/skill-literature/SKILL.md` Validate Step 2 (the `missing_fields` jq at
      lines ~396-407), add an authors-shape check that emits warnings for: (a) `authors` present
      but not an array (`(.authors | type) != "array"`), (b) an array element that is not a string,
      (c) an array element that looks comma-joined (contains `, ` followed by a capitalized
      name-like token, i.e. a likely second full name). *(completed)*
- [x] Keep the existing `.authors == null` missing-field warning intact; add the shape check as a
      separate `schema_warnings` category (e.g. `authors:not-array`, `authors:non-string-element`,
      `authors:possibly-comma-joined`) so the two concerns stay distinguishable in output.
      *(completed: added as a distinct `authors_shape_warnings` array/category, kept separate from
      `schema_warnings`)*
- [x] Refine the "possibly-comma-joined" heuristic to avoid flagging legitimate single-author
      `"Last, First"` strings (which `zotero-index-add.sh` itself produces) — flag only when an
      element contains 2+ `, ` occurrences or a `, ` followed by a further capitalized token that
      resembles a second name. *(completed: 2+ `, ` occurrences, or exactly one `, ` followed by
      2+ non-initial capitalized tokens in the remainder)*
- [x] Update any nearby validate-output/reporting block in the skill so the new warning categories
      are surfaced to the user alongside existing `schema_warnings`. *(completed: added "Authors
      Shape Warnings" section to Validate Step 4 Display Report)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-literature/SKILL.md` - extend Validate Step 2 jq and warning reporting.

**Verification**:
- Run the new jq heuristic against a copy of the current per-repo `specs/literature/index.json`
  (or a fixture built from the report's known-bad set) and confirm it flags string-typed and
  comma-joined entries while producing zero false positives on legitimate `"Last, First"`
  single-author entries.

---

### Phase 2: Create reusable authors-normalization script [COMPLETED]

**Goal**: Provide an idempotent, dry-run-by-default tool (versioned in this repo) that normalizes
`authors` in any `index.json`, to be run by the user against the external global index in Phase 4.

**Tasks**:
- [x] Create `.claude/scripts/literature-normalize-authors.sh` accepting an index path argument
      and defaulting to a non-mutating dry-run (require an explicit `--apply`/`--write` flag to
      persist changes). *(completed)*
- [x] Implement the normalization rules from the research: if `authors` is a string, split on
      `, ` into an array; if `authors` is a one-element array whose single string contains `, `,
      split that element into multiple elements; otherwise leave unchanged. Model the split logic
      on `.claude/extensions/literature/scripts/zotero-index-add.sh:142-148`. *(completed)*
- [x] Guard against name-internal commas conservatively (mirror the same heuristic used by the
      Phase 1 validate check so the two stay consistent). *(completed: shared `is_comma_joined`
      heuristic matching Phase 1's SKILL.md jq check, applied to both the raw-string rule and the
      one-element-array rule)*
- [x] In dry-run mode, print a per-entry before/after diff and a summary count of entries that
      would change; make repeated runs idempotent (a normalized index produces zero changes).
      *(completed and verified against a scratch copy of the live global index)*
- [x] Add a short usage header comment documenting the `--apply` flag and the dry-run default.
      *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/literature-normalize-authors.sh` - new reusable normalization/checker script.

**Verification**:
- Dry-run against a fixture containing the report's 12 string-typed + representative malformed
  entries produces the expected splits; a second run over the normalized fixture reports zero
  changes (idempotence). Script makes no writes without `--apply`.

---

### Phase 3: Document the Literature tooling ownership boundary [COMPLETED]

**Goal**: Record that migration tooling lives in the external Literature repo, preventing future
mis-scoped audits (research Context Extension Recommendation).

**Tasks**:
- [x] Add a short note to the literature context docs (e.g. under
      `.claude/context/project/literature/`) clarifying that one-time/re-runnable migration
      tooling for importing a project's `specs/literature/` into the central corpus lives in
      `~/Projects/Literature/scripts/migrate-from-repo.sh` — NOT in this repo's `.claude/scripts/`
      — and that the central `index.json` is likewise owned by the separate Literature repo.
      *(completed: added "Tooling Ownership Boundary" section to
      `.claude/context/project/literature/domain/literature-index.md`)*
- [x] Cross-reference the new `.claude/scripts/literature-normalize-authors.sh` (Phase 2) and the
      extended `/literature --validate` check (Phase 1) as the maintenance tools for this schema.
      *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- A literature context doc under `.claude/context/project/literature/` (locate the existing
  literature architecture doc during implementation; create a concise note file only if none fits).

**Verification**:
- The note names the external script path and the ownership boundary, and links the two in-repo
  maintenance tools.

---

### Phase 4: Prepare external-repo deliverables and apply-guide [NOT STARTED]

**Goal**: Produce ready-to-apply, reviewable deliverables for the external Literature repo work
without modifying or committing to that repo.

**Tasks**:
- [ ] Read `~/Projects/Literature/scripts/migrate-from-repo.sh` (read-only) and author a unified
      diff / patch file (saved under `specs/801_literature_index_authors_schema_normalization/`)
      that fixes both authors-handling sites: the root-entry path (~lines 161-173) to split a
      string-typed `.authors` on `, `, and the subdirectory/chapter path (~lines 246, 301) to
      split `$authors` on `, ` when it is a string instead of wrapping it as `[$authors]`.
- [ ] Run the Phase 2 normalization script in dry-run against `~/Projects/Literature/index.json`
      (read-only) and capture the full before/after diff as an artifact under `specs/801.../`.
- [ ] Write an apply-guide markdown under `specs/801.../` giving the user exact steps to: apply
      the migrate patch, run `literature-normalize-authors.sh --apply` against the global index,
      review `git diff` in the Literature repo (cross-checking the report's known-bad set), and
      commit there. Explicitly note this is user action outside this repo.
- [ ] Note in the apply-guide the deferred out-of-scope `SKILL.md:1654` bug as a candidate
      follow-up task.

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `specs/801_literature_index_authors_schema_normalization/` - patch file, dry-run diff capture,
  and apply-guide markdown (deliverables only; no external-repo writes).

**Verification**:
- The patch applies cleanly against the current `migrate-from-repo.sh` (test with `git apply
  --check` in a scratch copy, not the live external repo). The dry-run diff enumerates the
  expected 12 string + 110 malformed entries. `git -C ~/Projects/Literature status` shows a clean
  tree (no agent modifications).

---

## Testing & Validation

- [ ] Phase 1 heuristic flags all known-bad shapes and zero legitimate `"Last, First"` entries
      when run against the current corpus.
- [ ] Phase 2 script is dry-run by default, produces correct splits, and is idempotent.
- [ ] Phase 2 script makes no filesystem writes without an explicit `--apply` flag.
- [ ] Phase 4 patch passes `git apply --check` against a scratch copy of `migrate-from-repo.sh`.
- [ ] External repo remains unmodified: `git -C ~/Projects/Literature status` is clean after the
      task completes.
- [ ] `bash .claude/scripts/check-extension-docs.sh` (if it exercises literature docs) passes for
      any new context note added in Phase 3.

## Artifacts & Outputs

- `.claude/skills/skill-literature/SKILL.md` (modified — extended validate check)
- `.claude/scripts/literature-normalize-authors.sh` (new — reusable normalization/checker)
- A literature context note under `.claude/context/project/literature/` (new or modified)
- `specs/801_literature_index_authors_schema_normalization/` deliverables: `migrate-from-repo.sh`
  patch file, normalization dry-run diff capture, and apply-guide markdown
- `specs/801_literature_index_authors_schema_normalization/summaries/01_authors-schema-normalization-summary.md`

## Rollback/Contingency

- All in-repo changes (Phases 1-3) are isolated to `.claude/` and are revertable via `git revert`
  or `git checkout` of the touched files in this config repo.
- No external-repo changes are made by the task, so there is nothing to roll back in
  `~/Projects/Literature`; the prepared patch and normalization are inert until the user applies
  them.
- If the Phase 1 heuristic proves noisy in practice, it can be tightened or reverted independently
  of the Phase 2 script, since the two are separately committed.

# Implementation Plan: Migrate All 19 Extensions' index-entries.json to the Reconciled Schema

- **Task**: 990 - Migrate all 19 extensions index-entries.json to the reconciled schema shape
- **Status**: [IMPLEMENTING]
- **Effort**: 11 hours (phase sum 10.75)
- **Dependencies**: 987 (completed — landed `index.schema.json` and `check-extension-docs.sh` Rule T in `advisory` mode)
- **Research Inputs**: `specs/990_index_entries_schema_migration/reports/01_index-entries-schema-migration.md`
- **Artifacts**: plans/01_index-entries-schema-migration.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

All 19 extensions' *source* `index-entries.json` files (in `agent-system/extensions/**`, never
`.claude/**`) must be migrated to the reconciled `index.schema.json` entry shape so
`check-extension-docs.sh`'s Rule T reports zero advisories. The live gate currently emits **580**
advisory lines across **17 of 19** extensions (only `epidemiology` and `slidev` are clean), broken
into five categories: `load_when.languages` 275, `description` 147, `tags` 94,
`load_when.topics` 40, `load_when.skills` 24. The work is organized as one phase per
territory-disjoint extension cluster — each phase owns a distinct set of `index-entries.json`
files, so phases 2-10 can execute in parallel. Definition of done is the task's inherited
verification bar: zero Rule T advisories plus a zero-hit `load_when.languages|load_when.skills`
grep, with no entry losing its reachability in `context-discovery.md`'s adaptive query.

### Research Integration

The research report's six corrections are binding and supersede the task description's own
numbers wherever they conflict:

1. **147, not 166** description-bearing entries (cslib 16, email 8, filetypes 11, latex 10,
   lean 31, nix 11, python 6, typst 26, web 23, z3 5).
2. **`tags` exists in only 6 of the 10 named extensions** (cslib 16, latex 10, lean 31, python 6,
   typst 26, z3 5 = 94). `email`, `filetypes`, `nix`, `web` have no `tags` field — the rename is a
   no-op there, not a defect to chase.
3. **The fold-in is genuinely editorial.** 13 entries have `description` + `summary` combined
   length > the schema's `summary.maxLength: 200` and need an actual rewrite, not concatenation
   (cslib 3, email 6, lean 4); 2 lean summaries already exceed 200 on their own and must shrink
   regardless.
4. **`memory/project/memory/memory-troubleshooting.md`** has `skills` as its *only* reachability
   hook. A blind delete orphans it; it needs `commands: ["/learn", "/distill"]` added at the same
   time.
5. **`core` (9 entries) and `email` (1 entry) are also in `load_when.skills` scope**, though named
   in no WORK item. `core/patterns/lit-stage4a-flow.md` is a second orphan risk — its only other
   key is an inert `task_types: []`.
6. **`formal` has 40 `load_when.topics` violations** covered by no WORK item. These must be
   *hoisted* to entry-level `topics` (a valid schema field formal does not currently use), not
   deleted.

Plus the report's `founder` finding: 11 entries carry both `languages` and `task_types`, so
WORK item 3 must **union**, never overwrite.

**Two live-audit refinements this plan adds on top of the report:**

- **`email`'s 8 and `filetypes`' 9 `load_when.languages` arrays are EMPTY** (`[]`), and
  `filetypes`' other 2 are the dead `["deck"]`. None of the 17 is a rename — all 17 are
  deletions. Only the 258 non-empty declarations across the 12 migration-map extensions are
  renames (256 renames + the 2 `["deck"]` deletions = 258).
- **The corpus is 461 entries, not 470.** Confirmed by
  `jq -s '[.[].entries]|flatten|length' agent-system/extensions/*/index-entries.json`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; ROADMAP.md was not consulted.

## Goals & Non-Goals

**Goals**:
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports
  **zero** Rule T advisories across all 19 extensions.
- `grep -rn 'load_when.languages\|load_when.skills' agent-system/extensions/*/index-entries.json`
  returns **zero** declarations.
- Every entry that is reachable via `context-discovery.md`'s adaptive query today remains
  reachable after migration — verified by diff against a pre-migration baseline, not assumed.
- Every `summary` stays within the schema's 200-character cap, with the 13 over-cap merges
  rewritten rather than concatenated.
- All 19 files remain valid JSON with unchanged entry counts (461 total).

**Non-Goals**:
- **Do not delete or fold `formal`'s `category` field.** It is a real
  `additionalProperties: false` violation on all 46 formal entries, but Rule T does not check it,
  the verification bar does not require it, and whether its content should be discarded or folded
  into `subdomain`/`topics` is unverified. Leave it exactly as-is for a future task.
- **Do not promote `SCHEMA_CONFORMANCE_GATE_MODE` from `advisory` to `hard`.** That is the
  explicit scope of a follow-up task.
- **Do not "fix" `nvim`'s `neovim`/`nvim` naming mismatch.** The task_type string is `neovim`
  while the directory is `nvim`; this is a pre-existing mismatch to preserve verbatim, not
  invent around.
- **Do not resolve `formal`'s bare `logic`/`math`/`physics` values against the manifest's
  colon-form `formal:logic`/`formal:math`/`formal:physics` routing keys.** WORK item 3 says
  migrate 1:1; this plan reads that as *keep the literal string values unchanged*, yielding
  `task_types: ["formal", "logic", "math", "physics"]` — the same "preserve, do not invent
  around" stance applied to `nvim`.
- Do not touch `line_count`, `domain`, `subdomain`, or `path` fields.
- Do not edit `.claude/**`. It is a regenerated deploy artifact.
- Do not clean up the 189 unrelated empty-array `load_when` keys (core 151, email 17,
  filetypes 11, founder 10) beyond the ones this migration's own edits touch.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A blind scripted `skills` delete orphans `memory-troubleshooting.md` and `core/patterns/lit-stage4a-flow.md` | H | H | Phases 2 and 3 name both entries by path with their required replacement hooks and forbid a bare delete; Phase 11 diffs reachability against the Phase 1 baseline |
| A uniform `languages -> task_types` jq rename silently drops `founder`'s 11 pre-existing `task_types` values | H | H | `founder` is isolated in Phase 10 with a union-merge step and a before/after `task_types` array-length diff for exactly those 11 paths |
| `formal`'s `load_when.topics` hoist is forgotten (covered by no WORK item, and not caught by the grep spot-check) | H | M | Phase 9 owns it as an explicit, separately verified sub-step; Phase 11 treats the full Rule T run — not the grep — as the binding check |
| Naive `description` + `summary` concatenation produces schema-invalid summaries > 200 chars | M | H | The 13 over-cap entries are enumerated per phase and flagged as requiring rewrite; Phase 11 asserts a zero-count of `summary` > 200 across the corpus |
| Edits land in `.claude/**` instead of `agent-system/extensions/**` and are wiped on next deploy | H | M | Source-store rule restated in every phase's task list; Phase 11 greps `.claude/**` index-entries copies for unexpected divergence and confirms all edits are git-tracked under `agent-system/` |
| A hand or scripted JSON edit corrupts a file (trailing comma, lost entry) | H | L | Per-extension `jq empty` + entry-count assertion is a green criterion for every phase, not deferred to Phase 11 |
| Merged summary text introduces a task-number citation into a deliverable | M | L | Phase 11 runs `check-task-references.sh`; `agent-system/**` is a deliverable tree, not exempt |
| The 275 `languages` figure conflates 258 renames with 17 deletions, leading to inert `task_types: []` keys | M | M | Phases 4 (email, filetypes) treat empty arrays as deletions; renames only apply to non-empty arrays |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5, 6, 7, 8, 9, 10 | 1 |
| 3 | 11 | 2, 3, 4, 5, 6, 7, 8, 9, 10 |

Phases within the same wave can execute in parallel. Wave 2's nine phases are strictly
territory-disjoint: each owns its own set of `agent-system/extensions/*/index-entries.json`
files, and no file is written by two phases.

---

### Phase 1: Baseline Capture and Reachability Snapshot [COMPLETED]

**Goal**: Record the pre-migration ground truth so every later phase can be verified by diff
rather than by assumption, and so orphaning is detectable.

**Tasks**:
- [ ] Run `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`
      and save the full Rule T advisory set to a scratch baseline file (outside the repo, e.g.
      the session scratchpad).
- [ ] Record the per-category counts and confirm they still total 580
      (`languages` 275, `description` 147, `tags` 94, `topics` 40, `skills` 24).
- [ ] Record the per-extension entry counts and the corpus total via
      `jq -s '[.[].entries]|flatten|length' agent-system/extensions/*/index-entries.json`.
- [ ] Capture a reachability baseline: for every entry in every extension, record whether it has
      at least one *effective* hook under `context-discovery.md`'s adaptive query — i.e. a
      non-empty `load_when.agents`, `load_when.commands`, or `load_when.task_types`, or
      `load_when.always == true`. Save the list of entries whose effective-hook count is zero
      today (the pre-existing-unreachable set) separately from those with hooks.
- [ ] Confirm the two named orphan-risk entries appear in the baseline as currently reachable
      *only* via `skills`: `memory/project/memory/memory-troubleshooting.md` and
      `core/patterns/lit-stage4a-flow.md`.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts 580 total advisories in five categories (275/147/94/40/24),
461 corpus entries, and exactly 2 skills-only orphan-risk entries. Confirm all three by the
commands in the task list above before any editing phase begins; if any number differs from this
plan, record the live number as authoritative and note the divergence for Phase 11.

**Files to modify**:
- None. Read-only; writes only to a scratch baseline outside the repository.

**Verification**:
- Baseline file exists and is non-empty.
- The zero-effective-hook set is enumerated and includes the two named orphan-risk entries.

---

### Phase 2: `core` — Delete `load_when.skills` (9 entries, 1 with replacement hook) [COMPLETED]

**Goal**: Clear `core`'s 9 `load_when.skills` violations without orphaning
`patterns/lit-stage4a-flow.md`.

**Tasks**:
- [x] Edit **`agent-system/extensions/core/index-entries.json`** only. Never `.claude/**`. *(completed)*
- [x] For the 8 entries that already carry a populated `agents` and/or `commands` array, delete
      the `skills` key outright: `patterns/batch-drain-loop.md`,
      `patterns/context-exhaustion-detection.md`, `patterns/context-protective-lead.md`,
      `patterns/subagent-continuation-loop.md`, `patterns/task-lock.md`,
      `patterns/topic-assignment-pattern.md`, `standards/git-staging-scope.md`,
      `standards/orchestrator-runtime-files.md`. *(completed)*
- [x] For **`patterns/lit-stage4a-flow.md`**, whose only other key is an inert `task_types: []`:
      before or while deleting `skills`, add an `agents` array naming the agents that run its six
      skills — `general-research-agent`, `general-research-hard-agent`,
      `general-implementation-agent`, `general-implementation-hard-agent`, `planner-agent`,
      `planner-hard-agent` — mirroring how `patterns/subagent-continuation-loop.md` already
      expresses skill-implied reachability via `agents`. Also drop the inert `task_types: []`. *(completed)*
- [x] Confirm no other `core` entry was touched (129 of 130 entries unchanged apart from the 9). *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: Asserts exactly 9 `core` entries carry `load_when.skills` and that 8 of them
have an independent `agents`/`commands` hook. Confirm with
`jq -r '.entries[]|select(.load_when.skills)|"\(.path) :: \(.load_when|tostring)"' agent-system/extensions/core/index-entries.json`
before editing; if the count is not 9, or if a second entry lacks an independent hook, treat the
extra entry as a new orphan risk and give it an equivalent `agents`/`commands` replacement rather
than deleting blindly.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` — delete 9 `load_when.skills` keys; add an
  `agents` array to `patterns/lit-stage4a-flow.md` and drop its empty `task_types`.

**Verification**:
- `jq empty agent-system/extensions/core/index-entries.json` passes; entry count still 130.
- `jq '[.entries[]|select(.load_when.skills)]|length'` returns 0.
- `patterns/lit-stage4a-flow.md` has a non-empty `agents` array (its enumerated dependent: the
  adaptive query in `context-discovery.md` must still return it for `planner-agent`).

---

### Phase 3: `literature` + `memory` — Delete `load_when.skills` (14 entries, 1 with replacement hook) [COMPLETED]

**Goal**: Clear the remaining skills-only extensions without orphaning
`memory-troubleshooting.md`.

**Tasks**:
- [x] Edit **`agent-system/extensions/literature/index-entries.json`** and
      **`agent-system/extensions/memory/index-entries.json`** only. Never `.claude/**`.
- [x] `literature`: delete `load_when.skills` from all 6 entries. All 6 already carry a non-empty
      `commands` array (`/literature`, and for three of them `/research`, `/plan`, `/implement`);
      no replacement hook is needed. *(completed)*
- [x] `memory`: delete `load_when.skills` from 7 of 8 entries, each of which already carries a
      matching non-empty `commands` array. *(completed)*
- [x] `memory`: for **`project/memory/memory-troubleshooting.md`**, whose `skills` array is its
      *only* reachability hook, add `commands: ["/learn", "/distill"]` before or while deleting
      `skills` — mirroring the pattern already used by sibling entries
      `domain/memory-reference.md` and `README.md`, which pair those same two skills with those
      same two commands. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: Asserts 6 literature and 8 memory entries carry `load_when.skills`, with
exactly one (`memory-troubleshooting.md`) lacking an independent hook. Confirm with the same
`jq -r '.entries[]|select(.load_when.skills)|"\(.path) :: \(.load_when|tostring)"'` probe against
both files before editing.

**Files to modify**:
- `agent-system/extensions/literature/index-entries.json` — delete 6 `load_when.skills` keys.
- `agent-system/extensions/memory/index-entries.json` — delete 8 `load_when.skills` keys; add
  `commands: ["/learn", "/distill"]` to `memory-troubleshooting.md`.

**Verification**:
- `jq empty` passes on both; entry counts still 6 and 8.
- `jq '[.entries[]|select(.load_when.skills)]|length'` returns 0 for both.
- `memory-troubleshooting.md` has a non-empty `commands` array; the adaptive query for `/learn`
  still returns it.

---

### Phase 4: `email` + `filetypes` — Full Migration (19 entries) [COMPLETED]

**Goal**: Migrate both extensions whose `load_when.languages` arrays are deletions rather than
renames, and fold in their `description` fields.

**Tasks**:
- [x] Edit **`agent-system/extensions/email/index-entries.json`** and
      **`agent-system/extensions/filetypes/index-entries.json`** only. Never `.claude/**`.
- [x] `email` (8 entries): fold each `description` into `summary` and delete `description`.
      **6 of the 8 need a genuine rewrite**, not concatenation, because combined length exceeds
      the 200-char cap — notably `domain/staleness-detection.md` (359 + 150 = 509) and
      `domain/wrapper-contracts.md` (250 + 85 = 335), plus `email-preferences.md`,
      `domain/archive-mode-risk.md`, `patterns/bulk-bucket-review.md`, and
      `design/email-to-memory-preferences.md` in the 205-236 range. Pick and compress the more
      informative phrasing; do not truncate mid-sentence.
- [x] `email`: delete all 8 `load_when.languages` keys. **These arrays are empty (`[]`) — this is
      a deletion, not a rename to `task_types`.** All 8 entries already carry
      `task_types: ["email"]`.
- [x] `email`: delete `load_when.skills` from `design/email-to-memory-preferences.md` (the single
      skills entry). Safe outright — `task_types: ["email"]` already provides reachability.
- [x] `email` has no `tags` field on any entry; WORK item 2 is a no-op here.
- [x] `filetypes` (11 entries): fold each `description` into `summary` and delete `description`.
      No entry exceeds the 200-char cap when merged, so these are straightforward merges.
- [x] `filetypes`: delete all 11 `load_when.languages` keys — 9 are empty (`[]`) and 2 are the
      dead `["deck"]` (`patterns/pitch-deck-structure.md`,
      `patterns/touying-pitch-deck-template.md`). Both `["deck"]` entries already carry 4 `agents`
      and `commands` (`/convert`, `/deck`), and no manifest declares a `deck` task_type, so the
      deletion is lossless. **Do not rename any of these to `task_types`.**
- [x] `filetypes` has no `tags` and no `load_when.skills`; WORK items 2 and 5 are no-ops here.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: Asserts email 8 `description` / 8 empty `languages` / 1 `skills`, and
filetypes 11 `description` / 9 empty + 2 `["deck"]` `languages`; and that 6 email merges exceed
200 chars. Confirm the empty-vs-non-empty split with
`jq '[.entries[]|select(.load_when.languages!=null)|select(.load_when.languages|length==0)]|length'`
per file, and the over-cap set with
`jq -r '.entries[]|select(has("description"))|select(((.summary|length)+(.description|length))>200)|.path'`.
If any `languages` array turns out non-empty in `email`, it is a rename, not a deletion.

**Files to modify**:
- `agent-system/extensions/email/index-entries.json` — 8 description fold-ins (6 rewrites),
  8 `languages` deletions, 1 `skills` deletion.
- `agent-system/extensions/filetypes/index-entries.json` — 11 description fold-ins,
  11 `languages` deletions.

**Verification**:
- `jq empty` passes on both; entry counts still 8 and 11.
- `jq '[.entries[]|select(has("description") or has("tags"))]|length'` returns 0 for both.
- `jq '[.entries[]|select(.load_when.languages or .load_when.skills)]|length'` returns 0 for both.
- `jq '[.entries[]|select((.summary|length)>200)]|length'` returns 0 for both.
- Every entry still has at least one non-empty `agents`/`commands`/`task_types` hook.

---

### Phase 5: `cslib` + `latex` + `python` + `z3` — Full Migration (37 entries) [COMPLETED]

**Goal**: Migrate the four small extensions that carry the full `description` + `tags` +
non-empty `languages` triple with a clean 1:1 task_type mapping.

**Tasks**:
- [x] Edit **`agent-system/extensions/{cslib,latex,python,z3}/index-entries.json`** only. Never
      `.claude/**`.
- [x] Fold `description` into `summary` and delete `description`: cslib 16, latex 10, python 6,
      z3 5 = 37 entries. **3 cslib entries exceed the 200-char cap when merged** and need a
      rewrite; the remaining 34 merge cleanly.
- [x] Rename `tags` -> `keywords` on all 37 entries (cslib 16, latex 10, python 6, z3 5). No entry
      in any of these four already has a populated `keywords` field, so the rename is
      conflict-free; confirm before renaming rather than assuming.
- [x] Rename `load_when.languages` -> `load_when.task_types`, values unchanged: cslib
      `["cslib"]`, latex `["latex"]`, python `["python"]`, z3 `["z3"]`. None of these four has a
      pre-existing `task_types` on the same entry, so this is a pure key rename with no union
      needed — confirm with the overlap probe before renaming.
- [x] None of these four has `load_when.skills` or `load_when.topics`.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: Asserts 37 description-bearing and 37 tags-bearing entries across the four,
37 non-empty `languages`, zero `keywords`/`task_types` collisions, and 3 over-cap cslib merges.
Confirm collisions with
`jq '[.entries[]|select((.load_when.languages!=null) and (.load_when.task_types!=null))]|length'`
and `jq '[.entries[]|select(has("tags") and has("keywords"))]|length'` per file; both must be 0
before a blind rename.

**Files to modify**:
- `agent-system/extensions/cslib/index-entries.json` — 16 entries (3 rewrites).
- `agent-system/extensions/latex/index-entries.json` — 10 entries.
- `agent-system/extensions/python/index-entries.json` — 6 entries.
- `agent-system/extensions/z3/index-entries.json` — 5 entries.

**Verification**:
- `jq empty` passes on all four; entry counts still 16/10/6/5.
- `jq '[.entries[]|select(has("description") or has("tags"))]|length'` returns 0 for each.
- `jq '[.entries[]|select(.load_when.languages)]|length'` returns 0 for each.
- `jq '[.entries[]|select((.summary|length)>200)]|length'` returns 0 for each.
- `task_types` values match the pre-migration `languages` values one-for-one.

---

### Phase 6: `lean` — Full Migration (31 entries) [COMPLETED]

**Goal**: Migrate `lean`, the extension with the heaviest editorial load relative to its size.

**Tasks**:
- [x] Edit **`agent-system/extensions/lean/index-entries.json`** only. Never `.claude/**`.
- [x] Fold `description` into `summary` and delete `description` on all 31 entries.
      **4 entries exceed the 200-char cap when merged** and need a rewrite:
      `contracts/context-hygiene.md` (121 + 273 = 394), `contracts/adversarial-verification.md`
      (148 + 240 = 388), `contracts/anti-analysis.md` (107 + 179 = 286), and
      `contracts/reference-grounding.md` (80 + 191 = 271).
- [x] **2 lean summaries already exceed 200 characters on their own** and must be compressed
      regardless of the merge — identify them with
      `jq -r '.entries[]|select((.summary|length)>200)|.path'` and shrink them as part of the
      same edit. Note this is the only extension where a summary is already over-cap
      pre-migration.
- [x] Rename `tags` -> `keywords` on all 31 entries.
- [x] Rename `load_when.languages` -> `load_when.task_types` on the 30 entries that have it,
      value `["lean4"]` unchanged. **One entry has no `languages` key** — leave its `load_when`
      alone.
- [x] No `load_when.skills` or `load_when.topics` in this extension.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: Asserts 31 description, 31 tags, 30 (not 31) non-empty `languages`, 4
over-cap merges, and 2 already-over-cap summaries. Confirm the 30-vs-31 `languages` split with
`jq '[.entries[]|select(.load_when.languages)]|length'` — a rename loop that assumes 31 will fail
or fabricate a key on the 31st entry.

**Files to modify**:
- `agent-system/extensions/lean/index-entries.json` — 31 fold-ins (4 rewrites + 2 pre-existing
  over-cap compressions), 31 tag renames, 30 languages renames.

**Verification**:
- `jq empty` passes; entry count still 31.
- `jq '[.entries[]|select(has("description") or has("tags"))]|length'` returns 0.
- `jq '[.entries[]|select(.load_when.languages)]|length'` returns 0.
- `jq '[.entries[]|select((.summary|length)>200)]|length'` returns 0 — this is the phase's
  strictest check, since lean is the only extension entering with a pre-existing over-cap summary.
- Exactly 30 entries carry `task_types: ["lean4"]`; the 31st still has no task_types key added.

---

### Phase 7: `typst` — Full Migration (26 entries) [COMPLETED]

**Goal**: Migrate `typst`'s description + tags + languages triple.

**Tasks**:
- [x] Edit **`agent-system/extensions/typst/index-entries.json`** only. Never `.claude/**`.
- [x] Fold `description` into `summary` and delete `description` on all 26 entries. No entry
      exceeds the 200-char cap when merged, so these are straightforward merges — but check each
      merged result against the cap rather than assuming.
- [x] Rename `tags` -> `keywords` on all 26 entries.
- [x] Rename `load_when.languages` -> `load_when.task_types` on all 26 entries, value
      `["typst"]` unchanged. No pre-existing `task_types` overlap.
- [x] No `load_when.skills` or `load_when.topics` in this extension.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: Asserts 26/26/26 for description/tags/non-empty languages and zero over-cap
merges. Confirm the over-cap count with the combined-length probe before editing; if any entry is
over cap, it needs a rewrite, not a concatenation.

**Files to modify**:
- `agent-system/extensions/typst/index-entries.json` — 26 entries, all three transforms.

**Verification**:
- `jq empty` passes; entry count still 26.
- Zero `description`, `tags`, `load_when.languages`; zero summaries > 200.
- All 26 entries carry `task_types: ["typst"]`.

---

### Phase 8: `nix` + `web` — Description Fold-In and Languages Rename (34 entries) [COMPLETED]

**Goal**: Migrate the two extensions that carry `description` and `languages` but no `tags`.

**Tasks**:
- [x] Edit **`agent-system/extensions/nix/index-entries.json`** and
      **`agent-system/extensions/web/index-entries.json`** only. Never `.claude/**`.
- [x] Fold `description` into `summary` and delete `description`: nix 11, web 23 = 34 entries.
      No entry in either exceeds the 200-char cap when merged; verify per entry anyway.
- [x] Rename `load_when.languages` -> `load_when.task_types`: nix `["nix"]` (11 entries), web
      `["web"]` (23 entries), values unchanged. No pre-existing `task_types` overlap in either.
- [x] **Neither extension has a `tags` field.** WORK item 2 is a no-op here — do not go looking
      for one, and do not invent a `keywords` field where none existed.
- [x] No `load_when.skills` or `load_when.topics` in either.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: Asserts nix 11 / web 23 description-bearing entries, matching non-empty
`languages` counts, and zero `tags` in either. Confirm the zero-`tags` claim with
`jq '[.entries[]|select(has("tags"))]|length'` per file — if it is non-zero, the rename step
applies after all.

**Files to modify**:
- `agent-system/extensions/nix/index-entries.json` — 11 entries.
- `agent-system/extensions/web/index-entries.json` — 23 entries.

**Verification**:
- `jq empty` passes on both; entry counts still 11 and 23.
- Zero `description`, zero `tags`, zero `load_when.languages`; zero summaries > 200.
- All 11 nix entries carry `task_types: ["nix"]`; all 23 web entries carry `task_types: ["web"]`.

---

### Phase 9: `formal` — Languages Rename Plus `load_when.topics` Hoist (46 entries) [NOT STARTED]

**Goal**: Migrate `formal`, the only extension with a `load_when.topics` violation, without
losing its topic data and without touching its out-of-scope `category` field.

**Tasks**:
- [ ] Edit **`agent-system/extensions/formal/index-entries.json`** only. Never `.claude/**`.
- [ ] Rename `load_when.languages` -> `load_when.task_types` on all 46 entries. Value strings
      are preserved **verbatim**: `formal` (46), `logic` (23), `math` (22), `physics` (3), so an
      entry with `languages: ["formal","logic"]` becomes `task_types: ["formal","logic"]`. Do
      **not** rewrite these to the manifest's colon-form routing keys
      (`formal:logic`/`formal:math`/`formal:physics`) — WORK item 3 says migrate 1:1, and this
      plan reads that as preserving the literal values, consistent with the `nvim` mismatch
      being preserved rather than invented around.
- [ ] **Hoist `load_when.topics` to entry-level `topics` on the 40 entries that have it.** Move
      the array up to `entries[i].topics` (a valid, already-declared schema field that `formal`
      currently does not use anywhere) and delete the nested `load_when.topics` key. This is a
      move, not a delete — the topic strings are meaningful search keywords.
- [ ] Confirm no `formal` entry already has an entry-level `topics` field before hoisting; if one
      does, union rather than overwrite.
- [ ] **Leave `category` untouched on all 46 entries.** It is a genuine
      `additionalProperties: false` violation, but it is out of scope: Rule T does not check it
      and the verification bar does not require it. Deleting it is not a bonus fix — whether its
      content belongs in `subdomain` or `topics` is unverified.
- [ ] `formal` has no `description`, `tags`, or `load_when.skills`.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: Asserts 46 non-empty `languages`, 40 `load_when.topics`, and zero existing
entry-level `topics`. Confirm with
`jq '[.entries[]|select(.load_when.topics)]|length'` and
`jq '[.entries[]|select(has("topics"))]|length'` before editing. If the second is non-zero, the
hoist must union with existing values, not replace them.

**Files to modify**:
- `agent-system/extensions/formal/index-entries.json` — 46 languages renames, 40 topics hoists.

**Verification**:
- `jq empty` passes; entry count still 46.
- `jq '[.entries[]|select(.load_when.languages or .load_when.topics)]|length'` returns 0.
- `jq '[.entries[]|select(has("topics"))]|length'` returns 40, and the flattened topic-string
  multiset is identical before and after (nothing lost in the hoist).
- `jq '[.entries[]|select(has("category"))]|length'` still returns 46 — the out-of-scope field is
  deliberately untouched.

---

### Phase 10: `founder` + `present` + `nvim` — Languages Migration (83 entries) [NOT STARTED]

**Goal**: Migrate the three remaining languages-only extensions, including the one case that
requires a union-merge rather than a rename.

**Tasks**:
- [ ] Edit **`agent-system/extensions/{founder,present,nvim}/index-entries.json`** only. Never
      `.claude/**`.
- [ ] **`founder` (34 entries) — union, do NOT overwrite.** 11 entries carry both
      `languages: ["founder"]` and a populated, more-specific `task_types`:
      `patterns/legal-planning.md` (`contract-review`, `legal`), `patterns/project-planning.md`
      (`project-timeline`), `domain/spreadsheet-frameworks.md` (`sheet`),
      `patterns/cost-forcing-questions.md` (`sheet`), `templates/typst/cost-breakdown.typ`
      (`sheet`), `domain/financial-analysis.md` (`finance`),
      `patterns/financial-forcing-questions.md` (`finance`), `templates/financial-analysis.md`
      (`finance`), `patterns/pitch-deck-structure.md` (`deck`),
      `patterns/slidev-deck-template.md` (`deck`), `patterns/yc-compliance-checklist.md`
      (`deck`). For each, union `"founder"` into the existing array (e.g.
      `["founder","contract-review","legal"]`) — an overwrite silently drops the actual routing
      discriminators. The other 23 founder entries are a plain rename.
- [ ] **`present` (26 entries)**: plain rename `languages: ["present"]` ->
      `task_types: ["present"]`. `present` has 36 entries total, 26 with `languages` and 10 with
      `task_types`, and the two sets are verified disjoint — no union needed.
- [ ] **`nvim` (23 of 24 entries)**: plain rename `languages: ["neovim"]` ->
      `task_types: ["neovim"]`. **Preserve the `neovim` string exactly**; the directory is `nvim`
      but the task_type is `neovim`, a pre-existing mismatch this task must not "fix". One nvim
      entry has no `languages` key — leave it alone.
- [ ] None of the three has `description`, `tags`, `load_when.skills`, or `load_when.topics`.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: Asserts founder 34 / present 26 / nvim 23 non-empty `languages`, with
exactly 11 founder and 0 present/nvim entries needing a union. Confirm with
`jq '[.entries[]|select((.load_when.languages!=null) and (.load_when.task_types!=null))]|length'`
per file *before* any rename — a uniform rename run against a non-zero count silently destroys
data.

**Files to modify**:
- `agent-system/extensions/founder/index-entries.json` — 23 renames + 11 union-merges.
- `agent-system/extensions/present/index-entries.json` — 26 renames.
- `agent-system/extensions/nvim/index-entries.json` — 23 renames.

**Verification**:
- `jq empty` passes on all three; entry counts still 34/36/24.
- `jq '[.entries[]|select(.load_when.languages)]|length'` returns 0 for each.
- **Union check**: for each of the 11 named founder paths, the post-migration `task_types` array
  length equals its pre-migration length + 1, and still contains every original value. A length
  of 1 on any of those 11 means the union was an overwrite — revert and redo.
- All 23 nvim entries carry `task_types: ["neovim"]`, never `["nvim"]`.

---

### Phase 11: Full-Corpus Verification and Reachability Diff [NOT STARTED]

**Goal**: Prove the inherited verification bar is met and that no entry was orphaned or corrupted
in the process.

**Tasks**:
- [ ] Run the binding check:
      `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` and
      confirm **zero** Rule T advisory lines across all 19 extensions (down from 580).
- [ ] Run the spot-check:
      `grep -rn 'load_when.languages\|load_when.skills' agent-system/extensions/*/index-entries.json`
      and confirm zero hits. **Treat this as a narrower subset of the Rule T run, never a
      substitute for it** — it does not catch `load_when.topics`, `description`, or `tags`.
- [ ] Corpus integrity: `jq empty` on all 19 files; total entry count still 461, and each
      extension's per-file count matches the Phase 1 baseline exactly.
- [ ] Zero forbidden entry keys corpus-wide:
      `jq -s '[.[].entries[]|select(has("description") or has("tags"))]|length' agent-system/extensions/*/index-entries.json`
      returns 0.
- [ ] Cap compliance:
      `jq -s '[.[].entries[]|select((.summary|length)>200)]|length' agent-system/extensions/*/index-entries.json`
      returns 0.
- [ ] **Reachability diff against the Phase 1 baseline**: recompute the effective-hook set
      (non-empty `agents`/`commands`/`task_types`, or `always: true`) for every entry and confirm
      the zero-effective-hook set did not grow. Specifically confirm
      `memory/project/memory/memory-troubleshooting.md` and `core/patterns/lit-stage4a-flow.md`
      are now reachable, and that no previously-reachable entry became unreachable.
- [ ] Run the adaptive query from `context-discovery.md` for a representative sample of hooks
      (`planner-agent`, `/learn`, `/distill`, `/literature`, `task_type=meta`) and confirm the
      migrated entries appear.
- [ ] Deliverable rule: run `bash agent-system/extensions/core/scripts/check-task-references.sh`
      (or the deployed equivalent) and confirm no task-number citation was introduced into any
      merged `summary` text. `agent-system/**` is a deliverable tree, not exempt.
- [ ] Source-store rule: confirm `git status --short` shows changes only under
      `agent-system/extensions/*/index-entries.json` and `specs/990_*/`, with **no** modified
      files under `.claude/`.
- [ ] Optional confidence check: re-run the gate with `SCHEMA_CONFORMANCE_GATE_MODE=hard` to
      confirm it would pass if promoted. **Do not commit any change to the gate's default mode** —
      promotion is a separate follow-up task.

**Timing**: 0.75 hours

**Depends on**: 2, 3, 4, 5, 6, 7, 8, 9, 10

**Verification Tier**: full

**Scope Hypothesis**: Asserts a 580 -> 0 advisory delta and a 461-entry corpus. Both come from
the Phase 1 baseline; if Phase 1 recorded different live numbers, this phase's targets are the
Phase 1 numbers, not the ones written here.

**Files to modify**:
- None. Read-only verification. Any defect found is fixed in the owning phase, which is then
  re-verified.

**Verification**:
- All 10 checks above pass. The Rule T zero-advisory result and the reachability diff are the two
  non-negotiable gates; a green grep with a non-green Rule T run is a failure, not a pass.

---

## Testing & Validation

- [ ] `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` — zero
      Rule T advisories across all 19 extensions (baseline: 580).
- [ ] `grep -rn 'load_when.languages\|load_when.skills' agent-system/extensions/*/index-entries.json`
      — zero declarations.
- [ ] `jq empty` passes on all 19 `index-entries.json` files.
- [ ] Corpus entry count unchanged at 461; per-extension counts unchanged.
- [ ] Zero entries with `description` or `tags` corpus-wide.
- [ ] Zero `summary` fields over 200 characters corpus-wide.
- [ ] Zero `load_when.topics` corpus-wide; `formal` has 40 entry-level `topics` arrays with the
      identical topic-string multiset it had before.
- [ ] Reachability diff: the zero-effective-hook entry set did not grow relative to the Phase 1
      baseline; both named orphan-risk entries are now reachable.
- [ ] `founder`'s 11 dual-keyed entries each retain every original `task_types` value plus
      `"founder"`.
- [ ] `nvim`'s 23 migrated entries carry `task_types: ["neovim"]`.
- [ ] `formal`'s 46 entries still carry their `category` field (out-of-scope, deliberately
      untouched).
- [ ] No task-number citations introduced into `agent-system/**`.
- [ ] `git status --short` shows no modified files under `.claude/`.

## Artifacts & Outputs

- `agent-system/extensions/core/index-entries.json` (modified)
- `agent-system/extensions/cslib/index-entries.json` (modified)
- `agent-system/extensions/email/index-entries.json` (modified)
- `agent-system/extensions/filetypes/index-entries.json` (modified)
- `agent-system/extensions/formal/index-entries.json` (modified)
- `agent-system/extensions/founder/index-entries.json` (modified)
- `agent-system/extensions/latex/index-entries.json` (modified)
- `agent-system/extensions/lean/index-entries.json` (modified)
- `agent-system/extensions/literature/index-entries.json` (modified)
- `agent-system/extensions/memory/index-entries.json` (modified)
- `agent-system/extensions/nix/index-entries.json` (modified)
- `agent-system/extensions/nvim/index-entries.json` (modified)
- `agent-system/extensions/present/index-entries.json` (modified)
- `agent-system/extensions/python/index-entries.json` (modified)
- `agent-system/extensions/typst/index-entries.json` (modified)
- `agent-system/extensions/web/index-entries.json` (modified)
- `agent-system/extensions/z3/index-entries.json` (modified)
- `agent-system/extensions/epidemiology/index-entries.json` (unchanged — already clean)
- `agent-system/extensions/slidev/index-entries.json` (unchanged — already clean)
- `specs/990_index_entries_schema_migration/summaries/01_index-entries-schema-migration-summary.md`

## Rollback/Contingency

Each phase owns a disjoint set of files and commits per green sub-step (one extension per
commit), so a defective phase is reverted by `git revert` of that phase's commits without
disturbing any sibling phase. The migration touches only data files consumed by the extension
loader — no script, agent, or skill behavior changes — so a partial revert leaves the system in a
consistent (if partially migrated) state where Rule T simply reports a non-zero advisory count
again, as it does today. Because the gate remains in `advisory` mode throughout, no revert is
time-critical: a partially migrated corpus never blocks a build or a deploy.

If the reachability diff in Phase 11 shows an entry became unreachable, revert only the owning
extension's commit, restore the entry's hooks, and re-run the diff — do not attempt a corpus-wide
revert.

**Do not** attempt rollback by editing `.claude/**`; it is a regenerated deploy artifact and any
hand-edit there is wiped on the next extension reload.

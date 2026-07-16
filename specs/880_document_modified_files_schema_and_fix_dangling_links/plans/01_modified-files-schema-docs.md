# Implementation Plan: Task #880

- **Task**: 880 - Document the modified_files/files_touched schema that targeted staging depends on
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/880_document_modified_files_schema_and_fix_dangling_links/reports/01_modified-files-schema-dangling-links.md
- **Artifacts**: plans/01_modified-files-schema-docs.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Close two dangling-reference defects of the same class. First, document the `modified_files`
field in `return-metadata-file.md` and the per-objective `files_touched` field in
`progress-file.md` — the fields on which the entire targeted-staging contract rests, cited by
four documents as the schema authority but present in neither. Second, repoint two dangling
relative links in the Neovim integration guide. All work is documentation-only; no new scripts.

### CRITICAL: Edit the tracked source tree, never the deploy tree

The task's `file_scope` and the research report both name `.claude/...` paths. **Those paths are
wrong as edit targets.** Verified during planning:

- `.gitignore` line 7 ignores `/.claude/` entirely. Its own comment: *"Nothing under it is
  hand-authored — every deployed file has a source... Wipe and regenerate at any time."*
- The `.claude/` deploy tree is a **disposable build artifact** regenerated from
  `agent-system/extensions/`. An edit there would be **never committed** and **wiped** on the
  next regeneration.
- Deploy and source were verified **byte-identical** at planning time (`diff -q` clean on all
  three files), so nothing is currently at risk — but every edit must land in the source.

| Deploy path (do NOT edit) | Tracked source (EDIT THIS) |
|---|---|
| `.claude/context/formats/return-metadata-file.md` | `agent-system/extensions/core/context/formats/return-metadata-file.md` |
| `.claude/context/formats/progress-file.md` | `agent-system/extensions/core/context/formats/progress-file.md` |
| `.claude/context/project/neovim/guides/neovim-integration.md` | `agent-system/extensions/nvim/context/project/neovim/guides/neovim-integration.md` |

Note the Neovim guide lives in the **`nvim`** extension, not `core`.

### Research Integration

Key findings carried into this plan:

- Both dangling-field claims VERIFIED against the source tree during planning:
  `grep -c modified_files` on the source `return-metadata-file.md` → **0**;
  `grep -c files_touched` on the source `progress-file.md` → **0**.
- The contract is unambiguous across producer (`general-implementation-agent.md`) and consumer
  (`orchestrator-postflight.sh`): `modified_files` is an optional top-level `string[]`,
  **repo-relative** paths, individual files only (no directories), empty → write `[]`, never omit.
- The description's citation `general-implementation-agent.md:394` is **stale** (the file has
  drifted). Real citations: lines 151-155, 166-168, 212-215, 425-435, 494. Do not anchor any edit
  or any written cross-reference at line 394.
- The prospective/retrospective contrast already exists at `state-management-schema.md`
  (heading `### File Scope Field`, line 231). Link/mirror it rather than re-deriving it.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided and no roadmap flag set; roadmap phases are not part of this plan.

## Goals & Non-Goals

**Goals**:
- Document `modified_files` in the source `return-metadata-file.md`: type, position, semantics,
  path form (repo-relative), directory prohibition, empty-array requirement, and provenance.
- Document `files_touched` in the source `progress-file.md` as a per-objective field, including
  its additive semantics and its role feeding the summed `modified_files`.
- Make the retrospective-vs-prospective (`modified_files`/`files_touched` vs `file_scope`)
  distinction explicit in both schema docs.
- Repoint the two dangling links in the Neovim integration guide so they resolve **from the
  deployed location**.
- Keep the deploy tree byte-identical to source (convenience mirror only; never committed).

**Non-Goals**:
- No new scripts, no script changes (`orchestrator-postflight.sh` is read-only reference).
- No edits to the four *citing* documents (`git-staging-scope.md`, `skill-git-workflow/SKILL.md`,
  `general-implementation-agent.md`) — this task documents the schema; the agent-emitter task
  is separate and is unblocked by this one.
- No edits to `.opencode/` mirrors, nor restructuring of `return-metadata-file.md`'s existing
  (pre-existing, `.opencode`-flavored) Related Documentation list.
- No change to the actual runtime behavior of staging.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer edits `.claude/` instead of source; work is wiped and never committed | H | M | The mapping table above; Phase 4 asserts `git status` shows the three source files as modified |
| Implementer "re-fixes" the Neovim link depth against the source location and breaks it | H | M | Phase 3 states the deploy-location reasoning explicitly and forbids recomputing from source |
| Implementer anchors an edit at the stale line 394 | M | L | Called out in Research Integration and in Phase 2 |
| New docs hardcode brittle line numbers that drift again | M | M | Cite section/field names only, never line numbers, in all authored content |
| Task-number citations leak into deliverables outside `specs/**` | M | M | Explicit rule restated in every phase's tasks; Phase 4 greps for it |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. Phases 1, 2, and 3 touch three disjoint
files and have no ordering constraint between them — the cross-references they author point at
files that already exist, so neither edit needs the other to land first.

---

### Phase 1: Document `files_touched` in progress-file.md [COMPLETED]

**Goal**: Make `progress-file.md` the authoritative schema for the per-objective `files_touched`
array that the implementation agent accumulates and later sums.

**Edit target** (tracked source, NOT the deploy copy):
`agent-system/extensions/core/context/formats/progress-file.md`

**Tasks**:
- [x] Add a `files_touched` row to the `### objectives (required)` per-objective field table
      (currently `id` / `description` / `status` / `note`): type `array of strings`, Required `No`,
      described as repo-relative paths of files written or edited while working this objective.
      *(completed)*
- [x] Extend the `**Immutability**` note that follows the table so it stays accurate: `id` and
      `description` remain immutable; `status`, `note`, **and `files_touched`** change during
      execution. `files_touched` is **additive** — appended to, never overwritten, across updates
      to the same objective. *(completed)*
- [x] In prose beneath the table, state: entries are **individual repo-relative file paths**, not
      directory prefixes and not absolute paths; and this per-objective array is the accumulation
      mechanism that the implementation agent sums (flattened + deduplicated across every phase
      and every objective) into the top-level `modified_files` field of `.return-meta.json`.
      *(completed)*
- [x] Cross-reference `return-metadata-file.md` (sibling file, link as `return-metadata-file.md`)
      and `../standards/git-staging-scope.md` — the latter path verified to resolve from both the
      source and deploy `context/formats/` directories. *(completed)*
- [x] Add a `files_touched` array to at least one objective in the `## Schema` skeleton JSON so
      the field appears in the canonical shape. *(completed)*
- [x] Add `files_touched` arrays to the objectives in the `## Example: Implementation Progress`
      full example. Show a realistic done-objective with 1-2 repo-relative paths, and at least one
      objective demonstrating that a `not_started` objective may carry an empty array or omit it.
      *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/context/formats/progress-file.md` - add `files_touched` to the
  objectives field table, the immutability note, the schema skeleton, and the worked example;
  add prose on path form, additivity, and the link to `modified_files`.

**Verification**:
- `grep -c files_touched agent-system/extensions/core/context/formats/progress-file.md` returns
  a count of at least 5 (table row + prose + skeleton + example occurrences).
- Every JSON block in the file still parses: extract each fenced ```json block and pipe through
  `jq empty`.
- The file contains no `task {N}` / `tasks {N}-{M}` citation and no hardcoded line-number
  citation to `general-implementation-agent.md`.

---

### Phase 2: Document `modified_files` in return-metadata-file.md [COMPLETED]

**Goal**: Make `return-metadata-file.md` the authoritative schema for the top-level
`modified_files` array that `orchestrator-postflight.sh` feeds directly to `git add`.

**Edit target** (tracked source, NOT the deploy copy):
`agent-system/extensions/core/context/formats/return-metadata-file.md`

**Tasks**:
- [x] Add a new `### modified_files (optional)` field-specification section positioned **after
      `### reflection (optional)` and before `### errors (optional)`**, matching the field's
      position in the worked Implementation Success example. *(completed)*
- [x] Content of the new section must state all of:
      - **Type**: optional `string[]` at the **top level** of `.return-meta.json` (a sibling of
        `memory_candidates` and `reflection`, not nested under `completion_data`).
      - **Include if**: the operation is `implement` (populated by implementation agents);
        unused/absent for `research` and `plan` operations.
      - **Path form**: **repo-relative** paths, relative to the repository root. State this
        explicitly — it is load-bearing, because postflight passes these entries straight to
        `git add` invoked from the repo root alongside repo-relative literals. Do not leave it
        implied. Absolute paths are not permitted.
      - **Granularity**: entries are **individual file paths**. Directory prefixes are **not**
        permitted.
      - **Empty behavior**: if no files were touched, write `"modified_files": []` — **never omit
        the field**. An empty or absent array is non-fatal: the consumer falls back to staging the
        fixed task-directory scope and emits a loud stderr warning. It never escalates to
        `git add -A`.
      - **Provenance**: the flattened, deduplicated union of every phase's every objective's
        `files_touched` array from that task's progress files (cross-reference
        `progress-file.md`). *(completed)*
- [x] Add the retrospective/prospective contrast: `modified_files` and `files_touched` are
      **retrospective** (what an agent actually touched, self-reported at implementation time, for
      git staging); `state.json`'s `file_scope` is **prospective** (what a task is declared to
      touch, set at creation time, for lock-overlap detection). The two are complementary and are
      never merged or reconciled against each other. Point to
      `../reference/state-management-schema.md` and its `File Scope Field` section by **name, not
      line number** (path verified to resolve from both source and deploy `context/formats/`).
      *(completed)*
- [x] Cross-reference `../standards/git-staging-scope.md` as the fullest narrative description of
      the staging contract. *(completed)*
- [x] Add `"modified_files": [...]` to the top-level `## Schema` skeleton JSON block, placed
      consistently with the field-spec ordering. *(completed)*
- [x] Add a realistic `"modified_files"` array to the `### Implementation Success (Non-Meta)`
      example, which currently omits the key entirely. Use repo-relative paths consistent with
      that example's existing `artifacts` entries. *(completed)*

**Constraints**:
- Do **not** anchor any edit at `general-implementation-agent.md:394` — that citation is stale.
- Cite section and field names, never line numbers, in all authored content.
- Leave the existing `## Related Documentation` list untouched (pre-existing `.opencode`-flavored
  list; out of scope). Cross-references belong inline in the new section.

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - add the
  `### modified_files (optional)` section between `reflection` and `errors`; add the field to the
  `## Schema` skeleton and to the Implementation Success example.

**Verification**:
- `grep -c modified_files agent-system/extensions/core/context/formats/return-metadata-file.md`
  returns a count of at least 5.
- The new heading sits strictly between the `reflection` and `errors` headings:
  `grep -n '^### \(reflection\|modified_files\|errors\)' <file>` shows that order.
- Every fenced ```json block still parses under `jq empty`.
- The words "repo-relative", the directory prohibition, and the never-omit-`[]` rule are all
  present in the new section.
- No `task {N}` citation and no `general-implementation-agent.md:` line-number citation.

---

### Phase 3: Fix the two dangling links in neovim-integration.md [COMPLETED]

**Goal**: Repoint two `See Also` links that currently resolve outside the repository.

**Edit target** (tracked source in the **nvim** extension, NOT the deploy copy):
`agent-system/extensions/nvim/context/project/neovim/guides/neovim-integration.md`

**The two replacements** (in the `## See Also` section, near the end of the file):

| Current (dangling, 6 levels up) | Corrected (4 levels up) |
|---|---|
| `[Permission Configuration](../../../../../../.claude/docs/guides/permission-configuration.md)` | `[Permission Configuration](../../../../docs/guides/permission-configuration.md)` |
| `[User Guide](../../../../../../.claude/docs/guides/user-guide.md)` | `[User Guide](../../../../docs/guides/user-guide.md)` |

**CRITICAL — read before touching the link depth**:

This file is **edited in the source tree** but its relative links must resolve **from its
deployed location**, `.claude/context/project/neovim/guides/`. The depth is computed against the
deploy location, and that is correct. Verified during planning:

- From the **deploy** dir, `../../../../docs/guides/permission-configuration.md` resolves to
  `.claude/docs/guides/permission-configuration.md` — **exists**. Same for `user-guide.md`.
- From the **source** dir, the same relative path resolves to
  `agent-system/extensions/nvim/docs/guides/permission-configuration.md` — **does not exist**.

That source-tree miss is expected and is **not a bug**. The `nvim` extension's context deploys
into `.claude/context/...` while the link target (`docs/guides/`) deploys from the **core**
extension into `.claude/docs/...`; the two only sit at the correct relative offset once both are
deployed. **Do NOT recompute the depth against the source-tree location, and do NOT "fix" it to
make it resolve from `agent-system/`.** Any verification of these links must be performed against
the deployed path, per the Verification block below.

**Tasks**:
- [x] Apply the two link replacements exactly as tabulated above. Change only the link targets;
      leave link text and the trailing descriptions (`- Hook permissions`,
      `- General Claude Code usage`) unchanged. *(completed)*
- [x] Leave the sibling `[TTS/STT Integration Guide](tts-stt-integration.md)` link untouched.
      *(completed)*

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/nvim/context/project/neovim/guides/neovim-integration.md` - replace two
  dangling 6-level-up link targets with the correct 4-level-up targets.

**Verification**:
- No six-level-up path remains:
  `grep -c '\.\./\.\./\.\./\.\./\.\./\.\.' <source file>` returns 0.
- Both corrected targets resolve **from the deploy directory** (this is the correct test):
  `test -f .claude/context/project/neovim/guides/../../../../docs/guides/permission-configuration.md`
  and the same for `user-guide.md` — both must pass.
- The `## See Also` section still contains exactly its original four bullets.

---

### Phase 4: Mirror source to deploy and verify the whole change [COMPLETED]

**Goal**: Restore the source/deploy byte-identity invariant so the live session sees the new
schema text, then verify the complete change set.

**Context**: `.claude/` is gitignored and disposable; it is regenerated from
`agent-system/extensions/` by the extension picker. Copying each edited source file over its
deploy counterpart reproduces exactly what regeneration would produce for these three files, and
preserves the byte-identity that held before this task. This mirror is a **convenience only** —
it is never committed and carries no risk, because the source is the sole authority.

**Tasks**:
- [x] Copy each edited source file over its deploy counterpart (three `cp` operations following
      the mapping table in the Overview). *(completed)*
- [x] Confirm `diff -q` is clean for all three source/deploy pairs. *(completed)*
- [x] Confirm `git status --short` lists the **three source files under `agent-system/`** as
      modified, and lists **nothing under `.claude/`** (it is gitignored — its appearance would
      mean the wrong tree was edited). *(deviation: altered — the three files were already
      committed individually at the end of Phases 1-3 per the mandatory per-phase-green commit
      workflow, so `git status --short` no longer shows them as pending "M"; verified instead via
      `git log --oneline -- <path>` for each of the three files, confirming each carries a `task
      880 phase N: ...` commit, and confirmed `.claude/` shows no tracked entries at all —
      stronger than the original ask, since the work is already durably committed, not merely
      staged)*
- [x] Run the deliverable-rule sweep: confirm no `task {N}` / `tasks {N}-{M}` citation was
      introduced into any of the three edited files (all live outside `specs/**`). *(completed:
      swept via `git diff <pre-880-commit>..HEAD` restricted to added lines — zero added lines
      contain a task-number citation; two pre-existing citations in return-metadata-file.md,
      predating this task, were left untouched per Non-Goals)*
- [x] Confirm the no-new-scripts constraint held: `git status --short` shows no added `.sh` file
      and no modification to `orchestrator-postflight.sh`. *(completed)*
- [x] Confirm every fenced ```json block in both edited schema files parses under `jq empty`.
      *(completed: all newly-authored blocks parse; one pre-existing non-JSON comment-prefixed
      block in return-metadata-file.md, predating this task, was left as-is per Non-Goals)*

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3

**Files to modify**:
- None in the source tree. Writes only to the gitignored deploy tree:
  `.claude/context/formats/return-metadata-file.md`,
  `.claude/context/formats/progress-file.md`,
  `.claude/context/project/neovim/guides/neovim-integration.md`.

**Verification**:
- All three `diff -q` pairs clean.
- `git status --short` shows exactly the three `agent-system/**` files modified, nothing under
  `.claude/`, no new scripts.
- The Phase 3 deploy-location link tests pass against the mirrored deploy copies.

---

## Testing & Validation

- [ ] `grep -c modified_files agent-system/extensions/core/context/formats/return-metadata-file.md`
      >= 5 (was 0).
- [ ] `grep -c files_touched agent-system/extensions/core/context/formats/progress-file.md`
      >= 5 (was 0).
- [ ] Both schema docs state, in the new content: repo-relative path form, directories not
      permitted, and empty → write `[]` never omit.
- [ ] Both schema docs contain the retrospective-vs-`file_scope`-prospective contrast.
- [ ] The two schema docs cross-reference each other, and `modified_files` points to
      `git-staging-scope.md` and `state-management-schema.md` by section/field name.
- [ ] Every fenced ```json block in both schema docs parses under `jq empty`.
- [ ] Zero six-level-up relative paths remain in `neovim-integration.md`; both corrected links
      resolve from the **deploy** location.
- [ ] Source and deploy byte-identical for all three files.
- [ ] No task-number citations in any of the three edited files.
- [ ] No new scripts; `orchestrator-postflight.sh` unmodified.

## Artifacts & Outputs

- `agent-system/extensions/core/context/formats/return-metadata-file.md` (modified) — new
  `### modified_files (optional)` section, schema skeleton entry, example entry.
- `agent-system/extensions/core/context/formats/progress-file.md` (modified) — `files_touched`
  field-table row, additivity/path-form prose, skeleton and example entries.
- `agent-system/extensions/nvim/context/project/neovim/guides/neovim-integration.md` (modified) —
  two corrected `See Also` links.
- Deploy-tree mirrors of the above three (gitignored, not committed, not artifacts of record).
- `specs/880_document_modified_files_schema_and_fix_dangling_links/summaries/01_*-summary.md`
  (implementation summary).

## Rollback/Contingency

All changes are additive documentation edits to three tracked files in a clean, isolated scope.
To revert: `git checkout -- agent-system/extensions/core/context/formats/return-metadata-file.md
agent-system/extensions/core/context/formats/progress-file.md
agent-system/extensions/nvim/context/project/neovim/guides/neovim-integration.md`, then re-mirror
source over the three deploy paths (or regenerate the deploy tree from the extension picker,
which is the sanctioned reset path for the entire disposable `.claude/` tree).

No runtime behavior changes, so there is no failure mode requiring coordinated rollback: if the
new schema text is wrong, the fallback is the status quo ante — agents that never learned to emit
the field and trigger the existing non-fatal under-stage warning path.

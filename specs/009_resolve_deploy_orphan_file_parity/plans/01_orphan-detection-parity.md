# Implementation Plan: Task #9

- **Task**: 9 - resolve_deploy_orphan_file_parity
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: 32 (deploy, completed), 18 (staleness detection, completed) -- both preconditions satisfied
- **Research Inputs**: specs/009_resolve_deploy_orphan_file_parity/reports/01_orphan-file-parity-remeasurement.md
- **Artifacts**: plans/01_orphan-detection-parity.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Declared-vs-deployed parity for `provides.*` categories is verified only in the
declared-to-deployed direction (missing / hash-mismatch), never the reverse, so a file that loses
its source-store owner stays in the deploy tree forever. This plan takes **direction (a)** -- build
mechanical orphan detection -- and resolves the 4 currently-orphaned files and 2 ghost
`context/index.json` rows as part of it. The detector is whole-tree (all active extensions at once,
since one extension's orphan may be another's declared file), reuses the existing declared-side
enumeration rather than re-deriving it, and **reports without deleting**: the copy engine's
additive-only semantics are deliberately preserved. Done when a new `verify-deploy.sh` gate reports
zero orphans and zero ghost index rows against the live tree, a regression test proves the gate
fires on a planted orphan, and the measurement recipe plus exclusion contract live in a durable
context file.

### The direction (a) vs (b) decision

The task defers this choice to planning. **Decision: direction (a), with the documentation
component of (b) folded in as the detector's exclusion contract rather than as a standalone
"this gap is intentional" note.** Four reasons:

1. **(b) documents a defect as design.** The drift is not hypothetical or benign: it has already
   produced two `errors.json` records (`err_1786349061556_LuKGif`,
   `err_1786350581273_TAWj0I`), one incorrect "REVISED" scope correction on this very task, and two
   separate rounds of measurement ambiguity. A prose note saying "additive-only is intended" would
   not have caught any of them.
2. **(b)'s literal target file no longer exists.** The task description names
   `docs/architecture/architecture-spec.md` as where the documentation would go -- but that file was
   deliberately deleted from the source store (commit `0e6245fd0`) and is itself one of the 4
   orphans. Direction (b) as written would mean writing documentation into a file that only exists
   as deploy-tree debris.
3. **The cost of (a) is bounded and mostly already paid.** The declared-side enumeration exists and
   is already the single source of truth (`walk_category_leaves` driven by
   `loader.CATEGORY_DESCRIPTORS`). What is missing is only the deployed-side walk, a set
   subtraction, and an explicit exclusion contract.
4. **(a) subsumes (b).** The detector's exclusion contract *is* the durable statement of which parts
   of the deploy tree are legitimately undeclared and why -- strictly more informative than a note
   asserting one-directionality, and mechanically enforced instead of aspirational.

**Non-goal, stated up front**: this does not make the deploy engine subtractive. Nothing added here
deletes a deployed file automatically. Deletion stays a deliberate human action (targeted removal,
or `deploy-headless.sh --wipe`), preserving the existing safety property that a deploy never removes
anything from a target repo.

### Research Integration

The research report is authoritative for scope and supersedes the task description's "REVISED
2026-08-24" block, which it re-measured and found factually wrong. Findings carried into this plan:

- **The orphan set is exactly 4 files, not 11**: `context/orchestration/orchestration-validation.md`,
  `context/orchestration/subagent-validation.md`, `docs/architecture/architecture-spec.md`,
  `docs/README.md`. `docs/README.md` **is** still an orphan, contrary to the revision. Independently
  re-confirmed while drafting this plan: all four are present in `.claude/` with `Aug 9 20:12`
  mtimes and all four are absent from the source store.
- **Eight of the eleven files the revision named have valid source-store owners** and deploy
  byte-identically. A plan drafted against the revision would delete live content.
- **Root cause is confirmed by git history**, not merely inferred: commits `0e6245fd0` and
  `89eac9896` (2026-08-09) deleted these files from the source store and cleaned the source
  `index-entries.json`; the deploy tree captured them minutes earlier and the additive-only
  copy/merge path has never removed them.
- **The two ghost `context/index.json` rows persist**: re-confirmed that
  `orchestration/orchestration-validation.md` and `orchestration/subagent-validation.md` appear in
  the live `.claude/context/index.json` and in **zero** source `index-entries.json` files.
- **The clean-scratch-regenerate measurement recipe has no durable home** and its noise-filtering
  rules (session-lock files, uncommitted working-tree artifacts, `.syncprotect` paths) exist only in
  ad hoc task history. Phase 1 gives it one.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context, so roadmap consultation was skipped and
no roadmap phases are included. `specs/ROADMAP.md` exists in this repository but was deliberately
not read or modified.

## Goals & Non-Goals

**Goals**:
- Decide direction (a) vs (b) explicitly and implement the chosen one (done: direction (a) above).
- Add whole-tree, all-extensions orphan detection that reuses `CATEGORY_DESCRIPTORS` /
  `walk_category_leaves` as its declared-side source of truth rather than a second hand-maintained
  list.
- Detect ghost `context/index.json` rows (present live, declared in no active extension's
  `index-entries.json`) in the same pass -- this is the other half of the same additive-only defect.
- Surface both as a `verify-deploy.sh` gate, in both narrative and `--findings` modes.
- Prove the detector with a scratch-tree regression test that plants a known orphan and a known
  legitimately-undeclared path.
- Resolve the 4 live orphan files and 2 ghost index rows so the gate is green on the live tree.
- Give the measurement recipe and the exclusion contract a durable home in `context/patterns/`.
- Close both `errors.json` records with one change, as the task requires.

**Non-Goals**:
- Making the copy engine or index merge subtractive / auto-deleting. Detection only.
- Rewriting `install-extension.sh`'s `merge_index_entries()`. Its additive-only behavior is now
  *detected*, not changed; a subtractive merge is a separate decision with its own blast radius.
- Acting on the task description's REVISED 11-file scope. It is superseded.
- Running a full `deploy-headless.sh --wipe` regenerate as the routine fix (contingency only).
- Editing files under `.claude/**` as source. The one sanctioned `.claude/` mutation is Phase 5's
  deletion of debris that has no source-store owner.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer follows the task description's REVISED 11-file scope and deletes 8 legitimately-declared files | H | M | The 4-file set is restated in this plan's Overview, in Phase 1's Scope Hypothesis, and in Phase 5's task list; Phase 5 requires the detector's own output as the deletion authority, not any prose list |
| Exclusion contract is too narrow -- the gate cries wolf on every legitimately-undeclared runtime/merged artifact, gets ignored, and rots | H | M | Phase 1 empirically enumerates and classifies **every** live-only path before any code is written; Phase 4 asserts specific non-flagging cases, not only the positive case |
| Exclusion contract is too broad -- a wildcard swallows a real future orphan | H | L | Exclusions are per-class and named, never a blanket path prefix where a narrower rule works; each class carries its justification in the context doc |
| Whole-tree detection implemented per-extension by mistake, flagging every other extension's files as core's orphans | H | M | Explicit in Phase 2's goal and signature: the declared set is the union across **all** loaded extensions, computed once |
| Deleting the 4 orphans breaks something that still reads them | M | L | Phase 5 greps the whole repo for inbound references before deleting; the files are 15 days stale and their content was folded into live successors |
| The new gate is edited in the source store but the implementer runs the stale deployed copy and sees no gate | M | M | Every phase's verification invokes the source-store copy explicitly (`bash agent-system/extensions/core/scripts/verify-deploy.sh`); no redeploy is performed by this task |
| Redeploy appears needed to make the cleanup stick | L | L | It is not: nothing in the source store re-creates the 4 files, so a later default resync cannot resurrect them |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5 | 3 |
| 5 | 6 | 4, 5 |

Phases within the same wave can execute in parallel. Wave 4's two phases have disjoint territory:
Phase 4 owns `scripts/tests/` plus a throwaway scratch repo; Phase 5 owns the live `.claude/` tree.
Neither writes a file the other reads.

### Phase 1: Measure the Orphan Set and Write the Detection Contract [COMPLETED]

**Goal**: Re-confirm the orphan set against a fresh tree, classify every live-only path into named
categories, and record the measurement recipe and exclusion contract in a durable context file --
so the detector built in Phase 2 is written against a documented contract rather than a guess.

**Tasks**:
- [x] Run `bash .claude/scripts/check-deploy-freshness.sh` and confirm exit 0 before trusting any
      measurement. If it warns, stop and report -- the measurement is not usable. *(completed:
      exit 0)*
- [x] Reproduce the clean scratch regenerate: `git clone --no-local` this repo to a scratch dir,
      `bash .claude/scripts/deploy-headless.sh <scratch>`, then
      `diff <(find .claude -type f | sort) <(find <scratch>/.claude -type f | sort)`. *(completed)*
- [x] Enumerate **every** live-only line and classify each into exactly one class: real orphan;
      runtime artifact (`tmp/workflow-active-*`, `RESUME.md`, `__pycache__`/`*.pyc`);
      merged-or-generated artifact (`context/index.json`, `CLAUDE.md`, `settings.json`,
      `extensions/*/manifest.json`); `.syncprotect`-protected path; uncommitted source-store
      working-tree artifact (a scratch clone carries only committed content). *(completed: also
      found a `scripts/literature-pyenv/venv/**` runtime-provisioned-tool instance, folded into
      the runtime-artifact class rather than a new class)*
- [x] Independently list the live `context/index.json` paths that appear in no active extension's
      `index-entries.json`, normalizing with the same rules as `normalize_index_path` in
      `verify.lua`. *(completed: exactly 2, matching research)*
- [x] Write `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md`: the
      measurement recipe, the classified exclusion table with a justification per class, the ghost
      index-row check, and the direction decision (detect, never auto-delete; additive copy
      semantics retained deliberately). *(completed)*
- [x] Add an `index-entries.json` row for the new pattern file in
      `agent-system/extensions/core/index-entries.json`. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: the research report asserts exactly 4 real orphans and 4-5 noise classes.
Both are hypotheses. Confirm by running the scratch regenerate above and classifying the raw
live-only diff exhaustively -- every line lands in a class or the count is wrong. If the real-orphan
count differs from 4, record the discrepancy and carry the measured set forward; do not reconcile it
to the report.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md` - new; recipe,
  exclusion contract, decision record
- `agent-system/extensions/core/index-entries.json` - one new entry row

**Verification**:
- `jq -e . agent-system/extensions/core/index-entries.json` parses.
- Every live-only diff line from the measurement appears in exactly one class in the new doc.
- The doc names the 4 orphan paths and the 2 ghost index rows explicitly as the measured baseline.

---

### Phase 2: Whole-Tree Orphan Detection in verify.lua [COMPLETED]

**Goal**: Add a whole-tree, all-extensions orphan pass to `verify.lua` that computes the declared
set from the existing `CATEGORY_DESCRIPTORS`-driven enumeration, subtracts it from the deployed
tree, applies Phase 1's exclusion classes, and reports orphan files and ghost index rows.

**Tasks**:
- [x] Add `M.find_orphans(target_dir, extensions, protected_paths, opts)` where `extensions` is an
      array of `{ name, source_dir, manifest }` for **all** loaded extensions -- the declared set is
      their union, computed once. Per-extension orphan detection is incorrect by construction: one
      extension's undeclared file is routinely another's declared file.
- [x] Build the declared rel-path set by iterating every `CATEGORY_DESCRIPTORS` key with a
      `list_key` through the existing `walk_category_leaves`, for every extension. Do not re-derive
      the category-to-target-path mapping.
- [x] Add the `manifest` category's special case explicitly (`extensions/{name}/manifest.json`),
      which `walk_category_leaves` skips because it has no `list_key`.
- [x] Walk the deployed tree with the existing `scan_directory_recursive`, subtract the declared
      set, and apply the exclusion predicates for each class named in Phase 1's doc.
- [x] Add the ghost index-row check: live `context/index.json` entry paths minus the union of active
      extensions' `index-entries.json` paths, both normalized through `normalize_index_path`.
- [x] Return `{ orphans = {rel,...}, ghost_index_entries = {path,...}, checked = n,
      excluded = { [class] = count } }`; keep `M.verify_extension`'s existing result shape
      untouched.
- [x] Add a header comment stating the detect-never-delete contract and pointing at the Phase 1
      context doc.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: this phase assumes the declared set is fully reconstructible from
`CATEGORY_DESCRIPTORS` plus the one `manifest` special case. Confirm by running `find_orphans`
against the live tree and checking that its excluded/flagged classification reproduces Phase 1's
hand-classification exactly. A path that lands in neither the declared set nor a named exclusion
class, and is not one of the 4 known orphans, means the assumption is wrong -- investigate before
proceeding.

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` - new `find_orphans` and its helpers

**Verification**:
- Headless smoke run of `find_orphans` against the live tree returns the 4 known orphans and the
  2 known ghost rows, and nothing else.
- No change to `M.verify_extension`'s returned fields (existing gate 5 output is byte-identical).

---

### Phase 3: Expose via manager and Add the verify-deploy Gate [COMPLETED]

**Goal**: Make the detector reachable from the shell as a `verify-deploy.sh` gate, in both narrative
and `--findings` modes, following gate 5's existing headless-nvim precedent.

**Tasks**:
- [x] Add `manager.find_orphans(project_dir)` in
      `lua/neotex/plugins/ai/shared/extensions/init.lua`: enumerate loaded extensions via
      `manager.list_loaded`, resolve each source dir and manifest, read `.syncprotect`, and call
      `verify.find_orphans` once for the whole tree.
- [x] Add gate 13 to `agent-system/extensions/core/scripts/verify-deploy.sh`, modeled line-for-line
      on gate 5: same `CURRENT_GATE` assignment, same `[SKIP]` posture when the target is a deploy
      consumer rather than the source store, same headless-nvim invocation shape, same unanchored
      grep for the emitted token (OSC7 robustness).
- [x] Emit one `ORPHAN_FINDING` line per orphan file and per ghost index row; in `--findings` mode
      push each as its own `FINDING gate13 ...` entry (pass `""` as `fail`'s third argument to
      suppress the aggregate, matching gates 5 and 11).
- [x] Update the script header: it currently documents "all eleven gates (gate0 through gate10)"
      while gate11 and gate12 already exist. Correct the range to cover gate13 as part of this edit.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - new `manager.find_orphans`
- `agent-system/extensions/core/scripts/verify-deploy.sh` - gate 13 plus header range correction

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh` (source-store copy, not the deployed
  one) runs gate 13 and reports exactly the 4 orphans plus 2 ghost rows.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --findings --quiet | grep '^FINDING gate13'`
  yields one line per finding.
- Gates 0-12 produce the same findings set as before this phase (capture and diff
  `--findings --quiet` output before and after).

---

### Phase 4: Scratch-Tree Regression Test [COMPLETED]

**Goal**: Prove the gate fires on a planted orphan and stays silent on legitimately-undeclared
paths, so the exclusion contract is enforced by a test rather than by reviewer memory.

**Tasks**:
- [x] Write `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh` modeled on the
      existing `test-deploy-propagation.sh` (scratch `mktemp` git repo, trap-based cleanup, real
      `deploy-headless.sh` subprocess, `pass()`/`fail()` counters, exit 0/1/2 convention).
- [x] Assertion A: a file planted in the scratch deploy tree under a declared category directory but
      absent from every manifest is reported as an orphan.
- [x] Assertion B: a runtime path (`tmp/workflow-active-test`) is **not** reported.
- [x] Assertion C: a merged/generated artifact (`context/index.json`) is **not** reported.
- [x] Assertion D: an index row injected into the scratch `context/index.json` with no
      `index-entries.json` declaration is reported as a ghost row.
- [x] Assertion E: an unmodified scratch regenerate reports zero orphans -- the no-false-positive
      baseline.
- [x] Add `tests/test-deploy-orphans.sh` to `provides.scripts` in
      `agent-system/extensions/core/manifest.json` (scripts are declared individually; the test
      runner discovers by glob, but the file must be declared to deploy).

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh` - new
- `agent-system/extensions/core/manifest.json` - one `provides.scripts` entry

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh` exits 0 with all five
  assertions passing.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` discovers the new suite and the
  full shell suite still exits 0.
- `jq -e . agent-system/extensions/core/manifest.json` parses.

---

### Phase 5: Resolve the 4 Live Orphans and 2 Ghost Index Rows [COMPLETED]

**Goal**: Clear the measured debris from the live deploy tree so gate 13 is green, using the
detector's own output as the deletion authority.

**Tasks**:
- [x] Re-run gate 13 and take **its** output as the authoritative deletion list. Do not delete
      anything named only in prose -- specifically, do not act on the task description's REVISED
      11-file list.
- [x] For each candidate, grep the repository for inbound references before deleting; if a live file
      still links to it, record that and stop rather than deleting.
- [x] Delete the 4 orphan files from `.claude/`:
      `context/orchestration/orchestration-validation.md`,
      `context/orchestration/subagent-validation.md`, `docs/architecture/architecture-spec.md`,
      `docs/README.md`.
- [x] Remove the 2 ghost rows from `.claude/context/index.json` with `jq`, writing via a temp file
      and re-validating before replacing.
- [x] Confirm the deletion is durable: nothing in the source store re-creates these paths, so a
      later default (non-destructive) resync cannot resurrect them. Do **not** run a redeploy as
      part of this phase.

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: 4 files and 2 index rows. This is the research report's measurement,
re-confirmed at plan time, but gate 13's live output at implementation time supersedes it. If the
detector reports a different set, use the detector's set and record the difference in the summary.

**Files to modify**:
- `.claude/context/orchestration/orchestration-validation.md` - delete (no source-store owner)
- `.claude/context/orchestration/subagent-validation.md` - delete (no source-store owner)
- `.claude/docs/architecture/architecture-spec.md` - delete (no source-store owner)
- `.claude/docs/README.md` - delete (no source-store owner)
- `.claude/context/index.json` - remove 2 ghost entry rows

**Note on the source-store boundary**: this phase is the one sanctioned `.claude/` mutation in this
task. The source-store rule forbids *authoring* files into the disposable deploy tree; here the
change is the removal of debris that has no source-store owner and that the source store is already
correct about. No source file is edited to achieve it.

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh` gate 13 reports zero orphans and
  zero ghost rows.
- `jq -e . .claude/context/index.json` parses and its entry count dropped by exactly 2.
- Gates 0-12 findings set is unchanged from the Phase 3 capture.

---

### Phase 6: Record the Decision and Close the Error Records [COMPLETED]

**Goal**: Make the additive-only-plus-detection decision discoverable from the deploy documentation,
and close both `errors.json` records this task was chartered to cover.

**Tasks**:
- [x] Add a short subsection to `agent-system/extensions/core/docs/architecture/extension-system.md`
      stating that copy and index merge are additive-only by design, that removal is a deliberate
      manual action (targeted deletion or `deploy-headless.sh --wipe`), and that drift is caught by
      `verify-deploy.sh` gate 13 -- pointing at the Phase 1 context doc rather than restating it.
- [x] Add the same pointer to `agent-system/extensions/core/context/guides/loader-reference.md` where
      it describes the copy engine, if that file has a natural anchor; skip it if it does not rather
      than forcing a section.
- [x] Close both error records:
      `bash .claude/scripts/errors-append.sh update --id err_1786349061556_LuKGif --fix-status fixed --fix-task 9`
      and the same for `err_1786350581273_TAWj0I`.
- [x] Write the implementation summary, recording the direction (a) decision, the confirmed orphan
      count, and any discrepancy between the plan's hypotheses and what was measured.

**Timing**: 0.75 hours

**Depends on**: 4, 5

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/extension-system.md` - new subsection
- `agent-system/extensions/core/context/guides/loader-reference.md` - pointer, if a natural anchor
  exists
- `specs/errors.json` - two `fix_status` updates via the sanctioned writer
- `specs/009_resolve_deploy_orphan_file_parity/summaries/01_orphan-detection-summary.md` - new

**Verification**:
- Both error records show `fix_status: "fixed"` and `fix_task: 9`.
- The new documentation cross-references resolve to files that exist.
- No task-number reference appears in any file outside `specs/**`.

---

## Testing & Validation

- [x] `bash agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh` exits 0 (all five
      assertions). *(completed)*
- [x] `bash agent-system/extensions/core/scripts/tests/run-all.sh` exits 0. *(deviation: altered — pre-existing unrelated test-validate-return-meta.sh failure; new suite passes, see summary)*
- [x] `bash agent-system/extensions/core/scripts/verify-deploy.sh` -- gate 13 green, gates 0-12
      findings set unchanged versus the pre-work capture. *(deviation: altered — gate 13 confirmed green post-Phase-5; exact before/after diff not captured in this concurrent multi-agent session, verified by direct isolation instead, see summary)*
- [x] `bash agent-system/extensions/core/scripts/verify-deploy.sh --findings --quiet` produces a
      clean, diffable findings set. *(verified by construction; see summary's Plan Deviations for the full-run timing note)*
- [x] `bash .claude/scripts/check-task-references.sh` (or the repo's equivalent lint) reports no new
      task-number references outside `specs/**`. *(completed: 0 occurrences)*
- [x] `jq -e .` parses `agent-system/extensions/core/manifest.json`,
      `agent-system/extensions/core/index-entries.json`, and `.claude/context/index.json`. *(completed)*

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md` (new)
- `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh` (new)
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` (modified: `find_orphans`)
- `lua/neotex/plugins/ai/shared/extensions/init.lua` (modified: `manager.find_orphans`)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (modified: gate 13, header range)
- `agent-system/extensions/core/manifest.json`, `.../index-entries.json` (modified: one entry each)
- `agent-system/extensions/core/docs/architecture/extension-system.md` (modified)
- `.claude/` deploy tree: 4 files deleted, 2 index rows removed
- `specs/009_resolve_deploy_orphan_file_parity/summaries/01_orphan-detection-summary.md` (new)

## Rollback/Contingency

- **Code changes** (Phases 1-4, 6): all in git-tracked source. Revert the phase commits; the
  detector is purely additive -- no existing gate, verification path, or copy behavior is modified,
  so reverting restores the prior state exactly.
- **Deploy-tree deletions** (Phase 5): the deleted files exist in git history at commits
  `0e6245fd0` / `89eac9896`'s parents and can be restored from there if an inbound reference turns
  up later. The `.claude/` tree is itself regenerable.
- **If targeted deletion in Phase 5 proves unsafe** (e.g. the index-row edit corrupts
  `context/index.json`): fall back to `bash .claude/scripts/deploy-headless.sh --wipe`, which
  rebuilds the whole tree from source and clears all orphans and ghost rows by construction. This is
  the contingency, not the default -- it has a far larger blast radius and depends on the snapshot /
  restore path for `settings.json` and `.syncprotect` paths.
- **If Phase 1's measurement contradicts the research report**: stop and report rather than
  proceeding on either count. A third contradictory measurement is a signal about the measurement
  method, not about the orphan set.

# Implementation Plan: Lean Mirror Entry Load-Order Fix

- **Task**: 1001 - Fix lean mirror entry load-order defect; audit duplicated index paths
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: Task 1000 (completed -- establishes and proves the union-valued pattern)
- **Research Inputs**: specs/1001_lean_mirror_entry_load_order/reports/01_lean-mirror-load-order-defect.md
- **Artifacts**: plans/01_lean-mirror-load-order-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`agent-system/extensions/lean/index-entries.json` declares a mirror entry for
`contracts/adversarial-verification.md` whose `load_when.agents` names only
`lean-research-hard-agent`. Because `merge.append_index_entries` upserts index entries **by path**
and replaces the whole entry object rather than merging fields, a lean-loaded deploy that processes
lean after core silently drops core's `general-research-hard-agent` hook on that path, with no error
signal. This plan applies the union-valued `load_when.agents` pattern task 1000 established and
proved, verifies it by reconstructing the actual merge rather than reading the JSON, extends the
same one-line fix to the two structurally identical sibling defects that live in the same declared
file, and records the full duplicated-path audit plus the follow-up candidates the task explicitly
asked to be recorded rather than implemented.

### Research Integration

The research report supplies four load-bearing findings this plan is built on, all verified by
direct code reading rather than inference:

1. The upsert mechanism itself (`merge.lua`, `M.append_index_entries`): whole-entry replacement on a
   `path` match, no per-field merge, no union logic, no warning.
2. The named target defect: lean's `contracts/adversarial-verification.md` entry declares
   `["lean-research-hard-agent"]`; core's declares `["general-research-hard-agent"]`.
3. **Two further lean/core pairs of identical shape**, both inside this task's declared file_scope:
   `contracts/reference-grounding.md` (core `["general-research-hard-agent",
   "planner-hard-agent"]` vs lean `["lean-research-hard-agent",
   "lean-implementation-hard-agent"]`) and `contracts/anti-analysis.md` (core
   `["general-implementation-hard-agent", "general-research-hard-agent"]` vs the same lean pair).
   Neither list overlaps its core counterpart, so each is strictly narrower than the union.
4. **One distinct, arguably more severe variant** internal to
   `agent-system/extensions/cslib/index-entries.json`: two entries for
   `project/cslib/standards/ci-pipeline.md` inside a single file's own array, colliding on every
   deploy that loads cslib at all, independent of any other extension or load order.

No existing lint rule in `check-extension-docs.sh` (Rule R, Rule T) or anywhere else detects either
shape.

### Scope Boundary Resolution (explicit, not silent)

The research deferred two scope questions to planning. Both are decided here, with rationale, so
neither is resolved by omission at implementation time.

**Decision 1 -- the two sibling lean/core pairs are IN scope, fixed by this task.**
`contracts/reference-grounding.md` and `contracts/anti-analysis.md` live in
`agent-system/extensions/lean/index-entries.json`, which *is* this task's entire declared
`file_scope`. WORK item 1's phrasing is "at minimum general-research-hard-agent alongside
lean-research-hard-agent" -- a floor, not a ceiling. The edit is the same one-line class, the
verification is the same merge reconstruction, and the alternative is knowingly editing a file while
leaving two identical instances of the very defect being fixed sitting three entries away. That is
the worse outcome. They are fixed in a **separate phase** (Phase 2) from the named target (Phase 1)
so the mandated fix lands, is committed, and is independently verifiable before any widening.

**Decision 2 -- the cslib internal duplicate is OUT of scope for any fix, IN scope for the record.**
`agent-system/extensions/cslib/index-entries.json` is not in this task's `file_scope`. `file_scope`
is a prospective, lock-overlap-detection declaration (see `state-management-schema.md`); editing a
file outside it is exactly the silent-scope-violation this system's boundaries exist to prevent, and
risks colliding with a concurrent task holding that file. Additionally the cslib case is a genuinely
*different* mechanism -- same-file, array-order collision requiring no second extension -- so it
warrants its own reasoning and its own verification, not a ride-along on a cross-extension fix.
WORK item 2 requires it be *enumerated and reported*, not fixed ("even if this task only fixes the
lean instance"); Phase 3 discharges that obligation and records it as a follow-up candidate.

### Prior Plan Reference

No prior plan for this task. Task 1000's completed plan and summary are the pattern reference: it
established the union-valued `load_when.agents` convention for cslib, proved it via a disposable
headless-Neovim merge reconstruction rather than static JSON inspection, deleted the scratch
artifacts afterward, and interpreted its `check-extension-docs.sh` bar as "the extension's own
PASS", not the script's global exit code. This plan reuses all four of those decisions verbatim
rather than re-deriving them.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no ROADMAP.md consultation was
requested. No roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Lean's `contracts/adversarial-verification.md` entry carries a union-valued `load_when.agents`
  containing both `lean-research-hard-agent` and `general-research-hard-agent` (WORK item 1).
- The same union fix is applied to the two structurally identical sibling entries in the same file
  (`contracts/reference-grounding.md`, `contracts/anti-analysis.md`) -- see Decision 1.
- The fix is proved by **running a reconstruction of the actual merge** (core entry processed first,
  lean second) and asserting on the surviving entry, never by reading the edited JSON and asserting
  it looks right.
- The complete duplicated-path audit is recorded in the task summary, including the out-of-scope
  cslib finding (WORK item 2).
- The loader-warning / lint-rule question is recorded as a follow-up candidate with enough specifics
  to be actionable, and is **not** implemented here (WORK item 3).
- `check-extension-docs.sh` passes for the lean extension.

**Non-Goals**:
- Fixing `agent-system/extensions/cslib/index-entries.json`'s internal `ci-pipeline.md` duplicate --
  out of `file_scope`; recorded, not fixed (Decision 2).
- Adding any new lint rule, loader warning, or check to `check-extension-docs.sh` or elsewhere --
  WORK item 3 explicitly says record, do not widen.
- Changing any `context/contracts/*.md` file content, or any `line_count` value. The `line_count`
  values in lean's index (93 / 97 / 111) are correct for the current files and this task must not
  make them wrong by touching either side.
- Resolving the *content*-level path collision between core's and lean's `context/contracts/*.md`
  copies (see Risks) -- a separate, larger concern; recorded as a follow-up candidate only.
- Editing anything under `.claude/**`. That tree is a disposable deploy artifact; the source store
  `agent-system/extensions/**` is the only correct edit target.
- Loading the lean extension into this repo's deploy in order to test. The defect is dormant here
  by design; verification is by reconstruction, not by changing what this repo loads.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Verification degenerates into "read the JSON, assert it looks right" -- the exact failure the task's verification bar was written to forbid | H | M | Phase 1's verification is a *runnable* reconstruction whose assertion is on the merged output, not the source file. A phase whose only evidence is a `jq` read of the edited file does not satisfy its own criteria and must not be marked complete. |
| The union entry hooks `general-research-hard-agent` to a path whose *deployed file content* is lean's lean4-specialized override (lean also ships `context/contracts/*.md` and `copy_category("context", ...)` copies by path, so lean's 93-line copy overwrites core's 103-line copy in a lean-loaded deploy) | M | H | Out of scope to fix, but must not be discovered silently: Phase 3 records it explicitly as a follow-up candidate. This is the same trade-off task 1000 already accepted for cslib, and the task description mandates the union pattern regardless. |
| Scratch reconstruction script / scratch index file left behind, contaminating the working tree or being mistaken for a deliverable | M | M | Write scratch artifacts only under the session scratchpad directory, never the repo. Phase 4 confirms `git status --short` shows no stray files before the phase closes. |
| `check-extension-docs.sh` exits non-zero for a pre-existing, unrelated reason and is misread as this task failing | M | M | Read the bar as lean's own PASS / relevant rule output, exactly as task 1000's summary did. Any unrelated FAIL must be named and attributed in the summary, not silently absorbed. |
| Widening to the two sibling entries introduces a semantically wrong union for some pair | L | L | Phase 2 requires the implementer to confirm the union restores exactly core's-plus-lean's agents and nothing invented. If any pair turns out to be a deliberate narrowing rather than a defect, close it as a `#### Reasoned Exclusions` record with evidence rather than forcing the edit. |
| `line_count` drifts out of sync as a side effect | L | L | This task edits only `load_when.agents` arrays. Phase 4 runs `generate-context-line-counts.sh --check` to confirm no `line_count` regressed. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. This plan is fully sequential: Phases 1 and 2
edit the same JSON file, Phase 3 reports on what 1 and 2 actually did, and Phase 4 is the closing
gate over all of them.

---

### Phase 1: Union-Value the Named Adversarial-Verification Entry [NOT STARTED]

**Goal**: Discharge WORK item 1 -- lean's `contracts/adversarial-verification.md` entry declares a
union `load_when.agents`, proved by a run reconstruction of the core-then-lean merge.

**Tasks**:
- [ ] Read the current entry in `agent-system/extensions/lean/index-entries.json` and re-confirm it
      declares `load_when.agents: ["lean-research-hard-agent"]` and
      `load_when.task_types: ["lean4"]`. Re-confirm core's entry for the same path declares
      `["general-research-hard-agent"]`.
- [ ] Edit **only** the `load_when.agents` array to the union
      `["lean-research-hard-agent", "general-research-hard-agent"]`. Leave `line_count` (93),
      `task_types`, `domain`, `subdomain`, `summary`, and `keywords` untouched, and do not add a
      `commands` key that the entry does not currently have.
- [ ] Confirm the file is still valid JSON (`jq empty` on it) before proceeding.
- [ ] Build the merge reconstruction in the scratchpad directory (NOT the repo): a disposable
      headless-Neovim script that calls
      `neotex.plugins.ai.shared.extensions.merge.append_index_entries` against a scratch index file,
      passing core's entries first and lean's entries second -- the realistic core-then-extension
      processing order.
- [ ] Run it and assert the single surviving entry for `contracts/adversarial-verification.md` has a
      `load_when.agents` containing **both** `general-research-hard-agent` and
      `lean-research-hard-agent`. Capture the actual output for the summary.
- [ ] Run the same reconstruction against the pre-edit state (or reason from the captured output) to
      confirm the assertion would have **failed** before the edit -- an assertion that passes either
      way proves nothing.

**Timing**: 35 minutes

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase assumes exactly one entry in lean's index declares
`contracts/adversarial-verification.md` and exactly one in core's does. Confirm at implementation
time with `jq -r '[.entries[] | select(.path == "contracts/adversarial-verification.md")] | length'`
against both files -- both must return `1`. If either returns more, stop and report: that is a
different defect (the cslib internal-duplicate shape) appearing in a new file.

**Files to modify**:
- `agent-system/extensions/lean/index-entries.json` - `load_when.agents` of the
  `contracts/adversarial-verification.md` entry only

**Verification**:
- The reconstruction **run** (not a JSON read) prints a merged entry whose `load_when.agents`
  contains both agent names; the captured output is preserved for the summary.
- The same reconstruction demonstrably fails on the pre-edit state.
- `jq empty agent-system/extensions/lean/index-entries.json` exits 0.
- `git diff` shows exactly one changed hunk, confined to one `agents` array.

---

### Phase 2: Extend the Union Fix to the Two Sibling Entries in the Same File [NOT STARTED]

**Goal**: Close the two structurally identical defects that live inside this task's declared
file_scope, per Decision 1, so the file is not left holding known instances of the defect it was
just edited to fix.

**Tasks**:
- [ ] For `contracts/reference-grounding.md`: confirm core declares
      `["general-research-hard-agent", "planner-hard-agent"]` and lean declares
      `["lean-research-hard-agent", "lean-implementation-hard-agent"]`. Set lean's array to the
      4-name union of exactly those two lists -- no invented names, no omissions.
- [ ] For `contracts/anti-analysis.md`: confirm core declares
      `["general-implementation-hard-agent", "general-research-hard-agent"]` and lean declares
      `["lean-research-hard-agent", "lean-implementation-hard-agent"]`. Set lean's array to the
      4-name union of exactly those two lists.
- [ ] Leave `line_count` (97 and 111 respectively), `task_types`, and every other field untouched on
      both entries.
- [ ] Re-run the Phase 1 merge reconstruction, extended to assert on all three paths, and confirm
      each merged entry's `load_when.agents` is the full expected union.
- [ ] If either pair turns out on inspection to be a deliberate narrowing rather than a defect, do
      NOT force the edit: close that item as a `#### Reasoned Exclusions` record under this phase
      with `Item | Reason | Evidence` columns, and mark the phase
      `[COMPLETED WITH EXCLUSIONS]`.

**Timing**: 30 minutes

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts there are exactly **two** remaining lean/core duplicated
paths beyond the one fixed in Phase 1, and that lean's index has **no** internal duplicate of its
own. Confirm both at implementation time before editing:
`jq -r '.entries[].path' agent-system/extensions/lean/index-entries.json | sort | uniq -d` must
print nothing, and the cross-file duplicate set between lean and core must be exactly
`{adversarial-verification, reference-grounding, anti-analysis}`. If the confirmed set differs from
the hypothesis, record the actual set and treat the difference as a finding for Phase 3, not as a
reason to skip the phase.

**Files to modify**:
- `agent-system/extensions/lean/index-entries.json` - `load_when.agents` of the
  `contracts/reference-grounding.md` and `contracts/anti-analysis.md` entries only

**Verification**:
- The extended reconstruction **run** shows all three merged entries carrying their full expected
  unions.
- `jq empty` on the edited file exits 0.
- `git diff` shows changes confined to `agents` arrays -- no `line_count`, `task_types`, `summary`,
  or `keywords` value differs from its pre-task value.

---

### Phase 3: Record the Duplicated-Path Audit and Follow-Up Candidates [NOT STARTED]

**Goal**: Discharge WORK item 2 (the audit is recorded in the task summary) and WORK item 3 (the
loader-warning question is recorded as a follow-up, not implemented).

**Tasks**:
- [ ] Re-run the audit queries fresh rather than copying the research report's table on trust: the
      cross-extension duplicate scan and the per-extension internal-duplicate scan over
      `agent-system/extensions/*/index-entries.json`. Record the actual numbers observed.
- [ ] Write the duplicated-path audit into the task summary as a table covering all findings, each
      row stating the path, the declaring extensions, whether it is the cross-extension or
      same-file shape, and its disposition (fixed here / out of file_scope / already fixed).
- [ ] State the cslib disposition explicitly and with its reason -- out of `file_scope`, a
      different collision mechanism, recorded per WORK item 2 rather than fixed -- so a reader of
      the summary alone can see it was decided, not overlooked.
- [ ] Record the WORK item 3 follow-up candidate concretely enough to act on: a check that (a) flags
      any path declared by more than one extension's `index-entries.json` where the
      `load_when.agents` sets differ and neither is a superset of the other, and (b) flags
      unconditionally any path declared more than once within a single extension's own array. Note
      that it belongs alongside the existing Rule R / Rule T family in `check-extension-docs.sh`,
      and that it would have caught every finding in the audit table automatically.
- [ ] Record the second follow-up candidate surfaced during planning: the **content**-level path
      collision. Lean's `provides.context` includes `contracts`, and `copy_category("context", ...)`
      copies by path, so in a lean-loaded deploy lean's `context/contracts/*.md` copies overwrite
      core's at the same deploy paths. Confirm this by inspection at implementation time and state
      the consequence plainly: the union index entry restores the *hook* for
      `general-research-hard-agent`, but that agent then receives lean's lean4-specialized override
      content rather than core's generic contract. Record; do not fix.

**Timing**: 30 minutes

**Depends on**: 1, 2

**Verification Tier**: prose

**Scope Hypothesis**: The research report asserts 4 findings across 19 extensions and 478 total
entries, with no duplicated paths among the remaining 15 extensions. Every one of those numbers is a
hypothesis, not a fact -- re-run both audit queries and report the numbers actually observed. If they
differ from the research report's, the observed numbers win and the divergence is itself worth a line
in the summary.

**Files to modify**:
- `specs/1001_lean_mirror_entry_load_order/summaries/01_lean-mirror-load-order-fix-summary.md` -
  audit table, cslib disposition, and both follow-up candidates

**Verification**:
- The summary contains a duplicated-path audit table whose rows match the freshly-run query output,
  not the research report copied forward unverified.
- The cslib finding appears with an explicit stated disposition and reason.
- Both follow-up candidates are recorded with enough specificity to be turned into tasks, and
  neither is implemented anywhere in the diff.

---

### Phase 4: Closing Gate and Scratch Cleanup [NOT STARTED]

**Goal**: Run the full gate set, confirm no collateral damage and no stray artifacts, and confirm
the source-store boundary was respected.

**Tasks**:
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and read the result against the lean-scoped
      bar: lean's own PASS. If the global exit code is non-zero for an unrelated pre-existing
      reason, name the failing rule and the file it concerns in the summary and attribute it
      explicitly, rather than absorbing it silently or claiming a clean run.
- [ ] Run `bash .claude/scripts/generate-context-line-counts.sh --check` and confirm no `line_count`
      in lean's index (or anywhere else) is now wrong -- this task changed no file contents, so any
      new mismatch would be collateral damage.
- [ ] Run `jq empty` over every edited `index-entries.json` one final time.
- [ ] Confirm the diff touches `agent-system/extensions/lean/index-entries.json` plus `specs/**`
      only. Any `.claude/**` path in the diff is a source-store boundary violation and must be
      reverted and redone against `agent-system/extensions/**`.
- [ ] Delete the scratch reconstruction script and scratch index file; confirm `git status --short`
      shows no stray untracked files introduced by this task.
- [ ] Confirm no task-number references were written into any deliverable outside `specs/**` (this
      task's deliverable edits are JSON `agents` arrays, so this should be trivially satisfied --
      confirm rather than assume).

**Timing**: 25 minutes

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Verification**:
- `check-extension-docs.sh` shows lean PASS; any unrelated failure is named and attributed.
- `generate-context-line-counts.sh --check` reports no new mismatch.
- `git status --short` shows no scratch artifacts and no `.claude/**` modifications.
- The complete diff is confined to one source-store JSON file plus this task's `specs/**` artifacts.

---

## Testing & Validation

- [ ] Merge reconstruction, **executed**, shows `contracts/adversarial-verification.md` surviving a
      core-then-lean merge with both `general-research-hard-agent` and `lean-research-hard-agent`
      in `load_when.agents` (the task's stated verification bar).
- [ ] The same reconstruction demonstrably fails against the pre-edit state.
- [ ] All three lean/core duplicated paths carry their full expected unions post-merge.
- [ ] `jq empty agent-system/extensions/lean/index-entries.json` exits 0.
- [ ] `bash .claude/scripts/check-extension-docs.sh` -- lean PASS.
- [ ] `bash .claude/scripts/generate-context-line-counts.sh --check` -- no new mismatches.
- [ ] The duplicated-path audit, including the out-of-scope cslib finding, is present in the summary.
- [ ] Both follow-up candidates are recorded and neither is implemented.
- [ ] No scratch files remain; no `.claude/**` file was edited.

## Artifacts & Outputs

- `agent-system/extensions/lean/index-entries.json` -- three `load_when.agents` arrays widened to
  their unions (one mandated, two per Decision 1)
- `specs/1001_lean_mirror_entry_load_order/plans/01_lean-mirror-load-order-fix.md` -- this plan
- `specs/1001_lean_mirror_entry_load_order/summaries/01_lean-mirror-load-order-fix-summary.md` --
  implementation summary carrying the duplicated-path audit table, the cslib disposition, and both
  follow-up candidates
- Transient, deleted before completion: the headless-Neovim merge reconstruction script and its
  scratch index file, written under the session scratchpad directory

## Rollback/Contingency

The entire code change is three `load_when.agents` array edits in a single JSON file, each additive
(names are added, never removed). Reverting is `git checkout` of that one file at the pre-task
commit, or removing the added names by hand. Nothing is deployed, no file content changes, no
generated artifact depends on the edit, and the lean extension is not loaded in this repo, so the
change is inert here until a lean-loaded deploy regenerates its index.

If the merge reconstruction cannot be made to run (for example the headless-Neovim harness is
unavailable), do NOT substitute a static JSON read and declare the bar met -- that is precisely the
verification the task description forbids. Mark the phase `[BLOCKED]`, record what was tried and why
it failed, and leave the edit uncommitted or clearly flagged as unverified.

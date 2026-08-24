# Implementation Plan: Task #32

- **Task**: 32 - redeploy_and_remediate_install_once_settings
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: `specs/032_redeploy_and_remediate_install_once_settings/reports/01_redeploy-and-remediate-baseline.md`
- **Artifacts**: plans/01_deploy-remediate-stale-grant.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Deploy the accumulated `agent-system/extensions/**` source store to the `.claude/` tree, then
hand-remove one stale permission grant that the deploy mechanism structurally cannot fix, then
prove the deploy landed without introducing regressions by diffing the post-deploy
`verify-deploy.sh` findings set against the verbatim pre-deploy baseline already captured in the
research report. The definition of done is: deploy ran; the deployed `.claude/settings.json`
carries no `mcp__lean-lsp__*` grant while the source copy remains untouched; the post-deploy
findings set contains **no finding absent from the pre-deploy baseline**; the four previously
completed-but-not-live fixes are recorded in `CHANGE_LOG.md` by durable anchor; and both deferred
decisions are recorded with their reasons.

Constraint that shapes every phase: the pre-deploy baseline **already exists** (research report
Section 4, 52 lines, verbatim). It must not be re-captured — re-capturing it after deploying
would silently erase the very comparison this task exists to make.

### Research Integration

The plan is built on the research report's measurements, not the task description's superseded
figures. Specifically integrated:

- **Drift is 16 files / 12 commits under `agent-system/`**, not "133 commits"; gate5 reports
  **11 findings** (6 drifted scripts + 2 never-deployed scripts + 3 drifted non-script docs).
  Risk of deploying the whole source store is therefore assessed as **low** — all 16 files trace
  to four `[COMPLETED]` task directories, with no in-flight or uncommitted work mixed in.
- **All three premises confirmed by direct inspection**: `mcp-server-ownership.md` is deployed and
  byte-identical; the stale grant sits at `.claude/settings.json:188` and is absent from
  `agent-system/extensions/core/root-files/settings.json`; install-once semantics are real in
  `loader.lua` (`INSTALL_ONCE_ROOT_FILES`, line 134; copy-skip at line 476) and `init.lua`
  (lines 770/776).
- **Pre-existing findings are enumerated** (10 gate3 "Rule R" line-count mismatches, 1 gate3
  "Rule S" index entry, a gate8 cluster of single-source-assertion and fix-roundtrip failures).
  These will still be present post-deploy and are **not** regressions.
- **gate5 coverage gap**: `verify-deploy.sh` gate5 does not compare `manifest.json` content or all
  context-pattern docs, so 3 changed files (core `manifest.json`, literature `manifest.json`,
  `context/project/literature/patterns/shared-module-extraction-for-gate-checks.md`) need a manual
  `diff` — a clean gate5 alone does not prove they deployed.
- **Diff method**: the report specifies `grep '^FINDING ' | sort -u` on both sides, to avoid false
  deltas from narrative-line reordering.
- **`system-defect-record.sh`'s nonzero exit is explained** as documented usage-error behavior on a
  bare invocation, not drift — no phase investigates it.
- **Both deferred decisions confirmed factually** and both recommended DEFER with specific reasons
  (Section 5), which Phase 6 records verbatim in intent.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context. `specs/ROADMAP.md` exists but contains no
item this task advances (its only deploy-adjacent entry concerns manifest-driven README
generation, which is unrelated). No roadmap phases are included and `ROADMAP.md` is not modified.

### Measured Correction to the Delegation Brief (read before Phase 6)

The dispatch brief states "CHANGE_LOG is a deliverable outside `specs/**`". Measured: the file is
at **`specs/CHANGE_LOG.md`**, i.e. inside `specs/**`, where
`.claude/rules/no-task-references-in-deliverables.md` explicitly exempts task numbers — and the
file's own existing entries use `**Task N: name**` headings. The binding constraint is
nevertheless honored in the strictest direction, because durable anchors are what a future reader
actually needs and are permitted under either reading: **Phase 6 writes the entry keyed on durable
anchors (filenames, function names, gate names) and adds no task numbers.** This note exists so the
implementer does not "discover" the discrepancy mid-phase and reverse the decision.

## Goals & Non-Goals

**Goals**:
- Run `bash .claude/scripts/deploy-headless.sh`, making the four completed-but-not-live fixes
  actually live.
- Remove the stale `mcp__lean-lsp__*` grant from the **deployed** `.claude/settings.json`, as the
  single sanctioned exception to the source-store-deploy boundary, with the reasoning recorded.
- Prove, baseline-relatively, that the deploy introduced no new `verify-deploy.sh` finding.
- Confirm concretely that the deployed `skill_orchestrate_mint_dispatch_seq` now matches the source
  persisted-counter form (the defect this orchestration run hit live).
- Cover gate5's blind spot by hand-diffing the 3 files it does not compare.
- Record in `CHANGE_LOG.md`, by durable anchor, which previously-completed work became live.
- Record both deferred decisions with their reasons.

**Non-Goals**:
- Fixing any pre-existing finding in the baseline (gate3 Rule R line-count mismatches, gate3 Rule S
  missing index entry, gate8 single-source-assertion and fix-roundtrip failures). Out of scope;
  they are inputs to the comparison, not work items.
- Widening `verify-deploy.sh` gate5's coverage. Identified as a real gap; belongs to a separate
  task.
- Re-registering or re-scoping the `lean-lsp` MCP server, or building the project-scoped
  registration mechanism.
- De-duplicating the nine playwright grants across the `web` and `present` settings fragments.
- Investigating `system-defect-record.sh` (research settled it: expected usage-error exit).
- Any edit to `agent-system/extensions/core/root-files/settings.json` — it is already correct.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Post-deploy `verify-deploy.sh` still reports findings and is misread as failure | H | H (certain) | Acceptance is **baseline-relative**: only a `FINDING` line absent from research report Section 4 is a regression. Phase 5 encodes this as a mechanical `comm -13` set difference, not a judgment call. |
| Baseline is re-captured after the deploy, destroying the comparison | H | M | Phase 1 writes the Section 4 text to an on-disk baseline file **before** Phase 2 deploys; Phase 5 reads only that file. No phase may run `verify-deploy.sh` before Phase 2 completes. |
| Hand-edit "corrected" by editing the source copy instead | H | M | Explicitly forbidden in Phase 4's tasks and re-asserted in its acceptance criteria: source copy already has no `lean-lsp` grant (`grep -c` returns 0) and must still return 0 afterward. |
| Source-store-boundary advisory hook warning silently ignored | M | H (will fire) | Phase 4 requires the reasoning be *written down* (summary + `CHANGE_LOG.md`), and Phase 6 verifies the record exists. The hook is advisory (non-blocking) by design. |
| gate5 blind spot lets `manifest.json` drift survive a clean run | M | M | Phase 3 hand-diffs the 3 uncovered files plus reconciles all 16 changed files. |
| The stale grant is the **last** array element; a careless line deletion leaves a trailing comma and invalid JSON | H | M | Phase 4 requires a `jq empty` validity check plus an element-count comparison before/after, not a bare line delete. |
| Deploy clobbers unrelated local state | M | L | Phase 1 takes a `git-snapshot.sh` checkpoint first; `.claude/` is gitignored and regenerable, and install-once files are structurally preserved. |
| MCP registration change cannot be observed from this session | L | H (certain) | Recorded as an explicit manual follow-up for a fresh session in Phase 6; not treated as an in-task acceptance gate. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Pre-Deploy Snapshot and Baseline Materialization [NOT STARTED]

**Goal**: Take a rollback checkpoint and materialize the research report's verbatim pre-deploy
baseline as an on-disk file, so the post-deploy comparison has a fixed, machine-diffable
counterpart. Confirm the pre-deploy preconditions still hold at execution time.

**Tasks**:
- [ ] Run `bash .claude/scripts/git-snapshot.sh 32` to create a rollback checkpoint before any
  deploy or hand-edit.
- [ ] Extract the fenced code block in research report Section 4 (lines 195-247 of
  `reports/01_redeploy-and-remediate-baseline.md`) verbatim to
  `specs/032_redeploy_and_remediate_install_once_settings/pre-deploy-findings.txt`.
- [ ] Derive the normalized comparison set:
  `grep '^FINDING ' pre-deploy-findings.txt | sort -u > pre-deploy-findings.normalized.txt`.
- [ ] Confirm preconditions still hold (each is a one-line check, recorded in the summary):
  - `grep -n "lean-lsp" .claude/settings.json` still hits (expected: line 188).
  - `grep -c "lean-lsp" agent-system/extensions/core/root-files/settings.json` returns `0`.
  - `grep -n "dispatch_seq_counter" .claude/scripts/skill-base.sh` still shows the ambient form
    (`dispatch_seq_counter=$((dispatch_seq_counter + 1))`, ~line 958).
- [ ] Record the 16-file changed set for Phase 3's reconciliation:
  `git log --since="2026-08-17 21:36:34 -0700" --name-only --pretty=format: -- agent-system/ | sort -u`
  written to `specs/032_redeploy_and_remediate_install_once_settings/changed-source-files.txt`.
- [ ] **MUST NOT** run `verify-deploy.sh` in this phase. The baseline is transcribed from the
  report, never re-derived.

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: The report asserts the changed source set is **16 files** and the normalized
baseline is **28 `FINDING` lines** (of 52 total captured lines). Both are hypotheses to confirm at
implementation time: the implementer must report the actual `wc -l` of
`changed-source-files.txt` and `pre-deploy-findings.normalized.txt`. A mismatch is **not** a
blocker — it means source changed since the report — but it MUST be recorded in the summary, and if
`changed-source-files.txt` exceeds 16 the implementer must confirm the extra files also belong to
completed work before proceeding to Phase 2.

**Files to modify**:
- `specs/032_redeploy_and_remediate_install_once_settings/pre-deploy-findings.txt` - new; verbatim
  Section 4 capture
- `specs/032_redeploy_and_remediate_install_once_settings/pre-deploy-findings.normalized.txt` - new;
  `grep '^FINDING ' | sort -u` form
- `specs/032_redeploy_and_remediate_install_once_settings/changed-source-files.txt` - new; the
  changed-source manifest for Phase 3

**Verification**:
- `pre-deploy-findings.normalized.txt` exists, is non-empty, and every line starts with `FINDING `.
- A `git stash list` / snapshot ref confirms the checkpoint was created.
- All three precondition checks reported with their actual output.
- No `verify-deploy.sh` invocation appears in this phase's command history.

---

### Phase 2: Run the Deploy [NOT STARTED]

**Goal**: Deploy the entire `agent-system/extensions/**` source store to `.claude/`, making the
mint-dispatch-seq fix and the three literature fixes live.

**Tasks**:
- [ ] Run `bash .claude/scripts/deploy-headless.sh`, capturing full stdout+stderr to
  `specs/032_redeploy_and_remediate_install_once_settings/deploy-output.txt`.
- [ ] Record the deploy's exit code explicitly.
- [ ] Read the deploy output for any reported skip, error, or "preserved (settings install-once)"
  count and record it — the install-once preservation line is **expected and correct**, not a
  failure.
- [ ] Confirm the deploy did **not** overwrite `.claude/settings.json`: `grep -n "lean-lsp"
  .claude/settings.json` must still hit after the deploy (this is the install-once trap the task
  exists to remediate; its persistence here confirms the mechanism behaved as documented).

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- `.claude/**` - regenerated wholesale by the deploy script (sanctioned: this is the deploy
  process itself, explicitly exempted by `source-store-deploy-boundary.md`)
- `specs/032_redeploy_and_remediate_install_once_settings/deploy-output.txt` - new; deploy log

**Verification**:
- `deploy-headless.sh` exits 0 (a nonzero exit halts the phase and is recorded, not worked around).
- `.claude/scripts/skill-base.sh` and `agent-system/extensions/core/scripts/skill-base.sh` are now
  byte-identical (`diff -q` reports no difference).
- The two previously-never-deployed files now exist:
  `.claude/scripts/tests/test-mint-dispatch-seq.sh` and
  `.claude/scripts/literature_quality_gate.py`.
- `grep -n "lean-lsp" .claude/settings.json` still hits (install-once confirmed; remediated in
  Phase 4).

---

### Phase 3: Targeted Post-Deploy Acceptance Checks [NOT STARTED]

**Goal**: Prove the two things `verify-deploy.sh` alone cannot prove — that the live-observed
mint-dispatch-seq defect is actually fixed in the deployed tree, and that the 3 files gate5 never
compares deployed correctly.

**Tasks**:
- [ ] **Mint-dispatch-seq acceptance check** (the concrete defect this deploy fixes):
  - Confirm the deployed `skill_orchestrate_mint_dispatch_seq` now derives the sequence from the
    loop-guard file: `grep -n "dispatch_seq_counter" .claude/scripts/skill-base.sh` must show
    `new_seq=$(jq -r '(.dispatch_seq_counter // 0) + 1' "$loop_guard_file")` and must **no longer**
    show `dispatch_seq_counter=$((dispatch_seq_counter + 1))`.
  - Extract the function body from both deployed and source copies and confirm they match
    textually.
  - Run the now-deployed regression suite:
    `bash .claude/scripts/tests/test-mint-dispatch-seq.sh`. Baseline Cases C/D/E/F (and Case B) were
    FAILing pre-deploy; record which cases pass now.
- [ ] **gate5 blind-spot manual diffs** — `diff -q` each of the 3 files gate5 does not compare,
  deployed vs source:
  - `.claude/manifest.json` (or the core manifest at its deployed path) vs
    `agent-system/extensions/core/manifest.json`
  - the deployed literature manifest vs `agent-system/extensions/literature/manifest.json`
  - `.claude/context/project/literature/patterns/shared-module-extraction-for-gate-checks.md` vs its
    source counterpart
- [ ] **Full reconciliation**: for every path in `changed-source-files.txt` from Phase 1, `diff -q`
  the source file against its deployed counterpart and record any that still differ or are missing.
  Record any file that legitimately has no deployed counterpart (source-only files such as
  `merge-sources/**`) as such rather than as a failure.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts **3** gate5-uncovered files and a **16**-file
reconciliation set, both taken from research report Section 1's table. The implementer must confirm
these against `changed-source-files.txt` produced in Phase 1 rather than assuming them. If the
deployed path for either `manifest.json` differs from the assumed location, resolve the actual
deployed path from the deploy output or the loader's category descriptors and record it — do not
silently skip the check.

**Files to modify**:
- `specs/032_redeploy_and_remediate_install_once_settings/post-deploy-checks.txt` - new; the
  recorded output of every check above

**Verification**:
- Deployed `skill-base.sh` contains the `jq -r '(.dispatch_seq_counter // 0) + 1'` form and does not
  contain the ambient-increment form.
- `test-mint-dispatch-seq.sh` runs; every previously-failing case (B, C, D, E, F) is reported with
  its new status. Any case still failing is recorded as a genuine finding, not glossed.
- Each of the 3 gate5-uncovered files reports byte-identical, or its difference is recorded.
- Every reconciled file is classified: identical / differs / source-only / missing.

---

### Phase 4: Hand-Remove the Stale Grant from the Deployed settings.json [NOT STARTED]

**Goal**: Remove the `mcp__lean-lsp__*` grant from the **deployed** `.claude/settings.json` — the
one edit a redeploy structurally cannot make — and record the boundary-rule reasoning rather than
suppressing the advisory hook warning.

**SANCTIONED BOUNDARY EXCEPTION (read before editing)**: `.claude/rules/source-store-deploy-boundary.md`
normally forbids hand-authoring `.claude/**`. This edit is the single explicitly-justified
exception for this task, because `settings.json` deploys under **install-once** semantics
(`INSTALL_ONCE_ROOT_FILES` in `loader.lua:134`; copy-skip at `loader.lua:476`; unload-exclusion at
`init.lua:770/776`). Once a project has its own copy, no redeploy ever overwrites it — so this file
is effectively **user state**, not a regenerable deploy artifact, and the boundary rule's premise
("the next regeneration silently wipes your edit") does not hold. Phase 2 empirically confirmed
this: the grant survived a full deploy.

**Tasks**:
- [ ] Confirm the source copy is already correct and record the evidence:
  `grep -c "lean-lsp" agent-system/extensions/core/root-files/settings.json` returns `0`.
- [ ] Record the pre-edit permission-array element count (e.g. via `jq` on the containing array) so
  the post-edit count can be checked as exactly one fewer.
- [ ] Remove the `"mcp__lean-lsp__*"` element. **Note it is the last element of its array** — a bare
  line deletion would leave a trailing comma on the preceding `"Skill",` line and produce invalid
  JSON. Use a structure-aware edit (a `jq` filter such as `del(.. | select(. == "mcp__lean-lsp__*"))`
  applied to the specific array, or an Edit that removes the comma with the line) and validate.
- [ ] Validate: `jq empty .claude/settings.json` exits 0.
- [ ] **MUST NOT** edit `agent-system/extensions/core/root-files/settings.json` in any way. It is
  already correct; "fixing" the hook warning by touching the source copy is explicitly forbidden.
- [ ] **Record the expected hook warning and its reasoning in writing.** The
  `validate-meta-write.sh` PostToolUse advisory hook will fire on this `.claude/**` write. It is
  non-blocking and its warning is correct *in general*. Write into the implementation summary — and
  carry the same reasoning into the `CHANGE_LOG.md` entry in Phase 6 — that: (a) the warning fired;
  (b) it does not apply to an install-once root file, which is user state rather than a regenerable
  deploy artifact; (c) the source copy was verified already-correct and deliberately left untouched.
  Silently ignoring the warning is a phase failure even if the edit itself is correct.

**Timing**: 0.25 hours

**Depends on**: 2

**Verification Tier**: interface

**Commit Mode**: per-substep

**Files to modify**:
- `.claude/settings.json` - remove the single `"mcp__lean-lsp__*"` permission element
  (**sanctioned install-once exception**; `.claude/` is gitignored so this change is not committed
  — the *record* of it in the summary and `CHANGE_LOG.md` is the durable artifact)

**Verification**:
- `grep -c "lean-lsp" .claude/settings.json` returns `0`.
- `jq empty .claude/settings.json` exits 0 (file is still valid JSON).
- The containing permission array has exactly one fewer element than the pre-edit count, and every
  other grant is unchanged (`"Skill"`, `"WebFetch"`, `"Task"`, etc. all still present).
- Hook-registration and any other top-level `settings.json` sections are byte-unchanged apart from
  the removed element.
- `grep -c "lean-lsp" agent-system/extensions/core/root-files/settings.json` still returns `0`
  and `git status --short agent-system/extensions/core/root-files/settings.json` shows no
  modification.
- The install-once reasoning is present, in prose, in the implementation summary.

---

### Phase 5: Baseline-Relative verify-deploy Comparison [NOT STARTED]

**Goal**: Run the post-deploy findings capture and prove, mechanically, that no finding present now
was absent from the pre-deploy baseline. Pre-existing findings are explicitly **not** failures.

**Tasks**:
- [ ] Run `bash .claude/scripts/verify-deploy.sh --findings --quiet` capturing full output to
  `specs/032_redeploy_and_remediate_install_once_settings/post-deploy-findings.txt`. Note this
  invokes `run-all.sh` internally and takes several minutes — allow for it rather than timing out
  and retrying.
- [ ] Normalize with the tool's documented consumer pattern:
  `grep '^FINDING ' post-deploy-findings.txt | sort -u > post-deploy-findings.normalized.txt`.
- [ ] Compute the **regression set** — findings present now and absent from the baseline:
  `comm -13 pre-deploy-findings.normalized.txt post-deploy-findings.normalized.txt`.
- [ ] Compute the **resolved set** for the record (present in baseline, gone now):
  `comm -23 pre-deploy-findings.normalized.txt post-deploy-findings.normalized.txt`. Expect the
  gate3/gate5 drift findings and the gate8 mint-dispatch-seq case failures to appear here.
- [ ] For each line in the regression set, if any: classify it and record it. Do **not** classify a
  baseline finding as a regression, and do **not** attempt to fix pre-existing findings.
- [ ] Explicitly confirm the known pre-existing findings survived unchanged rather than being
  re-introduced: the 10 gate3 "Rule R" line-count mismatches, the gate3 "Rule S"
  `return-meta-artifacts-template.md` index entry, and the gate8 single-source-assertion /
  fix-roundtrip failures.

**Timing**: 0.75 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: The acceptance criterion assumes the pre-deploy normalized set is a faithful
transcription of research report Section 4 and that ~11 gate5/gate3 drift findings plus ~9 gate8
mint-dispatch-seq case failures will move to the resolved set. These are hypotheses. The implementer
must report the actual line counts of the regression set and the resolved set, and must not
retroactively edit `pre-deploy-findings.normalized.txt` to make the comparison come out clean —
that file is frozen input from Phase 1.

**Files to modify**:
- `specs/032_redeploy_and_remediate_install_once_settings/post-deploy-findings.txt` - new
- `specs/032_redeploy_and_remediate_install_once_settings/post-deploy-findings.normalized.txt` - new
- `specs/032_redeploy_and_remediate_install_once_settings/findings-delta.txt` - new; the regression
  set and resolved set with their classifications

**Verification**:
- **Acceptance criterion (primary)**: the regression set
  (`comm -13 pre-deploy post-deploy`) is empty. A non-empty regression set blocks phase completion
  and is recorded with per-line classification.
- A non-empty *post-deploy findings set* is explicitly **not** a failure — only the regression set
  gates this phase.
- The resolved set is non-empty and includes the gate5 `skill-base.sh` / literature-script drift
  findings and the `Missing scripts` findings, confirming the deploy actually took effect.
- `pre-deploy-findings.normalized.txt` is byte-identical to its Phase 1 form (`git diff` shows no
  modification to it).

---

### Phase 6: Record the Change Log Entry, Deferred Decisions, and Summary [NOT STARTED]

**Goal**: Make the deploy's meaning legible to a future reader — which previously-completed work
became live at this deploy (so it is not misdated), why the install-once hand-edit was sanctioned,
and why the two deferred decisions were deferred.

**Tasks**:
- [ ] Add a `CHANGE_LOG.md` entry under a new dated heading (`### 2026-08-24`), following the file's
  existing structure but **keyed on durable anchors, with no task numbers** — see "Measured
  Correction to the Delegation Brief" in this plan's Overview for why this holds even though the
  file lives at `specs/CHANGE_LOG.md`. Cite each newly-live fix by its durable anchor:
  - the **mint-dispatch-seq persisted-counter fix** in `scripts/skill-base.sh` —
    `skill_orchestrate_mint_dispatch_seq` now derives the sequence via
    `jq -r '(.dispatch_seq_counter // 0) + 1'` from the loop-guard file instead of an ambient shell
    variable that collapses to empty under `set -u` in a fresh shell; the regression suite is
    `scripts/tests/test-mint-dispatch-seq.sh`
  - the **literature conversion quality gate hardening** against control-character/mojibake
    extraction output (`literature-convert.sh`, `literature_quality_gate.py`) — HIGH severity, a
    corpus-corruption vector on the pymupdf fallback tier
  - the **discovery tier-starvation and silent Tier 3 failure fix** in `literature-discover.sh`
  - the **validate-mode directory-path false-positive fix** (the `-d` vs `-f` branch) in
    `skill-literature` validate mode, plus the `--dry-run` flag/doc mismatch in
    `literature-normalize-authors.sh`
  - State plainly that this work was authored earlier and became **live at this deploy**, so a
    future reader does not misdate it.
  - Include the install-once hand-edit and its reasoning (grant removed from the deployed
    `settings.json`; source copy already correct and untouched; advisory hook warning expected and
    inapplicable to an install-once root file).
- [ ] Verify no task number entered the new entry:
  `bash .claude/scripts/check-task-references.sh` (or a targeted grep over the added lines for
  `[Tt]ask [0-9]`) returns clean for the added content.
- [ ] Write the implementation summary to
  `specs/032_redeploy_and_remediate_install_once_settings/summaries/01_deploy-remediate-stale-grant-summary.md`,
  recording:
  - the deploy result and the baseline-relative findings comparison (regression set = empty, plus
    the resolved set)
  - the mint-dispatch-seq acceptance-check result
  - the gate5 blind-spot manual-diff results
  - the install-once boundary-exception reasoning and the fired advisory hook
- [ ] **Record deferred decision (a) — lean-lsp user-scope mis-registration**: `lean-lsp` is
  registered at user (global) scope but hardcodes
  `/home/benjamin/Projects/BimodalLogic/.claude/scripts/lean-lsp-mcp-wrapper.sh
  --lean-project-path /home/benjamin/Projects/BimodalLogic`, a path into a different repository.
  **DEFER, not indefinitely**: this is a real bug class (user-scope registration used for a
  fundamentally per-project resource), but fixing it requires either an operator-level MCP
  re-registration outside the source store, or building the project-scoped registration mechanism —
  either would scope-creep a deploy-and-remediate task.
- [ ] **Record deferred decision (b) — nine duplicated playwright grants**: the identical 9 tools
  (`browser_click`, `browser_console_messages`, `browser_find`, `browser_navigate`,
  `browser_network_requests`, `browser_snapshot`, `browser_take_screenshot`, `browser_type`,
  `browser_wait_for`) are granted by both `agent-system/extensions/web/settings-fragment.json` and
  `agent-system/extensions/present/settings-fragment.json`. **DEFER**: harmless duplication — each
  extension independently needs these grants and an additive deep-merge merely makes the redundancy
  visible, not broken. The clean fix (grant once at machine scope in the NixOS configuration, per
  the grant-at-registration-scope rule) is a NixOS-side task. **Do not break working grants chasing
  tidiness** — neither fragment is edited by this task.
- [ ] **Record the manual follow-up check that this session cannot self-verify**: a *fresh* Claude
  Code session is required to observe MCP registration changes; confirm there that the expected
  servers appear and no `lean-lsp` grant is in effect for this project.
- [ ] Optionally note the identified `verify-deploy.sh` gate5 coverage gap (`manifest.json` and some
  context docs uncompared) as a follow-up candidate — recording only, no implementation.

**Timing**: 0.5 hours

**Depends on**: 5

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `specs/CHANGE_LOG.md` - new dated entry, durable anchors only, no task numbers
- `specs/032_redeploy_and_remediate_install_once_settings/summaries/01_deploy-remediate-stale-grant-summary.md` - new

**Verification**:
- The new `CHANGE_LOG.md` entry exists, names all four newly-live fixes by durable anchor, and
  states they became live at this deploy.
- No `[Tt]ask [0-9]` occurrence in the added `CHANGE_LOG.md` content.
- The summary records: deploy result, empty regression set, mint-dispatch-seq check, gate5
  blind-spot diffs, install-once boundary reasoning, both deferred decisions with their reasons, and
  the fresh-session manual follow-up.
- Both deferred decisions are stated with a *reason*, not a bare "deferred".
- No modification to `agent-system/extensions/web/settings-fragment.json`,
  `agent-system/extensions/present/settings-fragment.json`, or
  `agent-system/extensions/core/root-files/settings.json`.

---

## Testing & Validation

- [ ] `deploy-headless.sh` exits 0.
- [ ] `diff -q .claude/scripts/skill-base.sh agent-system/extensions/core/scripts/skill-base.sh`
  reports no difference.
- [ ] Deployed `skill_orchestrate_mint_dispatch_seq` contains
  `jq -r '(.dispatch_seq_counter // 0) + 1'` and no ambient-increment form.
- [ ] `bash .claude/scripts/tests/test-mint-dispatch-seq.sh` — previously-failing Cases B/C/D/E/F
  reported with new status.
- [ ] `grep -c "lean-lsp" .claude/settings.json` returns `0`.
- [ ] `jq empty .claude/settings.json` exits 0.
- [ ] `grep -c "lean-lsp" agent-system/extensions/core/root-files/settings.json` still returns `0`
  and the file is unmodified in `git status`.
- [ ] `comm -13 pre-deploy-findings.normalized.txt post-deploy-findings.normalized.txt` is empty
  (**the acceptance criterion**).
- [ ] The 3 gate5-uncovered files are byte-identical between source and deployed, or their
  difference is recorded.
- [ ] No task number in the new `CHANGE_LOG.md` content.
- [ ] Manual, out-of-session: a fresh Claude Code session shows the expected MCP servers.

## Artifacts & Outputs

- `specs/032_redeploy_and_remediate_install_once_settings/pre-deploy-findings.txt` (Phase 1)
- `specs/032_redeploy_and_remediate_install_once_settings/pre-deploy-findings.normalized.txt` (Phase 1)
- `specs/032_redeploy_and_remediate_install_once_settings/changed-source-files.txt` (Phase 1)
- `specs/032_redeploy_and_remediate_install_once_settings/deploy-output.txt` (Phase 2)
- `specs/032_redeploy_and_remediate_install_once_settings/post-deploy-checks.txt` (Phase 3)
- Modified deployed `.claude/settings.json` (Phase 4; gitignored, recorded not committed)
- `specs/032_redeploy_and_remediate_install_once_settings/post-deploy-findings.txt` (Phase 5)
- `specs/032_redeploy_and_remediate_install_once_settings/post-deploy-findings.normalized.txt` (Phase 5)
- `specs/032_redeploy_and_remediate_install_once_settings/findings-delta.txt` (Phase 5)
- New dated entry in `specs/CHANGE_LOG.md` (Phase 6)
- `specs/032_redeploy_and_remediate_install_once_settings/summaries/01_deploy-remediate-stale-grant-summary.md` (Phase 6)

## Rollback/Contingency

- **Snapshot**: Phase 1 takes `bash .claude/scripts/git-snapshot.sh 32` before any mutation. Any
  rollback of tracked files goes through that snapshot; per
  `.claude/rules/git-workflow.md`, no destructive git command runs on a dirty tree without it.
- **Deploy rollback**: `.claude/` is a gitignored, disposable deploy artifact regenerated from the
  source store. If the deploy produces a broken tree, re-running `deploy-headless.sh` from a
  corrected source store is the remedy; there is nothing hand-authored in `.claude/` to lose
  **except** install-once files.
- **settings.json rollback**: `.claude/settings.json` is install-once and therefore NOT regenerable
  — it is the one file a re-deploy will not restore. Before the Phase 4 edit, copy it to
  `specs/032_redeploy_and_remediate_install_once_settings/settings.json.bak`. To roll back, restore
  from that copy and re-validate with `jq empty`.
- **Non-empty regression set in Phase 5**: do not "fix forward" by editing deployed files. Record
  the regression lines, mark Phase 5 `[BLOCKED]`, and escalate — the correct fix targets the source
  store and belongs to a follow-up cycle.
- **Deploy exits nonzero**: halt at Phase 2, record the output, do not proceed to Phases 3-6. A
  partial deploy invalidates the baseline comparison's premise.

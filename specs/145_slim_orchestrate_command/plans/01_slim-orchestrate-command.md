# Implementation Plan: Task #145

- **Task**: 145 - Slim `commands/orchestrate.md` to the flag table and the dispatch
- **Status**: [IMPLEMENTING]
- **Effort**: 7.5 hours
- **Dependencies**: 149 (team-mode deletion — already landed; baseline is post-deletion)
- **Research Inputs**: `specs/145_slim_orchestrate_command/reports/01_slim-orchestrate-command.md`
- **Artifacts**: plans/01_slim-orchestrate-command.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Reduce `agent-system/extensions/core/commands/orchestrate.md` (44,953 B / 790 lines) to the
argument/flag surface plus the parse-and-dispatch core, deleting the 28,059 B
`### MULTI-TASK DISPATCH` block (62% of the file) and the consolidated-output invocation. Two
pieces of contract text found nowhere else relocate to
`docs/architecture/orchestrate-state-machine.md`. Ownership of the batch-results rendering moves
to `skill-orchestrate` Stage MT-5 (which already computes every input it needs), and 25+
cross-references naming the deleted Step numbers are repointed. The retained STAGE 0 keeps a
compact executable core so live `/orchestrate N,M` never stops working at any phase boundary.

The two questions the research flagged as blocking are pre-resolved by `specs/PATH.md`'s
"One engine, batch of one" section and its Stage A row A.1, and are implemented as decisions
here rather than re-litigated. See **Pre-Resolved Decisions** below.

### Research Integration

Findings carried forward verbatim:

- Measured baseline 44,953 B / 790 lines; per-section byte table (research Finding 1) is the
  budget baseline in Phase 6.
- Only the "Runtime wave-split check" subsection is genuinely self-labeled illustrative
  (Finding 3) — but see Decision 1: the rest is narration around a small executable core, not
  the core itself.
- Relocation verdict (Finding 4): relocate the `MAX_TASKS=8` BATCHING RULE and, from Step 5, the
  Exit-Path Coverage table plus the residue-check bash block. Do **not** relocate the wave-split
  defense-in-depth note — already near-verbatim in
  `context/patterns/multi-task-operations.md`'s "File Footprint Overlap as a Serialization Edge".
- Flag-gap analysis (Finding 5): `--hard` is the single genuine gap.
  `--force`/`--local`/`--exploit`/`--explore` are correctly excluded.
- Cross-reference inventory (Finding 6 / "Cross-References" section) is the Phase 2/3 checklist.

Verified during planning, beyond the research:

- `dependency_graph` is genuinely consumed every cycle at SKILL.md:2776 (Stage MT-3 step 3
  eligibility). It is a hard-required input and must keep being passed.
- `waves` is written into `mt_state_file` at SKILL.md:2524 and read **nowhere** — a repo-wide
  sweep of `scripts/`, `context/`, `docs/` finds no reader outside
  `orchestrate-dry-run-report.sh`, which builds its own array independently. It is vestigial.
- The consolidated-output *template* already lives in its own file
  (`context/patterns/orchestrate-batch-results-template.md`, 8,315 B). What Step 5 holds is only
  the *invocation* plus pre-computation prose. The template file survives untouched.
- SKILL.md Stage MT-5 step 4 already owns the consolidated summary and already computes
  `forward_progress_violated`, `defer_ledger`, `idle_overlap_ledger`,
  `verify_deploy_baseline_notices`, and `detected_defects` — it only lacks the instruction to
  read and emit the template. Without that one line, deleting Step 5 silently removes all
  multi-task output.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `specs/ROADMAP.md` in this repository. The governing design spec is `specs/PATH.md`; this task
is Stage A row A.1 ("slim `commands/orchestrate.md`"), a zero-risk ~10k-tokens-per-invocation
saving that also documents `--hard`. A.1 is downstream of A.0 (base-lifecycle-skill deletion) and
upstream of the `orchestrate-cycle-plan.sh` work (PATH row 147), which will later absorb the
dependency-graph construction retained here.

## Pre-Resolved Decisions

### Decision 1 — Retained STAGE 0 keeps computing and passing `dependency_graph`; `waves` becomes a single-row echo

**The research's "live multi-task dispatch breaks" finding is largely a false alarm**, and this
plan records the narrower true statement:

- `orchestrate.md`'s own text states the command never loops waves; the pre-computed `waves[]`
  array is vestigial (verified: no reader anywhere).
- The sole EXECUTING admission gate is SKILL.md Stage MT-3 step 4.5, which re-derives
  `eligible_tasks` **fresh every cycle** from current task statuses plus `dependency_graph` —
  never from a pre-computed wave row.
- `dependency_graph` is itself just a read of each task's `dependencies[]` out of
  `specs/state.json`, narrowed to in-batch.

What is therefore deleted is **narration**: the Kahn's-algorithm wave-assignment block, the
wave-split commentary, the Step 5 reconciliation prose, and the consolidated-output invocation.
What is **retained**, per PATH.md A.1's "STAGE 0 parse + dispatch":

1. `source .claude/scripts/parse-command-args.sh` and the flag-thread notes (compressed);
2. the dry-run short-circuit, unchanged, still pointed at
   `scripts/orchestrate-dry-run-report.sh`, plus the dry-run prohibition block verbatim;
3. the `len(TASK_NUMBERS)` single-vs-multi branch;
4. a compact multi-task delegation-context builder: task validation (not-found / terminal skip,
   with the loud skipped-tasks warning), the intra-batch `dependency_graph` jq build, and the
   `Skill` invocation with every delegation key unchanged.

**`waves` keeps its key** — dropping it would leave SKILL.md Stage MT-1 reading an absent key,
which this plan forbids — but is passed as a single row containing all validated tasks,
`[[t1, t2, ...]]`. Rationale: that value is a truthful description of what the engine actually
does (one cycling loop, eligibility re-derived every cycle), it is recorded into `mt_state_file`
and read by nothing, and it removes the last consumer of Kahn's algorithm from this file. MT-1's
description of `waves` is updated in Phase 3 to say "diagnostic echo, recorded not consumed".

**Net effect on live `/orchestrate N,M`**: none. Admission, eligibility, deferral, locking, and
dispatch all continue to run exactly as today.

**Deferred to a later task, not silently dropped**: the `waves` key itself and the STAGE 0
dependency-graph build both belong in `orchestrate-cycle-plan.sh` (PATH row 147). Do not remove
them here.

### Decision 2 — <= 8,000 B is a real target, measured against PATH.md A.1's keep-list

The research measured the budget against the task description's instruction-(4) keep-list
(12,546 B) and concluded the target was arithmetically impossible. That is the **wrong list**.
PATH.md A.1 is the authority and its keep-list is narrower: "keep Arguments, Options (add the
undocumented `--hard`), STAGE 0 parse + dispatch, checkpoints. Target <= 8 KB". It does **not**
require `## Output` and `## Error Handling` to survive verbatim, and it does not protect
CHECKPOINT 3's 3,153 B of inline commentary.

So <= 8,000 B is the target, reached by tightening prose in CHECKPOINT 3, `## Output`,
`## Error Handling`, the long `## Options` rows, and CHECKPOINT 1 / STAGE 2.

**Semantics that MUST survive tightening, in full** (the stop rule — never cut one of these to
hit a number):

- every flag's meaning and default, including `--continue-budget`-style "never inferred"
  contracts and the `--research`/`--plan`/`--implement` composability contract (canonical
  lifecycle ordering, stop-after-last-named-phase, new artifact round, no status regression);
- every delegation-context key the skill actually reads, in both the single-task STAGE 2 JSON and
  the multi-task STAGE 0 invocation;
- checkpoint ORDER (STAGE 0 -> CHECKPOINT 1 -> STAGE 2 -> CHECKPOINT 2 -> CHECKPOINT 3);
- the dry-run prohibition block, verbatim;
- the Anti-Bypass Constraint, verbatim;
- CHECKPOINT 3's staging bash, the zero-`modified_files` warning wording (explicitly canonical,
  "do not invent a second wording"), and the completion-only `.return-meta.json` deletion
  asymmetry.

Where a long paragraph is duplicated elsewhere, replace it with a one-line statement of the
meaning plus a pointer to the authoritative file, never with silence.

**Working per-section budget** (Phase 6 target; the honest floor may land 8,000-9,000 B):

| Section | Now | Target |
|---|---|---|
| frontmatter + title | 546 | 546 |
| `## Arguments` | 318 | 318 |
| `## Constraints` | 694 | ~650 |
| `## Options` (+ `--hard` row) | 3,063 | ~1,900 |
| `## Anti-Bypass Constraint` | 230 | 230 (verbatim) |
| `## Execution` heading | 14 | 14 |
| `### STAGE 0` | 4,348 | ~1,800 |
| `### MULTI-TASK DISPATCH` | 28,059 | 0 |
| `### CHECKPOINT 1` | 934 | ~600 |
| `### STAGE 2` | 1,152 | ~950 |
| `### CHECKPOINT 2` | 262 | 262 |
| `### CHECKPOINT 3` | 3,153 | ~1,000 |
| `## Output` | 1,607 | ~550 |
| `## Error Handling` | 573 | ~400 |
| **Total** | **44,953** | **~9,200** |

If the honest floor exceeds 8,000 B, Phase 6 **must** record the exact measured byte count and
name the sections that could not be tightened further without cutting a listed semantic. Silently
missing the target, and silently gutting a semantic to hit it, are both failures.

## Goals & Non-Goals

**Goals**:

- `commands/orchestrate.md` reduced toward <= 8,000 B with before/after byte counts recorded.
- `### MULTI-TASK DISPATCH` (Steps 1-5) and the consolidated-output invocation deleted.
- BATCHING RULE (`MAX_TASKS=8` + trim behavior), Exit-Path Coverage table, and the residue-check
  bash block relocated to `docs/architecture/orchestrate-state-machine.md`.
- STAGE 0 reduced to parse + dry-run short-circuit + single-vs-multi branch + delegation-context
  build, retaining `dependency_graph` so live batch dispatch is unaffected.
- `--hard` documented in the Options table (one row, cost and composability).
- Both "single-task only" Constraints lines updated to "per-task in the batch engine once the
  feature-port task lands".
- Every cross-reference to a deleted Step number repointed or deleted; multi-task batch output
  still rendered (ownership moved to Stage MT-5).
- Source store is the only edit target. Nothing hand-authored under `.claude/**`.

**Non-Goals**:

- Relocating the wave-split defense-in-depth note (redundant with
  `multi-task-operations.md`).
- Relocating any deleted content into `skills/skill-orchestrate/SKILL.md`. SKILL.md edits are
  limited to pointer repoints plus the two one-line ownership statements Phase 3 enumerates.
- Re-adding `--team` / `--team-size` (deleted by the predecessor).
- Retiring `orchestrate-dry-run-report.sh` (a later task's job — keep the short-circuit pointed
  at it).
- Cleaning up the now-orphaned `EXPLOIT_FLAG`/`EXPLORE_FLAG` in `parse-command-args.sh`
  (out of scope; file separately).
- Fixing the known pre-existing `verify-deploy.sh` failures (gate3 index-entries line_count,
  gate10 unknown state.json fields `abandon_reason`/`blocks_note`, gate12 state-writer boundary
  in `test-force-phases.sh`, intermittent gate8 timing flake). These predate this batch.
- Any change to flag semantics, delegation-context keys, checkpoint order, or the dry-run
  prohibition block.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Deleting Step 5 removes the only site that emits batch results, so `/orchestrate N,M` finishes silently | H | H | Phase 3 lands the Stage MT-5 emit instruction and repoints its template pointers **before** Phase 4 deletes anything. Phase 3's verification greps the template file for a live caller. |
| The compact STAGE 0 builder drops or renames a delegation key the skill reads | H | M | Phase 4 diffs the new invocation's key set against the old one key-by-key and against SKILL.md Stage MT-1's read list; the check is an explicit sub-step, not an eyeball pass. |
| A phase boundary leaves the source store undeployable while six dependent tasks queue behind this one | H | M | Every phase is a self-contained deployable unit; Phases 1-3 are purely additive/pointer edits; Phase 4 deletes and installs the replacement in one edit to one file. Phase 7 runs deploy + full gates. |
| Prose tightening silently changes a flag semantic | H | M | Decision 2's explicit stop-list; Phase 6 verification re-reads every Options row against `parse-command-args.sh` and confirms each flag's meaning and default survive. |
| A cross-reference repoint is missed, leaving a dangling "Step N" pointer | M | H | Phase 5 re-greps `"Step [0-9]"`, `"MULTI-TASK DISPATCH"`, and `"orchestrate\.md.*Step"` across the whole source store after edits; zero hits outside intentional history notes is the exit criterion. |
| `modified_files` excursion advisory fires — task `file_scope` lists only 2 files but ~12 are touched | L | H | Expected and benign. Widen `file_scope` via the sanctioned `--file-scope-add` path at Phase 1, or accept the advisory and note it in the summary. Never suppress it. |
| The `waves` single-row echo confuses a future reader of `mt_state_file` | L | M | Phase 3 updates MT-1's description of `waves` to name it a diagnostic echo, and Phase 1's relocated state-machine text records that the engine re-derives eligibility every cycle. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |
| 6 | 7 | 6 |

Phases within the same wave can execute in parallel. Phases 2 and 3 touch disjoint files
(Phase 2: docs/context/scripts; Phase 3: `skill-orchestrate/SKILL.md` only) and may be run
concurrently or sequentially.

---

### Phase 1: Baseline measurement and contract-text relocation [COMPLETED]

**Goal**: Record the before-state precisely, and land the two genuinely-orphaned pieces of
contract text in `docs/architecture/orchestrate-state-machine.md` so that Phase 2's repoints have
a real target and Phase 4's deletion loses nothing. Purely additive — no deletion yet.

**Tasks**:

- [x] Record baseline: `wc -c -l agent-system/extensions/core/commands/orchestrate.md` and the *(completed: 44,953 B / 790 lines)*
      per-section byte table (reuse the research's method: section boundaries from
      `grep -n '^#'`). Write the numbers into the eventual summary's before-column.
- [ ] Optionally widen the task's `file_scope` to cover the files this plan touches, via the
      sanctioned `--file-scope-add` path, so the excursion advisory reflects intent. *(deviation: skipped — the excursion advisory is expected and benign per the plan's own risk table; accepted rather than widening scope)*
- [x] In `orchestrate-state-machine.md`, under `## MT Mode: Multi-Task Orchestration` and before
      `### Dependency Gating Model`, add a `### Batch Size Cap (MAX_TASKS)` section stating:
      `MAX_TASKS = 8`; a request exceeding it is **trimmed to the first 8 tasks** with the
      warning `Batching is not yet supported. Running with first N tasks only.`; batching proper
      is not yet supported. Include the bash guard verbatim from the deleted Step 4 so the
      wording and the trim semantics are preserved exactly. *(completed)*
- [x] In `orchestrate-state-machine.md`'s existing `### Commit Granularity` section, append the
      **Exit-Path Coverage** table verbatim from the deleted Step 5 (all six outcome rows:
      `completed`, `failed`, `blocked`, partial, deferred-self-modifying,
      deferred-by-redeploy-checkpoint), preserving every cross-reference inside its cells. *(completed)*
- [x] In the same `### Commit Granularity` section, append the **residue check** bash block
      verbatim (`git status --porcelain -- specs/`, WARN-ONLY, never commits) together with the
      one-sentence statement that it warns and never commits, and name Stage MT-5 as the site
      that now runs it (the command no longer does). *(completed)*
- [x] Reword `orchestrate-state-machine.md:424`'s self-reference so this document describes
      itself as the source of truth for commit granularity rather than pointing at
      `commands/orchestrate.md` Step 5. *(completed)*
- [x] Do **not** relocate the wave-split defense-in-depth note. *(completed: left in place, near-verbatim coverage already exists in multi-task-operations.md)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts exactly three relocated units (BATCHING RULE, Exit-Path
Coverage table, residue-check block) and one reworded self-reference. Confirm at implementation
time by diffing the deleted Step 4/Step 5 text against `multi-task-operations.md`,
`batch-orchestration-guardrails.md`, and `orchestrate-state-machine.md`'s pre-existing
`### Commit Granularity` — if a fourth genuinely-orphaned unit surfaces, relocate it and record
the addition in the summary rather than dropping it.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - add
  `### Batch Size Cap (MAX_TASKS)`; extend `### Commit Granularity` with the Exit-Path Coverage
  table and residue-check block; reword the line-424 self-reference.

**Verification**:
- `grep -n "MAX_TASKS" docs/architecture/orchestrate-state-machine.md` returns the new section
  with the literal `8` and the trim wording.
- `grep -n "Exit-path coverage\|residue" docs/architecture/orchestrate-state-machine.md` returns
  the relocated table and bash block.
- `grep -n "Step 5" docs/architecture/orchestrate-state-machine.md` returns nothing pointing at
  `commands/orchestrate.md`.
- `commands/orchestrate.md` byte count unchanged from baseline (this phase adds only).

---

### Phase 2: Repoint non-SKILL cross-references [NOT STARTED]

**Goal**: Repoint or delete every reference outside `skill-orchestrate/SKILL.md` that names a
`commands/orchestrate.md` Step number or the `MULTI-TASK DISPATCH` section, so nothing dangles
after Phase 4. Pointer-only edits; no behavior changes.

**Tasks**:

- [ ] `docs/architecture/batch-admit-schema.md` (lines ~12, 297, 342, 474, 497, 538): six sites
      naming "Step 3" as a reader/consumer of the admission-verdict schema, several tagged
      "illustrative only". Repoint each to `skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 (the
      actual executing consumer) and drop the now-meaningless "illustrative only" qualifier.
- [ ] `context/patterns/batch-orchestration-guardrails.md` (lines ~168, 255, 410, 469, 717-721,
      831, 838, 902): eight sites. Repoint the table row at 168 ("the command entry point that
      builds the wave schedule... (Step 3)") to name Stage MT-3 step 4.5. Update the
      "Rejected Approaches" entry at 717-721 to record that the Kahn's-algorithm pseudocode has
      since been deleted rather than converted to a script, so the rejection is history not a
      live constraint.
- [ ] `context/patterns/multi-task-operations.md`: repoint line ~629's "Step 3" mirror pointer
      (drop it — the content it mirrors stays here); update line ~667's `## See Also` entry to
      drop "with MULTI-TASK DISPATCH section".
- [ ] `context/patterns/file-footprint-overlap.md` (lines ~108-109): drop `Step 3` from the list
      of consumers of the shared overlap predicate, leaving the remaining consumers intact.
- [ ] `context/patterns/orchestrate-batch-results-template.md` (line 4): rewrite the header so it
      names Stage MT-5 as the emitting call site instead of "`commands/orchestrate.md`'s
      MULTI-TASK DISPATCH path... at Step 5", and update the closing "Read this file at the
      Step 5 call site" sentence to name Stage MT-5.
- [ ] `context/standards/orchestrator-runtime-files.md` (line ~43): "The batch commit step in
      `commands/orchestrate.md`" is already stale independent of this task (that batch commit was
      retired). Fix it opportunistically to name the per-task commits at Stage MT-4 step 5.5.
- [ ] Comment-only script sites, kept accurate: `scripts/orchestrate-dry-run-report.sh`
      (lines ~36, 38, 71, 112, 175, 212, 518 — reword "mirrors commands/orchestrate.md
      MULTI-TASK DISPATCH Step N" to name the state-machine doc / Stage MT-3, and point the
      `MAX_TASKS=8` "verbatim from orchestrate.md Step 4" comment at the new
      `### Batch Size Cap (MAX_TASKS)` section), `scripts/orchestrate-predispatch-review.sh`
      (line ~6), `scripts/test-session-runtime-files.sh` (line ~132).
- [ ] Leave `scripts/lint/lint-task-lookup-adoption.sh:284` and
      `docs/examples/research-flow-example.md` alone — generic, non-step-numbered, single-task.

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: the research inventoried ~25 sites across 8 non-SKILL files. That count is a
hypothesis. Confirm at implementation time with
`grep -rn 'orchestrate\.md.*Step [0-9]\|MULTI-TASK DISPATCH' agent-system/extensions/core/` and
treat the grep, not the inventory, as the checklist; record any site the research missed.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` - repoint 6 Step-3 sites
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - repoint 8 sites
- `agent-system/extensions/core/context/patterns/multi-task-operations.md` - drop 2 pointers
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` - drop Step 3 consumer
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - name MT-5 as call site
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - fix stale batch-commit reference
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` - comments only
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` - comment only
- `agent-system/extensions/core/scripts/test-session-runtime-files.sh` - comment only

**Verification**:
- `grep -rn 'orchestrate\.md.*Step [0-9]' agent-system/extensions/core/ --include='*.md' --include='*.sh'`
  returns nothing outside `skill-orchestrate/SKILL.md` (Phase 3's job).
- `bash agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh 145` still runs
  (comment-only edits changed no logic).
- No `.md` file references a `MULTI-TASK DISPATCH` section that will not exist.

---

### Phase 3: Move batch-output ownership to Stage MT-5 and repoint SKILL.md [NOT STARTED]

**Goal**: Make `skill-orchestrate` self-sufficient for multi-task reporting before the command's
Step 5 disappears, and repoint SKILL.md's 14+ Step-number references. Bounded to pointer repoints
plus two one-line ownership statements — no relocated content.

**Tasks**:

- [ ] Stage MT-5 step 4: add the single emit instruction — "READ
      `context/patterns/orchestrate-batch-results-template.md` and emit the batch results using
      that template exactly; its per-section rendering conditions are contract, not commentary."
      This is the one line whose absence would silently delete all batch output.
- [ ] Stage MT-5 step 4: repoint the four "see `commands/orchestrate.md`'s `### X` section for
      the actual rendering" pointers (Pre-Existing Deploy-Verify Failures, System Defects
      Detected, the ZERO DISPATCH / `defer_ledger` additive requirement, Admitted (idle overlap
      advisory)) at the template file's own identically-named `###` sections.
- [ ] Stage MT-5: add the re-run-sequence derivation in one sentence — order the deferred/excluded
      task numbers predecessor-first using `dependency_graph`, ascending within a tier, one
      `/orchestrate {N}` line per task; printed, never executed. This replaces the deleted Step
      5's "reuse the `waves` array computed at Step 3". Check first whether the template's own
      `### ZERO DISPATCH` section ("Re-run sequence (dependency order; printed, not executed)")
      already suffices; if it does, add only a pointer, not a restatement.
- [ ] Stage MT-5: name Stage MT-5 as the site that now runs the residue check (relocated in
      Phase 1), or state that the check is documented in `orchestrate-state-machine.md`'s
      `### Commit Granularity` and is advisory — pick one and be explicit.
- [ ] Stage MT-1: update the `waves` bullet to describe it as a **diagnostic echo** — recorded
      into `mt_state_file`, read by nothing, with eligibility re-derived fresh every cycle at
      Stage MT-3 step 4.5. Keep the key required.
- [ ] Stage MT-1 lines ~2507/2516: the "Upstream review cross-reference" paragraph currently
      depends on "the command's Step 1.5 (Pre-Dispatch Review)" and "Step 2/3 output". Repoint to
      STAGE 0's delegation-context builder; state that the pre-dispatch review call has moved
      into (or been retired from) STAGE 0 consistent with Phase 4's decision, and keep the
      Non-Negotiable 3 residual-gap pointer intact.
- [ ] Lines ~2600, 2613, 2651, 2670, 2683: "Step 5" cited as reader of MT state fields
      (`forward_progress_violated` and friends) — repoint to Stage MT-5, which is the real
      reader after this change.
- [ ] Line ~3072: "orchestrate.md Step 3" as origin of the mirrored wave-split check — restate as
      Stage MT-3 step 4.5 being the sole implementation, with the contract documented in
      `context/patterns/batch-orchestration-guardrails.md`.
- [ ] Lines ~3675, 3778, 3865: "so `commands/orchestrate.md` Step 5 can read it" — repoint to
      Stage MT-5.
- [ ] Line ~578: the `force_phases` "8 threading sites" count includes the deleted Step 4 site.
      Recount after Phase 4 and correct the number (defer the final recount to Phase 5's sweep if
      the exact post-deletion count is not yet determinable).

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: the research counted "14+ sites" in SKILL.md. Confirm with
`grep -n 'orchestrate\.md' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` and
treat that grep as the checklist. Any site not covered by the bullets above must be classified
(repoint / delete / leave) explicitly, not skipped.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - MT-5 emit instruction and
  four rendering repoints; MT-1 `waves` and upstream-review repoints; ~10 Step-5/Step-3 pointer
  repoints; `force_phases` site count.

**Verification**:
- `grep -rn 'orchestrate-batch-results-template' agent-system/extensions/core/skills/` returns
  the new MT-5 emit instruction — the template has a live caller.
- `grep -n 'commands/orchestrate\.md.*Step [0-9]' skills/skill-orchestrate/SKILL.md` returns
  nothing.
- Re-read Stage MT-5 end to end and confirm every input the template's ten `###` subsections need
  is computed in MT-5 (`completed_tasks`, `failed_tasks`, `deferred_self_modifying`,
  `deferred_deploy_checkpoint`, `defer_ledger`, `idle_overlap_ledger`,
  `verify_deploy_baseline_notices`, `detected_defects`, `cycles_used`, `forward_progress_violated`,
  and a `validated_count` equal to `length(task_numbers)`).
- Deploy and confirm `skill-orchestrate` still loads (no broken heading/anchor references).

---

### Phase 4: Delete MULTI-TASK DISPATCH and install the reduced STAGE 0 [NOT STARTED]

**Goal**: The core edit. Delete `### MULTI-TASK DISPATCH` (Steps 1-5, lines 131-634) and replace
STAGE 0's narration with the compact parse + dry-run + branch + delegation-context builder — in
one edit to one file, so that no intermediate state exists where multi-task dispatch has no
invocation site.

**Tasks**:

- [ ] Compose the replacement STAGE 0 body (single edit, replacing lines ~59-634):
      1. the `source .claude/scripts/parse-command-args.sh "$ARGUMENTS"` fence, with the exports
         comment retained and the six paragraphs of per-flag threading prose compressed to a
         short list — one clause per flag naming the delegation key it becomes and whether it is
         consumer-side-only (never forwarded to `orchestrate-batch-admit.sh`). Every flag's
         meaning and its consumer-side-only property must survive.
      2. the dry-run short-circuit fence **verbatim**, still calling
         `bash .claude/scripts/orchestrate-dry-run-report.sh` with the `SESSION_ID`-may-be-unset
         note, plus the **dry-run prohibition block verbatim** (retarget only its dangling
         "MUST NOT continue to MULTI-TASK DISPATCH" phrase to "MUST NOT continue to multi-task
         dispatch below").
      3. the `len(TASK_NUMBERS) == 1` / `> 1` branch.
      4. a compact multi-task block: validation loop (skip not-found and terminal, collect
         `skipped_tasks`, print them as warnings, ABORT if no validated tasks remain); the
         intra-batch `dependency_graph` build (single jq pass over `specs/state.json`
         `dependencies[]`, narrowed to `validated_tasks`); `waves` as one row of all validated
         tasks; `batch_session_id` from `common_session_id`; and the `Skill` invocation plus its
         JSON delegation-context block, both with the **identical key set** in use today.
- [ ] Decide and record the fate of the Step 1.5 Pre-Dispatch Review call
      (`orchestrate-predispatch-review.sh`). It is advisory-loud and non-blocking, and it is the
      only visibility surface Non-Negotiable 3 relies on for out-of-batch/nonexistent dependency
      edges. **Default: retain it as a single one-line invocation** inside the compact block (a
      `bash ...predispatch-review.sh "${validated_tasks[@]}"` line plus one sentence saying it is
      advisory, never blocking). Dropping it silently removes a guardrail surface — if it is
      dropped, say so explicitly and repoint Non-Negotiable 3.
- [ ] Delete the consolidated-output invocation, the `validated_count` precomputation prose, the
      commit-reconciliation narrative, the re-run-sequence derivation, and the
      "After consolidated output, STOP" line — all superseded by Phase 3's Stage MT-5 ownership.
- [ ] Confirm the `MAX_TASKS=8` guard's own text no longer lives here (it is in
      `orchestrate-state-machine.md` from Phase 1). Decide whether the executable guard itself
      stays in the compact block: **default yes**, kept as the 6-line bash guard, because it is
      an executing behavior and the state-machine doc is documentation, not code.
- [ ] Do not touch the Anti-Bypass Constraint, CHECKPOINT 1, STAGE 2, CHECKPOINT 2,
      CHECKPOINT 3, `## Output`, or `## Error Handling` in this phase — Phase 6 owns those.

**Timing**: 1.5 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Scope Hypothesis**: the deletion is asserted as lines 131-634 (28,059 B) with STAGE 0 lines
59-130 (4,348 B) rewritten. Confirm the exact boundaries at implementation time with
`grep -n '^#' commands/orchestrate.md` before editing — the line numbers here derive from a
measurement taken before Phases 1-3 and must be re-derived, not trusted.

**Files to modify**:
- `agent-system/extensions/core/commands/orchestrate.md` - delete `### MULTI-TASK DISPATCH`;
  replace `### STAGE 0` body with the compact parse + dry-run + branch + delegation-context build.

**Verification**:
- `grep -n 'MULTI-TASK DISPATCH\|Kahn' commands/orchestrate.md` returns nothing.
- Key-set diff: the new `Skill` args string and JSON block contain exactly
  `multi_task_mode, task_numbers, waves, dependency_graph, session_id, focus_prompt, lit_flag,
  allow_self_modifying, allow_scope_collision, continue_budget, clean_flag, effort_flag,
  model_flag, force_phases` — compared line-by-line against the pre-edit block and against
  SKILL.md Stage MT-1's read list. Zero additions, zero removals, zero renames.
- Checkpoint order intact: `grep -n '^### ' commands/orchestrate.md` shows STAGE 0, CHECKPOINT 1,
  STAGE 2, CHECKPOINT 2, CHECKPOINT 3 in that order.
- Dry-run prohibition block present and byte-identical apart from the retargeted phrase.
- Deploy the source store, then run `/orchestrate --dry-run` for a **single** number and for a
  **two-number** batch; both still produce the admission report and dispatch nothing.
- Record the interim byte count.

---

### Phase 5: Post-deletion dangling-reference sweep [NOT STARTED]

**Goal**: Catch every reference the Phase 2/3 inventories missed, now that the deletion is real.

**Tasks**:

- [ ] `grep -rn 'MULTI-TASK DISPATCH' agent-system/extensions/core/` — expect zero hits, or only
      hits that read as history ("the former MULTI-TASK DISPATCH block") and are intentional.
- [ ] `grep -rn 'orchestrate\.md.*Step [0-9]\|orchestrate\.md.*#### Step' agent-system/extensions/core/`
      — expect zero.
- [ ] `grep -rn 'commands/orchestrate\.md' agent-system/extensions/core/` — review every
      remaining hit and confirm each still describes something the file actually contains.
- [ ] Recount and correct SKILL.md's `force_phases` "N threading sites" number (deferred from
      Phase 3) against the post-deletion tree.
- [ ] Repeat the same sweep against the repo's own `docs/` and `README.md` surfaces if any
      reference `commands/orchestrate.md` step numbers.

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: local

**Files to modify**:
- Whatever the sweep surfaces — expected to be a small tail on the Phase 2/3 files.

**Verification**:
- All three greps above return zero unintended hits.
- `git diff --stat` for this phase is small; anything large means the Phase 2/3 inventory was
  materially incomplete and should be called out in the summary.

---

### Phase 6: Options `--hard` row, Constraints update, and prose tightening to budget [NOT STARTED]

**Goal**: Add the missing `--hard` documentation, correct the two stale "single-task only"
Constraints lines, and tighten the retained sections toward <= 8,000 B without cutting any
semantic on Decision 2's stop-list.

**Tasks**:

- [ ] Add one `--hard` row to the `## Options` table: high-effort mode; parsed by
      `parse-command-args.sh` as `EFFORT_FLAG=hard`, threaded as `effort_flag` and derived by the
      engine into `hard_mode`, which gates the hard-mode contract injection and the churn /
      three-strikes / burnout counters; cost ~3-5x standard; composable with `--lit`, the model
      flags, and the phase-forcing flags; default false. Keep it to one row.
- [ ] Do **not** add rows for `--force`, `--local`, `--exploit`, `--explore`. Do **not** re-add
      `--team` / `--team-size`.
- [ ] Update the two `## Constraints` lines that say the phase-forcing flags are "single-task
      only" to say they are **per-task in the batch engine once the feature-port task lands**,
      keeping the accurate present-tense statement that they are accepted and ignored in
      multi-task mode today. Update the matching "Single-task only" clauses in the
      `--research` / `--plan` / `--implement` Options rows the same way.
- [ ] Tighten `## Options`: compress the `--continue-budget` and `--research`/`--plan`/
      `--implement` rows to a one-line meaning plus a pointer to the authoritative file
      (`context/standards/orchestrator-runtime-files.md` for budget continuation;
      `.claude/CLAUDE.md`'s `/orchestrate` row for the composability contract). Preserve
      "never inferred", canonical lifecycle ordering, stop-after-last-named-phase, new artifact
      round, and no-status-regression as explicit clauses.
- [ ] Tighten `### CHECKPOINT 3`: keep both bash fences, the canonical zero-`modified_files`
      warning wording, and the completion-only `rm -f "${metadata_file}"` asymmetry with its
      reason in one sentence. Compress the mid-lifecycle-sweep and commit-mutex commentary to a
      sentence plus the existing pointer to `context/standards/orchestrator-runtime-files.md`.
- [ ] Tighten `## Output`: keep all five outcome lines (Completion / Partial / Blocked /
      System Defects Detected / `--dry-run`). Compress the System Defects Detected paragraph and
      keep its example table row; keep the "no task status was mutated" statement and the
      source-store remedy sentence.
- [ ] Tighten `## Error Handling`: keep all five bullets; compress wording only. The
      MAX_INFRA_FAILURES bullet must keep its "distinct from work-budget exhaustion
      (`cycle_count` unaffected)" clause.
- [ ] Tighten `### CHECKPOINT 1` and `### STAGE 2`: keep the permissive-gate statement, the
      terminal-states-only blocking list, the partial-with-no-handoff clause, both
      "IMMEDIATELY CONTINUE" directives, and the full STAGE 2 JSON delegation block. Compress
      surrounding narration.
- [ ] Leave `## Anti-Bypass Constraint` and `## Arguments` byte-identical.
- [ ] Measure. Record the exact final byte count. If it exceeds 8,000 B, state the number and
      name the sections that could not shrink further without cutting a listed semantic. Do not
      cut a listed semantic to reach the number.

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: interface

**Scope Hypothesis**: Decision 2's per-section budget table projects a ~9,200 B floor against an
8,000 B target. Both numbers are hypotheses. Confirm by measuring after each section's tightening
rather than only at the end, so the final report can attribute the overage (if any) to specific
sections instead of asserting a global impossibility.

**Files to modify**:
- `agent-system/extensions/core/commands/orchestrate.md` - Options `--hard` row and row
  compression; Constraints wording; CHECKPOINT 1 / STAGE 2 / CHECKPOINT 3 / Output /
  Error Handling tightening.

**Verification**:
- Every flag `parse-command-args.sh` exports that `/orchestrate` actually consumes has a row:
  `--lit, --dry-run, --allow-self-modifying, --allow-scope-collision, --continue-budget, --clean,
  --fast, --hard, --haiku, --sonnet, --opus, --fable, --research, --plan, --implement`. Check by
  diffing the table against the parser's export list.
- `grep -n 'single-task only\|Single-task only' commands/orchestrate.md` returns only the updated
  "per-task in the batch engine once the feature-port task lands" phrasing.
- `grep -n 'team' commands/orchestrate.md` returns nothing.
- Re-read every retained Options row and confirm its default column and meaning are unchanged.
- `wc -c commands/orchestrate.md` recorded; percentage reduction from 44,953 B computed.

---

### Phase 7: Deploy, full gate run, and acceptance evidence [NOT STARTED]

**Goal**: Prove the change is deployable and that every acceptance criterion holds, with the
known pre-existing failures distinguished from anything this task caused.

**Tasks**:

- [ ] Deploy the source store to `.claude/` through the sanctioned deploy path (never by hand-
      editing `.claude/**`).
- [ ] Run the full gate set (`verify-deploy.sh` and whatever else the postflight gate set
      invokes). Record every failure.
- [ ] Classify each failure against the known pre-existing list: gate3 index-entries `line_count`
      mismatches, gate10 unknown `state.json` entry fields `abandon_reason`/`blocks_note`,
      gate12 state-writer boundary in `test-force-phases.sh`, intermittent gate8 timing flake.
      Anything **not** on that list is caused by this task and must be fixed before the phase
      closes.
- [ ] Note that gate3's `line_count` for `commands/orchestrate.md` will legitimately change; if
      an index entry records the file's line count, regenerate it rather than leaving a stale
      value, and distinguish that from the pre-existing gate3 mismatches.
- [ ] Acceptance evidence, recorded in the summary:
      - before/after byte counts and the percentage reduction;
      - the flag-coverage diff showing every consumed flag is documented;
      - `/orchestrate --dry-run` with a single task number producing the report;
      - `/orchestrate --dry-run` with two task numbers producing the report;
      - the full gate run's green/known-failure classification.
- [ ] Confirm no file under `.claude/**` was hand-authored: `git status` shows source-store paths
      only (`.claude/` is gitignored and regenerated).

**Timing**: 1.0 hours

**Depends on**: 6

**Verification Tier**: full

**Files to modify**:
- None expected beyond regenerated index entries; any source-store fix required by a
  newly-introduced gate failure.

**Verification**:
- Deploy completes without error.
- Gate run shows only the four known pre-existing failure classes.
- Both `--dry-run` invocations produce reports.
- All acceptance evidence captured.

---

## Testing & Validation

- [ ] `wc -c agent-system/extensions/core/commands/orchestrate.md` before (44,953) and after,
      with the delta and percentage recorded.
- [ ] `grep -n 'MULTI-TASK DISPATCH\|Kahn' commands/orchestrate.md` returns nothing.
- [ ] Delegation-key set in the multi-task `Skill` invocation is byte-for-byte the same set as
      before, verified against SKILL.md Stage MT-1's read list.
- [ ] `grep -n '^### ' commands/orchestrate.md` shows the checkpoint order unchanged.
- [ ] The dry-run prohibition block is present and semantically unchanged; the short-circuit
      still calls `orchestrate-dry-run-report.sh`.
- [ ] `/orchestrate --dry-run N` and `/orchestrate --dry-run N,M` each produce the admission
      report and dispatch nothing.
- [ ] `grep -rn 'orchestrate\.md.*Step [0-9]' agent-system/extensions/core/` returns zero.
- [ ] `grep -rn 'orchestrate-batch-results-template' agent-system/extensions/core/skills/`
      returns a live Stage MT-5 caller.
- [ ] Options table covers every `/orchestrate`-consumed parser flag, `--hard` included; no
      `--team` rows.
- [ ] Full gate run green apart from the four documented pre-existing failure classes.

## Artifacts & Outputs

- `agent-system/extensions/core/commands/orchestrate.md` — slimmed (target <= 8,000 B; honest
  floor reported if exceeded).
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — new
  `### Batch Size Cap (MAX_TASKS)`; `### Commit Granularity` extended with the Exit-Path Coverage
  table and residue-check block.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-5 owns batch-results
  emission; ~14 pointer repoints; Stage MT-1 `waves` reclassified as a diagnostic echo.
- Six context/docs files and three scripts — cross-reference repoints (comment-only in the
  scripts).
- `specs/145_slim_orchestrate_command/summaries/01_*-summary.md` — with the before/after byte
  table, the flag-coverage diff, both dry-run transcripts, and the gate classification.

## Rollback/Contingency

Every phase is a single scoped commit against the source store; `.claude/` is a regenerated
deploy artifact and holds no state to unwind. To revert, `git revert` the phase commits in reverse
order and redeploy — Phases 1-3 are additive and safe to keep even if Phase 4 is reverted.

The one ordering hazard is reverting Phase 3 while Phase 4 stands: that would leave multi-task
runs with no output emitter. If Phase 4 has landed, revert Phase 4 first or not at all.

If Phase 4's compact STAGE 0 turns out to break live batch dispatch in a way the dry-run path
cannot reveal (the dry-run script is an independent reimplementation and will pass regardless),
restore the previous STAGE 0 body from git and re-derive the delegation-context builder from the
`Skill` invocation block alone — that block, not the surrounding narration, is the load-bearing
part.

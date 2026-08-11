# Implementation Plan: Clear Failing Gates and Reconcile Ledgers

- **Task**: 47 - Clear the two failing verification gates and reconcile the defect/review ledgers against reality
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/047_clear_failing_gates_and_reconcile_ledgers/reports/01_clear-failing-gates-and-reconcile-ledgers.md
- **Artifacts**: plans/01_clear-gates-reconcile-ledgers.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Three independent bookkeeping items, all already caught by existing validators and all verified
against the current tree by the research report: (1) the `state.json` duplicate `project_number`
is already resolved and needs re-verification only, (2) the doc-lint gate fails on 2 core
`line_count` mismatches plus 1 unregistered context file, and (3) two ledgers (`specs/errors.json`,
`specs/reviews/state.json`) have drifted from reality. No design work is required. Definition of
done is the task's stated acceptance: `verify-deploy.sh --findings` reports 23/23,
`validate-state.sh --deep` exits 0 with zero FAIL findings, no `errors.json` entry is marked
unfixed whose defect is demonstrably fixed (each closure carrying its own recorded evidence), and
`specs/reviews/state.json` lists every review report on disk.

### Research Integration

The research report supersedes the task description on three points, and this plan is built on the
report:

- **Item 1 is already fixed** by commit `4c4c59ef7` (duplicate 41 renumbered to 51,
  `next_project_number` advanced to 52); `validate-state.sh --deep` already reports 15/0/0. Phase 1
  is therefore verification-only, with no `state.json` write of any kind.
- **Only 2 `line_count` mismatches remain, not 3.** The literature entry
  (`project/literature/domain/literature-index.md`, 117 -> 144) was already corrected in commit
  `7822f50cb`. The two live mismatches are both in core.
- **Only 2 review reports are missing from `reviews/state.json`, not 3.** The
  `review-2026-08-11-refactor-completion-and-efficiency` entry the description treats as missing is
  already present and correct.

The report also supplies the drafted index-entry JSON (Phase 3), the per-entry closure evidence
(Phase 5), the `lock_session_self_contention` caveat (Phase 6), the extracted per-review severity
data and recomputed statistics (Phase 7), and the postflight-automation finding that
`errors-append.sh update` already supports closure but has zero callers (Phase 8).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (`roadmap_path` not provided in the delegation context).

## Goals & Non-Goals

**Goals**:
- `bash .claude/scripts/verify-deploy.sh --findings` reports 23/23 with zero gate-3 findings.
- `bash .claude/scripts/validate-state.sh --deep` exits 0 with zero FAIL findings.
- Every `errors.json` entry demonstrably fixed in the current tree is closed, each with its own
  recorded closing evidence; nothing is mass-closed.
- `specs/reviews/state.json` registers all 6 on-disk review reports with a recomputed `statistics`
  block.
- The postflight auto-closure question is answered in writing as a recommendation, not built.

**Non-Goals**:
- Deciding the declared-vs-deployed parity question, or resolving the 4 orphan files present in the
  live tree but absent from a clean regenerate. That belongs to the existing
  `resolve_deploy_orphan_file_parity` task. The missing index entry handled here is the inverse
  case (source present, registration absent) and is a one-line addition, not a parity decision.
- Closing `deploy_ghost_index_entries` or any other `errors.json` entry not independently verified
  fixed in this task.
- Building postflight auto-closure automation (wiring `errors-append.sh update` into a lifecycle
  hook). Recording the reasoning is in scope; implementing it is not.
- Any edit under `.claude/**`. The source store is `agent-system/extensions/**`; the only sanctioned
  way for `.claude/**` to change is the deploy in Phase 4.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Source-store-only index edit leaves gate 3 red, because Rule S checks the DEPLOYED `.claude/context/index.json` | H | H | Phase 4 is a mandatory redeploy phase gated on Phases 2 and 3; the acceptance check runs only after it |
| A redeploy removes the 4 out-of-scope orphan files, silently absorbing the excluded parity work | H | M | Phase 4 uses `deploy-headless.sh` DEFAULT mode only, which the script's own header documents as "Never destructive; never removes anything". `--wipe` is FORBIDDEN by this plan |
| Closing an `errors.json` entry that is not actually fixed | H | L | Only the 3 entries carrying direct evidence (regex text match; two green test-suite runs) close in Phase 5, each with its evidence recorded. `lock_session_self_contention` is adjudicated separately in Phase 6 and may legitimately stay open |
| Inventing an `errors.json` evidence field the schema does not declare | M | M | `errors-schema.json` declares no evidence property and `errors-append.sh update` mutates only `fix_status`/`fixed_date`/`fix_task`. Evidence is recorded in the task summary and commit messages instead; see Phase 5 |
| Inventing severity numbers for `review-2026-07-29`, which has no severity taxonomy in its own text | M | M | Phase 7 records `0/0/0/0` with the reasoning written down, per the report's option (a); no number is invented without being labeled as a choice |
| Hand-rolled `jq` read-modify-write on `specs/state.json` | H | L | No phase writes `state.json` for this task's items. Any lifecycle status write goes through `scripts/state-write.sh` / `update-task-status.sh` |
| Deploy invoked as an unsanctioned automated caller of `deploy-headless.sh` | M | M | Phase 4 records its authorization rationale explicitly (the deploy IS the declared operation of that phase, deliberately invoked and logged, not a silent side effect of an unrelated one) and states that it sets no precedent |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 5, 7 | -- |
| 2 | 3, 6 | 2 (for 3), 5 (for 6) |
| 3 | 4 | 2, 3 |
| 4 | 8 | 1, 4, 6, 7 |

Phases within the same wave can execute in parallel.

**Territory** (file ownership, to keep wave-1 parallelism safe):
- Phases 2, 3: `agent-system/extensions/core/index-entries.json`
- Phases 5, 6: `specs/errors.json`
- Phase 7: `specs/reviews/state.json`
- Phase 4: the deployed `.claude/` tree (no source-store writes)
- Phases 1, 8: read-only plus the summary artifact

---

### Phase 1: Re-verify state.json duplicate resolution [COMPLETED]

**Goal**: Confirm item 1 needs no fix, producing the evidence the acceptance criterion requires.

**Tasks**:
- [x] Run `bash .claude/scripts/validate-state.sh --deep` and capture full output. *(completed)*
- [x] Confirm exit code 0 and zero FAIL findings. *(completed: 15/0/0)*
- [x] Confirm the specific `--deep` check "All active_projects[].project_number values are unique"
      passes, and that the TODO.md-in-sync check passes. *(completed: both PASS)*
- [x] Record the passed/warning/failed counts verbatim for the summary. *(completed: Passed 15, Warnings 0, Failed 0)*

**Timing**: 0.2 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- None. This phase is verification-only.

**Verification**:
- `validate-state.sh --deep` exits 0 with zero FAIL findings.
- If any FAIL appears, STOP and report rather than editing `state.json` ad hoc — any remediation
  must route through `scripts/state-write.sh`, never a hand-rolled `jq` read-modify-write.

---

### Phase 2: Correct the two core line_count mismatches [COMPLETED]

**Goal**: Bring `agent-system/extensions/core/index-entries.json` `line_count` values back in sync
with the files on disk.

**Tasks**:
- [x] Run `bash .claude/scripts/generate-context-line-counts.sh --check` and capture the finding
      list before any edit. *(completed)*
- [x] Confirm the mismatch set is exactly the two core entries named in the Scope Hypothesis.
      *(completed: exact match)*
- [x] Run `bash .claude/scripts/generate-context-line-counts.sh --write`. *(completed: 2 changed)*
- [x] Re-run `--check` and confirm zero numeric mismatches across all extensions. *(completed: 483
      exact, 0 mismatch)*
- [x] Inspect `git diff agent-system/extensions/core/index-entries.json` and confirm the diff
      touches only `line_count` values. *(completed: the working tree also carried an unrelated
      pre-existing uncommitted stray edit to a third entry, `patterns/mcp-server-ownership.md`
      (183 -> 298), belonging to the separate in-flight task rewriting that document — that
      task's status is `[implementing]` in state.json. That change is also a `line_count`-only
      value, verified correct against `wc -l`, but it is out of this task's scope and was staged
      and committed separately from this task's two entries via a hand-crafted 2-hunk patch
      applied with `git apply --cached`, deliberately bypassing `git-commit-scoped.sh`'s
      whole-file `git add` because it cannot stage at hunk granularity — see the Phase 2 progress
      file's `approaches_tried` for the full reasoning. The stray edit remains uncommitted in the
      working tree, untouched by this task.)*

**Timing**: 0.3 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Exactly 2 `line_count` mismatches remain, both in core:
`architecture/context-layers.md` (declared 134, actual 194) and `patterns/context-discovery.md`
(declared 375, actual 379). Confirm by reading the pre-edit `--check` output rather than assuming;
if `--write` changes any entry outside this set, record the extra changes in the summary instead of
silently accepting them.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - two `line_count` values corrected by the
  script

**Verification**:
- `generate-context-line-counts.sh --check` reports 0 numeric mismatches, 0 null, 0 missing source.
- `git diff` shows only `line_count` numeric changes.

---

### Phase 3: Register the missing context/standards index entry [COMPLETED]

**Goal**: Add the one missing source index entry for
`context/standards/task-reference-exemptions.md`, clearing the Rule S failure at its source.

**Tasks**:
- [x] Confirm the file has no entry anywhere: search `index-entries.json` across all extensions for
      `task-reference-exemptions`. *(completed: zero hits)*
- [x] Confirm the file's actual line count with `wc -l` and use that value, not the report's.
      *(completed: 103, matches report)*
- [x] Add the entry to `agent-system/extensions/core/index-entries.json`, modeled on the
      neighboring `subdomain: "standards"` entries and on the `architecture/context-layers.md` /
      `patterns/context-discovery.md` shape (`on_demand: true`, empty `load_when`), since this doc
      is loaded via plain backticked reference rather than an eager import or a command hook.
      *(completed)*
- [x] Place the entry in the file's existing ordering convention for `standards/` entries.
      *(completed: the first 16 `standards/` entries are alphabetical, but the 3 most recently
      added — `git-staging-scope.md`, `orchestrator-runtime-files.md`,
      `context-tier-semantics.md` — are appended out of alpha order at the end of the block,
      establishing an append-at-end convention for new entries; the new entry follows that
      convention, appended immediately after `context-tier-semantics.md`, the last entry in the
      file)*
- [x] Validate the file parses: `jq empty agent-system/extensions/core/index-entries.json`.
      *(completed)*
- [x] Re-run `generate-context-line-counts.sh --check` and confirm the new entry reports an exact
      match (0 mismatch, 0 missing source). *(completed: 484 entries, 484 exact, 0 mismatch)*

**Timing**: 0.4 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: Exactly 1 context file is present on disk but registered in no
`index-entries.json` (`context/standards/task-reference-exemptions.md`, ~103 lines). Confirm the
count by re-running `check-extension-docs.sh` and counting Rule S failures before editing; if more
than one Rule S failure of this shape exists, handle only the ones that are the inverse case
(source present, registration absent) and record any others as out of scope — the orphan direction
(registered but no source) belongs to the separate parity task.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - one new entry appended in the `standards`
  subdomain

**Verification**:
- `jq empty` succeeds on the edited file.
- The entry's `line_count` matches `wc -l` exactly under `--check`.
- Rule S will still report a failure until Phase 4 deploys; that is expected here, not a defect.

---

### Phase 4: Redeploy and clear the doc-lint gate [COMPLETED]

**Goal**: Propagate the Phase 2 and Phase 3 source-store edits into the deployed
`.claude/context/index.json` so Rule S and gate 3 actually clear, then confirm 23/23.

**Tasks**:
- [x] Run the NON-DESTRUCTIVE deploy: `bash .claude/scripts/deploy-headless.sh` (default mode, no
      flag). Do NOT pass `--wipe`. *(completed: no `--wipe` used)*
- [x] Capture the reported artifact/extension counts. *(completed: "Resynced 6 extension(s)")*
- [x] Confirm `.claude/context/index.json` now contains the `standards/task-reference-exemptions.md`
      entry and the two corrected `line_count` values. *(completed: entry present; 194 and 379
      confirmed)*
- [x] Run `bash .claude/scripts/check-extension-docs.sh` and confirm zero Rule S failures.
      *(completed: all extensions PASS, "PASS: all extensions OK")*
- [x] Run `bash .claude/scripts/verify-deploy.sh --findings` and confirm 23/23 with zero FINDING
      lines. *(completed: "[verify-deploy] PASS -- 23 check(s), 0 failure(s)")*
- [x] Confirm the 4 out-of-scope orphan files are still present in the live tree (the default deploy
      mode removes nothing); record this explicitly so the excluded parity work is demonstrably
      untouched. *(completed: all 4 confirmed present —
      `context/orchestration/orchestration-validation.md`,
      `context/orchestration/subagent-validation.md`, `docs/architecture/architecture-spec.md`,
      `docs/README.md`)*
- [x] Record the deploy authorization rationale in the summary: this invocation is the declared
      purpose of this phase, explicitly and deliberately made, with its output logged — not a
      silent side effect of an unrelated operation — and it sets no precedent for any other
      automated call site. *(completed: see implementation summary)*

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Scope Hypothesis**: `verify-deploy.sh --findings` currently reports 22/23 with exactly 3 gate-3
findings and no other gate affected. Re-run it BEFORE deploying to confirm the 22/23 baseline and
the exact finding set; if any gate other than 3 is red at baseline, that is out of this task's
scope and must be reported rather than fixed here. *(Observed: the 22/23 count matched exactly,
and only gate 3 was red, but the exact finding set was 1 FINDING line — the Rule S entry for
`task-reference-exemptions.md` — not 3. The 2 `line_count` mismatches from Phase 2 never
surfaced as separate gate-3 FINDING lines even before that phase landed; Rule S only enumerates
missing/orphaned index entries, not line_count numeric drift. This is a narrower-than-estimated
finding set, not a scope violation — no gate other than 3 was red.)*

**Files to modify**:
- The deployed `.claude/` tree (regenerated from the source store; no hand-authored writes)

**Verification**:
- `verify-deploy.sh --findings` reports 23/23.
- `check-extension-docs.sh` exits 0.
- The orphan files named in the excluded parity task are still present.

---

### Phase 5: Close the three verified-fixed errors.json entries [COMPLETED]

**Goal**: Mark exactly the three entries with direct evidence as fixed, each closure carrying its
own recorded evidence.

**Tasks**:
- [x] Re-confirm each entry's fix independently before closing it (do not close on the report's
      say-so alone):
      - `hook_regex_defect` (`err_1786349061492_XpY38x`): read
        `agent-system/extensions/core/hooks/validate-handoff-location.sh` and confirm the regex uses
        the `{3,}` quantifier, which matches 4+-digit task directories. *(completed: line 65 uses
        `[0-9]{3,}`)*
      - `test_suite_deployed_mode_failures` (`err_1786368358319_8jwcdo`) and
        `test_suite_failure_undocumented` (`err_1786350581305_8cNAZ7`): run
        `bash agent-system/extensions/core/scripts/tests/run-all.sh` and
        `bash .claude/scripts/tests/run-all.sh`, and confirm 0 failed in both. Record the actual
        counts observed, not the report's figures. *(completed: source-store 39 passed, 0 failed,
        39 total; deployed 38 passed, 0 failed, 38 total)*
- [x] Close each entry individually via
      `bash .claude/scripts/errors-append.sh update --id <ID> --fix-status fixed --fix-task 47
      --fixed-date <ISO8601>`. One invocation per entry — no batch/mass close. *(completed: 3
      separate invocations)*
- [x] Record the per-entry closing evidence. `errors-schema.json` declares no evidence property and
      `errors-append.sh update` mutates only `fix_status`/`fixed_date`/`fix_task`, so DO NOT invent
      an evidence field in `errors.json`. Record evidence in the implementation summary as a table
      (`id` / `type` / `evidence` / `command run` / `observed output`) and echo the one-line
      evidence in each phase commit message. *(completed: table in summary, evidence in commit
      message)*
- [x] Confirm `jq empty specs/errors.json` still parses and that only the 3 intended records
      changed (`git diff specs/errors.json`). *(completed: valid JSON, exactly 3 hunks changed)*

**Timing**: 0.6 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Exactly 3 `errors.json` entries close in this phase. Confirm by listing all
`fix_status: "unfixed"` entries before editing and checking the diff after: any entry closed beyond
these 3 is an over-close and must be reverted.

**Files to modify**:
- `specs/errors.json` - three records transition to `fix_status: fixed` with `fixed_date` and
  `fix_task`

**Verification**:
- `jq '[.errors[] | select(.fix_status == "fixed")] | length' specs/errors.json` increases by
  exactly 3.
- Each closed record has `fix_task: 47` and a populated `fixed_date`.
- The summary contains one evidence row per closed entry.

---

### Phase 6: Adjudicate lock_session_self_contention [COMPLETED]

**Goal**: Independently decide whether `lock_session_self_contention`
(`err_1786349061524_pY97cE`) may be closed, and record the reasoning either way.

**Tasks**:
- [x] Read the full MT-1 / MT-3 / MT-4 call chain in
      `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` and trace every
      `task-lock.sh acquire` / `release` / `session-register` call site. *(completed: traced
      session-register at line 1418, orchestrate-batch-admit.sh --session-id at line 1628,
      acquire at line 1960, dispatch session_id at line 2009, release at line 2395,
      session-release at line 2545)*
- [x] Confirm whether the acquire argument, the release argument, and the batch registration all
      use the bare `$session_id` consistently (the reported fix), with no remaining
      `${session_id}_${task_num}` suffixed form on any of the three. *(completed: all 6 traced
      call sites use the bare `$session_id`; the SKILL.md text itself carries explicit invariant
      comments at lines 1963-1968 and 2397-2398 documenting the bare-value requirement)*
- [x] Decide:
      - If the trace is consistent end to end, close the entry with
        `errors-append.sh update --id err_1786349061524_pY97cE --fix-status fixed --fix-task 47`
        and record the traced call sites as the evidence. *(completed: DECISION = CLOSED — trace
        is consistent end to end)*
      - If any inconsistency or unreadable path remains, LEAVE THE ENTRY OPEN and record why. An
        open entry here is a valid outcome, not a phase failure — the acceptance criterion only
        forbids leaving unfixed an entry that is *demonstrably* fixed.
- [x] Do not execute a live multi-task `/orchestrate` dispatch to test this; it is out of scope and
      flagged as risky. Textual tracing is the sanctioned confirmation method for this phase.
      *(completed: no live dispatch executed, textual tracing only)*
- [x] Record the decision and its basis in the summary. *(completed: see implementation summary)*

**Timing**: 0.4 hours

**Depends on**: 5

**Verification Tier**: local

**Files to modify**:
- `specs/errors.json` - conditionally, one record, only if the trace confirms the fix

**Verification**:
- The summary states the decision (closed / left open) and names the call sites traced.
- If closed, the record carries `fix_task: 47` and a `fixed_date`.
- No other `errors.json` record changed in this phase.

---

### Phase 7: Register the missing review reports and refresh statistics [COMPLETED]

**Goal**: Make `specs/reviews/state.json` list every review report present on disk, with a
recomputed `statistics` block.

**Tasks**:
- [x] Enumerate `specs/reviews/*.md` on disk and diff against the `review_id`s already registered.
      *(completed: 6 on disk, 4 registered, exactly 2 missing — matches Scope Hypothesis)*
- [x] Add an entry for `review-2026-07-29-agent-system.md` using the existing entry shape
      (`review_id`, `date`, `scope`, `report_path`, `summary` with
      `files_reviewed`/`critical_issues`/`high_issues`/`medium_issues`/`low_issues`, `tasks_created`,
      `registries_updated`). Set `tasks_created: []` — the review's own Section 3 states its proposed
      meta tasks were "for user review — none created". *(completed; `files_reviewed: 0`, following
      the precedent set by the already-registered `review-2026-08-11` entry for a similarly
      non-diff-based qualitative review)*
- [x] For that review's severity counts, record `0/0/0/0` and write the reasoning down explicitly:
      the report contains no critical/high/medium/low taxonomy in its own text (it uses root-cause
      and wave/task framing), so zeros record "no severity triage performed", not "no issues found".
      Do not invent counts. Capture this reasoning in the commit message and the summary.
      *(completed)*
- [x] Add an entry for `review-2026-08-10-agent-system-refactor-capstone.md` with severities taken
      from its own Section 7 defect ledger: critical 1, high 2, medium 5, low 1 (the tenth,
      `delegation_interrupted`, is unclassified/historical and is excluded from the counts), and
      `tasks_created: [1007, 1008, 1009, 1010, 1011]` — stale pre-vault-reset numbers preserved
      verbatim, consistent with how the already-registered entries preserve their own historical
      numbers. *(completed)*
- [x] Recompute `statistics`: `total_reviews: 6`; `last_review: "2026-08-11"` (unchanged);
      `total_issues_found` = 32 + 0 + 9 = 41; `total_tasks_created` = 9 + 0 + 5 = 14. Re-derive each
      figure from the file rather than trusting these numbers. *(completed: independently
      re-derived via jq sums over the final file — 6 reviews, 41 issues, 14 tasks, exact match)*
- [x] Update `_last_updated` to the current ISO8601 timestamp. *(completed: 2026-08-11T22:32:00Z)*
- [x] Confirm `jq empty specs/reviews/state.json` parses and entries stay ordered by date.
      *(completed: valid JSON; entries were initially appended out of date order (08-11 preceding
      07-29/08-10) and were re-sorted into strict date order as a follow-up correction)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Exactly 2 on-disk review reports are unregistered
(`review-2026-07-29-agent-system.md`, `review-2026-08-10-agent-system-refactor-capstone.md`), and
6 reports exist on disk in total. Confirm by listing `specs/reviews/*.md` and comparing against
`jq -r '.reviews[].review_id'` before editing; the recomputed statistics figures (41, 14) are
likewise hypotheses to be re-derived from the actual per-entry sums after the additions land.

**Files to modify**:
- `specs/reviews/state.json` - two new entries plus a recomputed `statistics` block and
  `_last_updated`

**Verification**:
- Every file matching `specs/reviews/review-*.md` has a corresponding `report_path` in
  `state.json`.
- `total_reviews` equals the on-disk report count.
- `total_issues_found` and `total_tasks_created` equal the sums of the per-entry values.

---

### Phase 8: Record postflight-automation reasoning and run final acceptance [NOT STARTED]

**Goal**: Answer the postflight auto-closure question in writing (without building it) and verify
every acceptance criterion in one pass.

**Tasks**:
- [ ] Confirm the finding before recording it: `grep -rn "errors-append.sh update"` across
      `agent-system/extensions/` and confirm the only matches are the script's own usage/doc
      comments (zero real callers).
- [ ] Write the postflight-automation recommendation into the implementation summary: full semantic
      matching between "a change landed" and "which entry it fixes" requires judgment and is not
      cheaply automatable; the narrow, cheap partial automation is that `errors-append.sh update`
      already supports `--fix-status fixed --fix-task N` and has zero callers, so a future task
      could let a plan or phase declare which error ids it resolves and have postflight invoke the
      existing subcommand when that field is present and the phase's verification passed. Flag that
      this needs a schema decision and is deliberately not built here.
- [ ] Run the full acceptance set and capture output:
      - `bash .claude/scripts/verify-deploy.sh --findings` -> 23/23
      - `bash .claude/scripts/validate-state.sh --deep` -> exit 0, zero FAIL
      - `jq '[.errors[] | select(.fix_status == "unfixed")] | .[].id' specs/errors.json` -> review
        the remaining list and confirm none is demonstrably fixed by this task's evidence
      - review-report registration completeness check from Phase 7
- [ ] Write the implementation summary at
      `specs/047_clear_failing_gates_and_reconcile_ledgers/summaries/01_clear-gates-reconcile-ledgers-summary.md`,
      including the per-entry closing-evidence table (Phase 5), the Phase 6 decision, the Phase 7
      severity-choice reasoning, the Phase 4 deploy rationale, and this recommendation.
- [ ] Confirm no file under `.claude/**` was hand-authored: `git status` plus a review of the
      phase-by-phase modified-file list.

**Timing**: 0.5 hours

**Depends on**: 1, 4, 6, 7

**Verification Tier**: full

**Files to modify**:
- `specs/047_clear_failing_gates_and_reconcile_ledgers/summaries/01_clear-gates-reconcile-ledgers-summary.md`
  - new summary artifact

**Verification**:
- All four acceptance criteria pass and their outputs are quoted in the summary.
- The summary contains the postflight-automation recommendation and every recorded decision.

---

## Testing & Validation

- [ ] `bash .claude/scripts/validate-state.sh --deep` exits 0 with zero FAIL findings.
- [ ] `bash .claude/scripts/generate-context-line-counts.sh --check` reports 0 numeric mismatches,
      0 null, 0 missing source across all extensions.
- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0 with zero Rule S failures.
- [ ] `bash .claude/scripts/verify-deploy.sh --findings` reports 23/23 with zero FINDING lines.
- [ ] `jq empty` succeeds on `agent-system/extensions/core/index-entries.json`, `specs/errors.json`,
      and `specs/reviews/state.json`.
- [ ] Every `specs/reviews/review-*.md` file has a matching entry in `specs/reviews/state.json`, and
      `statistics` equals the recomputed per-entry sums.
- [ ] No `errors.json` entry remains `unfixed` whose defect this task demonstrated fixed, and each
      closure has a recorded evidence row in the summary.
- [ ] `git status` shows no hand-authored file under `.claude/**` (deploy-regenerated files only).

## Artifacts & Outputs

- `specs/047_clear_failing_gates_and_reconcile_ledgers/plans/01_clear-gates-reconcile-ledgers.md`
  (this file)
- `specs/047_clear_failing_gates_and_reconcile_ledgers/summaries/01_clear-gates-reconcile-ledgers-summary.md`
- Modified: `agent-system/extensions/core/index-entries.json` (2 corrected `line_count` values,
  1 new entry)
- Modified: `specs/errors.json` (3 closures, plus at most 1 conditional closure from Phase 6)
- Modified: `specs/reviews/state.json` (2 new entries, recomputed `statistics`)
- Regenerated: the deployed `.claude/` tree (Phase 4, non-destructive mode)

## Rollback/Contingency

- All source-store and `specs/**` edits are small, git-tracked, and per-phase committed, so any
  single phase reverts with `git revert` of its own commit.
- `.claude/` is gitignored and disposable: re-running `bash .claude/scripts/deploy-headless.sh`
  (default mode) restores it from whatever the source store currently holds. Never use `--wipe` as
  a rollback mechanism in this task — it would delete the out-of-scope orphan files and absorb work
  this task explicitly excludes.
- If Phase 4's redeploy leaves any gate other than 3 red, stop and report rather than fixing
  forward into adjacent scope; the task boundary excludes the parity question.
- If a Phase 5 closure is later found premature, reopen with
  `errors-append.sh update --id <ID> --fix-status unfixed` rather than editing `specs/errors.json`
  by hand.

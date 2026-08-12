# Implementation Plan: Task #56

- **Task**: 56 - LEVER 3 of the context-cost work (command bodies): slim todo.md and orchestrate.md
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None blocking (state.json lists `dependencies: [48]`, an auto-added
  file-scope-overlap edge consulted only for multi-task wave assignment; research confirmed it is
  not an ordering directive and does not gate this single-task dispatch)
- **Research Inputs**: specs/056_slim_todo_and_orchestrate_command_bodies/reports/01_command-body-region-extraction.md
- **Artifacts**: plans/01_command-body-extraction.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two reference regions currently inflate command bodies that are loaded in full on every
invocation: `## Notes` in `commands/todo.md` (7,851 B, lines 1028-EOF) and the
`## Batch Orchestrate Results` fenced output template in `commands/orchestrate.md` (6,648 B, lines
555-691). Move each verbatim into a new `context/patterns/` file, replace it in the command body
with an imperative follow-this-pointer instruction, repoint the one internal cross-reference that
points into the extracted `## Notes` region, and register both destination files in
`index-entries.json`. Definition of done: both command bodies measurably smaller, existing tests
pass unmodified, and every extracted region is reachable from the command body by a pointer an
executing agent is explicitly told to follow — verified by an end-to-end read of each resulting
command body, not assumed.

### Research Integration

Key findings carried into this plan:
- Both regions re-measured byte-exact against the audit figures; no drift. Region boundaries:
  `todo.md` lines 1028-1195 (EOF), `orchestrate.md` lines 555-691 (fence content).
- `todo.md` line 148 contains the only internal cross-reference pointing INTO the extracted
  region ("per the jq/shell escaping guidance in the Notes section"). Repointing it is a required
  edit, not optional cleanup — leaving it is the silent-deletion failure mode.
- `orchestrate.md` has no second internal pointer into its region; only the Step 5 call site
  immediately above the fence becomes the pointer.
- No test or lint greps literal text out of either region. `test-session-runtime-files.sh` greps
  `orchestrate.md` only in Step 5 (Commit Reconciliation, ~lines 425-434);
  `lint-state-writer-boundary.sh` allowlists `todo.md` for a pattern in Step 5.7.4 (~line 866).
  Both sit outside the extraction regions, so tests pass unmodified *provided the diff stays
  strictly inside the two named regions plus their call-site pointer text*.
- The `orchestrate.md` self-modification admission gate is multi-task-only; a solo dispatch does
  not trip it, and editing the source store mid-loop does not change the already-loaded prompt.
- Sibling task premise (slimming `commands/task.md`) independently verified and REJECTED:
  `task.md` is 37,465 B, the smallest of the three, with ~0-1 KB of extractable material and no
  `## Notes`-style or output-template-style region. Recommendation is to drop that task, recording
  the reason. Phase 6 records this; no phase acts on that task's scope.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied in the delegation context; no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Remove 7,851 B from `commands/todo.md` and 6,648 B from `commands/orchestrate.md` per-invocation
  body cost, relocating the content verbatim (not paraphrased) to `context/patterns/`.
- Preserve 100% of behavior: every relocated region reachable by an imperative
  "read this file now" instruction at the point of need.
- Repoint the one internal cross-reference at `todo.md` line ~148.
- Register both new context files so the discovery index reflects them.
- Report measured before/after bytes for both command files.

**Non-Goals**:
- Any edit to `commands/task.md` or to the sibling task that proposes slimming it. The
  recommendation is recorded in the summary only.
- Any edit at the `git commit -m` call sites (`todo.md` Step 6) — that is the scoped-commit
  propagation work's territory.
- Any edit to `.claude/**` (deploy artifact) or any deploy/regeneration run.
- Rewriting, condensing, or improving the relocated content. It moves verbatim; editorial
  improvement is a separate concern and would break the "no behavior lost" acceptance property.
- Touching `orchestrate.md` Step 5 (Commit Reconciliation, ~lines 420-534) or `todo.md`
  Step 5.7 (~lines 811-937) — the two test/lint-load-bearing zones.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Line-148 cross-reference left saying "the Notes section" after the section is gone | H | M | Phase 2 makes the repoint an explicit checklist item; Phase 5's end-to-end read re-checks that zero occurrences of "Notes section" / "see Notes" remain in `todo.md` |
| `## Batch Orchestrate Results` template paraphrased instead of moved verbatim, losing the nine interleaved per-section "rendered only when X" gating rules | H | M | Phase 3 requires a byte-comparison of the moved fence content against the original; the pointer must say the template MUST be followed exactly |
| Diff creeps into `orchestrate.md` Step 5 or `todo.md` Step 5.7, breaking `test-session-runtime-files.sh` Case 2 or `lint-state-writer-boundary.sh` | H | L | Phase 1 records a green test baseline; Phase 5 re-runs the same suite; the plan names both zones as explicit no-touch territory |
| A pointer is written as a passive "see also" rather than an imperative instruction, silently degrading it into a deletion | H | M | Acceptance-critical property; Phase 5 reads each command body end to end as an executing agent and asserts each pointer is imperative and sited at the moment of need |
| New context files omitted from `index-entries.json`, or `line_count` wrong | M | M | Phase 4 registers both and runs `test-index-entries-schema.sh` / `validate-context-index.sh` |
| Task-number references leak into the new `context/patterns/` files or command bodies | M | L | Phase 5 runs the repo-wide task-reference lint; the write-time hook is a second layer |
| Edits accidentally targeted at `.claude/**` instead of the source store | H | L | Every phase's file list names `agent-system/extensions/core/**` paths only; source-store rule restated as a MUST NOT below |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel. Phases 2 and 3 touch disjoint command files
and create disjoint destination files, so they are genuinely parallelizable; if run sequentially
instead, order does not matter. Neither may touch `index-entries.json` — that edit is serialized
into Phase 4 precisely so the two cannot collide on it.

### Phase 1: Baseline measurement and green test baseline [COMPLETED]

**Goal**: Establish the before-state numbers the acceptance criterion requires, and confirm the
test suite is green BEFORE any edit, so any later failure is attributable to this work rather than
inherited.

**Tasks**:
- [ ] Record `wc -c` for `agent-system/extensions/core/commands/todo.md` and
      `agent-system/extensions/core/commands/orchestrate.md`. Expected 49,254 B and 43,180 B;
      if either differs, record the actual value and use it as the baseline (do not assume).
- [ ] Re-confirm both region boundaries before cutting: `grep -n '^## Notes' commands/todo.md`
      (expect 1028) with EOF at 1195; and locate the ` ```markdown ` fence opening
      `## Batch Orchestrate Results` in `commands/orchestrate.md` (expect 555) and its closing
      fence (expect 691). Record the actual line numbers found.
- [ ] Measure each region exactly: `awk '/^## Notes/{flag=1} flag' commands/todo.md | wc -c` and
      `sed -n '{start},{end}p' commands/orchestrate.md | wc -c`.
- [ ] Run the existing test suite unmodified and record the result:
      `bash agent-system/extensions/core/scripts/tests/run-all.sh`, plus
      `bash agent-system/extensions/core/scripts/test-session-runtime-files.sh` and
      `bash agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` explicitly
      (the two files research identified as content-dependent on the target command files).
- [ ] Note any test that is ALREADY failing before any edit. A pre-existing failure is not caused
      by this work and must not be silently attributed to it — record it in the baseline so
      Phase 5 can compare like for like.
- [ ] Write the baseline numbers into the scratchpad or the task directory so Phase 5 and Phase 6
      can cite them without re-deriving.

**Timing**: 25 minutes

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: The plan asserts `todo.md` = 49,254 B / `## Notes` at line 1028-1195 /
7,851 B, and `orchestrate.md` = 43,180 B / fence at 555-691 / 6,648 B, and that the test suite is
currently green. All five are hypotheses from a prior research pass. Confirm each by direct
measurement in this phase before any edit; if a figure differs, use the measured value and note
the drift rather than proceeding on the stale number.

**Files to modify**: none (measurement only)

**Verification**:
- Before-bytes for both command files recorded as concrete numbers.
- Both region boundary line numbers confirmed by grep, not assumed.
- Test suite run completed with per-test pass/fail recorded, including any pre-existing failure.

---

### Phase 2: Extract `todo.md` `## Notes` and repoint the internal cross-reference [COMPLETED]

**Goal**: Move the `## Notes` reference material out of the `/todo` command body into a new
`context/patterns/` file, leaving behind an imperative instruction to read it, and fix the one
cross-reference that pointed into the moved region.

**Tasks**:
- [x] Create `agent-system/extensions/core/context/patterns/todo-archival-reference.md` containing
      the five subsections **verbatim** from `todo.md`'s `## Notes`: `### Task Archival`,
      `### Orphan Tracking`, `### Misplaced Directories`, `### Roadmap Updates`,
      `### jq Pattern Safety (Issue #1132)`. Promote each `###` to the destination file's own
      heading level as needed and add a one-paragraph opening stating what the file is and which
      command consumes it. Do not condense, reword, or "improve" any subsection. *(completed:
      byte-diff confirmed verbatim content, only whitespace/heading-level differs)*
- [x] Delete lines 1028-EOF from `commands/todo.md` and replace them with a short imperative
      pointer block. It MUST be phrased as an instruction to act on, e.g.:
      "**Reference material**: the archival-status definitions, orphan and misplaced-directory
      categories, roadmap annotation formats and safety rules, and jq/shell escaping rules that
      Steps 2.5, 2.6, 3, and 5.5 depend on live in
      `.claude/context/patterns/todo-archival-reference.md`. READ that file before executing any
      of those steps." Not "see also", not "for more detail". *(completed: pointer uses this exact
      wording)*
- [x] Repoint the cross-reference at `commands/todo.md` line ~148 (Step 3, subtasks-defer guard).
      Replace "per the jq/shell escaping guidance in the Notes section" with an explicit pointer
      the agent is told to follow — point it at
      `.claude/context/patterns/jq-escaping-workarounds.md`, which already carries this guidance
      in full, and keep the "(never `!=`)" clause. Confirm the line number by grepping for
      `the Notes section` rather than trusting 148. *(completed: line 148 repointed to
      jq-escaping-workarounds.md, "never !=" clause retained)*
- [x] Grep `commands/todo.md` for any remaining `Notes section`, `see Notes`, `in the Notes`, or
      `## Notes` occurrence and confirm zero remain (other than the new pointer block's own
      wording, if it retains a `## Notes` heading). *(completed: grep returns zero occurrences)*
- [x] Use the `.claude/context/patterns/...` deployed-path form in the pointer. Both that form and
      the bare `context/patterns/...` form appear in these files; the deployed-path form is the
      one an executing agent can open without ambiguity. Confirm the chosen form against existing
      references in the same file before writing. *(completed: both forms confirmed present in
      todo.md/orchestrate.md; deployed-path form used per plan directive)*
- [x] Confirm the new file and the edited region contain no task-number references (deliverable
      rule) and no emojis. *(completed: check-task-references.sh and emoji grep both clean)*

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exactly one internal cross-reference points into the
extracted region (`todo.md` line ~148) and exactly five subsections comprise `## Notes`. Confirm
at implementation time by `grep -n 'Notes section\|see Notes\|in the Notes' commands/todo.md` over
the whole file and by enumerating `###` headings between line 1028 and EOF; if either count
differs from the hypothesis, handle every occurrence found, not just the predicted one.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/todo-archival-reference.md` - new file, receives
  the verbatim `## Notes` content
- `agent-system/extensions/core/commands/todo.md` - remove lines 1028-EOF, add imperative pointer
  block, repoint the line-~148 cross-reference

**Verification**:
- `wc -c commands/todo.md` shows a reduction close to 7,851 B minus the pointer block's size.
- Byte/line spot-check that the destination file's subsection content matches the original
  (e.g. diff the extracted region against the destination body ignoring the added preamble).
- Zero stale "Notes section" references remain in `commands/todo.md`.
- `commands/todo.md` Step 5.7 (~lines 811-937) and Step 6 (~lines 938-964) are untouched in the
  diff — confirm with `git diff` hunk ranges.

---

### Phase 3: Extract `orchestrate.md` batch-results output template [COMPLETED]

**Goal**: Move the `## Batch Orchestrate Results` fenced template out of the `/orchestrate`
command body — where it is needed only on the multi-task path — into a new `context/patterns/`
file, replacing it with an imperative must-follow-exactly pointer at the Step 5 call site.

**Tasks**:
- [x] Create
      `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md`
      containing the fence content from `commands/orchestrate.md` lines 555-691 **verbatim**,
      including all nine `###`-level subsections (ZERO DISPATCH, Succeeded, Failed, Skipped,
      Deferred (self-modifying), Deferred (other admission exclusions), Deferred (redeploy
      checkpoint), Pre-Existing Deploy-Verify Failures (Not Deferred), System Defects Detected,
      Next Steps) and every interleaved "rendered only when X" / "populated from Y" gating rule.
      Preserve the content inside a markdown fence so the template remains copy-exact, and add a
      short preamble naming which command and which step consumes it. *(completed: direct count
      found 10 `###` subsections, not nine as hypothesized — the plan's own enumerated list
      already names all 10, including "Next Steps"; all 10 included verbatim, byte-diff confirmed)*
- [x] Delete the fence (and the now-orphaned `**Consolidated Output**:` label if it reads better
      folded into the pointer) from `commands/orchestrate.md` and replace it with an imperative
      pointer, e.g.: "**Consolidated Output**: READ
      `.claude/context/patterns/orchestrate-batch-results-template.md` now and emit the batch
      results using that template. The template MUST be followed exactly — its per-section
      rendering conditions are part of the contract, not commentary." *(completed: pointer uses
      this exact wording, folded into the Consolidated Output label)*
- [x] Preserve everything surrounding the fence unchanged: the "Re-run sequence derivation" note
      immediately above, and the "**After consolidated output, STOP. Do not continue to CHECKPOINT
      1.**" line immediately below. Both are decision logic and stay inline. *(completed: both
      confirmed present and unchanged around the new pointer)*
- [x] Confirm nothing else in `commands/orchestrate.md` refers to the extracted block by name
      (`grep -n 'Batch Orchestrate Results\|Consolidated Output' commands/orchestrate.md`).
      *(completed: only the Step 5 heading (line 420, unrelated wording), the {validated_count}
      cross-reference note (line 503, inside the no-touch zone, unchanged), and the new pointer
      itself (line 553) match)*
- [x] Confirm the diff does not touch Step 5 Commit Reconciliation (~lines 420-534), which
      `test-session-runtime-files.sh` Case 2 greps for `file_session_id` and
      `mt_state_file_valid`. *(completed: single diff hunk starts at line 553; file_session_id/
      mt_state_file_valid at lines 428-435 untouched)*
- [x] Confirm the new file contains no task-number references and no emojis. *(completed:
      check-task-references.sh and emoji grep both clean)*

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts the fence spans lines 555-691 (6,648 B), contains nine
`###`-level subsections, and that no other site in `orchestrate.md` references the block by name.
Confirm by locating the fence delimiters directly, counting `###` headings inside them, and
running the name grep over the whole file; use the measured boundaries, not the asserted ones.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - new
  file, receives the verbatim template
- `agent-system/extensions/core/commands/orchestrate.md` - remove the fence, add the imperative
  must-follow-exactly pointer at the Step 5 call site

**Verification**:
- `wc -c commands/orchestrate.md` shows a reduction close to 6,648 B minus the pointer's size.
- The destination file's template content byte-matches the original fence content (diff-verified,
  not eyeballed).
- `git diff` hunk ranges confirm Step 5 Commit Reconciliation is untouched.
- The "STOP. Do not continue to CHECKPOINT 1." instruction still immediately follows the pointer.

---

### Phase 4: Register both destination files in the context index [NOT STARTED]

**Goal**: Make both new `context/patterns/` files discoverable through the same mechanism their
sibling pattern files use, so the extraction is a relocation within the system rather than a move
to an unindexed corner.

**Tasks**:
- [ ] Add an entry to `agent-system/extensions/core/index-entries.json` (under `.entries`) for
      `patterns/todo-archival-reference.md`: `domain: "core"`, `subdomain: "patterns"`, a
      one-line `summary`, accurate `line_count`, `keywords`, `topics`, and
      `load_when: {agents: [], task_types: [], commands: ["/todo"]}` — matching the shape of the
      existing `patterns/roadmap-update.md` entry.
- [ ] Add the parallel entry for `patterns/orchestrate-batch-results-template.md` with
      `load_when: {agents: [], task_types: [], commands: ["/orchestrate"]}` — matching the
      existing `patterns/batch-orchestration-guardrails.md` entry.
- [ ] Compute `line_count` from the actual written files (`wc -l`), do not estimate.
- [ ] Check whether `agent-system/extensions/core/manifest.json` needs an edit. Investigation
      during planning found `provides.context` lists the `patterns` directory wholesale rather
      than individual files, so new files under `patterns/` should already deploy without a
      manifest change. Confirm this by inspecting `.provides.context` before deciding; edit the
      manifest only if the confirmation fails.
- [ ] Run `bash agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh` and
      `bash agent-system/extensions/core/scripts/validate-context-index.sh`.
- [ ] Run `bash agent-system/extensions/core/scripts/tests/test-double-loading-check.sh` — the
      empty-`agents[]`-with-populated-`commands[]` shape is the "direct command, not
      agent-dispatched" case its Case 2 covers, so this should pass.

**Timing**: 30 minutes

**Depends on**: 2, 3

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exactly two new index entries are required and that
`manifest.json` needs no change (because `provides.context` names the `patterns` directory, not
individual files). Confirm the manifest claim by reading `.provides.context` directly before
skipping the manifest edit; confirm the entry count matches the number of files actually created
in Phases 2-3.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - two new entries
- `agent-system/extensions/core/manifest.json` - only if the directory-level `provides.context`
  confirmation fails

**Verification**:
- `jq '.entries[] | select((.path//"") | test("todo-archival-reference|orchestrate-batch-results-template"))' index-entries.json`
  returns both entries with correct `load_when` shapes.
- `test-index-entries-schema.sh` and `validate-context-index.sh` pass.

---

### Phase 5: Acceptance verification — re-measure, re-run tests, end-to-end pointer read [NOT STARTED]

**Goal**: Prove the three acceptance properties: measured before/after bytes reported, existing
tests pass unmodified, and every extracted region is reachable by an explicit follow-this-pointer
instruction — the last one verified by actually reading each command body end to end as an
executing agent would, not by assuming it from the diff.

**Tasks**:
- [ ] Re-measure: `wc -c` both command files; compute absolute and percentage deltas against the
      Phase 1 baseline. Also record the sizes of both new `context/patterns/` files, so the
      accounting shows content relocated rather than lost.
- [ ] Re-run the identical test set from Phase 1, **unmodified**:
      `scripts/tests/run-all.sh`, `scripts/test-session-runtime-files.sh`,
      `scripts/lint/lint-state-writer-boundary.sh`. Compare per-test results against the Phase 1
      baseline. Any test modified to make it pass invalidates the acceptance criterion — if a test
      genuinely must change, stop and report rather than editing it.
- [ ] Run `bash agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh` and the
      repo-wide task-reference lint (`check-task-references.sh`) to confirm no task-number
      references leaked into the new deliverable files.
- [ ] **END-TO-END READ (explicit, not assumed) — `commands/todo.md`**: read the resulting file
      from first line to last, in order, as the agent executing `/todo` would. At each step that
      previously relied on `## Notes` content (Steps 2.5, 2.6, 3, 5.5, and the jq-classification
      guidance in Step 3), confirm the executing agent is told, in imperative form, to read a
      named file, and that the named file exists and contains the needed content. Record the
      per-step confirmation as a list, not a single "verified" claim.
- [ ] **END-TO-END READ (explicit, not assumed) — `commands/orchestrate.md`**: read the resulting
      file from first line to last, in order, following the MULTI-TASK DISPATCH path through to
      Step 5. Confirm the executing agent reaches an imperative instruction to read the batch
      results template file, that the instruction states the template must be followed exactly,
      and that the STOP instruction still follows it. Record the confirmation explicitly.
- [ ] For each of the two pointers, apply the passive/imperative test: would an agent reading only
      the command body know it is REQUIRED to open the referenced file at that moment? If the
      wording admits "see also" reading, rewrite it before closing this phase.
- [ ] Confirm no file under `.claude/**` was written by this work
      (`git status --short` shows only `agent-system/**` and `specs/**` paths).

**Timing**: 45 minutes

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the Phase 1 test set is the complete relevant gate and
that the expected deltas are roughly -7.6 KB (`todo.md`) and -6.4 KB (`orchestrate.md`) after
pointer text. Confirm by running the full `run-all.sh` suite (not a hand-picked subset) and by
reporting the actual measured deltas, whatever they turn out to be.

**Files to modify**: none (verification only; corrective edits to pointer wording are permitted
and expected if the imperative test fails)

**Verification**:
- Before/after byte table produced for both command files, plus sizes of both new files.
- Every test that passed at Phase 1 passes now, with no test file modified
  (`git diff --stat` shows zero changes under `scripts/`).
- A per-step written record of the two end-to-end reads exists, naming each consuming step and
  the pointer that serves it.

---

### Phase 6: Summary with measurement table and recorded sibling-task recommendation [NOT STARTED]

**Goal**: Produce the implementation summary carrying the acceptance evidence and the explicit,
recorded recommendation about the standing sibling task — so the decision is on the record rather
than silently inherited.

**Tasks**:
- [ ] Write `specs/056_slim_todo_and_orchestrate_command_bodies/summaries/01_command-body-extraction-summary.md`
      per `summary-format.md`.
- [ ] Include the before/after measurement table from Phase 5: per-file before bytes, after bytes,
      absolute delta, percentage delta, plus the size of each new `context/patterns/` file, with a
      line stating total content relocated vs. total content removed (these should reconcile).
- [ ] Include the test result: which suite was run, that it was run unmodified, and the
      before/after comparison.
- [ ] Include the per-step pointer-reachability record from Phase 5's two end-to-end reads.
- [ ] **Record the sibling-task recommendation explicitly**: research independently verified and
      REJECTED the premise behind the standing proposal to slim `commands/task.md` as "the largest
      per-invocation context contributor". Measured, `task.md` is 37,465 B — the *smallest* of the
      three command files (`todo.md` 49,254 B, `orchestrate.md` 43,180 B) — and it is procedural
      and mode-specific throughout, already citing standards by pointer rather than restating
      them, with roughly 0-1 KB of extractable material and no `## Notes`-style appendix or
      standalone output template. Recommendation: **drop that task rather than re-pointing it**;
      re-pointing it at `todo.md`/`orchestrate.md` is redundant because this work already covers
      both. Note the one caveat: if the original concern was actually about `task.md`'s *imported*
      context chain rather than its command body, that is a different lever (import-chain
      trimming) needing a freshly scoped task, not a repoint of the existing one.
- [ ] State explicitly in the summary that no action was taken on that other task's scope — only
      the recommendation is recorded.
- [ ] Note the residual finding for future readers: `orchestrate.md` is on the
      orchestrator-critical-path inclusion table, so a future `/orchestrate` batch that
      co-dispatches this file's editors alongside another task may defer on the self-modification
      admission gate; solo dispatch is unaffected.
- [ ] Confirm the summary contains no emojis, and that task-number references appear only inside
      `specs/**` (which the summary is).

**Timing**: 30 minutes

**Depends on**: 5

**Verification Tier**: prose

**Files to modify**:
- `specs/056_slim_todo_and_orchestrate_command_bodies/summaries/01_command-body-extraction-summary.md` - new

**Verification**:
- Summary contains a populated before/after byte table with real measured numbers, not the
  planning-time estimates.
- Summary contains the sibling-task recommendation verbatim in substance, with the "drop it"
  verdict and both supporting grounds stated.
- Summary states no action was taken on the other task's scope.

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` passes, run unmodified, with
      results matching the Phase 1 baseline.
- [ ] `bash agent-system/extensions/core/scripts/test-session-runtime-files.sh` passes (Case 2
      greps `orchestrate.md` Step 5, which must be untouched).
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` passes
      (allowlists `todo.md` Step 5.7.4, which must be untouched).
- [ ] `bash agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh` passes.
- [ ] `bash agent-system/extensions/core/scripts/validate-context-index.sh` passes.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-double-loading-check.sh` passes.
- [ ] Repo-wide task-reference lint passes (no task numbers outside `specs/**`).
- [ ] `git diff --stat` shows zero modifications under `agent-system/extensions/core/scripts/`.
- [ ] `git status --short` shows zero writes under `.claude/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/todo-archival-reference.md` (new, ~7.9 KB)
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` (new,
  ~6.7 KB)
- `agent-system/extensions/core/commands/todo.md` (modified, expected ~41.7 KB)
- `agent-system/extensions/core/commands/orchestrate.md` (modified, expected ~36.8 KB)
- `agent-system/extensions/core/index-entries.json` (modified, two new entries)
- `specs/056_slim_todo_and_orchestrate_command_bodies/plans/01_command-body-extraction.md` (this
  file)
- `specs/056_slim_todo_and_orchestrate_command_bodies/summaries/01_command-body-extraction-summary.md`

## Constraints (binding)

**MUST NOT**:
- Write to any path under `.claude/**`. That tree is a disposable deploy artifact regenerated from
  `agent-system/extensions/**`; a hand-authored file there is silently wiped. Edit
  `agent-system/extensions/core/**` only.
- Run any deploy or regeneration step. Regeneration is manual-only outside the sanctioned
  multi-task orchestration call site.
- Modify any file under `agent-system/extensions/core/scripts/` — the acceptance criterion is that
  existing tests pass *unmodified*.
- Touch `commands/orchestrate.md` Step 5 Commit Reconciliation (~420-534) or `commands/todo.md`
  Step 5.7 (~811-937) / Step 6 (~938-964).
- Edit `commands/task.md` or act on the sibling task's scope in any way.
- Introduce task-number references into any file outside `specs/**`.
- Paraphrase, condense, or improve relocated content. It moves verbatim.

## Rollback/Contingency

All edits are confined to five files in the source store plus two new files, all tracked by git and
committed per phase. To revert: `git revert` the phase commits in reverse order, or for a single
phase, restore the two touched files from the pre-phase commit. Because the two new
`context/patterns/` files are additions and the command-body edits are deletions plus a small
pointer insertion, a partial rollback (e.g. reverting only the `orchestrate.md` extraction while
keeping the `todo.md` one) is clean — Phases 2 and 3 are independent by construction, and Phase 4's
index entries can be trimmed to match whichever extraction survives. If the end-to-end read in
Phase 5 finds a pointer that cannot be made adequately imperative without restoring inline content,
restore that specific region inline and record the exception rather than shipping a degraded
pointer.

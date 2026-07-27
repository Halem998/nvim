# Research Report: Task #917

**Task**: 917 - Converge single-task /orchestrate partial triage onto the mt engine
**Started**: 2026-07-27T15:03:00Z
**Completed**: 2026-07-27T15:45:00Z
**Effort**: Medium (multi-file coordinated edit, two explicit decisions, one test-suite update)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh`,
  `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
  `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh`,
  `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh`,
  `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`,
  `agent-system/extensions/core/docs/architecture/handoff-schema.md`,
  `agent-system/extensions/core/commands/orchestrate.md`,
  `specs/901_orchestrate_dry_run_admission_report/tests/test-triage-classify.sh`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md, no-task-references-in-deliverables.md

## Executive Summary

- All facts in the task description were independently re-verified by reading the SOURCE-STORE
  copies (`agent-system/extensions/core/**`, not `.claude/**`). Every cited line number and quote
  matches. This is a convergence task, not a new design: `docs/architecture/orchestrate-state-machine.md`
  line 29 already documents the target behavior (`partial (no handoff, cycle limit)` exits only at
  `cycle_count >= MAX_CYCLES`); the classifier and `SKILL.md` Stage 4 currently exit unconditionally
  instead.
- The fix requires **no new bounding mechanism**. Stage 4's outer loop (`while [ "$cycle_count" -lt
  "$MAX_CYCLES" ]`, SKILL.md line 211) and Stage 7's existing `MAX_CYCLES reached` exit (line
  907-913) already provide exactly the bound Decision G asks to "confirm" — once the unconditional
  `EXIT` at line 432 is replaced with an implement dispatch, a task that makes no progress simply
  keeps cycling until the pre-existing MAX_CYCLES exit fires. No new counter, no new gate.
- Six files need coordinated edits (A-H map onto exactly these): the classifier script (code +
  header table), `SKILL.md` Stage 4 (partial sub-state) and Stage MT-4 (phase-grouping table), the
  dry-run reporter (exclusion arm + header comment), the state-machine doc, and — found during this
  research, **not named in the task's file_scope** — a test file,
  `specs/901_orchestrate_dry_run_admission_report/tests/test-triage-classify.sh`, which contains an
  assertion (`THE DIVERGENCE`, lines 74/85/131-138) that explicitly expects task-fixture 955's
  `partial`-with-neither row to classify as `implement` under `mt` and `exit_partial` under
  `single`. This test will fail after change (A) and must be updated in the same commit; recommend
  the plan add it to file_scope even though it lives under a `specs/` tree from a different task.
- Decision 1 (the `blocked` row): the codebase already independently implements the "leading
  hypothesis" — single-task Stage 4's `blocked` handler (SKILL.md lines 435-445) unconditionally
  escalates to blocker resolution (matching `needs_human`), with no reference anywhere to skipping.
  This is corroborating evidence the divergence is intentional, not a copy of the same defect
  pattern as the `partial` row. Recommend: keep the divergence, but document it explicitly (the
  classifier header table already states it as a bare fact with no justification — that omission is
  what needs fixing, not the behavior).
- Decision 2 (`exit_partial` schema value fate): no external consumer other than this repo's own
  `orchestrate-triage-classify.sh` / `orchestrate-dry-run-report.sh` was found referencing the
  literal string `exit_partial` (grep across the whole repo, excluding `.git`, found only the three
  in-scope files plus this task's own state.json description). Recommend **explicitly reserving**
  `exit_partial` in the schema doc/header as "defined but currently unreachable — kept for schema
  stability and any future engine/mode that still wants an exit-without-dispatch verdict," rather
  than a version bump; there are zero external readers to break, so retiring the string outright
  would be safe too, but reserving it is lower-risk and the task's own wording ("choose between
  retaining it as an explicitly-reserved value and versioning the schema") treats reservation as the
  lighter-weight of the two acceptable outcomes.

## Context & Scope

Task 917 asks to remove a structural defect in `/orchestrate`'s single-task engine: a task left
`[PARTIAL]` by a base-mode (non-hard) research/plan/implement dispatch has, by construction, no
`.orchestrator-handoff.json` (base-mode writers never write one — confirmed at
`docs/architecture/handoff-schema.md` lines 239-246). The single-task triage path currently treats
that normal "no handoff, no blockers" case as a permanent dead end (`exit_partial`), while the
multi-task (`mt`) engine, given the literal same task in the literal same state, dispatches
`implement`. This research task's job was to re-verify every factual claim in the task description
against the SOURCE-STORE files (never `.claude/**`), enumerate every file/line that needs to change,
and produce recommendations on the two explicitly-undecided sub-questions (Decision 1: `blocked` row;
Decision 2: `exit_partial` schema fate) for `/plan` to consume.

**Binding constraint reaffirmed**: all edits target `agent-system/extensions/core/**`. This task's
own `state.json` entry already lists `file_scope` restricted to that tree (`orchestrate-triage-classify.sh`,
`skills/skill-orchestrate/SKILL.md`, `docs/architecture/orchestrate-state-machine.md`,
`commands/orchestrate.md`, `orchestrate-dry-run-report.sh`) — confirmed correct except for the
missing test file noted above.

## Findings

### Codebase Patterns — exact locations for each scope item

**A. `orchestrate-triage-classify.sh` engine fork** (`agent-system/extensions/core/scripts/orchestrate-triage-classify.sh`)
- Line 246: `((if $engine == "mt" then "implement" else "exit_partial" end)) as $grp |` — the fork to
  remove. Target: both engines resolve to `"implement"` unconditionally for this row (i.e. replace
  the conditional with a literal `"implement"`, or collapse the `if` entirely).
- Line 249-250: the `reason` string's `(if $engine == "mt" then "mt routes to implement" else
  "single exits partial" end)` branch must also be flattened to a single engine-agnostic reason
  (something like `"is partial with neither continuation nor blockers; routes to implement"`).
- `handoff_state` computation at line 248 (`if $hstate == "absent" then "absent" else "empty" end`)
  is untouched by this change — it does not reference `$engine`.

**B. `SKILL.md` Stage 4 partial sub-state** (`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`)
- Lines 369-376: the "Cross-reference" paragraph asserting the two engines are "intentionally
  different" / "diverge by design" and citing the (now-superseded, untraceable — see Appendix)
  "Decision D1 in this task's originating plan" must be deleted per the task's explicit instruction.
- Lines 427-433: the "Sub-state: no handoff, no blockers" branch currently is:
  ```
  echo "[orchestrate] Task $task_number in partial state with no continuation and no blockers."
  echo "Cycle $cycle_count/$MAX_CYCLES consumed. Run /orchestrate $task_number to retry or /implement $task_number for manual resume."
  EXIT (partial, cycle_count)
  ```
  This must become a dispatch, structurally mirroring the adjacent "Sub-state: continuation
  available" branch immediately above it (lines 387-421: `skill_preflight_update` to
  `"implement"`, reset `dispatch_start_ts`/`dispatch_was_transport_error`, invoke the Agent tool
  with `$IMPLEMENT_AGENT`, then fall into the shared Stage 5 handoff-read). The one substantive
  difference: resume context comes from `scripts/orchestrate-recover-outcome.sh` (called against
  `$TASK_DIR` and the **prior** dispatch's `.return-meta.json`, since Stage 4 runs *before* this
  cycle's dispatch — there is no current-cycle `dispatch_start_ts` window yet) rather than from a
  handoff's `continuation_context`. See "Recommendations" below for the specific call shape and the
  `window_start_ts` argument question this raises (a genuinely new use of that script — its two
  existing call sites, Stage 5 and Stage MT-4 step 1, are both strictly post-dispatch).
- The removal of the unconditional `EXIT (partial, cycle_count)` means this row now naturally falls
  under the outer `while` loop's own bound (line 211: `while [ "$cycle_count" -lt "$MAX_CYCLES" ]`)
  and Stage 7's existing `If MAX_CYCLES reached` exit (lines 907-913) — no new bounding logic is
  needed (Decision/Scope item G is satisfied by *not adding* a second, redundant guard).

**C. Classifier header verdict table** (`agent-system/extensions/core/scripts/orchestrate-triage-classify.sh`)
- Lines 12-23 (the "Two-engine rationale" paragraph) must be rewritten: it currently states the
  `partial`-with-neither row is "the one row where the two engines genuinely diverge" and that "this
  script transcribes both engines verbatim rather than picking a winner" — both now false for that
  row. The paragraph should instead state that engines are unified except for the `blocked` row
  (Decision 1), and reference the resolution of Decision D1 as historical context, not live
  rationale.
- Lines 52-63 (the verbatim engine table) — the `partial, neither` row's `single group` column
  changes from `exit_partial` to `implement`. The `blocked` row is addressed by Decision 1 below
  (recommend: keep as-is, but the surrounding prose must state the justification, not just the
  bare table entry).
- Lines 72-73 (`group` field enum documentation: "One of: research, plan, implement, needs_human,
  exit_partial, skip, terminal") — must be updated per Decision 2 (recommend: keep `exit_partial`
  listed, but annotate it as reserved/currently-unreachable rather than silently leaving it looking
  live).

**D. Stage MT-4 phase-grouping table** (`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`)
- Lines 1192-1205: this table is already correct for the `mt` engine (`partial` with no handoff ->
  `implement_tasks`, line 1204) — it needs no row change, only re-confirmation that it still matches
  the classifier post-fix (it already did, since `mt` was never the divergent side). The three
  tables that "must agree at the end of this task" per scope item D are: (1) the classifier's own
  header table (C above), (2) Stage 4's single-task prose (B above, now converged with mt), (3) this
  MT-4 table (already correct, unchanged). Recommend a short explicit note in this table's preamble
  (already present at lines 1192-1194 stating "the table and the script MUST be changed together")
  gets extended to say all three artifacts, not just the script+this-table pair, given B's cross
  reference removal.

**E. Dry-run reporter lockstep edit** (`agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh`)
- Line 55 (header, item 7 of "Composition"): `` `needs_human` and `exit_partial` become exclusions ``
  — needs rewording once `exit_partial` can no longer be emitted by the `partial`-with-neither row
  (it remains schema-reserved per Decision 2, so the wording should say it is excluded *if ever
  emitted*, or simply drop the mention if the decision is to fully retire it operationally while
  reserving only the string).
- Lines 403-405 (the `case "$group" in ... exit_partial)` arm): this exclusion arm becomes dead code
  once the classifier stops emitting `exit_partial` for the reachable case. Recommend keeping the
  `case` arm (cheap defensive code, consistent with reserving the schema value in Decision 2) but
  rewording its message so it no longer claims "single-task engine exits partial rather than
  dispatching" (now false) — e.g. "handoff-triage exit_partial (reserved verdict value; not expected
  to be emitted post-convergence — treated as excluded defensively)".
- No occurrences of `exit_partial` exist in the "Report sections" documentation block (lines 59-70)
  or elsewhere in the file beyond these two spots — confirmed by grep.

**F. State-machine doc** (`agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`)
- Line 29 is **already correct** and is the target, not the thing to change: `` `partial` (no
  handoff, cycle limit) | `cycle_count >= MAX_CYCLES` | Report state, exit | — | — ``. Per the
  task's finding 6, no wording change is needed to this row itself. What *does* need a small
  addition: the row currently reads as if "no handoff" alone were an action-taking condition; after
  the fix, "no handoff, no blockers" alone routes to dispatch (row 25/26's `implement` action), and
  only "no handoff, no blockers, AND cycle_count >= MAX_CYCLES" exits. Recommend either (a) leave
  row 29 as the natural fallthrough once row 25/26-style dispatch is added as an explicit `partial`
  (no handoff, no blockers, cycles remain) row, or (b) add one clarifying sentence beneath the table
  (near lines 36-44, which already annotate the table with implementation-detail prose) stating that
  the no-handoff/no-blockers sub-state now dispatches `implement` on every cycle where budget
  remains, and only the generic MAX_CYCLES-exhausted exit (row 29) terminates it — making explicit
  that row 29 is reached via the *same* generic end-of-cycle check already covering every other
  non-terminating row, not a dedicated early exit.

**G. MAX_CYCLES bound confirmation** — see the "no new bounding logic is needed" note under B above.
`MAX_CYCLES=5` (SKILL.md line 124). The existing `while` loop condition plus the Stage 7 exit at
lines 907-913 are the sole and sufficient bound; this scope item is satisfied by verification, not
new code. Recommend the plan record this as an explicit verification step (e.g., a manual/dry-run
trace of a task that starts `partial`/no-handoff/no-blockers and never produces a new handoff or
`.return-meta.json` success, confirming it cycles exactly `MAX_CYCLES` times then exits) rather than
a code change.

**H. `commands/orchestrate.md` entry-point contract language** (`agent-system/extensions/core/commands/orchestrate.md`)
- Lines 451-456 (CHECKPOINT 1 "Permissive gate" prose) are **already accurate as a target
  post-fix** claim — the defect this task fixes is precisely what made the claim false today. No
  weakening/tightening of this prose is needed; if anything the fix makes it newly true rather than
  requiring correction. Recommend either no change, or (optional, low-priority) a one-line
  strengthening such as a footnote confirming partial-with-no-handoff is now included in "all
  non-terminal states" without exception, to close the loop for a future reader auditing this claim
  against the code the way this task's diagnosis did.

### Additional finding: test file outside declared file_scope

`specs/901_orchestrate_dry_run_admission_report/tests/test-triage-classify.sh` contains a named
assertion for exactly the divergence being removed:
```
[955]="implement"       # partial, neither -> mt
[955]="exit_partial"    # partial, neither -> single (THE DIVERGENCE)
...
if [ "$div_mt" = "implement" ] && [ "$div_single" = "exit_partial" ]; then
  pass "3. engine divergence: task 955 (partial, neither) is 'implement' under mt and 'exit_partial' under single"
```
This test will fail immediately after change (A) lands and is a live regression check, not
documentation — grep confirmed no other repo location references `exit_partial` outside the five
files already in this task's `file_scope` plus this test file. `specs/901.../tests/test-dry-run-report.sh`
(sibling file, same directory) was also checked and does **not** reference `exit_partial` — no
change needed there. Recommend the plan explicitly add
`specs/901_orchestrate_dry_run_admission_report/tests/test-triage-classify.sh` to file_scope (it is
technically outside `agent-system/extensions/core/`, but the no-task-references rule's exception
list explicitly permits `specs/**`, and this is a test-suite maintenance edit, not a new deliverable
— rewording its assertion to expect convergence rather than divergence, and renaming the
"THE DIVERGENCE" case label/comments accordingly).

### External Resources

Not applicable — this is a pure codebase-consistency task with no external library/API surface.
All research was internal codebase exploration (Glob/Grep/Read across
`agent-system/extensions/core/**` and `specs/**`).

## Decisions

### Decision 1 — the `blocked` row (mt: `skip`, single: `needs_human`)

**Finding**: This divergence is *already independently corroborated* elsewhere in the live code,
unlike the `partial` row (which had no such corroboration — Stage 4's old prose simply asserted
"intentionally different" with a dangling citation to an untraceable historical plan). Specifically:
- `orchestrate-triage-classify.sh` line 60: `blocked | skip | needs_human`.
- `SKILL.md` Stage 4's `#### State: blocked` handler (lines 435-445) contains **no engine
  conditional at all** — for single-task invocations it unconditionally reads blockers from
  `state.json` and invokes blocker escalation (Stage 6), i.e. it always behaves as `needs_human`.
  There is no code path in the single-task engine that would ever skip a blocked task.
- Stage MT-4's phase-grouping table (line 1205) folds `blocked` into the generic `skip` row
  alongside `researching`/`planning`/unknown — batch mode genuinely wants to let sibling tasks
  proceed rather than stall the whole batch on one blocked task, which single-task mode has no
  concept of (there are no siblings).

**Recommendation**: Confirm the task's own "leading hypothesis" as the decision — **keep the
divergence**, since it reflects a real semantic difference (solo vs. batch has no analogue to
"skip and let siblings continue"), and it is already how the live single-task handler behaves
(changing it to `skip` would be a *behavior regression* introducing a new defect, not a fix). The
actionable gap is documentation, not behavior: the classifier's header table today states the row as
a bare fact with zero justification (unlike scope item A's row, which at least had a — as it turns
out unconvincing — rationale paragraph). Add a short justification sentence next to the `blocked`
row in the header table and in Stage 4's `blocked` handler (a short comment, not a whole
cross-reference paragraph like the one being deleted from the `partial` row) stating: "solo
invocations have no sibling to make progress on, so escalation is the only meaningful action;
batch invocations skip to let siblings proceed." This closes the "undocumented divergence" gap the
task explicitly calls out as unacceptable, without changing behavior.

### Decision 2 — fate of `exit_partial` in the `orchestrate-triage-v1` schema

**Finding**: `exit_partial` is enumerated in the classifier's own header doc-comment (line 72) as
one of seven possible `group` values, and is a literal string emitted only by the one row being
converged (line 246) — after fix (A), no code path can produce it. A repo-wide grep (excluding
`.git`) found the string in exactly: the classifier itself (header + code, 3 files' worth of lines
already cataloged in Findings above), the dry-run reporter (header + case arm), the `SKILL.md`
cross-reference being deleted, and the test file. No consumer outside this repo's own `.claude`/
`agent-system` tooling was found — there is no external API contract or third-party reader of this
NDJSON schema (it is produced and consumed entirely within this repo's own orchestration tooling,
per the classifier's own header: "Verdict schema (pinned as 'orchestrate-triage-v1'...)" — "pinned"
here documents stability intent, not an external SLA).

**Recommendation**: **Retain `exit_partial` as an explicitly-reserved value**, not a schema version
bump. Rationale: (1) a version bump (`orchestrate-triage-v2`) would be pure churn given zero
external consumers and zero remaining callers of the value — it buys nothing a doc comment doesn't;
(2) retiring the string outright is defensible but slightly riskier for no benefit, since some
future engine or mode change might legitimately want an "exit without dispatching" verdict distinct
from `skip`/`needs_human`/`terminal`, and having the string already defined avoids re-deriving its
exact semantics later; (3) the task's own phrasing treats "retain as reserved" and "version the
schema" as the two acceptable outcomes and explicitly rules out only the third, silent option
(leaving a dead value undocumented) — reservation is the lower-cost of the two acceptable choices.
Concretely: update the header's `group` field doc (line 72-77) to mark `exit_partial` as "(reserved;
not currently emitted by any row post-convergence — kept for schema stability, available to a future
row/engine)", and leave the dry-run reporter's defensive `case` arm in place (per Finding E above)
rather than deleting it.

## Risks & Mitigations

- **Risk**: Stage 4's new implement-dispatch sub-state, sourcing resume context from
  `orchestrate-recover-outcome.sh` against a *prior* (not current-cycle) `.return-meta.json`, is a
  genuinely new call shape for that script (its two existing callers are strictly post-dispatch,
  using the current cycle's `dispatch_start_ts` as the freshness window). Passing a `window_start_ts`
  of `0` (or omitting a meaningful window) at Stage 4 disables the staleness gate for this read,
  which is intentional (we want the last dispatch's leftover state regardless of age) but is a
  deviation from every other call site's fail-closed-on-staleness posture. **Mitigation**: the plan
  should explicitly document why staleness gating is inapplicable at Stage 4 (there is no "this
  dispatch's window" yet — that's the entire reason for consulting the *prior* dispatch's state),
  and should NOT reuse the variable name `dispatch_start_ts` for this read (that name is
  semantically "the current dispatch's window start" everywhere else in the file) — use a distinct
  name (e.g. `prior_meta_probe_window`) to avoid a future reader assuming it is bound the same way.
- **Risk**: Repeated no-progress cycling (a genuinely stuck base-mode partial task) will now spend up
  to `MAX_CYCLES` (5) real Agent-tool dispatches before exiting, versus the old behavior of exiting
  immediately on cycle 1. This is more tool-call cost per stuck task, which is the correct trade-off
  per the task's acceptance criterion but worth flagging as an expected, intentional cost increase
  for the genuinely-stuck case (not a regression — it is the entire point of the fix for the
  non-stuck, resumable case).
- **Risk**: The test file identified in Findings is outside `agent-system/extensions/core/**` and
  outside this task's declared `file_scope`. **Mitigation**: flagged explicitly above; recommend
  `/plan` add it to file_scope rather than discovering the failure only at verification time.

## Context Extension Recommendations

None. This is a meta task operating entirely within already-well-documented territory
(`docs/architecture/handoff-schema.md`, `docs/architecture/orchestrate-state-machine.md`, and the
classifier/SKILL.md's own extensive inline documentation already cover this area in detail — the
defect was a code/doc divergence, not a documentation gap).

## Appendix

### Search queries / exploration used
- `find agent-system -iname "orchestrate-triage-classify.sh"` / `-recover-outcome.sh` /
  `-dry-run-report.sh` — located source-store copies.
- `grep -n "Stage 4|Sub-state|no handoff, no blockers|intentionally different|diverge by design|exit_partial|MAX_CYCLES|cycle_count|Stage MT-4|Phase grouping" skills/skill-orchestrate/SKILL.md`
- `grep -rn "orchestrate-triage-v1|exit_partial" agent-system/extensions/core/` — confirmed full
  extent of the schema value's usage within the source store.
- `grep -rln "orchestrate-triage-classify|exit_partial" .` (repo-wide, excluding `.git`) — confirmed
  no consumers outside `agent-system/extensions/core/**` and the two `specs/901.../tests/*.sh` /
  `specs/913.../` history files (the latter are historical artifacts referencing the mechanism, not
  live callers).
- `grep -rn "Decision D1|originating plan"` — confirmed the "originating plan" cited by the current
  Stage 4 cross-reference and the classifier header is not traceable in the current doc tree (likely
  archived/vaulted from an earlier task number that has since been renumbered or archived) — this is
  additional support for the task's framing that "the divergence was never actually decided" in any
  currently-recoverable sense.
- Read in full or in relevant part: `orchestrate-triage-classify.sh` (all 272 lines),
  `orchestrate-recover-outcome.sh` (all 163 lines), `SKILL.md` lines 200-260, 340-480, 895-945,
  1160-1240, `orchestrate-dry-run-report.sh` lines 1-70, 370-428, `orchestrate-state-machine.md`
  lines 1-60, `commands/orchestrate.md` lines 440-480, `handoff-schema.md` lines 225-300.
- `specs/901_orchestrate_dry_run_admission_report/tests/test-triage-classify.sh` — grepped for
  `exit_partial` and engine-divergence assertions; found the "THE DIVERGENCE" test case (lines 74,
  85, 131-138) that will need updating.

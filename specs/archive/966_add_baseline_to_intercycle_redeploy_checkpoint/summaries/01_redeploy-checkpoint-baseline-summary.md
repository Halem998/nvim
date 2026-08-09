# Implementation Summary: Task #966

- **Task**: 966 - Give the inter-cycle redeploy checkpoint a pre/post baseline
- **Status**: [COMPLETED]
- **Started**: 2026-07-29T20:31:00Z
- **Completed**: 2026-07-29T21:45:00Z
- **Effort**: ~1.25 hours
- **Dependencies**: 967 (batch-ordering edge only; no file-scope overlap, not acted on)
- **Artifacts**: plans/01_redeploy-checkpoint-baseline.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

`verify-deploy.sh` reported the deployed tree's absolute state with no baseline notion, so the
inter-cycle redeploy checkpoint could not distinguish "this redeploy broke the tree" from "this
tree was already broken before I touched it" — any standing repo-wide lint failure converted a
multi-task `/orchestrate` batch into run-one-task-then-defer. This task added an additive
`--findings` mode to `verify-deploy.sh` that emits a normalized, one-per-line, machine-diffable
findings set across all four gates, wired the inter-cycle redeploy checkpoint to capture that set
once immediately before `deploy-headless.sh` and once after, defer only on the set difference, and
rewrote the authoritative failure contract to describe the resulting THREE operator-visible
states. All seven planned phases completed.

## What Changed

- `agent-system/extensions/core/scripts/verify-deploy.sh` — added `--findings` flag,
  `FINDINGS_LIST` accumulator, `CURRENT_GATE` labels, an extended `fail()` (optional 3rd argument
  overrides/suppresses the default finding text), exit-2 sentinels, gate-3 capture with per-`FAIL:`
  extraction (excluding `ADVISORY:`), gate-4 conditional non-quiet re-invocation, and sorted
  findings output after the narrative PASS/FAIL line. Default-mode output/exit codes verified
  byte-identical to the pre-edit script.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — rewrote the
  `### The Inter-Cycle Redeploy Checkpoint` subsection's **Failure contract** paragraph into a
  three-branch statement (deploy-headless failure / new-finding verify-deploy failure /
  pre-existing-only verify-deploy failure), and added **Baseline mechanism**, **Exit-2
  resolution**, and one **Rejected alternative** entry.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — added the
  `verify_deploy_baseline_notices` `mt_state_file` schema field; rewrote Stage MT-3 step 7's Fire
  bullet (pre-redeploy baseline capture), added an explicit `deploy-headless.sh` failure branch
  stated before any baseline logic, added the post-redeploy capture and the three-way `POST_EXIT`
  branch (success / third-state / defer); extended Stage MT-5's field-read list, added the
  "never consulted by exit-status resolution" note, added the reporting instruction, and added the
  field to the `specs/.return-meta-multi-${session_id}.json` jq emission.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — Phase 6 conditional path:
  mirrored the three-branch summary into the **Transcribed: inter-cycle redeploy checkpoint**
  block, preserving the CO-MAINTENANCE note verbatim and keeping the block a
  cross-reference-by-path summary, not a full restatement.
- `agent-system/extensions/core/commands/orchestrate.md` — added a new
  `### Pre-Existing Deploy-Verify Failures (Not Deferred)` Consolidated Output section (rendered
  whenever `verify_deploy_baseline_notices` is non-empty, including on succeeded batches), and
  enriched the `### Deferred (redeploy checkpoint)` Reason-cell template to name the
  newly-introduced-finding count.

## Decisions

- (Plan Decisions 1-8 as recorded in the plan file were followed as specified: `FINDING `-prefixed
  gate-labeled lines; exit-2 folded into the findings vocabulary as a synthesized sentinel;
  gate-3 findings limited to `FAIL:` lines; count-free finding text; third state updates
  `deployed_critical_paths`; third state is not a `defer_ledger` entry; third state does not flip
  batch exit status; baseline captured immediately before `deploy-headless.sh`.)
- `fail()`'s extension took an optional 3rd argument (override/suppress) rather than the plan's
  literal "append `FINDING $CURRENT_GATE $1`" — needed for Decision 4 (count-free
  `STRICT_CORE_DEPLOY` finding) and to avoid the two gate-level aggregate `fail()` calls emitting a
  redundant generic finding alongside the per-underlying-finding lines extracted separately. See
  Plan Deviations below.
- Operator-confirmed CONDITIONAL PATH for Phase 6: `specs/state.json`'s `file_scope` for this task
  was extended by the operator, before this dispatch, to include
  `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` as its fifth entry
  (verified via direct read). The implementer did not extend `file_scope` itself, per the plan's
  explicit prohibition.

## Plan Deviations

- **Task 1.2** (`fail()` extension) altered: added an optional 3rd argument to `fail()` that
  overrides (or, if passed empty, suppresses) the default `$1` finding text, rather than the
  literal unconditional `FINDING $CURRENT_GATE $1` append the plan's task text describes. Needed so
  the gate-3 `STRICT_CORE_DEPLOY` sub-check can omit its embedded count (Decision 4) and so the two
  aggregate gate-3/gate-4 `fail()` calls can suppress their own generic finding in favor of the
  per-underlying-finding lines extracted separately at those call sites. Every other `fail()` call
  site keeps the original unmodified two-argument shape.
- **Phase 4 verification bullet 2** altered: the plan expected `grep -n
  'verify_deploy_baseline_notices'` to return hits in "exactly four places." The live count is 8,
  all falling within the same four CONCEPTUAL locations named (schema definition, third-state
  branch, MT-5 read/report block, jq emission) — the MT-5 read/report block alone needed 5
  sentences across the field-read list, the two-sentence exit-status-resolution note, and the
  reporting-instruction paragraph to state the contract clearly in prose. No hit falls outside
  those four locations.
- **Correctness fix discovered during Phase 7's own criterion-1 evidence run** (not itself a
  planned task, but load-bearing for the plan's own Decisions 2 and 8): the pre/post capture
  pattern as first drafted in Phase 3 and mirrored in Phase 6 — `X=$(cmd | grep ... | sort -u);
  EXIT=$?` — incorrectly captures `sort -u`'s exit status rather than `verify-deploy.sh`'s own,
  because a pipeline inside a command substitution runs in its own subshell whose `PIPESTATUS`
  does not propagate back to the parent shell. Verified empirically (an initial evidence run
  showed `PRE_EXIT=0`/`POST_EXIT=0` despite `verify-deploy.sh` itself exiting 1). Fixed in both
  `skill-orchestrate/SKILL.md`'s Stage MT-3 step 7 and `skill-orchestrate-hard/SKILL.md`'s mirror
  by capturing the script's own exit code first, as the sole command in its substitution, then
  filtering the already-captured text as a separate step. Re-verified: `PRE_EXIT`/`POST_EXIT`
  correctly read 1 against this repo's actual standing failure.

## Verification

- Build: N/A (documentation and shell script, no build step)
- Tests: N/A (no automated test suite for this subsystem; verification is the six-criterion bar
  below plus the repo's own lint gates)
- Files verified: Yes
- **`bash -n`**: `agent-system/extensions/core/scripts/verify-deploy.sh` — exits 0. Confirmed via
  `git log --name-only` across all six `task 966 phase N` commits that it is the ONLY `.sh` file
  touched by this task.
- **Default-mode invariance**: captured stdout/stderr/exit from the pre-edit script (via `git show
  HEAD:...` into a temp file, no destructive git operation) and the post-edit script against the
  same tree — byte-identical (`diff` empty), exit 1 both times.
- **Criterion 1** (pre-existing failure does not defer): `PRE_EXIT=1`, `POST_EXIT=1`,
  `pre_count=4`, `post_count=4`, `NEW_FINDINGS=[]` (empty) against this repo's actual current
  standing `verify-deploy.sh` gate-3 doc-lint failure. Rendered banner:
  `[PRE-EXISTING VERIFY-DEPLOY FAILURE - 4 finding(s) predate this redeploy, 0 newly introduced;
  batch continuing]`.
- **Criterion 2** (newly-introduced failure still defers): scratch-copy test (never the live
  tree) — `PRE_EXIT=0`; induced by renaming `scripts/events-append.sh` to `.bak`; `POST_EXIT=1`;
  `NEW_FINDINGS=[FINDING gate1 scripts/events-append.sh is missing]` — exactly the induced line.
  Reverted; re-confirmed the diff returns empty (`REVERT_EXIT=0`).
- **Criterion 3** (`deploy-headless.sh` failure defers unconditionally): confirmed by read-through
  and grep that the failure branch appears before, and its own paragraph names none of, the
  baseline capture variables.
- **Criterion 4** (no deferred task is failed or status-mutated): "Never add to `failed_tasks`.
  Never status-mutate. Never abort." survives verbatim in both the `deploy-headless.sh` failure
  branch and the `NEW_FINDINGS` non-empty branch; the third-state branch's paragraph does not
  mention `failed_tasks` at all.
- **Criterion 5** (authoritative subsection matches implemented behavior; no referring file
  restates it): every `grep -rn 'The Inter-Cycle Redeploy Checkpoint'` hit across
  `agent-system/extensions/core/` either IS the authoritative subsection or cross-references it by
  path. `skill-orchestrate-hard/SKILL.md` carries a separately-contracted CO-MAINTENANCE
  **transcribed summary** (not a bare cross-reference) — a pre-existing, deliberate distinction
  named in the plan's Scope Note 1; Phase 6 kept it a summary while bringing its content back into
  agreement with the rewritten contract.
- **Criterion 6** (`bash -n` clean): see above.
- `check-task-references.sh`: `PASS: 0 unexempted task-reference occurrences across 4 tree(s)`.
- `check-extension-docs.sh --quiet`: 4 pre-existing `FAIL:` lines, all "deployed script content
  drift" / "not in provides.scripts" deploy-freshness findings. One
  (`scripts/verify-deploy.sh`) is the expected, documented consequence of editing a source-store
  script without a subsequent redeploy, per `.claude/rules/source-store-deploy-boundary.md` — a
  live instance of the exact "pre-existing, reported loudly, does not block" scenario this task
  implements, not a defect in this task's deliverables.

## Impacts

- Any future `/orchestrate` (or `/orchestrate --hard`) multi-task batch that hits the inter-cycle
  redeploy checkpoint on a repository with a standing `verify-deploy.sh` failure will now run to
  completion (reporting the pre-existing failure loudly) instead of deferring every remaining task
  for the rest of the invocation.
- A redeploy that genuinely introduces a new `verify-deploy.sh` finding still defers exactly as
  before.
- `deploy-headless.sh` failure still defers unconditionally with zero baseline consultation.
- The `--findings` mode on `verify-deploy.sh` is additive and available for any other future
  automated consumer needing a machine-diffable findings set.

## Follow-ups

- Phase 6's Scope Note 1 default path (recording a blocker for a future task) did not apply — the
  conditional (mirror-edit) path was taken because the operator had already extended `file_scope`.
  No outstanding blocker to record for the hard-mode file.
- None else outstanding; all six verification-bar criteria demonstrated with evidence above.

## References

- `specs/966_add_baseline_to_intercycle_redeploy_checkpoint/plans/01_redeploy-checkpoint-baseline.md`
- `specs/966_add_baseline_to_intercycle_redeploy_checkpoint/reports/01_verify-deploy-baseline-design.md`
- `specs/966_add_baseline_to_intercycle_redeploy_checkpoint/progress/phase-{1..7}-progress.json`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`'s
  `### The Inter-Cycle Redeploy Checkpoint` subsection (the authoritative contract)

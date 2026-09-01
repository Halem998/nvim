# Report: Retarget the 7 Hard-Mode Test/Lint Files to skill-orchestrate's hard_mode Branch

- **Task**: 120 - Retarget hard mode tests to engine branch
- **Started**: 2026-09-01T00:00:00Z
- **Completed**: 2026-09-01T13:09:00Z
- **Effort**: ~2 hours (research only)
- **Dependencies**: Task 118 (hard contracts injection), Task 119 (hard-mode state-machine migration) — both `[COMPLETED]`
- **Sources/Inputs**:
  - `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (4,118 lines) — the merged engine, read in full-region excerpts around each mechanism
  - `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (1,823 lines) — the still-present, not-yet-deleted `-hard` file, read for each test's current target
  - The 7 files under `agent-system/extensions/core/scripts/tests/**` and `scripts/lint/**` named in this task
  - `specs/116_core_agent_system_consolidation/reports/02_baseline-and-audit-evidence.md` (Finding 2, the 7-file roster)
  - `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md` (section A4, especially A4-iv's retarget-not-delete decision and the residue-measurement table)
- **Artifacts**:
  - This report
- **Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- All 7 files' underlying mechanisms (loop-guard budget override, routing resolution, handoff
  reader fields, loop-guard staleness, dispatch_seq identity, resume-scan ordering, convergence
  policing fields) **do survive** inside `skill-orchestrate/SKILL.md`'s `hard_mode` branches —
  Task 120's premise ("retarget, not delete") holds for all 7. No coverage needs to be dropped.
- 5 of 7 files are **mechanical retargets**: a sentinel comment pair (`# --- <name>:begin/:end
  ---`) that used to exist once in each of two files now exists exactly once, under the *same*
  sentinel name, inside `skill-orchestrate/SKILL.md`. Swapping the file-path variable is close to
  sufficient. These are: `test-loop-guard-staleness.sh`, `test-resume-scan-nonconformance.sh`,
  `lint-contract-compliance.sh`, and (with one behavioral-expectation fix noted below)
  `test-loop-guard-budget-override.sh` and `test-handoff-dispatch-identity.sh`.
- 2 of 7 files need **real logic changes**, not just a path swap, because their entire premise —
  "extract the same construct from two engine files and assert the two copies agree" — no longer
  has two engines to compare: `test-routing-resolution.sh` (Assert 3 only; Asserts 1/2/4 are
  unaffected) and `test-handoff-reader-parity.sh` (most of the file).
- One genuine **semantic drift** was found, not just a location change: in the merged file, the
  `guard_session_id` mismatch INFO log that `test-loop-guard-budget-override.sh` Case 4 currently
  treats as "base-mode only" is now unconditional/shared code. A naive path-only retarget of that
  test will fail against the merged file's *correct* behavior. This must be fixed as part of the
  retarget, not deferred.
- Two of `test-handoff-reader-parity.sh`'s three "hard-only allowlisted" field reads
  (`skeleton`, `sorry_inventory`) have also drifted to different variable names, different read
  forms, and in one case moved to being unconditional/shared rather than hard-only. The third
  (`blocker_target`/`verbatim_goal`) survived unchanged and retargets cleanly.
- **Caveat on anchors**: `skill-orchestrate/SKILL.md` is being concurrently edited by sibling
  tasks in the same batch. Every location below is identified primarily by **heading text,
  sentinel comment, or a unique surrounding string** — the same anchor strategy several of these
  tests already use internally — with line numbers given only as an as-of-writing convenience,
  not a retarget target in themselves.

## Context & Scope

This is a research-only task. The 7 files enumerated in the task description
(`test-loop-guard-budget-override.sh`, `test-routing-resolution.sh`,
`test-handoff-reader-parity.sh`, `test-loop-guard-staleness.sh`,
`test-handoff-dispatch-identity.sh`, `test-resume-scan-nonconformance.sh`,
`lint-contract-compliance.sh`) currently point some or all of their fixtures/assertions at
`agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`. A prerequisite task already
landed the hard-mode contract-injection and state-machine logic as `hard_mode`-gated (or, in a
few cases, now-unconditional) branches inside `agent-system/extensions/core/skills/
skill-orchestrate/SKILL.md` (confirmed: 55 occurrences of `hard_mode` in that file today).
`skill-orchestrate-hard/SKILL.md` itself is still present on disk — its deletion is a distinct,
later, dependent task and is explicitly out of scope here.

The question this report answers, file by file: where does each test's fixture/anchor now live
inside `skill-orchestrate/SKILL.md`, does the underlying mechanism still exist and still behave
the same way, and what has to change (path only, vs. path + logic) to retarget correctly.

No files were modified for this report. No mutation checks were executed (that is
implementation-phase verification work); this report identifies, per file, what the mutation
check should assert once the retarget lands.

## Findings

### 1. `scripts/tests/test-loop-guard-budget-override.sh`

- **Current target**: both `skill-orchestrate/SKILL.md` (`BASE_SKILL`) and
  `skill-orchestrate-hard/SKILL.md` (`HARD_SKILL`), via a shared sentinel
  `budget-continuation-override:begin`/`:end` plus two different resume-echo anchor strings
  (`RESUME_ANCHOR_BASE` = `...(infra failures`, `RESUME_ANCHOR_HARD` = `...(burnout signals so
  far`) used to select where each per-file region ends.
- **What it exercises**: Defect B — the `--continue-budget` operator override that resets an
  exhausted `MAX_CYCLES` budget while preserving `dispatch_seq_counter`/`detected_defects`; the
  immediately-following resume-read block (cycle_count, session_id-mismatch INFO log); and a
  Stage 7 message-text check that both engines' `MAX_CYCLES` reached message names
  `--continue-budget`.
- **Where it lives now**: the `budget-continuation-override:begin`/`:end` sentinel exists exactly
  **once** in `skill-orchestrate/SKILL.md` (Stage 2, immediately after the `loop-guard-staleness`
  region). The resume-read block that follows it is now a **single shared block** for both modes:
  a self-contained `if [ "${hard_mode:-false}" = "true" ]; then echo "...Resuming (hard mode) —
  burnout signals so far: $burnout_signals_this_session"; fi` sits immediately before, and is
  fully closed before, the one shared `echo "[orchestrate] Resuming — cycle $cycle_count of
  $MAX_CYCLES (infra failures: ...)"` line — which is `RESUME_ANCHOR_BASE`'s exact text.
  `RESUME_ANCHOR_HARD`'s exact single-line text ("...burnout signals so far...infra failures...")
  no longer exists anywhere in this primary resume path (it does still exist, differently
  worded, in the separate "lost init race" branch further down, prefixed "Resuming (lost init
  race)" — not the same code path this test targets).
  A code comment at this exact spot in `skill-orchestrate/SKILL.md` explicitly names this test
  file and explains why the hard-only echo was written as a **self-closed** `if` block rather
  than wrapping the shared echo: so this test's extract-through-that-echo-and-append-a-synthetic-
  `fi` technique keeps working unmodified against the merged file.
- **Mechanism survives**: yes, intact — budget override, archival, and counter-preservation logic
  is unchanged in substance.
- **What must change**:
  - Collapse `BASE_SKILL`/`HARD_SKILL` to a single file target (`skill-orchestrate/SKILL.md`).
    Extract **one** region using the existing `BEGIN_MARKER` + `RESUME_ANCHOR_BASE` pair (drop
    `RESUME_ANCHOR_HARD` — it no longer identifies a distinct region).
  - Run the extracted region **twice** per case — once with `hard_mode=false`, once with
    `hard_mode=true` injected into the `run_region` subshell environment — replacing the current
    "iterate over `$BASE_SKILL $HARD_SKILL`" loop with "iterate over the two `hard_mode` values
    against the one region."
  - **Behavioral fix required, not just a path change**: Case 4 currently gates the
    `guard_session_id` mismatch INFO-log assertion on `engine_label == "base"`, reflecting the old
    fact that `skill-orchestrate-hard/SKILL.md`'s resume-read block had no `guard_session_id`
    check at all. In the merged file that check is unconditional, shared code — it fires
    regardless of `hard_mode`. The retargeted test must assert the INFO log appears in **both**
    the `hard_mode=false` and `hard_mode=true` runs, not skip the assertion for the hard case.
    Retargeting without this fix produces a false failure against demonstrably-correct merged-file
    behavior.
  - The Stage 7 MAX_CYCLES `--continue-budget` message check currently runs once against each of
    `BASE_SKILL`/`HARD_SKILL` separately; collapse to a single check against
    `skill-orchestrate/SKILL.md`.
- **Suggested mutation check**: temporarily remove the hard-mode-only burnout echo's `if` guard
  (making it unconditional) and confirm the retargeted region still produces the expected
  hard_mode=false output without the burnout line; separately, delete the `guard_session_id`
  mismatch check entirely and confirm the retargeted test now fails on the (fixed) Case 4
  assertion for both runs.

### 2. `scripts/tests/test-routing-resolution.sh`

- **Current target**: Assert 3 only (`ORCH_SKILL` = `skill-orchestrate/SKILL.md`, `ORCH_HARD_SKILL`
  = `skill-orchestrate-hard/SKILL.md`). Asserts 1, 2, and 4 are manifest-driven
  (`agent-system/extensions/**/manifest.json`) and never reference either `SKILL.md` file — they
  are unaffected by this task and need no changes.
- **What it exercises**: (a) structural parity — both orchestrate engines invoke
  `command-route-agent.sh` at least 3 times (research/plan/implement) and neither contains a
  stale case-table/sed-derivation routing pattern; (b) semantic parity — hard-mode routing falls
  back to an extension's standard `routing_agents` entry (`via="hard-miss-standard-fallback"`) on
  a `routing_agents_hard` miss, rather than discarding the domain agent.
- **Where it lives now**: `skill-orchestrate/SKILL.md` alone already contains **5** occurrences of
  `command-route-agent.sh` (verified via `grep -c`), comfortably above the `>=3` floor Assert 3
  checks per file today. The semantic fallback logic (`hard-miss-standard-fallback`) is dispatch-
  prep logic inside the single file's routing resolution step, gated on `hard_mode`, not a
  separate engine.
- **Mechanism survives**: yes.
- **What must change**: this is a genuine "two engines to compare" premise with only one engine
  left, so it needs a real rewrite, not just a path swap:
  - Replace the dual `orch_calls`/`orch_hard_calls` count-and-compare with a single count against
    `skill-orchestrate/SKILL.md`, asserting `>= 3`.
  - To preserve the *intent* of the original parity check (research/plan/implement dispatch sites
    present under **both** modes, not just present somewhere), recommend strengthening this into
    an intra-file check: confirm `command-route-agent.sh` calls exist both inside the base
    dispatch-construction branch and inside the `hard_mode`-gated "Per-Phase Dispatch (H1)" branch
    (identifiable by its own heading, `##### Hard branch: Per-Phase Dispatch (H1)`), rather than
    a flat total across the whole file that could pass even if one mode's dispatch sites were
    accidentally deleted.
  - The `case "\$TASK_TYPE"`/`sed .s/^skill-` anti-pattern check (grep against both files) reduces
    to a single-file grep.
- **Suggested mutation check**: delete one `command-route-agent.sh` call from inside the H1 hard
  branch specifically (leaving the base-branch calls intact) and confirm the strengthened,
  branch-aware version of Assert 3 fails — the flat-count-only version would not catch this,
  which is itself evidence the strengthening is worth doing.

### 3. `scripts/tests/test-handoff-reader-parity.sh`

- **Current target**: both `skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md`
  (via `resolve_candidate`, source-store-first with deploy-tree fallback).
- **What it exercises**: field-by-field parity of Stage 5's handoff-result-read jq filters
  (`dispatch_status`, `dispatch_summary`, `blockers`, `next_hint`, `phases_completed`,
  `phases_total`, `plan_markers_verified`, the multi-line `continuation` dual-form-resolution
  block, and `artifacts[0].{path,type,summary}`) plus three "hard-only allowlisted" fields
  (`skeleton`, `sorry_inventory`, `blockers[0].target`/`verbatim_goal`) that only the hard engine
  reads, asserted for successful extraction and sane values rather than compared to base.
- **Where it lives now — this file needs the most rework of the seven**, because its entire
  design assumes two files to diff, and there is now one:
  - The `SHARED_FIELDS` list, the `continuation` block, and the `artifacts[0].*` triplet are all
    anchored off one comment string (`'not bare `.status`) so a handoff with a missing'`) that is
    now unique to a **single** Stage 5 region in `skill-orchestrate/SKILL.md` — a code comment at
    the boundary of the next stage (Stage 5b's own heading, "Churn Detection (H6) and
    Three-Strikes Audit Dispatch (H5) — hard mode only") explicitly states that stage was placed
    to stay "strictly outside the Stage 5 region `test-handoff-reader-parity.sh` extracts,"
    confirming this Stage 5 region is the intended, still-single, retarget target. Comparing
    `BASE_SKILL` output to `HARD_SKILL` output on these fields is now comparing a file to itself —
    the retarget must replace "assert base filter == hard filter" with "assert the filter is
    present, well-formed, and produces the expected value against the shared fixture," dropping
    the comparison dimension entirely for these fields.
  - The three "hard-only allowlisted" fields have drifted individually, not just moved file:
    - **`skeleton`**: the old pattern (`skeleton=$(echo "$handoff" | jq -r '...')`) no longer
      exists anywhere. The merged file reads it as `last_skeleton=$(jq -r '.skeleton // false'
      "$handoff_file")` — a **renamed variable**, reading directly from the handoff **file**
      rather than piping the already-loaded `$handoff` variable — and it now lives inside Stage
      4's `hard_mode`-gated "Per-Phase Dispatch (H1)" branch, not Stage 5. The retargeted test's
      extraction regex must be rewritten for this new variable name and read form, and the
      "where it lives" framing corrected from "Stage 5, hard-only" to "Stage 4 H1 branch,
      hard-only."
    - **`sorry_inventory`**: the old pattern assigned a `sorry_inventory=` variable directly. The
      merged file instead inlines `.sorry_inventory[]?.follow_up_task` into
      `follow_up_tasks=`/`follow_up_count=` (found via the surrounding comment "Derive the
      follow-up task list from the actually-shipped wrap-up.md field `sorry_inventory[]...`" near
      the skeleton-exhaustion branch), and — significantly — **this code path is now
      unconditional / shared**, not gated on `hard_mode`. The retargeted test must drop this
      field from the "hard-only, not compared to base" bucket entirely; it either needs a new
      single-file presence check with no hard/base distinction, or should be reconsidered for
      removal from this test if the field is exercised elsewhere.
    - **`blocker_target` / `verbatim_goal`**: these **did survive unchanged** — same variable
      names, same `echo "$handoff" | jq -r '...'` form — now living inside Stage 5b's
      `hard_mode`-gated churn-detection block (`blocker_target=$(echo "$handoff" | jq -r
      '.blockers[0].target // "unknown"')` and `verbatim_goal=$(echo "$handoff" | jq -r
      '.blockers[0].verbatim_goal // ""')`). This pair is a clean retarget: point the existing
      extraction pattern at `skill-orchestrate/SKILL.md` and it should work unmodified.
- **Mechanism survives**: yes for the field values and validator-shared-fixture logic; the
  **comparison mechanism itself** (base vs. hard) does not survive and must be replaced with a
  single-file presence/correctness mechanism.
- **What must change**: this file needs logic changes, not a path swap:
  1. Collapse `BASE_SKILL`/`HARD_SKILL` resolution to one file.
  2. Convert `SHARED_FIELDS`/`continuation`/`artifacts[0].*` checks from "extract twice, compare"
     to "extract once, assert present and correctly valued against the fixture."
  3. Rewrite the `skeleton` extraction pattern for its new variable name/read form and correct
     section framing (Stage 4 H1, not Stage 5).
  4. Rewrite or retire the `sorry_inventory` hard-only assertion given it is no longer
     conditional on `hard_mode`.
  5. Retarget `blocker_target`/`verbatim_goal` extraction to the single file — no pattern changes
     needed there.
- **Suggested mutation check**: for each of the 7 field/block checks, delete or corrupt that
  field's jq filter in the single merged file and confirm the retargeted test fails specifically
  on that field (there is no longer a "compare to the other engine" fallback signal to rely on,
  so each check must independently detect its own field's breakage).

### 4. `scripts/tests/test-loop-guard-staleness.sh`

- **Current target**: `SKILL_FILE` = `skill-orchestrate-hard/SKILL.md` only (this test was
  always single-engine, unlike most of the others).
- **What it exercises**: the 3-signal operational-staleness detector for a present-but-superseded
  loop guard/churn-state file (distinct from the git-restoration/ephemerality hazard).
- **Where it lives now**: the `loop-guard-staleness:begin`/`:end` sentinel exists exactly **once**
  in `skill-orchestrate/SKILL.md`, in Stage 2. A design-decision table earlier in the same file
  explicitly records this detector as "hard-mode-gated only (D4)" — i.e., still conditionally
  wrapped for `hard_mode`, matching the file's own header comment ("D4: this detector stays
  strictly `$hard_mode`-gated — whether base...").
- **Mechanism survives**: yes, unchanged in substance and still `hard_mode`-gated exactly as
  before.
- **What must change**: cleanest retarget of the seven — change `SKILL_FILE` from
  `skill-orchestrate-hard/SKILL.md` to `skill-orchestrate/SKILL.md`. No sentinel-name changes, no
  logic changes. The extracted region should be run with `hard_mode=true` in its fixture
  environment (previously implicit, since the whole file was the hard engine — now must be set
  explicitly since the surrounding file also serves base mode).
- **Suggested mutation check**: temporarily change the `hard_mode`-gate condition on this region
  to always-true (removing the gate) and confirm existing behavior is unaffected when run with
  `hard_mode=true` (expected, since the check already assumes that), then separately confirm the
  retargeted test's fixture explicitly sets `hard_mode=true` — running it without that would now
  silently skip the whole detector region rather than fail loudly, a regression risk worth a
  dedicated assertion.

### 5. `scripts/tests/test-handoff-dispatch-identity.sh`

- **Current target**: both `skill-orchestrate/SKILL.md` (`BASE_SKILL`) and
  `skill-orchestrate-hard/SKILL.md` (`HARD_SKILL`).
- **What it exercises**: the `dispatch_seq` identity gate (Defect A) — an orchestrator-minted,
  per-dispatch value that discriminates a legitimate handoff write from a still-live
  predecessor's late write, layered after the pre-existing mtime staleness check.
- **Where it lives now**: the `dispatch-seq-gate:begin`/`:end` sentinel exists exactly **once** in
  `skill-orchestrate/SKILL.md`, immediately after the mtime staleness check in Stage 5, and — the
  most notable finding for this file — **it is unconditional, shared code**, not `hard_mode`-
  gated at all; it always ran the same way for both engines even before the merge, and continues
  to run the same way for both modes in the single file now. A nearby comment in the merged file
  explicitly names this test: it explains that the `append_detected_defect` helper is kept as a
  locally-named function specifically because this test "stubs `append_detected_defect` by this
  exact name and `eval`s a region below that calls it" — confirming the stub-by-name mechanism
  this test relies on is still intact and deliberately preserved.
- **Mechanism survives**: yes, unchanged.
- **What must change**: collapse the dual-file extraction-and-diff to a single-file extraction.
  Since the region was already engine-symmetric by design (not `hard_mode`-gated), the "parity"
  assertions become "this one region behaves correctly" rather than "these two copies agree" —
  recommend still running the extracted region under both `hard_mode=true` and `hard_mode=false`
  fixture environments if any downstream logic in the region reads `$hard_mode`-derived variables
  (worth a quick check at implementation time — not fully verified in this pass whether the
  extracted region itself branches on `hard_mode`, only that the sentinel-bounded gate logic does
  not).
- **Suggested mutation check**: change the minted `dispatch_seq` value between mint-time and
  read-time (simulating a stale/mismatched handoff) and confirm the retargeted single-file test
  still detects and reports `DISPATCH_SEQ MISMATCH` correctly; separately, rename
  `append_detected_defect` in a scratch copy and confirm the stub-based mechanism this test uses
  would have caught the rename (proving the stub is still load-bearing post-retarget).

### 6. `scripts/tests/test-resume-scan-nonconformance.sh`

- **Current target**: three sites — `SITE_A_FILE` = `skill-orchestrate-hard/SKILL.md`,
  `SITE_B_FILE` = `skill-implementer-hard/SKILL.md`, `SITE_C_FILE` =
  `skill-lean-implementation-hard/SKILL.md` — compared pairwise for a shared ordering contract via
  the `resume-scan-conformance-gate:begin`/`:end` sentinel plus a library file
  (`.claude/scripts/lib/phase-heading-patterns.sh`) sourced just before each region (deliberately
  excluded from the extracted region itself, per the test's own header comment).
- **What it exercises**: cross-site consistency of the resume-scan nonconformance-detection
  ordering contract, extracted and syntax-checked independently at all three sites.
- **Where it lives now**: `resume-scan-conformance-gate:begin`/`:end` exists exactly **once** in
  `skill-orchestrate/SKILL.md`, replacing Site A only. Sites B (`skill-implementer-hard/SKILL.md`)
  and C (`skill-lean-implementation-hard/SKILL.md`) are untouched by this migration — they remain
  `-hard`-specific files not yet folded into any base engine, and are out of scope for this task
  (their own eventual disposition is a separate concern from Task 120).
- **Mechanism survives**: yes, unchanged at Site A; Sites B/C are unaffected either way.
- **What must change**: change `SITE_A_FILE` from `skill-orchestrate-hard/SKILL.md` to
  `skill-orchestrate/SKILL.md`, and update the label strings ("Site A (skill-orchestrate-hard)")
  to "Site A (skill-orchestrate)" wherever they appear (both in the extraction-failure message and
  the `SITE_LABEL` associative array). No sentinel or logic changes; the library-sourcing
  exclusion note in the header comment remains accurate (still sits immediately before the marker
  at the new site too — confirm at implementation time, not independently re-verified line-by-line
  in this pass).
- **Suggested mutation check**: reorder two lines inside Site A's extracted region (breaking the
  shared ordering contract) and confirm the retargeted test still fails the cross-site consistency
  assertion against Sites B and C exactly as before.

### 7. `scripts/lint/lint-contract-compliance.sh`

- **Current target**: Check D (`check_d_convergence_policing`) only; `skill_file` =
  `$CORE_ROOT/skills/skill-orchestrate-hard/SKILL.md`. (Checks A–C and E onward reference other
  files/agents not in scope for this task.)
- **What it exercises**: a plain `grep -qF` presence check for three convergence-policing field
  names — `total_churn`, `target_churn`, `adversarial_triggers` — asserting the churn-state schema
  these fields belong to is declared somewhere in the target file.
- **Where it lives now**: all three fields are present in `skill-orchestrate/SKILL.md` — confirmed
  via direct grep: `total_churn` and `target_churn` appear in the Stage 2 churn-state
  init/resume block (churn-file init JSON literal and the resume-read `total_churn=$(jq -r
  '.total_churn // 0' "$churn_file")` line) and again in Stage 5b's churn-increment logic
  (`.target_churn[$target]`); `adversarial_triggers` appears in the same Stage 2 churn-file init
  JSON literal (`'{"session_id": $session_id, "total_churn": 0, "target_churn": {},
  "adversarial_triggers": 0, "audit_dispatches": 0}'`).
- **Mechanism survives**: yes, unchanged in substance — the check is a simple grep, and all three
  fields it looks for are present.
- **What must change**: simplest retarget of the seven — change the `skill_file` variable (in
  `check_d_convergence_policing`) from `skill-orchestrate-hard/SKILL.md` to
  `skill-orchestrate/SKILL.md`. The `log_pass`/`log_fail`/`log_info` message strings
  ("skill-orchestrate-hard: contains...", "Convergence policing fields in
  skill-orchestrate-hard") should be updated to say "skill-orchestrate" for message accuracy —
  cosmetic, not required for the check to pass or fail correctly, but worth doing in the same
  pass to avoid a stale/misleading log line surviving the retarget.
- **Suggested mutation check**: temporarily delete the `adversarial_triggers` field from the
  churn-init JSON literal in `skill-orchestrate/SKILL.md` and confirm the retargeted Check D
  fails specifically on that field, then restore it.

## Decisions

- **Retarget, not delete or rewrite from scratch**, confirmed correct for all 7 files per the
  design decision already recorded in `specs/116_core_agent_system_consolidation/reports/
  03_target-state-design.md` section A4(iv) — every mechanism this task's 7 files test still
  exists post-merge.
- **5 of 7 files are mechanical (path/label swap, one behavioral-expectation fix each at most)**;
  **2 of 7 files (`test-routing-resolution.sh` Assert 3, `test-handoff-reader-parity.sh`)
  require genuine logic rewrites**, not just path substitution, because their premise of
  comparing two separate engine files no longer applies with a single merged engine.
- **`skill-orchestrate-hard/SKILL.md` itself is out of scope for this task** — it remains on disk
  and un-deleted; deletion is a distinct, dependent, later task (already scoped separately in the
  backlog) with its own precondition that this retarget task land and verify first.
- **Sites B/C of `test-resume-scan-nonconformance.sh`** (`skill-implementer-hard/SKILL.md`,
  `skill-lean-implementation-hard/SKILL.md`) are explicitly left untouched — only Site A
  retargets.

## Recommendations

Priority order for an implementation plan, roughly cheapest/lowest-risk to most involved:

1. `lint-contract-compliance.sh` Check D — single variable change.
2. `test-loop-guard-staleness.sh` — single variable change, explicit `hard_mode=true` fixture.
3. `test-resume-scan-nonconformance.sh` Site A — variable + label string changes.
4. `test-handoff-dispatch-identity.sh` — collapse dual-file extraction to single-file; verify no
   hidden `hard_mode` branching inside the region before dropping the two-fixture-environment run.
5. `test-loop-guard-budget-override.sh` — collapse dual-file extraction to single-file
   dual-`hard_mode`-run, **and** fix the Case 4 `guard_session_id` INFO-log expectation (now
   unconditional for both modes) — this is a correctness fix, not just a retarget, and should not
   be skipped or deferred.
6. `test-routing-resolution.sh` Assert 3 — single-file count, recommend strengthening to a
   branch-aware check (base dispatch-construction branch vs. H1 hard branch) rather than a flat
   total, to preserve the original parity intent.
7. `test-handoff-reader-parity.sh` — the largest single piece of work: convert the
   compare-two-engines mechanism to a single-file presence/correctness mechanism for the shared
   fields, and rewrite the `skeleton` and `sorry_inventory` hard-only-field extraction logic to
   match their new variable names, read forms, and (for `sorry_inventory`) their new
   unconditional/shared status. `blocker_target`/`verbatim_goal` retarget cleanly with no pattern
   changes.

After retargeting, run the full suite and perform the mutation check named per-file above
(reintroduce each guarded bug, confirm the retargeted test still catches it) before considering
this task's WORK item complete, per the task description's own verification requirement.

## Risks & Mitigations

- **Risk**: `skill-orchestrate/SKILL.md` is being edited concurrently by sibling tasks in this
  batch; line numbers cited in this report (and in the current test files' own `sed -n`/`awk`
  line-range logic, where any exists) may drift before implementation starts.
  **Mitigation**: every location in this report is anchored primarily by sentinel comment name,
  heading text, or a unique surrounding string (matching the pattern several of these tests
  already use for their own extraction), not by line number. The implementer should re-locate
  each anchor by search at implementation time rather than trusting the line numbers recorded
  here.
- **Risk**: the `test-handoff-reader-parity.sh` rewrite (item 7) is large enough that a partial or
  rushed implementation could silently drop coverage for the `sorry_inventory` and `skeleton`
  fields specifically, since their extraction patterns must change rather than just their file
  target. **Mitigation**: the mutation check specified for this file (delete/corrupt each field's
  filter individually, confirm the retargeted test fails on that specific field) directly guards
  against this.
- **Risk**: the Case 4 fix in `test-loop-guard-budget-override.sh` could be missed if the
  retarget is treated as "mechanical" by default (since 5 of 7 files genuinely are). **Mitigation**:
  called out explicitly in both the Executive Summary and the Recommendations ordering above.

## Appendix

- Confirmed via `grep -c hard_mode agent-system/extensions/core/skills/skill-orchestrate/
  SKILL.md` → 55 occurrences, corroborating that the Task 118/119 migrations landed before this
  research began.
- Confirmed via `wc -l` that `skill-orchestrate/SKILL.md` is 4,118 lines and
  `skill-orchestrate-hard/SKILL.md` is 1,823 lines as of this research pass.
- Sentinel names found unchanged (single-copy) in `skill-orchestrate/SKILL.md`:
  `budget-continuation-override:begin/:end`, `loop-guard-staleness:begin/:end`,
  `dispatch-seq-gate:begin/:end`, `resume-scan-conformance-gate:begin/:end`.
- No sentinel comment exists for the Stage 5 handoff-reader-parity region or for Stage 5b's churn
  detection block; both are instead identified by heading text ("### Stage 5: Handoff Reading",
  "### Stage 5b: Churn Detection (H6) and Three-Strikes Audit Dispatch (H5) — hard mode only")
  and by a unique surrounding comment string, respectively.

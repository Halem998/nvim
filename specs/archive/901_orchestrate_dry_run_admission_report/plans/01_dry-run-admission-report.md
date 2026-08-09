# Implementation Plan: Task #901

- **Task**: 901 - Add an orchestrate dry-run that reports batch admission verdicts before dispatch
- **Status**: [COMPLETED]
- **Effort**: 7.5 hours
- **Dependencies**: 900 (`orchestrate-batch-admit.sh`, completed)
- **Research Inputs**: `specs/901_orchestrate_dry_run_admission_report/reports/01_dry-run-admission-report.md`
- **Artifacts**: plans/01_dry-run-admission-report.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a strictly read-only `--dry-run` flag to `/orchestrate` that runs the full admission analysis
and prints a report instead of dispatching. The analysis is assembled from primitives that already
exist and are already read-only (`orchestrate-batch-admit.sh` for file_scope collisions,
`task-lock.sh check` for lock contention, the Kahn's-algorithm wave computation already specified
in `commands/orchestrate.md` Steps 2-3) plus one genuinely new piece: a handoff-triage classifier
extracted into its own script so the live dispatch path and the dry-run report read the same rule
rather than two independently-maintained copies.

Two new scripts are introduced. `orchestrate-triage-classify.sh` is the shared classifier — the
"one code path" — consumed by both the live Stage MT-4 dispatch grouping and the dry-run report.
`orchestrate-dry-run-report.sh` is the dry-run-only composer that calls the classifier plus the
three existing read-only primitives and prints the report. `orchestrate-batch-admit.sh` is reused
verbatim and is **not modified** by this task.

### Research Integration

Every substantive design decision below is taken from the research report:

- `--dry-run` is absent from `parse-command-args.sh`; the report identifies the exact four edit
  sites (init block, regex scan, `FOCUS_PROMPT` sed chain, `export` line) following the
  `CLEAN_FLAG`/`FORCE_FLAG` pattern. Phase 1 implements exactly that.
- `orchestrate-batch-admit.sh` is already a pure read-only NDJSON predicate covering the
  file_scope-collision exclusion reason, including the `in_batch`/`cross_batch` distinction.
  Reused unmodified (Phase 3).
- `task-lock.sh check` is the read-only lock primitive (`free` / `held-fresh` / `held-stale`,
  exits 0/1/2/3). The report notes two nuances the classifier must honor: `check` does not compare
  `session_id`, so a lock held by the *current* session is not contention; and `held-stale` would
  not actually block a live `acquire`, so it must be an informational note rather than an
  exclusion. Both are implemented in Phase 3.
- The report's "critical finding" — that single-task Stage 4 and multi-task Stage MT-4 genuinely
  disagree on `partial with no handoff` — is resolved below under Decision D1.
- The report's "always green" warning drives the report-format requirements in Phase 3: the
  exclusion section is never omitted, checks-run vs. checks-skipped is stated explicitly, and
  reasons carry the same structured fields the underlying primitives already emit.

### Prior Plan Reference

No prior plan. Task 900's plan and test suite
(`specs/900_cross_batch_file_scope_admission/`) are used only as **precedent** for script
structure, manifest registration, and the scratch-deploy-tree test pattern — not as a template.

### Roadmap Alignment

`roadmap_path` was not supplied in the delegation context, so ROADMAP.md was not consulted as a
planning input. A read-only grep confirms no open roadmap item names orchestration admission or
dry-run behavior, so there is no roadmap phase in this plan and no roadmap file is touched.

## Decisions

### D1 (required by the task): resolving the Stage 4 / Stage MT-4 discrepancy — **Option (A)**

The task's acceptance criterion asks the triage classifier to agree exactly with the Stage MT-4
phase-grouping table. The research report shows that table's `partial with no handoff` row
contradicts the single-task Stage 4 handler for the identical condition (MT-4 dispatches to
implement; Stage 4 exits the invocation with `partial`). `/orchestrate` selects between these two
engines purely by `len(TASK_NUMBERS)`.

**Chosen: Option (A) — branch the classifier on the same argument-count condition the live command
already branches on.** The classifier takes an explicit `engine` argument (`single` | `mt`) and
carries two transcribed precedence tables; the dry-run report derives `engine` from
`len(task_numbers)` using the identical `== 1` vs `> 1` test in `orchestrate.md` STAGE 0.

Justification:

1. A dry-run's entire value is being a *prediction of what the live path will do*. Option (B)
   (restricting the full report to multi-task invocations) does not avoid the problem — it still
   has to print a single-task preview, and that preview still has to apply single-task Stage 4
   precedence. B is therefore A plus a second, divergent output format, not a simplification.
2. Option (A) keeps one report shape, which is load-bearing for the anti-"always green"
   requirement: a reader who has learned to scan the Excluded section should not have that section
   silently restructured because they passed one task number instead of two.
3. The acceptance criterion is satisfied precisely where it is meaningful: the `mt` branch is a
   verbatim transcription of the MT-4 table, asserted by a fixture test (Phase 6). The `single`
   branch is governed by Stage 4, which is the honest reading — a classifier that applied MT-4
   semantics to a single-task invocation would be confidently wrong, which is the failure the task
   description explicitly warns against.
4. The report degrades rather than forks: a one-task batch prints the same sections, with a
   single-row wave table and a "batch of one — no split applicable" split line.

Consequence for scope: because the `mt` table's `partial with blockers -> failed_tasks` row has no
spelled-out pre-dispatch mechanism today (research Risk 2), Phase 5 must wire Stage MT-4 to call
the shared classifier. That is the "one code path, two consumers" requirement; without it this
task would ship a second, independently-maintained copy of the rule.

### D2: two new scripts, not one

`orchestrate-triage-classify.sh` (shared, called by the live path) is kept separate from
`orchestrate-dry-run-report.sh` (dry-run only). Having the live Stage MT-4 dispatch call a script
named "dry-run-report" would be actively misleading, and the live path needs only the classifier.
This mirrors how task 900 extracted the collision check into its own predicate consumed by two
call sites.

### D3: `orchestrate-batch-admit.sh` is not modified

It is already read-only and already emits every field the report needs. It appears in this task's
`file_scope` only because the design *reads* it. Leaving it untouched also minimizes contention
with the adjacent not-started task that will add a self-modification solo-only gate on top of the
same script.

## Goals & Non-Goals

**Goals**:
- A `--dry-run` flag on `/orchestrate`, parsed through `scripts/parse-command-args.sh` as
  `DRY_RUN_FLAG` following the `CLEAN_FLAG`/`FORCE_FLAG` convention.
- A printed admission report containing: the admitted set with computed wave assignment; every
  excluded candidate with a specific structured reason (file_scope collision naming the colliding
  task and overlapping path, unmet predecessor, lock held by another session, or
  stale/unresumable handoff); and a recommended split when the admitted set should not run as a
  single batch.
- A handoff-triage classifier that agrees exactly with the live phase-grouping rules, extracted so
  the live dispatch and the dry-run report call the same code (D1, D2).
- Strict read-only behavior: no `state.json` write, no TODO.md regeneration, no lock acquisition,
  no agent dispatch, no git commit — asserted by test, not merely by review.

**Non-Goals**:
- Modifying `orchestrate-batch-admit.sh` (D3).
- Adding a synchronous batch-approval gate to the autonomous loop. `--dry-run` is an opt-in
  preflight surface a human invokes deliberately; it changes nothing about a normal
  `/orchestrate` run.
- Resolving the open design fork over whether an out-of-batch dependent task should be excluded or
  the batch auto-expanded. The report *surfaces* the case; it does not decide it.
- A self-modification solo-only gate (belongs to the adjacent not-started task).
- Editing anything under `.claude/` — that tree is a gitignored, disposable deploy artifact.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Classifier silently assumes MT-4 semantics for a single-task invocation, producing a confidently wrong report | H | M | D1 Option (A): explicit `engine` argument, both tables transcribed, fixture test asserts the two engines diverge on `partial with no handoff` (Phase 6) |
| Dry-run path mutates something (lock acquire, status reconcile, TODO regen) | H | L | Forbidden-call list in each new script's header; `--dry-run` branch placed *before* GATE IN in `orchestrate.md`; Phase 6 test checksums `state.json`, `TODO.md`, and `.lock/` before and after a report run |
| The live MT-4 grouping and the classifier drift apart after this task | M | M | Phase 5 makes MT-4 *call* the classifier and annotates the retained table as documentation-of, not source-of, the rule |
| Report shows "0 excluded" from a degraded run (batch-admit exit 2) and reads as a clean batch | M | M | Mandatory "Checks run / checks skipped" section; degraded checks named individually; exclusion section always printed even when empty |
| `held-stale` lock reported as an exclusion misrepresents live behavior (live `acquire` overrides stale locks) | M | M | `held-stale` is an informational note, never an exclusion; asserted by fixture test |
| Lock held by the *current* session reported as contention (false positive self-collision) | M | M | Report accepts a session id and compares it against `check`'s `session=` field before excluding |
| N handoff reads for a large batch inflate context | L | L | Handoff is read only for `partial`-status candidates, bounded by the existing `MAX_TASKS=8` guard, which the dry-run reuses rather than raising |
| Scope collision with the adjacent not-started task on `orchestrate.md` / `orchestrate-batch-admit.sh` | M | M | D3 (no edit to the admission script); `orchestrate.md` edits confined to the Options table and a new STAGE 0 branch, touching no existing step body |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 5 | 2 |
| 3 | 4 | 1, 3 |
| 4 | 6 | 3, 4, 5 |

Phases within the same wave can execute in parallel.

**SOURCE-STORE RULE**: every edit below targets `agent-system/extensions/core/**`. No file under
`.claude/**` is edited by any phase — that tree is regenerated from the source store.

**Deliverable-file rule**: no phase may write a task-number citation into any file outside
`specs/**`. Reference durable anchors (script names, section headings, schema names) instead.

---

### Phase 1: Add `DRY_RUN_FLAG` to the shared argument parser [COMPLETED]

**Goal**: `--dry-run` is recognized by the same parser every command already sources, and is
stripped from `FOCUS_PROMPT` so it never leaks into an agent prompt.

**Tasks**:
- [x] In `scripts/parse-command-args.sh`, add `DRY_RUN_FLAG` to the header's Exported Variables
      comment block, described as `"true" or "false" (--dry-run mode: report-only, no dispatch)` *(completed)*
- [x] Add `DRY_RUN_FLAG="false"` to the Step 4 default-initialization block, adjacent to
      `CLEAN_FLAG`/`FORCE_FLAG` *(completed)*
- [x] Add `if [[ "$remaining" =~ --dry-run ]]; then DRY_RUN_FLAG="true"; fi` to the Step 4 flag scan *(completed)*
- [x] Append `| sed 's/--dry-run//g'` to the Step 5 `FOCUS_PROMPT` sed pipeline, placed **before**
      the `--force` entry is irrelevant but keep the chain's existing ordering style *(completed)*
- [x] Add `DRY_RUN_FLAG` to the Step 6 `export` line *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/scripts/parse-command-args.sh` - four edit sites plus the header
  comment; no behavior change for any existing flag

**Verification**:
- `bash -n agent-system/extensions/core/scripts/parse-command-args.sh` passes
- Sourcing with `"901 --dry-run"` yields `TASK_NUMBERS=901`, `DRY_RUN_FLAG=true`, empty
  `FOCUS_PROMPT`
- Sourcing with `"901,902 --dry-run focus text"` yields `TASK_NUMBERS="901 902"`,
  `DRY_RUN_FLAG=true`, `FOCUS_PROMPT="focus text"`
- Sourcing with `"901"` yields `DRY_RUN_FLAG=false` (default preserved)
- Sourcing with `"901 --clean --force --lit"` yields unchanged values for all pre-existing flags

---

### Phase 2: Create the shared handoff-triage classifier [COMPLETED]

**Goal**: One executable, read-only source of truth for "what would this task's status route to,"
carrying both engine tables per Decision D1, consumable by the live dispatch and the dry-run
report alike.

**Tasks**:
- [x] Create `scripts/orchestrate-triage-classify.sh` with usage *(completed)*
      `orchestrate-triage-classify.sh <engine> <task_number> [<task_number> ...]`, where `engine`
      is `single` or `mt`
- [x] Source `deploy-root-guard.sh` and resolve `STATE_FILE` exactly as *(completed)*
      `orchestrate-batch-admit.sh` does
- [x] Validate args: unknown engine, zero task numbers, or a non-integer task number is a usage *(completed)*
      error (exit 2, nothing on stdout, one loud stderr line)
- [x] Read each candidate's `status` and `project_name` from a single `state.json` read *(completed)*
- [x] For `partial`-status candidates only, read *(completed)*
      `specs/{NNN}_{project_name}/.orchestrator-handoff.json` and extract `blockers` (length) and
      `continuation_context` (non-null AND has `handoff_path`); record the file's mtime age in
      minutes. Never read plans, reports, or summaries (Context Flatness Constraint)
- [x] Implement the precedence for `partial`, in this order (transcribed from the single-task *(completed)*
      handler's explicit reads, which both engines share): (1) continuation available ->
      `implement`; (2) else blockers present -> `needs_human`; (3) else neither
- [x] Encode the two engine tables: *(completed)*

      | status | `mt` group | `single` group |
      |--------|-----------|----------------|
      | `not_started` | `research` | `research` |
      | `researched` | `plan` | `plan` |
      | `planned`, `implementing` | `implement` | `implement` |
      | `partial` + continuation | `implement` | `implement` |
      | `partial` + blockers, no continuation | `needs_human` | `needs_human` |
      | `partial`, neither | `implement` | `exit_partial` |
      | `blocked` | `skip` | `needs_human` |
      | `researching`, `planning`, unknown | `skip` | `skip` |
      | terminal (`completed`/`abandoned`/`expanded`) | `terminal` | `terminal` |

- [x] Emit NDJSON, one compact object per candidate in input order, schema *(completed)*
      `orchestrate-triage-v1` with stable field order: `$schema`, `task_number`, `engine`,
      `status`, `group`, `handoff_state` (`absent` | `continuation` | `blockers` | `empty` |
      `not_applicable`), `blocker_count`, `handoff_age_min` (null when no handoff), `reason`
      (machine-templated; never the sole carrier of a fact already present as a field)
- [x] Document in the header: the two-engine rationale (D1), that `engine` MUST be derived from *(completed)*
      the same `len(task_numbers)` test the command uses, the forbidden-call list (no
      `task-lock.sh acquire`, no `update-task-status.sh`, no `generate-todo.sh`, no
      `skill-base.sh` write functions, no `reconcile-task-status.sh` without `--dry-run`, no Agent
      dispatch), and the exit codes (0 = verdicts emitted regardless of group; 2 = usage error or
      state unavailable)
- [x] Register `orchestrate-triage-classify.sh` in `manifest.json` `provides.scripts`, preserving *(completed)*
      the array's existing alphabetical ordering

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` - new file
- `agent-system/extensions/core/manifest.json` - one entry added to `provides.scripts`

**Verification**:
- `bash -n` passes; `jq -e '.provides.scripts | index("orchestrate-triage-classify.sh")'` on the
  manifest is non-null
- Against live `specs/state.json`, `orchestrate-triage-classify.sh mt 901` emits one well-formed
  NDJSON line with `group` matching the task's current status row
- `orchestrate-triage-classify.sh bogus 901` and `orchestrate-triage-classify.sh mt` both exit 2
  with empty stdout
- `git status --porcelain specs/` is empty after a run (no mutation)

---

### Phase 3: Create the dry-run admission report script [COMPLETED]

**Goal**: A single read-only script that composes the collision, lock, predecessor, and triage
checks into the printed report the task specifies, with wave assignment and recommended split
computed by the same algorithm the live dispatch uses.

**Tasks**:
- [x] Create `scripts/orchestrate-dry-run-report.sh` with usage *(completed)*
      `orchestrate-dry-run-report.sh [--session <session_id>] <task_number> [<task_number> ...]`
- [x] Batch validation mirroring `commands/orchestrate.md` MULTI-TASK DISPATCH Step 1: not-found *(completed)*
      and terminal-status candidates become reported skips, not silent drops
- [x] Reuse the existing `MAX_TASKS=8` guard verbatim; if exceeded, report the trim explicitly in *(completed)*
      the report rather than trimming silently. Do not introduce a larger preview-only limit
- [x] Build the intra-batch dependency graph and compute waves with the same Kahn's-algorithm *(completed)*
      logic specified in `orchestrate.md` Steps 2-3, including circular-dependency detection; a
      circular batch prints a named error section and yields an empty admitted set instead of
      aborting the report
- [x] Call `orchestrate-batch-admit.sh` once for the validated set; map `decision == "defer"` to: *(completed)*
      `collision_scope == "in_batch"` -> deferred to a later wave (reported in the split section,
      not the exclusion section); `collision_scope == "cross_batch"` -> **excluded**, reason
      naming `colliding_task_number`, `colliding_task_status`, and `overlapping_path`
- [x] Call `task-lock.sh check <task_number>` per candidate and branch on its exit code: *(completed)*
      `0`/`free` -> no effect; `1`/`held-fresh` with `session=` different from `--session` ->
      **excluded** with holder session and `heartbeat_age_min`; `1`/`held-fresh` with a matching
      session -> no exclusion (self-held, documented as a false-positive guard); `2`/`held-stale`
      -> **informational note only**, never an exclusion, since a live `acquire` would override it;
      `3` -> a named degraded check
- [x] Compute unmet predecessors from `dependencies[]`: an intra-batch non-terminal predecessor *(completed)*
      orders the candidate into a later wave (not an exclusion); an **out-of-batch** non-terminal
      predecessor is an **exclusion** whose reason names the predecessor's number and status and
      labels it `cross_batch`, reusing the `in_batch`/`cross_batch` vocabulary the admission schema
      already established
- [x] Call `orchestrate-triage-classify.sh <engine> <validated_tasks...>` with *(completed)*
      `engine = single` when exactly one task number was given and `mt` otherwise — the identical
      test `orchestrate.md` STAGE 0 uses. Map `needs_human` and `exit_partial` to **exclusions**
      (reason carrying `blocker_count` and `handoff_age_min`), `skip` to a reported skip, and
      `research`/`plan`/`implement` to admitted with the phase that would be dispatched
- [x] Print the report with these sections, in this order, **all of them unconditionally**: *(completed)*
      1. **Header** — invocation, engine (`single`/`mt`, and which precedence table that selects),
         candidate count, session id if supplied
      2. **Checks run** — one line per check (`file_scope collision`, `lock contention`,
         `predecessor`, `handoff triage`) stating `ran` or `SKIPPED (degraded: <reason>)`. Never
         present a degraded run's output as equivalent to a clean one
      3. **Admitted** — task, status, computed wave, phase that would be dispatched
      4. **Excluded** — task, reason code, structured detail. When empty, print an explicit
         `0 excluded (all N candidates admitted)` line; **never** omit or collapse this section
      5. **Notes** — non-excluding informational findings (`held-stale` locks, in-batch wave
         deferrals, `MAX_TASKS` trim, out-of-batch dependency edges)
      6. **Recommended split** — the same wave numbers the live dispatch would use, rendered as
         `Wave N: <tasks>`; for a one-task batch, `batch of one — no split applicable`
- [x] Header contract comment: the same forbidden-call list as Phase 2, plus an explicit statement *(completed)*
      that this script never writes any file and never calls `task-lock.sh acquire`
- [x] Exit codes: 0 whenever a report was printed (regardless of how many exclusions — verdicts *(completed)*
      are data, not errors, matching the admission script's convention); 2 on usage error or
      unreadable `state.json`
- [x] Register `orchestrate-dry-run-report.sh` in `manifest.json` `provides.scripts`, preserving *(completed)*
      alphabetical ordering

**Timing**: 2 hours

**Depends on**: 2

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` - new file
- `agent-system/extensions/core/manifest.json` - one entry added to `provides.scripts`

**Verification**:
- `bash -n` passes; manifest entry present
- Against live state, `orchestrate-dry-run-report.sh 901 902` prints all six sections including an
  Excluded section, and its Recommended split wave numbers match a hand-run of `orchestrate.md`
  Steps 2-3 on the same two tasks
- A run against a batch with no exclusions still prints the Excluded section with the explicit
  `0 excluded` line
- `git status --porcelain` and a `sha256sum` of `specs/state.json` and `specs/TODO.md` are
  unchanged across a run; no `.lock/` directory is created for any candidate
- `grep -n 'task-lock.sh acquire\|update-task-status\|generate-todo\|skill_preflight\|skill_postflight'`
  on the new script returns only the forbidden-call header comment, never a call site

---

### Phase 4: Wire `--dry-run` into the `/orchestrate` command [COMPLETED]

**Goal**: `/orchestrate N --dry-run` runs the report and stops, never reaching GATE IN, the skill,
an agent, or a commit — for both single-task and multi-task argument shapes.

**Tasks**:
- [x] Add a `--dry-run` row to the Options table in `commands/orchestrate.md`: *(completed)*
      "Report-only: run the full admission analysis and print the verdict report; dispatch nothing
      and mutate nothing", default `false`
- [x] In STAGE 0, immediately after `parse-command-args.sh` is sourced and **before** the *(completed)*
      `len(TASK_NUMBERS)` branch, add the dry-run short-circuit:
      ```bash
      if [ "${DRY_RUN_FLAG:-false}" = "true" ]; then
        bash .claude/scripts/orchestrate-dry-run-report.sh --session "$SESSION_ID" $TASK_NUMBERS
        # STOP HERE.
      fi
      ```
      with a note that `SESSION_ID` may be unset at this point (the flag is parsed before GATE IN);
      pass `--session` only when it is non-empty
- [x] Add an explicit prohibition block beneath it: in dry-run mode the command MUST NOT continue *(completed)*
      to MULTI-TASK DISPATCH, MUST NOT reach CHECKPOINT 1 (GATE IN), MUST NOT invoke the Skill or
      Agent tools, MUST NOT acquire a task lock, and MUST NOT run CHECKPOINT 3 (COMMIT). Phrase it
      in the same imperative style as the existing Anti-Bypass Constraint
- [x] Add a short paragraph explaining that the report uses the same admission analysis the live *(completed)*
      path uses (naming `orchestrate-batch-admit.sh` and `orchestrate-triage-classify.sh` by path),
      and that the printed wave numbers are the same ones a live run would dispatch — referencing
      the schemas by path, never restating them
- [x] Add a `--dry-run` line to the Output section describing the report-only outcome *(completed)*

**Timing**: 1 hour

**Depends on**: 1, 3

**Files to modify**:
- `agent-system/extensions/core/commands/orchestrate.md` - Options table row, new STAGE 0
  short-circuit block, prohibition block, Output line. No existing step body is rewritten

**Verification**:
- The dry-run block appears textually before both the `len(TASK_NUMBERS) == 1` fall-through and
  the MULTI-TASK DISPATCH heading
- `grep -c '^- \*\*' ` style checks are unnecessary; instead confirm the file still contains its
  original STAGE 0 / MULTI-TASK DISPATCH / CHECKPOINT 1 / STAGE 2 / CHECKPOINT 2 / CHECKPOINT 3
  headings unchanged (`grep -n '^### \|^#### '`)
- No task-number citation was introduced (`grep -nE '\btasks? [0-9]{2,4}\b'` shows only
  pre-existing occurrences, which this phase must not add to)

---

### Phase 5: Make live Stage MT-4 consume the shared classifier [COMPLETED]

**Goal**: Satisfy "one code path, two consumers" — the live dispatch grouping and the dry-run
report read the same rule, and MT-4's `partial with blockers` row gains the pre-dispatch mechanism
it currently lacks.

**Tasks**:
- [x] In `skills/skill-orchestrate/SKILL.md` Stage MT-4, immediately above the Phase grouping *(completed)*
      table, add the classifier call:
      ```bash
      bash .claude/scripts/orchestrate-triage-classify.sh mt "${eligible_tasks[@]}"
      ```
      with instructions to `jq`-filter the NDJSON by `.group` into `research_tasks`, `plan_tasks`,
      `implement_tasks`, `failed_tasks` (from `needs_human`), and skip (from `skip`/`terminal`)
- [x] Retain the existing Phase grouping table verbatim, re-labelled as documentation of the rule *(completed)*
      the script transcribes, with a one-line note naming
      `scripts/orchestrate-triage-classify.sh` as the executable source of truth and stating that
      the table and the script must be changed together
- [x] State explicitly that this call supplies the pre-dispatch `blockers`/`continuation_context` *(completed)*
      read for `partial` tasks that the table previously only asserted, and that its precedence is
      continuation > blockers > neither
- [x] Add the degradation path, mirroring the wording already used for the admission script: exit *(completed)*
      2 means state is unavailable; log a loud warning and fall back to the table's grouping
      inline rather than silently skipping dispatch
- [x] Add a cross-reference in the single-task `State: partial` handler noting that the identical *(completed)*
      rule is available as `orchestrate-triage-classify.sh single`, and that the `single` engine's
      `partial`-with-neither outcome (`exit_partial`) is intentionally different from `mt`'s —
      pointing at the plan's Decision D1 by description, not by task number
- [x] Confirm no other Stage MT-4 behavior changes: task-lock acquire, batching rule, completion *(completed)*
      sequencing, per-task postflight, and lock release are all untouched

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage MT-4 grouping section
  gains a script call plus annotations; single-task `partial` handler gains a cross-reference

**Verification**:
- `grep -n 'orchestrate-triage-classify.sh' ` on SKILL.md returns both the MT-4 call and the
  single-task cross-reference
- The Phase grouping table's rows are byte-identical to their pre-edit content (diff shows only
  added surrounding text)
- Stage MT-4's `task-lock.sh acquire` block and the Stage MT-3 step 4.5 admission block are
  unchanged in the diff
- No task-number citation introduced

---

### Phase 6: Fixture-based test suite and read-only assertion [COMPLETED]

**Goal**: Deterministic regression coverage for both new scripts, including the engine divergence
that Decision D1 turns on and a hard assertion that a dry-run mutates nothing.

**Tasks**:
- [x] Create `specs/901_orchestrate_dry_run_admission_report/fixtures/state-dry-run.json`: a *(completed)*
      synthetic `state.json` covering — a clean pair of admittable tasks; a cross-batch file_scope
      collision; an out-of-batch non-terminal predecessor; a `partial` task with blockers and no
      continuation; a `partial` task with neither blockers nor continuation; a `partial` task with
      a valid continuation; a terminal task; and a `not_started` task
- [x] Create the matching handoff fixtures under the fixtures directory so the classifier's *(completed)*
      `partial` reads have deterministic input
- [x] Create `specs/901_orchestrate_dry_run_admission_report/tests/test-triage-classify.sh` *(completed)*
      following the scratch-deploy-tree pattern already proven in this repository's admission-script
      suite: `mktemp -d`, copy the script plus `deploy-root-guard.sh` into
      `<scratch>/proj/.claude/scripts/`, seed `<scratch>/proj/specs/state.json` from the fixture,
      `trap cleanup EXIT`, and never touch the real `.claude/` tree
- [x] Triage assertions: every row of both engine tables; the `partial` precedence order *(completed)*
      (continuation wins over blockers); **the divergence case** — the same `partial`-with-neither
      task classifies as `implement` under `mt` and `exit_partial` under `single`; usage errors
      exit 2 with empty stdout
- [x] Create `specs/901_orchestrate_dry_run_admission_report/tests/test-dry-run-report.sh` with the *(completed)*
      same scratch-tree pattern (copying `orchestrate-batch-admit.sh`, `task-lock.sh`,
      `orchestrate-triage-classify.sh`, and the report script)
- [x] Report assertions: all six sections present on every run; the Excluded section present with *(completed)*
      an explicit `0 excluded` line on a clean batch; a cross-batch collision exclusion names the
      colliding task and overlapping path; an out-of-batch unmet predecessor is excluded while an
      in-batch one only affects wave order; `held-fresh` by a different session excludes;
      `held-fresh` by the supplied `--session` does **not** exclude; `held-stale` appears under
      Notes and **not** under Excluded; a `partial`-with-blockers task is excluded as needs-human;
      wave numbers match a hand-computed Kahn ordering for the fixture
- [x] Degradation assertion: with `state.json` removed from the scratch tree, the report exits 2 *(completed)*
      loudly rather than printing a misleading clean report
- [x] **Read-only assertion**: `sha256sum` every file in the scratch `specs/` tree before and after *(completed)*
      a report run and require the manifest to be identical; require that no `.lock/` directory
      exists afterward
- [x] Run both suites; record any deviation between a prediction in this plan and observed correct *(completed)*
      behavior in the summary rather than silently adjusting the test to match the script

**Timing**: 1.5 hours

**Depends on**: 3, 4, 5

**Files to modify**:
- `specs/901_orchestrate_dry_run_admission_report/fixtures/state-dry-run.json` - new
- `specs/901_orchestrate_dry_run_admission_report/fixtures/` handoff fixtures - new
- `specs/901_orchestrate_dry_run_admission_report/tests/test-triage-classify.sh` - new
- `specs/901_orchestrate_dry_run_admission_report/tests/test-dry-run-report.sh` - new

**Verification**:
- Both suites exit 0 with zero FAIL lines
- The real repository `.claude/` tree and `specs/state.json` are unmodified after running them
  (`git status --porcelain` clean apart from the new test/fixture files)

---

## Testing & Validation

- [x] `bash -n` clean on `parse-command-args.sh`, `orchestrate-triage-classify.sh`, and
      `orchestrate-dry-run-report.sh`
- [x] Pre-existing flag parsing (`--clean`, `--force`, `--lit`, `--team`, `--hard`, model flags) is
      byte-for-byte unchanged in behavior after the Phase 1 edit
- [x] `--dry-run` is stripped from `FOCUS_PROMPT` and therefore never reaches an agent prompt
- [x] The triage classifier reproduces every row of the live Stage MT-4 phase-grouping table under
      `engine=mt` (the task's acceptance criterion) and the single-task `partial` handler's
      precedence under `engine=single`
- [x] The engine divergence is asserted, not assumed: one fixture task classifies differently under
      the two engines and the test names why
- [x] A dry-run run mutates nothing: `state.json`, `TODO.md`, and all `.lock/` directories are
      byte-identical before and after; no `git` invocation occurs
- [x] `task-lock.sh` is invoked only in `check` mode anywhere in the new code
      (`grep -n 'task-lock.sh' ` on both new scripts shows only `check`)
- [x] The report reads only `state.json` and `.orchestrator-handoff.json` — no plan, report, or
      summary file is opened (Context Flatness Constraint)
- [x] Both new scripts are registered in `manifest.json` `provides.scripts`
- [x] No file outside `specs/**` gained a task-number citation
- [x] No file under `.claude/**` was edited by any phase (`git status` shows no `.claude/` entries;
      the tree is gitignored and regenerated from the source store)

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` (new, shared classifier)
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` (new, report composer)
- `agent-system/extensions/core/scripts/parse-command-args.sh` (modified: `DRY_RUN_FLAG`)
- `agent-system/extensions/core/commands/orchestrate.md` (modified: flag + STAGE 0 short-circuit)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (modified: MT-4 consumes the
  shared classifier)
- `agent-system/extensions/core/manifest.json` (modified: two `provides.scripts` entries)
- `specs/901_orchestrate_dry_run_admission_report/tests/test-triage-classify.sh` (new)
- `specs/901_orchestrate_dry_run_admission_report/tests/test-dry-run-report.sh` (new)
- `specs/901_orchestrate_dry_run_admission_report/fixtures/state-dry-run.json` and handoff
  fixtures (new)

**Deploy note**: the `.claude/` tree is a gitignored, disposable deploy artifact. The new scripts
become live only after the core extension is re-deployed from the source store by the normal
loader path; no phase edits `.claude/` directly, and the tests deliberately run against a scratch
deploy tree so they pass before any re-deploy happens.

## Rollback/Contingency

Every change is additive and independently revertible:

- **Phase 1** — remove the four `DRY_RUN_FLAG` lines. No existing flag is touched, so reverting
  cannot regress any other command.
- **Phases 2-3** — delete the two new scripts and their `manifest.json` entries. Nothing in the
  pre-existing system references them except the Phase 4/5 edits.
- **Phase 4** — remove the STAGE 0 short-circuit block and the Options row; `/orchestrate` returns
  to ignoring an unrecognized `--dry-run` token (which parses harmlessly into `FOCUS_PROMPT` only
  if Phase 1 is also reverted, so revert Phase 4 before Phase 1 if reverting both).
- **Phase 5** — remove the classifier call and revert the annotation; the retained Phase grouping
  table is unchanged, so Stage MT-4 falls back to exactly its current documented behavior. This is
  the only phase that touches a live dispatch path, and it is the first to revert if any
  orchestration regression is observed.
- **Phase 6** — test and fixture files are inert; deleting them affects no runtime path.

If the report proves too noisy or too slow in practice, the contained fix is to reduce the Notes
section — never to omit the Excluded section, whose unconditional presence is the property that
keeps the report worth reading.

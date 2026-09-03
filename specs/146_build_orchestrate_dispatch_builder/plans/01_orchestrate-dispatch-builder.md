# Implementation Plan: Task #146

- **Task**: 146 - Build orchestrate-build-dispatch.sh: per-dispatch context files, pointer prompts, and the user-decision contract
- **Status**: [IMPLEMENTING]
- **Effort**: 14 hours
- **Dependencies**: 145 (completed)
- **Research Inputs**: `specs/146_build_orchestrate_dispatch_builder/reports/01_orchestrate-build-dispatch.md`
- **Artifacts**: plans/01_orchestrate-dispatch-builder.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Move every dispatch prompt the `/orchestrate` lead currently authors inline into a script-generated
per-dispatch context file, leaving the lead with a fixed one-sentence pointer prompt. A new
`agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` performs Stage 3.5 (Dispatch
Prep) in full, gathers the additional per-dispatch inputs the inline recipes interpolate (task
description, artifact round, report/plan paths, normalized continuation pointer, handoff path,
dispatch sequence, territory), writes `specs/{NNN}_{slug}/.dispatch/{seq}.md`, and prints
`{dispatch_file, model}`. All 11 physical `Run **Stage 3.5**` call sites in
`skills/skill-orchestrate/SKILL.md` are replaced by one script call plus a fixed pointer prompt, and
the Stage 3.5 prose is deleted in favor of a pointer to the script. Alongside this, the
user-decision contract is written once under `context/standards/`, referenced (never restated) from
the dispatch file and the agent contracts, and added as an optional field to
`context/formats/return-metadata-file.md` and `docs/architecture/handoff-schema.md`.

**Edit target is the source store**: every change lands under `agent-system/extensions/core/**`.
Never hand-author under `.claude/**` — that tree is a disposable deploy artifact
(`.claude/rules/source-store-deploy-boundary.md`).

Definition of done: `grep -c "Run \*\*Stage 3.5" SKILL.md` returns 0; a generated dispatch file
diffs field-for-field against the inline recipe it replaces; the lead's authored prompt bytes for a
real 3-task multi-task cycle drop by >= 90% (measured, reported); the routing-driven agent-contract
sweep is reported with explicit negatives; a research dispatch setting `user_decision` is shown
reaching `.return-meta.json` intact; the full gate set is green.

### Research Integration

The research report supplies the four facts this plan is built on, all independently re-verified
while planning:

1. **11 physical call sites, not 8.** `grep -c "Run \*\*Stage 3.5"` on
   `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` returns **11** — 8 single-task
   Stage 4 sites (`not_started`, `researching`, `researched`, `planning`, `planned/implementing`
   hard branch, `planned/implementing` base branch, `partial` continuation-available, `partial`
   no-continuation) plus 3 MT-4 loop bodies (`research_tasks`, `plan_tasks`, `implement_tasks`).
   The task description's "five single-task sites" and `specs/PATH.md`'s "eight dispatch sites" are
   correct *logical-recipe* counts (5 single-task recipes + 3 MT-4 loops = 8); the physical edit
   count is 11. Both numbers are stated here so the implementer edits all 11.
2. **Four/six auxiliary dispatches are out of scope.** The H4 adversarial-verification re-dispatch
   (2 occurrences), Stage 5a's fork and reviser dispatches, Stage 5b's divergence audit, and Stage
   6's fork/reviser/re-implement sequence do not call Stage 3.5 today and keep their inline prompts
   unchanged.
3. **`user_decision` has zero existing precedent** in either target schema doc. Its contract file
   goes in `context/standards/`, not `context/contracts/` — every file in `context/contracts/` is
   hard-mode-gated and loaded conditionally, while this contract applies in base mode too.
   It must not be conflated with `handoff-schema.md`'s existing informational `decisions_made`.
4. **The agent-contract sweep is routing-table-driven.** `find agent-system/extensions -path
   "*/agents/*.md"` returns ~65 files across ~20 extensions, most of which `skill-orchestrate`
   can never dispatch. The sweep walks each `manifest.json`'s `routing_agents` (and
   `routing_agents_hard`) blocks, mirroring Stage 1b/MT-2 resolution.

### Prior Plan Reference

No prior plan. `specs/146_build_orchestrate_dispatch_builder/plans/` was empty at planning time.

### Roadmap Alignment

No `specs/ROADMAP.md` found. The governing sequencing document is `specs/PATH.md`, where this task
is **Stage A.2** of the thin-lead critical path: it produces the second of the three cycle scripts
(`orchestrate-build-dispatch.sh`), consumed later by `orchestrate-cycle-plan.sh` (Stage A.3, a
separate task). This task wires the script into the still-existing per-cycle bash in `SKILL.md`;
it does not build or wire the batch planner.

## Open Decisions (stated explicitly, resolved here)

**`.dispatch/{seq}.md` accumulates one file per dispatch** — unlike every other per-task ephemeral
runtime file, each of which is a singleton overwritten in place or `rm -f`'d exactly once. No
existing reaper covers a growing per-task directory: `reap-session-runtime-files.sh` deliberately
does not recurse into `specs/{NNN}_{SLUG}/`, and `task-lock.sh reap` only handles `.lock/`.

**Decision (adopted, per the research recommendation)**: mirror the singleton files' lifecycle —
`rm -rf "${TASK_DIR}/.dispatch/"` co-located with every existing loop-termination
`rm -f "$loop_guard_file"` site and at the per-task MT-5 equivalent. No new age-based reaper is
built. Rationale: dispatch files are *inputs*, not outcomes — the outcome lives in
`.return-meta.json` and `.orchestrator-handoff.json`, both already durable-provenance — so they
carry no audit value once their one dispatch completes, and this keeps `.dispatch/` consistent with
every other per-task ephemeral file's disposition. Phase 9 implements this; it is not deferred.

## Goals & Non-Goals

**Goals**:
- A single `orchestrate-build-dispatch.sh` that reproduces every input the inline dispatch recipes
  interpolate today, byte-for-byte in semantics, and writes it to `.dispatch/{seq}.md`.
- All 11 physical dispatch sites reduced to one script call plus a fixed pointer prompt.
- Stage 3.5's prose deleted from `SKILL.md`, replaced by a pointer to the script.
- The user-decision contract written once in `context/standards/`, referenced from the dispatch
  file and every dispatchable agent contract, and added as an optional field to both schema docs.
- `.dispatch/` registered across every runtime-file surface (class table, `.gitignore`, staging
  scope, tracking-check probes) and cleaned up at loop termination.
- Measured, reported acceptance numbers.

**Non-Goals**:
- Building or wiring `orchestrate-cycle-plan.sh` (a separate Stage A.3 task). This script is
  called by the existing per-cycle bash in `SKILL.md`.
- Touching the auxiliary dispatch sites (H4 re-verification, Stage 5a fork/reviser, Stage 5b audit,
  Stage 6 fork/reviser/re-implement). They keep inline prompts.
- Changing what any agent receives semantically. This is a transport change only.
- Making the lead read the dispatch file. The lead writes a path into a prompt and nothing more.
- Minting `dispatch_seq` or stamping `dispatch_start_ts` inside the script — both remain
  caller-owned and are passed in.
- Adding a new age-based reaper (see Open Decisions).
- Any edit under `.claude/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer edits only 5 or 8 of the 11 physical call sites, leaving live inline Stage 3.5 prose | H | M | Phase 7 gate: `grep -c "Run \*\*Stage 3.5" SKILL.md` must return 0; Phases 6 and 7 each re-grep before closing |
| The continuation dual-form jq expression is hand-copied and drifts from `orchestrate-triage-classify.sh`'s `continuation_ok` predicate (a drift the codebase already annotates as having happened once) | H | M | Phase 4 extracts the resolution into a shared helper the script and the predicate both use, or (fallback) reuses the jq expression verbatim; Phase 5 adds a byte-comparison test that fails on divergence |
| A generated dispatch file silently drops a Stage 3.5 input | H | M | Phase 5's parity test generates a file for a real task and diffs field-by-field against the inline recipe's enumerated inputs; the test enumerates all inputs explicitly rather than spot-checking |
| `.dispatch/` files get committed into `specs/` because a registration surface was missed | M | M | Phase 2 lands all four registration surfaces *before* the script first writes a file (Phase 3 depends on Phase 2); `check-runtime-file-tracking.sh` probe added in the same phase |
| `.dispatch/` accumulation grows unbounded on long hard-mode runs | M | M | Phase 9 implements the Stage 8 / MT-5 `rm -rf`, in this task, not deferred |
| Agent-contract sweep misses an extension whose `routing_agents` uses a compound task_type (e.g. `present:grant`) | M | M | Phase 8 drives the sweep through `manifest-routing-lib.sh`'s own `routing_lookup`, not a re-derived grep |
| `user_decision`'s contract file is placed in `context/contracts/` and thereby silently hard-mode-gated by a downstream reader | H | L | Phase 1 places it in `context/standards/`; the dispatch file injects its reference unconditionally, outside the `hard_contracts_block` conditional |
| `validate-return-meta.sh` rejects or strips the new optional `user_decision` field | M | M | Phase 1 runs the validator against a sample carrying the field and adjusts the validator if it is field-allowlisted |
| Task-number references leak into deliverables outside `specs/**` | M | M | Every phase's verification runs `scripts/check-task-references.sh`; cite durable anchors (filenames, section headings), never task numbers |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |
| 5 | 6, 8 | 5 |
| 6 | 7 | 6 |
| 7 | 9 | 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: User-decision contract and schema-doc fields [COMPLETED]

**Goal**: Write the user-decision contract once, in a location that is not hard-mode-gated, and add
`user_decision` as an optional field to both schema documents by reference.

**Tasks**:
- [x] Create `agent-system/extensions/core/context/standards/user-decision-contract.md` stating: *(completed)*
      the orchestrator never asks the user on its own and never decides; agents decide and record
      each decision with its reasoning in their artifact; an agent sets
      `user_decision: {question, options: [...], recommended, blocking: true|false}` only when a
      choice genuinely requires the user's judgment (a preference the artifacts cannot infer, an
      external cost or risk the user must accept, an ambiguity research cannot resolve); a
      non-blocking decision proceeds on `recommended` and is surfaced for review; a blocking one
      stops cleanly at a resumable point; the postflight script relays the field as a verdict; the
      lead puts the question once, batched at cycle end. Include the field's exact JSON shape and a
      short "when NOT to raise one" list.
- [x] Add a `### user_decision (optional)` subsection to
      `context/formats/return-metadata-file.md`, *(completed)* sited alongside the other optional top-level
      fields (`memory_candidates`, `reflection`, `proposed_file_scope`). Give the shape and a
      one-line pointer to the contract file; do not restate the contract.
- [x] Add a `### user_decision (optional)` subsection to `docs/architecture/handoff-schema.md` *(completed)*
      alongside `decisions_made`, with an explicit note distinguishing the two: `decisions_made` is
      informational/historical, `user_decision` is a live forward-looking request.
- [x] Confirm `user_decision` is producer-owned and survives a later writer's read-modify-write, *(completed)*
      consistent with `return-metadata-file.md`'s "Multiple Sequential Writers" section; state this
      in the new subsection.
- [x] Run `bash agent-system/extensions/core/scripts/validate-return-meta.sh` (or the deployed *(completed: not field-allowlisted, validator passed sample with user_decision intact)*
      equivalent) against a sample `.return-meta.json` carrying `user_decision`; if the validator
      is field-allowlisted, add the field to its allowlist.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/context/standards/user-decision-contract.md` - new file, the single
  home of the contract
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - new optional-field
  subsection
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - new optional-field
  subsection plus the `decisions_made` disambiguation
- `agent-system/extensions/core/scripts/validate-return-meta.sh` - only if field-allowlisted

**Verification**:
- The contract text exists in exactly one file; `grep -rn "user_decision" agent-system/extensions/core/`
  shows the two schema docs referencing, not restating, it.
- A sample `.return-meta.json` with `user_decision` passes `validate-return-meta.sh`.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` clean.

---

### Phase 2: Register `.dispatch/` across every runtime-file surface [COMPLETED]

**Goal**: Make `.dispatch/` a recognized ephemeral runtime-file class everywhere before the script
first writes into it, so no dispatch file can ever be staged or committed.

**Tasks**:
- [x] Add a row for `.dispatch/{seq}.md` to `context/standards/orchestrator-runtime-files.md`'s *(completed)*
      class table: **Ephemeral** disposition, directory class (like `.lock/`), with a one-line note
      that it is the only per-task ephemeral entry that accumulates rather than being a singleton,
      and that its disposition is bulk `rm -rf` at loop termination (see Phase 9).
- [x] Add `**/.dispatch/` to the repo-root `.gitignore` ephemeral block, adjacent to `**/.lock/`. *(completed)*
- [x] Add `":(exclude)${task_dir}/.dispatch/"` to **every** `ephemeral_excludes` array in *(completed: 3 array literals found and updated -- 2 in git-staging-scope.md, 1 candidate_excludes in git-commit-scoped.sh)*
      `context/standards/git-staging-scope.md`.
- [x] Add a probe entry inside the directory to *(completed)*
      `scripts/check-runtime-file-tracking.sh`'s `EPHEMERAL_PROBES` array, following the
      `${PROBE_DIR}/.lock/holder.json` pattern (e.g. `${PROBE_DIR}/.dispatch/1.md`) — the probe must
      be a file *inside* the directory, since `git check-ignore` is tested per path.
- [x] Re-run the tracking check and confirm the new probe reports OK. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: `git-staging-scope.md` is expected to contain **two** `ephemeral_excludes`
array literals (a primary and a restated copy). Confirm at implementation time with
`grep -n "ephemeral_excludes=(" agent-system/extensions/core/context/standards/git-staging-scope.md`
and update every occurrence found, not the two assumed here.

**Files to modify**:
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - class-table row
- `.gitignore` (repo root) - `**/.dispatch/`
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - all `ephemeral_excludes`
  arrays
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` - `EPHEMERAL_PROBES` entry

**Verification**:
- `bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` passes with the new
  probe reported OK.
- `git check-ignore -q specs/000_probe/.dispatch/1.md` succeeds.
- `grep -c "\.dispatch" agent-system/extensions/core/context/standards/git-staging-scope.md` equals
  the confirmed `ephemeral_excludes` array count.

---

### Phase 3: `orchestrate-build-dispatch.sh` — CLI and Stage 3.5 replication [COMPLETED]

**Goal**: Create the script with its full CLI surface and the four Stage 3.5 outputs plus model
resolution, reproducing Stage 3.5's semantics exactly.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` with the *(completed)*
      documented signature: `<task_number> <phase> --session SID --seq N [--clean] [--lit] [--hard]
      [--fast] [--model M] [--focus "..."] [--territory "..."]`, plus `--dispatch-start-ts` for the
      caller-stamped window timestamp. Follow the doc-header/usage/exit-code conventions of
      `orchestrate-triage-classify.sh` and `orchestrate-recover-outcome.sh`.
- [x] Set the exec bit; use the repo's standard strict-mode idiom for a single-shot script. *(completed)*
- [x] Resolve `memory_context`: `bash .claude/scripts/memory-retrieve.sh "$description" *(completed)*
      "$task_type" "$memory_arg3"`, gated on `clean_flag != "true"`, with `memory_arg3="$focus_prompt"`
      only for `phase=research` and `""` otherwise. Never emit an empty tag.
- [x] Resolve `lit_context` by executing `context/patterns/lit-stage4a-flow.md`'s six-directive *(completed)*
      resolution via `literature-lit-flag-resolve.sh`, branching on
      `LIT_DISABLED|SUBINDEX_PRESENT|GLOBAL_MISSING|PROMPT_NEEDED|AUTONOMOUS_GLOBAL|SPARSE_PROMPT_NEEDED`.
      The script runs headless: hard-code `orchestrator_mode: true` semantics so the two interactive
      directives always resolve to the `[lit:auto]` fallback and `AskUserQuestion` is never
      attempted.
- [x] Emit `effort_note` as one line, only when `effort_flag` is non-empty. *(completed)*
- [x] Build `hard_contracts_block` only when `hard_mode == "true"`: source *(completed)*
      `scripts/lib/manifest-routing-lib.sh`, use the phase-keyed `core_contracts` array (research:
      anti-analysis / reference-grounding / adversarial-verification; plan: reference-grounding /
      wrap-up / anti-analysis; implement: anti-analysis / wrap-up [+ territory when set] / recovery
      / phase-closure / pre-edit-gate), then apply extension overrides from `routing_lookup_flat
      "hard_contracts" "$task_type"` — **never** `routing_lookup`, which assumes a different
      manifest shape. Honor `replace:{basename}:{path}` in-place substitution by basename; append
      all other entries additively in manifest order. Wrap the result in `<hard-mode-contracts>`
      with one `- context/contracts/{file}` line per entry. Call the routing functions directly
      (never via command substitution) and read `$_ROUTE_LAST_VALUE`/`$_ROUTE_LAST_VIA`.
- [x] Resolve `model` as pass-through of `model_flag` (`haiku`/`sonnet`/`opus`/`fable`), empty when *(completed)*
      unset — never the string `"null"`.
- [x] Preserve the injection order for the four block outputs: `memory_context`, `lit_context`, *(completed)*
      `effort_note`, `hard_contracts_block`, each skipped when empty.

**Timing**: 2 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - new file

**Verification**:
- `bash -n` clean; `shellcheck` clean at the repo's configured level.
- Invoking the script for a real task with `--hard` produces a `<hard-mode-contracts>` block whose
  entries match those the inline Stage 3.5 recipe produces for the same task_type and phase.
- With `--clean`, no memory block is emitted; without it, the block matches
  `memory-retrieve.sh`'s direct output.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet` still green.

---

### Phase 4: `orchestrate-build-dispatch.sh` — per-dispatch gatherers and file writer [COMPLETED]

**Goal**: Gather the additional per-dispatch inputs the inline recipes interpolate, write
`specs/{NNN}_{slug}/.dispatch/{seq}.md`, and print the one-line JSON return.

**Tasks**:
- [x] Read `description` and `task_type` directly from `specs/state.json` *(completed: used skill_validate_input (skill-base.sh) rather than re-deriving the jq -- equivalent effect, DRYer)*
      (`.active_projects[] | select(.project_number == $num)`). This removes the
      `DESCRIPTION`/`description` case-alias reconciliation entirely — the script becomes the single
      source and callers no longer pre-extract it.
- [x] Resolve the artifact round by sourcing `scripts/skill-base.sh` and calling *(completed)*
      `skill_read_artifact_number` directly (do not re-implement its fallback-count logic).
      Phase-to-mode map: `research` -> `mode=current`, `artifact_dir=reports/`; `plan` ->
      `mode=prev`, `artifact_dir=plans/`; `implement` -> `mode=prev`, `artifact_dir=summaries/`.
      `mode=prev` is `next_artifact_number - 1` floored at 1 — the planner and implementer share the
      round research opened. Record both `ARTIFACT_NUMBER` and `ARTIFACT_PADDED` in the file.
- [x] For `phase=plan`, resolve the latest report path with the existing state.json jq pattern *(completed)*
      (first `.artifacts[]` entry of `type=="report"`, `// ""`).
- [x] For `phase=implement`, resolve the latest plan path with *(completed)*
      `ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1`.
- [x] For `phase=implement`, resolve the continuation pointer from `.orchestrator-handoff.json` *(completed: extracted to scripts/lib/continuation-pointer-lib.sh, shared with orchestrate-triage-classify.sh's continuation_ok)*
      accepting **both** forms — nested `continuation_context.handoff_path` (deprecated) and flat
      top-level `continuation_path` (the live form) — normalized to
      `{handoff_path, orchestrator_mode: true}` or `null`. **Extract this into a shared helper**
      (e.g. a function in `scripts/lib/`) that `orchestrate-triage-classify.sh`'s `continuation_ok`
      predicate also uses, collapsing the two existing hand-copied implementations into one. If
      extraction proves out of reach within the phase, reuse the jq expression verbatim and record
      why in the phase notes — but the shared helper is the intended outcome.
- [x] Record `handoff_path` (`${task_dir_abs}/.orchestrator-handoff.json`), the caller-supplied *(completed)*
      `--seq N`, and the caller-supplied `--dispatch-start-ts`. The script neither mints the sequence
      nor stamps its own timestamp; both stay caller-owned.
- [x] Pass `--territory "..."` through as an opaque JSON string when set; never reconstruct it. *(completed)*
- [x] Append the user-decision contract reference unconditionally — outside the `hard_mode` *(completed)*
      conditional — pointing at `context/standards/user-decision-contract.md` (Phase 1), with a
      short inline reminder of when to set the field. Do not restate the contract.
- [x] `mkdir -p "${TASK_DIR}/.dispatch"` and write `{seq}.md` with a stable section order: *(completed)*
      identity (task, phase, agent-facing framing), description, task_type, artifact round and
      output path, phase-specific inputs (report path / plan path / continuation pointer), handoff
      path and dispatch sequence, territory, then the four Stage 3.5 blocks in their preserved
      order, then the user-decision contract reference.
- [x] Print exactly one line of JSON: `{"dispatch_file": "...", "model": "..."}`. *(completed)*

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - gatherers, writer, JSON
  return
- `agent-system/extensions/core/scripts/lib/` - new shared continuation-pointer helper (name chosen
  at implementation time)
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` - switch `continuation_ok`
  onto the shared helper

**Verification**:
- Running the script for a real task in each of the three phases writes a well-formed
  `.dispatch/{seq}.md` and prints exactly one parseable JSON line (`jq -e . <<< "$out"`).
- The written file contains a non-empty value for every input the corresponding inline recipe
  interpolates.
- `git status --short` shows no `.dispatch/` path (Phase 2's ignore rules hold).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet` green.

---

### Phase 5: Parity test and anti-drift test [COMPLETED]

**Goal**: Prove mechanically that a generated dispatch file carries every input the inline recipe
would have interpolated, and that the continuation-pointer resolution cannot drift again.

**Tasks**:
- [x] Add `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` *(completed)*
      (auto-discovered by `run-all.sh`; set the exec bit — a lost exec bit degrades to a loud SKIP,
      not a false pass).
- [x] Parity assertions: for each of `research`, `plan`, `implement`, generate a dispatch file *(completed)*
      against a fixture task and assert the presence and non-emptiness of every enumerated input —
      description, task_type, artifact round + padded form + output dir, phase-specific path
      (report / plan / continuation), handoff path, dispatch seq, dispatch start ts, territory when
      supplied, memory block when not `--clean`, lit block when `--lit`, effort note when
      `--fast`/`--hard`, hard-contracts block when `--hard`, user-decision contract reference
      always. Enumerate explicitly; do not spot-check.
- [x] Negative assertions: `--clean` suppresses the memory block; absent `--lit` suppresses the lit *(completed)*
      block; no empty tag is ever emitted; `model` is empty (not `"null"`) when `--model` is unset.
- [x] Anti-drift assertion: compare the continuation-pointer resolution used by the script against *(completed: shared-helper call in both, structurally asserted plus functional equivalence check)*
      `orchestrate-triage-classify.sh`'s `continuation_ok` predicate — a shared-helper call in both
      (preferred), or a byte-comparison of the jq expression, failing loudly on divergence.
- [x] Headless assertion: with `--lit` and no sub-index present, the run completes without *(completed)*
      attempting an interactive prompt and falls back to `[lit:auto]`.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - new test suite

**Verification**:
- The new suite passes standalone and is discovered by
  `bash agent-system/extensions/core/scripts/tests/run-all.sh` (its path appears in the run
  transcript, not as a `[SKIP]`).
- Deliberately removing one gatherer makes the parity test fail (confirm the test actually bites,
  then restore).

---

### Phase 6: Replace the 8 single-task Stage 4 dispatch sites [COMPLETED]

**Goal**: Reduce each single-task dispatch site to one script call plus the fixed pointer prompt.

**Tasks**:
- [x] For each of the 8 single-task `Run **Stage 3.5**` occurrences (`not_started`, `researching`, *(completed)*
      `researched`, `planning`, `planned/implementing` hard branch, `planned/implementing` base
      branch, `partial` continuation-available, `partial` no-continuation): replace the Stage 3.5
      invocation and all inline prompt construction with a single call to
      `orchestrate-build-dispatch.sh`, threading the already-minted `dispatch_seq`, the stamped
      window timestamp, the resolved flags, and (hard branch only) `--territory`.
- [x] Parse `{dispatch_file, model}` from the script's one-line JSON and use `model` for the Agent *(completed)*
      call's model selection exactly as `model_flag` is used today.
- [x] Set every site's prompt to the fixed pointer form: `You are dispatched by /orchestrate for *(completed: hard branch also appends phase_mission_block, which is genuinely per-cycle content the script does not gather (next_phase/phases_completed/phases_total) -- see Phase 6 progress deviations)*
      task {N}, phase {phase}. Read {dispatch_file} first and execute it exactly; it names every
      input, output path and contract.` No description, briefing, memory block, contract text, or
      plan path appears in the lead's prompt at any site.
- [x] Leave each site's `delegation_context` / `context` JSON object semantics unchanged except for *(completed)*
      removing fields now carried by the dispatch file; do not add the four Stage 3.5 blocks to it
      (they were never in it).
- [x] Do not touch the auxiliary dispatches (H4 re-verification x2, Stage 5a fork and reviser, *(completed)*
      Stage 5b audit, Stage 6 fork/reviser/re-implement) — they keep inline prompts.

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: full

**Scope Hypothesis**: 8 single-task physical occurrences are expected (verified at plan time at
`SKILL.md` lines 955, 1003, 1117, 1239, 1431, 1545, 1627, 1693 — line numbers drift, so re-derive
with `grep -n "Run \*\*Stage 3.5" SKILL.md` and treat the non-MT-4 subset as the phase's scope).
Confirm the count before editing and after: this phase leaves exactly the 3 MT-4 occurrences.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - 8 single-task Stage 4 sites

**Verification**:
- `grep -c "Run \*\*Stage 3.5" SKILL.md` returns exactly 3 (the MT-4 loops, Phase 7's scope).
- `grep -c "orchestrate-build-dispatch.sh" SKILL.md` returns at least 8.
- No single-task site's prompt string contains a description, memory, briefing, contract, or plan
  path — confirm by reading each edited hunk.
- The auxiliary dispatch sites are byte-identical to their pre-edit state.

---

### Phase 7: Replace the 3 MT-4 loops, delete the Stage 3.5 prose [COMPLETED]

**Goal**: Finish the call-site migration and remove Stage 3.5's prose from the engine in favor of a
pointer to the script.

**Tasks**:
- [x] Replace the 3 MT-4 loop bodies (`research_tasks`, `plan_tasks`, `implement_tasks`) with the *(completed: also removed the now-dead per-task description read (script re-derives it from state.json))*
      same one-call + fixed-pointer-prompt shape as Phase 6, threading the per-task
      `dispatch_seq` minted from `mt_state_file.dispatch_seq_counter`.
- [x] Confirm the artifact-round threading gap closes here: MT-4 dispatches now carry an explicit *(completed: confirmed -- orchestrate-build-dispatch.sh's artifact-round gatherer (Phase 4) applies uniformly to every phase call, MT-4 included)*
      artifact round via the dispatch file rather than relying on the agent to derive one.
- [x] Delete the `### Stage 3.5: Dispatch Prep` section body, replacing it with a short pointer *(completed)*
      naming `scripts/orchestrate-build-dispatch.sh` as the sole implementation and stating that no
      dispatch prep happens inline any more.
- [x] Update any cross-reference elsewhere in `SKILL.md` that says "see Stage 3.5 above" so it *(completed)*
      points at the script instead; leave the SKILL.md statement enumerating auxiliary dispatches
      that "do not call Stage 3.5" accurate (reword to reference the script).
- [x] Record the `SKILL.md` byte size before and after for the Stage A budget line. *(completed: 277015 -> 270380 bytes, -6635 bytes net)*

**Timing**: 1.5 hours

**Depends on**: 6

**Verification Tier**: full

**Scope Hypothesis**: 3 MT-4 occurrences remain at phase start (plan-time lines 3351, 3363, 3380).
Confirm with `grep -n "Run \*\*Stage 3.5" SKILL.md` before editing; the post-edit count must be 0.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - 3 MT-4 loops, Stage 3.5 section
  body, cross-references

**Verification**:
- `grep -c "Run \*\*Stage 3.5" SKILL.md` returns **0**.
- `grep -n "Stage 3.5" SKILL.md` shows only pointer/reference text, no procedure.
- `wc -c SKILL.md` recorded before and after; the reduction is reported.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet` green.

---

### Phase 8: Routing-driven agent-contract sweep [COMPLETED]

**Goal**: Give every agent `skill-orchestrate` can dispatch through a Stage-3.5-backed site a short
"Dispatch file" section, and report the negatives explicitly.

**Tasks**:
- [x] Enumerate dispatchable agents by walking every `agent-system/extensions/*/manifest.json`'s *(completed: resolved via command-route-agent.sh/manifest-routing-lib.sh with ROUTE_MANIFEST_ROOT=agent-system (source-store mode); 62 unique agents resolved)*
      `routing_agents` and `routing_agents_hard` blocks, resolving through
      `scripts/lib/manifest-routing-lib.sh`'s own functions (mirroring Stage 1b / MT-2). Do not
      iterate the ~65 `agents/*.md` files blindly. Handle compound task types (e.g. `present:grant`)
      through the library rather than a grep.
- [x] For each resolved research / plan / implement agent, add a short **Dispatch file** section: *(completed: all 62 files updated, verified via git diff --name-only against the resolved-set file list (identical, no scope creep))*
      read the dispatch file named in the prompt first; treat it as the authoritative dispatch
      context; it names every input, output path, and contract; plus a one-line pointer to
      `context/standards/user-decision-contract.md`. Do not restate the user-decision contract.
- [x] Confirm the three core agents are covered: `general-research-agent`, `planner-agent`, *(completed)*
      `general-implementation-agent`.
- [x] Produce the sweep report as a table: extension, task_type, resolved research/plan/implement *(completed: see progress/phase-8-progress.json notes and the task summary)*
      agent, section added (yes/no), and reason for any "no".
- [x] Report explicit negatives: extensions with no `routing_agents` block; task types routing to *(completed)*
      the three core agents (already covered, not a separate edit); and the agents
      `skill-orchestrate` dispatches only through auxiliary, non-Stage-3.5 sites —
      `reviser-agent`, `spawn-agent`, `code-reviewer-agent`, `meta-builder-agent` — which are named
      as out-of-scope negatives, not silently omitted.
- [x] Run `scripts/lint/lint-agent-contracts.sh` and confirm every edited contract still passes *(completed)*
      (including Check F's `.return-meta.json` artifacts-template requirement).

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: interface

**Scope Hypothesis**: `find agent-system/extensions -path "*/agents/*.md"` returns ~65 files across
~20 extensions, of which only the routing-resolved subset is in scope. Confirm the actual
in-scope agent set at implementation time by running the manifest walk and printing the resolved
set before editing any file; the sweep report's table is the confirmation record.

**Files to modify**:
- `agent-system/extensions/core/agents/general-research-agent.md`
- `agent-system/extensions/core/agents/planner-agent.md`
- `agent-system/extensions/core/agents/general-implementation-agent.md`
- `agent-system/extensions/*/agents/*.md` - the routing-resolved subset only, enumerated at
  implementation time

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` passes.
- Every agent in the resolved set has exactly one **Dispatch file** section; no agent outside the
  set was edited (`git status --short` matches the sweep table).
- The sweep report names its negatives explicitly.

---

### Phase 9: `.dispatch/` cleanup wiring, acceptance measurement, full gate run [NOT STARTED]

**Goal**: Close the accumulation decision, measure and report the acceptance numbers, demonstrate
`user_decision` end to end, and run the full gate set green.

**Tasks**:
- [ ] Add `rm -rf "${TASK_DIR}/.dispatch/"` co-located with every existing loop-termination
      `rm -f "$loop_guard_file"` site in `SKILL.md`, and at the per-task MT-5 multi-task postflight
      equivalent. Match the surrounding comment convention naming it loop-termination-only cleanup.
- [ ] **Acceptance — prompt-byte measurement**: for a real 3-task multi-task cycle, measure the
      lead's authored prompt text before (from the pre-edit call-site shape, reconstructable from
      git history) and after (the fixed pointer prompt x 3). Report both byte counts and the
      percentage reduction; the target is >= 90%.
- [ ] **Acceptance — parity**: report Phase 5's parity-test result as passing, naming the fields
      compared.
- [ ] **Acceptance — sweep**: attach Phase 8's sweep table with its explicit negatives.
- [ ] **Acceptance — user_decision end to end**: run a research dispatch whose agent sets
      `user_decision` and show the field arriving in `.return-meta.json` intact (structure and
      values unchanged), surviving any later writer's read-modify-write.
- [ ] **Full gate run**: `scripts/tests/run-all.sh`, `scripts/verify-deploy.sh`,
      `scripts/check-runtime-file-tracking.sh`, `scripts/check-task-references.sh`, and the
      `scripts/lint/*` suite. Report each result.
- [ ] Confirm no file under `.claude/**` was hand-authored at any point in this task
      (`git status --short` plus a review of every touched path).

**Timing**: 1.5 hours

**Depends on**: 7, 8

**Verification Tier**: full

**Scope Hypothesis**: three loop-termination `rm -f "$loop_guard_file"` sites are expected in
`SKILL.md` (plan-time lines 1503, 1767, 2410) plus one MT-5 per-task equivalent. Confirm with
`grep -n 'rm -f "\$loop_guard_file"' SKILL.md` and inspect Stage MT-5 directly; wire every site
found, not the four assumed here.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - `.dispatch/` cleanup at every
  loop-termination site and MT-5
- `specs/146_build_orchestrate_dispatch_builder/summaries/01_orchestrate-dispatch-builder-summary.md`
  - the acceptance report

**Verification**:
- Every gate command above exits 0; each result is named in the summary.
- After a full simulated cycle, `ls specs/{NNN}_{slug}/.dispatch/ 2>/dev/null` is empty or absent.
- The measured prompt-byte reduction is >= 90% and both raw numbers are reported.
- `.return-meta.json` from the demonstration run contains the `user_decision` object unmodified.

---

## Testing & Validation

- [ ] `grep -c "Run \*\*Stage 3.5" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
      returns 0.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` green, with
      `test-orchestrate-build-dispatch.sh` discovered and passing (not `[SKIP]`).
- [ ] `bash agent-system/extensions/core/scripts/verify-deploy.sh` green.
- [ ] `bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` green with the new
      `.dispatch/` probe.
- [ ] `bash agent-system/extensions/core/scripts/check-task-references.sh` clean — no task-number
      references in any deliverable outside `specs/**`.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` green.
- [ ] Dispatch-file parity confirmed field-by-field for all three phases.
- [ ] Continuation-pointer resolution shared (or byte-identical) between the new script and
      `orchestrate-triage-classify.sh`.
- [ ] Prompt-byte reduction >= 90% on a real 3-task cycle, both numbers reported.
- [ ] A `user_decision`-setting research dispatch reaches `.return-meta.json` intact.
- [ ] No `.dispatch/` path appears in `git status --short` at any point.
- [ ] No file under `.claude/**` was hand-authored.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` (new)
- `agent-system/extensions/core/context/standards/user-decision-contract.md` (new)
- `agent-system/extensions/core/scripts/lib/` continuation-pointer helper (new)
- Edits: `skills/skill-orchestrate/SKILL.md`, `context/formats/return-metadata-file.md`,
  `docs/architecture/handoff-schema.md`, `context/standards/orchestrator-runtime-files.md`,
  `context/standards/git-staging-scope.md`, `scripts/check-runtime-file-tracking.sh`,
  `scripts/orchestrate-triage-classify.sh`, the routing-resolved `agents/*.md` set, repo-root
  `.gitignore`
- `specs/146_build_orchestrate_dispatch_builder/summaries/01_orchestrate-dispatch-builder-summary.md`
  carrying the four acceptance results and the sweep table

## Rollback/Contingency

Every phase is a separate commit, so rollback is per-phase `git revert`. The riskiest boundary is
Phases 6-7 (the `SKILL.md` call-site migration): if a dispatch regression appears after landing,
reverting Phases 6, 7, and 9's `SKILL.md` hunks restores the inline recipes while leaving the
script, tests, contract, and registration surfaces in place — they are additive and inert until a
call site uses them. Phase 2's registration is safe to keep on any rollback (an ignore rule for a
directory that is no longer written costs nothing). If the shared continuation helper in Phase 4
causes a regression in `orchestrate-triage-classify.sh`, revert that single file to its
hand-copied predicate and fall back to the verbatim-jq option recorded in Phase 4's tasks.

# Implementation Plan: Task #939

- **Task**: 939 - Fix off-schema .return-meta.json writes breaking orchestrator recovery
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/939_return_metadata_schema_compliance/reports/01_return-metadata-schema-compliance-research.md
- **Artifacts**: plans/01_return-metadata-schema-compliance.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two verified writer-side defects cause agents to write `.return-meta.json` files that do not
conform to the schema its readers assume: phase-count fields written at the top level instead of
under `.metadata`, and an `artifacts` array of bare strings instead of objects. Both degrade
silently — the recovery script returns 0/0 phases and an empty artifact path from a present,
parseable file. This plan fixes the ambiguous writer instructions that caused each shape, records
an explicit decision against a schema-permissive reader fallback, adds one general
"reader got an empty or zero value from a present, parseable file" detection signal covering both
defects, and escalates that signal in the one orchestrator branch that structurally could not see
it. Every phase's claim is confirmed by running the real recovery script against constructed
scratch inputs, never by reading code.

### Research Integration

The research report is integrated as follows:

- **Root cause of the nesting drift** (Finding A): `general-implementation-hard-agent.md` shows a
  correct top-level `phases_completed`/`phases_total` example for `.orchestrator-handoff.json` at
  Stage 5, a few dozen lines before its Stage 7 `.return-meta.json` instruction groups the same two
  field names in one clause with `modified_files` (which genuinely IS top-level in
  `.return-meta.json`). Phase 2's fix therefore states the nesting explicitly AND names the
  cross-file collision, rather than only rewording one sentence.
- **Discrepancy resolved, not silently followed** (Finding A): the task description states
  `skill-team-implement/SKILL.md` shows a top-level shape. Direct inspection shows its Stage 13
  example is already correctly nested under `"metadata"`. Phase 3 therefore adds the same
  disambiguating prose the other writers need to an already-correct example, and does NOT
  "correct" a shape that is not wrong.
- **Coupled reader** (Finding A): `skill-implementer-hard/SKILL.md` Stage 6 reads
  `jq -r '.phases_completed // 0'` at the top level. Fixing the hard-mode writer without fixing
  this reader newly breaks the non-orchestrator `/implement --hard` phase gate. Phase 2 lands both
  in one atomic batch. See "Declared Footprint vs. Actual Footprint" below.
- **Item C recommendation adopted** (Finding C): no schema-permissive top-level-phases fallback is
  added to `orchestrate-recover-outcome.sh`. Phase 5 records the decision in the script's own
  header so a future reader does not re-litigate it.
- **Item D's actual gap** (Finding D): the existing phase-marker grep lives only in the
  `recovered=false` branch and structurally cannot fire in Defect 1's own scenario, which produces
  `recovered=true`. The fix is widening the trigger, not inventing a diagnostic. Phases 5 and 6
  implement the report's two-part split (a same-file self-consistency check in the script; a
  widened trigger in the orchestrator skills), because the Context Flatness Constraint forbids the
  plan-file cross-check from living inside the recovery script.
- **jq stderr is a free signal** (Finding E): the `artifact_path=` line lacks the `2>/dev/null`
  most sibling jq calls carry, so Defect 2 emits three real `jq: error ... Cannot index string
  with string "path"` lines that nothing consumes. Phase 5 converts that into a captured signal
  rather than suppressing it outright.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no roadmap flag was set; this plan
neither reads nor writes ROADMAP.md.

## Declared Footprint vs. Actual Footprint

The task's declared `file_scope` lists six files. This plan touches **three files beyond** that
declaration. Per the delegation constraint against silently widening the footprint, each is stated
explicitly with its reason, and one candidate is explicitly scoped **out**:

| File | In declared file_scope? | Disposition | Reason |
|------|------------------------|-------------|--------|
| `skills/skill-implementer-hard/SKILL.md` | No — but declared by task 940 | **Included** (Phase 2) | See "Ownership call" below. Its Stage 6 reads `.phases_completed` at the top level, correct only by coincidence with the ambiguous writer instruction Phase 2 fixes. |
| `skills/skill-orchestrate/SKILL.md` | No | **Included** (Phase 6) | Item D requires the detection signal to escalate rather than degrade. The only branch that can act on Defect 1's scenario (`recovered=true`) lives here, in Stage 5 and its Stage MT-4 mirror. A detection field emitted by the script with no consumer would satisfy item D in letter only. |
| `skills/skill-orchestrate-hard/SKILL.md` | No | **Included** (Phase 6) | Carries the mirrored Stage 5 recovery branch. Fixing only the base mirror leaves `/orchestrate --hard` with the identical blind spot — a partial fix that reads as complete. |
| `skills/skill-implementer/SKILL.md` | No — but declared by task 940 | **Scoped OUT** (verify only) | Its Stage 6 read is already correct (`jq -r '.metadata.phases_completed // 0'`) and its instruction delegates writing to `general-implementation-agent.md`. Phase 2 confirms it read-only via grep and makes no edit. There is no defect here to fix, so ownership never arises — the file stays entirely task 940's. |

No other file is edited. `.claude/**` is never written (see Constraints).

### Ownership call: `skills/skill-implementer-hard/SKILL.md`

This file sits between two task boundaries: it is not in task 939's declared `file_scope`, but it
IS in task 940's, and task 940 is serialized strictly after 939 by a `dependencies[]` edge. Two
defensible options existed. **Task 939 takes the edit (option (a)).** Stating the call and its
consequences plainly, since it widens this task's declared footprint into a file another task also
declares:

- **The coupling is a correctness invariant of Phase 2's own edit, not a separable improvement.**
  Phase 2 changes the hard-mode agent's writer instruction to nest `phases_completed`/`phases_total`
  under `metadata`. The moment that lands, this file's top-level read returns 0/0 for every
  `/implement --hard` run. Deferring the reader fix means task 939 ships a change that leaves the
  non-orchestrator hard-mode phase gate broken and depends on a *different* task to restore it.
- **The regression window is real, not theoretical, and its length is not bounded by the dependency
  edge.** Serialization guarantees ordering, not promptness. If task 940 slips, is re-scoped, or is
  abandoned, the broken state persists indefinitely with no record of why. Option (b) would trade a
  two-line edit for a durable "system is broken until some other task runs" condition.
- **Cost of taking it here is near zero.** The change is two `jq` read expressions. It does not
  overlap task 940's actual concern in this file (summary metadata headers), so it neither
  pre-empts nor complicates 940's own edit.
- **Consequence, stated for the downstream implementer**: task 940's implementer will find this
  file already changed at its Stage 6 reads. That is expected, not a conflict — the `.metadata.`
  prefix will already be present, and 940 should treat those two lines as done and proceed with its
  own summary-header scope. There is no concurrency hazard in either direction, since the two tasks
  never run simultaneously.
- **What is NOT taken**: task 939 claims no other part of this file, and makes no edit at all to
  `skill-implementer/SKILL.md`. The footprint widening is exactly two read expressions in one file.

## Goals & Non-Goals

**Goals**:

- Every writer that instructs an agent to emit `phases_completed`/`phases_total` in
  `.return-meta.json` states the `.metadata` nesting as explicitly as `memory_candidates` and
  `modified_files` already state their top-level position.
- `general-research-agent.md` carries a local, inline instruction for the `artifacts` object-array
  shape, removing the dependency on a reference that demonstrably was not followed.
- The `phases_completed`/`phases_total` cross-file name collision between `.return-meta.json`
  (nested) and `.orchestrator-handoff.json` (top-level, always) is documented in the format doc as
  a first-class callout, in the same style as its existing "Three distinct vocabularies" table.
- An explicit, recorded decision on item C (defensive reader acceptance), with reasoning that
  survives in the file rather than only in this plan.
- One general detection signal — "a present, parseable file yielded an empty or zero value" —
  covering both defects with one code shape, consumed and escalated by the orchestrator branch that
  previously could not see it.
- Every claim above confirmed by constructing off-schema scratch files and running the real
  `orchestrate-recover-outcome.sh` against them, with before/after recorded.

**Non-Goals**:

- Redefining the schema in `context/formats/return-metadata-file.md`. It is believed correct; only
  additive hardening (a collision callout) is in scope.
- Redefining `orchestrate-recover-outcome.sh`'s existing read locations. The two documented
  locations stay exactly as they are.
- Adding a schema-permissive top-level-phases fallback (item C, explicitly declined — see Phase 5).
- Retroactively repairing any existing `.return-meta.json` file on disk. These are ephemeral,
  deleted after postflight.
- Any change to `.orchestrator-handoff.json`'s own top-level phase-field rule, which is correct.
- Any edit under `.claude/**`.

## Constraints (binding)

- **SOURCE-STORE RULE**: every edit targets `agent-system/extensions/core/**`. `.claude/**` is a
  gitignored, disposable deploy artifact and is NEVER written. Phase 7 verifies this mechanically.
- **LINE-NUMBER CAVEAT**: anchor every edit on symbol names and quoted strings (e.g. the literal
  `Agent-specific metadata fields:`, the function name `emit`, the heading
  `### Stage 7: Write Metadata File`). Never on line numbers — they drift on every edit.
- **VERIFICATION BY CONSTRUCTION**: reading the code is what left this defect in place. Every
  behavioral claim is confirmed by running the real script against a constructed input and
  recording observed stdout/stderr/exit code.
- **NO TASK REFERENCES**: no task-number citations in any file outside `specs/**`. All edited files
  in this plan are outside `specs/**`.
- **Scratch location**: scratch `.return-meta.json` fixtures go in the session scratchpad
  directory, never inside the repository.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Phase 2 fixes the hard-mode writer but not the coupled `skill-implementer-hard` reader, breaking the non-orchestrator `/implement --hard` phase gate | H | M | Both edits are one `atomic-batch` phase with a single green criterion; Phase 2's verification greps that no `jq -r '.phases_completed` without a `.metadata.` prefix remains in that file |
| Adding fields to `orchestrate-recover-outcome.sh`'s `emit()` breaks its three call sites | H | L | Fields are added to the emitted JSON object only; the three call sites read named fields via jq and ignore unknown ones. Phase 5 verifies the existing field set is byte-identical for a control fixture before and after |
| The widened trigger in Phase 6 fires on a genuine zero-phase implementation (a plan with no `### Phase N:` headings) | M | L | Gate on `phases_total == 0` specifically (never `phases_completed == 0` alone), and treat a grep that finds `recovered_total == 0` as "no contradiction, nothing to escalate" rather than a second trigger |
| Escalation is implemented as a log line only, reproducing the silent-degradation shape it exists to fix | H | M | Phase 6's acceptance criterion is behavioral, not textual: the corroborated case must change `plan_markers_verified` from `absent` to `true` so the completion gate can act on evidence — verified by a constructed run, not by reading the added text |
| Task 940 edits the same two implementation-agent files after this task | M | H | All edits to `general-implementation-agent.md` and `general-implementation-hard-agent.md` are confined to Phase 2 and land in one commit; no later phase re-touches them |
| Editing `.claude/**` out of habit, where the change is silently wiped on next deploy | H | M | Phase 7 runs `git status --porcelain` plus a path check confirming no `.claude/` path appears in this task's changed set |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 6 | 5 |
| 4 | 7 | 2, 3, 4, 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Reproduce Both Defects By Construction (Baseline) [COMPLETED]

**Goal**: Establish the observed before-state for both defects by running the real, unmodified
`orchestrate-recover-outcome.sh` against constructed off-schema fixtures. Nothing in the repository
is edited. This baseline is the comparison target for Phase 7.

**Tasks**:

- [x] Create a scratch fixture directory under the session scratchpad (never inside the repo).
      *(completed: reused pre-existing `939-verify/{control_correct,defect1_topmeta,defect2_barestrings}/` under the session scratchpad)*
- [x] Write fixture `control/.return-meta.json`: `status: "implemented"`, correctly nested
      `.metadata.phases_completed = 6` / `.metadata.phases_total = 6`, an `artifacts` array of one
      well-formed object with `type`/`path`/`summary`, and a `completion_data` object. *(completed)*
- [x] Write fixture `defect1/.return-meta.json`: identical, except `phases_completed`/`phases_total`
      appear ONLY at the top level and `.metadata` contains neither. *(completed)*
- [x] Write fixture `defect2/.return-meta.json`: `status: "researched"` with `artifacts` as an array
      of bare strings. *(completed)*
- [x] Run `bash agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh <fixture_dir>
      <window_start_ts>` against each of the three, with `window_start_ts` set one hour in the past
      so the freshness gate passes. Capture stdout, stderr, and exit code for each. *(completed)*
- [x] Record all three observed results verbatim in the phase's progress notes: expect control to
      report `phases_completed: 6`; expect defect1 to report `phases_completed: 0, phases_total: 0`
      with exit 0 and `recovered: true`; expect defect2 to report `artifact_path: ""` with three
      `jq: error ... Cannot index string with string` lines on stderr and exit 0. *(completed: all
      three matched expectations exactly — see progress/phase-1-progress.json)*
- [x] If any observed result contradicts the expectation above, STOP and report the discrepancy
      before proceeding — the premise of the remaining phases would be wrong. *(completed: no
      contradiction found, proceeded to Phase 2)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly three fixtures reproduce the two defects plus a
control, and that defect1 yields `0/0` while defect2 yields an empty `artifact_path`. Confirm by
running the script and comparing captured stdout against the expectations listed above; a mismatch
is a stop condition, not something to reconcile in prose.

**Files to modify**: none (scratch fixtures only, outside the repository)

**Verification**:

- Three captured stdout JSON objects exist, one per fixture, each with a recorded exit code.
- The defect1 capture literally shows `"phases_completed":0,"phases_total":0` while its input file
  literally contains `"phases_completed": 6`.
- The defect2 capture literally shows `"artifact_path":""` and its stderr contains at least one
  `Cannot index string with string` line.
- `git status --porcelain` shows no repository changes from this phase.

---

### Phase 2: Phase-Field Nesting — Implementation Agents and the Coupled Hard-Mode Reader [COMPLETED]

**Goal**: Make the `.return-meta.json` nesting of `phases_completed`/`phases_total` unambiguous in
both implementation agent definitions, and fix the one reader whose correctness depended on the
ambiguity. These three files land together because splitting them introduces a regression.

**Tasks**:

- [x] In `agents/general-implementation-agent.md`, locate the Stage 7 instruction by its literal
      trailing sentence `Agent-specific metadata fields: \`phases_completed\`, \`phases_total\`.`
      Replace it with wording that states the location as explicitly as the two adjacent directives
      already do — that these two fields go **inside the `metadata` object**, not at the top level,
      and that this is the opposite of the same two field names in `.orchestrator-handoff.json`.
      *(completed)*
- [x] In the same file, add a worked `implemented`-case JSON example at Stage 7 showing the correct
      nesting (the file currently has a worked example only for the `partial` case, leaving the
      success case with nothing to pattern-match). Anchor it adjacent to the existing example block
      containing the literal `"phases_completed": N,`. *(completed)*
- [x] In `agents/general-implementation-hard-agent.md`, locate the `### Stage 7: Write Metadata
      File` heading and its sentence beginning `Include \`phases_completed\`, \`phases_total\`,
      \`modified_files\``. Split the clause so `phases_completed`/`phases_total` are stated as
      nested under `metadata` and `modified_files` as top-level, and add an explicit note that the
      top-level shape shown earlier in Stage 5 belongs to `.orchestrator-handoff.json` and does NOT
      apply to this file. *(completed)*
- [x] In `skills/skill-implementer-hard/SKILL.md`, locate the Stage 6 postflight reads
      `jq -r '.phases_completed // 0'` and `jq -r '.phases_total // 0'` and change both to read
      `.metadata.phases_completed // 0` and `.metadata.phases_total // 0`, matching the sibling
      `skill-implementer/SKILL.md`. Change nothing else in this file — it is another task's declared
      territory and this task claims exactly these two read expressions (see "Ownership call").
      *(completed)*
- [x] Confirm read-only (no edit) that `skills/skill-implementer/SKILL.md` Stage 6 already reads
      `.metadata.phases_completed`; record the grep output as evidence for the scoped-out decision.
- [x] Confirm no task-number citation was introduced in any of the three edited files. *(completed:
      grep for `task [0-9]+|tasks [0-9]+|\(task [0-9]+` across all three edited files, zero hits)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: This phase asserts exactly three files are edited (`general-implementation-agent.md`,
`general-implementation-hard-agent.md`, `skill-implementer-hard/SKILL.md`) and one is verified
read-only (`skill-implementer/SKILL.md`). Confirm at implementation time by grepping the whole
`agent-system/extensions/core/` tree for `phases_completed` and checking that every remaining hit is
either an `.orchestrator-handoff.json` context (correctly top-level), a `.metadata.`-prefixed read,
or already-correct prose. If the grep surfaces a fourth writer or reader not listed here, add it to
this phase rather than deferring it — the coupling argument that justifies this batch applies
identically to any such site.

**Files to modify**:

- `agent-system/extensions/core/agents/general-implementation-agent.md` — Stage 7 nesting statement
  made explicit; worked `implemented`-case example added.
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — Stage 7 clause split;
  cross-file collision note added.
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` — Stage 6 reads corrected to
  `.metadata.`-prefixed form.

**Verification**:

- `grep -n "phases_completed" agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md`
  shows no read lacking a `.metadata.` prefix.
- Both agent files contain an explicit statement of the `metadata` nesting adjacent to the
  `Agent-specific metadata fields` / Stage 7 wording, and both name the
  `.orchestrator-handoff.json` collision.
- `general-implementation-agent.md` contains a worked `implemented`-case example with
  `phases_completed` inside a `"metadata"` object.
- `skill-implementer/SKILL.md` is unchanged (`git diff --stat` shows no entry for it).
- No `.claude/` path appears in `git status --porcelain`.

---

### Phase 3: Phase-Field Nesting — Team Skill Prose and Format-Doc Collision Callout [COMPLETED]

**Goal**: Give `skill-team-implement/SKILL.md` the same disambiguating prose without altering its
already-correct example, and add the missing cross-file collision callout to the format doc.

**Tasks**:

- [x] Confirm first that `skills/skill-team-implement/SKILL.md`'s Stage 13 JSON example already
      nests `phases_completed`/`phases_total` under `"metadata"` (the task description states
      otherwise; the research found it correct). Record the observed shape. If it is in fact
      top-level, correct it and note the correction; if nested, do NOT "fix" it. *(completed:
      confirmed nested under `"metadata"` at lines 547-552; not corrected, per research)*
- [x] Add a short explicit sentence next to that example stating that the two fields nest under
      `metadata` in `.return-meta.json`, contrasting with `.orchestrator-handoff.json`'s always-
      top-level rule. *(completed)*
- [x] In `context/formats/return-metadata-file.md`, add a collision callout to the field spec that
      lists `phases_completed` / `phases_total` (the bullet list under the `metadata` section
      beginning `Additional optional fields for specific agent types:`). Mirror the style of the
      existing `### Three distinct vocabularies sharing the same words` table: a compact two-row
      table contrasting `.return-meta.json` (nested under `metadata`, or under `partial_progress`
      for interrupted work) against `.orchestrator-handoff.json` (top-level, always), with a
      one-line note that a writer correct for one file is wrong for the other. *(completed)*
- [x] Confirm the callout is additive documentation only — no field is renamed, no read location is
      redefined, no existing sentence's meaning changes. *(completed: `git diff` shows pure
      additions, no deletions, in both files)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts exactly two files are edited and that
`skill-team-implement/SKILL.md`'s existing example needs prose reinforcement rather than shape
correction. Confirm by reading the Stage 13 example block before editing and recording whether
`phases_completed` sits inside a `"metadata"` object; the recorded observation, not this plan's
expectation, decides which of the two treatments applies.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-team-implement/SKILL.md` — disambiguating sentence
  added adjacent to the Stage 13 metadata example.
- `agent-system/extensions/core/context/formats/return-metadata-file.md` — cross-file nesting
  collision callout added to the `phases_completed`/`phases_total` field spec.

**Verification**:

- Diff read-through confirms every changed hunk in both files lies in prose or a table, with no
  change to any JSON example's key placement (unless the recorded observation showed a genuine
  top-level shape, in which case that correction is called out in the phase notes).
- The format doc's new callout names both file names and both nesting rules.
- No task-number citation appears in either file.
- No `.claude/` path appears in `git status --porcelain`.

---

### Phase 4: Artifacts Array Shape — Local Instruction in the Research Agent [COMPLETED]

**Goal**: Remove the research agent's dependence on a reference that was demonstrably not followed,
by adding a local, inline statement of the `artifacts` object-array shape at the point of use.

**Tasks**:

- [x] Confirm by grep that `agents/general-research-agent.md` currently contains no instruction for
      the `artifacts` field shape (research found exactly one unrelated prose use of the word).
      Record the grep output. *(completed: single unrelated prose hit at "Reference existing
      artifacts in the new report", confirmed)*
- [x] Locate the `### Stage 7: Write Metadata File` heading and the sentence beginning
      `Write to \`specs/{NNN}_{SLUG}/.return-meta.json\` with status \`researched\`.` *(completed)*
- [x] Add an explicit statement that `artifacts` is a **required** array of **objects**, each with
      `type`, `path`, and `summary` — never an array of bare path strings — plus a minimal inline
      one-object example. Keep it to a few lines; this is a call-site reminder, not a schema
      restatement. *(completed)*
- [x] Keep the existing `@`-reference to `context/formats/return-metadata-file.md` in place. The
      local instruction supplements the reference; it does not replace it. *(completed: verified
      the Stage 0 "always load" reference at the top of the file is unchanged)*
- [x] Decide and record explicitly (item B's open choice): the local-instruction option is taken
      rather than merely making the reference more prominent, because Defect 2 already falsified
      "the reference alone is sufficient." State this reasoning in the phase notes, not in the
      edited file. *(completed — see progress/phase-4-progress.json)*
- [x] **Scope Hypothesis widening** (see below): the grep found `general-implementation-hard-agent.md`,
      `general-research-hard-agent.md`, `planner-agent.md`, and `planner-hard-agent.md` equally
      silent on the `artifacts` shape while each independently writing `.return-meta.json`. Per the
      Scope Hypothesis's own instruction ("add it to this phase rather than deferring it"), each
      received the same minimal local instruction. This widens Phase 4's edit set from the
      single declared file to five files — recorded explicitly here and in the implementation
      handoff/summary, per the binding constraint against silent footprint widening. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts `general-research-agent.md` is the only writer lacking an
`artifacts`-shape instruction. Confirm at implementation time by grepping every agent definition
under `agent-system/extensions/core/agents/` for `artifacts` and checking which Stage 7 sections
state the shape; if another agent definition is equally silent AND writes `.return-meta.json`, add
it to this phase rather than leaving a second instance of the same defect in place.

**Files to modify**:

- `agent-system/extensions/core/agents/general-research-agent.md` — Stage 7 gains an explicit
  `artifacts` object-array instruction with a minimal inline example.

**Verification**:

- `grep -n "artifacts" agent-system/extensions/core/agents/general-research-agent.md` now shows the
  new instruction and its inline example.
- The inline example's single object contains all three of `type`, `path`, `summary`.
- Diff read-through confirms the change is confined to prose and a fenced example block.
- No `.claude/` path appears in `git status --porcelain`.

---

### Phase 5: Reader Hardening — Item C Decision and the General Empty-Value Detection Signal [COMPLETED]

**Goal**: Record the explicit decision against a schema-permissive fallback, and add one general
detection signal to `orchestrate-recover-outcome.sh` covering both defects with a single code
shape — without changing any existing read location or emitted field.

**Tasks**:

- [x] **Item C decision, recorded in the file**: add a short block to the script's header comment
      stating that a top-level `phases_completed` fallback is deliberately NOT added, that the two
      documented read locations (`.metadata.*` and `.partial_progress.*`) are exhaustive by design,
      and that the reason is to keep writer drift visible rather than silently blessed. Note that
      the detection signal below is the evidence-based alternative. Confirm the existing two read
      lines are left byte-identical. *(completed: the two `.metadata.phases_completed //
      .partial_progress.phases_completed // 0` / `.metadata.phases_total // ...` read lines are
      unchanged character-for-character)*
- [x] Add an `evidence_suspect` boolean and an `evidence_reason` string token to the `emit` function
      and to the emitted JSON object. Add them as new named fields; do not reorder or rename any
      existing field. Remember the existing brace requirement on positional parameters past `$9`.
      *(completed: `${12}`/`${13}`)*
- [x] Implement the general check as one shape, not two special cases: `evidence_suspect` is true
      when a present, parseable, fresh file yields a zero-or-empty value that its own contents
      contradict. Two instances of that one signature:
      - `PHASES_ZERO_ON_SUCCESS` — `status == "implemented"` and both resolved phase counts are 0
        (an implementation dispatch always has at least one phase, so 0/0 on a claimed-complete
        implementation is inherently suspect).
      - `ARTIFACTS_SHAPE_MISMATCH` — `(.artifacts | length) > 0` but the resolved `artifact_path`
        is empty (a non-empty array that yields no path is proof of a shape mismatch, not proof of
        "no artifacts"). *(completed)*
- [x] Set `evidence_reason` to `NONE` when `evidence_suspect` is false, and to the matching token
      above otherwise. If both signatures fire, prefer `PHASES_ZERO_ON_SUCCESS` and note the
      precedence in the header. *(completed: if/elif ordering plus a header table row and an
      inline comment both state the precedence)*
- [x] Capture the jq stderr signal rather than swallowing it: make the `artifact_path`/
      `artifact_type`/`artifact_summary` extractions detect a jq failure (non-zero exit or a
      captured error) and treat it as corroboration for `ARTIFACTS_SHAPE_MISMATCH`, so the errors
      become a used signal instead of noise. Do NOT simply append `2>/dev/null` and discard them.
      *(completed: `artifact_path_rc`/`artifact_type_rc`/`artifact_summary_rc` capture `$?` from
      each unredirected jq call; stderr still surfaces exactly as before, and a nonzero rc
      additionally feeds `jq_artifact_failure`, which ORs into the `ARTIFACTS_SHAPE_MISMATCH`
      condition)*
- [x] Preserve the script's read-only contract: it still reads only `<task_dir>/.return-meta.json`,
      performs no writes, and calls none of the forbidden helpers listed in its own header.
      *(completed: no new file writes introduced; the only new reads are internal jq
      transformations of the already-loaded `$meta_json` variable)*
- [x] Update the header's output-field documentation block to list the two new fields with the same
      `name  type  description` shape the existing entries use. *(completed)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts the script has exactly three call sites (base Stage 5, hard
Stage 5, multi-task Stage MT-4 step 1) and that adding fields is backward-compatible for all three.
Confirm by grepping the whole `agent-system/extensions/core/` tree for
`orchestrate-recover-outcome.sh` and checking each hit reads named fields via jq rather than
positionally; a call site that consumes the output positionally or by field count would invalidate
the backward-compatibility claim and must be handled in Phase 6.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` — header decision record and
  output-field docs; `emit` gains two fields; general empty-value detection added; jq artifact-read
  failure captured as corroboration.

**Verification**:

- Re-run all three Phase 1 fixtures against the modified script. Observed and recorded:
  - control: `evidence_suspect: false`, `evidence_reason: "NONE"`, and every pre-existing field
    byte-identical to the Phase 1 control capture.
  - defect1: `evidence_suspect: true`, `evidence_reason: "PHASES_ZERO_ON_SUCCESS"`, and
    `phases_completed`/`phases_total` still `0` (the values are NOT silently corrected — that is the
    item C decision holding).
  - defect2: `evidence_suspect: true`, `evidence_reason: "ARTIFACTS_SHAPE_MISMATCH"`.
- Exit codes for all three fixtures are unchanged from Phase 1.
- `bash -n` on the script passes.
- `grep -n "\.metadata\.phases_completed" scripts/orchestrate-recover-outcome.sh` confirms the
  original read expression is unchanged.
- No `.claude/` path appears in `git status --porcelain`.

---

### Phase 6: Detection Escalation — Widen the Trigger in Both Orchestrator Skills [COMPLETED]

**Goal**: Close the structural gap the research proved: the existing phase-marker cross-check lives
only in the `recovered=false` branch and cannot fire in Defect 1's own `recovered=true` scenario.
Make the recovered-success path consume `evidence_suspect` and escalate on evidence.

**Tasks**:

- [x] In `skills/skill-orchestrate/SKILL.md` Stage 5, locate the recovered-success branch by its
      literal `if [ "$recovered" = "true" ]; then` and the `plan_markers_verified="absent"`
      assignment inside it. Add a corroboration block that runs ONLY when
      `evidence_suspect == true` and `evidence_reason == "PHASES_ZERO_ON_SUCCESS"` and
      `dispatch_status == "implemented"`. *(completed)*
- [x] In that block, reuse the existing phase-marker grep idiom verbatim from the `recovered=false`
      branch — the same two `grep -cE '^### Phase [0-9]+(\.[0-9]+)?: '` forms, the same
      `x=$(grep -c ...) || x=0` pattern, the same plan-path re-derivation fallback. Do not
      re-derive a new regex; the canonical forms are fixed by the plan-format standard.
      *(completed)*
- [x] Escalate rather than merely log: when the grep corroborates (`recovered_total > 0` and
      `recovered_completed == recovered_total`), set `phases_completed`/`phases_total` from the grep
      AND set `plan_markers_verified="true"`, so the completion-claim gate's Case 3 fallback can
      allow completion on **evidence** rather than on schema permissiveness. Emit a loud
      `[UNVERIFIED ...]`-family stderr banner naming the contradiction and the source of the
      corrected counts. *(completed: `[UNVERIFIED PHASES CORROBORATED]` banner, in the same
      bracketed-tag family as `[SPARSE COVERAGE ...]`)*
- [x] When the grep does NOT corroborate — `recovered_total == 0` (a plan with no phase headings) or
      `recovered_completed < recovered_total` — treat it as "no contradiction to resolve": leave
      `plan_markers_verified="absent"` and the counts untouched, and log the non-corroboration.
      This is the false-positive guard. *(completed and verified — see progress/phase-6-progress.json)*
- [x] Keep the Context Flatness Constraint intact: the added block reads only the plan file via the
      same two `grep -c` calls the sanctioned narrow exception already permits, returning integers
      and no matched line content. Extend that exception's precondition comment to name the new
      reachable branch, so the contract text matches the code. *(completed: "Recovery exception
      (phase-marker grep)" bullet rewritten to name both reachable branches)*
- [x] Apply the identical change to `skills/skill-orchestrate/SKILL.md`'s Stage MT-4 recovery path
      (the multi-task mirror that reads `phases_completed`/`phases_total`/`plan_markers_verified`
      from the recovery JSON). *(completed)*
- [x] Apply the identical change to `skills/skill-orchestrate-hard/SKILL.md`'s mirrored Stage 5
      recovery branch, preserving its `[hard-orchestrate]` log prefix. *(completed)*
- [x] Confirm no task-number citation was introduced in either skill file. *(completed: zero hits)*

**Timing**: 1.0 hours

**Depends on**: 5

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exactly three consumer sites need the widened trigger (base
Stage 5, base Stage MT-4, hard Stage 5). Confirm at implementation time by grepping both skill files
for `plan_markers_verified="absent"` and for `orchestrate-recover-outcome.sh`; every site that sets
`plan_markers_verified` to `absent` on a recovered-success path is in scope for this phase. A fourth
such site found by the grep is added here, not deferred.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 5 recovered-success
  branch and Stage MT-4 mirror gain the corroboration block; Context Flatness Constraint
  precondition comment updated.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — mirrored Stage 5
  recovered-success branch gains the same block.

**Verification**:

- Construct a scenario fixture: a task directory containing the defect1 `.return-meta.json` shape,
  no `.orchestrator-handoff.json`, and a `plans/` file whose `### Phase N:` headings are all marked
  `[COMPLETED]`. Extract the added block's bash into a runnable harness and execute it against the
  fixture. Record that `plan_markers_verified` becomes `true` and the phase counts become the
  grep-derived N/N, with the loud banner on stderr.
- Construct the false-positive fixture: the same `.return-meta.json` shape with a plan file
  containing zero `### Phase N:` headings. Record that `plan_markers_verified` stays `absent`,
  counts stay `0/0`, and the non-corroboration is logged.
- Diff both skill files' extracted bash through `bash -n` via a scratch extraction; syntax passes.
- The three grep-idiom forms in the added block are character-identical to the existing
  `recovered=false` branch's forms.
- No `.claude/` path appears in `git status --porcelain`.

---

### Phase 7: End-to-End Verification By Construction and Final Gates [COMPLETED]

**Goal**: Confirm the observed after-state against Phase 1's recorded before-state, and run the full
gate set for the whole task.

**Tasks**:

- [x] Re-run all three Phase 1 fixtures against the final `orchestrate-recover-outcome.sh`. Record
      stdout, stderr, and exit code for each. *(completed — see summary's before/after table)*
- [x] Produce the explicit before/after table required by the task description: for each defect, the
      Phase 1 observed values and the Phase 7 observed values side by side, including the new
      `evidence_suspect`/`evidence_reason` fields. *(completed — see summary)*
- [x] Re-run the Phase 6 corroboration harness against both the corroborating and non-corroborating
      fixtures; record both outcomes. *(completed: identical results to Phase 6 — corroborating
      fixture flips plan_markers_verified absent->true with 3/3 counts; non-corroborating fixture
      stays absent/0/0)*
- [x] Writer-instruction check: for each of the five edited writer/reader files, grep the specific
      anchor string and confirm the new wording is present and unambiguous. A human-readable
      confirmation that a fresh reader of each Stage 7 instruction cannot resolve the nesting the
      wrong way. *(completed: all five anchors confirmed present)*
- [x] Source-store boundary gate: confirm `git status --porcelain` contains no path beginning with
      `.claude/`, and that every changed non-`specs/` path begins with `agent-system/extensions/core/`.
      *(completed: zero `.claude/` paths; all 12 non-specs changed files begin with
      `agent-system/extensions/core/`)*
- [x] No-task-references gate: grep every changed file outside `specs/**` for task-number citation
      patterns (`task [0-9]`, `tasks [0-9]`, `(task [0-9]`); confirm zero hits. *(completed: zero
      NEW citations introduced across the entire task diff — pre-existing task-808/task-774/
      task-447/task-412/task-1 hits in unrelated, untouched-by-this-diff lines were confirmed via
      `git diff` to predate this task)*
- [x] Run `bash -n` on the modified script and on scratch extractions of both skill files' modified
      bash blocks. *(completed: all four pass)*
- [x] Run `bash .claude/scripts/validate-artifact.sh` against this plan file if available, and
      confirm no new errors. *(completed: `[PASS] plan artifact is valid (0 warning(s))`)*
- [x] Write the implementation summary to
      `specs/939_return_metadata_schema_compliance/summaries/01_return-metadata-schema-compliance-summary.md`,
      including the before/after table and the explicit item-B, item-C, and footprint decisions.
      *(completed)*
- [x] Confirm the plan's own phase headings are all marked `[COMPLETED]` before reporting completion.
      *(completed: Phases 1-6 all [COMPLETED]; this phase completes the set)*

**Timing**: 1.0 hours

**Depends on**: 2, 3, 4, 5, 6

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts five writer/reader files carry new or corrected wording
(`general-implementation-agent.md`, `general-implementation-hard-agent.md`,
`skill-implementer-hard/SKILL.md`, `skill-team-implement/SKILL.md`, `general-research-agent.md`) and
nine files are changed in total. Confirm against `git diff --stat` for this task's commits rather
than against this list; a mismatch means an earlier phase's Scope Hypothesis resolved differently
and the summary must record the actual set, not this one.

**Files to modify**:

- `specs/939_return_metadata_schema_compliance/summaries/01_return-metadata-schema-compliance-summary.md`
  — implementation summary (created).

**Verification**:

- The before/after table exists and shows, for defect1: `phases_completed` 0 both before and after
  (unchanged by design), with `evidence_suspect` going `absent -> true`; and for defect2:
  `artifact_path` `""` both before and after, with `evidence_suspect` going `absent -> true`.
- The Phase 6 harness records `plan_markers_verified` transitioning `absent -> true` on the
  corroborating fixture and staying `absent` on the non-corroborating one.
- `git status --porcelain` shows zero `.claude/` paths.
- Zero task-number citation hits outside `specs/**`.
- All `bash -n` checks pass.

---

## Testing & Validation

- [ ] Control fixture's recovery output is byte-identical for every pre-existing field before and
      after all changes (no regression to the correct-shape path).
- [ ] Defect 1 fixture produces `evidence_suspect: true` / `evidence_reason: "PHASES_ZERO_ON_SUCCESS"`
      and its phase counts remain `0/0` in the script output (proving no permissive fallback was
      added).
- [ ] Defect 2 fixture produces `evidence_suspect: true` / `evidence_reason: "ARTIFACTS_SHAPE_MISMATCH"`.
- [ ] Corroborating orchestrator fixture flips `plan_markers_verified` to `true` and yields
      grep-derived N/N counts with a loud stderr banner.
- [ ] Non-corroborating orchestrator fixture (plan with zero phase headings) leaves
      `plan_markers_verified` at `absent` and counts at `0/0`.
- [ ] `skill-implementer-hard/SKILL.md` contains no `phases_completed` read lacking a `.metadata.`
      prefix.
- [ ] `skill-implementer/SKILL.md` is untouched.
- [ ] `bash -n` passes on `orchestrate-recover-outcome.sh` and on extracted bash from both
      orchestrator skill files.
- [ ] No changed path outside `specs/**` begins with `.claude/`.
- [ ] No task-number citation in any changed file outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/agents/general-implementation-agent.md` (modified)
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` (modified)
- `agent-system/extensions/core/agents/general-research-agent.md` (modified)
- `agent-system/extensions/core/skills/skill-team-implement/SKILL.md` (modified)
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` (modified, beyond declared
  file_scope — see Declared Footprint vs. Actual Footprint)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (modified, beyond declared
  file_scope)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (modified, beyond declared
  file_scope)
- `agent-system/extensions/core/context/formats/return-metadata-file.md` (modified)
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` (modified)
- `specs/939_return_metadata_schema_compliance/summaries/01_return-metadata-schema-compliance-summary.md`
  (created)
- Scratch fixtures under the session scratchpad (not deliverables, not committed)

## Rollback/Contingency

- Every phase commits separately except Phase 2, which is one declared `atomic-batch` commit
  spanning its three files. Reverting any single phase's commit restores the prior behavior without
  touching the others.
- The highest-risk coupling is Phase 2's writer/reader pair. If it must be reverted, revert the
  whole Phase 2 commit — never one file of it, since the writer and the hard-mode reader are only
  consistent together.
- Phase 5 is additive to the emitted JSON only; reverting it leaves the three call sites reading the
  same field set they read today. Phase 6 depends on Phase 5's fields, so reverting Phase 5 requires
  reverting Phase 6 first.
- Phases 3 and 4 are prose-only and independently revertible with no behavioral coupling.
- If Phase 1's baseline capture contradicts the research's recorded observations, stop before any
  edit and report — the premise of Phases 2 through 6 would need re-examination rather than a
  rollback.

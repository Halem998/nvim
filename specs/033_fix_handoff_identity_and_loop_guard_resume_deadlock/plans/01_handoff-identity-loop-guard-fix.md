# Implementation Plan: fix_handoff_identity_and_loop_guard_resume_deadlock

- **Task**: 33 - fix_handoff_identity_and_loop_guard_resume_deadlock
- **Status**: [IMPLEMENTING]
- **Effort**: 16 hours
- **Dependencies**: None
- **Research Inputs**: specs/033_fix_handoff_identity_and_loop_guard_resume_deadlock/reports/01_handoff-identity-and-loop-guard-resume.md
- **Artifacts**: plans/01_handoff-identity-loop-guard-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Four coupled run-state-integrity defects in the orchestrator engines share one root cause: the
system treats "a dispatched agent reported" as "that agent terminated". This plan states that
model once in a new context pattern file, then closes each defect against it: a per-dispatch
`dispatch_seq` identity minted by the orchestrator and checked at Stage 5 (Defect A), an explicit
operator-typed budget-continuation override for an exhausted loop guard (Defect B), a territory
contract that asserts only what is checkable plus the missing `territory` wiring in the hard
engine's per-phase dispatch context (Defect 5), and a handoff-before-marker ordering rule with a
heading-scan cross-check (Defect 6). Definition of done: both regression tests the acceptance
criteria demand pass, all six named existing suites still pass, and no writer or reader in core,
cslib, or lean is left on the old contract.

**Every edit target in this plan is under `agent-system/extensions/**`.** `.claude/**` is a
gitignored, regenerated deploy artifact; it is read and executed (tests, `verify-deploy.sh`,
`deploy-headless.sh`) but never edited.

### Research Integration

The research report resolved four questions this plan builds on rather than re-litigates:

- **Identity mechanism**: an orchestrator-minted, unforgeable `dispatch_seq` embedded in handoff
  CONTENT, compared by Stage 5 against the value the orchestrator itself minted for the current
  cycle. This is the only evaluated approach demonstrably correct while the predecessor is still
  live and writing — a woken predecessor cannot know the successor's freshly-minted value.
  Content-only phase echoing was rejected (a woken predecessor echoes its own original phase
  number and looks internally consistent). Phase-scoped filenames are optional defense-in-depth,
  explicitly out of scope here.
- **Prerequisite gap**: `cslib-implementation-hard-agent.md` hardcodes the bare
  `.orchestrator-handoff.json` filename instead of reading `handoff_path` from delegation
  context, unlike lean and core. Fixed in Phase 6 regardless of mechanism.
- **`cycle_count` semantics**: per-task and cumulative across invocations, by design — confirming
  existing intent, not a new decision. `session_id` is a reliable new-invocation signal but MUST
  NOT be gated on: that would let an operator bypass MAX_CYCLES by re-invoking, and
  `test-session-runtime-files.sh` Case 3 forbids it. The fix is a distinct, explicit,
  operator-typed override with a loud archive-and-reinit and an honest Stage 7 message.
- **Scope**: Defect 5 stays (its fix site needs a `territory` key ADDED to hard Stage 4's
  dispatch-context construction — there is none today, so this is wiring, not prose). Defect 6
  stays but is planned as a cleanly separable phase (Phase 12) so scope can shrink if needed.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in the delegation context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:
- A predecessor phase's late handoff write — mtime INSIDE the successor's dispatch window — is
  rejected by both engines, demonstrated by a regression test reproducing that exact timing.
- The `dispatch_seq` contract is consistent across schema, `validate-handoff.sh`,
  `docs/architecture/handoff-schema.md`, `context/standards/orchestrator-runtime-files.md`, every
  core writer/reader, and the cslib and lean extension writers.
- An operator invoking the documented resume command after a MAX_CYCLES exhaustion actually
  dispatches work in BOTH engines, via an explicit typed override, covered by a regression test.
- Stage 2, Stage 7, Stage 8 cleanup, and the printed resume message all agree on one explicitly
  documented answer to "is `cycle_count` per-invocation or per-task".
- Defect A's Stage 5 gate is a verbatim twin in both engines; Defect B's asymmetry decision is
  recorded in both files.
- The territory contract asserts only checkable, locally-scoped facts and is actually wired into
  the hard engine's per-phase dispatch context.
- Plan-marker promotion can no longer run ahead of the handoff on an interrupted dispatch.
- `test-session-runtime-files.sh` Case 3 still passes unmodified.

**Non-Goals**:
- Phase-scoped handoff filenames or a pointer file (defense-in-depth only; the content-based
  check is load-bearing and works at the existing static path).
- Adding the general 3-signal `loop-guard-staleness` detector to base mode. This is explicitly
  deferred, and the deferral is recorded in both engines.
- Folding budget exhaustion into hard mode's 3-signal staleness detector. That detector is for
  content gone stale; an exhausted guard is accurate, not stale.
- Preventing operator abuse of the new override flag (a deliberate, visible, typed human decision
  is exactly what the flag is for).
- Extending the stray-handoff sweep to new filename shapes (moot — no filename change).
- Changing `cycle_count`'s per-task cumulative semantics.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| One-sided fix of the Stage 5 verbatim twin — the named recurring defect class for this file pair | H | M | Phase 4 depends on Phase 3 and must diff the two gate blocks for verbatim equality apart from the notice prefix; Phase 7 extends `test-handoff-reader-parity.sh` to assert gate parity mechanically |
| Case 3's regex-anchored 3-line extraction is brittle to reformatting near the `guard_session_id != session_id` anchor | H | M | Phases 8/9 keep that block's 3-line shape byte-stable; every Defect B phase runs `test-session-runtime-files.sh` before reporting, not only at the end |
| A writer left on the old contract silently omits `dispatch_seq`, and a strict gate then rejects every legitimate handoff | H | M | Phases 3/4 land the gate as reject-on-MISMATCH, never reject-on-absent, with a loud warning on absent; the strict form is not adopted in this task |
| `cslib-implementation-hard-agent.md`'s hardcoded filename means cslib never sees a dynamic contract change | M | H | Phase 6 fixes it as a prerequisite, matching lean's existing `handoff_path`-or-fallback wording |
| Combined scope too large for one implementation pass | M | M | Phase 12 (Defect 6) is planned last and cleanly separable; dropping it leaves Defects A/B/5 complete |
| Edits to `.claude/**` silently wiped | H | L | Every phase's file list is source-store-only; Phase 13 redeploys via `.claude/scripts/deploy-headless.sh` and re-runs gates against the redeployed tree |
| Six phases touch `skill-orchestrate-hard/SKILL.md` or `skill-orchestrate/SKILL.md` | M | H | Wave table serializes every phase touching either file; no two same-file phases share a wave |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 5 | 1, 2 |
| 3 | 4, 6, 8 | 2, 3, 5 |
| 4 | 7, 9 | 3, 4, 8 |
| 5 | 10, 11 | 1, 8, 9 |
| 6 | 12 | 9, 11 |
| 7 | 13 | all |

Phases within the same wave can execute in parallel. Same-wave groups were checked for file
overlap and each touches a disjoint file set: wave 2 is (hard SKILL) vs (core agent contracts);
wave 3 is (base SKILL) vs (extension contracts) vs (hard SKILL — Defect B territory only, and
Phase 4 does not touch the hard engine); wave 4 is (test scripts) vs (base SKILL + command);
wave 5 is (test script) vs (territory.md + hard SKILL). Phase 11 is sequenced after Phase 9
specifically because it may need to touch the base engine.

---

### Phase 1: Shared "report != termination" model and runtime-files rationale [COMPLETED]

**Goal**: State the shared root cause once, in one new file, and correct the now-false tracking
rationale that depends on it.

**Tasks**:
- [x] Create `context/patterns/dispatch-report-not-termination.md` stating: a dispatched agent
      that has reported may still be live (via a self-armed watcher/monitor, or an operator
      resume) and may still commit and write files concurrently with the next dispatch. Include
      the two named instances: (1) a woken predecessor's late write always carries a NEWER mtime
      than the successor's dispatch window, so any mtime-only gate is structurally blind to it;
      (2) a woken predecessor reading a global "no concurrent agent" assertion has no way to
      recognize its own liveness as the exception that assertion failed to name. Draft wording is
      in the research report's "Shared Report != Termination Model" section — refine, do not
      restate verbatim elsewhere. *(completed)*
- [x] Add a "tear down watchers/monitors before reporting" directive to the pattern file so the
      wake path is reduced at source, not only tolerated. *(completed)*
- [x] In `context/standards/orchestrator-runtime-files.md`, rewrite the
      `.orchestrator-handoff.json` "Durable provenance (tracked)" rationale: its current
      justification (a documented freshness gate already protects against the "restored from an
      old commit" scenario) is true only for the git-restoration hazard and false for the
      late-writer hazard. Name both hazards, and point at the new pattern file for the second.
      *(completed)*
- [x] Register the new file in `agent-system/extensions/core/index-entries.json` with an accurate
      `line_count` (or run `.claude/scripts/generate-context-line-counts.sh --write` and take its
      value). *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md` - NEW; the
  single statement of the shared model
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - handoff
  tracking-rationale entry corrected
- `agent-system/extensions/core/index-entries.json` - index entry for the new context file

**Verification**:
- New file exists, is non-empty, and names both hazards.
- `bash .claude/scripts/generate-context-line-counts.sh --check` reports no drift for core.
- `grep -c "dispatch-report-not-termination" agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` is at least 1.

---

### Phase 2: `dispatch_seq` wire format — schema, validator, schema doc [COMPLETED]

**Goal**: Define the `dispatch_seq` field once, in the three places that define the handoff wire
contract, so every later phase codes against a settled shape.

**Tasks**:
- [x] Add `dispatch_seq` to `context/schemas/orchestrator-handoff-schema.json` as a top-level
      integer property. Do NOT add it to `required` — a writer that omits it must degrade to a
      loud warning, not a hard rejection (see Phase 3's gate posture). Document in its
      `description` that it is minted by the orchestrator immediately before the `Agent` call, is
      echoed back unchanged by the dispatched agent, and exists specifically so a still-live
      predecessor's late write can be discriminated from this dispatch's own. *(completed)*
- [x] Extend `scripts/validate-handoff.sh` with a `dispatch_seq` check in the same style as the
      existing conditionally-required checks: present-and-integer passes; absent emits a WARN
      naming the writer contract; present-but-not-an-integer FAILs. Update the script's usage/help
      text block alongside it. *(completed)*
- [x] Update `docs/architecture/handoff-schema.md`: document `dispatch_seq`, and correct the
      existing statement that "a handoff at the correct path is not necessarily *this dispatch's*
      handoff" so it names `dispatch_seq` as the discriminator rather than offering mtime as the
      only mitigation. Also correct the `phase` field's documentation to say explicitly that its
      four-value lifecycle enum cannot discriminate one plan phase from another and is not an
      identity mechanism. *(completed)*
- [x] Extend `scripts/tests/test-validate-handoff.sh` with cases for all three `dispatch_seq`
      outcomes (valid integer, absent, non-integer). *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: atomic-batch

**Scope Hypothesis**: This phase asserts exactly four files and that `validate-handoff.sh` has an
existing conditionally-required check idiom to copy. Confirm at implementation time by reading
the script's existing `skeleton` / `artifacts` conditional checks before writing the new one; if
the idiom differs from what this plan assumes, follow the script's actual convention.

**Files to modify**:
- `agent-system/extensions/core/context/schemas/orchestrator-handoff-schema.json` - add
  `dispatch_seq` property, non-required
- `agent-system/extensions/core/scripts/validate-handoff.sh` - add the `dispatch_seq` check and
  usage text
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - document `dispatch_seq`;
  correct the mtime-only mitigation claim and the `phase` field's description
- `agent-system/extensions/core/scripts/tests/test-validate-handoff.sh` - three new cases

**Verification**:
- `bash -n agent-system/extensions/core/scripts/validate-handoff.sh` passes.
- `jq empty agent-system/extensions/core/context/schemas/orchestrator-handoff-schema.json` passes.
- `bash agent-system/extensions/core/scripts/tests/test-validate-handoff.sh` passes, including the
  three new cases.

---

### Phase 3: Hard engine — mint, inject, and gate on `dispatch_seq` [COMPLETED]

**Goal**: Make `skill-orchestrate-hard` the source of truth for what counts as the current
dispatch, and reject any handoff that does not match.

**Tasks**:
- [x] In Stage 2, initialize a monotonic `dispatch_seq` counter (persisted in the loop guard
      alongside `cycle_count`, with the `// 0` forward-compatible read idiom the other counters
      already use, so it survives a resume and never repeats a value within a task). *(completed:
      dispatch_seq_counter field + mint_dispatch_seq() helper)*
- [x] Immediately before every `Agent` tool call in Stage 4, increment the counter and capture the
      value into a shell variable for this dispatch, adjacent to the existing
      `dispatch_start_ts=$(date -u +%s)` capture. Cover every Stage 4 dispatch site: the research
      handler, the plan handler, and each implement/continuation/resume handler, plus the
      revise/blocker-escalation dispatch if one exists in this engine. *(completed: all 4
      dispatch_start_ts sites confirmed via grep now mint dispatch_seq; the per-phase site mints
      just before dispatch_context construction so the literal can carry it inline)*
- [x] Add `"dispatch_seq"` to each dispatch's delegation/dispatch context, next to the existing
      `handoff_path` key, including the per-phase `dispatch_context` JSON literal in Stage 4.
      *(completed)*
- [x] In Stage 5, extend the staleness gate: after the existing mtime check (which is KEPT as a
      second line of defense against the git-restoration hazard), read the handoff's
      `dispatch_seq` and compare it against the value minted for THIS cycle. On mismatch, set
      `handoff_stale=true` and take the same loud-error + `system-defect-record.sh` +
      `append_detected_defect` path the mtime branch already takes, with a distinct message
      naming both values. On absent, emit a WARN naming the writer contract and do NOT reject —
      the strict form is deliberately not adopted in this task. *(completed)*
- [x] Add a one-line pointer to `context/patterns/dispatch-report-not-termination.md` in the
      staleness-gate comment block, explaining why mtime alone is structurally insufficient. Do
      not restate the model. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: interface

**Scope Hypothesis**: This phase assumes five Stage 4 dispatch sites in this engine. Confirm at
implementation time with `grep -n "dispatch_start_ts" agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
— every site that sets a dispatch window is a site that must also mint a `dispatch_seq`. If the
counts disagree, the grep is authoritative and every found site must be covered.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - Stage 2 counter, Stage 4
  minting and context injection at every dispatch site, Stage 5 gate extension

**Verification**:
- Every `dispatch_start_ts` assignment in the file has a `dispatch_seq` mint adjacent to it.
- Every dispatch context containing `handoff_path` also contains `dispatch_seq`.
- The Stage 5 gate rejects on mismatch and warns (does not reject) on absent.
- `bash agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh` still passes (the
  new guard field must not disturb the 3-signal detector).

---

### Phase 4: Base engine — verbatim twin of the Stage 5 gate, plus base dispatch sites [COMPLETED]

**Goal**: Honor the binding co-maintenance contract by landing the identical gate in
`skill-orchestrate`, so this fix is not the next instance of the known one-sided-fix defect class.

**Tasks**:
- [x] Copy Phase 3's Stage 5 gate extension into `skill-orchestrate/SKILL.md` VERBATIM, changing
      only the notice prefix (`[orchestrate]` vs `[hard-orchestrate]`) and the self-attributing
      `--detecting-site` / `--attributed-path` strings, exactly as the existing twin does.
      *(completed)*
- [x] Mirror the Stage 2 counter initialization. *(completed)*
- [x] Mint and inject `dispatch_seq` at every base-engine dispatch site: the single-task Stage 4
      research/plan/implement/continuation/resume handlers, the Stage 6 blocker-escalation revise
      dispatch, AND the multi-task Stage MT-4 research/plan/implement dispatches (which build
      their own per-task `handoff_path_abs` and are a separate set of call sites). *(completed:
      the Stage 6 revise re-dispatch had no dispatch_start_ts capture at all -- added one
      alongside the mint, matching every other handoff-writing site; MT-4 uses a batch-scoped
      dispatch_seq_counter + per-task dispatch_seq map in mt_state_file since three tasks can
      dispatch in one batched message)*
- [x] Add the same one-line pointer to `context/patterns/dispatch-report-not-termination.md`.
      *(completed)*
- [x] Diff the two gate blocks and confirm byte-equality apart from the prefix and attribution
      strings before reporting. *(completed: byte-identical apart from prefix/attribution and one
      hard-mode-only "HARD-MODE TWIN of..." cross-reference comment, matching the existing
      convention where such cross-reference comments live only in the hard-mode file -- see the
      append_detected_defect precedent)*

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts the base engine has both single-task Stage 4 handlers and
a separate Stage MT-4 dispatch set. Confirm with
`grep -n "handoff_path" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — every
context object carrying `handoff_path` is a dispatch site needing `dispatch_seq`.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 2 counter, Stage 4 and
  Stage MT-4 minting and injection, Stage 5 gate twin

**Verification**:
- A diff of the two Stage 5 gate blocks shows only prefix and attribution differences.
- Every context object carrying `handoff_path` in this file also carries `dispatch_seq`.
- `bash agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh` still passes.

---

### Phase 5: Core writer contracts [COMPLETED]

**Goal**: Every core agent and skill that writes a handoff echoes `dispatch_seq` back unchanged.

**Tasks**:
- [x] Add the echo-back instruction to each core writer: read `dispatch_seq` from the delegation
      context and write it into the handoff unchanged; if the field is absent from the delegation
      context, omit it rather than inventing a value. *(completed: the two research agents and
      skill-team-implement are non-writers of .orchestrator-handoff.json by design, so their
      instruction is framed as a defensive/forward-pass note rather than an active writer path —
      confirmed via grep that neither writes the file today)*
- [x] Update `context/contracts/wrap-up.md`'s H9 handoff-write contract to include `dispatch_seq`
      in the required-echo field set, since that file is the contract the agents reference.
      *(completed)*
- [x] Update `context/formats/return-metadata-file.md` only if it documents the handoff's field
      set; if it does not, leave it untouched and record that in the phase's report. *(completed:
      left untouched -- it documents only the phases_completed/phases_total nesting contrast, not
      the full handoff field set)*
- [x] Do not restate the report-vs-termination model in any of these files — a one-line pointer
      to the pattern file is the maximum. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts the core writer set is the four agents plus
`wrap-up.md`, `skill-implementer-hard`, and `skill-team-implement`. Confirm at implementation time
with `grep -rln "orchestrator-handoff.json" agent-system/extensions/core/{agents,skills,context}`
and treat that result as authoritative; readers-only files (schema, validators, hooks, docs) are
out of this phase's scope and are handled elsewhere in the plan.

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` - echo `dispatch_seq`
- `agent-system/extensions/core/agents/general-implementation-agent.md` - echo `dispatch_seq`
- `agent-system/extensions/core/agents/general-research-hard-agent.md` - echo `dispatch_seq`
- `agent-system/extensions/core/agents/general-research-agent.md` - echo `dispatch_seq`
- `agent-system/extensions/core/context/contracts/wrap-up.md` - H9 required-echo field set
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` - echo `dispatch_seq`
- `agent-system/extensions/core/skills/skill-team-implement/SKILL.md` - echo `dispatch_seq`

**Verification**:
- Every file in the confirmed writer set mentions `dispatch_seq`.
- `bash .claude/scripts/lint/lint-agent-contracts.sh` passes.

---

### Phase 6: Extension writer contracts (cslib, lean) plus the cslib `handoff_path` prerequisite [COMPLETED]

**Goal**: Sweep the non-core writers the acceptance criteria name, and close the pre-existing
cslib gap that would otherwise make cslib deaf to any dynamic handoff contract.

**Tasks**:
- [x] **Prerequisite fix**: change `cslib-implementation-hard-agent.md`'s handoff-write step from
      the hardcoded bare `.orchestrator-handoff.json` filename to the dynamic form lean already
      uses — write to the absolute path given in the delegation context as `handoff_path`, with
      `{task_dir}/.orchestrator-handoff.json` as the documented fallback when that field is
      absent. Match lean's wording so the two extensions do not drift. *(completed: wording
      matched verbatim to lean-implementation-hard-agent.md's Step 1)*
- [x] Add the `dispatch_seq` echo-back instruction to every cslib writer:
      `cslib-implementation-hard-agent.md`, `cslib-implementation-agent.md`,
      `cslib-research-agent.md`, `skill-cslib-implementation-hard/SKILL.md`,
      `skill-cslib-research/SKILL.md`. *(completed: the two non-writer files
      (cslib-implementation-agent.md, cslib-research-agent.md) get a defensive-case note next to
      their existing "MUST NOT write" prohibition, matching Phase 5's core precedent)*
- [x] Add the same instruction to every lean writer: `lean-implementation-hard-agent.md`,
      `skill-lean-implementation-hard/SKILL.md`, and `lean/context/contracts/anti-analysis.md`
      where it describes the handoff write. *(completed)*
- [x] Use the same wording as Phase 5's core contract so a future reader can diff them.
      *(completed)*

**Timing**: 1.5 hours

**Depends on**: 2, 5

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts five cslib and three lean files. Confirm with
`grep -rln "orchestrator-handoff.json" agent-system/extensions/cslib agent-system/extensions/lean`
before editing; the `literature` extension's `merge-sources/claudemd.md` hit is a doc reference,
not a writer, and is deliberately excluded.

**Files to modify**:
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` - dynamic
  `handoff_path` + `dispatch_seq` echo
- `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` - `dispatch_seq` echo
- `agent-system/extensions/cslib/agents/cslib-research-agent.md` - `dispatch_seq` echo
- `agent-system/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md` - `dispatch_seq` echo
- `agent-system/extensions/cslib/skills/skill-cslib-research/SKILL.md` - `dispatch_seq` echo
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` - `dispatch_seq` echo
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` - `dispatch_seq` echo
- `agent-system/extensions/lean/context/contracts/anti-analysis.md` - `dispatch_seq` echo

**Verification**:
- `grep -c "handoff_path" agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`
  is at least 1, and the bare hardcoded filename no longer appears as the write target.
- Every confirmed extension writer mentions `dispatch_seq`.
- `bash .claude/scripts/check-extension-docs.sh` passes.

---

### Phase 7: Defect A regression test [COMPLETED]

**Goal**: Acceptance criterion 1 — a test that reproduces the observed timing (late write with
mtime INSIDE the successor's dispatch window) and asserts rejection.

**Tasks**:
- [x] Create `scripts/tests/test-handoff-dispatch-identity.sh` following the conventions of the
      sibling suites in that directory (same harness shape, same pass/fail reporting, same exit
      codes). Cases:
      1. Handoff whose `dispatch_seq` matches the current cycle's minted value and whose mtime is
         inside the window: ACCEPTED.
      2. Handoff whose `dispatch_seq` is a PREDECESSOR's value and whose mtime is inside the
         successor's window (the observed failure, with the recorded 6-second overlap shape):
         REJECTED. This is the load-bearing case.
      3. Handoff with an old mtime (git-restoration hazard): still REJECTED by the retained mtime
         check.
      4. Handoff with no `dispatch_seq` at all: WARN, not rejected.
      *(completed: all 4 cases run against both engines' extracted regions, 22 assertions total)*
- [x] Assert the gate's behavior for BOTH engines — the test must extract and exercise the gate
      logic from each SKILL.md, or assert their byte-equality, so a future one-sided edit fails
      the suite. *(completed: does both -- executes the gate logic from each engine's extraction
      AND test-handoff-reader-parity.sh asserts byte-equality)*
- [x] Extend `scripts/tests/test-handoff-reader-parity.sh` with an assertion that the two Stage 5
      gate blocks remain parity-equal on the `dispatch_seq` comparison. *(completed: added
      `dispatch-seq-gate:begin`/`:end` sentinel markers to both SKILL.md files to make the
      region mechanically extractable)*

**Timing**: 1.5 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh` - NEW
- `agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh` - gate parity
  assertion

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh` passes with
  all four cases exercised.
- `bash agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh` passes.
- Temporarily reverting the Phase 3 gate makes case 2 fail (confirm the test actually tests the
  fix, then restore).

---

### Phase 8: Defect B — hard engine budget-continuation override [COMPLETED]

**Goal**: Give the operator a sanctioned, explicit way to continue an exhausted run in hard mode,
and make Stage 7's message honest.

**Tasks**:
- [x] Record the decision explicitly, in the Stage 2 comment block: `cycle_count` is a per-task,
      cumulative budget that survives re-invocation by design; it is deliberately NOT reset on a
      new `session_id`, because that would let re-invocation silently bypass MAX_CYCLES. Point at
      `test-session-runtime-files.sh` Case 3 as the regression protecting this. *(completed)*
- [x] Parse a new explicit operator flag (name it `--continue-budget`) from the delegation
      context. Do NOT infer it from `session_id`, mtime, or any automatic signal. *(completed:
      `continue_budget_flag` parsed in Stage 0)*
- [x] In Stage 2, after the existing staleness block and before the resume read: if
      `cycle_count >= MAX_CYCLES` AND the flag is present, archive the exhausted guard aside using
      the same `mv`-to-dated-name pattern the staleness detector already uses (for auditability),
      reinitialize at `cycle_count=0` preserving the cross-invocation history fields, and log
      loudly naming the exhausted count, the archive destination, and the flag that authorized it.
      *(completed: uses `cp` not `mv` for the archive step specifically because the SAME guard
      path is then reinitialized in place from the copy, preserving dispatch_seq_counter and
      detected_defects rather than falling through to fresh-init)*
- [x] In Stage 2, if `cycle_count >= MAX_CYCLES` and the flag is ABSENT: exit immediately with a
      clear message naming the actual working command, instead of entering a loop that runs zero
      times and falls through to a misleading Stage 7 message. *(completed)*
- [x] Update Stage 7's MAX_CYCLES branch to print the command that actually works
      (`/orchestrate {N} --hard --continue-budget`), not the current no-op instruction.
      *(completed)*
- [x] Leave Stage 8 cleanup UNCHANGED (guard still preserved on partial exit — correct, since the
      guard's job is to persist across exactly this gap) and add a comment saying so explicitly,
      so the four sites visibly agree. *(completed)*
- [x] Record, in this file, the asymmetry decision: budget exhaustion is deliberately NOT a fourth
      signal in the 3-signal `loop-guard-staleness` detector, because that detector's premise is
      "content gone stale" while an exhausted guard is accurate. Also record that whether base mode
      gains the general 3-signal detector is out of scope and not decided here. *(completed)*
- [x] Add the same decision record to `context/standards/orchestrator-runtime-files.md`'s loop-guard
      entry so the semantics live in the standard, not only in the engines. *(completed)*
- [x] Keep the `guard_session_id != session_id` mismatch block's 3-line shape byte-stable.
      *(completed: that anchor lives only in skill-orchestrate/SKILL.md per
      test-session-runtime-files.sh's LOOP_GUARD_SKILL resolution -- confirmed untouched by this
      phase's hard-engine-only edits; test-session-runtime-files.sh run clean, 6/6 passed)*

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - Stage 2 decision record,
  flag parse, exhaustion branch, Stage 7 message, Stage 8 comment, asymmetry record
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - loop-guard
  `cycle_count` semantics record

**Verification**:
- `bash agent-system/extensions/core/scripts/test-session-runtime-files.sh` passes, Case 3
  included, with Case 3 itself unmodified.
- `bash agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh` passes (the
  override must not appear as a fourth detector signal).
- Stage 2, Stage 7, Stage 8, and the resume message all name the same semantics.

---

### Phase 9: Defect B — base engine override, command flag, recorded asymmetry [COMPLETED]

**Goal**: Close the same deadlock in base mode (which today has zero self-healing), and document
the flag at the command surface.

**Tasks**:
- [x] Apply the same override mechanism to `skill-orchestrate/SKILL.md` Stage 2 (exhaustion branch
      + archive-and-reinit + honest refusal when the flag is absent) and Stage 7 (both exhaustion
      messages must name `/orchestrate {N} --continue-budget`). *(completed)*
- [x] Leave base Stage 8's guard `rm -f`-on-clean-exit-only behavior unchanged, with the same
      explicit comment. *(completed)*
- [x] Record the SAME `cycle_count` per-task/cumulative decision in base's Stage 2 comment block.
      *(completed)*
- [x] Record the asymmetry decision in base too, in the file's existing "recorded, not acted on"
      style: the 3-signal detector's absence here remains deliberate and undecided by this work;
      the override is orthogonal to it and does not require deciding it. Mirror the decision text
      from Phase 8 so the two records visibly agree, while noting the mechanism itself is
      asymmetric (net-new code here, not a mirror of hard's detector). *(completed)*
- [x] Add `--continue-budget` to `commands/orchestrate.md`'s flag table and thread it into the
      skill delegation context alongside `lit_flag`, following how `--lit` and
      `allow_self_modifying` are already threaded. *(completed: also required adding
      `--continue-budget` parsing to `scripts/parse-command-args.sh`, the actual shared parser
      site `--lit`/`--allow-self-modifying` are parsed at -- not in this plan's original file
      list but mechanically required for the flag to reach `commands/orchestrate.md` at all)*
- [x] Keep base's `guard_session_id != session_id` mismatch block's 3-line shape byte-stable — it
      is the exact anchor Case 3 extracts from THIS file. *(completed: confirmed via grep after
      the Stage 2 edit AND test-session-runtime-files.sh run immediately after, 6/6 passed)*

**Timing**: 1.5 hours

**Depends on**: 4, 8

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 2 override, Stage 7
  messages, Stage 8 comment, decision and asymmetry records
- `agent-system/extensions/core/commands/orchestrate.md` - `--continue-budget` flag table row and
  delegation-context threading

**Verification**:
- `bash agent-system/extensions/core/scripts/test-session-runtime-files.sh` passes with Case 3
  unmodified — run this immediately after the Stage 2 edit, not only at phase end.
- Both engines' asymmetry records are present and mutually consistent.
- `commands/orchestrate.md` documents the flag and passes it through.

---

### Phase 10: Defect B regression test [COMPLETED]

**Goal**: Acceptance criterion 3 — prove the documented resume path actually dispatches work in
both engines.

**Tasks**:
- [x] Create `scripts/tests/test-loop-guard-budget-override.sh` following sibling-suite
      conventions. Cases, run against BOTH engines:
      1. Guard at `cycle_count == MAX_CYCLES`, flag absent: engine refuses with the honest message
         and does NOT enter a zero-iteration loop.
      2. Guard at `cycle_count == MAX_CYCLES`, flag present: guard archived to a dated name,
         reinitialized at 0, loud log emitted, and the loop condition is now true (work would be
         dispatched).
      3. Guard below MAX_CYCLES, flag present: normal resume, no archive, no reinit — the flag is
         inert when the budget is not exhausted.
      4. Guard with a different `guard_session_id` and a non-exhausted budget: still just an INFO
         log, never a reset — asserting the Case 3 invariant from a second angle. *(completed: 36
         assertions across both engines; discovered during authoring that the guard_session_id
         INFO log itself is base-engine-only -- skill-orchestrate-hard/SKILL.md's resume-read has
         no such check at all -- so case 4's log-content assertion is base-only while the
         never-reset invariant is asserted for both)*
- [x] Assert Stage 7's printed message names the flag. *(completed)*
- [x] Confirm `scripts/test-session-runtime-files.sh` Case 3 is byte-unmodified relative to
      `HEAD` (`git diff HEAD -- <path>` shows no change inside the Case 3 block); if a change was
      unavoidable, record the justification in the phase report and in the test file itself.
      *(completed: git diff HEAD is empty for that file; test-loop-guard-budget-override.sh also
      runs test-session-runtime-files.sh itself as its own final assertion, not just trusting a
      hand-authored claim)*

**Timing**: 1.5 hours

**Depends on**: 8, 9

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-loop-guard-budget-override.sh` - NEW

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-loop-guard-budget-override.sh` passes with
  all four cases exercised against both engines.
- `bash agent-system/extensions/core/scripts/test-session-runtime-files.sh` passes.
- `git diff HEAD -- agent-system/extensions/core/scripts/test-session-runtime-files.sh` is empty,
  or a recorded justification exists.

---

### Phase 11: Defect 5 — sound territory assertion, actually wired [COMPLETED]

**Goal**: Replace an unsound global no-concurrency claim with a checkable local one, and inject it
at a dispatch site that today has no `territory` key at all.

**Tasks**:
- [x] Rewrite `context/contracts/territory.md`'s Territory Declaration Template to assert only
      what is true and checkable: this dispatch owns these files; other work may exist
      concurrently; if you observe work you did not do (foreign commits, foreign uncommitted
      modifications, a running build you did not start), STOP and report it rather than proceeding
      or dismissing it. Explicitly remove any framing that would license a woken agent to
      dismiss a true observation of concurrent work as fictitious. *(completed)*
- [x] Add a one-line pointer to `context/patterns/dispatch-report-not-termination.md` explaining
      why the global claim is unsound (a reported dispatch may still be live). Do not restate.
      *(completed)*
- [x] Review the "shared state file / merge-write protocol" bullets in the same file against the
      new `dispatch_seq` contract and correct anything that now contradicts it (in particular any
      "last-write wins" phrasing that assumes the writer is the current dispatch). *(completed:
      corrected the Handoff Merge Rule's conflict-resolution bullet)*
- [x] **Wiring**: add a `territory` key to `skill-orchestrate-hard/SKILL.md`'s Stage 4 per-phase
      `dispatch_context` JSON literal, populated from the phase's own file list, so the contract
      is actually delivered to the dispatched agent. There is no such key today — this is new
      wiring, not a prose change. *(completed: owned_files points the agent at the plan's own
      Phase N "Files to modify" section rather than the orchestrator pre-parsing it itself, to
      avoid expanding the orchestrator's Read allowlist beyond its enumerated bounded uses --
      the agent is unrestricted in what it may read)*
- [x] Check `skill-orchestrate/SKILL.md` for equivalent boilerplate; if base mode has no per-phase
      territory construction, record that as a deliberate non-change rather than inventing one.
      *(completed: confirmed via grep -- base mode dispatches the whole plan, not per-phase, and
      has no territory construction anywhere; recorded non-change, no edit made)*
- [x] Review the hard engine's "Parallel Wave Dispatch: DISABLED" framing and scope it explicitly
      to what this orchestrator's own Stage 4 does (it never issues two concurrent `Agent` calls),
      so it can no longer be read as a claim about the state of the world. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1, 8, 9

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/context/contracts/territory.md` - template reframe, pointer,
  merge-protocol review
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - `territory` key added to
  the Stage 4 per-phase dispatch context; no-concurrency framing scoped
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - only if base has equivalent
  boilerplate; otherwise a recorded non-change

**Verification**:
- `grep -n "territory" agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` shows
  the key present in the Stage 4 dispatch context literal.
- The template contains a STOP-and-report clause and no global no-concurrency assertion.
- The hard engine's dispatch-context invariant checks (I1/I2, documented in its Stage 1b region)
  still hold with the new key present.

---

### Phase 12: Defect 6 — handoff before marker promotion, plus heading-scan cross-check [NOT STARTED]

**Goal**: An interrupted dispatch can no longer leave the plan's phase markers ahead of the
handoff, and the successor is not dispatched over unconfirmed work.

**Tasks**:
- [ ] In `context/contracts/wrap-up.md`, add an explicit ordering rule between the Incremental
      Commit Discipline and the terminal handoff write: a phase heading MUST NOT be promoted to
      `[COMPLETED]` before the handoff reflecting that phase has been written. State it as an
      ordering constraint with a named rationale (an agent that dies between the two leaves the
      plan file ahead of the handoff by construction).
- [ ] Add the cross-check to `skill-orchestrate-hard/SKILL.md`'s Stage 4 `next_phase`
      heading-status scan: compare the marker-derived completed count against the handoff's own
      `phases_completed`. On disagreement, do not silently dispatch the successor — emit a loud
      notice and treat the disputed phase as `[PARTIAL]`, matching the manual downgrade the
      operator performed in the observed incident.
- [ ] Apply the equivalent cross-check to `skill-orchestrate/SKILL.md`'s recovery-count /
      `next_phase` greps.
- [ ] Use the canonical phase-heading patterns from `scripts/lib/phase-heading-patterns.sh` rather
      than re-deriving a regex, and honor its ordering obligation: run
      `has_nonconforming_phase_headings` over the whole file before any filtered scan the
      cross-check depends on.

**Timing**: 1.5 hours

**Depends on**: 9, 11

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/context/contracts/wrap-up.md` - ordering rule
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - heading-scan cross-check
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - equivalent cross-check

**Verification**:
- `wrap-up.md` states the ordering rule explicitly.
- Both engines' heading scans consult the handoff's `phases_completed` before selecting
  `next_phase`, and both source `phase-heading-patterns.sh` rather than inlining a regex.
- `bash agent-system/extensions/core/scripts/tests/test-reconcile-handoff-status.sh` still passes.

---

### Phase 13: Consistency sweep, redeploy, and full gate run [NOT STARTED]

**Goal**: Acceptance criteria 2, 5, and 7 — prove nothing was left on the old contract and every
named suite still passes.

**Tasks**:
- [ ] Re-run the blast-radius grep
      (`grep -rln "orchestrator-handoff.json" agent-system/extensions/`) and confirm every writer
      carries the `dispatch_seq` echo and every reader/validator agrees with the schema. Record any
      file deliberately excluded (e.g. the literature extension's doc-only reference) with its
      reason.
- [ ] Confirm the four documents the criteria name are mutually consistent: the schema,
      `validate-handoff.sh`, `docs/architecture/handoff-schema.md`, and
      `context/standards/orchestrator-runtime-files.md`.
- [ ] Redeploy the source store into `.claude/` via `bash .claude/scripts/deploy-headless.sh` so
      the deployed tree matches, then run `bash .claude/scripts/verify-deploy.sh`.
- [ ] Run all six named existing suites plus the two new ones:
      `test-validate-handoff.sh`, `test-handoff-reader-parity.sh`, `test-loop-guard-staleness.sh`,
      `test-reconcile-handoff-status.sh`, `test-validate-handoff-location.sh`,
      `test-session-runtime-files.sh`, `test-handoff-dispatch-identity.sh`,
      `test-loop-guard-budget-override.sh`.
- [ ] Run the lints: `check-extension-docs.sh`, `lint/lint-agent-contracts.sh`,
      `lint/lint-routing-wiring.sh`, `lint/lint-contract-compliance.sh`,
      `generate-context-line-counts.sh --check`.
- [ ] Confirm no `.claude/**` file was hand-edited during implementation
      (`git status` plus a review of the phase reports).
- [ ] Confirm no task-number reference was introduced outside `specs/**`
      (`bash .claude/scripts/check-task-references.sh` if present).

**Timing**: 1.5 hours

**Depends on**: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts eight suites and five lints. Confirm the lint list against
`ls agent-system/extensions/core/scripts/lint/` and the suite list against
`ls agent-system/extensions/core/scripts/tests/` at implementation time; run everything found that
touches handoff or loop-guard behavior, not only the enumerated set.

**Files to modify**:
- None expected. Any file touched here is a defect found by the sweep and must be reported as such.

**Verification**:
- All eight suites pass.
- All lints pass.
- `verify-deploy.sh` passes against the redeployed tree.
- The exclusion list from the blast-radius grep is recorded with reasons.

---

## Testing & Validation

- [ ] `test-handoff-dispatch-identity.sh` — new; case 2 (late write with mtime inside the
      successor's window) is the load-bearing acceptance test for criterion 1.
- [ ] `test-loop-guard-budget-override.sh` — new; covers criterion 3 in both engines.
- [ ] `test-validate-handoff.sh` — extended with three `dispatch_seq` cases.
- [ ] `test-handoff-reader-parity.sh` — extended with a Stage 5 gate parity assertion.
- [ ] `test-loop-guard-staleness.sh` — unchanged; must still pass, proving the override was not
      folded into the 3-signal detector.
- [ ] `test-reconcile-handoff-status.sh` — unchanged; must still pass.
- [ ] `test-validate-handoff-location.sh` — unchanged; must still pass.
- [ ] `test-session-runtime-files.sh` — Case 3 unmodified and passing (criterion 5).
- [ ] `verify-deploy.sh` against the redeployed tree.
- [ ] Negative check: temporarily reverting the Phase 3 gate must make identity case 2 fail.

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md` (new)
- `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-loop-guard-budget-override.sh` (new)
- Modified: both orchestrate SKILL.md files, `commands/orchestrate.md`, the handoff schema,
  `validate-handoff.sh`, `docs/architecture/handoff-schema.md`,
  `context/standards/orchestrator-runtime-files.md`, `context/contracts/territory.md`,
  `context/contracts/wrap-up.md`, four core agents, `skill-implementer-hard`,
  `skill-team-implement`, five cslib files, three lean files, `index-entries.json`
- `specs/033_fix_handoff_identity_and_loop_guard_resume_deadlock/summaries/01_*-summary.md`

## Rollback/Contingency

Every phase is an independent commit under the `task {N} phase {P}` convention, so any single
phase reverts with `git revert` without disturbing the others. Three natural rollback boundaries:

- **Defect 6 (Phase 12)** is fully separable — reverting it leaves Defects A, B, and 5 complete.
- **Defect 5 (Phase 11)** is separable from A and B; only its pointer to the Phase 1 pattern file
  couples it, and that pointer is inert if reverted.
- **Defect A (Phases 2-7)** is revertible as a unit. The gate is additive and reject-on-mismatch
  only (never reject-on-absent), so partially-reverted state degrades to today's mtime-only
  behavior rather than rejecting legitimate handoffs.

If the identity gate proves too strict in live use, the immediate mitigation is to demote the
mismatch branch from `handoff_stale=true` to a loud warning in both engines (a two-line change in
each), preserving detection while restoring the old accept-and-proceed behavior, rather than
reverting the whole mechanism.

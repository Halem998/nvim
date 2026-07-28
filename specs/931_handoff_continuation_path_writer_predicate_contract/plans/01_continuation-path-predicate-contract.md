# Implementation Plan: Task #931

- **Task**: 931 - handoff_continuation_path_writer_predicate_contract
- **Status**: [COMPLETED]
- **Effort**: 6 hours
- **Dependencies**: None
- **Research Inputs**: specs/931_handoff_continuation_path_writer_predicate_contract/reports/01_handoff-continuation-predicate-contract.md
- **Artifacts**: plans/01_continuation-path-predicate-contract.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-script-testing.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `.orchestrator-handoff.json` continuation pointer has a field-name schism: the sole active
writer (H9 hard-mode wrap-up) emits a **flat top-level `continuation_path` string**, while
`orchestrate-triage-classify.sh` and base `skill-orchestrate/SKILL.md` Stage 4 read **only** the
nested `continuation_context.handoff_path`. A real hard-mode partial handoff therefore classifies
as `handoff_state: "empty"` instead of `"continuation"`, so the richer resume context never
reaches the successor dispatch.

This plan implements the research's **Option B, precisely scoped**: relax the two nested-only
readers to accept *either* form, mirroring the dual-acceptance convention `validate-handoff.sh`
already ships. It additionally closes the secondary gap the research flagged — base SKILL.md's
dispatch-context construction must **normalize** a flat `continuation_path` into the nested shape
the successor implementation agent consumes — and rewrites `docs/architecture/handoff-schema.md`,
which currently documents only the nested form while simultaneously naming a writer that emits
the flat one.

The regression test lands **first** and is proven RED against the unfixed predicate before the
fix is written, per the mandatory mutation-check discipline.

### Research Integration

Every material premise below comes from the research report, which corrected the task
description's stated mechanism:

- The defect is **not** `continuation_context` populated with `handoff_path: null`. It is a
  flat-vs-nested field-name schism. Plan phases are built on the corrected version.
- `skill-base.sh`'s `skill_write_orchestrator_handoff` (the only code that would ever write the
  nested form) is **dead code with zero callers** — hence Option A (forcing all writers onto the
  nested form) is rejected in favor of teaching the readers the form real writers emit.
- `validate-handoff.sh` already accepts `continuation_path` OR `continuation_context` as two
  equally valid forms. This is the codified precedent that makes Option B a codification, not a
  novel relaxation.
- `skill-orchestrate-hard/SKILL.md`'s Stage 4 reader already checks `.continuation_path` and is
  self-consistent with its own writer; the break is specifically in the shared classifier and the
  base engine.
- `orchestrate-dry-run-report.sh` calls the classifier and reports its verdict verbatim, so it
  inherits the fix with no edit of its own (confirmed: it contains zero `continuation` references).

Two grounding facts were resolved during planning that the research left as open investigation
items, and they are recorded here so the implementer does not re-derive them:

1. **Test sandboxing is solvable without an env-var override.**
   `orchestrate-triage-classify.sh` sources `deploy-root-guard.sh`, which hard-requires the
   script's parent directory to match `*/.claude` or `*/.opencode`, and derives
   `PROJECT_ROOT="$SCRIPT_DIR/../.."`. A workdir shaped as `$WORKDIR/.claude/scripts/` (holding
   copies of both `orchestrate-triage-classify.sh` and `deploy-root-guard.sh`) plus a sibling
   `$WORKDIR/specs/` satisfies both constraints, making `PROJECT_ROOT == $WORKDIR`. **No
   `STATE_FILE` override needs to be added.** This is a hypothesis to confirm at implementation
   time (see Phase 1's Scope Hypothesis), not a licence to skip verifying it.
2. **There are more nested-only read sites than the research enumerated.** Beyond
   `skill-orchestrate/SKILL.md`'s Stage 4 handler, the Stage 5 handoff-result read and the
   Stage MT-4 multi-task implement dispatch each independently read `.continuation_context`.
   Phase 3 covers all three so the "one rule, several copies" contract does not partially land.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- A handoff emitted by the standard (H9 flat `continuation_path`) writer path with a populated
  continuation classifies as `handoff_state: "continuation"`, not `"empty"`.
- The base engine's hand-applied mirror of the classifier rule changes in lockstep with the
  script, keeping the declared "one rule, several copies" contract intact.
- The successor implement dispatch actually **receives** a usable continuation pointer: a flat
  `continuation_path` is normalized into the nested `{ handoff_path, orchestrator_mode }` shape
  the dispatch context passes as `continuation_context`.
- `docs/architecture/handoff-schema.md` documents **both** accepted forms, names which writer
  emits which, and no longer contradicts its own "Handoff Writers" table.
- A committed regression suite at
  `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` covers the
  case, registered in `manifest.json`, and demonstrably RED before the fix.
- The dead `skill_write_orchestrator_handoff` has an explicit, recorded disposition.

**Non-Goals**:
- **Option A is explicitly rejected**: no writer is migrated onto the nested form. `wrap-up.md`'s
  canonical schema and the three agent-level Stage 5 templates are not rewritten.
- **cslib's Stage 5 template is out of scope.** `cslib-implementation-hard-agent.md` emits only
  `continuation_context`, hardcoded null, with no population instruction anywhere in the file — so
  cslib hard-mode partials never populate any continuation pointer regardless of which reader
  form is accepted. This is a separate, narrower defect in a different extension; fixing this
  task's readers does nothing for it either way. **Named follow-up: give
  `cslib-implementation-hard-agent.md` Stage 5 a `continuation_path` key plus the
  populate-on-partial/blocked instruction that core and lean already carry.** Recorded in
  Artifacts & Outputs for `/todo` harvest; not implemented here.
- **`skill_postflight_update`'s accept-list is out of scope.** A sibling task owns admitting
  `partial`/`blocked` (and deciding `failed`'s disposition) into that accept-list in
  `scripts/skill-base.sh`. See the collision analysis under Phase 4.
- No change to the verdict schema (`orchestrate-triage-v1`), its field names, or the engine
  routing table. Only the population of the existing `continuation` boolean changes.
- The reserved-but-unemitted `exit_partial` group stays reserved and unemitted.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Co-edit collision: both SKILL.md files were modified minutes ago by a sibling adding three-tier `dispatch_status` validation (Tier A `researched\|planned\|implemented`, Tier B `partial\|failed\|blocked`, Tier C off-schema banner) | H | M | Anchor **every** edit on symbol names and quoted distinctive strings (`continuation=$(echo "$handoff" \| jq`, `**Sub-state: continuation available**`), **never** line numbers — line numbers in this plan and the research report are stale-by-construction. Re-grep before each edit. Phase 6 greps for the `[OFF-SCHEMA DISPATCH STATUS` banner string to confirm the sibling's work is undisturbed. |
| A vacuous regression test that passes both pre- and post-fix | H | M | Phase 1 is gated on an observed RED: the suite MUST be run against the unfixed script and MUST report the `continuation_path`-only fixture as `"empty"`. Phase 1 does not close until that RED is recorded. A suite that passes at the end of Phase 1 is a defect, not a success. |
| Predicate fix lands but successor still receives a null `continuation_context` (the research's named secondary gap) | H | M | Phase 3 scopes the dispatch-context normalization explicitly as its own tasks, separate from the predicate mirror. The definition-of-done is not treated as met by the classifier verdict alone. |
| Deploy-root guard blocks the sandboxed test invocation | M | M | Resolved in planning: shape the workdir as `$WORKDIR/.claude/scripts/`. Phase 1 confirms empirically before building fixtures on top of it. |
| Editing `scripts/skill-base.sh` collides with the sibling's accept-list follow-up | M | L | Phase 4's skill-base.sh edit is comment-only, inside `skill_write_orchestrator_handoff` — a **different function** from `skill_postflight_update`. No shared lines, no behavioral change. Stated explicitly in Phase 4. |
| Edits accidentally target `.claude/**` (a gitignored, regenerated deploy artifact) | H | L | Every phase's file list is rooted at `agent-system/extensions/**`. Phase 6 runs `git status --short -- .claude/` and treats any modified tracked file there as a failure. |
| Task-number citations leak into deliverables | M | L | All files touched are outside `specs/**`. Phase 6 greps the diff for task-number citation patterns; prose cites durable anchors (function names, section headings, `validate-handoff.sh`) instead. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel. Phase 3 and Phase 4 touch disjoint files
(`skill-orchestrate/SKILL.md` vs. `skill-orchestrate-hard/SKILL.md` + `skill-base.sh`) and may run
concurrently.

---

### Phase 1: Regression suite, proven RED against the unfixed predicate [COMPLETED]

**Goal**: A fixture-driven suite exists at the conventional location, is registered, and is
**demonstrated to fail** against the current nested-only predicate on the exact case the
definition-of-done names. No production code is touched in this phase.

**Tasks**:
- [x] Confirm the sandbox shape empirically before writing fixtures: create a scratch
      `$WORKDIR/.claude/scripts/`, copy `orchestrate-triage-classify.sh` **and**
      `deploy-root-guard.sh` into it, create `$WORKDIR/specs/state.json`, and confirm the copied
      script runs (guard passes, `PROJECT_ROOT` resolves to `$WORKDIR`). If it does not, fall back
      to the research's alternative and add a minimal, separately-justified `STATE_FILE` override —
      do **not** weaken the mutation check to route around the friction. *(completed: confirmed by
      manual probe before writing the suite, and the suite's own sandbox-probe assertion at the top
      of the run passed — no STATE_FILE override needed)*
- [x] Create `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh`
      following the harness convention established by the two sibling suites at that location:
      `pass()`/`fail()`/`info()` helpers, integer `PASSED`/`FAILED` counters,
      `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`, `mktemp -d` workdir with
      `trap cleanup EXIT`, inline heredoc fixtures (no committed fixture tree), exit 0 iff
      `FAILED == 0`. *(completed)*
- [x] Fixture A (**the mutation-check fixture, load-bearing**): `specs/state.json` with an
      `active_projects` entry at status `partial`, plus that task's
      `.orchestrator-handoff.json` containing `"continuation_context": null` and
      `"continuation_path": "specs/NNN_slug/handoffs/phase-2-handoff-TS.md"`. Assert
      `handoff_state == "continuation"` and `group == "implement"`. *(completed)*
- [x] Fixture B (**no-regression on the nested form**): handoff with
      `"continuation_context": {"handoff_path": "...", "orchestrator_mode": true}` and no
      `continuation_path`. Assert `handoff_state == "continuation"`. *(completed)*
- [x] Fixture C (**genuinely empty stays empty — the anti-over-relaxation guard**): handoff with
      both `continuation_context: null` and `continuation_path: null`, `blockers: []`. Assert
      `handoff_state == "empty"`, `group == "implement"`. A relaxation that turns this into
      `"continuation"` is a defect. *(completed)*
- [x] Fixture D (**blockers precedence preserved**): `continuation_path` populated AND
      `blockers` non-empty. Assert `handoff_state == "continuation"` (continuation outranks
      blockers, per the script's documented precedence), NOT `"blockers"`. *(completed)*
- [x] Assert both engines (`single` and `mt`) agree on Fixture A, since the `partial + continuation`
      row is a converged row in the engine table. *(completed: also asserted for B, C, D)*
- [x] **Run the suite against the current, unfixed script and record the observed RED.** Fixture A
      must report `"empty"`. Capture the literal failing output into the phase's commit message or
      progress notes as the mutation-check evidence. *(completed: RED observed, exit code 1, 5
      passed / 4 failed — Fixture A reported handoff_state="empty" group="implement" on both
      engines; Fixture D reported handoff_state="blockers" group="needs_human" on both engines;
      Fixtures B and C passed pre-fix as expected)*
- [x] Register `"tests/test-orchestrate-triage-classify.sh"` in
      `agent-system/extensions/core/manifest.json`'s `provides.scripts` array, alongside the two
      existing `tests/` entries. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Two hypotheses require implementation-time confirmation.
(a) *The `$WORKDIR/.claude/scripts/` sandbox shape satisfies `deploy-root-guard.sh` and yields
`PROJECT_ROOT == $WORKDIR` with no source change to the tool.* Confirm by running the copied
script against a synthetic `state.json` before any fixture work; if it fails, the fallback is the
justified `STATE_FILE` override, not a skipped mutation check.
(b) *Four fixtures (A–D) suffice to cover the predicate's behavior space.* Confirm by re-reading
the `partial` branch of the verdict `jq` after writing them and checking each reachable outcome
(`continuation`/`blockers`/`empty`/`absent`) is either asserted or consciously excluded.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` - new file, the
  regression suite
- `agent-system/extensions/core/manifest.json` - add the suite to `provides.scripts`

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` exits
  **non-zero** with Fixture A reporting `handoff_state: "empty"` — this RED is the phase's
  success criterion.
- Fixtures B, C, D pass even pre-fix (they exercise unchanged behavior); only A is RED.
- `jq . agent-system/extensions/core/manifest.json` parses.
- `bash -n` on the new suite.

---

### Phase 2: Relax the classifier predicate to dual-form acceptance [COMPLETED]

**Goal**: `orchestrate-triage-classify.sh` accepts a non-null top-level `continuation_path` OR a
non-null nested `continuation_context.handoff_path`, and the suite from Phase 1 flips to GREEN.

**Tasks**:
- [x] In `orchestrate-triage-classify.sh`, replace the `continuation_ok` `jq` expression — anchored
      on the string `continuation_ok=$(jq -r`, not a line number — so it evaluates true when
      **either** `(.continuation_context.handoff_path // null) != null` **or**
      `(.continuation_path // null) != null`. Preserve the existing defensive
      `[ "$continuation_ok" = "true" ] || continuation_ok="false"` normalization and the
      `2>/dev/null` guard unchanged. *(completed)*
- [x] Update the script's header precedence block (the transcribed rule beginning
      `# Precedence for \`partial\` status`) so line 1 reads as a continuation pointer in **either**
      accepted form rather than `continuation_context` alone. *(completed)*
- [x] Update the header's engine table row label `partial + continuation` commentary and the
      `handoff_state` field definition in the verdict-schema comment block (currently
      `"continuation" (valid continuation_context)`) to name both forms. *(completed)*
- [x] Update the `reason` string emitted on the continuation row — currently the literal
      `" is partial with a valid continuation_context; routes to implement"` — so it no longer
      names only one form. Keep it a machine-templated summary that carries no fact absent from a
      structured field, per the script's own stated convention. *(completed: now "is partial with
      a valid continuation pointer; routes to implement")*
- [x] Add a short header note citing `validate-handoff.sh`'s already-shipped dual acceptance as
      the precedent this change conforms to, so a future editor does not re-narrow it. *(completed:
      added inline in the continuation_ok comment block)*

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: *The classifier's dependents are exactly `orchestrate-dry-run-report.sh`
(which reports the verdict verbatim and needs no edit) and the two SKILL.md engines (Phases 3–4).*
Confirm at implementation time with
`grep -rn "orchestrate-triage-classify" agent-system/extensions/` and verify no consumer parses
the `reason` string or branches on its wording.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` - dual-form predicate,
  header precedence block, schema comment, reason string

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` exits **0**
  — Fixture A now `"continuation"`, Fixtures B/C/D unchanged. Paired with Phase 1's recorded RED,
  this is the completed mutation check.
- `bash -n` on the modified script.
- Direct-dependent smoke: run `orchestrate-dry-run-report.sh` from a deployed tree and confirm it
  still parses verdicts and reports `handoff_state` verbatim with no schema complaint.

---

### Phase 3: Base engine — mirror the predicate and normalize the dispatch context [COMPLETED]

**Goal**: `skill-orchestrate/SKILL.md` reads both forms everywhere it reads a continuation pointer,
**and** the "continuation available" branch hands the successor agent a usable nested
`continuation_context` even when the writer emitted only a flat `continuation_path`. This phase
closes the secondary gap that the predicate relaxation alone does not.

**Tasks**:
- [x] Stage 4 `#### State: partial` handler: change the read (anchor on
      `continuation=$(echo "$handoff" | jq -c '.continuation_context // null')` inside the block
      immediately following the `**Cross-reference**` paragraph) to resolve **either** form. Emit a
      normalized object, e.g. `continuation` set to
      `{ handoff_path: (.continuation_context.handoff_path // .continuation_path), orchestrator_mode: true }`
      when either source is non-null, else `null`. *(completed)*
- [x] Update the sub-state condition prose `**Sub-state: continuation available** (continuation !=
      null AND has handoff_path)` so it describes the normalized value, not the raw nested field.
      *(completed)*
- [x] Dispatch-context normalization (**the secondary gap**): the Agent-tool context row that
      passes `continuation_context` must pass the **normalized** object built above, not the raw
      handoff field. The target shape is `{ handoff_path, orchestrator_mode: true }`, matching the
      shape `context/patterns/subagent-continuation-loop.md` already documents for the intra-skill
      successor case. Make it explicit in the table row that this is a normalized value, so a
      future editor does not "simplify" it back to a raw field read. *(completed)*
- [x] Stage 5 handoff-result read: the second
      `continuation=$(echo "$handoff" | jq -c '.continuation_context // null')` occurrence (inside
      the `else` arm that begins `handoff=$(cat "$handoff_file")`) must use the same dual-form
      resolution. Do **not** disturb the adjacent `dispatch_status` / `plan_markers_verified`
      reads added by the recent sibling. *(completed: adjacent reads untouched)*
- [x] Stage MT-4 multi-task implement dispatch: the bullet reading
      `Read \`continuation\` from \`task_dir/.orchestrator-handoff.json\` (or null)` is currently
      field-agnostic prose feeding a `continuation_context: continuation` dispatch field. Make it
      name the dual-form resolution and the normalized output shape explicitly. *(completed)*
- [x] Update the `**Cross-reference**` paragraph so its claim that the hand-applied rule matches
      `scripts/orchestrate-triage-classify.sh single` remains true after Phase 2. *(completed: added
      explicit mention of dual-form resolution; the underlying claim was already true)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: *There are exactly three continuation-pointer read sites in
`skill-orchestrate/SKILL.md` (Stage 4 partial handler, Stage 5 result read, Stage MT-4 dispatch
bullet).* Confirm at implementation time with
`grep -n "continuation" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` and check
each hit is either edited or consciously excluded with a stated reason.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 4 partial handler read +
  sub-state prose + dispatch-context row, Stage 5 result read, Stage MT-4 dispatch bullet,
  cross-reference paragraph

**Verification**:
- Extract the new `jq` expression from the Stage 4 code block and run it directly against Phase 1's
  Fixtures A–D; confirm it yields the same continuation/no-continuation decision as the fixed
  script for all four. Divergence between the script and its hand-applied mirror is exactly the
  class of defect this task exists to fix.
- Confirm the normalized object for Fixture A evaluates to a non-null
  `{ handoff_path: "specs/NNN_slug/handoffs/phase-2-handoff-TS.md", orchestrator_mode: true }`.
- `grep -c "OFF-SCHEMA DISPATCH STATUS" ` on the file is unchanged from its pre-edit value
  (sibling's `dispatch_status` work undisturbed).

---

### Phase 4: Hard-engine reader symmetry and dead-writer disposition [COMPLETED]

**Goal**: The hard engine reads both forms (defending against the mirror-image of today's bug), and
the dead `skill_write_orchestrator_handoff` gets an explicit recorded disposition.

**Tasks**:
- [x] `skill-orchestrate-hard/SKILL.md` Stage 4 `#### State: partial`: the read anchored on
      `continuation=$(echo "$handoff" | jq -r '.continuation_path // null')` currently checks the
      flat form **only**. Give it the same OR-fallback to `.continuation_context.handoff_path`.
      Rationale to state inline: today no writer needs it, but a revived nested-form writer would
      otherwise be invisible to the hard engine — the exact mirror of the defect being fixed.
      *(completed)*
- [x] `skill-orchestrate-hard/SKILL.md` Stage 5 result read: the
      `continuation=$(echo "$handoff" | jq -c '.continuation_context // null')` occurrence inside
      the `else` arm beginning `handoff=$(cat "$handoff_file")` is nested-only and inconsistent with
      its own Stage 4. Apply the same dual-form resolution. Leave the adjacent `skeleton`,
      `sorry_inventory`, `dispatch_status`, and `plan_markers_verified` reads untouched. *(completed:
      adjacent reads confirmed untouched by diff inspection)*
- [x] Update `**Sub-state: continuation available** (continuation != null)` prose if the resolution
      change alters what "non-null" means there. *(completed: reworded to describe the dual-form
      resolution and the literal-string-"null" comparison)*
- [x] **`skill_write_orchestrator_handoff` disposition — decided: document as dead, do not delete,
      do not rewire.** Add a header comment to the function in
      `agent-system/extensions/core/scripts/skill-base.sh` recording that (i) it currently has zero
      callers, (ii) the nested `continuation_context` object it would write is one of two accepted
      forms (the other being the flat `continuation_path` that live H9 wrap-up writers emit), and
      (iii) a future caller may use it as-is because the readers now accept its output. Rationale:
      deleting it would remove the only nested-form writer at the same moment the readers are being
      taught to accept the nested form, and rewiring it to also emit the flat form is unjustified
      work on a codepath nothing calls. *(completed: zero callers re-confirmed by grep at
      implementation time)*
- [x] **Collision statement (required by delegation)**: this is the *only* `skill-base.sh` edit in
      this plan. It is **comment-only**, adds no executable line, and lives inside
      `skill_write_orchestrator_handoff`. The named sibling follow-up targets
      `skill_postflight_update`'s status accept-list (admitting `partial`/`blocked`, deciding
      `failed`) — a **different function** with no shared lines. The two changes cannot conflict
      textually and are semantically independent. If the sibling has already landed by
      implementation time, re-read the file and confirm the two functions are still disjoint before
      editing. *(completed: re-confirmed disjoint at implementation time —
      skill_postflight_update spans lines 396-430, skill_write_orchestrator_handoff spans
      588-669+; no shared lines)*

**Timing**: 45 minutes

**Depends on**: 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - Stage 4 partial read
  OR-fallback, Stage 5 result read, sub-state prose
- `agent-system/extensions/core/scripts/skill-base.sh` - comment-only header note on
  `skill_write_orchestrator_handoff`

**Verification**:
- Extract the hard engine's new Stage 4 `jq` expression and run it against Phase 1's Fixtures A–D;
  confirm agreement with the fixed classifier on all four.
- `bash -n agent-system/extensions/core/scripts/skill-base.sh` passes.
- `git diff -- agent-system/extensions/core/scripts/skill-base.sh` shows comment lines only (every
  added line begins with `#`), and touches no line inside `skill_postflight_update`.
- `grep -c "OFF-SCHEMA DISPATCH STATUS"` on the hard SKILL.md is unchanged from its pre-edit value.

---

### Phase 5: Rewrite handoff-schema.md to document both accepted forms [COMPLETED]

**Goal**: `docs/architecture/handoff-schema.md` stops contradicting itself. It documents both
continuation-pointer forms, states which writer emits which, and its examples show shapes a live
writer would actually produce.

**Tasks**:
- [x] Add a new **"Two Accepted Forms"** subsection under the continuation field documentation,
      stating: flat top-level `continuation_path` (string) is what live H9 wrap-up writers emit and
      is the hard-mode canonical form per `context/contracts/wrap-up.md`; nested
      `continuation_context` (object with `handoff_path` + `orchestrator_mode`) is the documented
      form, written today only by the unreferenced `skill_write_orchestrator_handoff`; **both are
      accepted by every reader and by `validate-handoff.sh`**. State that the two must not be
      re-narrowed to one without changing every reader in lockstep. *(completed)*
- [x] Rewrite the `## Complete JSON Schema` block so `continuation_path` appears as a documented
      top-level optional field alongside `continuation_context`. Today `continuation_path` does not
      appear anywhere in this document. *(completed)*
- [x] Add a `### continuation_path (optional, present when status = "partial")` field definition
      mirroring the existing `### continuation_context` one; cross-reference the two. *(completed)*
- [x] Correct the `### Handoff Writers` table: it names `general-implementation-hard-agent.md` H9
      Stage 5 as the only active writer while the schema above documents a form that writer never
      emits. Add a column (or per-row note) recording **which form** each listed writer emits, and
      mark `skill_write_orchestrator_handoff` as defined-but-unreferenced consistently with the
      Phase 4 comment. *(completed)*
- [x] Update `### When to Write \`continuation_context\`` to cover both forms (retitle as needed).
      *(completed: retitled "When to Write a Continuation Pointer")*
- [x] Update `### \`orchestrator_mode\` Flag in Continuation Context` to explain that a flat
      `continuation_path` carries no `orchestrator_mode`, and that the reader supplies
      `orchestrator_mode: true` during normalization (matching Phase 3's dispatch-context work).
      *(completed)*
- [x] Rewrite the `### Partial with Continuation` example under `## Example Handoff Objects` to
      show the **flat** form a live writer actually produces, and add a second example showing the
      nested form, labelled with its writer. *(completed)*
- [x] Update the `## Reading Contract` section so its guidance reflects dual-form resolution.
      *(completed)*
- [x] Sanity-check `## Relationship to Continuation Handoffs` for any claim invalidated by the
      above. *(completed: the ASCII diagram named a writer inconsistent with the corrected Handoff
      Writers table — general-implementation-hard-agent's H9 wrap-up, not base-mode
      skill-implementer — and used the nested field only; rewritten to name the actual active
      writer, the flat field, and the reader's normalization step)*

**Timing**: 1.5 hours

**Depends on**: 3, 4

**Verification Tier**: prose

**Scope Hypothesis**: *Eight sections of `handoff-schema.md` require edits (Complete JSON Schema,
a new `continuation_path` field definition, `continuation_context` field definition, Handoff
Writers table, When to Write, orchestrator_mode Flag, Partial with Continuation example, Reading
Contract), plus the new Two Accepted Forms subsection.* Confirm at implementation time with
`grep -n "continuation" agent-system/extensions/core/docs/architecture/handoff-schema.md`, checking
every hit is either updated or consciously left alone — the count is a hypothesis, not a budget.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - rewrite of the
  continuation-pointer contract across the sections enumerated above

**Verification**:
- Diff read-through confirming every changed hunk is prose/markdown/JSON-example text with no
  executable surface.
- Cross-check each of the document's continuation examples against the actual field the named
  writer emits (read `context/contracts/wrap-up.md` and
  `agents/general-implementation-hard-agent.md` Stage 5 to confirm).
- Every internal cross-reference named in the new text resolves to a real file/section.
- No task-number citations anywhere in the file.

---

### Phase 6: Full-gate consistency sweep [COMPLETED]

**Goal**: One pass confirming the fix is coherent across script, both engines, docs, and validator,
with no stray deploy-tree edits, no disturbed sibling work, and no leaked task references.

**Tasks**:
- [x] Run the full regression suite green:
      `bash agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh`.
      *(completed: 9 passed, 0 failed, exit 0)*
- [x] Run the two sibling suites in `scripts/tests/` to confirm no collateral damage. *(completed:
      test-census-count.sh 8/8, test-validate-no-task-references.sh 21/21, both exit 0)*
- [x] `bash -n` every modified shell file. *(completed: all 3 clean)*
- [x] `jq . agent-system/extensions/core/manifest.json`. *(completed: parses)*
- [x] Residual-nested-only sweep:
      `grep -rn "continuation_context" agent-system/extensions/core --include=*.sh --include=*.md`
      and confirm every remaining read site either resolves both forms or is a writer/doc reference
      that intentionally names one form. *(completed: full grep reviewed; found one additional
      residual — `docs/architecture/orchestrate-state-machine.md`'s state table row, Context
      Flatness Guarantee code snippet, and Partial Recovery Flow example were nested-only/stale,
      a companion doc not in this plan's original file list but describing the same rule fixed
      elsewhere; updated for consistency rather than left as a third silently-diverging copy.
      All other hits are writers, the fixed reader sites, or doc references correctly naming one
      or both forms) (deviation: altered — updated orchestrate-state-machine.md, a file outside
      this plan's originally enumerated file lists, for dual-form consistency; see progress file
      phase-6 deviations)*
- [x] Cross-engine agreement check: for each of Phase 1's Fixtures A–D, confirm the classifier
      verdict, base SKILL.md's hand-applied rule, and hard SKILL.md's rule all agree. *(completed:
      all three jq expressions run directly against all 4 fixtures, identical verdicts)*
- [x] `validate-handoff.sh` against Fixtures A and B to confirm the validator's pre-existing dual
      acceptance still holds and has not been contradicted by the doc rewrite. *(completed: both
      pass with 10 PASS / 1 WARN (optional sorry_inventory field) / 0 FAIL, exit 0)*
- [x] **Source-store boundary check**: `git status --short -- .claude/` shows no modified tracked
      file. Every edit in this plan must be rooted at `agent-system/extensions/**`. *(completed:
      empty output)*
- [x] **Sibling-work check**: `grep -c "OFF-SCHEMA DISPATCH STATUS"` in both SKILL.md files matches
      pre-task values; `grep -n "dispatch_status" ` shows the three-tier validation intact.
      *(completed: base=2, hard=1, unchanged; diff shows zero touched dispatch_status/OFF-SCHEMA
      lines)*
- [x] **No-task-references check**: `git diff` over all changed files contains no `task N` /
      `tasks N-M` / `(task N)` citation patterns (all changed files are outside `specs/**`).
      *(completed: grep over the full accumulated diff since before this task's plan commit
      found zero matches)*
- [x] Re-read the definition of done and confirm each clause is demonstrably met: a
      standard-writer-path handoff with a populated continuation classifies as a continuation;
      `handoff-schema.md` matches actual writer and classifier behavior; a regression test covers
      the case and was proven RED pre-fix. *(completed: all three clauses demonstrably met — see
      Phase 1's recorded RED and Phase 2's recorded GREEN)*

**Timing**: 30 minutes

**Depends on**: 5

**Verification Tier**: full

**Files to modify**:
- None (verification-only phase; any defect found routes back to its owning phase)

**Verification**:
- All checks above pass. The complete gate set for this repository runs clean.

---

## Testing & Validation

- [x] `test-orchestrate-triage-classify.sh` observed **RED** on Fixture A against the pre-fix
      predicate (mutation check, Phase 1) — a test passing both before and after does not count.
- [x] Same suite **GREEN** on all fixtures after Phase 2.
- [x] Fixture C (both forms null) still classifies `"empty"` — the relaxation did not over-relax.
- [x] Fixture D confirms continuation-over-blockers precedence is preserved.
- [x] Base and hard SKILL.md hand-applied rules agree with the script on all four fixtures.
- [x] `orchestrate-dry-run-report.sh` inherits the corrected verdicts with no edit.
- [x] `validate-handoff.sh` accepts both fixture forms (pre-existing behavior, unregressed).
- [x] `bash -n` clean on all modified shell files; `jq .` clean on `manifest.json`.
- [x] No modified tracked files under `.claude/`.
- [x] Sibling `dispatch_status` three-tier validation intact in both SKILL.md files.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` (new)
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` (dual-form predicate)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (mirrored predicate +
  dispatch-context normalization)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (reader symmetry)
- `agent-system/extensions/core/scripts/skill-base.sh` (comment-only dead-function disposition)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (rewritten continuation
  contract)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (Phase 6
  addition, not in the original plan: dual-form consistency fix for the same rule, found stale
  during the residual-nested-only sweep — see Phase 6's deviation note)
- `agent-system/extensions/core/manifest.json` (test registration)

**Named follow-up for harvest (NOT implemented here)**: give
`agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` Stage 5 a
`continuation_path` key plus the populate-on-partial/blocked instruction that the core and lean
hard-mode agents already carry. Without it, cslib hard-mode partials populate no continuation
pointer of any form, independent of this task's reader fix.

## Rollback/Contingency

Every phase is an independent, revertable commit against files that are all plain text under
`agent-system/extensions/**`; no state, schema, or generated artifact is migrated.

- **Phase 2 regression** (classifier over-relaxes, or a dependent breaks): revert that single
  commit. The predicate returns to nested-only; the suite goes RED on Fixture A again, which is the
  documented pre-fix state — not a corrupted one.
- **Phase 3 regression** (successor dispatch receives a malformed normalized object): revert Phase
  3 alone. Phase 2's classifier fix stands on its own — the task routes to implement correctly, it
  just falls back to the coarser `.return-meta.json` resume probe as it does today.
- **Phase 4/5**: comment- and doc-only; reverting is textual with zero behavioral effect.
- **Phase 1**: the suite is additive. If the sandbox shape proves unworkable and no justified
  override is acceptable, stop and escalate rather than landing the fix untested — a predicate
  change without a proven-RED regression test does not satisfy the definition of done.

If the co-editing sibling's changes conflict at implementation time, do **not** resolve by
overwriting: re-read the current file state, re-anchor on symbol names, and re-apply the minimal
edit.

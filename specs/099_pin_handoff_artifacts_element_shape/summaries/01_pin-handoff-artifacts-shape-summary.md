# Implementation Summary: pin_handoff_artifacts_element_shape

- **Task**: 99 - Make the `.orchestrator-handoff.json` `artifacts[]` element shape unambiguous
- **Status**: [COMPLETED]
- **Started**: 2026-08-24
- **Completed**: 2026-08-24
- **Effort**: ~3 hours
- **Dependencies**: None
- **Artifacts**: plans/01_pin-handoff-artifacts-shape.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Pinned the `.orchestrator-handoff.json` `artifacts[]` element shape normatively in exactly one
place (`handoff-schema.md`'s `### artifacts (required)` section) and propagated it by reference,
never by restatement, into every agent contract that can write the file — including the two lean
research agents that previously had zero mention of `.orchestrator-handoff.json` at all, the acute
reproducing gap that motivated this task. `validate-handoff.sh` now type-checks `.artifacts[0]`
before indexing into it and FAILs with a message naming the index and observed type instead of
degrading silently. `.return-meta.json`'s already-correct `artifacts` guidance was not touched.

## What Changed

- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — added an explicit
  never-a-bare-string statement to `### artifacts (required)`; added a Defensive-case
  cross-reference, a non-deciding note recording the observed research-agent-as-writer
  contradiction, and a no-consumer-side-tolerance-exists-today note to "Handoff Writers".
- `agent-system/extensions/core/context/formats/return-metadata-file.md` — added a
  cross-reference paragraph disambiguating `.return-meta.json`'s `artifacts` shape (summary
  required) from `.orchestrator-handoff.json`'s parallel-but-not-identical shape (summary
  optional).
- `agent-system/extensions/lean/agents/lean-research-agent.md` — added a new
  `.orchestrator-handoff.json (research is a non-writer by design)` section with a Defensive
  case paragraph, modeled on `general-implementation-agent.md`'s pattern.
- `agent-system/extensions/lean/agents/lean-research-hard-agent.md` — added the identical
  section after Stage 7, before Stage 8.
- `agent-system/extensions/core/agents/general-research-agent.md` — extended the existing
  Stage 3.6 Defensive-case paragraph with an artifacts-shape reference sentence.
- `agent-system/extensions/core/agents/general-research-hard-agent.md` — same addition
  (folded in per plan decision).
- `agent-system/extensions/core/agents/general-implementation-agent.md` — same addition to its
  "Defensive case, if a handoff is written anyway" paragraph (folded in per plan decision).
- `agent-system/extensions/core/context/contracts/wrap-up.md` — extended the H9 `artifacts`
  field-semantics bullet with the explicit bare-string prohibition, referencing
  `handoff-schema.md` (folded in per plan decision).
- `agent-system/extensions/core/scripts/validate-handoff.sh` — Check 2c now probes
  `.artifacts[0] | type` before extracting per-field values; a non-object element FAILs with a
  message naming the index (`0`) and the observed type, and skips the per-field extraction so the
  generic "missing required field(s)" message never masks the real shape defect. The
  log-only/non-gating invocation posture in `skill-base.sh` was left unchanged, as decided.

## Decisions

- **Element shape settled as**: object `{type, path[, summary]}`, `type`/`path` required,
  `summary` optional — matching the existing `orchestrator-handoff-schema.json` exactly. No new
  schema file or template fragment introduced.
- **Scope Decisions table (from the plan), all four followed as decided**:
  - `general-research-hard-agent.md` + `general-implementation-agent.md` — **FOLD IN** (Phase 4).
    Done.
  - `wrap-up.md` H9 prose — **FOLD IN** (Phase 5). Done.
  - `validate-handoff.sh` Check 2c type-check — **FOLD IN** (Phase 6). Done.
  - Shared loud-normalize-and-record consumer-side helper — **DEFERRED**. See Follow-ups.
- **ACCEPTANCE clause resolution**: the plan's "dual-shape tolerance is either removed or
  deliberately retained with a recorded reason" clause does not apply as written, because no such
  consumer-side tolerance exists for `.orchestrator-handoff.json` today — both
  `skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md` read
  `jq -r '.artifacts[0].path // ""'` unguarded. This finding is now recorded explicitly in
  `handoff-schema.md`'s "Handoff Writers" section so a future reader does not search for
  tolerance that was never implemented. Nothing was added or removed; the finding is recorded.
- **Surfaced maintainer contradiction** (not resolved by this plan, by design): a live research
  dispatch for this very task supplied a base-mode `general-research-agent` with `handoff_path`
  and an instruction to write `.orchestrator-handoff.json`, contradicting
  `handoff-schema.md`'s categorical "research agents never write a handoff at all, in any mode"
  claim. `handoff-schema.md`'s "Handoff Writers" section now records this as a named open
  question, not a decision, with two candidate resolutions: (a) stop instructing research agents
  to write the file, restoring the documented invariant, or (b) expand the documented writer set
  to match observed practice. This is left for a maintainer to decide.
- **Scope-hypothesis divergence recorded (Phase 4)**: the plan's Phase 4 scope hypothesis assumed
  exactly three contracts carry a "Defensive case" paragraph
  (`general-research-agent.md`, `general-research-hard-agent.md`,
  `general-implementation-agent.md`). A fresh `grep -rln "Defensive case"
  agent-system/extensions/*/agents/*.md` at implementation time found seven matches: the three
  hypothesized files, plus `cslib-implementation-agent.md`, `cslib-research-agent.md` (both
  outside this task's declared 5-file scope and this plan's Scope Decisions table — left
  unedited, not silently folded in), and `lean-research-agent.md` /
  `lean-research-hard-agent.md` (which already carry the equivalent artifacts-shape pinning as
  part of the Phase 3 section this same plan added — no separate edit needed). Only the three
  originally hypothesized core files were edited in Phase 4, per the plan's own instruction to
  "decide per-file whether it is in scope, rather than editing whatever the grep happens to
  return."

## Plan Deviations

- None (implementation followed plan). The Phase 4 scope-hypothesis divergence above is recorded
  as required by the plan's own Scope Hypothesis instruction — it is a documented finding, not a
  deviation from what the plan asked for.

## Verification

- Build: N/A (documentation + one bash script)
- Tests: Passed — `bash -n validate-handoff.sh` passes; validator run against this task's own
  real `.orchestrator-handoff.json` produces the same PASS-with-warnings outcome as before the
  change; a synthetic `"artifacts": ["some/path.md"]` fixture now FAILs with a message naming
  index `0` and type `string`, with no raw jq error; a correct object-element fixture still
  passes Check 2c.
- Lint: `lint-agent-contracts.sh` passed (106 passed, 0 failed, 0 warnings) — Check F confirmed
  every dispatchable agent, including the two lean research agents, carries a correct
  `.return-meta.json` artifacts template.
- Task-reference lint: `check-task-references.sh --quiet` passed with 0 unexempted occurrences
  across all four scanned trees.
- Files verified: Yes — all nine changed files exist and contain the expected additions;
  `orchestrator-handoff-schema.json` is byte-identical to its pre-change state (`git diff --stat`
  empty); no path under `.claude/**` was modified (source-store rule honored throughout).

## Impacts

- Agents writing `.orchestrator-handoff.json` (currently only
  `general-implementation-hard-agent.md`'s H9 wrap-up, plus any future writer that reverses a
  research agent's non-writer scoping decision) now have one unambiguous normative statement to
  point at, reachable from every contract that could plausibly write the file.
- A dispatch that emits a bare-string `artifacts[0]` is now caught by `validate-handoff.sh` with
  an actionable message (index + observed type) instead of a raw jq error or a misleading
  "missing required field" message — though this remains a log-only diagnostic, not a gate, per
  the plan's explicit non-goal.
- `.return-meta.json`'s already-correct, already-strict `artifacts` guidance is untouched; readers
  are now warned the two files' shapes are similar but not interchangeable.

## Follow-ups

- **Deferred (from the plan's Scope Decisions table)**: a shared loud-normalize-and-record helper
  for the two `SKILL.md` consumer call sites (`skill-orchestrate/SKILL.md` and
  `skill-orchestrate-hard/SKILL.md`), analogous to the existing `.return-meta.json`
  `ARTIFACTS_SHAPE_MISMATCH` consumer chokepoint in `skill_read_metadata`
  (`scripts/skill-base.sh`). This is genuinely different work — a new shared helper, defect-record
  wiring, and edits to both orchestrate engines' live state-machine code — and was deliberately
  not implemented here. It is the remaining gap against the "caught with a clear message on the
  consumer side" acceptance criterion; `validate-handoff.sh`'s producer-side check (this task)
  covers the diagnostic, log-only side only.
- **Maintainer decision needed**: reconcile the "research agents never write a handoff" categorical
  claim in `handoff-schema.md`'s "Handoff Writers" section against the observed practice of live
  delegation contexts instructing base-mode research agents to write one (see Decisions above for
  the two candidate resolutions). Not an implementation item — recorded for a human to decide.
- **Out of this task's scope, noted for awareness**: `cslib-implementation-agent.md` and
  `cslib-research-agent.md` also carry "Defensive case" paragraphs (surfaced by the Phase 4
  grep) but were never part of this task's declared file scope or Scope Decisions table; they
  were left unedited rather than silently widened.

## References

- `specs/099_pin_handoff_artifacts_element_shape/plans/01_pin-handoff-artifacts-shape.md`
- `specs/099_pin_handoff_artifacts_element_shape/reports/01_pin-handoff-artifacts-shape.md`

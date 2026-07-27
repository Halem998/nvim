# Implementation Summary: Task #925

**Completed**: 2026-07-27
**Duration**: ~1 hour

## Overview

Authored two new sibling contracts in the source store — `phase-closure.md` (depth-first phase
closure with cheapest-first ordering and a stop-at-boundary rule) and `pre-edit-gate.md`
(proportionate per-item evidence before applying a mechanical-list edit) — and wired both into
all four core implementer files (`general-implementation-agent.md`,
`general-implementation-hard-agent.md`, `skill-implementer/SKILL.md`,
`skill-implementer-hard/SKILL.md`) via explicit `@`/`Path:` reference bullets. Registered both
contracts in `index-entries.json` and recorded the placement/no-central-injection-point findings
in `context-layers.md`.

## What Changed

- `agent-system/extensions/core/context/contracts/phase-closure.md` — new file. Depth-first
  closure contract: close-before-open, cheapest-closure-first ordering, and a distinct
  stop-at-a-closed-phase-boundary clause, plus a verbatim scope-limitation sentence reconciling
  the rule with `plan-format.md`'s wave table and `territory.md`.
- `agent-system/extensions/core/context/contracts/pre-edit-gate.md` — new file. Per-item pre-edit
  verification gate: hypothesis premise (wired to `plan-format.md`'s `Scope Hypothesis` field),
  probe-before-edit rule with three concrete probe shapes, a proportionality/cheapness ceiling,
  failed-probe routing into the existing `Reasoned Exclusions` table, and an orthogonality
  section distinguishing the gate from Verification Tier and Commit Mode.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — added two
  `@`-reference bullets to `## Context References`.
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — added two
  `@`-reference bullets, `(MANDATORY)`-annotated to match the surrounding hard-mode convention.
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` — added two `Path:` bullets.
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` — added two `Path:`
  bullets, `(loaded by agent)`-annotated to match.
- `agent-system/extensions/core/index-entries.json` — added two entries with
  `load_when.agents: ["general-implementation-agent", "general-implementation-hard-agent"]`,
  the first non-hard-exclusive `contracts/*` registrations in the system.
- `agent-system/extensions/core/context/architecture/context-layers.md` — added a "Contracts
  directory: convention vs. load path" subsection recording both required findings.

## Decisions

- Followed the plan's own depth-first-closure rule while implementing it: each phase's checklist
  was fully checked off, its heading advanced, and a scoped git commit made before the next phase
  opened — no phase was left `[PARTIAL]`.
- Within the wave-3 pair (Phases 4 and 5, both blocked only by Phase 3), closed Phase 4
  (25-minute estimate) before Phase 5 (30-minute estimate), per the contract's own
  cheapest-closure-first ordering clause.
- Ran each phase's `**Scope Hypothesis**` probe before editing, per the pre-edit gate this task
  itself authors: Phase 3's four-file `## Context References` count-of-1 probe, and Phase 4's
  system-wide zero-non-hard-`contracts/*`-registrations probe. Both probes confirmed the plan's
  hypotheses exactly; no Reasoned Exclusion was needed for either.
- Phase 5's plan-stated anchor ("its existing 'Where to store new content' decision tree")
  describes text that literally lives in `merge-sources/claudemd.md`, not in `context-layers.md`
  itself. Verified that `context-layers.md` is nonetheless the unambiguous correct target — it is
  the "Full details" link target that `claudemd.md`'s decision tree points to — and proceeded
  without treating this as a probe failure, since the file identity was never in doubt, only the
  anchor's literal wording.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (prose/documentation-only source-store edits, no runtime code paths).
- Tests: N/A.
- Files verified: Yes — every phase's grep/jq verification criteria from the plan re-run and
  confirmed passing in Phase 6's cross-cutting sweep, including the verbatim scoping-sentence
  check, the three-clause presence check, the eight-way referrer sweep, JSON validity, and a
  task-reference hygiene sweep (zero hits) across all eight touched source-store files.

## Notes

- All eight touched files are under `agent-system/extensions/core/`; `git status --short`
  confirms zero paths under `.claude/` from this task's work.
- Per the task's SCOPE BOUNDARY, no extension implementation agents and no orchestrator skills
  (`skill-orchestrate`, `skill-orchestrate-hard`) were touched.
- Deployment (regenerating `.claude/` from the source store) is out of scope for this task per
  its Non-Goals; the two new contracts and the four referrer-file edits are inert in the deployed
  `.claude/` tree until the next sync/deploy operation picks them up.

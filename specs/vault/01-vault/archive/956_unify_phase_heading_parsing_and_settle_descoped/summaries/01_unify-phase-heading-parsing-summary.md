# Implementation Summary: Task #956

- **Task**: 956 - Unify phase-heading parsing across all sites and settle the [DESCOPED] outcome
- **Status**: [COMPLETED]
- **Started**: 2026-07-29T00:00:00Z
- **Completed**: 2026-07-29T05:00:00Z
- **Effort**: ~5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_unify-phase-heading-parsing.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Introduced `scripts/lib/phase-heading-patterns.sh` as the single sourced anchor for the canonical
`### Phase N: {name} [STATUS]` grammar, the closed six-value status-marker enum, and a shared
non-conforming-heading detector, then migrated every one of the ~19 previously-independent
phase-heading regex sites across eleven files onto it. Settled two open vocabulary questions as
Recorded Decisions in the plan: letter-suffixed sub-phases (`3a`) stay unsupported, with
non-conformance now made loud and named rather than silently mis-parsed (D1); `[DESCOPED]` is
rejected in favor of `[COMPLETED WITH EXCLUSIONS]`, whose five-condition admission test already
covers the whole-phase case (D2). All ten plan phases completed and are committed.

## What Changed

- `agent-system/extensions/core/scripts/lib/phase-heading-patterns.sh` — new; the shared anchor.
  Exports the canonical ERE/BRE grammar forms, the closed six-value `PHASE_STATUS_ENUM`, DONE/OPEN
  alternations, `extract_phase_number`, `nonconforming_phase_headings`, `warn_nonconforming`, and
  `has_nonconforming_phase_headings` (added mid-implementation to close a `pipefail`/SIGPIPE race
  — see Decisions).
- `agent-system/extensions/core/scripts/tests/test-phase-heading-patterns.sh` — new; 35-assertion
  fixture suite covering every exported constant and function, including an equivalence check
  between the ERE and BRE forms and a live reproduction of the SIGPIPE race the new helper fixes.
- `agent-system/extensions/core/scripts/update-task-status.sh` — migrated `count_plan_phases()`
  from inline BRE to the library's ERE forms; added a loud, distinguishable INCONCLUSIVE branch
  for non-conforming headings (closing the `[DESCOPED]` TOTAL-inflation defect); migrated the
  `first_phase` auto-advance extraction; new exit code 5 for a missing library.
- `agent-system/extensions/core/scripts/validate-artifact.sh` — migrated the phase-presence check,
  phase-line enumeration, and phase-number extraction (fixing the reporting collapse where
  `3a`/`3b`/`3c` all reported as one number); added an advisory-default/`--strict`-error
  marker-enum and number-token check.
- `agent-system/extensions/core/scripts/update-phase-status.sh` — added caller-supplied
  `phase_number` argument validation against the library's bare-token grammar; migrated the
  lookup grep onto the library's `PHASE_HEADING_PREFIX`.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
  `skill-orchestrate-hard/SKILL.md` — migrated all `recovered_total`/`recovered_completed` pairs
  and the hard-mode `next_phase` resume-scan onto the library; fixed the DONE-alternation drift so
  `[COMPLETED WITH EXCLUSIONS]` counts as closed in recovery paths.
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md`,
  `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` — migrated
  resume-scan `next_phase` sites; the lean site gained decimal sub-phase support it never had and
  dropped its non-portable `grep -P` extraction.
- `agent-system/extensions/core/agents/general-implementation-agent.md`,
  `general-implementation-hard-agent.md` — migrated the Stage 5a marker-repair block's four regex
  fragments; the two blocks remain textually parallel except one intentional label difference.
- `agent-system/extensions/core/commands/task.md` — migrated `/task --review` Step 3's
  phase-enumeration grep; confirmed the phase-categorization list already matched the six-value
  enum exactly.
- `agent-system/extensions/core/context/formats/plan-format.md`,
  `context/standards/status-markers.md`, `rules/plan-format-enforcement.md`,
  `rules/artifact-formats.md` — ratified D1/D2 in place; replaced the hand-maintained "Consumer
  sites" prose list with the live `grep -rl 'phase-heading-patterns.sh'` mechanism.
- `agent-system/extensions/core/manifest.json` — registered the new library and test script.
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — fixed a basename-matching gap
  in its cross-extension-reference check (see Decisions).

## Decisions

- **D1** (plan Recorded Decisions): letter-suffixed sub-phases stay unsupported; the general fix
  for the observed `3a` silent-undercount defect is loud, named non-conformance detection at every
  accounting site, not a widened grammar — widening fixes exactly one token shape and leaves the
  defect class (e.g. `3-alt`, `III`) intact.
- **D2** (plan Recorded Decisions): `[DESCOPED]` is rejected; whole-phase descoping uses
  `[COMPLETED WITH EXCLUSIONS]` with a full `#### Reasoned Exclusions` record, since that
  outcome's five-condition admission test already covers "all remaining items" identically to a
  subset.
- **D3** (plan Recorded Decisions): non-conformance is inconclusive-and-loud (the same
  pass-through branch as "zero conforming headings"), never a hard refusal — refusing would
  regress every plan authored before this contract existed.
- Added `has_nonconforming_phase_headings` to the library mid-implementation (Phase 4): the
  originally-planned `nonconforming_phase_headings <file> | grep -q .` idiom is racy under
  `set -o pipefail` — `grep -q` exits after its first match and closes the pipe; if the producer
  is still writing (realistic here, since each loop iteration runs several greps), the producer
  receives SIGPIPE and the pipeline's exit status becomes the producer's signal-exit code rather
  than reliably reflecting output presence. Retrofitted across every already-committed call site.
- Fixed a genuine, previously-latent `check-extension-docs.sh` bug (Phase 10): its
  cross-extension-reference check compares a bare filename extracted from prose against
  `provides.scripts` entries verbatim, never stripping a subdirectory prefix (`lib/...`,
  `tests/...`). No `lib/`-scoped script had ever been referenced by bare name in prose before this
  task. Fixed with basename-normalized fallback exclusion sets.

## Plan Deviations

- **Task 4.5** (has_nonconforming_phase_headings): altered — the boolean non-conforming-heading
  check call form was changed from a `grep -q` pipe to a dedicated library function after
  discovering the pipefail/SIGPIPE race described above; retrofitted across Phases 7-9's
  already-committed files.
- **Task 6.3** (library gap): altered — added `PHASE_NUMBER_TOKEN_ERE` and `PHASE_HEADING_PREFIX`
  exports to the library (with fixture coverage) rather than composing them locally in
  `update-phase-status.sh`, per Phase 2's own Scope Hypothesis obligation to extend the library
  when a consumer needs an export it does not yet provide.
- **Task 10.4** (check-extension-docs.sh): altered — added a basename-matching fallback to a
  gate script not in the plan's original file list, because this task's own doc references were
  what first triggered the bug, and Phase 10's own verification requires every gate to exit 0.

## Verification

- Build: N/A (no compiled artifacts)
- Tests: Passed — `scripts/tests/test-phase-heading-patterns.sh` 35/35; deliberate-breakage check
  confirmed the assertions are live, not vacuous
- Files verified: Yes — all `bash -n` clean; `check-task-references.sh` over
  `agent-system/extensions` exits 0; `manifest.json` parses; `check-extension-docs.sh` exits 0
  except 2 pre-existing, unrelated `literature`-extension `.pyc`-cache-file findings

## Impacts

- Every phase-heading accounting site in the repository now shares one grammar, one enum, and one
  non-conformance detector; a future grammar change touches one file instead of ~19.
- A non-conforming heading (letter suffix, extra decimal level, or unrecognized marker) is now
  named and loud at every site instead of silently under-counting, over-counting, or
  mis-attributing — closing both defects the triggering research report identified.
- `check-extension-docs.sh`'s cross-extension-reference check is now correct for any future
  subdirectory-scoped script referenced by bare name in prose, not just this task's library.

## Follow-ups

- None. The one known, deliberately out-of-scope item (the extension-loader's own
  brand-new-`scripts/<subdir>/*.sh`-file propagation gap) is unchanged and remains documented in
  `rules/source-store-deploy-boundary.md`; this task worked around it for this repo's deploy via a
  direct file copy, per the plan's own Phase 10 instruction, and did not attempt a subsystem fix.

## References

- `specs/956_unify_phase_heading_parsing_and_settle_descoped/plans/01_unify-phase-heading-parsing.md`
- `specs/956_unify_phase_heading_parsing_and_settle_descoped/reports/01_unify-phase-heading-parsing.md`
- `specs/956_unify_phase_heading_parsing_and_settle_descoped/progress/phase-{1..10}-progress.json`

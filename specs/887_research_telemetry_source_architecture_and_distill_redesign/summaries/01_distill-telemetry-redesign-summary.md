# Implementation Summary: Task #887

**Completed**: 2026-07-28
**Duration**: 12 phases across one implementation session

## Overview

Implemented the full plan at `plans/01_distill-telemetry-redesign.md`: settled the OTel <->
`events.jsonl` seam with a new `cc_session_id` join key, split the 2,941-line
`skill-memory/SKILL.md` into `skill-learn` and `skill-distill`, restructured `skill-distill`
around a shared sub-mode skeleton, and specified/landed five new or redefined telemetry-sourced
sub-modes (`--revise`, `--meta`, `--review`, `--learn`, `--dream`), growing `/distill` from 7 to
12 sub-modes. All 12 plan phases are `[COMPLETED]`; final validation (Phase 12) passed every
check, including a live extension-deploy verification that surfaced and fixed a real stale-deploy
defect.

## What Changed

- `agent-system/extensions/core/context/schemas/events-schema.json` -- added nullable
  `cc_session_id` property
- `agent-system/extensions/core/scripts/events-append.sh` -- added `--cc-session-id` flag
  mirroring `--cwd`
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh` -- captures and threads
  `cc_session_id`; corrected a stale header comment
- `agent-system/extensions/core/hooks/events-log-artifact.sh` -- captures and threads
  `cc_session_id`
- `agent-system/extensions/core/context/formats/events-format.md` -- new "Claude Code OTel
  Correlation" section, field table row, updated example lines
- `agent-system/extensions/memory/context/project/memory/telemetry-guardrails.md` -- new file:
  four-tier source model, evaluator-outside-the-loop rule, six failure modes, `gen_ai.*`
  borrowing rule, cross-repo invocation discipline
- `agent-system/extensions/memory/skills/skill-learn/SKILL.md` -- new, split from
  `skill-memory/SKILL.md`'s pre-`## Mode: distill` content
- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` -- new, split from the
  post-boundary content; restructured with a `## Shared Sub-Mode Skeleton`, `purge`/`gc` moved
  adjacent, and five new sub-mode sections added (`revise`, `meta`, `review`, `learn`,
  redefined `dream`)
- `agent-system/extensions/memory/skills/skill-memory/` -- removed
- `agent-system/extensions/memory/manifest.json` -- `provides.skills` and `routing` repointed
- `agent-system/extensions/memory/commands/learn.md`, `commands/distill.md` -- delegation
  references repointed; `distill.md` rewritten for 12-sub-mode dispatch
- `agent-system/extensions/memory/index-entries.json` -- skill assignments repointed, stale
  `line_count` values corrected, new `telemetry-guardrails.md` entry
- `agent-system/extensions/memory/EXTENSION.md`, `README.md` -- skill-mapping/command tables and
  lifecycle description updated
- `agent-system/extensions/memory/context/project/memory/distill-usage.md` -- rewritten to
  document all 12 sub-modes
- `agent-system/extensions/email/context/project/email/design/email-to-memory-preferences.md`,
  `agent-system/extensions/email/skills/skill-email-cleanup/SKILL.md` -- all `skill-memory`
  cross-references repointed to `skill-learn`/`skill-distill` by section name

## Decisions

- `cc_session_id` is the only genuinely new seam field; `cwd` was already fully implemented
  (a plan-time correction preserved from the Overview).
- `--revise` and `--meta` were built by substantially reusing the prior `dream` sub-mode's
  Event Ingestion/Correlation/Classification/Gate content and Improvement Proposals content
  respectively, in substance unchanged, per the plan's explicit design decision.
- The redefined `--dream` now sources from `history.jsonl` exclusively and carries no
  event-correlation machinery; it ended up in its correct final ordering slot by construction
  (each of Phases 6-9 inserted immediately before it), requiring no physical move in Phase 10.
- Each of `--revise`/`--meta`/`--learn` gets its own dedicated log file
  (`revise-log.json`/`meta-log.json`/`learn-harvest-log.json`) rather than overloading the
  general `distill-log.json`'s closed `type` enum.
- `meta-builder-agent`'s documented extension-detection limitation (defaults to `core`, needs
  human correction for extension-scoped proposals) was honestly encoded into `--meta` rather
  than assuming full automatic detection exists.

## Plan Deviations

- **Phase 3, 7, 11 Scope Hypothesis counts**: several file/reference counts (commands/*.md
  occurrences, email-extension `skill-memory` occurrences) differed from the plan's estimates;
  actuals were used and the discrepancies recorded inline in the plan.
- **Phase 5 reduction depth**: the "reduce to deltas" task was scoped to boilerplate
  consolidation (MANDATORY-STOP phrasing, skeleton-reference pointers) rather than a deeper
  rewrite of genuinely sub-mode-specific execution logic, per the phase's own allowance to leave
  divergent content stated in full.
- **Phase 10 State Integration fix**: corrected the `dream` column of the shared State
  Integration table (no longer increments `distill_count`, since the redefined dream doesn't
  mutate memory files) -- necessary fallout from the redefinition, not separate scope.
- **Phase 11 beyond-list fixes**: discovered and fixed a broken cross-reference
  (`skill-learn/SKILL.md`'s "Tombstone Application below"), 12 inherited task-number citations,
  a duplicate dispatch-table row, and a stale distill-log `type` enum -- all within files this
  task modified and all necessary for Phase 12's grep gate to pass.
- **Phase 12 deploy defect**: `deploy-headless.sh` only refreshes the core tree; the
  already-loaded `memory` extension's skill directories were stale post-deploy. Fixed via a
  headless `reload("memory")` call using the same extension-manager API the interactive picker
  uses.

## Verification

- Build: N/A (documentation/skill-specification task; no compiled build step)
- Tests: All Phase 12 validation checks passed -- schema validation (3 cases), events-append.sh
  flag behavior, events-query.sh tolerance, `.claude/` write-target grep (clean), task-number
  citation grep (clean within scope), `validate-artifact.sh` (PASS), extension redeploy
  (PASS after fix), six-failure-mode walk (5/5 PASS, one honestly-flagged residual risk for
  `--review`'s optional logging)
- Files verified: Yes -- line-count reconciliation exact at every split/reorder step, all
  JSON files `jq`-valid, all code fences balanced

## Notes

- The `--review` sub-mode's Log Entry is intentionally optional (read-only, no vault mutation to
  protect); a `--review` run can complete with zero durable audit trail. This is an accepted
  design trade-off, recorded in the Phase 12 six-failure-mode walk rather than silently passed.
- Numerous pre-existing, unrelated task-number citations remain in the email extension's own
  domain docs (`task 821/822/823/824/827`, `.dotfiles task 72/80`) -- a distinct, larger,
  out-of-scope cleanup for that extension, not touched by this task beyond its
  `skill-memory` cross-references.
- The five new sub-mode specifications are written to a level `/expand` can turn into standalone
  implementation tasks, per the plan's stated Goal.

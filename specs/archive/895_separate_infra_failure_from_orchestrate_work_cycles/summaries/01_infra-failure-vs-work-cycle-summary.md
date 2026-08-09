# Implementation Summary: Task #895

**Completed**: 2026-07-25
**Duration**: ~1.5 hours (single continuous session)

## Overview

`/orchestrate` previously treated any missing `.orchestrator-handoff.json` as a consumed work
cycle, even when the Agent tool call itself died at the transport/API layer before the subagent
ever ran. This implementation adds a corroborated two-signal discrimination rule — a narrated
orchestrator judgment about the Agent tool call's own outcome, AND a mechanical
`.return-meta.json` mtime check against the dispatch window — that routes a genuinely
corroborated infrastructure failure to a separate, capped counter (`infra_failures`,
`MAX_INFRA_FAILURES=3`) instead of `cycle_count`. The fix was applied to both manifestations of
the defect: single-task Stage 5 in both orchestrator variants, and the strictly worse
multi-task Stage MT-4, which previously marked a task `failed_tasks` outright with no retry at
all. All six plan phases completed in dependency order (Phase 2's counter plumbing and Stage 7
terminal bound landed before Phase 3's exemption branch, per the plan's explicit ordering
requirement).

## What Changed

- `agent-system/extensions/core/context/patterns/infra-failure-discrimination.md` — New shared
  pattern doc: the two-signal rule, the `MAX_INFRA_FAILURES` cap and its `burnout_signals`-shape
  imitation/divergence, the `MAX_CYCLES + MAX_INFRA_FAILURES` worst-case bound, the terminal
  condition, and the fail-safe defaults with an explicit "do not weaken the AND" warning.
- `agent-system/extensions/core/index-entries.json` — Registered the new pattern doc entry
  (`patterns/infra-failure-discrimination.md`).
- `agent-system/extensions/core/context/patterns/mcp-tool-recovery.md` — Added a cross-link to
  the new doc noting it covers Agent/Task-tool transport-layer failures (a different surface
  than MCP tool call failures).
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 2: `MAX_INFRA_FAILURES=3`
  declaration and `infra_failures` read/init/persist in all three loop-guard init paths
  (resume, fresh, lost-race). Stage 4: dispatch-window capture (`dispatch_start_ts`,
  `dispatch_was_transport_error`) plus narrated-judgment instructions at all four state-handler
  dispatch sites (`not_started`, `researched`, `planned`/`implementing`, `partial` continuation).
  Stage 5: two-signal discrimination branch replacing the unconditional missing-handoff charge;
  `cycle_count` increment now conditional on `infra_exempt_cycle`. Stage 7: `infra_failures`
  added to the loop-guard persist write, plus a `MAX_INFRA_FAILURES` terminal condition with a
  distinct exit message, inserted before the existing `MAX_CYCLES` check. Stage MT-1: schema
  additions (`MAX_INFRA_FAILURES`, `infra_failures: {}` map, `dispatch_start_ts: {}` map).
  Stage MT-4: dispatch-window recording at all three per-task dispatch groups, a narrated
  per-task transport-judgment paragraph, and a per-task discrimination branch replacing the
  unconditional `If missing: mark task in failed_tasks, skip.` — a corroborated infra failure now
  defers the task (up to `MAX_INFRA_FAILURES` times) instead of failing it immediately.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — The same Stage 2/4/5/7
  changes applied to the hard-mode variant, matching `burnout_signals_this_session`'s
  declaration/persistence shape, with `[hard-orchestrate]` log prefixes. Multi-task mode needed
  no hard-mode edit: verified its "Multi-Task Mode" section still delegates unmodified to base
  MT-1..MT-5, so the base-file fix already covers `/orchestrate --hard` multi-task runs.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — Added
  `MAX_INFRA_FAILURES` to the loop-guard schema example and enforcement section, a new state
  table row for `partial (infra cap)`, a new "Infra-Failure vs. Work-Cycle Discrimination"
  subsection linking the pattern doc, and a per-task infra-cap note in the multi-task exit
  conditions section.
- `agent-system/extensions/core/commands/orchestrate.md` — Added the infra-cap termination
  reason to the Constraints list and the Error Handling section, kept to one line each per the
  plan's user-facing-doc guidance.

`agent-system/extensions/core/docs/architecture/architecture-spec.md` was checked but not
modified: it defers to `orchestrate-state-machine.md` for the loop-guard schema rather than
enumerating fields itself, so the plan's conditional edit did not apply.

## Decisions

- Followed the plan's exact replacement text for all 16 edit sites rather than re-deriving the
  discrimination logic, per the delegation instructions.
- Preserved the `AND` (never weakened to `OR` or a fallthrough) at every discrimination site in
  both variants: either signal alone defaults to charging a genuine work cycle.
- Site 1 (`not_started`) in the hard-mode file has its `Agent tool:` pseudo-block inside a plain
  (non-`bash`-tagged) fence, unlike sites 2-4 which sit inside real `bash` fences. Followed the
  plan's "insert inside the same fence, not a new one" instruction literally for all four sites
  rather than forcing a `bash`-tagged fence at site 1.
- Confirmed (rather than edited) two Phase 5 items that were already correct: the "Multi-Task
  Mode" delegation text is unchanged (no stop condition hit), and Stage 3b's loop-guard `jq`
  write uses field assignment and therefore already preserves `infra_failures` without a
  Stage 3b-specific change.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (markdown/prose-plus-bash source files, no compiled artifact)
- Tests: N/A (no executable test harness for SKILL.md prose-plus-bash; validation is structural,
  per the plan's "Testing & Validation" section)
- Files verified: Yes — all Testing & Validation checklist items passed:
  - `bash -n` on every extracted fenced bash block edited in Phases 2, 3, 5 (base Stage 2 and
    Stage 5; hard-mode Stage 2 and Stage 5) — all balanced, no syntax errors.
  - `jq empty` passes on `agent-system/extensions/core/index-entries.json`.
  - Dispatch-site parity: `dispatch_start_ts=`/`dispatch_start_ts` count is 4 per-cycle dispatch
    sites in each SKILL.md (base and hard), plus the base file's MT-1 schema field and 3 MT-4
    per-task-group occurrences, and the base file's mechanical `window_start=$(jq ...
    .dispatch_start_ts[$t] ...)` read in MT-4 step 1.
  - The literal string `# Increment cycle and continue` appears in neither SKILL.md (both
    replaced by the discrimination branch).
  - Bound trace (by hand): all-infra-failure invocation terminates after exactly
    `MAX_INFRA_FAILURES` iterations (3 base, 3 hard — the cap is identical/flat in both); an
    all-genuine-cycle invocation terminates after exactly `MAX_CYCLES` iterations (5 base, 13
    hard); a mixed invocation terminates after at most `MAX_CYCLES + MAX_INFRA_FAILURES` (8 base,
    16 hard), since every iteration charges exactly one of the two independently-capped counters.
  - Conservative-default trace (by hand): a missing handoff with `dispatch_was_transport_error`
    unset (`${dispatch_was_transport_error:-false}` defaults to `false`) charges a cycle even if
    `meta_touched` happens to be `false`, because the `AND` requires both. A missing handoff with
    `dispatch_was_transport_error=true` but a freshly-written `.return-meta.json`
    (`meta_mtime >= window_start`, so `meta_touched=true`) also charges a cycle, because the
    mechanical signal disagrees.
  - No path under `.claude/` modified: confirmed via `git status --short` / `git diff --name-only`
    at Phase 6, and again at the end of this implementation.
  - No new task-number citations outside `specs/**`: confirmed via
    `git diff -- agent-system/ | grep -nE '^\+.*\btasks? [0-9]{2,4}\b'` returning nothing, run
    after every phase and once more at the end.
- Dispatch-site parity audit (Phase 6, recorded per the plan's requirement that an unrecorded
  exclusion is indistinguishable from an omission):
  - **Base** (`skill-orchestrate/SKILL.md`): 4 in-scope Stage 4 sites (state handlers for
    `not_started`, `researched`, `planned`/`implementing`, `partial` continuation) each carry a
    `dispatch_start_ts=` line. 5 occurrences of "Invoke the Agent tool" are intentionally
    excluded: the Stage 5a drift-inspection fork, the Stage 5a reviser-agent fork, and Stage 6's
    steps 2 (research fork), 4 (reviser), and 5 (re-dispatch implement).
  - **Hard mode** (`skill-orchestrate-hard/SKILL.md`): 4 in-scope Stage 4 sites (`not_started`,
    H4 verification re-dispatch, the planner dispatch inside the `adversarial_verified=true`
    branch, the H1 per-phase dispatch) each carry a `dispatch_start_ts=` line. 2 occurrences of
    "Agent tool:" are intentionally excluded: the H5 three-strikes divergence-audit dispatch
    (Stage 4b churn detection) and Stage 6's blocker-escalation research dispatch.

## Notes

- The `validate-context-index.sh` script must run from a deployed `scripts/` tree (`.claude/` or
  `.opencode/`), not the `agent-system/` source store directly (it refuses with a clear error
  when run from the source store, since `../..` would resolve to a bogus repo root there). Ran
  the deployed `.claude/scripts/validate-context-index.sh` copy instead: JSON syntax valid, 155
  entries checked, 0 errors. It reported many pre-existing line-count `WARN`s across unrelated
  files, confirming the deployed `.claude/context/index.json` tree is generally stale relative to
  source (expected, since deployment via the extension picker's "Load Core" is manual and
  user-driven, and is explicitly out of scope for this task per its Non-Goals). This task's own
  new index entry (`patterns/infra-failure-discrimination.md`) exists only in the source store
  (`agent-system/extensions/core/index-entries.json`) and was validated there directly with
  `jq empty` and a `jq -r select(...)` lookup at Phase 1 — both passed.
- Deployment (regenerating `.claude/` via "Load Core") was intentionally not performed, per the
  plan's Non-Goals.

# Implementation Summary: Task #63

- **Task**: 63 - Fix the agent-side hard-mode routing downgrade that discards declared domain agents
- **Status**: [COMPLETED]
- **Started**: 2026-08-17
- **Completed**: 2026-08-17
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_fix-hard-mode-agent-routing.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

`command-route-agent.sh` computed only the `routing_agents_hard` manifest block under
`--hard`, and on a miss discarded the extension's own declared `routing_agents` entry in
favor of the caller's generic hard default — making `--hard` route strictly worse than no
flag for the 14 extensions that declare `routing_agents` without `routing_agents_hard`.
Implemented a three-rung fallback ladder (`routing_agents_hard` -> `routing_agents`,
`via="hard-miss-standard-fallback"` -> `default_agent`) in the consumer script, mirroring
`command-route-skill.sh`'s already-correct standard-then-hard composition. Amended the one
test assertion that pinned the defect as correct and added a fourth case for the genuine
total-miss rung.

## What Changed

- `agent-system/extensions/core/scripts/command-route-agent.sh` — computes the standard
  `routing_agents` lookup unconditionally up front (`_route_std_value`/`_route_std_via`);
  under `effort_flag=hard`, tries `routing_agents_hard` first, falls back to the standard
  value with `via="hard-miss-standard-fallback"` on a miss, and only reaches
  `$default_agent` (`via="default"`) on a genuine total miss of both blocks. Non-hard mode
  is behaviorally unchanged. `_route_block` removed from body and `unset` list;
  `_route_std_value`/`_route_std_via` added to the `unset` list (no state leak). EDGE CASES
  header and the `$4` parameter comment rewritten to document the ladder instead of
  asserting the discard was deliberate.
- `agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` — Assert 3's
  neovim/nix semantic sub-checks inverted from expecting the caller's generic hard default
  to expecting the extension's own standard agent with `via="hard-miss-standard-fallback"`;
  framing comment rewritten (standard-block reuse is now the correct contract, not a
  regression); added a fixture-coupling comment noting `nix` is itself one of the 14
  hard-block-less extensions, so a future `routing_agents_hard` declaration for `nix` shifts
  this fixture's expected value; added a fourth semantic case proving a never-declared
  task_type under `--hard` still resolves the caller-supplied default (the genuine
  total-miss rung, previously unexercised). The lean4 sub-check (hard-hit proof) is
  unmodified.

## Decisions

- Fixed the consumer (`command-route-agent.sh`), not `manifest-routing-lib.sh`:
  `routing_lookup()` is a deliberate single-block primitive, and `command-route-skill.sh`
  already composes its own two-block ladder in the consumer, not the library.
- Reused the `via="hard-miss-standard-fallback"` string verbatim from the skill-side
  resolver so `routing_trace` output is diagnostically comparable across both resolvers.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (bash scripts)
- Tests: Passed — `test-routing-resolution.sh` 19/19 PASS (was 18/18 PASS pre-fix on the
  now-amended assertion count; added one new total-miss case)
- Files verified: Yes

### Pre-fix vs. post-fix resolution matrix (op=research, `ROUTE_MANIFEST_ROOT=agent-system`)

| task_type              | standard              | hard (pre-fix)                | hard (post-fix)          |
|-------------------------|------------------------|--------------------------------|----------------------------|
| typst                   | typst-research-agent   | general-research-hard-agent (DOWNGRADE) | typst-research-agent |
| neovim                  | neovim-research-agent  | general-research-hard-agent (DOWNGRADE) | neovim-research-agent |
| nix                     | nix-research-agent     | general-research-hard-agent (DOWNGRADE) | nix-research-agent |
| python                  | python-research-agent  | general-research-hard-agent (DOWNGRADE) | python-research-agent |
| latex                   | latex-research-agent   | general-research-hard-agent (DOWNGRADE) | latex-research-agent |
| web                     | web-research-agent     | general-research-hard-agent (DOWNGRADE) | web-research-agent |
| z3                      | z3-research-agent      | general-research-hard-agent (DOWNGRADE) | z3-research-agent |
| formal:logic (compound) | logic-research-agent   | general-research-hard-agent (DOWNGRADE) | logic-research-agent |
| lean4 (genuine hard block) | lean-research-agent | lean-research-hard-agent (correct) | lean-research-hard-agent (unchanged) |
| zzz-unrouted (total miss) | general-research-agent | general-research-hard-agent (correct) | general-research-hard-agent (unchanged) |

Spot-checked op=plan/op=implement for neovim, python, latex: hard == standard in every case
(no downgrade). Confirmed only `skill-orchestrate` and `skill-orchestrate-hard` source this
script, and both hard-mode defaults (`general-research-hard-agent`, `planner-hard-agent`,
`general-implementation-hard-agent`) survive as the ladder's true-total-miss rung.

**Mutation check**: reverted `command-route-agent.sh` to its pre-fix content — the amended
Assert 3 neovim/nix sub-checks went RED (2 failures, 17/19 passed); restored the fix — suite
returned to 19/19 GREEN, and the restored file is byte-identical to the committed fix
(`git diff --stat` empty).

**14-extension inventory re-derived independently** via
`jq 'has("routing_agents")'`/`jq 'has("routing_agents_hard")'` across
`agent-system/extensions/*/manifest.json`: email, epidemiology, filetypes, formal, founder,
latex, memory, nix, nvim, present, python, typst, web, z3 — confirms the count of 14 from
the research report.

**Shell-state leak check**: after a sourced call, no `_route_*` variable remains in the
calling shell.

`command-route-skill.sh` and `manifest-routing-lib.sh` are unmodified (`git diff --stat`
empty on both paths). No file under `.claude/**` was touched.

## Impacts

- `/orchestrate --hard` and `--hard` invocations of `/research`, `/plan`, `/implement` via
  `skill-orchestrate-hard` now correctly resolve domain-specific agents (e.g.
  `neovim-research-agent`, `python-implementation-agent`) instead of silently falling back
  to the generic hard default for any of the 14 extensions lacking a `routing_agents_hard`
  block.
- No behavior change for standard (non-hard) resolution, and no change for the 3 extensions
  (core, cslib, lean) that already declare `routing_agents_hard`.

## Follow-ups

- None required by this task. Two adjacent items were explicitly scoped out per the plan's
  Non-Goals and remain available as separate future tasks: documenting the two-block
  composition pattern in `context/guides/manifest-routing-schema.md` /
  `hard-mode-routing.md`, and declaring `routing_agents_hard` blocks for any of the 14
  affected extensions (a distinct contract-delivery concern, not a bug fix).

## References

- Plan: `specs/063_fix_hard_mode_agent_routing_downgrade/plans/01_fix-hard-mode-agent-routing.md`
- Research: `specs/063_fix_hard_mode_agent_routing_downgrade/reports/01_agent-routing-hard-mode-parity.md`

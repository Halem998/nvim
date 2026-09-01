# Research Report: Task #121

- **Task**: 121 - Delete hard mode lifecycle files
- **Started**: 2026-09-01T00:00:00Z
- **Completed**: 2026-09-01T00:00:00Z
- **Effort**: verification only, no implementation
- **Dependencies**: Task 118, Task 119, Task 120, Task 128 (all [COMPLETED] per state)
- **Sources/Inputs**: Codebase inspection (agent-system/extensions/core, cslib, lean), git history, specs/TODO.md, specs/116 design report
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- **PRECONDITION NOT MET. Deletion must not proceed.** Two of the three stated preconditions
  hold; the third (test/lint retargeting "landed and verified working") does not, and a
  fourth, unstated but load-bearing dependency (the `/research`/`/plan`/`/implement` commands
  and their live `--hard` routing) is still fully live and would break on deletion.
- Hard-mode contract-injection mechanism: **confirmed landed** in
  `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (`<hard-mode-contracts>`
  block, Stage 3.5 dispatch prep).
- State-machine residue migration: **confirmed landed** (H1 per-phase dispatch, H4 adversarial
  gate, H5 divergence audit, H6 churn detection all present as `hard_mode`-gated branches in
  `skill-orchestrate/SKILL.md`).
- Test/lint retargeting: **incomplete, contradicting task 120's own completion summary**.
  `lint-contract-compliance.sh` Checks A, C (main loop), and E still hard-require the exact
  files this task would delete; `lint-agent-contracts.sh`'s in-scope path list still enumerates
  two of them. These were verified against the actual current file content and against the git
  commit that task 120 claims did the retargeting.
- Separately, and more seriously: `/research`, `/plan`, `/implement` (task 124, "Delete
  lifecycle commands," is still `[PLANNING]`) are live commands whose `--hard` flag still routes
  through `command-route-skill.sh` to `skill-researcher-hard`/`skill-planner-hard`/
  `skill-implementer-hard` via the core manifest's `routing_hard` block — a mechanism
  `test-routing-resolution.sh` deliberately and correctly still tests as live, current behavior.
  Deleting the target files, and/or stripping `routing_hard` from the three manifests, breaks
  this live command surface and that test suite.

## Context & Scope

Task 121 asks to delete `skill-orchestrate-hard` and the three `-hard` lifecycle skills/agents,
and to strip `routing_hard`/`routing_agents_hard` from the core, cslib, and lean manifests,
under an explicit precondition: the hard-mode contract-injection mechanism, the state-machine
residue migration, and the test/lint retargeting must already be landed and verified working
inside `skill-orchestrate/SKILL.md`, making this "pure deletion with zero rewiring." This report
verifies that precondition against the live source store rather than against task-status labels.

## Findings

### 1. Hard-mode contract-injection mechanism — LANDED

`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` builds a
`<hard-mode-contracts>` tag (around line 882-944) inside its Stage 3.5 dispatch-prep, gated on
`hard_mode`, wrapping references to the same `context/contracts/*.md` files the `-hard` files
used. This matches A4 of `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md`.

### 2. State-machine residue migration — LANDED

`skill-orchestrate/SKILL.md` contains, all `hard_mode`-gated:
- H1 single-blocking-phase-per-cycle dispatch (Stage 4, `#### State: planned or implementing`,
  "Hard branch: Per-Phase Dispatch (H1)")
- H4 adversarial-verification gate (Stage 4, `researched`/`planning` handlers)
- H5 three-strikes divergence-audit dispatch and H6 per-target churn counters (Stage 5b)
- Loop-guard staleness detector, churn-state init (`.orchestrator-churn-state.json`)

This matches the acceptance table referenced at the top of the file and A4's residue-migration
requirement.

### 3. Test/lint retargeting — NOT LANDED (contradicts task 120's summary)

Task 120 ("Retarget hard mode tests to engine branch") is marked `[COMPLETED]` and its summary
(`specs/120_retarget_hard_mode_tests_to_engine_branch/summaries/01_retarget-hard-mode-tests-summary.md`)
states `lint-contract-compliance.sh` was retargeted "Check C's existence assertion and Check D's
`skill_file`... updated all message strings." Direct inspection of the current file, cross-checked
against the actual commit `f3fb615bb` ("task 120 phase 2: retarget lint-contract-compliance.sh"),
shows this claim is only partially true:

- **Check D** (convergence policing) — fully retargeted to `skill-orchestrate/SKILL.md`. Correct.
- **Check C** (`check_c_hard_skill_dispatch`, `agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh:222-256`)
  — only its trailing "special case" sub-block (the `skill-orchestrate-hard` existence check) was
  retargeted to `skill-orchestrate/SKILL.md`. The **main loop above it was left untouched**:
  it still iterates
  `SKILL_AGENTS=(["skill-researcher-hard"]="general-research-hard-agent" ["skill-planner-hard"]="planner-hard-agent" ["skill-implementer-hard"]="general-implementation-hard-agent")`
  and calls `log_fail "$skill: SKILL.md not found"` for each of the three when the file is
  missing. Deleting the three `-hard` SKILL.md files makes this loop fail three times.
- **Check A** (`check_a_hard_agent_contract_references`, lines ~119-171) — never touched by task
  120's commit. Still does `log_fail "general-research-hard-agent.md not found"` /
  `"planner-hard-agent.md not found"` / `"general-implementation-hard-agent.md not found"` when
  those exact files (this task's deletion targets) are absent.
- **Check E** (`check_e_h2_vocabulary`, lines ~293-321) — never touched. Still does
  `log_fail "general-implementation-hard-agent.md not found -- skipping H2 vocabulary checks"`.

Separately, `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`'s
`IN_SCOPE_RELATIVE_PATHS` array (curated, hand-maintained, unrelated to task 120's scope) still
lists `core/agents/general-implementation-hard-agent.md` and `core/agents/planner-hard-agent.md`
as paths expected to carry the no-task-references bullet. This was never in task 120's scope and
is a second, independent gap that deletion would trip.

**Conclusion**: the "test/lint retargeting... landed and verified working" clause of task 121's
own stated precondition is false for `lint-contract-compliance.sh` (Checks A, C, E) and
`lint-agent-contracts.sh`. Running `lint-contract-compliance.sh` after this task's deletion, as
written today, would produce at least 3 (Check A) + 3 (Check C) + 1 (Check E) = 7 new `log_fail`
lines, and `lint-agent-contracts.sh` would fail on two missing in-scope paths.

### 4. `/research`/`/plan`/`/implement` are still live and still dispatch `--hard` to these exact files

This is the more consequential finding, and is outside what task 121's dependency list (118,
119, 120, 128) currently accounts for.

- `agent-system/extensions/core/commands/research.md` (652 lines) still exists, still accepts
  `--hard`, and at line 484 sources `command-route-skill.sh "research" "$task_type"
  "skill-researcher" "$shell_effort_flag"` — i.e. it still resolves through the routing ladder
  with the hard effort flag threaded in. `plan.md` and `implement.md` do the same for their ops.
- `command-route-skill.sh` (still present, not retired) resolves `effort_flag=hard` against each
  manifest's `.routing_hard` block. The core manifest's `routing_hard` block maps
  `research.general/meta/markdown -> skill-researcher-hard`, `plan.* -> skill-planner-hard`,
  `implement.* -> skill-implementer-hard`.
- `agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` deliberately and
  correctly asserts this is live behavior today: its Assert 1 builds a `HARD_MATRIX_FILE` from
  every manifest's `.routing_hard` block and checks `command-route-skill.sh` resolves each pair;
  a second explicit loop (`for op_default in "research skill-researcher-hard" "plan
  skill-planner-hard" "implement skill-implementer-hard"`) checks the hard-mode default
  resolution for `general`/`meta`/`markdown` task types. This is not stale residue to retarget —
  task 120's own summary explicitly did NOT touch this section, and correctly so, since
  `routing_hard` was still a live, correct mechanism when task 120 ran.
- Task 124, "Delete lifecycle commands and update reference" (the task that removes
  `research.md`/`plan.md`/`implement.md` and thereby retires the only caller of
  `command-route-skill.sh`), is still `[PLANNING]`, not completed. Task 127, "Collapse routing
  ladder to routing agents" (the task that removes `routing`/`routing_hard` from all manifests
  once nothing calls them), is `[NOT STARTED]` and explicitly depends on **both** Task 124 and
  Task 121 having already landed — its own description states: "DEPENDS ON both the command
  deletions (routing/skill-dispatch has no remaining caller) and the hard-mode file deletions...
  having already landed."

**Consequence if task 121 proceeds now**: `/research --hard`, `/plan --hard`, `/implement --hard`
on `general`/`meta`/`markdown` task types are live, user-reachable commands today. Deleting
`skill-researcher-hard/SKILL.md`, `skill-planner-hard/SKILL.md`, `skill-implementer-hard/SKILL.md`
and their agent files while these commands still route to them by name breaks that command
surface outright (a `Skill`/`Agent` tool call naming a file that no longer exists). Additionally
removing the `routing_hard`/`routing_agents_hard` blocks from the core/cslib/lean manifests (as
task 121's WORK section directs) changes the failure mode from a loud missing-file error to a
silent one: `command-route-skill.sh`'s documented fallback ("Hard mode with no hard variant:
emits stderr note, uses standard skill") means `--hard` on these three commands would silently
downgrade to standard-effort research/plan/implement with no user-visible signal beyond a stderr
note — and `test-routing-resolution.sh`'s hard-matrix and `op_default` assertions would fail
loudly in CI either way, since the manifests would no longer declare the pairs the test expects.

### Note on cslib and lean manifests

`cslib/manifest.json`'s `routing_hard` block also references `skill-researcher-hard`,
`skill-planner-hard`, `skill-implementer-hard` (for its `pr`/`cslib` sub-types, e.g.
`plan.cslib -> skill-planner-hard`, `implement.pr -> skill-implementer-hard`), so it is affected
by the same live-command dependency as core. `lean/manifest.json`'s `routing_hard` block, by
contrast, references only lean's own domain-specific hard skills (`skill-lean-research-hard`,
`skill-lean-implementation-hard`) and does not name any of the seven files this task deletes —
its inclusion in task 121's WORK section is consistent with A4(iii) of the design report (which
treats `routing_hard`/`routing_agents_hard` as a key that becomes universally inert once nothing
calls the routing ladder, regardless of what it points to), but removing it *now* would break
lean's own live `--hard` routing the same way core/cslib's removal would break theirs, since
`/research`/`/plan`/`/implement` are still the caller for lean4 too.

## Decisions

- No files were modified. This report is verification-only, per the precondition's explicit
  "verify before starting, do not proceed otherwise" instruction.
- Recommend the parent orchestrator treat this task as blocked rather than proceeding to
  planning/implementation.

## Risks & Mitigations

- **Risk**: proceeding with the deletion as scoped would break live `/research --hard`,
  `/plan --hard`, `/implement --hard` on `general`/`meta`/`markdown` (and cslib's `pr`/`cslib`
  hard routes), and would introduce at least 8 new lint/test failures
  (`lint-contract-compliance.sh` Checks A/C/E, `lint-agent-contracts.sh`,
  `test-routing-resolution.sh`'s hard-matrix and `op_default` assertions).
- **Mitigation (recommended)**: reorder the backlog so Task 124 (delete lifecycle commands) lands
  before Task 121, matching the actual dependency `routing_hard`'s live callers create — not just
  Task 121's current stated dependency list (118, 119, 120, 128), which omits 124. As a fallback
  if 124 cannot land first, Task 121's WORK section would need to be split: file/agent deletion
  and manifest `routing_hard` removal deferred until 124 lands, while a corrective pass to
  `lint-contract-compliance.sh` (Checks A, C, E) and `lint-agent-contracts.sh`'s in-scope list is
  still independently needed regardless of sequencing (task 120's completion claim for these
  specific checks does not match the file content).

## Context Extension Recommendations

None — this is a sequencing/verification finding specific to this task's backlog graph, not a
general documentation gap.

## Appendix

- Files inspected: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
  `agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh`,
  `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`,
  `agent-system/extensions/core/scripts/tests/test-routing-resolution.sh`,
  `agent-system/extensions/core/commands/research.md`,
  `agent-system/extensions/core/scripts/command-route-skill.sh`,
  `agent-system/extensions/{core,cslib,lean}/manifest.json`.
- Git commands: `git log --oneline -- <path>`, `git show f3fb615bb -- <path>`.
- Cross-referenced: `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md`
  (A1, A3, A4, A7), `specs/120_retarget_hard_mode_tests_to_engine_branch/summaries/01_*.md`,
  `specs/TODO.md` entries for tasks 118, 119, 120, 121, 124, 127, 128.

# Implementation Summary: Task #900

**Completed**: 2026-07-25
**Duration**: single implementation session, 6 phases

## Overview

Implemented `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`, a read-only,
blocking (defer-not-fail) admission predicate that checks each candidate task's `file_scope`
against every non-terminal task in `specs/state.json` — not just the tasks in the current
`/orchestrate` invocation, and not just tasks currently holding a lock. Both existing runtime
wave-split checks (`commands/orchestrate.md` Step 3, `skills/skill-orchestrate/SKILL.md` Stage
MT-3 step 4.5) now call this script instead of their prior invocation-scoped inline pairwise
loop, and both had their `2+ tasks` precondition removed since a cross-batch collision exists at
batch size 1.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` — new script. Single
  `jq --slurpfile` read of `specs/state.json`; emits one NDJSON verdict
  (`orchestrate-batch-admit-v1`) per candidate task number in input order. Transcribes (never
  restates) the directory-prefix overlap predicate from `file-footprint-overlap.md`, mirroring
  `task-lock.sh`'s `scopes_overlap()`. Implements the deferral-direction rule: `in_batch`
  collisions defer only the higher-numbered candidate (existing wave-split behavior preserved
  bit-for-bit); `cross_batch` collisions defer unconditionally.
- `agent-system/extensions/core/manifest.json` — registered the new script in
  `provides.scripts`.
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` — new canonical schema
  document (modelled on `handoff-schema.md`), pinning every verdict field, the
  blocking-vs-advisory rationale, and the `collision_scope`-vs-`severity` naming rationale.
- `agent-system/extensions/core/docs/README.md` — indexed the new schema doc next to the
  existing Handoff Schema entry.
- `agent-system/extensions/core/commands/orchestrate.md` — Step 3's runtime wave-split check now
  calls the script, handles both `collision_scope` branches with distinct warnings, states the
  defer-not-fail invariant and the exit-2 degradation path, and no longer claims an
  invocation-scoped read.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-3 step 4.5 mirrors
  the same change for per-cycle dispatch; preserves surrounding cycle semantics (deferred tasks
  are never added to `failed_tasks`) and the sibling-added `skill_gate_completion_claim` calls
  and Stage 5 recovery-grep block untouched.
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` — registered the
  script as the algorithm's fourth named consumer (batch-admission-level), updated the "three
  callers" / "All three callers" language to four, and extended the Non-Goals scan-scope note to
  cover the third scan-scope shape (repo-wide via a single `state.json` read) without weakening
  the "predicate only" statement.
- `specs/900_cross_batch_file_scope_admission/fixtures/state-cross-batch.json` — new frozen
  fixture. Copies tasks 900, 902, 906, and 907 verbatim from live `specs/state.json` on the
  load-bearing fields, plus five synthetic entries: a terminal task overlapping 900, a
  trailing-slash directory-scope task, and three isolation-only helper tasks (terminal-exclusion
  candidate, and an edge-linked pair) so each mechanic (terminal exclusion, edge exclusion,
  directory-prefix matching) can be asserted independently of the real 900/902/906/907
  collisions.
- `specs/900_cross_batch_file_scope_admission/tests/test-batch-admit.sh` — new deterministic
  test suite. Builds a throwaway scratch deploy tree per run (never writes to the real
  `.claude/`), asserts exact verdict lines, well-formedness, all four exit-code paths, and a
  live smoke check against the real `specs/state.json` (structural assertions only, since live
  state mutates as tasks complete).

## Decisions

- Used `jq -n` with `--slurpfile` (not a positional file argument) so the script satisfies the
  "exactly one read of `STATE_FILE`" requirement literally — a positional argument alongside
  `--slurpfile` would have caused a second read.
- Fixed a jq context-binding bug during implementation: `index(.project_number)` inside a
  pipeline evaluates `.` against the piped array, not the outer entry, so the edge-exclusion
  filter now binds the outer entry to a named variable (`. as $t`) before calling `index`.
- Added three helper synthetic fixture entries (992 terminal-exclusion candidate; 993/994
  edge-linked pair) beyond the two the plan named explicitly (terminal-overlap and
  directory-scope), because the fixture's mandated verbatim inclusion of 900/902/906/907 already
  produces real collisions among those four tasks, which would otherwise confound a clean,
  isolated assertion of the terminal-exclusion and edge-exclusion mechanics. The fixture's
  `length >= 6` verification check accommodates this.

## Plan Deviations

- **Task 2.3** (Phase 2 exact-line assertion for scenario "candidates 900 902") altered: the
  plan predicted candidate 900 would emit `admit`. Because the fixture must copy 900/902/906/907
  verbatim from live `specs/state.json`, and 900 has a genuine, independent cross-batch collision
  with 906 (shared `skills/skill-orchestrate/SKILL.md` scope, no `dependencies[]` edge), a
  correct implementation defers 900 against 906 rather than admitting it. The test asserts this
  correct, real behavior instead; 902's line (defer against 900, `in_batch`) is unchanged from
  the plan's prediction and still verifies the in-batch direction rule. Recorded in
  `progress/phase-2-progress.json` and annotated inline on the plan's checklist item.
- **Task 6.2** (Phase 6 doc-lint/wiring validator run) altered in scope only: `check-extension-docs.sh`
  and `validate-wiring.sh` report pre-existing findings unrelated to this task (deployed-content
  drift for `git-snapshot.sh`/`skill-base.sh`/`reconcile-artifacts.sh`/`git-workflow.md`, and 42
  missing `project/neovim/*` context files) — none reference any file this task touched. Per the
  plan's own instruction, these are recorded in `progress/phase-6-progress.json`, not fixed here.
  `validate-extension-index.sh` passed with 0 errors.

## Verification

- Build: N/A (bash/jq scripts, no compiled build step)
- Tests: Passed — `specs/900_cross_batch_file_scope_admission/tests/test-batch-admit.sh` exits 0
  (8/8 assertions, including the live smoke check)
- Files verified: Yes — every phase's exact verification block from the plan was run and passed;
  Stage 5a backstop confirmed all 6 phase headings carry `[COMPLETED]`; 0 remaining `- [ ]`
  checklist items in the plan.
- Additional ad hoc checks: empty/absent `file_scope` and unknown candidates confirmed to admit;
  confirmed via sha256 checksum that the script never mutates `specs/state.json`.

## Notes

- Nothing in this change deploys to `.claude/` — per the plan's explicit Deployment note, the
  new script and edited commands/skills/context/docs reach the running system only after a
  user-driven sync (`<leader>al`, "Load Core"). `check-extension-docs.sh` correctly reports the
  new script as an ADVISORY "never deployed" item (not a FAIL) for this reason.
- The working tree contains pre-existing, unrelated modifications to `.claude-extensions.json`,
  `lua/neotex/plugins/editor/which-key.lua`, and `lua/neotex/plugins/tools/himalaya/utils/cli.lua`
  that predate this session's work on task 900 and are outside this task's `file_scope`.

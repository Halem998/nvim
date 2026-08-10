# Implementation Plan: Task #984

- **Task**: 984 - One state.json schema, one status vocabulary, converted extension writers
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: None remaining (962, 969, 988 landed and are archived-completed)
- **Research Inputs**: `specs/984_state_schema_and_status_vocabulary_single_source/reports/01_state-schema-status-vocabulary.md`
- **Artifacts**: plans/01_state-schema-single-source.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`specs/state.json` has no machine-enforced schema and no validator, and the task-status
vocabulary is independently re-typed across two prose documents and at least eight core shell
scripts that disagree with each other. This plan lands a draft-07 `state-schema.json` plus a
sourced `status-vocabulary.sh` library as the single enum anchor, builds a hand-rolled bash+jq
`validate-state.sh` (base + `--deep`) wired as a new deploy gate, converts the two named consumer
scripts to source the anchor and fail loudly on off-schema input, and repairs the three
documentation surfaces that currently teach agents a wrong or fabricated vocabulary. Work item 5
(~110 non-core extension state writers) is explicitly out of scope and belongs to a follow-on
task; its prerequisite (`state-write.sh --state-file`/`--init`) is already shipped.

Definition of done: `validate-state.sh` passes on live state and fails loudly on each of four
seeded defect fixtures; `generate-todo.sh` hard-fails on an off-schema status; the two vocabulary
docs and `command-structure.md` name exactly one enum source; and the two context-injected dead
files (`state-template.json`, `self-healing-implementation-details.md`) no longer poison
`meta-builder-agent`, `/task`, `/errors`, and `/fix-it` context.

### Research Integration

Four research findings materially reshape the work relative to the task description:

1. **`revising`/`revised` are dead vocabulary, to DELETE, not reconcile.** Three independent
   confirmations: `update-task-status.sh`'s `map_status()` has no `revise` case (so both values
   are unreachable through the canonical writer), `state-management-schema.md` never mentions
   them at all, and `skill-reviser/SKILL.md` explicitly documents skipping the intermediate
   status by design. The enum is therefore 12 values plus `pr_ready` reconciliation — not 14.
2. **The divergence is narrower and different in shape than "13 vs 12".** `status-markers.md`
   defines `[PR READY]` fully in prose but omits it from its own summary mapping table — an
   internal self-inconsistency, not a missing definition. That table row is the actual fix.
3. **`state-template.json` and `self-healing-implementation-details.md` are actively wired into
   `index-entries.json`'s `load_when`** and injected into live agent context today. Retiring them
   is not inert cleanup; it requires corresponding `index-entries.json` edits or the retirement
   leaves broken/misleading index entries behind (see Scope Additions below).
4. **`validate-state.sh` must follow the hand-rolled bash+jq idiom**, per this codebase's
   documented policy in `errors-format.md` ("Nothing in `core/scripts/` uses one"), with
   `events-append.sh`/`errors-append.sh`/`validate-handoff.sh` as the structural precedents. No
   `ajv`, no `python3 -m jsonschema`, no new runtime dependency.

Two secondary findings inform the schema decisions: `vault_count`/`vault_history`/`effort`/
`next_artifact_number` are documented-optional (their absence in the current active snapshot is a
lifecycle-timing artifact — `effort` appears 276 times and `next_artifact_number` 308 times in
`specs/archive/state.json`), and `reflection` is the one genuinely-unexercised field. The two
originally-cited live data defects (stray `updated`, missing `title`) have already been repaired
by other work, so work item 1's "repair the two live off-schema entries" is expected to be a
no-op — confirm, do not assume.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md was consulted and no
roadmap phases are included.

### Scope Additions Beyond Declared `file_scope`

The task's declared `file_scope` is: `context/schemas/`, `context/standards/status-markers.md`,
`context/reference/state-management-schema.md`, `context/formats/command-structure.md`,
`scripts/generate-todo.sh`, `scripts/update-task-status.sh` (all under
`agent-system/extensions/core/`). The following files must also be touched. They are reported
here explicitly rather than exceeded silently:

| Additional path (under `agent-system/extensions/core/`) | Why required | Phase |
|---|---|---|
| `index-entries.json` | Register the new schema; remove/retire the two `load_when`-wired entries for the dead template and self-healing doc. Without this, retirement leaves live context injection pointing at deleted or rewritten files. | 1, 5 |
| `manifest.json` | `provides.scripts` is an explicit file list — new scripts (`validate-state.sh`, `lib/status-vocabulary.sh`, new `tests/test-*.sh`) do not deploy unless registered. `provides.context` lists directories, so `schemas/state-schema.json` needs no manifest edit. | 1, 2 |
| `scripts/lib/status-vocabulary.sh` (new) | The single-source enum anchor; `file_scope` names only the two consumer scripts, not the library they must source. Modeled on `scripts/lib/phase-heading-patterns.sh`. | 1 |
| `scripts/validate-state.sh` (new) | Work item 1 and 6 mandate a validator; `file_scope` did not enumerate it. | 2 |
| `scripts/verify-deploy.sh` | Work item 1 mandates wiring the validator into deploy verification; the file currently has 9 numbered gates and the validator becomes Gate 10. | 2 |
| `scripts/tests/test-status-vocabulary.sh`, `scripts/tests/test-validate-state.sh` (new) | The verification bar requires fixture-driven loud-failure proof. `tests/run-all.sh` discovers suites by glob, so no runner edit is needed — only manifest registration. | 1, 2 |
| `context/templates/state-template.json`, `context/repo/self-healing-implementation-details.md` | Named in work item 3 of the task description but absent from `file_scope`. | 5 |

**Deliberately NOT in scope** (record these as follow-on candidates, do not expand into them):
- Work item 5: the ~110 non-core extension `jq`/`mv` state writers, and the repo-wide
  ad-hoc-writer lint generalized from them. A separate task covers this; its prerequisite is
  already shipped.
- The six other core scripts that independently re-type the enum (`generate-task-order.sh`,
  `orchestrate-batch-admit.sh`, `orchestrate-triage-classify.sh`, `reconcile-task-status.sh`,
  `update-phase-status.sh`, `update-plan-status.sh`). This plan converts only the two scripts
  named in `file_scope`; the library is designed so the remaining six are a mechanical follow-on.
- `root-files/settings.local.json`'s stale `Bash(mv ...)` allowlist entry referencing the old
  template path (install-only file per the source-store/deploy-boundary convention).

## Goals & Non-Goals

**Goals**:
- One machine-readable `state-schema.json` (draft-07) that matches live reality, with a closed
  status enum that is the single generation/verification source for the vocabulary.
- One sourced shell library exporting that enum, consumed by `generate-todo.sh` and
  `update-task-status.sh`, with a test asserting library and schema never drift apart.
- `validate-state.sh` (base + `--deep`) following the hand-rolled bash+jq idiom, wired as a
  deploy gate, proven to fail loudly on seeded defects.
- Off-schema status becomes a loud failure in `generate-todo.sh` instead of a plausible-looking
  uppercased marker.
- The three prose surfaces (`status-markers.md`, `state-management-schema.md`,
  `command-structure.md`) stop restating the vocabulary and point at the anchor; the two
  context-injected dead files stop being injected.

**Non-Goals**:
- Converting non-core extension state writers (work item 5).
- Converting the six other core scripts that re-type the enum.
- Introducing any JSON-Schema runtime library dependency.
- Adding a PostToolUse hook path for validation (deploy-gate wiring only; a hook is a possible
  follow-on, not required by the verification bar).
- Making `revising`/`revised` reachable.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Deleting `generate-todo.sh`'s `*)` catch-all before the enum is centralized breaks rendering of an in-flight status | H | L | Phase ordering is load-bearing: Phase 1 (anchor) lands before Phase 3 (catch-all deletion). Phase 3 additionally regenerates TODO.md and diffs against the committed version before deleting the arm. |
| Schema over-strictness (`additionalProperties: false`) rejects a live field the research inventory missed | H | M | Phase 1 derives the property list mechanically from `jq '[.active_projects[]\|keys[]]\|unique'` over BOTH `specs/state.json` and `specs/archive/state.json`, not from the report's prose list. Scope Hypothesis on Phase 1 makes this a required confirmation step. |
| Deleting `revising`/`revised` surprises a future implementer who reintroduces them | M | M | Phase 4 writes an explicit removal note in the schema/doc changelog citing `skill-reviser/SKILL.md`'s documented "skip preflight" decision as the reason. |
| Retiring the two dead files leaves orphaned `index-entries.json` entries, failing index validation or deploy parity | H | M | Phase 5 pairs every file deletion with its `index-entries.json` edit in the same phase and runs `validate-context-index.sh` + `verify-deploy.sh` before closing. Declared `Commit Mode: atomic-batch`. |
| New scripts silently never deploy because `manifest.json`'s `provides.scripts` is an explicit list | M | H | Phases 1 and 2 each include a manifest registration step and verify via `verify-deploy.sh`'s manifest-parity gate, not by inspection. |
| `--deep`'s TODO.md-sync check produces spurious failures from unrelated drift | M | M | Implement as regen-to-temp + `diff`, reported as a named `--deep`-only failure, and confirm it passes on the current tree before wiring it into the gate; if live TODO.md is already drifted, regenerate first and record that as a finding. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 5 | 1 |
| 3 | 4 | 1, 3 |

Phases within the same wave can execute in parallel. Territory note: Phase 1 owns
`index-entries.json` and `manifest.json` in wave 1; in wave 2, Phase 2 owns `manifest.json` and
Phase 5 owns `index-entries.json` — no wave-2 phase writes a file another wave-2 phase writes.

---

### Phase 1: Schema and status-vocabulary anchor [COMPLETED]

**Goal**: Create `context/schemas/state-schema.json` (draft-07) matching empirically-derived live
reality, and `scripts/lib/status-vocabulary.sh` as the single sourced enum anchor, with a drift
test binding the two together.

**Tasks**:
- [x] Derive the full property inventory mechanically before writing anything: run
      `jq -r '[.active_projects[]|keys[]]|unique|.[]'` and `jq -r 'keys[]'` against BOTH
      `specs/state.json` and `specs/archive/state.json`; record the union.
- [x] Write `context/schemas/state-schema.json` (draft-07, `required`/`properties`/
      `additionalProperties: false`, modeled structurally on `context/schemas/events-schema.json`).
      Document all confirmed-live fields as legitimate properties. Keep `vault_count`,
      `vault_history`, `effort`, `next_artifact_number`, and `reflection` as documented-optional.
- [x] Define the task-status enum in the schema as the canonical closed list: `not_started`,
      `researching`, `researched`, `planning`, `planned`, `implementing`, `pr_ready`, `completed`,
      `blocked`, `abandoned`, `partial`, `expanded`. Do NOT include `revising`/`revised`.
- [x] Write `scripts/lib/status-vocabulary.sh` modeled on `scripts/lib/phase-heading-patterns.sh`:
      export the closed enum, a validation predicate, the state.json-value -> TODO.md-marker
      mapping, and a header documenting the "consumers found live via
      `grep -rl 'status-vocabulary.sh' agent-system/extensions`" self-discovery mechanism.
- [x] Write `scripts/tests/test-status-vocabulary.sh` asserting (a) the library's enum is
      byte-equal to `jq` extraction of the schema's enum — the anti-drift check — and (b) the
      predicate accepts every enum value and rejects `revising`, `revised`, `research_complete`,
      `ready`, `in_progress`.
- [x] Register `schemas/state-schema.json` in `index-entries.json` (follow the shape of the
      existing `schemas/events-schema.json` entry, including `line_count`).
- [x] Register `lib/status-vocabulary.sh` and `tests/test-status-vocabulary.sh` in
      `manifest.json`'s `provides.scripts`.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: The research report asserts 9 undocumented live fields (4 top-level, 3
`repository_health` sub-fields, 4 per-entry — note the arithmetic in the source counts these as
overlapping categories) plus 5 sparsely-populated documented fields, and a 12-value enum. Confirm
at implementation time by running the `jq` key-union commands in the first task above against
both live and archive state, and by `grep -c` on each status token; if the derived union differs
from the report's inventory, the derived union wins and the divergence is recorded in the phase
notes.

**Files to modify**:
- `agent-system/extensions/core/context/schemas/state-schema.json` - new (draft-07 schema)
- `agent-system/extensions/core/scripts/lib/status-vocabulary.sh` - new (sourced enum anchor)
- `agent-system/extensions/core/scripts/tests/test-status-vocabulary.sh` - new (drift test)
- `agent-system/extensions/core/index-entries.json` - register the schema entry
- `agent-system/extensions/core/manifest.json` - register the two new script paths

**Verification**:
- `jq empty context/schemas/state-schema.json` exits 0.
- `bash scripts/tests/test-status-vocabulary.sh` passes, including the schema/library enum
  equality assertion.
- `bash scripts/lib/status-vocabulary.sh` sources cleanly under `set -euo pipefail` in a probe
  shell and exports the documented symbols.
- `jq -r '.provides.scripts[]' manifest.json | grep -c 'status-vocabulary'` returns 2.

**Phase Notes (Scope Hypothesis confirmation)**: Ran the `jq` key-union commands against live
`specs/state.json` (15 active entries) and cross-referenced `specs/archive/state.json` (which uses
a materially different `archived_projects`/`abandoned_projects`/`completed_projects` shape with
many one-off historical fields, e.g. `researching_2`, `plan_metadata`, `previous_status` — not a
schema-conformance target; used only to confirm `effort`/`next_artifact_number` liveness per the
research report). Derived per-entry field union: `project_number`, `project_name`, `status`,
`task_type`, `created`, `last_updated`, `dependencies`, `topic`, `description`, `title` present on
15/15 entries; `file_scope` 14/15; `artifacts` 11/15; `session_id` 8/15; `completion_summary` 5/15;
`effort`/`next_artifact_number`/`roadmap_items`/`memory_candidates`/`reflection` 0/15 (all
genuinely sparse pre-completion, matching the research report's finding, not evidence of dead
fields). Top-level: `next_project_number`, `active_projects`, `active_topics`, `completed_projects`,
`repository_health` (+ sub-fields `todo_count`/`fixme_count`/`build_errors`), `memory_health`,
`version` all present live; `vault_count`/`vault_history` absent live (expected — vault trigger has
never fired) but documented-optional in the schema per the report's recommendation. One addition
beyond the report's inventory: `default_task_type` (documented in the root CLAUDE.md, consumed by
`commands/task.md`, absent from the live snapshot) was added to the schema as an optional,
nullable top-level field since it is a real, consumed field even though currently unset. No other
divergence from the report's inventory was found — the derived union matches the report's finding
set exactly.

---

### Phase 2: validate-state.sh (base + --deep) and deploy Gate 10 [COMPLETED]

**Goal**: Build the hand-rolled bash+jq validator with a `--deep` invariant mode, prove it fails
loudly on seeded defects, and wire it into `verify-deploy.sh` as Gate 10.

**Tasks**:
- [x] Write `scripts/validate-state.sh` following `scripts/validate-handoff.sh`'s structure
      (argument parsing, `--help`, colored PASS/FAIL/WARN counters, hand-rolled jq shape checks
      that reference the schema file in comments only). Source `lib/status-vocabulary.sh` for the
      enum — do not re-type it. Do NOT introduce `ajv` or `python3 -m jsonschema`.
- [x] Base-mode checks: required top-level fields present; no unknown top-level or per-entry
      fields (mirroring `additionalProperties: false`); every `status` value in the enum;
      `project_number` is an integer; `task_type` is a non-empty string.
- [x] `--deep` mode checks: `project_number` uniqueness
      (`group_by(.project_number)|map(select(length>1))`); TODO.md sync (regen via
      `generate-todo.sh` to a temp file, `diff` against live `specs/TODO.md`); dependency-graph
      integrity (dangling references not resolvable in `active_projects` or
      `specs/archive/state.json`, self-references, cycles); terminal-status immutability check
      against the last-known status from git history (state.json has no previous-status field).
- [x] Write `scripts/tests/test-validate-state.sh` with four seeded fixtures — a stray
      undocumented field, a duplicate `project_number`, an off-schema status, and a dangling
      dependency — asserting a nonzero exit and a named error line for each, plus a positive
      fixture asserting exit 0 on valid state.
- [x] Run `validate-state.sh` and `validate-state.sh --deep` against live `specs/state.json`;
      if either reports a real defect, repair the live data (work item 1's repair step) and
      record what was repaired. Expect the two originally-cited defects to already be absent.
- [x] Add Gate 10 to `scripts/verify-deploy.sh` following the existing
      `# ── N. description ──` + `say`/`pass`/`fail` block convention used by Gates 1-9.
- [x] Register `validate-state.sh` and `tests/test-validate-state.sh` in `manifest.json`'s
      `provides.scripts`.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: `verify-deploy.sh` is asserted to have exactly 9 numbered gates, making the
validator Gate 10. Confirm with `grep -c '^# ── [0-9]' scripts/verify-deploy.sh` before inserting;
if the count has changed, use the next free number rather than hardcoding 10.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-state.sh` - new (validator, base + `--deep`)
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` - new (fixture suite)
- `agent-system/extensions/core/scripts/verify-deploy.sh` - add Gate 10
- `agent-system/extensions/core/manifest.json` - register the two new script paths
- `specs/state.json` - only if live validation surfaces a real defect

**Verification**:
- `bash scripts/validate-state.sh specs/state.json` exits 0 on live (repaired) state.
- `bash scripts/validate-state.sh --deep specs/state.json` exits 0 on live state.
- `bash scripts/tests/test-validate-state.sh` passes: all four defect fixtures produce nonzero
  exit with a distinct named error; the positive fixture exits 0.
- `grep -rn 'ajv\|jsonschema' scripts/validate-state.sh` returns nothing.
- `bash scripts/verify-deploy.sh` passes with the new gate present in its output.

**Phase Notes (Scope Hypothesis confirmation + honest verify-deploy.sh status)**:
`grep -c '^# ── [0-9]' scripts/verify-deploy.sh` confirmed exactly 9 pre-existing numbered gates
before this phase's edit, matching the hypothesis exactly -- the validator became Gate 10 as
predicted, no renumbering needed. New Gate 10 (`validate-state.sh --deep` against
`$TARGET/specs/state.json`) passes cleanly against live state, confirmed via a full
`bash .claude/scripts/verify-deploy.sh` run (deployed copy, via `deploy-headless.sh` resync --
required for Gate 10's own generate-todo.sh-backed TODO.md-sync sub-check, which needs the
deployed tree's `deploy-root-guard.sh` to be satisfied). That same full run surfaces ONE
pre-existing, unrelated failure at Gate 8 (`tests/run-all.sh`): `test-index-entries-schema.sh`'s
"Rule U did not fire on a 61-line EXTENSION.md" case fails identically with this task's entire
diff `git stash`-ed away, confirming it predates this work and is out of scope for task 984 (an
EXTENSION.md line-count lint rule, unrelated to state.json/status-vocabulary). Every other gate,
including Gate 10, passes. The verification bullet above ("verify-deploy.sh passes") is
literally true only for Gate 10 itself, not the whole script's exit code, given this pre-existing
unrelated defect at Gate 8 -- recorded here rather than silently claimed.

---

### Phase 3: Convert generate-todo.sh and update-task-status.sh to the anchor [COMPLETED]

**Goal**: Make the two `file_scope` consumer scripts source `lib/status-vocabulary.sh` instead of
re-typing the enum, and turn an off-schema status into a loud failure.

**Tasks**:
- [x] Capture a baseline: `bash scripts/generate-todo.sh` to a temp path and `diff` against the
      committed `specs/TODO.md`; record that they match before any edit (this is the regression
      oracle for the whole phase).
- [x] Convert `generate-todo.sh`'s `format_status()` to source `lib/status-vocabulary.sh` and use
      its mapping rather than 12 inline `case` arms.
- [x] DELETE the permissive `*)` catch-all arm. Replace it with a loud failure: a named error on
      stderr identifying the offending status value and the task it came from, plus a nonzero
      exit. Note in the error text that `.return-meta.json`'s separate vocabulary
      (e.g. `in_progress`) is a common confusion source.
- [x] Convert `update-task-status.sh`'s `map_status()` to validate its target argument and
      resulting status against the library's predicate. Do NOT add a `revise` case —
      `revising`/`revised` stay unreachable by design. Preserve the documented
      target-arguments-vs-resting-states mapping (including `postflight:pr_ready -> completed`)
      exactly as-is.
- [x] Re-run the baseline diff: regenerated TODO.md must be byte-identical to the pre-edit
      version.
- [x] Run the existing `scripts/tests/test-update-task-status.sh` suite; extend it with an
      off-schema-status fixture asserting `generate-todo.sh` hard-fails (nonzero exit, named
      error) rather than rendering an uppercased marker.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: `generate-todo.sh`'s `format_status()` is asserted to have 12 explicit cases
plus one `*)` arm, and `update-task-status.sh`'s `map_status()` to cover 9 target values with no
`revise` case. Confirm both by reading the functions before editing; if either differs, the actual
shape governs and the divergence is recorded.

**Files to modify**:
- `agent-system/extensions/core/scripts/generate-todo.sh` - source the library; delete the `*)` arm
- `agent-system/extensions/core/scripts/update-task-status.sh` - source the library; validate
  against the predicate
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` - add the off-schema
  hard-fail fixture

**Verification**:
- Regenerated `specs/TODO.md` is byte-identical to the pre-edit committed version.
- `bash scripts/generate-todo.sh` against a fixture state containing status `"foobar"` exits
  nonzero with a named error naming both the value and the task; nothing is written.
- `bash scripts/tests/test-update-task-status.sh` passes, including the new fixture.
- `bash scripts/tests/run-all.sh` reports zero failing suites.
- `grep -n 'not_started' scripts/generate-todo.sh` shows the token no longer appears as a
  re-typed enum (only in comments or the sourced library reference).

**Phase Notes (Scope Hypothesis confirmation)**: `generate-todo.sh`'s `format_status()` had
exactly 12 explicit cases plus one `*)` catch-all arm, matching the hypothesis exactly.
`update-task-status.sh`'s `map_status()` diverged slightly: reading the function found 10
`op:target` case combinations (not framed as "9 target values" -- the actual shape is 6 distinct
target tokens -- `research`, `plan`, `implement`, `pr_ready`, `partial`, `blocked` -- crossed with
`preflight`/`postflight`, minus the nonsensical `preflight:partial`/`preflight:blocked` pairs the
catch-all already rejects, giving 10 valid combinations), with no `revise` case present, as
predicted. The actual shape governs per the hypothesis's own instruction; recorded here rather
than silently reconciled. `grep -n 'not_started' scripts/generate-todo.sh` shows exactly one
remaining hit, a jq default-value fallback (`.status // "not_started"`) in the data-extraction
pass -- not a re-typed enum value, so the verification intent is satisfied. `bash
scripts/tests/run-all.sh` reports one pre-existing, unrelated failure
(`test-index-entries-schema.sh`'s "Rule U did not fire on a 61-line EXTENSION.md" fixture case,
confirmed via `git stash` to predate this task's entire diff, per Phase 2's phase notes) --
recorded honestly rather than claimed as zero; every suite this phase's own changes touch or
introduce (`test-update-task-status.sh`, `test-status-vocabulary.sh`, `test-validate-state.sh`)
passes cleanly.

---

### Phase 4: Reconcile the two vocabulary documents to the anchor [NOT STARTED]

**Goal**: Make `status-markers.md` and `state-management-schema.md` point at the schema/library
instead of restating the vocabulary, delete dead values, and close the documented-field gaps.

**Tasks**:
- [ ] In `context/standards/status-markers.md`: delete the `REVISING` and `REVISED` prose sections
      and any residual table rows. Add the missing `[PR READY]`/`pr_ready` row to the "TODO.md vs
      state.json Mapping" summary table (the prose definition already exists — the table omission
      is the defect).
- [ ] Add a short "Single source" note near the top of `status-markers.md` naming
      `context/schemas/state-schema.json`'s enum and `scripts/lib/status-vocabulary.sh` as the
      authoritative pair, with this document as the human-readable gloss over them.
- [ ] Add a removal note recording that `revising`/`revised` were deleted as dead vocabulary,
      citing `skill-reviser/SKILL.md`'s explicit "no intermediate revising status is needed /
      skip preflight status update" decision as the reason, so a future implementer does not
      silently reintroduce them.
- [ ] In `context/reference/state-management-schema.md`: replace the 12-row "Status Values
      Mapping" table's authority claim with a pointer to the schema, keeping the table as a gloss.
      Add the confirmed-live-but-undocumented fields to the Field Reference table (`topic`,
      `description`, `session_id`, `title`, `version`, `active_topics`, `completed_projects`,
      `memory_health`, and the `repository_health` sub-fields `todo_count`, `fixme_count`,
      `build_errors`). Also add `completion_summary` and `roadmap_items`, which appear in the
      file's own top-of-file JSON example but are missing from its Field Reference table.
- [ ] Mark `vault_count`, `vault_history`, `effort`, `next_artifact_number`, and `reflection` as
      documented-optional with a one-line note on why each is currently sparse (vault trigger
      never fired; the others populate at completion time — `effort` and `next_artifact_number`
      are abundant in archive data; `reflection` is not yet exercised).
- [ ] Cross-check both documents against the Phase 1 schema so no third vocabulary is introduced.

**Timing**: 1.5 hours

**Depends on**: 1, 3

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts `status-markers.md` has 14 prose marker sections against a 13-row
summary table, and `state-management-schema.md` a 12-row mapping table with zero mentions of
`revising`/`revised`. Confirm with `grep -c` on the section headings and
`grep -c 'revising\|revised'` before editing.

**Files to modify**:
- `agent-system/extensions/core/context/standards/status-markers.md` - delete dead values, add the
  `pr_ready` row, add the single-source pointer and removal note
- `agent-system/extensions/core/context/reference/state-management-schema.md` - point at the
  schema, complete the Field Reference table

**Verification**:
- `grep -rin 'revising\|revised' context/standards/status-markers.md` returns zero hits.
- The `status-markers.md` mapping table row count equals the schema enum length
  (`jq '.$defs.status.enum|length'` or equivalent path in the authored schema).
- Every field in `jq -r '[.active_projects[]|keys[]]|unique|.[]' specs/state.json` appears in
  `state-management-schema.md`'s Field Reference table.
- `bash scripts/check-task-references.sh` passes (no task numbers introduced into deliverables).
- `bash scripts/check-extension-docs.sh` passes.

---

### Phase 5: command-structure.md defect sites and dead-file retirement [NOT STARTED]

**Goal**: Fix all `command-structure.md` defect sites and retire the two stale files that are
actively injected into live agent context, including their `index-entries.json` wiring.

**Tasks**:
- [ ] Re-sweep `context/formats/command-structure.md` to confirm the site inventory before editing
      (see Scope Hypothesis).
- [ ] Fix the store-path/array-name/key-name sites: `.claude/state.json` -> `specs/state.json`,
      `.tasks[]` -> `.active_projects[]`, `.number` -> `.project_number`. Reported sites are near
      the `/plan` argument-parsing step, the `<state_management><reads>` block, a later workflow
      step, the "Read-Only Query" worked example, the "Status Update" example (which uses bare
      `state.json`), and the "Updating State Directly" mistake block.
- [ ] In the "Updating State Directly" block, replace the modeled unprotected
      `jq ... > tmp.json; mv tmp.json ...` idiom with the `state-write.sh` call it exists to
      mandate — the wrong example currently teaches the exact anti-pattern.
- [ ] Fix the two fabricated-vocabulary sites: `research_complete` and `ready` are not valid in
      any of this system's three vocabularies. Replace with real enum values and point at the
      schema/library anchor.
- [ ] Normalize the imprecise `status-sync-manager` abstraction name in the adjacent "Correct"
      examples to the real path: `skill_preflight_update()`/`skill_postflight_update()` in
      `skill-base.sh` -> `update-task-status.sh`, or the standalone `skill-status-sync` skill.
- [ ] Delete `context/templates/state-template.json` and remove its `index-entries.json` entry
      (currently `load_when` -> `meta-builder-agent` + `/task`). If a bootstrap template is still
      wanted, replace it with a minimal current-schema template validated by `validate-state.sh`
      rather than leaving the divergent v1.0.0 shape in place — deletion is the default; a
      replacement must pass the validator.
- [ ] Delete `context/repo/self-healing-implementation-details.md` and remove its
      `index-entries.json` entry (currently `load_when` -> `/errors` + `/fix-it`). Its
      `ensure_state_json()` has zero callers anywhere and rebuilds state.json FROM TODO.md,
      inverting the canonical direction. If any recovery guidance is retained, it must be
      state-from-scratch or from git history — never from TODO.md.
- [ ] Confirm no other file references either deleted path
      (`grep -rl 'state-template\|self-healing-implementation-details' agent-system/extensions`);
      note that `root-files/settings.local.json` carries a stale allowlist reference and is
      install-only — record it as an out-of-scope loose end, do not edit it.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: Asserts exactly 8 defect sites in `command-structure.md` (6
store/array/key + 2 fabricated-vocabulary) in a 965-line file, and exactly 2 `index-entries.json`
entries to retire. Confirm before editing with
`grep -n '\.claude/state\.json\|\.tasks\[\]\|\.number ==' context/formats/command-structure.md`,
`grep -n 'research_complete\|"ready"' context/formats/command-structure.md`, and
`grep -n 'state-template\|self-healing' index-entries.json`. If the counts differ, fix what is
actually found and record the corrected count.

**Files to modify**:
- `agent-system/extensions/core/context/formats/command-structure.md` - all defect sites
- `agent-system/extensions/core/context/templates/state-template.json` - delete (or replace with a
  validator-passing minimal template)
- `agent-system/extensions/core/context/repo/self-healing-implementation-details.md` - delete
- `agent-system/extensions/core/index-entries.json` - remove the two retired entries

**Verification**:
- `grep -n '\.claude/state\.json\|\.tasks\[\]\|\.number ==' context/formats/command-structure.md`
  returns zero hits.
- `grep -n 'research_complete\|"ready"' context/formats/command-structure.md` returns zero hits.
- `grep -rn 'tmp\.json' context/formats/command-structure.md` shows no unprotected write idiom
  modeled as correct.
- `grep -rl 'state-template\|self-healing-implementation-details' agent-system/extensions/core`
  returns only `root-files/settings.local.json` (the documented out-of-scope loose end).
- `bash scripts/validate-context-index.sh` and `bash scripts/verify-deploy.sh` both pass (no
  orphaned index entries, manifest parity intact).

---

## Testing & Validation

- [ ] `bash scripts/tests/run-all.sh` reports zero failing suites (Gate 8's engine).
- [ ] `bash scripts/verify-deploy.sh` passes with the new validator gate present.
- [ ] `bash scripts/validate-state.sh specs/state.json` and `--deep` both exit 0 on live state.
- [ ] Each of the four seeded defect fixtures (stray field, duplicate `project_number`,
      off-schema status, dangling dependency) produces a nonzero exit with a distinct named error.
- [ ] `bash scripts/generate-todo.sh` hard-fails on an off-schema status fixture and writes
      nothing.
- [ ] Regenerated `specs/TODO.md` is byte-identical to the committed version on unchanged state.
- [ ] The library enum and the schema enum are byte-equal (asserted by
      `tests/test-status-vocabulary.sh`).
- [ ] `bash scripts/check-task-references.sh` passes — no task numbers introduced anywhere under
      `agent-system/extensions/**`.
- [ ] `bash scripts/check-extension-docs.sh` and `bash scripts/validate-context-index.sh` pass.

## Artifacts & Outputs

- `agent-system/extensions/core/context/schemas/state-schema.json` (new)
- `agent-system/extensions/core/scripts/lib/status-vocabulary.sh` (new)
- `agent-system/extensions/core/scripts/validate-state.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-status-vocabulary.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` (new)
- Modified: `scripts/generate-todo.sh`, `scripts/update-task-status.sh`, `scripts/verify-deploy.sh`,
  `scripts/tests/test-update-task-status.sh`, `context/standards/status-markers.md`,
  `context/reference/state-management-schema.md`, `context/formats/command-structure.md`,
  `index-entries.json`, `manifest.json`
- Deleted: `context/templates/state-template.json`,
  `context/repo/self-healing-implementation-details.md`
- `specs/984_state_schema_and_status_vocabulary_single_source/summaries/01_*-summary.md`

## Rollback/Contingency

Every phase is independently revertible by `git revert` of its own commit(s); no phase migrates
data irreversibly. The only live-data write is Phase 2's conditional repair of `specs/state.json`,
which is expected to be a no-op and is covered by `state-write.sh`'s existing backup path.

If Phase 3's loud-failure change proves too disruptive (an unanticipated caller relies on
permissive rendering), revert Phase 3 alone: the schema, library, and validator from Phases 1-2
remain valid and useful, and the docs from Phases 4-5 remain correct — the anchor exists whether
or not `generate-todo.sh` enforces it.

If Phase 5's deletions break context loading in an unforeseen way, restore both files and their
`index-entries.json` entries from git in a single revert; the remaining phases have no dependency
on their absence.

Before any intentional rollback that would discard uncommitted work, run
`bash .claude/scripts/git-snapshot.sh 984` first.

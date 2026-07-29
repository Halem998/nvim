# Implementation Plan: Task #979

- **Task**: 979 - Bootstrap the errors.json lane for real: one schema, validated append script, reconciled docs
- **Status**: [NOT STARTED]
- **Effort**: 10 hours
- **Dependencies**: None (see "Non-Dependency Note" below regarding tasks 951/952/953)
- **Research Inputs**: specs/979_bootstrap_errors_json_lane/reports/01_bootstrap-errors-schema-research.md
- **Artifacts**: plans/01_errors-json-lane-bootstrap.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`specs/errors.json` is documented as the backbone of `/errors`, `rules/error-handling.md`, and
several skills' failure paths, but the file does not exist in this repo and its shape is described
three mutually inconsistent ways. Every reader guards with `[ -f ]` and silently degrades to a
no-op, so the error-tracking layer is decorative. This plan makes it real: one authoritative
draft-07 schema plus a prose format contract, a single `flock`'d writer script with `append` and
`update` subcommands, a bootstrapped `specs/errors.json`, deploy-path wiring, and a rewrite of the
three conflicting doc blocks and the one live inline jq writer to point at the new schema and
script.

Definition of done: `errors-append.sh append` writes a schema-valid record under concurrent
invocation and rejects an off-schema record loudly; `errors-append.sh update` mutates an existing
record's `fix_status`/`fixed_date`/`fix_task` under the same lock without corrupting the file;
`specs/errors.json` exists and validates; `/errors` runs end-to-end without silent degradation; and
`grep -rn '\.errors *+=' agent-system/extensions/core/` returns zero hits.

### Research Integration

The research report is integrated as follows, and its findings drive the phase split:

- **Every task-description claim was empirically confirmed.** No phase is spent re-verifying the
  premise; phases start from construction.
- **`errors.json` is mutated in place, not append-only.** This is the single biggest deviation from
  "mirror `events-append.sh`" and is why the writer script is split across two phases: Phase 2
  builds `append` as a near-direct port, Phase 3 builds `update` as original read-modify-write
  design with no precedent in `core/scripts/` (`events-append.sh` is the only `flock` user there).
- **"Schema-validated" means hand-written bash checks kept in sync with the JSON Schema doc**, not
  a runtime JSON-Schema-library call. No `ajv`/`jsonschema` dependency is introduced.
- **Only ONE real inline jq writer exists** (`skills/skill-planner/SKILL.md`, the "jq Parse Failure"
  recovery block). The verification bar's grep sweep is a one-file conversion, not a repo sweep —
  Phase 7 is sized accordingly.
- **Both live readers already assume `{"errors": [...]}`**, so object-with-array costs zero reader
  changes. The sibling repo's live bare array is the anomaly being fixed, not a precedent.
- **Research's Context Extension Recommendation is ACCEPTED**: this plan adds
  `context/formats/errors-format.md` alongside the schema file, because the doc-block rewrites need
  a prose target for the lazy-creation semantics, the two-subcommand CLI contract, the deprecated
  `resolved` note, and the `recurrence_count` drop rationale — none of which a schema JSON can
  carry. This mirrors how `events-format.md` serves `events-schema.json`.
- **The known deploy-mechanism gap** (headless sync may not re-run `copy_scripts` for an
  already-loaded extension) is why Phase 8 verifies the file landed in `.claude/scripts/`, not
  merely that the source-store file was authored.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided in the delegation context and no `roadmap_flag` was set. Roadmap
review/update phases are therefore not included.

### Non-Dependency Note

The task description's "UNBLOCKS tasks 951/952/953" claim is not a real dependency edge — those
tasks explicitly avoid building on `errors.json` and use `event_type: system_defect` on
`events.jsonl` instead. No work is planned for them and this task's completion is not gated on
them. Tasks 954 and 955 are subsumed: 954's source-store defect lane becomes a documented `type`
value, and 955's schema-drift reconciliation IS Phase 1 of this plan.

## Goals & Non-Goals

**Goals**:
- One authoritative machine-checkable schema (`context/schemas/errors-schema.json`) plus one prose
  contract (`context/formats/errors-format.md`) as the single source of truth for the record shape.
- One writer: `scripts/errors-append.sh` with `append` and `update` subcommands, `flock`-guarded,
  hand-validated in the `events-append.sh` idiom, lazily creating the target file.
- A regression suite proving concurrent-append safety and loud off-schema rejection.
- `specs/errors.json` bootstrapped with `{"errors": []}` in this repo.
- Three doc blocks and one inline jq writer converted to point at the schema/script.
- Deploy-path wiring so the new script and schema actually reach a deployed `.claude/`.

**Non-Goals**:
- No runtime JSON-Schema-library validation (`ajv`, `python3 -m jsonschema`). Nothing in
  `core/scripts/` uses one; introducing it is out of house style.
- No cross-repo data migration. The sibling repo's live bare-array `specs/errors.json` is neither
  read nor written by this task; the `resolved` enum value exists precisely so that data stays
  schema-valid.
- No changes to `context/standards/error-handling.md`'s `.agent-logs/errors.json` block. That is a
  different path with a different shape and no writer or reader anywhere; it is outside this task's
  file scope and conflating the two would be a defect.
- No changes to `/errors` Fix Mode's git-staging block. Only the JSON-mutation step routes through
  the new script; the targeted-staging pattern stays verbatim.
- No `recurrence_count` field in the persisted schema (computed at query time — see Phase 1).
- No work on tasks 951/952/953.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The `update` read-modify-write under `flock` is novel and easy to get subtly wrong (lock dropped across the temp-file rename; validating the delta instead of the merged result) | H | M | Hold `flock` for the entire read-jq-write-`mv` sequence inside one subshell; validate the MERGED document (not the delta) before the atomic `mv`; Phase 4 adds a concurrent-update regression case, not only a concurrent-append one |
| New `scripts/*.sh` file silently fails to reach an already-deployed `.claude/scripts/` via headless sync (documented gap in `source-store-deploy-boundary.md`) | H | M | Phase 8 explicitly checks `.claude/scripts/errors-append.sh` exists and is executable post-deploy and invokes it from the deployed path; falls back to the documented one-off loader-primitive workaround if absent |
| Adopting a strict `id` regex rejects already-live records elsewhere (`err_001`-style ids) | M | M | Schema constrains `id` as a non-empty string with a documented RECOMMENDED form (`err_{timestamp_ms}_{random6}`), not an enforced pattern; the writer always emits the recommended form |
| Rewriting `commands/errors.md` Fix Mode disturbs the git-staging block | M | L | Explicit Non-Goal above; Phase 6 diff-checks that the `stage_paths` block is byte-identical after the edit |
| A doc rewrite introduces a task-number citation into a deliverable outside `specs/**` | M | M | Every deliverable phase uses durable anchors (script names, schema field names, file paths) only; Phase 8 runs `check-task-references.sh` as part of the final gate |
| An edit lands under `.claude/**` instead of `agent-system/extensions/**` and is wiped by the next deploy | H | M | Binding constraint restated in every phase's task list; Phase 8 verifies via `git status` that no hand-authored `.claude/**` file appears outside the deploy regeneration |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 6 | 1 |
| 3 | 3, 7 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 1, 4 |
| 6 | 8 | 5, 6, 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Author the reconciled schema and format contract [NOT STARTED]

**Goal**: Produce the single source of truth for the `specs/errors.json` record shape — a draft-07
JSON Schema plus a prose format document — resolving all three documented variants into one.

**Tasks**:
- [ ] Write `agent-system/extensions/core/context/schemas/errors-schema.json` (draft-07), modeled
      structurally on `context/schemas/events-schema.json`:
  - Top level: object with required `errors` (array of error records) and OPTIONAL
    `schema_version` (string). Bare array is NOT valid — see Decisions below.
  - Per-record `required`: `id`, `timestamp`, `type`, `severity`, `message`, `context`,
    `fix_status` (the 7-field intersection, promoted to the required set).
  - `id`: non-empty string. Document the RECOMMENDED form `err_{timestamp_ms}_{random6}` in the
    `description`; do NOT enforce it via `pattern`, so legacy `err_001`-style ids stay valid.
  - `timestamp`: string, `format: date-time`.
  - `type`: open non-empty string (NOT a closed enum), mirroring `events-schema.json`'s
    `event_type` openness. `description` lists the common values from `rules/error-handling.md`
    (`delegation_hang`, `timeout`, `validation_failed`, `status_sync_failure`, `file_not_found`,
    `parse_error`, `git_commit_failure`, `build_error`, `tool_unavailable`, `mcp_abort_error`,
    `delegation_interrupted`, `jq_parse_failure`) plus `source_store_defect` — the subsumed
    source-store defect lane, added here as a documented `type` value rather than a new field.
  - `severity`: closed enum `critical | high | medium | low`.
  - `message`: non-empty string.
  - `context`: object, the UNION SUPERSET of all three documented variants — `session_id`,
    `command`, `task`, `phase`, `checkpoint`, `agent`, `file` — with NONE individually required
    (no single writer populates them all). `additionalProperties: true`.
  - `trajectory`: optional object `{delegation_path: array of string, failed_at_depth: integer}`.
  - `recovery`: optional object `{suggested_action: string, auto_recoverable: boolean}`.
  - `fix_status`: closed enum `unfixed | in_progress | fixed | resolved`, with `resolved`
    documented in its `description` as a DEPRECATED synonym for `fixed`, retained only so
    already-written cross-repo data validates. The writer never emits it.
  - `fixed_date` (optional, `format: date-time`) and `fix_task` (optional, integer).
  - NO `recurrence_count`. Record the drop rationale in the schema `description` and the format doc.
- [ ] Write `agent-system/extensions/core/context/formats/errors-format.md`, modeled on
      `context/formats/events-format.md` (~150-250 lines), covering:
  - Overview + the "formal machine-checkable contract lives in
    `context/schemas/errors-schema.json`; the two must stay in sync" pointer.
  - File location (`specs/errors.json`, sibling to `events.jsonl`/`state.json`/`TODO.md`).
  - **Why object-with-array, not bare array** (explicitly required by the task): both live readers
    (`orchestrator-postflight.sh`, `hooks/events-log-artifact.sh`) already index `.errors[]` /
    `.errors[-1]`, so the object form costs zero reader changes; it admits future top-level
    metadata (`schema_version`) without a breaking shape change; the observed bare-array file
    elsewhere is the drift being corrected, not a precedent.
  - Lazy creation: the file is not pre-created in general; `errors-append.sh` creates it with
    `{"errors": []}` on first invocation in any repo. (This repo additionally bootstraps it
    eagerly — Phase 8.) Never gitignored.
  - **Mutability contrast with `events.jsonl`**: `events.jsonl` is strictly append-only; error
    records are living state mutated in place via `fix_status` transitions. This is why the writer
    has two subcommands.
  - The full `errors-append.sh` CLI contract for `append` and `update` (see Phase 2/3 for the
    exact flag lists) — this document is the contract the doc-block rewrites point at.
  - Reconciliation decisions: `recurrence_count` is computed at query time by `/errors` grouping on
    `type`, never stored; `resolved` is deprecated-but-valid; `context` is a superset with no
    required sub-fields.
- [ ] Register both files in `agent-system/extensions/core/index-entries.json`, copying the shape
      of the existing `formats/events-format.md` and `schemas/events-schema.json` entries
      (`domain: core`, matching `subdomain`, `load_when.task_types: ["meta"]`, accurate
      `line_count`, keywords, `topics: ["observability"]` / `["observability","standards"]`).
- [ ] Verify no task-number citations appear in either new file (durable anchors only).

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts a 7-field required set, a 7-key `context` superset, and a
4-value `fix_status` enum, derived from the research report's field-union table. Confirm at
implementation time by re-deriving the intersection/union directly from the three live doc blocks
(`rules/error-handling.md`'s "1. Log the Error" JSON, `commands/errors.md`'s "1. Load Error Data"
JSON, `commands/errors.md`'s "4. Update errors.json" JSON) plus `skills/skill-planner/SKILL.md`'s
inline writer, before finalizing `required`. If the re-derivation disagrees with the table, the
live files win and the divergence is recorded in the format doc.

**Files to modify**:
- `agent-system/extensions/core/context/schemas/errors-schema.json` - new, draft-07 schema
- `agent-system/extensions/core/context/formats/errors-format.md` - new, prose format contract
- `agent-system/extensions/core/index-entries.json` - two new context index entries

**Verification**:
- `jq empty agent-system/extensions/core/context/schemas/errors-schema.json` exits 0
- `jq -e '.["$schema"] == "http://json-schema.org/draft-07/schema#"'` on the schema exits 0
- `jq empty agent-system/extensions/core/index-entries.json` exits 0 and both new paths are present
- `jq -e '.properties.errors.items.required | length == 7'` on the schema exits 0
- `grep -c 'recurrence_count' context/schemas/errors-schema.json` shows it appears only in prose
  rationale (or zero times), never as a `properties` key

---

### Phase 2: Write errors-append.sh with the `append` subcommand [NOT STARTED]

**Goal**: Land the single writer script with a working `append` path — a near-direct port of
`events-append.sh`'s validated, `flock`'d, `jq -c -n`-built shape, adapted to a JSON document
(not JSON Lines) target.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/errors-append.sh`, matching the surrounding
      style in `core/scripts/` (`events-append.sh` is the model): shebang, header comment block
      with Usage / single-responsibility statement / pointer to `context/formats/errors-format.md`
      and `context/schemas/errors-schema.json` / exit codes / outputs, `set -euo pipefail`, a
      `usage()` heredoc.
- [ ] Add subcommand dispatch: first positional argument is `append` or `update`; anything else
      (including absent) exits 1 with a loud error and the usage block. `update` is stubbed in this
      phase to exit 1 with "not yet implemented" and is completed in Phase 3.
- [ ] Implement `append` argument parsing:
  - Required: `--type`, `--severity`, `--message`
  - Optional context: `--session`, `--command`, `--task`, `--phase`, `--checkpoint`, `--agent`,
    `--file`
  - Optional trajectory: `--delegation-path-json '["a","b"]'`, `--failed-at-depth N`
  - Optional recovery: `--suggested-action`, `--auto-recoverable true|false`
- [ ] Implement hand-written validation (the house idiom — NO JSON-Schema-library call), each
      failing loudly with a specific message and writing nothing:
  - Required-arg presence check.
  - `--severity` against the closed `case` enum `critical|high|medium|low`.
  - `--task`, `--phase`, `--failed-at-depth` are bare integers via bash regex.
  - `--auto-recoverable` is exactly `true` or `false`.
  - `--delegation-path-json` parses and is a JSON ARRAY (`jq -e 'type == "array"'`).
  - `--message` and `--type` are non-empty.
- [ ] Resolve `SCRIPT_DIR`/`PROJECT_ROOT` and source `deploy-root-guard.sh` immediately after,
      exactly as `events-append.sh` does, so invocation from the source store fails loudly.
- [ ] Generate `id` as `err_${timestamp_ms}_${random6}` and `timestamp` as ISO-8601 UTC, reusing
      `events-append.sh`'s `/dev/urandom` + `$RANDOM` fallback block verbatim in shape.
- [ ] Build the record via `jq -c -n --arg ...` — never string concatenation. Omit optional
      sub-objects entirely when no contributing flag was supplied (do not emit an empty
      `trajectory: {}`); emit `context` always, containing only the supplied keys.
- [ ] Lazily create `specs/errors.json` with `{"errors": []}` if absent, INSIDE the lock.
- [ ] Append under `flock -x 200` on `specs/.errors.lock` (sibling naming to `specs/.events.lock`),
      holding the lock across the entire read -> `jq '.errors += [$rec]'` -> temp-file write ->
      validate -> `mv` sequence. Validate the MERGED document parses and still has an array
      `.errors` before the `mv`; on failure, leave the original untouched and exit 1.
- [ ] Echo the new `id` to stdout; exit 0.
- [ ] `chmod +x` the script.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/errors-append.sh` - new writer script

**Verification**:
- `bash -n scripts/errors-append.sh` exits 0
- `shellcheck scripts/errors-append.sh` reports no errors (warnings triaged, matching the
  cleanliness level of `events-append.sh`)
- Invoked from a deployed tree against a scratch repo root: a valid `append` creates
  `specs/errors.json` with `{"errors":[<record>]}` and prints an `err_`-prefixed id
- An `append` with `--severity bogus` exits 1, prints a message naming the valid values, and
  leaves `specs/errors.json` byte-identical
- An `append` omitting `--message` exits 1 and writes nothing
- Invoking with no subcommand, or `errors-append.sh frobnicate`, exits 1 with the usage block

---

### Phase 3: Add the `update` subcommand (read-modify-write under lock) [NOT STARTED]

**Goal**: Implement in-place record mutation — the design deviation from `events-append.sh` that
has no precedent in `core/scripts/` — so `/errors` Fix Mode has a real implementing script.

**Tasks**:
- [ ] Implement `update` argument parsing:
  - Required: `--id ERR_ID`, `--fix-status STATUS`
  - Optional: `--fixed-date ISO8601` (defaults to now when `--fix-status fixed` is given and the
    flag is absent), `--fix-task N`
- [ ] Validate before touching the file: `--fix-status` against the closed `case` enum
      `unfixed|in_progress|fixed`. **`resolved` is schema-valid for reading but MUST be rejected as
      an input value** with a message stating it is a deprecated synonym for `fixed`; this is what
      keeps the deprecation from re-propagating. `--fix-task` is a bare integer.
- [ ] Implement the read-modify-write inside ONE `flock -x 200` subshell on the same
      `specs/.errors.lock`:
  1. Fail loudly (exit 1) if `specs/errors.json` is absent — `update` never lazily creates.
  2. Fail loudly if the document does not parse or `.errors` is not an array.
  3. Fail loudly with a distinct message if no record matches `--id` (never a silent no-op).
  4. Apply the mutation via a single `jq` expression over `.errors |= map(...)`.
  5. Write to a temp file, then **validate the MERGED result** (parses; `.errors` is an array; the
     target record still carries all 7 required fields; its `fix_status` is in the enum) BEFORE the
     atomic `mv`. On any failure, leave the original untouched and exit 1.
  6. `mv` the temp file into place — still holding the lock.
- [ ] Place the temp file next to the target (e.g. `specs/.errors.json.tmp.$$`) so the `mv` is a
      same-filesystem atomic rename, and clean it up on the failure paths.
- [ ] Echo the updated `id` to stdout; exit 0.
- [ ] Extend the header comment block and `usage()` to document both subcommands fully.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/errors-append.sh` - add the `update` subcommand

**Verification**:
- `bash -n` and `shellcheck` clean
- Against a scratch fixture: `update --id <existing> --fix-status fixed --fix-task 42` sets
  `fix_status`, `fix_task`, and a non-null `fixed_date`, and leaves every sibling record untouched
- `update --id err_nonexistent --fix-status fixed` exits 1 with a "no record matching id" message
  and leaves the file byte-identical
- `update --id <existing> --fix-status resolved` exits 1 naming the deprecation
- `update` against an absent `specs/errors.json` exits 1 and does NOT create the file
- Corrupting the fixture to a bare array causes `update` to exit 1 with a shape error, not to
  silently rewrite it

---

### Phase 4: Regression suite for concurrency and off-schema rejection [NOT STARTED]

**Goal**: Prove the two verification-bar claims mechanically — concurrent invocation does not lose
or corrupt records, and off-schema input is rejected loudly.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-errors-append.sh`, structurally
      modeled on `scripts/tests/test-phase-heading-patterns.sh`: `set -uo pipefail`,
      `pass()`/`fail()`/`info()` helpers, `PASSED`/`FAILED` integer counters, exit 0 on all-pass /
      1 on any-fail / 2 on environment error, and the same deploy-tree-first /
      source-store-fallback candidate list for locating the script under test.
- [ ] Run every case against an isolated scratch project root (`mktemp -d` with a `specs/`
      subdirectory), never against the live repo's `specs/errors.json`.
- [ ] Concurrency case (the flock test): launch N (>= 20) `append` invocations in parallel with
      `&` + `wait`, then assert `jq '.errors | length'` equals exactly N, that the document still
      parses, and that `jq '[.errors[].id] | unique | length'` also equals N (no lost or duplicated
      records).
- [ ] Concurrent-update case: seed M records, launch M parallel `update` invocations each targeting
      a distinct id, then assert all M carry `fix_status: "fixed"` and the record count is
      unchanged.
- [ ] Off-schema rejection cases, each asserting exit code 1 AND a byte-identical file afterwards:
      invalid `--severity`; missing `--message`; non-integer `--task`; malformed
      `--delegation-path-json`; `--auto-recoverable maybe`; `update --fix-status resolved`;
      `update` with an unmatched `--id`.
- [ ] Lazy-creation case: `append` against a scratch root with no `specs/errors.json` creates it
      with a valid shape.
- [ ] Shape-conformance case: assert every produced record carries all 7 required fields and that
      the top level is an object with an `errors` array (never a bare array).
- [ ] `chmod +x` the test script.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts a specific case inventory (one concurrency case, one
concurrent-update case, seven rejection cases, one lazy-creation case, one shape case). Confirm at
implementation time that each named rejection case corresponds to an actually-implemented
validation branch in `errors-append.sh`; if Phase 2/3 implemented a validation this list omits, add
a case for it rather than leaving it untested.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-errors-append.sh` - new regression suite

**Verification**:
- `bash scripts/tests/test-errors-append.sh` exits 0 with every case reported PASS
- Deliberately breaking the `--severity` enum check in a scratch copy of `errors-append.sh` makes
  the suite exit 1 (proving the suite actually discriminates, not merely passes)
- The live repo's `specs/` is unmodified after a full suite run (`git status --short specs/` clean
  of test artifacts)

---

### Phase 5: Deploy-path wiring [NOT STARTED]

**Goal**: Make the new script, schema, format doc, and test actually reach a deployed `.claude/`
tree, and gate on their presence.

**Tasks**:
- [ ] Insert `"errors-append.sh"` into `agent-system/extensions/core/manifest.json`'s
      `provides.scripts` array in correct alphabetical position — between `"deploy-root-guard.sh"`
      and `"events-append.sh"` (`err` < `eve`).
- [ ] Insert `"tests/test-errors-append.sh"` into the same array in correct position within the
      `tests/` grouping (before `tests/test-git-commit-scoped.sh`; after
      `tests/test-corroborate-phase-counts.sh`).
- [ ] Confirm no manifest change is needed for the schema or format doc: `provides.context` lists
      `"schemas"` and `"formats"` as whole-directory copy targets, so both new files are picked up
      automatically. Record this confirmation rather than assuming it.
- [ ] Extend `agent-system/extensions/core/scripts/verify-deploy.sh` gate 1's presence-check loop
      with `scripts/errors-append.sh`, `context/schemas/errors-schema.json`, and
      `context/formats/errors-format.md`. Update the gate's header comment, which currently says
      "These six are the passive-signal-capture stack" — restate it in terms of the store families
      covered rather than a bare count, so the comment does not go stale on the next addition.
- [ ] Verify the deliverable rule: no task-number citations introduced into any of these files.

**Timing**: 0.75 hours

**Depends on**: 1, 4

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exactly two `provides.scripts` insertions and exactly
three `verify-deploy.sh` gate-1 additions, and asserts that `provides.context` requires no change.
Confirm at implementation time by re-reading `provides.context` in the manifest to check that
`"schemas"` and `"formats"` are still whole-directory entries (not per-file lists); if either has
been converted to a per-file list, add the explicit entries instead.

**Files to modify**:
- `agent-system/extensions/core/manifest.json` - two `provides.scripts` entries
- `agent-system/extensions/core/scripts/verify-deploy.sh` - three gate-1 presence checks plus a
  header-comment correction

**Verification**:
- `jq empty agent-system/extensions/core/manifest.json` exits 0
- `jq -r '.provides.scripts[]' manifest.json` shows `errors-append.sh` immediately after
  `deploy-root-guard.sh`, and the array is still sorted within each grouping
- `jq -r '.provides.scripts | length' manifest.json` equals the prior count plus 2
- `bash -n scripts/verify-deploy.sh` exits 0
- `grep -c 'errors-append.sh\|errors-schema.json\|errors-format.md' scripts/verify-deploy.sh`
  returns 3

---

### Phase 6: Reconcile the three conflicting doc blocks [NOT STARTED]

**Goal**: Replace the three inline restatements of the record shape with short field summaries plus
pointers to the schema and format doc, so drift cannot recur.

**Tasks**:
- [ ] `agent-system/extensions/core/rules/error-handling.md`, the "1. Log the Error" section:
      replace the full inline JSON example with a short prose field list (the 7 required fields
      named, `context` described as a superset) plus the pointer sentence: the formal contract
      lives in `context/schemas/errors-schema.json` and the prose contract in
      `context/formats/errors-format.md`; the two must stay in sync. Replace "Record in
      errors.json:" with an instruction to call `scripts/errors-append.sh append`, showing one
      short invocation. Leave the "Session-Aware Error Aggregation" subsection and every other
      section of the file untouched.
- [ ] `agent-system/extensions/core/commands/errors.md`, "1. Load Error Data" (the read-shape
      block): replace the inline JSON with a pointer to the schema/format doc plus a one-line
      statement of the top-level shape (`{"errors": [...]}`) that a reader needs to write a `jq`
      query. Delete `recurrence_count` from the example; add a sentence to "2. Analyze Patterns"
      making explicit that recurrence is COMPUTED at analysis time by grouping on `type`, not read
      from a stored field.
- [ ] `agent-system/extensions/core/commands/errors.md`, "4. Update errors.json" (the update-shape
      block): replace the inline JSON with an `errors-append.sh update` invocation showing
      `--id`, `--fix-status fixed`, `--fix-task`. Rewrite step 3 of "3. Execute Fixes" ("Update
      error status to 'in_progress'") and step 5 ("Update error status to 'fixed'") to name the
      script as well.
- [ ] Leave "5. Git Commit" and its `stage_paths` block BYTE-IDENTICAL. Diff-check this explicitly.
- [ ] Use durable anchors only (script names, schema field names, file paths) — no task numbers, in
      keeping with the deliverable rule.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts exactly three doc blocks across exactly two files. Confirm
at implementation time with `grep -rn 'recurrence_count\|fixed_date\|fix_task'
agent-system/extensions/core/rules/ agent-system/extensions/core/commands/` — the research found
these three field names appear NOWHERE else in `core/`, so a hit outside the two named files means
a fourth block exists and the count is wrong. Record any such finding rather than silently
absorbing it.

**Files to modify**:
- `agent-system/extensions/core/rules/error-handling.md` - "1. Log the Error" block
- `agent-system/extensions/core/commands/errors.md` - "1. Load Error Data" and "4. Update
  errors.json" blocks, plus the "2. Analyze Patterns" recurrence sentence and the two step
  references in "3. Execute Fixes"

**Verification**:
- Diff read-through confirms every changed hunk lies inside prose/markdown regions
- `git diff` on `commands/errors.md` shows ZERO changes within the "5. Git Commit" section
- `grep -c 'recurrence_count' commands/errors.md` returns 0 in the schema-example position (any
  remaining occurrence is the computed-at-query-time prose)
- Both files reference `context/schemas/errors-schema.json` and `context/formats/errors-format.md`
- `bash .claude/scripts/check-task-references.sh` reports no new findings in either file

---

### Phase 7: Convert the one inline jq writer [NOT STARTED]

**Goal**: Eliminate the sole live `.errors += [...]` inline write so `errors-append.sh` is the only
writer, satisfying the verification bar's grep sweep.

**Tasks**:
- [ ] In `agent-system/extensions/core/skills/skill-planner/SKILL.md`, the "jq Parse Failure"
      recovery block: replace the `jq '.errors += [{...}]' specs/errors.json > specs/tmp/errors.json
      && mv` pipeline with an equivalent single `scripts/errors-append.sh append` invocation
      carrying the same payload — `--type jq_parse_failure`, `--severity medium`,
      `--message "jq parse error in postflight artifact linking"`, `--session "$session_id"`,
      `--command /plan`, `--task "$task_number"`, `--checkpoint GATE_OUT`,
      `--suggested-action "Use two-step jq pattern from jq-escaping-workarounds.md"`,
      `--auto-recoverable true`.
- [ ] Leave step 2 ("Retry with two-step pattern") and the surrounding "Subagent Timeout" and "Git
      Commit Failure" subsections untouched.
- [ ] Re-run the verification-bar grep across the whole core extension to confirm zero remaining
      inline writers.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts that exactly ONE inline `.errors +=` writer exists in
`agent-system/extensions/core/`. Confirm at implementation time by re-running
`grep -rn '\.errors *+=' agent-system/extensions/core/` BEFORE editing; if the count is not 1,
convert every hit found and record the corrected count. Also widen the sweep once to
`grep -rn '\.errors *+=' agent-system/extensions/` (all extensions, not just core) and record
whether any non-core extension has its own inline writer — the verification bar names core only,
so a non-core hit is reported, not silently fixed.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-planner/SKILL.md` - "jq Parse Failure" recovery block

**Verification**:
- `grep -rn '\.errors *+=' agent-system/extensions/core/` returns ZERO hits
- `grep -rn 'specs/tmp/errors.json' agent-system/extensions/core/` returns zero hits
- Diff read-through confirms the change is confined to the one fenced code block

---

### Phase 8: Bootstrap, deploy, and end-to-end verification [NOT STARTED]

**Goal**: Create the runtime artifact, regenerate the deploy tree, and prove the whole lane works
from the deployed path with no silent degradation.

**Tasks**:
- [ ] Create `specs/errors.json` in this repo with exactly `{"errors": []}`. This is a `specs/**`
      RUNTIME artifact, NOT a deploy artifact — it is authored directly here and has no
      manifest/source-store counterpart.
- [ ] Confirm `specs/errors.json` is not gitignored and will be tracked.
- [ ] Regenerate the deploy tree via `bash .claude/scripts/deploy-headless.sh`. Do NOT hand-author
      anything under `.claude/**`.
- [ ] Verify the known deploy-mechanism gap did not bite: confirm `.claude/scripts/errors-append.sh`
      exists AND is executable, `.claude/scripts/tests/test-errors-append.sh` exists,
      `.claude/context/schemas/errors-schema.json` exists, and
      `.claude/context/formats/errors-format.md` exists. If any is missing, apply the documented
      one-off loader-primitive workaround (per `rules/source-store-deploy-boundary.md`'s "Known
      gap") and re-verify — do not proceed on a partial deploy.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` and confirm gate 1 passes with the three new
      entries.
- [ ] Run `bash .claude/scripts/tests/test-errors-append.sh` from the DEPLOYED path and confirm
      exit 0.
- [ ] End-to-end `/errors` check against the live `specs/errors.json`: confirm it loads the file
      and reports zero errors as a real empty result, NOT as the `[ -f ]`-guard silent-degradation
      path. Then append one throwaway record via the deployed `errors-append.sh`, re-run the
      `/errors` load step, confirm the record is seen, and `update` it to `fixed` — then remove the
      throwaway record so the committed `specs/errors.json` is left as `{"errors": []}`.
- [ ] Confirm the two live readers work against the real file: `orchestrator-postflight.sh`'s
      `error_ref` query (`jq '[.errors[]? | select(.context.session_id == $sid)] | ... | .id'`)
      returns cleanly, and `hooks/events-log-artifact.sh`'s `.errors[-1].context.session_id` read
      resolves against a seeded record.
- [ ] Run the final gate set: `bash .claude/scripts/check-task-references.sh` (no new findings),
      `bash .claude/scripts/check-extension-docs.sh`, and the verification-bar grep
      `grep -rn '\.errors *+=' agent-system/extensions/core/` (zero hits).
- [ ] Confirm via `git status --short` that no hand-authored file appeared under `.claude/**`
      outside the deploy regeneration.

**Timing**: 1.25 hours

**Depends on**: 5, 6, 7

**Verification Tier**: full

**Files to modify**:
- `specs/errors.json` - new runtime artifact, `{"errors": []}`
- (`.claude/**` is regenerated by `deploy-headless.sh`, never hand-authored)

**Verification**:
- `jq -e '.errors | type == "array" and length == 0' specs/errors.json` exits 0
- `test -x .claude/scripts/errors-append.sh` exits 0
- `bash .claude/scripts/verify-deploy.sh` exits 0 with gate 1 passing all nine entries
- `bash .claude/scripts/tests/test-errors-append.sh` exits 0
- `/errors` completes without emitting a "file not found / skipping" degradation path
- `grep -rn '\.errors *+=' agent-system/extensions/core/` returns zero hits
- `bash .claude/scripts/check-task-references.sh` exits 0

---

## Testing & Validation

- [ ] `jq empty` passes on `errors-schema.json`, `manifest.json`, `index-entries.json`, and
      `specs/errors.json`
- [ ] `bash -n` and `shellcheck` clean on `errors-append.sh`, `test-errors-append.sh`, and
      `verify-deploy.sh`
- [ ] `test-errors-append.sh` exits 0 from both the source-store path and the deployed path
- [ ] Concurrency: >= 20 parallel `append` invocations yield exactly 20 unique records in a
      still-parsing document
- [ ] Concurrency: parallel `update` invocations on distinct ids all land, with an unchanged record
      count
- [ ] Loud rejection: every off-schema input case exits 1 AND leaves the target file byte-identical
- [ ] `update` against an unmatched `--id` exits 1 rather than silently no-op'ing
- [ ] `update --fix-status resolved` is rejected (deprecation does not re-propagate)
- [ ] Lazy creation works in a repo with no pre-existing `specs/errors.json`
- [ ] `verify-deploy.sh` gate 1 passes with all three new presence checks
- [ ] `/errors` runs end-to-end against the real `specs/errors.json` with no silent degradation
- [ ] Both live readers resolve against a seeded record
- [ ] `grep -rn '\.errors *+=' agent-system/extensions/core/` returns zero hits
- [ ] `check-task-references.sh` reports no new findings
- [ ] `check-extension-docs.sh` passes
- [ ] `git status --short` shows no hand-authored `.claude/**` file outside deploy regeneration

## Artifacts & Outputs

**New files**:
- `agent-system/extensions/core/context/schemas/errors-schema.json`
- `agent-system/extensions/core/context/formats/errors-format.md`
- `agent-system/extensions/core/scripts/errors-append.sh`
- `agent-system/extensions/core/scripts/tests/test-errors-append.sh`
- `specs/errors.json` (runtime artifact, `{"errors": []}`)

**Modified files**:
- `agent-system/extensions/core/index-entries.json`
- `agent-system/extensions/core/manifest.json`
- `agent-system/extensions/core/scripts/verify-deploy.sh`
- `agent-system/extensions/core/rules/error-handling.md`
- `agent-system/extensions/core/commands/errors.md`
- `agent-system/extensions/core/skills/skill-planner/SKILL.md`

**Regenerated (never hand-authored)**:
- `.claude/**` via `deploy-headless.sh`

**Task artifacts**:
- `specs/979_bootstrap_errors_json_lane/plans/01_errors-json-lane-bootstrap.md` (this file)
- `specs/979_bootstrap_errors_json_lane/summaries/01_errors-json-lane-bootstrap-summary.md`

## Rollback/Contingency

All source-store changes are additive or confined to well-scoped blocks, so rollback is a
per-phase `git revert` of that phase's commit. Specific contingencies:

- **`update` proves unreliable under concurrency** (Phase 3/4): ship `append` alone as a green
  milestone, mark Phase 3 `[PARTIAL]`, and leave `commands/errors.md`'s Fix Mode pointing at the
  existing inline pattern until `update` passes. `append` is independently valuable and Phase 7's
  writer conversion only needs `append`.
- **Deploy does not pick up the new script** (Phase 8): the documented loader-primitive workaround
  is the first fallback. If it also fails, leave the source-store files committed, mark Phase 8
  `[BLOCKED]` naming the loader gap, and do NOT hand-author `.claude/scripts/errors-append.sh` — a
  hand-authored deploy file is wiped by the next regeneration and would create a false green.
- **A doc rewrite breaks a downstream consumer**: the three doc blocks are prose-only and
  independently revertible; reverting Phase 6 restores the prior (inconsistent but working)
  documentation without affecting the script or schema.
- **`specs/errors.json` bootstrap causes an unexpected hook cascade** (the `events-log-artifact.sh`
  PostToolUse hook fires on writes to this path): the hook already tolerates an empty
  `.errors[-1]` read and emits nothing; if it misbehaves, delete `specs/errors.json` to restore the
  prior lazy-creation-only state — no other change is required to recover.

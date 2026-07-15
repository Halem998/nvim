# Implementation Plan: Unified event/reflection JSONL store + schema + reader API

- **Task**: 869 - Unified event/reflection JSONL store + schema + reader API
- **Status**: [NOT STARTED]
- **Effort**: 4.5 hours
- **Dependencies**: None (foundational contract for downstream tasks 870, 871, 872)
- **Research Inputs**: reports/01_event-store-schema-design.md
- **Artifacts**: plans/01_event-store-plumbing.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build the append-only JSONL event store plumbing under `agent-system/extensions/core/`: a
documented schema (`context/formats/events-format.md`), a formal JSON Schema
(`context/schemas/events-schema.json`), a shared append helper (`scripts/events-append.sh`), and a
shared query/reader helper (`scripts/events-query.sh`). The store file `specs/events.jsonl` is
created lazily on first append (mirroring `errors.json`) and never gitignored. This task implements
only the store plumbing and its documented format -- no agent-behavioral capture (tasks 870/871)
and no distillation consumer (task 872). The sync-surface files `manifest.json`,
`index-entries.json`, and `EXTENSION.md` are kept in sync; `CLAUDE.md` is auto-generated and is
never hand-edited.

### Research Integration

The plan follows report `01_event-store-schema-design.md` directly:
- Store path `specs/events.jsonl`, lazily created, never gitignored (mirrors `errors.json`).
- Per-line event schema with required `event_id`, `event_type`, `category`, `timestamp`,
  `session_id`, `message`; nullable `duration_seconds`, `task`, `checkpoint`, `detail`,
  `error_ref`.
- `category` is a closed 4-value enum (`deviation|blocker|milestone|success`); `event_type` and
  `checkpoint` are open/extensible strings with documented common values; `detail` is an open
  object -- so downstream tasks can extend without a schema-breaking revision.
- Two scripts mirroring the `memory-harvest.sh` (write) / `memory-retrieve.sh` (read) verb-pairing.
- `events-append.sh` builds each line via `jq -c -n` (never string concatenation) and guards the
  append with `flock` on `specs/.events.lock` (defense-in-depth beyond POSIX small-write atomicity).
- Both scripts tolerate `specs/events.jsonl` and `specs/errors.json` being absent (exit 0, empty
  result); `error_ref` is always an optional cross-link, never a hard foreign key.
- `duration_seconds` (not `duration_ms`) matches the `return-metadata-file.md` convention.
- Source of truth is `agent-system/extensions/core/`; propagation to `.claude/` / `.opencode/` is a
  separate, pre-existing sync mechanism and is out of scope.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided and no ROADMAP.md consulted. The task's own `topic`
("memory-improvement-loop") sequences this as the foundational contract before tasks 870-872.

## Goals & Non-Goals

**Goals**:
- Document the `specs/events.jsonl` line schema and its lazy-creation/cross-link conventions in a
  new `context/formats/events-format.md`.
- Formalize a single event line as a draft-07 JSON Schema in `context/schemas/events-schema.json`,
  in the style of the existing `schemas/frontmatter-schema.json`.
- Ship `scripts/events-append.sh`: a single-responsibility, `jq`-built, `flock`-guarded append
  helper with a documented CLI interface.
- Ship `scripts/events-query.sh`: a shared reader/filter/aggregate helper that tolerates an absent
  store and supports `--format jsonl|json-array|summary-counts`.
- Keep `manifest.json`, `index-entries.json`, and `EXTENSION.md` in sync with the two new scripts
  and two new context files.

**Non-Goals**:
- No hook-based automatic lifecycle logging (task 870).
- No completion-time reflection capture (task 871).
- No `/distill` dream-mode consumer (task 872).
- No log rotation/archival strategy for `specs/events.jsonl` (flagged for a future task).
- No edits to `.claude/extensions/core/` or `.opencode/` (separate sync mechanism).
- No hand-editing of the generated `CLAUDE.md`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Concurrent-writer corruption of `events.jsonl` | H | L | Build line via `jq -c -n` into a variable, single `printf ... >>` append, wrapped in `flock` on `specs/.events.lock`. |
| Scripts assume `errors.json`/`events.jsonl` exist and crash on lazy absence | M | M | Both helpers explicitly handle missing files (append creates lazily; query returns empty set, exit 0). `error_ref` never treated as a required FK. |
| Schema over-fitting blocks downstream tasks 870-872 | M | M | Keep `event_type`/`checkpoint` open strings and `detail` an open object; only `category` is a closed enum. |
| Sync-file drift (stale counts/entries) | M | M | Compute the true post-edit script count from `manifest.json` at implementation time rather than trusting the stale EXTENSION.md "27"; add index-entries for both new context files; verify `manifest.json` and `index-entries.json` stay valid JSON. |
| JSON-escaping bugs from hand-built lines | M | L | Never string-concatenate JSON; always `jq -c -n --arg/--argjson`. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Author schema doc and JSON Schema [COMPLETED]

**Goal**: Define the authoritative contract -- the documented event-line format and its formal
JSON Schema -- that both helper scripts and all downstream consumers build on.

**Tasks**:
- [x] Create `agent-system/extensions/core/context/formats/events-format.md` documenting: store
      path `specs/events.jsonl`, lazy-creation and never-gitignored convention, one-compact-JSON-
      object-per-line rule (`jq -c`), the full field table (from the research report), the
      `category` closed enum, the `event_type`/`checkpoint` open-string common-values tables, the
      `detail` open-object contract, and the optional `error_ref` cross-link to `errors.json`
      (always optional, never a hard FK). Follow the style of existing `formats/*.md` docs
      (e.g. `handoff-artifact.md`, `return-metadata-file.md`). *(completed)*
- [x] Create `agent-system/extensions/core/context/schemas/events-schema.json` as a draft-07 JSON
      Schema for a single event line: required `event_id`, `event_type`, `category`, `timestamp`,
      `session_id`, `message`; optional/nullable `duration_seconds`, `task`, `checkpoint`,
      `detail`, `error_ref`. `category` constrained via `enum`; `detail` as an open object
      (`"type": "object"` with `additionalProperties: true`). Match the style of the existing
      `schemas/frontmatter-schema.json`. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/context/formats/events-format.md` - new documented schema
- `agent-system/extensions/core/context/schemas/events-schema.json` - new draft-07 JSON Schema

**Verification**:
- `jq . events-schema.json` parses without error.
- The field table in `events-format.md` matches the schema's required/optional fields exactly.
- `category` enum lists exactly `deviation`, `blocker`, `milestone`, `success`.

---

### Phase 2: Implement events-append.sh (write helper) [COMPLETED]

**Goal**: Ship the single-responsibility append helper that validates and atomically appends one
event line, creating the store lazily on first use.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/events-append.sh` with the CLI:
      `--event-type TYPE --category CAT --session SESSION_ID [--task N] [--checkpoint NAME]
      [--duration SECONDS] --message "..." [--detail-json '{...}'] [--error-ref ERR_ID]`.
      *(completed)*
- [x] Generate `event_id` as `evt_{timestamp_ms}_{random6}` and `timestamp` as ISO 8601.
      *(completed)*
- [x] Build the line via `jq -c -n --arg/--argjson ...` into a variable (never string
      concatenation); validate `--category` against the closed enum and fail loudly on an invalid
      value; parse `--detail-json` via `--argjson` so malformed JSON fails before any write.
      *(completed: also fixed a bash parameter-expansion default-value bug and a SIGPIPE-under-pipefail bug found during verification)*
- [x] Resolve the store path (`specs/events.jsonl`) relative to repo root; create it lazily if
      absent; append with a single `printf '%s\n' "$line" >> "$EVENTS_FILE"` wrapped in `flock` on
      `specs/.events.lock`. *(completed)*
- [x] `chmod +x` the script; follow existing script conventions (`set -euo pipefail`, header
      comment, usage function) modeled on `memory-harvest.sh`. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/scripts/events-append.sh` - new append helper

**Verification**:
- One invocation with all required flags creates `specs/events.jsonl` and appends one valid line;
  `jq . specs/events.jsonl` parses each line.
- Invalid `--category` exits non-zero with a clear message and writes nothing.
- Malformed `--detail-json` exits non-zero before appending.
- Two rapid invocations produce exactly two well-formed lines (no interleaving).

---

### Phase 3: Implement events-query.sh (read helper) [COMPLETED]

**Goal**: Ship the shared reader so every consumer uses identical, tested `jq` filter syntax
instead of ad hoc one-liners.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/events-query.sh` with the CLI:
      `[--session ID] [--task N] [--category CAT] [--event-type TYPE] [--checkpoint NAME]
      [--since ISO8601] [--until ISO8601] [--format jsonl|json-array|summary-counts]`.
      *(completed)*
- [x] Implement filtering over the JSONL stream using native `jq` (no `--slurp` for line
      filtering); `--format json-array` collects into an array; `--format summary-counts` emits
      counts grouped by `category` and `event_type` (modeled on the `distill-log.json` summary
      rollup shape). *(completed)*
- [x] Tolerate an absent `specs/events.jsonl`: return an empty result set and exit 0 (never error).
      *(completed)*
- [x] `chmod +x`; follow existing script conventions modeled on `memory-retrieve.sh`. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/scripts/events-query.sh` - new query helper

**Verification**:
- Query against a non-existent store exits 0 with empty output.
- Filters (`--category`, `--session`, `--event-type`, date range) return only matching lines.
- `--format json-array` emits valid JSON parseable by `jq .`.
- `--format summary-counts` emits the expected per-category / per-event-type counts.

---

### Phase 4: Sync manifest.json, index-entries.json, and EXTENSION.md [COMPLETED]

**Goal**: Register the two new scripts and two new context files across the extension's
sync-surface files, keeping counts and discovery metadata accurate.

**Tasks**:
- [x] `agent-system/extensions/core/manifest.json`: add `"events-append.sh"` and
      `"events-query.sh"` to `provides.scripts`. No change to `provides.context` (the `"formats"`
      and `"schemas"` whole-directory entries already cover the two new files). *(completed:
      inserted alphabetically between "command-route-skill.sh" and "export-to-markdown.sh";
      true count is 52, not the 50 the research report observed -- two more scripts landed
      between the research pass and this implementation pass)*
- [x] `agent-system/extensions/core/index-entries.json`: add two per-file entries -- one for
      `formats/events-format.md`, one for `schemas/events-schema.json` -- matching the shape of
      existing entries (`domain: "core"`, `subdomain: "formats"`/`"schemas"`, `line_count`,
      `keywords`, `topics`, and a `load_when` block). Set a real `line_count` from the authored
      files. *(completed: positioned alphabetically within the formats/schemas blocks;
      line_count 140/70 respectively)*
- [x] `agent-system/extensions/core/EXTENSION.md`: update the `scripts` count row to the true
      post-edit `provides.scripts` count (compute from `manifest.json`; the current "27" is
      pre-existing drift), and add one "Key Capabilities" bullet describing the unified event store.
      *(completed: count corrected to 52)*

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Files to modify**:
- `agent-system/extensions/core/manifest.json` - add 2 script entries
- `agent-system/extensions/core/index-entries.json` - add 2 discovery entries
- `agent-system/extensions/core/EXTENSION.md` - correct scripts count, add capability bullet

**Verification**:
- `jq . manifest.json` and `jq . index-entries.json` parse without error.
- `provides.scripts` contains both new script names exactly once each.
- `index-entries.json` has exactly two new entries with correct paths and non-null `line_count`.
- EXTENSION.md scripts count equals `jq '.provides.scripts | length' manifest.json`.

---

### Phase 5: End-to-end verification [NOT STARTED]

**Goal**: Confirm the append/query round-trip works and all sync files remain valid.

**Tasks**:
- [ ] Run an append -> query round-trip: append 2-3 varied events (different `category`,
      one with `--detail-json`, one with `--error-ref`, one point-event with no `--duration`), then
      query them back by `--session`, by `--category`, and with `--format summary-counts`.
- [ ] Confirm lazy creation: delete any test `specs/events.jsonl`, run one append, verify the file
      is created and gitignore status is unchanged (not ignored).
- [ ] Confirm graceful absence: with no store present, `events-query.sh` exits 0 and emits empty.
- [ ] Validate every appended line against `events-schema.json` (e.g. via a `jq`-based required-key
      check, since no JSON Schema validator is assumed installed).
- [ ] Re-validate `manifest.json`, `index-entries.json` as JSON and confirm EXTENSION.md count.
- [ ] Remove any throwaway test lines from `specs/events.jsonl` so the store is left clean (or
      leave it absent if only test events were written).

**Timing**: 0.5 hours

**Depends on**: 4

**Files to modify**:
- None (verification only; clean up any test artifacts in `specs/events.jsonl`)

**Verification**:
- Round-trip append/query returns the exact events written.
- Each appended line satisfies the required-key contract from `events-schema.json`.
- All three sync files parse/validate and counts are consistent.

---

## Testing & Validation

- [ ] `jq . events-schema.json` parses; `category` enum is exactly the four values.
- [ ] `events-append.sh` creates `specs/events.jsonl` lazily and appends valid compact JSON lines.
- [ ] Invalid `--category` and malformed `--detail-json` both fail before writing.
- [ ] Concurrent/rapid appends produce non-interleaved, individually valid lines.
- [ ] `events-query.sh` filters correctly and tolerates an absent store (exit 0, empty).
- [ ] `--format json-array` and `--format summary-counts` produce valid, expected output.
- [ ] `manifest.json` and `index-entries.json` remain valid JSON; both new scripts registered.
- [ ] EXTENSION.md scripts count matches `provides.scripts` length.

## Artifacts & Outputs

- `agent-system/extensions/core/context/formats/events-format.md` (new)
- `agent-system/extensions/core/context/schemas/events-schema.json` (new)
- `agent-system/extensions/core/scripts/events-append.sh` (new)
- `agent-system/extensions/core/scripts/events-query.sh` (new)
- `agent-system/extensions/core/manifest.json` (edited)
- `agent-system/extensions/core/index-entries.json` (edited)
- `agent-system/extensions/core/EXTENSION.md` (edited)
- `specs/869_unified_event_reflection_store/summaries/01_event-store-plumbing-summary.md` (on completion)

## Rollback/Contingency

All changes are additive under `agent-system/extensions/core/` plus three edited sync files. To
revert: delete the two new scripts and two new context files, and `git checkout` the three edited
sync files (`manifest.json`, `index-entries.json`, `EXTENSION.md`). `specs/events.jsonl` is a
lazily-created runtime artifact; if only test events were written during verification, delete the
file to restore the pre-task state. No downstream consumers exist yet (tasks 870-872 are not
implemented), so removal is non-breaking.

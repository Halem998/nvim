# Implementation Summary: Task #869

**Completed**: 2026-07-15
**Duration**: ~20 minutes

## Overview

Built the append-only JSONL event/reflection store plumbing under
`agent-system/extensions/core/`: a documented schema, a formal JSON Schema, a `flock`-guarded
append helper, and a filter/aggregate query helper, with all sync-surface files
(`manifest.json`, `index-entries.json`, `EXTENSION.md`) kept in sync. This implements only the
store plumbing and its documented contract -- no hook-based automatic logging, no completion-time
reflection capture, and no `/distill` consumer, all of which are out of scope for this task.

## What Changed

- `agent-system/extensions/core/context/formats/events-format.md` -- New documented schema for
  `specs/events.jsonl`: store location, lazy-creation/never-gitignored convention, the
  one-compact-JSON-object-per-line rule, the full field table, the `category` closed enum, the
  `event_type`/`checkpoint` open-string common-values tables, the `detail` open-object contract,
  and the `error_ref` cross-link contract to `errors.json`.
- `agent-system/extensions/core/context/schemas/events-schema.json` -- New draft-07 JSON Schema
  formalizing the same contract (required `event_id`/`event_type`/`category`/`timestamp`/
  `session_id`/`message`; nullable `duration_seconds`/`task`/`checkpoint`/`detail`/`error_ref`),
  in the style of the existing `frontmatter-schema.json`.
- `agent-system/extensions/core/scripts/events-append.sh` -- New executable append helper.
  Validates `--category` against the closed enum and `--detail-json` as valid JSON before any
  write; builds each line via `jq -c -n` (never string concatenation); appends via a single
  `printf >> file` write guarded by `flock` on `specs/.events.lock`; creates `specs/events.jsonl`
  lazily on first use.
- `agent-system/extensions/core/scripts/events-query.sh` -- New executable query helper.
  Filters the JSONL stream natively (no `--slurp` for the filtering step) by `--session`,
  `--task`, `--category`, `--event-type`, `--checkpoint`, `--since`/`--until`; supports
  `--format jsonl|json-array|summary-counts`; tolerates an absent store (empty result, exit 0).
- `agent-system/extensions/core/manifest.json` -- Added `events-append.sh` and
  `events-query.sh` to `provides.scripts` (52 total, up from 50).
- `agent-system/extensions/core/index-entries.json` -- Added two discovery entries
  (`formats/events-format.md`, `schemas/events-schema.json`), positioned alphabetically within
  their existing subdomain blocks.
- `agent-system/extensions/core/EXTENSION.md` -- Corrected the `scripts` count row (27 -> 52,
  pre-existing drift) and added a "Unified Event Store" Key Capabilities bullet.

## Decisions

- `category` is a closed 4-value enum (`deviation|blocker|milestone|success`); `event_type` and
  `checkpoint` remain open, documented strings so future instrumentation can add values without a
  schema-breaking revision.
- `duration_seconds` (not `duration_ms`), matching the existing `return-metadata-file.md`
  convention.
- Two single-responsibility scripts (append / query), mirroring the existing
  `memory-harvest.sh`/`memory-retrieve.sh` verb-pairing.
- `error_ref` is always optional, never a hard foreign key -- both scripts work correctly whether
  or not `specs/errors.json` exists.

## Plan Deviations

- **Task 5.1** altered: the append/query round-trip verification was run against a temporary,
  untracked local scripts harness at repo-root depth rather than directly invoking the scripts
  from their `agent-system/extensions/core/scripts/` source location. Reason: both scripts
  resolve `PROJECT_ROOT` via `SCRIPT_DIR/../..` (the same convention `memory-harvest.sh` already
  uses), which is correct only at the scripts' eventual `.claude/scripts/` deployment depth, not
  at their three-deep source location. The harness was deleted after verification; no file under
  `.claude/` or `.opencode/` was read, created, or modified.

Two implementation bugs were found and fixed during Phase 2 verification (not deviations from the
plan's intent, but worth recording): a `set -o pipefail` + SIGPIPE interaction in the random-ID
generation pipeline, and a bash parameter-expansion default-value bug in the `--detail-json`
handling (`${var:-{}}` corrupts non-empty values). Both are fixed in the committed script and
covered by the verification run.

## Verification

- Build: N/A (shell scripts + JSON/Markdown, no build step)
- Tests: Passed -- full Phase 1-5 verification criteria all confirmed: `jq . events-schema.json`
  parses; category enum is exactly the four values; append creates the store lazily and produces
  valid compact JSON lines; invalid `--category` and malformed `--detail-json` both fail before
  any write; two rapid invocations produced non-interleaved, individually valid lines; all
  `--format` modes and all filters work correctly; an absent store returns empty results and
  exits 0 for every format; `manifest.json`/`index-entries.json` remain valid JSON with exactly
  the expected new entries; `EXTENSION.md`'s scripts count (52) matches
  `provides.scripts | length`.
- Files verified: Yes

## Notes

- `specs/events.jsonl` was intentionally left absent after verification, matching its pre-task
  lazily-created state -- only throwaway test events were written, and they were removed.
- No rotation/archival strategy exists for `specs/events.jsonl`; this is a known, explicitly
  out-of-scope gap flagged in the research report for a future task.
- No downstream consumers exist yet (automatic hook-based logging, completion-time reflection
  capture, and a `/distill` dream-mode reader are separate, not-yet-implemented tasks); this task
  is pure plumbing and is non-breaking to remove if ever needed.

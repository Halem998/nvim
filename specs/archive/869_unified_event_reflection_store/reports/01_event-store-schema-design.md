# Research Report: Task #869

**Task**: 869 - Unified event/reflection JSONL store + schema + reader API
**Started**: 2026-07-15T00:00:00Z
**Completed**: 2026-07-15T00:00:00Z
**Effort**: Small-medium (schema doc + 2 scripts + sync-file edits)
**Dependencies**: None (this task is the foundational contract for tasks 870, 871, 872)
**Sources/Inputs**: Codebase exploration only (agent-system/extensions/core/, specs/state.json,
specs/TODO.md) — no web research needed, this is a purely internal-convention design task.
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- No prior art for a unified event store exists in this codebase — `specs/errors.json` is the
  closest analog (also lazily created, never gitignored, becomes tracked once written) but is a
  mutable `{errors: [...]}` array, not an append-only log. `.memory/distill-log.json` is the
  closest *shape* precedent for an operations log with a summary rollup.
- The source of truth for this extension is `agent-system/extensions/core/` (NOT `.claude/extensions/core/`,
  which is a synced deployment copy with no scripts/context dirs of its own — confirmed empty).
  All file_scope edits belong under `agent-system/extensions/core/...`; propagation to `.claude/`
  and `.opencode/` is a separate, already-existing sync mechanism (see task 868's precedent commit,
  which touched only `agent-system/extensions/literature/...`) and is out of scope for this task.
- Recommended store path: `specs/events.jsonl` (repo root `specs/`, sibling to `errors.json`,
  `state.json`, `TODO.md`), lazily created on first append, never gitignored (same convention as
  `errors.json`).
- JSONL is natively `jq`-streamable with no `-s`/`--slurp` needed for line-by-line filtering,
  which is exactly what "so no subsystem hand-rolls jq" wants a shared script to wrap.
- Recommend two new scripts: `events-append.sh` (single responsibility: validate + append one
  event) and `events-query.sh` (filter/aggregate reader), mirroring the existing
  `memory-harvest.sh` (write) / `memory-retrieve.sh` (read) verb-pairing convention.
- `checkpoint` should reuse the four existing `skill-base.sh` lifecycle stage names
  (`preflight`, `context_injection`, `verification`, `postflight`) plus the two
  `command-gate-in.sh`/`command-gate-out.sh` checkpoint names (`GATE_IN`, `GATE_OUT`) plus
  phase markers (`phase_{N}`) — documented as an open/extensible string, not a closed enum,
  since task 870's hook instrumentation and task 871's completion-seam write will both need to
  add checkpoint values this task cannot fully anticipate.

## Context & Scope

Task 869 is explicitly scoped to **plumbing only**: the JSONL file format, its schema, and two
shared helper scripts. It must NOT implement any of:
- The hook-based automatic lifecycle logging (task 870)
- The completion-time reflection capture (task 871)
- The `/distill` dream-mode consumer (task 872)

This report designs the contract those three tasks will build on, informed by reading their full
task descriptions from `specs/state.json` (870/871/872) to ensure the schema anticipates their
actual field needs without over-fitting to any one of them.

## Findings

### Codebase Patterns

**Directory structure** (confirmed via `find`):
```
agent-system/extensions/core/
├── EXTENSION.md              # counts table + capability bullets (task must update)
├── manifest.json             # provides.scripts array (task must add 2 entries);
│                              # provides.context already declares "formats" and "schemas"
│                              # as whole-directory entries, so new files under those dirs
│                              # need NO manifest.json change themselves
├── index-entries.json        # per-file discovery metadata for context/formats/ and
│                              # context/schemas/ (task must add 2 new entries)
├── scripts/                  # 47 scripts currently listed in manifest.provides.scripts
│                              # (EXTENSION.md's "27" count is already stale/drifted —
│                              # pre-existing drift, not introduced by this task, but worth
│                              # fixing the true count while editing that table)
└── context/
    ├── formats/               # 13 existing format specs (return-metadata-file.md,
    │                          # handoff-artifact.md, subagent-return.md, etc.) — each has
    │                          # a matching index-entries.json entry
    └── schemas/               # 2 existing JSON/YAML schema files (frontmatter-schema.json,
                                # subagent-frontmatter.yaml) — also individually indexed
```

**`.claude/extensions/core/` vs `agent-system/extensions/core/`**: `.claude/extensions/core/`
contains only `manifest.json` — no `scripts/`, `context/`, `EXTENSION.md`, etc. The real,
editable source tree lives under `agent-system/extensions/core/` and is synced outward. This
matches the file_scope given for task 869 exactly (`agent-system/extensions/core/scripts/`, etc.)
and matches the immediately-preceding task 868's implementation (touched only
`agent-system/extensions/literature/...`, never `.claude/extensions/literature/...`).

**`errors.json` schema and conventions** (from `agent-system/extensions/core/rules/error-handling.md`
and `agent-system/extensions/core/commands/errors.md` — these two are the authoritative,
currently-used spec; a third doc, `context/standards/error-handling.md`, contains a stale/inconsistent
alternate schema at `.agent-logs/errors.json` that does not match actual usage and should not be
treated as authoritative):

```json
{
  "id": "err_{timestamp}",
  "timestamp": "ISO_DATE",
  "type": "delegation_hang|timeout|build_error|...",
  "severity": "critical|high|medium|low",
  "message": "Error description",
  "context": {
    "session_id": "sess_1736700000_abc123",
    "command": "/implement",
    "task": 259,
    "phase": 2,
    "checkpoint": "GATE_OUT"
  },
  "trajectory": {
    "delegation_path": ["orchestrator", "implement", "skill-implementer", "general-implementation-agent"],
    "failed_at_depth": 3
  },
  "recovery": { "suggested_action": "...", "auto_recoverable": true },
  "fix_status": "unfixed"
}
```

Confirmed empirically: `specs/errors.json` does **not** currently exist on disk in this repo and is
**not** gitignored — it is created lazily on first error and then tracked normally. This is the
precedent task 869 explicitly asks to mirror for `specs/events.jsonl`.

Key reusable conventions from this schema (per the task description's "reuse the errors.json
entry-schema conventions and the shared session_id/task cross-link keys"):
- `context.session_id` (format `sess_{timestamp}_{random}`, generated at GATE IN)
- `context.task` (bare integer project number — matches `state.json`'s `project_number`, NOT the
  zero-padded directory name)
- `context.checkpoint` (a string naming the lifecycle point, e.g. `"GATE_OUT"`)
- `fix_status`/`recovery` style forward-looking fields are errors.json-specific and should NOT be
  copied verbatim into the events schema — events are append-only observations, not mutable
  tickets, so there is no "unfixed -> fixed" transition to track.

**Lifecycle checkpoint vocabulary** (from `agent-system/extensions/core/scripts/skill-base.sh` and
`command-gate-in.sh`/`command-gate-out.sh`): the four skill-base.sh stage functions are literally
named `preflight`, `context_injection`, `verification`, `postflight` (used as the `hook_name`
argument to `skill_run_extension_hook`), and the two command-level checkpoints are `GATE_IN` /
`GATE_OUT` per `command-gate-in.sh`'s own header comment ("CHECKPOINT 1: Session generation, task
lookup..."). Task 870's description explicitly says it will instrument "the four skill-base.sh
lifecycle stage functions (preflight/context_injection/verification/postflight)" — so the event
schema's `checkpoint` field must accept exactly these four strings plus `GATE_IN`/`GATE_OUT` plus
free-form phase markers (`phase_1`, `phase_2`, ...) used during `/implement`. Recommendation:
document `checkpoint` as an **open string** with a documented common-values table, not a closed
enum — a closed enum would need revising the moment task 870 or 871 needs one more value.

**Return-metadata / subagent-return conventions** (`context/formats/return-metadata-file.md`,
`context/formats/subagent-return.md`): both use `metadata.session_id`, `metadata.duration_seconds`,
`metadata.delegation_path` (array of strings) as the standard trio for any structured record that
crosses agent boundaries. The events schema should use `duration_seconds` (not `duration_ms`) for
consistency with this existing convention, nullable for point-in-time events with no duration.

**`.memory/distill-log.json` shape** (closest existing "operations log" precedent):
```json
{
  "version": "1.0.0",
  "operations": [],
  "summary": {
    "total_operations": 0, "total_purged": 0, "total_merged": 0,
    "total_compressed": 0, "total_refined": 0, "last_operation": null
  }
}
```
This is a mutable array-with-rollup, not JSONL, but shows the existing precedent for "per-event
detail records feeding a small aggregate summary" that a future `events-query.sh --summary` mode
could echo.

**Consumer requirements gathered from tasks 870/871/872** (`specs/state.json`, read directly, not
re-derived):
- Task 870 (automatic hook logging): needs to log "timings and success milestones" from the four
  skill-base.sh stages, plus "deviations, and blockers" from a PostToolUse/Stop/SubagentStop hook,
  "cross-linked with errors.json via the shared session_id/task keys." It must also "handle the
  lazy absence of errors.json gracefully" — i.e., a cross-link is an *optional* field pointing at
  an errors.json `id`, never a hard foreign-key requiring errors.json to exist.
- Task 871 (completion-time reflection): needs to write a structured "what worked / what was hard
  / what was missed / successes" object at the `orchestrator-postflight.sh` completion seam, as a
  new field alongside `memory_candidates`/`completion_summary` in state.json AND land a copy in
  the unified store. This is a `category: "success"` or a new `event_type: "reflection"` shape
  with a nested payload distinct from the simple point-events task 870 emits — the schema's
  `payload`/`detail` field needs to be an open object to carry this without a schema revision.
- Task 872 (`/distill` dream mode): is a pure **reader** of the store — needs to query across all
  events (not just one task/session) to synthesize proposals. This confirms `events-query.sh`
  needs cross-session/cross-task aggregate filtering (by `category`, `event_type`, date range),
  not just single-session lookup.

### External Resources

Not applicable — this is a pure internal-convention design task with no external library/API
dependency. No WebSearch/WebFetch was used, consistent with "Network errors: continue with
codebase-only research" fallback guidance (n/a here since no network calls were attempted, but
noting for completeness per report-format.md's Sources/Inputs field).

### Recommendations

#### 1. Store location and lifecycle

- Path: `specs/events.jsonl` (flat, repo-root-relative, sibling to `errors.json`/`state.json`).
- Lazily created: no script pre-creates an empty file; the append helper creates the file (and
  its parent dir, trivially already present) on first invocation if absent, exactly mirroring
  `errors.json`'s "doesn't exist until the first error" behavior confirmed above.
- Never gitignored (mirrors `errors.json`, which is not gitignored either) — once created it is a
  normal tracked file that accumulates across the repo's lifetime. (A future task, not this one,
  may want a rotation/archival strategy once this grows large — worth flagging as a
  Context Extension Recommendation below, not solving here.)
- One JSON object per line, `\n`-terminated, produced by `jq -c` (compact, single-line) so the
  file is trivially both `jq`-streamable (jq's default multi-document-stream parsing works
  directly on JSONL with no `--slurp` needed) and `wc -l`-countable.

#### 2. Event schema

Recommended per-line object shape (documented in the new
`context/formats/events-format.md` and formalized in `context/schemas/events-schema.json`):

```json
{
  "event_id": "evt_{timestamp_ms}_{random6}",
  "event_type": "lifecycle_stage | deviation | blocker | milestone | success | reflection | ...",
  "category": "deviation | blocker | milestone | success",
  "timestamp": "2026-07-15T10:22:31.123Z",
  "duration_seconds": 4.2,
  "session_id": "sess_1736700000_abc123",
  "task": 259,
  "checkpoint": "preflight | context_injection | verification | postflight | GATE_IN | GATE_OUT | phase_2 | ...",
  "message": "Brief one-line human-readable description",
  "detail": { "...": "open object, event_type-specific payload (e.g. reflection fields)" },
  "error_ref": "err_1736700000"
}
```

Field-by-field rationale:

| Field | Required | Notes |
|-------|----------|-------|
| `event_id` | yes | Unique, sortable-by-creation-order (timestamp-prefixed), same style as `errors.json`'s `err_{timestamp}` and `sess_{timestamp}_{random}` session IDs — reuses the established ID convention rather than inventing a new one (e.g. UUID). |
| `event_type` | yes | Free-form but documented common values; the *specific* kind of event (finer-grained than `category`). Task 870 will add lifecycle-stage and hook-triggered types; task 871 will add `reflection`. This task should seed the doc with a starter list but explicitly mark it open/extensible. |
| `category` | yes | Exactly the four values the task description names: `deviation`, `blocker`, `milestone`, `success`. This is the field task 872's dream-mode will primarily group/filter by. Closed enum (these four cover the stated design intent; unlike `checkpoint`, this field's whole purpose per the task description is to be a stable filterable taxonomy). |
| `timestamp` | yes | ISO 8601, matching every other timestamp convention in this codebase (`errors.json`, return-metadata, state.json). |
| `duration_seconds` | no | Nullable — point events (a blocker being hit) have no duration; a completed lifecycle stage does. Named `duration_seconds` (not `duration_ms`) to match `return-metadata-file.md`'s existing `metadata.duration_seconds` convention. |
| `session_id` | yes | Reuses the exact `sess_{timestamp}_{random}` value already generated at GATE_IN — the shared cross-link key named explicitly in the task description. |
| `task` | no (nullable) | Bare integer, matching `errors.json`'s `context.task` and `state.json`'s `project_number` (NOT the zero-padded directory string). Nullable because some events (e.g. `/refresh`, `/todo` archival sweeps) are not task-scoped. |
| `checkpoint` | no (nullable) | Open string; documented common values are the four skill-base.sh stage names, `GATE_IN`/`GATE_OUT`, and `phase_{N}`. Nullable for events with no single lifecycle-point association. |
| `message` | yes | Short human-readable summary, mirrors `errors.json`'s `message` field. |
| `detail` | no | Open object for `event_type`-specific structured payload — this is where task 871's reflection object (`what_worked`/`what_was_hard`/`what_was_missed`/`successes`) nests without requiring a schema revision. |
| `error_ref` | no (nullable) | The cross-link to `errors.json` named explicitly in the task description — holds an `errors.json` entry's `id` (e.g. `"err_1736700000"`). Always optional: task 870's description explicitly requires "handle the lazy absence of errors.json gracefully," so this must never be treated as a required foreign key, and the reader/append helpers must never assume `errors.json` exists. |

#### 3. Shared append helper: `events-append.sh`

New script: `agent-system/extensions/core/scripts/events-append.sh`.

- Single responsibility: build one validated JSON line and append it — analogous to
  `memory-harvest.sh`'s narrow, single-purpose role (contrasted with the broader
  `memory-retrieve.sh` reader).
- Interface (CLI, so any hook/skill/script can call it without hand-rolling `jq`):
  ```
  events-append.sh --event-type TYPE --category CAT --session SESSION_ID \
    [--task N] [--checkpoint NAME] [--duration SECONDS] --message "..." \
    [--detail-json '{"...":"..."}'] [--error-ref ERR_ID]
  ```
- Internals: construct the line via `jq -c -n --arg ... '{...}'` (never string-concatenation,
  to keep JSON-escaping correct — same discipline `memory-harvest.sh` and friends already use),
  then append with a **single write syscall** appended to the open-for-append file descriptor
  (e.g. `printf '%s\n' "$line" >> "$EVENTS_FILE"`, constructing `$line` fully in a variable first
  rather than piping/streaming multiple writes). Single small (<4KB) appends to a file opened
  `O_APPEND` are atomic on Linux even under concurrent writers, but given this codebase's explicit
  prior concern about concurrent-session safety (`task-lock.sh`'s whole rationale, and its
  explicit warning against the non-atomic `jq -n > file` full-rewrite pattern for *state* files),
  the append helper should still wrap the write in `flock` on a dedicated lock file
  (e.g. `specs/.events.lock`) as defense-in-depth — cheap to add, removes any doubt, and matches
  this codebase's general bias toward explicit locking over relying on OS-level guarantees.
- Lazy creation: if `specs/events.jsonl` does not exist, the first `events-append.sh` call creates
  it (no separate init step, no committed empty placeholder file).
- No caller should ever construct a JSONL line manually. This is the concrete mechanism behind the
  task description's "so no subsystem hand-rolls jq."

#### 4. Shared reader/query helper: `events-query.sh`

New script: `agent-system/extensions/core/scripts/events-query.sh`.

- Because JSONL is a native `jq` input format (jq parses a stream of concatenated JSON values with
  no `--slurp` required), the reader is mostly a thin, documented wrapper around `jq` filter
  composition — but a *shared* one, so every consumer (task 870's own instrumentation checking
  its own writes, task 872's dream-mode) uses identical, tested filter syntax instead of five
  slightly-different ad hoc `jq` one-liners.
- Interface:
  ```
  events-query.sh [--session ID] [--task N] [--category CAT] [--event-type TYPE] \
    [--checkpoint NAME] [--since ISO8601] [--until ISO8601] \
    [--format jsonl|json-array|summary-counts]
  ```
- `--format summary-counts` should emit a small aggregate (counts grouped by `category` and/or
  `event_type`), directly useful to task 872's dream-mode synthesis and modeled on
  `.memory/distill-log.json`'s existing `summary` rollup shape (total counts by kind).
- Must tolerate `specs/events.jsonl` not existing yet (empty result set, exit 0 — not an error),
  mirroring how `errors.json`-reading code elsewhere in this codebase is expected to handle lazy
  absence gracefully.

#### 5. Sync-surface edits (this task's actual file_scope)

- `agent-system/extensions/core/manifest.json`: add `"events-append.sh"` and
  `"events-query.sh"` to `provides.scripts`. No change needed to `provides.context` — `"formats"`
  and `"schemas"` are already declared as whole-directory entries, and the new
  `events-format.md`/`events-schema.json` files land inside those already-declared directories.
- `agent-system/extensions/core/index-entries.json`: add two new per-file discovery entries (one
  for `formats/events-format.md`, one for `schemas/events-schema.json`), following the exact
  shape of existing entries like `formats/handoff-artifact.md` (domain `core`, subdomain
  `formats`/`schemas`, `line_count`, `keywords`, `topics: ["orchestration"]` or a new
  `"events"`/`"logging"` topic, and a `load_when` block — likely `task_types: ["meta"]` plus
  agent-scoping for whichever future agents/skills from tasks 870-872 will consume it).
- `agent-system/extensions/core/EXTENSION.md`: bump the `scripts` count row (currently a stale
  "27" against an actual manifest count of 47 — pre-existing drift this task should not be blamed
  for introducing, but the edit is a natural moment to correct it to the true post-edit count),
  and add one line to "Key Capabilities" describing the new unified event store.
- New files: `agent-system/extensions/core/context/formats/events-format.md` (the documented
  schema, field table, `checkpoint`/`category` value vocab, lazy-creation note, cross-link
  contract with `errors.json`) and `agent-system/extensions/core/context/schemas/events-schema.json`
  (formal JSON Schema draft-07 for one event line, in the same style as the existing
  `schemas/frontmatter-schema.json`).

## Decisions

- Store path: `specs/events.jsonl` (not `.agent-logs/events.jsonl` — the latter path appears only
  in one stale, inconsistent doc and does not match the actually-used `specs/errors.json`
  location this task is told to mirror).
- `category` is a closed 4-value enum (`deviation|blocker|milestone|success`) per the task
  description; `checkpoint` and `event_type` are open/extensible strings with documented common
  values, because tasks 870/871 will need to add values this task cannot fully enumerate up front.
- `error_ref` (not `error_id`) chosen as the cross-link field name to avoid ambiguity with the
  event's own `event_id`, and is always optional/nullable.
- Two scripts, not one: `events-append.sh` (write) and `events-query.sh` (read), mirroring the
  existing `memory-harvest.sh`/`memory-retrieve.sh` verb-pairing already established in this
  extension, rather than one combined multi-mode script.
- `duration_seconds` (matching `return-metadata-file.md` convention), not `duration_ms`.

## Risks & Mitigations

- **Concurrent-writer corruption**: mitigated via single-syscall appends plus an `flock`-guarded
  critical section in `events-append.sh` (defense-in-depth beyond POSIX's own small-write
  atomicity guarantee).
- **Unbounded file growth**: `specs/events.jsonl` will grow indefinitely with no rotation
  mechanism designed in this task. Flagged as a Context Extension Recommendation below rather
  than solved here — out of this task's stated scope ("it implements only the store plumbing and
  its documented format").
- **Schema churn from downstream tasks**: mitigated by keeping `checkpoint`/`event_type` open
  strings and `detail` an open object, so tasks 870/871 can add new values/payloads without
  requiring a schema-breaking revision to this contract.
- **errors.json absence**: `error_ref` is always optional and both new scripts must be written to
  work correctly whether or not `specs/errors.json` exists, per task 870's explicit requirement.

## Context Extension Recommendations

- **Topic**: JSONL log rotation/archival policy.
- **Gap**: No existing context doc addresses what happens when `specs/events.jsonl` (or, by
  extension, `specs/errors.json`) grows very large over a long-lived repo's lifetime.
- **Recommendation**: A future task (not 869-872) should evaluate whether `/todo`'s existing
  vault-archival mechanism (`specs/archive/` -> `specs/vault/{NN-vault}/` at
  `next_project_number > 1000`) is the right place to also rotate `events.jsonl`, or whether a
  separate size/age-based rotation is warranted. Not a blocker for this task.

## Appendix

### Search queries / exploration used
- Filesystem exploration: `find`/`ls` over `.claude/extensions/core`, `agent-system/extensions/core`
- `jq` inspection of `specs/state.json` (tasks 869-872 full descriptions), `manifest.json`,
  `index-entries.json`
- `grep` over `error-handling.md` (rule + standard versions), `errors.md` command,
  `skill-base.sh`, `command-gate-in.sh`, `task-lock.sh`, `memory-harvest.sh`,
  `distill-log.json`, `distill.md`
- Confirmed via `git show 1187e8cf8 --stat` that task 868's precedent implementation touched only
  `agent-system/extensions/literature/...`, never the deployed `.claude/extensions/literature/...`
  copy — the sync-out step is a separate, pre-existing mechanism.

### References
- `agent-system/extensions/core/rules/error-handling.md` (authoritative errors.json schema)
- `agent-system/extensions/core/commands/errors.md` (errors.json usage/consumer)
- `agent-system/extensions/core/context/formats/return-metadata-file.md`,
  `subagent-return.md`, `handoff-artifact.md` (existing format-doc precedents)
- `agent-system/extensions/core/context/schemas/frontmatter-schema.json` (existing JSON Schema style precedent)
- `agent-system/extensions/core/scripts/memory-harvest.sh`, `memory-retrieve.sh` (verb-pairing precedent)
- `agent-system/extensions/core/scripts/task-lock.sh` (atomic-write discipline precedent)
- `agent-system/extensions/core/scripts/skill-base.sh`, `command-gate-in.sh`, `command-gate-out.sh` (checkpoint vocabulary)
- `.memory/distill-log.json` (operations-log-with-summary precedent)
- `specs/state.json` entries for tasks 870, 871, 872 (downstream consumer requirements)

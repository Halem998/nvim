# Bootstrap Harvest Dataset

A one-shot, read-only, pointer-based distillation of the Claude Code transcript corpus
(`~/.claude/projects/`) and the durable prompt spine (`~/.claude/history.jsonl`), produced by
`agent-system/extensions/memory/scripts/bootstrap-harvest.sh` and its three sub-passes. This is
**not** a duplicated copy of the source data — every row points back into the corpus (session id
+ transcript path) rather than embedding transcript content.

This dataset is a one-time mine of a perishable, ~30-day-rolling window. It will not be
regenerated on a schedule; a future consumer that wants fresher data re-runs the same scripts
(now deployable via the memory extension's `provides.scripts`) against the corpus as it exists
at that time.

## Files

| File | Rows (observed) | Source |
|------|------------------|--------|
| `sessions.jsonl` | 829 | Top-level transcripts under `~/.claude/projects/*/` (excludes the harvest's own session and its subagent sidecars) |
| `history-spine.jsonl` | 4,930 | `~/.claude/history.jsonl`, grouped by `sessionId` |
| `harvest-manifest.json` | n/a | Run metadata: timestamps, per-pass counts, tool versions, the `inferred_outcome` formula |

## `sessions.jsonl` Schema

One row per top-level (non-subagent) transcript session:

| Field | Type | Notes |
|-------|------|-------|
| `session_id` | string | Claude Code's own UUID session id |
| `repo` | string | Resolved via `sessions-index.json.entries[].projectPath` → record `cwd` → fail loudly. Never a dirname guess. |
| `first_timestamp` / `last_timestamp` | ISO8601 | Bounds of the session |
| `message_count` | int | Total message count in the transcript |
| `is_error_count` | int | `is_error=true` occurrences in the session's own tool results |
| `subagent_is_error_count` | int | `is_error=true` occurrences rolled up from that session's subagent sidecars |
| `total_is_error` | int | `is_error_count + subagent_is_error_count` |
| `tool_result_count` | int | Denominator for `is_error_rate` |
| `is_error_rate` | float | `total_is_error / tool_result_count` (0 when denominator is 0) |
| `inferred_outcome` | string | One of `trivial`/`clean`/`mixed`/`high_error` — see formula below |
| `task_numbers` | int[] | Best-effort task numbers attributed to this session's subagent work (nulls excluded; may be empty) |
| `agent_types` | string[] | Distinct subagent `agentType` values observed for this session |
| `subagent_count` | int | Count of subagent sidecars attributed to this session |
| `transcript_path` | string | Absolute path to the source transcript (pointer, not a copy) |

## `history-spine.jsonl` Schema

One row per `sessionId` found in `history.jsonl` (or the `__no_session_id__` sentinel row for
records that lack one, so they are never silently dropped):

| Field | Type | Notes |
|-------|------|-------|
| `session_id` | string | Claude Code UUID, or the `__no_session_id__` sentinel |
| `repo` | string | The record's `project` field (already an absolute path, same format as `cwd`) |
| `prompt_count` | int | Number of prompts logged for this session |
| `first_timestamp` / `last_timestamp` | epoch ms | Bounds of the session's prompt activity |

`history.jsonl` is parsed via a whole-stream, skip-and-continue decode (Python
`json.JSONDecoder().raw_decode`) rather than naive line-splitting, because at least one real
record contains an embedded raw (unescaped) newline that breaks line-oriented parsing. Decode
failures are counted and reported, never silently dropped.

## `inferred_outcome` — an Explicit Modeling Decision, Not an Extraction

There is no session-level success/failure field anywhere in the source data.
`inferred_outcome` is a label this harvest **invents**, computed as follows. Every row retains
its raw `total_is_error` numerator and `tool_result_count` denominator, so a future consumer can
recompute a different label from the retained counts without re-mining the (perishable) corpus:

```
total_is_error = is_error_count + subagent_is_error_count
is_error_rate  = total_is_error / tool_result_count        (0 when denominator is 0)

trivial     when message_count < 3          (too short to judge -- NOT a success claim)
clean       when total_is_error == 0 and message_count >= 3
mixed       when 0 < is_error_rate <= 0.10
high_error  when is_error_rate > 0.10
```

The `0.10` threshold is a **provisional judgement call**, chosen against the corpus-wide 2.9%
`is_error` density established during the harvest's design research. It is stated here in plain
text so it can be revised without re-mining.

## Known Gaps (stated honestly)

- **Retention cliff**: transcripts are a rolling ~30-day window. Of the 4,930 distinct sessions
  present in the durable `history.jsonl` spine, only 664 (13.5%) still have a matching transcript
  in `sessions.jsonl` — **86.5% of historically logged sessions have already expired** and are
  irrecoverable. This is close to, but not identical to, the design-time estimate of ~88%; both
  numbers describe the same expiring window measured at different moments, and the dataset
  reports what was actually observed at harvest time rather than the earlier estimate.
- **ProofChecker has zero retained transcripts**: it is the single highest-usage project in the
  durable spine (8,720 prompts across 2,088 sessions — more than 3x the next-highest project) but
  contributes **zero rows** to `sessions.jsonl`. There is no `is_error`/outcome signal for this
  project anywhere in this harvest; only its raw prompt-count history survives.
- **Attribution coverage is partial by design**: task-number attribution comes from a narrow,
  deliberately unwidened regex over subagent sidecar descriptions. Sidecars whose description
  does not match get `task_numbers: []` rather than a guess — see `harvest-manifest.json`'s
  `attribution_pass` counts for the resolved/unresolved split actually observed.
- **Decode failures are real, not zero**: both the transcript pass and the `history.jsonl` pass
  encountered files/records that failed to decode. Both are counted explicitly in
  `harvest-manifest.json` rather than silently dropped; see that file for the exact counts
  observed on this run.
- **One test-fixture transcript session is included**: `sessions.jsonl` contains one row whose
  `repo` field points at a scratchpad path used by an unrelated task's implementation testing
  (a real, legitimately-created Claude Code session, not a self-exclusion failure — its
  `session_id` does not match the harvest's own excluded session id). It is retained as-is
  because it is genuine corpus data, not fabricated by this harvest; a future consumer filtering
  by `repo` prefix will naturally exclude scratchpad-rooted sessions if desired.

## Design Rationale: Pointer-Based, Not a Duplicate

Every row in `sessions.jsonl` carries `transcript_path` rather than any transcript content. This
dataset is a distilled index over the corpus — small enough to be durable past the retention
cliff — not a second copy of transcript data. A future consumer that needs actual message content
follows `transcript_path` back into `~/.claude/projects/` while it still exists, or accepts that
the pointer is now dangling once the window has rolled past it.

## Provenance

See `harvest-manifest.json` for the harvest timestamp, excluded self-session id, per-pass
observed counts, tool versions, and the Phase 1 pilot's measured strategy-decision basis. All
figures in this README are pulled from that manifest or independently recomputed from the JSONL
files themselves at documentation time — never copied from pre-harvest estimates.

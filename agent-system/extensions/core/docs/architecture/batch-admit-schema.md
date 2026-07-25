# Cross-Batch Admission Verdict Schema

**Status**: Current architecture.

**File location**: n/a — this is a stdout stream contract, not a file. The script emits NDJSON
directly; nothing is written to disk.
**Written by**: `.claude/scripts/orchestrate-batch-admit.sh`
**Read by**: `commands/orchestrate.md` Step 3 (pre-computed wave schedule) and
`skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 (per-cycle eligibility gate)

**See Also**: `context/patterns/file-footprint-overlap.md` (the canonical overlap predicate this
script transcribes and never restates), `handoff-schema.md` (the sibling orchestrator-facing
schema document this page is modelled on)

## Invocation Contract

```
orchestrate-batch-admit.sh <task_number> [<task_number> ...]
```

Arguments are the candidate task numbers — the caller's already-computed
`validated_tasks`/`task_numbers` for this invocation. Output is NDJSON on stdout: exactly one
compact JSON object per candidate argument, one per line, in input order. There is no other
output mode.

**Exit codes**:
- `0`: verdicts were emitted successfully, regardless of how many are `defer`. Verdicts are
  data, not errors — this script never exits non-zero merely because a candidate was deferred.
- `2`: usage error (zero arguments, or a non-integer argument) or unavailable state (`jq`
  missing, or `specs/state.json` missing/unparseable). Nothing is printed on stdout in either
  case; a single loud line naming the reason goes to stderr.

There is no `1` exit code and no `fail` decision value — a candidate this script cannot resolve
(unknown task number, terminal status, empty/null `file_scope`) is admitted, not failed. Only a
usage error or unavailable state aborts the whole invocation before any verdict is printed.

## Complete JSON Schema

Every emitted line matches this shape. Key order is stable — always as listed below, never
reordered per verdict.

```json
{"$schema":"orchestrate-batch-admit-v1","task_number":900,"decision":"defer","colliding_task_number":902,"colliding_task_status":"not_started","overlapping_path":"agent-system/extensions/core/scripts/orchestrate-batch-admit.sh","collision_scope":"cross_batch","reason":"file_scope overlap with non-terminal task #902 (not in this batch) at agent-system/extensions/core/scripts/orchestrate-batch-admit.sh; no dependencies[] edge between them"}
```

An `admit` verdict carries only the first three keys:

```json
{"$schema":"orchestrate-batch-admit-v1","task_number":905,"decision":"admit"}
```

## Field Definitions

| Field | Type | Presence | Meaning |
|-------|------|----------|---------|
| `$schema` | string | always | Literal `"orchestrate-batch-admit-v1"`. Pinned; never changes across an invocation or a version. |
| `task_number` | int | always | The candidate task number, echoed back from the corresponding CLI argument. |
| `decision` | string | always | `"admit"` or `"defer"` — never `"fail"`. |
| `colliding_task_number` | int | defer only | The other task's `project_number`. |
| `colliding_task_status` | string | defer only | The other task's `status` string, verbatim from `specs/state.json`. |
| `overlapping_path` | string | defer only | The first overlapping path, taken from the COLLIDING task's declared `file_scope` (the "foreign" side) — matches `task-lock.sh`'s `scopes_overlap()` convention of returning the first match, not an exhaustive list. |
| `collision_scope` | string | defer only | `"in_batch"` (the colliding task is itself one of this invocation's candidate arguments) or `"cross_batch"` (it is not). |
| `reason` | string | defer only | Machine-templated human-readable summary. Never the sole carrier of any fact already available as a structured field above. |

## Deferral-Direction Rule and Caller Guidance

- **`in_batch`**: the colliding task is itself one of this invocation's candidate arguments.
  This resolves by ordinary same-run deferral — the candidate is deferred to the next
  wave/cycle, same as the pre-existing invocation-scoped check already did. No special handling
  is required beyond what callers already implement for a same-batch collision.
- **`cross_batch`**: the colliding task is NOT one of this invocation's candidate arguments.
  This means the requested candidate is excluded from this invocation's admitted set and the
  colliding task is surfaced for human batch-composition judgment. This is explicitly **not** a
  correctness verdict on the candidate task, and explicitly **not** an instruction to fold the
  out-of-batch task into the run. The out-of-batch task is idle and in no batch, so it will not
  itself advance and resolve the collision on its own; a human resolves batch composition.

Both branches share the defer-not-fail invariant: a `defer` verdict never marks the candidate
task failed, and this script never writes to `specs/state.json` — it is a pure, read-only
predicate that only prints.

## Why This Check Is Blocking, Not Advisory

The imported criterion for the blocking-vs-advisory decision is: computable from on-disk state
alone, and the harm of skipping it is silent and hard to detect later. A cross-batch `file_scope`
collision satisfies both halves of that criterion — it requires nothing but a read of
`specs/state.json`, and if skipped, two sessions can concurrently edit the same files with no
lock contention (the colliding task holds no lock; it simply is not running) and no visible
symptom until a merge conflict or a silently overwritten edit turns up much later. A future
maintainer who is tempted to relax this check to advisory after reading general literature on
false positives from coarse directory-prefix scope declarations should re-derive the criterion
above first: the false-positive cost here is a deferred task, not silent data loss, and the two
are not comparable. This check stays blocking.

## Why `collision_scope`, Never `severity`

`severity` already carries two incompatible vocabularies in this codebase: `hard|soft` for
handoff blockers (see `handoff-schema.md`), and `critical|high|medium|low` for error/review
issues. Reusing that name here for a third, unrelated vocabulary (`in_batch|cross_batch`) would
collide with both existing meanings. `collision_scope` is a distinct field name for a distinct
concept — which side of the invocation boundary the colliding task falls on — and is not a
severity ranking at all.

## Accepted False-Positive Profile

This script transcribes, and never restates or forks, the directory-prefix overlap predicate
defined once in `context/patterns/file-footprint-overlap.md`. That predicate is directory-prefix
matching only: a task declaring a whole directory as its `file_scope` will defer against
anything beneath it, with no glob/regex matching and no content-hash refinement. This cost is
accepted rather than engineered around — see that document's Non-Goals section for the full
rationale. `orchestrate-batch-admit.sh` is that document's fourth named consumer, alongside the
task-level, phase-level, and lock-acquisition-level callers already listed there.

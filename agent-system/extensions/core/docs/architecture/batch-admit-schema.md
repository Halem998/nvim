# Cross-Batch Admission Verdict Schema

**Status**: Current architecture. Version 2 (`orchestrate-batch-admit-v2`) — see "Version History"
at the bottom for what changed from v1 and why the bump was a version, not an additive field.

**File location**: n/a — this is a stdout stream contract, not a file. The script emits NDJSON
directly; nothing is written to disk.
**Written by**: `.claude/scripts/orchestrate-batch-admit.sh`
**Read by**: `commands/orchestrate.md` Step 3 (pre-computed wave schedule),
`skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 (per-cycle eligibility gate),
`scripts/orchestrate-dry-run-report.sh` Step 4 (read-only report composer — same call, same
schema, never a forked copy), and `scripts/orchestrate-predispatch-review.sh` (Classes C and D —
a report composer in the same relationship to this schema as the dry-run reporter above: it
re-presents `defer_reason == "self_modifying"` and `defer_reason == "file_scope_collision" &&
collision_scope == "cross_batch"` verdicts, adding a declaration-coarseness diagnosis and a
suggested serializing edge respectively, never re-deriving the collision algorithm itself)

**See Also**: `context/patterns/file-footprint-overlap.md` (the canonical overlap predicate this
script transcribes and never restates), `context/patterns/batch-orchestration-guardrails.md`
("Self-Modification Hazard: The Fourth Admission Dimension" — the rationale behind the
critical-path list and the two-test inclusion/exclusion criteria), `handoff-schema.md` (the
sibling orchestrator-facing schema document this page is modelled on),
`context/reference/orchestrator-critical-paths.json` (the declared critical-path list and
`scope_roots` this script loads and expands)

## Invocation Contract

```
orchestrate-batch-admit.sh [--invocation-count <N>] <task_number> [<task_number> ...]
```

Positional arguments are the candidate task numbers — the caller's already-computed
`validated_tasks`/`task_numbers`/`eligible_tasks` for this call. Output is NDJSON on stdout:
exactly one compact JSON object per candidate argument, one per line, in input order. There is no
other output mode.

**`--invocation-count <N>`**: the total number of validated candidates in the WHOLE invocation
this call is part of — not merely the wave/cycle subset passed as positional arguments. Defaults
to the number of positional `<task_number>` arguments when omitted (backward-compatible: correct
for any caller that already passes its whole set in one call). A caller that passes a
wave/cycle SUBSET (`wave_tasks`, `eligible_tasks`) MUST pass its invocation's full
validated-candidate count here — see "Why `--invocation-count` Exists" below for what breaks if
a caller forgets.

**Exit codes**:
- `0`: verdicts were emitted successfully, regardless of how many are `defer`. Verdicts are
  data, not errors — this script never exits non-zero merely because a candidate was deferred.
- `2`: usage error (zero positional arguments, a non-integer positional argument, or a
  non-integer `--invocation-count` value) or unavailable state (`jq` missing, or
  `specs/state.json` missing/unparseable). Nothing is printed on stdout in either case; a single
  loud line naming the reason goes to stderr.

There is no `1` exit code and no `fail` decision value — a candidate this script cannot resolve
(unknown task number, terminal status, empty/null `file_scope`) is admitted, not failed. Only a
usage error or unavailable state aborts the whole invocation before any verdict is printed.

## Complete JSON Schema

Every emitted line matches one of the three shapes below. Key order is stable — always as listed,
never reordered per verdict. `self_modifying` is present on **every** verdict, including plain
`admit` verdicts — this is the one field that never depends on which branch produced the verdict.

**Self-modifying defer** (self-modification hazard, invocation carries more than one candidate):

```json
{"$schema":"orchestrate-batch-admit-v2","task_number":460,"decision":"defer","self_modifying":true,"defer_reason":"self_modifying","critical_path":"agent-system/extensions/core/scripts/orchestrate-batch-admit.sh","critical_label":"admission predicate","reason":"candidate #460 file_scope names orchestrator-critical path \"agent-system/extensions/core/scripts/orchestrate-batch-admit.sh\" (admission predicate); deferred out of this invocation because orchestrator-critical work runs solo only — re-run task #460 alone"}
```

**File-scope collision defer** (unchanged algorithm from v1, plus the two additive fields):

```json
{"$schema":"orchestrate-batch-admit-v2","task_number":900,"decision":"defer","self_modifying":false,"defer_reason":"file_scope_collision","colliding_task_number":902,"colliding_task_status":"not_started","overlapping_path":"agent-system/extensions/core/scripts/orchestrate-batch-admit.sh","collision_scope":"cross_batch","reason":"file_scope overlap with non-terminal task #902 (not in this batch) at agent-system/extensions/core/scripts/orchestrate-batch-admit.sh; no dependencies[] edge between them"}
```

**Admit** (carries only `$schema`, `task_number`, `decision`, `self_modifying` — nothing else,
whether `self_modifying` is `true` (a self-modifying candidate admitted solo, invocation count
== 1), `false` (an ordinary candidate), or `null` (degraded — see below)):

```json
{"$schema":"orchestrate-batch-admit-v2","task_number":905,"decision":"admit","self_modifying":false}
```

## Field Definitions

| Field | Type | Presence | Meaning |
|-------|------|----------|---------|
| `$schema` | string | always | Literal `"orchestrate-batch-admit-v2"`. Pinned; never changes across an invocation. |
| `task_number` | int | always | The candidate task number, echoed back from the corresponding CLI argument. |
| `decision` | string | always | `"admit"` or `"defer"` — never `"fail"`. |
| `self_modifying` | bool \| null | always | `true` when the candidate's own `file_scope` names a declared orchestrator-critical path; `false` when it does not; `null` when the critical-path data file is missing or unparseable (degraded — the check could not run, never silently reported as `false`). |
| `defer_reason` | string | defer only | REQUIRED on every `defer` verdict (v2). Exactly one of `"self_modifying"` or `"file_scope_collision"` — the discriminator that determines which of the two field groups below is present. |
| `critical_path` | string | `defer_reason == "self_modifying"` only | The matched declared critical path, after `scope_roots` expansion (may be a source-store path or a deploy-tree path, whichever the candidate's `file_scope` actually named). |
| `critical_label` | string | `defer_reason == "self_modifying"` only | The matched entry's short label, from `orchestrator-critical-paths.json`. |
| `colliding_task_number` | int | `defer_reason == "file_scope_collision"` only | The other task's `project_number`. |
| `colliding_task_status` | string | `defer_reason == "file_scope_collision"` only | The other task's `status` string, verbatim from `specs/state.json`. |
| `overlapping_path` | string | `defer_reason == "file_scope_collision"` only | The first overlapping path, taken from the COLLIDING task's declared `file_scope` (the "foreign" side) — matches `task-lock.sh`'s `scopes_overlap()` convention of returning the first match, not an exhaustive list. |
| `collision_scope` | string | `defer_reason == "file_scope_collision"` only | `"in_batch"` (the colliding task is itself one of this invocation's candidate arguments) or `"cross_batch"` (it is not). |
| `reason` | string | defer only | Machine-templated human-readable summary. Never the sole carrier of any fact already available as a structured field above. |

## Precedence: Self-Modification Runs First and Short-Circuits

The self-modification check runs BEFORE the file-scope collision scan and, when it fires
(`self_modifying == true`), SHORT-CIRCUITS the collision scan entirely — a self-modifying
candidate never also carries collision fields, regardless of whether it is deferred (invocation
count > 1) or admitted solo (invocation count == 1). Rationale: it is a pure single-candidate
predicate whose consequence is strictly larger in scope (excluded from the WHOLE invocation vs.
deferred one wave/cycle), and first-match determinism matches this script's existing "first hit
wins, no exhaustive collection" convention used elsewhere in the collision scan.

## Deferral-Direction Rule and Caller Guidance

- **`defer_reason == "self_modifying"`**: the candidate's own `file_scope` names a declared
  orchestrator-critical path AND the invocation carries more than one candidate
  (`--invocation-count` > 1). The candidate is excluded from the WHOLE INVOCATION, not merely
  deferred to a later wave/cycle within it — see "Why `--invocation-count` Exists" below for why
  this scope distinction is load-bearing. If the invocation carries exactly one candidate, the
  SAME hazardous candidate is instead `admit`ted with `self_modifying: true` still present (solo
  is the desired outcome for orchestrator-critical work).
- **`defer_reason == "file_scope_collision"`, `collision_scope == "in_batch"`**: the colliding
  task is itself one of this invocation's candidate arguments. This resolves by ordinary
  same-run deferral — the candidate is deferred to the next wave/cycle, same as the
  pre-existing invocation-scoped check already did. No special handling is required beyond what
  callers already implement for a same-batch collision.
- **`defer_reason == "file_scope_collision"`, `collision_scope == "cross_batch"`**: the colliding
  task is NOT one of this invocation's candidate arguments. This means the requested candidate is
  excluded from this invocation's admitted set and the colliding task is surfaced for human
  batch-composition judgment. This is explicitly **not** a correctness verdict on the candidate
  task, and explicitly **not** an instruction to fold the out-of-batch task into the run. The
  out-of-batch task is idle and in no batch, so it will not itself advance and resolve the
  collision on its own; a human resolves batch composition.

All three defer flavors share the defer-not-fail invariant: a `defer` verdict never marks the
candidate task failed, and this script never writes to `specs/state.json` — it is a pure,
read-only predicate that only prints.

**v2 consumer requirement**: any consumer that branches on a `defer` verdict MUST check
`defer_reason` before falling back to `collision_scope`-only logic. A pre-v2 consumer that
assumed every `defer` was a `file_scope_collision` and branched on `collision_scope` alone would
misread a `self_modifying` defer as an ordinary `in_batch`/`cross_batch` collision (both carry a
`reason` string, so the mistake would not immediately surface as an error) — see "Version
History" below for why this required a schema version bump rather than an additive field.

## Why `--invocation-count` Exists

Both live callers (`commands/orchestrate.md` Step 3 and `skills/skill-orchestrate/SKILL.md`
Stage MT-3 step 4.5) dispatch in wave/cycle-sized SUBSETS of the invocation's full candidate set
— `wave_tasks` and `eligible_tasks` respectively — never the whole set in one call. A
self-modifying candidate in Wave 0 and an unrelated candidate in Wave 1 are still "in the same
invocation" for the purpose of the self-modification gate (the whole point is to keep
orchestrator-critical work from running alongside ANY sibling, not merely a same-wave one), so
the trigger for `defer_reason == "self_modifying"` must be evaluated against the WHOLE
invocation's validated-candidate count, not the size of whichever subset happens to be passed as
positional arguments. `--invocation-count` makes that count an explicit, required-by-convention
input rather than something this script would otherwise have to (incorrectly) infer from
`argc`. Both live call sites pass `--invocation-count` set to their own invocation's full count
(`${#validated_tasks[@]}` / `${#task_numbers[@]}`), never the wave/cycle subset size.

**Convergence requirement on the SKILL.md caller**: because Stage MT-3 re-evaluates
`eligible_tasks` every cycle, a `self_modifying` defer verdict must be recorded in an
invocation-scoped exclusion set (`deferred_self_modifying` in `mt_state_file`) that is excluded
from `eligible_tasks` on every subsequent cycle. Without this, the same candidate would
re-qualify as eligible on the very next cycle (nothing about its own status or predecessors
changed) and the check would re-fire every cycle, forever — the defer condition never clears on
its own. `commands/orchestrate.md`'s pre-computed wave-schedule caller does not need an
equivalent set because each wave is dispatched at most once per invocation; the recurring-cycle
shape is unique to the SKILL.md multi-task loop.

## Why This Check Is Blocking, Not Advisory

The imported criterion for the blocking-vs-advisory decision is: computable from on-disk state
alone, and the harm of skipping it is silent and hard to detect later. Both dimensions this
script implements satisfy that criterion:

- A cross-batch `file_scope` collision requires nothing but a read of `specs/state.json`, and if
  skipped, two sessions can concurrently edit the same files with no lock contention (the
  colliding task holds no lock; it simply is not running) and no visible symptom until a merge
  conflict or a silently overwritten edit turns up much later.
- A self-modifying candidate's hazard requires nothing but a read of the candidate's own
  `file_scope` against a declared list, and if skipped, an unverifiable orchestrator-machinery
  fix can be bundled into a multi-task batch commit with no visible symptom until a later defect
  is traced back to it.

A future maintainer who is tempted to relax either check to advisory after reading general
literature on false positives from coarse directory-prefix scope declarations should re-derive
the criterion above first: the false-positive cost here is a deferred task, not silent data
loss, and the two are not comparable. Both checks stay blocking.

## Why `collision_scope`, Never `severity`

`severity` already carries two incompatible vocabularies in this codebase: `hard|soft` for
handoff blockers (see `handoff-schema.md`), and `critical|high|medium|low` for error/review
issues. Reusing that name here for a third, unrelated vocabulary (`in_batch|cross_batch`) would
collide with both existing meanings. `collision_scope` is a distinct field name for a distinct
concept — which side of the invocation boundary the colliding task falls on — and is not a
severity ranking at all. `defer_reason` is likewise a distinct field from both: it discriminates
which HAZARD DIMENSION fired, not which side of a boundary a collision falls on.

## Accepted False-Positive Profile

This script transcribes, and never restates or forks, the directory-prefix overlap predicate
defined once in `context/patterns/file-footprint-overlap.md`. That predicate is directory-prefix
matching only: a task declaring a whole directory as its `file_scope` will defer against
anything beneath it, with no glob/regex matching and no content-hash refinement. This cost is
accepted rather than engineered around — see that document's Non-Goals section for the full
rationale. `orchestrate-batch-admit.sh` is that document's fourth named consumer, alongside the
task-level, phase-level, and lock-acquisition-level callers already listed there. The
self-modification check is a FURTHER APPLICATION of the same predicate (candidate `file_scope`
vs. a static declared list, rather than vs. another task's `file_scope`) and inherits the same
false-positive profile — a candidate declaring a whole directory that happens to contain a
critical file will be flagged, with no finer-grained disambiguation.

## Degradation (D5): Visible, Never Silent

A missing, unreadable, or unparseable `orchestrator-critical-paths.json` does NOT disable the
self-modification check silently and does NOT abort the invocation. Instead:

- `self_modifying` is `null` on EVERY verdict for that invocation (never silently `false`, which
  would be indistinguishable from "checked and found non-hazardous").
- One loud `WARNING:` line goes to stderr naming the missing/unparseable file.
- The collision scan still runs unaffected — a degraded self-modification check does not
  degrade the rest of admission.
- `orchestrate-dry-run-report.sh`'s "Checks run" section prints `self-modification: SKIPPED
  (degraded: ...)` instead of `self-modification: ran`, so a human reading the report sees the
  degradation directly rather than inferring it from an absent exclusion.

## Version History

**v1** (original): `$schema`, `task_number`, `decision`, and the four `collision_scope`-defer
fields (`colliding_task_number`, `colliding_task_status`, `overlapping_path`, `collision_scope`)
plus `reason`. Every `defer` verdict was, by construction, a file-scope collision — there was
only one kind of defer, so no discriminator field existed.

**v2** (current): adds `self_modifying` (present on every verdict) and the self-modification
hazard dimension (`defer_reason`, `critical_path`, `critical_label` on a self-modifying defer;
`defer_reason` also added to the pre-existing collision defer, now valued
`"file_scope_collision"`). This was a VERSION BUMP, not an additive-field change, because a v1
consumer's `defer` handling assumed every defer was a collision and branched on
`collision_scope` alone; an unrecognized second defer flavor routed through that pre-v2 default
branch would be misread as an ordinary in-batch collision (a "retry next wave" outcome) rather
than the invocation-scoped exclusion it actually is — and since the self-modifying candidate's
own eligibility does not change on its own, that misread produces a non-converging retry loop,
never a merely incorrect one-off classification. All in-repo consumers (`commands/orchestrate.md`
Step 3, `skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5, and
`scripts/orchestrate-dry-run-report.sh` Step 4) were updated to the v2 discriminator in the same
change that introduced it — there is no transitional period where v1 and v2 consumers coexist
against a v2 script.

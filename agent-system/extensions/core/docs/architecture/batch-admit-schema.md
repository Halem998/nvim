# Cross-Batch Admission Verdict Schema

**Status**: Current architecture. Version 3 (`orchestrate-batch-admit-v3`) — see "Version History"
at the bottom for what changed from v1 to v2 and from v2 to v3, and why each bump was a version,
not an additive field.

**File location**: n/a — this is a stdout stream contract, not a file. The script emits NDJSON
directly; nothing is written to disk.
**Written by**: `.claude/scripts/orchestrate-batch-admit.sh`
**Read by**: `commands/orchestrate.md` Step 3 (pre-computed wave schedule, illustrative only — see
that file's own framing of what actually executes),
`skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 (per-cycle eligibility gate — the sole
EXECUTING admission gate on the MT dispatch path),
`skills/skill-orchestrate-hard/SKILL.md` `## Multi-Task Mode` (explicit transcription of the same
Stage MT-3 step 4.5 contract, co-maintained with the base skill),
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

**`--invocation-count <N>`**: the number of candidates being CO-DISPATCHED IN THE SAME wave/cycle
as the positional `<task_number>` arguments — not the whole invocation's total candidate count.
Defaults to the number of positional `<task_number>` arguments when omitted (backward-compatible:
correct for any caller that already passes its own co-dispatch set in one call). A caller that
passes a wave/cycle SUBSET (`wave_tasks`, `eligible_tasks`) MUST pass that subset's own size here
— see "Why `--invocation-count` Exists" below for why a whole-invocation count is wrong as of v3.

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

**Self-modifying defer** (self-modification hazard, candidate is co-dispatched this wave/cycle
alongside another candidate):

```json
{"$schema":"orchestrate-batch-admit-v3","task_number":460,"decision":"defer","self_modifying":true,"defer_reason":"self_modifying","critical_path":"agent-system/extensions/core/scripts/orchestrate-batch-admit.sh","critical_label":"admission predicate","reason":"candidate #460 file_scope names orchestrator-critical path \"agent-system/extensions/core/scripts/orchestrate-batch-admit.sh\" (admission predicate); deferred out of this wave/cycle because it is co-dispatched alongside another candidate this cycle — it becomes eligible again once that co-dispatch clears, or pass --allow-self-modifying to override"}
```

**File-scope collision defer** (unchanged algorithm from v1, plus the two additive fields):

```json
{"$schema":"orchestrate-batch-admit-v3","task_number":"{N}","decision":"defer","self_modifying":false,"defer_reason":"file_scope_collision","colliding_task_number":"{M}","colliding_task_status":"not_started","overlapping_path":"agent-system/extensions/core/scripts/orchestrate-batch-admit.sh","collision_scope":"cross_batch","reason":"file_scope overlap with non-terminal task #{M} (not in this batch) at agent-system/extensions/core/scripts/orchestrate-batch-admit.sh; no dependencies[] edge between them"}
```

**Admit** (carries only `$schema`, `task_number`, `decision`, `self_modifying` — nothing else,
whether `self_modifying` is `true` (a self-modifying candidate admitted solo, co-dispatch count
== 1), `false` (an ordinary candidate), or `null` (degraded — see below)):

```json
{"$schema":"orchestrate-batch-admit-v3","task_number":905,"decision":"admit","self_modifying":false}
```

## Field Definitions

| Field | Type | Presence | Meaning |
|-------|------|----------|---------|
| `$schema` | string | always | Literal `"orchestrate-batch-admit-v3"`. Pinned; never changes across an invocation. |
| `task_number` | int | always | The candidate task number, echoed back from the corresponding CLI argument. |
| `decision` | string | always | `"admit"` or `"defer"` — never `"fail"`. |
| `self_modifying` | bool \| null | always | `true` when the candidate's own `file_scope` names a declared orchestrator-critical path; `false` when it does not; `null` when the critical-path data file is missing or unparseable (degraded — the check could not run, never silently reported as `false`). |
| `defer_reason` | string | defer only | REQUIRED on every `defer` verdict (since v2). Exactly one of `"self_modifying"` or `"file_scope_collision"` — the discriminator that determines which of the two field groups below is present, and, as of v3, also determines what operator remedy applies (a `self_modifying` defer has a consumer-side `--allow-self-modifying` override; `file_scope_collision` has none). |
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
candidate never also carries collision fields, regardless of whether it is deferred (co-dispatch
count > 1) or admitted solo (co-dispatch count == 1). Rationale, corrected for v3: the "strictly
larger consequence" reason from v2 no longer holds — both defer flavors now share the same
wave/cycle scope of consequence. The surviving reason is narrower: self-mod is a pure
single-candidate predicate (tests the candidate's own `file_scope` against a static list) that is
cheaper to evaluate than the collision scan's set comparison against every other non-terminal
task, and first-match determinism matches this script's existing "first hit wins, no exhaustive
collection" convention used elsewhere in the collision scan.

**A1 — dependency-edge exemption asymmetry, explained not remedied**: the collision dimension
exempts any `dependencies[]`-edge-connected task from its comparison set; the self-modification
dimension applies no equivalent exemption. This is deliberate: once `--invocation-count` is
same-cycle-scoped, an edge-connected pair can never share that count in the first place (the
calling skill's own eligibility rule guarantees a successor is never eligible in the same cycle as
its predecessor), so an explicit exemption in the self-mod branch would be unreachable dead code.
See `context/patterns/batch-orchestration-guardrails.md`'s "The Same-Cycle Narrowing and Its
Hazard Accounting" subsection for the full argument.

## Deferral-Direction Rule and Caller Guidance

- **`defer_reason == "self_modifying"`**: the candidate's own `file_scope` names a declared
  orchestrator-critical path AND it is co-dispatched this wave/cycle alongside another candidate
  (`--invocation-count` > 1). The candidate is deferred out of the CURRENT wave/cycle — converging
  the same way an `in_batch` `file_scope_collision` defer already does — not excluded from the
  whole invocation. If the co-dispatch count is exactly one, the SAME hazardous candidate is
  instead `admit`ted with `self_modifying: true` still present (solo is still the desired outcome
  for orchestrator-critical work). The consumer (`skills/skill-orchestrate/SKILL.md` Stage MT-3
  step 4.5 and its `skill-orchestrate-hard` transcription) may bypass acting on this verdict when
  `--allow-self-modifying` is active for the invocation — see "Why This Check Is Blocking, Not
  Advisory" below for the override's exact boundary.
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

**Consumer requirement (since v2, unchanged by v3)**: any consumer that branches on a `defer`
verdict MUST check `defer_reason` before falling back to `collision_scope`-only logic. A pre-v2
consumer that assumed every `defer` was a `file_scope_collision` and branched on `collision_scope`
alone would misread a `self_modifying` defer as an ordinary `in_batch`/`cross_batch` collision
(both carry a `reason` string, so the mistake would not immediately surface as an error). A
v2-aware consumer that still treats a `self_modifying` defer as a permanent whole-invocation
exclusion under v3 has a DIFFERENT, narrower mismatch — see "Version History" below for the v3
entry's full account of why this required a schema version bump rather than an additive field.

## Why `--invocation-count` Exists

Both live callers (`commands/orchestrate.md` Step 3, illustrative only, and
`skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5, the sole EXECUTING gate) dispatch in
wave/cycle-sized SUBSETS of the invocation's full candidate set — `wave_tasks` and
`eligible_tasks` respectively. As of v3, `--invocation-count` is evaluated against that SAME
subset — this cycle's actual co-dispatch count, not the whole invocation's full candidate count.
The v2 argument for whole-invocation scope ("the whole point is to keep orchestrator-critical
work from running alongside ANY sibling, not merely a same-wave one") is the exact claim v3
reverses: a `dependencies[]`-edge-connected pair can never co-occupy a wave/cycle in the first
place (the calling skill's own eligibility rule guarantees a successor is never eligible until
its predecessor terminates), so a whole-invocation count fires against pairs that never actually
co-occur in a dispatch batch. That was a pure false positive, not a safety margin.
`--invocation-count` still makes the co-dispatch count an explicit, required-by-convention input
rather than something this script would otherwise have to (incorrectly) infer from `argc`. Both
live call sites now pass `--invocation-count` set to the CURRENT wave/cycle's own size
(`${#wave_tasks[@]}` / `${#eligible_tasks[@]}`), never the whole invocation's full candidate
count.

Retained flag name (unchanged from v1/v2): `--invocation-count` keeps its original name even
though its documented semantics narrowed, because `scripts/orchestrate-dry-run-report.sh` and
`scripts/orchestrate-predispatch-review.sh` pass this flag by name; renaming it would make an
unrecognized flag fall through those callers' argument scans into positional validation, aborting
with exit 2. A `--codispatch-count` alias was considered and rejected as extra surface on
orchestrator-critical machinery for a naming-clarity improvement only.

**Convergence requirement on the SKILL.md caller — CHANGED IN v3**: under v2, because Stage MT-3
re-evaluates `eligible_tasks` every cycle, a `self_modifying` defer verdict had to be recorded in
an invocation-scoped EXCLUSION set (`deferred_self_modifying` in `mt_state_file`) that was
excluded from `eligible_tasks` on every subsequent cycle, or the same candidate would re-qualify
as eligible on the very next cycle and the check would re-fire forever. As of v3, the convergence
mechanism is different: `deferred_self_modifying` is now an APPEND-ONLY OBSERVATION LOG, not an
exclusion set, and the defer clears on its own once the co-dispatched sibling that caused it
leaves `eligible_tasks` (enters `researching`/`planning`, terminates, or fails) — the loop's
existing per-cycle re-evaluation of `eligible_tasks` from current state already guarantees this,
the same convergence `file_scope_collision` already relies on. A bounded
`consecutive_no_dispatch_cycles` counter backs the narrow non-convergence mode this change opens
(two self-modifying candidates that keep mutually re-qualifying each other as the colliding
sibling every cycle), breaking the loop with `partial` status rather than silently spinning to
`MAX_CYCLES_MT`. `commands/orchestrate.md`'s pre-computed wave-schedule caller does not need an
equivalent mechanism because each wave is dispatched at most once per invocation; the
recurring-cycle shape is unique to the SKILL.md multi-task loop.

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

**The `--allow-self-modifying` override does not change this.** The check remains fully blocking;
this script always computes and emits the honest `self_modifying`/`defer_reason` verdict
regardless of the flag, and `--allow-self-modifying` is NEVER passed to
`orchestrate-batch-admit.sh`. The override is a CONSUMER decision, made at
`skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 (and its `skill-orchestrate-hard`
transcription), to not ACT on an emitted `self_modifying` defer verdict — dispatching the
candidate this cycle anyway, with a loud bypass notice logged regardless of whether the gate
would otherwise have fired. It is never a change to this script's own output schema or blocking
behavior, and it defaults off (`"false"`), per-invocation only.

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

**v3** (current): narrows the SEMANTIC of a `self_modifying` defer from a permanent
whole-invocation exclusion to a converging same-cycle defer (the `$schema` string, field set, and
key order are otherwise unchanged from v2 — no field was added or removed). This was a VERSION
BUMP rather than an additive-field change, for the same class of reason the v1-to-v2 bump was: a
v2-aware consumer still applying v2's permanent-exclusion handling to a v3 `self_modifying`
verdict would over-defer a task the v3 script expects to be retried next cycle once its
co-dispatched sibling clears — silently reintroducing a form of the original
whole-invocation-exclusion behavior the narrowing was meant to remove, via a stale consumer rather
than a script defect. `--invocation-count`'s documented contract also narrowed in the same
change (whole-invocation count to same-cycle co-dispatch count), and a new consumer-side
`--allow-self-modifying` override was added — never passed to this script, so it does not appear
in this schema.

Every in-repo consumer's status as of v3:

| Consumer | Status |
|---|---|
| `commands/orchestrate.md` Step 3 | Updated (illustrative block only — see that file's own framing of what executes) |
| `skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 | Updated — the sole EXECUTING gate |
| `skills/skill-orchestrate-hard/SKILL.md` `## Multi-Task Mode` | Updated — explicit transcription added, closing a prior zero-reference gap |
| `scripts/orchestrate-dry-run-report.sh` Step 4 | Verified v3-compatible, NOT edited (outside this change's declared file scope) — pins no `$schema` string literal and already branches on `defer_reason` |
| `scripts/orchestrate-predispatch-review.sh` Classes C and D | Verified v3-compatible, NOT edited (outside this change's declared file scope) — pins no `$schema` string literal and already branches on `defer_reason` |

**Declared residual for the two verified-not-edited consumers**: both call this script once with
their whole candidate set rather than a same-cycle co-dispatch subset, so under the narrowed v3
semantics their existing exclusion-scope PROSE (describing a `self_modifying` defer as
whole-invocation) now over-states the live consequence. This is a recorded follow-up, not a
silent gap — see `context/patterns/batch-orchestration-guardrails.md`'s "Scope Limitation and
Residual Risk" section for the broader scope-boundary reasoning this residual sits alongside.

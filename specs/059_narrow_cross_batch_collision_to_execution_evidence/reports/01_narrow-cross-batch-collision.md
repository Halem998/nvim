# Research Report: Task #59

**Task**: 59 - Gate cross-batch file_scope collisions on execution evidence, not non-terminal status
**Started**: 2026-08-17T19:00:00Z
**Completed**: 2026-08-17T19:43:00Z
**Effort**: medium (one script's jq predicate, one schema doc version bump, two guardrail-doc
corrections, two test-suite additions — all inside a self-modifying, solo-dispatch file_scope)
**Dependencies**: None
**Sources/Inputs**: Codebase (script, docs, tests, state.json) — no web search needed; this is a
self-contained internal defect with a fully-specified root cause in the task description.
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect and its root cause, as stated in the task description, are verified against the
  actual code and are accurate: `orchestrate-batch-admit.sh`'s `file_scope_collision` dimension
  currently compares a candidate against *every* non-terminal task in `specs/state.json`
  (`is_terminal` excludes only `completed`/`abandoned`/`expanded`), and for `collision_scope ==
  "cross_batch"` it defers **unconditionally** regardless of the colliding task's actual status —
  including `not_started`, which can never self-clear without a dispatch that only a human or a
  future batch can trigger.
- The fix is a **narrow, single-clause change**: in the `cross_batch` branch of the collision-scan
  comparison-set/hit logic (`orchestrate-batch-admit.sh` lines ~450-531), require the colliding
  task's status to be one of `{researching, planning, implementing}` before it counts as a hit.
  `in_batch` behavior is untouched (confirmed both by the task description's own reasoning and by
  the existing test fixtures — see Findings below). Idle cross-batch overlaps (any other
  non-terminal status: `not_started`, `researched`, `planned`, `blocked`, `partial`, `pr_ready`)
  become `admit` verdicts that must carry a new, loud, non-silent advisory field.
- **Existing test fixtures require no behavioral changes** — every current `cross_batch` fixture
  (`test-conflict-predicate.sh` case 2.2's task #841, `test-four-tier-conflict.sh` case 9's task
  #603) already uses `status: "implementing"`, which is in-flight under the new rule and keeps
  deferring exactly as before. **New fixtures must be added** to cover the changed idle-overlap
  path, since no existing fixture exercises it.
- Schema version bump to `orchestrate-batch-admit-v5` is scoped narrowly: exactly **three files**
  pin the literal string `"orchestrate-batch-admit-v4"` in the whole `agent-system/extensions/core`
  tree — `scripts/orchestrate-batch-admit.sh`, `docs/architecture/batch-admit-schema.md`, and
  `scripts/test-conflict-predicate.sh` — confirming the task description's "narrow blast radius"
  claim exactly.
- `batch-admit-schema.md`'s "Why This Check Is Blocking, Not Advisory" section is indeed
  self-refuting as described: it argues the harm of skipping the check is that "two sessions can
  concurrently edit the same files with no lock contention" in the same breath as conceding "the
  colliding task holds no lock; it simply is not running" — these two clauses describe mutually
  exclusive scenarios (concurrent editing vs. provably not running) and both need correcting to
  describe an *evidence-gated* rationale.
- `batch-orchestration-guardrails.md`'s Blocking-vs-Advisory Classification Table indeed has no
  dedicated `cross_batch` row — its one `file_scope overlap` row bundles creation-time and runtime
  wave/cycle-split (`in_batch`) together and does not mention `cross_batch` at all. A new row (or
  row split) is needed.
- The batch's two sibling tasks are task 60 (`thread_evidence_gated_verdict_through_admission_consumers`,
  depends on [59]) and task 61 (`surface_coarse_file_scope_declarations_at_creation`, depends on
  [59]) — confirming the task description's "consumer-side task in this batch" and "this batch's
  three task numbers" language. Four tasks in `specs/state.json` (53, 14, 17, 44) carry
  `dependencies[]` edges added specifically because their `file_scope` overlaps 59/60/61's declared
  scope with no other relation — these are the "workaround" edges the CLOSING STEP names for
  removal once 59 is implemented and deployed (see Findings for the file-scope evidence behind
  this identification; 48 and 50 also depend on 59/60/61 but via a repo-wide `agent-system/extensions/`
  scope declaration unrelated to this collision, so they are not part of the four).

## Context & Scope

The task narrows `orchestrate-batch-admit.sh`'s cross-batch `file_scope_collision` dimension so
that a genuinely idle non-terminal task (no dispatch in flight, no lock, no live session) no
longer permanently blocks batch admission for every candidate that happens to overlap its
declared `file_scope`. The concurrency hazard this dimension is meant to catch is already fully
covered by `session_contention()`/D4 (live-session liveness via pid-alive / heartbeat staleness)
and by `task-lock.sh`'s held-lock scan; this task's fix removes only the redundant,
non-self-clearing part — ordering concerns belong in `dependencies[]`, not in a defer that can
never converge on its own.

Scope is deliberately narrow: the shared overlap predicate
(`context/patterns/file-footprint-overlap.md` / `scripts/lib/file-scope-overlap.sh`) is NOT
touched — only the **comparison-set filter** for the `cross_batch` branch changes. `in_batch`
behavior is explicitly required to stay bit-for-bit unchanged. The task is `self_modifying`
(declares `orchestrate-batch-admit.sh` itself) and therefore requires solo dispatch — expected and
already reflected in the delegation context.

## Findings

### Codebase Patterns

**Where the defer fires (`orchestrate-batch-admit.sh` lines 450-531).** The `$comparison_set` is
built from every entry in `active_projects` that is non-terminal, not the candidate itself, and
not `dependencies[]`-edge-connected in either direction (lines 452-460) — this set has no status
filter beyond terminal exclusion. The `$hit` computation (lines 462-477) then applies, for each
member of that set:

```
select($scope_kind == "cross_batch" or $other_num < $c) |
scopes_overlap_first($c_scope; ($other.file_scope // [])) as $ov_path |
select($ov_path != null and $ov_path != "") |
```

For `collision_scope == "in_batch"`, the `$other_num < $c` clause already narrows the direction
(only the lower-numbered in-batch task counts as a hit) — that clause is untouched by this task.
For `collision_scope == "cross_batch"`, the `select` always passes (`scope_kind == "cross_batch"`
is unconditionally true for anything not in `$cands`), so status is never consulted at all. This
is exactly the "ANY non-terminal task" behavior the task description names.

**The fix's natural insertion point.** Add a status check scoped to the `cross_batch` disjunct
only, e.g. (illustrative, not literal diff):

```jq
select(
  ($scope_kind == "cross_batch" and (($other.status // "") | ascii_downcase
     | . == "researching" or . == "planning" or . == "implementing"))
  or
  ($scope_kind == "in_batch" and $other_num < $c)
)
```

This keeps `in_batch`'s existing clause completely untouched (still `$other_num < $c` with no
status test) and adds the new evidence gate only to the `cross_batch` disjunct — matching the task
description's "in_batch behavior stays blocking and unchanged bit-for-bit" requirement precisely.
Tasks that fail the new `cross_batch` clause (i.e., an idle cross-batch overlap) fall out of `$hit`
entirely and flow into the *existing* `if $hit == null then` branch — which today already runs the
session-registry pass and, on no session hit, emits a plain `admit`. **This is the key design
fork the plan stage must resolve**: an idle-but-overlapping cross-batch task must not simply
vanish into a bare `admit` with no trace — the task description requires "a loud advisory field
[that] must never be silent." The plan needs to decide whether that advisory computation is
folded into the existing `$hit == null` branch (re-deriving "is there an idle overlapping
cross_batch task, even though it didn't count as a hit" as a separate, non-blocking lookup) or
computed once and threaded through, to avoid a second, near-duplicate `scopes_overlap_first` scan
over the same comparison-set construction logic.

**No status-derived discriminator field exists yet for "advisory."** A grep across
`agent-system/extensions/core/docs/` and `context/` for a literal `"advisory` field name found no
precedent — `defer_reason` is the only discriminator field in this schema today, and it is present
only on `defer` verdicts. The plan will need to name and design this new field from scratch. Given
the existing schema conventions (`self_modifying` is present on every verdict including `admit`;
`defer_reason` discriminates *why* a defer fired), a consistent shape would be a new field present
only on `admit` verdicts when an idle cross-batch overlap was found and suppressed — e.g.
`idle_cross_batch_overlap: {task_number, status, overlapping_path}` or a flat
`idle_collision_task_number` / `idle_collision_status` / `idle_collision_path` field triad mirroring
the existing `colliding_task_number`/`colliding_task_status`/`overlapping_path` naming already used
by the defer branch. This report intentionally leaves the exact field name/shape as a planning
decision rather than prescribing one, since it is pure schema design with no existing precedent to
defer to.

**Existing test fixtures need no behavioral changes, only additions.** Verified by reading both
test files' fixtures directly:

| File | Case | Cross-batch/other task | Status | In-flight under new rule? | Currently defers? | Breaks under fix? |
|---|---|---|---|---|---|---|
| `test-conflict-predicate.sh` | 2.2 | #841 (`g22_cross_batch_collider`) | `implementing` | yes | yes | **no** — stays deferred |
| `test-four-tier-conflict.sh` | 9 | #603 (`case_h_low`) | `implementing` | yes | yes | **no** — stays deferred |

No existing fixture in either file exercises a `cross_batch` collision against a `not_started`
(or `researched`/`planned`/`blocked`/`partial`/`pr_ready`) colliding task — every current
`cross_batch` fixture already uses `implementing`. This means the fix is a pure behavioral
narrowing with **zero regression risk against the existing suite** as written, but it also means
the suite currently has **no positive coverage at all** of the exact defect this task fixes (an
idle `not_started` cross-batch collider incorrectly deferring). New test cases are required in
both files: at minimum, one case mirroring 2.2/case-9's shape but with the colliding task's status
set to `not_started` (or another idle non-terminal status), asserting `decision == "admit"` and
the presence of the new advisory field with the correct colliding-task identity — this is the
task's own root-cause reproduction, and its absence from the current suite is exactly why the
BimodalLogic defect went unnoticed until observed in production.

**`in_batch` is unaffected by design, not merely by omission.** The task description states
`in_batch` behavior must stay unchanged "because both candidates there are genuinely about to be
dispatched." This is corroborated by `orchestrate-batch-admit.sh`'s own header comment (lines
207-217, "Deferral-direction rule for file_scope_collision") and by
`batch-orchestration-guardrails.md`'s Non-Negotiable 2 and its "Three Existing Admission Layers"
section: `in_batch` collisions are drawn from *this invocation's own candidate set*, which by
construction is about to be dispatched together — there is no "idle" case to gate on for `in_batch`
at all, since every in-batch candidate is, by definition, imminently active. This confirms the fix
should touch only the `cross_batch` disjunct.

### Schema Version Bump Scope

`grep -rl "orchestrate-batch-admit-v4" agent-system/extensions/core/` returns exactly three files:

1. `scripts/orchestrate-batch-admit.sh` (the `$schema` literal emitted 5 times across the jq
   program's branches, plus the header-comment prose).
2. `docs/architecture/batch-admit-schema.md` (the schema doc itself — field tables, example
   verdicts, and the full "Version History" section, which will need a new `v4 to v5` entry
   following the existing entries' style: what changed, and *why it was a version bump and not an
   additive field* — per this doc's own established convention for every prior bump).
3. `scripts/test-conflict-predicate.sh` (one assertion at line 216 pinning the literal
   `"orchestrate-batch-admit-v4"` string for case 3's non-regression check).

`scripts/test-four-tier-conflict.sh` does **not** pin the schema string anywhere (confirmed by
grep) — it only asserts on `decision`/`defer_reason`/`collision_scope`, so it needs no `$schema`
literal update, only the new test case(s) described above. This matches the task description's
"narrow blast radius" and "consumers branching on defer_reason are updated separately" framing —
`orchestrate-dry-run-report.sh`, `orchestrate-predispatch-review.sh`, and
`skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 all consume `defer_reason` but pin no `$schema`
string literal (confirmed for `dry-run-report.sh`/`predispatch-review.sh` by
`batch-admit-schema.md`'s own v4 consumer table, which states this explicitly), and their updates
for the new advisory-admit shape are task 60's declared scope
(`thread_evidence_gated_verdict_through_admission_consumers`), not this task's.

### Self-refuting Rationale in `batch-admit-schema.md`

The task description's claim is verified verbatim. `orchestrate-batch-admit.sh`'s own header
comment (lines 226-239, "Why this check is blocking, not advisory") reads:

> "if skipped, two sessions can concurrently edit the same files with no lock contention (**the
> colliding task holds no lock; it simply is not running**)"

The parenthetical concedes the premise the main clause needs to be false. If the colliding task
"simply is not running," there is no session to concurrently edit anything — the harm scenario
described (concurrent editing) cannot occur for the case the parenthetical describes. The
identical passage is duplicated in `batch-orchestration-guardrails.md`'s "Why This Check Is
Blocking, Not Advisory" section (lines 280-298) with the same wording ("two sessions can
concurrently edit the same files with no lock contention... the colliding task holds no lock; it
simply is not running"). Both occurrences need the correction the task description calls for:
recasting the rationale so it justifies **evidence-gating** (defer only while there is actual
execution evidence; otherwise surface loudly and admit) rather than the current blanket-defer
framing that the parenthetical itself already undermines.

### Missing `cross_batch` Row in the Blocking-vs-Advisory Table

`batch-orchestration-guardrails.md`'s Classification Table (lines 84-93) has exactly one row for
file-scope overlap:

```
| File-scope overlap (creation-time and runtime wave/cycle-split) | BLOCKING | On-disk `file_scope`
comparison, no agent invoked; an unserialized overlap risks silent concurrent-write corruption
discovered only later |
```

This row's own label — "creation-time and runtime wave/cycle-split" — explicitly scopes it to
layers 1 and 2 of the "Three Existing Admission Layers" section (task-creation-time pairwise
comparison, and the runtime wave/cycle-split check, both `in_batch`-shaped by construction). It
never mentions `orchestrate-batch-admit.sh`'s cross-batch extension at all. The task requires
adding the missing row — most naturally split into two: keep the existing row scoped explicitly to
`in_batch`/creation-time (still unconditionally BLOCKING, per the confirmed-unchanged reasoning
above), and add a new row for `cross_batch` reflecting the narrowed, evidence-gated behavior (still
BLOCKING while genuine execution evidence exists, but no longer for a merely-idle overlap, which
becomes the new advisory-admit path).

### Comparison-Set vs. Overlap-Predicate: Confirmed Scope Boundary

`file-footprint-overlap.md`'s Non-Goals section states explicitly: "No opinion on scan scope: this
document defines the overlap PREDICATE only... not how widely a caller applies it." This confirms
the task description's framing — this task changes only `orchestrate-batch-admit.sh`'s
**comparison-set membership test** (which candidates count as a hit), never the shared
`scopes_overlap_first`/`norm` predicate in `scripts/lib/file-scope-overlap.sh` or its canonical
definition. No edit to `file-footprint-overlap.md`'s algorithm content is implied by this task,
only to its consumer-table prose if it needs a one-line clarification of the narrowed `cross_batch`
consumer behavior (optional — the doc already disclaims scan-scope opinions, so this may need no
edit at all; a planning-stage judgment call, not a research finding).

### The Four Colliding Workaround Tasks (for the CLOSING STEP, not this task's scope)

Batch siblings confirmed: task 60 (`thread_evidence_gated_verdict_through_admission_consumers`,
`dependencies: [59]`, file_scope touching `skill-orchestrate/SKILL.md`,
`skill-orchestrate-hard/SKILL.md`, `commands/orchestrate.md`, `parse-command-args.sh`,
`orchestrate-dry-run-report.sh`, `orchestrate-predispatch-review.sh`,
`orchestrate-batch-results-template.md`, `task-lock.md`, `multi-task-operations.md`) and task 61
(`surface_coarse_file_scope_declarations_at_creation`, `dependencies: [59]`, file_scope touching
`validate-state.sh`, `commands/task.md`).

Cross-referencing every task's `dependencies[]` against `{59, 60, 61}` and each task's own declared
`file_scope` against 60's and 61's file_scope identifies exactly four tasks whose dependency edge
is attributable to a genuine `file_scope` overlap with 59/60/61 (i.e., a workaround for this
defect) rather than an unrelated broad-sweep dependency:

| Task | Overlap evidence |
|---|---|
| 53 | shares `skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md` with task 60 |
| 14 | shares `skill-orchestrate/SKILL.md` with task 60 |
| 17 | shares `commands/orchestrate.md` with task 60 |
| 44 | declares the whole `agent-system/extensions/core/context/` directory, which is a
      directory-prefix ancestor of task 59's own `context/patterns/file-footprint-overlap.md` and
      `context/patterns/batch-orchestration-guardrails.md` file_scope entries |

Two further tasks (48, 50) also list 59/60/61 in `dependencies[]`, but their `file_scope` declares
the repo-wide root `agent-system/extensions/` — a legitimate, much broader final-integration/
verification sweep unrelated to this specific collision, not a workaround for this defect. This
matches the task description's count of "four colliding tasks" exactly. This identification is
recorded here for the CLOSING STEP's benefit but is explicitly **out of scope for this task's own
implementation** — the task description gates edge removal on "after this task is implemented AND
deployed."

### Recommendations

1. **Implementation location**: the single jq `select(...)` clause inside the `$hit` computation
   (`orchestrate-batch-admit.sh` around line 467) is the only behavioral change needed to the
   comparison logic itself. Everything else (schema bump, doc corrections, new fields, new tests)
   flows from that one change.
2. **New field design**: settle on a name/shape for the advisory field before editing the schema
   doc, since the doc's Version History section requires documenting *why* this was a version bump
   (per its own established convention — every prior bump explains why an additive field was
   insufficient). Suggest reusing the existing `colliding_task_number`/`colliding_task_status`/
   `overlapping_path` field names, nested or suffixed, for continuity with the defer-branch
   vocabulary the guardrails doc and downstream consumers already understand.
3. **Test additions**: add at least one new case per test file exercising a `not_started` (or
   other idle non-terminal status) cross-batch collider, asserting `admit` + the new advisory
   field's presence and correctness — this is the task's own regression guard against the exact
   defect it fixes, and its current absence is a genuine coverage gap, not merely thoroughness.
4. **Doc updates**: (a) rewrite the self-refuting paragraph in both
   `orchestrate-batch-admit.sh`'s header comment and `batch-orchestration-guardrails.md`'s "Why
   This Check Is Blocking, Not Advisory" section to state the evidence-gated rationale without the
   internal contradiction; (b) split or add a `cross_batch` row in the Classification Table; (c)
   add a `v4 to v5` Version History entry to `batch-admit-schema.md` following the existing
   entries' template (what changed, why it was a version bump, and the per-consumer status table).
5. **Consumer non-scope reminder**: `orchestrate-dry-run-report.sh`, `orchestrate-predispatch-review.sh`,
   and `skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 are explicitly task 60's scope, not this
   task's — this task's own file_scope list does not include any of them, and the task description
   states this explicitly ("consumers branching on defer_reason are updated separately by the
   consumer-side task in this batch"). The plan should not add edits to those files.

## Decisions

- Confirmed the fix touches only the `cross_batch` disjunct of the collision-scan `$hit`
  computation; `in_batch`'s `$other_num < $c` clause is untouched.
- Confirmed the in-flight status set per the task description is exactly
  `{researching, planning, implementing}` (case-insensitive, matching the existing `is_terminal`
  helper's case-insensitivity convention already used elsewhere in the same script).
- Confirmed exactly three files pin the `orchestrate-batch-admit-v4` schema string
  (`orchestrate-batch-admit.sh`, `batch-admit-schema.md`, `test-conflict-predicate.sh`);
  `test-four-tier-conflict.sh` needs no `$schema` string update, only new test cases.
- Confirmed no existing test fixture in either test file currently exercises an idle
  (non-in-flight) `cross_batch` collision — both existing cross_batch fixtures use `implementing`
  — so the fix carries zero regression risk against the current suite but also currently has zero
  positive coverage of the defect it fixes.
- Left the exact shape/name of the new advisory field as an open planning decision (no existing
  schema precedent to defer to); documented candidate shapes for the plan stage to choose from.
- Identified tasks 60 and 61 as the batch's other two task numbers, and tasks 53/14/17/44 as the
  four workaround-edge colliding tasks the CLOSING STEP will need to touch after deployment (not
  in this task's own file_scope or implementation).

## Risks & Mitigations

- **Risk**: narrowing the comparison too broadly (e.g. accidentally touching the `in_batch` clause
  too) would violate the task's explicit "unchanged bit-for-bit" requirement.
  **Mitigation**: the recommended `select(...)` restructuring keeps the two disjuncts
  (`in_batch`/`cross_batch`) as separate clauses so `in_batch`'s existing `$other_num < $c` test is
  never touched; the existing `test-four-tier-conflict.sh` cases 7/8/10/11 (all `in_batch`) and
  `test-conflict-predicate.sh` case 2.1 (`in_batch`) already assert this behavior and will catch
  any accidental regression.
- **Risk**: a silent advisory (an idle overlap that gets admitted with no visible trace at all)
  would recreate, in a different form, exactly the kind of silent-harm profile the Blocking vs.
  Advisory criterion in `batch-orchestration-guardrails.md` exists to prevent for BLOCKING checks —
  and the task description is explicit that "the advisory must never be silent."
  **Mitigation**: design the new field so it is present on every `admit` verdict where an idle
  cross-batch overlap was found (never optional/omitted on a hit), mirroring how `self_modifying`
  is already present on every verdict regardless of branch — this is the existing schema's own
  precedent for "always-present, never silently omitted" fields.
- **Risk**: the version bump touches the same schema string in three unrelated files; missing one
  would leave the schema self-inconsistent (script emits v5, doc/tests still say v4).
  **Mitigation**: the `grep -rl "orchestrate-batch-admit-v4"` command used in this research is
  cheap and exhaustive — re-run it during implementation/verification to confirm all three (and
  only three) occurrences were updated.
- **Risk**: scope creep into task 60's territory (consumer files) given how closely related they
  are.
  **Mitigation**: this task's declared `file_scope` (six files) does not include any of task 60's
  consumer files; the plan should hold to that boundary strictly, per the task description's own
  explicit note about consumer updates being separate.

## Context Extension Recommendations

None — this is a meta task operating entirely within already-well-documented orchestrator-internal
machinery; the existing docs (`batch-admit-schema.md`, `batch-orchestration-guardrails.md`,
`file-footprint-overlap.md`) are comprehensive and are themselves the artifacts this task edits.

## Appendix

- Searches/reads performed: direct `Read` of `orchestrate-batch-admit.sh` (full),
  `docs/architecture/batch-admit-schema.md` (full), `context/patterns/batch-orchestration-guardrails.md`
  (full), `context/patterns/file-footprint-overlap.md` (full), `scripts/lib/file-scope-overlap.sh`
  (full); targeted `Read` of `test-conflict-predicate.sh` (lines 1-224) and
  `test-four-tier-conflict.sh` (lines 280-446); `grep -rn`/`grep -rl` for
  `"orchestrate-batch-admit-v4"` across `agent-system/extensions/core/`; a Python/json scan of
  `specs/state.json`'s `active_projects` for file_scope overlap against this task's six declared
  files and for `dependencies[]` edges naming 59/60/61.
- No web search was needed — this is a fully self-contained internal-codebase defect with the root
  cause already verified and stated in the task description.

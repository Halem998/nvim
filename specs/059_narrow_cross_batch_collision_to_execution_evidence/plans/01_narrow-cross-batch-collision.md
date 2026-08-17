# Implementation Plan: Task #59

- **Task**: 59 - Gate cross-batch file_scope collisions on execution evidence, not non-terminal status
- **Status**: [NOT STARTED]
- **Effort**: 4.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/059_narrow_cross_batch_collision_to_execution_evidence/reports/01_narrow-cross-batch-collision.md
- **Artifacts**: plans/01_narrow-cross-batch-collision.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`orchestrate-batch-admit.sh`'s `file_scope_collision` dimension defers a candidate against any
non-terminal task whose `file_scope` overlaps it, and for `collision_scope == "cross_batch"` it
does so unconditionally — so an idle `not_started` task with a broad scope becomes a permanent,
never-self-clearing blocker. This plan narrows the `cross_batch` disjunct of the `$hit` selection
to require actual execution evidence (status in `{researching, planning, implementing}`), converts
a provably-idle overlap into an `admit` verdict carrying a loud, always-present advisory field,
bumps the verdict schema to `orchestrate-batch-admit-v5`, corrects the self-refuting blocking
rationale, adds the missing `cross_batch` row to the Blocking-vs-Advisory table, and closes the
current test-coverage gap for the idle-collider case. Done means: both admission test suites are
green including new idle-collider cases, no `orchestrate-batch-admit-v4` literal survives in the
source store, and the four workaround `dependencies[]` edges (tasks 53, 14, 17, 44) are removed
after deploy.

### Research Integration

The research report is integrated throughout. Key findings carried into phases:

- The fix's only behavioral site is the `select(...)` inside the `$hit` list comprehension in
  `orchestrate-batch-admit.sh` (the `$comparison_set` construction is the terminal/dependency-edge
  filter and is NOT the evidence filter — do not touch it).
- `in_batch`'s `$other_num < $c` clause is structurally correct and must stay untouched; every
  in-batch candidate is imminently dispatched by construction, so there is no idle case to gate.
- Exactly three files pin the literal `orchestrate-batch-admit-v4`:
  `scripts/orchestrate-batch-admit.sh` (5 emit sites + 2 header-prose mentions),
  `docs/architecture/batch-admit-schema.md`, and `scripts/test-conflict-predicate.sh` (one
  assertion). `test-four-tier-conflict.sh` pins no schema literal.
- Both existing `cross_batch` fixtures (`test-conflict-predicate.sh` case 2.2's #841 and
  `test-four-tier-conflict.sh` case 9's #603) already use `status: "implementing"`, so they stay
  deferring and the change carries zero regression risk against the current suite — but that also
  means the suite has zero positive coverage of the defect being fixed.
- The research left the advisory field's name and shape as an open planning decision. **This plan
  settles it** (see "Design Decision: the advisory field" below) so implementation has no open fork.

**One research correction the implementer must know**: the report locates the self-refuting
"two sessions can concurrently edit the same files with no lock contention ... it simply is not
running" passage in `batch-orchestration-guardrails.md` at lines 280-298. It is **not there**. A
`grep -n "concurrently edit the same files"` finds that passage in exactly two places:
`orchestrate-batch-admit.sh`'s header comment and `docs/architecture/batch-admit-schema.md`'s
`## Why This Check Is Blocking, Not Advisory` section. The guardrails file's carrier of the same
blanket rationale is its **Classification Table row** ("File-scope overlap (creation-time and
runtime wave/cycle-split) | BLOCKING | ... an unserialized overlap risks silent concurrent-write
corruption discovered only later"), which is the same edit as the missing-`cross_batch`-row
requirement. Locate every passage by `grep`, never by the line numbers quoted in the report or in
this plan — they drift.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no ROADMAP.md was consulted.

## Design Decision: the advisory field

Settled here so no phase carries an open fork.

**Name**: `idle_overlap_advisory`. **Shape**: a nested object, not a flat field triad.

```json
"idle_overlap_advisory": {
  "colliding_task_number": 841,
  "colliding_task_status": "not_started",
  "overlapping_path": "case_x/shared.sh",
  "collision_scope": "cross_batch",
  "reason": "file_scope overlap with IDLE (not in-flight) task #841 (status \"not_started\", not in this batch) at case_x/shared.sh; admitted because no execution evidence exists — add a dependencies[] edge if ordering between them matters"
}
```

Rationale for each choice:

- **Nested, not flat**: the defer branch already emits top-level `colliding_task_number`,
  `colliding_task_status`, `overlapping_path`, and `collision_scope`. Nesting reuses that exact
  vocabulary (so a reader who understands the defer branch understands this immediately) without
  ever putting two different meanings behind one top-level key. A flat triad would make
  `colliding_task_number` mean "the thing that blocked you" on a defer and "the thing that did
  NOT block you" on an admit — precisely the kind of overload the schema doc's `collision_scope`
  vs. `severity` section already rejects once.
- **Always present when the condition holds, never optional**: the field appears on **every**
  verdict emitted after the collision scan (the plain `admit`, the `session_active` defer, and the
  `file_scope_collision` defer) whenever a suppressed idle cross-batch overlap exists. This follows
  `self_modifying`'s precedent (present on every verdict, including admits) rather than
  `defer_reason`'s (present only on defers), and it is what satisfies the task's "the advisory must
  never be silent" requirement. It is absent only when no idle cross-batch overlap was found, and
  on the three early-exit admit branches (unknown task / terminal status / empty `file_scope`) and
  the two `self_modifying` branches, none of which run the collision scan at all.
- **First-match, ascending `project_number`**: identical determinism convention to `$hit`.

## Design Decision: the predicate restructuring

Settled here so the implementer does not re-derive it. The current single-pass `$hit` comprehension
becomes a materialized `$overlaps` list plus two derived selections, so the advisory needs **no
second `scopes_overlap_first` scan**:

```jq
def is_in_flight: ascii_downcase as $s | ($s == "researching" or $s == "planning" or $s == "implementing");
```

```jq
(
  [
    $comparison_set[] as $other |
    ($other.project_number) as $other_num |
    ($cands | index($other_num)) as $in_batch_idx |
    (if $in_batch_idx == null then "cross_batch" else "in_batch" end) as $scope_kind |
    select($scope_kind == "cross_batch" or $other_num < $c) |
    scopes_overlap_first($c_scope; ($other.file_scope // [])) as $ov_path |
    select($ov_path != null and $ov_path != "") |
    {
      other_num: $other_num,
      other_status: ($other.status // ""),
      ov_path: $ov_path,
      scope_kind: $scope_kind,
      in_flight: (($other.status // "") | is_in_flight)
    }
  ]
) as $overlaps |
($overlaps | map(select(.scope_kind == "in_batch" or .in_flight)) | first) as $hit |
($overlaps | map(select(.scope_kind == "cross_batch" and (.in_flight | not))) | first) as $idle_overlap |
```

Why this shape:

- The comprehension body — including the `select($scope_kind == "cross_batch" or $other_num < $c)`
  direction filter — is copied **verbatim** from the current code with only the `in_flight` key
  added to the emitted object. The `in_batch` disjunct is therefore untouched bit-for-bit.
- `$hit`'s new filter admits every `in_batch` member unconditionally (they already passed the
  `$other_num < $c` direction test upstream) and admits a `cross_batch` member only when
  `in_flight`. That is exactly the narrowing, and nothing else.
- `$comparison_set` is already `sort_by(.project_number)`, so `| first` on either derived list
  preserves the existing ascending-order first-match determinism.
- Use `| not` for negation (`(.in_flight | not)`), never `!=` — see CLAUDE.md's "jq Command
  Safety" section on Issue #1132 escaping.

**Known and accepted behavior change beyond the headline narrowing**: when a candidate overlaps
both a lower-numbered idle `cross_batch` task and a higher-scanned `in_batch` task, the old code
emitted the `cross_batch` defer (first in ascending order) and the new code emits the `in_batch`
defer instead. The decision is `defer` either way; only the discriminator changes. This is correct
and intended — record it in the schema doc's Version History entry rather than treating it as a
regression.

## Goals & Non-Goals

**Goals**:
- Narrow the `cross_batch` disjunct of the state.json collision dimension to execution evidence
  (`{researching, planning, implementing}`, case-insensitive).
- Emit a loud, never-silent `idle_overlap_advisory` on every post-scan verdict where an idle
  cross-batch overlap was found and suppressed.
- Bump the verdict schema to `orchestrate-batch-admit-v5` across all three pinning files.
- Correct the self-refuting blocking rationale in `orchestrate-batch-admit.sh`'s header and in
  `batch-admit-schema.md`; correct/split the corresponding Classification Table row in
  `batch-orchestration-guardrails.md`.
- Close the test-coverage gap: new cases in both suites for the idle `not_started` cross-batch
  collider producing `admit` + advisory.
- After implementation **and deploy**, remove the workaround `dependencies[]` edges on tasks 53,
  14, 17, and 44 that point at 59/60/61.

**Non-Goals**:
- Any change to `in_batch` behavior. It stays blocking and bit-for-bit identical.
- Any duplication of liveness checking in the state.json dimension. Live-session coverage remains
  the `session_active` (D4 / `session_contention()`) dimension's exclusive job.
- Any change to the shared overlap predicate — `scripts/lib/file-scope-overlap.sh` and
  `context/patterns/file-footprint-overlap.md`'s algorithm content are out of scope. This is a
  comparison-set filter change only.
- Any edit to `defer_reason` consumers (`orchestrate-dry-run-report.sh`,
  `orchestrate-predispatch-review.sh`, `skill-orchestrate/SKILL.md` Stage MT-3 step 4.5,
  `skill-orchestrate-hard`). Those are task 60's declared scope and appear in no phase here.
- Any relaxation of the check as batch size grows. This is evidence-gating, not batch-size-gating.
- Any hand-edit under `.claude/`. That tree is a gitignored deploy artifact.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Accidentally altering the `in_batch` disjunct while restructuring `$hit` | H | M | Phase 2 copies the comprehension body verbatim and adds only the `in_flight` key; existing `in_batch` fixtures (predicate 2.1, four-tier 7/8/10/11) are the regression guard and must be green before the phase closes |
| A silent advisory (idle overlap admitted with no trace) | H | M | Field is emitted on all three post-scan verdicts, never optional; Phase 6 asserts its presence and its exact contents, not merely `decision == "admit"` |
| Schema bump lands in some but not all three pinning files, leaving script/doc/test disagreeing | M | M | Phase 3 is `atomic-batch` across the script and the test pin; its exit gate is `grep -rn "orchestrate-batch-admit-v4" agent-system/extensions/core/` returning zero hits |
| Editing `.claude/**` instead of the source store (edits silently wiped on next deploy) | H | M | Every phase's file list is under `agent-system/extensions/core/**`; Phase 7's verification greps the diff for any `.claude/` path before closing |
| Report's line-number citations (especially the guardrails 280-298 claim) send the implementer to the wrong passage | M | H | Corrected in "Research Integration" above; every phase instructs `grep`-based location, never line numbers |
| Scope creep into task 60's consumer files, which are closely related and tempting | M | M | Phase 7 verifies the full diff touches only the six declared `file_scope` files |
| Removing the workaround dependency edges before deploy, re-exposing the collision | M | L | Phase 7 gates edge removal on a successful `deploy-headless.sh` run and re-verifies admission against live state before writing state.json |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5, 6 | 3 |
| 5 | 7 | 4, 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Baseline capture and hypothesis confirmation [NOT STARTED]

**Goal**: Establish a green pre-change baseline and mechanically confirm every count and location
this plan asserts, before any file is modified.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/test-conflict-predicate.sh` and record the
      pass/fail tally verbatim.
- [ ] Run `bash agent-system/extensions/core/scripts/test-four-tier-conflict.sh` and record the
      pass/fail tally verbatim.
- [ ] Run `grep -rn "orchestrate-batch-admit-v4" agent-system/extensions/core/` and record every
      hit with its file and line.
- [ ] Confirm `test-conflict-predicate.sh` case 2.2's colliding task #841 and
      `test-four-tier-conflict.sh` case 9's task #603 both carry `status: "implementing"` in their
      fixtures (read the fixture-construction `jq` calls, not the assertions).
- [ ] Run `grep -rn "concurrently edit the same files" agent-system/extensions/core/` and record
      which files actually carry the self-refuting passage.
- [ ] Locate the Classification Table row in `batch-orchestration-guardrails.md` by
      `grep -n "File-scope overlap"` and record its line.

**Timing**: 20 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This plan asserts (a) exactly 3 files pin `orchestrate-batch-admit-v4`, with
5 emit sites plus 2 header-prose mentions in the script and 1 assertion in
`test-conflict-predicate.sh`; (b) both existing `cross_batch` fixtures use `implementing`; (c) the
self-refuting passage lives in exactly 2 files, not including the guardrails doc. Confirm each by
the `grep`/read commands above and record the actual results. If any count differs, update this
plan's later phases before proceeding rather than implementing against the stale hypothesis.

**Files to modify**: none (read-only phase).

**Verification**:
- Both suites report all-pass with no pre-existing failures. A pre-existing failure must be
  recorded and understood before Phase 2 begins; it must not be silently inherited as "expected".
- The recorded `v4` hit list, fixture statuses, and passage locations are written into the phase's
  progress notes so later phases can diff against them.

---

### Phase 2: Narrow the cross_batch disjunct and emit the advisory field [NOT STARTED]

**Goal**: Change the behavior — and only the behavior — in `orchestrate-batch-admit.sh`'s jq
program. The `$schema` string stays `v4` in this phase; the bump is Phase 3.

**Tasks**:
- [ ] Add `def is_in_flight: ascii_downcase as $s | ($s == "researching" or $s == "planning" or $s == "implementing");`
      immediately after the existing `def is_terminal:` line in the jq program, matching its
      case-insensitivity convention.
- [ ] Replace the single-pass `$hit` comprehension with the materialized `$overlaps` list plus the
      two derived selections exactly as specified in "Design Decision: the predicate restructuring"
      above. Copy the comprehension body verbatim; add only the `in_flight` key.
- [ ] Append `idle_overlap_advisory` to the plain `admit` verdict emitted when
      `$hit == null` and `$sess_hit == null`, using
      `+ (if $idle_overlap == null then {} else {idle_overlap_advisory: {...}} end)` so existing
      field order is unchanged and the new key is always last.
- [ ] Append the same conditional `idle_overlap_advisory` to the `session_active` defer verdict.
- [ ] Append the same conditional `idle_overlap_advisory` to the `file_scope_collision` defer
      verdict.
- [ ] Build the advisory's `reason` string to name the colliding task, its status, `cross_batch`,
      the overlapping path, and the `dependencies[]`-edge remedy, per the shape above.
- [ ] Do NOT touch `$comparison_set` construction, the `select($scope_kind == "cross_batch" or
      $other_num < $c)` direction filter, `session_contention()`, or `corroborated_by`.

**Timing**: 60 minutes

**Depends on**: 1

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - jq program only: new
  `is_in_flight` def, restructured `$overlaps`/`$hit`/`$idle_overlap`, advisory appended to three
  verdict objects.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` passes.
- Both suites re-run and match the Phase 1 baseline tally exactly — no new failures, no newly
  passing tests (existing fixtures are all `implementing` or `in_batch`, so behavior must be
  identical).
- Ad-hoc positive check against a scratch state fixture (a temp `STATE_FILE` copy, never the real
  `specs/state.json`): a candidate overlapping a `not_started` cross-batch task now yields
  `decision == "admit"` with an `idle_overlap_advisory` naming that task, its `not_started` status,
  and the overlapping path. Capture the verdict JSON in the phase notes.
- Ad-hoc negative check on the same scratch fixture: flipping that colliding task's status to
  `implementing` restores `decision == "defer"` with `defer_reason == "file_scope_collision"` and
  `collision_scope == "cross_batch"`.
- `git diff` for this phase shows changes only inside the jq program region of the one file.

---

### Phase 3: Bump the verdict schema to v5 [NOT STARTED]

**Goal**: Move every `orchestrate-batch-admit-v4` literal in the script and in the test pin to
`orchestrate-batch-admit-v5` in one atomic change, and correct the script header's rationale and
`cross_batch` deferral-direction prose in the same pass.

**Tasks**:
- [ ] Replace all 5 `$schema` emit-site literals in `orchestrate-batch-admit.sh` with
      `orchestrate-batch-admit-v5`.
- [ ] Replace both header-comment mentions of the pinned schema string with `v5`.
- [ ] Document `idle_overlap_advisory` in the header's verdict-schema field list, in the same style
      as the surrounding entries: name the nested keys, state that it is present on every post-scan
      verdict where a suppressed idle cross-batch overlap exists, and state the branches where it
      is structurally absent (three early-exit admits, both `self_modifying` branches).
- [ ] Rewrite the header's `cross_batch` bullet under "Deferral-direction rule for
      file_scope_collision": it no longer "defers UNCONDITIONALLY"; it defers only while the
      colliding task's status is in `{researching, planning, implementing}`, and otherwise admits
      with `idle_overlap_advisory`. Keep the `in_batch` bullet's wording untouched.
- [ ] Rewrite the header's "Why this check is blocking, not advisory" paragraph so it justifies
      **evidence-gating** instead of blanket deferral, and so the self-contradiction is gone. The
      corrected argument: a cross-batch overlap against an **in-flight** task satisfies both halves
      of the imported criterion (computable from on-disk state; the harm of skipping is a silent
      concurrent write). An overlap against a **provably idle** task satisfies neither — there is no
      second session to write concurrently, so the only real concern is *ordering*, which belongs in
      `dependencies[]` and is surfaced loudly by `idle_overlap_advisory` rather than by a defer that
      can never self-clear. Preserve the paragraph's existing closing guidance about not relaxing
      the check on false-positive grounds, and state explicitly that this narrowing is
      evidence-gating, not batch-size-gating.
- [ ] Update `test-conflict-predicate.sh`'s single `orchestrate-batch-admit-v4` assertion (case 3's
      non-regression check) to `orchestrate-batch-admit-v5`, and update the adjacent `info` message
      text so it no longer says "v4".

**Timing**: 50 minutes

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Scope Hypothesis**: This phase asserts the batch is exactly two files
(`orchestrate-batch-admit.sh`, `test-conflict-predicate.sh`) and exactly 8 literal replacements
(5 emit + 2 header + 1 assertion). Confirm against Phase 1's recorded `grep` output before editing;
the exit gate below is the mechanical confirmation. The batch is declared here in advance —
intermediate per-file states are expected red (the test pins v5 while the script still emits v4, or
vice versa) and MUST NOT be committed. Do not widen the batch after the fact.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - schema literals, header field
  documentation, deferral-direction bullet, blocking-rationale paragraph.
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` - the one schema-literal
  assertion and its `info` message.

**Verification**:
- `grep -rn "orchestrate-batch-admit-v4" agent-system/extensions/core/scripts/` returns zero hits
  (`batch-admit-schema.md` still legitimately holds v4 references until Phase 4).
- `grep -c "orchestrate-batch-admit-v5" agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`
  equals the Phase 1 count of v4 occurrences in that file.
- `bash -n` passes on both scripts.
- Both suites green.
- Re-read the rewritten rationale paragraph and confirm no sentence both asserts concurrent-edit
  harm and concedes the colliding task is not running.

---

### Phase 4: Update batch-admit-schema.md to v5 [NOT STARTED]

**Goal**: Bring the schema document into agreement with the v5 script: version string, new field
definition, new example verdict, corrected blocking rationale, and a v4-to-v5 Version History entry
following the document's own established convention.

**Tasks**:
- [ ] Update the `**Status**:` line to Version 5 (`orchestrate-batch-admit-v5`).
- [ ] Update every `"$schema":"orchestrate-batch-admit-v4"` occurrence in the example verdicts and
      the `$schema` row of the Field Definitions table to v5.
- [ ] Add an `idle_overlap_advisory` row to the Field Definitions table: type `object`, presence
      "present on any post-scan verdict (admit, `session_active` defer, or `file_scope_collision`
      defer) when a suppressed idle cross-batch overlap exists; absent otherwise and on all
      pre-scan branches", with the four nested keys and `reason` enumerated.
- [ ] Add a new example verdict under `## Complete JSON Schema` for the idle-cross-batch admit case,
      in the same compact one-line style as the existing examples.
- [ ] Rewrite `## Why This Check Is Blocking, Not Advisory` to the evidence-gated argument (same
      substance as Phase 3's header rewrite, at document length). Retitle if the current title no
      longer describes the section's claim — e.g. to name the in-flight/idle split explicitly.
- [ ] Update `## Deferral-Direction Rule and Caller Guidance`'s `cross_batch` prose to the narrowed
      rule, leaving the `in_batch` prose untouched.
- [ ] Review `## Precedence: Self-Modification, Then Collision, Then Session-Registry` and
      `## Accepted False-Positive Profile` for statements the narrowing falsifies (in particular any
      claim that an idle non-terminal overlap defers, or any false-positive accounting that assumed
      it did) and correct them.
- [ ] Add a `**v5**` Version History entry after v4, matching the existing entries' template: what
      changed, and — as every prior entry does — *why this was a version bump rather than an
      additive field*. The reason: a v4-aware consumer branching on `decision` alone will read an
      idle-overlap admit as an unqualified all-clear and will not surface the advisory, silently
      losing the very signal the narrowing exists to make loud; and a v4 consumer's defer handling
      no longer sees the cross-batch idle case at all. Also record the accepted discriminator change
      documented under "Design Decision: the predicate restructuring" above (a candidate overlapping
      both an idle lower-numbered cross-batch task and an in-batch task now reports `in_batch`
      instead of `cross_batch`; the decision is `defer` either way).
- [ ] Note in the Version History entry that `defer_reason` consumers are updated separately (task
      60's scope) — describe them by file, not by task number.

**Timing**: 50 minutes

**Depends on**: 3

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`

**Verification**:
- `grep -c "orchestrate-batch-admit-v4" agent-system/extensions/core/docs/architecture/batch-admit-schema.md`
  returns hits only inside the Version History's historical `**v4**` entry prose (a historical
  reference to the old version string is correct there); every live example, status line, and field
  row reads v5.
- Diff read-through confirms every changed hunk is prose or a fenced JSON example, with no
  executable surface.
- Each example verdict in the document is valid JSON (`jq -e . <<<'...'` on each one).
- The new Version History entry answers the "why a bump, not an additive field" question the
  document's own prior entries all answer.

---

### Phase 5: Correct the guardrails table and rationale; resolve file-footprint-overlap.md [NOT STARTED]

**Goal**: Add the missing `cross_batch` row to the Blocking-vs-Advisory Classification Table with
the corrected rationale, and make an explicit, recorded decision about whether
`file-footprint-overlap.md` needs any edit at all.

**Tasks**:
- [ ] In `batch-orchestration-guardrails.md`, split the single `File-scope overlap (creation-time
      and runtime wave/cycle-split)` Classification Table row into two rows: keep the existing row
      scoped explicitly to `in_batch`/creation-time (still unconditionally BLOCKING, with its
      existing "Why" text intact), and add a new `cross_batch` row.
- [ ] Write the new `cross_batch` row's Classification as BLOCKING-when-in-flight / ADVISORY-when-
      idle, with a "Why" cell stating the evidence-gated reasoning: an overlap against a task in
      `{researching, planning, implementing}` satisfies both halves of the criterion; an overlap
      against a provably idle task satisfies neither, because there is no second session, so the
      residual concern is ordering (which `dependencies[]` expresses) and it is surfaced loudly via
      `idle_overlap_advisory` rather than deferred.
- [ ] Check `## Blocking vs. Advisory: The Criterion`'s prose and `## Batch-Size Scaling: Scope of
      Deferral, Not Existence of the Check` for any statement the narrowing falsifies; if the
      batch-size section is cited as forbidding this change, add one sentence distinguishing
      evidence-gating from batch-size-gating.
- [ ] Check `## Non-Negotiables` and `## The Three Existing Admission Layers` for language asserting
      unconditional cross-batch deferral and correct it if present.
- [ ] Read `file-footprint-overlap.md`'s Non-Goals and consumer prose and decide explicitly: either
      add a one-line clarification that `orchestrate-batch-admit.sh`'s cross-batch consumer now
      applies the predicate over an evidence-filtered comparison set, or record a
      `#### Reasoned Exclusions` entry in this phase explaining why no edit is warranted (the
      document already disclaims any opinion on scan scope). Do NOT change the algorithm content or
      the predicate definition under any circumstance.

**Timing**: 40 minutes

**Depends on**: 3

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` - clarification only,
  or no change with a recorded reasoned exclusion.

**Verification**:
- The Classification Table has a row whose Guardrail cell names `cross_batch`, and the pre-existing
  file-scope row's Guardrail cell now names `in_batch` explicitly.
- Table rendering is intact (equal pipe-delimited column counts on every row).
- `git diff` on `file-footprint-overlap.md` is either empty (with a reasoned-exclusion record in the
  phase notes) or confined to consumer-facing prose — the `scopes_overlap`/`norm` algorithm
  definition is byte-identical either way.
- Diff read-through confirms every changed hunk is prose or table markup.

---

### Phase 6: Add idle-collider regression tests to both suites [NOT STARTED]

**Goal**: Close the coverage gap the research identified — no existing fixture exercises an idle
cross-batch collider — with positive tests in both suites that fail against the pre-Phase-2 script.

**Tasks**:
- [ ] In `test-conflict-predicate.sh`, add a Group 2 case (numbered after 2.4, e.g. 2.5) mirroring
      case 2.2's shape but with the cross-batch colliding task's status set to `not_started`:
      assert `decision == "admit"`, `has("defer_reason") == false`, `has("idle_overlap_advisory")`,
      and that the advisory's `colliding_task_number`, `colliding_task_status` (`not_started`),
      `collision_scope` (`cross_batch`), and `overlapping_path` are all correct.
- [ ] In `test-conflict-predicate.sh`, add a companion case asserting the advisory is **absent** on
      a verdict with no idle cross-batch overlap (e.g. case 2.1's `#830` admit), so "always present"
      cannot be trivially satisfied by an unconditional field.
- [ ] In `test-conflict-predicate.sh`, add a case flipping the same idle collider's status to each
      of `researching`, `planning`, and `implementing` and asserting `defer` +
      `defer_reason == "file_scope_collision"` + `collision_scope == "cross_batch"` for each —
      pinning the in-flight set boundary, not just one member of it.
- [ ] In `test-four-tier-conflict.sh`, add a case mirroring case 9's two-pass shape but with the
      pass-1 winner idle (`not_started` instead of `implementing`), asserting that pass 2 over the
      deferred singleton now returns `admit` with the advisory — i.e. the non-convergence path
      converges once the collider is provably idle. Use a fresh `case_*` file_scope namespace so it
      cannot interfere with the existing `case_g`/`case_h` fixtures.
- [ ] In `test-four-tier-conflict.sh`, add an assertion that the existing `in_batch` cases (7, 8,
      10, 11) still report `collision_scope == "in_batch"` — an explicit bit-for-bit guard on the
      untouched disjunct.
- [ ] Follow each suite's existing fixture-construction, `pass`/`fail`/`info`, and cleanup
      conventions exactly; add new fixture projects in their own number range and remove them at the
      end of the case if the surrounding suite does so.

**Timing**: 70 minutes

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh`
- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh`

**Verification**:
- Both suites run green, with the new cases visibly present in the pass tally (the tally is strictly
  larger than the Phase 1 baseline by the number of cases added).
- Negative control: temporarily revert `orchestrate-batch-admit.sh` to its pre-Phase-2 `$hit`
  selection (via `git stash` of that hunk or a scratch copy — never a destructive reset on a dirty
  tree) and confirm the new idle-collider cases **fail**. Restore immediately. A new test that
  passes against the old predicate is not testing the fix.
- `bash -n` passes on both test scripts.

---

### Phase 7: Full verification sweep, deploy, and workaround-edge removal [NOT STARTED]

**Goal**: Confirm the whole change is coherent and in-scope, deploy the source store to `.claude/`,
and only then remove the four workaround `dependencies[]` edges that exist solely to work around
the defect this task fixes.

**Tasks**:
- [ ] Run both suites one final time; both green.
- [ ] `grep -rn "orchestrate-batch-admit-v4" agent-system/extensions/core/` returns hits only inside
      `batch-admit-schema.md`'s historical `**v4**` Version History entry.
- [ ] `grep -rn "concurrently edit the same files" agent-system/extensions/core/` returns zero hits,
      or only hits inside a corrected passage that no longer self-refutes.
- [ ] Review the complete `git diff` for this task and confirm it touches exactly the six declared
      `file_scope` files and nothing else — in particular no `.claude/**` path, and none of
      `orchestrate-dry-run-report.sh`, `orchestrate-predispatch-review.sh`,
      `skill-orchestrate/SKILL.md`, `skill-orchestrate-hard/SKILL.md`, or
      `scripts/lib/file-scope-overlap.sh`.
- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` (or the repo's equivalent
      deploy path) so `.claude/` reflects the updated source store, and confirm the deployed
      `.claude/scripts/orchestrate-batch-admit.sh` emits `orchestrate-batch-admit-v5`.
- [ ] Only after a successful deploy: re-run the deployed admission script against the real
      `specs/state.json` for task 59 and confirm the verdict shape is v5, as a live smoke check.
- [ ] Remove from `specs/state.json` the `dependencies[]` entries naming 59, 60, or 61 on tasks 53,
      14, 17, and 44 — and only those entries. Re-verify each of the four tasks' remaining
      `dependencies[]` array against its pre-edit value so no unrelated edge is dropped.
- [ ] Leave tasks 48 and 50 untouched: their 59/60/61 edges accompany a repo-wide
      `agent-system/extensions/` file_scope and are a legitimate final-integration dependency, not a
      workaround for this defect.
- [ ] Run `bash .claude/scripts/generate-todo.sh` to regenerate TODO.md from the edited state.json.
- [ ] Validate `specs/state.json` parses (`jq -e . specs/state.json`) and, if present, run the
      repo's state validator.

**Timing**: 50 minutes

**Depends on**: 4, 5, 6

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts exactly four tasks (53, 14, 17, 44) carry removable
workaround edges and that tasks 48 and 50 do not. Confirm at implementation time by re-deriving the
list from `specs/state.json`: for every task whose `dependencies[]` intersects `{59, 60, 61}`,
compare its declared `file_scope` against 59/60/61's. A task whose only relation is a genuine
file_scope overlap with this batch is a workaround; a task declaring the repo-wide
`agent-system/extensions/` root is not. Record the re-derived list and reconcile any divergence from
the four before editing state.json.

**Files to modify**:
- `specs/state.json` - remove the four workaround `dependencies[]` edges.
- `specs/TODO.md` - regenerated, not hand-edited.

**Verification**:
- Both suites green; `bash -n` clean on all three edited scripts.
- The `v4` grep and the `.claude/**` diff check above both come back clean.
- Deployed `.claude/scripts/orchestrate-batch-admit.sh` emits v5.
- `jq` confirms tasks 53, 14, 17, 44 no longer list 59, 60, or 61 in `dependencies[]`, and that each
  of their remaining edges matches its pre-edit value minus exactly the removed entries.
- `jq` confirms tasks 48 and 50 still list their 59/60/61 edges.
- TODO.md regenerated from state.json (not hand-edited) and parses cleanly.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/test-conflict-predicate.sh` passes, with a strictly
      larger pass tally than the Phase 1 baseline.
- [ ] `bash agent-system/extensions/core/scripts/test-four-tier-conflict.sh` passes, with a strictly
      larger pass tally than the Phase 1 baseline.
- [ ] Negative control confirmed: the new idle-collider cases fail against the pre-fix predicate.
- [ ] `bash -n` clean on `orchestrate-batch-admit.sh`, `test-conflict-predicate.sh`, and
      `test-four-tier-conflict.sh`.
- [ ] No `orchestrate-batch-admit-v4` literal survives outside `batch-admit-schema.md`'s historical
      Version History entry.
- [ ] `in_batch` bit-for-bit guard: predicate case 2.1 and four-tier cases 7, 8, 10, 11 all still
      report `collision_scope == "in_batch"` with unchanged decisions.
- [ ] Every example verdict in `batch-admit-schema.md` is valid JSON.
- [ ] Full diff touches only the six declared `file_scope` files plus `specs/state.json` and
      `specs/TODO.md` in Phase 7.

## Artifacts & Outputs

- `specs/059_narrow_cross_batch_collision_to_execution_evidence/plans/01_narrow-cross-batch-collision.md` (this file)
- `specs/059_narrow_cross_batch_collision_to_execution_evidence/summaries/01_narrow-cross-batch-collision-summary.md`
- Modified: `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`
- Modified: `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`
- Modified: `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- Modified (or explicitly unchanged with a reasoned exclusion): `agent-system/extensions/core/context/patterns/file-footprint-overlap.md`
- Modified: `agent-system/extensions/core/scripts/test-conflict-predicate.sh`
- Modified: `agent-system/extensions/core/scripts/test-four-tier-conflict.sh`
- Modified: `specs/state.json` (workaround-edge removal, Phase 7 only)

## Rollback/Contingency

- Each phase commits on green, so any phase can be reverted independently with `git revert` of its
  commit. Phase 3 is a declared `atomic-batch` and reverts as a single unit.
- If the restructured `$overlaps`/`$hit` selection proves subtly wrong under real state, revert
  Phase 2 and Phase 3 together (the schema string must never emit v5 with v4 behavior) and re-derive
  the selection against a scratch state fixture before retrying.
- If deploy fails in Phase 7, stop before the state.json edit: the workaround edges must remain in
  place until the fix is actually deployed, or the collision they work around re-fires.
- If the workaround-edge removal turns out to have dropped an unrelated edge, restore the four
  tasks' `dependencies[]` arrays from the pre-edit `specs/state.json` in git history and re-derive
  the removal set task by task.
- The task is `self_modifying` and requires solo dispatch. If a revert leaves `.claude/` and the
  source store disagreeing, re-run `deploy-headless.sh` rather than hand-editing `.claude/**`.

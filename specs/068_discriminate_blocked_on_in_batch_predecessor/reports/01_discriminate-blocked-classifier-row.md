# Research Report: Task #68

**Task**: 68 - Make the multi-task /orchestrate classifier's `blocked` row DISCRIMINATING
**Started**: 2026-08-31T00:00:00Z
**Completed**: 2026-08-31T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase read (`agent-system/extensions/core/**`), prior-art report (archived task `orchestrate_eligibility_not_status_gated`), live `state.json` schema probe
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Root cause, re-derived**: Stage MT-3 step 3's dependency-graph eligibility gate (in
  `skills/skill-orchestrate/SKILL.md`) already correctly discriminates in-batch predecessors —
  it excludes a task from `eligible_tasks` while a predecessor is still in-progress and admits it
  once the predecessor reaches a terminal state. The chain in the live repro (437→436→434→433)
  is therefore *correctly* wave-ordered and *correctly* re-admitted to `eligible_tasks` cycle
  over cycle. The defect is entirely downstream: Stage MT-3 step 4.5 immediately re-classifies
  that now-eligible task by its literal `status` string, and the classifier's `blocked` arm
  ignores everything step 3 just established, unconditionally emitting `group: "skip"` for
  engine `mt`. Nothing between step 3 and step 4.5 (or anywhere else) ever rewrites the stale
  `status: "blocked"` string, so the same non-informative classification repeats every cycle
  until `MAX_CYCLES_MT` is spent. The bug is a **lost signal**, not a missing gate: the ordering
  constraint is already solved correctly one layer down; the classifier just never asks it.
- `/spawn` already writes the exact signal the fix needs and doesn't need to change: it
  preserves the task's pre-block phase status as `previous_status` (`skills/skill-spawn/SKILL.md`
  Stage 2, `state-write.sh` call around line 100-119) and adds the new unblocker task's number to
  the parent's `dependencies[]` (Stage 13, lines ~415-427) — so a blocked task's discharge target
  phase is already recorded, not something that has to be inferred or re-derived.
- **Recommended discriminator**: read `dependencies[]` for the blocked candidate directly from
  the classifier's *already-slurped* `state_arr[0].active_projects` (no new read, no new CLI
  argument, no call-site change — the classifier reads the whole file today, not just the
  candidate rows). Discharge requires ALL THREE:
  1. `dependencies[]` is non-empty (an empty list is not evidence of resolution — see Risks).
  2. every listed dependency's own `status` in state.json is exactly `"completed"` (not the
     broader `is_terminal` set — see Decisions #1 below for why `abandoned`/`expanded`
     predecessors must NOT silently discharge).
  3. the candidate's `.orchestrator-handoff.json` `blockers[]` array (read under the SAME
     Context-Flatness-compliant widening the task description names) is empty or the handoff is
     absent.
  If all three hold: route via `previous_status` through the *same* not_started/researched/
  planned-or-implementing/researching/planning logic the classifier already applies to a live
  status, using `previous_status` as the input instead of `status`. If `previous_status` is
  itself missing (a hand-set block, or a handoff written before this field existed), do not
  guess — stay `needs_human` with a reason naming the gap. If discriminator 1 or 2 fails: stay
  `skip` (mt) / `needs_human` (single), exactly as today, with a reason string naming which
  dependency is still outstanding. If discriminator 3 fails (blockers present) even though 1-2
  hold: `needs_human` for both engines, citing the blocker count — this reuses the *exact*
  precedence shape (continuation > blockers > neither) the `partial` row already established,
  applied to `blocked` instead of introducing a new shape.
- **No status-rewrite component is needed.** `skill_validate_input` (`scripts/skill-base.sh`)
  only blocks the three terminal statuses; it does not require any particular incoming status
  for a given operation. `update-task-status.sh`'s preflight write unconditionally overwrites
  `status` to the in-progress variant of whatever operation was dispatched, with no precondition
  on the prior value. So once the classifier routes a discharged `blocked` task to (say)
  `plan`, Stage MT-4 dispatches `skill-planner`, whose own `skill_preflight_update` call
  overwrites the stale `"blocked"` string to `"planning"` as an ordinary side effect of being
  dispatched — this is the *identical* mechanism the prior `researching`/`planning` convergence
  fix already relies on, verified by direct read rather than assumed by analogy.
- **Prior art (Decision 3, archived task `orchestrate_eligibility_not_status_gated`, report
  `01_admission-predicate-eligibility-and-self-mod-tiebreak.md` line 383)** — "`blocked` and
  `unknown` rows: leave unchanged... No argument surfaced during this research to widen scope to
  either row" — is **narrowed, not overturned wholesale**: the `unknown` row stays untouched (no
  new argument for it here either), and the `blocked` row's classification-vs-argument logic is
  narrowed to exactly the discriminated case this task supplies fresh evidence for (an in-batch
  predecessor's ordering constraint being silently thrown away downstream of a gate that already
  solved it). The single-engine `blocked → needs_human` divergence for the *non-discharged* case
  is unaffected and remains DESIGN per the classifier's own audit discriminator.
- `context/patterns/batch-orchestration-guardrails.md`'s normative principle ("a guardrail should
  degrade to an ORDERING CONSTRAINT whenever possible... never as an accidental consequence of a
  gate's implementation shape") already implies this fix in prose — the `blocked` classifier
  verdict is simply not yet a row in that file's Gate Catalogue table, because until now it was a
  triage verdict layered blindly on top of an admission gate that had already solved the ordering
  question. This task should add it as a new ORDERING CONSTRAINT row (discharged sub-case) with a
  companion note that the *non-discharged* sub-case is a documented, deliberate divergence, not a
  second exclusion.

## Context & Scope

Researched only the discrimination/routing question and its immediate co-maintenance set,
per the task's binding scope rules (edit only `agent-system/extensions/core/**`). Did not
re-derive the OBSERVED DEFECT or LIVE REPRODUCTION sections (given as ground truth); this report
re-derives the CAUSE (why the loop cannot converge) and settles the four open design questions
the task description poses.

## Findings

### Codebase Patterns

**The classifier (`scripts/orchestrate-triage-classify.sh`, 334 lines) — exact anchors**:
- Header verdict table row: line 63, `| blocked | skip | needs_human |`.
- Justification prose: lines 77-90, ending with the audit discriminator quoted in the task
  description verbatim ("does the OTHER engine's own handler implement the divergence in its own
  code, or does only this shared table assert it?").
- `jq` arm: `elif $status == "blocked"` (confirmed present, unconditional `if $engine == "mt" then
  "skip" else "needs_human" end`), the last `elif` before the catch-all `unknown` `else` branch.
- The script already slurps the **entire** `specs/state.json` into `$state_arr` once
  (`--slurpfile state_arr "$STATE_FILE"`) and derives `$all` = `.active_projects // []` — this is
  used today only to look up each candidate's OWN row, but nothing prevents looking up an
  *arbitrary other* task number's row from the same already-loaded `$all` array inside the same
  `jq` invocation. This is the concrete basis for the "no new read, no call-site change" claim:
  the dependency lookup is a second `select(.project_number == $dep)` against data already in
  memory, not a second file read.
- The handoff read (currently gated to `status == "partial"` only, lines ~186-246) needs
  widening to also run for `status == "blocked"` candidates, reusing the identical
  `blocker_count`/`age_min` extraction already written — this is the "scope widening of an
  existing read, not a new I/O class" the task names.

**Stage MT-3 step 3 (`skills/skill-orchestrate/SKILL.md`, ~lines 1529-1556) — the gate that
already solves ordering**: "Build eligible_tasks: For each task, include it if ALL of the
following are true: ... All predecessors from `dependency_graph[task_num]` are in terminal state
or `failed_tasks`." Two explicit sub-rules follow: a `failed_tasks`-listed predecessor moves the
dependent straight to `failed_tasks` with status `blocked` (this already correctly satisfies the
task's acceptance criterion "a task whose predecessor FAILED still lands in `failed_tasks`" and
needs NO change); a still-in-progress predecessor defers the dependent to next cycle. Crucially,
`dependency_graph` itself is **intra-batch only** by construction — `commands/orchestrate.md`
Step 2 explicitly restricts wave/graph edges to `dependencies[]` entries that are also in
`validated_tasks` ("Restrict to intra-batch dependencies only (ignore dependencies on tasks not
in `validated_tasks`)"), with out-of-batch edges deliberately handled by a SEPARATE mechanism
(pre-dispatch review, Step 1.5, reporting-only). This step-3 gate is status-agnostic: it applies
identically whether the task's `status` is `blocked`, `researching`, `not_started`, etc. — it has
never needed to know about `status` at all, which is exactly why it already gets the ordering
question right while the classifier (which looks at nothing but `status`) gets it wrong.

**Why "predecessor present in the classifier's own CLI candidate list" (an initially tempting
reading of the task's Fact 1) does NOT work as the mechanism** and why the actual mechanism must
instead look up the dependency's status from the already-slurped full `active_projects` array:
in the live path, Stage MT-3 step 4.5 calls the classifier with `"${eligible_tasks[@]}"`
(`skills/skill-orchestrate/SKILL.md` line ~1584) — the per-cycle, *shrinking* eligible set, not
the stable original `task_numbers`. Step 3's own rule 1 excludes any `{completed, abandoned,
expanded}` task from `eligible_tasks`. So by the exact cycle in which a blocked successor first
becomes eligible (its predecessor just turned terminal the cycle before), that predecessor has
*already* dropped out of `eligible_tasks` and is therefore absent from the classifier's own `$@`
that cycle — checking "is dependency #437 among my sibling candidates" would read FALSE for
task 436 in precisely the reproduction scenario, reproducing the very defect being fixed. The
fact that IS true and useful is narrower and simpler: the classifier already has ALL of
`state.json` loaded, so it can resolve *any* dependency's current status regardless of whether
that dependency is among this cycle's candidate arguments. This requires zero widening of the
CLI's variadic argument list and zero change to either existing call site (`Stage MT-3 step 4.5`'s
`eligible_tasks` call, or `orchestrate-dry-run-report.sh`'s `validated_tasks` call) — matching
the task's "no new argument, no call-site change" constraint literally rather than loosely.

**`/spawn`'s existing writes are exactly what the fix needs, unchanged** (`skills/skill-spawn/
SKILL.md`):
- Stage 2 (~lines 100-119): `state-write.sh` sets `status: "blocked"` AND `previous_status: $prev`
  in the same write, where `$prev` is the status captured immediately before the transition.
  Comment at line 98: "`[BLOCKED]` means 'has unmet dependencies', not 'encountered an error'" —
  corroborates that `blocked` has always been documented as pure ordering information, matching
  the live repro's `blockers: []` observation.
- Stage 13 (~lines 415-427): adds the newly spawned unblocker task's number to the *parent's*
  `dependencies[]` array — this is the `dependencies[437]`-style edge the live repro's chain
  relies on, confirmed as the actual write site (not inferred).
- No candidate design in this report requires any edit to `skill-spawn/SKILL.md` — `previous_status`
  is already the exact discharge-target signal needed, and `dependencies[]` is already the exact
  ordering signal needed. Design Direction question 4 ("should `/spawn` stop writing `blocked` at
  all") is answered NO: the redundancy with `dependencies[]` is deliberate and load-bearing —
  `dependencies[]` alone cannot distinguish "blocked, ordering only" from "blocked, needs a
  human" without the discrimination this task adds; removing the status string would only remove
  a value that the fixed classifier is about to start reading meaningfully.

**No status-precondition guard blocks discharge-then-dispatch**: `scripts/skill-base.sh`'s
`skill_validate_input` (~lines 179-209) only rejects the three terminal statuses
(`completed`/`abandoned`/`expanded`); it has no allow-list keyed by operation. `scripts/
update-task-status.sh`'s preflight branch (`update_state_json`, ~lines 611-625) writes
`status: $status` unconditionally via `state-write.sh`, with no read-modify-check against the
prior value — it is a pure overwrite. This means a `blocked` task dispatched to (say) `plan`
transitions cleanly to `"planning"` the moment `skill_preflight_update` runs, with no special
casing required. This mirrors, and is confirmed by direct read to work the same way as, the
already-shipped `researching`→dispatch, `planning`→dispatch convergence from the prior
`orchestrate_eligibility_not_status_gated` task (`skills/skill-orchestrate/SKILL.md` line
~1548-1551: "it becomes eligible, the classifier... routes it to the phase its status names, and
Stage MT-4's lock acquire reclaims the stale lock and dispatches it" — no separate rewrite step
was needed there either).

**`orchestrate-dry-run-report.sh`'s existing architecture already anticipates and needs this
exact fix**: it independently re-implements the intra-batch wave/Kahn computation (Step 3, ~lines
225-280) and separately excludes tasks with an unmet *out-of-batch* predecessor (Step 6, ~lines
428-447, keyed purely on `dependencies[]` + the dependency's own state.json status — NOT on the
candidate's own `status` field at all). It then calls the classifier once over the full
`validated_tasks` set (Step 7, ~line 464) and composes the admitted set by excluding anything the
classifier marks `skip`/`needs_human`/`terminal` (~lines 477-501, 531-536) *regardless of wave
number*. Concretely: today, a later-wave task blocked on an earlier-wave in-batch predecessor is
already excluded from "Admitted" by the unconditional `blocked → skip` classifier row, even
though its wave number is computed correctly and printed. Since the recommended discriminator
(dependency lookup from the already-slurped full state, not candidate-list membership) works
identically whether the dependency has already run (live path) or hasn't run yet (dry-run,
predecessor's `status` will be e.g. `"planned"`/`"not_started"`, not `"completed"` — so
discriminator 2 correctly reads FALSE at prediction time and the task correctly stays
excluded/skip), dry-run's existing single-pass architecture needs NO additional change beyond
picking up the classifier's new (still occasionally `skip`, now-discriminating) output — the
already-documented "static-vs-cycling divergence" note (~line 543-544: "a live run recomputes per
cycle against a shrinking eligible set, so the live run may admit tasks this report excludes")
already correctly scopes the residual gap between prediction and live-cycling behavior, and
remains accurate after this fix (it does not need rewording).

**Prior art located and read** (archived `specs/archive/067_orchestrate_eligibility_not_status_gated/reports/01_admission-predicate-eligibility-and-self-mod-tiebreak.md`):
- Decision 3 (line 383): "`blocked` and `unknown` rows: leave unchanged, per the task's own
  default. No argument surfaced during this research to widen scope to either row."
- That report's own framing (lines 318-322) already anticipated the shape of a future
  `blocked`-row change without committing to it: it names `blocked→needs_human (single) / skip
  (mt)` as "the one row this task changes" was scoped OUT of, listing it alongside rows with no
  fixture coverage at the time.
- This task supplies the "argument" that report explicitly said hadn't surfaced: a live,
  measured, reproducible infinite-skip defect for the in-batch-predecessor sub-case specifically.
  Decision 3 is therefore narrowed (not silently contradicted): the row stays unconditional for
  the *non-discharged* case (an unresolved, or out-of-batch, or handoff-blockers-non-empty
  block), and becomes discriminating only for the *discharged, in-batch, no-recorded-blockers*
  case.

**`context/patterns/batch-orchestration-guardrails.md`** (~lines 100-119, "Gate Catalogue
(post-fix)" table): confirmed the `blocked` classifier verdict has NO row in this table today —
the table covers `self_modifying`, `file_scope_collision` (three sub-cases), `session_active`,
held-lock, and `deploy_checkpoint` only. The "Unmet predecessor (dependency-graph eligibility)"
guardrail (Stage MT-3 step 3's gate) DOES appear in the earlier Blocking-vs-Advisory
classification table (marked BLOCKING) but likewise has no row in the Gate Catalogue
ordering-vs-exclusion table — an adjacent, pre-existing omission this report flags but does not
treat as in-scope to fix beyond noting it (see Risks). The normative principle stated
immediately above that table — "a guardrail should degrade to an ORDERING CONSTRAINT whenever
possible... never as an accidental consequence of a gate's implementation shape" — is a verbatim
match for this defect's shape: the `blocked` classifier verdict's unconditional `skip` was never
a deliberately justified exclusion for the in-batch-predecessor sub-case, it was an accidental
byproduct of the classifier never having been taught to look past the status string.

### Recommendations

1. **Classifier jq change** (`scripts/orchestrate-triage-classify.sh`): replace the unconditional
   `blocked` arm with a discriminating one. Pseudocode of the required logic (exact jq to be
   written at planning/implementation time):
   ```
   elif $status == "blocked" then
     ($all[] | select(.project_number == $c) | .dependencies // []) as $deps |
     ($all[] | select(.project_number == $c) | .previous_status // null) as $prev |
     if ($deps | length) == 0 then
       -> stays skip(mt)/needs_human(single); reason: "no tracked dependency; likely
          externally/manually blocked"
     elif (all $deps as $d: ($all[] | select(.project_number == $d) | .status) == "completed") | not
       -> stays skip(mt)/needs_human(single); reason names which dependency(ies) remain
          outstanding, and separately flags any dependency whose status is a NON-completed
          terminal (abandoned/expanded) as a distinct, louder warning (see Decisions #1)
     elif ($blockers_from_handoff | length) > 0 then
       -> needs_human (BOTH engines); reason cites blocker_count, matching the `partial` row's
          existing shape
     elif $prev == null then
       -> needs_human (BOTH engines); reason: "blocked with satisfied dependencies but no
          previous_status; cannot determine discharge phase"
     else
       -> re-dispatch $prev through the SAME not_started/researched/planned-or-implementing/
          researching/planning logic already in this script, i.e. treat $prev as if it were
          $status for routing purposes only
     end
   ```
   The single-engine `needs_human` outcome for the non-discharged branches is preserved
   unconditionally (Decision 2 below), so `single`'s only new behavior is the discharged branch
   itself — a solo `/orchestrate` on a task blocked on an already-completed dependency will now
   correctly dispatch instead of escalating to a human for no reason, which is a strict
   improvement consistent with the audit discriminator (see Decisions #3).
2. **Handoff read widening**: extend the existing `status == "partial"` gate on the handoff-read
   loop (lines ~186-246) to also fire for `status == "blocked"`, reusing the identical
   `blocker_count` extraction. No new I/O class, no new script dependency.
3. **Header table, justification prose, header schema doc**: rewrite the `blocked` row and its
   lines 77-90 justification paragraph so it no longer asserts unconditional divergence — state
   the new discriminated behavior and explicitly narrow (not delete) the "two independently
   corroborating handlers = design" framing: it remains true for the *non-discharged* sub-case,
   and the discharged sub-case is new, converged, non-diverging behavior for `mt` (still
   diverges from `single`'s conservative default of staying `needs_human` for the *non-discharged*
   case only — see Decisions #3 for whether `single` should ALSO discriminate).
4. **`skills/skill-orchestrate/SKILL.md`**: Stage MT-4's phase-grouping table (~line 2030) and its
   adjacent justification (~2039-2043) need the same rewrite as the classifier's own table, per
   the file's own "MUST be changed together" contract at line ~2033. The single-task `#### State:
   blocked` handler (~line 658) and its "Decision 1" note (~673-677) need updating only if
   Decision 3 below extends discrimination to `single` — otherwise a one-line cross-reference
   update pointing at the classifier's now-more-detailed audit note suffices.
5. **`skills/skill-orchestrate-hard/SKILL.md`**: confirmed (by direct read) its own `#### State:
   blocked` handler (~line 1037) is a compressed, standalone copy ("Read blockers from
   state.json. Invoke blocker escalation (Stage 6)") with NO MT-specific phase-grouping table of
   its own — its Multi-Task Mode section is a genuine "Same as base" pointer for MT stages (the
   file's own stated rationale for why bare pointers are otherwise risky, per the task
   description, applies to *mechanisms*, not to this single-task-only handler, which has no MT
   counterpart to omit). Recommend: no MT-specific edit needed here (correctly inherits via the
   pointer); the single-task handler needs the same single-task-scope decision as #4 above,
   applied consistently.
6. **`context/patterns/batch-orchestration-guardrails.md`**: add TWO new rows to the "Gate
   Catalogue (post-fix)" table: (a) `blocked` (discharged: in-batch dependency completed, no
   recorded handoff blockers) → ORDERING CONSTRAINT, self-clears once the classifier next runs
   after the predecessor's `status` write lands; (b) `blocked` (not discharged: dependency
   outstanding, dependency abandoned/expanded, or handoff blockers present) → stays whatever the
   *non-discharged* classification already is today (documented divergent design for `single`;
   ADVISORY-with-loud-warning skip for `mt`, per acceptance criteria). Consider (optional,
   flagged not mandated) also adding the pre-existing, currently-missing "Unmet predecessor
   (dependency-graph eligibility)" row while this file is open for edit, since it is the SAME
   omission class and the file is already being touched — see Risks for why this is optional
   rather than required.
7. **`scripts/orchestrate-dry-run-report.sh`**: no code change identified as required (Step 3's
   independent wave computation and Step 6's independent out-of-batch-predecessor exclusion
   already correctly complement the classifier's new discriminated output — see Findings above).
   Verify at planning/implementation time that the existing `reason` string surfaced through
   `$trow` (classifier's own `.reason` field) is sufficiently informative when printed, since
   dry-run currently does not print the classifier's raw `reason` field at all in the Excluded
   section (only a templated `t_skip_reason`/`t_exclude_reason` derived from `.group`) — decide
   whether to thread the richer per-dependency reason through, or accept the existing generic
   "handoff-triage skip (status blocked)" phrasing (task's acceptance criterion only requires the
   dry-run PREDICT the new behavior correctly, not that it reproduce the classifier's full prose).
8. **`docs/architecture/orchestrate-state-machine.md`**: the top single-task-oriented state table
   row for `blocked` (~line 31: `Read blockers from state.json, dispatch_blocker_escalation()` →
   `planned`) is single-engine-scoped and needs no change unless Decision 3 extends discrimination
   to `single`. The prose at ~line 413 ("If a predecessor is `failed`, the dependent task is
   immediately moved to `failed_tasks` with status `blocked`") and the exit-conditions table row
   at ~line 434 ("No eligible tasks | partial | Deadlock or all blocked") both describe mechanisms
   this task does not change (step 3's failed-predecessor handling, and the genuine-deadlock exit
   path) — confirm no edit needed there beyond a pass to ensure no adjacent prose asserts the
   now-changed "blocked always skips" premise.
9. **Test suite** (`scripts/tests/test-orchestrate-triage-classify.sh`): the existing
   `fixture_blocked` (line 219) and its "DOCUMENTED DIVERGENCE... do NOT fix this" assertions
   (lines 258-265) must be rewritten to cover BOTH the discharged and non-discharged sub-cases
   for BOTH engines — at minimum: (a) discharged, no handoff → routes via `previous_status`; (b)
   discharged, handoff with non-empty blockers → `needs_human`; (c) non-discharged (dependency
   still in-progress) → stays `skip`(mt)/`needs_human`(single), unchanged from today; (d)
   dependency abandoned (not completed) → distinct loud-warning `needs_human`; (e) empty
   `dependencies[]` → stays `skip`/`needs_human`, unchanged. Per the repo's own mutation-check
   discipline (`context/standards/shell-script-testing.md`), each new fixture must be verified to
   FAIL against the pre-fix classifier before being accepted as a valid regression guard.

## Decisions

1. **Discharge requires predecessor status exactly `"completed"`, not the broader `is_terminal`
   set.** An `abandoned`/`expanded` predecessor means the ordering constraint can never be
   satisfied as originally intended — silently routing the dependent to its next phase would be
   wrong (the work it was waiting on will never land). This mirrors, at the classifier layer, the
   same distinction Stage MT-3 step 3 already draws between a `completed` predecessor (dependent
   becomes eligible) and a `failed`/never-finishing one (dependent is moved to `failed_tasks`,
   never silently promoted). The classifier should treat a non-completed-terminal predecessor as
   its own case (loud `needs_human`, both engines), not conflate it with either "still working"
   or "cleanly discharged."
2. **`single` engine's non-discharged `blocked → needs_human` stays unconditional and stays
   diverging from `mt`'s non-discharged `blocked → skip`.** This is the part of Decision 1 from
   the prior task that is genuinely reaffirmed, not narrowed: a solo invocation has no sibling
   batch to make progress on while waiting, so escalating immediately remains the only meaningful
   action for the non-discharged case. No new argument surfaced in this research to change that.
3. **`single` engine's DISCHARGED `blocked` case SHOULD also route through `previous_status`
   rather than staying `needs_human`.** Reasoning: the classifier header's own audit discriminator
   ("does the OTHER engine's own handler implement the divergence in its own code, or does only
   this shared table assert it?") asks whether escalating a task whose dependency has *already
   completed* is still a deliberate, independently-corroborated design choice, or an accident of
   the old unconditional rule. A solo `/orchestrate 436` invoked after 437 has already completed
   elsewhere has no reason to escalate to a human for a block that is factually already resolved
   — escalating there is exactly the "genuinely stuck" framing this repo's normative ordering
   principle rejects. The `single` handler (`#### State: blocked`, `skills/skill-orchestrate/
   SKILL.md` ~line 658, and its state-machine-doc counterpart) should therefore gain the SAME
   discriminating read (dependency status + handoff blockers) the classifier already performs for
   `single` via `orchestrate-triage-classify.sh single $task_number` — the single-task Stage 4
   handler already has a documented "Cross-reference" precedent (line 528) for delegating to the
   classifier script's identical logic; this is a natural extension of that existing precedent,
   not a new pattern. Net effect: `single` and `mt` CONVERGE on the discharged case and remain
   DIVERGENT only on the non-discharged case — an even cleaner instance of the "documented,
   independently-implemented divergence, narrowed to its true minimal scope" shape the audit
   discriminator asks for.
4. **No separate rewrite component; the verdict alone suffices.** Confirmed by direct read of
   `skill_validate_input` and `update-task-status.sh`'s preflight write (see Findings) that
   dispatching a `blocked`-status task to research/plan/implement cleanly and unconditionally
   overwrites the stale status as a side effect of normal preflight, with no precondition guard
   in the way. `scripts/orchestrator-postflight.sh` and `scripts/reconcile-task-status.sh` need
   NO new write logic for this fix.
5. **`/spawn` keeps writing `blocked` + `previous_status` unchanged.** The status string is not
   redundant with `dependencies[]` once the classifier is fixed — it is the trigger that tells
   the classifier "run the discrimination logic at all" (as opposed to `dependencies[]` alone,
   which every non-blocked status also carries and which the classifier does not otherwise
   consult). Removing it would require inventing a new signal to replace it.
6. **`unknown` row is out of scope.** No argument surfaced in this research to touch it; Decision
   3 from the prior task stands for that row without narrowing.

## Risks & Mitigations

- **Risk**: treating an `abandoned` predecessor identically to a `completed` one would silently
  promote a task whose real precondition can never be met. **Mitigation**: Decision 1 above —
  discharge requires literal `status == "completed"`, with a distinct loud warning for
  non-completed-terminal predecessors, never silent promotion or silent indefinite skip.
- **Risk**: an empty `dependencies[]` on a `blocked` task (hand-set block, or a handoff-only
  block predating consistent `/spawn` usage) being misread as "trivially satisfied" (vacuous
  truth over an empty list) and auto-discharged with no real evidence of resolution.
  **Mitigation**: explicit guard — empty `dependencies[]` is its own non-discharging branch with
  its own reason string, never falls through to the "all deps completed" check.
- **Risk**: widening the "Gate Catalogue" table to include the pre-existing, unrelated "Unmet
  predecessor" omission alongside the new `blocked` rows could scope-creep this task into
  editing unrelated table content. **Mitigation**: flagged as optional in Recommendation 6, not
  mandated; planning should decide whether to fold it in (same file, same table, low marginal
  cost) or leave it as a distinct, separately-scoped follow-up — either is defensible, but the
  choice should be an explicit plan decision, not an incidental byproduct of this edit.
- **Risk**: dry-run's `reason` field surfacing may not carry the new, more specific per-dependency
  detail (see Recommendation 7) if left unthreaded, weakening the dry-run's diagnostic value for
  a partially-discharged chain. **Mitigation**: not required by acceptance criteria (dry-run must
  predict the new *behavior*, not reproduce classifier prose verbatim); flagged for a planning-
  time judgment call rather than treated as a defect.
- **Risk**: extending discrimination to the `single` engine's discharged case (Decision 3) is the
  one recommendation in this report that goes beyond the task description's literal "mt classifier
  row" framing. **Mitigation**: framed explicitly as a Decision with its own reasoning (the audit
  discriminator applied honestly, per the task's own instruction to do so rather than defer);
  planning may choose to accept, defer to a follow-up task, or reject with documented reasons —
  this report does not treat it as mandatory, only as the answer the audit discriminator points
  to when applied consistently.

## Context Extension Recommendations

- **Topic**: Gate Catalogue completeness in `batch-orchestration-guardrails.md`.
- **Gap**: the "Unmet predecessor (dependency-graph eligibility)" guardrail is documented as
  BLOCKING in the Blocking-vs-Advisory table but has no corresponding ORDERING CONSTRAINT row in
  the Gate Catalogue (post-fix) table, an omission adjacent to (but distinct from) this task's own
  scope.
- **Recommendation**: either fold a row for it into this task's edit of that file (low marginal
  cost, same table, same edit session) or record it explicitly as a scoped-out follow-up in this
  task's plan, so it does not silently recur as "no argument surfaced" the way `blocked` itself
  did in the prior task.

## Appendix

### Files read (direct, full or targeted reads — not re-derived from the task description)

- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` (full, 334 lines)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (targeted: ~500-700, ~1280-1600,
  ~1960-2070)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (targeted: ~1025-1050,
  ~1535-1560)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` (targeted:
  header + fixture/assertion block)
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` (targeted: header,
  Steps 3/6/7, admitted-set composition, report body)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (full,
  ~140 lines read)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (targeted:
  ~20-40, ~400-440)
- `agent-system/extensions/core/commands/orchestrate.md` (targeted: ~120-235, Steps 1.5-3)
- `agent-system/extensions/core/skills/skill-spawn/SKILL.md` (targeted: ~85-135, ~295-460,
  ~525-545)
- `agent-system/extensions/core/scripts/skill-base.sh` (targeted: ~150-260)
- `agent-system/extensions/core/scripts/update-task-status.sh` (targeted: ~580-660)
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` (grep-targeted for `blocked`)
- `specs/archive/067_orchestrate_eligibility_not_status_gated/reports/01_admission-predicate-eligibility-and-self-mod-tiebreak.md`
  (targeted: Decisions section, blocked/unknown references)
- `specs/state.json` (schema probe only, to confirm `dependencies`/`previous_status`/`blocks_note`
  field presence in this repo's live active_projects entries — this repo currently has no task in
  `blocked` status; the reproduction is confirmed from the shared skill/script source instead)

### Grep queries used

- `grep -n "blocked" .../skill-orchestrate/SKILL.md`
- `grep -n "dependency_graph\|Kahn\|topological\|wave" .../commands/orchestrate.md`
- `grep -n "previous_status\|\"blocked\"\|blocks_note" specs/state.json`
- `grep -n "expected.*status\|precondition\|current_status ==" .../skill-{researcher,planner,implementer}/SKILL.md`
- `grep -n "blocked" .../reconcile-task-status.sh`

# Research Report: Task #60

**Task**: 60 - Thread evidence-gated verdict through admission consumers
**Started**: 2026-08-17
**Completed**: 2026-08-17
**Effort**: Medium (doc/consumer threading across 9 files, no predicate logic changes)
**Dependencies**: Task 59 (predicate half — COMPLETED; verified live at v5)
**Sources/Inputs**: Codebase read (predicate script, schema doc, all 9 declared consumer files), task 59's plan/summary, `git log`
**Artifacts**: `specs/060_thread_evidence_gated_verdict_through_admission_consumers/reports/01_thread-evidence-gated-verdict.md`
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- Task 59 (predicate half) is confirmed **complete and live**: `orchestrate-batch-admit.sh`
  already emits `orchestrate-batch-admit-v5`, already carries `idle_overlap_advisory`, and
  `docs/architecture/batch-admit-schema.md` is already fully rewritten for v5. Do not re-derive
  or re-verify the predicate — it is ground truth for this task.
- Task 59's own summary explicitly named this task's WORK item 1 as its declared follow-up:
  *"Thread the `idle_overlap_advisory` field through the `defer_reason`-branching consumers... a
  separate, sibling task's declared scope."*
- All 5 WORK items map to concrete, located edits across the 9 declared files. No new mechanism
  needs inventing anywhere — every item folds an existing pattern (the `--allow-self-modifying`
  parser/threading shape, the existing Class D suggestion string, the existing schema doc's
  "human resolves batch composition" framing) into a sibling location.
- The one genuinely open design question is **WORK item 2's exact bypass scope**: whether
  `--allow-scope-collision` bypasses `file_scope_collision` defers of *both* `collision_scope`
  values, or `cross_batch` only. See "Decisions" below for the recommendation and the reasoning
  a planner should re-verify.
- Co-maintenance is real and mechanical: `skill-orchestrate-hard/SKILL.md`'s
  `file_scope_collision` bullet currently reads "unchanged from the base skill's handling" —
  every prose fix to the base skill's cross_batch bullet must be re-transcribed there too, not
  merely pointed at.

## Context & Scope

Task 59 changed the admission *predicate* (`orchestrate-batch-admit.sh`) and its schema doc,
narrowing `cross_batch` `file_scope_collision` to require execution evidence and adding a new
`idle_overlap_advisory` field on the resulting `admit` verdict for provably-idle overlaps. Task
59's own summary lists the four `defer_reason`-branching consumers it explicitly did **not**
touch (declared out of its own scope): `orchestrate-dry-run-report.sh`,
`orchestrate-predispatch-review.sh`, `skill-orchestrate/SKILL.md`, `skill-orchestrate-hard/SKILL.md`.
This task (60) is exactly that follow-up, plus four additional, independently-scoped fixes
(the `--allow-scope-collision` override, folding Class D's suggestion into the dispatch-path
warning, correcting the three-way-contradictory self-clearing claim, and the stale schema-version
prose).

**Verified current state of the predicate** (confirming the task's own NOTE):
`agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` — every one of its 10
`$schema` literals reads `"orchestrate-batch-admit-v5"` (line 76 header, plus 9 emit sites at
lines 463/466/469/479/490/493/548/551/581). `idle_overlap_advisory` is fully implemented (lines
140-159 header doc; lines 525-541 the `$idle_overlap`/`$idle_advisory_frag` computation; appended
via `+ $idle_advisory_frag` to all three post-scan verdict shapes at lines 548, 563, 594).
`docs/architecture/batch-admit-schema.md` is fully v5 (Status line, all example verdicts, Field
Definitions table row for `idle_overlap_advisory`, full "v4 to v5" Version History entry). Do
not re-touch either file for this task — they are upstream inputs, not part of this task's
declared `file_scope`.

## Findings

### WORK 1 — Render `idle_overlap_advisory` in the dispatch-path warning and batch results surface

**"Dispatch-path warning" = the two live admission-consumer sites that print a WARNING at the
moment a verdict is acted on** (not the separate, pre-existing Step 1.5 review call):

- `skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 (~line 1500-1585): the sole EXECUTING
  gate. Currently branches `self_modifying` / `file_scope_collision` (`in_batch`/`cross_batch`) /
  `session_active`, each with its own `[orchestrate] WARNING:` template. None of these branches
  currently reads or prints `.idle_overlap_advisory` — it is silently dropped even when present
  on the very verdict object being branched on (the field can co-occur with any of the three
  post-scan verdict shapes per the schema).
- `skills/skill-orchestrate-hard/SKILL.md` `## Multi-Task Mode` transcription (~line 1552-1591):
  same gap, mirrored (co-maintenance twin).
- `commands/orchestrate.md` Step 3/4 (~line 270-330): the illustrative (non-executing) block —
  still must be updated since it is the documentation of what the skill does, read by an
  operator running `--dry-run` or debugging a transcript.

Since `idle_overlap_advisory` is present on `admit` verdicts too (not only defers), the natural
integration point in each of the three files is: immediately after computing `decision`/`.self_modifying`
handling and before/alongside the existing defer branches, check
`jq -e '.idle_overlap_advisory'` and — whenever present, regardless of whether this verdict's
own `decision` was `admit`, `session_active` defer, or `file_scope_collision` defer — print a
**distinct, loud** line (never folded silently into an existing WARNING's text, since the task's
own instruction is "advisory never means unlogged or silent" and the advisory names a
*different* colliding task than the verdict's own subject in the `session_active`/collision defer
cases). Suggested shape, mirroring the existing warning templates' voice:
```
[orchestrate] ADVISORY: Task #{task_number} has file_scope overlapping IDLE (status:
  {colliding_task_status}) out-of-batch task #{colliding_task_number} at {overlapping_path}; not
  blocking because no execution evidence exists. Add a dependencies[] edge between #{task_number}
  and #{colliding_task_number} if ordering matters.
```

**"Batch results surface" = `context/patterns/orchestrate-batch-results-template.md`**, the
`## Batch Orchestrate Results` consolidated Step 5 output template. It currently has no
subsection for an idle-overlap advisory (verified via full read — no `idle`/`advisory` string
anywhere in the file). Its existing `### Deferred (other admission exclusions)` table only
covers `defer` verdicts, and an idle-overlap-carrying verdict is by definition an `admit` — so
this needs a **new** `###` subsection (a natural name: `### Admitted (idle overlap advisory)`),
populated per-task from whichever accumulator structure Stage MT-3/MT-5 already builds for
`idle_overlap_advisory`-carrying admits, rendered unconditionally-when-non-empty like the
existing `### Deferred (redeploy checkpoint)` pattern. Columns should mirror the field set:
Task | Colliding Task | Colliding Status | Overlapping Path | Note.

**Also in scope but not explicitly named in the task's WORK bullets — verify with planner**:
`orchestrate-dry-run-report.sh` (declared `file_scope`) has the exact same gap. Its per-task
verdict loop (Step 4, ~line 320-365) currently only special-cases `self_mod == "true"` on an
`admit` decision (adding a `notes+=(...)` entry) and has no `.idle_overlap_advisory` check at
all, on either the `admit` path or any of the three `defer` paths. Given it is in the declared
`file_scope` and is one of the schema doc's four named `defer_reason`-branching consumers, it
almost certainly needs the same treatment (a `notes+=("Task #$t: idle overlap advisory — ...")`
line wherever `jq -e '.idle_overlap_advisory != null'` on the verdict), even though WORK item 1's
prose names only "the dispatch-path warning and... the batch results surface." Flagging this as
likely in-scope-by-inclusion rather than asserting it outright, since the task's own WORK list is
authoritative over my inference.

### WORK 2 — `--allow-scope-collision` override

**Exact mirror pattern already exists for `--allow-self-modifying`** in
`scripts/parse-command-args.sh` (173 lines total, small file):
- Doc comment block, lines 25-26 (`ALLOW_SELF_MODIFYING_FLAG` description)
- Default init, line 86: `ALLOW_SELF_MODIFYING_FLAG="false"`
- Detection, lines 136-138: `if [[ "$remaining" =~ --allow-self-modifying ]]; then ALLOW_SELF_MODIFYING_FLAG="true"; fi`
- Strip-from-FOCUS_PROMPT, line 160: `| sed 's/--allow-self-modifying//g' \`
- Export list, line 170

`--allow-scope-collision` needs the identical five touch points, producing
`ALLOW_SCOPE_COLLISION_FLAG` (default `"false"`).

**Threading downstream** (mirroring `allow_self_modifying`'s exact path):
1. `commands/orchestrate.md`:
   - `## Options` table (line ~35): add a row, same voice as the existing
     `--allow-self-modifying` row — "Opt-in bypass of the [scope-collision] admission gate for
     this invocation only... never a general-purpose weakening", default `false`.
   - STAGE 0 (line ~56): read `ALLOW_SCOPE_COLLISION_FLAG` from the sourced parser, same as
     `ALLOW_SELF_MODIFYING_FLAG` is read and passed as `allow_self_modifying`.
   - Step 4's Skill invocation `args:` string and delegation-context JSON (lines ~394, ~407): add
     `allow_scope_collision={ALLOW_SCOPE_COLLISION_FLAG}` / `"allow_scope_collision": "{ALLOW_SCOPE_COLLISION_FLAG}"`
     alongside the existing `allow_self_modifying` entries.
   - The `cross_batch` WARNING bullet (~line 285-292): add the same "consumer-side override check
     first" framing `--allow-self-modifying`'s bullet has, naming `--allow-scope-collision` as the
     bypass and stating explicitly (per the task's own instruction) that
     `orchestrate-batch-admit.sh` is NEVER passed the flag and always emits the honest verdict —
     "a loud bypass notice logged either way" (i.e., even when the flag is inactive and no bypass
     occurs, nothing needs to change there; the loud notice is only for the ACTIVE-bypass case,
     matching `--allow-self-modifying`'s own "distinct bypass notice... whether or not the gate
     would otherwise have fired" pattern — re-verify against the task's literal wording, which
     says "with a loud bypass notice logged either way," i.e. the bypass notice logs whether or
     not the collision was actually present, mirroring the self-modifying BYPASS notice's own
     unconditional-logging behavior).
2. `skills/skill-orchestrate/SKILL.md` Stage MT-1 (line ~1217): add `allow_scope_collision`
   (default `"false"`) to the delegation-context field list alongside `allow_self_modifying`.
   Stage MT-3 step 4.5's `file_scope_collision` branch (line ~1538-1562): add the
   "consumer-side override check first" logic mirroring the `self_modifying` branch's shape
   (lines 1505-1537) — check `allow_scope_collision == true`, and if so, dispatch anyway with a
   loud `[orchestrate] BYPASS:` notice, never suppressing the underlying verdict computation.
3. `skills/skill-orchestrate-hard/SKILL.md` — same two edits, co-maintained (its
   `file_scope_collision` bullet at ~line 1568-1574 currently says "unchanged from the base
   skill's handling"; it will need to actually diverge here to carry the override logic, or the
   pointer needs to become a transcription like the `self_modifying` bullet immediately above it
   already is).

**The script itself is explicitly NOT touched** — `orchestrate-batch-admit.sh` is outside this
task's declared `file_scope` and the task explicitly forbids ever passing the flag to it: *"It
must NEVER be passed to orchestrate-batch-admit.sh, which always computes and emits the honest
verdict regardless."* This matches the existing `--allow-self-modifying` precedent exactly (the
schema doc's own "Why This Check Is Evidence-Gated..." section states this invariant for that
flag verbatim: *"The `--allow-self-modifying` override does not change this... `--allow-self-modifying`
is NEVER passed to `orchestrate-batch-admit.sh`."*).

**Open design question for the planner — bypass scope**: `file_scope_collision` defers currently
have two shapes: `collision_scope == "in_batch"` (colliding task is in this same invocation,
naturally resolves via retry within a few cycles) and `collision_scope == "cross_batch"`
(colliding task outside this invocation, an in-flight real hazard post-task-59, needs human
batch-composition judgment). Grepping the full corpus (`docs/architecture/batch-admit-schema.md`,
`context/patterns/batch-orchestration-guardrails.md`) for any existing "override for
file_scope_collision" discussion found none, confirming the task's own framing that "no override
... was ever considered and rejected" — this is a genuinely fresh design surface, not a
reversal. Two readings are both textually consistent with the task description:
  - **(a) Bypass both scopes** — the flag name is `--allow-scope-collision`, unqualified, and
    `--allow-self-modifying` bypasses its hazard unconditionally regardless of the co-dispatch
    nuance behind it; symmetry argues for one flag covering the whole `file_scope_collision`
    dimension.
  - **(b) Bypass `cross_batch` only** — `in_batch` already has a working, bounded, self-resolving
    remedy (wait one cycle) that costs nothing; only `cross_batch`'s "excluded, needs a human"
    outcome is the kind of friction an operator override exists to relieve.
  My recommendation for the plan: **(a)**, both scopes, for symmetry with the flag's
  unqualified name and with `--allow-self-modifying`'s own unconditional-hazard-bypass precedent
  — but this should be an explicit, stated decision in the plan (not silently assumed), since
  choice (b) is defensible and narrower (safer default surface).

### WORK 3 — Fold Class D's `dependencies[]` suggestion into the dispatch-path warning

**Class D's exact existing suggestion computation and string** live in
`scripts/orchestrate-predispatch-review.sh`:
- jq computation (lines 386-394): for each `defer_reason == "file_scope_collision" && collision_scope == "cross_batch"` verdict, computes `suggested_dependent` (the higher task number) and
  `suggested_predecessor` (the lower task number).
- Rendered string (lines 478-491): `"#{task_number}: file_scope collision with out-of-batch task
  #{colliding_task_number} (status: {colliding_task_status}) at {overlapping_path} -- suggest
  adding #{suggested_predecessor} as a dependencies[] entry on #{suggested_dependent} to serialize
  them"` (+ optional `[corroborated by a live registered session]` suffix).

This is a **separate, pre-existing, already-advisory-loud review surface** — called once at
`commands/orchestrate.md` Step 1.5 ("Pre-Dispatch Review"), documented there and cross-referenced
from `skill-orchestrate/SKILL.md` Stage MT-1 (~line 1211-1218, "Upstream review cross-reference")
as having *already* reviewed the full raw `dependencies[]` before wave assignment narrows it. The
gap named by the task is precise: this suggestion is computed and printed once, upstream, at
Step 1.5 — but the actual EXCLUSION (the moment a candidate is dropped from dispatch) happens
later, at a *different* site (`skill-orchestrate/SKILL.md` Stage MT-3 step 4.5's `cross_batch`
WARNING, ~line 1552-1562, and `commands/orchestrate.md`'s illustrative Step 3 `cross_batch`
WARNING, ~line 313-320) — neither of which currently prints the `dependencies[]` remedy at all,
only "batch composition needs human review." **Do not build a new suggestion mechanism** (the
task is explicit about this) — reuse the identical `suggested_dependent`/`suggested_predecessor`
ordering rule (higher task number depends on lower) and append the identical suggestion clause to
those two WARNING templates (and the `skill-orchestrate-hard/SKILL.md` twin).

### WORK 4 — Correct the false self-clearing claim (three-way corpus contradiction)

**The false claim, located precisely**: `skills/skill-orchestrate/SKILL.md` line ~1538-1542:
> "**`file_scope_collision`** — retains the exact pre-existing `collision_scope` branching below,
> byte-for-byte. **Both branches** preserve the surrounding cycle semantics verbatim: a deferred
> task is removed from **this cycle's** dispatch batch, is never added to `failed_tasks`, and
> **becomes eligible again on a later cycle**..."

This claim is accurate for `in_batch` (the colliding task IS in this same invocation's
`task_numbers`, so a later cycle of the SAME loop naturally re-evaluates and can dispatch it,
clearing the collision) but false for `cross_batch`: the colliding task is, by construction, NOT
in `task_numbers` — this invocation's cycle loop has no mechanism that ever advances or resolves
it. "Eligible again on a later cycle" implies the SAME invocation's own progress will clear the
defer; for `cross_batch` that can only happen if an *external* process independently changes the
colliding task's status, which this invocation neither causes nor waits for. The identical
pattern repeats at line 1841 ("it becomes eligible again next cycle") in a different context and
should be checked for scope during implementation (verify whether that instance is talking about
`self_modifying`/`in_batch` specifically, where the claim IS true, versus a generalized claim).

`skills/skill-orchestrate-hard/SKILL.md`'s twin (line ~1568-1574) makes the same error more
tersely: *"`file_scope_collision` (`in_batch` / `cross_batch`): unchanged from the base skill's
handling — defer the named task to a later cycle... No behavioral change here"* — inherits the
false generalization by reference rather than restating it, but must still be fixed
(co-maintenance).

**The three-way corpus disagreement, verified exactly as the task describes**:
1. `docs/architecture/batch-admit-schema.md`'s "Deferral-Direction Rule and Caller Guidance"
   section (line ~213-225, current v5 prose): *"the requested candidate is excluded from this
   invocation's admitted set and the colliding task is surfaced for human batch-composition
   judgment. This is explicitly not a correctness verdict on the candidate task, and explicitly
   not an instruction to fold the in-flight out-of-batch task into the run; a human resolves
   batch composition."* — no claim of automatic self-clearing; frames it as invocation-scoped
   exclusion requiring human resolution.
2. `commands/orchestrate.md`'s `cross_batch` WARNING template (line ~313-320): *"Excluding
   #{task_number} from this run — batch composition needs human review."* — consistent with the
   schema doc's framing (excluded from the run, human review), and itself internally correct.
3. `skills/skill-orchestrate/SKILL.md` (and its hard-mode twin): claims cross_batch, like
   in_batch, "becomes eligible again on a later cycle" — contradicts both (1) and (2).

**Fix direction**: rewrite SKILL.md's (and the hard twin's) `file_scope_collision` bullet to stop
asserting "both branches... become eligible again on a later cycle" as a blanket claim. Split the
claim explicitly by `collision_scope`: `in_batch` genuinely does self-clear via the existing
per-cycle re-evaluation (keep that claim, it is correct and load-bearing for the convergence
argument elsewhere in the file); `cross_batch` should instead say something aligned with (1)/(2)
— e.g. "the candidate is excluded from this invocation; it does not automatically become eligible
again within this run — the colliding out-of-batch task is outside `task_numbers` and this loop
has no mechanism to advance it. A human resolves batch composition (see the Class D
`dependencies[]` suggestion, WORK 3 above, for the remedy when ordering matters), or a future
invocation naturally re-evaluates once the colliding task's status has independently changed."

### WORK 5 — Stale schema-v3 prose

Confirmed via grep across all 9 declared files for `schema v[0-9]` / `orchestrate-batch-admit-v[0-9]`:
- `skills/skill-orchestrate/SKILL.md` line 1500: `"(schema v3 — every defer verdict carries this
  REQUIRED discriminator..."` — stale, live script is v5.
- `commands/orchestrate.md` line 270: identical stale `"(schema v3 —..."` phrase.
- `skills/skill-orchestrate-hard/SKILL.md` line 1566: says `"(schema v4 —..."` — **also stale**
  (not literally "v3", but still behind the live v5). The task's WORK 5 bullet names "the two
  consumer files that still say v3" specifically (matching only the base SKILL.md and
  commands/orchestrate.md), but given the co-maintenance mandate and that all three should agree
  with the live script, recommend the planner also bump the hard-mode file's "v4" mention to v5
  in the same pass rather than leaving a residual third stale reference — flagging this rather
  than silently expanding WORK 5's stated scope.
- `scripts/orchestrate-predispatch-review.sh` and `scripts/orchestrate-dry-run-report.sh`: no
  `$schema` string literal pinned in either (confirmed via grep; matches the schema doc's own v4
  Version History note that both scripts "pin no `$schema` string literal") — no fix needed
  there for this specific item, though see WORK 1's dry-run-report finding above for the separate
  `idle_overlap_advisory` gap.
- `context/patterns/orchestrate-batch-results-template.md`, `context/patterns/task-lock.md`,
  `context/patterns/multi-task-operations.md`: no `schema v[0-9]` / `-v[0-9]` mentions found —
  not implicated in WORK 5.

## Decisions

- Predicate half (task 59) is verified complete and out of scope — no edits to
  `orchestrate-batch-admit.sh` or `batch-admit-schema.md` in this task.
- `orchestrate-dry-run-report.sh`'s missing `idle_overlap_advisory` rendering is very likely
  in-scope-by-declared-`file_scope`-inclusion even though WORK 1's prose names only "the
  dispatch-path warning and... the batch results surface" — recommend the plan treat it as
  in-scope, flagged for explicit confirmation rather than silent inference.
- `--allow-scope-collision`'s exact bypass boundary (`in_batch`+`cross_batch` vs. `cross_batch`
  only) is the one open fork; recommend both-scopes for name/precedent symmetry, stated as an
  explicit plan decision.
- `skills/skill-orchestrate-hard/SKILL.md`'s stale "schema v4" mention (distinct from the two
  literal "v3" files WORK 5 names) should likely be swept to v5 in the same pass for corpus
  consistency — flagged, not asserted as in-scope.

## Risks & Mitigations

- **Co-maintenance drift**: skill-orchestrate and skill-orchestrate-hard are explicitly required
  to stay in lockstep (file header: "CO-MAINTENANCE: an edit to either copy REQUIRES the same
  edit to the other"). Every WORK item 1-4 edit to the base skill has a corresponding edit
  required in the hard-mode twin. Mitigation: treat each WORK item as a paired edit, verify both
  files after each item rather than batching all base-skill edits before starting the hard-mode
  twin.
- **`commands/orchestrate.md`'s Step 3/4 block is illustrative, not executing** (explicitly
  stated in-file: "this subsection is illustrative of the CONTRACT `skill-orchestrate` fulfills,
  not code this file itself runs"). Edits there are documentation-correctness only; the actual
  runtime behavior for WORK 2/3/4 is entirely determined by the SKILL.md edits. Mitigation: no
  special risk, just don't mistake a `commands/orchestrate.md`-only edit for a functional fix.
  Note task 787's plan is the origin of that illustrative-block framing — the same discipline
  should be honored here.
- **Advisory rendering must never suppress or replace the verdict's own defer/admit warning** —
  the task explicitly states "advisory never means unlogged or silent." Since
  `idle_overlap_advisory` can co-occur with a `session_active` or `file_scope_collision` defer
  about a *different* colliding task than the advisory names, the two must be printed as
  genuinely separate lines, never merged into one message that could obscure either fact.

## Context Extension Recommendations

- None — this is a well-documented, actively-maintained subsystem with an unusually thorough
  schema doc and guardrails pattern file; no context gap was found during this research.

## Appendix

**Search queries / commands used**:
- `find agent-system/extensions/core -iname "*batch-admit*" -o -iname "*predispatch-review*"`
- `grep -n "allow-self-modifying|allow_self_modifying"` across parse-command-args.sh,
  commands/orchestrate.md, both SKILL.md files
- `grep -n "schema v[0-9]|batch-admit-v[0-9]|orchestrate-batch-admit-v[0-9]"` across all 9
  declared files
- `grep -n "cross_batch|in_batch|collision_scope|eligible again|idle_overlap|schema.*v3|schema.*v4"` in skill-orchestrate/SKILL.md
- `grep -n "will not advance|self-clear|human resolves|excluded from this run|excluded from this cycle|eligible again"` across schema doc, guardrails pattern, both command/skill files
- `grep -n "idle_overlap_advisory|defer_reason|Class [A-E]|--allow-self-modifying"` in
  orchestrate-predispatch-review.sh and orchestrate-dry-run-report.sh
- Full reads: `orchestrate-batch-admit.sh` (611 lines), `batch-admit-schema.md` (542 lines),
  `parse-command-args.sh` (174 lines), `orchestrate-batch-results-template.md` (147 lines)
- Task 59's completed summary: `specs/059_narrow_cross_batch_collision_to_execution_evidence/summaries/01_narrow-cross-batch-collision-summary.md`

**References**:
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` (predicate, verified v5, not edited)
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` (schema doc, verified v5, not edited)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (Classification Table, `cross_batch` row already updated by task 59)

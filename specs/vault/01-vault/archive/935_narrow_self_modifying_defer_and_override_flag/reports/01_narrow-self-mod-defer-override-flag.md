# Research Report: Task #935

**Task**: 935 - Narrow the self-modifying admission defer from whole-invocation to same-wave scope, add an explicit opt-in override flag, and reconcile the surrounding documentation/schema/hard-mode gaps this narrowing exposes
**Started**: 2026-07-28T00:00:00Z
**Completed**: 2026-07-28T00:00:00Z
**Effort**: large (seven scope items, one script change, one shared-parser change, four documentation/schema files, one skill-file consistency question)
**Dependencies**: 932, 933, 934, 936 — all four completed and confirmed live in `specs/state.json`.
  Dependency 934 (inter-cycle redeploy checkpoint) is the load-bearing one: its retirement of
  hazard 3 to "PARTIALLY RETIRED... replaced by a narrower mid-invocation script-swap exposure"
  is the exact precondition this task's Scope A narrowing leans on, and its own report/summary
  were read in full before any other file (see Sources below).
**Sources/Inputs**: Codebase read (source-store files only, per the binding SOURCE-STORE RULE);
  no web search performed — this is a self-contained design question over already-verified,
  already-documented in-repo machinery.
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The root cause of both motivating incidents is the same one line of code, and it is not "the
  gate is too strict by design" — it is a scope-mismatch bug.** `orchestrate-batch-admit.sh`'s
  self-modification trigger fires whenever `--invocation-count` exceeds 1. Both live callers
  (`commands/orchestrate.md` Step 3 and `skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5)
  deliberately pass the **whole invocation's** candidate count (`${#validated_tasks[@]}` /
  `${#task_numbers[@]}`), never the size of the actual same-cycle dispatch batch
  (`${#wave_tasks[@]}` / `${#eligible_tasks[@]}`) — a choice the schema doc's own "Why
  `--invocation-count` Exists" section defends explicitly: "the whole point is to keep
  orchestrator-critical work from running alongside ANY sibling, not merely a same-wave one."
  That defense is exactly what this task's own verified incident 2 falsifies: 935 declares a
  `dependencies[]` edge on 934, so Stage MT-3 step 3's own eligibility rule (**all predecessors
  from `dependency_graph[task_num]` must be terminal**) makes it structurally impossible for 934
  and 935 to ever occupy the same `eligible_tasks` cycle-batch — yet the self-mod check still
  fires for both, because it is reading the WHOLE-invocation count (2), not the actual per-cycle
  co-dispatch count (which is always 1 for this pair, by construction of the dependency graph).
- **Recommended fix for Scope A: change the *counting unit*, not the underlying design intent.**
  Pass `${#eligible_tasks[@]}` (Stage MT-3 step 4.5) / `${#wave_tasks[@]}` (`orchestrate.md` Step
  3, documentation-only today — see Scope E finding below) as `--invocation-count` instead of the
  whole-invocation count. This directly retires both verified incidents: any task set fully
  serialized by `dependencies[]` edges (incident 2, and any edge-connected subset of incident 1)
  never actually co-occupies a cycle-batch, so the narrowed check no longer fires against them.
  Genuinely wave/cycle-co-occupying siblings with no edge between them (the collision dimension's
  own comparison set) still trigger the self-mod defer — this is the surviving, hazard-1-grounded
  strictness the task's own "DO NOT NAIVELY DELETE OR WEAKEN THIS GATE" instruction protects.
- **Scope A1's "asymmetry" dissolves as a corollary of the Scope A fix — it does not need a
  separate, new dependency-edge exemption bolted onto the self-mod predicate.** The collision
  dimension's edge exemption exists because its comparison set spans *outside* the current
  wave/cycle entirely (cross-batch, `specs/state.json`-wide) — a scope where two tasks *could*
  otherwise appear to collide despite being edge-connected, so the exemption is load-bearing
  there. Once the self-mod trigger is narrowed to the *same-cycle* co-dispatch count (Scope A),
  an edge-connected pair is **structurally guaranteed** never to co-occupy that count in the
  first place (Stage MT-3 step 3's eligibility rule enforces this identically for every predecessor
  edge, self-modifying or not) — so an *explicit* edge exemption in the self-mod predicate would
  be dead code, not a missing feature. Recommend documenting this as the resolution (asymmetry is
  explained, not fixed by new code) rather than transcribing the collision dimension's exemption
  logic into the self-mod branch.
- **A second, unflagged tension the task description does not name: narrowing Scope A trades
  "solo re-run, human decides when to redeploy" for "runs inside the same automated
  invocation, `deployed-headless.sh`/`verify-deploy.sh` auto-fire via dependency 934's checkpoint
  with no human review in between."** Hazard 1 (verification gap) is explicitly "unaffected by
  sequencing" per the task description — it does not distinguish solo-run from same-wave-run from
  whole-invocation-run, so it gives **no differential signal about where to draw the scope line**
  (same-wave vs. whole-invocation). What Scope A's narrowing *does* change is who reviews the fix
  before it goes live: today, a deferred self-modifying task is re-run solo, and a human decides
  when to run `<leader>al`/`deploy-headless.sh` manually — an implicit, human-paced review gate.
  After Scope A's narrowing admits an edge-serialized self-modifying pair into one multi-task
  invocation, dependency 934's own Stage MT-3 step 7 checkpoint will auto-redeploy and
  auto-verify between their cycles with **zero human review** — the exact automation hazard 1
  warns is uniquely risky for unverified orchestrator-machinery fixes. This is not a reason to
  reject Scope A (the narrowing is still correct — hazard 1 does not distinguish the two paths
  either way, so it cannot argue AGAINST narrowing any more than it argues FOR keeping
  whole-invocation scope), but it is the concrete, hazard-1-grounded justification for why Scope
  B's override flag must default to **off** and require deliberate human intent, and it belongs
  in the guardrails doc as the stated reason (see Recommendations, Scope B below).
- **Scope D's "verified gate gap" is real, but its root cause is a fragile *prose* inheritance
  mechanism, not a missing script call that needs inventing from scratch.** `skill-orchestrate-hard/SKILL.md`
  contains exactly two sentences referencing multi-task mode (Stage 0: "Same as base
  `skill-orchestrate`... use base multi-task stages"; and a dedicated `## Multi-Task Mode`
  section at the file's end: "Same as base `skill-orchestrate` multi-task stages (MT-1 through
  MT-5)") and zero references to any specific script, stage number, or bash block within those
  stages. Contrast this with dependency 934's own conclusion that the redeploy checkpoint is
  "inherited by reference" via the identical pointer — that conclusion is only as reliable as the
  pointer itself, and this task's own verified `grep` finding (zero hits for `batch-admit`) is
  direct evidence the pointer is *not* reliably followed by an executing agent, since the
  self-modification gate this pointer nominally also covers (it was already part of "MT-1 through
  MT-5" *before* dependency 934 ever ran) shows the same zero-reference symptom. Recommend
  resolving this by **explicit transcription** of Stage MT-3 step 4.5's bash block (and, by the
  same reasoning, step 7's checkpoint) into `skill-orchestrate-hard/SKILL.md`'s own
  `## Multi-Task Mode` section — consistent with this file's own stated design philosophy ("FULL
  STRUCTURAL VARIANT, not a thin wrapper... Loop-level changes... cannot be expressed as prompt
  injection into the base skill... both skills should evolve together") — rather than merely
  strengthening the pointer's wording, which would repeat the same class of failure this task
  just found.
- **Scope E's finding is confirmed exactly as stated, and it is mechanically linked to Scope A.**
  `commands/orchestrate.md`'s "Runtime wave-split check" text ("Before dispatching EVERY wave
  (Step 4)...") documents a bash call using `${wave_tasks[@]}`, but Step 4 itself never loops over
  `waves` to dispatch and gate one wave at a time — it builds `waves_json` wholesale (the `for
  wave_tasks in "${waves[@]}"` loop at line 335 only serializes JSON, it does not dispatch or gate
  anything) and hands the entire schedule to **one** `skill-orchestrate` Skill-tool call. The only
  code that actually executes a real, per-batch admission call is Stage MT-3 step 4.5, which
  iterates **cycles**, not the pre-computed `waves[]` array. `commands/orchestrate.md`'s bash
  block is therefore illustrative documentation of a contract the skill fulfills, not executable
  logic this file itself runs — confirming the task's own diagnosis. Recommend rewriting the
  prose to state this plainly (the command computes and hands off the wave schedule; the skill's
  Stage MT-3 is the sole executing gate, cycle-by-cycle) rather than inventing a real per-wave
  loop in the command file, which would violate the Anti-Bypass Constraint's spirit of keeping
  lifecycle-adjacent logic inside the delegated skill.

## Context & Scope

This is a `meta` task whose declared file scope is entirely within `agent-system/extensions/core/`
(the source store; the binding SOURCE-STORE RULE prohibits any `.claude/**` edit). The
declared scope covers: the admission script itself, the shared flag parser, the verdict schema
doc, the critical-path data file, the guardrails pattern doc, the command file, and both
orchestrate skill files (base and hard). This report does not write any implementation — it hands
a fully-grounded design, with explicit per-scope-item decisions and their hazard justification, to
the planning stage. Per the binding no-task-references-in-deliverables rule, this report itself
(a `specs/**` artifact) is exempt and may cite task numbers; any recommendation destined for a
non-`specs/**` file below is phrased so the planner can carry it over without a task-number
citation (see, e.g., the guardrails-doc wording recommendations under Scope A).

## Findings

### Codebase Patterns

**The two verified incidents share one root cause, confirmed by reading the actual comparison
count each caller passes.** `orchestrate-batch-admit.sh`'s jq program (lines ~329-350) computes
`sm_flag` (whether the candidate's own `file_scope` names a critical path) purely from the
candidate's own data — it never looks at any other task for this branch. The only place
concurrency/co-occurrence enters the self-mod decision is the `$inv_count > 1` test immediately
after. Both call sites (`orchestrate.md` line ~229, `skill-orchestrate/SKILL.md` line ~1263) pass
the WHOLE invocation's validated/task_numbers count as `--invocation-count`, deliberately — this
is exactly what "Why `--invocation-count` Exists" in `batch-admit-schema.md` documents as
intentional, on the stated rationale that a Wave-0 self-modifying candidate and an unrelated
Wave-1 candidate are "still in the same invocation" and should not be allowed to run "alongside"
each other. This task's own verified incident 2 is the falsifying case: 934 and 935 are not
merely in different waves, they are **edge-connected**, so Stage MT-3 step 3's eligibility rule
(`All predecessors from dependency_graph[task_num] are in terminal state...`) guarantees they can
never appear in the same `eligible_tasks` cycle-batch at all — there is no "alongside" for this
pair to protect against, at any scope narrower than the whole invocation.

**Stage MT-3 step 3's eligibility rule already does the work Scope A needs — it is not new
machinery, only a new argument to an existing call.** The rule already computes exactly the
set the self-mod check should be counted against: `eligible_tasks`, this cycle's actual dispatch
candidates, with every predecessor-blocked task already excluded. Changing Stage MT-3 step 4.5's
`--invocation-count` argument from `${#task_numbers[@]}` to `${#eligible_tasks[@]}` requires no
new computation — the eligible-tasks array already exists in scope at the exact point the
admission call runs (`bash .claude/scripts/orchestrate-batch-admit.sh --invocation-count
"${#task_numbers[@]}" "${eligible_tasks[@]}"` becomes `--invocation-count
"${#eligible_tasks[@]}"`, everything else on that line unchanged). The equivalent change for
`orchestrate.md` Step 3 is `${#validated_tasks[@]}` -> `${#wave_tasks[@]}`, though Scope E's
finding (below) means this specific line is documentation of the skill's contract rather than
code this file itself executes today.

**The `deferred_self_modifying` set's "never reset" semantics need to change alongside the
trigger, or the narrowing is incomplete.** Stage MT-3 step 3 currently excludes any task number
"in `deferred_self_modifying`" from `eligible_tasks` **permanently for the rest of the
invocation** — this set is explicitly documented as "an INVOCATION-SCOPED set (persists across
every cycle of this same `mt_state_file`, never reset mid-invocation)." If only the *trigger*
(Scope A's `--invocation-count` argument) is narrowed but the *consequence* (permanent exclusion
via this set) is left unchanged, a genuinely-colliding same-cycle pair (no edge between them,
correctly deferred) would still never get a second chance later in the invocation once one of
the pair is admitted and its co-occupant departs `eligible_tasks` — this is the same
converge-vs-never-converge distinction the schema doc's own v1-to-v2 history discusses. The
existing `orchestrate.md` Consolidated Output table (Exit-path coverage, "Deferred
self-modifying" row) already describes the desired end-state prose: "it becomes eligible, and
committable, on a later cycle" — this is presently **inaccurate** for the current
permanent-exclusion-set implementation, but would become accurate once the consequence is
narrowed from a permanent set to a same-cycle-only defer (mirroring `file_scope_collision`'s
existing defer-to-next-cycle behavior, which already re-evaluates every cycle with no persistent
exclusion set at all). This is independent confirming evidence — not merely an assumption — that
the intended post-narrowing behavior was already anticipated in one piece of prose before this
task existed.

**Hard mode's multi-task-mode inheritance is prose-only, and the self-mod gate's absence
pre-dates dependency 934.** `skill-orchestrate-hard/SKILL.md` was grepped for `Stage MT`,
`multi_task`, `wave`, `deploy-headless`, `verify-deploy`: the only hits are Stage 0's two-line
pointer and the file-final `## Multi-Task Mode` section's near-identical one-line pointer — no
bash block, no script name, no stage-number cross-reference beyond "MT-1 through MT-5" as a
label. This is the SAME pointer mechanism dependency 934's own report relied on to conclude the
redeploy checkpoint is "inherited by reference, confirmed by reading the actual file" — but the
self-modification admission gate (Stage MT-3 step 4.5) already existed in base
`skill-orchestrate/SKILL.md` **before** dependency 934 ran, and this task's own verified `grep`
finding shows it produces zero references in the hard-mode file regardless. The two findings are
in tension only if "same as base... use base multi-task stages" is read as a guaranteed, uniform
inheritance mechanism; the more defensible reading, given this task's own evidence, is that the
pointer is a documentation shorthand whose actual behavioral reliability at agent-execution time
is unverified and, per this task's grep, likely absent for at least the self-mod gate. (Whether
dependency 934's own inheritance conclusion for the redeploy checkpoint should be revisited on the
same grounds is a fair question this report raises but does not resolve — it is out of this
task's declared file scope, since `skill-orchestrate-hard/SKILL.md`'s Multi-Task Mode section
being made explicit for the self-mod/collision gate would, as a side effect, also make the
redeploy-checkpoint inheritance explicit if both are transcribed together.)

**`orchestrate.md`'s wave-split-check code block is real prose describing the skill's contract,
not code this file executes.** Confirmed by reading Step 4 in full: the `for wave_tasks in
"${waves[@]}"` loop (line 335) exists solely to build `waves_json` for the single Skill-tool
payload; there is no second loop anywhere in `commands/orchestrate.md` that dispatches wave by
wave and re-invokes `orchestrate-batch-admit.sh` between waves. The prose at Step 3 ("Before
dispatching EVERY wave (Step 4)... `bash .claude/scripts/orchestrate-batch-admit.sh
--invocation-count ... "${wave_tasks[@]}"`") describes a check that, in the live implementation,
only runs inside `skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 — cycle-by-cycle, not
wave-by-wave, since Stage MT-3 recomputes `eligible_tasks` every cycle from live `state.json`
rather than iterating the `waves[]` array directly (this exact cycle-vs-wave distinction was
already established in dependency 934's own report, under "Where 'wave' boundaries actually
live"). `commands/orchestrate.md` Step 3's code block is therefore vestigial with respect to
actual execution — useful as a stated contract, misleading as a claim about what this file does.

**The nine-file critical-path list's existing evidence still holds, and one new candidate pair
now clears both conjunctive tests.** Re-applying the two tests (reachability: read/executed on
the MT batch-dispatch path; decision-relevance: a defect yields a silent wrong admission/wave/
lock/completion decision, not a loud failure, not a cosmetic one) to each of the nine declared
paths, the existing per-file evidence in `batch-orchestration-guardrails.md`'s Inclusion Table is
unchanged by anything in this task or dependency 934 — none of the nine files' reachability or
decision-relevance rationale depends on facts dependency 934 altered. The three explicitly-excluded
files (`command-gate-in.sh`, `command-gate-out.sh`, `orchestrator-postflight.sh`) and the three
reachable-but-not-decision-relevant files (`generate-todo.sh`, `validate-artifact.sh`,
`lifecycle-notify.sh`) are likewise unaffected — dependency 934 did not touch MT dispatch's use of
any of these six. However: dependency 934 newly wired `scripts/deploy-headless.sh` and
`scripts/verify-deploy.sh` directly into Stage MT-3 step 7, unconditionally on the MT batch-dispatch
path whenever the checkpoint fires. Applying the two tests: (1) reachability — yes, both are
executed directly from Stage MT-3 step 7, on the MT dispatch path, not merely adjacent to it; (2)
decision-relevance — mixed. `deploy-headless.sh`'s own **failure** mode (`exit 1`/`2`) is
explicitly loud (triggers the documented failure-path warning and `deferred_deploy_checkpoint`
population) — this specific failure mode fails the decision-relevance test's "not a loud failure"
clause, the same way `validate-artifact.sh` is excluded. But a **silent misdeploy** (an exit-0
partial/incorrect sync that `deploy-headless.sh` itself does not detect) is exactly the class of
defect `verify-deploy.sh` exists to catch — and a defect **in `verify-deploy.sh` itself** that
silently reports a pass when the deploy is actually broken is a textbook match for the
decision-relevance criterion's own language for `orchestrate-batch-admit.sh` (entry #7: "a bug in
it defeats the very check meant to catch bugs like it"). Recommend the planner formally apply the
two tests to `verify-deploy.sh` as a **candidate tenth entry** (its failure mode is the silent one,
`deploy-headless.sh`'s is the loud one, so the pair does not automatically clear together) —
this task's own declared scope names `orchestrator-critical-paths.json` as in-scope, so this is a
live decision for this task rather than a deferred one, even though the task's own Scope C prose
frames the re-application as being "to the nine paths" (a strict reading would stop there; the
"apply the tests, do not pattern-match" instruction and the guardrails doc's own "fact about the
CURRENT dispatch implementation, not a permanent property" warning both argue for extending the
same rigor to the two files dependency 934 just added to the same dispatch path).

### External Resources

Not applicable — this is an internal design question over already-verified, already-documented
in-repo machinery; no external documentation or best-practice search was needed or performed.

### Recommendations

**Scope A — narrow trigger AND consequence, not just one of the two.**
1. *Trigger*: change `--invocation-count` at both call sites from the whole-invocation count to
   the same-cycle/same-wave co-dispatch count (`${#eligible_tasks[@]}` in
   `skill-orchestrate/SKILL.md` Stage MT-3 step 4.5; `${#wave_tasks[@]}` in `orchestrate.md` Step
   3, understanding per the Scope E finding that this specific line is documentation of the
   skill's contract rather than code the command file itself runs). This directly retires both
   verified incidents: an edge-connected pair can never co-occupy `eligible_tasks`/`wave_tasks`
   simultaneously (Stage MT-3 step 3's own eligibility rule enforces this identically for every
   predecessor edge), so the narrowed count for either member of such a pair is always 1 whenever
   it actually reaches the eligibility/dispatch computation.
2. *Consequence*: change `deferred_self_modifying` from a permanent, never-reset-mid-invocation
   exclusion set to a same-cycle-only defer, converging exactly like `file_scope_collision`
   already does (re-evaluated every cycle, no persistent set). This is required for the
   narrowing to be complete — narrowing only the trigger while keeping permanent-exclusion
   semantics would still strand a genuinely-colliding pair (no edge, same-cycle) once one member
   is admitted and the other permanently excluded, contradicting the schema doc's converging-defer
   precedent for the sibling defer_reason. Recommend retaining a distinct `defer_reason` value
   (`self_modifying`) so the operator-facing warning and remedy text can still name the hazard
   precisely, without perpetuating the permanent-set-based bookkeeping this narrowing removes.
3. *What still triggers after narrowing*: a self-modifying candidate that genuinely shares a
   cycle/wave with an un-edge-connected sibling — this is the surviving, hazard-1-grounded case
   the task's "DO NOT NAIVELY DELETE OR WEAKEN THIS GATE" instruction protects, and it is exactly
   the case Scope B's override flag exists to let an operator deliberately accept.
4. *Guardrails-doc update*: `batch-orchestration-guardrails.md`'s hazard 3 subsection (and its
   "Self-Modification Hazard: The Fourth Admission Dimension" section) should record, alongside
   dependency 934's existing (i)/(ii)/(iii) breakdown, a fourth clarification: the narrowing from
   whole-invocation to same-cycle scope is justified specifically because hazards 2 (retired) and
   3's residual (retired by dependency 934's checkpoint) are what the whole-invocation scope was
   over-protecting against; hazard 1 (verification gap) is unaffected by this scope choice in
   either direction and is not, by itself, a reason to prefer whole-invocation scope over
   same-cycle scope — it is the reason a gate (at whichever scope) must survive at all, and the
   reason Scope B's override defaults to off.

**A1 — resolve, do not replicate.** Recommend documenting in
`batch-orchestration-guardrails.md`'s "Self-Modification Hazard" section that the apparent
asymmetry between the collision dimension's explicit dependency-edge exemption and the self-mod
dimension's absence of one is **explained, not remedied**, by Scope A's narrowing: the collision
predicate's comparison set spans outside the current cycle/wave entirely (every non-terminal task
in `specs/state.json`, cross-batch), a scope where an edge-connected pair could otherwise
false-positive without the exemption; the self-mod predicate, once narrowed to the same-cycle
co-dispatch count, operates entirely within a set (`eligible_tasks`) that Stage MT-3 step 3's own
eligibility rule already guarantees excludes any edge-connected predecessor. Recommend explicitly
noting in the script's own header comment (the "Precedence (D4)" block) that no dependency-edge
exemption is needed in the self-mod branch for exactly this reason, so a future reader does not
mistake the asymmetry for an oversight and add dead code to "fix" it.

**Scope B — explicit opt-in override, default off, human-intent-gated.** Add
`--allow-self-modifying` (or an equivalently unambiguous name) as a new flag in
`scripts/parse-command-args.sh`, following the file's existing scan-then-strip pattern exactly:
add one `if [[ "$remaining" =~ --allow-self-modifying ]]; then ALLOW_SELF_MODIFYING_FLAG="true";
fi` block in Step 4 (alongside the other boolean flags, defaulting `ALLOW_SELF_MODIFYING_FLAG="false"`
in the same initialization block), one `| sed 's/--allow-self-modifying//g'` line in the Step 5
strip chain (placed anywhere in the chain since `sed` order does not matter for
disjoint patterns, but conventionally grouped with the other boolean-flag strips), and add the
new variable name to the final `export` statement. This is the exact failure mode the task's own
IMPLEMENTATION NOTE warns about: a flag added to the scan without the matching strip-chain entry
leaks its literal text into `FOCUS_PROMPT`, corrupting the prompt every downstream agent receives.
Thread the parsed flag through both call sites' bash: when true, skip the self-mod branch of
`orchestrate-batch-admit.sh`'s consumer-side handling entirely for this invocation (the script
itself remains a pure predicate and should NOT be modified to accept the flag — it has no
awareness of command-line flags today and should stay that way; the override belongs at the
consumer, which already branches on `defer_reason` and can simply choose not to act on a
`self_modifying` verdict when the flag is set, logging a loud "self-modification gate bypassed by
--allow-self-modifying" notice either way). Default OFF, matching every other safety-relevant flag
in the existing set (`--force`, not `--allow-force-by-default`). Document the flag in
`commands/orchestrate.md`'s `## Options` table alongside `--lit` and `--dry-run`, and reference it
from `batch-orchestration-guardrails.md`'s Self-Modification Hazard section as the deliberate,
human-intent escape hatch for the residual, narrowed-but-still-live same-cycle-collision case
(Scope A's #3 above).

**Scope C — re-apply, and extend to dependency 934's new dispatch-path additions.** Re-confirm
the nine existing entries' evidence unchanged (done above; no revision needed to any of the nine
rows). Apply the same two-test rigor to `scripts/deploy-headless.sh` and `scripts/verify-deploy.sh`,
both newly reachable on the MT dispatch path via dependency 934's Stage MT-3 step 7:
`verify-deploy.sh` is the stronger candidate for inclusion (a defect causing a false pass is
silent and decision-relevant, per the finding above); `deploy-headless.sh`'s primary failure mode
is already loud (matching the exclusion rationale for `validate-artifact.sh`), though a silent
partial-sync defect in it would also clear decision-relevance — recommend the planner decide
whether to add `verify-deploy.sh` alone, both, or neither, with the reasoning above as the basis,
and update the Inclusion/Exclusion tables accordingly with the same evidence-table format the
existing nine entries use. Also re-confirm (no change needed) that the three-excluded-files
reachability conclusion is unaffected by anything in this task's or dependency 934's changes,
consistent with the "Note on Reachability Durability" caveat already in the guardrails doc.

**Scope D — explicit transcription, not a stronger pointer.** Recommend adding, to
`skill-orchestrate-hard/SKILL.md`'s `## Multi-Task Mode` section, an explicit, named restatement
of Stage MT-3 step 4.5's admission-call bash block (with the narrowed `--invocation-count`
argument from Scope A) and step 7's redeploy-checkpoint trigger, each tagged with a byte-identical
cross-reference comment naming the exact base-skill stage/step they are transcribed from and
requiring co-maintenance (mirroring this file's own existing convention for other transcribed
mechanics, e.g., its `772`/`773` numbered-block markers). A bare strengthened pointer ("Same as
base... this INCLUDES Stage MT-3 step 4.5's admission call and step 7's redeploy checkpoint — see
that file for the exact bash") is a cheaper fix and worth recording as the fallback if the planner
judges the maintenance-burden tradeoff differently, but this task's own verified `grep` finding is
direct evidence that a bare pointer (even one already covering this exact mechanism, pre-dating
dependency 934) does not reliably produce the intended behavior — recommend transcription as the
primary recommendation, not the pointer-strengthening fallback.

**Scope E — fix the prose, not the command file's control flow.** Rewrite
`commands/orchestrate.md`'s "Runtime wave-split check (cross-batch defense-in-depth)" subsection
(Step 3) to state plainly that Step 4 hands the entire pre-computed wave schedule to a single
`skill-orchestrate` Skill-tool call, and that the actual, executing admission gate is
`skill-orchestrate/SKILL.md` Stage MT-3 step 4.5, which re-evaluates `eligible_tasks` every
**cycle** (not literally per pre-computed wave). Retain the bash block as illustrative of the
contract the skill fulfills (useful for a reader who wants to see the actual command without
opening the skill file), but remove or clearly bracket the "Before dispatching EVERY wave (Step
4)" framing that implies this file itself loops and gates wave-by-wave. This keeps the fix
one-directional (prose to behavior) rather than adding a real per-wave loop to the command file,
which would cut against the Anti-Bypass Constraint's intent of keeping lifecycle-adjacent
dispatch logic inside the delegated skill.

**Scope F — restate the acceptance, updated reasoning, no protection extension in this task.**
`batch-orchestration-guardrails.md`'s "Scope Limitation and Residual Risk" section already
documents this gap as known and accepted. Recommend restating it with reasoning updated for this
task's changes: plain multi-task `/implement N,M`, `/research N,M`, and `/plan N,M` have no wave
or cycle computation of any kind (no Kahn's algorithm, no `eligible_tasks` re-evaluation loop) —
they are simple per-task iteration with no wave/cycle unit to narrow a trigger against in the
first place, so Scope A's same-cycle narrowing does not transfer to these commands by analogy;
extending equivalent protection to them would require introducing a wave/cycle concept those
commands do not have today, which is out of this task's declared file scope. Recommend the
restated acceptance name this explicitly (rather than merely repeating "known, accepted, not
silently absorbed") so a future reader does not assume Scope A's narrowing implicitly covers
these commands too.

**Scope G — version bump required, not an additive field.** The self-mod defer_reason's
consequence changes from "excluded from the whole invocation, permanently, via a never-reset set"
to "deferred to the next cycle, converges the same way as `file_scope_collision`" (Scope A #2).
This is exactly the class of change the schema doc's own Version History calls out for the v1-to-v2
bump: "an unrecognized changed semantic routed through [an] old branch... produces a non-converging
retry loop, never a merely incorrect one-off classification" — here the risk runs the other
direction (a v2-assuming consumer that still treats `self_modifying` as permanently exclusionary
would over-defer a task that the new v3 script now expects to be retried next cycle, silently
reintroducing a form of the original whole-invocation-exclusion bug for any consumer not updated).
Recommend bumping to `orchestrate-batch-admit-v3`, with `docs/architecture/batch-admit-schema.md`
updated to: (1) document the new same-cycle-scoped, converging semantics for `defer_reason ==
"self_modifying"` (removing language that implies whole-invocation, permanent exclusion); (2) add
the `--allow-self-modifying` bypass behavior (Scope B) to the "Why This Check Is Blocking, Not
Advisory" section, noting that bypass is a consumer-side decision, never a change to the script's
own output schema; (3) add a Version History entry mirroring the existing v1-to-v2 entry's
reasoning; (4) add `skills/skill-orchestrate-hard/SKILL.md`'s `## Multi-Task Mode` section (once
transcribed per Scope D) to the "Read by" list at the top of the document, closing the accuracy
gap the task names explicitly.

## Decisions

- **Scope A**: narrow both the trigger (`--invocation-count` -> same-cycle/wave co-dispatch
  count) and the consequence (permanent `deferred_self_modifying` set -> same-cycle-only defer,
  converging like `file_scope_collision`). Both halves are needed; narrowing only one leaves the
  fix incomplete.
- **Scope A1**: no new dependency-edge exemption code in the self-mod predicate. Document the
  asymmetry as resolved by Scope A's narrowing (edge-connected pairs are structurally excluded
  from ever sharing a cycle/wave, so no explicit exemption is reachable code).
- **Scope B**: add `--allow-self-modifying`, default off, parsed via the existing scan-then-strip
  pattern in `parse-command-args.sh` (both halves required, per the task's own IMPLEMENTATION
  NOTE), acted on by the consumer (command/skill), not by `orchestrate-batch-admit.sh` itself.
- **Scope C**: re-confirm all nine existing entries unchanged; recommend the planner formally
  evaluate `verify-deploy.sh` (strong candidate) and `deploy-headless.sh` (weaker candidate, loud
  primary failure mode) as new critical-path entries, since dependency 934 newly wired both onto
  the MT dispatch path.
- **Scope D**: transcribe (not merely strengthen the pointer for) Stage MT-3 step 4.5 and step 7
  into `skill-orchestrate-hard/SKILL.md`'s `## Multi-Task Mode` section, with co-maintenance
  cross-reference comments.
- **Scope E**: rewrite `orchestrate.md`'s Step 3 prose to state the command hands off the whole
  wave schedule in one Skill call and the skill's Stage MT-3 is the sole executing, per-cycle gate
  — do not add a real per-wave loop to the command file.
- **Scope F**: restate the existing accepted-limitation language with reasoning specific to why
  Scope A's narrowing does not transfer (no wave/cycle unit exists in those commands).
- **Scope G**: bump to `orchestrate-batch-admit-v3` given the semantic (not merely additive)
  change to what a `self_modifying` defer means and how consumers must react to it.

## Risks & Mitigations

- **Risk**: narrowing Scope A without also narrowing the `deferred_self_modifying` set's
  permanence (consequence half) leaves a genuinely-colliding same-cycle pair permanently stranded
  once one member departs eligibility. **Mitigation**: Scope A's decision requires both halves;
  do not implement the trigger change alone.
- **Risk**: Scope B's override flag, if it defaults to on or is easy to leave set across
  invocations, would silently reintroduce whole-invocation-scale exposure to hazard 1 with no
  deliberate per-invocation intent. **Mitigation**: default off, per-invocation only (matching
  every other flag in `parse-command-args.sh`), documented explicitly in the guardrails doc as the
  human-intent escape hatch for the narrowed gate's residual case, not a general-purpose
  weakening.
- **Risk**: transcribing Stage MT-3 step 4.5/step 7 into `skill-orchestrate-hard/SKILL.md`
  (Scope D) creates a second copy that can drift from the base skill's copy over time.
  **Mitigation**: the file already accepts this maintenance tradeoff for other loop-level
  mechanics (its own stated design philosophy); tag both copies with a co-maintenance
  cross-reference comment, matching the existing `772`/`773` block-marker convention already used
  in this same file for exactly this kind of transcribed, must-stay-synchronized content.
- **Risk**: bumping to v3 (Scope G) without updating every consumer in the same change would
  leave a v2-assuming consumer silently misreading a same-cycle-converging defer as a permanent
  exclusion (or vice versa). **Mitigation**: the schema doc's own v1-to-v2 precedent already
  establishes the norm of updating all in-repo consumers in the same change that introduces a new
  version; recommend the plan enumerate the same consumer list (`commands/orchestrate.md` Step 3,
  `skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5, `scripts/orchestrate-dry-run-report.sh`
  Step 4, `scripts/orchestrate-predispatch-review.sh`, and now
  `skills/skill-orchestrate-hard/SKILL.md`'s transcribed copy per Scope D) and confirm each is
  updated together.
- **Risk**: extending the critical-path list (Scope C) to include `verify-deploy.sh` and/or
  `deploy-headless.sh` without also considering whether they need their OWN self-modification
  admission treatment (i.e., should a task whose `file_scope` names `verify-deploy.sh` itself be
  gated the same as one naming `orchestrate-batch-admit.sh`?) could be treated as automatic but
  deserves the same explicit two-test write-up as the existing nine, not just a name added to a
  list. **Mitigation**: recommend the plan produce the same evidence-table row format
  (Reachability evidence / Decision-relevance evidence) used for the existing nine entries, rather
  than a bare list append.

## Context Extension Recommendations

- **Topic**: none — this is a `meta`-type task whose only deliverables are the eight declared
  source-store files; no new context-file gap was identified beyond what the recommendations above
  already assign to specific files in scope.

## Appendix

### Files read (source-store, per the binding SOURCE-STORE RULE)

- `specs/934_inter_wave_redeploy_checkpoint/reports/01_inter-wave-redeploy-checkpoint-design.md`
  (full) and `specs/934_inter_wave_redeploy_checkpoint/summaries/01_inter-cycle-redeploy-checkpoint-summary.md`
  (full) — dependency's research and implementation record, read first per the delegation
  context's explicit instruction.
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` (full)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (full)
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` (full)
- `agent-system/extensions/core/scripts/parse-command-args.sh` (full)
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` (full)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage MT-1 through MT-5
  region, lines ~1100-1420 and ~1740-1800; grep across the whole file for
  `batch-admit|self_modif|deferred_self_modifying|invocation-count`)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (lines 1-120, 1180-1224;
  full-file grep for `Stage MT|multi_task|MULTI-TASK|deploy-headless|verify-deploy|wave`)
- `agent-system/extensions/core/commands/orchestrate.md` (lines 1-300, 301-370, 405-475, 502-560;
  full-file grep for step/stage headings and `Skill(`)
- `specs/state.json` entries for tasks 934 and 935 (dependency/file_scope confirmation)

### Note on this task's own handoff artifact

Per `docs/architecture/handoff-schema.md`'s "Handoff Writers" table, base-mode `skill-researcher`
(and, by the same documented rule, this research agent) is explicitly prohibited from writing
`.orchestrator-handoff.json` — research's outcome channel is `.return-meta.json` only. This report
and the accompanying `.return-meta.json` (status `researched`) are the complete, correctly-scoped
output of this research pass; no `.orchestrator-handoff.json` was written.

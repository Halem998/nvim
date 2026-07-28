# Implementation Plan: Task #935

- **Task**: 935 - Narrow the self-modifying admission defer from whole-invocation to same-wave scope, add an explicit opt-in override flag, and reconcile the surrounding documentation/schema/hard-mode gaps this narrowing exposes
- **Status**: [IMPLEMENTING]
- **Effort**: 11 hours
- **Dependencies**: 932, 933, 934, 936 (all completed)
- **Research Inputs**: specs/935_narrow_self_modifying_defer_and_override_flag/reports/01_narrow-self-mod-defer-override-flag.md
- **Artifacts**: plans/01_narrow-self-mod-defer-override-flag.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The self-modification admission trigger in `orchestrate-batch-admit.sh` fires on
`--invocation-count > 1`, but both live callers deliberately pass the WHOLE invocation's candidate
count rather than the actual same-cycle co-dispatch count. Because Stage MT-3 step 3's eligibility
rule makes it structurally impossible for a `dependencies[]`-edge-connected pair to occupy the same
`eligible_tasks` batch, an edge-connected pair is a pure false positive today. This plan narrows
the trigger to the same-cycle/same-wave co-dispatch count AND narrows the consequence (the
permanent `deferred_self_modifying` exclusion set becomes a same-cycle defer converging like
`file_scope_collision`), adds an opt-in `--allow-self-modifying` override defaulting off, closes
the hard-mode gate gap by explicit transcription, re-applies the two conjunctive critical-path
tests to the newly-reachable deploy scripts, fixes the command-file prose/behavior mismatch,
restates the plain-multi-task scope limitation, and bumps the verdict schema to
`orchestrate-batch-admit-v3`.

Definition of done: all eight declared source-store files updated coherently, a single deliberate
redeploy performed only at the end, and the standing safe default preserved — a genuinely
co-dispatched self-modifying candidate still defers unless a human passes the override.

### Research Integration

The research report is the primary input and is followed on every scope item. Its load-bearing
findings integrated here:

- **Root cause is a counting-unit bug, not a design decision.** Both call sites pass
  `${#task_numbers[@]}` / `${#validated_tasks[@]}` where the actual co-dispatch set is
  `${#eligible_tasks[@]}` / `${#wave_tasks[@]}`. Phase 4 and Phase 6 change exactly that argument.
- **Both halves of Scope A are required.** Narrowing only the trigger while keeping the
  never-reset `deferred_self_modifying` exclusion set would strand a genuinely-colliding
  same-cycle pair. Phase 5 narrows the consequence.
- **A1's asymmetry is explained, not remedied.** Once the count is same-cycle-scoped, an
  edge-connected pair can never co-occupy the count, so an explicit dependency-edge exemption in
  the self-mod branch would be unreachable dead code. Recorded as documentation (Phases 1 and 9),
  never as new predicate code.
- **Scope B's override must default off**, justified by the trade the narrowing makes: an
  edge-serialized self-modifying pair now runs inside one automated invocation where the
  inter-cycle redeploy checkpoint auto-redeploys and auto-verifies with zero human review,
  replacing a human-paced manual redeploy. Hazard 1 (verification gap) is retired by nothing in
  this chain and is why a safe default must survive.
- **Scope D is fixed by transcription, not a stronger pointer.** The zero-hit grep for
  `batch-admit` in the hard-mode skill is direct evidence that the existing bare pointer does not
  reliably carry the mechanism.
- **Scope G is a version bump, not an additive field**, because the consequence of a
  `self_modifying` defer changes semantically.

### Prior Plan Reference

No prior plan for this task. Effort calibration and sequencing discipline are borrowed from the
immediately-preceding dependency task's implementation record (`specs/934_inter_wave_redeploy_checkpoint/summaries/01_inter-cycle-redeploy-checkpoint-summary.md`):
seven phases at ~2.5 hours total for a smaller surface; that task confirmed empirically that a
mid-run deploy can crash a script that is overwriting itself, and that
`check-extension-docs.sh` FAILs on source/deploy drift until a deliberate redeploy. Both facts are
designed into this plan's sequencing and verification.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and `roadmap_flag` is absent. No
ROADMAP.md consultation performed; no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Narrow the self-modification defer's TRIGGER from whole-invocation count to same-cycle/same-wave
  co-dispatch count, at both live call sites and in the script's own contract documentation.
- Narrow the defer's CONSEQUENCE from a permanent invocation-scoped exclusion set to a same-cycle
  defer that converges the way `file_scope_collision` already does.
- Add `--allow-self-modifying` (default off) through `parse-command-args.sh`'s scan AND strip
  chain, threaded to the consumer, never to the predicate script.
- Record, per remaining unit of strictness, which surviving hazard it pays for; remove strictness
  with no surviving hazard behind it.
- Close the hard-mode gate gap by explicit transcription into `skill-orchestrate-hard/SKILL.md`.
- Re-apply the two conjunctive tests to the nine declared critical paths and to the two scripts
  newly wired onto the MT dispatch path.
- Make `commands/orchestrate.md` Step 3's prose match what that file actually does.
- Restate the plain-multi-task scope limitation with reasoning current after this narrowing.
- Bump the verdict schema to `orchestrate-batch-admit-v3` and update the schema document.

**Non-Goals**:
- Removing, disabling, or weakening the gate. A genuinely co-dispatched self-modifying candidate
  still defers by default.
- Adding a dependency-edge exemption to the self-mod predicate (it would be unreachable).
- Adding a real per-wave dispatch loop to `commands/orchestrate.md`.
- Extending admission protection to plain `/implement N,M`, `/research N,M`, `/plan N,M` (Scope F
  restates the acceptance; extension would require a wave/cycle concept those commands lack).
- Editing `scripts/orchestrate-dry-run-report.sh` or `scripts/orchestrate-predispatch-review.sh` —
  both are outside the declared file scope. Their v3 compatibility is verified and recorded, not
  patched.
- Any write under `.claude/**` other than the single deliberate deploy in the final phase.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A mid-implementation redeploy swaps `orchestrate-batch-admit.sh` / `parse-command-args.sh` under the in-flight run, stranding it | H | M | No redeploy occurs until Phase 10. All edits land in `agent-system/extensions/core/` only; the live `.claude/` tree keeps its coherent pre-change copies for the whole run. Phase 10 performs ONE deliberate redeploy after every file is mutually consistent. |
| This task's own `file_scope` names six critical paths; if run under multi-task `/orchestrate`, Stage MT-3 step 7's checkpoint would auto-redeploy mid-invocation | H | L | This task must run SOLO. That is exactly what the pre-narrowing gate enforces today, and the narrowing does not land until Phase 10's redeploy. Phase 10 verifies solo-run behavior is preserved. |
| Narrowing only the trigger leaves a genuinely-colliding same-cycle pair permanently stranded | H | M | Phase 5 is mandatory and depends on Phase 4; the plan does not admit a trigger-only outcome. |
| Removing the permanent exclusion set introduces a new non-convergence mode: `eligible_tasks` non-empty every cycle but admission defers every candidate, so nothing dispatches until MAX_CYCLES | M | M | Phase 5 adds an explicit post-admission empty-dispatch-batch guard alongside the existing pre-admission circuit breaker, and writes down the convergence argument. |
| `--allow-self-modifying` added to the scan without the strip chain leaks its literal text into `FOCUS_PROMPT` for every downstream agent | H | M | Phase 2's verification is a live source-and-assert test on `FOCUS_PROMPT`, not a diff read. |
| The override flag defaults on, or persists across invocations, silently restoring whole-invocation exposure to hazard 1 | H | L | Default `"false"` in the same initialization block as every other boolean flag; per-invocation only, no state.json field; loud bypass notice logged at the consumer whether or not the gate would have fired. |
| Renaming `--invocation-count` would break the two out-of-scope report composers (unknown flag becomes a positional arg, then a usage error, exit 2) | H | L | The flag name is RETAINED; only its documented semantics change. Rejected-alternative recorded in the script header. |
| A v3 bump leaves an unupdated consumer misreading the new converging defer as a permanent exclusion | M | M | Phase 9 enumerates every consumer and verifies each. The two out-of-scope report composers are verified to pin no `$schema` literal and to branch on `defer_reason`, so they remain v3-compatible; their now-pessimistic exclusion-scope prose is recorded as a declared residual. |
| `check-extension-docs.sh` FAILs on source/deploy drift for the whole run | L | H | Expected and pre-declared. It is re-run to PASS only after Phase 10's redeploy. |
| Guardrails-doc edits accrue task-number citations | M | M | `no-task-references-in-deliverables` sweep is a named verification step in Phases 3, 8, 9, and 10; provenance is cited by durable anchor (section name / file path) only. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2 |
| 3 | 5 | 4 |
| 4 | 6, 7, 8 | 5 |
| 5 | 9 | 5, 7 |
| 6 | 10 | 6, 8, 9 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Admission script — v3 schema and contract-header rewrite [COMPLETED]

**Goal**: Make `orchestrate-batch-admit.sh` emit `orchestrate-batch-admit-v3` and carry a header
that states the narrowed semantics, the retained flag name, and the A1 no-edge-exemption
resolution. The predicate logic itself does not change — the counting unit is a caller concern.

**Tasks**:
- [x] Replace every `"orchestrate-batch-admit-v2"` string literal in the jq program with
      `"orchestrate-batch-admit-v3"`. Anchor on the quoted literal, not on line numbers.
- [x] Rewrite the `--invocation-count <N> (D3)` header block: it now documents the number of
      candidates being CO-DISPATCHED IN THE SAME wave/cycle as the positional arguments, not the
      whole invocation. Callers that pass a wave/cycle subset MUST pass that subset's own size.
      Keep the `argc` default and the non-integer usage-error behavior unchanged.
- [x] Add to the same header block an explicit "flag name retained" note: `--invocation-count` is
      kept rather than renamed because two out-of-scope report composers
      (`orchestrate-dry-run-report.sh`, `orchestrate-predispatch-review.sh`) pass it by name and an
      unknown flag would fall through to positional validation and abort with exit 2. Record the
      rejected `--codispatch-count` alias and why it was not added (extra surface on
      orchestrator-critical machinery for a naming improvement only).
- [x] Rewrite the file-top paragraph that reads "the candidate is deferred out of the WHOLE
      INVOCATION (never merely a wave/cycle)" to state the narrowed consequence: deferred out of
      the current wave/cycle, converging the same way a `file_scope_collision` defer does.
- [x] Extend the `Precedence (D4)` header block with the A1 resolution: the collision dimension's
      `dependencies[]`-edge exemption is deliberately NOT replicated in the self-mod branch, and
      this is not an oversight. State the reason — once the count is same-cycle-scoped, an
      edge-connected pair is structurally excluded from ever sharing that count by the eligibility
      rule, so an explicit exemption would be unreachable code. Also correct D4's "strictly larger"
      rationale sentence, which no longer holds now that both defer flavors share a wave/cycle
      scope of consequence; re-ground it on the remaining reason (a pure single-candidate predicate
      evaluated before a set-comparison scan).
- [x] Update the `defer_reason` field-description comment: it no longer says the two reasons carry
      "whole-invocation exclusion vs. one-wave/cycle deferral"; both are wave/cycle-scoped, and the
      discriminator now exists to name the HAZARD and select the operator remedy.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: The `$schema` literal appears exactly 9 times in
`scripts/orchestrate-batch-admit.sh`, and the only two source-store files containing
`orchestrate-batch-admit-v2` are that script and `docs/architecture/batch-admit-schema.md`.
Confirm at implementation time with
`grep -c 'orchestrate-batch-admit-v2' agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`
and `grep -rln 'orchestrate-batch-admit-v2' agent-system/`. If either count differs, enumerate the
actual sites before editing and record the correction.

**Scope Hypothesis**: The source-store copy of this script CANNOT be executed in place —
`deploy-root-guard.sh` rejects any invocation whose parent directory is not `*/.claude` or
`*/.opencode`. Confirm by running the edited source-store copy once and reading the guard's
error, then use the scratch-tree path below. Do NOT "fix" this by redeploying.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` — schema literals (9),
  `--invocation-count` contract block, whole-invocation consequence paragraph, `Precedence (D4)`
  block, `defer_reason` field comment.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` exits 0.
- `grep -c 'orchestrate-batch-admit-v3'` equals the pre-edit v2 count; `grep -c
  'orchestrate-batch-admit-v2'` is 0 in this file.
- Executable smoke test WITHOUT touching the live deploy tree: create a scratch deploy-shaped
  directory under the scratchpad (`<scratch>/repo/.claude/scripts/`), copy the edited script plus
  `deploy-root-guard.sh` into it, copy `context/reference/orchestrator-critical-paths.json` to the
  matching relative location, write a synthetic `<scratch>/repo/specs/state.json` containing (a) a
  self-modifying candidate, (b) an unrelated sibling, (c) an edge-connected pair. Then assert:
  `--invocation-count 1` on the self-modifying candidate yields `decision":"admit"` with
  `"self_modifying":true`; `--invocation-count 2` yields `"decision":"defer"` with
  `"defer_reason":"self_modifying"`; every emitted line carries
  `"$schema":"orchestrate-batch-admit-v3"`.
- Confirm the collision-scan branch is unchanged: the collision verdict for the unrelated pair is
  byte-identical to the pre-edit output apart from the `$schema` value.

---

### Phase 2: Add `--allow-self-modifying` to the shared argument parser [COMPLETED]

**Goal**: Add the override flag to `parse-command-args.sh` through BOTH the scan and the strip
chain, with a default of `"false"`, so no literal flag text can leak into `FOCUS_PROMPT`.

**Tasks**:
- [x] Add `ALLOW_SELF_MODIFYING_FLAG` to the `# Exported Variables:` header comment block, worded
      like the other boolean entries and stating "default off; opt-in bypass of the
      self-modification admission gate, per-invocation only".
- [x] Add `ALLOW_SELF_MODIFYING_FLAG="false"` to the Step 4 initialization block alongside
      `LIT_FLAG="false"`.
- [x] Add the scan block `if [[ "$remaining" =~ --allow-self-modifying ]]; then
      ALLOW_SELF_MODIFYING_FLAG="true"; fi`, grouped with the other boolean-flag scans.
- [x] Add `| sed 's/--allow-self-modifying//g'` to the Step 5 strip chain, grouped with the other
      boolean-flag strips.
- [x] Add `ALLOW_SELF_MODIFYING_FLAG` to the Step 6 `export` statement.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: No existing scan pattern falsely matches inside the literal
`--allow-self-modifying`, and no existing strip pattern partially consumes it (which would leave
a fragment in `FOCUS_PROMPT`). The candidate near-misses to check are `--local`, `--lit`,
`--force`, `--fast`. Confirm empirically by the leak test below rather than by reading the
patterns; if any false match is found, reorder the strip chain so the longest pattern is stripped
first and record the ordering constraint in a comment.

**Files to modify**:
- `agent-system/extensions/core/scripts/parse-command-args.sh` — header comment, Step 4 init,
  Step 4 scan, Step 5 strip chain, Step 6 export.

**Verification**:
- `bash -n` on the edited file exits 0.
- Leak test (the load-bearing check): in one shell, source the edited file with
  `"935 --allow-self-modifying focus on the gate"` and assert `ALLOW_SELF_MODIFYING_FLAG` is
  `true`, `TASK_NUMBERS` is `935`, and `FOCUS_PROMPT` is exactly `focus on the gate` with no
  `--allow`, no `self-modifying`, and no stray hyphen residue.
- Default test: source with `"935 focus on the gate"` and assert `ALLOW_SELF_MODIFYING_FLAG` is
  `false` and `FOCUS_PROMPT` is unchanged.
- Non-interference test: source with `"935 --lit --hard --allow-self-modifying text"` and assert
  `LIT_FLAG=true`, `EFFORT_FLAG=hard`, `ALLOW_SELF_MODIFYING_FLAG=true`, `FOCUS_PROMPT=text`.
- Regression test: source with `"935 --local --force text"` and assert
  `ALLOW_SELF_MODIFYING_FLAG=false` (no false positive from the new scan).

---

### Phase 3: Critical-path list — re-apply the two tests, add the tenth entry [COMPLETED]

**Goal**: Execute Scope C. Re-confirm the nine existing entries against the two conjunctive tests,
and formally evaluate the two scripts newly wired onto the MT dispatch path by the inter-cycle
redeploy checkpoint, adding whichever clears both tests with the same evidence-row format.

**Tasks**:
- [x] Read `skill-orchestrate/SKILL.md` Stage MT-3 step 7 to confirm exactly which scripts the
      checkpoint invokes on the MT dispatch path.
- [x] Re-apply reachability + decision-relevance to all nine existing Inclusion Table rows. Record
      "unchanged" explicitly rather than silently leaving them alone; no row is expected to change.
- [x] Apply both tests to `scripts/verify-deploy.sh`. Decision to implement: **INCLUDE**.
      Reachability — executed directly from Stage MT-3 step 7 on the MT dispatch path.
      Decision-relevance — a defect causing a false PASS is silent and lets a broken deploy be
      treated as verified, matching the admission-predicate row's own "a bug in it defeats the very
      check meant to catch bugs like it" language.
- [x] Apply both tests to `scripts/deploy-headless.sh`. Decision to implement: **EXCLUDE**, with an
      evidence row in the Exclusion Table's "Reachable but not decision-relevant" group. Its
      primary failure mode is loud (`exit 1`/`2`, triggering the documented failure-path warning
      and `deferred_deploy_checkpoint` population), matching the exclusion rationale already used
      for `validate-artifact.sh`. Record in the same row that a hypothetical silent partial-sync
      defect would clear decision-relevance, so a future reader sees this was a judged call on the
      primary mode, not an unconsidered omission.
- [x] Add the `verify-deploy.sh` entry to `context/reference/orchestrator-critical-paths.json`'s
      `critical_paths` array with a short `label` (e.g. `"deploy verification gate"`), matching the
      existing entry shape exactly.
- [x] Add the matching row to the guardrails Inclusion Table with both evidence columns filled, and
      update that section's heading and any "the nine files" phrasing to the new count.
- [x] Add the `deploy-headless.sh` row to the Exclusion Table with its evidence.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: `deploy-headless.sh` and `verify-deploy.sh` are the ONLY files newly
reachable on the MT batch-dispatch path since the inter-cycle redeploy checkpoint landed. Confirm
by reading Stage MT-3 step 7 in full and enumerating every script it invokes; if a third appears,
apply the same two tests to it and record the outcome rather than silently skipping it.

**Files to modify**:
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` — one new
  `critical_paths` entry.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — Inclusion
  Table (one new row, heading count), Exclusion Table (one new row).

**Verification**:
- `jq -e . agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` exits 0
  and the new entry has both `path` and `label` keys.
- `jq '.critical_paths | length'` equals the prior length plus 1.
- Re-run Phase 1's scratch-tree smoke test with the updated critical-paths file copied in, and
  assert a synthetic candidate whose `file_scope` names `scripts/verify-deploy.sh` now yields
  `"self_modifying":true`.
- Guardrails table row count matches the JSON array length; every heading or prose reference to the
  old count is updated (grep the file for the old numeral used as a file count).
- No task-number citation introduced (grep the diff for `task [0-9]`).

---

### Phase 4: Narrow the TRIGGER and add the override consumer branch [COMPLETED]

**Goal**: In `skill-orchestrate/SKILL.md` Stage MT-3 step 4.5, change the `--invocation-count`
argument from the whole-invocation count to the same-cycle co-dispatch count, invert the prose that
currently forbids exactly that, and add the `--allow-self-modifying` bypass branch at the consumer.

**Tasks**:
- [x] Change the step 4.5 bash call from `--invocation-count "${#task_numbers[@]}"` to
      `--invocation-count "${#eligible_tasks[@]}"`. Everything else on that line is unchanged.
- [x] Rewrite the sentence immediately above that call — currently "passing `--invocation-count`
      set to this invocation's FULL `task_numbers` count (NOT `${#eligible_tasks[@]}`), so the
      self-modification defer trigger below is evaluated against the whole invocation, never just
      this cycle's eligible subset" — to state the inverted, now-correct contract: the count is
      this cycle's actual co-dispatch set, because an edge-connected pair can never share an
      `eligible_tasks` batch (step 3's predecessor rule guarantees it), so a whole-invocation count
      fires against pairs that never actually co-occur.
- [x] Add a short rationale sentence naming which surviving hazard the remaining strictness pays
      for: a self-modifying candidate genuinely sharing a cycle with an un-edge-connected sibling
      still defers, and that residual is grounded in the standing verification-gap hazard, not in
      the two hazards the dependency chain retired.
- [x] Add the override branch to the `self_modifying` consumer handling: when the invocation
      carries `allow_self_modifying == true`, do NOT act on the `self_modifying` defer verdict —
      dispatch the candidate this cycle anyway — and log a loud, distinct bypass notice naming the
      matched `critical_path` and `critical_label` and the flag that caused the bypass. State
      explicitly that the bypass is a CONSUMER-side decision: the verdict is still emitted, still
      carries `self_modifying: true`, and `orchestrate-batch-admit.sh` is never passed the flag.
- [x] Log the bypass notice whether or not the gate would otherwise have fired, so a transcript
      reader can always tell the override was active.
- [x] Read `allow_self_modifying` from the delegation context alongside `session_id` / `lit_flag`
      in the Stage MT-1 input list.

**Timing**: 1 hour

**Depends on**: 1, 2

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-1 delegation-context
  input list; Stage MT-3 step 4.5 bash call, its preceding contract prose, and the
  `self_modifying` consumer branch.

**Verification**:
- Grep the file for `--invocation-count`: exactly one occurrence remains and it reads
  `"${#eligible_tasks[@]}"`.
- Grep for `${#task_numbers[@]}` in the step 4.5 region: zero occurrences.
- No remaining prose in this file instructs a caller to pass the whole-invocation count (grep for
  `FULL` / `whole invocation` in the step 4.5 region and confirm each surviving hit is the
  corrected wording).
- The bypass branch names `allow_self_modifying`, states the consumer-side-only rule, and does not
  add any flag to the script invocation line.
- Trace-read the step 4.5 branch table end to end and confirm the three `defer_reason` outcomes
  (`self_modifying` with and without override, `in_batch`, `cross_batch`) each have exactly one
  reachable handling path.

---

### Phase 5: Narrow the CONSEQUENCE — converging same-cycle defer [COMPLETED]

**Goal**: Change `deferred_self_modifying` from a never-reset eligibility-exclusion set into a
same-cycle defer that converges like `file_scope_collision`, retaining the field only as an
invocation-scoped OBSERVATION log for postflight reporting, and add the convergence guard the
removal makes necessary.

**Tasks**:
- [x] Stage MT-1 `mt_state_file` schema: redefine `deferred_self_modifying: []` as an append-only
      observation log of task numbers the gate deferred at least once this invocation. State
      explicitly that it is NO LONGER an eligibility exclusion, and that the convergence mechanism
      is now the same one `file_scope_collision` uses (re-evaluated every cycle, no persistent
      exclusion). Preserve `deferred_deploy_checkpoint`'s distinct, still-permanent semantics
      untouched and say so, so the two are not conflated.
- [x] Stage MT-3 step 2 (all-terminal check): remove `deferred_self_modifying` from the set of
      conditions that count a task as "nothing left to do". A same-cycle-deferred task still has
      work pending. Leave `deferred_deploy_checkpoint` in place.
- [x] Stage MT-3 step 3 (build `eligible_tasks`): remove the `NOT in deferred_self_modifying`
      exclusion bullet and its convergence-rationale text. Leave the `deferred_deploy_checkpoint`
      bullet unchanged.
- [x] Stage MT-3 step 4 (no-eligible circuit breaker): remove `deferred_self_modifying` from its
      exclusion list, and update the parenthetical that currently reserves the "stuck tasks"
      framing away from deferred-self-modifying tasks.
- [x] Stage MT-3 step 4.5 `self_modifying` branch: change "add it to the INVOCATION-SCOPED
      `deferred_self_modifying` set (persists for the remainder of this invocation)" to "remove
      from THIS cycle's dispatch batch, exactly as the two `file_scope_collision` branches do, and
      append to the `deferred_self_modifying` observation log". Update the warning text so it no
      longer says "excluding from this invocation / re-run it alone" — it now says the candidate is
      deferred to a later cycle and names the co-dispatched sibling situation that caused it.
- [x] **Add the convergence guard**: after step 4.5's filtering, if the dispatch batch is empty
      while `eligible_tasks` was non-empty, nothing dispatches this cycle. Add an explicit
      consecutive-no-dispatch counter (reset on any dispatch) that breaks the loop with partial
      status and a named diagnostic once it reaches a small bound. Write down the convergence
      argument this replaces: a same-cycle self-mod defer clears once its co-dispatched sibling
      leaves `eligible_tasks` (entering `researching`/`planning`, terminating, or failing), which
      the existing loop guarantees; the counter exists only to bound the case where it does not.
- [x] Stage MT-5: keep `deferred_self_modifying` in the consolidated summary and in
      `.return-meta-multi.json`'s `tasks_deferred_self_modifying`, but relabel it from
      "deferred-for-solo-run" to an observation ("deferred at least one cycle by the
      self-modification gate"). Change the `exit_status` gate so it no longer goes partial merely
      because the log is non-empty — a task that was deferred and then ran to a terminal state is a
      success. Gate instead on whether any logged task is still non-terminal at loop exit.
- [x] Sweep the whole file for any remaining prose asserting whole-invocation exclusion or
      permanent-set semantics for `self_modifying` and correct each.

**Timing**: 2 hours

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: `deferred_self_modifying` occurs 20 times in
`skills/skill-orchestrate/SKILL.md`. Confirm with
`grep -c deferred_self_modifying agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
before editing, and re-run after to confirm every surviving occurrence is either the observation-log
definition, an observation-log append, or a reporting read — and that zero occurrences remain in an
eligibility, all-terminal, or circuit-breaker condition.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-1 schema block;
  Stage MT-3 steps 2, 3, 4, 4.5 (plus the new guard); Stage MT-5 reporting, `exit_status` gate,
  and the `.return-meta-multi.json` jq construction.

**Verification**:
- Post-edit `grep -n deferred_self_modifying` output is read line by line and each hit classified
  as definition / append / report. Zero hits appear in an eligibility or terminal-check condition.
- `grep -n deferred_deploy_checkpoint` confirms every one of its occurrences is unchanged from the
  pre-edit state (this phase must not disturb the checkpoint's permanent semantics).
- Trace three scenarios on paper against the edited text and record the traces:
  (a) self-modifying candidate + un-edge-connected sibling, both eligible cycle 1 — candidate
  defers, sibling dispatches, candidate dispatches cycle 2 once the sibling leaves eligibility;
  (b) self-modifying candidate + edge-connected predecessor — candidate never shares a cycle,
  count is 1, admits immediately;
  (c) two mutually-colliding self-modifying candidates that keep re-qualifying — the new
  no-dispatch counter breaks the loop with a named partial diagnostic rather than spinning to
  MAX_CYCLES_MT.
- The `exit_status` gate no longer references a non-empty `deferred_self_modifying` as a partial
  trigger; confirm the replacement condition is stated in terms of terminal status at loop exit.

---

### Phase 6: `commands/orchestrate.md` — Scope E prose, narrowed count, override option [COMPLETED]

**Goal**: Make the command file's Step 3 prose match what the file actually does, carry the
narrowed count in its illustrative block, document `--allow-self-modifying`, and thread the parsed
flag into the Skill delegation context.

**Tasks**:
- [x] Rewrite the "Runtime wave-split check (cross-batch defense-in-depth)" framing. Remove the
      "Before dispatching EVERY wave (Step 4)" claim. State plainly that Step 4 builds
      `waves_json` wholesale and hands the ENTIRE pre-computed wave schedule to a single
      `skill-orchestrate` Skill call, and that the sole executing admission gate is
      `skill-orchestrate/SKILL.md` Stage MT-3 step 4.5, which re-evaluates `eligible_tasks` every
      CYCLE rather than iterating the pre-computed `waves[]` array. Do not add a real per-wave
      dispatch loop to this file.
- [x] Retain the bash block, explicitly bracketed as illustrative of the contract the skill
      fulfills rather than as code this file runs. Change its `--invocation-count` argument from
      `"${#validated_tasks[@]}"` to `"${#wave_tasks[@]}"` and rewrite the surrounding sentence that
      currently says "never `${#wave_tasks[@]}`".
- [x] Rewrite the `self_modifying` bullet: it no longer says "exclude the candidate from the WHOLE
      INVOCATION". It says the candidate is deferred out of the current wave/cycle and becomes
      eligible on a later one, and it names the override flag as the deliberate human-intent escape
      hatch for the residual co-dispatch case.
- [x] Leave the "Post-dispatch counterpart" note about the inter-cycle redeploy checkpoint intact;
      re-read it after editing to confirm it still reads correctly in the new surrounding prose.
- [x] Add `--allow-self-modifying` to the `## Options` table with its default (`false`) and a
      description naming it as an opt-in bypass requiring deliberate human intent.
- [x] In STAGE 0, read `ALLOW_SELF_MODIFYING_FLAG` from the sourced parser and pass it into the
      Skill delegation context as `allow_self_modifying`, alongside `lit_flag`.
- [x] Confirm the Consolidated Output "Exit-path coverage" table's "Deferred self-modifying" row
      now reads accurately ("it becomes eligible, and committable, on a later cycle"), which was
      previously inaccurate against the permanent-set implementation. Correct the surrounding row
      text if the wording still implies a solo re-run is required.

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/commands/orchestrate.md` — `## Options` table; STAGE 0 flag
  threading; Step 3 wave-split-check subsection (framing, bash argument, `self_modifying` bullet);
  Consolidated Output exit-path row.

**Verification**:
- Grep for `EVERY wave`: zero occurrences remain in the Step 3 subsection.
- Grep for `--invocation-count`: the single occurrence reads `"${#wave_tasks[@]}"`.
- Grep for `WHOLE INVOCATION` in the `self_modifying` bullet: zero occurrences.
- `--allow-self-modifying` appears in the Options table and in the STAGE 0 delegation-context
  construction; the two spellings match exactly.
- Read Step 4 in full and confirm no dispatch loop was added — the `for wave_tasks in
  "${waves[@]}"` loop still only serializes JSON.
- No task-number citation introduced (grep the diff for `task [0-9]`).

---

### Phase 7: Hard-mode gate gap — explicit transcription (Scope D) [COMPLETED]

**Goal**: Close the verified gate gap. Transcribe the admission call and the redeploy checkpoint
into `skill-orchestrate-hard/SKILL.md`'s `## Multi-Task Mode` section so a multi-task `--hard` run
has a self-modification gate, a cross-batch collision gate, and a redeploy checkpoint — instead of
a bare pointer that the zero-hit grep shows is not reliably followed.

**Tasks**:
- [x] Decision to implement: **hard mode gets the gate, by transcription.** Record the reasoning in
      the section itself — a bare "same as base" pointer already nominally covered this mechanism
      and produced zero references to it, so strengthening the pointer would repeat the failure
      class this task just found. Note that this matches the file's own stated design philosophy as
      a full structural variant rather than a thin wrapper.
- [x] Expand `## Multi-Task Mode` beyond its current two-sentence pointer: keep the pointer, then
      add an explicitly transcribed restatement of Stage MT-3 step 4.5 — the admission call with
      the NARROWED `--invocation-count "${#eligible_tasks[@]}"` argument, the `defer_reason`-first
      branching, the `self_modifying` / `in_batch` / `cross_batch` handling, the
      `--allow-self-modifying` bypass branch, and the degradation path.
- [x] Transcribe Stage MT-3 step 7's redeploy-checkpoint trigger in the same section, since it sits
      on the same dispatch path and shares the same inheritance-by-prose weakness.
- [x] Tag both transcribed blocks with a co-maintenance cross-reference naming the exact base-skill
      stage and step they mirror, and stating that an edit to either copy REQUIRES the same edit to
      the other. Follow the file's existing convention for marked transcribed blocks; anchor on the
      convention's shape, not on any line number.
- [x] Do not restate the verdict schema or the overlap predicate — reference
      `docs/architecture/batch-admit-schema.md` and
      `context/patterns/file-footprint-overlap.md` by path, matching the base skill.

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: full

**Scope Hypothesis**: `skill-orchestrate-hard/SKILL.md` currently contains ZERO occurrences of
`batch-admit`, `deploy-headless`, and `verify-deploy`. Confirm with a pre-edit grep; if any
occurrence exists, reconcile with it rather than adding a duplicate.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — `## Multi-Task Mode`
  section only.

**Verification**:
- Post-edit `grep -n 'orchestrate-batch-admit'` returns at least one hit in the `## Multi-Task
  Mode` section (the gap is closed).
- The transcribed admission call's `--invocation-count` argument is byte-identical to the base
  skill's post-Phase-4 argument; diff the two blocks and confirm the only intended differences are
  the co-maintenance markers.
- The co-maintenance marker names the base stage and step by name, not by line number.
- `## Key Differences from skill-orchestrate` is re-read and updated if the new section
  contradicts any row.

---

### Phase 8: Guardrails doc — hazard accounting, A1, override rationale, Scope F [COMPLETED]

**Goal**: Record, in the authoritative pattern document, which surviving hazard each remaining unit
of strictness pays for; resolve A1 as explained-not-remedied; state why the override defaults off;
and restate the plain-multi-task scope limitation with current reasoning.

**Tasks**:
- [x] In `## Self-Modification Hazard: The Fourth Admission Dimension`, add a subsection recording
      the narrowing and its hazard accounting: the whole-invocation scope was over-protecting
      against the rollback/commit-granularity hazard (retired) and the bootstrapping hazard's
      in-batch form (retired by the inter-cycle redeploy checkpoint); the verification-gap hazard is
      unaffected by the scope choice in EITHER direction, so it is not itself an argument for
      whole-invocation scope — it is the reason a gate at some scope must survive at all.
- [x] Add the A1 resolution to the same section: the collision dimension's `dependencies[]`-edge
      exemption is load-bearing there because its comparison set spans outside the current
      wave/cycle (every non-terminal task in state, cross-batch); the self-mod dimension needs no
      such exemption once its count is same-cycle-scoped, because the eligibility rule already
      guarantees an edge-connected pair never shares that count. State that the asymmetry is
      explained rather than fixed, and that adding an exemption would be unreachable code.
- [x] Update the hazard 3 (i)/(ii)/(iii) breakdown where it asserts the in-batch form is
      "structurally impossible" BECAUSE the gate excludes from the whole invocation — that premise
      no longer holds. Restate it in terms of the narrowed gate plus the checkpoint, preserving the
      retired/surviving split style the section already uses.
- [x] Record the override flag: name `--allow-self-modifying`, state the default is off, and state
      the justification directly — the narrowing trades a solo re-run where a human decides when to
      redeploy for a run inside one automated invocation where the checkpoint auto-redeploys and
      auto-verifies with no human review in between, which is precisely the automation the
      verification-gap hazard warns is uniquely risky for unverified orchestrator-machinery fixes.
      Frame the flag as a deliberate, per-invocation human-intent escape hatch for the residual
      co-dispatch case, never a general-purpose weakening.
- [x] Rewrite `### Scope Limitation and Residual Risk` (Scope F). Decision to implement: **restate
      the acceptance, do not extend protection.** Give the reasoning specific to this change —
      plain multi-task `/implement N,M`, `/research N,M`, `/plan N,M` have no wave or cycle
      computation at all (no Kahn ordering, no per-cycle eligibility re-evaluation), so there is no
      wave/cycle unit for the narrowed trigger to be counted against; the narrowing therefore does
      NOT transfer to them by analogy, and extending equivalent protection would require
      introducing a wave/cycle concept those commands do not have. Say this explicitly so a future
      reader does not assume the narrowing implicitly covered them.
- [x] Re-read `### The Inter-Cycle Redeploy Checkpoint` and `### Note on Reachability Durability`
      and correct any sentence the narrowing has invalidated.

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` —
  `## Self-Modification Hazard` section (new narrowing/hazard-accounting subsection, A1 resolution,
  hazard 3 breakdown correction, override record), `### Scope Limitation and Residual Risk`.

**Verification**:
- Diff read-through confirming every changed hunk is prose in a context/pattern document with no
  execution surface.
- Grep the whole file for `whole invocation` / `WHOLE INVOCATION`: every surviving hit is either a
  historical/retired-form statement clearly labelled as such, or corrected.
- Every one of the three hazards is named at least once with an explicit live / retired /
  partially-retired status, and no unit of remaining strictness is left without a named hazard
  behind it.
- Cross-reference check: every path this section names resolves to a file that exists.
- No task-number citation introduced (grep the diff for `task [0-9]`); provenance cited by section
  name or file path only.

---

### Phase 9: Schema document — `orchestrate-batch-admit-v3` (Scope G) [COMPLETED]

**Goal**: Bring `docs/architecture/batch-admit-schema.md` to v3, documenting the changed semantics
of a `self_modifying` defer, the consumer-side override, the corrected `--invocation-count`
contract, the accurate reader list, and a Version History entry mirroring the v1-to-v2 reasoning.

**Tasks**:
- [x] Update the Status line and every `$schema` literal in the three JSON examples and the field
      table from `orchestrate-batch-admit-v2` to `orchestrate-batch-admit-v3`.
- [x] Rewrite `## Why --invocation-count Exists`. Its current argument ("the whole point is to keep
      orchestrator-critical work from running alongside ANY sibling, not merely a same-wave one")
      is the exact claim this change reverses. Replace it with the co-dispatch-count contract and
      the reason: an edge-connected pair is structurally unable to co-occupy a wave/cycle, so a
      whole-invocation count fires against pairs that never actually co-occur. Keep and clearly
      label the retained flag NAME rationale from Phase 1.
- [x] Rewrite `## Deferral-Direction Rule and Caller Guidance`'s `self_modifying` bullet: the
      candidate is deferred out of the current wave/cycle, not the whole invocation, and converges
      the same way an `in_batch` collision does. Keep the solo-admit behavior statement (count == 1
      still admits with `self_modifying: true`).
- [x] Rewrite the `## Why --invocation-count Exists` "Convergence requirement on the SKILL.md
      caller" paragraph: the invocation-scoped exclusion set is no longer the convergence
      mechanism. State the new one (re-evaluated every cycle; the defer clears when the
      co-dispatched sibling leaves `eligible_tasks`) and name the bounded no-dispatch guard added
      alongside it.
- [x] Add the consumer-side override to `## Why This Check Is Blocking, Not Advisory`: the check
      remains blocking; `--allow-self-modifying` is a CONSUMER decision to not act on a verdict,
      never a change to this script's output schema, and the script never receives the flag.
- [x] Update the `**Read by**:` list to include `skills/skill-orchestrate-hard/SKILL.md`'s
      `## Multi-Task Mode` section (now accurate after Phase 7), closing the accuracy gap named in
      the task scope.
- [x] Add a `**v3**` Version History entry mirroring the v1-to-v2 entry's reasoning: this is a
      version bump rather than an additive field because the SEMANTIC of a `self_modifying` defer
      changed (permanent whole-invocation exclusion to a converging same-cycle defer); a consumer
      still applying v2's permanent-exclusion handling would over-defer a task the v3 script
      expects to be retried next cycle, silently reintroducing a form of the original
      whole-invocation-exclusion behavior.
- [x] Enumerate every in-repo consumer in the v3 entry and record its status:
      `commands/orchestrate.md` Step 3, `skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5,
      `skills/skill-orchestrate-hard/SKILL.md` `## Multi-Task Mode`,
      `scripts/orchestrate-dry-run-report.sh` Step 4, `scripts/orchestrate-predispatch-review.sh`
      Classes C and D. Record the last two as **verified v3-compatible but not edited** (outside
      this change's declared file scope), with the evidence: neither pins a `$schema` string
      literal and both already branch on `defer_reason`. Record the declared residual — both call
      the script once with their whole candidate set, so under the narrowed semantics their
      exclusion-scope PROSE now over-states the live consequence, which needs a follow-up.

**Timing**: 1.5 hours

**Depends on**: 5, 7

**Verification Tier**: interface

**Scope Hypothesis**: Neither `scripts/orchestrate-dry-run-report.sh` nor
`scripts/orchestrate-predispatch-review.sh` pins the `$schema` string literal, so the v3 bump
cannot break them. Confirm at implementation time with
`grep -n 'orchestrate-batch-admit-v' agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh
agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` — expected zero hits. If a
pin is found, STOP and record it as a scope conflict rather than silently editing an out-of-scope
file.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` — Status line, `Read by`
  list, three JSON examples, `$schema` field-table row, `## Why --invocation-count Exists`,
  `## Deferral-Direction Rule and Caller Guidance`, `## Why This Check Is Blocking, Not Advisory`,
  `## Version History`.

**Verification**:
- `grep -c 'orchestrate-batch-admit-v2'` in this file returns only the count expected inside the
  Version History's historical v1/v2 entries; every live/current reference is v3.
- Repo-wide `grep -rn 'orchestrate-batch-admit-v2' agent-system/` returns only historical Version
  History mentions.
- Each of the three JSON examples is validated with `jq -e .` and its key order matches the order
  the edited script actually emits (compare against Phase 1's scratch-tree smoke-test output).
- The `Read by` list names all five consumers and the two out-of-scope ones are labelled as
  verified-not-edited with their evidence.
- No task-number citation introduced (grep the diff for `task [0-9]`).

---

### Phase 10: Cross-file consistency sweep, deliberate redeploy, final gates [NOT STARTED]

**Goal**: Confirm the eight files are mutually consistent, then perform the single deliberate
redeploy and run the full gate set against the live system. This is the only phase permitted to
write under `.claude/`.

**Tasks**:
- [ ] Consistency sweep across all eight files: the `--invocation-count` argument expression, the
      `--allow-self-modifying` flag spelling, the `allow_self_modifying` delegation-context key,
      and the `orchestrate-batch-admit-v3` schema string must each be spelled identically
      everywhere they appear.
- [ ] Sweep for stale whole-invocation / permanent-exclusion language across all eight files.
- [ ] Confirm the source-store boundary held: `git diff --stat` over every commit for this task
      shows zero `.claude/` paths BEFORE the redeploy step below.
- [ ] Run the no-task-references sweep over every file touched outside `specs/`. Distinguish
      pre-existing hits from newly introduced ones via `git diff`; fix only what this change
      introduced, and record any pre-existing hits without fixing them.
- [ ] `bash -n` on both edited scripts (source-store copies).
- [ ] Re-run the Phase 1 scratch-tree executable smoke test end to end with the final versions of
      the script and the critical-paths JSON, covering: solo self-modifying candidate admits;
      co-dispatched pair defers with `defer_reason: "self_modifying"`; edge-connected pair admits;
      `verify-deploy.sh` in a `file_scope` is detected; degraded critical-paths file yields
      `self_modifying: null` on every verdict and a loud stderr warning.
- [ ] Perform ONE deliberate redeploy: `bash .claude/scripts/deploy-headless.sh`, then
      `bash .claude/scripts/verify-deploy.sh`. Log it explicitly as a conscious, one-time
      invocation matching this plan's Rollback/Contingency — not a routine practice.
- [ ] After redeploy: `bash .claude/scripts/check-extension-docs.sh` must exit 0 (it is EXPECTED to
      FAIL on source/deploy drift for every prior phase; only here is a PASS required).
- [ ] After redeploy: `bash -n` on both deployed script copies.
- [ ] `bash .claude/scripts/validate-artifact.sh` against this plan file: PASS.

**Timing**: 1 hour

**Depends on**: 6, 8, 9

**Verification Tier**: full

**Scope Hypothesis**: `check-extension-docs.sh` will report exactly as many drift issues as there
are edited script/doc files until the redeploy, and zero after. Confirm the pre-redeploy count
matches the edited-file count; an unexplained extra issue means something outside this change's
scope drifted and must be investigated, not absorbed.

**Files to modify**:
- None in the source store. The redeploy writes `.claude/**` as a deploy artifact by design, which
  is the sanctioned exception to the source-store rule.

**Verification**:
- All eight declared source-store files confirmed present and modified.
- Zero `.claude/` paths in any pre-redeploy commit for this task.
- `verify-deploy.sh` exit code recorded and compared against the pre-change baseline (a
  pre-existing non-zero baseline is not a regression; a NEW non-zero is).
- `check-extension-docs.sh` exits 0.
- The three post-redeploy behavioral traces from Phase 5 are re-read against the DEPLOYED skill
  file to confirm the transcription survived the sync intact.

---

## Testing & Validation

- [ ] `bash -n` clean on `orchestrate-batch-admit.sh` and `parse-command-args.sh`, in both
      source-store and post-redeploy deployed form.
- [ ] `--allow-self-modifying` leak test: `FOCUS_PROMPT` carries zero flag residue; default is
      `false`; no false positive from `--local` / `--lit` / `--force` / `--fast`.
- [ ] Scratch-tree executable smoke test of the admission script covering solo-admit, co-dispatch
      defer, edge-connected admit, new critical-path detection, and the degraded-data-file path.
- [ ] Every emitted verdict carries `"$schema":"orchestrate-batch-admit-v3"`.
- [ ] `jq -e .` passes on `orchestrator-critical-paths.json` and on all three schema-doc examples.
- [ ] Zero occurrences of `deferred_self_modifying` remain in an eligibility, all-terminal, or
      circuit-breaker condition; `deferred_deploy_checkpoint` occurrences are unchanged.
- [ ] `grep 'orchestrate-batch-admit'` in `skill-orchestrate-hard/SKILL.md` returns at least one
      hit (Scope D gap closed).
- [ ] Zero `EVERY wave` occurrences in `commands/orchestrate.md` Step 3 (Scope E closed).
- [ ] Repo-wide `grep -rn 'orchestrate-batch-admit-v2' agent-system/` returns only historical
      Version History mentions.
- [ ] No newly introduced task-number citations outside `specs/**`.
- [ ] Zero `.claude/` modifications in any commit before Phase 10's deliberate redeploy.
- [ ] `check-extension-docs.sh` exits 0 after redeploy; `validate-artifact.sh` PASSes on this plan.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` (v3 schema, rewritten contract
  header, A1 resolution note)
- `agent-system/extensions/core/scripts/parse-command-args.sh` (`--allow-self-modifying`)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (narrowed trigger and
  consequence, override branch, convergence guard)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (transcribed Multi-Task
  Mode gate and checkpoint)
- `agent-system/extensions/core/commands/orchestrate.md` (Scope E prose, narrowed count, override
  option and threading)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (hazard
  accounting, A1, override rationale, Scope F restatement, Scope C tables)
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` (tenth entry)
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` (v3)
- `specs/935_narrow_self_modifying_defer_and_override_flag/summaries/01_narrow-self-mod-defer-override-flag-summary.md`

## Rollback/Contingency

The live system is unaffected until Phase 10, because `.claude/` is not written before then and the
in-flight session executes only its pre-change deployed copies. Consequences by stage:

- **Abort before Phase 10**: revert the task's commits with `git revert`. No redeploy is needed —
  the deploy tree never diverged behaviorally, and the next routine `<leader>al` sync restores
  coherence.
- **Phase 10 redeploy or verify fails**: `verify-deploy.sh` exit 2 is a FAILURE, never a pass.
  Revert the task's source-store commits, re-run `deploy-headless.sh` to restore the pre-change
  deploy tree, and re-run `verify-deploy.sh` to confirm the baseline exit code is restored.
- **Behavioral regression discovered after landing**: the narrowing can be reverted independently
  of the override flag by restoring the two `--invocation-count` arguments and the
  `deferred_self_modifying` eligibility exclusion; the flag, the critical-path addition, the
  hard-mode transcription, and the prose fixes are all safe to keep.
- **Never** resolve a mid-run inconsistency by redeploying early. A partial redeploy is exactly the
  mid-invocation script-swap exposure this task's dependency chain named and contained.

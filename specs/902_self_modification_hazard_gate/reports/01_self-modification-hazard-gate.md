# Research Report: Task #902

**Task**: 902 - Flag tasks that modify orchestrator machinery and force them to run alone
**Started**: 2026-07-25T00:00:00Z
**Completed**: 2026-07-25T00:00:00Z
**Effort**: Medium (one data file + a small verdict extension to an existing script + report/doc wiring; the hard part is the analysis, not the code volume)
**Dependencies**: 901 (dry-run admission report surface, `orchestrate-triage-classify.sh`, `orchestrate-dry-run-report.sh` — completed), 899 (guardrails context pattern where the rationale is recorded)
**Sources/Inputs**:
- Codebase: `scripts/orchestrate-batch-admit.sh`, `scripts/orchestrate-dry-run-report.sh`, `scripts/orchestrate-triage-classify.sh`, `commands/orchestrate.md`, `skills/skill-orchestrate/SKILL.md`, `skills/skill-orchestrate-hard/SKILL.md`, `scripts/skill-base.sh`, `scripts/task-lock.sh`, `scripts/update-task-status.sh`, `scripts/orchestrator-postflight.sh`, `scripts/command-gate-in.sh`, `scripts/command-gate-out.sh`, `scripts/parse-command-args.sh`, `context/patterns/batch-orchestration-guardrails.md`, `context/patterns/regeneration-is-manual-only.md`, `context/patterns/multi-task-operations.md`, task 901's report/summary
- WebSearch: self-hosting/bootstrap-compiler and CI/CD self-repair-agent practice, package-manager staged self-upgrade (npm staged publishing), current as of July 2026
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The headline finding changes the whole shape of the problem**: because `.claude/` is a
  gitignored, disposable deploy artifact regenerated ONLY by an interactive, human-driven
  `<leader>al` action with no headless/CI equivalent (`context/patterns/regeneration-is-manual-only.md`),
  and every core script structurally refuses to run from anywhere except a deployed `.claude/` or
  `.opencode/` tree (`deploy-root-guard.sh`'s two-grandparent check), **a source-store edit to
  ANY `agent-system/extensions/core/**` file has zero live effect on the currently-executing
  `/orchestrate` session, for any candidate file on the task's list, full stop.** The naive
  framing — "a known-defective orchestrator supervises its own live repair" — does not literally
  occur here. This does not make the gate pointless; it changes what it is actually protecting
  against (see Findings > "What Hazard Actually Survives the Deploy-Manual Invariant").
- **A second, independently load-bearing finding narrows the candidate list itself**: multi-task
  `/orchestrate` dispatch (Stage MT-1 through MT-5 in `skill-orchestrate/SKILL.md`, and the
  MULTI-TASK DISPATCH section of `commands/orchestrate.md`) is the ONLY mode in which "siblings
  in the same pass" exist at all — a single-task invocation has no siblings to endanger, so the
  solo-only gate is meaningless outside MT mode. Two of the task's own candidates —
  `command-gate-in.sh`/`command-gate-out.sh` — are **explicitly and provably bypassed** in MT
  mode (`skill-orchestrate/SKILL.md`'s own text: "Multi-task dispatch bypasses the single-task
  gate scripts entirely... they are never sourced here"). A third candidate,
  `scripts/orchestrator-postflight.sh`, is **never referenced anywhere in `skill-orchestrate/SKILL.md`
  at all** (confirmed by grep) — MT-4 does its own inline, lighter per-task postflight
  (`skill_postflight_update` + `skill_link_artifacts` from `skill-base.sh`) and single-task mode
  dispatches via the Agent tool directly too, never via the Skill tool to
  skill-researcher/planner/implementer (the only callers `orchestrator-postflight.sh`'s own
  header names). All three of these candidates are excluded from the recommended critical set —
  not because they are unimportant, but because a defect in them cannot reach a second task in
  the same `/orchestrate` invocation, which is the specific harm this gate exists to stop.
- **Recommended critical set** (both a reachability test — read/executed by MT-mode batch
  dispatch — and a decision-relevance test — a defect here produces a *silent wrong* admission,
  wave, lock, or completion decision, not a loud/cosmetic one): `skills/skill-orchestrate/SKILL.md`,
  `skills/skill-orchestrate-hard/SKILL.md`, `commands/orchestrate.md`, `scripts/skill-base.sh`,
  `scripts/task-lock.sh`, `scripts/update-task-status.sh`, `scripts/orchestrate-batch-admit.sh`,
  `scripts/orchestrate-triage-classify.sh`, `scripts/orchestrate-dry-run-report.sh`. Excluded:
  `scripts/command-gate-in.sh`, `scripts/command-gate-out.sh`, `scripts/orchestrator-postflight.sh`
  (unreachable from MT dispatch), and mechanical-rendering files reachable from MT dispatch but
  not decision-relevant (`generate-todo.sh`, `validate-artifact.sh`, `lifecycle-notify.sh`).
- **A real, concrete illustration already exists in this repository's own history**: the commit
  trail shows a batch spanning this very task alongside five siblings run through one
  `/orchestrate` invocation (4 of 6 succeeded) — i.e., this self-modifying task was, in fact,
  already dispatched inside a multi-task batch before this gate existed. That is the exact
  scenario the task's MOTIVATION section describes, not a hypothetical.
- **Design recommendation**: declare the critical set as one JSON data file (path prefixes,
  matched with the SAME directory-prefix-overlap test `file-footprint-overlap.md` already
  defines), consumed by `orchestrate-batch-admit.sh` to add a `self_modifying` verdict dimension
  and a new solo-only defer reason; **the self-modifying candidate itself is the one deferred**
  (excluded from this invocation) whenever the invocation's total candidate count is greater than
  one — never its siblings, and never a hard failure. `orchestrate-dry-run-report.sh` and
  `commands/orchestrate.md` surface the flag with a plain-language reason; the rationale (why
  these nine files, why not the other three, and the deploy-manual analysis) goes in
  `batch-orchestration-guardrails.md`.
- **Explicit scope limitation, stated rather than hidden**: this gate protects `/orchestrate`
  only. Plain multi-task `/implement N,M`, `/research N,M`, `/plan N,M` invocations (which the
  Command Reference table separately supports) dispatch through `skill-implementer`/
  `skill-researcher`/`skill-planner` directly and never call `orchestrate-batch-admit.sh` at all
  — a self-modifying task batched that way is not covered by this gate. This is a genuine residual
  risk, consistent with the task's own file_scope (which does not touch those skills), and is
  flagged here for a future task rather than silently absorbed into this one's scope.

## Context & Scope

Task 902 extends the `/orchestrate` admission analysis (already built by tasks 900-901:
`orchestrate-batch-admit.sh`'s cross-batch file_scope collision predicate,
`orchestrate-triage-classify.sh`'s handoff-triage classifier, and `orchestrate-dry-run-report.sh`'s
read-only preview surface) with a new dimension: a candidate task whose `file_scope` touches a
defined set of orchestrator-critical paths must be flagged `self_modifying` and, whenever it is
batched alongside any sibling in the same `/orchestrate` invocation, deferred out of that
invocation (not failed) so it only ever runs solo. This report focuses on: (1) whether the
deploy-artifact model changes the live-hazard analysis at all, (2) which of the task's nine
candidate files actually execute during a live multi-task `/orchestrate` dispatch and should
therefore be in the critical set, (3) how the critical set should be declared as data in one
place, (4) what the solo-only deferral mechanism should look like precisely, and (5) external
practice on self-modifying/self-hosting automation as of July 2026 and how it does or does not
translate to this system's manual-only redeploy model.

## Findings

### What Hazard Actually Survives the Deploy-Manual Invariant

`context/patterns/regeneration-is-manual-only.md` states plainly: the `<leader>al` picker is the
ONLY mechanism that deploys `agent-system/extensions/**` into `.claude/`; its actual sync closure
(`execute_sync`) is not exported and is gated behind an unconditional, blocking
`vim.fn.confirm()` with no headless/flag bypass; "no task, script, or CI job may assume a deploy
has happened as a side effect of source-store edits." Independently, every core script (including
`orchestrate-batch-admit.sh`, `orchestrate-dry-run-report.sh`, `orchestrate-triage-classify.sh`,
`task-lock.sh`, all of them) resolves its repo root via `deploy-root-guard.sh`, which validates
`BASH_SOURCE[0]`'s own location structurally against exactly two accepted deploy-tree
grandparents (`.claude`, `.opencode`) and refuses to run otherwise — so these scripts cannot even
execute from inside the source store, let alone be invoked live from there.

Put together: **a candidate task's implementation, editing
`agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` (say), cannot alter the
behavior of the `.claude/scripts/orchestrate-batch-admit.sh` copy the CURRENTLY RUNNING
orchestrator session is calling, for the remainder of that session, under any circumstance short
of a human interactively choosing "Sync all" mid-run** — which is not a thing any agent or
automation in this system can trigger. This holds for every one of the task's nine candidates,
without exception; the deploy-manual invariant does not "partially" reduce the hazard for some
paths and not others — it removes the *live-corruption* mechanism entirely, for all of them.

This does not mean the gate is pointless — it means the actual harm the gate should be argued
against is a different, real set of risks that DO survive the deploy-manual model:

1. **Verification-gap risk.** Per task 901's implementation summary, the new scripts' own tests
   use a "scratch-deploy-tree pattern" (`mktemp -d` copies) — meaning an orchestrator-critical
   fix is verified against a COPY, never against the live `.claude/` tree it will eventually
   replace. The only thing that proves the fix actually works in place is a human manually
   redeploying and then real subsequent `/orchestrate` runs "in the wild" — exactly the two-gate
   verification model `regeneration-is-manual-only.md` already names ("manual regeneration, then
   accumulated real usage over time; neither gate can be satisfied by inspecting source-store code
   alone"). Bundling that residual, unverified risk into a large multi-task batch and a single
   consolidated output table is precisely the "green means nothing broke syntactically, not that
   it's right" failure mode task 901's own web research already surfaced for this codebase's
   `--dry-run` report design.
2. **Rollback/commit-granularity risk.** The multi-task batch git commit
   (`commands/orchestrate.md` Step 5) stages `specs/TODO.md`, `specs/state.json`, and every
   batch task's `specs/` directory into ONE commit; `orchestrator-postflight.sh`'s Stage 9b
   "also_carries" scan exists specifically because this codebase already recognizes that a commit
   mixing multiple tasks' index rows is harder to attribute and revert cleanly than one task per
   commit. An orchestrator-critical fix is exactly the kind of change a human is most likely to
   need to cleanly revert if post-redeploy behavior goes wrong; bundling it with N unrelated
   siblings' commits inherits that same ambiguity at the worst possible moment.
3. **A genuinely live, in-session risk, but not the naive one**: multi-task dispatch (MT-4) never
   calls `orchestrator-postflight.sh` — its own per-task postflight is `skill_postflight_update` +
   `skill_link_artifacts` (from `skill-base.sh`), and NEITHER of those, nor
   `commands/orchestrate.md`'s Step 5 batch commit (which stages only `specs/**` paths), ever
   stages or commits an implementation agent's self-reported `modified_files` list. Only the
   single-task path's `orchestrator-postflight.sh` (Stage 9) does that. This means a self-modifying
   task's ACTUAL source-store edits, when dispatched inside a multi-task `/orchestrate` batch, are
   likely to be left **uncommitted in the working tree** while later waves/cycles of the SAME
   invocation continue running sibling tasks — a real, structural gap (see Risks below), though
   fixing the batch-commit staging path itself is out of this task's file_scope.
4. **The self-hosting/bootstrapping angle the task's own research directive names directly**: the
   admission script this task extends is, itself, one of the files in the critical set (task 902's
   own `file_scope` includes `orchestrate-batch-admit.sh`). This is the same shape as a compiler
   that compiles itself — the running orchestrator's admission decision for THIS task is made by
   the OLD (deployed) copy of the very script this task is rewriting, and the NEW copy only governs
   admission decisions for tasks dispatched AFTER a human redeploys. The deploy-manual model
   happens to make this safe in the naive sense (no live self-alteration), but the "propose, then
   an independent human gate makes it live" shape is exactly the staged/bootstrap pattern current
   package-manager and self-hosting-compiler practice already converges on (see External Resources).

### Codebase Patterns: Reachability and Decision-Relevance, File by File

Two tests, applied together, are the actual argument structure requested by the task
("argue each inclusion from what actually executes DURING a live orchestration run... a file that
only affects future runs is a weaker case than one read or executed mid-dispatch"):

- **Reachability**: is the file read or executed by the MULTI-TASK batch-dispatch code path
  (`skill-orchestrate/SKILL.md` Stage MT-1 through MT-5, `skill-orchestrate-hard/SKILL.md`'s
  equivalent, and `commands/orchestrate.md`'s MULTI-TASK DISPATCH section) — the only mode in
  which "siblings in the same pass" exist? A file unreachable from MT dispatch cannot, by
  construction, let a defect in it touch a second task in the same invocation, regardless of how
  "orchestrator-sounding" its name is.
- **Decision-relevance**: among reachable files, does a defect produce a *silent wrong* decision
  (admission, wave placement, lock/concurrency safety, or completion status) as opposed to a
  loud/cosmetic failure (TODO.md rendering, artifact lint format)? This is the same
  blocking-vs-advisory-flavored test `batch-orchestration-guardrails.md` already uses for whether
  a check should gate at all.

**Included** (both tests pass):

| File | Reachability evidence | Decision-relevance |
|---|---|---|
| `skills/skill-orchestrate/SKILL.md` | Stage MT-1 through MT-5 (wave loop, per-task dispatch, per-task postflight, triage classifier call) are literally in this file and re-consulted every cycle of the same invocation | Directly IS the dispatch/triage/admission orchestration logic |
| `skills/skill-orchestrate-hard/SKILL.md` | Stage 0 detects `multi_task_mode` and routes; its own text says hard-mode's per-phase H1/H4/H5/H6/H7 contracts "apply to each individual task in the wave" — i.e. layered on top of, not replacing, base MT-1..MT-5 | Churn detection (H6), territory contracts (H7), and the completion-claim gate apply per-task inside an MT wave under `--hard` |
| `commands/orchestrate.md` | MULTI-TASK DISPATCH Steps 1-5 (batch validation, dependency graph, Kahn's-algorithm waves, the runtime `orchestrate-batch-admit.sh` call, the batch git commit) are literally in this file, read at STAGE 0 of every invocation | Directly IS the wave/admission/commit logic |
| `scripts/skill-base.sh` | MT-4 calls `skill_preflight_update`/`skill_postflight_update`/`skill_link_artifacts` inline, by name, in its own bash blocks, once per dispatched task per cycle | Contains `skill_gate_completion_claim` (the completion-claim verification gate — directly decides whether a batch task is falsely marked complete) and `skill_write_orchestrator_handoff` (the handoff writer MT-4's triage reads back) |
| `scripts/task-lock.sh` | MT-4 calls `acquire`/`release` directly by name, once per dispatched task per cycle; also the mechanism `orchestrate-dry-run-report.sh`'s `check` calls read | One of the three existing admission layers per `batch-orchestration-guardrails.md`; a defect here can produce false refusals or false double-admissions across the WHOLE batch, not just one task |
| `scripts/update-task-status.sh` | Called transitively by `skill_preflight_update`/`skill_postflight_update`, which MT-4 calls inline per task per cycle | Canonical state.json status-transition gatekeeper, including the `--phase-check=refuse` completion backstop |
| `scripts/orchestrate-batch-admit.sh` | Called once per wave by `commands/orchestrate.md` Step 3/4 and once per cycle's eligible set implicitly via the dry-run report's identical call shape | IS the file_scope-collision admission predicate this task extends |
| `scripts/orchestrate-triage-classify.sh` | Called once per cycle by MT-4 ("before grouping, call the shared handoff-triage classifier") | IS the phase-routing decision (research/plan/implement/needs_human/skip) for every eligible task in the batch |
| `scripts/orchestrate-dry-run-report.sh` | Not itself part of the live dispatch path, but is the ONLY place the flag this task adds becomes human-visible, and shares "one code path, two consumers" with the live admission scripts above | Its own header states it "cannot silently drift from live behavior" precisely because it composes the same primitives — the self-mod flag must be added here symmetrically with the live path or the report will lie |

**Excluded** (fail the reachability test, despite being explicitly named as candidates to evaluate):

| File | Why it fails reachability |
|---|---|
| `scripts/command-gate-in.sh` | `skill-orchestrate/SKILL.md`'s own text: "Multi-task dispatch bypasses the single-task gate scripts entirely (`command-gate-in.sh`/`command-gate-out.sh` are never sourced here)". A single-task invocation has no siblings in the same pass to endanger in the first place — the solo-only concept is a no-op there regardless of this file's correctness. |
| `scripts/command-gate-out.sh` | Same citation as above; additionally only ever invoked once per single-task command, never inside the MT-4 wave loop. |
| `scripts/orchestrator-postflight.sh` | Zero references anywhere in `skill-orchestrate/SKILL.md` (confirmed by grep across the full file) — its own header names its only callers as `skill-researcher/SKILL.md`, `skill-planner/SKILL.md`, `skill-implementer/SKILL.md`, none of which MT-4 or single-task Stage 4 invoke (both dispatch via the Agent tool directly to `research_agents[task_num]`/`planner-agent`/`implement_agents[task_num]`, never via the Skill tool to those three skills). |

Also excluded, deliberately, despite being technically reachable from MT-4 (`skill_link_artifacts`
calls `generate-todo.sh` internally): `generate-todo.sh`, `validate-artifact.sh`,
`lifecycle-notify.sh`. These fail the decision-relevance test — a defect here produces a
wrong-*looking* TODO.md, a lint warning, or a missed notification, none of which is a silent wrong
admission/dispatch/completion decision the way a `task-lock.sh` or
`orchestrate-triage-classify.sh` defect would be. Naming this exclusion explicitly is itself part
of the argument against over-inclusion the task warns about: the critical set is not "everything
`grep`-reachable from MT-4," it is "everything reachable AND decision-relevant."

### Concrete Precedent in This Repository's Own History

The commit trail already contains `orchestrate tasks 896-902: complete orchestration (4/6
succeeded)` — a real multi-task `/orchestrate` invocation whose batch included this very task
(902, this self-modification-hazard-gate task, whose own `file_scope` touches
`orchestrate-batch-admit.sh`, `commands/orchestrate.md`, and
`batch-orchestration-guardrails.md`) alongside five siblings, before this gate existed to catch
it. This is not a hypothetical scenario invented for this report — it is the literal situation the
task's MOTIVATION section describes, already realized once in this repository.

### Solo-Only Semantics: What Gets Deferred, and Against What Count

The task's design constraint — "a self-modifying task is deferred out of a multi-task batch, not
failed" — resolves an ambiguity that would otherwise need a design decision: it is **the
self-modifying candidate itself** that is excluded from the invocation (not its siblings). This is
the minimal-blast-radius reading and the only one consistent with the existing defer-not-fail
precedent, where the LOWER-PRIORITY / conflicting party is always the one that yields, never an
inversion where one task holds an entire unrelated batch hostage.

The self-modifying check is a pure, single-candidate predicate — no comparison against other
tasks' `file_scope` is needed (unlike the existing collision check), only a comparison of the
candidate's OWN `file_scope` entries against the critical-path data file, using the identical
directory-prefix-overlap test `file-footprint-overlap.md` already defines (exact match, or either
side a `/`-terminated prefix of the other) — reused, not reinvented, exactly as
`orchestrate-batch-admit.sh`'s own `scopes_overlap_first` already transcribes that same algorithm
for a different "foreign list."

**The deferral trigger must be evaluated against the INVOCATION's total validated candidate
count, not the current wave's subset count.** A self-modifying task in Wave 0 and an unrelated
task in Wave 1 (no direct file_scope overlap, hence no existing collision-based defer) are still
"in the same pass" per the motivating hazard, even though they never share a wave. Scoping the
solo-only check to "this wave has 2+ tasks" would under-fire; it must be "this invocation's
`validated_tasks` count is greater than 1," checked once, early (alongside Step 1 Batch Validation
in `commands/orchestrate.md` and the equivalent early step in `orchestrate-dry-run-report.sh`),
independent of wave computation.

### Declaring the Critical Set as Data, in One Place

The design constraint requires the set to be data, not a condition duplicated across call sites,
and there are at least two consumers that need it: `orchestrate-batch-admit.sh` (the actual
solo-only decision) and `orchestrate-dry-run-report.sh` (the human-visible reason string). A
single new JSON data file — e.g. `context/reference/orchestrator-critical-paths.json` — holding
an array of path prefixes relative to `agent-system/extensions/core/` (the SAME base the task's
own `file_scope` entries are already expressed against — confirmed from this task's own
`state.json` entry) is the natural fit: both scripts `jq`/`--slurpfile` load it directly, and
`batch-orchestration-guardrails.md` cross-references it by path for the prose rationale, exactly
mirroring how that document already treats `file-footprint-overlap.md` as the single algorithm
source multiple consumers point back to rather than restate.

### External Resources (current as of July 2026)

- **Self-hosting/bootstrap compiler analogy**: the classic "reflection on trusting trust" shape —
  a system that builds/repairs itself is only as trustworthy as the version of itself doing the
  building — is the direct analogue of task 902's own `orchestrate-batch-admit.sh` deciding
  whether task 902 gets admitted using the OLD (pre-fix) copy of that same script. Current
  literature on bootstrapped/trusted-oversight framing for AI agents converges on the same
  resolution this system already has by accident of its deploy-manual design: insert an
  independent gate (here, a human's interactive redeploy decision) between "the fix is proposed"
  and "the fix is authoritative," rather than trusting the self-referential system to certify its
  own change live. ("No orchestration framework can certify its own inputs — that responsibility
  belongs to [an external] layer," per current zero-trust multi-agent governance framing.)
- **CI/CD self-repair-agent pattern (2026)**: the emerging "Pipeline Doctor"/"Interceptor" pattern
  — a specialized repair agent that reads failure logs and commits a fix back to the branch — is
  explicitly described in current practice as producing "a fix commit from the agent" that still
  goes through the SAME review/merge gate as any other change, not a live in-place patch of the
  running pipeline. This matches this task's rollback-granularity argument: even fully autonomous
  self-repair proposals are staged as ordinary, separately-reviewable commits, not applied
  in-flight to the process doing the repairing.
- **Package-manager self-upgrade / staged publishing (npm, May 2026)**: npm's staged-publishing
  feature (CLI 11.15.0) is a close structural analogue to this system's deploy-manual model —
  `npm publish` makes a package live immediately, while `npm stage publish` places it in a holding
  queue that requires a separate, human, 2FA-gated approval before it becomes installable; CI can
  submit to the stage non-interactively, but the "proof of presence" gate is always a human action
  at promotion time, never automatic. This is materially the same two-phase shape as "an agent
  commits a source-store fix" (stage) followed by "a human interactively runs `<leader>al` and
  chooses Sync all" (promote) — reinforcing that the deploy-manual model is not an accident to
  route around but an already-correct instance of the staged-rollout discipline current
  package-management practice is independently converging on.
- **Canary/staged rollout general principle**: current CI/CD and mobile-release guidance (Play
  Console staged rollouts, Microsoft Configuration Manager's Early Update Ring) continues to
  emphasize isolating a self-affecting or infrastructure-affecting change from unrelated payload
  changes specifically so that a problem discovered post-rollout can be attributed and rolled back
  without also reverting unrelated work — the same rollback-granularity argument this report makes
  independently from the codebase's own `git-staging-scope.md`/Stage 9b precedent.

Sources:
- [Teaching Your CI to Fix Itself](https://medium.com/codetodeploy/teaching-your-ci-to-fix-itself-99b33d41338f)
- [Building Self-Healing CI/CD Pipelines for Agentic AI Systems](https://optimumpartners.com/insight/how-to-architect-self-healing-ci/cd-for-agentic-ai/)
- [Zero-Trust AI Governance for Multi-Agent Systems | CSA](https://cloudsecurityalliance.org/blog/2026/06/24/securing-the-swarm-governance-attack-surfaces-and-zero-trust-architectures-in-multi-agent-ai-environments)
- [Bootstrapped Monitoring: Leveraging Transparent Reasoning to Oversee Stronger AI Agents](https://arxiv.org/pdf/2606.11998)
- [Staged publishing and new install-time controls for npm - GitHub Changelog](https://github.blog/changelog/2026-05-22-staged-publishing-and-new-install-time-controls-for-npm/)
- [npm to Implement Staged Publishing After Turbulent Shift Off...](https://socket.dev/blog/npm-to-implement-staged-publishing)
- [Release app updates with staged rollouts - Play Console Help](https://support.google.com/googleplay/android-developer/answer/6346149?hl=en)

## Decisions

- The critical set is scoped to files reachable from MULTI-TASK `/orchestrate` batch dispatch
  AND decision-relevant (silent-wrong-decision potential), excluding
  `command-gate-in.sh`/`command-gate-out.sh` (never sourced in MT mode) and
  `orchestrator-postflight.sh` (never called by `skill-orchestrate/SKILL.md` at all, in either
  single- or multi-task mode).
- The self-modifying predicate is a pure, single-candidate check (own `file_scope` vs. the
  critical-path data file), reusing `file-footprint-overlap.md`'s exact-match-or-prefix test —
  no new overlap algorithm.
- The solo-only rule defers THE SELF-MODIFYING CANDIDATE (never its siblings) whenever the
  invocation's total validated candidate count exceeds one, evaluated once against that whole-
  invocation count (not per-wave), consistent with defer-not-fail.
- The critical set is declared once as a JSON data file (path prefixes relative to
  `agent-system/extensions/core/`), consumed by `orchestrate-batch-admit.sh` and
  `orchestrate-dry-run-report.sh`; the WHY (rationale per file, and the deploy-manual analysis
  above) is recorded in `batch-orchestration-guardrails.md`, not duplicated as comments in the
  data file itself.
- The gate's scope is explicitly `/orchestrate` only; plain multi-task `/implement`/`/research`/
  `/plan` invocations are not covered and this is stated as a known limitation, not silently
  absorbed.

## Risks & Mitigations

- **Risk**: multi-task `/orchestrate`'s batch commit path (`commands/orchestrate.md` Step 5)
  stages only `specs/**` paths and never an implementation agent's self-reported `modified_files`
  — meaning a self-modifying task's actual `agent-system/**` edits may be left uncommitted in the
  working tree while later waves of the SAME invocation continue running. **Mitigation**: this
  report flags it for a follow-up task (out of this task's `file_scope`); in the meantime, the
  solo-only gate this task adds at least ensures a self-modifying task's edits are never dispatched
  alongside concurrently-running siblings in the SAME cycle, narrowing (without eliminating) the
  window this uncommitted-tree risk could matter in.
- **Risk**: a future maintainer, seeing "orchestrator-postflight.sh" and "command-gate-*.sh"
  excluded, might assume the exclusion was an oversight rather than a deliberate, evidence-based
  call. **Mitigation**: `batch-orchestration-guardrails.md`'s new section must state the exclusion
  rationale as prominently as the inclusions, with the exact grep/citation evidence above, so a
  later reader can verify rather than re-litigate from scratch.
- **Risk**: over-fitting the critical set to today's dispatch mechanics — if a future change
  routes MT-mode dispatch through the Skill tool (calling skill-researcher/planner/implementer,
  and therefore `orchestrator-postflight.sh`) instead of the Agent tool directly, the reachability
  argument for excluding `orchestrator-postflight.sh` would flip. **Mitigation**: state the
  reachability test itself (not just its current-day conclusion) in
  `batch-orchestration-guardrails.md`, so a future maintainer re-derives the exclusion/inclusion
  from the test rather than treating today's list as permanently fixed.
- **Risk**: the solo-only check, if implemented as a full-batch-count test evaluated only once at
  Step 1, could miss a self-modifying task added to `validated_tasks` for a resumed/continued
  invocation. **Mitigation**: evaluate the check every time `orchestrate-batch-admit.sh` or the
  dry-run script is invoked (it already is, per-wave and per-invocation respectively) rather than
  caching the invocation-level candidate count anywhere.

## Context Extension Recommendations

- **Topic**: multi-task `/orchestrate` batch commit does not stage implementation agents'
  self-reported `modified_files`. **Gap**: `commands/orchestrate.md` Step 5's "Batch Git Commit"
  stages only `specs/TODO.md`, `specs/state.json`, and each task's `specs/` directory — unlike the
  single-task path's `orchestrator-postflight.sh` Stage 9, which explicitly reads and stages
  `modified_files` from `.return-meta.json`. **Recommendation**: a follow-up task should extend
  Step 5 (or MT-4's per-task postflight) to collect and stage each dispatched task's
  `modified_files` the same way the single-task path already does, closing a real (if narrow)
  uncommitted-working-tree gap independent of this task's self-modification-hazard gate.

## Appendix

### Search Queries Used
- "2026 self-hosting compiler bootstrap staged build \"does not deploy its own fix\" self-upgrade CI/CD canary autonomous agent"
- "package manager self-upgrade staged rollout 2026 \"never bundle\" self-update with other changes blast radius"
- "AI agent self-modifying its own orchestration harness safety 2026 \"reflection on trusting trust\" bootstrapping risk isolate change"
- "npm self-update npm-cli release process separate from other package publishes staged rollout rollback isolation 2026"

### Key Files Referenced (agent-system/extensions/core/ — the source store; .claude/ is the
disposable deploy artifact and is never edited directly)
- `scripts/orchestrate-batch-admit.sh`, `scripts/orchestrate-dry-run-report.sh`,
  `scripts/orchestrate-triage-classify.sh`
- `commands/orchestrate.md` (MULTI-TASK DISPATCH Steps 1-5, STAGE 0 dry-run short-circuit)
- `skills/skill-orchestrate/SKILL.md` (Stage MT-1 through MT-5; confirmed zero references to
  `orchestrator-postflight.sh` or `command-gate-in.sh`/`command-gate-out.sh` anywhere in the file)
- `skills/skill-orchestrate-hard/SKILL.md` (Stage 0 Multi-Task Mode Detection; "Multi-Task Mode"
  section: "Same as base skill-orchestrate multi-task stages (MT-1 through MT-5)")
- `scripts/skill-base.sh` (`skill_preflight_update`, `skill_postflight_update`,
  `skill_link_artifacts`, `skill_gate_completion_claim`, `skill_write_orchestrator_handoff`)
- `scripts/task-lock.sh`, `scripts/update-task-status.sh`, `scripts/command-gate-in.sh`,
  `scripts/command-gate-out.sh`, `scripts/orchestrator-postflight.sh`, `scripts/parse-command-args.sh`
- `context/patterns/batch-orchestration-guardrails.md`, `context/patterns/regeneration-is-manual-only.md`,
  `context/patterns/multi-task-operations.md` (File Footprint Overlap as a Serialization Edge
  section; confirms the runtime wave-split check is `/orchestrate`-specific and not shared with
  plain multi-task `/implement`/`/research`/`/plan`)
- task 901's report/summary (`specs/901_orchestrate_dry_run_admission_report/`) for the two new
  scripts' schemas and the "one code path, two consumers" precedent this task extends

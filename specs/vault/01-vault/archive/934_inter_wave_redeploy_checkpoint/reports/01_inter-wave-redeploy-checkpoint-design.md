# Research Report: Task #934

**Task**: 934 - Inter-wave redeploy checkpoint via the existing headless deploy path
**Started**: 2026-07-28T00:00:00Z
**Completed**: 2026-07-28T00:00:00Z
**Effort**: medium (single design-focused research pass; no code written)
**Dependencies**: 932 (completed), 933 (completed), 936 (completed) — all three closed, confirmed
  live in `specs/state.json`
**Sources/Inputs**: Codebase read (source-store files only, per the SOURCE-STORE RULE), no web
  search needed — this is a self-contained design question over already-verified machinery.
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The three dependency tasks (commit-per-wave staging, pre-dispatch review, Stage 8
  `.return-meta.json` clobber fix) are all completed, so the commit-granularity precondition this
  task's own description leans on (Scope item C) already holds: `skill-orchestrate/SKILL.md`
  Stage MT-4 step 5.5 now issues one scoped commit per task per phase transition, inside the
  per-task postflight loop, before the loop advances to the next cycle. A redeploy checkpoint
  slotted in immediately after step 5.5 (or as a new step 7, after step 6's cycle-count
  increment) therefore naturally satisfies "commit before redeploy" with no additional
  sequencing work — the ordering falls out of already-shipped machinery rather than needing new
  coordination.
- The self-modification admission gate (Stage MT-3 step 4.5 / `orchestrate.md` Step 3) already
  fully **excludes** a self-modifying candidate from the entire invocation (not merely defers it
  to a later wave) when its declared `file_scope` matches one of the nine
  `orchestrator-critical-paths.json` entries. This means the hazard-3 scenario as literally
  phrased ("W0 fixes the predicate, W1 still runs stale") cannot occur *via a correctly-declared
  self-modifying task* inside one multi-task batch today — that task never dispatches in-batch at
  all; the operator is told to re-run it solo. The hazard survives in two more precise forms this
  report separates out (see Findings): (a) a task whose *actual* `modified_files` touch a
  critical path while its *declared* `file_scope` does not (an under-declaration the
  self-modifying gate cannot see, since it only reads `file_scope`), and (b) the general
  cross-invocation case — a solo fix lands and commits, but nothing redeploys it, so the *next*
  invocation (batch or solo) still runs the stale deployed copy. Both are real and both are
  exactly what an inter-wave/inter-cycle checkpoint can retire; the report recommends triggering
  on **actual `modified_files`** (already read into scope at step 5.5 for staging) rather than
  declared `file_scope`, because it is strictly more precise and closes gap (a) that a
  file_scope-only trigger would miss.
- The genuinely new hazard the task description flags is real and independently confirmed: four
  of the nine critical-path files are shell scripts re-invoked via `bash .claude/scripts/X.sh`
  fresh from disk on every call (`scripts/skill-base.sh`, `scripts/task-lock.sh`,
  `scripts/update-task-status.sh`, `scripts/orchestrate-batch-admit.sh`, plus
  `scripts/orchestrate-triage-classify.sh` and `scripts/orchestrate-dry-run-report.sh`), while the
  two `SKILL.md` files and `commands/orchestrate.md` are read once into the orchestrator's own
  context at Skill/command-dispatch time and stay fixed for the remainder of that turn regardless
  of any later redeploy. A mid-run redeploy therefore swaps live script behavior for the
  *remaining cycles of the very same orchestrator invocation* — a materially different exposure
  than the disproven live-corruption hypothesis for markdown artifacts, and it collapses the
  human verification gap (hazard 1) that manual, human-paced redeployment previously provided.
  This report recommends a narrow, evidence-gated trigger plus a hard `verify-deploy.sh` gate and
  a defer-remaining-waves failure contract to contain it, rather than concluding the checkpoint is
  unsafe to build.
- A previously-undiscussed collision risk: `deploy-headless.sh` overwrites the *whole* `.claude/`
  tree, and nothing today serializes that overwrite against another concurrently-running
  `/orchestrate`, `/implement`, or a human's `<leader>al` invocation reading the same tree. This
  is new exposure this task's automation specifically introduces (today's deploy is manual and
  human-paced, so this race is rare in practice); the report recommends reusing the existing
  fail-open `specs/.commit-lock/`-style mutex pattern (not a new lock primitive) around the
  checkpoint's `deploy-headless.sh` call.
- Hard mode (`skill-orchestrate-hard/SKILL.md`) explicitly delegates its multi-task stages to
  the base skill by reference ("Same as base `skill-orchestrate`... use base multi-task stages")
  rather than duplicating Stage MT-3's text. A checkpoint added to base Stage MT-3 is therefore
  inherited by `--hard` automatically, with no separate edit needed — confirmed by reading
  `skill-orchestrate-hard/SKILL.md`'s Stage 0, not assumed. This is unlike the Stage 8
  `.return-meta.json` clobber (dependency 936), where hard mode needed independent verification
  because it has no Stage 8 write of its own; here the reuse is by reference, so the inheritance
  is structural rather than needing to be replicated.

## Context & Scope

This is a design-and-documentation task (per the declared file scope, no new script is required
— the two scripts already exist and are already verified). The substantive work is: (1) decide a
narrow, evidence-based trigger; (2) decide a fail-safe failure contract; (3) confirm/document the
commit-before-redeploy ordering; (4) reconcile the checkpoint against `deploy-headless.sh`'s and
`regeneration-is-manual-only.md`'s "must be invoked explicitly, never a silent side effect"
constraint; (5) update `batch-orchestration-guardrails.md`'s hazard-3 paragraph to reflect
whatever is decided. This report does not write any implementation — it hands a fully-grounded
design to the planning stage.

## Findings

### Codebase Patterns

**Where "wave" boundaries actually live.** `commands/orchestrate.md` Step 3 pre-computes a
Kahn's-algorithm wave schedule (`waves = [[42], [43, 44]]`) and hands it to a *single*
`skill-orchestrate` instance. Inside the skill, Stage MT-3 ("Lifecycle-Cycling Loop") does not
iterate the `waves` array directly — it recomputes `eligible_tasks` every **cycle** from current
`state.json` status plus the `dependency_graph`, and MAX_CYCLES_MT bounds the loop
(`min(task_count * 5, 25)`). A "wave boundary" for the purpose of this task is therefore best
understood as **the end of one Stage MT-3 cycle** (after Stage MT-4's dispatch and step 5.5's
per-task commits, before the loop re-evaluates eligibility for the next cycle) — not a literal
single pass over one `waves[]` entry. The checkpoint should hook there: after step 6 ("Increment
cycle_count") and before the loop returns to step 1 ("Status refresh") for the next cycle. This
placement is natural, not contested — no existing step currently occupies that exact point.

**Commit-before-redeploy already holds by construction.** Stage MT-4 step 5.5 commits each
dispatched task in the current cycle individually, inside the same per-task loop iteration that
just ran that task's postflight — this is unconditional and precedes step 6 (cycle-count
increment) and the loop's return to step 1. By the time a hypothetical "step 7: inter-cycle
redeploy checkpoint" would run, every task dispatched this cycle has already had its own commit
attempt (success or logged failure — commit failure at 5.5 is explicitly non-blocking). No new
sequencing logic is needed to satisfy Scope item C; the report's recommendation is simply to
state this ordering explicitly in the implementation (a new step, e.g. "6.5" or "7", positioned
after step 6) rather than invent a different commit-then-redeploy synchronization mechanism.

**Self-modification exclusion is invocation-scoped, not wave-scoped, and already total.**
Both `orchestrate.md` Step 3 and `skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 exclude a
`self_modifying`-flagged candidate from the **whole invocation** (recorded in the
invocation-scoped `deferred_self_modifying` set), not merely deferred to a later wave/cycle like
an ordinary `file_scope_collision`. The task is "neither marked failed nor blocked — it simply is
not dispatched by this invocation," with the operator told to `/orchestrate {task_number}` solo.
This means: **the literal in-batch W0-fixes/W1-still-stale sequence cannot occur for a candidate
whose declared `file_scope` correctly names the critical path it touches** — such a candidate
never dispatches in that batch at all. The genuinely live residual is narrower and takes two
shapes:

1. **Declared/actual divergence** — a task's declared `file_scope` does *not* name a critical
   path (so the admission gate does not flag it as `self_modifying` and it dispatches normally in
   an early wave/cycle), but its *actual* `modified_files` (self-reported by the implementation
   agent, read at Stage MT-4 step 5.5 from that task's own `.return-meta.json`) *do* include one
   of the nine critical paths. Task 933's Defect 3 discussion documents the mirror-image problem
   (over-broad `file_scope` causing false-positive self-modifying defers) but the *under*-broad
   direction — a narrower declared `file_scope` than what actually gets touched — is not fully
   closed by any of the three completed dependency tasks. This is exactly the shape of gap an
   inter-wave/inter-cycle checkpoint should defend against, and it argues for triggering on
   **actual `modified_files`** rather than declared `file_scope` (see Recommendations below): the
   modified_files list is already read into scope at step 5.5 for staging, so checking it against
   `orchestrator-critical-paths.json` costs nothing extra to compute and is strictly more precise
   than a file_scope-based trigger.
2. **Cross-invocation staleness** — a self-modifying candidate is correctly excluded, the operator
   re-runs it solo per the logged instruction, it completes and commits its fix to the source
   store. Nothing today redeploys that fix. If the operator then resumes the *original* batch's
   remaining, not-yet-dispatched task numbers via a fresh `/orchestrate` invocation, that new
   invocation's admission decisions (and every critical script it calls) still run against the
   stale, pre-fix deployed copy — because deployment is exclusively manual. This is the more
   general, and arguably the dominant, form of hazard 3: it is not really "inter-wave" so much as
   "inter-invocation," but a checkpoint hooked at cycle/wave boundaries *within* whichever
   invocation happens to contain the fix is the only place the orchestrator itself can act on it
   without requiring the operator to remember to redeploy by hand between invocations.

**The new script-swap hazard is real, confirmed independently.** Reading
`orchestrator-critical-paths.json`, six of the nine critical paths are `scripts/*.sh` files
(`skill-base.sh`, `task-lock.sh`, `update-task-status.sh`, `orchestrate-batch-admit.sh`,
`orchestrate-triage-classify.sh`, `orchestrate-dry-run-report.sh`); every one of them is invoked
via a fresh `bash .claude/scripts/X.sh ...` subprocess call at each use site throughout
`skill-orchestrate/SKILL.md` and `orchestrate.md` — a shell script has no analogue to "already
loaded into context," so each invocation genuinely re-reads the current on-disk bytes. The
remaining three critical paths (`skills/skill-orchestrate/SKILL.md`,
`skills/skill-orchestrate-hard/SKILL.md`, `commands/orchestrate.md`) are read once, into the
orchestrator's own context, at Skill-tool/command-dispatch time, and — because that context is
fixed for the remainder of the turn regardless of what the deployed file on disk later says — a
mid-run redeploy of these three has no effect on the *currently executing* orchestrator turn; it
only affects the *next* Skill/command dispatch. This is the precise asymmetry the task
description points at: for scripts, a mid-run redeploy is not merely a future-session concern, it
changes behavior *within the same running session*, reintroducing — for scripts specifically —
the failure mode the guardrails doc's live-corruption hypothesis disproved for markdown
artifacts. The practical consequence: an inter-cycle redeploy checkpoint retires hazard 3 for
scripts precisely because it operates within the same session, but that is also exactly why it
must be gated carefully — an unverified script fix now takes effect immediately, with no human
in the loop, for every remaining cycle of the current invocation.

**Verification cost is non-trivial but bounded and already tooled.** `verify-deploy.sh` runs a
doc-lint pass (`check-extension-docs.sh`, twice — once plain and once with
`STRICT_CORE_DEPLOY=1`) plus `jq`-based hook-registration checks; `deploy-headless.sh` spawns a
headless `nvim` process that syncs the full extension tree (verified at ~263 artifacts in
`regeneration-is-manual-only.md`'s own test). Neither is instantaneous, and both would run once
per triggered checkpoint — this is the concrete cost side of Scope item A's "weigh cost" framing,
and argues against an unconditional "always between cycles" trigger for a multi-task batch that
may span many cycles with no self-modifying content at all.

**Existing mutex pattern reusable for the new collision risk.** `git-commit-scoped.sh` already
implements a fail-open `specs/.commit-lock/` mutex: on failure to acquire, it logs a loud warning
and proceeds unserialized rather than blocking — explicitly because the worst case (a raw
`index.lock` race) is judged acceptable given the operation is still path-scoped. This is the
right template for the new deploy-collision risk this task's automation introduces (a
concurrently-running separate `/orchestrate`/`/implement` session, or a human's own `<leader>al`,
racing this checkpoint's `deploy-headless.sh` overwrite of the whole `.claude/` tree) — the
report recommends wrapping the checkpoint's `deploy-headless.sh` call in an equivalent fail-open
mutex (e.g. a new `specs/.deploy-lock/` directory-based lock, mirroring the commit-lock's
acquire/warn-and-proceed shape) rather than either inventing a blocking primitive or leaving the
new collision window completely unguarded.

**Hard mode inherits by reference, confirmed by reading the file.** `skill-orchestrate-hard/SKILL.md`
Stage 0 states "Same as base `skill-orchestrate`. Parse `multi_task_mode`. If true, use base
multi-task stages" — it does not duplicate Stage MT-1..MT-5's text. A checkpoint added to base
Stage MT-3 is therefore inherited by `--hard` runs automatically. This was verified by reading
the actual file rather than assumed from the task's declared file scope (which, correctly,
excludes `skill-orchestrate-hard/SKILL.md` — no edit to it is needed).

### External Resources

Not applicable — this is an internal design question over already-verified, already-documented
in-repo machinery; no external documentation or best-practice search was needed or performed.

### Recommendations

**A. Trigger — evidence-gated, not "always" and not a bare opt-in flag.** Recommend: after Stage
MT-4 step 5.5 commits each cycle's dispatched tasks, check the union of every dispatched task's
*actual* `modified_files` (already read at step 5.5 into the staging array) against the expanded
`orchestrator-critical-paths.json` list (the same `scope_roots × critical_paths` expansion
`orchestrate-batch-admit.sh` already performs — reuse its jq expression rather than re-deriving
it). If any modified file overlaps a critical path (directory-prefix overlap per
`file-footprint-overlap.md`'s canonical predicate — reuse it, do not restate it), run the
checkpoint before the next cycle's eligibility check. If none overlap, skip the checkpoint this
cycle at zero cost beyond the jq comparison. This differs deliberately from a
declared-`file_scope`-based trigger (which the self-modification admission gate already performs
pre-dispatch): using `modified_files` closes the under-declaration gap identified above and is
strictly more precise, at no extra cost since the array is already in scope. Recommend NOT an
unconditional "always between cycles" trigger (unjustified cost per every cycle of every batch,
regardless of relevance) and NOT a bare user-supplied opt-in flag (defeats `/orchestrate`'s
stated zero-synchronous-confirmation-gates design — the operator cannot know in advance which
cycle will touch critical-path files, so requiring them to pre-declare intent is equivalent to
requiring omniscience or defeating the point).

**B. Failure contract — defer remaining cycles, not abort, not silent-continue.** If
`deploy-headless.sh` fails (exit 1 or 2) or `verify-deploy.sh` fails (exit 1) after a checkpoint
fires, recommend: log a loud warning naming which gate failed and why, then **defer all remaining
not-yet-dispatched tasks** for the rest of this invocation (mirroring the existing
`deferred_self_modifying` mechanism's shape — an invocation-scoped exclusion, not a `failed_tasks`
mutation) rather than aborting the whole run or silently continuing against a now-uncertain
deploy state. This matches the guardrails doc's own "Defer-Not-Fail: The Standing Default"
section precisely: a checkpoint failure is a transient, resolvable-later condition (the operator
fixes whatever broke the deploy/verify, then manually redeploys and re-runs `/orchestrate` on the
remaining task numbers), not a terminal one. Tasks already dispatched and committed in prior
cycles are unaffected — their commits already landed at step 5.5 before this cycle's checkpoint
ran, so nothing already-done is put at risk by deferring what comes next. Abort-the-whole-run is
rejected because it would discard the batch's own bookkeeping state (`mt_state_file`) for no
benefit over deferral, since deferral already halts further exposure. Silent-continue is rejected
outright — it is exactly the "silently makes this worse than the gate it replaces" regression the
task description explicitly warns against.

**C. Sequencing — state explicitly, not re-engineer.** As found above, per-task commits (step
5.5) already precede any point a new checkpoint step could occupy in the same cycle. Recommend
the plan add a new step (numbered after step 6, e.g. "7. Inter-cycle redeploy checkpoint") to
Stage MT-3, and have `docs/architecture/orchestrate-state-machine.md`'s "Commit Granularity"
subsection gain one clause cross-referencing it: committed-then-redeployed, in that order, is
already guaranteed by existing step ordering and needs only to be stated, not built.

**D. Reconciling the deliberate-invocation constraint.** Recommend resolving this by narrowing
the constraint's *scope*, not by loosening it wholesale: `regeneration-is-manual-only.md`'s "must
be invoked explicitly and never as a silent side effect of an unrelated operation" line should
gain an explicit, narrowly-worded carve-out naming this exact checkpoint — because the trigger in
(A) is not a side effect of an *unrelated* operation, it is the operation the checkpoint exists
to correct: a documented, evidence-gated (critical-path-`modified_files`-only), loudly-logged
response to precisely the condition (a critical-path fix just landed) that makes redeployment
necessary. It is not silent (loud warning either way, gated and cycle-scoped) and not unrelated
(the fix that triggers it is the fix the checkpoint exists to make live). Recommend the plan draft
this carve-out as its own labeled subsection in `regeneration-is-manual-only.md` (e.g. "Automated
Exception: the Inter-Cycle Self-Modification Checkpoint") rather than editing the existing
sentence in place, so a future reader sees both the original constraint and the one narrow,
justified exception side by side — matching this document's own established pattern of recording
corrections as additive blocks (see its own "CORRECTION" section) rather than silently rewriting
prior text.

**E. Guardrails doc update — record retirement precisely, not overstate it.** Recommend
`batch-orchestration-guardrails.md`'s hazard 3 paragraph be updated to: (i) state that the
in-batch, file_scope-correctly-declared form of the hazard was already structurally impossible
before this task, because the self-modifying admission gate fully excludes such a candidate from
the invocation; (ii) state that the two residual forms — declared/actual `file_scope`
divergence, and cross-invocation staleness — are what this checkpoint retires, via the
`modified_files`-gated trigger; (iii) add hazard 3's replacement/residual honestly: the new
script-swap exposure (mid-invocation live behavior change for the six script critical paths, for
the remaining cycles of the same invocation) is a **replacement** hazard, not a fully independent
new one — it is the same underlying tension (verified-only-in-a-scratch-copy, hazard 1) now
manifesting mid-session rather than merely cross-session, and should be named as such rather than
listed as an unrelated fourth hazard. Recommend documenting hazard 3 as "partially retired,
replaced by a narrower and better-contained mid-invocation script-swap exposure" — not "retired,"
since the trade is real and should not be hidden.

## Decisions

- **Trigger evidence**: use post-dispatch `modified_files` (already in scope at step 5.5), not
  pre-dispatch declared `file_scope`, as the checkpoint's gating signal.
- **Checkpoint placement**: a new step after Stage MT-3 step 6 (cycle-count increment), before the
  loop returns to step 1 for the next cycle — this is a per-cycle hook, matching how Stage MT-3
  actually dispatches (cycle-by-cycle), not a literal per-`waves[]`-entry hook.
- **Failure contract**: defer remaining tasks for the rest of the invocation on either
  `deploy-headless.sh` or `verify-deploy.sh` failure; never abort, never silently continue.
- **Deliberate-invocation reconciliation**: add a narrow, explicitly-scoped carve-out to
  `regeneration-is-manual-only.md` naming this checkpoint, rather than loosen the general rule.
- **Guardrails wording**: hazard 3 should be recorded as "partially retired, replaced by a
  narrower mid-invocation script-swap exposure" — not a bare "retired."

## Risks & Mitigations

- **Risk**: a naive trigger on declared `file_scope` (mirroring the existing admission gate)
  would miss the under-declaration gap and give false confidence that hazard 3 is fully closed.
  **Mitigation**: gate on actual `modified_files` instead (Recommendation A).
- **Risk**: an unconditional "always between cycles" trigger imposes deploy/verify cost on every
  cycle of every multi-task batch regardless of relevance, and maximizes the new mid-invocation
  script-swap exposure window. **Mitigation**: evidence-gated trigger, fires only when a critical
  path was actually touched this cycle.
- **Risk**: automating what was previously a rare, human-paced, manual operation introduces a
  concurrent-write collision against another live session's `.claude/` tree reads or a human's own
  `<leader>al`. **Mitigation**: reuse the existing fail-open `specs/.commit-lock/`-style mutex
  pattern around the checkpoint's `deploy-headless.sh` call (a new `specs/.deploy-lock/`, same
  acquire/warn-and-proceed shape) rather than leaving the window unguarded or inventing a novel
  blocking primitive.
- **Risk**: a checkpoint failure treated as "continue anyway" would let the rest of the batch run
  against a deploy state of unknown correctness — potentially worse than never having checked at
  all, since the operator would see no warning distinguishing "we didn't check" from "we checked
  and it's broken but proceeded anyway." **Mitigation**: defer-remaining-tasks failure contract
  (Recommendation B), with a loud, specific warning naming which of the two gates failed.
- **Risk**: silently rewriting `regeneration-is-manual-only.md`'s "must be invoked explicitly"
  sentence to accommodate this checkpoint would make the document self-contradictory to a future
  reader who does not see this task's reasoning. **Mitigation**: additive, explicitly-labeled
  carve-out subsection (Recommendation D), matching the document's own established
  correction-as-addition pattern.

## Context Extension Recommendations

- **Topic**: none — this is a `meta`-type task whose only deliverables are the six declared
  source-store files; no new context-file gap was identified beyond what the recommendations
  above already assign to specific files in scope.

## Appendix

### Files read (source-store, per the binding SOURCE-STORE RULE)

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (full)
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` (full)
- `agent-system/extensions/core/scripts/deploy-headless.sh` (full)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (full)
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` (full)
- `agent-system/extensions/core/commands/orchestrate.md` (full)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stages MT-1 through MT-5,
  lines ~1125-1795)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (Stage 0 header, to
  confirm multi-task delegation-by-reference)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (Commit
  Granularity subsection)
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` (critical-path expansion
  logic, lines ~140-260)
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` (commit-lock mutex pattern, grep
  excerpt)
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` (overlap predicate
  summary)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (Handoff Writers table —
  used to confirm base-mode research does not write `.orchestrator-handoff.json`; see note below)
- `specs/state.json` entries for tasks 932, 933, 936, 934 (dependency status and this task's own
  record)

### Note on this task's own handoff artifact

The delegation context supplied a `handoff_path` pointing at
`specs/934_inter_wave_redeploy_checkpoint/.orchestrator-handoff.json` and an instruction to write
it. Per `docs/architecture/handoff-schema.md`'s "Handoff Writers" table, base-mode
`skill-researcher` (and, by the same documented rule, this research agent) is explicitly
prohibited from writing `.orchestrator-handoff.json` — research's outcome channel is
`.return-meta.json` only. This report and the accompanying `.return-meta.json` (status
`researched`) are therefore the complete, correctly-scoped output of this research pass; no
`.orchestrator-handoff.json` was written, consistent with the documented contract this same task
is asking the planning stage to reason carefully about elsewhere in the system.

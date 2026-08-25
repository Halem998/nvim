# Research Report: Task #83

**Task**: 83 - Make 'completed' mean 'in effect' for tasks that edit the source store — a postflight deploy gate
**Started**: 2026-08-25T00:29:15Z
**Completed**: 2026-08-25 (session sess_1787617685_88b825_83)
**Effort**: Medium-large (multiple call sites, one new automated-caller carve-out, careful concurrency reasoning)
**Dependencies**: 82 (complete — `verify-deploy.sh` gained `--skip-slow`; `deploy-headless.sh` now runs verification inline and exits 3 for "deploy landed, verification failed")
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/*.sh`, `skills/skill-orchestrate/SKILL.md`, `skills/skill-implementer/SKILL.md`, `context/patterns/*.md`), live measurement (`check-deploy-freshness.sh`, git log, deployed-vs-source diff)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Re-measured status (supersedes the stale figures in the task description)**: the deploy HAS run since. `check-deploy-freshness.sh` still reports `core` stale right now, but that is because commit `02ed59dda` ("task 82: complete implementation") landed under `agent-system/extensions/core` *after* the last deploy snapshot (`430159f3b…`); a byte-diff of the deployed vs. source `skill-base.sh` is empty — the dispatch_seq fix cited in the old description is confirmed live. Staleness is expected, ongoing, normal state, not a crisis figure to re-cite.
- **The gate cannot live only in `command-gate-out.sh`.** For the exact case this task cares about (`task_type: meta`, single-task `/implement`), the primary status-flip to `completed` happens **inside `skill-implementer/SKILL.md` Stage 7** (`update-task-status.sh postflight … implement … --phase-check=refuse`), which runs *before* `command-gate-out.sh` and leaves it a no-op (its defensive-correction branch only fires when `current_status != expected_status`, and by the time gate-out runs the status is already `completed`). `command-gate-out.sh` is also not the only completion path: `skill_postflight_update` (`skill-base.sh`) is a second, independent chokepoint used by `skill-orchestrate`, the team skills, and several extension implementation skills.
- **Recommendation**: mirror the *existing* `--phase-check=warn|refuse` backstop precedent (already inside `update-task-status.sh`, already fires for `operation==postflight && target_status==implement`, already resolves the task's own artifacts from disk with no new argument needed) with a sibling **deploy-freshness backstop**, unconditional (no opt-in flag, unlike phase-check — see Decision-Needed section), living in `scripts/update-task-status.sh` itself. This is the one place every completion path — `skill-implementer`'s inline call, `skill_postflight_update`'s call, and `command-gate-out.sh`'s defensive-correction call — already funnels through. **`scripts/update-task-status.sh` must be added to `file_scope`; it is currently absent.**
- **Do not let the backstop itself call `deploy-headless.sh`.** The multi-task `/implement N,M` loop and `skill-orchestrate`'s per-cycle dispatch both invoke per-task implementation skills **in parallel** (a single Agent-tool message per the BATCHING RULE). If the new backstop unconditionally shelled out to `deploy-headless.sh` from inside each task's own postflight call, concurrently-completing tasks in the same batch would race `deploy-headless.sh` invocations against the fail-open `specs/.deploy-lock` mutex — exactly the untested "`--wipe` racing another `--wipe`" hazard `regeneration-is-manual-only.md` already flags as open. Keep the backstop **check-only** (refuse, never auto-deploy) and put the **actual auto-deploy trigger** at a small number of already-serialized points: (a) `command-gate-out.sh`, for the true single-task path, after a refusal is observed; (b) the multi-task `/implement` loop's existing serial Step 4 (after all parallel dispatches return); (c) `skill-orchestrate`'s existing Stage MT-3 step 7, whose trigger predicate should be widened from the narrow `orchestrator-critical-paths.json` list to full `agent-system/extensions/**` overlap (or run both checks — see Findings).
- **A naive "any verification failure blocks completion" gate would brick the system today.** `regeneration-is-manual-only.md` documents that, as of the exit-3 change (task 82), `deploy-headless.sh` currently exits 3 on **every** non-dry-run invocation because of pre-existing doc-lint and gate-8 failures unrelated to any given task. The gate MUST use the same **baseline-relative** comparison `skill-orchestrate`'s Stage MT-3 step 7 already implements (new findings vs. pre-redeploy findings), not a raw exit-code check, or 47 of 48 active meta tasks would never be able to complete.
- **The carve-out is mandatory and has an exact model to follow.** `regeneration-is-manual-only.md`'s `## Automated Exception` subsection sanctions exactly one automated `deploy-headless.sh` caller (`skill-orchestrate`'s Stage MT-3 step 7) and explicitly states "no other automated caller may invoke `scripts/deploy-headless.sh` without its own equivalent exception recorded in this same section." This task adds at least one new caller (command-gate-out.sh's post-refusal trigger, and/or the multi-task loop's Step 4 trigger) and must therefore add its own labeled, additive subsection there — never editing the existing text.

## Context & Scope

Re-read from `specs/state.json` (`project_number: 83`), cross-checked against the delegation
context's explicit correction that the stale-deploy figures ("7 days and 133 commits stale") and
the mint-dispatch-seq/literature-fix non-deployment claims in the stored description are no
longer current: the deploy has since run, all three repos are reported byte-identical on shared
deployed scripts, and task 82 (wiring `deploy-headless.sh`'s inline `verify-deploy.sh` call and
its exit-3 contract) is complete. This report treats the stored description as background
motivation only and re-derives current facts from the live tree.

**Confirmed live** (measured this session):
- `.claude/scripts/skill-base.sh` line 963 reads `jq -r '(.dispatch_seq_counter // 0) + 1'` (the
  corrected form) both in the deployed tree and the source store, byte-identical diff.
- `check-deploy-freshness.sh /home/benjamin/.config/nvim` currently prints one `WARN` for the
  `core` extension (exit 0, as designed — it never blocks). This traces to commit `02ed59dda`
  ("task 82: complete implementation") landing under `agent-system/extensions/core` after the
  `.claude-extensions.json` snapshot (`source_git_head: 430159f3b…`) was taken — i.e., ordinary,
  expected drift from ongoing meta-task work, not a multi-day incident.
- `scripts/deploy-headless.sh` and `scripts/verify-deploy.sh` are present, executable, and dated
  today (task 82's work).

**The task's real remaining work**, as stated in the delegation context and confirmed by reading
`regeneration-is-manual-only.md`: a postflight gate so that a task touching the source store
cannot reach `[COMPLETED]` without a deploy having run, plus the mandatory carve-out that
subsection's own text requires for any additional automated `deploy-headless.sh` caller.

## Findings

### A. The completion-path topology (why `command-gate-out.sh` alone is insufficient)

There are at least **three** distinct call sites that can set a task's `state.json` status to
`completed` via `update-task-status.sh postflight <task> implement <session>`:

1. **`skill-implementer/SKILL.md` Stage 7** (line ~450) — the PRIMARY path for `task_type` in
   `{general, meta, markdown}`, i.e. exactly the population this task is about. Calls
   `update-task-status.sh` directly, inline, already passing `--phase-check=refuse`. This
   completes **before** `command-gate-out.sh` ever runs (gate-out is CHECKPOINT 2 in
   `commands/implement.md`, invoked only after the skill returns).
2. **`skill_postflight_update`** (`skill-base.sh`, "Stage 7: Update status to completed
   variant") — used by `skill-orchestrate` (its own per-task dispatch, passing `--phase-check`
   mode `"warn"`, not `"refuse"` — a deliberately weaker mode than the single-task path, so batch
   dispatch doesn't dead-end), `skill-researcher`/`skill-planner` (for their own non-`implement`
   status tokens), `skill-team-implement`, `skill-web-implementation`, `skill-epi-implement`, and
   others. `skill-implementer` (the core/general/meta/markdown skill) does **not** call this
   shared function — it has its own inline call (point 1).
3. **`command-gate-out.sh`'s defensive correction** — fires ONLY when
   `current_status != expected_status` after the skill returns. This is a backstop for crashed or
   non-conforming skills, not the normal path. By design it is a no-op whenever point 1 or 2
   already succeeded, which is the common case.

Multi-task `/implement N,M` **bypasses `command-gate-in.sh`/`command-gate-out.sh` entirely**
(`commands/implement.md` Step 3's own comment: "This multi-task loop bypasses
`command-gate-in.sh`/`command-gate-out.sh` entirely … so each per-task dispatch acquires/releases
the task lock itself"). Each dispatched task still reaches point 1 (skill-implementer's own inline
call) or point 2 (other skills' `skill_postflight_update` call) internally — `command-gate-out.sh`
is never involved for this path at all.

**Consequence**: a gate added only inside `command-gate-out.sh` would never see the "not yet
completed" state for the single most common case (`skill-implementer` on a meta task), because
that skill has already flipped `state.json` to `completed` by the time gate-out runs, and would
never fire at all for multi-task `/implement`.

### B. The existing precedent to mirror: `update-task-status.sh`'s phase-accounting backstop

`update-task-status.sh` already has exactly the shape needed, implemented once as a "Phase 0"
backstop (lines ~267–384):

- Fires when `operation == "postflight" && target_status == "implement" && state_is_noop != "true"`.
- Resolves the task's own on-disk artifact **itself**, from `task_number` — no new CLI argument
  was needed for the phase-check backstop to find the task's plan file; the same pattern applies
  directly to reading a task's `.return-meta.json` for `modified_files`, since `task_number` ->
  `project_name` -> `task_dir` is already resolved earlier in the script for the plan-file lookup.
- Distinguishes **inconclusive** (pass through silently or with a note) from **conclusive
  evidence of a problem** (only the conclusive case can refuse).
- `--phase-check=refuse` exits **4**, with no state.json write and no plan-file stamp, and a
  message naming the remedy.
- Every caller of `update-task-status.sh postflight … implement` already has to handle a non-zero
  `postflight_rc`; `skill-implementer/SKILL.md` Step 1a explicitly treats `rc==4` like a
  `partial` outcome: keep status at `implementing`, record `resume_phase`, let the next
  `/implement` resume. This is an **ordering constraint**, not a permanent exclusion — exactly
  the shape `batch-orchestration-guardrails.md`'s "Blocking vs. Advisory" section holds up as the
  preferred failure shape ("a guardrail should degrade to an ORDERING CONSTRAINT whenever
  possible... never as an accidental consequence of a gate's implementation shape").

A new **deploy-freshness backstop** in the same "Phase 0" family (call it "Phase 0.5" or fold it
into the same block) is the design that requires editing the fewest call sites: it fires for
every caller of `update-task-status.sh postflight … implement` uniformly — `skill-implementer`'s
inline call, `skill_postflight_update`'s call, and `command-gate-out.sh`'s defensive-correction
call all reach it automatically, with **no edits needed to `skill-implementer/SKILL.md` or any
other skill file** to thread a new flag through. This is the single strongest argument for
**adding `scripts/update-task-status.sh` to `file_scope`** — it is currently absent from the four
files the task was admitted with, and without it the gate cannot reach the primary meta-task
completion path at all.

**Whether it should be opt-in (a new `--deploy-check=warn|refuse` flag, mirroring
`--phase-check`) or unconditional** is a genuine decision the plan must make explicitly (see
Decisions Needed). Opt-in requires editing every caller to pass the flag (including
`skill-implementer/SKILL.md`, which is out of the currently-admitted `file_scope`); unconditional
requires none, at the cost of removing the "warn" escape hatch `skill-orchestrate` uses for
phase-check. Given the task's acceptance criterion is stated without exception ("a meta task
whose implementation edits the source store cannot reach `[COMPLETED]` without the deploy having
run" — full stop), **unconditional is the better fit for the stated goal**, and it is also the
only option that needs zero edits outside the four-plus-one files this task should own.

Classifying this gate under `batch-orchestration-guardrails.md`'s existing **Blocking vs.
Advisory** criterion (`context/patterns/batch-orchestration-guardrails.md` lines ~65–82) supports
BLOCKING: it is (1) computable purely from on-disk structural state — `modified_files` (from
`.return-meta.json`, already on disk) compared against `agent-system/extensions/**` via a
directory-prefix check, plus a git-log freshness comparison, no agent invocation required — and
(2) the harm of proceeding anyway is silent and hard to detect after the fact — this is a literal
restatement of the defect this whole task exists to close (tasks marked `[COMPLETED]` with
honest summaries while their fixes are absent from the running system).

### C. Scope of "touched the source store": broaden past the existing narrow critical-paths list

`context/reference/orchestrator-critical-paths.json` (the registry `skill-orchestrate`'s existing
Stage MT-3 step 7 checkpoint uses) has `scope_roots: ["agent-system/extensions/core", ".claude",
".opencode"]` and a small curated `critical_paths` list (about 15 files: `skill-base.sh`,
`task-lock.sh`, `update-task-status.sh`, `verify-deploy.sh`, etc.) — deliberately narrow, because
that checkpoint exists to protect the orchestrator's **own** mid-run safety (the script-swap
hazard), not to guarantee general deploy-freshness. It does not cover the `nvim`, `email`,
`literature`, `nix`, or `memory` extensions at all, and it does not cover non-critical files even
within `core` (e.g., a context doc, a non-critical skill file).

This task's stated scope is broader: "a meta task that touched `agent-system/**`" — i.e., any
file under any extension's source tree, matching `check-deroy-freshness.sh`'s own
`.claude-extensions.json`-driven per-extension scan (which already covers all six extensions, as
measured this session) and matching `source-store-deploy-boundary.md`'s `agent-system/**` pattern
for what counts as "the source store." **Recommendation**: the new gate's overlap predicate
should be `modified_files` entries starting with `agent-system/extensions/` (any extension), using
the directory-prefix rule already defined once in `context/patterns/file-footprint-overlap.md`
(reuse that document by reference; do not re-derive the algorithm inline) — **not** limited to
`orchestrator-critical-paths.json`'s curated list, and **not** gated on `task_type == "meta"`
specifically (a `general`-typed task could, in principle, also touch `agent-system/**`, and the
predicate should be path-based like every other file-scope check in this system, not type-based).

### D. The pre-existing-failure trap: baseline-relative comparison is mandatory, not optional

`regeneration-is-manual-only.md`'s `### deploy-headless.sh's Inline Verification and Exit Code 3`
subsection states plainly: *"As of this correction, doc-lint (gate 3 …) reports pre-existing
issues in this repo's own source store, and gate 8 … has pre-existing failing suites. Both
predate this correction and are unrelated to it. The practical effect: **every
`deploy-headless.sh` invocation exits 3** until those pre-existing failures are fixed. That is
the intended behavior."*

If the new postflight gate treats "exit 3" (or any non-zero exit) as an unconditional block, it
would block **every** meta task's completion, indefinitely, starting now — a severe regression
far worse than the silent-staleness defect it is meant to fix. `skill-orchestrate`'s Stage MT-3
step 7 already solved exactly this problem with its **baseline mechanism**
(`batch-orchestration-guardrails.md`'s `### The Inter-Cycle Redeploy Checkpoint`): capture
`verify-deploy.sh --findings --quiet` immediately before and after the redeploy, diff the two
sorted/deduplicated finding sets, and block only on **newly introduced** findings (branch b),
while proceeding — loudly, via a `[PRE-EXISTING VERIFY-DEPLOY FAILURE ...]` banner — when every
post-redeploy finding already existed pre-redeploy (branch c). The new gate MUST reuse this same
mechanism (by reference, not reimplementation) rather than a raw exit-code check, or it will brick
the system on day one given today's measured state.

Note this also means the gate's freshness check needs, at minimum, a way to determine "has *a*
deploy run since this task's changes landed" even when that deploy's `verify-deploy.sh` exits 3
for unrelated pre-existing reasons — i.e., "deploy has run" and "deploy's findings introduced no
new failures relative to this task's own change" are the two conditions to check, matching the
existing checkpoint's own two-gate structure (`deploy-headless.sh` failure vs.
`verify-deploy.sh` new-finding failure).

### E. Concurrency hazard: do not trigger `deploy-headless.sh` from inside parallel per-task postflight

Both `commands/implement.md`'s multi-task loop (Step 3: "invoke each task's implementation skill
using parallel Skill tool calls") and `skill-orchestrate`'s own per-cycle dispatch (Stage MT-4's
BATCHING RULE: "every cycle's Agent tool calls [are] issued in a single orchestrator message")
run multiple tasks' implementation skills **concurrently**. If the new backstop, sitting inside
`update-task-status.sh` (reached from each task's own postflight call), itself shelled out to
`deploy-headless.sh` on refusal, two or more concurrently-completing tasks in the same batch could
independently trigger `deploy-headless.sh` at nearly the same moment. `deploy-headless.sh` holds
`specs/.deploy-lock` **fail-open** (the same "acquire, warn-and-proceed" shape as
`specs/.commit-lock` — see `regeneration-is-manual-only.md`'s own "Concurrency" subsection under
"Round-Trip Fidelity of settings.local.json"), and that same document explicitly flags "a `--wipe`
racing another `--wipe`... is outside what this measurement covers, and remains an untested,
narrower hypothesis" as an open risk. Racing two non-`--wipe` resyncs is likely lower-risk than
racing two `--wipe`s (no destructive `rm -rf .claude` involved), but it is still unmeasured, and
`deploy-headless.sh`'s inline `verify-deploy.sh --skip-slow` call adds real wall-clock time
(~50-70s per the doc's measurement) that would multiply if fired once per task in a batch instead
of once per batch.

**Recommendation**: keep the `update-task-status.sh` backstop **check-only** — it may refuse
(leaving the task at `implementing`, an ordering constraint, exactly like phase-check's refusal
shape), but it must **never itself invoke `deploy-headless.sh`**. Put the actual (bounded,
evidence-gated, carve-out-requiring) auto-deploy trigger only at points that are already
single-threaded relative to a given cycle/batch:

- **True single-task `/implement N`** (not multi-task, not `/orchestrate`): after
  `skill-implementer`'s inline postflight call returns a refusal, `command-gate-out.sh` (running
  once, after the skill has fully returned — no concurrency at this point) is a safe place to
  run `deploy-headless.sh` once, then re-attempt the status transition. This is a genuinely new
  automated caller relative to the one `regeneration-is-manual-only.md` currently sanctions.
- **Multi-task `/implement N,M`**: `commands/implement.md`'s existing Step 4 (already serial,
  already runs once after all of Step 3's parallel dispatches have returned) is the natural
  single place to run one `deploy-headless.sh` for the whole batch if any dispatched task was
  refused for staleness, then re-attempt each refused task's status transition.
- **`/orchestrate`**: already has Stage MT-3 step 7, itself serial relative to its own cycle
  (fires after all of that cycle's parallel dispatches return). The narrow
  `orchestrator-critical-paths.json` trigger predicate should be reconsidered: either widen it to
  the same `agent-system/extensions/**` overlap this task defines (so the one checkpoint covers
  both the orchestrator's own self-modification hazard *and* this task's general-completion
  guarantee), or keep both checks distinct and let the general one also gate completion via the
  same check-only/refuse-and-resume shape as the other two paths, with the actual redeploy still
  routed through Stage MT-3 step 7's existing serialized call. Widening the trigger is likely the
  simpler design (one checkpoint, one carve-out, one baseline mechanism) but changes the meaning
  of an existing, heavily-documented mechanism — this is a decision for the plan, not something
  to resolve unilaterally here.

### F. `check-deploy-freshness.sh`'s documented contract must be updated if reused

`check-deploy-freshness.sh`'s own header states: *"Its only sanctioned caller is
`command-gate-in.sh`'s CHECKPOINT 1 ... MUST be run with `bash`, never sourced."* and *"ALWAYS
EXITS 0. This is not a preflight gate."* If the new deploy-freshness backstop reuses this script's
per-extension git-log comparison logic (recommended — it is already the correct, tested,
commit-granular freshness algorithm, see `scripts/tests/test-deploy-freshness.sh`), it must do so
either by (a) adding `update-task-status.sh` as a second sanctioned caller and updating this
script's own header/contract to say so explicitly (still always-exit-0 as a *library* call — the
new backstop interprets the WARN output itself rather than relying on the script's own exit code
to signal anything), or (b) factoring the comparison into a small shared function (e.g. in a
`scripts/lib/` helper) that both `check-deploy-freshness.sh` (silent, always-0, CHECKPOINT-1-only)
and the new backstop (blocking-capable) call, keeping the "one algorithm, multiple call sites"
property the rest of this codebase already uses for overlap detection
(`file-footprint-overlap.md`'s `FILE_SCOPE_OVERLAP_JQ_DEFS`) and for the deploy checkpoint itself
(`batch-orchestration-guardrails.md`'s "single, authoritative statement... every other file
cross-references this subsection by path rather than restating it"). Option (b) is the better fit
for this codebase's established documentation convention; it also avoids quietly relaxing
`check-deploy-freshness.sh`'s carefully-stated "always exit 0, never a gate" contract for its
existing caller. This is why `check-deploy-freshness.sh` was correctly admitted into `file_scope`
even if only its header/contract prose changes, not necessarily its executable logic.

### G. The required carve-out: exact wording and placement

`regeneration-is-manual-only.md`'s `## Automated Exception: The Inter-Cycle Self-Modification
Checkpoint` subsection is explicit about its own boundary: *"The exact and only sanctioned
automated call site: `skill-orchestrate`'s Stage MT-3 step 7 ... No other automated caller is
sanctioned by this subsection ... no other automated caller may invoke
`scripts/deploy-headless.sh` without its own equivalent exception recorded in this same
section. A future reader must not read this subsection as general precedent for scripted deploys
elsewhere in the system — it licenses exactly the one call site named above, nothing broader."*

This task's design (per Finding E) introduces **new** automated call sites — at minimum
`command-gate-out.sh`'s post-refusal trigger for the true single-task path, and the multi-task
`/implement` loop's Step 4 trigger; possibly a third if `/orchestrate`'s Stage MT-3 step 7 trigger
predicate is widened rather than reused as-is. Each is a distinct call site under this
subsection's own rule and needs its own recorded exception, following the document's own
established **correction-as-addition convention** (the `**CORRECTION.**` block, and the
`## Automated Exception` subsection itself, are both additive to text left byte-for-byte intact
above them — never a rewrite in place).

**Recommended placement**: a new subsection immediately after the existing `## Automated
Exception: The Inter-Cycle Self-Modification Checkpoint` subsection (i.e., before `###
deploy-headless.sh's Inline Verification and Exit Code 3`, which is itself additive to that
subsection and should logically follow both exceptions), titled something like `## Automated
Exception: The Postflight Completion-Deploy Gate`. It should NOT edit a single byte of the
existing `## Automated Exception` subsection's text — only add new prose after it, exactly as
that subsection itself did relative to the `**CORRECTION.**` block above it.

**Recommended content shape**, modeled sentence-for-sentence on the existing exception's own
three-part justification structure (the task description explicitly asks for this):

- **Exact and only sanctioned call sites** (name them precisely once the plan finalizes Finding
  E's design): e.g. "`command-gate-out.sh`'s post-refusal deploy trigger (single-task
  `/implement`/`/orchestrate` completion path)" and "`commands/implement.md` Step 4's
  batch-refusal deploy trigger (multi-task `/implement` completion path)." If Stage MT-3 step 7's
  predicate is widened rather than reused, no third exception is needed for `/orchestrate` — its
  existing exception already covers it, and the widening is a change to that existing (already
  sanctioned) call site's trigger condition, not a new call site.
- **Why this is not a side effect of an unrelated operation**: the task's own commit is what the
  deploy makes live — directly mirroring the existing exception's own phrasing ("the fix that
  triggers the checkpoint is precisely the fix the checkpoint exists to make live... The operation
  is not unrelated — it is the operation being corrected").
- **Why this is not silent**: log on fire (naming the task and the matched `agent-system/**`
  paths in its `modified_files`), on success (deployed artifact count, `verify-deploy` pass), and
  on failure (failing gate, exit code, and — per Finding D — whether the failure is newly
  introduced or pre-existing).
- **Why this is bounded**: evidence-gated on the task's own self-reported `modified_files`
  actually overlapping `agent-system/extensions/**` (per Finding C) — never an unconditional
  "always redeploy on every completion" trigger; fires once per refusal, not repeatedly (mirror
  the existing checkpoint's idempotence-guard framing, even if the concrete mechanism differs —
  here idempotence is naturally satisfied because a successful redeploy clears the staleness
  condition that caused the refusal, so a re-run of the same task's postflight will not re-trigger
  it).
- A closing sentence matching the existing exception's own closing scope-limiter: this carve-out
  licenses exactly the named call site(s), nothing broader; any future automated caller still
  needs its own exception recorded in this same section.

**Cross-reference discipline**: per the existing pattern, the *mechanism itself* (trigger
predicate, baseline comparison reuse, failure contract, idempotence) should be written once,
authoritatively, in whichever pattern doc ends up hosting it (either a new subsection of
`batch-orchestration-guardrails.md` alongside "The Inter-Cycle Redeploy Checkpoint," if the design
reuses that mechanism directly, or a new sibling pattern doc if the single-task and multi-task
shapes diverge enough to warrant their own home) — and `regeneration-is-manual-only.md`'s new
carve-out subsection should cross-reference it by path rather than restating the mechanism, the
same way its existing exception cross-references
`batch-orchestration-guardrails.md`'s "Inter-Cycle Redeploy Checkpoint" subsection today.

### H. `check-deploy-freshness.sh`'s advisory-only documentation requirement

The task's ACCEPTANCE text separately requires: *"`check-deploy-freshness.sh`'s read-side role is
explicitly documented as advisory-only so its always-exit-0 contract is no longer mistaken for a
gate."* This is largely already true in the script's own header (*"ALWAYS EXITS 0. This is not a
preflight gate"*) and in `regeneration-is-manual-only.md`'s `## Detecting When You're Stale`
section (*"It never blocks, aborts, retries, or auto-redeploys anything"*). What is currently
missing is an explicit forward-pointer, from that same documentation, to the **new** blocking
mechanism this task adds — i.e., a sentence in both the script's header and
`regeneration-is-manual-only.md` clarifying that staleness detection now has two tiers: this
script (silent, advisory, CHECKPOINT-1-only) for early operator awareness, and the new postflight
backstop (blocking, evidence-gated) for actually preventing an out-of-effect `[COMPLETED]`. This
is a small doc addition, not a design question, and belongs in the same `regeneration-is-manual-
only.md` edit as the carve-out (Finding G).

## Recommended Design Summary (for the planning phase)

1. **Overlap predicate**: `modified_files` entries (from the task's `.return-meta.json`) whose
   path starts with `agent-system/extensions/` (any extension) — reuse
   `context/patterns/file-footprint-overlap.md`'s directory-prefix rule by reference. Not gated
   on `task_type`.
2. **Where the check lives**: an unconditional new backstop in `scripts/update-task-status.sh`
   (Phase 0-family, alongside the existing `--phase-check` backstop), firing on
   `operation==postflight && target_status==implement && state_is_noop!=true`. Reuses
   `check-deploy-freshness.sh`'s per-extension git-log comparison (factor into a shared helper —
   Finding F) to determine "is a deploy pending" and, when pending, checks for baseline-relative
   `verify-deploy.sh` findings using the SAME mechanism `batch-orchestration-guardrails.md`'s
   Inter-Cycle Redeploy Checkpoint already implements (Finding D). Refusal exits a **new,
   distinct** exit code (5, since 4 is taken by phase-check) with no state.json write and no
   plan-file stamp — an ordering constraint, not an exclusion, exactly like phase-check's shape.
3. **Where the actual `deploy-headless.sh` trigger lives**: never inside the backstop itself
   (Finding E). Three serialized call sites, each needing its own carve-out entry (Finding G):
   `command-gate-out.sh` (single-task), `commands/implement.md` Step 4 (multi-task batch), and
   (if not folded into a widened Stage MT-3 step 7) `/orchestrate`'s own per-cycle checkpoint.
4. **`file_scope` correction**: the task's currently-admitted file_scope
   (`command-gate-out.sh`, `skill-base.sh`, `check-deploy-freshness.sh`,
   `regeneration-is-manual-only.md`) is missing `scripts/update-task-status.sh` (Finding A/B) and
   likely `commands/implement.md` (Finding E's Step 4 trigger) and
   `context/patterns/batch-orchestration-guardrails.md` (if the mechanism is documented there,
   Finding G). The planning phase should explicitly widen `file_scope` before implementation
   rather than discovering this mid-implementation.
5. **Do not touch `skill-implementer/SKILL.md`, `skill-orchestrate/SKILL.md`, or any other skill
   file** if the unconditional-backstop design (point 2) is adopted — this is the main appeal of
   that design over a new opt-in flag.

## Decisions Needed (for the planning phase, not resolved here)

- **Opt-in flag vs. unconditional backstop** in `update-task-status.sh` (Finding B). This report
  recommends unconditional, matching the task's unqualified acceptance language and avoiding
  edits outside the admitted file_scope, but the plan should state this explicitly rather than
  inherit it silently.
- **Whether `/orchestrate`'s Stage MT-3 step 7 predicate is widened** to `agent-system/
  extensions/**` (folding this task's general guarantee into the existing mechanism, one
  carve-out, one baseline system) **or kept narrow** with a second, parallel checkpoint for the
  general case (Finding E's third bullet). Widening is architecturally simpler but changes an
  existing, heavily cross-referenced mechanism's meaning; the plan should weigh this explicitly
  rather than default to whichever is easiest to code first.
- **Target status on refusal**: this report recommends "stay at `implementing`, ordering
  constraint, resumable next `/implement`" (mirroring phase-check exactly) over transitioning to
  `blocked` (also a valid `update-task-status.sh postflight` target, per
  `context/standards/status-markers.md`'s `[BLOCKED]` semantics — "task blocked," needs external
  unblocking). Either is defensible; the plan should pick one and state why. `blocked` more
  strongly signals "needs a human/redeploy action," but `implementing` is more consistent with
  the phase-check precedent's self-resuming ordering-constraint shape and needs no new field
  bookkeeping (`resume_phase` already exists and is already being written by that same code
  path).

## Risks & Mitigations

- **Risk**: unconditional backstop with no baseline comparison bricks all meta-task completion
  given today's measured pre-existing `deploy-headless.sh` exit-3 state (Finding D). **Mitigation**:
  mandatory baseline-relative comparison, reused from the existing checkpoint mechanism, not
  reimplemented.
- **Risk**: parallel per-task postflight calls race concurrent `deploy-headless.sh` invocations
  (Finding E). **Mitigation**: check-only backstop; auto-deploy trigger confined to already-serial
  call sites.
- **Risk**: scope creep into `skill-implementer/SKILL.md` or other skill files to thread a new
  flag, exceeding the admitted `file_scope`. **Mitigation**: unconditional-backstop design
  (Decision 1) avoids this entirely.
- **Risk**: carve-out drift — a future automated caller added without recording its own exception,
  the exact failure mode `regeneration-is-manual-only.md`'s existing exception already warns
  against. **Mitigation**: this report's Finding G gives the exact placement and content shape to
  follow; the plan should treat writing it as a first-class, separately-reviewable deliverable,
  not an afterthought.

## Context Extension Recommendations

None beyond what Findings F and H already identify as documentation gaps to close as part of this
task's own implementation (they are in-scope corrections to files already in the widened
`file_scope`, not a request for new standalone context files).

## Appendix

**Files read**: `specs/state.json` (task 83 entry), `agent-system/extensions/core/scripts/{check-
deploy-freshness.sh, command-gate-in.sh, command-gate-out.sh, skill-base.sh (excerpts),
update-task-status.sh (excerpts)}`, `agent-system/extensions/core/context/patterns/{regeneration-
is-manual-only.md, batch-orchestration-guardrails.md (excerpts), file-footprint-overlap.md}`,
`agent-system/extensions/core/context/reference/orchestrator-critical-paths.json`,
`agent-system/extensions/core/context/standards/status-markers.md` (excerpts),
`agent-system/extensions/core/commands/{implement.md, orchestrate.md}` (excerpts),
`agent-system/extensions/core/skills/{skill-implementer, skill-orchestrate}/SKILL.md` (excerpts),
`agent-system/extensions/core/context/formats/return-metadata-file.md` (excerpts).

**Commands run**: `jq` queries against `specs/state.json` and `.claude-extensions.json`;
`git log`/`git -C ... rev-parse`/`diff` comparisons of deployed vs. source `skill-base.sh`;
`bash .claude/scripts/check-deploy-freshness.sh` (live run, confirmed always-exit-0 WARN-only
behavior and current `core` staleness reason).

**No web research was needed** — this is a fully internal architecture question with the
governing precedent (`--phase-check`, the Inter-Cycle Redeploy Checkpoint, the Blocking vs.
Advisory criterion) already documented in the repository.

# Implementation Plan: Give the inter-cycle redeploy checkpoint a pre/post baseline

- **Task**: 966 - Give the inter-cycle redeploy checkpoint a pre/post baseline
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: 967 (batch-ordering edge; no file-scope overlap — see Scope Notes)
- **Research Inputs**: specs/966_add_baseline_to_intercycle_redeploy_checkpoint/reports/01_verify-deploy-baseline-design.md
- **Artifacts**: plans/01_redeploy-checkpoint-baseline.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`verify-deploy.sh` reports the deployed tree's absolute state and has no baseline notion, so the
inter-cycle redeploy checkpoint cannot distinguish "this redeploy broke the tree" from "this tree
was already broken before I touched it". Any standing repo-wide lint failure therefore converts a
multi-task `/orchestrate` batch into run-one-task-then-defer. This plan adds an additive
`--findings` mode to `verify-deploy.sh` that emits a normalized, one-per-line, machine-diffable
findings set across all four gates; has the orchestrator capture that set once immediately before
`deploy-headless.sh` and once after, and defer only on the set difference; and rewrites the
authoritative failure contract to describe the resulting THREE operator-visible states. Done when
a batch with a pre-existing verify failure runs to completion while reporting that failure loudly
at every checkpoint firing, a batch whose redeploy introduces a NEW finding still defers every
remaining task, and `deploy-headless.sh` failure still defers unconditionally with no baseline
consultation.

### Research Integration

The research report is integrated as the design spine of Phases 1-5:

- **Gate-by-gate itemization audit**: gates 1-2 already itemize (their `fail()` writes
  unconditionally, ignoring `--quiet`); gates 3-4 collapse an arbitrary number of underlying
  findings into one aggregate line each by discarding sub-script output to `/dev/null`. Phase 1
  fixes exactly that discard, without touching either wrapped script.
- **The `--quiet` asymmetry**: `check-extension-docs.sh`'s `FAIL:`/`ADVISORY:` lines and its
  `[ext_name]` headers survive `--quiet`; `check-task-references.sh`'s per-finding
  `path:line:content` lines do NOT (they are gated by its own `info()`). Gate 3 therefore captures
  the existing `--quiet` invocation; gate 4 must re-invoke WITHOUT `--quiet` to get detail.
- **Existing precedent reused, not reinvented**: `verify-deploy.sh`'s gate-3 `STRICT_CORE_DEPLOY`
  block already re-invokes a sub-script and greps its captured output for a stable token. Phase 1
  generalizes that shape rather than introducing a new mechanism.
- **Exit-2 resolution**: folded into the ordinary findings vocabulary via one synthesized sentinel
  line, so the pre/post comparison stays a single uniform set difference with no special case.
- **Reporting vocabulary**: the loud-banner + HTML-comment machine-marker pattern already used by
  the `ZERO DISPATCH` section in `commands/orchestrate.md` (same family as `[SPARSE COVERAGE ...]`
  / `[UNVERIFIED ...]`).
- **Ledger placement**: a new `verify_deploy_baseline_notices` field rather than overloading
  `defer_ledger`, because `defer_ledger`'s own contract scopes it to defer/exclusion events and
  the third state excludes nothing.

Two research recommendations are deliberately narrowed by this plan; both are recorded under
Decisions below: advisory lines are excluded from the gate-3 findings set, and count-bearing
finding text is normalized before comparison.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no `roadmap_path` in the delegation context).

## Scope Notes

### Scope note 1: `skill-orchestrate-hard/SKILL.md` co-maintenance obligation (OUT OF DECLARED SCOPE)

`agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` carries a **Transcribed:
inter-cycle redeploy checkpoint** block under an explicit contract: "an edit to either copy
REQUIRES the same edit to the other; the two MUST always agree." That block restates the
`deploy-headless.sh` / `verify-deploy.sh` invocation order and the failure branch this plan
changes. The file is **not** in this task's declared `file_scope`.

This plan does **not** silently expand scope to edit it. Phase 6 handles the obligation as
follows, and Phase 6 is the ONLY phase permitted to touch this subject:

- **Default path (scope unchanged)**: Phase 6 writes nothing outside `specs/**`. It records the
  divergence in the implementation summary and in `.orchestrator-handoff.json`'s `blockers` array,
  with the exact replacement text the mirror edit would need, so a follow-up task can land it
  mechanically.
- **Conditional path**: if, at implementation time, `skill-orchestrate-hard/SKILL.md` is present in
  this task's `file_scope` in `specs/state.json` (i.e. an operator extended it before dispatch),
  Phase 6 performs the mirror edit instead. The implementer MUST check `file_scope` and record
  which path was taken; it MUST NOT extend `file_scope` itself.

Mitigating context, verified from `skill-orchestrate/SKILL.md`'s own `mt_state_file` schema block:
`skill-orchestrate-hard` has **no MT-stage implementation of its own** — when `multi_task_mode` is
true it uses the base multi-task stages in `skill-orchestrate/SKILL.md`. The hard-mode block is
therefore a documentation mirror, not a second executable copy. Landing Phases 1-5 without it
produces a documentation inconsistency, not a behavioral divergence between the two engines. That
is a real, named defect to be closed — not a behavioral regression.

### Scope note 2: the `967` dependency edge

`specs/state.json` records `dependencies: [967]` for this task. That task's `file_scope`
(`git-commit-scoped.sh`, `git-staging-scope.md`) does not overlap this task's at all, and its
subject is never mentioned in this task's description. The research flagged this as a probable
artifact of a batch-ordering pass rather than a design constraint. No phase of this plan depends
on it. Recorded, not acted on.

### Scope note 3: concurrent-edit hazard on `skill-orchestrate/SKILL.md`

Three other not-yet-started tasks declare `skill-orchestrate/SKILL.md` in their `file_scope`, and
one also declares `commands/orchestrate.md`. `/orchestrate`'s admission gate never co-dispatches
overlapping file scopes, so no dependency edge is needed. An implementer should expect to rebase
onto whichever lands first and must not mistake that conflict for a defect.

## Goals & Non-Goals

**Goals**:

- Add an additive `--findings` output mode to `verify-deploy.sh` that emits a normalized, sorted,
  deduplicated, one-per-line findings set covering all four gates plus a "could not run" sentinel.
- Make the inter-cycle redeploy checkpoint capture a pre-redeploy baseline and defer on the SET
  DIFFERENCE (newly-introduced findings) rather than on the raw exit code.
- Introduce a THIRD operator-visible state — checked, broken, already broken, proceeded
  deliberately — reported as loudly as an outright failure, with a banner, a machine marker, a
  durable `mt_state_file` ledger field, and its own rendered output section.
- Rewrite the authoritative `### The Inter-Cycle Redeploy Checkpoint` **Failure contract**
  paragraph into a three-branch statement, and explicitly resolve `verify-deploy.sh` exit 2.
- Preserve defer-not-fail, the rejection of abort, and the rejection of silent-continue.

**Non-Goals**:

- Changing `deploy-headless.sh` in any way. Its failure keeps deferring unconditionally, with no
  baseline consultation.
- Changing `check-extension-docs.sh` or `check-task-references.sh`. Neither needs a change; only
  `verify-deploy.sh`'s own discard-to-`/dev/null` stops discarding.
- Changing the checkpoint trigger, the `deployed_critical_paths` idempotence guard, the Stage MT-4
  step 5.5 sequencing guarantee, or the `specs/.deploy-lock/` mutex.
- Changing `verify-deploy.sh`'s exit codes or its narrative output when `--findings` is absent.
- Editing anything under `.claude/**` (gitignored disposable deploy artifact).
- Adding a new admission gate. `verify_deploy_baseline_notices`, like `defer_ledger`, is
  write-only observation and MUST never be read by any eligibility check.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A baseline quietly swallows a real failure (constraint 2 violated) | H | M | The third state is never silent: loud banner + machine marker + durable ledger entry + its own rendered output section, all required by Phase 2's contract text and verified in Phase 7 |
| Non-determinism in the findings set manufactures a spurious "new" finding, deferring a healthy batch | M | M | `sort -u` at the point of capture in BOTH runs; count-bearing finding text normalized (Decision 4); identical invocation shape for pre and post |
| A newly-introduced failure hides inside an already-failing gate | H | M | Line-level, not exit-code-level and not per-gate-boolean-level, comparison — this is the crux the task description names |
| Default-mode `verify-deploy.sh` behavior drifts | H | L | Phase 1 verification requires byte-identical stdout/stderr/exit for a no-flag run captured before and after the edit |
| A new ADVISORY line from doc-lint defers a batch even though advisories are non-blocking | M | M | Gate-3 findings include only `FAIL:` lines, never `ADVISORY:` (Decision 3) |
| Documentation divergence with the hard-mode transcribed block | M | H | Scope note 1 above; Phase 6 records the divergence explicitly and supplies the exact replacement text |
| Doubled `verify-deploy.sh` cost per checkpoint firing | L | H | Bounded: the checkpoint is already gated by trigger + idempotence guard, and all four gates are lightweight |
| Task-number citations leak into deliverables | M | M | Every phase's tasks specify durable anchors (script names, stage labels, section headings); Phase 7 runs `check-task-references.sh` |

## Decisions

These are settled by this plan. An implementer changing one must record it as a deviation.

1. **Findings prefix and capture shape.** Every finding line begins with the literal token
   `FINDING ` followed by a gate label (`gate0`..`gate4`). The caller invokes
   `bash .claude/scripts/verify-deploy.sh --findings --quiet` and filters with
   `grep '^FINDING ' | sort -u`. The prefix filter is load-bearing: `verify-deploy.sh`'s final
   PASS line is an unconditional stdout `echo` and would otherwise pollute the captured set.
2. **Exit 2 is folded into the findings vocabulary, not special-cased.** Each exit-2 branch emits
   exactly one `FINDING gate0 verify-deploy could not run: <reason>` line before exiting, when
   `--findings` has already been parsed. Consequences, stated so no branch falls through:
   - `PRE_EXIT == 2` and `POST_EXIT == 2` with the same reason → sentinel present in both sets →
     empty difference → **third state**: proceed, reported loudly as "could not run, before or
     after this redeploy — pre-existing condition".
   - `PRE_EXIT` is 0 or 1 and `POST_EXIT == 2` → sentinel present only post → non-empty difference
     → **defer**, unchanged. A redeploy that succeeded yet cannot be verified at all is exactly
     the verification gap the checkpoint exists to catch, never something to wave through on a
     pre-existing-failure technicality.
3. **Gate 3 findings include `FAIL:` lines only, never `ADVISORY:`.** This narrows the research's
   recommendation. `check-extension-docs.sh` exits non-zero only on `FAIL`; treating a new advisory
   as a newly-introduced finding would defer a batch on a non-blocking signal and silently promote
   advisories to blocking.
4. **Finding text is normalized to be count-free before comparison.** The gate-3
   `STRICT_CORE_DEPLOY` message embeds a numeric count; emit the finding without it (the condition
   is boolean — "the deploy tree is behind the source store"). Magnitude drift inside an
   already-failing check must not manufacture a "new" finding. A genuinely redeploy-introduced
   instance still appears as absent→present, which the diff catches.
5. **The third state updates `deployed_critical_paths`, exactly as the success path does.** The
   redeploy mechanically succeeded; only the standing lint state is unhealthy. Without this, the
   idempotence guard would re-fire the checkpoint every cycle on the same paths purely because a
   pre-existing failure is still present.
6. **The third state is NOT a `defer_ledger` entry.** `defer_ledger`'s contract scopes it to
   defer/exclusion events; the third state excludes nothing. It gets its own field,
   `verify_deploy_baseline_notices`.
7. **The third state does NOT flip the batch exit status to `"partial"`.** A batch that ran to
   completion past a pre-existing failure is `"implemented"`. Stage MT-5's three-branch resolution
   must not consult `verify_deploy_baseline_notices`.
8. **The baseline is captured immediately before `deploy-headless.sh`**, not at some earlier fixed
   point, so it reflects the tree as it stood right before this specific redeploy. When
   `deploy-headless.sh` then fails, the captured baseline is simply discarded — the deferral is
   unconditional and consults nothing (constraint 5).

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4, 6 | 3 (phase 4); 2, 3 (phase 6) |
| 4 | 5 | 3, 4 |
| 5 | 7 | 1, 2, 3, 4, 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add the `--findings` mode to `verify-deploy.sh` [COMPLETED]

**Goal**: `verify-deploy.sh --findings --quiet` emits a normalized, sorted, deduplicated,
one-per-line findings set covering all four gates plus the exit-2 sentinel, with default-mode
behavior (narrative output and exit codes 0/1/2) byte-for-byte unchanged.

**Tasks**:

- [x] Add a `--findings` flag to the argument loop (`FINDINGS=false` default), and extend the
      `Usage:` and `Exit codes:` header block to document the mode, its output contract (`FINDING `
      prefix, gate labels, `sort -u` at the caller), and its additive-only guarantee. Note in the
      header that the checkpoint is its automated consumer and cross-reference
      `context/patterns/batch-orchestration-guardrails.md`'s `### The Inter-Cycle Redeploy
      Checkpoint` subsection by path (the file already does this — extend, do not duplicate).
      *(completed)*
- [x] Introduce a `FINDINGS_LIST` accumulator and a `CURRENT_GATE` variable set to `gate1`..`gate4`
      immediately before each numbered gate section. Extend `fail()` to append
      `FINDING $CURRENT_GATE $1` to the accumulator. `fail()`'s existing stderr output, counters,
      and `return 0` are unchanged — this is a second consumer of the SAME single source, not a
      duplicated message. *(deviation: altered — `fail()` also accepts an optional 3rd argument
      that overrides (or, if passed empty, suppresses) the default `$1` finding text; needed so
      the gate-3 `STRICT_CORE_DEPLOY` sub-check can omit its embedded count (Decision 4) and so
      the two aggregate gate-3/gate-4 `fail()` calls can suppress their own generic finding in
      favor of the per-underlying-finding lines extracted separately. The unmodified two-arg call
      shape used by every other `fail()` call site is untouched.)*
- [x] Emit the exit-2 sentinel `FINDING gate0 verify-deploy could not run: <reason>` on the two
      tree-condition exit-2 branches (target is not a directory; no `.claude/` deploy tree), and on
      the unknown-flag branch when `--findings` has already been parsed at that point. Emit only
      when `FINDINGS=true`. Document in the header that an unknown-flag exit 2 is a caller-side bug
      that both baseline runs hit identically, and is surfaced by the caller's loud banner.
      *(completed)*
- [x] **Gate 3**: replace `>/dev/null 2>&1` with a capture-to-variable of the same
      `check-extension-docs.sh --quiet` invocation (observationally identical — the output was
      already discarded). Keep the pass/fail branch driven by the captured exit status, unchanged.
      When `FINDINGS=true` and the gate failed, extract every `FAIL:` line, attribute it to the
      most recent `[ext_name]` / `[project-wide]` header seen, and append one
      `FINDING gate3 [<ext>] FAIL: <text>` line per finding. Exclude `ADVISORY:` lines
      (Decision 3). *(completed: verified live against this repo's current standing doc-lint
      failure — extraction produced 4 correctly-attributed `[core]` findings)*
- [x] **Gate 3, `STRICT_CORE_DEPLOY` sub-check**: emit its finding without the numeric count
      (Decision 4). *(completed)*
- [x] **Gate 4**: leave the `check-task-references.sh --quiet >/dev/null 2>&1` gate invocation
      verbatim. When `FINDINGS=true` AND that gate failed, re-invoke WITHOUT `--quiet`, capture
      stdout, and append each `path:line:content` finding line as
      `FINDING gate4 <path>:<line>:<content>`. This re-invocation mirrors the existing
      `STRICT_CORE_DEPLOY` re-invocation precedent in the same file. Add an inline comment stating
      WHY the two gates' `--quiet` handling is asymmetric (gate 3's detail survives `--quiet`;
      gate 4's does not). *(completed: verified with simulated non-quiet output since this repo's
      live gate 4 currently passes with zero findings)*
- [x] Print the accumulated findings, `sort -u`, to **stdout** after the final narrative PASS/FAIL
      line, when `FINDINGS=true` — including on a passing run (an empty set is a valid, meaningful
      result). Findings go to stdout so a `--quiet` caller's command substitution captures them;
      the FAIL narrative stays on stderr as today. *(completed)*
- [x] Confirm no task-number citation appears in any added line (deliverable rule). *(completed:
      no digit-bearing task citation in any added line)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts a **four-gate** findings surface plus one `gate0`
sentinel, and asserts that `check-extension-docs.sh` and `check-task-references.sh` need NO
changes. Confirm at implementation time by (a) re-reading both wrapped scripts' `fail()`,
`advisory()`, and `info()` bodies to verify which output survives `--quiet`, and (b) running each
wrapped script directly with and without `--quiet` against this repo and diffing the captured
output. If either assertion fails, record the deviation and widen only this phase.

**Files to modify**:

- `agent-system/extensions/core/scripts/verify-deploy.sh` — `--findings` flag, `FINDINGS_LIST`
  accumulator, `CURRENT_GATE` labels, `fail()` extension, exit-2 sentinels, gate-3 capture, gate-4
  conditional re-invocation, sorted findings output block, header documentation.

**Verification**:

- `bash -n agent-system/extensions/core/scripts/verify-deploy.sh` exits 0.
- **Default-mode invariance**: capture `bash <script> ; echo "exit=$?"` (stdout and stderr
  separately) from the pre-edit file and from the post-edit file against the same tree; the two
  must be byte-identical. Use `git stash`-free comparison via `git show HEAD:<path>` into a temp
  copy — never a destructive git operation on a dirty tree.
- `bash <script> --findings --quiet | grep -c '^FINDING '` returns a plausible count for this
  repo's CURRENT standing state, and each line names a gate label in `gate0`..`gate4`.
- Two consecutive `--findings --quiet` runs against an unmodified tree produce identical
  `sort -u` output (determinism check).
- A deliberately induced gate-1 failure (temporarily rename one deployed event-store file in a
  scratch copy of a deploy tree, never the live one) adds exactly one new `FINDING gate1` line and
  changes nothing else.
- Passing `--findings` against a nonexistent target emits exactly one `FINDING gate0` line and
  exits 2.

---

### Phase 2: Rewrite the authoritative failure contract [COMPLETED]

**Goal**: the `### The Inter-Cycle Redeploy Checkpoint` subsection's **Failure contract**
paragraph states the three-branch behavior, names the third operator-visible state, and resolves
exit 2 — with no other property of the subsection altered.

**Tasks**:

- [x] Replace the **Failure contract** paragraph in
      `context/patterns/batch-orchestration-guardrails.md` with a three-branch statement:
      (a) `deploy-headless.sh` failure → defer all remaining not-yet-dispatched tasks
      unconditionally, no baseline consultation, unchanged; (b) `verify-deploy.sh` failure with at
      least one newly-introduced finding relative to the pre-redeploy baseline → defer, unchanged
      in spirit, now finding-level rather than exit-code-level; (c) `verify-deploy.sh` failure
      whose findings are ALL present in the pre-redeploy baseline → proceed, reported loudly.
      *(completed)*
- [x] Preserve verbatim the existing rejections and their reasoning: abort is rejected (it discards
      `mt_state_file` bookkeeping for no benefit, since deferral already halts further exposure);
      silent-continue is rejected outright (the operator must always be able to distinguish "we
      didn't check" from "we checked, it's broken, and we proceeded anyway"). Keep the existing
      cross-reference to the `## Defer-Not-Fail: The Standing Default` section. *(completed)*
- [x] Add the third state's definition explicitly: "we checked, it's broken, it was ALREADY broken
      before this redeploy, and we proceeded deliberately" — and state that it is announced as
      loudly as an outright failure via a banner, a machine marker, and a durable
      `verify_deploy_baseline_notices` record. State that a baseline must never become a mechanism
      for quietly swallowing failures. *(completed)*
- [x] Add a short **Baseline mechanism** paragraph: the comparison is a sorted, deduplicated,
      line-level set difference over `verify-deploy.sh --findings --quiet` output, captured once
      immediately before `deploy-headless.sh` and once after; exit-code-only comparison is
      explicitly insufficient because a gate failing with 2 findings and the same gate failing with
      5 findings (3 of them new) produce the identical non-zero exit. *(completed)*
- [x] Add an **Exit-2 resolution** paragraph recording Decision 2 above, including why the
      asymmetric case (baseline established, post-redeploy unverifiable) defers. *(completed)*
- [x] Add a one-line **Rejected alternative** entry: "exit-code-only baseline comparison" —
      rejected for the masking reason above, recorded so a later pass cannot rediscover it.
      *(completed)*
- [x] Leave the Trigger, `modified_files` rationale, Sequencing, Idempotence guard, and Concurrency
      paragraphs untouched. Leave the "cross-references this subsection by path rather than
      restating it" sentence and its file list intact. *(completed: single contiguous diff hunk,
      confirmed via `git diff --unified=0`)*
- [x] Use durable anchors only — no task numbers (deliverable rule). *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — the
  **Failure contract** paragraph of `### The Inter-Cycle Redeploy Checkpoint`, plus the new
  Baseline mechanism, Exit-2 resolution, and one Rejected alternative entry.

**Verification**:

- Diff read-through confirms every changed hunk lies inside the `### The Inter-Cycle Redeploy
  Checkpoint` subsection.
- `grep -n 'defer all remaining not-yet-dispatched tasks'` shows the phrase surviving in branch
  (a) and branch (b), not deleted wholesale.
- `grep -n 'silently continue\|silent-continue'` still returns the preserved rejection.
- `grep -rn 'task [0-9]' ` over the changed hunks returns nothing.
- The `## Defer-Not-Fail: The Standing Default` section is unmodified.

---

### Phase 3: Rewrite Stage MT-3 step 7 and extend the `mt_state_file` schema [COMPLETED]

**Goal**: the checkpoint implementation in `skill-orchestrate/SKILL.md` captures a baseline,
diffs it, and branches three ways — with the trigger, idempotence guard, and sequencing guarantee
untouched.

**Tasks**:

- [x] In the `mt_state_file` schema block, add a field definition alongside
      `deferred_deploy_checkpoint` / `deployed_critical_paths`:
      `verify_deploy_baseline_notices: []` — an APPEND-ONLY OBSERVATION LOG of every checkpoint
      firing that proceeded past a pre-existing `verify-deploy.sh` failure, entries of the form
      `{"cycle": <int>, "gate": "verify-deploy.sh", "pre_findings": <int>, "post_findings": <int>, "new_findings": 0, "post_exit": <int>}`.
      Carry the same MUST NOT the `defer_ledger` definition carries: never read by any eligibility
      check, all-terminal check, circuit breaker, convergence guard, or admission branch; written
      for reporting only, read at Stage MT-5 and by `commands/orchestrate.md` Step 5.
      State explicitly that it is NOT a defer/exclusion set and is never merged into
      `defer_ledger`. *(completed)*
- [x] In Stage MT-3 step 7, leave the **Sequencing guarantee**, **Overlap computation**, and
      **Idempotence guard** bullets byte-for-byte unchanged. *(completed: diff read-through
      confirms these three bullets are untouched)*
- [x] Rewrite the **Fire** bullet: immediately before `deploy-headless.sh`, capture
      `PRE_FINDINGS=$(bash .claude/scripts/verify-deploy.sh --findings --quiet | grep '^FINDING ' | sort -u)`
      and `PRE_EXIT`. Then run `deploy-headless.sh` exactly as today. *(completed)*
- [x] Add an explicit **`deploy-headless.sh` failure branch** stated BEFORE any baseline logic:
      non-zero exit → defer unconditionally exactly as today, with NO baseline consultation
      whatsoever; `PRE_FINDINGS`/`PRE_EXIT` are discarded in this branch. Keep the existing
      `defer_ledger` append with `"detail": "deploy-headless.sh exit {exit_code}"`. *(completed:
      the branch's own paragraph names neither `PRE_FINDINGS` nor `PRE_EXIT`, confirmed by grep)*
- [x] On `deploy-headless.sh` success, capture `POST_FINDINGS` / `POST_EXIT` with the identical
      invocation shape at the same call site the plain `verify-deploy.sh` call occupies today.
      *(completed)*
- [x] **Success path (`POST_EXIT == 0`)**: unchanged — record matched critical paths into
      `deployed_critical_paths`, log deployed artifact count and a `verify-deploy` pass, continue.
      State that `PRE_FINDINGS` is unused in this branch. *(completed)*
- [x] **`POST_EXIT` non-zero**: compute `NEW_FINDINGS` as the set difference
      `POST_FINDINGS - PRE_FINDINGS` (e.g. `comm -13` over the two sorted, deduplicated sets), then
      branch:
      - **`NEW_FINDINGS` empty → the third state.** Log the banner
        `[PRE-EXISTING VERIFY-DEPLOY FAILURE - N finding(s) predate this redeploy, 0 newly introduced; batch continuing]`
        and the machine marker
        `<!-- verify-deploy-baseline pre={pre_count} post={post_count} new=0 proceeded=true -->`.
        Record matched critical paths into `deployed_critical_paths` (Decision 5). Do NOT add any
        task to `deferred_deploy_checkpoint`. Do NOT append to `defer_ledger` (Decision 6). Append
        one entry to `verify_deploy_baseline_notices`. Continue to the next cycle.
      - **`NEW_FINDINGS` non-empty → the existing failure path, unchanged in shape.** Add every
        non-terminal, non-`failed_tasks` task in `task_numbers` to `deferred_deploy_checkpoint`;
        never add to `failed_tasks`; never status-mutate; never abort. Keep the operator remedy in
        the warning. Enrich the `defer_ledger` `detail` field to name the new findings — count
        first, then the finding text itself as token budget allows, e.g.
        `"verify-deploy.sh exit 1 (2 new finding(s) vs. pre-redeploy baseline: <finding>; <finding>)"`.
      *(completed)*
- [x] Retain the closing bullet that already-dispatched-and-committed tasks from prior cycles are
      unaffected by any path. *(completed)*
- [x] Update the step's opening cross-reference sentence to keep pointing at the authoritative
      subsection for the full contract — reference by path, do not restate the contract here.
      *(completed: unchanged, already conformant)*
- [x] Use durable anchors only — no task numbers (deliverable rule). *(completed)*

**Timing**: 1.25 hours

**Depends on**: 1, 2

**Verification Tier**: interface

**Scope Hypothesis**: this phase asserts that Stage MT-3 step 7 and the `mt_state_file` schema
block are the ONLY two regions of `skill-orchestrate/SKILL.md` that describe the checkpoint's
fire/failure logic. Confirm by running
`grep -n 'verify-deploy\|deploy-headless\|deferred_deploy_checkpoint\|deployed_critical_paths'`
over the whole file at implementation time and checking every hit falls in one of those two
regions or in Stage MT-5 (which Phase 4 owns). Record any third region found as a deviation.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — the `mt_state_file` schema
  block (new field definition) and Stage MT-3 step 7 (Fire, deploy-headless failure branch,
  success path, three-way `POST_EXIT` branching).

**Verification**:

- Diff read-through confirms the Sequencing guarantee, Overlap computation, and Idempotence guard
  bullets are unchanged.
- `grep -n 'deployed_critical_paths'` confirms the third-state branch records into it, matching the
  success path.
- `grep -n 'defer_ledger'` confirms the third state does NOT append to it and the defer branch
  still does.
- The `deploy-headless.sh` failure branch appears textually BEFORE any `PRE_FINDINGS` consultation.
- No task-number citation in the changed hunks.

---

### Phase 4: Carry the new field through Stage MT-5 reporting and the batch handoff [NOT STARTED]

**Goal**: `verify_deploy_baseline_notices` survives to the end of the batch and reaches the
consolidated-output renderer, without altering the batch exit-status resolution.

**Tasks**:

- [ ] Add `verify_deploy_baseline_notices` to the list of `mt_state_file` fields read at Stage MT-5
      (the same list that already names `deferred_deploy_checkpoint`, `dispatch_start_ts`,
      `defer_ledger`, `current_statuses`).
- [ ] Add an explicit statement to the Stage MT-5 exit-status resolution that
      `verify_deploy_baseline_notices` is NEVER consulted by the `"implemented"` / `"partial"` /
      `"failed"` branch selection (Decision 7): a batch that ran to completion past a pre-existing
      failure is `"implemented"`. State this as a deliberate decision so a later pass does not
      "fix" it into a partial.
- [ ] Add a Stage MT-5 reporting instruction: whenever `verify_deploy_baseline_notices` is
      non-empty, it MUST be reported as a distinct category — never folded into
      `deferred_deploy_checkpoint` reporting and never omitted because the batch succeeded.
- [ ] Add `--argjson verify_deploy_baseline_notices "$verify_deploy_baseline_notices"` and the
      corresponding `"verify_deploy_baseline_notices": $verify_deploy_baseline_notices` key inside
      the `metadata` object of the `specs/.return-meta-multi-${session_id}.json` jq emission. The
      top-level `status` vocabulary is unchanged and gains no new value.
- [ ] Use durable anchors only — no task numbers (deliverable rule).

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: local

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-5 field-read list,
  exit-status resolution note, reporting instruction, and the batch return-metadata jq emission.

**Verification**:

- The jq block's `--argjson` count matches its key count inside `metadata`.
- `grep -n 'verify_deploy_baseline_notices'` returns hits in exactly four places across the file:
  the schema definition (Phase 3), the third-state branch (Phase 3), the MT-5 read/report block,
  and the jq emission.
- The `"implemented"` / `"partial"` branch conditions are otherwise textually unchanged.

---

### Phase 5: Render the third state in the consolidated output [NOT STARTED]

**Goal**: an operator reading `/orchestrate`'s batch output cannot miss a pre-existing
verify-deploy failure, and the defer case's Reason text now names the newly-introduced findings.

**Tasks**:

- [ ] Add a new section to the Consolidated Output template in `commands/orchestrate.md`, sibling
      to and immediately following `### Deferred (redeploy checkpoint)`:
      `### Pre-Existing Deploy-Verify Failures (Not Deferred)`. Render it only when
      `verify_deploy_baseline_notices` is non-empty; state that it renders on SUCCEEDED batches
      too, not only partial ones.
- [ ] Inside it, render the banner
      `[PRE-EXISTING VERIFY-DEPLOY FAILURE - N finding(s) predate this redeploy, 0 newly introduced; batch continuing]`
      and the machine marker
      `<!-- verify-deploy-baseline pre={pre_count} post={post_count} new=0 proceeded=true -->`,
      following the same banner + HTML-comment shape the `### ZERO DISPATCH` section already uses.
- [ ] Add a table with columns `Cycle | Gate | Pre-existing findings | New findings | Outcome`,
      one row per `verify_deploy_baseline_notices` entry, plus a one-line note that these findings
      are REAL problems that were not introduced by this batch's redeploy, with the operator remedy
      (fix the standing failure; re-run `verify-deploy.sh` manually to confirm).
- [ ] Add a sentence covering Decision 2's symmetric exit-2 case: when `post_exit` is 2, the row's
      Outcome reads "verify-deploy could not run, before or after this redeploy — pre-existing
      condition".
- [ ] Cross-reference `context/patterns/batch-orchestration-guardrails.md`'s
      `### The Inter-Cycle Redeploy Checkpoint` subsection for the full contract, mirroring how
      `### Deferred (redeploy checkpoint)` already does. Do NOT restate the contract inline
      (constraint 3, cross-reference-by-path discipline).
- [ ] Update the `### Deferred (redeploy checkpoint)` table's Reason cell template so it names the
      newly-introduced findings rather than only `{gate}, exit {code}` — e.g.
      `inter-cycle redeploy checkpoint gate failed ({gate}, exit {code}; {n} new finding(s) vs. pre-redeploy baseline); not dispatched for the remainder of this invocation`.
      Leave that section's operator-remedy paragraph and its authoritative cross-reference intact.
- [ ] Use durable anchors only — no task numbers (deliverable rule).

**Timing**: 0.75 hours

**Depends on**: 3, 4

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/core/commands/orchestrate.md` — the Consolidated Output template: new
  `### Pre-Existing Deploy-Verify Failures (Not Deferred)` section and the
  `### Deferred (redeploy checkpoint)` Reason-cell text.

**Verification**:

- Diff read-through confirms every changed hunk lies inside the Consolidated Output template block.
- The new section's placement is adjacent to `### Deferred (redeploy checkpoint)` and before
  `### Next Steps`.
- `grep -n 'batch-orchestration-guardrails.md'` confirms the new section cross-references the
  authoritative subsection by path.
- No inline restatement of the failure contract appears in the new section (read-through against
  Phase 2's rewritten paragraph — the new section describes RENDERING, not the contract).
- No task-number citation in the changed hunks.

---

### Phase 6: Resolve the hard-mode co-maintenance obligation [NOT STARTED]

**Goal**: the divergence between the authoritative contract and the transcribed block in
`skill-orchestrate-hard/SKILL.md` is either closed (if scope permits) or recorded loudly with the
exact replacement text — never left silent, never resolved by silently expanding scope.

**Tasks**:

- [ ] Read this task's `file_scope` array from `specs/state.json` and determine whether
      `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` is present. Record the
      answer explicitly in the phase's progress record. MUST NOT edit `file_scope`.
- [ ] **If present**: perform the mirror edit on the **Transcribed: inter-cycle redeploy
      checkpoint** block — replace its single failure sentence with the same three-branch summary
      Phase 3 implemented, keeping the block a SUMMARY that cross-references the authoritative
      subsection by path rather than restating the full contract. Preserve the CO-MAINTENANCE note
      verbatim.
- [ ] **If absent (expected default)**: make NO edit outside `specs/**`. Instead write, in the
      implementation summary, a clearly-labelled section naming the file, the CO-MAINTENANCE
      contract it carries, the specific sentence that is now stale, and the exact replacement text
      a follow-up should apply. Add the same as a `blockers` entry in
      `.orchestrator-handoff.json`, with `description`, `evidence` (the stale sentence quoted), and
      `resolution` (extend `file_scope` or create a follow-up task scoped to that one file).
- [ ] Either way, record in the summary the verified mitigating fact that
      `skill-orchestrate-hard` has no MT-stage implementation of its own and uses the base
      multi-task stages, so the divergence is documentary rather than behavioral.

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Verification Tier**: prose

**Scope Hypothesis**: this phase assumes `skill-orchestrate-hard/SKILL.md` is the ONLY file
outside the declared `file_scope` carrying a stale transcription of the checkpoint's failure
behavior. Confirm at implementation time with
`grep -rln 'deferred_deploy_checkpoint\|verify-deploy.sh' agent-system/extensions/` and check every
hit against the declared `file_scope`. Any additional out-of-scope file found gets the same
record-do-not-edit treatment, and the deviation is recorded.

**Files to modify**:

- Default path: `specs/966_add_baseline_to_intercycle_redeploy_checkpoint/summaries/01_*.md` and
  `specs/966_add_baseline_to_intercycle_redeploy_checkpoint/.orchestrator-handoff.json` only.
- Conditional path (only if `file_scope` already contains it):
  `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`.

**Verification**:

- The summary names which path was taken and why, with the `file_scope` read quoted as evidence.
- If the default path was taken: `git status --short` shows no modification to
  `skill-orchestrate-hard/SKILL.md`.
- If the conditional path was taken: the CO-MAINTENANCE note survives verbatim and the block still
  cross-references the authoritative subsection by path.

---

### Phase 7: Verification-bar sweep [NOT STARTED]

**Goal**: every one of the six verification-bar criteria is demonstrated with evidence, and the
repo's own lint gates pass.

**Tasks**:

- [ ] **Criterion 6 first (cheapest)**: `bash -n` on every edited shell script. Only
      `verify-deploy.sh` is expected; confirm no other `.sh` was touched via `git status --short`.
- [ ] **Criterion 1** (pre-existing failure does not defer): with this repo's current standing
      `verify-deploy.sh` state, walk the rewritten Stage MT-3 step 7 against a captured
      `PRE_FINDINGS`/`POST_FINDINGS` pair produced by running the new mode twice against an
      unchanged tree. Demonstrate the difference is empty and the documented branch is the third
      state. Record the actual captured counts as evidence.
- [ ] **Criterion 2** (a newly-introduced failure still defers): construct the negative case by
      taking a `PRE_FINDINGS` capture, then inducing one additional finding (e.g. temporarily
      introduce a task-number citation in a scratch file inside a deliverable tree, or rename an
      event-store file in a scratch deploy copy), capturing `POST_FINDINGS`, and confirming
      `comm -13` yields exactly the induced line. Revert the induced condition and re-confirm the
      difference returns to empty. Never induce the condition in a way that requires a destructive
      git operation to undo.
- [ ] **Criterion 3** (`deploy-headless.sh` failure defers unconditionally): confirm by
      read-through that the `deploy-headless.sh` failure branch in Stage MT-3 step 7 appears before
      and independently of any baseline capture consultation, and that no baseline field is
      referenced inside it.
- [ ] **Criterion 4** (no deferred task is failed or status-mutated): `grep -n 'failed_tasks'` and
      `grep -n 'status-mutate'` across Stage MT-3 step 7 confirm the "never add to `failed_tasks`,
      never status-mutate, never abort" language survives in the defer branch and that the third
      state adds nothing to either.
- [ ] **Criterion 5** (authoritative subsection describes implemented behavior; no referring file
      restates it): read the rewritten subsection against Phases 1, 3, 4, and 5 for agreement, then
      `grep -rn 'The Inter-Cycle Redeploy Checkpoint' agent-system/extensions/core/` and confirm
      every referring file cross-references by path rather than restating the contract. Note the
      Phase 6 outcome for the hard-mode file explicitly here.
- [ ] Run `bash .claude/scripts/check-task-references.sh` and confirm the edited deliverables
      introduce no new finding (compare against the baseline captured at the start of this phase).
- [ ] Run `bash .claude/scripts/check-extension-docs.sh --quiet` and confirm no new `FAIL:` line
      relative to the same baseline.
- [ ] Write the implementation summary covering all six criteria with the evidence captured above,
      plus the Phase 6 scope-note outcome.

**Timing**: 1.0 hour

**Depends on**: 1, 2, 3, 4, 5, 6

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts exactly ONE edited shell script (`verify-deploy.sh`) and
exactly FOUR edited source-store files across Phases 1-5. Confirm with `git status --short` before
writing the summary; any additional file is a deviation to record, not to normalize.

**Files to modify**:

- `specs/966_add_baseline_to_intercycle_redeploy_checkpoint/summaries/01_redeploy-checkpoint-baseline-summary.md`

**Verification**:

- All six verification-bar criteria have a recorded evidence line in the summary — an unverifiable
  criterion is reported as unverified, never inferred.
- `git status --short` shows no modification under `.claude/**`.

---

## Testing & Validation

- [ ] `bash -n` clean on `verify-deploy.sh` (verification-bar criterion 6).
- [ ] Default-mode `verify-deploy.sh` output and exit code byte-identical to the pre-edit script.
- [ ] `--findings --quiet` output is deterministic across two consecutive runs on an unchanged tree.
- [ ] `--findings` against a nonexistent target emits exactly one `FINDING gate0` sentinel, exit 2.
- [ ] An induced new finding appears in `comm -13 <pre> <post>` and disappears on revert
      (verification-bar criteria 1 and 2).
- [ ] The `deploy-headless.sh` failure branch references no baseline field (criterion 3).
- [ ] Defer branch retains "never add to `failed_tasks`, never status-mutate, never abort"
      (criterion 4).
- [ ] The authoritative subsection matches implemented behavior and no referring file restates it
      (criterion 5).
- [ ] `check-task-references.sh` and `check-extension-docs.sh` introduce no new findings relative
      to the pre-implementation baseline.
- [ ] No file under `.claude/**` is modified.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/verify-deploy.sh` — additive `--findings` mode.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — rewritten
  **Failure contract** paragraph plus Baseline mechanism, Exit-2 resolution, and one rejected
  alternative.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — `mt_state_file` schema field,
  Stage MT-3 step 7 baseline/diff/three-branch logic, Stage MT-5 read + reporting + jq emission.
- `agent-system/extensions/core/commands/orchestrate.md` — new
  `### Pre-Existing Deploy-Verify Failures (Not Deferred)` section and enriched defer Reason text.
- `specs/966_add_baseline_to_intercycle_redeploy_checkpoint/summaries/01_redeploy-checkpoint-baseline-summary.md`
- `specs/966_add_baseline_to_intercycle_redeploy_checkpoint/.orchestrator-handoff.json` — including
  the Phase 6 co-maintenance record when the default path is taken.

## Rollback/Contingency

- Each phase commits separately per the per-substep commit mandate, so any single phase reverts
  with `git revert` of its own commit without disturbing the others.
- Phases 2-5 are documentation and skill-text edits with no runtime effect until an
  `/orchestrate` batch fires the checkpoint; reverting them restores the prior contract exactly.
- Phase 1 is additive by construction: with `--findings` absent, `verify-deploy.sh` behaves
  identically to today, so a partial landing of Phase 1 alone cannot break the existing checkpoint.
- If the baseline mechanism proves too permissive in practice, the narrowest rollback is to change
  the third-state branch in Stage MT-3 step 7 to defer as well — restoring today's behavior while
  keeping the loud reporting and the `--findings` mode in place. This is a one-branch edit, not a
  revert of the whole task.

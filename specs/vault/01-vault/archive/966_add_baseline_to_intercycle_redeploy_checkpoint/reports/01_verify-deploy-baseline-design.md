# Research Report: Give the Inter-Cycle Redeploy Checkpoint a Pre/Post Baseline

**Task**: 966 - Give the inter-cycle redeploy checkpoint a pre/post baseline
**Started**: 2026-07-29
**Completed**: 2026-07-29
**Effort**: medium (one script + two SKILL.md engines + one authoritative doc subsection)
**Dependencies**: task 967 (git-commit-scoped.sh fix — unrelated file scope; reason for the
  edge is not evident from either task's file_scope and was not chased further, see Appendix)
**Sources/Inputs**: codebase (`agent-system/extensions/core/scripts/verify-deploy.sh`,
  `check-extension-docs.sh`, `check-task-references.sh`, `deploy-headless.sh`,
  `skills/skill-orchestrate/SKILL.md`, `skills/skill-orchestrate-hard/SKILL.md`,
  `commands/orchestrate.md`, `context/patterns/batch-orchestration-guardrails.md`,
  `context/reference/orchestrator-critical-paths.json`, `docs/architecture/handoff-schema.md`)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md (all edits
  target `agent-system/extensions/core/**`, never `.claude/**`)

## Executive Summary

- The checkpoint's blind spot is real and precisely diagnosed by the task description: gates 1
  and 2 of `verify-deploy.sh` already itemize every failure (their `fail()` prints unconditionally,
  ignoring `--quiet`), but gates 3 and 4 wrap `check-extension-docs.sh` and
  `check-task-references.sh` with `--quiet >/dev/null 2>&1`, collapsing an arbitrary number of
  underlying findings into ONE aggregate line each ("doc-lint reported failures"). This is the
  exact granularity gap the task's design note warned about, and it is fixable without touching
  either wrapped script.
- Both wrapped scripts can already emit itemized, machine-diffable findings with no changes to
  themselves: `check-extension-docs.sh`'s `fail()`/`advisory()` and its `[ext_name]` section
  headers print unconditionally regardless of `--quiet` (only `info()` is quiet-gated), so
  capturing its output even with `--quiet` still passed already yields full per-extension,
  per-check detail. `check-task-references.sh` is the one case that needs `--quiet` DROPPED
  (not added) at the call site, because its per-finding `path:line:content` lines are gated by
  its own `info()`/`--quiet`, while only per-tree counts survive under `--quiet`.
- `verify-deploy.sh` already contains a precedent for exactly this "re-invoke a sub-script and
  grep its captured output for a stable token" pattern (lines 175-181, the `STRICT_CORE_DEPLOY`
  re-check for undeployed event files). The recommended design reuses that shape rather than
  inventing a new mechanism.
- Recommended design: add a `--findings` mode to `verify-deploy.sh` that, additively (never
  changing existing exit-code or narrative-output behavior when the flag is absent), emits a
  sorted, deduplicated, one-per-line set of normalized finding strings covering all four gates.
  The orchestrator runs this mode once immediately BEFORE `deploy-headless.sh` (the pre-redeploy
  baseline, against the tree as it stood before this cycle's redeploy) and once after (the
  existing post-redeploy check, unchanged in position), then diffs the two sorted sets.
  `exit 2` ("cannot run") is folded into the same findings vocabulary via one synthesized sentinel
  finding line rather than special-cased — this makes the pre/post comparison symmetric and
  answers the task's exit-2 open question without a side channel.
- A significant, currently out-of-file_scope risk: `skill-orchestrate-hard/SKILL.md` carries an
  explicitly-marked **CO-MAINTENANCE** transcription of the exact Stage MT-3 step 7 logic this
  task must change ("an edit to either copy REQUIRES the same edit to the other; the two MUST
  always agree" — `skill-orchestrate-hard/SKILL.md` lines 1381-1407), and
  `skill-orchestrate-hard/SKILL.md` is itself a declared entry in
  `context/reference/orchestrator-critical-paths.json`. Task 966's `file_scope` in
  `specs/state.json` does not list this file. This is flagged prominently in Risks below for the
  planner to resolve explicitly (recommended: extend `file_scope`).

## Context & Scope

The task asks for a pre/post baseline around the two-gate inter-cycle redeploy checkpoint
(`deploy-headless.sh` then `verify-deploy.sh`) documented authoritatively in
`context/patterns/batch-orchestration-guardrails.md`'s `### The Inter-Cycle Redeploy Checkpoint`
subsection and implemented at Stage MT-3 step 7 of `skills/skill-orchestrate/SKILL.md` (mirrored
in `skill-orchestrate-hard/SKILL.md`). Scope is baselining `verify-deploy.sh` results only;
`deploy-headless.sh` failure keeps deferring unconditionally per the task's binding constraint 5.
The research below covers (1) the mechanics of `verify-deploy.sh`'s four gates and exactly where
finding-level detail is currently lost, (2) a concrete, minimal-footprint design for capturing and
diffing findings, (3) how the three operator-visible states should be logged and rendered, and (4)
scope/consistency risks the planner needs to resolve.

## Findings

### Codebase Patterns

**`verify-deploy.sh`'s four gates, and where itemization already exists vs. is lost**
(`agent-system/extensions/core/scripts/verify-deploy.sh`):

| Gate | Check | Itemized today? | Why |
|------|-------|------------------|-----|
| 1 | 6 event-store files present | Yes | `fail()` (line 79-85) does a raw `echo ... >&2`, unconditional — `say()`'s `--quiet` gating only wraps `pass()`, not `fail()` |
| 2 | 3 hook registrations in settings.json | Yes | Same `fail()`, same reasoning |
| 3 | Doc-lint (`check-extension-docs.sh --quiet`) | **No** — one aggregate line | Sub-script invoked as `>/dev/null 2>&1`; all detail discarded before `verify-deploy.sh`'s own `fail()` ever sees it |
| 4 | Task-reference lint (`check-task-references.sh --quiet`) | **No** — one aggregate line | Same discard pattern |

**`check-extension-docs.sh` already itemizes even under `--quiet`.** Its `fail()`
(`agent-system/extensions/core/scripts/check-extension-docs.sh:101-106`) and `advisory()`
(:109-116) both call raw `echo`, not the `info()` wrapper that `--quiet` gates — confirmed by
reading the function bodies directly. The `[$ext_name]` / `[project-wide]` section headers
(lines 1040, 1076) are also unconditional `echo`. So `bash check-extension-docs.sh --quiet 2>&1`
(capturing stdout instead of discarding it) already yields a fully itemized, per-extension list
of `FAIL: ...` / `ADVISORY: ...` lines bracketed by `[ext_name]` headers — no change to this
script is needed.

**`check-task-references.sh` needs `--quiet` dropped, not kept, for finding-level capture.** Its
per-finding line (`info "  $rel:$finding"`, line 142) IS gated by its own `--quiet`; only the
per-tree occurrence counts and the final `PASS`/`FAIL` summary line (plain `echo`, unconditional)
survive under `--quiet`. Running it WITHOUT `--quiet` and capturing stdout yields the full
`path:line:content` finding lines needed for line-level diffing. This is the one asymmetry
between the two wrapped scripts that an implementer must get right: `check-extension-docs.sh`
should still be invoked with `--quiet` (its FAIL/ADVISORY detail already survives that), while
`check-task-references.sh` should be invoked WITHOUT `--quiet` when capturing for findings.

**Existing precedent for exactly this pattern.** `verify-deploy.sh` lines 175-181 already
re-invoke `check-extension-docs.sh` a second time under `STRICT_CORE_DEPLOY=1` purely to grep its
captured output for the stable substring `events-`, treating the sub-script as a machine-readable
source rather than only a human-facing pass/fail gate. The recommended `--findings` design below
is the same shape generalized: capture full output, extract a small set of stable, line-oriented
tokens, expose them for programmatic comparison.

**`deploy-headless.sh` is out of scope for baselining and needs no change.** Its own header
already documents it as the sanctioned automated-caller boundary and its lock/self-overwrite
handling is unrelated to this task; task constraint 5 (its failure is never baseline-consulted)
requires no code change to this script, only to the orchestrator-side branching that decides
whether to invoke `verify-deploy.sh` at all.

**Checkpoint mechanics that MUST survive unchanged** (per task constraint 4, and confirmed by
reading Stage MT-3 step 7 and the authoritative subsection directly):
- **Trigger**: union of this cycle's `modified_files`, overlapped against the `scope_roots x
  critical_paths` expansion of `context/reference/orchestrator-critical-paths.json` via the
  directory-prefix predicate in `context/patterns/file-footprint-overlap.md`.
- **Idempotence guard**: subtract `mt_state_file.deployed_critical_paths` from the overlap set
  before firing; unaffected by this change since it gates whether the checkpoint fires AT ALL,
  upstream of baselining.
- **Sequencing**: per-task commits at Stage MT-4 step 5.5 precede the checkpoint, unconditionally,
  already guaranteed by existing loop ordering.
- **Concurrency**: `specs/.deploy-lock/` mutex inside `deploy-headless.sh`, untouched.

**`orchestrator-critical-paths.json` self-reference.** `skill-orchestrate/SKILL.md`,
`skill-orchestrate-hard/SKILL.md`, `commands/orchestrate.md`, and `scripts/verify-deploy.sh` are
ALL themselves declared critical paths. This is why the batch this task was researched in used
`--allow-self-modifying` (self-modification would otherwise be admission-gated) and is also why
`skill-orchestrate-hard/SKILL.md`'s CO-MAINTENANCE risk (below) is not a minor formality — the
system's own critical-path list treats that file as first-class checkpoint machinery, same as
`skill-orchestrate/SKILL.md`.

### Design: Finding-Level Baseline Comparison

**1. New `--findings` mode on `verify-deploy.sh` (additive only).** When passed, in addition to
(never instead of) the existing narrative PASS/FAIL output and exit codes (0/1/2, byte-for-byte
unchanged), print a final block of normalized, one-per-line finding strings, e.g.:

```
FINDING gate1 scripts/events-append.sh is missing
FINDING gate2 PostToolUse -> events-log-artifact.sh NOT registered
FINDING gate3 [core] FAIL: manifest.json is not valid JSON
FINDING gate4 agent-system/extensions/foo/bar.md:12:See task 500 for context
```

Sources per gate:
- Gate 1/2: already-computed `fail()` messages — just also push them into a `FINDINGS` array
  (no duplicated logic; the existing `fail()` calls are the single source, only their message
  text also gets appended to `FINDINGS`).
- Gate 3: capture `check-extension-docs.sh --quiet`'s stdout (currently discarded), grep it for
  lines matching `FAIL:` or `ADVISORY:` prefixed by the most recent `[ext_name]` header seen, and
  push each as one `FINDING gate3 ...` line.
- Gate 4: capture `check-task-references.sh` WITHOUT `--quiet` (see asymmetry note above), and
  push each `path:line:content` line as one `FINDING gate4 ...` line.
- **`exit 2` sentinel**: both of `verify-deploy.sh`'s exit-2 early-return branches (target not a
  directory; no `.claude/` deploy tree) should emit exactly one synthesized line before exiting,
  e.g. `FINDING gate0 verify-deploy could not run: <reason>`. This folds "the script itself could
  not run" into the same comparable vocabulary as every other finding rather than requiring the
  orchestrator to special-case exit 2 — see the exit-2 resolution below.

Recommend a caller-facing invocation shape of `bash .claude/scripts/verify-deploy.sh --findings
[TARGET]`, sorted+deduplicated (`sort -u`) at the point of capture so incidental glob/jq ordering
never produces a spurious diff between two runs of an unchanged tree.

**2. Orchestrator-side algorithm (Stage MT-3 step 7 of both `skill-orchestrate/SKILL.md` and
`skill-orchestrate-hard/SKILL.md`)**, replacing only the **Fire**/**Failure path** logic and
leaving Overlap computation, Idempotence guard, and Success path (on `verify-deploy.sh` exit 0)
untouched:

1. Immediately before invoking `deploy-headless.sh`, capture the baseline:
   `PRE_FINDINGS=$(bash .claude/scripts/verify-deploy.sh --findings | sort -u)`, `PRE_EXIT=$?`.
   This runs against the tree as it stood before this cycle's redeploy — i.e. the state produced
   by whichever redeploy (or none) last ran, which is precisely "pre-existing" in the sense
   constraint 2 requires.
2. Run `deploy-headless.sh` exactly as today. **Non-zero exit → defer unconditionally, exactly as
   today, with no baseline consultation whatsoever** (constraint 5). `PRE_FINDINGS`/`PRE_EXIT` are
   simply discarded in this branch.
3. On `deploy-headless.sh` success, run `POST_FINDINGS=$(bash .claude/scripts/verify-deploy.sh
   --findings | sort -u)`, `POST_EXIT=$?` — same invocation shape as step 1, now against the
   freshly-redeployed tree. This REPLACES today's plain `verify-deploy.sh` call at the same call
   site; the narrative human output is unaffected since `--findings` is additive.
4. `POST_EXIT == 0` → **success path, unchanged**: record matched critical paths into
   `deployed_critical_paths`, log the deployed artifact count and a `verify-deploy` pass, continue
   to the next cycle. `PRE_FINDINGS` is unused in this branch.
5. `POST_EXIT != 0` (1 or 2): compute `NEW_FINDINGS = POST_FINDINGS - PRE_FINDINGS` (set
   difference over the sorted, deduplicated lines — `comm -13`).
   - **`NEW_FINDINGS` empty → the new third state.** Every failure `verify-deploy.sh` reports
     post-redeploy was already present pre-redeploy. Log the loud banner (see Reporting below),
     record the matched critical paths into `deployed_critical_paths` exactly as the success path
     does (the redeploy itself succeeded; only the standing lint state is unhealthy), do **not**
     add any task to `deferred_deploy_checkpoint`, and append an entry to the new observation
     ledger described below. Continue to the next cycle.
   - **`NEW_FINDINGS` non-empty → existing failure path, unchanged in shape, richer in detail.**
     Add every non-terminal, non-`failed_tasks` task in `task_numbers` to
     `deferred_deploy_checkpoint`, exactly as today. The `defer_ledger` `detail` field should now
     name the new findings (count and, token-budget permitting, the finding text itself) rather
     than only `"{failed_gate} exit {exit_code}"`, e.g.:
     `"verify-deploy.sh exit 1 (2 new finding(s) vs. pre-redeploy baseline: gate3 [foo] FAIL: ...; gate4 bar.md:9:...)"`.

**3. Exit-2 resolution, stated explicitly (the task requires this be decided, not left to fall
through).** Because the sentinel line in point 1 above makes "could not run" a normal member of
the findings vocabulary, no special-casing is needed beyond what the diff already does:
- `PRE_EXIT == 2`, `POST_EXIT == 2`, same target/reason → the sentinel line appears in both sets →
  `NEW_FINDINGS` is empty → third state (proceed, reported loudly: "verify-deploy could not run,
  before or after this redeploy — pre-existing condition"). This correctly treats "this tree was
  already unverifiable" as the pre-existing case the task's constraint 2 wants surfaced but not
  acted on.
- `PRE_EXIT` is 0 or 1 (a real baseline was established) and `POST_EXIT == 2` → the sentinel line
  is present only in `POST_FINDINGS` → `NEW_FINDINGS` non-empty → existing failure path (defer).
  This is the correct conservative default: a redeploy that just succeeded
  (`deploy-headless.sh` exit 0) yet cannot subsequently be verified at all is exactly the
  "verification gap" hazard the checkpoint exists to catch, never something to wave through on a
  pre-existing-failure technicality.
- No other combination needs a separate branch; the sentinel-as-ordinary-finding design collapses
  what would otherwise be a third special case into the same set-difference logic already used for
  every other gate.

### Reporting: the Third Operator-Visible State

Constraint 2 requires this state be reported "just as loudly" as an outright failure — never a
silent continue. Recommended vocabulary, modeled directly on the existing conventions already in
this codebase for exactly this kind of loud-but-non-blocking notice (the `[ZERO DISPATCH ...]`
banner + HTML-comment machine marker pattern in `commands/orchestrate.md`'s Consolidated Output,
and the `[SPARSE COVERAGE ...]` / `[UNVERIFIED ...]` family named in the project's literature
mode):

- **Banner**: `[PRE-EXISTING VERIFY-DEPLOY FAILURE - N finding(s) predate this redeploy, 0 newly
  introduced; batch continuing]`
- **Machine marker**: `<!-- verify-deploy-baseline pre={pre_count} post={post_count} new=0
  proceeded=true -->`
- **New `mt_state_file` field**, sibling to (not merged with) `defer_ledger` since this is
  explicitly a *non*-defer/exclusion event (`defer_ledger`'s own doc comment: "never read by any
  eligibility check ... entries of every per-cycle defer/exclusion event" — this event excludes
  nothing, so it does not belong there): `verify_deploy_baseline_notices: []`, entries of the
  shape `{"cycle": <int>, "gate": "verify-deploy.sh", "pre_findings": <int>,
  "post_findings": <int>, "new_findings": 0}`.
- **Rendering surface**: a new sibling section in `commands/orchestrate.md`'s Consolidated Output,
  alongside the existing `### Deferred (redeploy checkpoint)` table (which continues to render the
  defer case unchanged) — e.g. `### Pre-Existing Deploy-Verify Failures (Not Deferred)` — rendered
  from `verify_deploy_baseline_notices` whenever non-empty, cross-referencing the authoritative
  subsection rather than restating the contract inline (matching how the existing
  `### Deferred (redeploy checkpoint)` section already defers to the authoritative subsection for
  the "why"). This is rendering, not restating — the same distinction the existing `### ZERO
  DISPATCH` section already relies on.

**Authoritative subsection rewrite** (constraint 3): the **Failure contract** paragraph in
`context/patterns/batch-orchestration-guardrails.md`'s `### The Inter-Cycle Redeploy Checkpoint`
currently reads "on failure of either gate ... defer all remaining not-yet-dispatched tasks." It
needs to become a three-branch statement: (a) `deploy-headless.sh` failure — defer unconditionally,
unchanged; (b) `verify-deploy.sh` failure with newly-introduced findings — defer, unchanged in
spirit but now finding-level rather than exit-code-level; (c) `verify-deploy.sh` failure with only
pre-existing findings — proceed, reported loudly via the banner/marker above, never silent. All
five referring files (per the task description) should keep cross-referencing this rewritten
paragraph by path, never restating it.

## Decisions

- **Baseline timing**: capture immediately before `deploy-headless.sh`, not at some earlier fixed
  point, so it reflects the tree as it stood right before this specific redeploy — the correct
  reading of "pre-existing" for this specific checkpoint firing.
- **Comparison granularity**: line-level, sorted-set diff over a new `--findings` mode's output,
  not exit-code-level and not per-gate-boolean-level — this is the minimum granularity that
  actually distinguishes "still has the same 2 failures" from "has the same 2 plus 3 new," which
  the task's design note correctly identifies as the crux.
- **No changes needed to `check-extension-docs.sh`.** Its existing `fail()`/`advisory()` behavior
  already survives `--quiet`; only `verify-deploy.sh`'s own discard-to-`/dev/null` needs to stop
  discarding.
- **`check-task-references.sh` must be invoked WITHOUT `--quiet`** when captured for findings
  (opposite of gate 3's invocation) — its own `--quiet` suppresses exactly the per-finding detail
  needed.
- **Exit 2 folded into the ordinary findings vocabulary via one sentinel line**, not a separate
  side-channel or special case in the orchestrator's branching logic — this both answers the
  task's open exit-2 question and keeps the comparison a single, uniform set-difference.
- **New ledger field (`verify_deploy_baseline_notices`) rather than overloading `defer_ledger`**,
  because the third state is definitionally a non-defer event and `defer_ledger`'s own contract
  explicitly scopes it to defer/exclusion events only.
- **`deployed_critical_paths` is updated on the third-state path**, same as the success path — the
  redeploy mechanically succeeded; only the standing lint state is unhealthy, and the idempotence
  guard should not re-fire the checkpoint on the same critical paths next cycle just because a
  pre-existing failure happened to still be present.

## Risks & Mitigations

- **`skill-orchestrate-hard/SKILL.md` CO-MAINTENANCE gap, not in `file_scope`.** This file
  transcribes the exact Stage MT-3 step 7 logic under an explicit "an edit to either copy REQUIRES
  the same edit to the other; the two MUST always agree" contract (lines 1381-1407), and it is
  itself a declared `orchestrator-critical-paths.json` entry — yet task 966's `file_scope` in
  `specs/state.json` lists only `skill-orchestrate/SKILL.md`, `batch-orchestration-guardrails.md`,
  `verify-deploy.sh`, and `commands/orchestrate.md`. Landing this task without also mirroring the
  change into `skill-orchestrate-hard/SKILL.md` would leave the two engines disagreeing on exactly
  the checkpoint behavior the CO-MAINTENANCE note exists to keep in lockstep — a real, not
  hypothetical, regression of an explicit MUST. **Mitigation (recommended, not decided here)**:
  extend `file_scope` to include `skill-orchestrate-hard/SKILL.md` before planning proceeds; the
  mirror edit itself is small once the primary design lands, since the hard-mode copy already
  cross-references the authoritative subsection for everything except the inline step summary.
- **Doubled `verify-deploy.sh` cost per checkpoint firing.** The design runs `verify-deploy.sh`
  twice (baseline + post) instead of once. This is bounded: the checkpoint itself is already
  gated by trigger + idempotence guard so it does not fire every cycle, and `verify-deploy.sh`'s
  four gates are lightweight (`git ls-files`-scoped scripts, a handful of `jq` queries). No
  mitigation needed beyond noting the cost is real but small and already amortized by the existing
  idempotence guard, which this task does not touch.
- **Non-determinism risk in the findings set.** Mitigated by `sort -u` at the point of capture in
  both the baseline and post runs (see Design above) — any incidental glob/jq ordering difference
  between two runs collapses before the diff, so it can never manufacture a spurious "new" finding.
- **`958` (the deploy-propagation task this task's own description names) is now `abandoned`.**
  Its `dependencies: [966]` edge (966 must land first) is now moot for scheduling purposes since
  958 will never dispatch, but the underlying reasoning in 966's description (verify-deploy.sh
  might grow a stricter gate that becomes the next standing failure) remains valid motivation for
  this task independent of 958's fate; no action needed here beyond noting it.

## Context Extension Recommendations

- **Topic**: machine-readable / diffable output modes for repo-health lint scripts.
- **Gap**: there is no documented convention in `context/patterns/` for "additive machine-output
  flag on an otherwise human-narrative lint script" — the `STRICT_CORE_DEPLOY` re-invocation
  precedent in `verify-deploy.sh` is real but undocumented as a reusable pattern.
- **Recommendation**: if a second lint script grows a similar need after this task lands, consider
  extracting the "capture full sub-script output, filter to a stable prefix, expose one-per-line"
  shape into a short `context/patterns/` note so future additions do not each reinvent the
  filtering rules independently. Not urgent enough to block this task.

## Appendix

- Search queries used: direct `Read`/`Grep`/`Bash` exploration of `verify-deploy.sh`,
  `check-extension-docs.sh`, `check-task-references.sh`, `deploy-headless.sh`,
  `skill-orchestrate/SKILL.md` (Stage MT-3 step 7, Stage MT-4, mt_state_file schema block),
  `skill-orchestrate-hard/SKILL.md` (transcribed checkpoint block), `commands/orchestrate.md`
  (Consolidated Output template, exit-path table), `context/patterns/batch-orchestration-
  guardrails.md` (`### The Inter-Cycle Redeploy Checkpoint`, `## Defer-Not-Fail`, `### The
  Forward-Progress Invariant`), `context/reference/orchestrator-critical-paths.json`,
  `docs/architecture/handoff-schema.md`.
- **Unresolved curiosity, not chased further (out of scope for this research)**: task 966's own
  `dependencies` field in `specs/state.json` lists task 967 ("Fix git-commit-scoped.sh .lock
  exclude pathspec aborting git add and silently dropping commits"), whose `file_scope`
  (`git-commit-scoped.sh`, `git-staging-scope.md`) does not overlap this task's `file_scope` at
  all and is never mentioned in 966's own description text. This reads like an artifact of the
  batch-ordering-edge pass (a separate, recent commit) rather than anything specific to the
  baseline-checkpoint design researched here; noted for the planner in case it reflects a real
  scheduling constraint this report is not positioned to evaluate.

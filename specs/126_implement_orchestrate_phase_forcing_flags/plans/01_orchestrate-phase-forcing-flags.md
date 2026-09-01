# Implementation Plan: Implement orchestrate phase forcing flags

- **Task**: 126 - Implement orchestrate phase forcing flags
- **Status**: [IMPLEMENTING]
- **Effort**: 9.5 hours
- **Dependencies**: Task 117, Task 122 (both `completed`)
- **Research Inputs**: `specs/126_implement_orchestrate_phase_forcing_flags/reports/01_orchestrate-phase-forcing-flags.md`
- **Artifacts**: plans/01_orchestrate-phase-forcing-flags.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; .claude/rules/source-store-deploy-boundary.md; .claude/rules/no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Implement design decision A2 (Phase-Forcing Flags): a composable `--research`/`--plan`/
`--implement` flag surface on `/orchestrate` that forces one or more lifecycle phases to re-run
even when the task has already progressed past them, opens a new `MM_` artifact round for the
forced work, and never regresses the task's status. The work spans a flag parser, a command-layer
threading pass across eight sites, a new phase-resolution stage ahead of the `skill-orchestrate`
state-machine loop, and one combined postflight change covering both the artifact-round advance
and the monotonic-max status clamp.

Definition of done: `/orchestrate N --research --plan` on an already-`[PLANNED]` task runs exactly
one research dispatch then one plan dispatch, writes both artifacts into a freshly opened round,
leaves the task's status at `planned` (never regressed to `researched`), and stops without
dispatching implement. Omitting all three flags leaves every existing code path byte-for-byte
unchanged.

### Research Integration

The research report is integrated in full. Three of its findings materially reshape this plan
relative to the task description, and each is recorded as an explicit decision below:

1. `orchestrator-postflight.sh` — the file the task description and the upstream design report
   both name as the site for WORK item (3) — is **not in `/orchestrate`'s call graph** and is
   **not edited by this plan**. See "Correction to the design report's premise" below.
2. `/orchestrate` never increments `next_artifact_number` for **any** phase today, so there is no
   working research increment to "generalize". The (a)/(b) scope call this forces is resolved
   below.
3. "Stage 1b/2" in the task description does not name a phase-selection site. `Stage 1b` is agent
   routing. This plan targets the functional need instead and says so.

### Correction to the design report's premise (WORK item 3's named file is dead code here)

The design report frames WORK item (3) as "a single conditional change at one call site" in
`orchestrator-postflight.sh` Stage 7a. Research established, with three independent pieces of
evidence, that this would be an inert change for `/orchestrate`:

- A repo-wide grep for `orchestrator-postflight.sh` across every `SKILL.md` returns
  `skill-implementer/SKILL.md` (the plain `/implement` command) and `skill-git-workflow/SKILL.md`
  (which documents itself as a non-runtime front for that same `/implement` path).
  `skill-orchestrate/SKILL.md` has **zero** references to it.
- `context/patterns/batch-orchestration-guardrails.md`'s own reference table already states
  verbatim that the script has "zero references anywhere in
  `skills/skill-orchestrate/SKILL.md` ... this script belongs to a different command's
  postflight, not MT dispatch."
- `/orchestrate`'s real single-task postflight path is `scripts/orchestrate-stage5-postflight.sh`,
  invoked from Stage 5's "Shared postflight tail".

**Decision**: `orchestrator-postflight.sh` is **removed from this task's edit targets**. Editing
its Stage 7a `do_artifact_increment` gate would change the plain `/implement` command's behavior
(its only real caller) while leaving `/orchestrate`'s round-numbering completely unaffected — a
change that would pass a superficial review precisely because the named file did change in the
way described. This correction is a deliverable of this task, not a workaround: the design
report's premise is wrong on this point and this plan records why.

### Scope decision on the pre-existing artifact-numbering gap — (a), with a drawn boundary

Research left open whether to (a) fold the pre-existing "`/orchestrate` never increments
`next_artifact_number`" gap into this task, or (b) scope strictly to the forced-phase case.

**Decision: (a), bounded to single-task mode.**

Rationale:
- A forced phase cannot open a new `MM_` round without a base increment mechanism to extend. Under
  (b) the forced path would be new machinery sitting beside a still-broken unforced path, and the
  two would produce different numbering for the same task — a worse end state than either.
- (a) is *smaller in code*, not larger. The gate under (b) is `force_invoked`-only; under (a) it is
  `research OR force_invoked`, which is the natural superset in the same conditional.
- (a) makes `/orchestrate` conform to a rule this repository already documents as normative:
  `rules/artifact-formats.md`'s "Research: Advances the sequence (reads `next_artifact_number`,
  uses it, increments)".

The boundary, stated so the widening does not creep:

| In scope (prerequisite, folded in) | Out of scope (filed as one separate defect) |
|---|---|
| P1 — single-task `/orchestrate` advances `next_artifact_number` on every research postflight, forced or not | Multi-task (Stage MT-4) `force_phases` consumption |
| P2 — single-task `/orchestrate` advances `next_artifact_number` on a **forced** plan/implement postflight (the A2 requirement proper) | Multi-task `next_artifact_number` advance |
| P3 — `artifact_number` is resolved per cycle and carried in every single-task Stage 4 dispatch context | Multi-task `artifact_number` dispatch-context threading |
| | `orchestrator-postflight.sh` Stage 7a's plan/implement gating for the plain `/implement` command |

P3 is in scope because without it the forced round number is computed but never reaches the agent
that writes the file — `general-research-agent.md` and `planner-agent.md` both read
`artifact_number` "from delegation context" with no documented fallback, and that field is absent
from every non-team single-task `/orchestrate` dispatch context today. A2's stated outcome ("using
the existing `MM_` round-numbering convention for the new artifact") is not achieved without it.

The multi-task deferrals are grouped into **one** defect rather than three, because MT phase
selection is owned by `scripts/orchestrate-triage-classify.sh` (an external classifier, a
structurally different mechanism from single-task Stage 4's semantic handler match) and MT dispatch
contexts are built inside three per-group loops with their own per-task variable naming. Fixing MT
coherently means one change to all three concerns at once, not three independent patches. Phase 7
files that defect.

### Composition semantics (A2(iii))

`--research --plan` means **"force research, then plan, then STOP"** — not "force both, starting
from the first, then continue naturally". The design report's own example (`--research --plan` on
an implemented task "leaving the existing implementation artifact alone") requires the loop to
terminate once the forced sequence is exhausted, never to fall through to the implement handler.
This needs its own small state machine — an ordered queue of not-yet-run forced phases consumed
one per loop cycle **in place of** (not in addition to) the status-derived handler selection —
distinct from the existing `current_status`-driven default.

**Ordering decision**: the forced sequence is ordered by **canonical lifecycle order**
(research -> plan -> implement), not by command-line token order. `--plan --research` and
`--research --plan` therefore mean the same thing. Rationale: a sequence that runs plan before
research is incoherent (plan consumes research's output), and regex-based flag detection in
`parse-command-args.sh` cannot recover token order anyway. This is a deliberate divergence from a
literal reading of the design report's "ordered as named on the command line".

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context; no ROADMAP.md consultation was performed.

## Goals & Non-Goals

**Goals**:
- A composable `--research`/`--plan`/`--implement` flag surface on `/orchestrate`, parsed once into
  a single canonical ordered value.
- A `force_phases`-first phase-resolution override ahead of `skill-orchestrate`'s state-machine
  loop, terminating when the forced sequence is exhausted.
- Single-task `/orchestrate` advances `next_artifact_number` on research postflight and on a forced
  plan/implement postflight, and carries the resolved `artifact_number` into every single-task
  dispatch context.
- A strictly opt-in monotonic-max status clamp so a forced earlier phase never regresses a task's
  status, while its artifact still links.
- Zero behavior change when none of the three flags is passed.

**Non-Goals**:
- Multi-task (`Stage MT-*`) consumption of `force_phases`, MT artifact-number advance, and MT
  `artifact_number` dispatch-context threading — deferred to one filed defect (Phase 7).
- Any edit to `scripts/orchestrator-postflight.sh` (see the correction above).
- Any change to `skill_read_artifact_number`'s `"current"`/`"prev"` mode logic — research confirmed
  it already behaves correctly once the increment fires.
- Any change to the four unforced status-transition paths (`skill-researcher`, `skill-planner`,
  `skill-implementer`, unforced `/orchestrate` cycles). The clamp is opt-in per call site.
- Renaming, reordering, or reusing positional 6 of `skill_postflight_update` (owned by a sibling
  task — see Cross-task composition below).

## Cross-task composition (binding constraints)

This task runs concurrently with siblings that edit three of the same files. These constraints are
binding on the implementer and take precedence over local convenience:

| Constraint | Rule |
|---|---|
| `skill_postflight_update` positional order | Current signature is `1 task_number, 2 operation, 3 session_id, 4 status, 5 phase_check_mode`. A sibling owns positional **6** (`task_dir_override`). This task takes positional **7** ONLY, and adds ONLY the `local status_clamp_mode="${7:-}"` line. Never add, read, rename, or renumber positional 6. Every existing 4-arg and 5-arg call site stays byte-for-byte unchanged. A positional gap at 6 is harmless in bash if this task lands first. |
| `commands/orchestrate.md` flag-threading shape | Use the identical shape at all eight sites: (a) `argument-hint`, (b) `## Options` row, (c) STAGE 0 "Exports:" comment, (d) STAGE 0 prose paragraph, (e) multi-task `args:` string, (f) multi-task JSON delegation context, (g) single-task `args:` string, (h) single-task JSON delegation context. This file threads BOTH an args string AND a separate JSON context object per dispatch site — four insertion points per flag, not two. Copy the existing `continue_budget` / `clean_flag` shape exactly; invent no new convention. |
| `skill-orchestrate/SKILL.md` stage ownership | This task owns a NEW stage (Stage 2b) ahead of Stage 3's loop, its Stage 1 and Stage MT-1 context-parse bullets, Stage 3's sub-step 3c, one added sentence in Stage 4's preamble, and the Stage 5 postflight-tail call-site argument. It MUST NOT add `force_phases` to Stage 3.5 Dispatch Prep (a sibling owns that stage; phase SELECTION is a different concern from per-dispatch context injection). It MUST NOT edit the bodies of the Stage 4 `researched` or `planning` handlers (a sibling owns those). Bullets added to the Stage 1 / MT-1 lists are additive only — never reorder a sibling's. |
| `orchestrate-stage5-postflight.sh` | A sibling also edits this file, in its deploy-pending / defect-record region. This task adds positional **20** (`force_invoked`, optional, defaulting `"false"`) and one new artifact-round-advance block after the existing artifact-linking block. The `if [ "$#" -lt 18 ]` usage guard is left unchanged, so neither landing order breaks the other. |
| Test files | A sibling owns `scripts/tests/test-skill-base-lifecycle.sh`. This task adds a NEW test file instead and does not touch that one. |
| Universal | Edit `agent-system/extensions/**` ONLY, never `.claude/**` (see `.claude/rules/source-store-deploy-boundary.md`). No task-number references in any file outside `specs/**` (see `.claude/rules/no-task-references-in-deliverables.md`) — anchor by heading or verbatim surrounding text, never line number alone. |

## Verification under a stale deploy (binding on every phase)

`.claude/` in this repository is a gitignored, disposable deploy artifact regenerated from
`agent-system/extensions/**`. This task edits the source store only. That creates a verification
hazard that would otherwise silently invalidate most of this plan's checks, and it is stated once
here rather than repeated per phase.

**The hazard.** Most scripts and every relevant test suite resolve their dependencies
**deploy-tree-first, source-store-second**. Verified resolution orders:

| Loader | Resolution order for its dependency |
|---|---|
| `scripts/tests/test-skill-base-lifecycle.sh` | `$REPO_ROOT/.claude/scripts/skill-base.sh`, then `$SCRIPT_DIR/../skill-base.sh` |
| `scripts/tests/test-status-vocabulary.sh` | `$REPO_ROOT/.claude/scripts/lib/status-vocabulary.sh`, then `$SCRIPT_DIR/../lib/status-vocabulary.sh` |
| `scripts/update-task-status.sh` | `$PROJECT_ROOT/.claude/...`, then `$PROJECT_ROOT/agent-system/extensions/core/...` |
| `scripts/skill-base.sh` (for `lib/common.sh`) | `${SKILL_REPO_ROOT}/.claude/scripts/lib/common.sh`, then `$(dirname "${BASH_SOURCE[0]}")/lib/common.sh` |
| `scripts/orchestrate-stage5-postflight.sh` (for `skill-base.sh`) | cwd-relative `.claude/scripts/skill-base.sh`, then `${REPO_ROOT}/.claude/...`, then `${SCRIPT_DIR}/skill-base.sh` |

Because `.claude/scripts/skill-base.sh` always exists in this repo, a source-store-only edit means
every one of these loaders keeps loading the **old** copy. A test written against new behavior then
fails spuriously, or — worse — passes while exercising nothing. Note that this is a *chain*, not a
single hop: even after sourcing the source-store `skill-base.sh` directly, its own `lib/` source
and its `update-task-status.sh` call still resolve deploy-first, so a partial fix leaves the clamp
calling an old `status-vocabulary.sh` that lacks this task's new functions.

Two loaders in the same tree resolve the OTHER way (`scripts/generate-todo.sh` and
`scripts/validate-state.sh` are `SCRIPT_DIR`-first). The order is therefore inconsistent
repo-wide, which is itself worth recording but is not this task's to reconcile.

**The protocol.** For every phase whose verification loads a file this task edits:

1. **Detect before trusting, and print what you detected.** Before running any suite, confirm
   which copy is being loaded — `diff -q .claude/scripts/skill-base.sh
   agent-system/extensions/core/scripts/skill-base.sh` for the tree-level question, and an `echo`
   of the resolved absolute path from inside any harness for the load-level question. Identical
   trees mean the check is meaningful but prove nothing about the new code; differing trees mean
   any deploy-first suite is testing the old copy. The resolved path must be printed, not just
   asserted on, so the provenance is visible in the run's own output rather than inferred. Record
   both results alongside the test output.
2. **Route task-edited files to the source store.** The four files this task edits and must load
   from `agent-system/extensions/core/` in its own tests are `scripts/skill-base.sh`,
   `scripts/lib/status-vocabulary.sh`, `scripts/orchestrate-stage5-postflight.sh`, and
   `scripts/parse-command-args.sh`. Everything else the fixture needs
   (`update-task-status.sh`, `state-write.sh`, `task-lock.sh`, and the rest of the dependency
   chain) may still be copied from the deployed tree — those are not under test here.
3. **Use a scratchpad harness for the chain.** Where a source-store file's own internal resolution
   would still reach back into `.claude/` (the `skill-base.sh` -> `lib/` and
   `orchestrate-stage5-postflight.sh` -> `skill-base.sh` hops above), assemble an isolated
   scratchpad tree whose `.claude/scripts/` is populated from the source store for exactly those
   four files and from the deployed tree for everything else, then point `SKILL_REPO_ROOT` and cwd
   at it. This reuses the fixture-repo technique `test-skill-base-lifecycle.sh` already
   establishes; only the provenance of the four files changes.

**Two things this task MUST NOT do**, both of which would mask the problem rather than handle it:

- **Do NOT deploy in order to make a test pass.** Regeneration is a separate, manual, user-owned
  operation (see `context/patterns/regeneration-is-manual-only.md`); deploying mid-task to turn a
  red test green destroys the very signal the test exists to give.
- **Do NOT reorder any existing suite's or script's deploy-first resolution.** That order is
  deliberate — the deployed tree is what actually executes in production, and the suites are
  written to test what runs. Changing it is a repo-wide behavioral decision affecting many
  loaders (including the two that already resolve the other way), and it is out of scope here.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `--research`/`--plan`/`--implement` are added to a **superset** parser shared by every command, so they begin being stripped from `FOCUS_PROMPT` for `/research`, `/plan`, `/implement` too | H | M | Phase 1 runs an explicit repo-wide audit for existing focus-prompt uses of these three tokens BEFORE adding the strip rules, and records the result. This is a Scope Hypothesis on Phase 1. |
| Implementing WORK item (3) against `orchestrator-postflight.sh` (as the task description literally directs) would look correct and change nothing | H | M — it is what the description says | The correction section above is carried into this plan verbatim, that file is struck from the edit targets, and Phase 7's verification asserts the file is unmodified. |
| A sibling lands a different positional-6 semantic for `skill_postflight_update` between this plan and its implementation | M | M | This task adds ONLY positional 7 and never reads 6. Its own call site passes an explicit empty string for 6; Phase 5 carries a Scope Hypothesis requiring the implementer to re-read the landed signature and pass `"${TASK_DIR:-}"` instead if the sibling's semantics make an empty 6 meaningful. |
| The monotonic-max clamp leaks into unforced callers and silently suppresses legitimate transitions | H | L | The clamp is opt-in via a new trailing parameter that defaults to today's exact behavior when absent or empty. Every existing call site is left unchanged. Phase 7 asserts an unforced cycle still transitions normally. |
| Adding the artifact-round advance to `skill_postflight_update` would double-increment for `/research` | H | L | It is deliberately NOT added there: `skill-researcher/SKILL.md` already performs its own inline increment and also calls `skill_postflight_update`. The advance goes in `orchestrate-stage5-postflight.sh`, which is `/orchestrate`-only. This matches the convention `context/patterns/skill-postflight-flow.md` already documents ("An importing skill that needs this increment keeps that one `state-write.sh` call inline"). |
| Forced phases run against a terminal-status task and corrupt it | H | L | Phase 4's override is ordered strictly AFTER the terminal-state check; a forced phase on `completed`/`abandoned`/`expanded` refuses with a loud named message, per `rules/state-management.md`'s "Cannot transition from terminal states". |
| Two forced-phase queue copies drift between Stage 2b and Stage 3's 3c | M | L | Stage 2b defines the queue and a named resolution function; 3c calls it by name. Stage 4 handlers are referenced by pointer, never inlined — the same "stated fully here, referenced later" idiom the file's `team_mode` fork paragraph already establishes. |
| Deploy-first dependency resolution makes this task's tests exercise the OLD `skill-base.sh` / `status-vocabulary.sh` — failing spuriously, or passing while testing nothing | H | H — this is the default behavior, not an edge case | The "Verification under a stale deploy" section above is binding on Phases 2, 5, and 7: detect which copy is loaded before trusting any result, route the four task-edited files to the source store, and use a scratchpad harness for the chained hops. Never deploy to make a test pass; never reorder an existing suite's resolution. |
| A partial fix to the stale-deploy hazard (sourcing the source-store `skill-base.sh` but letting its own `lib/` source resolve deploy-first) leaves the clamp calling a `status_vocabulary_would_regress` that does not exist | M | M | The protocol's step 3 requires the scratchpad tree to carry the source-store copy of ALL FOUR edited files, not just the entry point. Phase 5's verification asserts the function is resolvable from inside the harness before any clamp case runs. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4, 5 | 3 (Phase 4); 2 (Phase 5) |
| 4 | 6 | 4, 5 |
| 5 | 7 | 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Flag surface in the shared argument parser [COMPLETED]

- **Goal:** `/orchestrate --research --plan` produces one canonical, ordered, comma-separated
  `FORCE_PHASES_FLAG` export, with no collateral damage to any other command's `FOCUS_PROMPT`.

- **Tasks:**
  - [x] Audit first, edit second: run a repo-wide search for existing occurrences of `--research`,
        `--plan`, and `--implement` appearing as *focus-prompt text* (as opposed to as slash-command
        names or as documented flags of other commands) across `agent-system/extensions/**`,
        `.claude/**` docs, and `specs/**` examples. Record the count and each hit's disposition in
        the phase's commit message. If any live call site would be broken by the new strip rules,
        STOP and report rather than proceeding. *(completed)*
  - [x] In `scripts/parse-command-args.sh`, add `FORCE_PHASES_FLAG` to the header's
        "Exported Variables" comment block, documented in the same style as `CONTINUE_BUDGET_FLAG`
        (what it is, that it is `/orchestrate`-only, that it is composable, that its order is
        canonical lifecycle order not token order). *(completed)*
  - [x] In "Step 4: Scan for flags", initialize `FORCE_PHASES_FLAG=""` alongside the other
        default-false initializations. *(completed)*
  - [x] Append the three detection blocks in canonical lifecycle order, each appending its phase
        name to the accumulating comma-separated string. Follow the file's existing
        `if [[ "$remaining" =~ --flag ]]; then ... fi` idiom exactly. *(completed)*
  - [x] In "Step 5", add `--research`, `--plan`, and `--implement` to the `sed` strip chain so they
        never survive into `FOCUS_PROMPT`. *(completed)*
  - [x] Add `FORCE_PHASES_FLAG` to the trailing `export` statement. *(completed)*

- **Timing:** 1 hour

- **Depends on:** none

- **Verification Tier:** local

- **Scope Hypothesis:** This phase asserts that no existing command or documented workflow relies
  on the literal tokens `--research`, `--plan`, or `--implement` surviving into `FOCUS_PROMPT`.
  Confirm at implementation time by the repo-wide audit in the first task above, before any edit is
  made. Record the hit count and each disposition; a non-zero count of *live* hits invalidates the
  hypothesis and must be reported rather than worked around.

- **Files to modify:**
  - `agent-system/extensions/core/scripts/parse-command-args.sh` — new `FORCE_PHASES_FLAG` export,
    three detection blocks, three strip rules, header documentation.

- **Verification:**
  - `bash -n scripts/parse-command-args.sh` parses clean.
  - Sourcing the parser with `"42 --research --plan"` yields `FORCE_PHASES_FLAG="research,plan"`
    and an empty `FOCUS_PROMPT`.
  - Sourcing with `"42 --plan --research"` yields the identical `"research,plan"` (order
    canonicalization).
  - Sourcing with `"42 focus on the LSP config"` yields `FORCE_PHASES_FLAG=""` and the focus prompt
    intact.

---

### Phase 2: Status-rank helpers in the status-vocabulary library [COMPLETED]

- **Goal:** a reusable, sourced predicate answering "would this transition regress the task's
  lifecycle position?", with no existing behavior touched.

- **Tasks:**
  - [x] In `scripts/lib/status-vocabulary.sh`, add `STATUS_VOCABULARY_LIFECYCLE_RANK`, a `declare -A`
        map over the linear-progress subset of the closed enum:
        `not_started=0, researching=1, researched=2, planning=3, planned=4, implementing=5,
        pr_ready=6, completed=7`. Deliberately omit `blocked`, `partial`, `abandoned`, and
        `expanded` — per `rules/state-management.md`'s permissive model these are non-terminal
        exception states or terminal states that live outside the linear rank, and the clamp
        concerns only the ordinary lifecycle-progress axis. *(completed)*
  - [x] Add `status_vocabulary_rank <status>`, echoing the rank or an empty string when the status
        is unranked. *(completed)*
  - [x] Add `status_vocabulary_would_regress <current> <target>`, returning 0 (yes, regresses) only
        when BOTH statuses are ranked AND `rank(target) <= rank(current)`; returning 1 in every
        other case, including when either side is unranked. This "unranked means the clamp does not
        apply" rule is the deliberate, minimal choice: a forced phase on a `partial` or `blocked`
        task writes its status exactly as it does today. *(completed)*
  - [x] Document the rank map's source in a header comment: the valid-transition diagram in
        `context/standards/status-markers.md`. Note explicitly that `pr_ready` is included at rank 6
        (it sits on the linear axis between `implementing` and `completed`) even though the
        transition diagram's research-cited ordering stopped at `completed`. *(completed)*
  - [x] Confirm the library's existing self-verifying consumer-discovery comment
        (`grep -rl 'status-vocabulary.sh' agent-system/extensions`) still describes reality and needs
        no edit. *(completed)*

- **Timing:** 45 minutes

- **Depends on:** none

- **Verification Tier:** local

- **Files to modify:**
  - `agent-system/extensions/core/scripts/lib/status-vocabulary.sh` — new rank map and two new
    functions; existing `STATUS_VOCABULARY_ENUM`, `STATUS_VOCABULARY_TODO_MARKER_MAP`,
    `status_vocabulary_is_valid`, and `status_vocabulary_todo_marker` untouched.

- **Verification:**
  - `bash -n scripts/lib/status-vocabulary.sh` parses clean.
  - `status_vocabulary_would_regress planned researched` returns 0.
  - `status_vocabulary_would_regress researched planned` returns 1.
  - `status_vocabulary_would_regress planned planned` returns 0 (equal rank is a regression for
    monotonic-max purposes).
  - `status_vocabulary_would_regress blocked researched` returns 1 (unranked side).
  - The existing `scripts/tests/test-status-vocabulary.sh` drift assertion still passes — the enum
    array itself is unchanged, so the schema diff is unaffected. **That suite resolves the library
    deploy-first**, so it validates the deployed copy, not this phase's edit; run it for the
    unchanged-enum assurance it does give, and verify the four new-function cases above by sourcing
    `agent-system/extensions/core/scripts/lib/status-vocabulary.sh` directly. Do not modify that
    suite's resolution order — see "Verification under a stale deploy".

---

### Phase 3: Command-layer flag threading [COMPLETED]

- **Goal:** `FORCE_PHASES_FLAG` reaches `skill-orchestrate` as `force_phases` through all eight
  sites, in the shape the shared-file contract fixes.

- **Tasks:**
  - [x] (a) `argument-hint` in the frontmatter — extend to signal the new optional flags in the same
        terse style already used. *(completed)*
  - [x] (b) Add one `## Options` table row per flag (three rows), each describing that flag's forced
        phase, stating that they are composable, that the composed sequence STOPS after the last
        named phase, that ordering is canonical lifecycle order regardless of token order, and that
        they are single-task only (accepted and ignored in multi-task mode). Match the density and
        voice of the existing `--continue-budget` row. *(completed)*
  - [x] (c) Add `FORCE_PHASES_FLAG` to STAGE 0's `# Exports:` comment list. *(completed)*
  - [x] (d) Add a STAGE 0 prose paragraph threading `force_phases`, written on the same terms as the
        existing `CONTINUE_BUDGET_FLAG` paragraph: default `""`, consumer-side-only, read by
        `skill-orchestrate`'s own Stage 2b, never forwarded to any admission-gate script. *(completed)*
  - [x] (e) Add `force_phases={FORCE_PHASES_FLAG}` to the MULTI-TASK DISPATCH `args:` string. *(completed)*
  - [x] (f) Add `"force_phases": "{FORCE_PHASES_FLAG}"` to the multi-task JSON delegation context. *(completed)*
  - [x] (g) Add `force_phases={FORCE_PHASES_FLAG}` to the STAGE 2: DELEGATE `args:` string. *(completed)*
  - [x] (h) Add `"force_phases": "{FORCE_PHASES_FLAG}"` to the single-task JSON delegation context. *(completed)*
  - [x] Add one sentence to the `## Constraints` list recording that the three phase-forcing flags
        are single-task only, alongside the existing `--team` constraint sentence they mirror. *(completed)*

- **Timing:** 1.25 hours

- **Depends on:** 1

- **Verification Tier:** interface

- **Scope Hypothesis:** This phase asserts exactly eight insertion points plus one Constraints
  sentence. Confirm at implementation time by grepping the file for every existing occurrence of
  `CONTINUE_BUDGET_FLAG` and `continue_budget` and checking that this phase's edits land at the
  same set of sites plus the `argument-hint` and `## Options` sites that flag also occupies. A
  count other than eight means a site was missed or the file changed under a sibling's edit.

- **Files to modify:**
  - `agent-system/extensions/core/commands/orchestrate.md` — eight threading sites plus one
    Constraints sentence.

- **Verification:**
  - `grep -c 'FORCE_PHASES_FLAG' commands/orchestrate.md` returns 5 (Exports comment, prose
    paragraph, two `args:` strings, two JSON contexts — confirm the exact expected count against
    the `CONTINUE_BUDGET_FLAG` baseline rather than assuming this number).
  - Both `args:` strings and both JSON blocks carry the field; neither dispatch site has one
    without the other.
  - The `## Options` table renders with three new rows and no broken pipes.

---

### Phase 4: Forced-phase resolution stage in skill-orchestrate [COMPLETED]

- **Goal:** a `force_phases`-first override that runs the composed sequence and then terminates,
  implemented ahead of the state-machine loop without touching any sibling-owned stage or handler
  body.

- **Tasks:**
  - [x] Stage 1 (Input Validation): add ONE bullet parsing `force_phases` (default `""`) from the
        delegation context, appended to the end of the existing bullet list. Do not reorder existing
        bullets. State that it is single-task-only and consumed by Stage 2b. *(completed)*
  - [x] Stage MT-1 (Parse Multi-Task Context): add ONE bullet parsing `force_phases` for
        DIAGNOSTICS ONLY, and emit a once-per-batch accepted-and-ignored notice when non-empty,
        copying the existing `team_mode` notice's exact shape and rationale style. This is the
        precedented mechanism for a single-task-only flag reaching MT mode; it makes the deferral
        loud instead of silent. *(completed)*
  - [x] Add a new `### Stage 2b: Forced-Phase Queue Initialization`, placed after Stage 2 (Loop
        Guard Initialization) and immediately before `### Stage 3: State Machine Loop`. It must: *(completed)*
    - [x] Split `force_phases` into an ordered `force_queue` array, validating each entry against
          the closed set `{research, plan, implement}` and failing loudly on any other value. *(completed)*
    - [x] Define the phase-to-handler map as prose: `research` -> the Stage 4
          `#### State: not_started` handler body; `plan` -> the Stage 4 `#### State: researched`
          handler body; `implement` -> the Stage 4 `#### State: planned or implementing` handler
          body. Reference each by heading, never inline a copy. (Referencing the `researched`
          handler is a pointer, not an edit — it does not collide with the sibling that owns that
          handler's body.) *(completed)*
    - [x] Define the named function `resolve_cycle_artifact_number()`, which calls
          `skill_read_artifact_number "$task_number" "$PADDED_NUM" "$PROJECT_NAME" "$artifact_dir"
          "$mode"` with `mode="current"` and `artifact_dir="reports/"` for a research cycle, and
          `mode="prev"` with the matching directory for plan/implement cycles, exporting
          `ARTIFACT_NUMBER`/`ARTIFACT_PADDED`. Note explicitly that `skill_read_artifact_number`'s
          own logic is unchanged by this task. *(completed)*
    - [x] Write `force_phases_remaining` into the loop-guard JSON for observability only, in the
          same jq-write style Stage 3's 3b already uses. State that it is never authoritative and
          never gates admission. *(completed)*
    - [x] State the empty-queue invariant explicitly: when `force_queue` is empty, this stage is a
          no-op and every downstream path behaves byte-for-byte as it does today. *(completed)*
  - [x] Stage 3, sub-step 3c ("Dispatch by state"): rewrite as a two-branch decision. Order matters
        and must be stated as an ordering requirement, not left implicit:
    1. If `current_status` is terminal (`completed`, `abandoned`, `expanded`), run the existing
       terminal handler unchanged — a forced phase NEVER overrides a terminal state. On a non-empty
       `force_queue`, emit a loud named refusal message first, citing
       `rules/state-management.md`'s "Cannot transition from terminal states".
    2. Else if `force_queue` is non-empty: pop its head into `forced_phase`, set
       `force_invoked=true` for this cycle, call `resolve_cycle_artifact_number()`, and execute the
       Stage 4 handler the map names — by pointer, exactly as written.
    3. Else: set `force_invoked=false`, call `resolve_cycle_artifact_number()`, and dispatch by
       state exactly as today. *(completed)*
  - [x] Add the forced-sequence-exhausted terminal condition: after the cycle whose popped phase
        left `force_queue` empty completes its Stage 5 postflight, the loop STOPS. It does not fall
        through to status-derived dispatch. Route this through the existing terminal-condition
        reporting so the run's summary names it. *(completed)*
  - [x] Add ONE sentence to Stage 4's preamble (under the `### Stage 4: State Handlers` heading,
        before the first `#### State:` section) stating that every handler's `context` object
        additionally carries `artifact_number: $ARTIFACT_NUMBER`, resolved by Stage 2b's
        `resolve_cycle_artifact_number()`. This is the "stated fully here; every later occurrence
        references this paragraph" idiom the file's own `team_mode` fork paragraph already
        establishes, and it delivers P3 without editing a single handler body. *(completed)*
  - [x] Add a short note recording that the task description's "Stage 1b/2" phrasing does not name a
        phase-selection site — `Stage 1b` is agent routing — and that this stage is the functional
        target instead. *(completed)*

- **Timing:** 2 hours

- **Depends on:** 3

- **Verification Tier:** interface

- **Files to modify:**
  - `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 1 bullet, Stage MT-1
    bullet + notice, new Stage 2b, Stage 3 sub-step 3c, Stage 4 preamble sentence.

- **Verification:**
  - The new stage heading sorts between Stage 2 and Stage 3 in the file's heading outline.
  - No `#### State:` handler body under Stage 4 is modified — confirm with a scoped diff over the
    Stage 4 region showing changes only in its preamble.
  - Stage 3.5 Dispatch Prep is untouched — confirm with a scoped diff (sibling-owned).
  - `force_phases` appears in Stage 1, Stage MT-1, Stage 2b, and Stage 3 sub-step 3c, and nowhere
    else in the file.
  - Every bullet added to the Stage 1 and MT-1 lists is appended, not interleaved.

---

### Phase 5: Combined postflight — artifact-round advance and monotonic-max clamp [NOT STARTED]

- **Goal:** one forced-postflight code path that applies both the artifact-number advance and the
  status clamp under a single `force_invoked` condition, per the research report's recommendation
  to design WORK items (3) and (4) together.

- **Tasks:**
  - [ ] In `scripts/skill-base.sh`, `skill_postflight_update`: make exactly these three edits,
        mirroring the precision the sibling task's own plan uses on the same function.
    - [ ] **Edit 1 (one `local`)**: add `local status_clamp_mode="${7:-}"` immediately after the
          existing `local phase_check_mode="${5:-}"` line. Add NOTHING at positional 6.
    - [ ] **Edit 2 (usage-comment extension)**: extend the header `Usage:` line to show the new
          trailing parameter, and add a paragraph documenting it: absent or empty preserves today's
          behavior exactly; `"monotonic-max"` resolves `scripts/lib/status-vocabulary.sh`, maps the
          `operation`/`status` pair to its resting state the same way `update-task-status.sh`'s
          `map_status()` does, compares it against the task's current status via
          `status_vocabulary_would_regress`, and on a regression SKIPS the `update-task-status.sh`
          invocation with a named `[monotonic-max]` notice while still running the extension hook
          and the lifecycle event, returning 0.
    - [ ] **Edit 3 (in-block)**: inside the existing `case "$status" in` success arm, guard the
          `update-task-status.sh` invocation on the clamp decision. Keep `_postflight_rc` semantics
          intact — a clamp skip is rc 0, never a refusal code.
    - [ ] **Not touched** (state this explicitly in the header comment, so a later reader can see
          the boundary was deliberate): positional 6 and its `${6:-}` read; the `phase_check_args`
          array and its empty-array expansion; the `_postflight_rc` capture and the `return
          "$_postflight_rc"` line; the entire rc-6 deploy-pending block; the
          `skill_run_extension_hook` call; the `_events_append_observable` call; the non-success
          `*)` arm.
  - [ ] Resolve `status-vocabulary.sh` inside `skill_postflight_update` using the file's OWN
        existing convention (`${SKILL_REPO_ROOT}`-qualified first, `$(dirname "${BASH_SOURCE[0]}")`
        fallback — the same two-candidate shape the existing `lib/common.sh` source at the top of
        `skill-base.sh` uses). Do not invent a third resolution order. Note in the comment that this
        inherits the deploy-first hazard documented in this plan's stale-deploy section, and that
        the phase's own tests must therefore run under the scratchpad harness.
  - [ ] Verify and state in that comment that every existing 4-arg and 5-arg call site is unchanged,
        and that positional 6 is deliberately untouched.
  - [ ] In `scripts/orchestrate-stage5-postflight.sh`, add positional **20**:
        `force_invoked="${20:-false}"`. Document it in the file's `Usage:` header block. Leave the
        `if [ "$#" -lt 18 ]` guard and its usage-error string unchanged (the new argument is
        optional).
  - [ ] In that script's `case "$dispatch_status"` block, pass the clamp through on a forced
        dispatch. Positional arguments cannot be skipped, so reaching position 7 requires explicit
        placeholders at 5 and 6:
    - [ ] `researched` and `planned` arms currently pass **no** 5th argument. They gain
          `"" "" "<clamp>"` at positions 5/6/7. The explicit `""` at position 5 is behaviorally
          identical to omitting it — `phase_check_mode="${5:-}"` and the `-n` guard both yield the
          no-flag path — but it is required to reach 6 and 7 at all.
    - [ ] The `implemented` arm keeps its existing `"warn"` at position 5 unchanged, and gains `""`
          at 6 plus `<clamp>` at 7.
    - [ ] `<clamp>` is `monotonic-max` when `force_invoked` is `"true"` and the empty string
          otherwise, so an unforced cycle passes an empty 7th argument and takes the unchanged path.
    - [ ] Do not change the `partial|failed|blocked` or Tier C arms — neither calls
          `skill_postflight_update`.
  - [ ] Add a new `## Artifact-round advance` block AFTER the existing artifact-linking block and
        BEFORE the off-schema halt decision. It advances `next_artifact_number` via
        `bash .claude/scripts/state-write.sh` with the jq transform already proven in
        `orchestrator-postflight.sh` Stage 7a, gated on:
        `dispatch_status == "researched"` (P1 — unconditional, this is the base gap being closed)
        OR (`force_invoked == "true"` AND `dispatch_status` in `{planned, implemented}`) (P2).
        Non-blocking on failure, matching the warning style of the Stage 7a original.
  - [ ] Add a header comment in that block recording WHY the advance lives here and not in
        `skill_postflight_update`: `skill-researcher/SKILL.md` already performs its own inline
        increment and also calls `skill_postflight_update`, so folding it in would double-increment
        `/research`. This matches the convention `context/patterns/skill-postflight-flow.md` already
        documents.
  - [ ] Add a header comment recording that `orchestrator-postflight.sh` is NOT the site for this
        change, with the one-line reason (zero call sites in `skill-orchestrate/SKILL.md`), so the
        next reader does not re-derive the wrong target.

- **Timing:** 2 hours

- **Depends on:** 2

- **Verification Tier:** full

- **Commit Mode:** per-substep

- **Scope Hypothesis:** This phase assumes `skill_postflight_update`'s positional 6 is either
  absent or carries a sibling's `task_dir_override` defaulting to `${TASK_DIR:-}`. Confirm at
  implementation time by re-reading the landed function signature in `scripts/skill-base.sh`
  immediately before editing. If positional 6 exists and an empty value does NOT fall back to
  `${TASK_DIR:-}`, the call sites in `orchestrate-stage5-postflight.sh` must pass
  `"${task_dir}"` at position 6 instead of `""`. Record which branch was taken.

- **Files to modify:**
  - `agent-system/extensions/core/scripts/skill-base.sh` — positional 7 only, plus header docs.
  - `agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh` — positional 20, three
    clamp-threading call sites, one new artifact-round-advance block, header docs.

- **Verification:**
  - `bash -n` on both files.
  - `grep -n 'skill_postflight_update' scripts/orchestrate-stage5-postflight.sh` shows the three
    live call sites, each with the expected arity.
  - Every OTHER `skill_postflight_update` call site in the repository still passes 4 or 5 arguments
    — confirm with the repo-wide grep and diff the result against the pre-change list.
  - **Stale-deploy protocol (mandatory for this phase)**: run the `diff -q` detection on
    `skill-base.sh` and `lib/status-vocabulary.sh` and record the outcome. Exercise the new clamp
    ONLY under the scratchpad harness described in "Verification under a stale deploy", and assert
    inside that harness that `status_vocabulary_would_regress` is resolvable BEFORE running any
    clamp case — a "command not found" there is the signature of the partial-fix failure mode, not
    a logic bug.
  - `bash scripts/tests/test-skill-base-lifecycle.sh` still passes, run unmodified. It resolves
    `skill-base.sh` deploy-first, so it is a regression check on the DEPLOYED copy — real assurance
    that nothing already-shipped broke, but NOT evidence about this phase's edit. Report it as
    exactly that. Do not modify that suite, and do not deploy to change what it loads.
  - The full repository gate set runs green (this phase touches `skill-base.sh`, which every
    skill's postflight sources) — with the same caveat about what the deployed-tree suites do and
    do not cover.
  - `scripts/orchestrator-postflight.sh` and `scripts/tests/test-skill-base-lifecycle.sh` show as
    unmodified in `git status`.

---

### Phase 6: Wire the forced signal through the Stage 5 postflight tail [NOT STARTED]

- **Goal:** `force_invoked` and the resolved `artifact_number` actually reach the code written in
  Phases 4 and 5.

- **Tasks:**
  - [ ] In `skill-orchestrate/SKILL.md` Stage 5's "Shared postflight tail", extend the
        `orchestrate-stage5-postflight.sh` invocation to pass `"$force_invoked"` as the 20th
        positional argument, and add a short note that the argument is optional and that omitting it
        preserves the pre-change behavior.
  - [ ] Confirm `force_invoked` is in scope at that call site (set by Stage 3's 3c on every cycle,
        both branches) and initialized to `"false"` in Stage 2b so no cycle can read it unset.
  - [ ] Confirm `ARTIFACT_NUMBER` is in scope at every Stage 4 dispatch site, set by
        `resolve_cycle_artifact_number()` in 3c before the handler runs.
  - [ ] Trace and record the full end-to-end chain in a short note in Stage 2b:
        `parse-command-args.sh` -> `commands/orchestrate.md` (8 sites) -> Stage 1 `force_phases` ->
        Stage 2b `force_queue` -> Stage 3 3c `forced_phase`/`force_invoked`/`ARTIFACT_NUMBER` ->
        Stage 4 handler `context` -> Stage 5 tail -> `orchestrate-stage5-postflight.sh` positional
        20 -> clamp (positional 7 of `skill_postflight_update`) and artifact-round advance.

- **Timing:** 1 hour

- **Depends on:** 4, 5

- **Verification Tier:** interface

- **Files to modify:**
  - `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 5 call-site argument,
    Stage 2b chain note.

- **Verification:**
  - The Stage 5 invocation's argument count matches the script's documented 20-positional usage.
  - No variable in the chain is read before it is assigned, on either branch of 3c.
  - Stage MT-4's own `skill_postflight_update` calls are unchanged (still 4 or 5 arguments).

---

### Phase 7: Tests, documentation sync, and the deferred-defect filing [NOT STARTED]

- **Goal:** the new behavior is regression-protected, the documented surface matches the built
  surface, and the two deliberate deferrals are recorded where they will be found.

- **Tasks:**
  - [ ] Add a NEW test file `agent-system/extensions/core/scripts/tests/test-force-phases.sh`
        (deliberately not `test-skill-base-lifecycle.sh`, which a sibling owns). Reuse
        `test-skill-base-lifecycle.sh`'s STRUCTURAL conventions (mktemp workdir, EXIT-trap cleanup,
        `pass`/`fail`/`info` counters, isolated fixture repo, exit 0/1/2) but **deliberately invert
        its candidate-resolution order for the four files this task edits**: source
        `skill-base.sh`, `lib/status-vocabulary.sh`, `orchestrate-stage5-postflight.sh`, and
        `parse-command-args.sh` from `agent-system/extensions/core/` FIRST, falling back to
        `.claude/` only if the source-store copy is absent. Every other fixture dependency keeps the
        existing deploy-tree provenance. Add a header comment stating this inversion and why: this
        suite tests a pre-deploy source-store edit, which is a different question from what the
        deployed tree does, and copying the deploy-first order verbatim would make the suite
        silently vacuous. Cases:
    - [ ] **Harness sanity — listed first because it MUST run first, and gates every case below.**
          For each of the four task-edited files, `echo` the absolute path that actually resolved,
          and assert it lies under `agent-system/extensions/core/` rather than under `.claude/`.
          Then assert `status_vocabulary_would_regress` is a defined function. Echoing the resolved
          path (not merely asserting on it) is the requirement: a silent wrong-copy load is the
          entire hazard, so the path must appear in the suite's own output where a reader of a CI
          log can see which copy was exercised. A failure here exits 2 (environment error), never 1
          (test failure) — it means the suite would otherwise report on the wrong code, which is a
          different and more dangerous condition than a genuine assertion failure.
    - [ ] Parser: `--research --plan` and `--plan --research` both yield `"research,plan"`.
    - [ ] Parser: no flags yields `""` and an intact `FOCUS_PROMPT`.
    - [ ] Rank: the four `status_vocabulary_would_regress` cases from Phase 2.
    - [ ] Clamp: `skill_postflight_update <n> research <sid> researched "" "" monotonic-max` against
          a task at `planned` leaves the status at `planned` and prints the `[monotonic-max]` notice.
    - [ ] Clamp opt-out: the same call WITHOUT the 7th argument transitions the status, proving the
          default is unchanged.
    - [ ] Arity preservation: a 4-argument and a 5-argument call still behave exactly as before.
    - [ ] Artifact advance: a `researched` dispatch through `orchestrate-stage5-postflight.sh`
          increments `next_artifact_number`; a `planned` dispatch with `force_invoked=false` does
          not; a `planned` dispatch with `force_invoked=true` does.
  - [ ] Update `merge-sources/claudemd.md`'s `/orchestrate` command-table row to
        `/orchestrate N [--lit] [--research] [--plan] [--implement]` with a phrase naming the
        forcing semantics and the stop-after-last-named-phase rule.
  - [ ] Update `context/patterns/skill-postflight-flow.md`'s Stage 7 usage line and its
        "Not covered by this shared call" paragraph to mention the new optional clamp parameter and
        to keep its existing statement about inline `next_artifact_number` increments accurate.
  - [ ] File ONE new defect task covering the grouped multi-task deferral: `force_phases`
        consumption in Stage MT-4, `next_artifact_number` advance for MT postflight, and
        `artifact_number` dispatch-context threading in MT-4's three per-group dispatch loops.
        Include the rationale for grouping (MT phase selection is owned by
        `scripts/orchestrate-triage-classify.sh`, a structurally different mechanism from
        single-task Stage 4's semantic handler match).
  - [ ] File the correction to the design report's WORK item (3) premise where a future reader of
        that report will find it — either as an annotation on the design report itself or as a note
        in the deferred-defect task, whichever the repository's conventions support. State that
        `orchestrator-postflight.sh` was named in error and that the real target is
        `orchestrate-stage5-postflight.sh`.
  - [ ] Verify no file outside `specs/**` gained a task-number reference during this task.

- **Timing:** 1.5 hours

- **Depends on:** 6

- **Verification Tier:** full

- **Files to modify:**
  - `agent-system/extensions/core/scripts/tests/test-force-phases.sh` (new)
  - `agent-system/extensions/core/merge-sources/claudemd.md`
  - `agent-system/extensions/core/context/patterns/skill-postflight-flow.md`
  - `specs/**` — the new defect task entry (task-management artifacts only)

- **Verification:**
  - `bash scripts/tests/test-force-phases.sh` passes.
  - The full repository gate set runs green.
  - `bash .claude/scripts/check-task-references.sh` (or the repo's equivalent lint) reports no new
    violations.
  - `git status` shows `scripts/orchestrator-postflight.sh` and
    `scripts/tests/test-skill-base-lifecycle.sh` unmodified.

---

## Testing & Validation

- [ ] `bash -n` passes on all four modified shell files.
- [ ] The stale-deploy detection (`diff -q` source store vs. `.claude/`) has been run and its result
      recorded for `skill-base.sh`, `lib/status-vocabulary.sh`, `orchestrate-stage5-postflight.sh`,
      and `parse-command-args.sh`, so every result below is read with the right provenance in mind.
- [ ] `bash scripts/tests/test-force-phases.sh` passes, and its harness-sanity case confirms it
      loaded the source-store copies rather than the deployed ones.
- [ ] `bash scripts/tests/test-status-vocabulary.sh` still passes (enum/schema drift assertion) —
      recorded as a deployed-copy regression check, not as evidence about this task's new functions.
- [ ] `bash scripts/tests/test-skill-base-lifecycle.sh` still passes, unmodified — same caveat.
- [ ] No deploy/regeneration was performed at any point during this task, and no existing suite's
      or script's dependency-resolution order was changed.
- [ ] Repo-wide grep confirms every `skill_postflight_update` call site outside
      `orchestrate-stage5-postflight.sh` still passes 4 or 5 arguments.
- [ ] `/orchestrate N` with no forcing flags produces a byte-identical dispatch sequence to the
      pre-change behavior for a task at each of `not_started`, `researched`, and `planned`.
- [ ] `/orchestrate N --research` on a `[PLANNED]` task: one research dispatch, a new artifact round
      opened, status remains `planned`, the report is linked, the loop stops.
- [ ] `/orchestrate N --research --plan` on a `[PLANNED]` task: research then plan, one round, stop
      before implement.
- [ ] `/orchestrate N --research` on a `[COMPLETED]` task: loud refusal, no state mutation.
- [ ] `/orchestrate N,M --research` (multi-task): loud accepted-and-ignored notice, no MT behavior
      change.
- [ ] `scripts/orchestrator-postflight.sh` is unmodified.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/parse-command-args.sh` (modified)
- `agent-system/extensions/core/scripts/lib/status-vocabulary.sh` (modified)
- `agent-system/extensions/core/commands/orchestrate.md` (modified)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (modified)
- `agent-system/extensions/core/scripts/skill-base.sh` (modified — positional 7 only)
- `agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh` (modified)
- `agent-system/extensions/core/scripts/tests/test-force-phases.sh` (new)
- `agent-system/extensions/core/merge-sources/claudemd.md` (modified)
- `agent-system/extensions/core/context/patterns/skill-postflight-flow.md` (modified)
- One new defect task entry in `specs/**` for the grouped multi-task deferral
- `specs/126_implement_orchestrate_phase_forcing_flags/summaries/01_orchestrate-phase-forcing-flags-summary.md`

## Rollback/Contingency

Every phase is independently revertible and the whole change is inert when no forcing flag is
passed, so partial rollback is safe:

- **Phase 1 alone**: reverting restores the parser; nothing downstream reads `FORCE_PHASES_FLAG`
  when it is absent.
- **Phase 5 is the only phase touching a file every skill sources** (`skill-base.sh`). If the full
  gate set fails after it, revert that file's hunk alone — the new parameter is additive and
  unreferenced by any pre-existing call site, so removing it cannot leave a dangling caller.
- **Phase 4/6**: reverting the SKILL.md hunks leaves `force_phases` parsed at the command layer and
  ignored at the skill layer, which is a safe no-op.
- Because two sibling tasks edit three of these files concurrently, prefer a targeted per-file
  revert over a whole-branch reset, and re-read the current file state before any revert.

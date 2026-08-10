# Implementation Plan: Task #5

- **Task**: 5 - implement_roadmap_items_producer (roadmap_items is never derived by any implement path, so /todo's ROADMAP sync is dead in practice)
- **Status**: [COMPLETED]
- **Effort**: 4.5 hours
- **Dependencies**: None (stated dependency 1004 confirmed satisfied/vaulted by the research report)
- **Research Inputs**: specs/005_implement_roadmap_items_producer/reports/01_roadmap-items-producer.md
- **Artifacts**: plans/01_roadmap-items-producer.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The producer half of `/todo`'s ROADMAP.md sync computes nothing because the implementation
agents are never handed `specs/ROADMAP.md` to read — their existing "optionally generate
`roadmap_items`" instruction asks them to judge a match against a document they have never seen.
This plan threads `roadmap_path` through every dispatch context that reaches an implementation
agent (mirroring the pattern `skill-planner`/`planner-agent` already use), adds a read-only
"Load Roadmap Context" stage to both implementation agents, tightens the Stage 6a instruction
into a directive check, adds a distinct silent-zero signal to `/todo`, and proves the whole
downstream chain end to end on a fixture. No new matcher, no second write path.

### Research Integration

Every substantive claim in the research report was re-verified against current source before
planning; all confirmed:

- **Write path is correct and complete** — `skill_propagate_completion_summary`
  (`scripts/skill-base.sh:526-551`) guards `task_type != "meta"` and `roadmap_items` non-empty /
  non-`"[]"`, routes through `state-write.sh`. Confirmed by direct read.
- **Matcher is fully implemented, four tiers** — `find_match()`
  (`scripts/roadmap-integration.sh:407-451`) implements `explicit_task_ref`,
  `explicit_roadmap_item`, `exact_title_match`/`title_match`, `keyword_match`. Confirmed by
  direct read; there is no unimplemented placeholder tier.
- **Implementation agents never see ROADMAP.md** — grep for `roadmap`/`roadmap_path` across
  `skill-implementer/SKILL.md`, `skill-implementer-hard/SKILL.md`,
  `general-implementation-agent.md`, `general-implementation-hard-agent.md` returns only the
  Stage 6a instruction line and the metadata-read plumbing. No `Read specs/ROADMAP.md` anywhere.
  Confirmed as the live root cause.
- **`/todo`'s three-way branch omits the Roadmap section on parseable-and-zero-matches**
  (`commands/todo.md:402-414` dry-run, `:970-988` final summary), and `roadmap_silent_noop` only
  fires when `high_confidence_matches > 0 && annotations_made == 0`. Confirmed by direct read.

**One gap the research report did not cover, found during verification and added to scope**:
`/orchestrate` does **not** dispatch through `skill-implementer`. `skill-orchestrate/SKILL.md`
and `skill-orchestrate-hard/SKILL.md` invoke `$IMPLEMENT_AGENT` directly with their own inline
`context` objects (e.g. `skill-orchestrate/SKILL.md:351`, `:422`, `:483`, `:1225`, `:2009`;
`skill-orchestrate-hard/SKILL.md:702`). Threading `roadmap_path` only into the two implementer
skills would leave the fix entirely dead under `/orchestrate` — which is the very command this
task is being run under. Phase 1 covers all dispatch sites, not just the two the report named.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` was read. No current roadmap item corresponds to this work — the closest
section is "Agent System Quality", but none of its four open items describe roadmap-sync
plumbing. This plan advances no existing roadmap item. (`roadmap_flag` is not set for this
invocation, so no roadmap review/update phases are injected.)

## Goals & Non-Goals

**Goals**:

- Every dispatch path that reaches an implementation agent supplies `roadmap_path` in its
  delegation/context object.
- Both implementation agents load ROADMAP.md read-only before generating completion data, and
  Stage 6a becomes a directive check against the loaded text rather than an unanchored "only
  include if it clearly maps".
- `/todo` reports "eligible tasks existed, open roadmap items existed, zero matched" as a
  distinct, visible signal — not as an omitted section.
- The downstream chain (populated `roadmap_items` in `.return-meta.json` -> state.json ->
  `/todo` annotation of the matching ROADMAP.md item) is demonstrated on a fixture, with the
  `task_type == "meta"` suppression demonstrated alongside it.

**Non-Goals** (each is either already satisfied or explicitly out of scope):

- **Implementing or deleting a "Priority 3" matcher tier** (original work item 4). Verified moot:
  `find_match()` implements all four tiers today, with medium/low confidence deliberately scoped
  as report-only. No placeholder text exists in `commands/todo.md`. Nothing to implement, nothing
  to delete.
- **Reconciling Priority 2 with the no-task-references rule** (original work item 5). Verified
  moot: `.claude/rules/no-task-references-in-deliverables.md` scopes itself to "the entire
  repository EXCEPT `specs/**/*`", and its exemption taxonomy Category 1 gives `specs/**`
  artifacts a path-level exemption with no marker required. `specs/ROADMAP.md` is inside that
  exemption, and already carries informal task-number prose with no violation. No edit needed.
- **A second write path.** `skill_propagate_completion_summary` remains the sole writer.
- **A post-hoc fuzzy matcher in postflight.** Derivation stays in the agent's judgment.
- **Touching `/plan --roadmap`'s direct-write phase-injection mechanism.** It is orthogonal,
  already exists, defaults off, and cannot double-annotate (`roadmap-integration.sh` skips items
  containing `*(Completed:`). Leave it alone.
- **Changing `roadmap-integration.sh`'s output schema.** The new `/todo` signal is derived from
  data already in `/todo`'s scope.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| An agent over-claims a roadmap match, producing a wrong annotation | M | M | Stage 6a requires the copied text be verbatim from an open `- [ ]` item; `explicit_roadmap_item` only fires at `high` confidence on exact/substring match, so a paraphrase silently fails to match rather than mis-annotating |
| Adding a ROADMAP.md read to every non-meta implementation run adds cost | L | H | One `Read` of a ~40-line file; the stage is explicitly skip-on-missing and skip-for-meta |
| The new `/todo` no-match line becomes noise on ordinary runs | M | M | Gate on all three conditions (eligible tasks non-empty AND eligible matches empty AND at least one open checkbox remains), so it only fires in the genuinely-informative case |
| A dispatch site is missed, leaving the fix dead on one path | H | M | Phase 1 carries a Scope Hypothesis with an explicit enumeration command; Phase 5 re-greps for residual sites as a gate |
| Source-store edits do not reach the live repo | H | M | Phase 5 runs the deploy regeneration and the deploy gates; `.claude/**` is never hand-edited |
| Editing `commands/todo.md` bash regresses the existing three-way branch | M | L | The new signal is a fourth branch added alongside, never a rewrite of the existing three; the parseable/silent_noop invariants are restated unchanged |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 3 |
| 3 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 1, 2, and 3 touch disjoint file sets
(skills+orchestrators / agents / `commands/todo.md`) and share no ordering constraint.

---

### Phase 1: Thread `roadmap_path` into every implementation-agent dispatch context [COMPLETED]

**Goal**: Every path that spawns an implementation agent supplies `"roadmap_path":
"specs/ROADMAP.md"` in its delegation/context object, mirroring `skill-planner/SKILL.md:207`.

**Tasks**:

- [x] Enumerate all dispatch sites before editing (see Scope Hypothesis below); record the actual
      list found. *(completed: confirmed exactly 8 sites — 2 implementer skills + 5 in
      skill-orchestrate/SKILL.md (lines 353, 424, 485, 1227, 2009) + 1 in
      skill-orchestrate-hard/SKILL.md (dispatch_context block ~676-686) — matching the Scope
      Hypothesis exactly)*
- [x] `skills/skill-implementer/SKILL.md` Stage 4: add `"roadmap_path": "specs/ROADMAP.md",` to
      the delegation-context JSON block, placed adjacent to `plan_path` (matches the planner
      skill's placement convention). *(completed)*
- [x] `skills/skill-implementer-hard/SKILL.md`: same addition to its delegation-context JSON
      block (around line 254, near `plan_path`). *(completed)*
- [x] `skills/skill-orchestrate/SKILL.md`: add `roadmap_path: "specs/ROADMAP.md"` to each inline
      `context` object in the implementation-dispatch tables (initial dispatch, resume dispatch,
      the third dispatch table, the post-revise re-dispatch, and the multi-task dispatch).
      *(completed: 5 sites)*
- [x] `skills/skill-orchestrate-hard/SKILL.md`: same addition to its `$IMPLEMENT_AGENT` dispatch
      context. *(completed)*
- [x] Do NOT add `roadmap_path` to research or planner dispatch contexts — they already have it.
      *(completed: verified via diff review, no research/planner context objects touched)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: `local`

**Scope Hypothesis**: The hypothesis is that there are exactly six implementation-agent dispatch
context objects across four files (two implementer skills; five in `skill-orchestrate/SKILL.md`
at approximately lines 351, 422, 483, 1225, 2009; one in `skill-orchestrate-hard/SKILL.md` at
approximately line 702 — i.e. eight objects total). Confirm at implementation time, do not
assume: run
`grep -rn 'IMPLEMENT_AGENT\|orchestrator_mode: true\|delegation_path.*implement' agent-system/extensions/core/skills/skill-implementer/SKILL.md agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md agent-system/extensions/core/skills/skill-orchestrate/SKILL.md agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
and enumerate every context object that reaches an implementation agent. If the real count
differs from the hypothesis, edit what is actually there and record the corrected count in the
phase progress file.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` - add `roadmap_path` to Stage
  4 delegation context
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` - same
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - add `roadmap_path` to each
  implementation-dispatch `context` object
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - same

**Verification**:

- `grep -c 'roadmap_path' ` on each edited file returns the expected non-zero count.
- Every dispatch site enumerated by the Scope Hypothesis command now carries `roadmap_path`;
  re-run the command and confirm zero residual implementation-dispatch contexts lack the field.
- No research or planner dispatch context was modified (`git diff` review).

---

### Phase 2: Add roadmap loading and tighten Stage 6a in both implementation agents [COMPLETED]

**Goal**: Both implementation agents read ROADMAP.md read-only before generating completion data,
and Stage 6a becomes a directive check against the loaded text.

**Tasks**:

- [x] `agents/general-implementation-agent.md`: add a new read-only stage immediately before
      Stage 6a — "Load Roadmap Context" — modelled on `planner-agent.md`'s Stage 2.5. Contract:
      if `roadmap_path` is present in the delegation context AND the file exists AND
      `task_type != "meta"`, `Read` it and retain the open (`- [ ]`) item texts. If the field is
      absent or the file is missing, skip gracefully with no warning escalation. State
      explicitly: **MUST NOT** modify, write to, or create ROADMAP.md — this is a read-only
      consultation (same wording contract as `planner-agent.md` Stage 2.5). *(completed: added
      as "Stage 6-roadmap: Load Roadmap Context", immediately before Stage 6a)*
- [x] `agents/general-implementation-agent.md` Stage 6a (currently lines 546-549): replace
      "Optionally generate `roadmap_items` ... Only include if the task clearly maps to specific
      roadmap items" with a directive: check the loaded roadmap text for open (`- [ ]`) items this
      task's work closes; if one clearly matches, copy its item text **verbatim** into
      `roadmap_items`; if none matches, omit the field entirely. Add a note that a paraphrase will
      silently fail to match downstream, so verbatim copying is required, and that omission is
      preferred over `[]` (both are treated identically by the writer's guard, but omission
      states intent). *(completed)*
- [x] `agents/general-implementation-hard-agent.md`: add the equivalent "Load Roadmap Context"
      stage and update its Stage-6a-equivalent pointer (around line 451-452) so the hard agent
      carries the same directive rather than only pointing at the shared format doc. *(completed:
      added as "Stage 5.9: Load Roadmap Context"; Stage 7 pointer text now carries the directive)*
- [x] Leave the `completion_data` examples intact; update the non-meta example only if its
      wording now contradicts the directive. *(completed: examples left unchanged — neither
      contradicted the new directive)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: `local`

**Files to modify**:

- `agent-system/extensions/core/agents/general-implementation-agent.md` - new Load Roadmap
  Context stage; Stage 6a directive rewrite
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` - same

**Verification**:

- Both agents contain a stage that reads `roadmap_path` and both contain the read-only
  MUST-NOT-modify clause.
- Stage 6a in both no longer contains the word "Optionally" for `roadmap_items`, and does contain
  the verbatim-copy requirement.
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` passes (frontmatter
  and no-task-references bullet coverage unaffected).

---

### Phase 3: Add a distinct silent-zero signal to `/todo`'s Roadmap branch [COMPLETED]

**Goal**: `/todo` distinguishes "eligible completed tasks and open roadmap items both existed,
but nothing matched" from "there was legitimately nothing to compare", in both the dry-run output
and the final summary.

**Tasks**:

- [x] `commands/todo.md` Step 3.5.4 (after the `roadmap_eligible_matches` filter, where
      `roadmap_eligible_tasks[]`, `roadmap_eligible_matches`, and `roadmap_state` are all in
      scope): derive a new boolean `roadmap_no_match`. Compute the open-checkbox count from
      `roadmap_state` with jq (the items carry a `completed` boolean —
      `[.phases[].checkboxes.items[]? | select(.completed == false)] | length`), null-safe against
      the documented fallback value `'{"phases":[],"status_tables":[]}'`. Set
      `roadmap_no_match=true` iff: `roadmap_eligible_tasks[]` is non-empty AND
      `roadmap_eligible_matches[]` is empty AND the open-checkbox count is greater than zero.
      Define it unconditionally (including in both error-handling fallback blocks, as
      `roadmap_no_match=false`) so no downstream branch reads an unbound variable — matching the
      existing treatment of `high_confidence_matches`/`silent_noop`. *(completed: added as
      Step 3.5.5, immediately after the eligibility filter)*
- [x] Add `roadmap_no_match` to the Step 3.5 "Track:" bullet list with a one-line description.
      *(completed)*
- [x] `commands/todo.md` Step 4 (dry-run, currently the three-way branch at lines 402-414): add a
      fourth branch. Keep the existing three verbatim; narrow the first branch's omission
      condition to also require `roadmap_no_match == false`. New branch text:
      `No roadmap items matched this run's {N} eligible completed task(s) against {M} open roadmap item(s) -- no task populated roadmap_items; see completion_data.roadmap_items`
      *(completed)*
- [x] `commands/todo.md` final summary (lines 940-988): add the same line to the output template,
      add `OR roadmap_no_match == true` to the "Roadmap" row of the Section Inclusion Rules table,
      and add the fourth bullet to the branch list below it, again narrowing the omission bullet.
      *(completed)*
- [x] Restate the existing invariant unchanged: omission is permitted only when the roadmap parsed
      successfully AND there was genuinely nothing to compare. *(completed: invariant restated
      with the added `roadmap_no_match == false` conjunct in both locations)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: `local`

**Scope Hypothesis**: The hypothesis is that exactly four regions of `commands/todo.md` need
editing (Step 3.5.3/3.5.4 derivation + fallbacks, the Step 3.5 "Track:" list, the Step 4 dry-run
branch at ~402-414, and the final-summary branch + inclusion table at ~940-988). Confirm with
`grep -n 'roadmap_silent_noop\|silent_noop\|roadmap_structure.parseable' agent-system/extensions/core/commands/todo.md`
— every site that currently branches on `silent_noop` or `parseable` is a candidate site for the
new fourth branch. Record the actual list edited.

**Files to modify**:

- `agent-system/extensions/core/commands/todo.md` - `roadmap_no_match` derivation, fallback
  defaults, Track list, dry-run fourth branch, final-summary fourth branch and inclusion table

**Verification**:

- `bash -n` is not applicable (markdown), but every added bash fence must be syntactically valid:
  extract and `bash -n` the modified fences.
- `roadmap_no_match` is assigned in the main path and in both error-handling fallback blocks
  (grep count >= 3 assignment sites).
- Both the dry-run and final-summary sections now describe four branches, and the omission branch
  in each requires `roadmap_no_match == false`.

---

### Phase 4: End-to-end fixture test [COMPLETED]

**Goal**: Demonstrate — not argue — that a populated `roadmap_items` flows through the writer into
`state.json` and produces a ROADMAP.md annotation, that a `meta` task writes none, and that the
new `roadmap_no_match` derivation fires exactly on the intended condition.

**Tasks**:

- [x] Create `agent-system/extensions/core/scripts/tests/test-roadmap-items-producer.sh`,
      following the conventions of an existing suite (read
      `scripts/tests/test-skill-base-lifecycle.sh` for its `mktemp -d` fixture-repo pattern, since
      `skill_propagate_completion_summary` routes writes through `state-write.sh` and needs a repo
      shaped like the real one). *(completed)*
- [x] **Case 1 (the verification bar, end to end)**: fixture `ROADMAP.md` with a known open
      `- [ ] **Item text**: ...` checkbox; fixture `state.json` with one `completed`, non-`meta`
      task carrying a roadmap-related `completion_summary`. Call
      `skill_propagate_completion_summary` with a `roadmap_items` value whose entry is the
      verbatim item text; assert `state.json` now carries that `roadmap_items`. Then run
      `roadmap-integration.sh --roadmap <fixture> --state <fixture> --annotate` and assert the
      fixture ROADMAP.md item is now annotated with the `*(Completed: ...)*` suffix and that
      `annotation_summary.annotations_made` is 1 with `match_type: explicit_roadmap_item` at
      `high` confidence. *(completed: 4/4 assertions pass)*
- [x] **Case 2 (meta suppression preserved)**: same fixture, `task_type == "meta"`; assert
      `skill_propagate_completion_summary` writes `completion_summary` but no `roadmap_items` key
      to state.json. *(completed: 2/2 assertions pass)*
- [x] **Case 3 (paraphrase does not mis-annotate)**: `roadmap_items` containing a paraphrase
      rather than verbatim text; assert no `high`-confidence `explicit_roadmap_item` match is
      produced (this is the guard the Phase 2 verbatim requirement relies on). *(completed)*
- [x] **Case 4 (`roadmap_no_match` derivation)**: exercise the Phase 3 jq derivation in isolation
      against three inputs — (a) eligible tasks non-empty, matches empty, open checkboxes > 0 ->
      `true`; (b) eligible tasks empty -> `false`; (c) zero open checkboxes -> `false`.
      *(completed: 3/3 sub-cases pass)*
- [x] `chmod +x` the new suite (an un-executable suite is reported as a loud `[SKIP]` by
      `run-all.sh`, not a pass). *(completed)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-roadmap-items-producer.sh` and
      confirm all cases pass. *(completed: 11 passed, 0 failed, exit 0. Also confirmed discovered
      and passing under `run-all.sh` in source-store mode; two unrelated, pre-existing suite
      failures — `test-claude-refresh-matcher.sh` and `test-lint-state-writer-boundary.sh` — were
      observed only when run as part of the full batch, pass individually in isolation, and touch
      files this plan never modifies; not in scope for this task)*

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: `full`

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-roadmap-items-producer.sh` - new test suite

**Verification**:

- The new suite exits 0 with all four cases reported as passing.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet` discovers and runs the new
  suite (it appears in the summary; it is not `[SKIP]`ped).
- Case 1's assertion is on observed file content (annotated ROADMAP.md text and state.json
  `roadmap_items`), never on a claim in prose.

---

### Phase 5: Deploy regeneration and full gate run [COMPLETED]

**Goal**: The source-store edits reach the live `.claude/` tree and every repository gate passes.

**Tasks**:

- [x] Confirm no `.claude/**` file was hand-edited at any point:
      `git status --short .claude/` before regeneration, and review the whole diff for edits whose
      target path is `.claude/`. *(completed: zero hits before regeneration)*
- [x] Regenerate the deploy tree:
      `bash agent-system/extensions/core/scripts/deploy-headless.sh` (default non-destructive
      resync mode; do NOT use `--wipe`). *(completed: also required registering the new test
      suite in `agent-system/extensions/core/manifest.json`'s `provides.scripts` allow-list —
      `scripts/tests/*.sh` is not glob-discovered by the deploy engine, it is manifest-driven; the
      new file was silently absent from `.claude/scripts/tests/` until registered, then deployed
      correctly on the second regeneration)*
- [x] Run `bash .claude/scripts/verify-deploy.sh` and confirm all gates pass, including the
      no-task-references gate. *(21/23 pass. 2 pre-existing failures, both confirmed unrelated to
      this task's changes and out of scope: (1) `test-claude-refresh-matcher.sh` — a flaky
      live-process/pid-matching suite, `git diff --stat` against master confirms zero lines
      touched by this plan; (2) `validate-state.sh --deep`'s dangling-dependency check on task 9's
      own `dependencies: [1015]` entry (an unrelated task, vaulted target), pre-existing before
      any commit in this plan. This task's OWN dangling dependency (`5 -> 1004`, the plan's
      already-declared-satisfied dependency) WAS fixed in-scope via `state-write.sh` since it is
      this task's own metadata, consistent with the plan's own "Dependencies: None" declaration.
      No-task-references gate: PASS)*
- [x] Run `bash .claude/scripts/tests/run-all.sh` and confirm zero failing suites and zero
      `[SKIP]`s for the new suite. *(the new suite passes cleanly and is discovered, not
      `[SKIP]`ped; the pre-existing `test-claude-refresh-matcher.sh` failure above is the sole
      other suite failure, confirmed unrelated)*
- [x] Run `bash .claude/scripts/check-extension-docs.sh` and
      `bash .claude/scripts/lint/lint-agent-contracts.sh`; both exit 0. *(completed: both PASS)*
- [x] Residual-site sweep: re-run Phase 1's enumeration command against the deployed tree and
      confirm every implementation-agent dispatch context carries `roadmap_path`. *(completed: all
      8 sites confirmed — 1 + 1 + 5 + 1 across the four deployed skill files)*
- [x] Confirm no task-number citations were introduced outside `specs/**` (the deliverable rule) —
      `verify-deploy.sh`'s gate covers this, but confirm the gate actually ran and passed rather
      than assuming. *(completed: re-ran `check-task-references.sh --quiet` directly — 0
      unexempted occurrences across all 4 deliverable trees)*

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4

**Verification Tier**: `full`

**Files to modify**:

- None directly (regeneration writes `.claude/**` as a deploy artifact, which is the sanctioned
  deploy path and not a boundary violation)

**Verification**:

- `verify-deploy.sh` exits 0.
- `run-all.sh` exits 0 with the new suite counted as PASS.
- `check-extension-docs.sh` and `lint-agent-contracts.sh` exit 0.
- The deployed `.claude/skills/skill-implementer/SKILL.md` (and the other three) contain
  `roadmap_path`, proving the source edits propagated.

---

## Testing & Validation

- [ ] A completed non-meta task with a verbatim `roadmap_items` entry produces a populated
      `roadmap_items` in state.json and a subsequent annotation run marks the matching ROADMAP.md
      item — demonstrated on a fixture (Phase 4, Case 1).
- [ ] `task_type == "meta"` still writes no `roadmap_items` (Phase 4, Case 2).
- [ ] A paraphrased (non-verbatim) claim does not produce a high-confidence annotation
      (Phase 4, Case 3).
- [ ] `roadmap_no_match` is true exactly when eligible tasks existed, no matches were found, and
      open roadmap checkboxes remain (Phase 4, Case 4).
- [ ] Every implementation-agent dispatch context carries `roadmap_path` (Phases 1, 5).
- [ ] Both implementation agents load ROADMAP.md read-only and carry the verbatim-copy directive
      (Phase 2).
- [ ] All repository gates pass after deploy regeneration (Phase 5).

## Artifacts & Outputs

- Modified: `skills/skill-implementer/SKILL.md`, `skills/skill-implementer-hard/SKILL.md`,
  `skills/skill-orchestrate/SKILL.md`, `skills/skill-orchestrate-hard/SKILL.md` (all under
  `agent-system/extensions/core/`)
- Modified: `agents/general-implementation-agent.md`,
  `agents/general-implementation-hard-agent.md`
- Modified: `commands/todo.md`
- New: `scripts/tests/test-roadmap-items-producer.sh`
- Regenerated: `.claude/**` (deploy artifact)
- Implementation summary in `specs/005_implement_roadmap_items_producer/summaries/`

## Rollback/Contingency

Every change is additive and confined to the source store plus one new test file. To revert:
`git revert` the phase commits (each phase commits separately per the commit-per-green-substep
mandate), then re-run `deploy-headless.sh` to regenerate `.claude/` from the reverted source.

Per-phase contingencies:

- **Phase 1 finds more dispatch sites than hypothesised**: edit all of them; the phase is still
  one agent run (each edit is a one-line JSON addition). Record the corrected count.
- **Phase 3's jq derivation proves awkward against the `roadmap_state` shape**: fall back to
  adding an additive `checkboxes_open` field to `roadmap_structure` in `roadmap-integration.sh`
  (schema-additive, safe for the other consumer `commands/review.md`) and derive from that
  instead. Prefer the in-`/todo` derivation; this is the fallback only.
- **Phase 4's fixture cannot drive `skill_propagate_completion_summary` in a temp repo**: split
  the demonstration — assert the writer's behaviour by invoking `state-write.sh` on the fixture
  directly, and keep the `roadmap-integration.sh --annotate` half unchanged. Do not downgrade
  Case 1 to a prose argument; the verification bar requires observed file content.
- **Phase 5's `deploy-headless.sh` fails**: leave `.claude/` as-is (the default mode is
  non-destructive), report the failure, and mark the task `[PARTIAL]` rather than hand-editing
  `.claude/**` to work around it.

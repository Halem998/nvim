# Implementation Plan: Task #872

- **Task**: 872 - Add a review/revise "dream" mode to the existing /distill command
- **Status**: [NOT STARTED]
- **Effort**: 5.5 hours
- **Dependencies**: 869, 870, 871 (all complete -- event store, capture layers 1 and 2)
- **Research Inputs**: specs/872_distill_review_revise_dream_mode/reports/01_dream_mode_research.md
- **Artifacts**: plans/01_distill-dream-mode.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, no-task-references-in-deliverables.md, multi-task-creation-standard.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add `--dream` as an 8th sub-mode to the existing `/distill` command: it ingests the unified event
store via `events-query.sh`, re-reviews the memory vault against captured event evidence, and
surfaces agent-system improvement proposals as a separate deliverable. This is a
documentation/spec-writing task -- no shell script is authored and no script under
`agent-system/extensions/core/scripts/` is modified. All new behavior is expressed as prose plus
pseudocode inside the existing spec-driven skill-memory execution model, reusing the exact
seven-step shape (validate-on-read -> candidates -> dry-run -> mandatory AskUserQuestion stop ->
apply via existing UPDATE/EXTEND/CREATE/tombstone primitives -> batch index regen -> distill-log
entry) that every other mutating sub-mode already follows. Definition of done: all six in-scope
files are internally consistent, the four parallel sub-mode tables agree, and the "no events yet"
degraded path is documented as a first-class outcome.

### Research Integration

The research report resolved every open design decision; this plan carries them verbatim rather
than reopening them:
- `--dream` is a distinct flag in the first-match-wins dispatch chain, not an overload of
  `--refine --deep`.
- Ingestion is exclusively `events-query.sh` (`--format json-array` / `--format summary-counts`,
  `--since {last_dream}`); the script's own header forbids hand-rolled `jq` against the store.
- Correlation is two-tier: task-number substring match against a memory's free-text `source`
  frontmatter, then keyword/topic overlap reusing the existing overlap formula. No new formula.
- The three-strikes recurrence threshold is reused from hard-mode's H5/H6 precedent, not
  reinvented.
- Memory revisions and improvement proposals stay two distinct sections with different
  destinations and different write permissions.

**Verified live during planning** (not taken on faith from the report): `specs/events.jsonl` is
absent in this repo, and `events-query.sh --format summary-counts` returns
`{"total_events":0,"by_category":{},"by_event_type":{}}` while `--format json-array` returns `[]`,
both exiting 0. The "no events yet" path is therefore a real, reachable, non-error path on day
one -- it is the *default* experience until the store accumulates, which is why Phase 2 treats it
as a first-class documented outcome rather than an edge case.

**Verified live**: the deployed `.claude/commands/distill.md` is byte-identical to the
`agent-system/extensions/memory/` source (`diff -q` clean), confirming deployed copies are pure
sync targets and correctly out of scope.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no roadmap consultation was
requested; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Add `--dream` to `/distill`'s dispatch chain and every parallel sub-mode table, following the
  established sub-mode shape exactly.
- Specify event ingestion through `events-query.sh` only, including the verified "no events yet"
  degraded path.
- Specify event-to-memory correlation (task-number + keyword overlap) and
  corroborated/contradicted/gap classification, reusing existing formulas and thresholds.
- Specify memory revision via the existing UPDATE/tombstone/CREATE primitives behind a mandatory
  AskUserQuestion stop, with `--dry-run` performing zero writes.
- Specify improvement proposals as a separate deliverable at Required-components-only
  Multi-Task Creation Standard compliance.
- Keep all six in-scope files mutually consistent.

**Non-Goals**:
- No changes to any script under `agent-system/extensions/core/scripts/` (`events-query.sh`,
  `events-append.sh`, `orchestrator-postflight.sh`, either hook) or to `events-schema.json` /
  `events-format.md`. Verified sufficient as-is.
- No new shell script for dream mode.
- No edits to `.claude/` or `.opencode/` deployed copies (sync targets; CLAUDE.md is
  auto-generated from `EXTENSION.md`).
- No full Multi-Task Creation Standard compliance (no topic grouping, dependency interview,
  Kahn's-algorithm ordering, or DAG visualization). Deliberate v1 scope.
- **No edit to `multi-task-creation-standard.md`'s compliance table.** The research flagged adding
  a `/distill --dream` row as desirable, but that file sits outside the task's declared
  memory-extension scope. Recorded as a follow-up below rather than smuggled in -- see
  Risks.
- Dream mode never edits arbitrary skill/rule/context/doc files as a side effect.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Keyword-overlap correlation yields false positives (healthy memory flagged contradicted by an unrelated blocker sharing vocabulary) | M | H | Spec requires every AskUserQuestion option description to cite the specific correlated event IDs/messages as evidence. The human gate is the safety net; the heuristic is not trusted alone. |
| The four parallel sub-mode tables (distill.md availability, SKILL.md dispatch, EXTENSION.md commands, distill-usage quick reference) drift out of sync | M | M | Phase 6 is a dedicated cross-table consistency check enumerating all four locations explicitly. |
| Implementer adds "task 872" citations to the new table rows, copying the existing `[available - task 450]` pattern already present in `distill.md` and SKILL.md | L | **H** | Explicit MUST NOT in Phases 1, 2, 5 with a concrete durable-anchor replacement. The surrounding lines are themselves rule violations and are actively misleading as a template. Do not "fix" the pre-existing ones (out of scope); just do not add new ones. |
| Event-store growth makes a full first dream run slow | L | M | `last_dream` + `--since` bounds every run after the first; spec documents the first run's one-time cost. |
| Event-evidence-driven UPDATE produces low-quality generated prose written blind | M | M | Spec requires showing the *proposed new memory body* for review at the gate, not a bare "update memory X? yes/no". |
| `manifest.json` is edited to force a change it does not need | L | M | Phase 5 makes "verify and record no-change-needed" an explicit, legitimate outcome. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 3 |
| 4 | 5 | 1, 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel. Phases 2, 3, and 4 all write the same
SKILL.md section and are strictly sequential; Phase 1 owns a different file and is parallel-safe
with Phase 2.

---

### Phase 1: Command-layer dispatch in distill.md [COMPLETED]

**Goal**: `/distill --dream` parses, validates, and delegates correctly at the command layer.

**Tasks**:
- [x] Add `elif "--dream" in $ARGUMENTS: sub_mode = "dream"` to the `<argument_parsing>` if/elif
      chain, placed after `--gc` and before `--auto` (preserving first-match-wins semantics).
      *(completed)*
- [x] Add `--dream` to the numbered Sub-Mode Dispatch list in `<step_1>` prose as item 8.
      *(completed: appended as item 8 after auto in the prose list; the if/elif code chain
      independently places dream before auto per first-match-wins -- the two orderings do not
      conflict since the flags are mutually exclusive)*
- [x] Add a `dream` row to the Sub-Mode Availability table in `<workflow_execution><step_1>`.
      **MUST NOT** add a task-number citation in the `Task` column -- the existing
      `449`/`450`/`451`/`452` values violate the no-task-references rule. Write `Available`
      in the Status column and use a durable anchor (e.g. `Event-store review`) or an em-dash in
      the Task column. *(completed: used "Event-store review" as the durable anchor)*
- [x] Add a "Dream mode:" block to `<step_3>` Present Results describing: the two distinct output
      sections (memory revisions, improvement proposals), the no-events notice, dream-log.json
      logging, and state.json `memory_health` update. *(completed)*
- [x] Update `<error_handling><argument_errors>` flag lists to include `--dream` in both the
      unknown-flag and unknown-sub-mode messages. *(completed)*
- [x] Update `<state_management>` `<reads>` to add `specs/events.jsonl` (via events-query.sh) and
      `.memory/dream-log.json`; `<writes>` to add `.memory/dream-log.json` and note dream-mode
      frontmatter/content mutation of `.memory/10-Memories/*.md`. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/memory/commands/distill.md` - dispatch chain, availability table,
  present-results, error messages, state management

**Verification**:
- The if/elif chain still has exactly one first-match-wins path per flag; `--dream` cannot be
  shadowed by an earlier branch.
- `grep -n "task [0-9]" ` over the diff region returns no new hits.
- `--dream` appears in both error-message flag lists.

---

### Phase 2: SKILL.md dispatch row, event ingestion, and correlation [COMPLETED]

**Goal**: skill-memory knows dream mode exists, how to read the event store (including when it is
empty), and how to correlate events to memories.

**Tasks**:
- [x] Add a `dream` row to the `### Sub-Mode Dispatch` table (SKILL.md ~line 1073). Same
      no-task-number constraint as Phase 1 -- the adjacent `Available (task 449)` cells are
      pre-existing violations, not a template to copy. *(completed)*
- [x] Open a new `### Sub-Mode: dream` section. Placement: after `### Sub-Mode: auto` and before
      `### Distill Log Schema`, so the mode sections stay contiguous. *(completed)*
- [x] Write `#### Edge Case Checks`: run validate-on-read; count non-tombstoned memories; return
      early if the vault is empty (mirroring refine's early-return wording). *(completed)*
- [x] Write `#### Event Ingestion` specifying, in order: (1) the cheap gate
      `events-query.sh --format summary-counts [--since {last_dream}]`; (2) the deviation/blocker
      pull `events-query.sh --category deviation|blocker --format json-array [--since ...]`;
      (3) the reflection pull `events-query.sh --event-type reflection --format json-array
      [--since ...]`. State explicitly that hand-rolled `jq` against `specs/events.jsonl` is
      prohibited (the script's own header rule). *(completed)*
- [x] Document why the event-store copy of reflections is used rather than `state.json`'s
      `reflection` field: the store is append-only across a task's whole history, while
      `state.json`'s field is overwrite-only/most-recent-only. *(completed)*
- [x] Write `#### No Events Yet (Degraded Path)` as a **first-class, non-error** outcome, citing
      the verified behavior (`total_events: 0` / `[]`, exit 0, absent store). Spec the user-facing
      notice and the continuation rule: dream review proceeds using the existing scoring engine
      alone (staleness/duplicate/size) and reports zero correlations. This is the default
      experience until the store accumulates and MUST NOT be written as an error branch.
      *(completed)*
- [x] Write `#### Event-to-Memory Correlation`: tier (a) task-number substring match of an event's
      non-null `task` field against a memory's free-text `source` frontmatter; tier (b) fallback
      keyword/topic overlap reusing the existing overlap formula from `### Overlap Scoring` --
      reference it by section name, do not restate or fork it. *(completed)*
- [x] Write `#### Classification` defining corroborated / contradicted / gap, and state the
      three-strikes (>=3 occurrences at the same checkpoint/event_type) recurrence threshold,
      anchoring it to the hard-mode divergence-audit precedent by name rather than by task number.
      *(completed: anchored to "Convergence Policing Contract's Divergence Audit precedent
      (context/contracts/convergence.md)" by document name)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/memory/skills/skill-memory/SKILL.md` - dispatch table + first half of
  the dream section

**Verification**:
- Every documented ingestion call is a real `events-query.sh` invocation whose flags exist in the
  script's usage block (`--category`, `--event-type`, `--since`, `--format`).
- The no-events path is stated as a normal outcome with a visible notice, never as an error.
- The overlap formula is referenced, not duplicated.

---

### Phase 3: SKILL.md dream section -- memory revision execution [COMPLETED]

**Goal**: Specify how classified memories are revised, entirely through existing primitives and
behind a mandatory human gate.

**Tasks**:
- [x] Write `#### Dry-Run Behavior`: `--dry-run` prints the full three-bucket classification with
      counts and evidence citations and performs zero writes, matching the contract every other
      sub-mode honors. *(completed)*
- [x] Write `#### Interactive Selection -- MANDATORY STOP`, reusing the existing mandatory-stop
      banner style. Specify `AskUserQuestion` with `multiSelect`. *(completed)*
- [x] Spec the **corroborated** handling: no write; noted in the dream summary/log only.
      *(completed)*
- [x] Spec the **contradicted/stale** handling with three options: (i) UPDATE via the existing
      `### UPDATE Operation` template (old guidance to `## History`, corrected guidance as new
      main content, sourced from event evidence); (ii) tombstone via the existing frontmatter
      pattern with a new `tombstone_reason: "dream_superseded"` value (new *value*, same field
      shape as merge/purge -- not a new schema); (iii) skip. *(completed)*
- [x] Spec the **gap** handling: CREATE candidate via the existing `### CREATE Operation`
      template, sourced from event detail/message. State the escalation discriminator explicitly:
      durable domain/technique knowledge (fits the existing
      TECHNIQUE/PATTERN/CONFIG/WORKFLOW/INSIGHT taxonomy) stays a memory; a *system change*
      (skill/hook/rule/doc should differ) escalates to a Phase 4 improvement proposal instead.
      *(completed)*
- [x] Require that each option's `description` cites the specific correlated event IDs/messages as
      evidence, and that a proposed UPDATE shows the **proposed new memory body** for review --
      not a bare yes/no confirmation. *(completed)*
- [x] Write `#### Batch Index Regeneration`: after all writes, regenerate memory-index.json,
      index.md, and 10-Memories/README.md as one batch via the existing
      `### Index Regeneration Pattern` / `### JSON Index Maintenance` procedures. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 2

**Files to modify**:
- `agent-system/extensions/memory/skills/skill-memory/SKILL.md` - dream section revision half

**Verification**:
- Every write path routes through a named existing primitive; no new mutation primitive is
  introduced.
- No write path bypasses the AskUserQuestion stop.
- `--dry-run` is stated to perform zero writes on every path.

---

### Phase 4: SKILL.md dream section -- proposals, logging, and auto exclusion [COMPLETED]

**Goal**: Specify the separate improvement-proposal deliverable and all persistence/exclusion
wiring.

**Tasks**:
- [x] Write `#### Improvement Proposals`, stated up front as a **separate deliverable** from memory
      revision, never merged into one list (different destinations, different write permissions).
      *(completed)*
- [x] Spec proposal discovery: recurring (three-strikes) deviation/blocker events pointing at a
      named skill/hook/rule/lifecycle stage, plus recurring `what_was_hard`/`what_was_missed`
      phrases across reflection events for the same or related task types. *(completed)*
- [x] Spec presentation: `AskUserQuestion` `multiSelect`, one row per candidate, three options --
      "Create as task" / "Note in dream report only" / "Skip". *(completed)*
- [x] Spec the explicit "Yes, create tasks" confirmation gate before any task is created
      (Multi-Task Creation Standard Component 7). *(completed)*
- [x] Spec task creation at **Required-components-only** compliance: each confirmed proposal
      becomes one independent `task_type: "meta"` entry via the same primitive `/task`'s Create
      Task Mode uses (`next_project_number`, append to `active_projects`, `generate-todo.sh`, git
      commit), `file_scope` seeded from the paths the triggering events implicate. Explicitly note
      the intentional v1 gap (no grouping/dependencies/ordering/visualization), matching `/errors`.
      *(completed)*
- [x] Spec the doc-edit-proposal rule: proposals whose remedy is "edit file X's prose" are
      report-only findings. Dream mode MUST NOT edit files outside `.memory/`, `state.json`'s
      `memory_health`, and the dream/distill logs. *(completed)*
- [x] Write `#### Dream Log Schema` for the new `.memory/dream-log.json`, mirroring the
      `distill-log.json` shape (`version`, `operations[]`, `summary`) with dream-specific fields
      (correlation counts, classification buckets, proposals surfaced/created). *(completed)*
- [x] Spec the narrative dream report as **terminal-only output, not a persisted file**
      (ratifying research open decision (b)): `.memory/dream-log.json` is the machine-queryable
      record, and the human-readable synthesis is displayed in-terminal exactly as the bare
      `/distill` health report already is -- which is likewise never written to disk. Do **not**
      create `.memory/20-Indices/dream-report-{date}.md`; `20-Indices/` holds regenerated vault
      indexes, not dated run reports, and adding one would invent a new artifact type for no
      gain. A user who wants the narrative persisted can redirect it. *(completed)*
- [x] Add a `dream` row to `### Distill Log Schema`'s Operation Types table and to the `type`
      enum string; add `total_dreamed` (or equivalent) to the `summary` block. The Task column of
      that table is another pre-existing no-task-reference violation -- do not extend the pattern.
      *(completed: used an em-dash in the Task column)*
- [x] Update `### State Integration`: add `last_dream` and `dream_count` to the `memory_health`
      example, mirroring `last_distilled`/`distill_count`, and add a `dream` column (or fold into
      the existing mutating-sub-mode column) in the field-update-rules table. *(completed: added
      a third `dream` column)*
- [x] Add a `Dream` row to `### Sub-Mode: auto`'s **Explicitly Excluded Operations** table with the
      reason (event-evidence-driven revision is a judgment call requiring human review), and add
      dream to the "Skip ALL interactive operations" list in the auto execution flow. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 3

**Files to modify**:
- `agent-system/extensions/memory/skills/skill-memory/SKILL.md` - proposals, dream-log schema,
  distill-log/state integration updates, auto exclusion

**Verification**:
- Proposals and memory revisions are presented as two distinct sections in the spec.
- The auto-exclusion is stated in both the exclusion table and the execution-flow skip list.
- `last_dream` is defined before Phase 2's `--since {last_dream}` consumer relies on it (same
  file, forward reference is acceptable but must resolve).

---

### Phase 5: Context and extension metadata sync [COMPLETED]

**Goal**: The user-facing usage guide and extension metadata reflect dream mode.

**Tasks**:
- [x] `distill-usage.md`: add `/distill --dream` to the Quick Reference block; add a
      `### Dream (/distill --dream)` sub-mode workflow section (numbered workflow matching the
      other sub-modes' style, including the no-events degraded note); add a dream row to the
      Recommended Maintenance Cadence table; add the `dream-log.json` entry shape (the research
      flagged this as an undocumented schema gap and `distill-usage.md` is in scope); update the
      `--dry-run` line to include dream. *(completed)*
- [x] `distill-usage.md`: update the Auto section's "Explicitly excludes:" sentence to include
      dream. *(completed)*
- [x] `EXTENSION.md`: add a `/distill --dream` row to the Commands table. Note that CLAUDE.md is
      auto-generated from this file via the `claudemd` merge target -- do not hand-edit
      `.claude/CLAUDE.md`. *(completed; .claude/CLAUDE.md untouched)*
- [x] `index-entries.json`: add `dream`/`events` to the `distill-usage.md` entry's `keywords`,
      extend its `summary` to mention event-store review, and refresh its `line_count` to the
      post-edit value. *(completed: line_count updated to 211, verified against `wc -l`)*
- [x] `manifest.json`: **verify** whether any change is needed. Expected outcome: **none** --
      `provides.commands` already lists `distill.md`, no new command/skill/context file is added,
      and `routing` is unchanged. Recording "verified, no change required" is the correct and
      complete result here; do not manufacture an edit to make the file appear touched.
      *(completed: verified -- no change required; `provides.commands` already lists
      `distill.md`, `provides.context` already lists the `project/memory` directory generically
      (covers `distill-usage.md` without a per-file entry), and `routing` is unaffected since
      dream is a sub-mode dispatch inside the existing `skill-memory`/`distill.md`, not a new
      command or skill)*

**Timing**: 1 hour

**Depends on**: 1, 4

**Files to modify**:
- `agent-system/extensions/memory/context/project/memory/distill-usage.md` - quick ref, workflow,
  cadence, dream-log shape, dry-run, auto exclusion
- `agent-system/extensions/memory/EXTENSION.md` - commands table
- `agent-system/extensions/memory/index-entries.json` - keywords, summary, line_count
- `agent-system/extensions/memory/manifest.json` - verify only; no change expected

**Verification**:
- `jq . agent-system/extensions/memory/index-entries.json` and `jq . manifest.json` both parse.
- `line_count` matches actual `wc -l` of the edited `distill-usage.md`.
- No task numbers introduced in any of these files.

---

### Phase 6: Cross-file consistency verification [NOT STARTED]

**Goal**: All parallel tables agree and no rule is violated.

**Tasks**:
- [ ] Verify dream mode appears consistently in all four parallel sub-mode listings:
      `distill.md` availability table, SKILL.md Sub-Mode Dispatch table, `EXTENSION.md` Commands
      table, `distill-usage.md` Quick Reference. Descriptions must not contradict.
- [ ] Verify the auto-exclusion is stated in all three places it belongs: SKILL.md exclusion
      table, SKILL.md auto execution flow skip list, `distill-usage.md` auto section.
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and confirm it exits 0 (or that any
      failure is pre-existing and unrelated -- capture the before/after comparison rather than
      assuming).
- [ ] Run a no-task-references check over the diff: `git diff` filtered for `task [0-9]` /
      `tasks [0-9]` across all files outside `specs/**`. Must return zero **new** hits.
      Pre-existing violations in the untouched surrounding rows stay untouched.
- [ ] Confirm no file under `agent-system/extensions/core/scripts/` was modified:
      `git status --porcelain agent-system/extensions/core/` must be empty.
- [ ] Confirm no `.claude/` or `.opencode/` deployed copy was hand-edited.
- [ ] Re-confirm the documented no-events behavior still matches live output by re-running
      `events-query.sh --format summary-counts` and `--format json-array`.

**Timing**: 0.5 hours

**Depends on**: 5

**Files to modify**: none (verification only)

**Verification**:
- All four sub-mode tables agree.
- Doc-lint exits 0 or fails only in a demonstrably pre-existing, unrelated way.
- Zero new task-number citations; zero core-script modifications.

## Testing & Validation

- [ ] All four parallel sub-mode listings include dream with non-contradicting descriptions.
- [ ] `--dream` is in both `distill.md` error-message flag lists.
- [ ] Dream mode is excluded from `--auto` in all three documented locations.
- [ ] The no-events degraded path is documented as a normal, non-error outcome and matches live
      `events-query.sh` behavior.
- [ ] Every event read is an `events-query.sh` call using flags that exist in its usage block; no
      hand-rolled `jq` against `specs/events.jsonl` is specified anywhere.
- [ ] Every memory write path routes through an existing named primitive
      (UPDATE/EXTEND/CREATE/tombstone) behind a mandatory AskUserQuestion stop.
- [ ] `--dry-run` performs zero writes on every dream path.
- [ ] `index-entries.json` and `manifest.json` parse under `jq`; `line_count` is accurate.
- [ ] `check-extension-docs.sh` exits 0 (or fails identically to its pre-change baseline).
- [ ] Zero new task-number citations outside `specs/**`.
- [ ] `agent-system/extensions/core/` is untouched.

## Artifacts & Outputs

- `agent-system/extensions/memory/commands/distill.md` (modified)
- `agent-system/extensions/memory/skills/skill-memory/SKILL.md` (modified -- new
  `### Sub-Mode: dream` section plus dispatch/log/state/auto-exclusion updates)
- `agent-system/extensions/memory/context/project/memory/distill-usage.md` (modified)
- `agent-system/extensions/memory/EXTENSION.md` (modified)
- `agent-system/extensions/memory/index-entries.json` (modified)
- `agent-system/extensions/memory/manifest.json` (verified; no change expected)
- `specs/872_distill_review_revise_dream_mode/summaries/01_distill-dream-mode-summary.md`

**Runtime-only outputs** (created when `/distill --dream` actually runs, not by this task; outside
file_scope and non-blocking, consistent with every other distill sub-mode):
`.memory/dream-log.json`, `memory_health.last_dream`/`dream_count` in `specs/state.json`, and new
task directories for any confirmed proposal. The narrative report is terminal-only by decision
(see Phase 4) -- no dated report file is written.

**Research open decisions, ratified by this plan**: (a) the state field is `last_dream` /
`dream_count`, mirroring `last_distilled` / `distill_count` (Phase 4). (b) the narrative dream
report is terminal-only; no persisted `dream-report-{date}.md` (Phase 4). (c)
`multi-task-creation-standard.md` is a documented follow-up, not part of this task (Non-Goals).

**Documented follow-up** (deliberately not done here -- outside the declared memory-extension
scope): add a `/distill --dream` row to `multi-task-creation-standard.md`'s Current Compliance
Status table at the Required-components-only level, matching `/errors`' "Partial" framing.

## Rollback/Contingency

All changes are additive edits to six markdown/JSON files in one extension directory, with no
runtime or script surface. `git revert` of the task's commits restores the prior state completely;
no data migration, no deployed-copy divergence (deployed copies are regenerated by the extension
loader from source), and no partially-created runtime artifacts, since dream mode is only ever
*specified* by this task and never executed by it. If a single phase proves wrong, phases are
file-scoped enough to revert individually: Phase 1 (distill.md), Phases 2-4 (SKILL.md), Phase 5
(the remaining three files).

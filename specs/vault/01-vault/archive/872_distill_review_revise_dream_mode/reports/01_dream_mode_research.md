# Research Report: Task #872

**Task**: 872 - /distill review/revise (dream) mode
**Started**: 2026-07-15T08:15:00Z
**Completed**: 2026-07-15T08:45:00Z
**Effort**: Estimated 4-6 hours (documentation-only meta task; six files)
**Dependencies**: 869, 870, 871 (all complete — event store, capture layer 1, capture layer 2)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/memory/{commands/distill.md, skills/skill-memory/SKILL.md, context/project/memory/distill-usage.md, EXTENSION.md, manifest.json, index-entries.json}`
- Codebase: `agent-system/extensions/core/scripts/{events-query.sh, events-append.sh, orchestrator-postflight.sh}`
- Codebase: `agent-system/extensions/core/context/{schemas/events-schema.json, formats/events-format.md}`
- Codebase: `agent-system/extensions/core/hooks/{events-log-artifact.sh, events-log-lifecycle.sh}`
- Codebase: `.claude/docs/reference/standards/multi-task-creation-standard.md`
- Codebase: `.memory/distill-log.json`, `.memory/10-Memories/*.md`, `specs/state.json`
**Artifacts**:
- `specs/872_distill_review_revise_dream_mode/reports/01_dream_mode_research.md` (this report)
**Standards**: report-format.md, subagent-return.md, multi-task-creation-standard.md

## Executive Summary

- Add `--dream` as a **7th sub-mode** to `/distill`'s existing dispatch table (alongside
  report/purge/merge/compress/refine/gc/auto), NOT a new command. Wire it into skill-memory's
  `mode=distill` dispatch exactly like the other six sub-modes.
- Dream mode's job splits into two independent outputs that must not be conflated: (1) **memory
  revision** — reusing the *already-implemented* UPDATE/EXTEND/CREATE/tombstone primitives
  from `/learn` and `/distill --merge`/`--purge`, driven by event-derived evidence rather than
  new content, and (2) **improvement proposals** — a separate, non-memory deliverable that is
  surfaced for the user to route to `/task` or direct doc edits, never auto-applied.
- Ingestion is entirely through `events-query.sh` (`--format json-array` / `--format
  summary-counts`), which already tolerates an absent `specs/events.jsonl` — dream mode inherits
  that tolerance for free and must explicitly test the "no events yet" path (verified: the store
  is currently absent in this repo).
- Dream mode must be **interactive by default** (mirrors purge/merge/compress/refine), and must
  **never** be folded into `--auto`'s Tier-1-only non-interactive path — revising memory content
  based on judgment calls is exactly the class of operation `--auto` is documented to exclude.
- No core event-store scripts need to change. `events-query.sh`, `events-append.sh`,
  `events-schema.json`, `orchestrator-postflight.sh`, and both hooks are stable, generic
  contracts already built for exactly this kind of downstream consumer.

## Context & Scope

Tasks 869-871 built the unified event store (`specs/events.jsonl`), its reader/writer scripts,
schema/format docs, and two capture layers: (1) `skill-base.sh` lifecycle events +
`events-log-artifact.sh` (PostToolUse) + `events-log-lifecycle.sh` (Stop/SubagentStop), and (2)
`orchestrator-postflight.sh`'s `reflection` event emission (mirrored onto
`state.json` task entries' top-level `reflection` field). Task 872 is the declared "loop-closing
consumer": `/distill` gains a mode that reads this store, revises the memory vault in light of
it, and produces improvement proposals for the agent system itself.

The file_scope is documentation/spec files only (`distill.md`, `SKILL.md`, `distill-usage.md`,
`EXTENSION.md`, `manifest.json`, `index-entries.json`) — this is a spec-writing task; there is no
new shell script to author. All new behavior must be expressible as a sub-mode within the
existing spec-driven skill-memory execution model (the agent reads SKILL.md and follows its
prose+pseudocode instructions, exactly like the other six sub-modes already do).

## Findings

### Codebase Patterns

**Sub-mode dispatch is a pure priority chain.** `distill.md`'s `argument_parsing` block
(lines 17-54) is a first-match-wins if/elif chain setting `sub_mode`. Adding `--dream` is a one-line
addition: `elif "--dream" in $ARGUMENTS: sub_mode = "dream"`. The Sub-Mode Availability table
(distill.md lines 63-77) and skill-memory's mirrored Sub-Mode Dispatch table (SKILL.md lines
1071-1084) both need the new row. `skill-memory`'s `## Mode: distill` section is a flat sequence
of `### Sub-Mode: {name}` H3 sections (merge, compress, refine, auto — gc/purge presumably
earlier in the file, not re-read here since their pattern is already fully demonstrated by
merge/compress/refine); a new `### Sub-Mode: dream` section slots in the same way, following the
same internal structure every existing sub-mode uses: Edge Case Checks -> Candidate
Identification -> Dry-Run Behavior -> Interactive Selection (AskUserQuestion, MANDATORY STOP) ->
Execution -> Batch Index Regeneration -> Distill Log Entry.

**Every mutating sub-mode already follows one shape.** purge/merge/compress/refine all: (1) run
validate-on-read, (2) identify candidates via a scoring/matching rule, (3) support `--dry-run`
(preview, no writes), (4) present via `AskUserQuestion` `multiSelect` (a MANDATORY STOP — the
skill's frontmatter interactive requirement at the top of SKILL.md applies to these), (5) apply
the selected operation using one of the three canonical memory-mutation primitives (UPDATE
template / EXTEND template / tombstone-frontmatter / hard-delete for gc), (6) regenerate all
three indexes as one batch after all writes, (7) append a structured entry to
`.memory/distill-log.json` and bump its `summary.total_*` counter, (8) let `distill.md` Step 4
("Update State and Log") update `memory_health` in `specs/state.json` and git-commit. Dream mode
should be spec'd as an eighth instance of this exact shape — not a bespoke pipeline — so it
inherits validate-on-read, dry-run, interactive-stop, and logging conventions for free and stays
consistent with the rest of the file.

**`events-query.sh` is the correct, sufficient reader — no new script needed.** It supports
`--task N`, `--category`, `--event-type`, `--checkpoint`, `--since`/`--until`, and three output
formats (`jsonl`, `json-array`, `summary-counts`). It already tolerates an absent
`specs/events.jsonl` (returns `[]` / `{total_events:0,...}` and exits 0) — verified live in this
repo: `specs/events.jsonl` does not yet exist. Dream mode must document this "no events yet"
degenerate case explicitly (see Decisions below) rather than treat it as an error.

**Reflections are a distinguished `event_type`, not a separate store.** `reflection` events
(`category: "success"`, `event_type: "reflection"`) are appended by `orchestrator-postflight.sh`
Stage 6b using `--detail-json` carrying the four-field reflection object
(`what_worked`/`what_was_hard`/`what_was_missed`/`successes`); the *same* object is also persisted
verbatim on `specs/state.json`'s `active_projects[].reflection` field (Stage 7d, overwrite
semantics, most-recent-only). `/learn --task N` already knows how to present a task's current
`state.json` reflection as a reviewable pseudo-artifact (skill-memory SKILL.md lines 674-724).
Dream mode should reuse the *event-store* copy (via
`events-query.sh --event-type reflection --format json-array`) rather than `state.json`, because
the event store is append-only across the task's whole history (multiple `/implement` dispatches
each emit their own `reflection` event) while `state.json`'s field is overwrite-only
(most-recent-only) — dream mode reviewing "ALL memories in light of the logs" wants the full
historical signal, not just the latest snapshot.

**Recurrence thresholds already exist as codebase precedent.** Hard-mode's H5 "divergence audit"
uses a documented "three strikes on any target" rule and H6 "convergence policing" uses per-target
churn counters (see CLAUDE.md Hard Mode section). Dream mode's "is this a real, actionable
pattern or a one-off blip" question should reuse the same three-occurrences-or-more threshold
for both (a) flagging a memory as contradicted/stale and (b) promoting a recurring blocker/
deviation into an improvement-proposal candidate, rather than inventing a new threshold — this
keeps the codebase's "recurring signal" semantics consistent across hard-mode and dream mode.

**No task-creation helper script exists** — single-task creation logic lives inline in
`agent-system/extensions/core/commands/task.md`'s "Create Task Mode" (read
`next_project_number`, build a `state.json` entry, append, regenerate TODO.md via
`generate-todo.sh`, git commit). Multi-task creation (8-component pattern) lives inline in
`meta-builder-agent.md` / `skill-fix-it`. There is no shared `task-create.sh` primitive that
dream mode could shell out to.

### External Resources

Not applicable — this is a pure in-repo spec-extension task; no external library or API is
involved. No web research was performed (would not have surfaced anything the codebase inspection
didn't already answer).

### Recommendations

**1. Dispatch mechanism (research question 1).** Add `--dream` to `distill.md`'s argument-parsing
if/elif chain and Sub-Mode Availability table, and add `### Sub-Mode: dream` to skill-memory
SKILL.md's `## Mode: distill` section plus a row in its Sub-Mode Dispatch table. Do not overload
an existing flag (e.g. `--refine --deep`) — `--dream` is a distinct, higher-scope operation
(cross-references the event store; the other six never do) and deserves its own flag, matching
the task title's own framing ("review/revise mode ... NOT a separate /dream command" — i.e. new
flag on the existing command, exactly as `--purge`/`--merge`/etc. already are). Composable with
`--dry-run` and `--verbose` like all other sub-modes; explicitly **not** reachable via `--auto`
(document this exclusion the same way compress/purge/merge/Tier-2-refine are already documented as
excluded from `--auto`).

**2. Event ingestion and memory correlation (research question 2).** Ingest exclusively via
`events-query.sh` (never hand-rolled `jq` against `specs/events.jsonl` directly — this mirrors
the file's own header comment: "events-query.sh — Shared reader/filter/aggregate helper ... do
NOT hand-roll jq"). Concretely:
- Pull aggregate shape first: `events-query.sh --format summary-counts` (optionally `--since
  {last_dream_run_timestamp}` — see Decisions) to get `by_category`/`by_event_type` counts —
  this is the cheap "is there anything new to review" gate.
- Pull the full event set for correlation: `events-query.sh --format json-array [--category
  deviation|blocker] [--since ...]` for the deviation/blocker signal, and a separate
  `--event-type reflection --format json-array` call for the reflection signal.
- **Correlation to memories** has no existing direct foreign key (memories do not store a
  `source_task` field distinct from the free-text `source` frontmatter value, e.g. `"file:
  specs/259_.../reports/01_x.md"` or `"user input"`). Recommend a two-tier correlation:
  (a) **task-number correlation**: an event's `task` field, when non-null, can be matched against
  a memory's `source` frontmatter string via a `specs/{padded_or_bare}_` substring test (the same
  pattern `skill-memory`'s Task Mode Step 1 already uses to locate a task directory from a bare
  number) — this finds memories that were literally distilled from that task's artifacts via
  `/learn --task N`.
  (b) **topic/keyword correlation** (the fallback for events with no direct memory-task link,
  e.g. a recurring `checkpoint` or `event_type` seen across many tasks): match the event's
  `message`/`checkpoint`/`event_type` string against a memory's `keywords`/`topic` using the
  *same* keyword-overlap scoring already defined for `/learn`'s Memory Search (Overlap Scoring)
  and `/distill --merge`'s Pairwise Keyword Overlap Algorithm — reuse the formula, don't
  reinvent a new one.

**3. Revision semantics and write/confirmation gates (research question 3).** "Revise ALL
memories in light of the logs" should be read as *review* ALL (score every non-tombstoned memory
against the correlated event evidence) but *write* only what a human confirms — exactly the
purge/merge/compress/refine precedent, never the `--auto` (Tier-1-only, no `AskUserQuestion`)
precedent. Concretely, per memory, classify against its correlated events into one of three
buckets and handle each with an *existing* primitive, never a new one:
  - **Corroborated** (events since last review support the memory's guidance, e.g. later
    `success` events at the same checkpoint with no matching `deviation`/`blocker`): no write;
    optionally note in the dream summary/log only.
  - **Contradicted / stale** (a `deviation`/`blocker` pattern recurs — three-strikes threshold,
    per the H5/H6 precedent above — despite the memory's guidance being in force): present via
    `AskUserQuestion multiSelect` (mirroring compress/refine's presentation pattern) with options
    to (i) UPDATE the memory using the *existing* UPDATE template (SKILL.md "UPDATE Operation"),
    moving the old guidance into `## History` and writing the corrected guidance as new main
    content, sourced from the event evidence rather than new user-supplied text; or (ii)
    tombstone it using the *existing* tombstone-frontmatter pattern (`status: tombstoned`,
    `tombstoned_at`, `tombstone_reason: "dream_superseded"` — following the same field shape
    `merge`/`purge` already use, just a new `tombstone_reason` value) if the guidance is now
    actively wrong rather than merely stale; or (iii) skip.
  - **Gap** (a recurring event pattern — three-strikes — has no correlated memory at all): present
    as a CREATE candidate using the *existing* CREATE template, sourced from the event
    detail/message rather than a `/learn` segment. If the gap is systemic/agent-level rather than
    "here is a reusable technique," it escalates to an **improvement proposal** instead of a
    memory (see recommendation 4) — the discriminator: a memory candidate describes durable
    *domain/technique* knowledge (matches the existing TECHNIQUE/PATTERN/CONFIG/WORKFLOW/INSIGHT
    taxonomy); a proposal describes a *system change* (a skill, hook, rule, or doc should be
    different).
  - **Mandatory stop**: identical to the existing "MANDATORY INTERACTIVE REQUIREMENT" banner at
    the top of SKILL.md — dream mode's confirmation step is a hard `AskUserQuestion` stop, not
    optional, for every write path above. `--dry-run` shows the full classification (all three
    buckets, with counts and evidence citations) and performs zero writes, matching the
    dry-run contract every other sub-mode already honors.

**4. Improvement-proposal surfacing (research question 4).** Treat proposals as a genuinely
separate output from memory revision, not a memory category:
  - **Discovery**: derive proposal candidates from (a) recurring (three-strikes) `deviation`/
    `blocker` events that point at a *skill/hook/rule*, identifiable via the event's
    `checkpoint`/`event_type`/`message` referencing a named skill or lifecycle stage rather than
    a reusable technique, and (b) recurring `what_was_hard`/`what_was_missed` phrases across
    multiple `reflection` events for the same or related task types.
  - **Presentation**: `AskUserQuestion multiSelect`, one row per candidate proposal, with the
    Multi-Task Creation Standard's per-item option shape (`label`/`description`), letting the
    user choose per-proposal among **"Create as task"** / **"Note in dream report only"** /
    **"Skip"** — this is the same three-way shape the standard's Component 2 (Interactive
    Selection) already prescribes, and mirrors `--lit`'s three-choice PROMPT_NEEDED pattern
    elsewhere in this codebase (a familiar, already-established interaction shape for
    "do a live thing / defer via a task / explicitly skip").
  - **Confirmation**: reuse the standard's Component 7 (explicit "Yes, create tasks" before any
    task is created) — non-negotiable, matches every other multi-task creator in this codebase.
  - **Task creation, if chosen**: dream mode is not `meta-builder-agent` and should not
    reimplement Kahn's-algorithm/DAG dependency machinery. Recommend **Required-components-only**
    compliance (Discovery, Interactive Selection, Confirmation, State Updates), the same level
    `/errors` and `/review` already operate at ("Partial" in the standard's compliance table) —
    each confirmed proposal becomes one independent `task_type: "meta"` entry via the same
    primitive `/task`'s own "Create Task Mode" uses (`next_project_number`, append to
    `active_projects`, `generate-todo.sh`, git commit) with `file_scope` seeded from whichever
    `.claude`/`agent-system` paths the triggering events/checkpoints implicate. Do not add
    topic-grouping/dependency-interview/visualization for v1; note as a documented, intentional
    gap exactly as the standard already does for `/errors`.
  - **Documentation-edit proposals**: for a proposal whose remedy is "update file X's prose"
    rather than "spawn a task," present it as a **report-only** finding (third
    `AskUserQuestion` option above) — dream mode itself must never edit files outside its own
    file_scope (`.memory/`, `specs/state.json` memory_health, `.memory/distill-log.json`); it
    surfaces the recommendation for a human or a follow-up `/meta`/`/task` invocation, it never
    silently edits arbitrary skill/rule/context files as a side effect of `/distill --dream`.
  - **Report home**: `/distill` is not task-scoped (no `specs/{NNN}_{SLUG}/` directory of its
    own), matching the existing pattern where all other sub-modes write to `.memory/` +
    `specs/state.json`'s `memory_health`, never to a `specs/` task directory. Recommend a new
    `.memory/dream-log.json` (same shape as `.memory/distill-log.json`: `version`, `operations[]`,
    `summary`) for the structured/machine-queryable log, plus a human-readable
    `.memory/20-Indices/dream-report-{date}.md` (or an in-terminal-only report, consistent with
    the bare `/distill` health report today, which is also not persisted to disk) for the
    narrative synthesis + proposal list. This keeps dream mode inside the memory extension's own
    existing storage conventions and avoids inventing a new `specs/` artifact type.

**5. Files needed outside the declared file_scope (research question 5).** None of the six
in-scope files are insufficient for authoring the *spec*. The following runtime/data touches are
outside file_scope but are the same category of already-accepted, non-file_scope runtime writes
every other distill sub-mode already performs (e.g. `.memory/distill-log.json`,
`specs/state.json`'s `memory_health`, `.memory/10-Memories/*.md`, `.memory/memory-index.json`,
`.memory/20-Indices/index.md` are all written by existing sub-modes today without being listed in
any file_scope) — flagged for completeness, not as a plan blocker:
  - `.memory/dream-log.json` (new file, mirrors `.memory/distill-log.json`)
  - `.memory/20-Indices/dream-report-{date}.md` (new, if the persisted-report option is chosen)
  - `specs/state.json` (new `active_projects[]` entries for any confirmed proposal-tasks, plus
    a possible new `memory_health.last_dream` / `dream_count` field pair mirroring
    `last_distilled`/`distill_count`)
  - `specs/TODO.md` (regenerated via `generate-todo.sh` if any proposal became a task)
  - `specs/{NNN}_{slug}/` (a brand-new task directory per confirmed proposal-task — created by
    the same mechanism `/task` already uses, not new machinery)
  - No changes are needed to `agent-system/extensions/core/scripts/events-query.sh`,
    `events-append.sh`, `events-schema.json`, `events-format.md`,
    `orchestrator-postflight.sh`, or either hook — all four are stable, generic, already-general
    contracts (confirmed by inspection: `events-query.sh`'s filters already cover every axis
    dream mode needs; `detail` is intentionally schema-free so `reflection`'s four fields and any
    future dream-specific payload both fit without a schema revision).
  - Deployed copies (`.claude/extensions/memory/...`, `.opencode/extensions/memory/...`) are
    sync targets of the `agent-system/extensions/memory/` source files already in file_scope —
    no separate edit is needed there; this mirrors the existing "CLAUDE.md is auto-generated"
    note already in the task description.

## Decisions

- **`--dream` is the sub-mode name**, not `--review`/`--revise`, to match the task's own title
  ("review/revise (dream) mode") while staying a single unambiguous flag consistent with the
  existing `--purge`/`--merge`/`--compress`/`--refine`/`--gc`/`--auto` vocabulary.
- **Dream mode is interactive by default** and is explicitly excluded from `--auto`'s scope —
  stated as an explicit "Excluded from `--auto`" row, matching how compress/purge/merge/Tier-2-
  refine are already excluded there.
- **`events-query.sh` is used unmodified** — no new query script, no new flags on the existing
  script. Dream mode's `--since {last_dream_run}` incremental-review behavior is achieved by
  storing `last_dream` in `specs/state.json`'s `memory_health` (new field) and passing it as
  `events-query.sh`'s existing `--since` argument; first run (no prior `last_dream`) reviews the
  full store.
- **The "no events yet" case is a first-class, explicitly documented path**, not an error: dream
  mode must display something like "No events captured yet (`specs/events.jsonl` does not exist).
  Dream review will only reflect memory-vault-internal scoring (staleness/duplicate/size) until
  events accumulate." and continue in a degraded mode using the existing scoring engine alone —
  this was verified live: the store is currently absent in this repo, so this path is not
  hypothetical.
- **Recurrence threshold reused, not reinvented**: three-or-more occurrences of a
  `deviation`/`blocker` at the same `checkpoint`/`event_type` (optionally scoped to task or
  cross-task) is the bar for both "contradicted memory" and "improvement proposal candidate,"
  matching hard-mode's existing three-strikes (H5) precedent.
- **Memory revisions and improvement proposals are always presented as two distinct sections** in
  the dream output — never merged into a single list — because they have different destinations
  (`.memory/` vs. `specs/` task creation vs. doc-edit recommendation) and different write
  permissions (dream mode may write memories itself after confirmation; it may never write
  arbitrary skill/rule/doc files itself).

## Risks & Mitigations

- **Risk**: Correlating events to memories by keyword/topic overlap could produce false
  positives (flagging a healthy memory as "contradicted" from an unrelated recurring blocker that
  happens to share vocabulary). **Mitigation**: always present classification evidence (the
  specific correlated event IDs/messages) alongside the recommendation in the `AskUserQuestion`
  option description, so the human reviewer can reject a bad correlation at the confirmation
  gate — the gate is the safety net, not the correlation heuristic's precision.
- **Risk**: `specs/events.jsonl` can grow unboundedly (explicitly flagged as an out-of-scope gap
  in `events-format.md`); a full-history dream run with no `--since` bound could become slow or
  expensive as the store grows. **Mitigation**: the `last_dream` timestamp + `--since` pattern
  above bounds all but the first run; document that the first run's cost is a one-time expense.
- **Risk**: Improvement-proposal task creation, if implemented at "Required components only,"
  drifts from the Multi-Task Creation Standard's full compliance bar over time as other commands
  gain the Optional components. **Mitigation**: explicitly document dream mode's compliance level
  in the standard's own compliance table (a new row: `/distill --dream` | Yes | No | No | No |
  No | No — matching `/errors`'s existing "Partial (automatic mode intentional)" framing) so the
  gap is visible and trackable, not silently incomplete.
- **Risk**: A memory `UPDATE` driven by event evidence (rather than a human-supplied replacement
  segment, as `/learn`'s UPDATE assumes) could read oddly if the generated replacement content is
  low-quality prose. **Mitigation**: the `AskUserQuestion` step should show the *proposed* new
  memory body for review before it's written (not just "update memory X: yes/no"), giving the
  human a real edit-or-reject gate rather than a blind confirmation.

## Context Extension Recommendations

- **Topic**: `multi-task-creation-standard.md`'s compliance table does not yet have a row for any
  memory-extension command. **Gap**: once implemented, `/distill --dream`'s task-creation path
  should be added to the standard's compliance table (Current Compliance Status section) the same
  way `/errors`/`/review`/`/task --review` already are. **Recommendation**: update
  `multi-task-creation-standard.md` as part of implementation (this file is outside the task's
  declared file_scope — flag for the planner to decide whether to include it or leave as a
  follow-up).
- **Topic**: there is no existing "dream-log schema" documented anywhere (mirroring
  `events-schema.json`/`events-format.md` for the event store, or the inline schema tables in
  SKILL.md for `distill-log.json`). **Gap**: `distill-usage.md` and/or `SKILL.md`'s dream
  sub-mode section should include the `dream-log.json` entry shape explicitly (this is within
  file_scope — `distill-usage.md` and `SKILL.md` are both listed).

## Appendix

- Search queries used: none (web); codebase inspection only, via `Read`/`Bash`/`Grep`/`find`.
- Key files read in full or substantial part: `distill.md`, `skill-memory/SKILL.md` (both pages),
  `distill-usage.md`, `EXTENSION.md`, `manifest.json`, `index-entries.json`,
  `events-query.sh`, `events-schema.json`, `events-format.md`, `events-append.sh`,
  `orchestrator-postflight.sh`, `events-log-lifecycle.sh`, `events-log-artifact.sh`,
  `memory-reference.md`, `multi-task-creation-standard.md`, `task.md` (partial),
  `.memory/distill-log.json`, `.memory/10-Memories/` listing, `specs/state.json`
  (`memory_health` + task 872 entry).

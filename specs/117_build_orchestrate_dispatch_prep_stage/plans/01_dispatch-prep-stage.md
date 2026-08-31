# Implementation Plan: Build the dispatch-prep stage in skill-orchestrate

- **Task**: 117 - Build the dispatch-prep stage in skill-orchestrate: memory retrieval, --lit resolution, --clean, --fast
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: None. **Blocks**: any successor task that deletes `commands/research.md`,
  `commands/plan.md`, `commands/implement.md`, or `skill-researcher`/`skill-planner`/
  `skill-implementer` (binding ORDERING constraint — this task must land and be verified working first)
- **Research Inputs**: `specs/117_build_orchestrate_dispatch_prep_stage/reports/01_dispatch-prep-stage-design.md`
- **Artifacts**: plans/01_dispatch-prep-stage.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`skill-orchestrate` dispatches every lifecycle phase directly via the Agent tool with zero memory
retrieval, zero `--lit` resolution, and no consumption of `--clean` or `--fast` — capabilities that
`skill-researcher`/`skill-planner`/`skill-implementer` provide today and that `/orchestrate` silently
loses. This plan adds ONE new shared stage ("Stage 3.5: Dispatch Prep") to
`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`, referenced by a short pointer at each
of the 7 single-task dispatch sites and the 3 multi-task dispatch loops, and threads `clean_flag`/
`effort_flag` from `agent-system/extensions/core/commands/orchestrate.md` into the skill. Exactly two
files change, both in the source store. Definition of done: every `/orchestrate` dispatch injects
`<memory-context>` and `<literature-briefing>` into its prompt on the same terms the three lifecycle
skills do today, and a multi-task dispatch prompt shows a non-empty task description.

### Research Integration

The research report is the primary input and is followed closely. Key findings carried into the phases:

- **No parser change needed.** `parse-command-args.sh` already unconditionally exports `CLEAN_FLAG`
  and `EFFORT_FLAG`; `orchestrate.md` already sources it. Only consumption wiring plus two new
  `## Options` rows are required (Phase 1).
- **Per-phase `memory-retrieve.sh` asymmetry is real and must be preserved.** `skill-researcher`
  passes `"$focus_prompt"` as the 3rd argument; `skill-planner` and `skill-implementer` pass `""`.
  The new stage reproduces this via a `phase` parameter (Phase 4).
- **Injection goes in the prompt text, never the context JSON** — `<memory-context>` first, then
  `<literature-briefing>`, never as empty tag pairs (Phases 4-6).
- **Shared-snippet convention, not 10 copies.** The file already uses "define once, reference at each
  dispatch site" for the dispatch-window block; repeating the ~274-line `lit-stage4a-flow.md`
  procedure at 10 sites would add ~1,500-2,000 lines and create 10 drift points.
- **Multi-task `description` gap is a must-fix in scope** (Phase 3). Stage MT-4's dispatch prompts
  already interpolate `$description`, but no multi-task stage assigns it; both `memory-retrieve.sh`
  (hard `exit 1` on empty description) and `lit-stage4a-flow.md` (`--query "$description"`) hard-require
  it, so without this fix the new stage silently no-ops for every multi-task run.
- **Case mismatch hazard**: single-task Stage 1 defines `DESCRIPTION` (uppercase); the shared lit flow
  expects `description`. The new stage aliases explicitly and says why (Phase 4).

Two report open questions were resolved during planning and no longer need implementation-time
investigation:

- `memory-retrieve.sh` **does** emit its own `</memory-context>` closing tag (verified at the script's
  tail) — the wrapping happens inside the script, so the injection line must not re-wrap.
- `lit-stage4a-flow.md`'s only preconditions are `lit_flag`, `description`, and `orchestrator_mode`
  (verified against its Preconditions section), and it sets `lit_context` already
  `<literature-briefing>`-wrapped.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no ROADMAP.md was consulted.

## Goals & Non-Goals

**Goals**:

- Add a single shared "Stage 3.5: Dispatch Prep" procedure to `skill-orchestrate/SKILL.md` producing
  two outputs (`memory_context`, `lit_context`) plus an optional effort-depth note, parameterized by
  `phase`.
- Reference that stage from all 7 single-task dispatch sites and all 3 multi-task dispatch loops, and
  inject its outputs into each dispatch's prompt text.
- Thread `--clean` and `--fast` end to end: `## Options` rows on `orchestrate.md`, both Skill `args:`
  strings, both JSON delegation contexts, and the skill's own context-reading stages.
- Fix the pre-existing multi-task `description` gap (per-task capture in Stage MT-2 plus a
  `descriptions` map in `mt_state_file`).
- Keep every edit in the source store (`agent-system/extensions/core/**`).

**Non-Goals**:

- Model flags (`--haiku`/`--sonnet`/`--opus`/`--fable`) — separately filed, out of scope.
- `--team` fan-out — out of scope.
- `--hard` / hard-mode contract injection; `skill-orchestrate-hard/SKILL.md` is not touched at all.
- Deleting `commands/research.md`/`plan.md`/`implement.md` or the three lifecycle skills — successor
  tasks, gated behind this one.
- Adding format-spec (`report-format.md`/`plan-format.md`) injection to `skill-orchestrate` — a real
  but separate pre-existing gap, deliberately not addressed here.
- Any edit under `.claude/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Line numbers from the research report drift as soon as editing begins | M | H | Re-anchor every edit on stable headers (`#### State:`, `### Stage MT-4`, `## Options`), never on the report's recorded line numbers. Phase 0 of each editing phase re-greps its anchors first. |
| Repeating the full lit flow at 10 sites bloats the file by ~1,500+ lines and creates 10 drift points | H | M | Stage 3.5 is authored once (Phase 4); Phases 5-6 add only a short pointer line plus the injection instruction at each site. A Phase 7 grep asserts the full procedure text appears exactly once. |
| Losing the research-vs-plan/implement `focus_prompt` argument asymmetry makes the migration non-equivalent | M | M | `phase` parameter is a required input to Stage 3.5, with an explicit table mapping phase to the 3rd `memory-retrieve.sh` argument. Phase 7 greps each site for a correct `phase=` value. |
| Forgetting the multi-task `description` gap: works in single-task testing, silently no-ops in every multi-task run | H | M | Phase 3 is a dedicated phase that lands before Stage 3.5 is authored. Stage 3.5 itself carries a loud non-blocking `if [ -z "$description" ]` warning so this class self-diagnoses if it ever regresses. |
| `DESCRIPTION` vs `description` case mismatch silently reads an unset variable in single-task mode | M | M | Stage 3.5 opens with an explicit `description="${DESCRIPTION:-$description}"` alias plus a comment stating why it must not be "simplified" away. |
| An edit lands in `.claude/**` instead of the source store and is wiped by the next regeneration | H | L | Every phase names its absolute source-store path. Phase 7 runs `git status` to confirm the diff touches only `agent-system/extensions/core/**` and `specs/**`. |
| Empty `<memory-context>`/`<literature-briefing>` tag pairs injected when context is empty | L | M | Injection instruction at each site states the skip-when-empty rule verbatim, matching `skill-researcher`'s Stage 5 wording. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1, 3 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |
| 6 | 7 | 1, 5, 6 |

Phases within the same wave can execute in parallel. Note on territory: Phases 2, 3, 4, 5, and 6 all
edit the same file (`skill-orchestrate/SKILL.md`), so they are deliberately serialized even where
their content is logically independent — Phase 2 lists Phase 3 as a dependency and Phase 6 lists
Phase 5 for exactly this reason, not because of a content dependency. Only Phase 1 (which edits
`orchestrate.md` alone) is genuinely parallel with Phase 3.

---

### Phase 1: Thread `--clean` and `--fast` through `orchestrate.md` [COMPLETED]

**Goal**: The command file documents and forwards `clean_flag` and `effort_flag` to
`skill-orchestrate` in both single-task and multi-task delegation, reusing the already-exported
shell variables rather than adding parsing logic.

**Tasks**:

- [x] Re-anchor: grep `agent-system/extensions/core/commands/orchestrate.md` for `## Options`,
      `source .claude/scripts/parse-command-args.sh`, and both `skill: "skill-orchestrate"` /
      `skill-orchestrate` Skill-invocation blocks; record current line numbers before editing.
- [x] Add two rows to the `## Options` table, copying wording verbatim from `implement.md`'s existing
      rows: `--clean` -> "Skip automatic memory retrieval" (default false); `--fast` -> "Low-effort
      mode: lighter reasoning, faster responses" (default false).
- [x] Update the STAGE 0 `# Exports:` comment after the `parse-command-args.sh` source call to include
      `CLEAN_FLAG` and `EFFORT_FLAG` — the parser already exports them; the comment is merely stale.
- [x] Add a short prose sentence after that block, matching the existing `ALLOW_SELF_MODIFYING_FLAG`
      paragraph's shape, stating that `CLEAN_FLAG` (default `"false"`) and `EFFORT_FLAG` (default
      `""`) are read here and passed into the Skill delegation context below.
- [x] Single-task STAGE 2: append `clean_flag={CLEAN_FLAG} effort_flag={EFFORT_FLAG}` to the Skill
      `args:` string, and add `"clean_flag": "{CLEAN_FLAG}"` and `"effort_flag": "{EFFORT_FLAG}"` to
      the JSON delegation context alongside the existing `"lit_flag"`.
- [x] Multi-task delegation block: make the identical two additions to its `args:` string and its JSON
      delegation context.

**Timing**: 30 minutes

**Depends on**: none

**Verification Tier**: interface

Rationale: the delegation-context field set is a contract consumed by a second file
(`skill-orchestrate/SKILL.md` Stage 1 and Stage MT-1, wired in Phase 2). The enumerated one-hop
dependent set is exactly that one file.

**Scope Hypothesis**: The `## Options` table currently has 5 rows and this phase brings it to 7; there
are exactly 2 Skill-invocation sites (single-task STAGE 2, multi-task), each with an `args:` string and
a JSON context block, for 4 edit points plus 2 table rows plus the STAGE 0 comment. Confirm by grepping
for `skill-orchestrate"` and counting `args:` occurrences before editing; if the count differs, wire
every site found rather than the assumed 2.

**Files to modify**:

- `agent-system/extensions/core/commands/orchestrate.md` - Options table rows, STAGE 0 exports comment
  and prose, both `args:` strings, both JSON delegation contexts.

**Verification**:

- `grep -c '^| `--clean`\|^| `--fast`' on the file returns 2.
- `grep -c 'clean_flag' agent-system/extensions/core/commands/orchestrate.md` returns at least 4
  (2 args strings + 2 JSON contexts); same for `effort_flag`.
- No occurrence of a new `--clean`/`--fast` parsing branch (confirm the phase added zero parsing logic).

---

### Phase 2: Consume the new flags inside `skill-orchestrate` [COMPLETED]

**Goal**: `clean_flag` and `effort_flag` are read from the delegation context in both the single-task
and multi-task entry stages and are in scope wherever Stage 3.5 will run; `effort_flag` also reaches
agent routing.

**Tasks**:

- [x] Re-anchor on `### Stage 1: Input Validation`, `### Stage 1b: Resolve Task-Type Routing`, and
      `### Stage MT-1: Parse Multi-Task Context`.
- [x] Stage 1: add `clean_flag` (default `"false"`) and `effort_flag` (default `""`) to the
      "Read from delegation context" bullet list, with a one-line note that `clean_flag` suppresses
      memory retrieval in Stage 3.5 and `effort_flag` supplies reasoning-depth guidance.
- [x] Stage 1b: change the three `command-route-agent.sh` calls to pass `"$effort_flag"` as the 4th
      argument in place of the current literal `""`, with a one-line comment noting only `"hard"`
      changes resolution behavior so `--fast` is a no-op here today and this is future-proofing.
      *(deviation: altered — used lowercase `$effort_flag`, not `$EFFORT_FLAG`, to match this
      file's existing convention that delegation-context-sourced flags like `lit_flag` are
      referenced lowercase throughout, distinct from state.json-extracted uppercase vars like
      `TASK_TYPE`)*
- [x] Stage MT-1: add `clean_flag` and `effort_flag` to the delegation-context field list read there,
      with the same defaults.
- [x] Verify no other stage in the file shadows or re-derives either variable.

**Timing**: 30 minutes

**Depends on**: 1, 3

Phase 1 is a genuine content dependency (this phase consumes the fields Phase 1 emits). Phase 3 is a
same-file territory serialization only.

**Verification Tier**: interface

Rationale: this is the consumer half of the cross-file contract established in Phase 1; the enumerated
dependent set is `orchestrate.md` (producer) plus `command-route-agent.sh`'s documented 4th-argument
contract.

**Scope Hypothesis**: Stage 1b contains exactly 3 `command-route-agent.sh` call sites (research, plan,
implement), each currently passing a literal `""` 4th argument. Confirm with
`grep -c 'command-route-agent.sh' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
before editing; wire every site found.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 1 context-read list,
  Stage 1b routing calls, Stage MT-1 context-read list.

**Verification**:

- `grep -n 'clean_flag' skill-orchestrate/SKILL.md` shows entries in both Stage 1 and Stage MT-1.
- `grep -n 'command-route-agent.sh' skill-orchestrate/SKILL.md` shows zero remaining `""` 4th
  arguments in Stage 1b.
- The `effort_flag` default remains `""` (not `"fast"`) so an unflagged run is unchanged.

---

### Phase 3: Fix the multi-task `description` gap [COMPLETED]

**Goal**: A per-task `description` is captured in Stage MT-2 and persisted into `mt_state_file`, so
Stage MT-4's existing `$description` interpolation and the new Stage 3.5's hard preconditions both
resolve to real text.

**Tasks**:

- [x] Re-anchor on `### Stage MT-1: Parse Multi-Task Context` (the `mt_state_file` init field list) and
      `### Stage MT-2: Build Per-Task Routing Table`.
- [x] Stage MT-1: add `descriptions: {}` (map task_num -> description) to the `mt_state_file` init field
      list, placed alongside the existing `task_dirs: {}`, `research_agents: {}`, `implement_agents: {}`
      siblings.
- [x] Stage MT-2: extend the opening prose ("read `state.json` to get `task_type`, `project_name`") to
      also name `description`, and add
      `description=$(echo "$task_data" | jq -r '.description // ""')` to the existing per-task loop.
- [x] Stage MT-2: write the captured value into `mt_state_file`'s `descriptions` map in the same
      per-task iteration.
- [x] Add a one-sentence note at the MT-2 capture point stating that both `memory-retrieve.sh` and
      `lit-stage4a-flow.md` hard-require this value, so it must not be dropped as redundant.
- [x] Stage MT-4: at the top of each of the three dispatch loops, read
      `description=$(jq -r --arg t "$task_num" '.descriptions[$t] // ""' "$mt_state_file")` so the
      existing `$description` prompt interpolation and Stage 3.5 both see it.

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: interface

Rationale: `mt_state_file`'s field set is a schema consumed by Stages MT-3, MT-4, and MT-5 and
documented in `context/standards/orchestrator-runtime-files.md`; adding a map is an interface change
whose one-hop dependents are those stages.

**Scope Hypothesis**: Stage MT-4 contains exactly 3 dispatch loops (research_tasks, plan_tasks,
implement_tasks), each a single prose bullet ending in `Invoke Agent tool: ...`. Confirm with
`grep -n 'Invoke Agent tool' skill-orchestrate/SKILL.md` scoped to the MT-4 section before editing.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage MT-1 `mt_state_file` field
  list, Stage MT-2 per-task loop and prose, Stage MT-4 three loop preambles.

**Verification**:

- `grep -n 'descriptions' skill-orchestrate/SKILL.md` shows the MT-1 field-list entry, the MT-2 write,
  and 3 MT-4 reads.
- Every MT-4 loop that interpolates `$description` in its prompt now has a preceding assignment in
  the same loop.
- Check `context/standards/orchestrator-runtime-files.md` for an `mt_state_file` field-list table; if
  one exists, add the `descriptions` row there too rather than leaving the doc stale.

---

### Phase 4: Author "Stage 3.5: Dispatch Prep" [COMPLETED]

**Goal**: One canonical, self-contained stage exists between Stage 3 and Stage 4 that takes a `phase`
parameter and produces `memory_context`, `lit_context`, and an optional effort-depth note — structured
to mirror `skill-researcher`'s Stage 4a closely enough to diff side by side.

**Tasks**:

- [x] Re-anchor: locate the boundary between `### Stage 3: State Machine Loop` and
      `### Stage 4: State Handlers`; insert the new stage there.
- [x] Write the stage header `### Stage 3.5: Dispatch Prep (shared, runs immediately before every
      Agent dispatch)` and a short paragraph stating it is the single canonical copy, referenced by a
      pointer line at every dispatch site in Stage 4 and Stage MT-4, and that it must never be inlined
      or duplicated.
- [x] Document the stage's inputs as an explicit table: `phase` (`research` | `plan` | `implement`),
      `description`, `task_type`, `focus_prompt`, `clean_flag`, `effort_flag`, `lit_flag`,
      `orchestrator_mode`.
- [x] Add the case-alias line with its rationale comment:
      `description="${DESCRIPTION:-${description:-}}"` — single-task mode defines `DESCRIPTION`
      (uppercase) while the shared lit flow and `memory-retrieve.sh` expect lowercase `description`.
      State explicitly that this alias must not be "simplified" away.
- [x] Add the loud, non-blocking empty-description warning, matching the file's existing warning style:
      `if [ -z "$description" ]; then echo "[orchestrate] WARNING: empty description at dispatch prep
      (phase=$phase) — memory retrieval and literature briefing will be skipped" >&2; fi`.
- [x] Write the memory-retrieval block gated on `clean_flag`, reproducing
      `skill-researcher`/`skill-planner`/`skill-implementer` Stage 4a verbatim except for the 3rd
      argument, which is selected by `phase`. Include a small table making the asymmetry explicit:
      `research` -> `"$focus_prompt"`; `plan` and `implement` -> `""`. Note that `memory-retrieve.sh`
      emits its own `<memory-context>` wrapper (verified against the script), so the injection must not
      re-wrap, and that it exits 1 with empty output when nothing matches.
- [x] Write the literature block as a verbatim reference to
      `@.claude/context/patterns/lit-stage4a-flow.md`, following `skill-researcher`'s wording: follow
      the file in full, branch on all six directives, and note that because `skill-orchestrate` always
      sets `orchestrator_mode: true`, the interactive `AskUserQuestion` branches are unreachable here
      and the deterministic `[lit:auto]` autonomous fallback always applies. State that this stage
      supplies the flow's three preconditions (`lit_flag`, `description`, `orchestrator_mode`).
- [x] Add the `clean_flag`/`lit_flag` independence note verbatim from the lifecycle skills: `--clean
      --lit` suppresses memory but still injects literature.
- [x] Add the effort-depth output: when `effort_flag` is non-empty, set a one-line
      `effort_note` to be appended to the dispatch prompt as reasoning-depth guidance, mirroring
      `research.md`'s existing instruction. Empty `effort_flag` produces no note.
- [x] Write the "Outputs and injection contract" subsection: `memory_context` then `lit_context` then
      `effort_note`, appended to the end of the dispatch site's existing prompt string; never inject an
      empty `<memory-context>` or `<literature-briefing>` tag pair; nothing goes into the `context` JSON.
- [x] Note in the stage that `skill-orchestrate` has no format-spec injection today, so unlike the
      lifecycle skills there is no format block for these to sit after — the blocks are simply the
      first content appended after the base prompt text.

**Timing**: 1 hour 15 minutes

**Depends on**: 2, 3

**Verification Tier**: interface

Rationale: this stage defines a contract (`phase` parameter, three named outputs, injection ordering)
that 10 call sites in the same file plus two external scripts depend on. The enumerated one-hop
dependents are Stage 4's 7 handlers and Stage MT-4's 3 loops (wired in Phases 5-6),
`memory-retrieve.sh`, and `lit-stage4a-flow.md`.

**Scope Hypothesis**: The stage is expected to be roughly 70-110 lines — substantially shorter than the
274-line `lit-stage4a-flow.md` because it references that file rather than inlining it. If the draft
exceeds ~150 lines, that is a signal the lit flow is being inlined; re-check before continuing.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - new `### Stage 3.5: Dispatch Prep`
  section inserted between Stage 3 and Stage 4.

**Verification**:

- `grep -c 'Stage 3.5' skill-orchestrate/SKILL.md` is non-zero and the header appears exactly once.
- The stage contains exactly one `memory-retrieve.sh` invocation and exactly one
  `lit-stage4a-flow.md` reference.
- The `phase`-to-3rd-argument mapping table is present and names all three phases.
- The `description` alias line and the empty-description warning are both present.
- No `AskUserQuestion` invocation appears anywhere in the new stage.

---

### Phase 5: Wire the 7 single-task dispatch sites [COMPLETED]

**Goal**: Every single-task Agent dispatch in Stage 4 runs Stage 3.5 first and injects its outputs into
the prompt.

**Tasks**:

- [x] Re-anchor by grepping for `#### State:` headings and, within Stage 4, for the
      `Invoke the Agent tool:` marker preceding each dispatch table.
- [x] For each dispatch site, insert a short pointer line immediately after the existing dispatch-window
      bash block and before `Invoke the Agent tool:`, of the form: "Run **Stage 3.5: Dispatch Prep**
      with `phase=research` (see Stage 3.5 above) to produce `memory_context`, `lit_context`, and
      `effort_note`." Use the correct `phase` value per site.
- [x] For each dispatch site, extend the `prompt` row of the Agent-tool table so it states that
      `memory_context`, then `lit_context`, then `effort_note` are appended to the prompt string,
      each skipped when empty.
- [x] Leave every `context` row unchanged — injection is prompt-side only.
- [x] Confirm the `blocked` and `completed` handlers are left untouched (they do not dispatch).

Per-site `phase` values, keyed on stable `#### State:` anchors:

| Handler anchor | Phase value |
|---|---|
| `not_started` / `not started` | `research` |
| `researching` | `research` |
| `researched` | `plan` |
| `planning` | `plan` |
| `planned` / `implementing` | `implement` |
| `partial` -> continuation sub-state | `implement` |
| `partial` -> no-handoff sub-state | `implement` |

**Timing**: 45 minutes

**Depends on**: 4

**Verification Tier**: interface

Rationale: each site consumes the Stage 3.5 contract; a wrong `phase` value or a missed site is a
contract violation invisible to a single-file read.

**Scope Hypothesis**: There are exactly 7 dispatch sites across 6 `#### State:` handler blocks (the
`partial` handler contains two). Confirm before editing by counting `Invoke the Agent tool:`
occurrences within the Stage 4 range; if the count is not 7, wire every site found and record the
discrepancy rather than assuming the report's map.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 4's 7 dispatch sites.

**Verification**:

- Count of `Stage 3.5: Dispatch Prep` pointer lines within Stage 4 equals the count of
  `Invoke the Agent tool:` occurrences within Stage 4.
- Grep for `phase=research` / `phase=plan` / `phase=implement` within Stage 4 yields 2 / 2 / 3
  respectively.
- No `context` row in Stage 4 gained a `memory_context` or `lit_context` field.

---

### Phase 6: Wire the 3 multi-task dispatch loops [COMPLETED]

**Goal**: Every multi-task Agent dispatch in Stage MT-4 runs the same Stage 3.5 procedure with the
correct per-phase parameter and injects its outputs.

**Tasks**:

- [x] Re-anchor on `### Stage MT-4: Phase-Aware Dispatch and Per-Task Postflight` and its three
      `For each task in ...` loops.
- [x] In the `research_tasks` loop, add a bullet before the `Invoke Agent tool:` bullet: "Run
      **Stage 3.5: Dispatch Prep** with `phase=research` for this task (the same single canonical
      procedure defined in Stage 3.5 — do not inline a second copy)."
- [x] Do the same in the `plan_tasks` loop with `phase=plan` and the `implement_tasks` loop with
      `phase=implement`.
- [x] In each loop, extend the `prompt = "..."` segment description to state that `memory_context`,
      then `lit_context`, then `effort_note` are appended, each skipped when empty.
- [x] Confirm each loop's Stage 3.5 invocation sees the per-task `description` read added in Phase 3,
      and that per-task `task_type` is in scope from the MT-2 routing table.
- [x] Add a one-line note at the head of Stage MT-4 stating that Stage 3.5 is per-task, not per-batch —
      it runs once inside each loop iteration, never hoisted above the loop.
- [x] Leave every `context = { ... }` object unchanged.

**Timing**: 40 minutes

**Depends on**: 5

Content-independent of Phase 5; serialized only because both phases edit
`skill-orchestrate/SKILL.md`.

**Verification Tier**: interface

**Scope Hypothesis**: Stage MT-4 contains exactly 3 dispatch loops. Confirm by counting
`Invoke Agent tool:` occurrences within the MT-4 range before editing.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage MT-4's 3 dispatch loops.

**Verification**:

- Each of the 3 MT-4 loops contains exactly one Stage 3.5 pointer bullet with the correct `phase` value.
- Each MT-4 loop's `description` read (Phase 3) precedes its Stage 3.5 pointer bullet.
- No `context = { ... }` object in MT-4 gained a `memory_context` or `lit_context` field.

---

### Phase 7: Cross-file audit and closeout [COMPLETED]

**Goal**: The full change is internally consistent, confined to the source store, free of task-number
references in deliverables, and leaves `skill-orchestrate-hard` untouched.

**Tasks**:

- [x] Assert the shared procedure exists exactly once: the full memory-retrieval bash block and the
      `lit-stage4a-flow.md` reference each appear exactly once in `skill-orchestrate/SKILL.md`.
      *(completed: memory-retrieve.sh invocation at line 396, lit-stage4a-flow.md reference at
      line 406, both exactly once)*
- [x] Assert total wiring: 10 Stage 3.5 pointer references (7 in Stage 4, 3 in Stage MT-4), and zero
      remaining Agent-dispatch sites in the file without one. Enumerate any dispatch site lacking a
      pointer and wire it. *(completed: 10 confirmed by grep, 2/2/3 research/plan/implement
      distribution in Stage 4, 1/1/1 in Stage MT-4. Scope note: Stage 5a's drift-inspection
      fork/reviser dispatches and Stage 6's blocker-escalation fork/reviser/re-dispatch-implement
      are NOT Stage 4/MT-4 lifecycle dispatch sites — they are narrow, single-purpose helper
      dispatches (drift/blocker investigation, targeted revision) outside the plan's declared
      7+3=10 scope, consistent with the Non-Goals precedent of documenting adjacent gaps rather
      than silently expanding scope. Recorded as a follow-up, not wired here.)*
- [x] Assert flag threading end to end: `clean_flag` and `effort_flag` each appear in `orchestrate.md`'s
      Options table, both `args:` strings, and both JSON contexts, and are read in the skill's Stage 1
      and Stage MT-1. *(completed: verified by grep)*
- [x] Assert the multi-task description fix: `descriptions` appears in the MT-1 field list, is written
      in MT-2, and is read in all 3 MT-4 loops. *(completed: verified by grep)*
- [x] Assert non-scope: `git diff --stat` shows changes confined to
      `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` and
      `agent-system/extensions/core/commands/orchestrate.md` (plus `specs/**` artifacts). Confirm
      `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` is unmodified.
      *(completed: git diff --stat confirms exactly these 2 files)*
- [x] Assert boundary compliance: `git status --short` shows zero modified paths under `.claude/`.
      *(completed)*
- [x] Run `bash .claude/scripts/check-task-references.sh` and confirm no new task-number references
      were introduced outside `specs/**`. Neither edited file may cite a task number.
      *(completed: PASS, 0 unexempted occurrences)*
- [x] Read both changed files end to end once, checking that no stale prose still claims
      `/orchestrate` performs no memory retrieval or no `--lit` resolution. *(completed: no stale
      claims found)*
- [x] Note in the summary that the source-store edits take effect only after a `.claude/` regeneration
      (deploy/reload), and that end-to-end runtime confirmation of a live `/orchestrate` dispatch
      requires that regeneration first. *(completed: noted in implementation summary)*

**Timing**: 40 minutes

**Depends on**: 1, 5, 6

**Verification Tier**: full

Rationale: this is the closing gate for the whole task; the complete gate set runs here regardless of
the per-phase tiers used above.

**Scope Hypothesis**: Exactly 10 Stage 3.5 pointer sites and exactly 2 modified source files are
expected. Both are hypotheses to confirm by grep and `git diff --stat`, not facts — if either count
differs, reconcile the difference explicitly before closing the phase rather than adjusting the
expectation.

**Files to modify**:

- None expected; this phase is verification. Any defect found is fixed in place in the two files above.

**Verification**:

- All eight assertions above pass.
- `check-task-references.sh` exits clean.
- `skill-orchestrate-hard/SKILL.md` byte-identical to its pre-task state.

---

## Testing & Validation

- [x] `skill-orchestrate/SKILL.md` contains exactly one `### Stage 3.5: Dispatch Prep` header and one
      copy of its procedure body.
- [x] All 10 dispatch sites (7 single-task, 3 multi-task) carry a Stage 3.5 pointer with the correct
      `phase` value; the phase distribution is research x2, plan x2, implement x3 (single-task) and
      research/plan/implement x1 each (multi-task).
- [x] `clean_flag` and `effort_flag` are threaded from `orchestrate.md`'s Options table through both
      Skill `args:` strings and both JSON delegation contexts into the skill's Stage 1 and Stage MT-1.
- [x] The `--clean` semantics match the lifecycle skills exactly: `clean_flag == "true"` suppresses
      memory retrieval and does not affect literature.
- [x] The `memory-retrieve.sh` 3rd-argument asymmetry is preserved (`$focus_prompt` for research, `""`
      for plan and implement).
- [x] `descriptions` map present in `mt_state_file`, written in MT-2, read in all 3 MT-4 loops; a
      multi-task research prompt renders as `Research task N: {actual description}`, not
      `Research task N: ` with nothing after the colon.
- [x] No `memory_context` or `lit_context` field was added to any `context` JSON object.
- [x] No empty `<memory-context>` or `<literature-briefing>` tag pair can be injected (skip-when-empty
      rule stated at every site).
- [x] `git status --short` shows zero modified paths under `.claude/`.
- [x] `bash .claude/scripts/check-task-references.sh` exits clean.
- [x] `skill-orchestrate-hard/SKILL.md` unmodified.

## Artifacts & Outputs

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — new Stage 3.5, 10 wired dispatch
  sites, Stage 1 / Stage 1b / Stage MT-1 flag consumption, Stage MT-1 / MT-2 / MT-4 description fix.
- `agent-system/extensions/core/commands/orchestrate.md` — 2 new Options rows, updated STAGE 0 exports
  comment and prose, flag threading in both delegation blocks.
- `specs/117_build_orchestrate_dispatch_prep_stage/summaries/01_*-summary.md` — implementation summary.
- Possible incidental: `context/standards/orchestrator-runtime-files.md` `mt_state_file` field-list row
  for `descriptions`, if that file documents the field list.

## Rollback/Contingency

Both changed files are tracked markdown in the source store with no build artifacts, so rollback is a
plain `git checkout` of the two paths (or `git revert` of the phase commits, which are per-phase and
independently revertable). Because `.claude/` is a gitignored, regenerated deploy artifact, reverting
the source store plus a regeneration fully restores prior behavior — no manual `.claude/` cleanup is
needed.

Partial-rollback contingencies, in decreasing order of preference:

- If Stage 3.5 proves incorrect after wiring, revert Phases 4-6 and keep Phases 1-3. Phase 1 (flag
  threading) and Phase 3 (the description fix) are independently valuable and safe on their own: extra
  unread delegation-context fields are inert, and the description fix repairs a pre-existing latent bug.
- If only the multi-task path misbehaves, revert Phase 6 alone; the single-task wiring in Phase 5 is
  independent and leaves multi-task dispatch exactly as it is today.
- If `effort_flag` threading into `command-route-agent.sh` (Phase 2) causes unexpected routing, revert
  that one call-site change back to the literal `""` 4th argument; it is explicitly optional per the
  research report and independent of the rest of the phase.

# Implementation Plan: Wire model-flag threading through /orchestrate

- **Task**: 114 - Wire model-flag threading through /orchestrate and the base orchestrate engine
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None (but see Sequencing below — this must land BEFORE the lifecycle-command deletion task)
- **Research Inputs**: `specs/114_wire_model_flag_through_orchestrate/reports/01_wire-model-flag-orchestrate.md`
- **Artifacts**: plans/01_wire-model-flag-orchestrate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`/orchestrate` accepts all four model flags (`--haiku`, `--sonnet`, `--opus`, `--fable`) at the
parser layer and then silently drops them: `commands/orchestrate.md` never reads `MODEL_FLAG`,
and `skills/skill-orchestrate/SKILL.md` contains zero occurrences of `model_flag` file-wide.
Every sub-dispatch runs on its agent's frontmatter default with no warning. This plan threads the
already-parsed `MODEL_FLAG` from the command into the skill's Stage 1 / Stage MT-1 context parse,
into **Stage 3.5 Dispatch Prep** (the single canonical per-dispatch context stage that already
owns `clean_flag`/`effort_flag`/`lit_flag`/`hard_mode`), and out to every lifecycle dispatch site
as the Agent tool's `model` parameter. Done means: with no flag, behavior is byte-identical to
today; with a flag, every research/plan/implement dispatch (single-task, multi-task, and team
fan-out) carries `model:`.

Scope is exactly two files, both in the source store:

- `agent-system/extensions/core/commands/orchestrate.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`

### Research Integration

The research report settled all three design questions with evidence; they enter this plan as
**decisions**, not open questions:

- **(a) Lifecycle-only scoping, for free.** A zero-match grep for "Stage 3.5" across the entire
  auxiliary-dispatch region (Stage 5a Drift Inspection, Stage 5b churn/divergence audit, Stage 6
  Blocker Escalation — six raw Agent-tool invocations) confirms none of them call Stage 3.5.
  Wiring `model_flag` into Stage 3.5 therefore scopes the override to research/plan/implement
  dispatches automatically, with **no exemption list to write or maintain**. The behavior is still
  documented explicitly in the Options table (Phase 1) so a future reader does not have to
  re-derive it from an absence.
- **(b) Resolve once, thread unchanged.** `model_flag` is read once at Stage 1 (single-task) and
  Stage MT-1 (multi-task) and passed unchanged into every Stage 3.5 call. It is never re-resolved
  per task, and no new per-task field is added to `mt_state_file` — it is an invocation-wide
  constant, exactly like `clean_flag`/`effort_flag`/`hard_mode`.
- **(c) Hard-mode multi-task coverage comes free.** `skill-orchestrate-hard/SKILL.md` states at
  two places that its multi-task stages are the base engine's MT-1..MT-5 unchanged, so this
  task's base-engine edits already cover hard mode's multi-task half. Hard mode's 7 single-task
  dispatch sites are out of scope here (a separate, currently-abandoned task).

Two research gotchas are load-bearing and are carried into the phases below:

1. **`MODEL_FLAG` defaults to the empty string `""`, not JSON `null`.** `commands/research.md`'s
   prose frames the unset case as `model_flag = null`; `scripts/parse-command-args.sh` actually
   sets `MODEL_FLAG=""`. Copying research.md's framing literally would produce a `"null"`
   string-equality check that never matches, breaking the no-flag regression. Every emptiness
   check written by this plan tests for **empty**, never for the literal token `null`.
2. **`orchestrate.md` needs 4 insertion points, not 2.** Unlike `research.md` (which threads flags
   only through a flat `args:` string), `orchestrate.md` threads each flag through **both** a flat
   `args:` Skill string **and** a separate JSON delegation-context object, at each of its two
   dispatch sites (multi-task and single-task). Missing the JSON half leaves `model_flag`
   unreachable from the `context` payload.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists but was not supplied as a `roadmap_path` input to this planning
dispatch, and no `roadmap_flag` was set. No roadmap review/update phases are included; a future
`--roadmap` run can add them.

### Sequencing (CONTRACT 5 — binding)

**This plan must land BEFORE the lifecycle-command deletion task touches `commands/research.md`.**
The reference pattern this work mirrors lives in `commands/research.md` (its `argument-hint`, its
four `## Options` model rows, its `model_flag` resolution block, and its `args:` string plus the
"If `model_flag` is set, pass the `model` parameter" instruction beneath it), and
`skills/skill-researcher/SKILL.md`'s matching context-parse key and pass-as-`model` sentence.
That file is inside the deletion task's blast radius. Landing first is the chosen resolution —
not "preserve the region" — because the task description itself records this ordering as
load-bearing. If the deletion has already landed when implementation starts, recover the pattern
from this plan's Phase 1 and Phase 3 text, which restates it in full, rather than blocking.

### Batch-alignment obligations (this plan's share)

- **CONTRACT 2 — `commands/orchestrate.md` flag-threading shape.** The paired phase-forcing task
  adds a different flag to this same file. Both use the identical shape, mirroring the existing
  `clean_flag`/`effort_flag` treatment, at the same eight sites enumerated in Phase 1. Neither
  invents a new convention; neither reorders the other's keys. The non-obvious half — that this
  file threads through **both** an `args:` string and a separate JSON context object per dispatch
  site, so it is 4 insertion points per flag rather than 2 — is stated explicitly in Phase 1 for
  the sibling to follow.
- **CONTRACT 3 — `skill-orchestrate/SKILL.md` stage ownership.** This plan **owns Stage 3.5
  Dispatch Prep** (its Inputs table, the new model-resolution subsection, and the "Outputs and
  injection contract" paragraph) plus the per-dispatch-site `model` parameter lines. It does not
  touch the Stage 4 `researched`/`planning` handlers' bodies beyond adding one row to their
  existing Agent-invoke tables (owned by the H4-gate-port task otherwise), and it does not touch
  Stage 3's loop or add any phase-resolution step (owned by the phase-forcing task). The Stage 1
  and Stage MT-1 context-parse bullet lists are shared with two siblings: additions there are
  **additive only, in the existing bullet style, never reordering a sibling's bullet**.
- **CONTRACT 7 — universal.** Edit `agent-system/extensions/**` only, never `.claude/**`. No
  task-number references in any deliverable text written into either target file.

### Anchoring discipline

Both target files are under concurrent edit by sibling tasks in this batch, and the original task
description's line numbers were already stale once. Every edit below is anchored by **heading or
verbatim surrounding text**. The line numbers given are a plan-time convenience measurement only
(taken against `orchestrate.md` at 782 lines / 43,407 bytes and `SKILL.md` at 4,118 lines /
268,147 bytes) and MUST be re-derived by grep at implementation time, never trusted.

## Goals & Non-Goals

**Goals**:

- `/orchestrate N --fable` (and `--haiku`/`--sonnet`/`--opus`) reaches every single-task
  research/plan/implement dispatch as the Agent tool's `model` parameter.
- `/orchestrate N,M --fable` reaches every per-task dispatch in all three Stage MT-4 loops.
- `/orchestrate N --team --fable` reaches every teammate spawned by the Stage 3.6 fan-out loop
  (free, because that loop already calls Stage 3.5 once per teammate).
- Lifecycle-only scoping is documented, not merely implied.
- With no model flag, behavior is byte-identical to today.

**Non-Goals**:

- `skills/skill-orchestrate-hard/SKILL.md` — hard mode's 7 single-task dispatch sites. Out of
  scope; separate task.
- `scripts/parse-command-args.sh`, `scripts/command-route-agent.sh`,
  `scripts/lib/manifest-routing-lib.sh` — **must not be modified**. Parsing is already correct;
  model selection is orthogonal to the agent-name routing ladder.
- Extending the model override to the six auxiliary/diagnostic dispatches (drift inspection,
  churn/divergence audit, blocker escalation fork/reviser/re-dispatch). They keep their
  frontmatter defaults by decision (a).
- The pre-existing, separate gap that Stage 6's implement re-dispatch injects no
  `memory_context`/`lit_context`/`effort_note`/`hard_contracts_block` at all. Noted by research;
  not fixed here.
- `merge-sources/claudemd.md`'s Model Enforcement / Composability wording. Out of file scope.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer copies `research.md`'s single-`args:`-string pattern and misses the JSON delegation-context object at each dispatch site | H | M | Phase 1 enumerates all 4 insertion points (2 `args:` strings + 2 JSON objects) as separate, individually-checked tasks; Phase 5 greps for exactly 2 `model_flag` occurrences per dispatch site |
| Implementer treats the unset default as JSON `null` (per `research.md` prose) instead of `""` | H | M | Stated in Overview, restated in Phase 2 and Phase 3 tasks; Phase 5's no-flag regression check is the gate that catches it |
| Line-number-anchored edit goes stale from a sibling's concurrent edit to the same file | M | H | Every task below anchors by heading or verbatim surrounding text; "Anchoring discipline" above forbids trusting the plan-time line numbers |
| Sibling task edits the same Stage 1 / Stage MT-1 bullet list and one edit clobbers the other | M | M | Additive-only rule (CONTRACT 3); insert the new bullet adjacent to the existing `effort_flag` bullet without touching sibling bullets; Phase 5 re-greps both lists |
| Dispatch-site count asserted (8 Stage 4 tables + 3 MT-4 loops + 1 fan-out loop = 12) is wrong at implementation time | M | M | Phase 4 carries a Scope Hypothesis with the exact confirming grep; note the research report said "9" Stage 4 sites where plan-time re-measure found **8** |
| The `model` output is mistakenly appended to the prompt string or added to the `context` JSON, like Stage 3.5's four existing outputs | M | M | Phase 3 requires a distinct sentence in the injection contract stating `model` is a sibling Agent-tool parameter only; Phase 5 greps that `model` never appears in a `context` object literal |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 3 |
| 4 | 5 | 1, 4 |

Phases within the same wave can execute in parallel. Phases 2, 3, and 4 all edit
`skill-orchestrate/SKILL.md` and are deliberately kept sequential; Phase 1 edits a different file
and may run alongside Phase 2.

---

### Phase 1: Thread `MODEL_FLAG` through `commands/orchestrate.md` [COMPLETED]

**Goal**: `MODEL_FLAG` is documented as an option, read from the sourced parser, and threaded into
both the `args:` string and the JSON delegation context at both dispatch sites — using the exact
shape the paired phase-forcing task will mirror.

**The shape (CONTRACT 2, binding on this task and the phase-forcing sibling)**: mirror the
existing `clean_flag`/`effort_flag` treatment verbatim at eight sites. Sites (e)-(h) are the
non-obvious part: this file carries **both** a flat `args:` Skill string **and** a separate JSON
delegation-context object at **each** of its two dispatch sites, so a flag needs **4 insertion
points, not 2**.

**Tasks**:

- [ ] (a) **`argument-hint`** (frontmatter, line 4): currently `TASK_NUMBERS [PROMPT]` with no flag
  list at all. Extend to list the model flags in `commands/research.md`'s style —
  `[--haiku|--sonnet|--opus|--fable]`. Add only the model-flag group; do not retrofit the other
  omitted flags (out of scope, and the sibling may be adding its own).
- [ ] (b) **`## Options` table**: add four rows, one per flag, after the existing `--fast` row and
  before `--team`, matching `research.md`'s wording verbatim:
  `--haiku` "Use Haiku model (fastest, lowest cost)", `--sonnet` "Use Sonnet model (balanced
  cost/quality)", `--opus` "Use Opus model (highest quality, same as agent default)", `--fable`
  "Use Fable model (claude-fable-5)"; Default `false` for each. Append to the `--haiku` row (or add
  as a single shared note directly under the table) the lifecycle-only scoping statement required
  by research recommendation 3: applies to research/plan/implement dispatches; diagnostic
  dispatches (blocker escalation, drift inspection, churn audit, plan revision) retain their
  frontmatter model.
- [ ] (c) **STAGE 0 "Exports:" comment** (the two `#` continuation lines under
  `source .claude/scripts/parse-command-args.sh "$ARGUMENTS"`): add `MODEL_FLAG` to the exported
  name list. Anchor on the literal `CLEAN_FLAG, EFFORT_FLAG, TEAM_MODE, TEAM_SIZE,
  TEAM_SIZE_EXPLICIT` run; insert `MODEL_FLAG` immediately after `EFFORT_FLAG`. Keep the comment
  block's existing wrap width.
- [ ] (d) **STAGE 0 prose paragraph**: the paragraph beginning
  `` `CLEAN_FLAG` (default `"false"`) and `EFFORT_FLAG` (default `""`) are also read here `` —
  extend it (or add a sibling sentence immediately after it) stating that `MODEL_FLAG` (**default
  `""`**, not `null`) is read here from the sourced parser and passed into the Skill delegation
  context below as `model_flag`, selecting the model family for every lifecycle dispatch
  `skill-orchestrate` makes, on the same terms `clean_flag`/`effort_flag` are threaded.
- [ ] (e) **Multi-task `args:` Skill string**: the one-line `args: "multi_task_mode=true ...`
  string. Insert `model_flag={MODEL_FLAG}` immediately after `effort_flag={EFFORT_FLAG}` and
  before `team_mode={TEAM_MODE}`.
- [ ] (f) **Multi-task JSON delegation-context object**: insert `"model_flag": "{MODEL_FLAG}",`
  between the `"effort_flag": "{EFFORT_FLAG}",` and `"team_mode": "{TEAM_MODE}",` lines.
- [ ] (g) **Single-task `args:` Skill string** (under `### STAGE 2: DELEGATE`): the
  `args: "task_number={N} session_id={SESSION_ID} orchestrator_mode=true ...` string. Insert
  `model_flag={MODEL_FLAG}` immediately after `effort_flag={EFFORT_FLAG}` and before
  `team_mode={TEAM_MODE}`.
- [ ] (h) **Single-task JSON delegation-context object**: insert `"model_flag": "{MODEL_FLAG}",`
  between the `"effort_flag": "{EFFORT_FLAG}",` and `"team_mode": "{TEAM_MODE}",` lines.
- [ ] Confirm both JSON blocks still parse as valid JSON after the insertions (comma placement).

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts exactly **two** dispatch sites in `orchestrate.md`, each
carrying **one** `args:` string and **one** JSON delegation-context object (4 insertion points).
Confirm at implementation time with
`grep -n 'effort_flag' agent-system/extensions/core/commands/orchestrate.md` — expect 4 hits in
the dispatch regions (2 in `args:` strings, 2 in JSON objects) plus the Options/prose mentions. If
the count differs (a sibling may have added a site), insert alongside every `effort_flag` dispatch
occurrence found, not the four this plan enumerated.

**Files to modify**:

- `agent-system/extensions/core/commands/orchestrate.md` — argument-hint, four Options rows plus
  scoping note, STAGE 0 exports comment, STAGE 0 prose, and 4 dispatch insertion points.

**Verification**:

- `grep -c 'MODEL_FLAG' agent-system/extensions/core/commands/orchestrate.md` returns at least 5
  (exports comment, prose, and the 4 interpolation points).
- `grep -n 'model_flag' agent-system/extensions/core/commands/orchestrate.md` shows exactly 2
  occurrences inside `args:` strings and 2 inside JSON context objects.
- Each edited JSON block is valid JSON with the placeholders treated as strings.
- Each new `model_flag` line sits immediately after its region's `effort_flag` line — no key
  reordering anywhere.

---

### Phase 2: Add the `model_flag` context-parse bullet to Stage 1 and Stage MT-1 [NOT STARTED]

**Goal**: `skill-orchestrate` reads `model_flag` once per invocation, in both the single-task and
multi-task entry stages, with the correct `""` default.

**Tasks**:

- [ ] Under `### Stage 1: Input Validation`, in the "Read from delegation context:" bullet list,
  insert a `model_flag` bullet **immediately after the existing `effort_flag` bullet and before
  the `hard_mode` bullet**. Match the neighbours' style exactly:
  `` - `model_flag` (default: `""`) — threaded from the command's `--haiku`/`--sonnet`/`--opus`/``
  `` `--fable` flags; selects the model family for every lifecycle dispatch this invocation ``
  `` makes. Consumed by Stage 3.5 Dispatch Prep's model-override resolution below. ``
- [ ] Add an explicit note in that same bullet that the not-set sentinel is the **empty string**,
  matching `parse-command-args.sh`'s `MODEL_FLAG=""` default — **not** the literal token `null`,
  despite `commands/research.md`'s prose framing.
- [ ] Under `### Stage MT-1: Parse Multi-Task Context`, insert the parallel bullet in the same
  position (after `effort_flag`, before `hard_mode`), with the multi-task phrasing the neighbours
  use: "...for every per-task dispatch this batch makes." State that it is resolved **once here**
  and never re-resolved per task, and that no per-task field is added to `mt_state_file`.
- [ ] Do not reorder, reword, or renumber any existing bullet in either list (CONTRACT 3 —
  two sibling tasks are adding their own bullets to these same two lists).

**Timing**: 25 minutes

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 1 and Stage MT-1
  context-parse bullet lists.

**Verification**:

- `grep -n 'model_flag' .../skill-orchestrate/SKILL.md` shows exactly 2 new occurrences, one in
  each stage's bullet list.
- `git diff` on the file shows only insertions in these two lists — zero deletions, zero moved
  lines.
- Both new bullets state the default as `""`; a `grep -n 'model_flag.*null'` over the file
  returns nothing.

---

### Phase 3: Wire `model_flag` into Stage 3.5 Dispatch Prep [NOT STARTED]

**Goal**: Stage 3.5 accepts `model_flag` as an input and produces a `model` output, with an
injection contract that makes explicit that `model` is a sibling Agent-tool parameter — never
appended to the prompt string and never added to the `context` JSON object.

**Ownership**: this phase is entirely inside this task's owned region (CONTRACT 3). No sibling
edits Stage 3.5.

**Tasks**:

- [ ] In Stage 3.5's **Inputs** table (the `| Input | Source |` table under
  `### Stage 3.5: Dispatch Prep`), add a row
  `` | `model_flag` | Stage 1 / Stage MT-1 (this invocation's `--haiku`/`--sonnet`/`--opus`/``
  `` `--fable` state) | `` immediately after the existing `effort_flag` row and before the
  `lit_flag` row.
- [ ] Add a **Model-override resolution** subsection, mirroring the shape and placement of the
  existing **Effort-depth note** (immediately after it, before the Hard-mode contract injection
  subsection). It must state: when `model_flag` is non-empty, set the `model` output to it
  unchanged (`haiku`/`sonnet`/`opus`/`fable` pass through verbatim — this stage does not translate
  or validate the value); when `model_flag` is empty, `model` stays empty and no `model` parameter
  is emitted at any call site, so the agent's frontmatter default applies. Anchor the emptiness
  test on the **empty string**, never on the literal `null`.
- [ ] Extend the **Outputs and injection contract** paragraph (begins "this stage produces
  `memory_context`, `lit_context`, `effort_note`, and `hard_contracts_block`") with a **distinct
  sentence** for `model`, stating that it is a fifth output of a different kind: it is passed as
  the Agent tool's `model` parameter at each call site, exactly like `subagent_type`, and is
  **never** appended to the prompt string and **never** added to the dispatch's `context` JSON
  object. Leave the existing four-output append order and the existing sentence "None of the four
  outputs is ever added to the dispatch's `context` JSON object" intact — do not rewrite "four" to
  "five" there, because `model` is not one of the appended four.
- [ ] Note in the same subsection, as the record of decision (a), that only dispatch sites which
  call this stage receive the override: the six auxiliary/diagnostic dispatches (Stage 5a drift
  inspection, Stage 5b churn/divergence audit, Stage 6 blocker escalation) do not call Stage 3.5
  and therefore keep their frontmatter defaults, by design and with no exemption list.

**Timing**: 45 minutes

**Depends on**: 2

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 3.5 Inputs table, new
  model-resolution subsection, Outputs-and-injection-contract paragraph.

**Verification**:

- The Inputs table contains a `model_flag` row positioned between `effort_flag` and `lit_flag`.
- A new subsection describes the empty/non-empty branch and names the output `model`.
- The injection-contract paragraph carries a sentence that names `model` as an Agent-tool
  parameter and explicitly excludes it from both the prompt string and the `context` object.
- `grep -n 'null' ` over the new text returns nothing referring to `model_flag`'s default.

---

### Phase 4: Pass `model` at every lifecycle dispatch site [NOT STARTED]

**Goal**: every dispatch site that calls Stage 3.5 emits the Agent tool's `model` parameter when
`model` is non-empty, and omits it entirely when empty.

**Tasks**:

- [ ] **Stage 4 single-task dispatch tables**: for each Agent-invoke table (the
  `| Field | Value |` tables whose first row is `` | `subagent_type` | ... | ``), add one row
  immediately after the `subagent_type` row:
  `` | `model` | Stage 3.5's `model` output — pass as the Agent tool's `model` parameter when ``
  `` non-empty; omit the parameter entirely when empty | ``. Re-measured at plan time these sit in
  the state handlers `not_started`, `researching`, `researched`, `planning`,
  `planned`/`implementing` (the hard-mode H1 branch), `partial` (its continuation-available and
  no-handoff sub-states), and the `partial` base branch — 8 tables total.
- [ ] **Concurrency note for the `researched` and `planning` handlers**: those two handlers'
  bodies are owned by the H4-gate-port sibling task. Restrict this edit to inserting the single
  `model` row into their existing Agent-invoke tables; do not restructure the handler. If the
  sibling has landed first and the table has moved or changed shape, re-locate by the
  `` | `subagent_type` | `$PLANNER_AGENT` `` row inside that handler and insert immediately after
  it.
- [ ] **Stage MT-4 per-task loops** (3 loops: research, plan, implement): each has an
  `- Invoke Agent tool: `subagent_type = ...`, prompt = ..., context = {...}` bullet. Add, to the
  same bullet, "pass Stage 3.5's `model` (if non-empty) as the Agent tool's `model` parameter" —
  placed adjacent to the `subagent_type` clause, never inside the `context = { ... }` object.
- [ ] **Stage 3.6 Team Fan-Out spawn loop**: in step 3's "Invoke the Agent tool:" bullet list
  (whose sub-bullets are `subagent_type`, `prompt`, `context`), add a `model` sub-bullet directly
  after `subagent_type`: "`model`: THIS teammate's own Stage 3.5 `model` output, passed as the
  Agent tool's `model` parameter when non-empty; omitted when empty." No other change is needed at
  this site — the loop already calls Stage 3.5 once per teammate, so team mode gets the override
  free.
- [ ] Verify no `model` key was added to any `context = { ... }` / `` | `context` | `` object at
  any of these sites.

**Timing**: 45 minutes

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts **12 dispatch sites**: 8 Stage 4 single-task Agent-invoke
tables + 3 Stage MT-4 per-task loops + 1 Stage 3.6 fan-out spawn loop. **Note the discrepancy**:
the research report asserts 9 Stage 4 sites; a plan-time re-measure found **8**
(`awk 'NR>=1066 && NR<=1856 && /subagent_type/' SKILL.md` → 8 hits, matching 8
`Invoke the Agent tool:` lines and 8 `Run **Stage 3.5: Dispatch Prep**` pointer lines in that
region). Confirm at implementation time with
`grep -n 'Run \*\*Stage 3.5: Dispatch Prep\*\*' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
— every pointer line found is a site requiring an edit, and the count of edits made must equal the
count of pointer lines. Do not implement to the number 8 or 9; implement to the grep result, and
record the actual count in the implementation summary.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 4 dispatch tables,
  Stage MT-4 dispatch bullets, Stage 3.6 spawn-loop bullet list.

**Verification**:

- The number of new `model` parameter mentions equals the number of
  `Run **Stage 3.5: Dispatch Prep**` pointer lines in the file.
- Every new `model` mention sits adjacent to a `subagent_type` clause, never inside a `context`
  object.
- `grep -n 'context.*model' SKILL.md` surfaces no dispatch `context` object containing a `model`
  key.

---

### Phase 5: Verification pass and consistency audit [NOT STARTED]

**Goal**: prove the change is additive (the single most important check) and that a set flag
traces end-to-end through all three dispatch paths.

**Tasks**:

- [ ] **No-flag regression trace (the primary gate)**: with `MODEL_FLAG=""` (today's default),
  walk the full chain by reading: all 4 `orchestrate.md` insertion points interpolate to an empty
  value → Stage 1 / Stage MT-1 read `model_flag` as `""` and treat it as not-set → Stage 3.5's
  resolution leaves `model` empty → every dispatch site omits the `model` parameter. Confirm no
  path emits `model: ""`, `model: null`, or the literal string `"null"`. Document this trace in
  the implementation summary — this is what proves the change is purely additive.
- [ ] **Single-task flag trace**: `/orchestrate N --fable` — trace `--fable` → `MODEL_FLAG=fable`
  → `args:`/JSON `model_flag=fable` → Stage 1 → Stage 3.5 `model=fable` → each of the Stage 4
  dispatch sites' `model` parameter. Repeat the read-through for `--haiku`, `--sonnet`, `--opus`
  (the resolution is pass-through, so one careful trace plus a value-list check suffices).
- [ ] **Multi-task flag trace**: `/orchestrate N,M --fable` — confirm the multi-task `args:` and
  JSON both carry it, Stage MT-1 reads it once, and all three MT-4 loops pass `model` per task
  with no per-task re-resolution and no `mt_state_file` field added.
- [ ] **Team-mode trace**: `/orchestrate N --team --fable` — confirm the Stage 3.6 spawn loop's
  per-teammate Stage 3.5 call yields `model` and the spawn passes it.
- [ ] **Lifecycle-only assertion**: re-run the research report's grep — search the region from
  `### Stage 5a: Drift Inspection` through the end of `### Stage 6: Blocker Escalation` for
  `Stage 3.5`; expect zero matches, confirming the six auxiliary dispatches remain unaffected.
  If a sibling task has since added a Stage 3.5 call there, stop and report — the lifecycle-only
  scoping decision would need re-examination rather than silent widening.
- [ ] **Untouched-file assertion**: `git status --short` shows exactly two modified files;
  `parse-command-args.sh`, `command-route-agent.sh`, and `manifest-routing-lib.sh` are unmodified.
- [ ] **Boundary assertion**: no file under `.claude/**` was written; no task-number reference was
  introduced into either target file.
- [ ] **Cross-sibling consistency check**: if the paired phase-forcing task has already landed its
  flag in `commands/orchestrate.md`, confirm both flags use the identical eight-site shape and
  that neither reordered the other's keys.

**Timing**: 30 minutes

**Depends on**: 1, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**: none (verification only; any defect found is fixed in the owning phase and
re-verified).

**Verification**:

- The no-flag trace is written out in the implementation summary with each link in the chain
  named.
- All four assertion greps return the expected results.

---

## Testing & Validation

- [ ] No-flag regression trace complete and documented: every insertion point interpolates empty,
  no dispatch site emits a `model` parameter, behavior byte-identical to today.
- [ ] `--fable` (and the other three flags) traceable end-to-end through the single-task path.
- [ ] `--fable` traceable through all three Stage MT-4 per-task loops in multi-task mode.
- [ ] `--fable` traceable through the Stage 3.6 team fan-out spawn loop.
- [ ] Zero `Stage 3.5` references in the Stage 5a–Stage 6 auxiliary-dispatch region (lifecycle-only
  scoping intact).
- [ ] Exactly two files modified; the three named scripts untouched.
- [ ] No writes under `.claude/**`; no task-number references in either target file.
- [ ] Every emptiness check tests the empty string, never the literal `null`.
- [ ] Actual dispatch-site count recorded and reconciled against this plan's hypothesis of 12.

## Artifacts & Outputs

- `specs/114_wire_model_flag_through_orchestrate/plans/01_wire-model-flag-orchestrate.md` (this
  file)
- `specs/114_wire_model_flag_through_orchestrate/summaries/01_wire-model-flag-orchestrate-summary.md`
  (written at implementation completion)
- Modified: `agent-system/extensions/core/commands/orchestrate.md`
- Modified: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`

## Rollback/Contingency

Every change is additive text in two markdown files with no schema or script changes, so rollback
is `git revert` of the phase commits (or `git checkout` of the two files at the pre-phase commit
after taking a snapshot via `bash .claude/scripts/git-snapshot.sh 114`). Reverting restores the
current behavior exactly: flags parsed and ignored.

Partial-landing contingency: because the phases are ordered input → resolution → consumption,
stopping after any phase leaves a coherent intermediate state — a `model_flag` that is read but
not yet consumed emits no `model` parameter anywhere, which is identical to today's behavior. The
one ordering that must not be inverted is landing Phase 4 before Phase 3, which would reference a
`model` output that Stage 3.5 does not yet produce.

If the lifecycle-command deletion task has already removed `commands/research.md` before this work
starts, do not block: Phase 1 and Phase 3 restate the reference pattern in full.

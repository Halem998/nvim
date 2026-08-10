# Research Report: Task #871

**Task**: 871 - Completion-time reflective harvest (/todo + /learn)
**Started**: 2026-07-15
**Completed**: 2026-07-15
**Effort**: medium (single-session, ~9 file_scope files, all doc/skill/script edits — no new scripts needed)
**Dependencies**: Task 869 (event store plumbing, COMPLETE), Task 870 (hook event logging, COMPLETE)
**Sources/Inputs**: Codebase (agent-system/extensions/core/, agent-system/extensions/memory/), task 869/870 artifacts (specs/869_unified_event_reflection_store/, specs/870_automatic_hook_event_logging/)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The event-store schema (task 869) was **explicitly designed** for this task: `events-format.md`
  already documents `event_type: "reflection"`, `category: "success"` (typical), and a `detail`
  object shaped exactly as `{what_worked, what_was_hard, what_was_missed, successes}`. No schema
  or `events-append.sh`/`events-query.sh` changes are needed — just one new call site.
- `orchestrator-postflight.sh` already has the exact seam this task needs: Stage 6b (event
  emission, added by task 870) and Stage 7b (writes `completion_summary`/`roadmap_items` to
  state.json, implement-only, gated on `status == success_status`). The new reflection field
  should follow the same two seams: one `events-append.sh` call near Stage 6b, one state.json
  write alongside Stage 7b.
- `return-metadata-file.md` already establishes the pattern to extend: `memory_candidates` is a
  top-level, optional, 0-3-item array on `.return-meta.json` that flows into a top-level
  sibling field on the state.json task entry. `reflection` should be added as a new top-level
  **object** field (not array) with the identical propagation pattern.
- `skill-todo/SKILL.md` Stage 7 (`HarvestMemories`) and Stage 9 (`InteractivePrompts`) already
  read `memory_candidates` from each archived task's state.json entry and present them via one
  `AskUserQuestion` multiSelect. The task instruction to "surface it via the existing
  AskUserQuestion" means: Stage 7 should also collect `reflection` per task, and Stage 9 should
  display it as read-only context alongside (not replacing) the memory-candidate multiSelect —
  no new prompt, no new selection mechanism required.
- `commands/todo.md` is **pre-existing legacy drift**: it has no memory-harvest stages at all
  (Stages 7/9/14 exist only in `skill-todo/SKILL.md`, not in the command file). This task's scope
  in `todo.md` should be a small, targeted addition (not a full re-sync of the memory-harvest
  workflow, which is out of scope and should be flagged as a separate follow-up).
- `memory-harvest.sh` is a **standalone, uncalled script** (confirmed via repo-wide grep): it is
  listed in `manifest.json`'s scripts but nothing in the codebase invokes it — `skill-todo`
  implements its own inline harvest logic instead. It is keyed on `project_number` reading
  `memory_candidates` from `active_projects[]`. If reflection needs a parallel standalone
  extraction path, this script is the logical (but currently dormant) place to add it — flagged
  as a design question for the plan, not resolved here.
- `/learn --task N`'s actual artifact-scanning logic lives in
  `agent-system/extensions/memory/skills/skill-memory/SKILL.md` (Task Mode Execution, Step 2:
  "Scan Artifacts" — `find "$task_dir" -type f -name "*.md"`), which is **NOT in this task's
  file_scope**. `commands/learn.md` only documents the workflow at a summary level. This is a
  scope gap the plan must explicitly address (see Risks).

## Context & Scope

This is a meta task extending the existing completion-time capture pipeline (`skill-todo`
memory harvest, `/learn --task N`) with a fourth data point — a structured self-reflection
(`what_worked` / `what_was_hard` / `what_was_missed` / `successes`) — captured once per task at
the orchestrator-postflight completion seam, persisted to state.json, and logged to the new
unified event store (`specs/events.jsonl`, task 869) for later distillation. It explicitly must
not replace or fork the existing `memory_candidates`/`completion_summary` machinery; it rides
alongside it.

**In file_scope** (9 files, all under `agent-system/extensions/`):
1. `core/skills/skill-todo/SKILL.md`
2. `core/scripts/memory-harvest.sh`
3. `core/scripts/orchestrator-postflight.sh`
4. `core/commands/todo.md`
5. `core/context/formats/return-metadata-file.md`
6. `memory/commands/learn.md`
7. `memory/EXTENSION.md`
8. `core/EXTENSION.md`
9. `core/manifest.json`

**Deployment convention** (confirmed from task 870's summary): edits are authored under
`agent-system/extensions/core/` (and `memory/`) — the *source* location. The deployed
`.claude/`/`.opencode/` copies are synced separately; task 870 explicitly left them un-synced and
accepted the resulting `check-extension-docs.sh` doc-lint drift as an expected, documented
finding. This task should follow the identical precedent unless told otherwise: **do not deploy**
to `.claude/`, and expect the same 1-2 doc-lint drift findings on `orchestrator-postflight.sh`
(already drifted from task 870; this task adds to the same drift, not new drift).

## Findings

### Codebase Patterns

**1. The event schema is already reflection-shaped (task 869, verified by reading the files
directly).**

`agent-system/extensions/core/context/formats/events-format.md`:
- `event_type` common-values table: `reflection | success (typically) | A completion-time
  structured reflection payload, nested in detail.`
- `detail` field description: *"e.g. a completion-time reflection's `what_worked`/
  `what_was_hard`/`what_was_missed`/`successes` fields nest here without requiring a schema
  revision"*.
- `category` closed enum is `deviation | blocker | milestone | success` — task 869's own report
  (`specs/869_unified_event_reflection_store/reports/01_event-store-schema-design.md`, line 170)
  explicitly floats `category: "success"` for the reflection event type.

`events-append.sh` (verified working, `set -euo pipefail`, tested by task 870) accepts
`--event-type`, `--category`, `--session`, `--task`, `--checkpoint`, `--message`,
`--detail-json`, `--error-ref`. A single call shape covers this task's need:

```bash
detail_json=$(jq -c -n \
  --arg what_worked "$what_worked" \
  --arg what_was_hard "$what_was_hard" \
  --arg what_was_missed "$what_was_missed" \
  --arg successes "$successes" \
  '{what_worked:$what_worked, what_was_hard:$what_was_hard,
    what_was_missed:$what_was_missed, successes:$successes}')

bash .claude/scripts/events-append.sh \
  --event-type reflection --category success \
  --checkpoint postflight --task "$task_number" --session "$session_id" \
  --message "Completion-time reflection recorded for task ${task_number}" \
  --detail-json "$detail_json" \
  >/dev/null 2>&1 || echo "[postflight] WARNING: reflection event append failed (non-blocking)" >&2
```

No changes needed to `events-append.sh`, `events-schema.json`, or `events-format.md` (all three
are out of file_scope anyway, and none require it — the schema's `detail` object is deliberately
open-typed to avoid a revision for exactly this payload).

**2. `orchestrator-postflight.sh`'s existing seams (read `orchestrator-postflight.sh` in full,
418 lines).**

- **Stage 6** (lines 137-170): reads `.return-meta.json` fields including
  `memory_candidates`, `completion_summary` (nested under `completion_data`), `roadmap_items`.
  A new `reflection` read should be added here: `reflection=$(jq -c '.reflection // null'
  "$metadata_file")` — top-level, matching `memory_candidates`'s top-level placement rather than
  nesting under `completion_data` (see return-metadata-file.md analysis below for why top-level
  is the right call).
- **Stage 6b** (lines 172-202, added by task 870): emits exactly one `orchestrator_status` event
  per postflight run, timed from `_postflight_t0`. This is the natural place to add a **second**,
  independent `events-append.sh` call for the reflection event — guarded on `[ "$reflection" !=
  "null" ] && [ -n "$reflection" ]`, non-blocking (`|| echo "... (non-blocking)" >&2`), same style
  as the existing call. Should NOT reuse the same event line (reflection has its own
  `event_type`/`category` semantics distinct from `orchestrator_status`).
- **Stage 7b** (lines 245-285): `implement`-only, gated on `[ "$operation_type" = "implement" ]`
  and `[ "${SKIP_COMPLETION_DATA:-false}" != "true" ]`, further gated per-field on `[ "$status" =
  "implemented" ]`. Writes `completion_summary` and `roadmap_items` as **top-level fields** on the
  matched `active_projects[]` entry via inline python3 with triple-single-quote string
  interpolation (`p['completion_summary'] = '''${completion_summary}'''`). A parallel block for
  `reflection` fits here, writing `p['reflection'] = {...}` as a JSON object (4 sub-fields), not
  a string — needs `json.loads('''${reflection}''')` (mirroring how Stage 7c already does this
  for `memory_candidates`, see below) rather than the raw string-substitution used for
  `completion_summary`.
- **Stage 7c** (lines 287-306): `memory_candidates` propagation, **all operations** (not
  implement-gated at the top, though in practice only implementation agents currently emit
  candidates), append semantics (`existing + new_candidates`). This is the closest existing
  precedent for a structured-object field write and should be the template Stage 7d (reflection)
  copies — except reflection should almost certainly be `implement`-only and **overwrite**
  (`p['reflection'] = new_reflection`), not append/accumulate, since it's a single point-in-time
  self-report about the just-completed task, not a growing list. (Recommend explicit
  `operation_type == "implement"` gate, matching completion_summary/roadmap_items gating in
  Stage 7b, since "task completion" only happens at the implement seam in this codebase's model —
  research/plan are intermediate lifecycle stages, not task completions.)
- **Escaping risk inherited from existing code, not introduced by this task**: both Stage 7b's
  `completion_summary` write and Stage 7c's `memory_candidates` write embed shell variables
  directly inside Python triple-quoted string literals via bash variable substitution
  (`'''${completion_summary}'''`, `json.loads('''${memory_candidates}''')`). This is fragile if
  the content contains `'''` or backslash sequences that collide with Python string parsing, but
  it is the established pattern for exactly this kind of write in this file today. The plan
  should either (a) follow the same pattern for consistency (lowest risk of introducing new
  inconsistency, accepted existing fragility), or (b) use `jq --slurpfile`/`--argjson` reading
  directly from the metadata file instead of round-tripping through a bash variable + python
  triple-quote, which would be strictly safer for reflection's four free-text fields (more
  characters for a user/agent to accidentally include quote sequences in than a short
  `completion_summary`). Recommend (b) for reflection specifically, given free-text risk, while
  leaving the existing fields alone.

**3. `return-metadata-file.md`'s schema conventions (426 lines, read in full).**

- `memory_candidates` is documented as a **top-level, optional** field (not nested in
  `completion_data`), 0-3 items, propagated by "Skill postflight" into state.json task entries
  "with append semantics" (line 190).
- `completion_data` (object) is documented as **conditionally required**: "Include if: status is
  `implemented`". It currently has exactly two sub-fields: `completion_summary` (required) and
  `roadmap_items` (optional).
- Two placement options for `reflection`:
  - **(a) Top-level sibling to `memory_candidates`** — e.g. `"reflection": {"what_worked": "...",
    ...}`. Matches the task description's literal wording: *"Persist the reflection as a new
    field alongside memory_candidates/completion_summary"* (memory_candidates is top-level today,
    so "alongside" it most naturally reads as top-level too).
  - **(b) Nested inside `completion_data`** — e.g. `completion_data.reflection = {...}`. Groups
    it with `completion_summary` textually, but breaks the "alongside memory_candidates"
    framing since memory_candidates is NOT inside completion_data today.
  - **Recommendation: (a), top-level**, for exact parity with `memory_candidates`'s existing
    placement and the task description's own phrasing. Document as: `"Include if: status is
    implemented and the agent captured a completion-time reflection (optional even then)"`.
- The doc's own field table for `completion_data` and a new sibling section for `reflection`
  should be added following the existing `### memory_candidates (optional)` section's structure
  (Type / Include-if / field table / category definitions analog / notes), with an explicit
  4-field table: `what_worked`, `what_was_hard`, `what_was_missed`, `successes` (all strings,
  all optional-but-encouraged, ~1-3 sentences each per the task's "structured" framing).
- **Cross-reference note for the plan**: the deeper field-level schema for state.json itself
  lives in `agent-system/extensions/core/context/reference/state-management-schema.md` (NOT in
  file_scope), which already documents `completion_summary`/`roadmap_items`/`memory_candidates`
  as state.json task-entry fields (lines 164-181, verified). That file will need a matching
  `reflection` field entry to stay accurate, but it is out of this task's file_scope — flag as a
  recommended follow-up addition the plan may choose to include anyway (it is a natural
  consequence of the change, low risk, single small file) or explicitly defer.

**4. `skill-todo/SKILL.md`'s Stage 7 (`HarvestMemories`) / Stage 9 (`InteractivePrompts`) (821
lines total, read in full).**

- Stage 7 currently: (1) collects `memory_candidates // []` per archived task, tagging with
  `task_number` provenance; (2) dedups against `.memory/memory-index.json` via keyword overlap;
  (3) applies a 3-tier classification (Tier 1 pre-selected PATTERN/CONFIG >=0.8 confidence, Tier
  2 shown WORKFLOW/TECHNIQUE >=0.5, Tier 3 hidden INSIGHT/<0.5); (4) stores as
  `harvest_candidates`.
- **Extension point**: add a parallel collection step reading `reflection // null` per archived
  task in the same loop as memory_candidates collection (same Stage 7, new sub-step). Store as
  `harvest_reflections` (task_number-keyed list of `{task_number, what_worked, what_was_hard,
  what_was_missed, successes}`), skip tasks with no reflection.
- Stage 9 currently presents ONE `AskUserQuestion` multiSelect for memory harvest candidates
  (Tier 1 pre-selected, Tier 2 shown, Tier 3 behind an expansion option). The task instruction
  "surface it via the existing AskUserQuestion interactive prompt" is best satisfied by
  **augmenting that same prompt's `description`/header text** with a per-task reflection summary
  block (read-only, informational — e.g. "Task 871 reflection: worked={...}; hard={...};
  missed={...}; successes={...}") rather than adding new selectable options or a second prompt.
  This keeps the change additive: the multiSelect mechanics (Tier 1/2/3, dedup, NOOP exclusion)
  are completely unchanged; only the surrounding question text/description grows a reflection
  section when `harvest_reflections` is non-empty. If `harvest_reflections` is empty, omit the
  section entirely (matches the existing "if empty, skip this sub-step" pattern used for
  memory-candidate absence).
- Stage 8 (`DryRunOutput`) should get a matching one-line addition: `Reflections: {N} task(s)
  reported a completion-time reflection` (only shown if `harvest_reflections` non-empty),
  mirroring the existing "Memory candidates: ..." dry-run line format.
- Stage 13 (`UpdateChangelog`) is a plausible additional surface (CHANGE_LOG.md already gets a
  "memory harvest note" appended per Stage 13's process step 3) — the plan could choose to also
  append a one-line reflection summary per archived task to CHANGE_LOG.md, though this is not
  explicitly required by the task description (which names state.json + events.jsonl +
  AskUserQuestion as the three landing sites, not CHANGE_LOG). Flagged as optional scope, not a
  requirement.
- Stage 14 (`CreateMemories`) explicitly notes: *"`memory_candidates` field is implicitly cleaned
  when the task entry is removed from active_projects and moved to archive during Stage 10."*
  The same note should be extended to mention `reflection` is cleaned identically (no separate
  cleanup logic needed — it rides on the existing archive-move mechanism since it's just another
  field on the same task-entry object).

**5. `commands/todo.md` is legacy/stale relative to `skill-todo/SKILL.md` (1013 lines, read
structure via headers).**

Confirmed by `grep -n "^#" `: `todo.md`'s numbered steps (1 through 7) have **no memory-harvest
stage at all** — no mention of `memory_candidates`, `harvest_candidates`, or the AskUserQuestion
memory prompt anywhere in the file. This is pre-existing drift (not something task 871
introduces), presumably because `todo.md` predates the memory-harvest feature being added to
`skill-todo/SKILL.md` and was never back-filled. Also confirmed: `todo.md` never says "delegates
to skill-todo" — it reads as an independent, older spec of the same command.

**Recommendation for the plan**: Do not attempt a full re-sync of `todo.md` with
`skill-todo/SKILL.md`'s memory-harvest workflow (that is a large, separate pre-existing drift-fix
task, out of scope here). Instead, make the minimal targeted addition this task's scope implies:
either (a) a one-line pointer in `todo.md`'s "Notes" section noting that completion-time
reflections (if present) are surfaced during archival per `skill-todo/SKILL.md`'s Stage 9, or (b)
skip `todo.md` content changes if the reflection SKILL.md work is judged sufficient and note in
the plan why `todo.md` was included in file_scope but received no functional change (e.g., "no
content change needed; confirmed via research that todo.md's Stage 7-9 memory-harvest logic does
not exist in this file to extend"). Recommend (a) — a small, honest note — over silently leaving
the listed file untouched.

**6. `memory-harvest.sh` is dormant (190 lines, read in full; confirmed via repo-wide grep for
call sites).**

`grep -rn "memory-harvest.sh"` across the whole `agent-system/` tree returns exactly 3 hits: the
script's own self-references (usage string, header comment) and one design-doc mention in the
email extension (`email-to-memory-preferences.md`) that explicitly **rejects** using this script
as a substrate for a different feature, noting: *"`.claude/scripts/memory-harvest.sh` reads
`.active_projects[] | select(.project_number == $task) | .memory_candidates` from
`specs/state.json`... it is keyed on `project_number`."* No skill, hook, or command actually
invokes it — `skill-todo` reimplements the same logic inline instead (Stage 7/9/14, described
above) and never shells out to this script.

Given this, the task's inclusion of `memory-harvest.sh` in file_scope likely anticipates one of:
- **(a)** Adding a parallel `reflection`-reading code path to this script for symmetry/future use
  (even though nothing calls it today, keeping the two "memory_candidates readers" — inline
  skill-todo logic and this standalone script — in sync going forward), OR
- **(b)** Documenting in the script's header comment that `reflection` is a sibling field this
  script does NOT currently harvest (scope note only, no functional change), OR
- **(c)** The file was included defensively/anticipating deeper harvest-script integration that
  turned out unnecessary once the design was actually worked out (as with `todo.md` above).

**Recommendation**: (a) is the most useful low-risk option if the plan wants this file to do
*something* — add a read of `reflection // null` for the given task_number (identical jq
selector pattern already used for `memory_candidates`) and print/output it in a clearly labeled
second stdout section, OR just document via a header comment that this script is presently
uncalled and reflection-awareness is deferred to `skill-todo`'s inline Stage 7 (matching the
"not replacing" instruction — the source of truth for harvest during `/todo` is the inline logic,
not this script). Given the script is confirmed dead code, the safest choice minimizing new
behavior surface is documentation-only (c)-leaning-(b), with a one-line header comment addition
noting that `reflection` lives on the same task entries but is consumed via `skill-todo`'s inline
logic, not this script — the plan should decide and state its reasoning explicitly either way.

**7. `/learn --task N` flow — scope gap identified.**

`commands/learn.md` (287 lines, read in full) documents Task Mode as: locate task directory ->
scan `reports/`, `plans/`, `summaries/`, `code/`, "Any other artifact directories" -> present
artifact list -> classify -> memory operations. It is a thin argument-parsing/delegation layer
that hands off to `skill-memory` (args: `mode=task, task_number={N}`) and only documents behavior
at a summary level — it does not itself implement the artifact scan.

The actual scan logic (`find "$task_dir" -type f -name "*.md" | sort`) lives in
`agent-system/extensions/memory/skills/skill-memory/SKILL.md`, "Task Mode Execution" -> "Step 2:
Scan Artifacts" (verified by reading the relevant section, lines 642-730). **This file is NOT in
task 871's file_scope.** Since the task's reflection payload lives in `specs/state.json`'s task
entry (not a markdown file under the task directory), `skill-memory`'s `find -name "*.md"` scan
will never surface it as a candidate artifact — the only way `/learn --task N` picks up a
completion-time reflection today is if `skill-memory/SKILL.md` Step 2 is *also* extended to read
`reflection` from state.json and present it as an additional pseudo-artifact/segment. That change
sits outside this task's declared file_scope.

**Recommendation for the plan** (explicit risk to carry forward, not resolved by this report):
1. Update `commands/learn.md`'s Task Mode "Workflow" step 2 ("Scan Artifacts") documentation to
   describe the *intended* behavior — i.e., note that when the task's state.json entry has a
   `reflection` field, it is included as an additional reviewable segment alongside the markdown
   artifacts — even though the functional implementation lives in `skill-memory/SKILL.md`.
2. Explicitly flag to the planner/implementer that making this behavior real requires touching
   `skill-memory/SKILL.md` Step 2, which is outside the given file_scope, and recommend either
   (a) expanding file_scope by one file at planning time (small, well-understood, low-risk
   addition: one new `jq` read + one appended pseudo-artifact entry in an existing loop), or (b)
   explicitly scoping this task's `/learn` change to documentation-only in `learn.md` and filing
   the `skill-memory/SKILL.md` functional change as an immediate, obvious follow-up (not a new
   task discovery — this report already identifies exactly what to change and where).
   Given the task description explicitly promises the `/learn --task` flow will "extend" (not
   just document) reflection surfacing, option (a) — expanding scope by one file — is the more
   faithful interpretation of the task's intent; the file_scope list is a task-creation-time
   estimate, not a hard technical constraint (confirmed: `state-management.md` rule documents
   `file_scope` as "descriptive/anticipated (not filesystem-validated)").

### External Resources

Not applicable — this is a self-contained meta task extending an already-designed internal
pipeline (task 869's schema, task 870's hook wiring). No external library/API research was
needed.

### Recommendations

1. **`return-metadata-file.md`**: Add a new `### reflection (optional)` section, top-level
   sibling to `memory_candidates`, gated "Include if: status is `implemented`" (matching
   `completion_data`'s gating), with a 4-field table (`what_worked`, `what_was_hard`,
   `what_was_missed`, `successes` — all strings, all optional individually but the object as a
   whole should be all-or-nothing per agent judgment). Add a worked example under the existing
   "Implementation Success (Non-Meta)" example.
2. **`orchestrator-postflight.sh`**:
   - Stage 6: read `reflection=$(jq -c '.reflection // null' "$metadata_file")`.
   - Stage 6b (or a new "Stage 6c"): emit one additional `events-append.sh` call,
     `--event-type reflection --category success`, guarded on reflection being non-null,
     independent of/after the existing `orchestrator_status` event call, non-blocking.
   - Stage 7b (or new "Stage 7d", to avoid conflating with completion_summary/roadmap_items'
     existing block): write `reflection` as a top-level object field on the matched
     `active_projects[]` entry, gated on `operation_type == "implement" && status ==
     "implemented" && reflection != "null"`, overwrite semantics (not append). Prefer
     `jq --argjson`/`--slurpfile`-based writes over the existing python3-triple-quote pattern for
     this specific field, given its multi-field free-text content is more injection-prone than
     the single-line `completion_summary`.
3. **`skill-todo/SKILL.md`**: Stage 7 gains a `harvest_reflections` collection sub-step (parallel
   to the memory_candidates collection, no dedup/tiering needed — reflections are 1-per-task, not
   deduped against a vault). Stage 8's dry-run gets one summary line. Stage 9's existing
   AskUserQuestion gains reflection context in its description/header (read-only, no new
   multiSelect options). Stage 14's existing cleanup note gets one added sentence.
4. **`commands/todo.md`**: Add a small, honest "Notes" addition acknowledging completion-time
   reflections surface during archival (pointing at `skill-todo/SKILL.md` for the authoritative
   process) rather than attempting to re-sync the whole (pre-existing, out-of-scope) memory
   harvest workflow into this file.
5. **`memory-harvest.sh`**: Add either a documentation-only header note (recommended, lowest
   risk, matches the script's confirmed-dormant status) or a parallel `reflection` read (if the
   plan decides this script should become the started point for a future direct-invocation
   harvest path). State the decision and reasoning explicitly in the plan.
6. **`memory/commands/learn.md`**: Update Task Mode's artifact-scan documentation to describe
   reflection inclusion. Recommend expanding file_scope by one file
   (`memory/skills/skill-memory/SKILL.md`, Step 2 "Scan Artifacts") to make this functionally
   real rather than documentation-only — see Risks below.
7. **`core/EXTENSION.md`**: The "Unified Event Store" bullet already says "...and reflections" (
   added by task 870's merged EXTENSION.md edit) — verify it still reads correctly after this
   task's changes; likely no further edit needed beyond consistency-checking, since it already
   anticipated this task.
8. **`memory/EXTENSION.md`**: Add a short note under "Memory Lifecycle" or a new small
   subsection acknowledging that `/todo`'s harvest step also surfaces completion-time reflections
   (state.json `reflection` field) alongside `memory_candidates`, and that `/learn --task N` can
   pull them in as an additional reviewable segment.
9. **`core/manifest.json`**: Almost certainly **no functional change needed** — `events-append.sh`,
   `events-query.sh`, `skill-todo`, `memory-harvest.sh`, and `orchestrator-postflight.sh` are all
   already listed in `provides.scripts`/`provides.skills`. Confirm no new script/skill file is
   being introduced by this task (none is, based on the design above) before touching this file;
   if the plan does add a new file anywhere, `manifest.json` needs the corresponding entry.

## Decisions

- **Placement**: `reflection` is a new **top-level** field in both `.return-meta.json` and the
  state.json task entry — parity with `memory_candidates`'s existing placement, not nested inside
  `completion_data`.
- **Gating**: `reflection` write to state.json (Stage 7d) is `implement`-operation-only,
  `status == "implemented"`-gated — matching `completion_summary`/`roadmap_items`'s existing
  gating rationale (task completion happens at the implement seam in this system's model).
- **Event mapping**: one `events-append.sh` call, `event_type=reflection`, `category=success`,
  `checkpoint=postflight`, `detail` = the 4-field object verbatim — exactly as anticipated by
  task 869's report and `events-format.md`'s existing documentation. No new event_type/category
  values, no schema changes.
- **AskUserQuestion reuse**: satisfied by augmenting Stage 9's existing memory-harvest prompt's
  descriptive text, not by adding a second prompt or new selectable options — keeps the change
  strictly additive per the task's "extending... rather than replacing" instruction.
- **`todo.md` and `memory-harvest.sh`**: both receive minimal, honest documentation-level
  additions rather than functional re-implementation, since both are confirmed to be
  out-of-band/legacy relative to the actual `skill-todo/SKILL.md` inline logic that does the real
  work. The plan should state this reasoning explicitly rather than silently leaving listed
  file_scope files untouched.

## Risks & Mitigations

- **Risk**: `/learn --task N`'s functional reflection-surfacing requires editing
  `skill-memory/SKILL.md`, which is outside the declared file_scope.
  **Mitigation**: Recommend the plan explicitly expand file_scope by this one well-understood
  file (Step 2 "Scan Artifacts", ~15-line addition per the pattern already documented in this
  report), citing `state-management.md`'s own statement that `file_scope` is
  "descriptive/anticipated (not filesystem-validated)" as the basis for the expansion. If the
  plan instead chooses to keep strictly to file_scope, it must document `/learn --task N` support
  as "documentation-only in this task; functional support is an immediate follow-up," since
  otherwise the task's stated goal ("surface it... via /learn --task flow") would not actually be
  achieved.
- **Risk**: Free-text reflection fields (4 fields, potentially multi-sentence) embedded into the
  existing python3 triple-quote string-interpolation pattern in `orchestrator-postflight.sh`
  could break on embedded quotes/newlines, more likely than the existing single-line
  `completion_summary` field.
  **Mitigation**: Use `jq --argjson`/temp-file based writes for the reflection field specifically
  (documented in Recommendations #2 above) rather than extending the fragile pattern to
  multi-field free text.
- **Risk**: `todo.md` (command file) and `skill-todo/SKILL.md` (skill file) are already
  out-of-sync (pre-existing drift, confirmed by this research); touching `todo.md` risks
  either (a) doing nothing useful, or (b) accidentally being interpreted as "the fix" for the
  larger pre-existing drift, scope-creeping this task.
  **Mitigation**: Plan should explicitly bound the `todo.md` change to a single small addition
  and explicitly note (in the plan's Non-Goals) that full `todo.md`/`skill-todo` re-sync is out
  of scope and pre-existing.
- **Risk**: `memory-harvest.sh` is dead code; adding functionality to it without a caller
  produces more dead code.
  **Mitigation**: Prefer the documentation-only addition (Recommendation #5) unless the plan
  identifies an actual future caller/use case for this script that justifies extending it.
- **Risk**: `manifest.json` changes are speculative until the plan finalizes whether any new file
  is introduced (e.g., if `skill-memory/SKILL.md` scope-expansion is chosen, that file is already
  registered under the `memory` extension's own manifest, not `core/manifest.json` — verify no
  new script/skill filename is created before touching `core/manifest.json` at all).
  **Mitigation**: Treat `core/manifest.json` as "verify, likely no-op" rather than "definitely
  edit."

## Context Extension Recommendations

- **Topic**: `agent-system/extensions/core/context/reference/state-management-schema.md`
  **Gap**: This file documents the state.json task-entry schema including
  `completion_summary`/`roadmap_items`/`memory_candidates` (lines 164-181, verified) but is not
  in this task's file_scope, so it will drift out of sync with the new `reflection` field unless
  separately updated.
  **Recommendation**: The plan should either include this file as a natural, low-risk consequence
  edit (single new field-table row + one paragraph, same pattern as the existing
  `memory_candidates` documentation immediately above it) or explicitly note it as a known,
  accepted doc-lag to be resolved in a follow-up task.

## Appendix

### Search queries / exploration used

- Repo-root discovery: located actual source-of-truth extension tree at
  `agent-system/extensions/core/` and `agent-system/extensions/memory/` (vs. deployed
  `.claude/extensions/core/`, `.opencode/extensions/core/` copies).
- `jq` inspection of `specs/state.json` for task 871's own entry (dependencies, file_scope,
  description) and tasks 869/870 (status, title) to confirm both dependencies are `completed`.
- Full reads: `events-schema.json`, `events-format.md`, `events-append.sh`, `events-query.sh`
  (partial), `orchestrator-postflight.sh` (full, 418 lines), `return-metadata-file.md` (full, 426
  lines), `skill-todo/SKILL.md` (full, 821 lines, in two passes), `commands/todo.md` (headers +
  targeted sections, 1013 lines), `memory-harvest.sh` (full, 190 lines), `commands/learn.md`
  (full, 287 lines), `core/EXTENSION.md` (full), `memory/EXTENSION.md` (full), `core/manifest.json`
  (full, 231 lines), `skill-memory/SKILL.md` (targeted Task Mode section, lines 630-730).
- `grep -rn "memory-harvest.sh"` across `agent-system/` to confirm zero call sites beyond
  self-reference and one design-doc rejection note.
- Read task 869's report (`01_event-store-schema-design.md`) and task 870's summary
  (`01_hook-event-instrumentation-summary.md`) to confirm both predecessor tasks explicitly
  anticipated and deferred this exact task's scope, and to avoid re-deciding already-settled
  design questions (event_type/category mapping for reflection).

### References

- `agent-system/extensions/core/context/schemas/events-schema.json`
- `agent-system/extensions/core/context/formats/events-format.md`
- `agent-system/extensions/core/scripts/events-append.sh`
- `agent-system/extensions/core/scripts/events-query.sh`
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh`
- `agent-system/extensions/core/context/formats/return-metadata-file.md`
- `agent-system/extensions/core/skills/skill-todo/SKILL.md`
- `agent-system/extensions/core/commands/todo.md`
- `agent-system/extensions/core/scripts/memory-harvest.sh`
- `agent-system/extensions/memory/commands/learn.md`
- `agent-system/extensions/memory/skills/skill-memory/SKILL.md` (out of file_scope, referenced
  for the identified risk)
- `agent-system/extensions/core/context/reference/state-management-schema.md` (out of file_scope,
  referenced for the identified context-extension gap)
- `specs/869_unified_event_reflection_store/reports/01_event-store-schema-design.md`
- `specs/870_automatic_hook_event_logging/summaries/01_hook-event-instrumentation-summary.md`

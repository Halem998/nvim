# Research Report: Build the dispatch-prep stage in skill-orchestrate

- **Task**: 117 - Build the dispatch-prep stage in skill-orchestrate: memory retrieval, --lit resolution, --clean, --fast
- **Started**: 2026-08-31T18:50:00Z
- **Completed**: 2026-08-31T19:10:00Z
- **Effort**: ~1 hour (research only)
- **Dependencies**: None (this is the A1-precondition rehome; it must land before any successor
  task deletes `commands/research.md`, `commands/plan.md`, `commands/implement.md`, or
  `skill-researcher`/`skill-planner`/`skill-implementer`)
- **Sources/Inputs**:
  - `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (2,814 lines, full read of
    Stages 0-8, MT-1 through MT-4, and the dispatch-site tables)
  - `agent-system/extensions/core/commands/orchestrate.md` (Options table, Stage 0 flag parsing,
    single-task and multi-task Skill delegation)
  - `agent-system/extensions/core/commands/research.md` / `plan.md` / `implement.md` (flag
    parsing precedent for `--clean`/`--fast`)
  - `agent-system/extensions/core/skills/skill-researcher/SKILL.md`,
    `skill-planner/SKILL.md`, `skill-implementer/SKILL.md` (Stage 4a: Memory Retrieval)
  - `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md` (274-line shared
    literature flow, full read)
  - `agent-system/extensions/core/scripts/memory-retrieve.sh`,
    `agent-system/extensions/core/scripts/parse-command-args.sh`,
    `agent-system/extensions/core/scripts/command-route-agent.sh`
  - `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md` (A1
    precondition, A6 preserved-assets table — authoritative design source for this task)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- `skill-orchestrate/SKILL.md` dispatches every lifecycle phase directly via the Agent tool
  against `general-research-agent`/`planner-agent`/`general-implementation-agent`, with zero
  memory retrieval and zero `--lit` resolution — confirmed live, matching the task's framing
  exactly (13 pass-through `lit_flag` occurrences, 0 `memory-retrieve`/`clean_flag`/
  `lit-stage4a`/`literature-briefing` occurrences).
- `orchestrate.md`'s `## Options` table has no `--clean` and no `--fast` row; but
  `parse-command-args.sh` (already sourced at Stage 0) unconditionally exports `CLEAN_FLAG` and
  `EFFORT_FLAG` regardless of whether `orchestrate.md` documents or consumes them — so no parser
  change is needed, only consumption.
- The correct design is **one new shared stage** ("Dispatch Prep") placed between the existing
  Stage 3 (State Machine Loop) and Stage 4 (State Handlers) in single-task mode, referenced by a
  short pointer line at each of the **7 single-task dispatch sites** and the **3 multi-task
  per-phase dispatch loops** — mirroring the file's existing convention for the
  "dispatch window for infra-failure discrimination" shared snippet, not a hand-rolled bash
  function (this file is prose executed by an LLM, not a real bash script).
- **Blocking latent bug found**: the multi-task dispatch loop (Stage MT-4) already references
  `$description` in its research-dispatch prompt (`"Research task $task_num: $description"`) but
  no stage in the multi-task path ever defines a per-task `description` variable — Stage MT-2
  only captures `task_type`/`project_name`. Both `memory-retrieve.sh` and
  `lit-stage4a-flow.md` require `description` as a hard precondition (`memory-retrieve.sh` exits
  1 with empty `description`). This must be fixed as part of this task, not left for later, or
  the new dispatch-prep stage will silently produce empty `memory_context`/`lit_context` for
  every multi-task dispatch.
- Recommended report path for the implementer: treat this as touching exactly two files —
  `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` and
  `agent-system/extensions/core/commands/orchestrate.md` — both in the source store, never
  `.claude/**` directly.

## Context & Scope

This is Phase-A/A1-precondition work identified by task 116's design report (report 03, "A1
precondition — the dispatch-bypass gap"). Scope is deliberately narrow per the task's WORK
description and per report 03's A6 table, which lists exactly three REBUILD-REQUIRED rows this
task must satisfy:

1. **Memory retrieval + `--clean` suppression** (A6 row 2)
2. **`--lit` literature briefing injection** (A6 row 1)
3. **`--fast`** (A6 row 3, distinct from `--hard`/hard-mode contract injection which is A4's
   scope, not this task's)

Explicitly **out of scope** (confirmed against A6, do not implement here):
- Model flags (`--haiku`/`--sonnet`/`--opus`/`--fable`) — task #114's scope, independently filed.
- `--team` mode — A5's scope (shared fan-out stage).
- `--hard` mode / hard-mode contract injection — A4's scope
  (`skill-orchestrate-hard` already exists as a separate file; this task touches
  `skill-orchestrate` only, not `skill-orchestrate-hard`).
- Deleting `commands/research.md`/`plan.md`/`implement.md` or the three lifecycle skills — those
  are later, ordering-dependent successor tasks per the binding ORDERING constraint in the task
  description and in report 03's "Migration note."

## Findings

### Current State (verified live)

**`skill-orchestrate/SKILL.md`** (2,814 lines):
- Stage 0 (line 25) reads `multi_task_mode, session_id, focus_prompt, lit_flag` from the
  delegation context. No `clean_flag`, no `effort_flag`.
- Stage 1 (line 39) reads `task_number, session_id, focus_prompt, lit_flag, continue_budget`,
  then extracts `PROJECT_NAME, TASK_TYPE, DESCRIPTION, TASK_DIR` from `state.json`. Note the
  case: this stage's description variable is `DESCRIPTION` (uppercase), unlike
  `skill-researcher`'s lowercase `description` — `lit-stage4a-flow.md`'s precondition section
  expects a variable simply named `description`; the new stage should either alias
  `description="$DESCRIPTION"` or pass `$DESCRIPTION` directly wherever the flow's steps
  reference `$description`, and call this out explicitly so the implementer does not trip on the
  case mismatch.
- Stage 1b (line 73) resolves `RESEARCH_AGENT`/`PLANNER_AGENT`/`IMPLEMENT_AGENT` via
  `command-route-agent.sh`, currently always passing `""` as the 4th (`effort_flag`) argument.
- Stage 3 (line 260): State Machine Loop — the per-cycle loop wrapper; ends around line 325.
- Stage 4 (line 325): State Handlers — contains exactly **7 dispatch sites** across 6 state
  blocks (each with an "Invoke the Agent tool" table with `subagent_type`/`prompt`/`context`
  rows):
  | Line (handler start) | State | Phase | subagent_type row | context row |
  |---|---|---|---|---|
  | 327 | `not_started`/`not started` | research | 346 | 348 |
  | 359 | `researching` | research | 390 | 392 |
  | 403 | `researched` | plan | 429 | 431 |
  | 442 | `planning` | plan | 472 | 474 |
  | 485 | `planned`/`implementing` | implement (fresh) | 509 | 511 |
  | 522 | `partial` → continuation sub-state | implement (resume) | 581 | 583 |
  | 522 | `partial` → no-handoff sub-state | implement (base-mode resume) | 643 | 645 |

  (`blocked` at 658 and `completed` at 677 do not dispatch — escalation/terminal states, out of
  scope.) Every `context` row already threads `lit_flag` through verbatim (never resolved); none
  inject `memory_context` or `lit_context`; none check `clean_flag`.
- Multi-task mode: Stage MT-1 (line 1284) reads `task_numbers, dependency_graph, waves,
  session_id, lit_flag, allow_self_modifying, allow_scope_collision` — no `clean_flag`, no
  `effort_flag`. Stage MT-2 (line 1475) builds the per-task routing table
  (`task_type, project_name, task_dir, research_agent, implement_agent`) — **no `description`
  capture**, confirmed by grep (`description` appears in the whole file's multi-task section only
  once, as a bare reference at line 2096, never assigned). Stage MT-4 (line 1955) is the
  phase-aware dispatch stage containing the **3 multi-task dispatch loops** (research_tasks
  loop at line ~2096, plan_tasks loop at line ~2103, implement_tasks loop at line ~2115), each a
  single prose bullet ending in "Invoke Agent tool: ... prompt = ..., context = ...", not a table
  — the injection point is the `prompt = "..."` segment of that bullet.
- The `dispatch_seq`/`dispatch_start_ts` "dispatch window" 3-line bash snippet is repeated
  verbatim at all 7 single-task sites (and analogously batched once per MT dispatch group) —
  this is the file's existing precedent for "one canonical shared block, referenced/repeated at
  each dispatch site" and is the pattern to follow for the new Dispatch Prep block, **except**
  that the new block is far larger (memory retrieval + the full `lit-stage4a-flow.md` 6-directive
  branch), so it should be defined ONCE as a numbered stage and referenced by a short pointer
  line at each site — not repeated in full 10 times, which would add on the order of 1,500-2,000
  lines.

**`orchestrate.md`** (verified live):
- `## Options` table (line 29) has exactly 4 rows: `--lit`, `--dry-run`,
  `--allow-self-modifying`, `--allow-scope-collision`, `--continue-budget` (5 rows, counting
  correctly). No `--clean`, no `--fast`.
- STAGE 0 (line ~44) sources `parse-command-args.sh`, whose own comment lists only
  `TASK_NUMBERS, FOCUS_PROMPT, REMAINING_ARGS, DRY_RUN_FLAG, ALLOW_SELF_MODIFYING_FLAG,
  ALLOW_SCOPE_COLLISION_FLAG, CONTINUE_BUDGET_FLAG` as "Exports:" — but
  `parse-command-args.sh` itself (confirmed by reading the script) unconditionally exports
  `CLEAN_FLAG` and `EFFORT_FLAG` (and `MODEL_FLAG`, `LIT_FLAG`, etc.) on every invocation
  regardless of what the caller's comment claims to use. **This means `CLEAN_FLAG` and
  `EFFORT_FLAG` are already live shell variables inside `orchestrate.md` today** — the gap is
  purely that `orchestrate.md` never reads or forwards them. No `parse-command-args.sh` change
  is needed; only `orchestrate.md`'s own STAGE 0 comment and downstream Skill-invocation blocks
  need updating.
- Single-task delegation (STAGE 2, ~line 620-644): `skill: "skill-orchestrate"`, args string at
  line 625 is `"task_number={N} session_id={SESSION_ID} orchestrator_mode=true
  lit_flag={LIT_FLAG} continue_budget={CONTINUE_BUDGET_FLAG}"`; JSON delegation context at
  line ~640-646 mirrors the same field set. Neither includes `clean_flag` or `effort_flag`.
- Multi-task delegation (~line 429-445): same shape, `args:` line 429/430 and JSON context
  line ~440-446, also missing `clean_flag`/`effort_flag`.

### Precedent: how `research.md`/`plan.md`/`implement.md` already do this

- `research.md` STAGE 1.5 parses `--fast`/`--hard` into `effort_flag` (prose var, materialized
  to a shell var just before use) and `--clean` into `clean_flag` (boolean), then STAGE 2 passes
  both into the Skill `args:` string and JSON delegation context alongside `lit_flag`
  (`args: "... effort_flag={effort_flag} model_flag={model_flag} clean_flag={clean_flag}
  lit_flag={lit_flag}"`).
- `implement.md` instead uses the shell-exported `EFFORT_FLAG`/`CLEAN_FLAG` directly from
  `parse-command-args.sh` (no re-parse), passing
  `args: "... effort_flag={EFFORT_FLAG} model_flag={MODEL_FLAG} clean_flag={CLEAN_FLAG}
  lit_flag={LIT_FLAG} orchestrator_mode=false"`. **`orchestrate.md` should follow this same
  shell-export shape** since it already sources `parse-command-args.sh` and does not re-parse
  flags itself (matching its existing `DRY_RUN_FLAG`/`ALLOW_SELF_MODIFYING_FLAG` usage pattern).
- `skill-researcher`/`skill-planner`/`skill-implementer` Stage 4a all gate memory retrieval on
  `clean_flag`:
  ```bash
  if [ "$clean_flag" != "true" ]; then
    memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "$focus_prompt" 2>/dev/null) || memory_context=""
  fi
  ```
  **Important asymmetry**: `skill-researcher` passes `"$focus_prompt"` as the 3rd
  `memory-retrieve.sh` argument; `skill-planner`/`skill-implementer` both pass `""` (empty
  string) instead. The new Dispatch Prep stage in `skill-orchestrate` must reproduce this same
  per-phase asymmetry — research dispatches pass `$focus_prompt`, plan/implement dispatches pass
  `""` — not a single hardcoded value for all three phases.
- All three skills' literature block is identical, delegating verbatim to
  `@.claude/context/patterns/lit-stage4a-flow.md`, whose only preconditions are `lit_flag`,
  `description`, and `orchestrator_mode` (defaulting to `"false"` when unset). Since
  `skill-orchestrate` always sets `orchestrator_mode: true` for every dispatch it makes, the
  flow's `AUTONOMOUS_GLOBAL` and the autonomous branch of `SPARSE_PROMPT_NEEDED` are the only
  reachable non-`LIT_DISABLED`/`GLOBAL_MISSING` branches in practice — **no `AskUserQuestion`
  call is ever reachable from inside `skill-orchestrate`'s dispatch prep**, which simplifies the
  new stage considerably versus the interactive skills' equivalent block (still import the whole
  file verbatim, per its own header, rather than hand-picking only the autonomous branches — the
  flow file is the single canonical copy and is explicitly designed to be imported by exactly
  this kind of caller).
- Injection placement (from `skill-researcher` Stage 5): the memory block goes in the **prompt
  text**, not the `context` JSON — `<memory-context>` first, then `<literature-briefing>`, both
  placed after any format-spec section and before task-specific instructions, and **never
  injected as an empty tag pair** when the corresponding context is empty. Since
  `skill-orchestrate` has no format-spec injection today (confirmed — zero occurrences of
  `report-format.md`/`plan-format.md`/`format_content` anywhere in the file; that gap is out of
  scope for this task), the two blocks simply become the first content appended to each
  dispatch's existing minimal prompt string, in that same order.

### `command-route-agent.sh`'s `effort_flag` parameter

`command-route-agent.sh`'s header documents `$4 = effort_flag: "hard" | "fast" | "" | unset`,
where only `"hard"` changes resolution behavior (routing against `routing_agents_hard` first).
Stage 1b currently passes `""` unconditionally. Threading `$EFFORT_FLAG` through here instead
(`source .claude/scripts/command-route-agent.sh "research" "$TASK_TYPE" "general-research-agent"
"$EFFORT_FLAG"`) is harmless and consistent with "the same way research.md/plan.md/implement.md
already do today" (those commands pass their own resolved effort flag into
`command-route-skill.sh`'s equivalent 4th argument) — but it is not strictly required by this
task's WORK item, which asks specifically about "dispatch-context construction," i.e. the
`context` JSON object built for each Agent-tool call, not agent-name routing. Recommend doing it
anyway (low-risk, one-line change per call, future-proofs `--hard` routing changes without a
second edit pass) but flag it as optional/non-blocking if the implementer wants a smaller diff.

### The multi-task `description` gap (must-fix, in scope)

Stage MT-4's three dispatch bullets (research/plan/implement) all reference `$description` in
their prompt text, but no stage in the multi-task path ever assigns it. Stage MT-2 ("Build
Per-Task Routing Table") only names `task_type, project_name` as fetched from `state.json`, and
the `mt_state_file` field list in Stage MT-1's init block has no `descriptions` map (it does have
`task_dirs`, `research_agents`, `implement_agents` as per-task maps — `descriptions` is the
missing sibling). Both `memory-retrieve.sh` (hard `exit 1` on empty `description`) and
`lit-stage4a-flow.md` (its resolver script takes `--query "$description"`) require this value.
**This is a pre-existing latent bug independent of this task**, but the new Dispatch Prep stage
cannot function correctly in multi-task mode without it, so fixing it is in scope: add a
per-task `description=$(echo "$task_data" | jq -r '.description // ""')` read inside Stage MT-2's
existing per-task loop, and add a `descriptions` map (task_num → description) to the
`mt_state_file` field list alongside `task_dirs`/`research_agents`/`implement_agents`.

## Decisions

- **Placement**: define the new stage as **"Stage 3.5: Dispatch Prep"** in the single-task
  path, positioned between the existing Stage 3 (State Machine Loop, ends ~line 325) and Stage 4
  (State Handlers, starts line 325) — i.e. inserted at the current line-325 boundary. For
  multi-task mode, the same procedure is referenced from inside Stage MT-4's three dispatch
  loops (no separate MT-numbered stage needed — MT-4 already documents per-loop dispatch prose,
  so add the same short pointer bullet there, reusing the exact same Stage 3.5 procedure text
  rather than defining a second copy).
- **Shape of the shared procedure**: a self-contained prose+bash block, structured to mirror
  `skill-researcher`'s Stage 4a exactly (so a future reader can diff the two side by side), with
  one addition — a `phase` parameter (`"research"`/`"plan"`/`"implement"`) that selects the
  `memory-retrieve.sh` 3rd argument (`$focus_prompt` for `"research"`, `""` otherwise). Two
  outputs: `memory_context` (raw, possibly empty, already `<memory-context>`-wrapped by
  `memory-retrieve.sh` itself — confirm this against the script's actual output format before
  wiring the injection line, since the skills' Stage 5 injection instructions say "already
  wrapped in `<memory-context>` tags" implying the wrapping happens either inside the script or
  inside Stage 4a's own code — worth one targeted `Read` of `memory-retrieve.sh`'s tail during
  implementation to confirm which) and `lit_context` (from the imported `lit-stage4a-flow.md`
  flow, already `<literature-briefing>`-wrapped per that flow's own contract).
- **Injection point**: append `memory_context` then `lit_context` (skip either when empty) to
  the end of each dispatch site's existing `prompt` string, after the existing task-description
  text, matching the "AFTER format spec / BEFORE task instructions" ordering intent as closely
  as this file's much shorter existing prompts allow (there is no format-spec block here to sit
  between, so simply: base prompt text, then memory block, then lit block).
- **Flag threading in `orchestrate.md`**: reuse the already-exported `CLEAN_FLAG`/`EFFORT_FLAG`
  shell variables from the existing `parse-command-args.sh` source call (no new parsing logic),
  add `--clean` and `--fast` rows to the `## Options` table (copy wording verbatim from
  `implement.md`'s existing rows: "Skip automatic memory retrieval" / "Low-effort mode: lighter
  reasoning, faster responses"), and thread `clean_flag={CLEAN_FLAG}` +
  `effort_flag={EFFORT_FLAG}` into both the single-task and multi-task Skill `args:` strings and
  JSON delegation-context blocks, alongside the existing `lit_flag={LIT_FLAG}`.
- **`effort_flag` reasoning-depth guidance**: per report 03's A6 note ("fast lowers reasoning
  depth, independent of hard_mode's contract injection"), append a short one-line note to each
  dispatch's prompt when `effort_flag` is set (mirroring `research.md`'s own instruction: "If
  `effort_flag` is set, pass it as prompt context to the skill/agent for reasoning depth
  guidance") — this is a small addition to the same Dispatch Prep stage, not a separate stage.
- **Fix the `description` gap in MT-2 as part of this task** (see Findings) since the new
  Dispatch Prep stage is unusable in multi-task mode without it, and it is a direct precondition
  failure, not a tangential cleanup.
- **Do not** touch `skill-orchestrate-hard/SKILL.md` — out of scope (A4), a separate file with
  its own independent (and currently non-functional per report 03 Finding 2) dispatch path.
- **Do not** add format-spec (`report-format.md`/`plan-format.md`) injection to
  `skill-orchestrate` — not requested by this task's WORK item; flagged only as a pre-existing,
  separate gap for a future task if needed.

## Risks & Mitigations

- **Risk**: repeating the full `lit-stage4a-flow.md` procedure text at all 10 dispatch sites
  would bloat the file by ~1,500+ lines and create 10 places that can drift out of sync.
  **Mitigation**: define once as Stage 3.5, reference by name at each site (the file already
  does this for smaller shared snippets like the dispatch-window block; extend the same
  convention rather than inventing a new one).
- **Risk**: silently reusing a single `memory-retrieve.sh` call across all three phases (ignoring
  the research-vs-plan/implement `focus_prompt` argument asymmetry) would diverge from the
  skills' current behavior and make the migration not-quite-equivalent. **Mitigation**: thread a
  `phase` parameter through the shared procedure exactly as described in Decisions above.
- **Risk**: forgetting the multi-task `description` gap means the new stage appears to work in
  single-task testing but silently no-ops (empty `memory_context`/`lit_context`, and the
  pre-existing prompt text's `$description` interpolation stays empty too) in every multi-task
  `/orchestrate` run. **Mitigation**: explicitly called out above as in-scope, must-fix.
  Verification: a forced multi-task test dispatch should show a non-empty `Research task N:
  {actual description text}` prompt, not `Research task N: ` with nothing after the colon.
  Consider adding a runtime `if [ -z "$description" ]` warning in the Dispatch Prep stage
  wherever it's called (self-diagnosing this exact gap class if it ever regresses again),
  matching this file's existing style of loud-non-blocking warnings (e.g. the task-lock defer
  warning at line ~317).
- **Risk**: variable-name case mismatch (`DESCRIPTION` vs. `description`) causes a
  copy-pasted `lit-stage4a-flow.md` reference to silently read an unset variable in single-task
  mode. **Mitigation**: explicitly alias `description="$DESCRIPTION"` (single-task) /
  `description` (already lowercase once the MT-2 fix above lands) at the top of the Dispatch
  Prep stage's own scope, and note this explicitly in the stage's own text so a future editor
  does not "simplify" it away.

## Context Extension Recommendations

None — the relevant patterns (`lit-stage4a-flow.md`'s import contract, `memory-retrieve.sh`'s
CLI contract, the file's own dispatch-window shared-snippet convention) are already documented
in place and sufficient; this task consumes them rather than needing new context documentation.

## Appendix

- Search/read commands used: `grep -n` for `subagent_type`/`lit_flag`/`clean_flag`/
  `memory-retrieve`/`description` across `skill-orchestrate/SKILL.md`, `orchestrate.md`,
  `research.md`, `parse-command-args.sh`, `command-route-agent.sh`; full reads of
  `lit-stage4a-flow.md` and the relevant Stage 4a sections of `skill-researcher`/
  `skill-planner`/`skill-implementer`; targeted `sed -n` reads of `skill-orchestrate/SKILL.md`
  Stage 0/1/1b, the 6 state-handler blocks (327-704), and Stage MT-1/MT-2/MT-4 (1284-2130).
- Exact single-task dispatch-site line numbers and multi-task loop line numbers are recorded in
  Findings above as of this research pass; they will drift once the implementer edits the file,
  so treat them as a starting map, not a frozen contract — re-anchor on the `#### State:` /
  `### Stage MT-4` headers, which are stable identifiers.

# Research Report: Wire model-flag threading through /orchestrate

- **Task**: 114 - Wire model-flag threading through /orchestrate and the base orchestrate engine
- **Started**: 2026-09-01T00:00:00Z
- **Completed**: 2026-09-01T00:00:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Sources/Inputs**:
  - `agent-system/extensions/core/commands/orchestrate.md`
  - `agent-system/extensions/core/commands/research.md`
  - `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  - `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
  - `agent-system/extensions/core/skills/skill-researcher/SKILL.md`
  - `agent-system/extensions/core/scripts/parse-command-args.sh`
  - `agent-system/extensions/core/scripts/command-route-agent.sh`
  - `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh`
  - `specs/state.json` (task 114 entry)
- **Artifacts**: this report
- **Standards**: report-format.md, return-metadata-file.md

## Executive Summary

- The task description's redirect ("wire `model_flag` into the dispatch-prep stage") is
  confirmed correct: `skill-orchestrate/SKILL.md`'s **Stage 3.5: Dispatch Prep** (line 597) is
  already the single canonical stage every research/plan/implement dispatch site funnels
  through for `clean_flag`/`effort_flag`/`hard_mode`. `model_flag` slots into the same stage as
  a new input producing a new `model` output (an Agent-tool parameter, not a prompt-appended
  string like the other four outputs).
- All previously-cited line numbers in the task description are stale (file grew from 188,284 to
  268,147 bytes since origination); this report re-measures every anchor and cites headings/
  surrounding text as the durable reference, with current line numbers as of this research pass
  only.
- **Design decision (a) UNIFORM vs LIFECYCLE-ONLY is resolved: LIFECYCLE-ONLY, and it falls out
  of the existing architecture for free.** None of the six auxiliary dispatch sites (Stage 5a
  Drift Inspection's fork + reviser, Stage 5b's divergence-audit research dispatch, Stage 6
  Blocker Escalation's fork + reviser + implement re-dispatch) call Stage 3.5 today — confirmed
  by a zero-match grep for "Stage 3.5" across that entire region. Wiring `model_flag` into Stage
  3.5 therefore automatically excludes these diagnostic dispatches with no exemption list to
  write or maintain.
- **Design decision (b) MULTI-TASK THREADING is resolved: resolve `model_flag` once at Stage 1 /
  Stage MT-1, thread it unchanged into every Stage 3.5 call** — exactly mirroring how
  `clean_flag`/`effort_flag`/`hard_mode` are already handled. It is a single invocation-wide
  value, never re-resolved per task in the MT-4 loops.
- **Design decision (c) HARD-MODE MT COVERAGE is confirmed to still hold.**
  `skill-orchestrate-hard/SKILL.md` states (at two locations, re-measured) that its multi-task
  stages are the base engine's MT-1 through MT-5 unchanged. The follow-on task therefore only
  needs to touch hard mode's 7 single-task dispatch sites (re-counted and re-anchored below).
- `commands/orchestrate.md` differs architecturally from `commands/research.md`: it sources
  `parse-command-args.sh` directly and threads flags through **both** a flat `args:` Skill string
  and a separate JSON delegation-context object at each of its two dispatch sites, so this task's
  fix needs 4 insertion points in `orchestrate.md`, not the 2 that `research.md`'s single-string
  pattern would suggest.

## Context & Scope

Scope is exactly as stated in the task: `commands/orchestrate.md` and
`skills/skill-orchestrate/SKILL.md` only. This report re-measures the current source-store state
(all citations verified directly against `agent-system/extensions/core/`, not the deployed
`.claude/` tree), confirms the dispatch-prep redirect, resolves the three required design
decisions with evidence, and hands the implementer a concrete, anchored edit list.

## Findings

### Re-measured facts (supersede the original description's line numbers)

- `skills/skill-orchestrate/SKILL.md` is now 268,147 bytes (matches the "~268,000" estimate in
  the revision note).
- `scripts/parse-command-args.sh` already handles all four model flags correctly and must not be
  touched: `MODEL_FLAG=""` default (line 87), set to `haiku`/`sonnet`/`opus`/`fable` at lines
  116/119/122/125, exported at line 186 (drifted from the original ":179" citation, substance
  unchanged).
- `commands/orchestrate.md` (43,407 bytes): zero references to any model flag anywhere — no
  `## Options` row, no `argument-hint` entry, no `MODEL_FLAG` in either dispatch site.
- `skills/skill-orchestrate/SKILL.md`: zero `model_flag`/`MODEL_FLAG` occurrences file-wide. Same
  for `skill-orchestrate-hard/SKILL.md`.
- `scripts/command-route-agent.sh` and `scripts/lib/manifest-routing-lib.sh`: still zero model
  handling — confirms these must stay untouched (model selection is orthogonal to the agent-name
  routing ladder these scripts implement).
- The reference pattern in `commands/research.md` still holds structurally but has one
  architectural difference worth flagging: research.md never sources `parse-command-args.sh`
  itself and carries **no separate JSON delegation-context block** — it threads
  `model_flag={model_flag}` only through its flat `args:` Skill string (lines 540 and 544), and
  the consuming half lives in `skill-researcher/SKILL.md:187` (context-parse key) and `:195`
  (pass-as-`model`-parameter instruction). `commands/orchestrate.md` is different: it sources
  `parse-command-args.sh` directly (line 56) and threads flags through **both** a flat `args:`
  string **and** a separate JSON delegation-context object at each of its two dispatch sites.
  Implication: the fix needs 4 insertion points in `orchestrate.md`, not 2.

### The fix point: Stage 3.5 Dispatch Prep

`skill-orchestrate/SKILL.md:597` — "Stage 3.5: Dispatch Prep (shared, runs immediately before
every Agent dispatch)" — is explicitly documented as "the SINGLE canonical copy" of the
memory-retrieval/literature-briefing/hard-contract-injection procedure that every Stage 4
(single-task) and Stage MT-4 (multi-task) dispatch site calls via a short pointer line, never
duplicating the body. It currently accepts `phase`, `description`, `task_type`, `focus_prompt`,
`clean_flag`, `effort_flag`, `lit_flag`, `orchestrator_mode`, `hard_mode`, `territory` as inputs
and produces `memory_context`, `lit_context`, `effort_note`, `hard_contracts_block` as outputs,
each appended (when non-empty) to the END of the dispatch prompt string, in that fixed order.

`model_flag` slots in as a new input, producing a new output (`model`) that is **not** appended
to the prompt like the other four — it is a sibling Agent-tool parameter, exactly like
`subagent_type`, mirroring research.md's contract precisely: non-empty → pass `model:` parameter
on the Agent tool invocation; empty → omit the parameter entirely (frontmatter default applies).
This needs its own sentence in Stage 3.5's "Outputs and injection contract" paragraph, distinct
from the four prompt-appended outputs, since it is never added to the prompt string or the
`context` JSON object.

Verified call sites that funnel through Stage 3.5 (all confirmed via `grep -n "Dispatch Prep"`):
9 single-task Stage 4 call sites (state handlers spanning research/plan/implement phases), the 3
multi-task Stage MT-4 per-task dispatch loops (research, planner, implement — invoked once per
task inside MT-4's own loop body), and the Stage 3.6 Team Fan-Out spawn loop (which itself calls
Stage 3.5 once per teammate before spawning — so `--hard --team` already gets hard-contract
injection "for free," and the model override will too, with zero additional wiring at that site).

### Design decision (a): UNIFORM vs LIFECYCLE-ONLY — resolved LIFECYCLE-ONLY

I grepped the entire auxiliary-dispatch region of `skill-orchestrate/SKILL.md` (from `### Stage
5a: Drift Inspection` through the end of `### Stage 6: Blocker Escalation`, re-measured at lines
2216-2410+) for any reference to "Stage 3.5" — **zero matches**. None of the following six
auxiliary dispatches call Stage 3.5 today:

- Stage 5a Drift Inspection: research fork (`subagent_type: "fork"`, re-measured ~line 2238) and
  plan-revision dispatch (`subagent_type: "reviser-agent"`, ~line 2252).
- Stage 5b Churn Detection / H5 Three-Strikes: divergence-audit dispatch
  (`subagent_type: $RESEARCH_AGENT`, ~line 2314), invoked via `delegation_context` rather than a
  raw `context` object.
- Stage 6 Blocker Escalation: research fork (`subagent_type: "fork"`, ~line 2354), plan-revision
  dispatch (`subagent_type: "reviser-agent"`, ~line 2376), and implement re-dispatch
  (`subagent_type: $IMPLEMENT_AGENT`, ~line 2396).

All six are raw Agent-tool invocations, mostly with `orchestrator_mode: false` (Stage 6's
implement re-dispatch is the one exception, with `orchestrator_mode: true`, yet it *still* does
not reference Stage 3.5 or append `memory_context`/`lit_context`/`effort_note`/
`hard_contracts_block` — a separate, pre-existing gap outside this task's scope, noted here for
completeness).

**Decision**: wiring `model_flag` into Stage 3.5's input/output set automatically scopes the
override to exactly the research/plan/implement lifecycle dispatches (Stage 4, Stage MT-4, and
Stage 3.6 team fan-out), leaving all six auxiliary/diagnostic dispatches at their frontmatter
defaults — with **zero exemption list to write or maintain**, since the auxiliary sites simply
never call the stage being modified. This resolves the task description's own stated argument for
lifecycle-only (reviser-agent's Opus-by-policy default should not be silently downgraded by a
user's `--haiku` intended for implementation speed) as an emergent property of the architecture,
not a new carve-out requiring separate code.

**Recommendation for the implementer**: state this explicitly in `orchestrate.md`'s `## Options`
table row for the model flags — e.g. "applies to research/plan/implement dispatches; diagnostic
dispatches (blocker escalation, drift inspection, churn audit, plan revision) retain their
frontmatter model" — so the behavior is documented, not just implied by omission.

### Design decision (b): MULTI-TASK THREADING — resolved: resolve once, thread unchanged

`model_flag` should be parsed once in Stage 1 (single-task) / Stage MT-1 (multi-task) and
threaded unchanged into every Stage 3.5 call, exactly mirroring how `clean_flag`/`effort_flag`/
`hard_mode` already work. Stage MT-1's own documentation (re-measured ~line 2543) states
`hard_mode` is "Consumed by Stage 3.5 Dispatch Prep's hard-mode contract injection below, for
every per-task dispatch this batch makes" — the same shape is correct for `model_flag`: a single
invocation-wide value, never re-resolved or re-read per task.

Concretely, Stage MT-4's three per-task dispatch loops (research ~line 3390, planner ~line 3402,
implement ~line 3419) each need one addition alongside their existing `subagent_type =` line:
"pass `model` (Stage 1/MT-1's resolved value, if non-empty) as the Agent tool's `model`
parameter." No new per-task state field is needed in `mt_state_file` — `model` is a batch-scoped
constant for the whole invocation, not a per-task map.

### Design decision (c): HARD-MODE MT COVERAGE — confirmed, still holds

`skill-orchestrate-hard/SKILL.md` states, at two re-measured locations (~line 1609 and ~line
1726, content unchanged from the original citations at :1580/:1687 — only line numbers drifted),
that its multi-task stages are "Same as base `skill-orchestrate` multi-task stages (MT-1 through
MT-5)." This means the base-engine fix in this task automatically covers hard mode's multi-task
half; the follow-on task (out of this task's scope) only needs to edit hard mode's single-task
dispatch sites.

Re-counted single-task `subagent_type` occurrences in `skill-orchestrate-hard/SKILL.md`: 7, at
re-measured lines 600, 635, 694, 724, 901, 1120, 1497 — matching the original "7 single-task
dispatch sites" claim exactly, just at new line numbers after the file's growth.

### Precise edit anchors in `commands/orchestrate.md`

- `argument-hint` (line 6): currently `TASK_NUMBERS [PROMPT]`, no flag list at all (unlike
  `research.md`'s argument-hint, which lists every flag including
  `[--haiku|--sonnet|--opus|--fable]`).
- `## Options` table (lines 31-43): 9 existing rows (`--lit`, `--dry-run`,
  `--allow-self-modifying`, `--allow-scope-collision`, `--continue-budget`, `--clean`, `--fast`,
  `--team`, `--team-size`), no model-flag rows.
- STAGE 0 (lines 54-80): sources `parse-command-args.sh` at line 56; its "Exports:" comment
  (lines 57-58) lists `TASK_NUMBERS`, `FOCUS_PROMPT`, `REMAINING_ARGS`, `DRY_RUN_FLAG`,
  `ALLOW_SELF_MODIFYING_FLAG`, `ALLOW_SCOPE_COLLISION_FLAG`, `CONTINUE_BUDGET_FLAG`,
  `CLEAN_FLAG`, `EFFORT_FLAG`, `TEAM_MODE`, `TEAM_SIZE`, `TEAM_SIZE_EXPLICIT` — no `MODEL_FLAG`.
  The prose paragraph at lines 78-80 explains `CLEAN_FLAG`/`EFFORT_FLAG` threading in the same
  style a `MODEL_FLAG` sentence should follow.
- Multi-task `args:` Skill string, line 448: threads `lit_flag`, `allow_self_modifying`,
  `allow_scope_collision`, `continue_budget`, `clean_flag`, `effort_flag`, `team_mode`,
  `team_size`, `team_size_explicit` — no `model_flag`.
- Multi-task JSON delegation-context object: `"clean_flag"` at line 464, `"effort_flag"` at line
  465, `"team_mode"` at line 466 — insertion point is between 465 and 466.
- Single-task `args:` Skill string, line 653: threads `lit_flag`, `continue_budget`,
  `clean_flag`, `effort_flag`, `team_mode`, `team_size`, `team_size_explicit` — no `model_flag`.
- Single-task JSON delegation-context object: `"clean_flag"` at line 672, `"effort_flag"` at line
  673, `"team_mode"` at line 674 — insertion point is between 673 and 674.

### Precise edit anchors in `skills/skill-orchestrate/SKILL.md`

- Stage 1 (`### Stage 1: Input Validation`, starts line 39): flag-read bullets for `clean_flag`
  and `effort_flag` (each ending "Consumed by Stage 3.5 Dispatch Prep's ... below") sit in the
  ~76-90 line range — a `model_flag` bullet belongs alongside them, default `""` (matching
  `MODEL_FLAG`'s actual bash default — note this is an empty string, not a JSON `null`, unlike
  the framing in `research.md`'s prose).
- Stage MT-1 (`### Stage MT-1: Parse Multi-Task Context`, starts line 2524): matching
  `clean_flag`/`effort_flag` bullets sit at ~2538-2545 — same addition needed.
- Stage 3.5 Dispatch Prep (line 597): add `model_flag` to the Inputs table; add a "Model-override
  resolution" subsection (mirroring the existing Effort-depth note's shape) that resolves
  `model_flag` to a `model` output (haiku/sonnet/opus/fable pass through unchanged; empty stays
  empty); update the "Outputs and injection contract" paragraph with a distinct sentence stating
  that `model`, when non-empty, is passed as the Agent tool's `model` parameter at each call
  site — never appended to the prompt string, never added to the `context` JSON object.
- Every Stage 4 dispatch-site table (9 sites) and the Stage MT-4 three per-task loops (research
  ~3390, planner ~3402, implement ~3419): each needs "pass `model` (if non-empty) as the Agent
  tool's `model` parameter" added alongside its existing `subagent_type` line/row.
- Stage 3.6 Team Fan-Out spawn loop's "Invoke the Agent tool" step (its `subagent_type`/`prompt`/
  `context` bullet list): same one-line addition, since this stage already calls Stage 3.5 once
  per teammate.

## Decisions

- **(a) Model override is LIFECYCLE-ONLY** (research/plan/implement dispatches via Stage 3.5),
  not uniform across every dispatch. Auxiliary/diagnostic dispatches (Stage 5a drift inspection,
  Stage 5b churn/divergence audit, Stage 6 blocker escalation's fork/reviser/re-dispatch) retain
  their frontmatter-default models, as an emergent consequence of never calling Stage 3.5 today —
  no new exemption logic is required to achieve this.
- **(b) `model_flag` is resolved once at Stage 1 / Stage MT-1** and threaded unchanged into every
  Stage 3.5 call for the whole invocation (single-task or multi-task batch) — never re-resolved
  or stored per-task in `mt_state_file`.
- **(c) Hard mode's multi-task half is covered for free** by base-engine delegation (confirmed,
  not merely assumed) — the follow-on task's scope is correctly limited to hard mode's 7
  single-task dispatch sites.
- The implementer should add 4 insertion points to `commands/orchestrate.md` (not 2), because
  that file — unlike `research.md` — threads flags through both a flat `args:` string and a
  separate JSON delegation-context object at each of its two dispatch sites.

## Recommendations

1. Implement the 8 numbered edits to `commands/orchestrate.md` listed under "Precise edit anchors
   in `commands/orchestrate.md`" above (argument-hint, Options table, exports comment, prose
   paragraph, and the 4 args-string/JSON insertion points across the two dispatch sites).
2. Implement the edits to `skills/skill-orchestrate/SKILL.md` listed under "Precise edit anchors
   in `skills/skill-orchestrate/SKILL.md`" above: Stage 1 and Stage MT-1 flag-read bullets, Stage
   3.5's new input/output/injection-contract text, and a one-line addition at each of the 9 Stage
   4 sites, the 3 Stage MT-4 per-task loops, and the Stage 3.6 team fan-out spawn loop.
3. Explicitly document decision (a) in `orchestrate.md`'s Options table so a future reader does
   not need to re-derive the lifecycle-only scoping from the absence of Stage 3.5 calls in the
   auxiliary sites.
4. Verification bar (unchanged from the task description, confirmed as the right bar): the
   no-flag regression check is the most important one — with `MODEL_FLAG=""` (today's default),
   all 4 orchestrate.md insertion points interpolate to an empty string, Stage 1/MT-1 treats
   empty as "not set," Stage 3.5 leaves `model` empty, and no dispatch site emits a `model`
   parameter, producing byte-identical behavior to today. Then verify `/orchestrate N --fable`
   (and the other three flags) on a single task, then `/orchestrate N,M --fable` for MT-4
   threading.

## Risks & Mitigations

- **Risk**: an implementer copies research.md's single-args-string pattern verbatim and misses
  the JSON delegation-context object that orchestrate.md also carries at each dispatch site,
  silently leaving `model_flag` unreachable from the `context` half of the payload.
  **Mitigation**: this report enumerates all 4 insertion points explicitly (2 `args:` strings + 2
  JSON objects), not just 2.
- **Risk**: treating `model_flag`'s default as JSON `null` (per research.md's prose framing)
  instead of the empty string `MODEL_FLAG` actually defaults to in `parse-command-args.sh`,
  causing a string-equality check for `"null"` that never matches an empty string.
  **Mitigation**: this report flags the `""` vs `null` distinction explicitly at both the
  orchestrate.md and SKILL.md edit points.
- **Risk**: a future line-number-anchored edit against this report goes stale the same way the
  original task description did, since sibling tasks are editing
  `skill-orchestrate/SKILL.md` concurrently in this same batch. **Mitigation**: this report
  anchors every finding by heading/surrounding-text description in addition to a line number, so
  the implementer can re-locate anchors even if line numbers have shifted again by
  implementation time.

## Appendix

- Re-measured file sizes: `skill-orchestrate/SKILL.md` 268,147 bytes;
  `skill-orchestrate-hard/SKILL.md` 113,312 bytes; `commands/orchestrate.md` 43,407 bytes;
  `commands/research.md` 28,649 bytes; `skill-researcher/SKILL.md` 15,956 bytes.
- Search commands used: `grep -n "model_flag\|MODEL_FLAG\|--haiku\|--sonnet\|--opus\|--fable"`
  across the command/skill files above; `grep -n "subagent_type"` and `grep -n "Dispatch Prep"`
  across `skill-orchestrate/SKILL.md`; `grep -n "MT-1 through MT-5\|multi-task stages are the
  base"` across `skill-orchestrate-hard/SKILL.md`.
- `specs/state.json` task 114 entry confirms `file_scope` is exactly
  `["agent-system/extensions/core/commands/orchestrate.md",
  "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md"]`, matching this report's
  scope.

# Research Report: Task #116

**Task**: 116 - Design the orchestrate-centric core consolidation and rebuild the backlog around it
**Started**: 2026-08-31
**Completed**: 2026-08-31
**Effort**: large (research only; Phase A/B/C design and backlog operations are later phases)
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/core/commands/{orchestrate,research,plan,implement,revise}.md` (source store, read in full)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (2,814 lines), `skill-orchestrate-hard/SKILL.md` (1,784 lines)
- `agent-system/extensions/core/skills/skill-{researcher,planner,implementer}{,-hard}/SKILL.md`
- `agent-system/extensions/core/skills/skill-team-{research,plan,implement}/SKILL.md`, `agents/synthesis-agent.md`
- `agent-system/extensions/core/agents/{general-research,planner,general-implementation}{,-hard}-agent.md`
- `agent-system/extensions/core/scripts/parse-command-args.sh`, `scripts/lib/manifest-routing-lib.sh`
- `agent-system/extensions/core/context/guides/hard-mode-routing.md`
- `agent-system/extensions/*/manifest.json` (19 extensions)
- `specs/state.json`, `specs/TODO.md`, `specs/events.jsonl`
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `/orchestrate` today is **not** a superset of `/research`+`/plan`+`/implement`+`/revise`. It is
  missing, at the command-file level: `--team`, `--hard`/`--fast`, all four model flags
  (`--haiku`/`--sonnet`/`--opus`/`--fable`), `--clean`, `--force`, `--roadmap`, and any user-driven
  phase-forcing or plan-revision-with-reason mechanism. `parse-command-args.sh` (the shared
  parser `orchestrate.md` sources) already computes all of these into shell variables, but
  `orchestrate.md`'s own Stage 2 delegation JSON never forwards them — this is a threading gap,
  not a parsing gap.
- Two currently silent, functionally-dead flags: `skill-orchestrate/SKILL.md` dispatches every
  phase via the **Agent tool directly** (`subagent_type: $RESEARCH_AGENT`, etc.), bypassing
  `skill-researcher`/`skill-planner`/`skill-implementer` entirely. Those three skills are the
  *only* place `memory-retrieve.sh`/`clean_flag` (Stage 4a) and the interactive `--lit`
  resolution machinery (`lit-stage4a-flow.md`'s `AskUserQuestion` branches) live — the dispatched
  agent files (`general-research-agent.md` etc.) contain **zero** references to either mechanism.
  Consequence: **every task ever run through `/orchestrate` today gets no memory-augmented
  context at all**, and **`--lit` on `/orchestrate` is threaded end-to-end as a boolean but never
  resolved into an actual literature briefing** — it silently no-ops rather than erroring.
- `/orchestrate --hard` is **unreachable**. `skill-orchestrate-hard/SKILL.md` exists (1,784
  lines), is exercised by 10+ test/lint scripts, but no command file anywhere invokes it — grepping
  every command and script for the string turns up only cross-references, never a dispatch site.
- Hard-mode skill/agent pairs are structurally near-identical to their base counterparts (same
  numbered Stage sequence; the hard variant typically adds 1-3 extra stages and is comparable in
  size, sometimes *smaller*), which is strong evidence A4's contract-injection collapse is cheap.
  Only 3 of 19 extension manifests (`core`, `cslib`, `lean`) declare `routing_hard`/
  `routing_agents_hard` today.
- Team mode has essentially no production usage: one historical session (task 36,
  2026-08-11) used `skill-team-research`; `skill-team-plan` and `skill-team-implement` have zero
  hits in `specs/events.jsonl`.
- `next_artifact_number` is incremented **only** by research's postflight
  (`orchestrator-postflight.sh:348-361`, comment says "research only"); plan/implement read it
  back via a `"prev"` mode (`skill-base.sh:295-296`, `next_artifact_number - 1`) and never
  increment it themselves. This means the MM_ numbering convention *already* supports append-only
  research re-runs, but a forced re-plan/re-implement under A2 would land on the *same* artifact
  number as the existing one unless new incrementing logic is added.
- The AUDIT SCOPE's six named sub-topics (`agent-system`, `essential-refactor`,
  `orchestration-concurrency`, `team-mode-lifecycle`, `status-marker-lifecycle`, `extensions`) do
  **not** exist as literal `state.json` `.topic` values today — every core task carries
  `topic: "core-agent-system"` (30 tasks) except the 3 latex tasks (`topic: "extensions"`). 30 +
  3 − 1 (task 116 excludes itself) = 32, which exactly matches the stated audit-scope count. The
  six names are an informal thematic clustering, not a queryable field; Phase B verdicts must be
  produced by reading each task's title/description/`file_scope`, which this report does (see
  Finding 7 evidence table).

## Context & Scope

This is Phase A research input only, per the binding delegation instructions: no file under
`agent-system/extensions/**` or `.claude/**` was modified; no task was revised, abandoned, or
created. The seven numbered findings below map onto the task description's numbered research
questions 1-7 (entry-point collapse, phase-forcing flags, hard-mode duplication, team-mode fold,
extension blast radius, preserved assets, backlog audit inputs).

---

## Finding 1 — Entry-point collapse (A1/A2): what `/orchestrate` does NOT already do

All five command files were read in full (`orchestrate.md` 750 lines, `research.md` 652,
`plan.md` 677, `implement.md` 506, `revise.md` 157). Comparing line-by-line:

### Capabilities present in the older commands, absent from `orchestrate.md`'s own logic

| Capability | Where it lives today | In `orchestrate.md`? |
|---|---|---|
| `--team` / `--team-size` | `research.md`, `plan.md`, `implement.md` Options tables; routes to `skill-team-*` | **No.** `orchestrate.md` Constraints line 24: "`--team` flag not supported." |
| `--fast` / `--hard` | All three; threaded as `effort_flag`/`EFFORT_FLAG` into `command-route-skill.sh` | **No.** Not in Options table; Stage 0 comment does not list `EFFORT_FLAG` among exports used. `skill-orchestrate/SKILL.md` has **zero** occurrences of `effort_flag` anywhere in 2,814 lines (confirmed by grep). |
| `--haiku`/`--sonnet`/`--opus`/`--fable` | All three; passed as `model` param to the Skill/Agent call | **No.** Not in Options table; `skill-orchestrate/SKILL.md` has zero occurrences of `model_flag`. This is precisely the subject of the currently-open tasks #114/#115. |
| `--clean` | All three; gates Stage 4a memory retrieval | **No.** Zero occurrences of `clean_flag` in `skill-orchestrate/SKILL.md`. |
| `--force` (override completed-task status) | `implement.md` only | **No** direct equivalent; `orchestrate.md`'s GATE IN is "permissive" and only blocks on `completed`/`abandoned`/`expanded`, so a completed task is already blocked with no override. |
| `--roadmap` (inject ROADMAP.md review phases into the plan) | `plan.md` only | **No.** |
| User-invoked plan revision with a reason, or the "no-plan -> description update" fallback | `revise.md` (`skill-reviser`/`reviser-agent`) | **Partially.** `skill-orchestrate/SKILL.md` invokes `reviser-agent` internally, but only automatically, for blocker-triggered or drift-triggered (`drift_pct > DRIFT_REVISION_THRESHOLD`) revision (lines 1085-1158) — always `revision_reason: "drift"` or a blocker context, never a user-supplied free-text reason, and never the description-update path (`revise.md` lines 37-38, 124-132). |
| Batch mode: independent per-task skill dispatch, per-task lock, second-pass re-sequencing | `research.md`/`plan.md`/`implement.md` MULTI-TASK DISPATCH (Steps 1-5, ~250 lines each) | **Different design, not absent.** `orchestrate.md`'s multi-task path (lines 100-596) builds the same wave/Kahn's-algorithm schedule but hands the **entire** schedule to a **single** `skill-orchestrate` call (`multi_task_mode=true`), which then loops waves internally at its own Stage MT-3. This is architecturally distinct (one skill invocation managing N tasks vs. N parallel skill invocations) but functionally covers the same batch-admission gates (`orchestrate-batch-admit.sh`, self-modification/scope-collision/session-contention defer reasons) — this one is NOT a gap, it is a genuine redesign already in place. |
| Dry-run report-only mode | none of the four | `orchestrate.md` has `--dry-run`, which the other four lack. Net addition, not a gap. |

### Capabilities computed but silently dropped by the shared parser

`parse-command-args.sh` (shared by `implement.md` and, per its own header, intended for reuse)
already parses `TEAM_MODE`, `TEAM_SIZE`, `EFFORT_FLAG`, `MODEL_FLAG`, `CLEAN_FLAG`, `FORCE_FLAG`
into exported shell variables (`scripts/parse-command-args.sh:14-179`). `orchestrate.md`'s own
Stage 0 sources this same script but its comment (`orchestrate.md:50-52`) only lists
`TASK_NUMBERS`, `FOCUS_PROMPT`, `REMAINING_ARGS`, `DRY_RUN_FLAG`,
`ALLOW_SELF_MODIFYING_FLAG`/`ALLOW_SCOPE_COLLISION_FLAG`/`CONTINUE_BUDGET_FLAG` as consumed —
and its Stage 2 delegation JSON (`orchestrate.md:629-646`) carries only `session_id`,
`delegation_depth`, `delegation_path`, `task_context`, `orchestrator_mode`, `focus_prompt`,
`lit_flag`, `continue_budget`. The other five variables are computed and then dropped on the
floor. **This is the exact shape of the wiring gap tasks #114/#115 already target** — confirmed,
not re-derived.

### Implication for A1

A1's "thin alias" option is viable *only* once the flag-threading gap above is closed and A2's
phase-forcing design lands — otherwise deleting `research.md`/`plan.md`/`implement.md` outright
would strand `--team`, `--hard`, model flags, `--clean`, `--force`, and `--roadmap` with no
reachable equivalent. `revise.md`'s two behaviors (reasoned revision, description-only update)
have no `/orchestrate` equivalent at all today and need an explicit design decision in "whatever
replaces `/revise`."

---

## Finding 2 — Phase-forcing flags (A2): what it would take

`skill-orchestrate/SKILL.md` Stage 4 (`SKILL.md:325-703`) is a pure **status-driven** state
machine: handlers exist for `not_started`, `researching`, `researched`, `planning`,
`planned`/`implementing`, `partial`, `blocked`, `completed`, `abandoned`/`expanded`, unknown.
There is no flag-driven override anywhere in Stage 4 — confirmed by grep, zero occurrences of
`--research`/`--plan`/`--implement` as flags, and zero conditional branching on any such flag
name. **Today there is no way to force `/orchestrate N --research` to re-run research on a task
already at `[RESEARCHED]` or beyond** — the state machine would route straight to the `researched`
handler (dispatch plan) or further, never back to research.

Sub-answers to the task's four bullets:

**(a) Where would the flag have to be consumed?** Two points, both currently absent: (1)
`orchestrate.md`'s own arg-parsing (needs new `--research`/`--plan`/`--implement` flags parsed
alongside the existing ones, likely via `parse-command-args.sh` or a new dedicated parse step),
and (2) `skill-orchestrate/SKILL.md`'s Stage 3/Stage 4 dispatch logic, which would need a
pre-Stage-4 override: "if a forcing flag names a phase at or before the task's current phase,
override the state-derived handler selection with the named phase's handler."

**(b) MM_ numbering: append or overwrite?** Confirmed asymmetric today:
- **Research**: `orchestrator-postflight.sh:348-361` increments `next_artifact_number`
  **only** on the research postflight path (comment: "Increment next_artifact_number
  (research only)"). Each research re-run therefore naturally gets a new number
  (`01_`, `02_`, ...) — append-only already works for research.
- **Plan/Implement**: `skill-base.sh:295-296` documents plan/implement as using
  `next_artifact_number - 1` ("prev" mode) — i.e. they reuse whatever number the *current*
  research round set, and neither increments it themselves. A forced re-plan on an
  already-`[PLANNED]` task would, under the current mechanism, resolve to the **same** MM
  number as the existing plan — either overwriting it in place (matching `revise.md`'s own
  documented behavior: "Plan revision creates a new plan file within the same artifact round... the
  revised plan uses the SAME artifact number") or colliding, depending on how the write is
  done. **A2 needs an explicit decision**: keep `revise.md`'s same-round-overwrite semantics for
  forced re-plan/re-implement (consistent with existing behavior, cheap), or add a new increment
  path (more storage, but matches the task description's stated "safer default"). This is not
  free either way — plan/implement genuinely have no increment mechanism today, unlike research.

**(c) Status regression hazard.** Confirmed real: nothing in the current state machine or
`update-task-status.sh` prevents a forced research pass on a `[PLANNED]` task from writing
`[RESEARCHED]` over it via the normal `skill_preflight_update`/`skill_postflight_update` path (used
identically by all three dispatch handlers) unless A2 adds an explicit status-preservation rule
for the forced-phase case (e.g., "forcing an earlier phase on a task already past it does not
regress `status`, only adds an artifact and a note").

**(d) `next_artifact_number` role.** It is the single shared per-task counter
(`state-management-schema.md:136-145`: "all artifact types share a single sequence number per
task within a round"; "Research advances the sequence"). Any A2 design that wants forced-phase
artifacts to append rather than overwrite must decide whether forcing plan/implement also
advances this counter (a change from current behavior) or continues reusing it (current
behavior, but then two same-numbered artifacts of different rounds are indistinguishable by
number alone — only by mtime/git history).

No `--research --plan` composition semantics exist today to build from (the flags don't exist at
all yet), so A2's "does composing force both, or stop after plan" question is fully open design
space, not something with existing precedent to preserve.

---

## Finding 3 — Hard-mode duplication (A4): measured

**Reachability defect, found first**: `/orchestrate --hard` has **no dispatch site**. Grepping
every command file and script for `skill-orchestrate-hard` turns up only cross-references from
tests (`test-loop-guard-budget-override.sh`, `test-handoff-dispatch-identity.sh`,
`test-handoff-reader-parity.sh`, `test-routing-resolution.sh`, `test-resume-scan-nonconformance.sh`,
`test-session-runtime-files.sh`), lint (`lint-contract-compliance.sh`), and doc pointers
(`hard-mode-routing.md`, `skill-base.sh` comments) — never an actual invocation from a command
file. `context/guides/hard-mode-routing.md` itself asserts "invoked by `/orchestrate --hard`" but
that flag does not exist in `commands/orchestrate.md`'s parsed set (Finding 1). **This means
`skill-orchestrate-hard` is currently dead code from the user's perspective** — fully built,
fully tested, unreachable. A4's collapse therefore deletes something nothing can currently invoke,
which lowers the practical cost of the decision (no live consumer to migrate off of) but raises
the bar on the test/lint suite: 10 test/lint files reference it and will need updating or deletion
regardless of what A4 decides.

**Structural overlap, base skill vs. hard skill** (stage-header comparison, not byte diff — the
files are not textually parallel enough for a meaningful line-diff):

| Skill pair | Base stages | Hard stages (extra vs. base) | Base lines | Hard lines |
|---|---|---|---|---|
| researcher | 1, 2+3, 3a, 4a, 4, 4b, 5, 5b, 6, 6a, 7-9, 10 | **+1.5** (Hard-Mode Cost Note) | 424 | 275 |
| planner | 1, 2+3, 3a, 3b, 4a, 4, 4b, 5, 5b, 6, 6a, 7, 7a, 8, 8a, 9, 10, 11 | **+1.5, +6b** (Skeleton Task Allocation/H8), **+6c** (Placeholder-Token Substitution) | 508 | 462 |
| implementer | 1, 2+3, 3a, 4a, 4, 4b, 5, 5a, 5b, 5c, 6a, 8, 8a, 9, 10, 11 | **+1.5, +3b** (Single-Phase Dispatch/H1) | 725 | 507 |

Every hard skill reuses the base's numbered stage sequence nearly verbatim (same numbers, same
order) and adds 1-3 extra stages for the H-technique-specific content. **All three hard skills are
smaller in raw line count than their base counterparts** despite the added stages — the base
skills carry more inline prose per stage. This is the opposite of what "duplication" usually
implies: the hard variants are not a bloated parallel copy, they are a lean superset structurally,
suggesting the actual duplication cost is concentrated in **prose repeated stage-by-stage**
(Stage 1, 2+3, 4a, 4, 4b, 5, 5b, 6a are near-identical boilerplate across all six files), not in
hard-specific logic. Agent-file sizes tell the same story: `general-research-agent.md` 370 vs.
`general-research-hard-agent.md` 332; `planner-agent.md` 384 vs. `planner-hard-agent.md` 334;
`general-implementation-agent.md` 774 vs. `general-implementation-hard-agent.md` 538 — hard
agents are consistently *smaller*.

`skill-orchestrate-hard/SKILL.md` (1,784 lines) has its own Stage 0, 1, 1b, **1c** (Orchestrator
Discipline Preamble), 2, 3, **3c** (Burnout Circuit-Breaker Gate), 4, **4b** (Churn Detection/H6),
5, 6, 7, 8 — and **contains zero MT-1..MT-5 stage headers**; the string "MT-" appears only 6
times, all as pointer text ("delegates to the SAME base MT stages," confirmed at
`orchestrate.md:509` too), consistent with the task description's own already-established finding
that multi-task mode lives solely in the base skill. Single-task hard-specific content is
concentrated in 5 extra/renamed stages (1c, 3c, 4b, plus 1.5-equivalent cost framing) layered onto
the same Stage 0/1/1b/2/3/4/5/6/7/8 skeleton the base skill uses.

**Where H2-H9 contract text currently lives**: scattered inline, stage-by-stage, inside each
`-hard` SKILL.md and hard agent file — there is no single shared context file that all six hard
consumers `@`-import for contract text today (contrast with `lit-stage4a-flow.md`, which *is* a
single shared block all four lifecycle skills import verbatim — see Finding 6). `manifest-routing-lib.sh`
and `hard-mode-routing.md` govern only **routing** (which skill/agent name to resolve to), not
contract **content** — they answer "which file to dispatch to," never "what text that file
contains." A4's "one edit updates every consumer" goal therefore requires a new mechanism (a
shared contract-text file analogous to `lit-stage4a-flow.md`, or a script that emits the H2-H9
block) — none exists to reuse today; this must be built, not adopted.

**Extension routing_hard footprint (Finding 5, reported here since directly relevant)**: of 19
extension manifests, only **3** declare `routing_hard`/`routing_agents_hard`: `core`, `cslib`,
`lean`. The other 16 (`email`, `epidemiology`, `filetypes`, `formal`, `founder`, `latex`,
`literature`, `memory`, `nix`, `nvim`, `present`, `python`, `slidev`, `typst`, `web`, `z3`) declare
`routing`/`routing_agents` but never the hard variants. Removing the two hard blocks from the
routing model therefore touches at most 3 manifests, not "every extension" — the blast radius is
small. Migration story for an extension that still declares `routing_hard` post-collapse is not
specified anywhere in the current codebase (no deprecation-warning or hard-error path exists for
an unrecognized/retired manifest key) — this is open design space for A4, not a preserved
existing behavior.

---

## Finding 4 — Team-mode fold (A5)

**Structural overlap**: `skill-team-research` (675 lines), `skill-team-plan` (624),
`skill-team-implement` (742), `synthesis-agent.md` (218). Stage-header comparison of
`skill-team-research` shows the same shared skeleton pattern as the hard skills: Stages 1, 2+3,
10 (Update Status), 11 (Write Metadata), 12 (Git Commit), 13 (Cleanup), 14 (Return Summary) are
boilerplate near-identical to the single-agent skills; team-specific content is concentrated in
Stages 4 (Check Team Mode Availability), 4a (Fallback to Single Agent), 4c (Self-Execution
Fallback), 5 (Spawn Research Wave), 6 (Wait for Wave Completion), 7 (Collect Teammate Results), 8
(Synthesize Findings), 9 (Create Unified Report). `synthesis-agent.md` (218 lines) is a single
shared consumer across all three team skills' final synthesis step — one genuinely
phase-agnostic component already.

**Teammate contract layer** (per the task description's own framing, confirmed present): per-teammate
finding files (Stage 7, "Collect Teammate Results"), the graceful `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`
degradation gate (`skill-team-research/SKILL.md:114`, `!= "1"` check with fallback to
`skill-researcher`), and territory/return-meta correlation — this is exactly what the two
currently-open backlog tasks #72 (teammate return-meta write conflict) and #73 (SubagentStop
postflight correlated to owning session) target; both explicitly touch all three team skills'
`SKILL.md` files plus `hooks/subagent-postflight.sh` and `context/patterns/postflight-control.md`
(#73) / `context/templates/agent-template.md` and `context/patterns/skill-postflight-flow.md`
(#72). Both are real, currently-undispatched defects in exactly the layer A5 proposes to fold —
confirming the task description's own pre-established finding that these two survive as
RESCOPE-or-MOOT depending on how the fold lands, never as a clean drop.

**Usage evidence**: `grep -c team specs/events.jsonl` returns exactly 3 hits, all
`subagent_stop` events for `skill-team-research (research)` on task 36
(session `sess_1786461982_2337d4`, 2026-08-11) — one historical invocation, not "no evidence,"
but a single isolated use. `skill-team-plan` and `skill-team-implement` return **zero** hits in
`events.jsonl` — no evidence either was ever actually dispatched. This is thin enough usage that
A5's "fold into a flag on the one engine" carries low regression risk from an actual-user-impact
standpoint, though the code paths themselves are real and non-trivial (675+624+742+218 = 2,259
lines across the three skills + synthesis agent).

**Not independently confirmed** (would require re-deriving A5's own already-decided contract): the
exact mechanism by which the folded engine would express "spawn N teammates, wait, synthesize" as
an internal branch rather than three separate skill dispatches — this is squarely implementation
design for the successor task, not a research-verifiable fact about the current system, and A5
itself says "implement, do not re-litigate" on the fold decision.

---

## Finding 5 — Extension blast radius

Covered fully in Finding 3's last paragraph: 3 of 19 manifests (`core`, `cslib`, `lean`) declare
`routing_hard`/`routing_agents_hard`. All 19 except `literature` and `slidev` declare the
non-hard `routing`/`routing_agents` blocks (those two set `routing_exempt: true` for independent
reasons per `hard-mode-routing.md`'s "Extension Overrides Core" section, unrelated to A4).
No manifest declares `routing_hard` without also declaring `routing_agents_hard` or vice versa in
this codebase (`core`, `cslib`, `lean` each declare both) — the two blocks travel together in
practice, though nothing in the routing lib enforces that pairing structurally.

---

## Finding 6 — Preserved assets (A6): file + line, and orchestrate-path vs. older-command-path

| Mechanism | File : line | Lives in `/orchestrate` path? | Lives in older-command path? |
|---|---|---|---|
| GATE IN / GATE OUT checkpoints | `scripts/command-gate-in.sh`, `scripts/command-gate-out.sh` | **Yes** — `orchestrate.md:602`, `:653` | Yes — all four (`research.md:407`, `plan.md:404`, `implement.md:359`, `revise.md:24/74`) |
| Scoped git commits per phase | `scripts/git-commit-scoped.sh` | Yes — `orchestrate.md:692` (per-cycle CHECKPOINT 3); also per-task inside `skill-orchestrate` Stage MT-4 step 5.5 for multi-task | Yes — each command's own CHECKPOINT 3 |
| Artifact format validators | `scripts/validate-artifact.sh`, invoked via `command-gate-out.sh` | Yes (via the shared gate-out call) | Yes (via the shared gate-out call) |
| Task-lock / session-registry concurrency | `scripts/task-lock.sh` | Yes — single-task via `command-gate-in.sh`; multi-task via `skill-orchestrate` Stage MT-1 (`session-register`)/MT-3 (`acquire-retry`) | Yes — each command's own multi-task Steps 2-3 |
| Batch admission gates (self-mod, scope-collision, cycle budget) | `scripts/orchestrate-batch-admit.sh` | Yes — `skill-orchestrate` Stage MT-3 step 4.5 (the sole EXECUTING gate per `orchestrate.md:240-241`) | Yes — each command's own Step 2.5 |
| `--lit` briefing injection (interactive resolution, not just flag passthrough) | `context/patterns/lit-stage4a-flow.md`, consumed by `skill-researcher/SKILL.md` Stage 4a, `skill-planner`, `skill-implementer` (+ `-hard` variants) | **NO — confirmed absent.** `skill-orchestrate/SKILL.md` only ever forwards the raw `lit_flag` boolean into the Agent tool's `context` dict (9 occurrences, all pass-through, e.g. lines 348, 392, 431, 474, 511, 583, 645, 2096, 2103, 2115). The dispatched agent files (`general-research-agent.md`, `planner-agent.md`, `general-implementation-agent.md`) contain **zero** references to `lit_flag`, `literature`, or `lit-stage4a-flow` — confirmed by grep. The resolution logic (directive branching, `AskUserQuestion`, `literature-lit-flag-resolve.sh`) exists **only** in the skill layer `/orchestrate` never calls. | Yes — the sole location. |
| Memory retrieval + `--clean` suppression | `scripts/memory-retrieve.sh`, consumed by `skill-researcher/SKILL.md` Stage 4a (and planner/implementer + `-hard`) | **NO — confirmed absent.** Zero occurrences of `clean_flag` or `memory-retrieve` in `skill-orchestrate/SKILL.md`'s 2,814 lines. Same root cause as `--lit`: `skill-orchestrate` dispatches the Agent tool directly, never the wrapping skill where Stage 4a lives. | Yes — the sole location. |
| Model flags (`--haiku`/`--sonnet`/`--opus`/`--fable`) | `scripts/parse-command-args.sh:108-118`; consumed by each command's Stage 2 `model` param | **NO — confirmed absent** (Finding 1). This is the exact subject of open tasks #114/#115. | Yes. |
| `--fast` | Same parser | **NO** (Finding 1) | Yes |
| The return-metadata handoff contract + recovery path | `.orchestrator-handoff.json` schema (`docs/architecture/handoff-schema.md`), `.return-meta.json`, read by `skill-orchestrate` Stage 5 and `orchestrate-recover-outcome.sh` | **Yes — this one is `/orchestrate`-native**, not older-command. `research.md`/`plan.md`/`implement.md` read `.return-meta.json` for status/artifacts only; the full handoff-with-`continuation_context` recovery contract is a `skill-orchestrate`-specific mechanism (Stage 5, `orchestrate.md:637-651` "recovers its outcome via `orchestrate-stage5-gates.sh`"). | Partial — `.return-meta.json` alone, not the richer handoff |

**Net reading for A6**: the two most consequential omissions are `--lit` interactive resolution
and memory retrieval — both currently exist **only** inside the skill layer that `/orchestrate`
bypasses. If A1 deletes `research.md`/`plan.md`/`implement.md` (and by extension makes
`skill-researcher`/`skill-planner`/`skill-implementer` unreachable, since nothing else invokes
them), these two mechanisms disappear from the system entirely unless explicitly rebuilt into
`skill-orchestrate`'s own dispatch-prep stage (mirroring Stage 4a from the base skills). This is
the single highest-value, most concrete design requirement this research surfaced — not a
hypothetical risk, a currently-live functional gap independent of any deletion.

---

## Finding 7 — Backlog audit inputs (Phase B evidence table)

**Topic-taxonomy note** (see Executive Summary): AUDIT SCOPE's six named categories are not live
`state.json` fields. `state.json` currently has `topic: "core-agent-system"` (30 tasks, including
task 116 itself), `topic: "extensions"` (3 tasks — the latex build-guard trio), `topic: "literature"`
(14 tasks, one short of the description's stated "15" — worth a one-line note to the description
author, not resolved here since literature is out of audit scope), and one `topic: null` task
(#100, `close_aggregator_file_scope_blind_spot`, not in the audit-scope count). 30 − 1 (task 116)
+ 3 = 32, matching the audit-scope count exactly. The table below assigns each task to the most
fitting informal category from the description's own list, by reading title + `file_scope`; this
is evidence for Phase B, not a Phase B verdict (no ON-PATH/RESCOPE/ABSORB/MOOT calls are made
here per the binding scope — only file survival vs. the Phase A decision it depends on).

| # | Title | Status | file_scope (key paths) | Informal category | A-item this depends on | Note |
|---|---|---|---|---|---|---|
| 13 | Instrument gate-out auto-repair reporting | not_started | `command-gate-out.sh`, `skill-base.sh` | orchestration-concurrency | A6 (GATE OUT survives) | Files survive unconditionally; touches a shared script both paths use |
| 14 | Prevent implementation-agent fan-out non-terminal status | not_started | `general-implementation-agent.md`, `skill-orchestrate/SKILL.md`, `lean-implementation{,-hard}-agent.md` | agent-system | A4 (lean hard agent), A1 | Base files survive; the lean `-hard` agent touched is an *extension*-owned hard agent, out of core-collapse scope per description |
| 20 | Metrics sync phantom paths | not_started | `assess-repo-health.sh`, `commands/todo.md` | agent-system | none (orthogonal) | Unaffected by A1-A5 |
| 22 | Silence opencode fragment validation spam | researching | `lua/.../merge.lua`, lean `opencode-agents.json` | agent-system | none (orthogonal) | Unaffected |
| 27 | Remove dead .opencode command router | not_started | `.opencode/scripts/*` | agent-system | none (orthogonal) | Unaffected |
| 29 | Generate mcp.json from extension manifests | not_started | `lua/.../merge.lua`, `manifest_spec.lua`, `extension-development.md` | extensions/agent-system | A3 (manifest schema) | `extension-development.md` documents the 4-block manifest model A3 may change |
| 30 | Register obsidian memory MCP server | not_started | memory ext `settings-fragment.json`, `manifest.json` | extensions | none | Unaffected by core collapse |
| 31 | Opencode extensions sync mechanism | researching | `.opencode/extensions/`, `scripts/lint/` | agent-system | none (orthogonal) | Unaffected |
| 42 | verify-deploy gates: broken-@-ref lint + context-budget gate | not_started | `verify-deploy.sh`, `scripts/lint/` | status-marker-lifecycle/agent-system | possible overlap with A2/#87 | Context-budget gate may double-count with mode-gated-section-loading (#87-90) |
| 43 | Email safety context loading decision | not_started | `email/EXTENSION.md`, `email/agents/`, `email/skills/` | extensions | none | **Topic anomaly**: `file_scope` is 100% email-extension files, yet `topic: core-agent-system` — flag for the Phase B author, not resolved here |
| 44 | Slim commands/task.md | planned | `commands/task.md`, `context/` | agent-system | A2/A3 indirectly | `task.md` is task-*creation*, not a lifecycle command — outside A1's collapse target, but its context-loading may shift if routing ladder (A3) changes |
| 45 | Global update extension repo registry | not_started | *(empty)* | agent-system | unknown | **Could not determine** — `file_scope` empty in state.json; recommend backfilling before Phase C |
| 46 | Fix present extension compound skill routing | not_started | *(empty)* | agent-system/extensions | A3 (routing ladder) | **Could not determine precisely** — empty `file_scope`, but title implies `command-route-skill.sh`/manifest compound-key resolution, directly touched by A3 |
| 48 | Propagate scoped commit to all call sites | not_started | `agent-system/extensions/` (whole tree) | orchestration-concurrency | A1 (command deletions) | **Explicitly named in the task description** as sequence-sensitive; call-site count shrinks if A1's command deletions land first |
| 50 | Restore verification trust / close hygiene residue | not_started | `verify-deploy.sh`, `lib/common.sh`, `literature-retrieve.sh`, core `manifest.json`, `claudemd.md`, `jq-escaping-workarounds.md`, `ROADMAP.md` | agent-system | minor A3 (manifest.json) | Broad hygiene task, mostly orthogonal; touches the core manifest A3/A4 also touch |
| 51 | Move session state files out of specs root | not_started | *(empty; concerns `.orchestrator-*.json` runtime files)* | status-marker-lifecycle | A6 (runtime files preserved) | File-location refactor, structurally independent of A1-A5 |
| 53 | Suppress expected handoff absence defect | not_started | `skill-orchestrate/SKILL.md`, `skill-orchestrate-hard/SKILL.md`, `handoff-schema.md`, `orchestrator-runtime-files.md`, `system-defect-record.sh` | status-marker-lifecycle | **A4 directly** | Touches `skill-orchestrate-hard` — same RESCOPE-pending-A4 shape as #114/#115; base-skill portion is real and independent |
| 64 | Decide/implement how --hard contracts reach agents system-wide | not_started | `manifest-routing-lib.sh`, `lint-routing-wiring.sh` | essential-refactor | **A4 (explicitly subsumed)** | Task description already states this is ABSORBed into A4's successor task — recorded here, not re-derived |
| 68 | Orchestrate blocked-verdict discrimination | not_started | `orchestrate-triage-classify.sh`, `orchestrate-dry-run-report.sh`, `orchestrate-batch-admit.sh`, `orchestrator-postflight.sh`, `reconcile-task-status.sh`, `skill-orchestrate{,-hard}/SKILL.md`, `skill-spawn/SKILL.md`, `batch-orchestration-guardrails.md`, `orchestrate-state-machine.md` | orchestration-concurrency | A4 (hard half), central engine | **BLOCKING candidate**: a real correctness defect in the exact engine A1 makes the sole entry point; the base-engine portion should land independent of/before the collapse so the defect isn't entrenched |
| 72 | Fix teammate return-meta write conflict | not_started | `agents/*.md`, `skill-team-{research,plan,implement}/SKILL.md`, `agent-template.md`, `skill-postflight-flow.md`, `orchestrator-runtime-files.md` | team-mode-lifecycle | **A5 (explicitly established)** | Already flagged RESCOPE-or-MOOT in the task description; recorded, not re-derived |
| 73 | Correlate subagent postflight hook to owning session | not_started | `hooks/subagent-postflight.sh`, `skill-base.sh`, `settings.json`, `postflight-control.md`, three team skills | team-mode-lifecycle | **A5 (explicitly established)** | Same as #72 |
| 81 | Mechanize task-lock/session-registry heartbeat refresh | not_started | `general-implementation{,-hard}-agent.md`, `task-lock.sh`, `update-phase-status.sh`, `skill-implementer/SKILL.md`, `skill-orchestrate{,-hard}/SKILL.md`, `commands/implement.md`, `task-lock.md` | orchestration-concurrency | A1 (implement.md fate) + A4 (hard half) | **BLOCKING candidate**: liveness/heartbeat correctness is a named A6 preserved asset; a stale heartbeat defect surviving into the collapsed single entry point is exactly the "entrenched defect" scenario A2's BLOCKING criterion describes |
| 87 | Mode-gated section loading convention | not_started | `context/patterns/`, `scripts/lint/`, `measure-eager-context.sh` | agent-system | **ON-PATH (explicit)** | Foundational convention task; should land early since #88-91-style applications depend on it |
| 88 | Mode-gate skill-orchestrate multi-task section | not_started | `skill-orchestrate/SKILL.md`, `context/patterns/` | agent-system | **ON-PATH (explicit)** | Flagged for double-count risk against the collapse's own MT-section reduction — do not count savings twice |
| 89 | Mode-gate literature and distill skills | not_started | `literature/skills/skill-literature/SKILL.md`, `memory/skills/skill-distill/SKILL.md` | extensions (applied) | ON-PATH | Touches only extension-owned files; arguably belongs under `extensions` topic rather than `core-agent-system`, same hygiene note as #43 |
| 90 | Adoption lint for shared task-lookup helper | not_started | `scripts/lint/`, `skill-base.sh` | agent-system | A1 (call-site count) | **Explicitly named** as sequence-sensitive alongside #48 |
| 91 | update-plan-status.sh non-conforming Status lines | not_started | `update-plan-status.sh`, `update-task-status.sh`, `plan-format.md` | status-marker-lifecycle | none (orthogonal) | Unaffected by A1-A5 |
| 114 | Wire model-flag threading through /orchestrate | not_started | `commands/orchestrate.md`, `skill-orchestrate/SKILL.md` | essential-refactor | **ON-PATH (pre-established)** | Confirmed by Finding 1 as a real, currently-open gap |
| 115 | Mirror model-flag into skill-orchestrate-hard | not_started | `skill-orchestrate-hard/SKILL.md`, `claudemd.md` | essential-refactor | **ON-PATH, partly MOOT under A4 (pre-established)** | Confirmed: if A4 deletes `skill-orchestrate-hard`, this mirror work is wasted; sequence A4 first |
| 74 | Shared LaTeX build-conflict guard script | not_started | `latex-build-guard.sh`, core `manifest.json` | extensions (latex internals) | none | Per task description's expected verdict: return to `extensions` topic untouched |
| 75 | Wire build guard into latex extension | not_started | `latex/manifest.json`, `latex/scripts/`, `latex/agents/*.md`, `latex/rules/latex.md` | extensions (latex internals) | none | Same as #74 |
| 76 | Close task-type-keyed hook gap for non-latex .tex compilers | not_started | `general-implementation{,-hard}-agent.md`, `skill-base.sh` | extensions (latex internals, touches core) | minor A4 (hard agent) | Touches the core hard agent file; otherwise latex-scoped per description's expected verdict |

**Data gaps found, not filled** (per instructions, stated rather than guessed): tasks #45 and #46
have empty `file_scope` arrays in `state.json` — their file-level impact could not be determined
from state.json alone and would need either their own research pass or a manual `file_scope`
backfill before Phase C sizing. Task #51 similarly has an empty `file_scope`; its title and
content make its target reasonably inferable (`.orchestrator-*` runtime files under `specs/`) but
this is inference, not a confirmed file list.

**Sequencing tensions surfaced beyond the two explicitly named ones (#48/#90 vs. A1, #114/#115 vs.
A4)**: #68 and #81 are argued above as BLOCKING candidates not previously called out in the task
description — both are live correctness defects in the exact machinery (`skill-orchestrate`'s
blocked-verdict routing; `general-implementation-agent`'s multi-phase heartbeat) that A1 elevates
to sole-entry-point status. #53 is a softer BLOCKING candidate: it concerns the reliability of the
handoff-absence defect signal, i.e. whether the collapse's own success/failure telemetry can be
trusted during rollout.

---

## Decisions

None — this is a research report; Phase A/B/C decisions are the successor planning/implementation
phases' responsibility per the task's own scoping.

## Risks & Mitigations

- **Risk**: A1 deletes `research.md`/`plan.md`/`implement.md` before `--lit`/memory-retrieval are
  rebuilt into `skill-orchestrate`'s own dispatch prep, silently degrading every task run through
  the collapsed engine. **Mitigation**: sequence Finding 6's two "NO — confirmed absent" rows as
  explicit A6 preserved-asset line items with a named post-collapse home (extend
  `skill-orchestrate` Stage 4 dispatch-prep to call `memory-retrieve.sh` and
  `lit-stage4a-flow.md` directly, mirroring the base skills' Stage 4a), and treat their absence as
  a blocking finding for the Phase A design, not a nice-to-have.
- **Risk**: Phase B verdicts double-count line-count savings between the collapse itself and
  #87-90's mode-gating work (both touch `skill-orchestrate/SKILL.md`'s MT section). **Mitigation**:
  Phase C sizing should net these against each other explicitly, as the task description already
  anticipates.
- **Risk**: #45/#46 lack `file_scope` data, risking an under-informed Phase C verdict.
  **Mitigation**: flag for a short follow-up research pass or manual backfill before finalizing
  their verdicts.

## Context Extension Recommendations

- **Topic**: state.json topic taxonomy vs. informal task-116-description categories. **Gap**: the
  six AUDIT SCOPE sub-topic names have no queryable representation; a future task-116-style audit
  will hit the same manual-clustering cost. **Recommendation**: if this pattern recurs, consider
  a lightweight `subtopic` or `tags[]` field in the task schema — out of scope to add here (this
  task's writes are confined to `specs/**` reports/plans, not schema changes), but worth naming
  for the successor design.

## Appendix

Representative commands used (illustrative, not exhaustive): `wc -l` and `grep -n "^### "` across
all command/skill/agent files named in Sources/Inputs; `grep -rn "effort_flag\|model_flag\|team_mode\|clean_flag\|force_flag"` against `skill-orchestrate/SKILL.md` (zero hits, confirming Finding 1);
`grep -rln "memory-retrieve.sh\|clean_flag"` and `grep -rln "lit_flag\|literature-briefing"` across
`skills/*/SKILL.md` and `commands/*.md` (confirming Finding 6); `grep -rn "skill-orchestrate-hard"`
across `commands/` and `scripts/` (confirming Finding 3's reachability defect); `jq` queries against
`specs/state.json`'s `.active_projects[]` filtered by `.topic` and cross-tabulated against
`specs/TODO.md` section headers (confirming Finding 7's topic-taxonomy note); `grep -c team
specs/events.jsonl` (confirming Finding 4's usage evidence); `for f in
agent-system/extensions/*/manifest.json; do jq 'has("routing_hard")' ...; done` (confirming
Finding 3/5's extension counts).

# Implementation Plan: Task #122

- **Task**: 122 - Build the team-mode shared fan-out stage in skill-orchestrate
- **Status**: [IMPLEMENTING]
- **Effort**: 9.5 hours
- **Dependencies**: 117 (dispatch prep stage, completed), 119 (hard-mode state-machine migration, completed)
- **Research Inputs**: specs/122_build_team_mode_fanout_stage/reports/01_team-fanout-stage-research.md
- **Artifacts**: plans/01_team-fanout-stage.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add one shared team-mode fan-out stage to `skill-orchestrate/SKILL.md` (new **Stage 3.6**), sitting
immediately after the existing Stage 3.5 Dispatch Prep and following that stage's own
single-canonical-copy discipline: every dispatch site references it with a pointer line and never
inlines a second copy. The stage is factored into a **shared skeleton** (availability check and
graceful degradation, effective team-size resolution, per-teammate spawn via the Agent tool with a
Stage 3.5 sub-call each, wave wait/timeout, result collection, postflight session correlation,
staging and cleanup) plus a **per-phase teammate-plan builder** (new **Stage 3.6a**) that supplies
the actual teammate list, prompts, output paths, and territory objects — because research/plan use a
fixed named-role set while implement uses a dynamic, plan-phase-keyed set with real source-file
ownership and an ad-hoc debugger role. `--team` and `--team-size` are added to `orchestrate.md`, with
an effort-aware default team size (3 baseline, 2 under `--fast`, 4 under `--hard`).

Definition of done: `/orchestrate N --team` fans out through the single Stage 3.6 for all three
lifecycle phases; `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` unset silently degrades to the existing
single dispatch; and the three `skill-team-*` skills are left untouched (their deletion is a
successor task's job, not this one's).

### Research Integration

Findings from `reports/01_team-fanout-stage-research.md` that shape this plan directly:

- The three team skills do **not** share one fan-out shape (research report's central finding,
  with a per-aspect comparison table). This plan adopts the report's recommended
  skeleton-plus-builder factoring rather than a single `{phase}`-substituted template.
- `context/contracts/territory.md` (H7) already defines the reusable
  `owned_files`/`read_only_files`/`forbidden_files` JSON shape and explicitly anticipates
  re-enabled parallel dispatch. It is reused verbatim; no new territory prose is authored.
- `synthesis-agent` has zero live dispatch call sites today. This plan wires it live for the
  research and plan synthesis step without editing the agent file.
- `parse-command-args.sh` cannot distinguish an explicit `--team-size 2` from its own hardcoded
  default of 2. Decision D2 below resolves this with a strictly additive export.
- The SubagentStop marker-correlation defect has a fully diagnosed root cause
  (`hooks/subagent-postflight.sh`'s `find_marker()` never reads the marker's own `session_id`).
  Decision D3 below picks the fix and splits it across the file-scope boundary.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and no roadmap phases are included.

## Decision Record

These five decisions are binding on the implementation. Do not re-derive or re-open them.

**D1 — Factoring: shared skeleton (Stage 3.6) + per-phase teammate-plan builder (Stage 3.6a).**
The genuinely uniform part across all three lifecycle phases is: availability check, team-size
resolution, spawn N teammates, wait with timeout, collect results, correlate postflight to the
owning session, stage and commit, clean up. That is Stage 3.6. What is *not* uniform — teammate
determination (fixed named roles vs. dynamic plan-phase set), output-path convention
(`{NN}_teammate-{letter}-findings.md` vs. `{NN}_candidate-{letter}.md` vs. phase-number-keyed
results), territory (none vs. real source files), extra roles (none vs. debugger), and wave count
(1 vs. N) — is Stage 3.6a, a `case "$phase" in` builder producing a uniform teammate-plan array
that Stage 3.6 then consumes without knowing which phase produced it. This mirrors the existing
relationship between Stage 4's per-status handlers (differing dispatch content) and Stage 3.5
(shared sub-call).

**D2 — Team-size default: widen file scope by exactly one file, for a strictly additive export.**
`scripts/parse-command-args.sh` hardcodes `TEAM_SIZE=2` before flag scanning, so the required
effort-aware default (3 / 2 under `--fast` / 4 under `--hard`) cannot be applied without knowing
whether the user typed the flag. The research report's option (a) — changing the pre-flag default
to empty — is **rejected**: `commands/implement.md` consumes the export with a bare
`[ "$TEAM_SIZE" -gt 4 ] && TEAM_SIZE=4`, which errors on an empty value, so that change is not
in fact consumer-safe. The research report's option (b) — silently overriding an explicit
`--team-size 2` — is also rejected as a knowingly-wrong behavior. Adopted instead: add a new
`TEAM_SIZE_EXPLICIT` export ("true"/"false", set `true` only when a `--team-size` flag was
matched), leaving `TEAM_SIZE`'s existing default and every existing consumer byte-identical.
`skill-orchestrate` applies the 3/2/4 table only when `TEAM_SIZE_EXPLICIT` is `false`.

**Files the implementation may therefore touch** (this task's `file_scope`, as amended by this
decision — Phase 1 records the amendment in `specs/state.json`):
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/commands/orchestrate.md`
- `agent-system/extensions/core/scripts/parse-command-args.sh` (additive export only)

No other source-store file may be edited. In particular `agents/synthesis-agent.md`,
`context/contracts/territory.md`, `hooks/subagent-postflight.sh`, and the three `skill-team-*`
skills are read-only for this task.

**D3 — Session correlation: adopt candidate (a) as the contract; implement its orchestrator-side
half here.** The marker's own `session_id` field is the correlation key — candidate (a) from the
already-diagnosed defect record. The hook-side predicate (read `session_id` from the marker and
compare against the stopping subagent's session before counting or deleting) lives in
`hooks/subagent-postflight.sh`, which is outside this task's file scope and is the declared scope
of a separate, dependent hook-side task. What lands **here**, entirely within Stage 3.6 and fully
effective without any hook change:

1. **Owning-session declaration**: Stage 3.6 captures the orchestrator's own marker path and its
   `session_id` before spawning any teammate, and names that pair as the correlation key.
2. **Teammate non-obligation**: every teammate dispatch context carries `postflight_obligation:
   false` and an explicit instruction that the teammate MUST NOT create a `.postflight-pending`
   marker of its own — so no foreign marker can ever be the one `find_marker()` picks first.
3. **Marker re-assertion after the wave** (the actual mitigation): after the wave returns and
   before the orchestrator's own postflight, verify the marker still exists and still carries this
   session's `session_id`; if teammate stops burned the continuation budget and deleted it,
   re-create it via `skill_create_postflight_marker` and reset `.postflight-loop-guard` to `0`,
   emitting one loud stderr line naming what happened. This converts the previously silent,
   trace-free deletion into an observable, self-healed event — which also satisfies candidate (d)
   ("make cap-reached distinguishable") as a side effect.
4. **Cross-reference by durable anchor only**: the stage text refers to
   `hooks/subagent-postflight.sh`'s `find_marker()` by path and function name. It MUST NOT cite a
   task number (deliverable rule).

The `events.jsonl` misattribution amendment recorded against the hook-side defect is
**out of scope here**: it is a property of `events-log-lifecycle.sh`'s SubagentStop branch, not of
this stage, and is verified by the hook-side task that owns that file.

**D4 — `synthesis-agent` goes live for research and plan.** Stage 3.6's collection step dispatches
`synthesis-agent` via the Agent tool (passing teammate finding paths, the task description, the
focus prompt, the output path, and `specs/ROADMAP.md` / `specs/TODO.md` paths — exactly the Stage 1
inputs that agent's own contract already declares), replacing the inline-lead-synthesis pattern.
The agent file itself is not edited. If the synthesis dispatch fails or produces no output file,
Stage 3.6 falls back to lead-inline synthesis with a loud warning rather than failing the cycle.
Implement has no synthesis step: its collection step aggregates per-phase results instead.

**D5 — Concurrency posture under composed flags and in multi-task mode.**
- `--hard --team` for research and plan: full fan-out, with `hard_mode` passed through to each
  teammate's Stage 3.5 sub-call so hard contracts are injected per teammate.
- `--hard --team` for implement: **H1 wins.** The hard branch's single-blocking-phase-per-cycle
  contract exists precisely to stop parallel implement churn, so implement fan-out is suppressed
  under `hard_mode`, degrading to the existing H1 single-phase dispatch with one loud stderr line
  stating why. The existing "Parallel Wave Dispatch: DISABLED" note is amended to say what it has
  always actually meant — it scopes the hard branch's own dispatch behavior — and to name team-mode
  research/plan fan-out as the sanctioned base-mode exception.
- Multi-task mode: `--team` is accepted and **ignored**, with a loud notice. Multi-task already
  fans out across tasks; multiplying that by per-task teammate fan-out compounds concurrency
  uncontrollably. `orchestrate.md`'s Constraints bullet is therefore *narrowed* (`--team` is
  single-task only) rather than deleted outright.

## Goals & Non-Goals

**Goals**:
- One canonical team-mode fan-out stage in `skill-orchestrate/SKILL.md`, parameterized by lifecycle
  phase, referenced by pointer from every dispatch site.
- Per-teammate finding-file convention reusing the existing `teammate_letter` / `artifact_number`
  delegation fields the research and planner agent contracts already declare.
- Per-teammate territory contracts for implement fan-out, reusing `context/contracts/territory.md`.
- Postflight-marker session correlation as specified in D3.
- `--team` / `--team-size` on `orchestrate.md` with the effort-aware default table.
- Graceful degradation preserved as an early check inside the same stage.

**Non-Goals**:
- Deleting or editing `skill-team-research`, `skill-team-plan`, or `skill-team-implement` (successor
  task).
- Editing `agents/synthesis-agent.md` (wired live, not modified).
- Editing `hooks/subagent-postflight.sh` or `events-log-lifecycle.sh` (hook-side dependent task).
- Adding format-specification injection (`report-format.md`/`plan-format.md`) to orchestrate
  dispatch prompts — a real but separate pre-existing gap already recorded in Stage 3.5.
- Regenerating the deployed `.claude/` tree (regeneration is manual-only).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A naive `{phase}`-substituted template silently breaks implement's dynamic wave/phase model | H | M | D1's skeleton/builder split; Phase 6 builds the implement builder separately and explicitly |
| Changing `parse-command-args.sh`'s `TEAM_SIZE` default breaks `implement.md`'s bare `-gt` test | H | H (if option (a) taken) | D2: strictly additive `TEAM_SIZE_EXPLICIT`; existing default untouched; Phase 1 verifies each consumer |
| Marker re-assertion (D3.3) masks a genuine premature-termination condition | M | L | Re-assertion emits a loud stderr line every time it fires and never runs silently; it re-creates, never suppresses, the guard |
| Stage 3.5's `territory` input is documented as hard-mode-only, so base-mode team-implement teammates would get no territory contract | M | M | Phase 6: the fan-out stage builds its own `<territory>` block for implement teammates independently of `hard_mode`, rather than re-gating Stage 3.5's hard-contract block (leaves the existing Stage MT-3 decision record undisturbed) |
| SKILL.md is 3,679 lines; edits to the wrong region or duplicated stage bodies | M | M | Phases are region-scoped and sequential; Phase 8 greps for accidental duplicate fan-out bodies |
| A task-number citation leaks into a deliverable | M | M | Phase 8 runs `check-task-references.sh`; every phase's text uses durable anchors |
| Deployed `.claude/` tree drifts from the source store, so a reader tests stale behavior | L | M | Phase 8 runs `check-deploy-freshness.sh` (advisory) and records that regeneration is the operator's manual step |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |
| 7 | 7 | 6 |
| 8 | 8 | 7 |

Phases within the same wave can execute in parallel. This plan is fully sequential: Phases 3-7 all
edit overlapping regions of the same file (`skills/skill-orchestrate/SKILL.md`), so concurrent
execution would collide.

---

### Phase 1: Additive TEAM_SIZE_EXPLICIT export and file-scope amendment [COMPLETED]

**Goal**: Give `skill-orchestrate` the signal it needs to distinguish a user-typed `--team-size`
from the parser's own default, without changing any existing exported value, and record the
one-file file-scope widening D2 requires.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/parse-command-args.sh`, initialize
      `TEAM_SIZE_EXPLICIT="false"` alongside the existing `TEAM_SIZE=2` initialization; set it to
      `"true"` inside each of the two `--team-size` match branches. Do NOT change `TEAM_SIZE`'s
      default value, its clamp behavior, or the `sed` strip lines. *(completed)*
- [x] Add `TEAM_SIZE_EXPLICIT` to the `export` list on the exports line, and document it in the
      header comment block alongside the existing `TEAM_MODE`/`TEAM_SIZE` entries. *(completed)*
- [x] Confirm every existing consumer of `TEAM_SIZE` is unaffected: grep `commands/*.md` and
      `skills/**` for `TEAM_SIZE` / `team_size` and verify no consumer's behavior changes.
      *(completed: only consumer of the exported TEAM_SIZE is commands/orchestrate.md's own new
      Stage 1/Stage 0 threading (Phase 2) plus commands/implement.md:49's pre-existing
      `[ "$TEAM_SIZE" -gt 4 ] && TEAM_SIZE=4`, unaffected since TEAM_SIZE's default/clamp are
      untouched; research.md/plan.md derive their own lowercase `team_size` independently and do
      not source this parser)*
- [x] Append `agent-system/extensions/core/scripts/parse-command-args.sh` to this task's
      `file_scope` array in `specs/state.json` (append only; never wholesale-assign the array),
      then run `bash .claude/scripts/generate-todo.sh`. *(completed: file_scope already carried
      this entry from the planning stage's D2 amendment; generate-todo.sh re-run to confirm)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The plan asserts exactly three files may be edited (D2) and that the only
`TEAM_SIZE` consumers are `commands/research.md`, `commands/plan.md`, and `commands/implement.md`.
Confirm at implementation time with `grep -rn "TEAM_SIZE\|team_size" agent-system/extensions/` and
report any consumer not on that list before proceeding.

**Files to modify**:
- `agent-system/extensions/core/scripts/parse-command-args.sh` - add `TEAM_SIZE_EXPLICIT` init, set
  it in both `--team-size` branches, add to exports and header comment
- `specs/state.json` - append one entry to this task's `file_scope`

**Verification**:
- `bash -n agent-system/extensions/core/scripts/parse-command-args.sh` passes
- Sourcing the script with `--team --team-size 4` yields `TEAM_SIZE=4 TEAM_SIZE_EXPLICIT=true`;
  with `--team` alone yields `TEAM_SIZE=2 TEAM_SIZE_EXPLICIT=false`; with no flags yields
  `TEAM_MODE=false TEAM_SIZE=2 TEAM_SIZE_EXPLICIT=false`
- `bash .claude/scripts/validate-state.sh` passes

---

### Phase 2: Command flags and skill-side input reading [COMPLETED]

**Goal**: Accept `--team` / `--team-size` on `/orchestrate`, thread them to `skill-orchestrate`, and
resolve the effective team size there.

**Tasks**:
- [x] `commands/orchestrate.md` Options table: add a `--team` row (default `false`) and a
      `--team-size` row (default: `3`, `2` under `--fast`, `4` under `--hard`; clamped 2-4).
      *(completed)*
- [x] `commands/orchestrate.md` Constraints: narrow the existing multi-task bullet per D5 — state
      that `--team` applies to single-task mode only and is accepted-and-ignored with a notice in
      multi-task mode. Do not leave the flat "`--team` flag not supported" wording standing.
      *(completed)*
- [x] `commands/orchestrate.md` STAGE 0: add `TEAM_MODE`, `TEAM_SIZE`, `TEAM_SIZE_EXPLICIT` to the
      documented exports comment and to the prose paragraph that already explains how
      `CLEAN_FLAG`/`EFFORT_FLAG` are threaded. *(completed)*
- [x] `commands/orchestrate.md` STAGE 2 DELEGATE: add `team_mode={TEAM_MODE}
      team_size={TEAM_SIZE} team_size_explicit={TEAM_SIZE_EXPLICIT}` to the `args` string and the
      three matching keys to the JSON delegation context. *(completed)*
- [x] `commands/orchestrate.md` MULTI-TASK DISPATCH: add the same three keys to its args/context
      **plus** one sentence stating they are carried for diagnostics and that multi-task mode does
      not fan out per task. *(completed)*
- [x] `skills/skill-orchestrate/SKILL.md` Stage 1: read `team_mode` (default `"false"`),
      `team_size` (default `2`), `team_size_explicit` (default `"false"`); derive `team_size_eff`
      via the D2 rule — when `team_size_explicit` is `"true"` use `team_size`, else `3` baseline /
      `2` when `effort_flag` is `fast` / `4` when `effort_flag` is `hard` — then clamp to 2-4.
      Place this immediately after the existing `hard_mode` derivation.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/commands/orchestrate.md` - Options, Constraints, STAGE 0, STAGE 2,
  MULTI-TASK DISPATCH
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 1 input reading and
  `team_size_eff` derivation only

**Verification**:
- The flat "`--team` flag not supported" sentence no longer appears in `commands/orchestrate.md`
- Every delegation site in `commands/orchestrate.md` that already passes `clean_flag`/`effort_flag`
  now also passes the three team keys (grep both spellings, args string and JSON)
- Stage 1's `team_size_eff` block covers all four cases (explicit, baseline, fast, hard) and clamps

---

### Phase 3: Stage 3.6 skeleton, part A — inputs, degradation, spawn, wait [NOT STARTED]

**Goal**: Author the first half of the shared fan-out stage: its inputs contract, the early
availability check and graceful-degradation fallthrough, the teammate spawn loop, and wave waiting.

**Tasks**:
- [ ] Insert a new `### Stage 3.6: Team Fan-Out (shared, invoked from every dispatch site when
      team_mode is true)` immediately after Stage 3.5 and before `### Stage 4: State Handlers`.
- [ ] Open with the same single-canonical-copy discipline Stage 3.5 states about itself: every
      dispatch site references this stage by pointer line; **never duplicate this body at a
      dispatch site**.
- [ ] Inputs table (mirroring Stage 3.5's own table shape): `phase`, `description`, `task_type`,
      `focus_prompt`, `clean_flag`, `effort_flag`, `lit_flag`, `hard_mode`, `team_size_eff`,
      `artifact_number`, `plan_path` (implement only), `session_id`, `task_dir`, `handoff_path`.
- [ ] **Early availability check** (first executable step, before any builder call or spawn): if
      `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS != "1"`, emit one stderr warning line and RETURN a
      `fanout_degraded=true` signal so the calling dispatch site proceeds with its existing
      single-agent Agent dispatch unchanged. `--team` is accepted, never rejected. Note explicitly
      that this stage MUST NOT re-invoke a whole lifecycle skill on the degraded path (double
      preflight/postflight) — the caller's own existing single dispatch is the fallback.
- [ ] Call **Stage 3.6a** (Phase 5/6) to obtain `teammate_plan`: an ordered array of
      `{label, prompt, subagent_type, output_path, delegation_extras, territory}` tuples.
- [ ] Spawn loop: for each tuple, run **Stage 3.5 Dispatch Prep** with the same `phase` and with
      `hard_mode`/`clean_flag`/`lit_flag` passed through unchanged (this is what makes
      `--hard --team` inject hard contracts per teammate for free), mint a per-teammate
      `dispatch_seq`, and invoke the Agent tool with the tuple's `subagent_type`, its prompt plus
      the four Stage 3.5 outputs appended in the documented order, and a context object carrying
      `task_number`, `task_type`, `session_id`, `orchestrator_mode: true`, `lit_flag`, `task_dir`,
      `handoff_path`, `dispatch_seq`, `postflight_obligation: false`, plus the tuple's
      `delegation_extras`.
- [ ] Wave wait: launch a wave's teammates in one message so they run concurrently; wait for all to
      return or hit a 30-minute wave timeout; on timeout record the missing labels and continue with
      whatever returned rather than failing the cycle.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the inputs table has the 14 rows listed above and that the
teammate tuple has 6 fields. Confirm at implementation time that Stage 3.6a (Phases 5-6) can
actually populate every declared field for all three phases; if a field proves unpopulatable for
some phase, record the discrepancy in the stage text rather than silently dropping the field.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - new Stage 3.6 section (first
  half) inserted between Stage 3.5 and Stage 4

**Verification**:
- Stage 3.6 appears exactly once; `grep -c "### Stage 3.6:"` returns 1
- The availability check is textually the first executable step of the stage
- The spawn loop calls Stage 3.5 per teammate by pointer, and does not restate Stage 3.5's body

---

### Phase 4: Stage 3.6 skeleton, part B — collection, session correlation, staging, cleanup [NOT STARTED]

**Goal**: Complete the shared skeleton with result collection, the D3 session-correlation
mechanism, commit staging, cleanup, and the stage's output contract.

**Tasks**:
- [ ] **Collection**: read each returned teammate's declared `output_path`; record present/missing
      per label; never abort on a missing file.
- [ ] **Session correlation (D3)**, authored as its own clearly delimited sub-block:
      - Before the spawn loop (cross-reference back into Phase 3's text), capture
        `marker_path="${TASK_DIR}/.postflight-pending"` and the `session_id` it carries.
      - State the teammate non-obligation rule: teammates receive `postflight_obligation: false`
        and MUST NOT create a `.postflight-pending` marker of their own.
      - After the wave returns: if `marker_path` is absent, or present with a different
        `session_id`, re-create it via `skill_create_postflight_marker` with this session's values,
        reset `${TASK_DIR}/.postflight-loop-guard` to `0`, and emit one loud stderr line naming the
        condition ("teammate stops consumed the continuation budget and removed this session's
        postflight marker; re-asserted").
      - Name the correlation key (the marker's own `session_id` field) and cross-reference
        `hooks/subagent-postflight.sh`'s `find_marker()` by path and function name as the site where
        the complementary read-side predicate belongs. **No task-number citation.**
- [ ] **Staging**: state that teammate artifacts are staged under the existing task-directory scope
      via `git-commit-scoped.sh` (the command's CHECKPOINT 3 already owns the commit); this stage
      performs no commit of its own and never uses `git add -A`.
- [ ] **Cleanup**: remove any per-wave scratch state this stage created; explicitly do NOT remove
      the postflight marker or the orchestrator loop-guard file (termination-only cleanup belongs to
      Stage 8).
- [ ] **Outputs contract**: the stage produces `fanout_degraded`, `teammate_results` (label ->
      path/status), and `synthesis_path` (empty for implement). State exactly what the calling
      dispatch site does with each.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 3.6 second half

**Verification**:
- The re-assertion block never runs silently: every branch that mutates the marker or loop guard
  emits a stderr line
- No task number appears anywhere in the new text (`grep -nE 'task [0-9]+' ` over the new region)
- The stage performs no `git commit` and contains no `git add -A`

---

### Phase 5: Stage 3.6a builders for research and plan, with live synthesis dispatch [NOT STARTED]

**Goal**: Author the per-phase teammate-plan builder for the two fixed-role phases, and wire
`synthesis-agent` live per D4.

**Tasks**:
- [ ] Insert `### Stage 3.6a: Teammate-Plan Builder (per-phase)` immediately after Stage 3.6, opening
      with the `case "$phase" in research|plan|implement) ... esac` dispatch shape and a one-paragraph
      statement of why the three phases genuinely differ (fixed roles vs. dynamic plan-phase set).
- [ ] `research` branch: fixed roles gated by `team_size_eff` — a=Primary, b=Alternatives,
      c=Critic (present from size 3), d=Horizons (present at size 4). Each tuple's
      `subagent_type` is `$RESEARCH_AGENT`; `delegation_extras` carries `artifact_number` and
      `teammate_letter`, which the research agent contracts already declare and from which they
      derive `reports/{NN}_teammate-{letter}-findings.md` themselves. `territory` is empty (no
      source files touched; artifact paths are disjoint by construction).
- [ ] `plan` branch: fixed roles gated by `team_size_eff` — a=Primary/Incremental,
      b=Alternative-Boundaries, c=Risk-and-Dependency (present from size 3).
      `subagent_type` is `$PLANNER_AGENT`; `delegation_extras` carries `artifact_number`,
      `teammate_letter`, and `research_path`; the planner contract derives
      `plans/{NN}_candidate-{letter}.md` itself. `territory` empty.
- [ ] **Synthesis step (D4)**, authored once and shared by both branches: after collection,
      dispatch `synthesis-agent` via the Agent tool with the teammate finding paths, task
      description, focus prompt, the unified output path
      (`reports/{NN}_team-research.md` for research, `plans/{NN}_{slug}.md` for plan),
      `specs/ROADMAP.md`, and `specs/TODO.md` — the exact Stage 1 inputs that agent's own contract
      declares. State explicitly that `agents/synthesis-agent.md` is NOT edited by this work.
- [ ] Synthesis fallback: if the dispatch returns without producing the output file, fall back to
      lead-inline synthesis with a loud warning; never fail the cycle on synthesis alone.
- [ ] Set `synthesis_path` in the stage outputs so the calling dispatch site can link the artifact.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts research has up to 4 roles and plan up to 3, and that both
agent families already accept `teammate_letter`/`artifact_number`. Confirm against
`agents/general-research-agent.md`, `agents/general-research-hard-agent.md`,
`agents/planner-agent.md`, and `agents/planner-hard-agent.md` before writing the builder; if a
`-hard` variant lacks the field, state that limitation in the builder text rather than assuming it.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - new Stage 3.6a section
  (research and plan branches plus the shared synthesis step)

**Verification**:
- `agents/synthesis-agent.md` is unmodified (`git diff --stat` shows no entry for it)
- The builder never hardcodes a teammate output path that contradicts
  `rules/artifact-formats.md`'s team-mode naming convention
- Both branches produce tuples with all 6 declared fields

---

### Phase 6: Stage 3.6a implement builder — dynamic waves, territory, debugger [NOT STARTED]

**Goal**: Author the implement branch of the builder, which is structurally different from the other
two: teammates are keyed to plan phases, own real source files, and can trigger an ad-hoc debugger.

**Tasks**:
- [ ] `implement` branch: derive the teammate set from the plan's own `**Dependency Analysis**` wave
      table when present, falling back to per-phase `**Depends on**:` fields, using the phase-heading
      grammar via `scripts/lib/phase-heading-patterns.sh` (source the shared anchor; do not
      re-derive a regex). Teammate count per wave = `min(len(wave.phases), team_size_eff)`.
      `subagent_type` is `$IMPLEMENT_AGENT`; `delegation_extras` carries `plan_path`,
      `phase_number`, and `roadmap_path`.
- [ ] State the whole-file conformance obligation before any filtered heading scan: call
      `has_nonconforming_phase_headings` on the plan first, and on a hit refuse to build a teammate
      plan (route to the stage's degraded single-dispatch return) rather than silently selecting the
      next conforming heading.
- [ ] `territory` per implement teammate: build the
      `owned_files`/`read_only_files`/`forbidden_files` object defined in
      `context/contracts/territory.md` — referenced by path, with no territory prose re-authored —
      pointing the agent at its own phase's "Files to modify" list, and include the contract's
      concurrency note verbatim in spirit (this declaration asserts ownership, not exclusivity).
      Emit this as the stage's own `<territory>` block appended to the teammate prompt,
      **independently of `hard_mode`**, so base-mode team-implement teammates are covered without
      re-gating Stage 3.5's hard-contract block.
- [ ] Multi-wave execution: waves run in dependency order; a later wave is built only after the
      previous wave's teammates return.
- [ ] Debugger role: on a teammate-reported phase error, spawn one additional teammate with the
      failing phase's context and the error text, outside the wave headcount; state its territory is
      the failing phase's own files.
- [ ] **D5 hard-mode interaction**: state at the head of this branch that when `hard_mode` is
      `"true"`, the implement builder returns an empty teammate plan and one loud stderr line, so the
      caller falls through to the existing H1 single-phase dispatch. H1's one-blocking-phase-per-cycle
      contract takes precedence over fan-out.

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts a per-teammate territory object can be derived from each
phase's "Files to modify" list. Confirm on this repository's own recent plans that the section
exists and is parseable; where it is absent, the builder must state the fallback (dispatch the phase
with an empty `owned_files` and let the agent derive its own from the phase body, as the existing H1
territory literal already does) rather than assuming the list is always present.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 3.6a implement branch

**Verification**:
- `context/contracts/territory.md` is unmodified and is referenced by path from the new text
- The conformance gate precedes every filtered phase-heading scan in the new text
- The hard-mode suppression statement is present and unambiguous

---

### Phase 7: Wire dispatch sites and reconcile concurrency notes [NOT STARTED]

**Goal**: Make the five Stage 4 dispatch sites actually use Stage 3.6, and reconcile the existing
concurrency prose so it no longer contradicts the new stage.

**Tasks**:
- [ ] For each research-dispatching handler (`not_started`, `researching`), each plan-dispatching
      handler (`researched`, `planning`), and the base branch of `planned`/`implementing`: add a
      `team_mode` fork at the same granularity the existing `hard_mode` fork (D5) uses —
      `if [ "${team_mode:-false}" = "true" ]; then` run **Stage 3.6** with the matching `phase`
      (pointer line only, never an inlined body) `else` the existing single-agent Agent dispatch,
      unchanged `fi`.
- [ ] State once, at the first fork, that a `fanout_degraded=true` return from Stage 3.6 means the
      handler proceeds with its own `else`-branch single dispatch — so the degraded path costs
      nothing beyond one warning.
- [ ] Amend the "Parallel Wave Dispatch: DISABLED" note per D5: it scopes the hard branch's own
      per-phase dispatch; team-mode research/plan fan-out is the sanctioned base-mode exception; and
      implement fan-out remains suppressed under `hard_mode`.
- [ ] Stage MT-1 / Stage MT-4: read `team_mode` for diagnostics and emit one notice that multi-task
      mode does not fan out per task; do not add a fan-out fork to Stage MT-4.
- [ ] Update Stage 1's acceptance-checklist table region only if the new stage changes a row's
      accuracy; otherwise leave it byte-identical.

**Timing**: 1 hour

**Depends on**: 6

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exactly five dispatch sites need a `team_mode` fork
(`not_started`, `researching`, `researched`, `planning`, and the base branch of
`planned`/`implementing`). Confirm by enumerating `#### State:` headings in Stage 4 at implementation
time and report any additional dispatching handler found.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 4 handlers, the
  parallel-dispatch note, Stage MT-1/MT-4 notice

**Verification**:
- Every fork references Stage 3.6 by pointer; `grep -c "Stage 3.6"` shows one definition plus one
  reference per fork, and no second copy of the stage body
- The base (`else`) branch text of each handler is byte-identical to before the fork
- The parallel-dispatch note no longer reads as a blanket claim that the orchestrator never issues
  concurrent Agent calls

---

### Phase 8: Full verification and consistency pass [NOT STARTED]

**Goal**: Run the complete gate set, confirm the untouched-file guarantees, and record residue.

**Tasks**:
- [ ] `bash .claude/scripts/check-task-references.sh` — zero unexempted hits in the edited files.
- [ ] `bash .claude/scripts/lint/lint-postflight-boundary.sh` on `skill-orchestrate` — the new stage
      must not violate the postflight boundary.
- [ ] `bash .claude/scripts/lint/lint-routing-wiring.sh` and
      `bash .claude/scripts/validate-wiring.sh` — no routing regression.
- [ ] `bash -n agent-system/extensions/core/scripts/parse-command-args.sh`.
- [ ] `bash .claude/scripts/validate-state.sh` and `bash .claude/scripts/check-deploy-freshness.sh`
      (advisory; regeneration of `.claude/` is the operator's manual step and is NOT performed here).
- [ ] Confirm the untouched-file guarantee with `git status --short`: no modification to
      `agents/synthesis-agent.md`, `context/contracts/territory.md`,
      `hooks/subagent-postflight.sh`, or any `skills/skill-team-*/` file.
- [ ] Grep for accidental duplication: exactly one `### Stage 3.6:` and one `### Stage 3.6a:`
      definition, and no inlined copy of either body at a dispatch site.
- [ ] Read the full Stage 3.6/3.6a region end to end once and confirm the five decisions (D1-D5) are
      each visibly honored in the shipped text.
- [ ] Record residue in the implementation summary: the hook-side read predicate and the
      `events.jsonl` misattribution amendment remain with the hook-scope task (named by file path,
      not task number, in any deliverable text).

**Timing**: 1 hour

**Depends on**: 7

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the five lint/validate scripts named above are the
applicable gate set. Confirm by listing `.claude/scripts/lint/` and `.claude/scripts/validate-*.sh`
at implementation time and run any additional script that applies to skills or commands.

**Files to modify**:
- None (verification only); the implementation summary is written under
  `specs/122_build_team_mode_fanout_stage/summaries/`

**Verification**:
- All named scripts exit 0 (or, for advisory scripts, emit only expected warnings)
- `git status --short` confirms exactly three source-store files changed

---

## Testing & Validation

- [ ] Sourcing `parse-command-args.sh` produces correct `TEAM_MODE`/`TEAM_SIZE`/`TEAM_SIZE_EXPLICIT`
      for: no flags, `--team`, `--team-size 4`, `--team --team-size 2`, `--team --fast`,
      `--team --hard`
- [ ] `commands/orchestrate.md` documents `--team` and `--team-size` and no longer states flatly
      that `--team` is unsupported
- [ ] Stage 3.6 exists exactly once, opens with the availability check, and is referenced by pointer
      from every team-mode fork
- [ ] Stage 3.6a covers all three phases with the documented per-phase differences
- [ ] The session-correlation sub-block names the marker `session_id` as the correlation key and
      re-asserts the marker loudly
- [ ] `check-task-references.sh` reports zero unexempted task-number citations in edited files
- [ ] `synthesis-agent.md`, `territory.md`, `subagent-postflight.sh`, and the three `skill-team-*`
      skills are byte-identical to their pre-task state

## Artifacts & Outputs

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage 3.6, Stage 3.6a, Stage 1
  inputs, Stage 4 forks, concurrency-note amendment, MT notice)
- `agent-system/extensions/core/commands/orchestrate.md` (Options, Constraints, STAGE 0, STAGE 2,
  multi-task dispatch context)
- `agent-system/extensions/core/scripts/parse-command-args.sh` (additive `TEAM_SIZE_EXPLICIT`)
- `specs/122_build_team_mode_fanout_stage/plans/01_team-fanout-stage.md` (this plan)
- `specs/122_build_team_mode_fanout_stage/summaries/01_team-fanout-stage-summary.md`

## Rollback/Contingency

All changes are confined to three source-store files and are additive: Stage 3.6/3.6a are new
sections, the Stage 4 forks preserve their `else` branches byte-identical, and the parser change adds
one export without altering any existing value. Reverting is `git revert` of the phase commits in
reverse order; because `.claude/` is a regenerated deploy artifact, no deployed-tree cleanup is
required beyond the operator's normal manual regeneration. If a single phase must be abandoned
mid-plan, the last green sub-step commit leaves the file in a consistent state: an authored but
unreferenced Stage 3.6 (Phases 3-6 without Phase 7) is inert, since no dispatch site invokes it.

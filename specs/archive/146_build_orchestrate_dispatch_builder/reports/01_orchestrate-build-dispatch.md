# Research Report: Task #146

**Task**: 146 - Build orchestrate-build-dispatch.sh: per-dispatch context files, pointer prompts, and the user-decision contract
**Started**: 2026-09-03T05:10:00Z
**Completed**: 2026-09-03T06:10:00Z
**Effort**: large (single script + 11 call-site edits + doc/registry updates + agent-contract sweep)
**Dependencies**: Task 145 (completed)
**Sources/Inputs**: Codebase exploration only (no web search needed — this is a pure in-repo refactor of `skill-orchestrate/SKILL.md`, `scripts/lib/manifest-routing-lib.sh`, `context/patterns/lit-stage4a-flow.md`, `scripts/orchestrate-recover-outcome.sh`, `scripts/orchestrate-triage-classify.sh`, `context/standards/orchestrator-runtime-files.md`, `context/standards/git-staging-scope.md`, `context/formats/return-metadata-file.md`, `docs/architecture/handoff-schema.md`, `.gitignore`, `scripts/check-runtime-file-tracking.sh`, `scripts/reap-session-runtime-files.sh`, `scripts/skill-base.sh`, agent contract files, `specs/PATH.md`)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch-site count is **8 physical Stage 4 sites + 3 MT-4 loop bodies = 11 textual edit
  points**, not "5+3=8" as the task description's raw count suggests. The description's "five"
  is correct at the *logical-recipe* level (research / plan / implement-hard / implement-base /
  partial — 5 distinct dispatch shapes), which matches `specs/PATH.md`'s "all eight dispatch
  sites" (5 logical single-task + 3 MT-4). The plan must state both numbers explicitly so the
  implementer edits all 11 physical `Run **Stage 3.5**` occurrences, not 5.
- Four additional Stage 3.5-adjacent dispatch sites — the H4 adversarial-verification re-dispatch
  (2 occurrences), Stage 5a's fork, Stage 5b's divergence-audit dispatch, and Stage 6's blocker
  research-fork/reviser/re-implement (3 dispatches) — **do not call Stage 3.5 today** and are
  **out of scope** for this task; they must keep their inline prompts unchanged. Scope creep here
  would blow the "one script call + fixed pointer prompt" acceptance bar.
- Every input the new script must gather is now fully enumerated and traced to its source (Stage
  3.5's four outputs, `resolve_cycle_artifact_number()`/`skill_read_artifact_number`'s
  current/prev mode split, the dual-form continuation-pointer normalization, territory's hard-mode
  H1 shape). See Findings §1–§4.
- `user_decision` has **no existing precedent** in either `return-metadata-file.md` or
  `handoff-schema.md` — it is a genuinely new optional field, distinct from the existing
  informational `decisions_made` field in the handoff schema (which must not be conflated with it).
- `.dispatch/` does not fit either existing runtime-file lifecycle cleanly: unlike the singleton
  `.orchestrator-loop-guard`/`.orchestrator-churn-state.json`/`.drift-inspection.json` (one file,
  overwritten or rm-f'd at Stage 8), `.dispatch/{seq}.md` **accumulates one file per dispatch** for
  the life of a task. Neither `reap-session-runtime-files.sh` (explicitly scoped to `specs/`-root
  singletons, not per-task dirs) nor any per-task reaper exists to age these out. The plan needs
  an explicit disposition decision (Risks §2).
- The agent-contract sweep target is **~65 agent files across ~20 extensions** (core: 5 files that
  matter; extensions: cslib, email, epidemiology, filetypes, formal, founder, latex, lean,
  literature, nix, nvim, present, python, typst, web, z3). Most are **not** reachable from
  `skill-orchestrate`'s Stage 1b routing at all (e.g. `legal-council-agent`, `meeting-agent`,
  `docx-edit-agent`) — the sweep must be routing-table-driven (walk `routing_agents` blocks in
  every `manifest.json`), not a blind file-by-file pass. See Findings §6.

## Context & Scope

Researched the exact mechanics `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
(4,105 lines) uses today at every point that builds a dispatch prompt, so the planner can design
`orchestrate-build-dispatch.sh` to reproduce every input byte-for-byte (per this task's MUST NOT:
"a generated dispatch file must carry every input the current inline recipe would have
interpolated"). Also researched the runtime-file registration surfaces (item 5) and the
user-decision contract's target files (item 4), and scoped the agent-contract sweep (item 3).

Out of scope for this research (left to planning): the exact Markdown template for
`.dispatch/{seq}.md`; the precise wording of the fixed pointer prompt (a first draft is quoted
verbatim in the task description and should be treated as close to final); wiring
`orchestrate-cycle-plan.sh` (a **different**, later task, 147/A.3) — this task's script is called
directly by the still-existing per-cycle bash in `SKILL.md`, not yet by a batch planner.

## Findings

### 1. Stage 3.5 "Dispatch Prep" — the procedure to replicate in full

Defined once at `SKILL.md:759-929`. Inputs: `phase` (`research`\|`plan`\|`implement`),
`description` (case-alias reconciliation: single-task uses uppercase `DESCRIPTION` from
`state.json` via `jq`, multi-task uses lowercase `description` from `mt_state_file.descriptions[]`
— **the alias `description="${DESCRIPTION:-${description:-}}"` at line 790 must be replicated or
the new script must simply take the description as an explicit CLI/JSON input and skip the alias
entirely**), `task_type`, `focus_prompt`, `clean_flag`, `effort_flag`, `model_flag`, `lit_flag`,
`hard_mode`, and (implement-hard-only) `territory`.

Four outputs, each optional and never emitted empty-tag: `memory_context` (via
`bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "$memory_arg3"`, gated on
`clean_flag != "true"`, with `memory_arg3="$focus_prompt"` only for phase=research, else `""`),
`lit_context` (via the full `context/patterns/lit-stage4a-flow.md` six-directive resolution —
`literature-lit-flag-resolve.sh` then branch on `LIT_DISABLED\|SUBINDEX_PRESENT\|GLOBAL_MISSING\|
PROMPT_NEEDED\|AUTONOMOUS_GLOBAL\|SPARSE_PROMPT_NEEDED`; the two interactive directives are
unreachable under `orchestrator_mode: true` and always resolve to the `[lit:auto]` fallback —
important: the new script runs headless, so it must hard-code `orchestrator_mode: true`
semantics, i.e. never attempt `AskUserQuestion`), `effort_note` (one line, only when
`effort_flag` non-empty), and `hard_contracts_block` (only when `hard_mode == "true"`; see §3
below). A fifth output, `model`, is not a prompt-string append — it passes through
`model_flag` unchanged (`haiku`/`sonnet`/`opus`/`fable`) and stays empty (never `"null"`) when
`model_flag` is empty; this is exactly the script's documented `{dispatch_file, model}` return
shape.

Injection order when present: `memory_context`, then `lit_context`, then `effort_note`, then
`hard_contracts_block`, each skipped when empty — none of the four is ever added to the `context`
JSON object (they are prompt-string content only). The new dispatch-file writer must preserve
this exact order and skip-when-empty behavior inside the file it writes (the file replaces the
prompt string, so the file's body should read as this same concatenation plus the extra items in
WORK item (1)).

### 2. Physical dispatch-site count: 11, not 8

`grep -c "Run \*\*Stage 3.5"` = **11** occurrences: single-task Stage 4 at lines 955 (`not_started`),
1003 (`researching`), 1117 (`researched`), 1239 (`planning`), 1431 (`planned/implementing` hard
branch), 1545 (`planned/implementing` base branch), 1627 (`partial` — continuation-available
sub-state), 1693 (`partial` — no-continuation sub-state); plus MT-4's three loops at 3351
(`research_tasks`), 3363 (`plan_tasks`), 3380 (`implement_tasks`). The task description's "three
MT-4 loops... and five single-task Stage 4 sites" and `specs/PATH.md`'s "all eight dispatch
sites" both count *logical* dispatch recipes (not_started/researching share one recipe;
researched/planning share one; the two partial sub-states are grouped under one `partial` state)
— 5 single-task recipes + 3 MT-4 loops = 8. **The plan must instruct the implementer to edit all
11 physical text locations**, cross-checked by re-running `grep -c "Run \*\*Stage 3.5"` == 0
after the edit (every occurrence replaced by a script call + fixed prompt).

Four *additional* `Stage 3.5`-adjacent dispatch sites do **not** call Stage 3.5 today and are
explicitly out of scope (confirmed by their `context` objects lacking `memory_context`/
`lit_context`, and by SKILL.md:851-853's own "six auxiliary/diagnostic dispatches ... do not call
Stage 3.5" statement): the H4 adversarial-verification re-dispatch (`$RESEARCH_AGENT`, occurs
twice — inside the `researched` and `planning` handlers, SKILL.md:1076-1079 and 1198-1201), Stage
5a's `"fork"` (plan-drift inspection, :2173), Stage 5a's `"reviser-agent"` (drift-triggered
revision, :2187), Stage 5b's `$RESEARCH_AGENT` divergence audit (:2291-style), Stage 6's blocker
`"fork"` research (:2251-area — wait, actually 2251 is the H4 research re-dispatch's own
`Agent tool:` block reused inline; Stage 6's dedicated fork/reviser/re-implement sequence is its
own block), and Stage 6's `"reviser-agent"` (:2313) and `$IMPLEMENT_AGENT` blocker re-dispatch
(:2333, confirmed by its `context` object at that line having no `memory_context`/`lit_context`
either). **None of these six/seven auxiliary dispatches gets a dispatch file under this task** —
leave their inline `prompt`/`delegation_context` construction untouched.

### 3. Additional per-dispatch inputs the script must gather beyond Stage 3.5's four outputs

- **Task description + task_type**: read directly from `specs/state.json`
  (`.active_projects[] | select(.project_number == $num) | .description, .task_type`) — this
  removes the case-alias problem in §1 entirely, since the script becomes the single source and
  the caller no longer needs to pre-extract `DESCRIPTION`.
- **Artifact round number (`MM_`)**: `resolve_cycle_artifact_number()` (SKILL.md:537-558) wraps
  `skill_read_artifact_number()` (`scripts/skill-base.sh:301-329` — exact function body already
  read; confirmed exports `ARTIFACT_NUMBER`/`ARTIFACT_PADDED`). Mode selection by phase:
  `research` → `mode=current, artifact_dir=reports/`; `plan` → `mode=prev, artifact_dir=plans/`;
  `implement` → `mode=prev, artifact_dir=summaries/`. `mode=current` uses
  `.next_artifact_number` as-is; `mode=prev` uses `next_artifact_number - 1` (floored at 1) — "the
  planner and implementer share the round research opened." The new script should call
  `skill_read_artifact_number` directly (source `scripts/skill-base.sh`) rather than
  re-implementing the fallback-count logic, to avoid a second copy drifting from the first.
- **Latest report path** (phase=plan): `jq -r '[.active_projects[] | select(.project_number==$num)
  | .artifacts // [] | .[] | select(.type=="report")] | .[0].path // ""' specs/state.json`
  (verbatim pattern at SKILL.md:1028-1031, 1150-1153).
- **Latest plan path** (phase=implement): `ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V |
  tail -1` (verbatim pattern at SKILL.md:1268, 1609, 1690, and MT-4's per-task equivalent).
- **Continuation pointer, dual-form + normalized** (phase=implement, `partial` state and MT-4's
  `implement_tasks` loop): read `.orchestrator-handoff.json`, resolve **either** nested
  `continuation_context.handoff_path` (deprecated, no live writer) **or** flat top-level
  `continuation_path` (the one canonical form live H9 writers emit), and normalize to
  `{handoff_path, orchestrator_mode: true}` or `null`. The exact `jq` one-liner is at
  SKILL.md:1594-1599 and must be reused verbatim — it is also implemented independently in
  `scripts/orchestrate-triage-classify.sh`'s `continuation_ok` predicate, which the codebase
  explicitly warns "do not let this hand-applied copy drift from that script again." **The new
  script should be the third and canonical implementation these two collapse into**, or at
  minimum must replicate the identical jq expression rather than a paraphrase.
- **Handoff path, dispatch_seq, dispatch_start_ts**: `handoff_path_abs =
  "${task_dir_abs}/.orchestrator-handoff.json"`; `dispatch_seq` is **minted by the caller**
  before invoking this script (via `mint_dispatch_seq()`, a named shim over
  `skill_orchestrate_mint_dispatch_seq()` in `scripts/skill-base.sh`) and passed in as `--seq N`
  — the script must NOT re-mint it itself, since the per-cycle bash in `SKILL.md` (not yet
  replaced by the future `orchestrate-cycle-plan.sh`, task 147) still owns the counter file
  (`loop_guard_file` single-task / `mt_state_file.dispatch_seq_counter` multi-task). Similarly
  `dispatch_start_ts` (`date -u +%s`) is captured by the caller immediately around the dispatch
  window for infra-failure discrimination and is **not** an input the build script needs to
  compute — but the task description explicitly lists it as something the script "additionally
  gathers," so the plan should clarify: the script *records into the dispatch file* the
  caller-supplied timestamp (as a `--dispatch-start-ts` input or by having the caller stamp it
  after the call), it does not generate its own.
- **Territory** (hard-mode `implement`, H1 branch only): the exact JSON shape at
  SKILL.md:1388-1393 (`owned_files`, `read_only_files: []`, `forbidden_files: []`,
  `concurrency_note`). Only one call site (`planned/implementing`'s hard branch) ever sets this
  non-empty; the script's `--territory "..."` flag should accept it as an opaque JSON string
  passed through, not reconstructed.
- **User-decision contract text** (see Findings §5): a short, fixed block referencing the
  contract file, appended once per dispatch file (not per-phase-varying).

### 4. Hard-mode contract block construction (`routing_lookup_flat`)

Fully read at SKILL.md:855-913 and `manifest-routing-lib.sh:200-`(~260). `core_contracts` is a
fixed, phase-keyed bash array (`research`: anti-analysis/reference-grounding/
adversarial-verification; `plan`: reference-grounding/wrap-up/anti-analysis; `implement`:
anti-analysis/wrap-up[+territory if set]/recovery/phase-closure/pre-edit-gate). Extension
overrides come from `routing_lookup_flat "hard_contracts" "$task_type"` (**never**
`routing_lookup` — a documented, deliberate sibling, not a wrapper, because `routing_lookup`
assumes a two-level `{op:{task_type:value}}` manifest shape while `routing_lookup_flat` is
one-level `{task_type:value}`). Entries starting `replace:{basename}:{path}` substitute in place
by basename match; all other entries append additively in manifest order. Output is a
`<hard-mode-contracts>` tag wrapping one `- context/contracts/{file}` line per resolved entry.
This entire procedure is already script-callable as-is (`manifest-routing-lib.sh` is a sourceable
library, not embedded prose) — the new script only needs to `source` it and reproduce
SKILL.md:864-912's bash verbatim.

### 5. User-decision contract — genuinely new, no existing field to extend

Searched `context/formats/return-metadata-file.md` (all 26 `##`/`###` headings) and
`docs/architecture/handoff-schema.md` (all 30 headings): neither file has a `user_decision` field
today. The nearest lookalike is `handoff-schema.md`'s `decisions_made` (optional, "Key decisions
that downstream cycles should be aware of. Prevents downstream agents from re-investigating
already-settled questions.") — this is purely informational/historical and **must not be
conflated** with the new field, which is a live, structured, *forward-looking* request
(`{question, options[], recommended, blocking}`) that the postflight script relays as an
`ask_user` verdict. `specs/PATH.md`'s "Where the user is asked" section (lines 142-163, quoted in
full in the delegation message) is the authoritative design; both target format docs
(`return-metadata-file.md`'s "Field Specifications" area, alongside existing optional fields like
`memory_candidates`/`reflection`/`proposed_file_scope`, and `handoff-schema.md`'s "Field
Definitions" area, alongside `decisions_made`) should each gain one new `### user_decision
(optional)` subsection that **references** a single contract file rather than restating the
schema — per the task's own instruction "Write this contract once ... do not restate it per
agent." No existing contract file is an obvious fit by name (`context/contracts/` holds
`anti-analysis.md`, `wrap-up.md`, `reference-grounding.md`, `adversarial-verification.md`,
`recovery.md`, `phase-closure.md`, `pre-edit-gate.md`, `territory.md` — all hard-mode-only and
loaded conditionally); since the user-decision contract must apply in **base mode too** (it is
not gated on `hard_mode`), it belongs in `context/standards/` as a new standalone file (e.g.
`context/standards/user-decision-contract.md`), not inside `context/contracts/`.

### 6. Agent-contract sweep scope

`find agent-system/extensions -path "*/agents/*.md"` returns **65 files** across core + 19
extensions (cslib, email, epidemiology, filetypes, formal, founder, latex, lean, literature, nix,
nvim, present, python, typst, web, z3). Only agents reachable from `skill-orchestrate`'s Stage 1b
routing (`$RESEARCH_AGENT`/`$PLANNER_AGENT`/`$IMPLEMENT_AGENT`, resolved per task_type from each
extension's `manifest.json` `routing_agents` block, the same table Stage 1b and MT-2 both consult)
are actually dispatched with a generated dispatch file under this task's scope — dispatching a
`Dispatch file` section onto e.g. `founder/agents/legal-council-agent.md` or
`filetypes/agents/docx-edit-agent.md` would be a wasted/incorrect edit if those agents are never
`$RESEARCH_AGENT`/`$PLANNER_AGENT`/`$IMPLEMENT_AGENT` targets. **The sweep must walk each
manifest's `routing_agents` table (mirroring Stage 1b's own resolution), not iterate the file
list blindly**, and the "report negatives" instruction should be read as: for every task_type
each manifest declares, name its resolved research/plan/implement agent, and confirm each
resolved agent file gets the new section — an extension with no `routing_agents` block at all (or
whose task types route to core's three base agents) is itself a valid negative to report. Note
also that `reviser-agent`, `spawn-agent`, `code-reviewer-agent`, and `meta-builder-agent` ARE
dispatched by `skill-orchestrate` (Stage 5a/5b/6, `subagent_type: "reviser-agent"` at
SKILL.md:2187/2313) but **never through a Stage-3.5-backed call site** (§2) — they should be
explicitly named as out-of-scope negatives in the sweep report, not silently omitted.

### 7. Runtime-file registration for `.dispatch/`

`context/standards/orchestrator-runtime-files.md`'s class table has two dispositions:
**Ephemeral** (no freshness gate on read — `.lock/`, `.orchestrator-loop-guard`,
`.orchestrator-churn-state.json`, `.drift-inspection.json`, etc.) and **Durable provenance**
(freshness-gated — `.orchestrator-handoff.json`, `.return-meta.json`). `.dispatch/{seq}.md` is a
write-once, read-once-by-the-dispatched-agent scratch file with **no downstream freshness-gated
re-read** (nothing re-reads an old dispatch file after its one dispatch completes) — it fits the
**Ephemeral** class by the same "no freshness gate, corruption risk if git-restored" rationale (a
restored stale dispatch file could point an agent at a phase/plan-round that no longer exists).
It should be added to: (a) the class table (new row, `.dispatch/{seq}.md`, ephemeral, directory
class like `.lock/`); (b) `.gitignore`'s ephemeral block as `**/.dispatch/`; (c)
`context/standards/git-staging-scope.md`'s `ephemeral_excludes` array (both copies, lines ~25-30
and ~165-170) as `":(exclude)${task_dir}/.dispatch/"`; (d)
`scripts/check-runtime-file-tracking.sh`'s `EPHEMERAL_PROBES` array (probe with a file inside it,
matching the `.lock/holder.json` pattern, e.g. `${PROBE_DIR}/.dispatch/1.md`).

### 8. "The reaper" — no clean existing home; a real gap to flag

Unlike the other per-task ephemeral files (each a **singleton**, overwritten in place or `rm -f`'d
exactly once at Stage 8 full-loop termination), `.dispatch/{seq}.md` **accumulates one new file
per dispatch** for the entire life of a task — a long-running hard-mode task with 20 phase
dispatches would leave 20 files behind. `scripts/reap-session-runtime-files.sh` explicitly and
deliberately does **not** recurse into `specs/{NNN}_{SLUG}/` — its own header comment states
per-task runtime files "are already correctly isolated" (meaning: cleaned up by the owning
skill's own Stage 8, not by this reaper). `task-lock.sh reap` only touches `.lock/`. There is
**no existing mechanism that ages out or bulk-deletes a growing per-task directory**. Two options
for the plan to decide between: **(a)** mirror the singleton files' lifecycle — `rm -rf
"${task_dir}/.dispatch/"` once at Stage 8 (loses per-dispatch audit trail across cycles, but
matches every existing per-task ephemeral file's disposition and needs no new reaper); **(b)**
treat it as a genuinely new per-task-growing ephemeral class needing a `find ... -mtime +N -delete`
style sweep, either folded into `skill-refresh`'s existing Step 4.5 (currently
session-scoped/repo-root-only — would need a second, task-scoped pass) or a new small reaper
script. Given `.dispatch/` files have no audit value once their one dispatch completes (they are
inputs, not outcomes — the outcome lives in `.return-meta.json`/`.orchestrator-handoff.json`,
both durable-provenance already), **(a) is the simpler, more consistent choice** and is
recommended, but this is a design decision the plan must state explicitly rather than leave
implicit.

## Decisions

- Treat "5 single-task Stage 4 sites" (task description) / "8 dispatch sites" (`PATH.md`) as
  *logical recipe* counts; the plan's acceptance criteria must additionally require all **11**
  physical `Run **Stage 3.5**` occurrences be gone from `SKILL.md` after the edit.
- Scope the four/six auxiliary dispatches (H4 re-verification, Stage 5a fork+reviser, Stage 5b
  audit, Stage 6 fork+reviser+re-implement) as explicitly **out of scope** — they keep inline
  prompts.
- `dispatch_seq` and `dispatch_start_ts` are caller-minted/caller-stamped, not
  script-generated; the script receives them as inputs (`--seq N` is already in the stated CLI
  signature; `dispatch_start_ts` should be clarified as a value the script records, not computes).
- `user_decision` gets its own new standalone contract file under `context/standards/` (not
  `context/contracts/`, since it must apply in base mode, unlike every existing contract file).
- The agent-contract sweep is manifest-`routing_agents`-driven, not a blind file-list iteration;
  `reviser-agent`/`spawn-agent`/`code-reviewer-agent`/`meta-builder-agent` are explicit
  out-of-scope negatives (dispatched by `skill-orchestrate`, but never via a Stage-3.5-backed
  site).
- Recommend `.dispatch/` directory be `rm -rf`'d at Stage 8 (mirroring the other per-task
  ephemeral singletons) rather than inventing a new age-based reaper, pending planner
  confirmation.

## Risks & Mitigations

- **Risk**: implementer edits only 5 (or 8) of the 11 physical call sites, leaving some inline
  Stage 3.5 prose live. **Mitigation**: acceptance test greps `SKILL.md` for
  `Run \*\*Stage 3.5` post-edit and requires zero matches; a second grep for `subagent_type` at
  each of the (now unchanged) 11 line numbers confirms the fixed pointer prompt shape.
- **Risk**: the continuation dual-form jq expression is hand-copied into the new script and
  silently drifts from `orchestrate-triage-classify.sh`'s `continuation_ok` predicate (a defect
  class the codebase already annotates as having happened once). **Mitigation**: the plan should
  either have the new script source a shared helper function for this resolution, or byte-diff
  the jq expression against the existing one in a test.
- **Risk**: `.dispatch/` accumulation with no cleanup mechanism silently grows `specs/` on
  long-running hard-mode tasks (each phase dispatch leaves a file). **Mitigation**: implement the
  Stage-8 `rm -rf` recommended in Findings §8 as part of this task, not deferred.
- **Risk**: agent-contract sweep misses an extension because its `routing_agents` block uses a
  compound task_type (e.g. `present:grant`) that a naive per-extension grep skips.
  **Mitigation**: reuse `manifest-routing-lib.sh`'s own resolution functions (`routing_lookup`)
  rather than re-deriving routing logic for the sweep.
- **Risk**: `user_decision`'s new contract file is placed in `context/contracts/` by convention
  with the other hard-mode contracts, then silently gated on `hard_mode` by a downstream reader
  that assumes everything in that directory is hard-mode-only. **Mitigation**: place it in
  `context/standards/` as identified in Findings §5, and have the dispatch file inject its
  reference unconditionally (not inside the `hard_contracts_block` conditional).

## Context Extension Recommendations

- **Topic**: dispatch-site inventory for `/orchestrate`. **Gap**: no single existing doc lists all
  11 physical Stage-3.5 call sites with their line numbers and distinguishing context-object
  shape (the closest is the summary table at SKILL.md:4095-4099, which only lists 3 rows and
  omits the partial/hard-branch/MT distinctions). **Recommendation**: once this task lands, fold
  the "8 logical / 11 physical sites, 4 out-of-scope auxiliary sites" enumeration into
  `docs/architecture/orchestrate-state-machine.md` (already the designated home for narrative
  moved out of `commands/orchestrate.md` per task 145) so a future refactor doesn't have to
  re-derive it by grep.

## Appendix

### Search queries / commands used

- `grep -n "Run \*\*Stage 3.5" SKILL.md` (11 hits, enumerated in Findings §2)
- `grep -n "subagent_type" SKILL.md` (full call-site enumeration)
- `sed -n` reads of SKILL.md ranges: 520-590 (`resolve_cycle_artifact_number`), 759-1030 (Stage
  3.5 full text + first two Stage 4 sites), 1100-1270 (plan-phase sites), 1264-1443 (implement
  hard branch), 1570-1720 (partial state, both sub-states), 2160-2340 (Stage 5a/5b/6 auxiliary
  dispatches)
- `sed -n '280,330p' scripts/skill-base.sh` (`skill_read_artifact_number`)
- `grep -n "routing_lookup_flat" -A 25 scripts/lib/manifest-routing-lib.sh`
- `sed -n '1,120p' context/standards/orchestrator-runtime-files.md` (class table, full)
- `sed -n '1,55p' .gitignore`; `grep -n ... context/standards/git-staging-scope.md`
- `sed -n '1,60p' scripts/check-runtime-file-tracking.sh`
- `grep -n "reap\|cleanup" scripts/reap-session-runtime-files.sh`, `skills/skill-refresh/SKILL.md`
- `grep -n "^##" context/formats/return-metadata-file.md docs/architecture/handoff-schema.md`
  (confirmed no existing `user_decision`)
- `find agent-system/extensions -path "*/agents/*.md"` (65 files enumerated)
- `grep -n "Target design: the thin lead\|Where the user is asked" -A 60 specs/PATH.md`
- `jq '.active_projects[] | select(.project_number==146)' specs/state.json`

### References

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` lines 520-590, 759-2340,
  3320-3420, 4095-4099
- `agent-system/extensions/core/scripts/skill-base.sh` lines 280-330
- `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh` lines 53-260
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh`,
  `orchestrate-triage-classify.sh` (style/precedent for the new script's doc-header conventions)
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`
- `agent-system/extensions/core/context/standards/git-staging-scope.md`
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh`
- `agent-system/extensions/core/scripts/reap-session-runtime-files.sh`
- `agent-system/extensions/core/context/formats/return-metadata-file.md`
- `agent-system/extensions/core/docs/architecture/handoff-schema.md`
- `agent-system/extensions/core/agents/{general-research-agent,planner-agent,
  general-implementation-agent,reviser-agent,spawn-agent,code-reviewer-agent,
  meta-builder-agent}.md`
- `specs/PATH.md` ("Target design: the thin lead", "Where the user is asked", Stage A table)

# Implementation Path

*Rewritten 2026-09-02 from a full re-survey of the agent system after the orchestrate-centric
consolidation (116 → 117-127, 135) landed. Supersedes every earlier revision of this file, all of
which described a Stage 0-6 structure whose tasks are now complete, abandoned, or renumbered. The
prior text survives in git history; nothing from it is carried forward except the standing rules
at the end.*

*Second pass, same day: three decisions recorded (batch of one; the orchestrator never asks on its
own; a bounded Workflow spike after Stage A), and the backlog manifest **applied** to
`state.json` — 145-148 created, 143/88/142/144/72 revised, 138/53/100/42 abandoned into
successors, three stale `file_scope` entries removed, `TODO.md` regenerated.*

**Goal (two halves, in priority order)**

1. `/orchestrate` is the only lifecycle entry point, driven by flags. **Done** in shape:
   `/research`, `/plan`, `/implement` are deleted (124); hard mode and team mode are folded into
   the single engine (117-123); phase forcing works in single-task mode (126). Two deletion tasks
   remain (125, 127).
2. The orchestrator is **token-cheap by construction**: it delegates, reads back compact verdicts,
   asks the user only when a decision is genuinely the user's, and otherwise carries almost
   nothing in context. **Not done.** The consolidation moved logic *into* the engine file without
   thinning it, and the engine is now the single largest per-invocation context cost in the
   system. Everything in Stage A below is about this.

---

## Where things stand (measured 2026-09-02, not inherited)

| Surface | Size | Loaded when |
|---|---|---|
| `skills/skill-orchestrate/SKILL.md` | **293,977 B (~74k tokens)** | every `/orchestrate` |
| `commands/orchestrate.md` | 46,874 B (~12k tokens) | every `/orchestrate` |
| CLAUDE.md chain + eager rules (`measure-eager-context.sh`) | 63,973 B (~16k tokens) | every session |
| **Total before the first dispatch** | **~405 KB, ~100k tokens** | |

The engine file has **grown 56%** (188 KB → 294 KB) since task 88 was filed against it, because
117-123 merged the hard-mode residue and the team fan-out into it. Task 88's "~83.5k baseline" is
stale; the honest figure is ~100k.

**Inside the engine** (section split verified fence-safe; zero headings inside code fences):

| Region | Bytes | Runs when |
|---|---|---|
| Single-task Stages 1-8 (`## Execution Flow`) | **~183,000** | only when exactly one task number is given |
| of which Stage 4 state handlers | 52,282 | |
| of which Stage 5 handoff reading | 25,439 | |
| of which Stage 2 loop guard init | 21,436 | |
| of which Stage 3.6 / 3.6a team fan-out | 19,414 | only under `--team` |
| of which Stage 5b churn / three-strikes | 4,918 | only under `--hard` |
| Multi-task Stages MT-1..MT-5 (`## Multi-Task Mode`) | **~111,000** | only when 2+ task numbers are given |
| `## MUST NOT` sections | ~10,000 | always |

Both engines load on every invocation; Stage 0 line 35 then skips one of them. The
mode-gating convention from 87 (`<!-- branch-gated:begin -->`) exists and is used by **zero**
files other than its own doc.

**Per-cycle cost is not the ~450 tokens the Context Flatness section claims.** The lead itself
authors every dispatch prompt, interpolating the full task description (open-task average
**4,612 B, max 11,598 B**) plus memory context, literature briefing, hard-contract block, and
handoff path, three near-identical recipes at `SKILL.md:3769-3808`. A five-task wave therefore
costs the lead **25-60 KB of self-authored prompt text per cycle**, all retained, before a single
verdict or handoff is read. This, not the handoff reads, is why a 5-task batch was observed to
exhaust most of its context before the second dispatch (142's filing).

**The two engines have drifted apart.** Multi-task mode lacks the handoff staleness and
`dispatch_seq` identity gates (143, a live correctness defect), lacks phase forcing and the
artifact-round advance (138), and lacks team fan-out. Single-task mode has all of them. Every
feature added to one path is a parity bug in the other until someone notices.

**Three smaller facts worth recording:**

- `commands/orchestrate.md` carries a 28,393 B `### MULTI-TASK DISPATCH` section that its own
  text labels "illustrative of the contract, not code this file itself runs". It costs ~7k tokens
  per invocation and executes never.
- `--hard` is parsed and stripped by `parse-command-args.sh:119,179` and consumed by the engine
  (63 `hard_mode` references), but is **absent from the Options table** in `orchestrate.md`. It
  is undocumented, not gone.
- The engine's lazy references point at ~520 KB of context/docs (`task-lock.md` 88 KB,
  `batch-orchestration-guardrails.md` 79 KB, `batch-admit-schema.md` 54 KB,
  `handoff-schema.md` 51 KB). Any cycle that follows one pulls it in whole.

Deploy state: `.claude/` is byte-identical to the source store for both orchestrator files.
`check-deploy-freshness.sh` reports clean. The 240 MB literature virtualenv is still untracked in
the source store and still shows in `git status` (unchanged from the prior survey; still unfiled).

---

## Target design: the thin lead

The design principle, stated once so every task below can cite it: **the lead never reads,
authors, or reasons about anything a script or a dispatched agent could own.** Its whole job per
cycle is four moves, and its context grows by the size of three small JSON objects per task.

### One engine, batch of one

Single-task mode is deleted. `/orchestrate 42` is a batch whose wave table has one row. Every
capability that exists only in the single-task engine today becomes a per-dispatch option in the
one engine:

| Capability | Lives today | Lives after |
|---|---|---|
| Phase forcing (`--research/--plan/--implement`) | single-task Stage 2b | cycle-plan script consumes `force_phases` per task (138 gap 1) |
| Team fan-out (`--team`) | single-task Stage 3.6/3.6a | a `team` flag on one dispatch row; the fan-out helper is a script the dispatch builder calls |
| Hard-mode churn / burnout counters | single-task Stage 2 + 5b | `orchestrate-churn.sh`, called from the postflight script when `hard_mode` |
| Loop guard / cycle budget | single-task Stage 2 + 7, MT-3 | cycle-plan script; one counter, one file |
| Handoff staleness + `dispatch_seq` gates | single-task Stage 5 only | postflight script, both paths, by construction (143) |

This is the single largest lever available, larger than 88's mode-gating ever was, and it
retires the parity-drift defect class outright rather than fixing instances of it.

### The four moves per cycle

```
1. plan     = $(orchestrate-cycle-plan.sh --session $sid --flags ...)      # one JSON object
2. for each row in plan.dispatch: Agent(subagent_type=row.agent, model=row.model,
                                        prompt="Read {row.dispatch_file} and execute it.")
   -- all rows in ONE message --
3. for each dispatched task: result=$(orchestrate-cycle-postflight.sh $task $sid)  # one JSON line
4. continue; or, only if some result.verdict == ask_user, relay that agent's question once
   (batched at cycle end); or stop when plan.stop is set
```

| Script | Absorbs (from the engine's inline prose/bash today) | Returns |
|---|---|---|
| `orchestrate-cycle-plan.sh` (**147**) | status refresh, heartbeat, all-terminal check, eligibility, admission (`batch-admit`), classification (`triage-classify`), lock acquire, `dispatch_seq` mint + window stamp, preflight status write, cycle/budget counters, redeploy-checkpoint decision, `force_phases` per task, missing task-dir creation | `{cycle, dispatch:[{task, phase, agent, model, dispatch_file, team}], deferred:[{task, reason}], blocked:[..], stop: null\|{reason, message}}` |
| `orchestrate-build-dispatch.sh N phase` (**146**) | Stage 3.5 in full (memory retrieval, `--lit` briefing, hard-contract block, effort note, model), territory, artifact round, continuation pointer, handoff path, the user-decision contract text; writes `specs/NNN_slug/.dispatch/{seq}.md` | `{dispatch_file, model}` |
| `orchestrate-cycle-postflight.sh N` (**143**, revised) | handoff read with mtime + `dispatch_seq` gates, return-meta recovery (now seq-checked), phase-count corroboration, writer-contract-aware defect recording, `user_decision` relay, status transition with monotonic clamp, artifact link, artifact-round advance, `modified_files` vs `file_scope` excursion advisory, scoped commit, MT-state update, lock release | `{task, phase, status, phases_completed, phases_total, verdict: ok\|defer\|blocked\|failed\|ask_user, user_decision?, note}` |

The dispatched agent reads its dispatch file. The lead never sees a task description, a memory
block, a briefing, or a contract again. The three scripts already have precedents in the repo
(`orchestrate-stage5-gates.sh`, `orchestrate-stage5-postflight.sh`, `orchestrate-triage-classify.sh`);
this is the same shape applied to the whole loop.

### Where the user is asked (decided 2026-09-02)

**The orchestrator never asks on its own, and never decides.** A run proceeds to the end
uninterrupted by default. The engine's own decision points — self-modifying or colliding
candidates, budget exhaustion, blockers, deploy-pending completions — stay exactly as autonomous
as today (defer in sequence, stop with an honest message, escalate through the existing blocker
dispatch), and the opt-in flags (`--allow-self-modifying`, `--allow-scope-collision`,
`--continue-budget`) remain the way to pre-answer them. There is no `--no-ask` flag because
there is nothing to switch off.

Decisions belong to the dispatched agents. A research, planner, or implementation agent decides
on its own and records the decision with its reasoning in its artifact. Only when a choice
genuinely requires the user's judgment — a preference the artifacts cannot infer, an external
cost or risk the user must accept, an ambiguity research cannot resolve — does it set
`user_decision: {question, options, recommended, blocking}` in its return metadata. Agents are
told to look for such choices and to avoid raising them unless actually needed. The postflight
script relays the field as a verdict; the lead's only role is to put the question to the user
once, batched at the end of the cycle after every other task has progressed, write the answer to
`specs/NNN_slug/.decisions.json`, and carry it into the next dispatch file. A non-blocking
decision proceeds on the agent's recommendation and is surfaced for review in the consolidated
output. The contract is written once (146) and referenced from every agent, never restated.

### Budgets (become gates, not aspirations)

| File | Today | Target | Gate |
|---|---|---|---|
| `skills/skill-orchestrate/SKILL.md` | 293,977 B | **≤ 20,000 B** | per-file ceiling in verify-deploy (142) |
| `commands/orchestrate.md` | 46,874 B | ≤ 8,000 B | same |
| Lead context growth per task per cycle | 5-12 KB authored + reads | ≤ ~1 KB (three JSON objects) | measured on a 5-task batch, recorded in 142's summary |
| Eager load before first dispatch | ~100k tokens | **≤ 25k tokens** | 142 |

Narrative, rationale, incident history, and exception taxonomies move to
`docs/architecture/orchestrate-state-machine.md` and the existing schema docs, which the lead is
forbidden to read during the loop. The `## MUST NOT` sections shrink to a list; their 9 KB of
branch enumeration is architecture documentation, not runtime instruction.

### A note on the harness Workflow tool

Claude Code now ships a `Workflow` tool: a deterministic JavaScript script that fans `agent()`
calls out in the background with structured-output schemas, consuming zero lead context per step.
That is, structurally, the thin lead. Two reasons it is not the recommendation here: the script
cannot run shell (admission, locks, commits, status writes would all have to move into agents),
and its availability in the consuming repos' harness versions is unverified. **Decided**: one
bounded spike **after** Stage A lands, when the three cycle scripts exist and a workflow could
simply call agents that call them. Stage E; file it when 88 completes, not before.

---

## Stage A — Thin lead (critical path)

Ordered. Each task touches an orchestrator-critical path and therefore takes the
designated-candidate slot: they serialize one per cycle whether batched or not. The
`dependencies[]` chain below makes one `/orchestrate` invocation carry the whole stage.

| # | Task | State | What lands | Saving |
|---|---|---|---|---|
| A.0 | **125** delete base lifecycle skills | planned | Pure deletion; its plan's Phase 7 also sweeps `orchestrate.md`, so it must precede A.1 | dead surface |
| A.1 | **145** slim `commands/orchestrate.md` | created | Delete the illustrative `### MULTI-TASK DISPATCH` block and the consolidated-output template; keep Arguments, Options (add the undocumented `--hard`), STAGE 0 parse + dispatch, checkpoints. Target ≤ 8 KB | ~10k tokens/invocation, zero risk |
| A.2 | **146** `orchestrate-build-dispatch.sh` + pointer prompts + user-decision contract | created | Stage 3.5 becomes a script writing `.dispatch/{seq}.md`; all eight dispatch sites send a fixed pointer prompt; agent contracts gain "read your dispatch file first" and the `user_decision` contract; threads the artifact round | the per-cycle authored-prompt cost, immediately, on both engines |
| A.3 | **147** `orchestrate-cycle-plan.sh` | created | MT-3 steps 1-4.5 and MT-4's per-task preflight/mint collapse into one script returning the dispatch plan; consumes `force_phases` per task; creates missing task dirs | MT-3 (35 KB) + half of MT-4 leave the engine |
| A.4 | **143** `orchestrate-cycle-postflight.sh` | revised (widened) | 143's two gates are the seed; the script also absorbs recovery (now seq-checked), corroboration, writer-contract-aware recording, `user_decision` relay, status clamp, artifact link + round advance, excursion advisory, scoped commit, MT-state update, lock release | remainder of MT-4 + MT-5 (56 KB) leave the engine; 53, 138, 100 close |
| A.5 | **148** port single-task-only features into the one engine | created | `--team` per row via `orchestrate-team-fanout.sh`; hard-mode counters into `orchestrate-churn.sh`; one loop-guard counter; drift/blocker dispatches as next-cycle rows; a single task number routed through the batch path behind a flag | prerequisite for A.6 |
| A.6 | **88** delete the single-task engine; rewrite `SKILL.md` as the four-move loop | revised (replaced) | Stages 1-8 deleted; MT-1..5 replaced by the loop above; narration moved to `docs/architecture/`; `## MUST NOT` reduced to a list; ≤ 20 KB. The original mode-gating premise (single-task is the hot path) is inverted by the default use and is dropped | **~70k tokens/invocation** |
| A.7 | **142** orchestrator context budget: measure and lock | revised (narrowed) | Baseline captured (numbers above), re-measured after each landing; per-file ceilings for the two orchestrator files and an eager-load ceiling wired into verify-deploy (absorbs 42); a 3-task batch's per-cycle growth measured and recorded | prevents regrowth |

**Dependency chain, applied in `state.json`**: 145←[125]; 146←[145]; 147←[146]; 143←[147];
148←[143]; 88←[148]; 142←[88]. 88's former edges [87, 127] are dropped; 127 no longer gates it.

**Why A.2 before A.3.** The dispatch-file builder is independent of the loop rewrite and lands
the per-cycle saving on the engine *as it exists today*. If Stage A stalls after A.2, multi-task
runs are already materially longer-lived.

**Why not just mode-gate (the 88 approach).** Mode-gating leaves both engines on disk, keeps the
parity-drift class alive, and saves ~26k of the ~100k. Deleting one engine and scripting the
other saves ~70k and removes the class. 87's convention remains useful for `--team`/`--hard`
residue if any prose survives in the thin file, and for 89/44.

---

## Stage B — Correctness and throughput for wide batches (independent, batchable)

These make the default (many tasks at once) safer and wider. None touches `SKILL.md`; all can run
alongside one Stage A member.

| # | Task | Op | Note |
|---|---|---|---|
| B.1 | **141** relay admission verdict in dry-run report | keep | Small; `--dry-run` is the surface used to compose batches and it currently lies about serialization. Self-modifying (dry-run-report is on the critical-path registry) |
| B.2 | **144** narrow coarse `file_scope` declarations | revised (addendum) | The three stale `general-implementation-hard-agent.md` scopes (76, 136, 139) are already removed at the state level; 144 verifies none remain and records the "scope unknown before research" convention. 88's `context/patterns/` entry was replaced with its rewrite; 44's `core/context/` root is the widest coarse declaration left |
| B.3 | **139 → 140** forbid concurrent-writer history rewrites; hook predicate | keep | The motivating incident was a five-agent batch. Directly proportional to batch width |
| B.4 | **14** implementation agents: no fan-out, terminal status, marker/commit sync | keep | Agent-contract side only. Serialize after 139 (both edit `general-implementation-agent.md`) and not alongside 146 (same file) |
| B.5 | **20** `/todo` phantom build_errors + `MAX_ARG_STRLEN` archive failure | keep | The second defect is data-loss class and arrives at ~15-25 archived tasks; the backlog is about to shed that many |
| B.6 | **51** runtime files out of `specs/` root; wire reap into `/todo` | keep | Coordinate with 147/143, which own the multi-state file's writer; land after 143 or declare the new path in 147 |
| B.7 | **91 → 136** plan Status-line diagnosis; producer-side ownership boundary | keep | Independent of the engine |
| B.8 | **72** teammate metadata ownership + SubagentStop correlation | re-pointed (deps → 148) | Fix against `orchestrate-team-fanout.sh` and `orchestrate-build-dispatch.sh`. Low priority until `--team` is used in anger again |
| B.9 | **13** gate-out auto-repair reporting | keep | Independent; low |
| B.10 | **129** `\b` grep audit | keep | Independent; low. Depends on 128 (done); eligible |

---

## Stage C — Other context-budget items (independent, low priority)

| Task | Op | Note |
|---|---|---|
| **44** slim `commands/task.md` | keep (planned, eligible: 87 done) | ~6k tokens per `/task`; plan is good; run whenever a batch has room. Its `core/context/` scope is the widest coarse declaration in 144's list; narrow it there first |
| **89** mode-gate `skill-literature` / `skill-distill` | keep | ~25k tokens per `/literature` and `/distill`; mechanical; outside the engine |
| **42** verify-deploy context gates | abandoned → absorbed into 142 | Item (a) is a regression guard for an already-held state; item (b) is exactly 142's lock. One task, not two |

---

## Stage D — Extension and repo work (unrelated to the orchestrator)

Kept as filed; sequenced by whatever batch has room. None are on the path.

| Task | Note |
|---|---|
| **113** briefing SIGPIPE crash | Hard crash of `--lit` in repo mode; cheap; run early in any batch |
| **74 → 75 / 76** LaTeX build guard | 76's scope must drop the deleted `-hard` agent file; 76 also touches `skill-base.sh` (critical path) |
| **137** lean agent artifact skeletons | Extension-side; produces validator-clean artifacts |
| **134** `/tag` reachability gate | Small; user-only skill |
| **29 → 30** `.mcp.json` from manifests; obsidian memory server | Deploy-engine Lua work |
| **43** email safety context decision | Extension-internal |
| **39** Zotero metadata resolution | Literature; planned |
| **45** `<leader>al` global update | Neovim Lua UI |
| **27** delete dead `.opencode` router | Pure deletion; cheap |
| **22** `.opencode` freeze: silence spam, record policy | Stranded at `[RESEARCHING]` with no task directory; safe to re-dispatch |

---

## Stage E — Optional, after Stage A

| Item | Note |
|---|---|
| Workflow-tool spike (approved, unfiled until 88 lands) | One bounded task: a `/orchestrate --workflow` path that hands the wave table to a `Workflow` script whose agents call the three cycle scripts. Measure lead context (should be ~zero) and confirm harness availability in each consuming repo before deciding anything |
| Lazy-reference diet | The ~520 KB the engine points at. After A.6 the thin lead cites only the three scripts and the state-machine doc; audit what remains referenced from agent files instead |

---

## Backlog operation manifest (applied 2026-09-02)

| Task | Operation | Reason |
|---|---|---|
| **145** `slim_orchestrate_command` | CREATED; deps [125] | A.1; zero-risk ~10k saving; also documents `--hard` |
| **146** `build_orchestrate_dispatch_builder` | CREATED; deps [145] | A.2; removes the lead's authored-prompt cost on both engines now; carries the user-decision contract |
| **147** `build_orchestrate_cycle_plan` | CREATED; deps [146] | A.3 |
| **143** | REVISED into "Build orchestrate-cycle-postflight.sh"; deps [147] | A.4; its two gates are the seed of the script |
| **148** `port_single_task_features_to_batch_engine` | CREATED; deps [143] | A.5 |
| **88** | REVISED into "Delete the single-task engine and rewrite skill-orchestrate as the four-move loop"; deps [148] (was [87, 127]) | A.6; original premise inverted |
| **142** | REVISED into "Orchestrator context budget: measure and lock" (absorbs 42); deps [88] | A.7 |
| **138** | ABANDONED → 147 (gap 1), 143 (gap 2), 146 (gap 3) | all three gaps close by construction in one engine |
| **53** | ABANDONED → 143 | recording order is a postflight-script concern; its live-predecessor evidence becomes 143's fixtures |
| **100** | ABANDONED → 143 | direction (a) is one comparison in the postflight script; (b)/(c) stay unfiled until (a) quantifies the class |
| **42** | ABANDONED → 142 | item (a) already holds; item (b) is 142 |
| **144** | REVISED (addendum): stale-scope verification and the pre-research convention | B.2 |
| **72** | REVISED (addendum): re-pointed to the fan-out and dispatch-builder scripts; deps [148] (was [122]) | B.8 |
| **76, 136, 139** | `file_scope`: deleted `general-implementation-hard-agent.md` entry removed | admission gate reads them |
| 125, 127, 141, 139, 140, 14, 20, 51, 91, 13, 129, 44, 89, and all Stage D | KEPT as filed | |

Net: 4 created, 6 revised, 4 abandoned into successors; open count 36 → 36. Every capability
named in an abandoned task has a named successor line above. Wave table after regeneration:
wave 1 holds the independent work, wave 2 [145, 127, 30, 75, 76, 136, 140], then 146 → 147 →
143 → 148 → [88, 72] → 142.

---

## Recommended batches

**Batch 1 — clear the deck (one invocation, dependency-ordered):**

```
/orchestrate 125, 141, 144, 20, 113, 27
```

Two self-modifying members (125 via its `orchestrate.md` sweep; 141 via `dry-run-report.sh`), so
one defers a cycle; the other four are free. Run `--dry-run` first and read the raw admission
verdict rather than the report's prose, since 141 is the task that fixes the report's prose.

**Batch 2 — Stage A as one chain:**

```
/orchestrate 145, 146, 147, 143, 148, 88, 142
```

Total order by design (every member touches `SKILL.md` or another critical path); seven cycles
minimum. Pair each cycle with one free Stage B/D task if wanted (139 → 140, 91 → 136, 51, 13,
129, 137, 134). Or simply hand both batches to one invocation — the chain sequences itself.

**Do not** run 44 alongside anything touching `core/context/` until 144 narrows its scope. **Do
not** run 72 before 148. **Do not** run 14 alongside 146 (both edit
`general-implementation-agent.md`). **Do not** run 76 alongside a Stage A member (it touches
`skill-base.sh`).

---

## Decisions

**Recorded 2026-09-02:**

1. **Batch of one.** Confirmed. Stage A deletes the single-task engine; team, hard and phase
   forcing survive as per-dispatch options.
2. **The orchestrator never asks and never decides.** Confirmed. Runs proceed to the end
   uninterrupted by default; only an agent-surfaced `user_decision` reaches the user, and agents
   are told to raise one only when the user's judgment is genuinely required.
3. **Workflow spike.** Approved, bounded, after 88 lands.
4. **Manifest applied** to `state.json`; `TODO.md` regenerated.

**Still open (answer whenever; none blocks Batch 1 or the first three Stage A tasks):**

5. **Team mode: keep or drop?** It costs ~5x per dispatch, its metadata-ownership defect (72) is
   unfixed, and it has been used rarely. Dropping it removes `orchestrate-team-fanout.sh` from 148
   and retires 72 outright. Keeping it costs one script and one fix.
6. **Hard mode: keep the stateful half?** Contract injection is cheap and script-side already.
   The churn/three-strikes counters and burnout breaker are the only reason `orchestrate-churn.sh`
   exists in 148. If hard mode is used only for its contracts, the counters can go.
7. **Let agents skip research.** Every task runs research → plan → implement today. Should the
   research agent be allowed to return "no research needed, proceed" for tasks whose description
   is already a specification (most defect filings here are), advancing straight to plan? Saves
   a full dispatch per such task; needs one verdict in the postflight script and a line in the
   research contract.
8. **Dry-run report.** Keep `orchestrate-dry-run-report.sh` as a human-facing surface (141 fixes
   it), or retire it in favor of `orchestrate-cycle-plan.sh --dry-run` printing its JSON? Keeping
   it means two renderings of one verdict to maintain.
9. **Consumer validation.** Should Stage A be declared done only after `<leader>al` reload and one
   real batch in a consuming repo (BimodalLogic or Theory), given every consumer runs this engine?

---

## Observations, unfiled

- `--hard` undocumented in `orchestrate.md`'s Options table while parsed and consumed (fold into
  NEW-F).
- cslib and lean manifests still declare four `routing_hard`/`routing_agents_hard` keys each. 121
  deliberately left lean's untouched and only pruned cslib's dead pairs; 127 owns the rest.
- The 240 MB `literature-pyenv/` virtualenv remains untracked and un-ignored in the source store
  (carried forward from the prior survey; one `.gitignore` line).
- Task 22 sits at `[RESEARCHING]` with no `specs/022_*` directory; the multi-task path has no
  `mkdir -p` (prior survey's observation, still true). 147 creates missing directories.
- The write-time task-reference hook fires on scratch files outside the repo tree (it blocked a
  throwaway script in the session scratchpad for containing "task 147"). Harmless, but its path
  filter could exempt `/tmp/**`.
- `validate-state.sh` fails on two fields its own writers produce: `abandon_reason` (every
  abandoned task since 31, including the four abandoned today) and `blocks_note` (106, 107,
  109). Same class as the `blockers` mismatch the prior survey recorded. Either add all three to
  `state-schema.json` or stop writing them; until then the gate-10 result carries no signal.
  Cheap; worth folding into 144 or 20 rather than filing separately.

---

## Standing rules (carried forward)

1. **Agent-system defects get filed here.** A fix in a consuming repo's `.claude/` is wiped on
   reload.
2. **Propose, then apply, across repos.**
3. **Verify by execution, not by reading.** This survey's own corrections: the "~450 tokens per
   cycle" claim was falsified by reading the dispatch recipe; the "83.5k baseline" was stale by
   56%; and 88's premise (single-task is the hot path) is the inverse of how the system is used.
4. **The lead never reads a report, plan, summary, description, or context file during the
   loop.** After Stage A this is a byte budget with a gate, not a MUST-NOT paragraph.

---

## Progress

*As of 2026-09-02.*

| Stage | Tasks | State |
|---|---|---|
| Consolidation (116 → 117-127, 135) | 117-124, 126, 128, 130-131, 133, 135 ☑ · **125, 127 ☐** | shape done; two deletions left |
| A — thin lead | 125 → 145 → 146 → 147 → 143 → 148 → 88 → 142 | **☐ critical path**; ~100k → ≤25k tokens eager, per-cycle authored text → ~1 KB/task |
| B — wide-batch correctness | 141, 144, 139→140, 14, 20, 51, 91→136, 72, 13, 129 | ☐ batchable |
| C — other budgets | 44, 89 (42 absorbed) | ☐ low |
| D — extensions/repo | 113, 74→75/76, 137, 134, 29→30, 43, 39, 45, 27, 22 | ☐ independent |
| E — optional | Workflow spike, lazy-reference diet | after A |

**Critical path now**: Stage A, headed by 125. Nothing upstream gates it. A.1 and A.2 each land a
measurable saving on their own; A.6 is where the file collapses.

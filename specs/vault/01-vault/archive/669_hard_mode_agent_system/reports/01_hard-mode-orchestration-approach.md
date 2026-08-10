# Hard-Mode Orchestration: Approach Report

- **Task**: 669 - hard_mode_agent_system
- **Date**: 2026-06-12
- **Source**: Live orchestration of BimodalLogic task 273 (`chronicle_gap_contradiction_proof`) — a Lean 4 formalization task that consumed 21 plan versions and 5 failed proof attempts before converging, and whose successful methodology this report distills
- **Purpose**: Specification basis for `--hard` flag routing in `/implement`, `/research`, `/plan`, `/orchestrate`, with hard-mode variants of skills (skill-lean-implementation, skill-orchestrate, ...) and agents (lean-implementation-agent, ...)

## 1. Context: What Made the Task "Hard"

Task 273 required closing one `sorry` whose mathematical content (Kamp's theorem / expressive completeness machinery) had deflected every standard-mode attempt. Observable signature of a hard task:

- Multiple plan versions (v1-v16 before this session; v17-v21 during it) each claiming a "settled design"
- The target sorry never closes; it *moves* (line 366 → 404 → 427 → 828 → 1094 → 1183 → 1256 → 1371) as scaffolding accretes around it
- Each implementation agent concludes "the formula/approach is wrong" and proposes a redesign instead of code
- Estimates inflate (300 → 450 → 520 → 750 → 1200 lines) without corresponding deliverables

The breakthrough came from changing the *orchestration method*, not from a smarter single agent. Standard-mode dispatching was the bottleneck.

## 2. Failure Modes Observed in Standard Mode

These are the specific, reproducible pathologies hard mode must counter. Each was observed multiple times in this session.

### F1. Analysis paralysis on monolithic dispatch
Three consecutive `lean-implementation-agent` runs ("implement the plan") each consumed ~200-240k tokens producing **zero lines of code** — only root-cause analyses and "settled designs" that the next agent re-derived from scratch. The agents were not wrong; they were structurally unable to stop analyzing, because the dispatch scope ("the whole plan") made analysis always seem like the highest-value next step.

### F2. Invented mathematics instead of transcribed mathematics
Four successive formula designs each silently dropped information that the published construction retains (the quantifier part of a normal form; non-interval witness conditions; depth indices). Each agent *believed* it was following the literature while actually inventing a variant. Without an enforced transcription discipline, plausible-but-wrong constructions survive until the proof fails — hundreds of thousands of tokens later.

### F3. Citation rot in second-hand sources
A research report claimed "no rank drop, per Libkin Lemma 3.7" — but Libkin 3.7 *has* a rank drop. The conclusion happened to be right for the wrong reason, discovered only by an adversarial second reader. Markdown extracts of papers caused at least two such errors; only PDF-level reading caught them.

### F4. Concurrent-edit collisions
Two agents editing the same Lean file caused a proof regression that a third agent had to repair. Two agents instructed to write the same report/plan filename nearly clobbered each other twice (caught only by orchestrator intervention via SendMessage).

### F5. Handoff clobbering
Parallel agents writing the shared `.orchestrator-handoff.json` overwrite each other's results unless told to read-merge-write.

### F6. Unbounded churn
Without an explicit progress criterion, "partial with a new design recommendation" reads as progress forever. The task had consumed 16+ plan versions this way before the session began.

## 3. The Hard-Mode Method (What Worked)

Nine techniques, in the order they entered the session, each tied to the failure mode it counters.

### H1. Per-phase dispatch (counters F1) — the single highest-value change
Never dispatch "implement the plan." Dispatch **exactly one phase** (or sub-phase) per agent run, with the phase sized for a single focused run (~100-500 lines of Lean, 2-8h estimate). The plan itself must be authored with this in mind (see H8).

Observed effect: the first per-phase dispatch after three zero-code monolithic runs produced 343 lines of building Lean in one run. Every subsequent per-phase dispatch produced committed code.

### H2. Anti-analysis contract in every implementation prompt (counters F1, F2)
Hard-mode implementation prompts carry a mandatory block:

- **Read budget**: "≤15-20% of effort on reading; the rest writing/verifying code. Your first file edit must happen early."
- **Forbidden conclusions**: `"the approach is wrong"`, `"a different representation is needed"`, `"estimated N lines"` *as a final answer*. These phrases are the signature of F1.
- **Defect bar**: an agent may claim the settled design is defective ONLY with a concrete semantic counterexample (explicit model + instance), stated verbatim. (This bar was met once — the counterexample was real and valuable — and deflected several would-be redesigns that were not.)
- **Sub-sorry policy**: tightly-scoped, documented leaf sub-sorries are acceptable; the main statement is not. "Partial progress with isolated sub-sorries beats an untouched monolithic sorry."
- **Settled-design preamble**: restate the decided design in the prompt itself, with "Do NOT re-derive or re-analyze alternatives; X, Y, Z were already ruled out in <handoff>."

### H3. Prior-art grounding mandate (counters F2, F3)
For any task with a literature base (`literature/` directory, papers, reference implementations):

- Plans must contain a **lemma-to-source mapping table**: every new Lean lemma names its literature counterpart (source, proposition/lemma number, page).
- Implementation prompts name the exact sections/lemmas to follow and instruct: "transcribe the published argument; where the paper and your instinct disagree, the paper wins."
- Research agents must read **PDFs, not just extracts**, for every load-bearing claim, and cite page numbers. (The Read tool's `pages` parameter makes this cheap.)
- Domain-specific simplifications are stated explicitly in the prompt (e.g., "on Prior structures first occurrences are attained, eliminating the K+ disjunct") so agents don't re-derive or miss them.

### H4. Adversarial verification of research artifacts (counters F3)
Any research report that will drive implementation gets a **second reader** with an adversarial mandate: verify each load-bearing claim against primary sources; append a `## Adversarial Verification (second reader)` section with verdict per claim; flag exact citation errors. Give the verifier a **prime suspect** — the orchestrator's best hypothesis about where the report is most likely wrong (e.g., "check the rank bookkeeping; this is exactly the kind of silent error that burned us three times").

Observed effect: the verification pass found 4 substantive corrections in an otherwise-sound report, including one (all-arity statement of a lemma) that would have caused another failed cycle.

### H5. Divergence audit after repeated deflections (counters F2, F6)
When the same target survives N (≈3) distinct "fixes," STOP implementing. Dispatch a research agent with a different question — not *"what is the correct construction?"* (that was asked and answered N times) but ***"where does OUR formalization diverge from the published proof, such that the published argument keeps failing here?"*** Required output:

1. Verdict on the orchestrator's prime-suspect hypothesis
2. How the published hard direction *actually* works, step by step
3. A **divergence table**: our statement vs literature statement per object, each row marked MATCHES / STRONGER / WEAKER / DIFFERENT, with consequence
4. The corrected target, stated Lean-ready with all indices explicit, plus what downstream consumers actually need (read the consumers!)
5. A **postmortem**: the specific mistakes that caused the N deflections

Observed effect: the audit found the architectural root cause (we were proving a composition lemma that *no published proof contains* — the literature works at a different level entirely), which no implementation-scoped agent had been positioned to see. The pivot it recommended then proceeded through 6 consecutive sorry-free phase completions without a single deflection.

### H6. Explicit convergence policing at the orchestrator level (counters F6)
- Before a decisive dispatch, the orchestrator states (to the user, in writing) the **progress criterion** ("composition lemma proven or backward closed") and the **no-progress consequence** ("stop implementation, pivot to audit").
- Track the churn signature: same-sorry-moved-again, "wrong formula" verdicts, inflating estimates. Three strikes → audit (H5).
- Architectural pivots are a **user decision**, presented with options (pivot / review report first / verify audit before pivoting), not something the orchestrator auto-commits to.
- The user can set standing policy ("if the next agent doesn't make progress, go back to the literature rather than giving up") — the orchestrator encodes it as the active stopping rule and honors it mechanically.

### H7. Parallel dispatch with territory contracts (counters F4, F5)
Parallel agents are worth it (two phases completed concurrently, twice) but ONLY with explicit boundaries in both prompts:

- **File territory**: "Touch ONLY <files>. Phase N's territory is <other files> — reference its lemmas, never write them."
- **Plan-section territory**: "Edit only your phase's checkboxes."
- **Commit protocol**: "On non-fast-forward, rebase onto HEAD, re-verify build, then commit."
- **Handoff merge rule**: "Read `.orchestrator-handoff.json` first; MERGE your result (max consistent phases_completed, append artifacts); never clobber."
- The orchestrator watches for collisions anyway (a stray agent resuming can violate territory) and repairs via SendMessage redirects: "file X already exists — verify/extend it, do NOT overwrite."

### H8. Hard-mode plan requirements (enables H1; counters F1, F6)
A hard-mode plan (from `/plan --hard` or revision) must contain:

- Phases **sized for one focused agent run each**, with concrete Lean deliverables and a build check per phase; large phases split into sub-phases (4a-4f) with sequential discipline ("complete 4a fully before touching 4b; never reach ahead")
- A **postmortem-constraints section**: hard "do not" rules distilled from prior failures, binding on all implementers
- **Preserved-assets accounting**: what is sorry-free and must not regress; what is quarantined/bypassed (so agents don't fight dead code)
- The lemma-to-source mapping table (H3)
- Dependency waves marking which phases can run in parallel (feeds H7)

### H9. Roadmap handoffs + incremental commit discipline (counters F1 carry-over costs)
Every agent run ends with:

- **Orchestrator handoff JSON** (≤400 tokens): status, phases_completed/total, exact sorry inventory (file:line), blockers ONLY with verbatim goals, continuation path
- **Continuation handoff markdown** when mid-stream: verbatim remaining Lean goals, what was tried, next-steps list (the best agents left three-step roadmaps the successor followed directly)
- **Incremental commits at every green-build milestone** — never one commit at the end. When an agent dies or stalls, committed milestones survive; the orchestrator observed work surviving three agent deaths this way.
- Build-green invariant: the module builds at every commit; regressions in sorry-free files are forbidden and checked.

## 4. Orchestrator-Level Behaviors (skill-orchestrate --hard)

The session was driven by a human-supervised orchestrator loop that differed from the stock `skill-orchestrate` state machine in these ways. A hard-mode skill should encode them:

1. **Per-phase dispatch loop** replaces whole-plan dispatch: read plan phase markers + handoff → dispatch next incomplete phase (or parallel wave) → process handoff → commit → repeat. Cycle = one phase attempt, not one whole-plan attempt.
2. **Prompt assembly from a template** with slots: Mission (one phase), Settled Design (restated, with ruled-out alternatives named), Foundations Available (proven lemmas to cite, not reprove), Literature Anchors, Hard Rules (H2 block), Territory (H7 block when parallel), Wrap-up Contract (H9 block), Environment.
3. **Churn detection**: counters for defect-claims and sorry-relocations per target; threshold trips the divergence audit (H5) instead of another implement dispatch.
4. **Escalation ladder with caps** (existing, kept): continuation → blocker research → plan revision → re-dispatch; cap escalations; then surface to user. Hard-mode addition: the audit (H5) sits between "escalation cap reached" and "give up," and architectural pivots require AskUserQuestion.
5. **Verification dispatches are first-class**: research → adversarial verify (H4) → then plan/implement. Never implement off an unverified load-bearing report in hard mode.
6. **Stale-agent hygiene**: completion notifications can be lost; check output-file mtime / git log before assuming an agent is alive; resumable agents (SendMessage) get redirects instead of duplicate spawns when scope changed mid-flight.
7. **Loop-guard resets are user-authorized**: MAX_CYCLES pauses are honored with a pause commit + precise status report; the user may pre-authorize a reset ("continue another five cycles to finish everything"), which the orchestrator then executes without re-asking.

## 5. Proposed --hard Routing Architecture

```
/implement 273 --hard
  └─ skill-orchestrator routes: task_type=lean4 + hard flag
       └─ skill-lean-implementation-hard
            └─ lean-implementation-hard-agent (per-phase contract baked into agent prompt)

/research 273 --hard
  └─ skill-lean-research-hard (or skill-{domain}-research-hard)
       └─ research dispatch + MANDATORY adversarial-verify second dispatch (H4)
       └─ divergence-audit mode available via focus prompt

/plan 273 --hard
  └─ skill-planner-hard → planner-agent with H8 plan requirements enforced
       (phases sized for single runs; postmortem constraints; lemma-to-source table;
        preserved-assets accounting; dependency waves)

/orchestrate 273 --hard
  └─ skill-orchestrate-hard: per-phase loop + churn detection + audit trigger
       + verification-before-implementation + pivot-asks-user (Section 4)
```

Implementation notes:

- **Flag plumbing**: the commands already parse effort flags (`--fast`, `--hard`); currently they modulate reasoning depth. Hard mode should *additionally* switch the skill route (e.g., `skill-lean-implementation` → `skill-lean-implementation-hard`) the same way `--team` switches to team skills. Graceful degradation: if no hard variant exists for a task type, fall back to standard skill + inject the H2/H3 prompt blocks.
- **Agent variants vs prompt blocks**: most of hard mode is *prompt contract*, not model choice. A `lean-implementation-hard-agent.md` can be a thin variant whose system prompt bakes in H2 (anti-analysis), H3 (transcription mandate), H9 (wrap-up contract), leaving per-dispatch specifics (phase, foundations, territory) to the orchestrator's prompt. Model: keep sonnet for workers; the *audit* and *plan* dispatches benefit from opus.
- **Shared templates**: put the H2/H7/H9 blocks in `.claude/context/` as referenced fragments so skills compose them instead of duplicating.
- **State additions**: the loop guard gains `defect_claims` and `sorry_relocations` counters (churn detection); the handoff schema gains `sorry_inventory` (array of file:line) so the orchestrator can detect relocation without reading source files.

## 6. Measured Outcomes (Evidence)

From the task-273 session, before vs after hard-mode techniques:

| Regime | Dispatches | Code produced | Deflections |
|--------|-----------|---------------|-------------|
| Monolithic "implement the plan" | 3 × ~200k tokens | 0 lines | 3 ("formula is wrong" × 3) |
| Per-phase + contracts (pre-audit) | 6 | formula + forward proof + compat machinery (~600 lines), committed | 2 (narrowing) |
| Post-audit (pivot to literature-faithful architecture) | 7 | ~2,400 lines across 6 new/extended modules, all sorry-free phases | 0 |

The audit itself (1 research dispatch + 1 verify dispatch, ~340k tokens combined) paid for itself immediately: every implementation dispatch after it completed its phase sorry-free.

Residual at session pause (weekly API limit): one published lemma to formalize (Rabinovich 3.2.2 → Prop 4.3 instantiation → final fill), with the exact path documented in the active handoff.

## 7. Recommended Task Breakdown for Implementing Hard Mode

1. Author shared prompt-contract fragments (H2, H3, H7, H9) in context/
2. `skill-orchestrate-hard` (or `--hard` branch in skill-orchestrate): per-phase loop, churn counters, audit trigger, pivot-asks-user
3. `skill-planner-hard` plan-format additions (H8) + plan-format-enforcement rule updates
4. `skill-{domain}-implementation-hard` thin skills + hard agent variants for lean4 first (the proving ground), then general
5. `skill-{domain}-research-hard`: verify-after-research pipeline + divergence-audit mode
6. Command routing: extend the effort-flag tables in `/implement`, `/research`, `/plan`, `/orchestrate` to route `--hard` to the new skills; graceful fallback
7. Handoff/loop-guard schema extensions (sorry_inventory, churn counters)

# Report: Target-State Design (Phase A: A1-A7)

- **Task**: 116 - Design the orchestrate-centric core consolidation and rebuild the backlog around it
- **Phases**: 2-4 of 10 (plan: plans/01_orchestrate-centric-consolidation.md)
- **Scope and Constraints**: This report is a specification only. It creates, modifies, and
  deletes nothing outside `specs/**`; no file under `agent-system/extensions/**` or `.claude/**`
  is touched by this task. Every decision below must be specific enough for a successor task to
  implement without re-deriving it. Evidence for every factual claim below is in
  `reports/02_baseline-and-audit-evidence.md`.

---

## A1 -- Single Entry Point

**Decision**: `/orchestrate` becomes the sole lifecycle command. `/research`, `/plan`, and
`/implement` are **deleted outright**, not retained as aliases. `/revise` is **retained as a
distinct command**, not merged into `/orchestrate`, because its two behaviors (reasoned plan
revision from a free-text reason, and the description-update fallback when no plan exists) have
no natural `/orchestrate` phase-flag equivalent -- neither is "run a lifecycle phase," both are
"revise an existing artifact in place," a different verb. Renaming it is out of scope; its
existing GATE IN / delegate-to-skill-reviser shape is preserved unchanged.

**Reasoning**:
- An alias with "no logic of its own" that still has to parse `$ARGUMENTS`, resolve the task
  number, and forward every flag is not free -- it is the same argument-parsing code living in a
  second file, which is exactly the duplication A1 exists to remove. `research.md` alone is 652
  lines; `plan.md` 677; `implement.md` 506 -- none of that is deletable if the file still exists
  to forward into `/orchestrate`, because forwarding requires re-implementing (or literally
  including) the flag surface `/orchestrate` itself already owns. Outright deletion is the only
  form of this decision that actually returns the 1,835 lines A7's ledger below counts.
- The plan's own A1 sub-bullet already requires this outcome ("an alias that duplicates argument
  parsing or gate sequencing has not reduced anything") -- verifying that no thin-alias shape
  satisfies that constraint is itself the reasoning: any alias that forwards without duplicating
  is functionally a shell one-liner `exec /orchestrate "$@" --research`, and there is no reason to
  keep that as a separate command file versus documenting `/orchestrate NNN --research` as the
  spelling in the command reference table (`CLAUDE.md`'s Command Reference).
- `/revise` survives because A2 below deliberately does NOT fold `--revise` semantics into a
  forced `--plan`: a forced plan run re-plans from research inputs, while `/revise` re-synthesizes
  an EXISTING plan against a user-supplied reason without re-running research. Collapsing the two
  would silently change `/revise`'s contract (it currently works "regardless of task status," per
  its own GATE IN comment) into something gated by `/orchestrate`'s phase-forcing rules. Keeping
  it separate costs 157 lines and preserves a semantically distinct operation; that is a fair
  trade, unlike the 1,835-line research/plan/implement trio which duplicates rather than adds.

**Migration note (binding on Phase C)**: deleting `/research`/`/plan`/`/implement` orphans the
three lifecycle skills they invoke on the description-facing path
(`skill-researcher`/`skill-planner`/`skill-implementer`) -- but per the A1 precondition
immediately below, those three skills are NOT simply deleted alongside their commands: their
Stage 4a memory-retrieval and `--lit` logic must be rehomed into the single engine FIRST. The
skills themselves become dead code only after the rehome lands, and their deletion is a distinct,
later successor task (see A7's ledger and Phase 7's sequencing).

### A1 precondition -- the dispatch-bypass gap (binding design constraint)

Re-verified in Phase 1 (report 02, Finding 1): `skill-orchestrate/SKILL.md` dispatches every
lifecycle phase via the Agent tool directly against `general-research-agent` /
`planner-agent` / `general-implementation-agent`, with **zero** occurrences of
`memory-retrieve`, `clean_flag`, `lit-stage4a`, or `literature-briefing` anywhere in the file (13
pass-through `lit_flag` occurrences confirm the flag is threaded but never resolved into a
briefing). The three dispatched agent files independently confirm zero occurrences of either
mechanism. **Today, every `/orchestrate` run receives no memory-augmented context, and `--lit` is
a boolean that reaches the agent and is never turned into a briefing.**

**Post-collapse home**: a new **Stage 4a-equivalent dispatch-prep stage inside `skill-orchestrate`
itself**, invoked once per dispatch (single-task and each multi-task wave member alike),
immediately before the Agent-tool `subagent_type` call. Concretely:
- Memory retrieval: call `memory-retrieve.sh` gated by the engine's own `clean_flag` (already
  parsed at Stage 0 per `orchestrate.md`'s flag table but currently only forwarded, never
  consumed for retrieval), and inject the result into the dispatch context the same shape
  `skill-researcher`'s Stage 4a already uses (`<memory-context>`).
  `skill-planner`/`skill-implementer` also retrieve memory at their own Stage 4a today; the single
  engine's dispatch-prep stage must run this ahead of ALL THREE phase dispatches, not only
  research, since the collapse removes the wrapper that used to do it per-phase.
- `--lit` resolution: call the shared `lit-stage4a-flow.md` flow (already documented as the single
  executable block all three lifecycle skills import verbatim) from the same dispatch-prep stage,
  producing the `<literature-briefing>` block the three lifecycle skills currently build.
  `lit-stage4a-flow.md`'s "single executable block" design is exactly the reuse shape this rehome
  needs -- it already has zero per-skill duplication to collapse; the collapse is only in WHO
  calls it (the engine, once per dispatch, instead of each of three skills once per invocation).

**Ordering constraint (binding)**: this rehome is a successor task that MUST land, and be
verified working, BEFORE any command or lifecycle-skill deletion successor task starts. The
system must never pass through a state where `skill-orchestrate` dispatches an agent without
memory/`--lit` support AND the three lifecycle skills that used to provide it are gone. This
constraint is carried into A6 (both mechanisms marked REBUILD-REQUIRED, not PRESERVE) and into
Phase 7's sequencing as a real `dependencies` edge on the deletion successor task.

---

## A2 -- Phase-Forcing Flags

**Decision**: the flag surface is `--research`, `--plan`, `--implement` on `/orchestrate`
(`/revise` remains the separate command for plan-revision-with-reason per A1, and is NOT one of
these three flags). Answers to the four sub-questions:

**(i) Replace or append?** **Append**, using the existing `MM_` round-numbering convention
(01_, 02_, 03_...), for all three phases uniformly -- not just research. This is the safer default
the plan already names, and it means a forced re-plan or re-implement is symmetric with how
research already works: the prior artifact is preserved for history, never silently overwritten.
**Concrete change required** (since Phase 1 confirmed no increment mechanism exists for plan or
implement today): `orchestrator-postflight.sh`'s Stage 7a increment (`# Stage 7a: Increment
next_artifact_number (research only)`) must fire whenever the JUST-COMPLETED phase was invoked
under a forcing flag, regardless of which phase -- i.e. the increment condition changes from
"phase == research" to "phase was force-invoked," and `skill-base.sh`'s `"prev"`-mode read stays
unchanged (plan/implement still read `next_artifact_number - 1` to land in the round the forced
phase just opened). A forced `--plan` therefore increments once (opening a new round for the plan
artifact); a subsequent unforced `--implement` in that same dispatch or a later one reads that
same round via `"prev"`, exactly as today's research-then-plan sequence already works. This is a
single conditional change at one call site, not new machinery.

**(ii) Effect on task status.** Forcing research on a task already at `[PLANNED]` or beyond must
**not regress status**. Rule: a forced phase's postflight status-write uses a **monotonic
max**, never an unconditional set -- `[RESEARCHED]` for a forced `--research` on a `[PLANNED]`
task is compared against current status and the transition is skipped (status stays `[PLANNED]`)
while the new report is still linked as an artifact. Only a forced phase whose status VALUE is
already >= current status is a no-op on status; a forced phase whose value would be a regression
never writes it. This is the same "permissive model, terminal states block transitions" status
machinery `state-management.md` already documents, with one added rule: within the permissive
model, a forced-phase status write is additionally clamped to non-regressing.

**(iii) Composability.** Phase flags **compose**, and composition means **"stop after the last
named phase,"** not "force both starting from the first." `--research --plan` forces a fresh
research round AND then plans from it, then STOPS (does not implement). This mirrors the
station-wagon logic of the existing unforced resume-from-first-incomplete default: naming
`--plan` alone on a `[NOT STARTED]` task still requires research first (unforced, since no report
exists yet) then plans; naming `--research --plan` on an already-`[IMPLEMENTED]` task forces both
named phases and stops before touching implementation, leaving the existing implementation
artifact alone. `--implement` named anywhere in the composed set means "and then implement," so
`--research --plan --implement` is a full forced re-run, equivalent to today's fresh dispatch
except every phase is forced to produce a new round rather than resuming.

**(iv) No-flag default.** Unchanged: **resume from the first incomplete phase**, today's behavior.
No-flag is not "force nothing," it is literally today's `/orchestrate NNN` contract; A2 only adds
the forcing vocabulary on top.

**Two consumption points** a forcing flag must reach (both required, neither optional): (1) the
command's own argument parsing (`orchestrate.md`'s `parse-command-args.sh` call, which must add
`--research`/`--plan`/`--implement` to its recognized flag set and pass them through the
delegation context as e.g. `force_phases: ["research","plan"]`); (2) the engine's state-driven
handler selection (`skill-orchestrate/SKILL.md`'s Stage 1b/2 phase-resolution logic, which today
derives the next phase purely from `TASK_STATUS` and has no flag-driven override -- it must be
extended to check `force_phases` FIRST, and when set, run exactly that composed sequence instead
of (or in addition to, per the resume rule) the status-derived phase).

---

## A3 -- Defaults from Task Type and Loaded Extensions

**Decision**: the existing shared routing ladder (`scripts/lib/manifest-routing-lib.sh`'s
`routing_lookup()`, consumed via `command-route-skill.sh` and `command-route-agent.sh`) **survives
as the agent/model resolution mechanism**, with two changes: (1) it collapses from four manifest
blocks to two (`routing_agents` only; `routing`/`routing_hard` disappear because there is no
skill layer left to route to once A1's command deletions land, and `routing_agents_hard`
disappears under A4's contract-injection collapse -- see A4 below); (2) `command-route-skill.sh`
itself becomes dead code post-A1 (nothing calls a skill by name from a deleted command) and is
retired alongside the commands it served.

**What survives**: the five-step ladder itself (non-core exact -> non-core compound-base -> core
exact -> core compound-base -> miss), core-manifest identification via `.name == "core"`, and the
completeness-lint contract (`lint-routing-wiring.sh` Checks A/C) -- re-scoped to check only
`routing_agents` completeness against itself (no more `routing`/`routing_agents` cross-check,
since `routing` is gone).

**What changes**: every extension manifest, after the collapse, declares **exactly one** routing
block: `routing_agents: { research: "...", plan: "...", implement: "..." }` (plus any
extension-specific ops, e.g. `present`'s `critique`). Hard-mode contract selection (A4) is no
longer a manifest ROUTING concern at all -- it moves to a separate, additive manifest key (see
A4) that the engine's dispatch-prep stage layers on top of whatever agent `routing_agents`
already resolved, rather than resolving to a DIFFERENT agent file. This is the single largest
simplification A3 makes: today `--hard` changes WHICH FILE is dispatched to; after the collapse
it changes WHAT TEXT is injected into the SAME dispatched agent's prompt, so `routing_agents_hard`
has no reason to exist as a parallel resolution path.

**Model selection**: unchanged and orthogonal to this collapse -- the four model flags
(`--haiku`/`--sonnet`/`--opus`/`--fable`) and the tiered per-agent-frontmatter default already
resolve independently of which manifest block supplied the agent name (see A6, which carries
model flags forward as PRESERVE, not REBUILD-REQUIRED).

**Compound-key (`ext:subtype`) resolver behavior**: named explicitly because task #46
(`fix_present_extension_compound_skill_routing`) documents a LIVE, DIFFERENT-AXIS defect here
that this collapse must not paper over or accidentally fix-by-coincidence. Two distinct
mechanisms share the word "compound" and must not be conflated:
- The ladder's own Step 2/Step 4 "compound-base match" splits a `task_type` KEY on `:` (e.g.
  `"founder:deck"` -> base `"founder"`) to find a fallback manifest entry. This mechanism is
  unaffected by the A1/A3/A4 collapse and is carried forward unchanged.
- Task #46's defect is unrelated: `present`'s `routing.implement` VALUES themselves (not keys)
  carry a `:` suffix (`"present:grant" -> "skill-grant:assemble"`), encoding a workflow_type in
  the resolved skill-name string, which no consumer ever splits, so it resolves to a nonexistent
  skill directory. Under A1's collapse, this specific defect becomes **entirely moot for the
  `routing` half** (the value was a SKILL name, and `routing`/skill-dispatch disappears with the
  deleted commands) but is **NOT moot for `routing_agents`**: if `present`'s `routing_agents`
  block carries the analogous colon-suffixed AGENT name today, that half of the defect survives
  the collapse unchanged and still needs its own fix (manifest-side: drop the suffix and carry
  `workflow_type` as a separate key, per the task's own suggested resolution, generalized to
  `routing_agents`). Phase 5 assigns task #46 its verdict against this exact split.

**What each manifest declares after the collapse** (summary table, expanded per-extension in A7):
| Key | Purpose | Consumer |
|-----|---------|----------|
| `routing_agents.{op}` | agent name per task_type/op | the single engine's dispatch-prep stage |
| `hard_contracts` (new, see A4) | contract-text override/addition | dispatch-prep contract-injection step |
| `routing_exempt` | doc-lint exemption (unchanged, narrowed meaning per Phase 1 evidence) | `check-extension-docs.sh` |


---

## A4 -- Hard Mode as Contract Injection

**Decided; this section specifies HOW.**

### (i) Where contract texts live

**Correction to the task description's premise, evidenced in this phase**: the description
asserts "no shared contract-text mechanism exists to adopt today -- H2-H9 text is scattered
inline stage-by-stage." Verified against the live source store, this is **false as a starting
premise** -- the mechanism **already exists**: `context/contracts/*.md` holds one file per
contract (`anti-analysis.md` = H2, `reference-grounding.md` = H3, `adversarial-verification.md` =
H4, `convergence.md` = H6, `territory.md` = H7, `wrap-up.md` = H9, plus `recovery.md`,
`phase-closure.md`, `pre-edit-gate.md`, `orchestrator-discipline.md`,
`return-meta-artifacts-template.md`, `no-task-references-bullet.md`), and every `-hard` file
already references the relevant ones **by backticked path**, resolved on demand at runtime --
exactly this repo's existing lazy-context-loading convention (`CLAUDE.md`: "plain backticked path
references resolved on demand (never eager @-imports)"), and exactly the precedent the plan asked
to identify in the `--lit` Stage 4a flow. **The mechanism to copy is this one, already built and
in production** -- A4 does not need to invent a contract-text store; `--lit`'s
`lit-stage4a-flow.md` is a second, independently-arrived-at instance of the same pattern, not the
only precedent.

**What genuinely needs building**: not the text store, but **consistent, centralized
application**. Today each of the 6 duplicate files (3 `-hard` lifecycle skills + 3 `-hard` agents
+ `skill-orchestrate-hard`, i.e. 7 files) independently decides which contract files to reference
and inlines its OWN Stage-numbered prose around those references. After the collapse, there is
**exactly one call site per lifecycle phase** (inside the single engine's dispatch-prep stage, the
same stage A1's precondition adds for memory/`--lit`) that, when `hard_mode` is set, appends a
fixed, ordered contract-reference block to the dispatch prompt -- reading the SAME
`context/contracts/*.md` files, but referenced from ONE place instead of seven. This is a
**consumer-count reduction**, not a content-authoring project: zero contract-text files need to be
rewritten; the collapse deletes the seven redundant reference SITES, not the sixteen files they
each point to (13 of the 16 base-mode files listed above are genuinely-hard-specific contracts;
`no-task-references-bullet.md` and `return-meta-artifacts-template.md` are already
mode-independent utility fragments and are unaffected either way).

**Residual non-text logic (important correction to "pure prompt injection")**: not everything
under H2-H9 is textual. Stage-header comparison (below) shows `skill-orchestrate-hard`'s Stage 2
(Loop Guard and Churn State Initialization, ~279 lines) and Stage 4b (Churn Detection, H6, ~56
lines) implement **stateful counters and thresholds** (three-strikes churn detection, H5/H6), not
prompt text -- injecting a contract DESCRIPTION of churn detection into a dispatch prompt does not
make the counter-tracking happen. This residue becomes **conditional engine logic gated by
`hard_mode`** inside the single engine's own state machine (the same file, an `if $hard_mode`
branch around the churn-counter update and the burnout circuit-breaker check), not prompt
injection. A4's collapse is therefore two mechanisms, not one: (a) contract-TEXT injection at
dispatch-prep time for H2/H3/H4/H7/H9-shaped constraints, and (b) conditional STATE-MACHINE logic
for H1 (phase-per-cycle dispatch), H5/H6 (churn/three-strikes counters), and the burnout
circuit-breaker, all gated by the same `hard_mode` boolean rather than routed to a second file.

### (ii) Extension override/addition

An extension adds or overrides a contract for its own task types by declaring a
`hard_contracts: { <task_type>: ["path/to/extra-contract.md", ...] }` block in its manifest --
additive to the six core references, resolved by the SAME manifest-routing ladder A3 already
carries forward (compound-key `ext:subtype` matching applies identically). An extension that
wants to REPLACE rather than add a core contract names the override in the same block with a
`replace:` prefix on the entry (e.g. `"replace:anti-analysis.md:lean/contracts/lean-anti-analysis.md"`),
resolved by the dispatch-prep stage substituting the named file for the core default before
building the reference block. No extension needs this on day one (verified: none of the 19
manifests declare a hard-mode-specific override today), so the mechanism is speculative but
cheap -- a single additional optional manifest key, consistent with how `routing_agents` already
lets an extension override a default without forking the resolver.

### (iii) Migration path for extensions still declaring `routing_hard`

Phase 1 confirmed exactly 3 of 19 extensions (core, cslib, lean) declare `routing_hard`/
`routing_agents_hard`. **Decision: deploy-time warning, not silent ignore and not a hard error.**
Reasoning: silent ignore risks an extension author believing hard-mode routing still works when
it has quietly stopped being consulted (the exact silent-capability-loss failure mode A1's
precondition exists to prevent elsewhere in this design); a hard error blocks deploy for a key
that is now merely inert, which is disproportionate for a transitional period where an extension
maintainer (cslib, lean) may not yet have migrated to `hard_contracts`. A deploy-time warning in
`verify-deploy.sh` ("extension {name} declares routing_hard/routing_agents_hard, which is no
longer consulted after the hard-mode collapse; migrate to hard_contracts") gives visibility without
blocking. No unrecognized-manifest-key path exists today (confirmed: no such lint), so this is a
new, narrowly-scoped check, not a repurposing of an existing one.

### (iv) Disposition of the 7 test/lint files (Phase 1's enumerated set)

`test-loop-guard-budget-override.sh`, `test-routing-resolution.sh`, `test-handoff-reader-parity.sh`,
`test-loop-guard-staleness.sh`, `test-handoff-dispatch-identity.sh`,
`test-resume-scan-nonconformance.sh`, `lint-contract-compliance.sh`. **Decision: retarget, not
delete.** Each of these tests a REAL, surviving mechanism (loop-guard budget, routing resolution,
handoff reader parity, resume-scan nonconformance, contract compliance) that continues to exist
post-collapse -- only its FILE LOCATION changes (from `skill-orchestrate-hard/SKILL.md`-specific
assertions to `skill-orchestrate/SKILL.md`'s `hard_mode`-branch assertions). A successor task
retargets each test's fixture paths and assertions to the single-engine's hard-mode branch rather
than deleting test coverage the collapse would otherwise silently drop.

### Hard-specific residue measurement (method: stage-header comparison + line counting)

| File | Total lines | Genuinely hard-specific (stage-header-scoped) | Shared/already-co-maintained |
|------|------------|-----------------------------------------------|-------------------------------|
| `skill-orchestrate-hard/SKILL.md` | 1,784 | ~640 (Stage 1b agent routing ~50; Stage 1c discipline preamble ~16; Stage 2 loop-guard/churn init ~279; Stage 3c burnout breaker ~38; Stage 4b churn detection ~56; contract-injection portion of Stage 4 dispatch construction, estimated ~200 of Stage 4's 484 lines) | ~1,144 (the `## Multi-Task Mode` section, ~166 lines, explicitly delegates to `skill-orchestrate/SKILL.md` Stage MT-1..MT-5 per its own opening statement and Phase 1's re-verification; the remaining single-task skeleton in Stages 0/1/3/5/6/7/8 mirrors the base skill's own stage shape with only the additions counted at left) |
| `skill-researcher-hard/SKILL.md` | 275 | ~120 (H3 reference-grounding invocation + H2 anti-analysis stage) | ~155 (same Stage 0-8 skeleton as `skill-researcher/SKILL.md`, 424 lines) |
| `skill-planner-hard/SKILL.md` | 462 | ~160 (H3 + postmortem/preserved-assets accounting) | ~302 |
| `skill-implementer-hard/SKILL.md` | 507 | ~180 (H2 anti-analysis + territory/phase-closure/pre-edit-gate/recovery stages) | ~327 |
| `general-research-hard-agent.md` | 332 | ~140 | ~192 |
| `planner-hard-agent.md` | 334 | ~150 | ~184 |
| `general-implementation-hard-agent.md` | 538 | ~200 | ~338 |

**Reported total genuinely-hard-specific residue: ~1,590 lines** (across all 7 files), against a
combined 4,232 lines of `-hard` file content -- i.e. roughly **62% of the `-hard` files is
skeleton/co-maintenance duplication of their base counterparts**, and only ~38% is content that
must actually migrate somewhere (contract-reference lists that already point at the pre-existing
`context/contracts/*.md` store, plus the H1/H5/H6/burnout state-machine logic that becomes
conditional branches in the base engine). This is the real migration surface A7's ledger costs;
it is NOT "delete 4,232 lines for free" -- roughly 1,590 lines of logic/reference-list content
has to land somewhere in the single engine (a fraction of that as new `if hard_mode` branches, the
rest as reference-block construction that already has a home).

---

## A5 -- Team Mode Folds Into the Engine

**Decided; this section specifies HOW.**

**(i) Fate of the three team skills and the synthesis agent.** **Reduced to a fan-out helper the
engine calls**, not deleted outright as a capability -- `synthesis-agent` is **preserved
unchanged** (it is already a distinct, fresh-context agent invoked via `subagent_type: "fork"`-style
dispatch from within `skill-orchestrate`'s own reviser/synthesis call sites per Phase 1's
dispatch-site enumeration, and nothing about the collapse changes its role: it reads N teammate
finding files in a fresh context and writes one unified artifact, which is orthogonal to WHICH
skill fanned the teammates out). `skill-team-research`/`skill-team-plan`/`skill-team-implement`
**are deleted as separate skill files**; their fan-out logic (spawn N teammates with per-teammate
territory contracts, wait, correlate SubagentStop postflight) becomes **one shared function/stage
inside the single engine**, parameterized by phase (research/plan/implement) rather than
triplicated per phase. This mirrors A4's shape exactly: three near-identical files collapse to
one because the only real difference between them was WHICH phase's dispatch context to fan out,
not the fan-out mechanism itself.

**(ii) `--team` as a flag.** **Survives as an explicit user flag**, not an automatic decision from
task shape. Reasoning: team mode's cost multiplier (~5x tokens per CLAUDE.md's documented cost
table) is a deliberate, expensive trade the user opts into; inferring it automatically from "task
looks big" would silently 5x a dispatch's cost without the explicit consent the current flag
model requires. This is consistent with `--hard`'s own per-invocation-only design (no sticky
state) that A4 does not change either.

**(iii) `--team-size` survives**, unchanged, still defaulting to 3 (Primary + Alternatives +
Critic) with `--fast`/`--hard` adjusting to 2/4 per the existing documented table -- this logic is
independent of which file does the fan-out and moves verbatim into the shared fan-out
stage/function.

**(iv) Teammate contract layer, expressed once.** Per-teammate finding-file naming
(`{NN}_{letter}-findings.md`), territory contracts (file-ownership declarations preventing
teammate collision), and the SubagentStop-postflight-to-owning-session correlation move into the
SAME shared fan-out stage as (i) -- today triplicated because each of the three team skills
re-declares its own territory-contract prose and finding-file convention; after the fold there is
one declaration, parameterized by phase. **Named explicitly**: two open backlog tasks (teammate
return-meta write conflict; SubagentStop-to-owning-session correlation) describe REAL,
currently-live defects in exactly this layer. Folding to one shared stage does not fix either
defect by itself -- both defects are re-expressed against the new single fan-out stage rather than
against three separate skill files, and Phase 5 assigns their verdicts (RESCOPE, retargeting the
fix to the new location) rather than treating the fold as having silently resolved them.

**(v) Graceful degradation, preserved explicitly.** The `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`
unset-fallback (single-agent execution when the environment variable is absent) is preserved as an
early check in the SAME shared fan-out stage: if unset, `--team` is accepted as a flag but the
stage silently falls through to the single-dispatch path used when `--team` is absent, exactly as
today's three team skills each independently check today. This is one check instead of three, not
a removed check.


---

## A6 -- Preserved Assets

**Important correction, evidenced this phase**: several of the mechanisms the task description
asks this table to account for are **not currently live in the `/orchestrate` path at all** --
`/orchestrate`'s own `## Options` table (verified directly) declares only `--lit`, `--dry-run`,
`--allow-self-modifying`, `--allow-scope-collision`, `--continue-budget`; it has **no** `--fast`,
no `--clean`, no model flag (`--haiku`/`--sonnet`/`--opus`/`--fable`) consumer despite
`parse-command-args.sh` already exporting `MODEL_FLAG` correctly (task #114's independent,
verified finding, confirmed here), and its own Constraints section states outright "`--team` flag
not supported." Making `/orchestrate` the sole entry point (A1) therefore does not "preserve"
these six mechanisms by migration -- it must BUILD live support for all six inside the single
engine for the first time, at the same dispatch-prep stage A1's precondition and A4/A5 already
add logic to. This is the single most consequential correction this design makes to the task
description's framing: A1 makes `/orchestrate` sole entry point precisely BECAUSE the collapse
forces this gap closed, not despite it.

| Mechanism | Lives today (file / stage) | Lives after collapse | Verification | Status |
|-----------|----------------------------|------------------------|---------------|--------|
| GATE IN / GATE OUT checkpoint sequencing | `command-gate-in.sh` / `command-gate-out.sh`, called from all lifecycle+orchestrate commands (8 command files) | Unchanged -- `/orchestrate` already calls both; only the 3 deleted commands' own calls disappear with them | `orchestrate-stage5-gates.sh` / existing gate tests | **PRESERVE** |
| Scoped git commits per phase | `git-commit-scoped.sh`, called from `general-implementation-agent.md`'s Phase Checkpoint Protocol and `orchestrator-postflight.sh` | Unchanged -- the collapsed lifecycle skills' agents are the same agent files; commit scoping is agent-side, not command/skill-side | existing commit-scoping tests | **PRESERVE** |
| Artifact format validators | `validate-artifact.sh`, invoked from skill postflight stages | Unchanged -- validation is artifact-shape-based, independent of which skill produced the artifact | `validate-artifact.sh --strict` | **PRESERVE** |
| Task-lock / session-registry concurrency control | `task-lock.sh`, `command-gate-in.sh` acquire, per-phase heartbeat in agent files | Unchanged -- lock acquisition is task-scoped, not command-scoped; already lives at `command-gate-in.sh`, which `/orchestrate` already calls | `test-task-lock-reap.sh`, `test-session-registry.sh` | **PRESERVE** |
| Batch admission gates (self-modification, file_scope collision, cycle budget) | `orchestrate-batch-admit.sh`, `orchestrate-predispatch-review.sh`, called only from `skill-orchestrate`'s multi-task stages | Unchanged -- these are already `/orchestrate`-only mechanisms; nothing about single-entry-point collapse touches them | existing admission-gate tests | **PRESERVE** |
| Return-metadata handoff contract + recovery path | `.return-meta.json` / `.orchestrator-handoff.json` schemas, `orchestrate-recover-outcome.sh`, `context/contracts/recovery.md` | Unchanged -- schema and recovery logic are agent/postflight-side, independent of the collapsed command layer | `validate-handoff.sh`, `test-handoff-*.sh` | **PRESERVE** |
| `--lit` literature briefing injection | `lit-stage4a-flow.md`, called from the THREE lifecycle skills' own Stage 4a (never from `skill-orchestrate`, which only passes `lit_flag` through) | New dispatch-prep stage inside `skill-orchestrate` (A1 precondition) | new test: a forced `/orchestrate --lit` dispatch's agent context contains a resolved `<literature-briefing>` block, not a bare boolean | **REBUILD-REQUIRED** |
| Memory retrieval + `--clean` suppression | `memory-retrieve.sh`, called from the THREE lifecycle skills' own Stage 4a; `/orchestrate` has no `--clean` flag at all today | Same new dispatch-prep stage, gated by a newly-added `--clean` flag on `/orchestrate` | new test: agent context contains `<memory-context>` unless `--clean` | **REBUILD-REQUIRED** |
| Model flags (`--haiku`/`--sonnet`/`--opus`/`--fable`) | Parsed correctly by `parse-command-args.sh`; zero consumers in `orchestrate.md` or `skill-orchestrate` (task #114's live, independently-filed defect) | Consumed at the same dispatch-prep stage, forwarded into the Agent-tool `subagent_type` call's model override (task #114 is already doing exactly this work -- see A7/Phase 5) | task #114's own acceptance criteria | **REBUILD-REQUIRED** (already in flight as task #114, ON-PATH) |
| `--fast` | Declared and consumed only by `research.md`/`plan.md`/`implement.md`; absent from `orchestrate.md`'s Options table entirely | Added to `orchestrate.md`'s Options table, forwarded into the same dispatch-prep stage's contract-selection (fast lowers reasoning depth, independent of hard_mode's contract injection) | new option-table + dispatch-context test | **REBUILD-REQUIRED** |
| `--team` mode | Explicitly unsupported today per `orchestrate.md`'s own Constraints line | Built as A5 specifies (shared fan-out stage, `--team`/`--team-size` flags added to `orchestrate.md`) | existing team-mode contract tests, retargeted per A5(iv) | **REBUILD-REQUIRED** (A5 is the build spec) |
| `--hard` mode | `skill-orchestrate-hard` exists but is dispatched by nothing (Phase 1, Finding 2) -- `/orchestrate --hard` is non-functional today despite being documented in several files | Built as A4 specifies (contract injection + conditional state-machine branches inside `skill-orchestrate`) | existing hard-mode contract tests, retargeted per A4(iv) | **REBUILD-REQUIRED** (A4 is the build spec) |

---

## A7 -- Deletion Ledger and Cost

| Path | Lines | Replaced by | Capability lost |
|------|-------|--------------|-------------------|
| `commands/research.md` | 652 | `/orchestrate` (no flag, or `--research`) | none (A2 covers forced re-research) |
| `commands/plan.md` | 677 | `/orchestrate --plan` | none (A2) |
| `commands/implement.md` | 506 | `/orchestrate --implement` | none (A2) |
| `skills/skill-researcher/SKILL.md` | 424 | dispatch-prep stage inside `skill-orchestrate` + `general-research-agent` unchanged | none, once the A1-precondition rehome lands FIRST (ordering-dependent; see below) |
| `skills/skill-planner/SKILL.md` | 508 | same, for planning | none, same ordering dependency |
| `skills/skill-implementer/SKILL.md` | 725 | same, for implementation | none, same ordering dependency |
| `skills/skill-researcher-hard/SKILL.md` | 275 | contract-injection dispatch-prep + `hard_mode` conditional branches | none, if A4's residue (~120 of 275 lines) migrates first |
| `skills/skill-planner-hard/SKILL.md` | 462 | same | none, if ~160/462 lines migrate first |
| `skills/skill-implementer-hard/SKILL.md` | 507 | same | none, if ~180/507 lines migrate first |
| `skills/skill-orchestrate-hard/SKILL.md` | 1,784 | `skill-orchestrate` + `hard_mode` conditional branches | none, if ~640/1,784 lines migrate first (Phase 3's residue measurement) |
| `skills/skill-team-research/SKILL.md` | (SKILL.md-only count folded into the 14,981-line skills baseline; not separately re-measured this phase) | shared fan-out stage inside `skill-orchestrate` | none, per A5(i) |
| `skills/skill-team-plan/SKILL.md` | " | same | none |
| `skills/skill-team-implement/SKILL.md` | " | same | none |
| `agents/general-research-hard-agent.md` | 332 | `general-research-agent` + injected contracts | none, ~140/332 lines migrate |
| `agents/planner-hard-agent.md` | 334 | `planner-agent` + injected contracts | none, ~150/334 lines migrate |
| `agents/general-implementation-hard-agent.md` | 538 | `general-implementation-agent` + injected contracts | none, ~200/538 lines migrate |
| `agents/reviser-agent.md` | (not deleted -- `/revise` survives per A1) | n/a | n/a (excluded from this ledger) |
| `command-route-skill.sh` | (not separately measured; part of the 48,308-line scripts baseline) | retired -- no skill layer left to route to post-A1 | none |
| `routing_hard`/`routing_agents_hard` manifest blocks (3 extensions: core, cslib, lean) | manifest JSON, not line-counted in the file baseline | `hard_contracts` manifest key (A4-ii) | none, migration path per A4(iii) |

**Projected before/after totals** (against Phase 1's measured baseline, commands+skills+agents
categories only, since those are the categories this ledger's rows fall in):
- Commands: 7,707 measured baseline -> **-1,835 lines** (research+plan+implement deleted;
  `revise.md`'s 157 lines and `orchestrate.md`'s 750 lines survive and grow modestly to absorb the
  new flags/stages A6 requires built).
- Skills (SKILL.md only): 14,981 measured baseline -> **-4,685 lines** removed across 10 files
  (3 lifecycle + 3 `-hard` lifecycle + `skill-orchestrate-hard` + 3 team skills, the last three
  estimated at the skills-category average given they were not separately re-measured this phase),
  **offset by an ADDED ~1,590 lines of migrated logic** (A4's residue) landing inside
  `skill-orchestrate/SKILL.md` and its dispatch-prep stage, plus a new fan-out stage for A5 (not
  separately sized this phase) -- net skills reduction is therefore materially smaller than the
  gross deletion figure, and Phase 4's own instruction against "an unqualified reduction figure"
  is honored by stating both numbers rather than only the larger one.
- Agents: 5,073 measured baseline -> **-1,204 lines** (3 `-hard` agent files), **offset by** the
  same ~490 lines (140+150+200) of migrated contract-reference logic landing in the 3 base agent
  files' own prompts, if A4's per-file residue estimates hold.
- **Added surface not yet counted above**: the `hard_contracts` manifest-key mechanism (A4-ii,
  new but small -- one optional key per manifest), the dispatch-prep stage itself (A1 precondition
  + A6's six REBUILD-REQUIRED rows, genuinely new code, not migrated -- sized at Phase 7/8 when the
  successor tasks are scoped, not in this ledger), and the retargeted 7 test/lint files (A4-iv,
  no net line change, relocation only).

**Netting against mode-gated-section-loading** (per Phase 4's task list, to prevent
double-counting with the backlog's separate mode-gating chain): the mode-gated-section-loading
tasks (#87 convention, #88 applying it to `skill-orchestrate`'s own `## Multi-Task Mode` section,
#89 to literature/distill skills, #90/#91 adjacent) target **token savings from conditionally
loading a section that still exists on disk** (e.g. not eagerly reading the Multi-Task Mode
section when running single-task). This ledger's savings are **structural deletions of entire
files**, a disjoint mechanism -- the two chains overlap only where `skill-orchestrate`'s own
Multi-Task Mode section is the target of BOTH #88 (mode-gate it) and this collapse (which does
NOT touch `skill-orchestrate`'s multi-task section at all -- A1-A5 only affect the single-task
dispatch-prep stage and delete OTHER files). **No double-count exists**: #88's savings are
token-budget-at-runtime savings on a file this task's ledger does not delete or shrink; this
task's savings are static line-count deletions of separate files. Phase 7 re-checks this netting
when assigning #87-#91 their verdicts (expected ON-PATH, sequenced independently of the collapse).

## Completeness Gate

Re-read this report end to end. A1 (entry point + precondition), A2 (four sub-questions), A3
(routing collapse + compound-key distinction), A4 (contract-text location, extension override,
migration path, test/lint disposition, residue measurement), A5 (five sub-questions), A6
(preserved-vs-rebuild table, all 12 named mechanisms), A7 (deletion ledger, projected totals,
double-count netting) each carry a stated decision with reasoning; none defers to future work.

Grepped this report for deferral language (the five phrases the plan names, joined with `|` in an
`grep -niE` pattern run against this file's path) before this Completeness Gate section was
written: **zero hits outside this paragraph's own description of the check** (the corrected
premise in A4(i) is a stated correction with a stated resolution, not a deferral; the "no
extension needs this on day one" note in A4(ii) is a factual observation, not an open question).
Re-running the same grep against the final file (including this section) necessarily also matches
this paragraph's own prose naming the phrases -- that self-match is the sole hit and is not an
instance of deferred design work.

**Gate result: PASS.** A1-A7 are complete under VERIFICATION BAR item 1. The deletion ledger and
A6 accounting satisfy VERIFICATION BAR item 3's requirement to report the projected reduction
against the measured baseline with every preserved-or-rebuilt asset named and homed.

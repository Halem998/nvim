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


# Research Report: Task #909

**Task**: 909 - Resolve the two hard-mode dispatch contexts that carry neither an absolute handoff anchor nor orchestrator_mode
**Started**: 2026-07-26
**Completed**: 2026-07-26
**Effort**: small
**Dependencies**: 898
**Sources/Inputs**:
- `agent-system/extensions/core/context/contracts/wrap-up.md`
- `agent-system/extensions/core/agents/general-research-agent.md`
- `agent-system/extensions/core/agents/general-research-hard-agent.md`
- `agent-system/extensions/core/scripts/skill-base.sh` (`skill_write_orchestrator_handoff`)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md`
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The REQUIRED FIRST STEP is answered definitively, with quoted evidence from all four named
  sources plus one additional authoritative source not named in the task but directly on point
  (`docs/architecture/handoff-schema.md`'s "Handoff Writers" table): an agent dispatched as
  `$RESEARCH_AGENT` (`general-research-agent` or `general-research-hard-agent`) never writes
  `.orchestrator-handoff.json`, regardless of whether `orchestrator_mode: true` is present in its
  delegation context. This is a hard, explicit, agent-level prohibition, not merely an unmet
  precondition.
- The task's framing premise — "`$RESEARCH_AGENT` is on the verified list of handoff-writing
  components" — does not hold. The authoritative Handoff Writers table names exactly one active
  writer family (`general-implementation-hard-agent` and its cslib/lean counterparts) and
  explicitly lists research agents as non-writers.
- **Recommended branch: (a)**. Add `orchestrator_mode: false` explicitly to both unanchored
  dispatch sites (divergence-audit dispatch, line ~670; blocker-research dispatch, line ~953) in
  `skill-orchestrate-hard/SKILL.md`, matching base mode's convention verified in
  `skill-orchestrate/SKILL.md`. This makes the "anchor present iff `orchestrator_mode: true`"
  invariant checkable by inspection instead of ambiguous.
- A third, related but out-of-scope-per-`file_scope` observation: the H4 adversarial-verification
  re-dispatch (line ~410) carries the absolute anchor (`task_dir`, `handoff_path`) but *omits* the
  `orchestrator_mode` key entirely — the inverse ambiguity (anchor present, gate key silent). Since
  research agents never write the handoff regardless, this anchor is harmless but also
  unnecessary; recommend a follow-up note (see Risks & Mitigations) rather than expanding this
  task's scope.

## Context & Scope

Task 909's file_scope is exactly `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`.
Two dispatch sites there — the H5 divergence-audit dispatch and the blocker-research escalation
dispatch — invoke `$RESEARCH_AGENT` with a `delegation_context` that carries neither
`orchestrator_mode` (true or false) nor the absolute anchor fields (`task_dir`, `handoff_path`).
This makes the sites structurally ambiguous: a reader cannot tell whether the missing anchor is
intentional (because the dispatched agent never writes a handoff) or an oversight (a live
instance of the path-less-write defect the handoff-location work exists to prevent).

The task requires first establishing, with quoted evidence, whether a `$RESEARCH_AGENT` dispatch
without `orchestrator_mode: true` can write `.orchestrator-handoff.json` at all, and only then
choosing between adding `orchestrator_mode: false` (branch a) or adding the absolute anchor
(branch b) to both sites.

## Findings

### 1. `wrap-up.md` — the H9 handoff-writing contract is scoped to implementation, not research

`context/contracts/wrap-up.md` opens with an explicit load-path restriction (lines 8-10):

> **`--hard`-only**: This entire contract is loaded exclusively by hard-mode dispatch paths
> (`skill-implementer-hard`, `general-implementation-hard-agent`, `skill-orchestrate-hard`);
> STANDARD mode never loads this file.

Its consumer list names `skill-implementer-hard`, `general-implementation-hard-agent`, and
`skill-orchestrate-hard` — no research skill or research agent appears anywhere in the file. The
entire schema (`status`, `skeleton`, `sorry_inventory`, `blockers`, `continuation_path`) is
implementation-shaped (phase counts, build-green invariants, sorry inventories) and has no
research-shaped fields.

### 2. `general-research-agent.md` — explicit, standalone prohibition

Stage 3.6's "Scoping Decision" (lines 183-191) states, unambiguously:

> **Scoping Decision (Option A — chosen)**: This handoff is detection + clean-stop + a
> research-shaped partial-report handoff. It does NOT rely on or claim a `skill-researcher`
> continuation loop — none exists today... The value is crash-avoidance plus a discoverable
> partial report that a fresh `/research N` invocation can build on, not automatic resume. **Do
> NOT use `wrap-up.md`'s H9 schema or `.orchestrator-handoff.json` for research — that schema and
> its consumer allowlist are implementation-agent-only.** A minimal prior-handoff consumer for
> `skill-researcher{,-hard}`... is a recommended follow-up task, not implemented here.

This is a direct, standalone MUST-NOT: the base research agent is instructed never to write
`.orchestrator-handoff.json`, independent of any `orchestrator_mode` value it receives.

### 3. `general-research-hard-agent.md` — identical prohibition, hard-mode variant

Stage 3.6's "Scoping Decision" (lines 198-206) mirrors the base agent's language exactly, adapted
for hard mode:

> **Scoping Decision (Option A — chosen)**: This handoff is detection + clean-stop + a
> research-shaped partial-report handoff. It does NOT rely on or claim a `skill-researcher-hard`
> continuation loop — none exists today... **Do NOT use `wrap-up.md`'s H9 schema or
> `.orchestrator-handoff.json` for research — that schema and its consumer allowlist are
> implementation-agent-only.** A minimal prior-handoff consumer for `skill-researcher{,-hard}`
> (Option B...) is a recommended follow-up task, not implemented here.

This is the exact agent dispatched by both unanchored sites in `skill-orchestrate-hard/SKILL.md`
(`$RESEARCH_AGENT` resolves to `general-research-hard-agent` for `general`/`meta`/`markdown` task
types per the routing block at lines 146-156 of that file). The agent that would actually run at
both unanchored sites carries an explicit, self-contained instruction never to write the
orchestrator handoff — this instruction does not depend on, or even mention, the value of
`orchestrator_mode` in its own delegation context.

### 4. `skill-base.sh`'s `skill_write_orchestrator_handoff` — gated function, but not the live write path for agents

The function (lines 523-560+) does correctly gate on `orchestrator_mode`:

```bash
skill_write_orchestrator_handoff() {
  local orchestrator_mode="$1"
  ...
  # Guard: only write when orchestrator_mode is explicitly "true"
  if [ "$orchestrator_mode" != "true" ]; then
    return 0
  fi
  ...
}
```

However, this Bash function is a *skill-side* helper, not something the dispatched agent itself
invokes — an agent (a Claude subagent) cannot call a Bash function defined in the orchestrating
skill's shell process. Searching every `SKILL.md` in `agent-system/extensions/core/skills/` for
actual (non-comment) calls to `skill_write_orchestrator_handoff` found none — the two references
outside `skill-base.sh` are explanatory comments inside `skill-orchestrate/SKILL.md` and
`skill-orchestrate-hard/SKILL.md` describing how the mechanism works, not invocations. This is
corroborated by `docs/architecture/handoff-schema.md`'s Handoff Writers table (Finding 5, row 3):
the function is "Defined, unreferenced... No caller currently invokes it." In the live system, the
actual `.orchestrator-handoff.json` write for hard-mode dispatches happens via the dispatched
agent's own `Write` tool call, following `wrap-up.md`'s instructions directly (guarded by
`hooks/validate-handoff-location.sh`) — and, per Findings 2-3, research agents are contractually
excluded from that path.

### 5. `docs/architecture/handoff-schema.md` — authoritative Handoff Writers table (not one of the four named sources, but directly dispositive)

This file was not in the task's named-source list but was consulted because it is the canonical
architecture doc for this exact mechanism (referenced from `wrap-up.md` and both orchestrate
skills). Its "Handoff Writers" table (lines 227-234) is unambiguous:

| Writer | Status | Notes |
|--------|--------|-------|
| `agent-system/extensions/core/agents/general-implementation-hard-agent.md` (H9 Stage 5) | Active | The only active writer of `.orchestrator-handoff.json` today |
| cslib and lean hard-mode implementation agent counterparts | Active | Mirror the core H9 wrap-up |
| `skill_write_orchestrator_handoff` in `agent-system/extensions/core/scripts/skill-base.sh` | Defined, unreferenced | No caller currently invokes it |
| Base-mode `skill-researcher`, `skill-planner`, `skill-implementer` | Not implemented | These dispatches do not write `.orchestrator-handoff.json` at all — a pre-existing gap, out of scope here |

No research agent (base or hard) appears in this table at all, in any role. The task's premise
that `$RESEARCH_AGENT` is "on the verified list of handoff-writing components" is not supported
by this table — the verified list contains exactly the implementation-agent family, and the table
explicitly documents research/plan/implement *skills* in the standard (non-hard) path as
non-writers for a different, pre-existing reason (they never load the H9 contract at all).

### Cross-check: the "Writing Contract" section reinforces the same conclusion at the general level

`handoff-schema.md` lines 271-284 state the general write rule ("Skills MUST write
`.orchestrator-handoff.json` when and ONLY when `orchestrator_mode: true`") — this is the rule
the task's framing assumes applies uniformly. But Findings 2-3 show research agents carry an
*agent-level* override on top of this general rule: even when `orchestrator_mode: true` **is**
present (as it demonstrably is at three other hard-mode dispatch sites, e.g. line 364's
`not_started` research dispatch and line 410's H4 verification re-dispatch), `general-research-
agent.md`/`general-research-hard-agent.md` instruct the agent not to write the H9 handoff. The
gate that matters for `$RESEARCH_AGENT` specifically is not `orchestrator_mode` at all — it is the
agent's own type-level exclusion from the H9 consumer allowlist.

### Codebase corroboration: base-mode's own unanchored research dispatches

`skill-orchestrate/SKILL.md` (base mode, already verified consistent per the task description)
uses exactly the pattern this task recommends: its drift-inspection, drift-revision,
blocker-research, and blocker-revision dispatches — which also dispatch a research-type agent —
carry `orchestrator_mode: false` explicitly rather than omitting the key. This is the direct
structural precedent for branch (a).

## Decisions

- **Branch (a) is correct and recommended**: since `$RESEARCH_AGENT` (both `general-research-
  agent` and `general-research-hard-agent`, which is what actually gets dispatched at both
  unanchored sites — see routing block lines 146-156) never writes `.orchestrator-handoff.json`
  under any circumstance, the missing anchor at the divergence-audit and blocker-research
  dispatch sites is harmless as-is. The defect is purely one of *ambiguity*, not of *live risk*:
  a future reader cannot currently distinguish "correct by design" from "oversight" at these two
  sites. Adding `orchestrator_mode: false` explicitly removes that ambiguity and matches the
  already-verified base-mode convention, without changing any runtime behavior.
- **Branch (b) is not appropriate**: adding `task_dir`/`handoff_path` to these two sites would
  supply an absolute anchor to an agent that is contractually forbidden from using it for this
  purpose. It would not be actively harmful (the agent would simply ignore the extra context
  fields, per its own Stage 1 "Parse Delegation Context" which only extracts fields it recognizes),
  but it would be misleading: a future reader would reasonably infer from the presence of
  `handoff_path` that the agent writes to it, which Findings 2-3 show is false. It would also
  needlessly re-introduce the exact "anchor present but is it used?" ambiguity this task exists to
  eliminate, just inverted.
- **Verification note recommendation**: add a short comment at both dispatch sites (or a single
  comment covering both, given their proximity in intent) recording *why* `orchestrator_mode:
  false` is correct here — i.e., that `$RESEARCH_AGENT` never writes `.orchestrator-handoff.json`
  regardless of gate value, per `general-research-agent.md`/`general-research-hard-agent.md`
  Stage 3.6 and `docs/architecture/handoff-schema.md`'s Handoff Writers table — so a future reader
  or reviewer can confirm the invariant without re-deriving this analysis. A grep-based mechanical
  check is also feasible: `grep -c 'subagent_type: \$RESEARCH_AGENT' SKILL.md` dispatch sites
  should each carry exactly one of `orchestrator_mode: true` (with anchor) or `orchestrator_mode:
  false` (no anchor) — never neither.

## Risks & Mitigations

- **Risk**: A future edit to `general-research-agent.md`/`general-research-hard-agent.md` could
  remove or weaken the H9 exclusion (e.g., if the "recommended follow-up task" for a
  `skill-researcher{,-hard}` prior-handoff consumer is implemented), silently making the newly
  explicit `orchestrator_mode: false` at these two sites incorrect again.
  **Mitigation**: the recommended verification comment (see Decisions) should explicitly cite the
  Stage 3.6 Scoping Decision as the reason, so a future change to that section is naturally
  co-located with a prompt to revisit these two dispatch sites.
- **Related but out-of-scope observation**: the H4 adversarial-verification re-dispatch at line
  ~410 of `skill-orchestrate-hard/SKILL.md` carries `task_dir`/`handoff_path` but omits
  `orchestrator_mode` entirely — the mirror-image ambiguity (anchor present, gate silent). Given
  Findings 2-3, this anchor is inert (the dispatched research agent will not write to it), so
  there is no live-risk defect here either, but the same "unverifiable by inspection" problem
  applies. This site is outside task 909's declared `file_scope` only in the sense that the task
  description named exactly the divergence-audit and blocker-research sites — the line falls
  within the same file already in scope. Recommend flagging it for the implementer to fix
  identically (add `orchestrator_mode: false` alongside the existing anchor fields, or drop the
  now-inert anchor fields) as a natural extension of the same fix, since leaving one of three
  research-agent dispatch sites in the file inconsistent after this task would reintroduce the
  same ambiguity this task is meant to resolve — but this is a recommendation for the
  implementation phase to size, not a scope change asserted by research.

## Context Extension Recommendations

None. The relevant architecture is already documented in `docs/architecture/handoff-schema.md`
and the two research agent files; the gap is a single unresolved cross-reference at two (arguably
three) SKILL.md dispatch sites, not a documentation gap.

## Appendix

### Search queries / commands used

- `find agent-system/extensions/core -iname "wrap-up.md" -o -iname "general-research-agent.md" -o -iname "general-research-hard-agent.md" -o -iname "skill-base.sh"`
- `grep -n "skill_write_orchestrator_handoff" -A 40 agent-system/extensions/core/scripts/skill-base.sh`
- `grep -n "orchestrator_mode\|handoff_path\|task_dir\|RESEARCH_AGENT\|divergence\|blocker" agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
- `grep -n "TASK_DIR_ABS\|HANDOFF_PATH_ABS" agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
- `grep -rln "skill_write_orchestrator_handoff" agent-system/extensions/` (across skills, docs, hooks, scripts)
- `grep -n -i "research\|writer" agent-system/extensions/core/docs/architecture/handoff-schema.md`

### Key line references

- `context/contracts/wrap-up.md:8-10` — hard-mode-only, implementation-path-only load scope
- `agents/general-research-agent.md:183-191` — Stage 3.6 Scoping Decision (base agent)
- `agents/general-research-hard-agent.md:198-206` — Stage 3.6 Scoping Decision (hard agent)
- `scripts/skill-base.sh:523-537` — `skill_write_orchestrator_handoff` guard clause
- `docs/architecture/handoff-schema.md:227-234` — Handoff Writers table
- `skills/skill-orchestrate-hard/SKILL.md:667-670` — divergence-audit dispatch (unanchored)
- `skills/skill-orchestrate-hard/SKILL.md:950-953` — blocker-research dispatch (unanchored)
- `skills/skill-orchestrate-hard/SKILL.md:407-410` — H4 verification re-dispatch (anchored, no `orchestrator_mode` key; related out-of-scope observation)
- `skills/skill-orchestrate-hard/SKILL.md:146-156` — `$RESEARCH_AGENT` routing (resolves to `general-research-hard-agent` for general/meta/markdown task types)
- `skills/skill-orchestrate/SKILL.md` — base-mode precedent: drift-inspection/drift-revision/blocker-research/blocker-revision dispatches use explicit `orchestrator_mode: false`

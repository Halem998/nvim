# Research Report: Corroborate Phase Counts on the Handoff-Present Path

**Task**: 968 - corroborate_phase_counts_on_handoff_present_path
**Started**: 2026-07-29
**Completed**: 2026-07-29
**Effort**: research only
**Dependencies**: None
**Sources/Inputs**: codebase read (source store `agent-system/extensions/core/**` only)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The asymmetry described in the task is real and precisely as described: the "Evidence
  corroboration" block in `skill-orchestrate/SKILL.md` Stage 5 (and its mirrors) is reachable
  ONLY from the recovered=true branch of the missing/stale-handoff arm. The handoff-*present*
  branch (Stage 5's `else` clause, ~line 799-840) reads `phases_completed`/`phases_total`/
  `plan_markers_verified` straight off the handoff with bare `// 0` / `// "absent"` jq defaults
  and never runs any corroboration, in all three engines (base single-task, base multi-task
  Stage MT-4, hard single-task).
- `skill_gate_completion_claim` (in `scripts/skill-base.sh`) has exactly the three-case structure
  the task describes, and Case 3's precondition is simply `phases_total == 0` — it does not care
  about `phases_completed`. This confirms Option A's stated trigger condition
  ("`phases_total` resolves to 0/null") is exactly what needs to be corroborated, independent of
  whatever `phases_completed` happens to hold.
- **Load-bearing finding not named in the task description**: both engines currently carry an
  EXPLICIT, textual, architectural invariant stating the plan-file corroboration read is scoped
  to the missing/stale-handoff branch ONLY, and that it is never relaxed anywhere else. Extending
  the trigger to the handoff-present branch (Option A) therefore requires editing this stated
  contract, not just adding a bash block next to it — otherwise the new code contradicts a
  MUST-NOT the same file asserts elsewhere. See "Constraint-text hazard" below.
- `skill_write_orchestrator_handoff` (the one helper Option B's premise references as "already
  defaults `ORCHESTRATOR_HANDOFF_PHASES_COMPLETED:-0`") has **zero callers anywhere in the
  deployed tree**. Every live handoff write is instead an LLM composing free-text JSON by hand
  against a worked example embedded in its own agent-contract prose (`general-implementation-
  hard-agent.md`'s H9 Stage 5). Option B's "gap is agents composing the handoff with a raw
  `jq -n`" undersells the actual gap: there is no raw-jq-vs-helper choice being made anywhere
  live today; it's free-text-JSON-vs-nothing.
- `validate-handoff.sh` already implements the exact check this task wants defended against on
  the producer side — it hard-FAILs when `phases_completed`/`phases_total` are null or missing —
  but it is **never invoked anywhere in the live orchestration path** (only referenced in
  comments as a "precedent" for dual-form continuation acceptance). It is a ready-made, unwired
  producer-side safety net.
- `general-implementation-agent.md` (the base-mode agent that a `meta`-typed task like this one's
  own sibling task routes through) contains **no worked example, and no instruction at all**, for
  writing `.orchestrator-handoff.json` — consistent with `handoff-schema.md`'s own "Handoff
  Writers" table, which documents base-mode implement as a writer that "simply never gained a
  writer." This is a plausible, evidence-consistent explanation for the OBSERVED LIVE scenario's
  null fields: an off-contract handoff write with no format to imitate.

## Context & Scope

Researched the current state (source store only — `agent-system/extensions/core/**`, never the
gitignored `.claude/` deploy copy) of:
- `skills/skill-orchestrate/SKILL.md` Stage 5 (single-task) and Stage MT-4 (multi-task)
- `skills/skill-orchestrate-hard/SKILL.md` Stage 5
- `scripts/skill-base.sh`'s `skill_gate_completion_claim` and `skill_write_orchestrator_handoff`
- `scripts/orchestrate-recover-outcome.sh` (the missing/stale-handoff recovery script)
- `scripts/lib/phase-heading-patterns.sh` (the shared phase-heading grammar/enum library)
- `scripts/validate-handoff.sh` (an existing, currently-unwired validator)
- `docs/architecture/handoff-schema.md` and `docs/architecture/orchestrate-state-machine.md`
- `agents/general-implementation-agent.md` and `agents/general-implementation-hard-agent.md`
  (what live writers actually do/document for `.orchestrator-handoff.json`)
- Existing test coverage under `scripts/tests/` for any of the above

No implementation was performed. This report evaluates options A/B/C on the evidence found and
flags a verification hazard for the future implementer, per the delegation instructions.

## Findings

### The gate: `skill_gate_completion_claim` (scripts/skill-base.sh, ~line 698)

Three-case, fail-closed, exactly as described in the task:

```bash
if [ "$phases_total" -gt 0 ] && [ "$phases_completed" -ge "$phases_total" ]; then
  return 0   # Case 2: present and complete — unconditional allow
fi
if [ "$phases_total" -gt 0 ]; then
  return 1   # Case 1: present, incomplete — unconditional refuse
fi
# Case 3: phases_total == 0 (accounting absent/malformed) — fall back to plan_markers_verified
[ "$plan_markers_verified" = "true" ] && return 0
return 1
```

Case 3's condition is `phases_total == 0` alone — `phases_completed`'s value is irrelevant once
`phases_total` is 0. This matches the task's framing of the trigger ("`phases_total` resolves to
0 / null") more precisely than the existing recovery-path signature (see below, which requires
BOTH counts to be 0). This is a real design choice the implementer must make explicitly, not
inherit silently — see "Open design question" below.

This function is called identically from all three sites and is the single source of the
three-case logic; nothing about it needs to change to implement Option A. It already has the
hook Option A needs: setting `plan_markers_verified="true"` from an independent source is
sufficient to flip Case 3 to allow, without touching Case 1 or Case 2 at all — so "the gate
`must never make the gate accept an uncorroborated claim`" and "Case 1 must still always refuse"
both hold automatically; Option A only ever feeds `plan_markers_verified`/`phases_*`, never the
case-selection logic itself.

### The existing corroboration block: reachable only from recovered=true (missing/stale branch)

`skill-orchestrate/SKILL.md` Stage 5 structure (identical shape in hard mode and in MT-4):

```
if [ ! -f "$handoff_file" ] || [ "$handoff_stale" = "true" ]; then
    # ... run orchestrate-recover-outcome.sh ...
    if [ "$recovered" = "true" ]; then
        phases_completed=... ; phases_total=... ; plan_markers_verified="absent"
        # ── Evidence corroboration ── (ONLY HERE)
        if [ "$evidence_suspect" = "true" ] && [ "$evidence_reason" = "PHASES_ZERO_ON_SUCCESS" ] \
           && [ "$dispatch_status" = "implemented" ]; then
            . scripts/lib/phase-heading-patterns.sh
            recovered_total=$(grep -cE "$PHASE_HEADING_ERE" "$plan")
            recovered_completed=$(grep -cE "$PHASE_HEADING_DONE_ERE" "$plan")
            if has_nonconforming_phase_headings "$plan"; then
                # leave plan_markers_verified=absent
            elif [ "$recovered_total" -gt 0 ] && [ "$recovered_completed" -eq "$recovered_total" ]; then
                phases_completed="$recovered_total"; phases_total="$recovered_total"
                plan_markers_verified="true"
                echo "[UNVERIFIED PHASES CORROBORATED] ..."
            else
                # non-corroborating: leave everything as-is
            fi
        fi
    else
        # ... phase-marker recovery grep (diagnostic only, never sets plan_markers_verified) ...
    fi
else
    # ── handoff-present branch ── NO CORROBORATION HERE
    dispatch_status=$(jq -r '.status // ""' <<<"$handoff")
    phases_completed=$(jq -r '.phases_completed // 0' <<<"$handoff")
    phases_total=$(jq -r '.phases_total // 0' <<<"$handoff")
    plan_markers_verified=$(jq -r '.plan_markers_verified // "absent"' <<<"$handoff")
    ...
    have_outcome=true
fi
# shared tail: calls skill_gate_completion_claim using whichever branch set the variables
```

Confirmed in **all three** engines — single-task base (`skill-orchestrate/SKILL.md` Stage 5),
multi-task base (Stage MT-4 step 1/2 — its own comment says "this step's own read applies only
when a handoff was actually present," i.e., it also just reads the raw fields with no
corroboration), and hard mode (`skill-orchestrate-hard/SKILL.md` Stage 5, whose own inline
comment even predicts the gap will be rare — "Hard mode's per-phase dispatch always populates
accounting, so Case 3 should be near-unreachable here" — but does not close it). This is the
exact "identical mirror" precedent Work item C asks to reuse, and it already exists for the
*missing-handoff* corroboration; Option A's job is to add a second, parallel "identical mirror"
for the *present-handoff* corroboration, in the same three places.

### `scripts/lib/phase-heading-patterns.sh` — confirmed reusable as-is

`PHASE_HEADING_ERE`, `PHASE_HEADING_DONE_ERE` (counts `[COMPLETED]` and
`[COMPLETED WITH EXCLUSIONS]` as closed), `has_nonconforming_phase_headings`, and
`warn_nonconforming` are all general-purpose and already used by the existing corroboration
block with no plan-state assumptions that would prevent reuse on the handoff-present path. No
new counting logic is needed; the task's "REUSE, DO NOT RE-INVENT" instruction is fully
achievable by copying the existing three-way branch (non-conforming → leave absent; fully closed
→ correct and set `true`; partial → leave untouched) verbatim into the new trigger site.

### Constraint-text hazard: the "MUST NOT (Context Flatness Constraint)" contract must also change

This is the most important finding not named in the task description. Both engines contain an
explicit prose contract stating the plan-file corroboration read is bounded to the
missing/stale-handoff branch, and nowhere else:

- `skill-orchestrate/SKILL.md`'s `## MUST NOT (Context Flatness Constraint)` section states,
  verbatim: *"These two exceptions narrow item 2 inside one branch; they do not relax items 1,
  3, or 4, and **they do not relax item 2 anywhere else**."* It also enumerates the corroboration
  block's precondition as "TWO reachable branches" (the missing/stale diagnostic branch, and the
  recovered=true evidence-corroboration branch) and says explicitly "Neither branch is a routine
  per-cycle read, and neither is a substitute for reading a handoff that is present and fresh."
- `skill-orchestrate-hard/SKILL.md`'s `## Tool Constraints (Pure Dispatcher)` → "Read allowlist"
  item 3(c) says the count-only phase-marker grep "fires only inside the missing/stale-handoff
  branch."

Implementing Option A therefore means these two passages become false the moment the new code
lands, unless they are edited in the same change. This is not optional cleanup — a future
maintainer or automated audit that reads either constraint section as ground truth would flag the
new code as violating a stated invariant, and the sentence "they do not relax item 2 anywhere
else" is a direct, specific claim the new code would falsify. The natural edit is to add a THIRD
reachable branch to both passages' enumeration (handoff-present + `phases_total==0` +
`status=="implemented"`), preserving the same four bounds (fields-only / narrow precondition /
token ceiling / diagnostic-vs-evidence-based-escalation framing) already used for the other two
branches, rather than loosening the constraint's wording generally.

**This is also the "verification hazard" the delegation context asked to be flagged**: both of
these are files the task's own `file_scope` names as orchestrator-critical
(`skill-orchestrate/SKILL.md`, `skill-orchestrate-hard/SKILL.md`). A change to either is normally
verifiable only against a scratch copy of the deploy tree (a throwaway clone or worktree with its
own `.claude/` regenerated from the edited source store), never against the live, currently-
running `.claude/` this session and its sibling sessions are actively being orchestrated through.
Editing `skill-orchestrate/SKILL.md` in place and then invoking `/orchestrate` (or any command
routed through it) against the *live* deploy before redeploying validated content risks the
orchestrator reading a half-edited or syntactically-broken Stage 5 mid-cycle for *every task
currently being orchestrated*, not just this one. The plan for this task should include an
explicit "verify via scratch deploy-tree copy, never the live `.claude/`" gate before any redeploy
step, mirroring how source-store-vs-deploy separation is already treated as load-bearing
elsewhere in this repo (`source-store-deploy-boundary.md`).

### `skill_write_orchestrator_handoff` has zero live callers

`scripts/skill-base.sh` documents this function's own disposition explicitly: *"this function
currently has ZERO callers anywhere in the deployed tree (confirmed by grep across
agent-system/extensions/ — only comments and doc cross-references name it, no invocation)."* It
does default `ORCHESTRATOR_HANDOFF_PHASES_COMPLETED`/`_TOTAL` to `0` via
`"${ORCHESTRATOR_HANDOFF_PHASES_COMPLETED:-0}"`, exactly as Option B's premise states — but
because nothing calls it, this default protects nobody today. Option B's "agents using the helper
are fine; the gap is agents composing the handoff with a raw `jq -n`" frames this as two
populations (helper-users vs. raw-jq-users) when in fact there is only one population today:
agents composing free-text JSON directly in their own response, following a worked example
embedded in prose (`general-implementation-hard-agent.md` Stage 5's `Always write this file, even
on successful completion:` block, and the `handoff-schema.md` "Handoff Writers" table which names
that same agent's H9 wrap-up as "The only active writer of `.orchestrator-handoff.json` today").
The worked example itself IS correct (shows `"phases_completed": N, "phases_total": M` as
placeholders for real integers) — the gap is that nothing enforces the LLM actually substitutes
real integers for `N`/`M` rather than, e.g., leaving them null under uncertainty.

### `validate-handoff.sh`: an unwired, ready-made producer-side check

`scripts/validate-handoff.sh` already does exactly what Option B would need on the producer side:
its Check 2 treats `phases_completed`/`phases_total` as required fields and explicitly fails when
either is `null` or missing (`"value" == "__MISSING__" || ("value" == "null" && field != "blockers")`
→ `log_fail`). It is referenced by exactly two other files, both as documentation/precedent, never
as an invocation:
- `docs/architecture/handoff-schema.md` (prose only)
- `scripts/orchestrate-triage-classify.sh` (a comment citing it as precedent for dual-form
  continuation acceptance, not a call)

Grepping both `SKILL.md` engines and both implementation-agent contracts for `validate-handoff`
finds zero invocations. If Option B is adopted in any form, wiring this existing script into the
hard-mode agent's H9 Stage 5 (self-check its own handoff before finishing) or into the
orchestrator's Stage 5 handoff-present branch (log-only, since a REFUSE-worthy defect should still
route through the corroboration/gate machinery rather than a hard stop) is a much smaller change
than writing new validation logic, and directly closes the "null instead of populated" failure
mode at the source rather than only at the reader.

### Why the OBSERVED LIVE scenario plausibly happened under base mode, not hard mode

`handoff-schema.md`'s "Handoff Writers" table states base-mode `skill-implementer`
(`general-implementation-agent.md`, the agent a `meta`-typed task like the empirically observed
10-phase example would route through under `/orchestrate` without `--hard`) is in the "Never
writes a handoff, by design... base-mode plan/implement simply never gained a writer" row — this
is an *expected-missing* case, recoverable via `.return-meta.json`, not a defect case.

Yet the observed scenario had a handoff *present*, with `phases_completed: null,
phases_total: null, plan_markers_verified: null`. Reading `general-implementation-agent.md`
directly: it has extensive instructions and worked examples for writing markdown handoff
*artifacts* (`handoffs/phase-{P}-handoff-{TIMESTAMP}.md`, for continuation between phase
dispatches) and for `.return-meta.json` (with a full worked JSON example, including the correct
NESTED placement of `phases_completed`/`phases_total` inside `metadata`) — but contains **no
worked example and no instruction at all** for `.orchestrator-handoff.json`'s shape. The
delegation context passed to every orchestrator-mode dispatch does include a `handoff_path`
field regardless of task type or hard/base mode (confirmed in Stage 4's context objects for
`researched`, `planned`/`implementing`, `partial`, and `blocked` states). A plausible,
evidence-consistent (not proven — flagged as inference, matching the task description's own
"empirical, not code review" caveat) explanation: the base-mode agent, seeing a `handoff_path`
field in its context but no format to imitate for that specific file, wrote one anyway by
analogy/improvisation and defaulted uncertain fields to `null` rather than `0`. If this diagnosis
is correct, it argues for Option B addressing base-mode agents too — either an explicit
instruction that base-mode implement should NOT write `.orchestrator-handoff.json` (tightening
the existing "never writes one, by design" contract from a silent absence into a stated
prohibition), or, if writing one defensively is acceptable, requiring it reuse the exact
integers already computed for Stage 5a's plan-heading repair pass (which both base and hard
agent contracts already run) rather than defaulting to null.

### No existing test coverage for the gate or the corroboration logic

`scripts/tests/` has no file referencing `skill_gate_completion_claim` or
`orchestrate-recover-outcome.sh`, and no file testing the inline corroboration bash block in
either `SKILL.md`. The only related test is `test-phase-heading-patterns.sh`, which tests the
shared library in isolation (fixture-driven, `mktemp -d` workdir, sourced-not-subprocessed,
`pass()`/`fail()`/`info()` counters — a directly reusable structural model). This means the
verification bar's three fixtures (all-closed → allow with banner; partial → refuse; zero
conforming headings → refuse with warning) have no existing harness to slot into; the
implementer will need to either (a) write a new fixture-driven test that sources
`skill-base.sh` + `phase-heading-patterns.sh` and directly exercises
`skill_gate_completion_claim` plus a small harness reproducing the new corroboration logic, or
(b) extract the corroboration logic itself into a small sourced function (mirroring how
`orchestrate-recover-outcome.sh` was extracted for the missing-handoff side) so it is testable
directly rather than only as embedded markdown-fenced bash. Given the block is about to be
duplicated a *second* time across three engines (it is already duplicated once, for the
recovery-path corroboration), extracting a shared function is worth strong consideration — not
because it's required by the task, but because it is the only way to make "the three engines
agree" mechanically checkable rather than eyeballed, and it is the only way to give the
verification-bar fixtures a stable, non-`SKILL.md`-embedded thing to test against. This is a
recommendation for the planner to weigh, not a predetermined answer.

## Decisions

None — this is a research-only task per the delegation instructions. No implementation was
performed.

## Evaluation of Options A/B/C

**Option A (widen the corroboration trigger to the handoff-present path)**: Directly closes the
asymmetry the task exists to fix, reuses 100% of the existing counting/enum logic, and the gate
function needs zero changes. Concrete cost beyond the bash itself: the "MUST NOT (Context
Flatness Constraint)" prose in both `SKILL.md` files must be edited in the same change (see
"Constraint-text hazard" above) or the new code contradicts a stated invariant. Recommended as
the core fix — it is the only option that actually changes what the gate sees for a handoff
that already exists with omitted optional fields, which is precisely the scenario in the task.

**Option B (close the producer side)**: Valuable defense-in-depth, not a substitute for A —
even a perfectly-instructed producer cannot retroactively fix a handoff some other, uncontracted
write path already produced (which the evidence above suggests is exactly what happened in the
observed case: an off-contract write from an agent with no documented format to follow). Concrete
near-free win identified during research: wiring the already-built, already-correct
`validate-handoff.sh` into the hard-mode agent's own H9 self-check (or as a Stage-5 log-only
diagnostic on the orchestrator side) would catch the null-field case at write time for the one
population (hard-mode H9 writers) that has a documented contract to enforce against. A second,
lower-confidence but evidence-consistent action: tighten `general-implementation-agent.md` (base
mode) to either explicitly not write `.orchestrator-handoff.json`, or, if it does, to source real
integers from the same Stage 5a plan-heading pass it already runs for `.return-meta.json`.

**Option C (mirror into MT and hard)**: Structurally required if A is adopted, matching the
existing "identical mirror" precedent already used for the recovery-path corroboration in all
three engines (confirmed present and byte-for-byte parallel in single-task base, Stage MT-4, and
hard-mode single-task today). No engine currently diverges on this dimension, so there is no
precedent yet for a deliberate three-way split the way the `blocked`-row divergence in
`orchestrate-triage-classify.sh`'s engine table is documented — if the implementer ends up
needing one (e.g., hard mode's per-phase dispatch making the trigger genuinely unreachable in
practice), it should be recorded in-file the same way that divergence is, with the same
"this is a DESIGN, not an undocumented assertion" framing, rather than silently varying.

**Recommendation**: adopt A and C together (they are not separable in practice — C is A applied
three times), edit the constraint-text passages in the same change, and treat B's
`validate-handoff.sh`-wiring sub-option as a cheap, additive follow-on within the same task
rather than a separate task, since it reuses an already-built script with no new logic.

## Risks & Mitigations

- **Verification hazard (flagged per delegation instructions)**: `skill-orchestrate/SKILL.md` and
  `skill-orchestrate-hard/SKILL.md` are orchestrator-critical and are the files this repo's own
  `/orchestrate` command is currently driving other in-flight tasks through. A syntax or logic
  error introduced mid-edit and picked up by a live redeploy before verification would affect
  every task being orchestrated, not just this one. Mitigation: verify (`bash -n` on extracted
  embedded bash, plus the three fixture scenarios) against a scratch copy of the deploy tree — a
  disposable worktree or clone with its own regenerated `.claude/` — before the normal
  source-store → deploy sync step touches the live, in-use `.claude/`.
- **Constraint-text drift**: if the bash is added without updating the "MUST NOT" / "Read
  allowlist" prose, the two go out of sync immediately. Mitigation: treat the prose edit as part
  of the same phase as the bash edit, not a follow-up.
- **Ambiguous trigger precondition**: the task says "phases_total resolves to 0/null" but the
  existing `PHASES_ZERO_ON_SUCCESS` signature (used on the recovery path) requires BOTH
  `phases_completed == 0` AND `phases_total == 0`. `skill_gate_completion_claim`'s own Case 3
  precondition is `phases_total == 0` alone. Using the gate's own precondition (total-only) is
  more symmetric with what the gate actually checks; using the existing evidence-signature
  precondition (both zero) is more symmetric with the recovery-path mirror precedent. This is a
  genuine open design choice, not resolvable from evidence alone — flagged for the planner rather
  than decided here.
- **Untestable-in-place logic**: with no existing harness for `skill_gate_completion_claim` or
  the corroboration block, the verification bar's three fixtures need new test infrastructure
  built from scratch. Mitigation: model the new test file on
  `scripts/tests/test-phase-heading-patterns.sh`'s structure (mktemp workdir, sourced functions,
  pass/fail counters), and strongly consider extracting the corroboration logic to a sourced
  function first so the fixtures test real production code rather than a hand-copied
  reimplementation of the `SKILL.md`-embedded bash.

## Context Extension Recommendations

- **Topic**: producer-side handoff validation
- **Gap**: `validate-handoff.sh` exists, is correct, and is entirely unwired into any live path.
  No context file currently documents this as a known gap or names it as a candidate follow-up.
- **Recommendation**: if Option B's `validate-handoff.sh`-wiring sub-option is not adopted in this
  task, record it explicitly (e.g., a note in `docs/architecture/handoff-schema.md`'s "Handoff
  Writers" section) so a future reader does not have to re-discover, via grep, that the script is
  dead code.

## Appendix

### Search queries / commands used

- `find . -iname "*phase-heading-patterns*"`, `find . -ipath "*skill-orchestrate*"`,
  `find . -iname "*orchestrate-recover-outcome*"`
- `grep -rn "skill_gate_completion_claim"`, `grep -rln "evidence_suspect\|PHASES_ZERO_ON_SUCCESS"`,
  `grep -rln "phases_completed\|phases_total"` across `agent-system/extensions/core`
- Full reads of `scripts/lib/phase-heading-patterns.sh`, `scripts/orchestrate-recover-outcome.sh`,
  `scripts/validate-handoff.sh`
- Targeted reads (line-ranged) of `skills/skill-orchestrate/SKILL.md` Stage 5 (~562-992) and
  Stage MT-4 (~1720-1940), `skills/skill-orchestrate-hard/SKILL.md` Stage 5 (~754-1180) and Tool
  Constraints (~1-68), `scripts/skill-base.sh`'s `skill_gate_completion_claim` (~668-731) and
  `skill_write_orchestrator_handoff` (~547-666), `docs/architecture/handoff-schema.md` (~199-298),
  `docs/architecture/orchestrate-state-machine.md` (~230-290)
- `grep -n "handoff\|MUST NOT" agents/general-implementation-agent.md` to confirm the absence of
  an `.orchestrator-handoff.json` worked example in the base-mode agent contract
- `grep -rl "validate-handoff.sh"` to confirm it has exactly two referrers, neither an invocation
- `find scripts/tests -iname "*orchestrat*" -o -iname "*corrobor*" -o -iname "*gate-completion*"`
  to confirm no existing test coverage

### Anchors for the implementer (symbol/heading-based, not line-number-based)

- `skill-orchestrate/SKILL.md`: `### Stage 5: Handoff Reading`, the `else` branch after
  `if [ ! -f "$handoff_file" ] || [ "$handoff_stale" = "true" ]; then ... else` (handoff-present
  read of `phases_completed`/`phases_total`/`plan_markers_verified`), and
  `## MUST NOT (Context Flatness Constraint)`.
- `skill-orchestrate/SKILL.md`: `### Stage MT-4: Phase-Aware Dispatch and Per-Task Postflight`,
  numbered step 2 ("Extract `dispatch_status`... freshly per task").
- `skill-orchestrate-hard/SKILL.md`: `### Stage 5: Handoff Reading (after each dispatch)` (the
  `<!-- BEGIN 772 Item 5B -->` / `<!-- END 772 Item 5B -->` block), and
  `## Tool Constraints (Pure Dispatcher)` → "Read allowlist" item naming the missing/stale-handoff
  scoping.
- `scripts/skill-base.sh`: `skill_gate_completion_claim()`, `skill_write_orchestrator_handoff()`.
- `scripts/lib/phase-heading-patterns.sh`: `PHASE_HEADING_ERE`, `PHASE_HEADING_DONE_ERE`,
  `has_nonconforming_phase_headings`, `warn_nonconforming`.
- `scripts/validate-handoff.sh`: Check 2 (required-field-null-fails-closed).
- `agents/general-implementation-agent.md`: absence of any `.orchestrator-handoff.json` section
  (searched for `handoff` and `MUST NOT`).

# Research Report: Task #898

**Task**: 898 - Completion-claim verification gate for the orchestrate skills
**Started**: 2026-07-25T00:00:00Z
**Completed**: 2026-07-25T00:00:00Z
**Effort**: Medium (doc reconciliation + one shared bash function + three call-site wire-ups)
**Dependencies**: Composes with the sibling task that added the phase-marker-grep recovery
carve-out to both orchestrate skills and reconciled `handoff-schema.md` /
`orchestrate-state-machine.md`'s "orchestrator never reads plan files" claim (see that task's
implementation summary, referenced by artifact path only — no task-number citation below).
**Sources/Inputs**: Codebase (`agent-system/extensions/core/**`, on-disk `specs/*/.orchestrator-handoff.json`
runtime samples), WebSearch (current AI-agent verification literature)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The described defect is already substantially fixed on disk.** Both `skill-orchestrate` Stage
  5 and Stage MT-4, and `skill-orchestrate-hard` Stage 5, already read `phases_completed` /
  `phases_total` from the handoff and refuse to run `skill_postflight_update ... implemented` when
  `phases_completed < phases_total`. What remains genuinely missing is `plan_markers_verified`
  handling (never read anywhere) and a uniform three-case, fail-closed treatment of the "phase
  accounting absent" case.
- **The field-location mismatch is real, but it is a doc bug, not a code bug.** There is exactly
  **one active writer** of `.orchestrator-handoff.json` in the core source tree —
  `general-implementation-hard-agent.md`'s H9 wrap-up (Stage 5) — plus one **dead, zero-caller**
  shared function (`skill_write_orchestrator_handoff` in `skill-base.sh`). Both already place
  `phases_completed`/`phases_total` at the **top level**. Every reader in both orchestrate skills
  already reads top level. 177 of 203 on-disk runtime handoff samples confirm top-level
  placement; only 1 sample is nested-only. `docs/architecture/handoff-schema.md`'s illustrative
  JSON Schema and `orchestrate-state-machine.md`'s example flow are the only artifacts that show
  the nested placement — **recommend Decision (a): keep/declare top level as canonical and fix
  the two docs**, not "move" the fields (they are already where they need to be).
- **A structurally larger, out-of-scope fact surfaced during verification**: base-mode (non-
  `--hard`) `skill-researcher`, `skill-planner`, and `skill-implementer` never write
  `.orchestrator-handoff.json` at all — confirmed by grep across every `.md`/`.sh` file in
  `agent-system/extensions/core/` and by `reconcile-task-status.sh`'s own inline comment
  ("`.orchestrator-handoff.json` is written only by hard-mode dispatch paths"). This gate's design
  must not assume base-mode dispatches ever populate a handoff; it only has teeth today for
  hard-mode dispatches (and the rare base-mode handoff a caller writes by hand, e.g. the one
  nested-only outlier found on disk).
- **`plan_markers_verified` is populated in only 28 of 203 (14%) on-disk samples**, even though
  the sole active writer's own contract says to set it on every dispatch once Stage 5a passes.
  This corroborates the task's premise that phase evidence is inconsistently emitted and that a
  fail-closed, three-case gate (not a blind allow) is the right response to an absent field.
- **Recommendation**: extract ONE shared bash function (e.g. `skill_gate_completion_claim`) into
  `skill-base.sh` that implements the three-case logic once, and call it identically from base
  Stage 5, hard Stage 5, and MT-4 — replacing the current copy-pasted arithmetic-only gate in all
  three sites. Do not reuse the sibling task's phase-marker-grep recovery exception; it is
  precondition-scoped to the missing/stale-handoff branch and this gate fires only when a handoff
  IS present, so reuse would violate both that exception's own "nowhere else" contract and this
  task's own no-plan-file-reads constraint.

## Context & Scope

Researched the current (on-disk, `agent-system/extensions/core/**`) state of the completion-claim
gating logic in `skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md`, the
`.orchestrator-handoff.json` schema documentation, and the actual field-placement behavior of
every component in the source tree that could plausibly write that file. Verified against 203
real runtime `.orchestrator-handoff.json` files still present under `specs/*/` (gitignored,
never committed, left over from real `/orchestrate` and `/orchestrate --hard` runs). Also
reviewed the sibling task's already-landed phase-marker-grep recovery carve-out to determine
whether this gate should compose with or stay independent of it. Did not read any plan files,
research reports, or summaries to verify completion claims for hypothetical future dispatches —
only to characterize the CURRENT code and CURRENT doc/code drift, which is examining the
orchestrator's own source, not the deliverables it produces.

## Findings

### Codebase Patterns

**1. The "implemented" phase-completion gate already exists in all three orchestrator call
sites — with a real gap only in `plan_markers_verified` handling.**

`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` Stage 5 (`implemented` case,
current text):
```bash
if [ "$phases_total" -eq 0 ] || [ "$phases_completed" -ge "$phases_total" ]; then
  skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status" "warn"
else
  echo "[orchestrate] Phase ${phases_completed}/${phases_total} complete — task not done. Continuing." >&2
  # No status transition — cycle_count still increments; next cycle re-dispatches implement.
fi
```
`skill-orchestrate-hard/SKILL.md` Stage 5 has the same shape but is *stricter*: it requires
`phases_total -gt 0` unconditionally (no zero-pass-through) before allowing completion. Base
Stage MT-4 (step 3) mirrors the base Stage 5 logic per-task, freshly re-reading each task's own
handoff every cycle. All three sites already increment `cycle_count`/`MAX_CYCLES_MT` on refusal
and leave the task at `implementing`, so a persistently-misreporting agent already terminates
against the existing cap (`MAX_CYCLES=5` base, `MAX_CYCLES=13` hard, `MAX_CYCLES_MT=min(task_count*5,25)`
multi-task) rather than looping forever — this part of the DESIGN CONSTRAINTS is already
satisfied by the existing arithmetic gate and needs no new bound, only verification (done here).

**What is missing**: `plan_markers_verified` is read by **nothing**. `grep -rn
"plan_markers_verified" skill-orchestrate/SKILL.md skill-orchestrate-hard/SKILL.md` returns zero
hits in both files, despite `docs/architecture/handoff-schema.md:185-190` documenting the exact
orchestrator behavior expected ("When `status = "implemented"` and `plan_markers_verified` is
absent or `false`, the orchestrator logs a warning... This warning does not block the next
lifecycle phase"). The doc's own prescribed behavior (warn-only, non-blocking) is weaker than
what this task's DESIGN CONSTRAINTS ask for (fail-closed, refuse-and-continuation-eligible when
BOTH phase accounting is absent AND `plan_markers_verified` is not true) — the doc's existing
"non-blocking" prescription should be superseded, not preserved, since it does not satisfy the
three-case fail-closed requirement.

**2. There is exactly one active writer of `.orchestrator-handoff.json` in the core source
tree, plus one dead one.**

Grepped every `.md` and `.sh` file under `agent-system/extensions/core/` for
`orchestrator-handoff` / `skill_write_orchestrator_handoff` / `write_orchestrator_handoff`, then
traced each hit to determine whether it is a writer, a reader, or prose referencing the concept:

| Component | Writes `.orchestrator-handoff.json`? | Evidence |
|---|---|---|
| `skill-base.sh`'s `skill_write_orchestrator_handoff()` | Defined, but **zero call sites** anywhere in the tree | `grep -rn skill_write_orchestrator_handoff` matches only the function's own definition and doc prose referencing it |
| `general-research-agent.md` (base) | No | Explicitly states it must NOT use `.orchestrator-handoff.json`'s H9 schema for research handoffs (a different, markdown-based handoff type) |
| `general-research-hard-agent.md` | No | Same explicit non-use statement |
| `planner-agent.md` / `planner-hard-agent.md` | No | Zero mentions of `orchestrator-handoff` in either file |
| `skill-researcher/SKILL.md` / `skill-planner/SKILL.md` | No | Zero mentions beyond the unrelated word "orchestrator" in delegation_path prose |
| `general-implementation-agent.md` (base) | No | Zero mentions in the entire file |
| `skill-implementer/SKILL.md` (base) | No | Zero mentions in the entire 754-line file; its only phase-completion backstop is `update-task-status.sh postflight ... --phase-check=refuse`, which independently re-derives phase completion from the **plan file's own headings** (ground truth), not from any handoff |
| **`general-implementation-hard-agent.md`** | **Yes** | Stage 5 (H9 Wrap-Up Contract): "Write the orchestrator handoff... Always write this file, even on successful completion" — writes `status`, `phases_completed`, `phases_total` at top level; Stage 5a separately sets `plan_markers_verified: true` when marker verification+repair passes |
| `skill-implementer-hard/SKILL.md` | No (reads `.return-meta.json`, not the handoff) | Reads `phases_completed`/`phases_total` from `.return-meta.json` for its own per-phase loop bookkeeping |
| `cslib-implementation-hard-agent.md`, `lean-implementation-hard-agent.md` (extensions) | Yes (same H9 pattern) | Confirms the "only the hard-mode implementation agent writes it" pattern extends to extension agents, not just core |
| `reconcile-task-status.sh` | No (reader only) | Its own inline comment states the fact plainly: `.orchestrator-handoff.json is written only by hard-mode dispatch paths` |

**Total: 1 active writer** (`general-implementation-hard-agent.md`'s H9 Stage 5, replicated by
its extension counterparts) **+ 1 dead writer** (`skill_write_orchestrator_handoff`, unreferenced).
Base-mode research, plan, and implement dispatches **structurally never produce**
`.orchestrator-handoff.json` — every base-mode cycle falls into Stage 5's missing-handoff branch.
This is a pre-existing architectural gap, out of this task's scope to fix, but directly bears on
the DECISION POINT: there is no meaningful population of "writers who use the nested form" to
weigh against — only one writer matters, and it already writes top level.

**3. On-disk evidence overwhelmingly confirms top-level placement, with one nested-only outlier.**

Scanned all 203 `.orchestrator-handoff.json` files still present under `specs/*/` (gitignored
runtime artifacts, never git-committed, left over from real `/orchestrate` invocations in this
repository):

| Placement | Count |
|---|---|
| Top-level `phases_completed`/`phases_total` only | 177 |
| Nested-only (`continuation_context.phases_completed`/`.phases_total`, top level absent) | 1 |
| Both top-level and nested present | 0 |
| Neither present (research/plan-phase handoffs, or pre-convention handoffs) | 25 |

The single nested-only outlier is worth naming as corroborating evidence of the exact confusion
this task expects: a writer that followed the doc's illustrative nested example instead of the
dominant top-level convention actually exists on disk today, in this repository.

`plan_markers_verified` presence: **28 of 203 (14%) are `true`; the remaining 175 have the field
entirely absent** — despite `general-implementation-hard-agent.md`'s own contract instructing it
to set the field on every dispatch once Stage 5a passes. This is independent, real-world evidence
that Case 3 (phase accounting or plan_markers_verified absent) is common enough in practice that
this gate's fallback behavior for that case matters, not a hypothetical edge case.

**4. `handoff-schema.md`'s Complete JSON Schema example is the ONLY artifact that shows the
nested placement**, and it is inconsistent with its own later "Example Handoff Objects" section
in the same file:
```json
// "Complete JSON Schema" (top of file) — nests phases_completed/phases_total under
// continuation_context, and shows plan_markers_verified at top level:
"continuation_context": {
  "handoff_path": "...",
  "phases_completed": 2,
  "phases_total": 4
},
"plan_markers_verified": true
```
```json
// "Partial with Continuation" example (further down the SAME file) — same nested placement
"continuation_context": {
  "handoff_path": "...",
  "phases_completed": 2,
  "phases_total": 4,
  "orchestrator_mode": true
}
```
Neither example shows the top-level placement that both real writers (active and dead) and both
real readers (base and hard `skill-orchestrate`) actually use. `orchestrate-state-machine.md`'s
"Partial Recovery Flow" example duplicates the same nested placement. All three doc locations
need the same fix.

**5. The sibling task's phase-marker-grep recovery exception is precondition-disjoint from this
gate and should NOT be reused.** That exception (in both orchestrate skills' Stage 5) fires
"ONLY when Stage 5 has already determined that this dispatch's `.orchestrator-handoff.json` is
missing or stale" — i.e., inside the `if [ ! -f "$handoff_file" ] || [ "$handoff_stale" = "true" ]`
branch. This task's gate fires in the opposite branch: a handoff IS present and fresh, and its
`status` field claims `"implemented"`. The recovery exception's own contract text is explicit
that it is "recovery-only" and fires "nowhere else," and this task's own DESIGN CONSTRAINTS
separately forbid reading plan files for verification. Both constraints point the same
direction: build this gate strictly from fields already inside the parsed handoff object
(`phases_completed`, `phases_total`, `plan_markers_verified`), and do not invoke the grep
recovery path from within it.

**6. `update-task-status.sh --phase-check=refuse` is a genuinely independent, stronger backstop
that already exists at the skill layer** (not the orchestrator layer this task targets). It reads
the plan file's own `### Phase N: ... [STATUS]` headings directly — ground truth, immune to
handoff self-report errors — and refuses (`exit 4`) to promote `implementing -> completed` if any
phase heading is not `[COMPLETED]`. `skill-implementer/SKILL.md` and `skill-implementer-hard/SKILL.md`
both call it. This is why the orchestrator-layer gates in Stage 5/MT-4 deliberately use `"warn"`
mode rather than `"refuse"` when phase accounting looks complete: the skill layer has already
made the authoritative call using richer, ground-truth evidence than the orchestrator is allowed
to read. This task's new gate should preserve that division of labor — it adds a fail-closed
check for the case the skill-layer backstop cannot fully cover (a completed-looking handoff that
is nonetheless internally inconsistent or missing corroborating evidence), not replace it.

### External Resources

Current (July 2026) literature on autonomous-agent completion-claim verification converges on a
few points directly relevant to this gate's design:

- Self-assessment is not a reliable substitute for external, independently-checkable evidence: "a
  model that misunderstood the task is equally likely to misjudge its own success at completing
  it" — directly analogous to why this gate must not trust `status: "implemented"` alone and must
  require corroborating phase/marker evidence from the handoff.
- A well-documented failure mode in autonomous computer-use agents is declaring a task complete
  when it is not (or the reverse — completing it but not recognizing that), which is structurally
  the same class of defect task 898 targets in the orchestrate skills.
- Evidence-grounded verification approaches (claim identification, supporting-evidence analysis,
  verification planning) generalize the idea this gate already implements at small scale: treat
  `status: "implemented"` as a claim, and require it to be checkable against independently-
  populated fields (`phases_completed`/`phases_total`, `plan_markers_verified`) rather than
  accepted at face value — this is consistent with the fail-closed, three-case design specified in
  this task's DESIGN CONSTRAINTS (present-and-short / present-and-complete / absent-with-fallback),
  rather than a binary trust/don't-trust the self-report.
- On fail-open vs. fail-closed design specifically: when the verifier cannot afford to re-read the
  work product (this task's explicit context-flatness constraint — no plan/report reads), the
  literature's guidance converges on failing closed on absent or ambiguous evidence and routing to
  a cheaper corroborating signal before allowing the claim, which is exactly the plan_markers_verified
  fallback this task specifies for the "absent" case, rather than a blind allow (today's base-mode
  behavior) or a blind refuse (which would violate the "must never regress into never completing"
  constraint already documented in the base skill's existing gate).

Sources:
- [Autonomous AI Agents: How They Think, Plan, and Complete Tasks](https://medium.com/@achivx/autonomous-ai-agents-how-they-think-plan-and-complete-tasks-14b7b8a884ef)
- ["Are We Done Yet?": A Vision-Based Judge for Autonomous Task Completion of Computer Use Agents](https://arxiv.org/pdf/2511.20067)
- [Safety Testing LLM Agents at Scale: From Risk Discovery to Evidence-Grounded Verification](https://arxiv.org/html/2607.01793v2)
- [From Fluent to Verifiable: Claim-Level Auditability for Deep Research Agents](https://arxiv.org/html/2602.13855)
- [Guideline-Grounded Evidence Accumulation for High-Stakes Agent Verification](https://arxiv.org/pdf/2603.02798)

### Recommendations

1. **DECISION POINT resolution: Option (a).** Declare top-level `phases_completed`/`phases_total`
   canonical. Do not touch any reader code (all three already read top level correctly). Fix
   three doc locations to match: `handoff-schema.md`'s "Complete JSON Schema" block, its "Partial
   with Continuation" example, and `orchestrate-state-machine.md`'s "Partial Recovery Flow"
   example — move `phases_completed`/`phases_total` out of `continuation_context` to the object's
   top level in all three, leaving `continuation_context` holding only `handoff_path` (and
   `orchestrator_mode` where already present). Justification: exactly one active writer exists
   and it already writes top level; the dead `skill_write_orchestrator_handoff` function also
   already writes top level; 177/203 real samples are top-level-only; only 1/203 is nested-only
   (itself evidence of the doc-caused confusion this fixes). There is no meaningful population of
   writers using the nested form to preserve compatibility with.
2. **Add `plan_markers_verified` reading to all three call sites** (base Stage 5, hard Stage 5,
   MT-4), superseding `handoff-schema.md`'s current "non-blocking warning only" prescription with
   the fail-closed three-case behavior this task specifies.
3. **Extract ONE shared function** — e.g. `skill_gate_completion_claim` in `skill-base.sh` —
   implementing the three-case logic exactly once:
   - Case 1 (phase accounting present, `phases_completed < phases_total`): refuse, log
     `"[orchestrate] COMPLETION-CLAIM GATE case 1/3 (phase accounting present, incomplete): N/M — refusing completion."`,
     no status transition, cycle continues (existing arithmetic gate's behavior, unchanged).
   - Case 2 (phase accounting present and complete, `phases_completed >= phases_total`): allow via
     `skill_postflight_update ... "warn"` (unchanged from today — this is the existing behavior in
     all three sites).
   - Case 3 (phase accounting absent, i.e. `phases_total == 0`/missing): fall back to
     `plan_markers_verified`. If `true`, allow with an info-level log naming the fallback used. If
     absent or `false`, refuse with
     `"[orchestrate] COMPLETION-CLAIM GATE case 3/3 (phase accounting absent, plan_markers_verified={absent|false}): refusing completion — handoff-writer defect suspected."`
     and treat as continuation-eligible (same no-transition, cycle-continues behavior as Case 1).
   Call this function identically from `skill-orchestrate/SKILL.md` Stage 5, Stage MT-4, and
   `skill-orchestrate-hard/SKILL.md` Stage 5, replacing the current three independently-copied
   arithmetic-only `if` blocks. This directly addresses the original DEFECT framing (MT-4 having
   no evidence check) by construction — a shared function cannot silently diverge across sites
   the way three hand-copied inline blocks already have (hard mode's `phases_total -gt 0` vs
   base's `phases_total -eq 0` pass-through is exactly this kind of copy drift, and a planner
   should decide explicitly whether the new shared function preserves that base/hard asymmetry or
   unifies it — Case 3 above unifies it by making the plan_markers_verified fallback the same in
   both modes, which is a deliberate behavior change for base mode from today's blind allow-on-
   absent to a corroborated allow/refuse).
4. **Do not reuse the phase-marker-grep recovery exception** in this gate. Keep the two mechanisms
   disjoint: recovery grep fires on missing/stale handoffs (no dispatch_status to trust at all);
   this gate fires on a present handoff whose dispatch_status claims `"implemented"` but whose
   supporting fields are weak. Note this explicitly in the plan so a future reader does not try to
   merge the two paths.
5. **Do not weaken the existing drift-detection gate.** It is orthogonal (keys off
   `dispatch_status = "partial"`, not `"implemented"`) and, per finding 3 above, is now capable of
   evaluating true for hard-mode partial dispatches (top-level fields are populated by the sole
   active writer). Verify its behavior once reachable — this is a good candidate for a dedicated
   verification phase in the plan (e.g., construct a synthetic partial handoff with
   `phases_total > 0` and confirm `invoke_drift_inspection` actually fires), since it has likely
   never been observed to fire in practice given the writer-population gap this report documents.
6. **MAX_CYCLES / MAX_CYCLES_MT interaction**: no code change needed. Refusal in Case 1 or Case 3
   already leaves the task at `implementing` and already lets the existing cycle-increment code
   run unconditionally (except for the pre-existing infra-failure exemption, which is unrelated).
   The bound already holds: `MAX_CYCLES=5` (base), `MAX_CYCLES=13` (hard), `MAX_CYCLES_MT=min(task_count*5,25)`
   (multi-task). The plan should include an explicit verification step confirming this (e.g. a
   dry-run trace or a synthetic handoff test) rather than assuming it, since the new Case 3 refusal
   path is new code even though the surrounding increment/cap machinery is not.

## Decisions

- DECISION POINT resolved as **(a)**: top-level `phases_completed`/`phases_total` is canonical;
  fix the docs, not the code. Backed by an exhaustive count of handoff writers in
  `agent-system/extensions/core/`: 1 active (`general-implementation-hard-agent.md` H9, mirrored
  by `cslib-implementation-hard-agent.md` and `lean-implementation-hard-agent.md`), 1 dead
  (`skill_write_orchestrator_handoff`, zero callers) — both already top-level.
- The sibling task's phase-marker-grep recovery exception is precondition-disjoint from this
  gate and must not be reused or merged with it.
- `handoff-schema.md`'s current "non-blocking warning" prescription for `plan_markers_verified`
  is superseded by this task's fail-closed three-case design; the doc needs updating to match,
  not preserving as-is.

## Risks & Mitigations

- **Risk**: Because base-mode dispatches never produce a handoff at all, a base-mode
  `skill-implementer` run that somehow DOES leave a stale/malformed handoff in place (e.g. a
  leftover file from a prior hard-mode run against the same task directory) could trigger this
  gate's Case 3 logic unexpectedly. **Mitigation**: the existing staleness gate (mtime vs.
  `dispatch_start_ts`) already runs before this gate would ever see the handoff, so a leftover
  file from a different mode/cycle is already routed to the missing/stale branch, not this one —
  no new interaction to design for, but worth a verification step in the plan.
- **Risk**: Extracting shared logic into `skill-base.sh` changes a load-bearing file used by many
  skills. **Mitigation**: the new function should be purely additive (a new function, not an edit
  to `skill_write_orchestrator_handoff` or any other existing function), minimizing blast radius.
- **Risk**: Changing base mode's Case 3 behavior from blind-allow to plan_markers_verified-gated
  is an intentional behavior change that could, in principle, block completion for legitimate
  base-mode handoffs (the rare hand-written or future-writer case) that omit
  `plan_markers_verified` for reasons unrelated to incompleteness. **Mitigation**: this is exactly
  the DESIGN CONSTRAINT's explicit ask ("fail CLOSED on missing evidence... rather than blindly
  allowing"), and the skill-layer `--phase-check=refuse` backstop remains the authoritative check
  either way — this orchestrator-layer gate refusing conservatively only costs one extra
  re-dispatch cycle, bounded by the existing MAX_CYCLES caps.

## Context Extension Recommendations

- **Topic**: Handoff-writer inventory. **Gap**: no existing context file documents which
  components actually write `.orchestrator-handoff.json` (this report had to derive it from
  scratch via repo-wide grep). **Recommendation**: consider adding a short "Handoff Writers"
  table to `docs/architecture/handoff-schema.md` itself (not a new file) enumerating the current
  writer(s), so future tasks don't have to re-derive this.
- **Topic**: Base-mode orchestrator-handoff coverage gap. **Gap**: the fact that base-mode
  research/plan/implement dispatches never produce `.orchestrator-handoff.json` at all is
  currently only implicit (one inline comment in `reconcile-task-status.sh`). **Recommendation**:
  this is a separate, larger task (wiring a handoff writer into the base skills, or explicitly
  documenting that base mode is handoff-less by design) — out of scope here, but worth a follow-up
  task if base-mode orchestration gating is ever expected to have the same evidence quality as
  hard mode.

## Appendix

### Search queries used
- Codebase: `grep -rn "orchestrator-handoff\|skill_write_orchestrator_handoff" agent-system/extensions/core/`
  (and per-file targeted variants), `grep -rn "phases_completed\|phases_total\|plan_markers_verified"`
  across skills/docs/agents, on-disk scan of all 203 `specs/*/.orchestrator-handoff.json` files via `jq`.
- Web: "2026 autonomous AI agent self-reported task completion verification gate fail closed
  evidence"; "LLM agent orchestration completion claim verification independently checkable
  evidence hallucination 2026".

### References
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage 5, Stage MT-4)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (Stage 5)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md`
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
- `agent-system/extensions/core/scripts/skill-base.sh`
- `agent-system/extensions/core/scripts/reconcile-task-status.sh`
- `agent-system/extensions/core/scripts/update-task-status.sh`
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md`
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md`

# Research Report: Task #897

**Task**: 897 - Sanctioned phase-marker grep exception for orchestrate
**Started**: 2026-07-25T00:00:00Z
**Completed**: 2026-07-25T00:00:00Z
**Effort**: small (single narrow rule addition to two SKILL.md files + one doc reconciliation)
**Dependencies**: sequenced after tasks 891/895 as a file-overlap serializer only (not a logical
prerequisite) — see task description
**Sources/Inputs**: Codebase (agent-system/extensions/core/skills/skill-orchestrate{,-hard}/SKILL.md,
agent-system/extensions/core/docs/architecture/handoff-schema.md,
agent-system/extensions/core/context/formats/plan-format.md, agent-system/extensions/core/rules/plan-format-enforcement.md,
specs/891_gate_orchestrate_completion_on_phase_progress/ summary)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The task description's line numbers (819-829, 828-829, 832) are **stale**. Re-verified current
  locations: base `skill-orchestrate/SKILL.md` MUST NOT section is now at **lines 1105-1116**
  (the "ONLY file read" sentence is line 1114), and the Skill-to-Agent Mapping "Drift inspection"
  row is at **line 1126**.
- `skill-orchestrate-hard/SKILL.md` has **no section literally named "MUST NOT"**. Its
  parallel constraint block is `## Tool Constraints (Pure Dispatcher)` at **lines 24-62**, with a
  4-category **Read allowlist** at lines 47-55 that **already explicitly permits reading
  `plans/*.md` and `reports/*.md`** (category 3, justified for the H4 adversarial-verification
  grep) — i.e. hard mode is *already* less restrictive than base mode's flat prohibition, and
  this pre-existing asymmetry must be accounted for, not treated as symmetric with base mode.
- Hard mode additionally already contains a **direct-grep precedent** doing almost exactly what
  this task asks for a different purpose: the `planned`/`implementing` state handler
  ("772 Item 5A", lines 465-475) runs `grep -E '^### Phase [0-9]+(\.[0-9]+)?: .*\[(NOT
  STARTED|PARTIAL|IN PROGRESS)\]' "$plan_path"` **every cycle** (not just on bad-handoff
  recovery) to pick the next phase to dispatch, overriding a naive handoff-derived increment.
  This establishes that a narrow, header-only grep against the plan file is already accepted
  practice in this codebase's own hard-mode dispatcher, via Bash (one of hard mode's 12
  permitted commands) against a Read-allowlisted file class.
- **Recommendation: (B) — add a narrow, explicitly-bounded, count-only `grep -c` exception**,
  not a fork-and-return-JSON dispatch. Token bound: **≤10 tokens per recovery event** (two
  `grep -c` integer outputs), fired **only** inside Stage 5's existing
  missing-handoff/stale-handoff branch — never as a routine per-cycle read. See Decisions below
  for the full rationale against Option A.
- The gap is real and distinct from the immediately-prior fix in task 891 (verified via that
  task's summary): 891 gated the *completed*-transition on `phases_total`/`phases_completed`
  **read successfully from an existing handoff**. It did not — and could not — address the case
  where Stage 5's `[ ! -f "$handoff_file" ] || [ "$handoff_stale" = "true" ]` branch is entered:
  in that branch, in both variants, phase accounting is never recovered from any other source;
  the cycle is only classified as infra-failure vs. charged-cycle, and the loop either
  re-dispatches or eventually exhausts `MAX_CYCLES`/`MAX_INFRA_FAILURES` with no visibility into
  true phase progress.
- `docs/architecture/handoff-schema.md` (lines 301-302) currently states as a flat, unqualified
  fact: "The orchestrator NEVER reads the actual research reports, plan files, or implementation
  summaries during its state machine loop." This is already false for hard mode's Read allowlist
  and Item 5A grep, and will become more false once the recovery exception lands — this doc needs
  a corresponding update, flagged as a Context Extension Recommendation below.

## Context & Scope

Verify whether skill-orchestrate's context-flatness MUST NOT list should gain a narrow,
recovery-only exception permitting a grep over plan-file phase-status headers (never full-file
reads) so the orchestrator has a legal way to recover `phases_completed`/`phases_total` when the
`.orchestrator-handoff.json` written by a dispatched agent is missing, stale, or malformed. Must
preserve the existing context-flatness rationale (~450 tokens/cycle) and evaluate reuse of the
existing "Drift inspection" fork-and-return-small-JSON pattern (Option A) against a direct narrow
grep exception in the MUST NOT list (Option B), per the task's explicit ask. Both
`skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md` are in scope; all edits must
target `agent-system/extensions/core/**`, never `.claude/**` (SOURCE-STORE RULE).

## Findings

### Codebase Patterns

**Base `skill-orchestrate/SKILL.md` MUST NOT section** (verified current, lines 1105-1116):

```
## MUST NOT (Context Flatness Constraint)

This skill MUST NOT:

1. **Read research reports** (`reports/*.md`) during the state machine loop
2. **Read plan files** (`plans/*.md`) during the state machine loop
3. **Read implementation summaries** (`summaries/*.md`) during the state machine loop
4. **Read continuation handoff files** (`handoffs/*.md`) — pass the path, not the content

The ONLY file read after each dispatch is `.orchestrator-handoff.json` (≤400 tokens).
This ensures context grows by only ~450 tokens per cycle regardless of artifact complexity.
```

Item 2 is the literal target of the description's requested exception. The Skill-to-Agent
Mapping table's "Drift inspection" row (line 1126) reads:
`| Drift inspection | "fork" | Inherits parent cache; reads plan file, writes
.drift-inspection.json |` — confirming the fork-and-return-small-JSON pattern the task asks to
evaluate as Option A. Stage 5a (`skill-orchestrate/SKILL.md` lines 653-687) shows the full
mechanics: a `"fork"` subagent is dispatched with a natural-language prompt instructing it to
read the whole plan file, count checklist items and deviation annotations, and write a compact
JSON (`drift_pct`, `deviation_count`, `total_items`, `completed_items`, `summary`) to
`.drift-inspection.json`, which the orchestrator then reads (small, bounded). This is capped at
`MAX_DRIFT_INSPECTIONS=1` per invocation and triggered only when `phases_total > 0 && status ==
"partial" && completion_ratio < DRIFT_COMPLETION_THRESHOLD (0.70)`.

**Hard `skill-orchestrate-hard/SKILL.md` parallel constraint section** — there is no section
titled "MUST NOT"; the functional equivalent is `## Tool Constraints (Pure Dispatcher)` (lines
24-62):

- **Permitted Bash** (lines 35-39): `jq, mkdir, mv, rm, ls, sort, tail, grep, cat, date, echo,
  source` — `grep` is already on this allowlist.
- **Read allowlist, 4 categories** (lines 47-55):
  1. `specs/state.json`
  2. `.orchestrator-handoff.json` and siblings (`.orchestrator-loop-guard`,
     `.orchestrator-churn-state.json`)
  3. **`specs/{NNN}_{SLUG}/plans/*.md` and `specs/{NNN}_{SLUG}/reports/*.md` — "reports are
     needed for the H4 adversarial-verification grep in Stage 4"** — i.e. plan-file access is
     *already sanctioned* in hard mode, for a different but structurally identical reason
     (bounded grep, not full comprehension read).
  4. `.claude/context/contracts/*.md` and `.claude/docs/architecture/*.md`.
- **Forbidden Reads** (lines 56-60): implementation source only (`lua/**`, `after/**`, etc.) —
  notably plan/report files are *not* in this forbidden list, consistent with category 3 above.

**Existing direct-grep precedent in hard mode** ("772 Item 5A", lines 465-475, inside the
`planned`/`implementing` — Per-Phase Dispatch (H1) handler):

```bash
next_phase=""
if [ -n "$plan_path" ] && [ -f "$plan_path" ]; then
  next_phase=$(grep -E '^### Phase [0-9]+(\.[0-9]+)?: .*\[(NOT STARTED|PARTIAL|IN PROGRESS)\]' "$plan_path" \
    | head -1 \
    | sed -E 's/^### Phase ([0-9]+(\.[0-9]+)?):.*/\1/')
fi
```

This runs on **every** `planned`/`implementing` cycle (not conditioned on a bad handoff) and
supersedes a naive `next_phase = phases_completed + 1` derivation, specifically because the
handoff-derived value could not address sub-phase numbering (`N.1`/`N.2`) or sparse numbering.
This is functionally a phase-header grep exception already in production for a *different*
purpose (next-phase selection) than the one task 897 asks to sanction (phases_completed/
phases_total recovery when handoff is unusable) — but it is the same access class (a bounded
`grep -E` over `### Phase N: ... [STATUS]` heading lines only) and the same file
(`$plan_path`).

**Canonical phase-heading format** (`agent-system/extensions/core/rules/plan-format-enforcement.md`
line 13): `### Phase N: {name} [STATUS]` — status lives only in the heading, valid markers
`[NOT STARTED]`, `[IN PROGRESS]`, `[COMPLETED]`, `[PARTIAL]`, `[BLOCKED]`, no emojis. This is a
stable, machine-parseable anchor that both Item 5A and the proposed recovery grep can rely on.

**The actual gap** (confirmed by reading Stage 5 in both variants, base lines 455-649 / hard
lines 679-874): the `if [ ! -f "$handoff_file" ] || [ "$handoff_stale" = "true" ]` branch (base
511-549, hard 738-776) performs **only** infra-failure discrimination
(`dispatch_was_transport_error` + `meta_touched` → exempt vs. charge a cycle). It never attempts
to recover `phases_completed`/`phases_total` from any other source. Downstream, since this
branch never enters the `case "$dispatch_status" in ...)` block (there is no `$dispatch_status`
to switch on), no postflight transition happens and the loop simply re-enters the same state
next cycle — bounded only by `MAX_CYCLES`/`MAX_INFRA_FAILURES`, with zero diagnostic signal about
how much of the plan is actually done. This is distinct from, and not fixed by, task 891's recent
change (verified via `specs/891_gate_orchestrate_completion_on_phase_progress/summaries/
01_gate-completion-on-phase-progress-summary.md`): 891 added the `phases_total == 0 ||
phases_completed >= phases_total` pass-through gate for the case where a handoff **is read
successfully** but omits phase fields. It does not touch the missing/stale-handoff branch at all.

**`docs/architecture/handoff-schema.md`** (lines 301-302) states flatly: "The orchestrator NEVER
reads the actual research reports, plan files, or implementation summaries during its state
machine loop. It reads ONLY the 400-token handoff object." This statement is already inaccurate
for hard mode (Read allowlist category 3 + Item 5A), and any change from this task will widen the
gap further unless the doc is updated in the same pass.

### External Resources

Not applicable — this is a meta task confined to the local skill-definition source store; no
external documentation is relevant.

### Recommendations

**Recommendation: Option (B) — a narrow, count-only `grep -c` exception, not Option A
(fork-and-return-small-JSON).**

Proposed mechanism (for the planner to size into phases, not prescribed in full here):

```bash
# Recovery-only: fired ONLY inside the missing/stale-handoff branch of Stage 5, never per-cycle.
if [ -n "$plan_path" ] && [ -f "$plan_path" ]; then
  recovered_total=$(grep -cE '^### Phase [0-9]+(\.[0-9]+)?: ' "$plan_path")
  recovered_completed=$(grep -cE '^### Phase [0-9]+(\.[0-9]+)?: .*\[COMPLETED\]' "$plan_path")
  echo "[orchestrate] RECOVERY: handoff unusable — plan headers show ${recovered_completed}/${recovered_total} phases [COMPLETED]." >&2
fi
```

Token bound: **two `grep -c` calls, each returning a single integer** — a hard, provable
ceiling of roughly **10 tokens total** per recovery event (well inside the existing ≤400-token
handoff budget, and negligible next to the "~450 tokens per cycle" invariant, which this
exception never touches on the normal successful-handoff path since it only fires inside the
already-existing missing/stale branch).

**Why (B) over (A)**:
1. **Precedent already exists at the (B) access class, not the (A) dispatch class.** Hard mode's
   Read allowlist and Item 5A already treat "grep the plan file's phase headers" as within the
   pure-dispatcher's own Bash budget — this task's ask is to extend that same class of access
   (never full-file reads, header-line grep only) to a second call site (Stage 5 recovery) and,
   for base mode, to sanction it there at all for the first time. It is consistency with an
   established pattern, not a new category of trust.
2. **Cost asymmetry favors (B) by a wide margin.** Option A requires a full `Agent` tool
   dispatch: fresh (or forked) LLM context, the entire plan file read and semantically
   interpreted, wall-clock latency on the order of the drift-inspection fork today, and an
   intermediate `.phase-recovery.json` artifact to define, write, and clean up. Option B is two
   `grep -c` shell calls returning integers — no LLM involvement, no new artifact schema, no
   added latency worth measuring.
3. **The task is mechanical, not semantic.** The drift-inspection fork (Option A's existing
   analog) is justified because its job — recognizing `*(deviation:` annotations and producing a
   qualitative `drift_pct` — benefits from an LLM's judgment. Counting `[COMPLETED]` phase
   headers against total phase headers is a deterministic string match with no interpretive
   component; delegating it to a subagent would be pure overhead for zero quality gain.
4. **(A) is not actually "exact" context flatness either.** The Agent tool invocation itself
   still costs orchestrator-visible context (the dispatch prompt, the tool-call/return
   bookkeeping) — plausibly comparable to or larger than two integers of grep output. The
   framing in the task description ("preserve context flatness exactly rather than
   approximately") somewhat overstates (A)'s advantage once the dispatch overhead is counted,
   not just the final JSON size.
5. **Fewer moving parts to keep correct over time.** (B) requires no new artifact type, no new
   cycle-accounting question ("does a recovery fork count toward `cycle_count`?"), and no new
   hook/validation surface. (A) would need all three answered and maintained.

**Explicit RECOVERY framing (required by the task)**: the grep exception must be textually
scoped in the MUST NOT list (base) and Read-allowlist/Tool-Constraints section (hard) as firing
**only** when Stage 5 has already determined the handoff for *this* dispatch is missing or stale
— i.e., inside the existing `if [ ! -f "$handoff_file" ] || [ "$handoff_stale" = "true" ]`
branch — never as a routine per-cycle read, and never as a substitute for reading the handoff
when one is present and fresh. Suggested wording for the base MUST NOT list (item 2 becomes, at
minimum, an explicit carve-out sentence following the existing four items and the "ONLY file
read" sentence):

> **Recovery exception**: When Stage 5 determines the current dispatch's handoff is missing or
> stale, the orchestrator MAY run at most two count-only `grep -c` calls against the plan file's
> `### Phase N: ... [STATUS]` heading lines (never a full-file read) to recover
> `phases_completed`/`phases_total` as a diagnostic second opinion. This is a bounded,
> recovery-only fallback (≤10 tokens), not a routine per-cycle read, and does not relax items 1,
> 3, or 4 above.

For hard mode, since the Read allowlist already covers `plans/*.md` structurally, the change is
narrower: wire the same count-only grep into Stage 5's missing/stale-handoff branch (currently it
does nothing beyond infra-failure classification), and add one sentence to the Tool Constraints
section clarifying that category 3's plan-file access also covers this Stage 5 recovery grep, in
addition to the already-documented H4 report grep — so the allowlist's own text stays accurate
about *why* plan files are readable.

## Decisions

- Recommend **Option (B)**: narrow, count-only `grep -c` exception, explicit token bound ≤10
  tokens per recovery event, gated strictly to Stage 5's existing missing/stale-handoff branch.
- Recommend the fix land in **both** `skill-orchestrate/SKILL.md` (new explicit carve-out
  sentence under the MUST NOT list, plus new Stage 5 recovery logic in the missing-handoff
  branch) and `skill-orchestrate-hard/SKILL.md` (Stage 5 recovery logic added; one sentence added
  to the Tool Constraints Read-allowlist category 3 to document the second justification).
- Recommend `docs/architecture/handoff-schema.md` lines 301-302 be updated in the same pass (or a
  fast-follow) to stop asserting an unqualified "NEVER reads... plan files", since that is
  already false for hard mode and will be doubly false for both variants after this change — see
  Context Extension Recommendations.
- The recovered counts should be treated as **diagnostic/logging only** in the initial cut (a
  loud `[orchestrate] RECOVERY: ...` log line), not silently substituted as if they were a real
  `dispatch_status`. There is no `dispatch_status` to switch on when the handoff itself is
  missing, so the existing infra-failure-vs-charged-cycle classification in that branch should
  remain the primary behavior; the recovery grep's job is to give the operator/orchestrator
  visibility into true phase progress, not to invent a synthetic "implemented" transition when no
  agent handoff exists at all. Planner should decide during planning whether/how the recovered
  counts feed loop-guard state beyond logging — that is an implementation-sizing decision, not a
  research one.

## Risks & Mitigations

- **Risk**: A loosely-worded carve-out could be read as license to grep other parts of the plan
  (checklist items, prose, deviation annotations), eroding context flatness by degrees. **Mitigation**:
  the recommended wording restricts the pattern to `### Phase N: ... [STATUS]` heading lines only
  and to `grep -c` (count-only, no captured line content), and ties it textually to "fires only
  inside the missing/stale-handoff branch."
- **Risk**: Divergence between base and hard variants' constraint-section prose (one has a
  literal "MUST NOT" heading, the other doesn't) could cause a future editor to update only one
  file. **Mitigation**: this report calls out both exact locations (base 1105-1116; hard 24-62)
  explicitly so the implementer edits both.
- **Risk**: `docs/architecture/handoff-schema.md`'s blanket "NEVER reads... plan files" statement
  left unedited would become a second source of truth contradicting the SKILL.md files.
  **Mitigation**: flagged as a Context Extension Recommendation below; low cost to fix in the
  same pass since it is a two-sentence edit.

## Context Extension Recommendations

- **Topic**: Orchestrator handoff reading contract exceptions.
- **Gap**: `docs/architecture/handoff-schema.md` lines 301-302 assert an unqualified "The
  orchestrator NEVER reads the actual research reports, plan files, or implementation summaries
  during its state machine loop" — already inaccurate for hard mode's Read allowlist/Item 5A, and
  will be inaccurate for both variants once this task's recovery exception lands.
- **Recommendation**: When implementing this task, add a short qualifying sentence to
  `handoff-schema.md`'s Reading Contract section noting the two sanctioned narrow exceptions
  (hard-mode H4 report grep + phase-header grep; the new missing-handoff phase-marker recovery
  grep in both variants), each bounded and recovery/verification-only, so the doc and the two
  SKILL.md files stay mutually consistent.

## Appendix

- Search queries / greps used: `grep -n "MUST NOT|Context Flatness|orchestrator-handoff.json|
  phases_completed|phases_total|Drift inspection|drift-inspection"` against both SKILL.md files;
  targeted `Read` calls at the MUST NOT section (base 1095-1129), Tool Constraints section (hard
  24-88), the `planned`/`implementing` handlers in both variants, Stage 5 in both variants, and
  `docs/architecture/handoff-schema.md` (full field/contract sections); `grep -n "^### Phase"` in
  `context/formats/plan-format.md` and `rules/plan-format-enforcement.md` for the canonical
  heading format.
- Files read (not modified): `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
  `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`,
  `agent-system/extensions/core/docs/architecture/handoff-schema.md`,
  `agent-system/extensions/core/rules/plan-format-enforcement.md`,
  `specs/891_gate_orchestrate_completion_on_phase_progress/summaries/
  01_gate-completion-on-phase-progress-summary.md`.

# Research Report: Task #924

**Task**: 924 - documented_reasoned_exclusions_phase_outcome
**Started**: 2026-07-27T16:40:00Z
**Completed**: 2026-07-27T16:54:00Z
**Effort**: ~1.5 hours (research)
**Dependencies**: None (skill-base.sh owned by a sibling task, deliberately out of file_scope)
**Sources/Inputs**: Codebase exploration of `agent-system/extensions/core/` (the SOURCE store;
  `.claude/` is the disposable deploy artifact and was not read or edited)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

All findings below were verified against `agent-system/extensions/core/` directly (the binding
source store per the task's SOURCE-STORE RULE), anchored on symbol names, exact quoted regexes,
and file/section names — never on line numbers, which are cited only as pointers for a human
reader and may drift.

## Executive Summary

- The strategic-sorry precedent (`context/contracts/wrap-up.md`'s `sorry_inventory` +
  `context/formats/plan-format.md`'s `## Planned Strategic Sorries`) is `--hard`-only and
  Lean/formal-flavored, but its *shape* — a machine-readable table of division points with
  `{item, assumption/reason, why_deferred, evidence-of-justification, tracking-id}` fields, tied
  to a `strategic: true` marker that lets a dispatch report success despite incompleteness — is
  exactly the shape a "documented, reasoned exclusion" (DRE) outcome needs, generalized to any
  task type and standard mode.
- **The trap is real and independently verified in both directions**: Stage 5a's blind-rewrite
  alternation is `\[(NOT STARTED|IN PROGRESS|PARTIAL)\]` in **both**
  `agents/general-implementation-agent.md` and `agents/general-implementation-hard-agent.md`
  (byte-identical). A new marker text outside that alternation survives Stage 5a untouched — good
  — but `scripts/update-task-status.sh`'s DONE regex is `'^### Phase [0-9][0-9]*:.*\[COMPLETED\][[:space:]]*$'`
  (literal `COMPLETED` only), so the same marker inflates `PHASE_CHECK_TOTAL` without ever
  incrementing `PHASE_CHECK_DONE` — permanently refusing the `--phase-check=refuse` completion
  gate. Both regexes must be edited; editing only one reproduces the opposite failure mode.
- **The open research question is answered**: `skill_gate_completion_claim()` in
  `scripts/skill-base.sh` reads only `phases_completed`/`phases_total`/`plan_markers_verified`
  fields the *caller already parsed out of* `.orchestrator-handoff.json` (agent self-report). It
  never reads the plan file, never runs a phase-heading regex, and explicitly documents (in its
  own header comment) that the one place a phase-heading grep is allowed is a narrow, diagnostic,
  non-authoritative recovery exception inside `skill-orchestrate/SKILL.md` Stage 5 — not this
  function. **Conclusion: `skill_gate_completion_claim` needs no code change**, provided
  implementation agents are instructed to count an exclusion-closed phase toward the
  `phases_completed` integer they self-report in the handoff. `scripts/update-task-status.sh`'s
  independent, plan-file-reading `--phase-check` backstop (`count_plan_phases()`) is the
  regex-based mechanism that unconditionally needs editing.
- **Phase-heading regex reconciliation**: at least four structurally distinct regex "shapes" for
  "what is a phase heading" exist across the codebase today; none of them admit a letter-suffixed
  sub-phase (`Phase 3a`). Two (`skill-implementer-hard/SKILL.md`, `skill-orchestrate/SKILL.md`)
  admit decimal sub-phases (`Phase 3.1`) via `[0-9]+(\.[0-9]+)?`; two
  (`scripts/update-task-status.sh`, the Stage 5a blocks in both implementation agents) admit
  digits only via `[0-9][0-9]*` / `[0-9]+`. `scripts/validate-artifact.sh` is a fifth, weaker
  digits-only site (presence-check and extraction only, no decimal). None of the five sites
  recognize a letter suffix.
- A documentation gap was found in passing: `agents/general-implementation-agent.md` and
  `agents/general-implementation-hard-agent.md` both instruct writing a per-objective
  `deviations` array "to the progress file `deviations` array (see
  `.claude/context/formats/progress-file.md` for schema)", and `context/formats/events-format.md`
  documents the `skipped|altered|deferred` type vocabulary for the parallel `events.jsonl`
  `deviation` category — but `context/formats/progress-file.md` itself does not define a
  `deviations` field anywhere in its own Schema/Field Specifications sections. This is a stale
  cross-reference, not something this task needs to fix, but the planner should not treat
  progress-file.md's *current* text as authoritative for the deviations schema — the schema
  actually lives split across the two implementation-agent files and events-format.md.

## Context & Scope

Task 924 asks for research (not implementation) into how to generalize the existing
strategic-sorry precedent into a new, machine-visible, `[COMPLETED]`/`[PARTIAL]`-distinct phase
outcome — "documented, reasoned exclusions" (DRE) — usable by any task type in standard mode, and
to resolve two concrete defects (Stage 5a's blind rewrite, and `update-task-status.sh`'s
asymmetric TOTAL/DONE regex) plus a related regex-reconciliation item (letter-suffixed sub-phase
headings), while deliberately leaving `scripts/skill-base.sh` untouched (owned by a sibling
`[PARTIAL]` task) unless research proves it must change. `scripts/skill-base.sh` was read
read-only, for the open research question, without editing it or claiming ownership of it.

## Findings

### 1. The Strategic-Sorry Precedent — Exact Shape

**`context/contracts/anti-analysis.md`** (Sub-Sorry Policy, `--hard`-only, loaded exclusively by
`skill-implementer-hard`/`general-implementation-hard-agent`/`skill-orchestrate-hard`) defines the
five-condition test for when a main-target-level placeholder is acceptable as a **strategic
sorry**:

1. **Deliberate division boundary** — planned as part of a skeleton, not an abandoned/stuck
   attempt.
2. **Tightly scoped** — exactly one theorem/function/definition, never a whole module/file.
3. **Documented** — the comment states (a) the assumption, (b) why deferred, (c) the owning
   follow-up task/sub-phase.
4. **Tracked** — recorded in the handoff `sorry_inventory` with `strategic: true` and a non-null
   `follow_up_task`.
5. **Build-green** — the placeholder is a syntactically/type-valid token (`sorry` in Lean4, or a
   domain equivalent like `raise NotImplementedError` / `-- STUB:`), and the build/typecheck still
   passes.

Meeting all five lets a dispatch report `status: "implemented"` with `skeleton: true` instead of
being forced to `partial`/`blocked`.

**`context/contracts/wrap-up.md`** (`sorry_inventory`, `--hard`-only) gives the canonical
machine-readable entry schema:
```
{file, line, statement, strategic, assumption, why_deferred, follow_up_task}
```
`follow_up_task` is REQUIRED (non-null) when `strategic: true` — "an untracked strategic sorry is
a defect, not a skeleton success." The handoff also carries top-level `skeleton` (bool) and
top-level `phases_completed`/`phases_total` (see Finding 5 below — these are the SAME top-level
fields the completion-claim gate consumes).

**`context/formats/plan-format.md`** (`## Planned Strategic Sorries`, present only when
`plan_metadata.skeleton: true`) is the PLAN-TIME half: a table placed immediately after
`## Implementation Phases`, columns `Division Point | File / Line / Statement | Assumption | Why
Deferred | Follow-Up Task`, explicitly reusing the `wrap-up.md` field names "verbatim; do not
redefine, rename, or invent a parallel schema." Plan-time entries are provisional (`TBD` for
file/line/statement); the implementer fills in the concrete values and writes the actual
`sorry_inventory` entry at implement time. A strategic sorry placed by the implementer that does
NOT correspond to a planned row is flagged as a "plan-unanticipated deviation" under a weaker
claim on condition 1, not silently accepted as equivalent.

**Interaction with completion**: `context/contracts/wrap-up.md`'s Build-Green Invariant states
STANDARD mode's invariant is "unchanged and absolute: it has no strategic-sorry exception, and no
leftover scaffolding of any kind is acceptable outside `--hard`" — i.e. today this "documented
incompleteness that still counts as success" shape exists ONLY for `--hard` + Lean-flavored
scaffolding. Task 924's generalization is precisely to lift the *shape* (not the Lean-specific
condition 5, or the hard-mode-only gating) to any task type / standard mode.

### 2. Stage 5a Blind-Rewrite Alternation — Verbatim, Both Agents

`agents/general-implementation-agent.md`, Stage 5a ("Verify and Repair Plan Markers"):
```bash
stale_total=$(grep -cE '^### Phase [0-9]+.*\[(NOT STARTED|IN PROGRESS|PARTIAL)\]' "$plan_file" 2>/dev/null || echo 0)
...
grep -nE '^### Phase [0-9]+.*\[(NOT STARTED|IN PROGRESS|PARTIAL)\]' "$plan_file" | while IFS=: read -r linenum content; do
    phase_num=$(echo "$content" | grep -oE "Phase [0-9]+" | grep -oE "[0-9]+")
    bash .claude/scripts/update-phase-status.sh "$task_number" "$project_name" "$phase_num" COMPLETED
done
```

`agents/general-implementation-hard-agent.md`, Stage 5a ("Verify and Repair Plan Markers (HARD
CONTRACT)") — byte-identical alternation and extraction:
```bash
stale_total=$(grep -cE '^### Phase [0-9]+.*\[(NOT STARTED|IN PROGRESS|PARTIAL)\]' "$plan_file" 2>/dev/null || echo 0)
...
grep -nE '^### Phase [0-9]+.*\[(NOT STARTED|IN PROGRESS|PARTIAL)\]' "$plan_file" | while IFS=: read -r linenum content; do
    phase_num=$(echo "$content" | grep -oE "Phase [0-9]+" | grep -oE "[0-9]+")
    bash .claude/scripts/update-phase-status.sh "$task_number" "$project_name" "$phase_num" COMPLETED
done
```
(The hard variant additionally sets `plan_markers_verified: true` in the handoff when this passes,
and — when `phase_number` is set for a single-phase dispatch — scopes the check to only the
assigned phase.)

**Implication for a new marker**: a marker whose bracket text is anything other than the literal
strings `NOT STARTED`, `IN PROGRESS`, or `PARTIAL` is, by construction, never touched by this
alternation — it is neither clobbered back to `[COMPLETED]` nor left stale. This is a *design
constraint that resolves itself* as long as the new marker text is chosen distinctly (see Finding
6) and the phase is transitioned to it directly (via `update-phase-status.sh`) at close time,
never left at `[PARTIAL]` hoping Stage 5a will "finish" it — Stage 5a only ever promotes to
`[COMPLETED]`, never to any exclusion marker.

### 3. `update-task-status.sh` TOTAL/DONE Regexes and `update-phase-status.sh` Accepted Set

`scripts/update-task-status.sh`, `count_plan_phases()`:
```bash
PHASE_CHECK_TOTAL=$(grep -c '^### Phase [0-9][0-9]*:.*\[[A-Z][A-Z ]*\][[:space:]]*$' \
  "$PHASE_CHECK_PLAN_FILE" 2>/dev/null) || PHASE_CHECK_TOTAL=0
PHASE_CHECK_DONE=$(grep -c '^### Phase [0-9][0-9]*:.*\[COMPLETED\][[:space:]]*$' \
  "$PHASE_CHECK_PLAN_FILE" 2>/dev/null) || PHASE_CHECK_DONE=0
```
TOTAL admits **any** uppercase-letters-and-spaces bracket content (`[A-Z][A-Z ]*`) — so a new
marker automatically counts toward the denominator with zero code change, *as long as its text is
restricted to uppercase letters and spaces* (no digits, punctuation, dashes, or parentheses — the
character class does not admit them). DONE admits the literal string `COMPLETED` only. This
function backstops the `--phase-check` opt-in gate on the `postflight`/`implement` transition
(guarded by `[[ -n "$PHASE_CHECK" ... ]]`); with `--phase-check=refuse` it `exit 4`s the whole
`update-task-status.sh` invocation — a hard stop, not a warning — when
`PHASE_CHECK_DONE < PHASE_CHECK_TOTAL` and at least one conforming heading exists. **This is the
regex that must change** (extend the DONE alternation to admit the new marker's literal text)
for scope item D.

`scripts/update-phase-status.sh` accepted `NEW_STATUS` values (verbatim from its own usage/case
block):
```
NEW_STATUS values: IN_PROGRESS, NOT_STARTED, COMPLETED, PARTIAL, BLOCKED
```
with a `case` statement normalizing each to a canonical bracket display form (`COMPLETED`,
`PARTIAL`, `BLOCKED`, etc.) and rejecting anything else. **This case statement must gain a new
branch** for the new marker (scope item D) — without it, no code path can ever legally *write*
the new phase heading in the first place, regardless of what the read-side regexes accept.

### 4. Phase-Heading Regex Census — Five Sites, At Least Three Divergent Shapes

| Site | Regex(es) | Digits-only vs. decimal | Letter suffix (`3a`) admitted? |
|------|-----------|--------------------------|----------------------------------|
| `scripts/update-task-status.sh` (`count_plan_phases`) | TOTAL: `^### Phase [0-9][0-9]*:.*\[[A-Z][A-Z ]*\][[:space:]]*$`; DONE: `^### Phase [0-9][0-9]*:.*\[COMPLETED\][[:space:]]*$` | digits only (`[0-9][0-9]*`) | No |
| `skills/skill-implementer-hard/SKILL.md` (per-phase dispatch resume scan) | `^### Phase [0-9]+(\.[0-9]+)?: .*\[(NOT STARTED\|PARTIAL\|IN PROGRESS)\]` | decimal sub-phase admitted (`(\.[0-9]+)?`) | No |
| `skills/skill-orchestrate/SKILL.md` (recovery-phase-marker grep, Stage 5) | total: `^### Phase [0-9]+(\.[0-9]+)?: `; completed: `^### Phase [0-9]+(\.[0-9]+)?: .*\[COMPLETED\]` | decimal sub-phase admitted | No |
| `agents/general-implementation-agent.md` + `general-implementation-hard-agent.md` (Stage 5a) | `^### Phase [0-9]+.*\[(NOT STARTED\|IN PROGRESS\|PARTIAL)\]`, extraction `grep -oE "Phase [0-9]+" \| grep -oE "[0-9]+"` | digits only (`[0-9]+`) | No |
| `scripts/validate-artifact.sh` (presence check + phase-number extraction) | `^### Phase [0-9]+` (presence, `grep -qE`), `^### Phase [0-9]\+` (BRE, `grep -n`), extraction `grep -oE '^### Phase [0-9]+' \| grep -oE '[0-9]+'` | digits only, no decimal | No |

`scripts/orchestrate-recover-outcome.sh` was checked and is **not** a phase-heading-regex site at
all — it reads `.metadata.phases_completed // .partial_progress.phases_completed // 0` and the
`_total` equivalent directly from a `.return-meta.json`/`.orchestrator-handoff.json`-shaped JSON
blob via `jq`, never touching the plan file. This is useful corroborating evidence for Finding 5.

Net: three structurally distinct notions of "a phase heading" (strict digits-only with an
end-of-line status anchor; digits-only without the end anchor; digits-with-optional-decimal), none
of which recognize a letter-suffixed sub-phase heading (`Phase 3a`) in either the TOTAL or DONE
direction anywhere in the codebase. `skill-implementer-hard/SKILL.md`'s own comment explicitly
documents that its decimal-admitting form was a deliberate fix for "N.1/N.2 sub-phase headings or
sparse numbering (1, 2, 2.1, 2.2, 3)" — i.e. decimal sub-phasing is an established, intentional
pattern already in production use; letter suffixing has no such precedent anywhere and would be a
genuinely new addition, not a gap-fill of an already-partially-supported case.

### 5. Open Research Question — Answered

`scripts/skill-base.sh`, `skill_gate_completion_claim()` (verbatim, header comment plus body):

```bash
# Usage: skill_gate_completion_claim "$task_number" "$phases_completed" \
#          "$phases_total" "$plan_markers_verified" "$log_prefix"
# ...
# All evidence is read from fields the caller already parsed out of
# .orchestrator-handoff.json. This function never reads a plan file, report, or summary, and
# never invokes the Stage 5 phase-marker recovery grep — that exception is scoped to the
# missing/stale-handoff branch and this gate fires only when a handoff IS present and fresh.
skill_gate_completion_claim() {
  ...
  if [ "$phases_total" -gt 0 ] && [ "$phases_completed" -ge "$phases_total" ]; then
    # Case 2: phase accounting present and complete — the only unconditional allow.
    return 0
  fi
  if [ "$phases_total" -gt 0 ]; then
    # Case 1: phase accounting present but incomplete — always refuse.
    return 1
  fi
  # Case 3: phases_total == 0 ... falls back to plan_markers_verified.
  if [ "$plan_markers_verified" = "true" ]; then
    return 0
  fi
  return 1
}
```

`phases_completed`/`phases_total` are opaque integers the agent itself writes into the top level
of `.orchestrator-handoff.json` (per `context/contracts/wrap-up.md` and
`context/formats/return-metadata-file.md`, `"phases_completed": N` / `"phases_total": M` with no
further specification of *how* N is derived — it is a self-report, not a script-derived count).
`docs/architecture/handoff-schema.md` corroborates: it documents the exact same three-case logic,
and separately confirms `orchestrate-recover-outcome.sh` reads `phases_completed`/`phases_total`
from the SAME top-level fields (not nested), and that the one phase-heading-grep "Recovery
exception" living in `skill-orchestrate/SKILL.md` Stage 5 is explicitly "diagnostic-only and never
moves `state.json`" — its recovered counts "never synthesize a `dispatch_status` and never drive a
status transition."

**Conclusion**: `skill_gate_completion_claim` needs **no code change**. An exclusion-closed phase
is invisible to it by design — the gate only ever sees the integers an agent already chose to
report. The correct lever is a documentation/instruction change (Finding 1's generalization target
plus scope item F): tell implementation agents to increment their self-reported
`phases_completed` for a phase they close via the new marker, exactly as they already do for a
phase closed via `[COMPLETED]`. `scripts/skill-base.sh` is correctly excluded from this task's
`file_scope` — nothing found here requires editing it, and the sibling task's ownership boundary
is not at risk of being violated.

By contrast, `scripts/update-task-status.sh`'s `count_plan_phases()` (Finding 3) is NOT reading a
self-report — it independently re-derives TOTAL/DONE by re-parsing the plan file's own heading
text via regex. That independence is exactly why it "definitely" needs the DONE-regex edit the
task description anticipated: no agent-side instruction change can make an already-hardcoded
literal-`[COMPLETED]` regex recognize a new marker string.

### 6. Recommendation — Marker Name and Record Location (proposal for the plan phase)

**Marker name**: `[COMPLETED WITH EXCLUSIONS]` as a new phase-heading status, added alongside the
existing five (`NOT STARTED`, `IN PROGRESS`, `COMPLETED`, `PARTIAL`, `BLOCKED`) in
`context/standards/status-markers.md`'s phase-heading vocabulary cross-reference,
`context/formats/plan-format.md`'s "Plan-level vs. phase-level markers" subsection, and
`rules/plan-format-enforcement.md`'s "Valid markers" list (scope items A and G).

Reasoning:
- **Passes the existing TOTAL regex unchanged.** `[A-Z][A-Z ]*` admits uppercase letters and
  spaces only — `COMPLETED WITH EXCLUSIONS` satisfies that character class with zero edits to the
  TOTAL side of `count_plan_phases()`. A name using digits, punctuation, a dash, or parentheses
  (e.g. `[COMPLETED-EXCLUSIONS]`, `[COMPLETED (EXCLUSIONS)]`) would silently fall OUT of TOTAL too,
  reproducing a variant of the exact denominator-inflation trap this task exists to close, so the
  plan phase should treat "uppercase letters and spaces only" as a hard constraint on whatever
  final name is chosen, not just a suggestion.
- **Distinct from both `COMPLETED` and `PARTIAL` by construction** (scope item A's defining
  requirement) — it is a different literal string, so it is unambiguous to both a human reader and
  every regex site in Finding 4.
- **Automatically survives Stage 5a** (Finding 2) — outside the `NOT STARTED|IN PROGRESS|PARTIAL`
  alternation, so the blind rewrite is a non-issue as long as the agent transitions the phase
  directly to this marker at close time rather than parking it at `[PARTIAL]`.
- Requires exactly two mechanical script edits (scope item D): extend
  `update-task-status.sh`'s DONE regex to an alternation
  (`\[(COMPLETED|COMPLETED WITH EXCLUSIONS)\]`, or equivalent), and add a `COMPLETED_WITH_EXCLUSIONS`
  (or similar canonical token) branch to `update-phase-status.sh`'s `case` statement, normalizing
  to the same display string.

**Record location**: a new `## Reasoned Exclusions` per-phase subsection in the **plan artifact**,
placed inside (or immediately following) the phase whose heading carries the new marker — mirroring
`## Planned Strategic Sorries`'s placement and column-reuse discipline rather than inventing a
parallel schema, per the task's explicit generalize-don't-parallel requirement (scope item C).
Recommended minimum columns, satisfying scope item B's "item, reason, evidence" floor and named to
be domain-neutral (no `file`/`line`/`statement`/`strategic`/`follow_up_task`, which are
sorry-specific):

```
| Item | Reason | Evidence |
|------|--------|----------|
| {excluded file/row/target} | {why not applicable} | {what confirms the reason — command output, diff excerpt, or artifact reference} |
```

Two supporting design notes for the plan phase:
1. **Plan-time vs. implement-time populates**: unlike `## Planned Strategic Sorries` (populated
   entirely at plan time, `TBD`-provisional until implementation), the task's own account of
   Phase 2/Phase 8 shows exclusions are typically *discovered* mid-implementation (a misdiagnosis,
   or false positives found while executing a row), while Phase 4 shows a pre-emptive declaration
   is also legitimate. The section should therefore be writable at either time, with implement-time
   entries confirming or superseding plan-time hypotheses — this dovetails naturally with
   `plan-format.md`'s existing `**Scope Hypothesis**` field ("Any count, file list, or scope
   estimate asserted in a plan is a hypothesis requiring implementation-time confirmation, never a
   fact"): a reasoned exclusion is, structurally, the closing act of a Scope Hypothesis whose count
   turned out to be an overcount. The plan phase should consider cross-referencing these two
   mechanisms explicitly rather than treating them as unrelated.
2. **Per-objective `deviations` (progress file / events.jsonl) is the WRONG grain to lift**, contra
   the task description's tentative candidate B: its `type` vocabulary (`skipped|altered|deferred`)
   is transient, per-objective, and — per the documentation-gap finding above — not even
   consistently documented in `progress-file.md` itself; a phase-level, plan-artifact-resident
   record is more durable, matches the strategic-sorry precedent's own placement choice, and is
   visible to the exact same downstream readers (`update-task-status.sh`, `validate-artifact.sh`,
   a future human auditor) that already read the plan file for phase state.

## Decisions

- Confirmed via direct evidence (not inference) that `skill_gate_completion_claim` requires no
  edit; the plan phase should NOT add `scripts/skill-base.sh` to file_scope on the strength of this
  research.
- Confirmed the letter-suffix regex gap is real and current (no existing letter-suffix support
  anywhere), distinguishing it from decimal sub-phasing, which already has established precedent
  and partial support in two of five sites.
- Recommended `[COMPLETED WITH EXCLUSIONS]` (uppercase-letters-and-spaces-only) as the concrete
  marker text, with the character-class constraint flagged as binding on any alternative name the
  planner might prefer.

## Risks & Mitigations

- **Risk**: choosing a marker name that violates the `[A-Z][A-Z ]*` character class silently
  reproduces the TOTAL-side half of the denominator-inflation trap. **Mitigation**: state the
  constraint explicitly in the plan (done above); `validate-artifact.sh`'s and
  `update-task-status.sh`'s regexes should ideally be exercised against the literal chosen string
  before the plan is finalized.
- **Risk**: an implementer agent parks an exclusion-closed phase at `[PARTIAL]` "to be safe,"
  relying on a human or a future dispatch to promote it — Stage 5a will never do this (by design,
  per Finding 2), so the phase would stay `[PARTIAL]` forever, reproducing the exact permanent-block
  failure this task exists to prevent. **Mitigation**: the implementation-agent instructions (scope
  item E) must be explicit that closing via reasoned exclusion is a *direct* transition performed
  by the agent via `update-phase-status.sh`, never a two-step "mark PARTIAL, let something else
  finish it" pattern.
- **Risk**: `count_plan_phases()`'s DONE-regex edit and `update-phase-status.sh`'s case-statement
  edit drift out of sync (one accepts the new marker, the other doesn't). **Mitigation**: scope
  item D explicitly requires both; the plan phase should treat them as one atomic edit, not two
  independently schedulable items.

## Context Extension Recommendations

- **Topic**: `deviations` array schema (per-objective progress-file mechanism).
  **Gap**: `context/formats/progress-file.md`'s own Schema/Field Specifications sections do not
  document the `deviations` array field, even though two implementation-agent files instruct
  writing to "the progress file `deviations` array (see `.claude/context/formats/progress-file.md`
  for schema)" and `context/formats/events-format.md` documents the parallel
  `skipped|altered|deferred` vocabulary for `events.jsonl`. **Recommendation**: a small follow-up
  (out of this task's scope) to add the `deviations` field to progress-file.md's own Schema section
  so the cross-reference in the implementation agents resolves to something that actually exists in
  the target file.

## Appendix

Files read (source store only, `agent-system/extensions/core/`):
- `context/contracts/wrap-up.md`
- `context/contracts/anti-analysis.md`
- `context/formats/plan-format.md`
- `context/formats/progress-file.md`
- `context/formats/events-format.md`
- `context/standards/status-markers.md`
- `rules/plan-format-enforcement.md`
- `agents/general-implementation-agent.md` (Stage 5a and deviation-annotation sections)
- `agents/general-implementation-hard-agent.md` (Stage 5a, Stage 4.5/4C)
- `scripts/update-task-status.sh` (`count_plan_phases`, phase-check gate block)
- `scripts/update-phase-status.sh` (accepted `NEW_STATUS` case block)
- `scripts/skill-base.sh` (`skill_gate_completion_claim`, read-only)
- `scripts/validate-artifact.sh` (phase-heading regexes)
- `scripts/orchestrate-recover-outcome.sh` (confirmed NOT a regex site — reads return-meta JSON)
- `skills/skill-implementer-hard/SKILL.md` (per-phase dispatch resume scan)
- `skills/skill-orchestrate/SKILL.md` (recovery-phase-marker grep, Stage 5)
- `docs/architecture/handoff-schema.md` (completion-claim gate documentation, corroborating)
- `context/formats/return-metadata-file.md` (`phases_completed`/`phases_total` field spec)

Search commands used: `grep -n`/`grep -rn` for `Stage 5a`, `sorry_inventory`, `deviation`,
`Phase [0-9]`, `skill_gate_completion_claim`, `phases_completed`, `plan_markers_verified`, and
`find . -iname` for `orchestrate-recover-outcome.sh` / `anti-analysis.md`, all executed against
`agent-system/extensions/core/` (never `.claude/`).

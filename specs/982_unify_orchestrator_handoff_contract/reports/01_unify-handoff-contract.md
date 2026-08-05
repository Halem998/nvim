# Research Report: Task #982

**Task**: 982 - Unify the .orchestrator-handoff.json contract
**Started**: 2026-08-05
**Completed**: 2026-08-05
**Effort**: Medium (schema authoring + 1 script rewrite + wrap-up.md/2 agent files + doc alignment)
**Dependencies**: Task 974 (completed)
**Sources/Inputs**: Codebase (agent-system/extensions/core/**), specs/TODO.md (tasks 947, 948, 949, 968, 973, 974)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The four schemas are real and independently verified against the freshly-redeployed tree, but
  the picture is better than the ticket implies in one respect and worse in another: the
  **readers are already fully reconciled with each other** (base and hard engines read identical
  jq paths for every field), but the **only live writer of a real handoff today
  (`general-implementation-hard-agent.md`) does not populate two fields both engines
  unconditionally read** (`.summary`, `.artifacts`) — a live, previously-uncatalogued defect,
  not just a documentation gap.
- `validate-handoff.sh`'s status enum (`implemented|partial|blocked`) would REJECT every
  research/plan handoff example in `handoff-schema.md` itself (`status: "researched"` /
  `"planned"`), and it enforces zero requirement on `artifacts` — a handoff can pass validation
  while structurally starving the orchestrator's artifact-linking read.
- The research-phase writer question is **already settled** by a prior, completed decision
  (task 947, abandoned in favor of this task, whose finding — research agents must not write a
  handoff — is already encoded in `general-research-agent.md`'s Stage 3.6 "Scoping Decision" and
  in `handoff-schema.md`'s Handoff Writers table). This task should preserve that decision, not
  re-litigate it, and fold it into the new unified schema's writer table.
- Recommended writer decision: **delete `skill_write_orchestrator_handoff`** (zero callers, and
  its own output shape is independently wrong against the fields readers use — no per-artifact
  `summary`, always-empty `blockers`, and it is the sole writer of the nested
  `continuation_context` form that no live writer needs). Declare `.return-meta.json` the single
  return channel for base-mode research/plan/implement (already true in practice; this task makes
  it the *decided* answer instead of an implicit default) and keep `.orchestrator-handoff.json`
  as a hard-mode-only artifact. This also collapses "Two Accepted Forms" down to **one**
  (flat `continuation_path`), satisfying the "one continuation form" requirement in WORK item 1
  for free.
- Recommended blocker shape: adopt the wrap-up.md hard-mode shape
  (`{phase, target, verbatim_goal, what_was_tried, why_it_failed}`) as canonical. Verified by
  grep: `.description` and `.severity` (the `handoff-schema.md`-documented shape) are read by
  **neither** engine anywhere; `.blockers[0].target` and `.blockers[0].verbatim_goal` are the
  only content-level blocker reads that exist, both in the hard engine only (H5 divergence audit
  and blocked-escalation blocker_desc). The base engine only ever reads `blockers | length`.

## Context & Scope

Researched the current state of `.orchestrator-handoff.json`'s four disagreeing sources (schema
doc, wrap-up.md, validate-handoff.sh, and the readers' union across both orchestrate engines),
the disposition of `skill_write_orchestrator_handoff`, and the three related/adjacent tasks
(968, 973 — kept separate per the task description; 947, 949 — abandoned/subsumed into this task
and task 948 respectively). The user's note that line numbers in the review are stale and the
`.claude/` tree was freshly redeployed was honored: every finding below was verified directly
against `agent-system/extensions/core/**` source-store files, not against the review's cited line
numbers.

Out of scope per the task description: cslib agent files (spun out to the task-948 cslib
terminal-metadata task, which depends on this one), task 968's gate logic (stays separate),
task 973's malformed-status recovery (stays; this task only reduces how often it fires).

## Findings

### Codebase Patterns

**Schema doc (`docs/architecture/handoff-schema.md`)**: Already substantially rewritten by prior
tasks — it documents "Two Accepted Forms" for continuation pointers, a corrected "Handoff
Writers" table, and the completion-claim verification gate in detail. It is the most
authoritative and most current of the four sources. Its gaps:
- The "Complete JSON Schema" code block (its own canonical example) has **no `skeleton` field,
  no `sorry_inventory` field**, and its `artifacts` array entries show only `{type, path}` — no
  `summary` — even though every reader site reads `.artifacts[0].summary`.
- Its `blockers` field shows only the soft `{description, phase, severity}` shape; the hard
  `{phase, target, verbatim_goal, what_was_tried, why_it_failed}` shape used by both engines'
  content-level blocker reads is absent from this document entirely (it lives only in
  `wrap-up.md`).

**wrap-up.md (H9 contract)**: Documents the hard-mode blocker shape and `sorry_inventory`
correctly, but its "Required fields" JSON block has **no `phase`, `summary`, or `artifacts`
field** — despite both engines reading `.summary` and `.artifacts[0].*` unconditionally from
every handoff, hard-mode included.

**validate-handoff.sh**: `required_fields=("status" "phases_completed" "phases_total"
"blockers")` — no `artifacts` check at all. `valid_statuses=("implemented" "partial" "blocked")`
— a **closed 3-value enum**, narrower than the 6-value normative vocabulary
(`researched|planned|implemented|partial|failed|blocked`) that `handoff-schema.md`'s own
`status` field definition, `return-metadata-file.md`, and `reconcile-task-status.sh`'s
`handoff_permits_promotion()` (which explicitly checks handoffs for `status="researched"` and
`status="planned"`, task 973's completed fix) all use. As written, `validate-handoff.sh` would
FAIL a `status: "researched"` handoff — which is exactly the shape `handoff-schema.md`'s own
first example object shows. Its blocker-field check (`Check 7`) validates against
`{phase, target}` — the wrap-up/hard shape — never against `{description, severity}`, so it is
already silently aligned with the shape that turns out to be the one actually used.

**The readers' union — verified more reconciled than the ticket implies**: `grep`-auditing every
`.blockers`/`.artifacts`/`.summary`/`.status`/`.phases_*`/`.skeleton`/`.sorry_inventory` jq path
in both `skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md` shows they are
**already identical** at every content-reading site:
- `dispatch_summary=$(echo "$handoff" | jq -r '.summary // ""')` — both engines, verbatim.
- `handoff_artifact_path/type/summary=$(echo "$handoff" | jq -r '.artifacts[0].{path,type,summary} // ""')` — both engines, verbatim.
- `phases_completed`, `phases_total`, `plan_markers_verified` — both engines, verbatim.
- Continuation dual-form resolution (`continuation_context.handoff_path // continuation_path`) —
  both engines, verbatim (base uses a `jq -c` pipeline; hard uses a shorter `jq -r` one-liner
  with the same precedence — a harmless syntactic difference, not a semantic one).
- The one genuine per-engine difference: only the **hard** engine additionally reads
  `.skeleton`, `.sorry_inventory`, `.blockers[0].target`, and `.blockers[0].verbatim_goal` (H5
  divergence-audit routing and blocked-escalation `blocker_desc`). The base engine reads
  `.blockers` only as `jq -c '.blockers // []'` and later `blockers | length` — it never drills
  into blocker field content. This is not a disagreement to resolve; it is the hard engine using
  hard-only fields that the base engine legitimately never needs (base-mode dispatches never
  write a handoff at all, so the base engine's blocker-array read is dead code on every path
  except the one hard-mode-authored handoff it might encounter under an odd dispatch mix — worth
  a note in the unified schema doc but not a functional bug).

**Live writer defect, newly verified (not previously catalogued)**: `general-implementation-hard-agent.md`
Stage 5's actual handoff-write template (the only text a hard-mode implement dispatch follows) is:
```json
{
  "status": "implemented | partial | blocked",
  "phases_completed": N, "phases_total": M,
  "sorry_inventory": [], "blockers": [], "continuation_path": null
}
```
**No `summary`, no `artifacts` field at all** — not even an empty array. Since both engines
unconditionally read `.artifacts[0].path` to decide whether to call `skill_link_artifacts`, a
real hard-mode `implemented` handoff today produces `handoff_artifact_path=""`, and the artifact
(summary file) is **never auto-linked** into `state.json` for hard-mode implement dispatches —
silently, because `[ -n "$handoff_artifact_path" ]` is simply false and the linking branch is
skipped without any warning. `lean-implementation-hard-agent.md`'s template is a partial
improvement (it does include `summary`) but still omits `artifacts` entirely, and additionally
writes a redundant `continuation_context: null` alongside `continuation_path: null` — a leftover
of the nested/flat form ambiguity `handoff-schema.md` calls out. (`cslib-implementation-hard-agent.md`
is out of scope for edits here per the task description, but per task 948's survey it also lacks
the artifacts-shape spec — consistent with this pattern across all three hard implementation
agents.)

**`skill_write_orchestrator_handoff` (skill-base.sh)**: Confirmed zero callers by full-tree grep
(only comments and doc cross-references name it). Its own output is independently non-conformant
with what readers need even if it were wired up: its `artifacts_json` builder only ever emits
`{type, path}` (no `summary` parameter exists in its 9-parameter signature), it hardcodes
`"blockers": []` unconditionally (no parameter for populating blockers), and it is the **only**
writer that would ever produce the nested `continuation_context` form — every other/live writer
uses the flat `continuation_path` string.

**Status vocabulary cross-check**: `reconcile-task-status.sh`'s `handoff_permits_promotion()`
(task 973, completed) already treats an off-vocabulary handoff status as equivalent to a missing
one and permits promotion, logging a loud warning — this is the correct, already-fixed behavior
this task should preserve and build on, not duplicate.

### External Resources

Not applicable — this is a pure codebase-consistency task; no external documentation was
consulted.

### Recommendations

**1. ONE schema — a new JSON Schema file**, mirroring `context/schemas/events-schema.json`'s
draft-07 style, at `agent-system/extensions/core/context/schemas/orchestrator-handoff-schema.json`.
Recommended shape (union of what readers actually consume, per the grep-audit above):

```jsonc
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Orchestrator Handoff JSON Schema (orchestrator-handoff-v1)",
  "type": "object",
  "required": ["status", "summary", "artifacts", "phases_completed", "phases_total", "blockers"],
  "properties": {
    "status": { "enum": ["researched","planned","implemented","partial","failed","blocked"] },
    "phase": { "enum": ["research","plan","implement","revise"] }, // optional, informational
    "summary": { "type": "string" },
    "artifacts": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["type", "path"],
        "properties": { "type": {"type":"string"}, "path": {"type":"string"}, "summary": {"type":"string"} }
      }
    },
    "blockers": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["phase", "target"],
        "properties": {
          "phase": {}, "target": {"type":"string"}, "verbatim_goal": {"type":"string"},
          "what_was_tried": {"type":"string"}, "why_it_failed": {"type":"string"}
        }
      }
    },
    "phases_completed": {"type":"integer"}, "phases_total": {"type":"integer"},
    "plan_markers_verified": {"type":["boolean","null"]},
    "skeleton": {"type":"boolean"},
    "sorry_inventory": {"type":"array"},
    "continuation_path": {"type":["string","null"]},
    "next_action_hint": {"type":"string"}
  },
  "additionalProperties": true
}
```
Key decisions embedded above: single blocker shape (hard/wrap-up shape — `.description`/`.severity`
retired as dead); single continuation form (`continuation_path` only — `continuation_context`
retired along with its sole writer, see Decision 3); `artifacts[].summary` finally documented;
`status` is the full 6-value vocabulary (not the narrower 3-value one `validate-handoff.sh`
currently enforces).

**Research-phase writer question — already settled, do not re-litigate**: preserve the existing,
already-implemented answer (research agents never write a handoff; `general-research-agent.md`'s
Stage 3.6 already states this explicitly). This task's job is to make the new schema doc's writer
table say so in one place that both `wrap-up.md` and the schema doc agree with, closing the loop
task 947 opened but did not land.

**2. `validate-handoff.sh`**: Rewrite `required_fields` to include `artifacts` (checking it is a
present array — empty is legal only when `status` is `partial`/`blocked`/`failed`; non-empty
required when `status` is `researched`/`planned`/`implemented`, since that's what
`skill_link_artifacts` depends on downstream). Expand `valid_statuses` from the 3-value hard-only
set to the full 6-value normative vocabulary. Keep the existing blocker-shape check
(`phase`/`target`) — it is already correct. Add explicit test fixtures for both directions
(accept a schema-valid handoff; reject one missing `artifacts` or carrying an off-vocabulary
`status`) per the verification bar.

**3. Writer decision — delete, don't wire up**: `skill_write_orchestrator_handoff` should be
deleted from `skill-base.sh`, not rewired. Rationale: (a) it has zero callers today and its own
output shape independently disagrees with the unified schema (no artifact summary parameter, no
blockers parameter, wrong continuation form); (b) base-mode research/plan/implement already have
a complete, tested, working alternative — `.return-meta.json` plus `orchestrate-recover-outcome.sh`
— that both engines already call at 3 sites each; (c) deleting the function's nested
`continuation_context` output simultaneously retires the second continuation form, directly
satisfying WORK item 1's "one continuation form" requirement without any reader-side change
(since the flat form is already what the live writer emits and what the resolution logic
prefers). This makes `.orchestrator-handoff.json` an exclusively hard-mode-implement artifact,
formally, rather than by accident. The verification bar's alternate acceptance condition ("if
return-meta is chosen, no handoff and no recovery-bridge warnings") is already achievable today
for base mode without further engine changes — confirm rather than build.

**4. Align writers to the schema**:
- `wrap-up.md`: add `summary` (required) and `artifacts` (required, may be `[]`) to the
  "Required fields" JSON block; add a one-line note that `phase` is optional/informational.
- `general-implementation-hard-agent.md` Stage 5: add `summary` and `artifacts` to its handoff
  write template (currently has neither) — this is the fix for the newly-verified artifact-linking
  defect, not just a documentation nicety.
- `lean-implementation-hard-agent.md` Stage 5: add `artifacts` (has `summary` already); remove
  the redundant `continuation_context: null` now that only the flat form is canonical.
- `handoff-schema.md`: fold in `skeleton`/`sorry_inventory` and the hard blocker shape into its
  "Complete JSON Schema" block (or replace that prose block with a pointer to the new
  `.schema.json` file, consistent with how `events-schema.json` is referenced elsewhere); retire
  the `{description, phase, severity}` blocker shape and the `continuation_context`
  documentation as dead, mirroring how "Handoff Writers" already marks
  `skill_write_orchestrator_handoff` as unreferenced (this task removes the function rather than
  leaving it undead).
- Neither engine's reader jq needs a functional change beyond simplifying the now-unnecessary
  nested-continuation_context branch (safe to leave as inert dead code if the planner prefers a
  smaller diff, since it will simply never match after the writer is deleted).

## Decisions

- The canonical blocker shape is the wrap-up.md/hard-mode shape
  (`{phase, target, verbatim_goal, what_was_tried, why_it_failed}`); the schema-doc's
  `{description, phase, severity}` shape is retired as dead (verified: read by neither engine).
- The canonical continuation form is the flat top-level `continuation_path` string; the nested
  `continuation_context` form is retired along with its sole (unreferenced) writer.
- `.orchestrator-handoff.json` becomes formally hard-mode-implement-only; base-mode
  research/plan/implement continue to rely exclusively on `.return-meta.json` plus
  `orchestrate-recover-outcome.sh`, which already fully implements this contract today.
- `skill_write_orchestrator_handoff` should be deleted, not wired up.
- `validate-handoff.sh`'s status enum must expand to the full 6-value vocabulary and must gain an
  `artifacts` presence/shape check.

## Risks & Mitigations

- **Risk**: deleting `skill_write_orchestrator_handoff` could be read as "removing a safety net."
  **Mitigation**: it has zero callers and produces schema-non-conformant output; deleting dead,
  wrong-shaped code is strictly safer than leaving it as an attractive nuisance for a future
  caller who would inherit its bugs.
- **Risk**: adding a required `artifacts` field to `validate-handoff.sh` could newly fail
  existing hard-mode handoffs mid-flight (partial/blocked ones legitimately have no artifact yet).
  **Mitigation**: make the `artifacts`-non-empty requirement conditional on
  `status ∈ {researched, planned, implemented}` only, matching the recommendation above; `partial`
  and `blocked` may have an empty array.
- **Risk**: fixing `general-implementation-hard-agent.md`/`lean-implementation-hard-agent.md`'s
  Stage 5 templates changes what a live H9 writer emits — must not silently drop the existing
  `sorry_inventory`/`skeleton` machinery. **Mitigation**: additive change only (add `summary`,
  `artifacts`; remove only the now-dead `continuation_context: null` line), verified by re-reading
  the full templates before editing, not just the fragments quoted above.

## Context Extension Recommendations

- **Topic**: Orchestrator handoff schema
- **Gap**: No machine-checkable JSON Schema file exists for `.orchestrator-handoff.json` today —
  only prose documents (`handoff-schema.md`, `wrap-up.md`) and a partial bash validator.
- **Recommendation**: `agent-system/extensions/core/context/schemas/orchestrator-handoff-schema.json`,
  referenced from `handoff-schema.md` the same way other schemas in that directory are already
  referenced from their owning docs, and consumed by a rewritten `validate-handoff.sh`.

## Appendix

Search queries / greps used: `skill_write_orchestrator_handoff` (full-tree), `.blockers[0].`,
`.blockers[$i].`, `severity`, `\.description\b` (both engines + triage classifier),
`handoff_status_value|handoff_permits_promotion|expected_status` (reconcile-task-status.sh),
`orchestrator-handoff|H9|wrap-up` (all core agent files + lean-implementation-hard-agent.md).
Files read in full or near-full: `docs/architecture/handoff-schema.md`,
`context/contracts/wrap-up.md`, `scripts/validate-handoff.sh`,
`scripts/skill-base.sh` (`skill_write_orchestrator_handoff`, `skill_corroborate_phase_counts`
headers), `context/schemas/events-schema.json`, relevant fragments of
`skill-orchestrate/SKILL.md`, `skill-orchestrate-hard/SKILL.md`,
`general-implementation-hard-agent.md`, `lean-implementation-hard-agent.md`,
`reconcile-task-status.sh`. Task descriptions read from `specs/TODO.md`: 947 (abandoned), 948
(not started, depends on this task), 949 (abandoned, folded into 948), 968 (completed), 973
(completed), 974 (completed).

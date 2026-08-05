# Research Report: Task #948

**Task**: 948 - Add a Stage 7 / final-metadata contract to all three cslib agents
**Started**: 2026-08-05
**Completed**: 2026-08-05
**Effort**: ~1 hour (research only)
**Dependencies**: handoff-unification prerequisite (COMPLETED), cslib summary-format prerequisite (COMPLETED)
**Sources/Inputs**: Codebase (agent-system/extensions/cslib/agents/*.md, core/agents/general-research-agent.md, core/context/formats/return-metadata-file.md, core/docs/architecture/handoff-schema.md), completed-task summaries
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `cslib-research-agent.md` has a Stage 0 (early `in_progress` metadata) but **no terminal Stage
  7 at all** — it never names the terminal status value (`researched`) and never specifies the
  `artifacts` array shape. This is the confirmed, live root cause of the production incident:
  two dispatches wrote the off-vocabulary `"status": "research_complete"`, which the
  orchestrator's fail-closed branch refused, stranding both tasks at `[RESEARCHING]` despite
  fully successful research.
- `cslib-implementation-agent.md` (base) has scattered status-value mentions
  (`implemented`/`partial`) inside its Final Verification Stage, but likewise never states the
  `artifacts` array-of-objects shape or its rationale anywhere in the file.
- `cslib-implementation-hard-agent.md` already has a `### Stage 7: Write Metadata File` heading
  naming `implemented|partial|failed` — it needs only the `artifacts`-shape-with-rationale
  addition to `.return-meta.json`, plus two independently-confirmed, already-scoped-in
  `.orchestrator-handoff.json` gaps: it hardcodes `"continuation_context": null` with no
  population instruction (should populate the canonical flat `continuation_path` field instead),
  and its inline JSON example lacks the artifacts-shape rationale (the object shape itself is
  already correct in the example).
- **Settled answer for item 3** (which `.orchestrator-handoff.json` rule to encode), read
  directly from the now-current `handoff-schema.md`: `.orchestrator-handoff.json` is **formally
  hard-mode-implement-only**. `cslib-research-agent.md` and `cslib-implementation-agent.md`
  (base, non-hard) must NEVER write that file — an explicit prohibition, not a contract for
  writing one. Only `cslib-implementation-hard-agent.md` writes it, and only using the flat
  `continuation_path` form (the deprecated nested `continuation_context` form has zero live
  writers system-wide and must not be reintroduced).
- Recommended fix is additive-only across all three files: no restructuring, no renumbering of
  existing stages/sections.

## Context & Scope

The task asks for a Stage 7 / final-metadata contract mirroring
`agent-system/extensions/core/agents/general-research-agent.md`'s Stage 7 (lines 306-327) to be
added to all three cslib agents, plus resolution of the `.orchestrator-handoff.json` question
using the now-completed handoff-unification task's settled answer. Scope was widened (per the
task description) to also cover the cslib artifacts-shape propagation item that the
handoff-unification task explicitly excluded and left as a named follow-up.

Both cited prerequisite tasks are `[COMPLETED]`:
- `specs/982_unify_orchestrator_handoff_contract/` — unified the four previously-disagreeing
  descriptions of `.orchestrator-handoff.json` around one JSON Schema file, deleted the
  zero-caller nested-form writer, and rewrote `docs/architecture/handoff-schema.md`.
- `specs/963_resolve_cslib_summary_format_divergence/` — formalized `## Plan Deviations` as a
  recognized optional section of `summary-format.md` and wired both cslib implementation agents
  to it (unrelated to this task's `.return-meta.json`/`.orchestrator-handoff.json` scope, but
  confirms the current, correct state of the summary-writing stage these agents already carry).

## Findings

### Codebase Patterns

**Reference contract to mirror** (`agent-system/extensions/core/agents/general-research-agent.md`
lines 306-327, `### Stage 7: Write Metadata File`):

```markdown
### Stage 7: Write Metadata File

Write to `specs/{NNN}_{SLUG}/.return-meta.json` with status `researched`. Agent-specific metadata fields: `findings_count`. Include `memory_candidates` array (from Stage 5) at the top level of the JSON output. Set `next_steps` to `"Run /plan {N} to create implementation plan"`.

**`artifacts` shape (required)**: `artifacts` is a **required array of objects**, each with
`type`, `path`, and `summary` keys — **never an array of bare path strings**. A bare-string array
parses as valid JSON but silently breaks the orchestrator's artifact-linking read
(`.artifacts[0].path`), which yields an empty string against a string element instead of an
object. Minimal example:

```json
"artifacts": [
  {
    "type": "report",
    "path": "specs/{NNN}_{SLUG}/reports/{NN}_{slug}.md",
    "summary": "One-line description of what the report covers."
  }
]
```

See `@.claude/context/formats/return-metadata-file.md`'s `artifacts (required)` section for the
full field spec — this is a call-site reminder, not a replacement for that reference.
```

**Current state of `cslib-research-agent.md`** (`agent-system/extensions/cslib/agents/`):
- Has `## Stage 0: Initialize Early Metadata` (lines 220-246) writing `"status": "in_progress"`.
- Has `## Critical Requirements` MUST DO #2: "Always write final metadata to
  `specs/{N}_{SLUG}/.return-meta.json`" — but never states what status value to write.
- Has MUST NOT #6: "Use status value `completed`" — a prohibition with no correct alternative
  supplied in-file.
- **No Stage 7, no Stage 6, no terminal-metadata section of any kind anywhere in the file.** This
  is the single largest gap of the three agents and the one directly implicated in the observed
  production failure.
- No `artifacts` shape guidance anywhere.

**Current state of `cslib-implementation-agent.md`** (base, non-hard):
- `## Final Verification Stage (MANDATORY)` → `### Recording Verification Results` shows an
  inline example with `"status": "implemented"` and a bare `"artifacts": [...]` ellipsis — no
  shape spec, no rationale.
- `### On Verification Failure` names `status: "partial"`.
- `## Create Implementation Summary` stage (added by the completed cslib summary-format task)
  writes the summary artifact but does not itself touch `.return-meta.json`.
- `## Critical Requirements` MUST DO #10: "Always create summary file before returning
  implemented status" — again assumes but never states the artifacts-array-of-objects shape.
- No mention of `.orchestrator-handoff.json` anywhere in the file (confirmed via grep) — this is
  correct behavior per the settled contract below and should be made explicit rather than left
  implicit.

**Current state of `cslib-implementation-hard-agent.md`**:
- Already has `### Stage 7: Write Metadata File` (lines 349-364):
  ```markdown
  Write to `specs/{NNN}_{SLUG}/.return-meta.json` with status `implemented|partial|failed`.
  Include `phases_completed`, `phases_total`, `memory_candidates`, and verification results:
  ```
  This already names the terminal status values explicitly — good baseline, but still has no
  `artifacts`-shape-with-rationale text (item 2 of the required scope).
- Already writes `.orchestrator-handoff.json` in `### Stage 5: Wrap-Up Contract (H9)`, Step 2
  (lines 296-311), with an inline template:
  ```json
  {
    "status": "implemented | partial | blocked",
    "skeleton": false,
    "summary": "Brief summary of what was proven",
    "phases_completed": N,
    "phases_total": M,
    "sorry_inventory": [],
    "blockers": [],
    "continuation_context": null,
    "artifacts": [{"path": "...", "type": "summary", "summary": "..."}]
  }
  ```
  This is confirmed by `handoff-schema.md`'s own "Handoff Writers" table (see below) to carry
  **two live, named, unlanded gaps**: (a) `"continuation_context": null` is hardcoded with no
  instruction for populating it on a `partial` return — the file names the now-deprecated nested
  form and gives the agent no path to the canonical flat form; (b) the file "lacks the
  `artifacts`-shape spec" per that same table entry, even though the inline example's shape
  (`{path, type, summary}` object) already happens to be correct — the explicit rationale text is
  what is missing, not the shape itself.

### External Resources

Not applicable — this is a purely internal contract-alignment task with no external
documentation dependency.

### The Settled `.orchestrator-handoff.json` Answer (item 3)

Read directly from the current, post-982 `agent-system/extensions/core/docs/architecture/handoff-schema.md`, section "Handoff Writers — the settled decision, in one place":

> `.orchestrator-handoff.json` is formally **hard-mode-implement-only**. Base-mode
> research/plan/implement return via `.return-meta.json` ... research agents never write a
> handoff at all, in any mode. This is a decided contract, not a default that happened to emerge.

The Handoff Writers table's cslib row, verbatim:

| Writer | Status | Continuation form emitted | Notes |
|--------|--------|----------------------------|-------|
| cslib and lean hard-mode implementation agent counterparts | Active | Flat `continuation_path` | Mirror the core H9 wrap-up, with two known, named, unlanded gaps left as follow-ups (both extensions are out of this document's declared scope): `cslib-implementation-hard-agent.md` Stage 5 hardcodes `continuation_context: null` with no population instruction, and lacks the `artifacts`-shape spec; ... |

And the base-mode row:

| Writer | Status | Continuation form emitted | Notes |
|--------|--------|----------------------------|-------|
| Base-mode `skill-researcher`, `skill-planner`, `skill-implementer` | Never writes a handoff, by design | Neither (no handoff written at all) | Research is explicitly prohibited from writing one ... base-mode plan/implement rely exclusively on `.return-meta.json`. This is the decided, expected, `.return-meta.json`-recoverable case ... not an unaddressed defect. |

This settles all three agents unambiguously:

| Agent | `.orchestrator-handoff.json` rule |
|-------|-------------------------------------|
| `cslib-research-agent.md` | **Explicit prohibition** — never writes this file, in any mode. Return status exclusively via `.return-meta.json` with `status: "researched"`. |
| `cslib-implementation-agent.md` (base, non-hard) | **Explicit prohibition** — same as above; base-mode implement relies exclusively on `.return-meta.json` with `status: "implemented"`. This mirrors the closing "Follow-ups" note in the handoff-unification task's own summary, which found (and flagged as a defect to fix forward, not repeat) a base-mode dispatch instructed to write this file under `orchestrator_mode: true` — the fix is to state the prohibition explicitly rather than leave it implicit. |
| `cslib-implementation-hard-agent.md` | **Keep writing it** (already correct at the "when" level) — but close the two named gaps: (a) replace the hardcoded `"continuation_context": null` with instructions to populate the canonical **flat** `continuation_path` string field when `status != "implemented"` (never the deprecated nested `continuation_context` object — it has zero live writers system-wide per `handoff-schema.md`'s "One Write Form, Deprecated-But-Accepted Read Form" section); (b) add the artifacts-shape-with-rationale text (mirroring `wrap-up.md`'s field-semantics bullet: `artifacts` is what `skill_link_artifacts` consumes to link the produced summary file into `state.json` — an absent/empty `artifacts` on an `implemented` handoff silently prevents linking). |

The canonical flat-form field, per `wrap-up.md`'s H9 schema (the authoritative hard-mode prose
contract) and `handoff-schema.md`'s "Two Distinct... / continuation_path" field definition:

```json
"continuation_path": "specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-{TS}.md"
```

null when `status == "implemented"`; populated with the continuation markdown path when
`status != "implemented"`.

### Recommendations

**1. `cslib-research-agent.md`** — insert a new `## Stage 7: Write Final Metadata` section
(mirroring `general-research-agent.md`'s Stage 7 verbatim in structure, adapted for CSLib):

```markdown
## Stage 7: Write Final Metadata

Write to `specs/{N}_{SLUG}/.return-meta.json` with `"status": "researched"`. Include
`memory_candidates` if any reusable CSLib patterns were discovered. Set `next_steps` to
`"Run /plan {N} to create implementation plan"`.

**`artifacts` shape (required)**: `artifacts` is a **required array of objects**, each with
`type`, `path`, and `summary` keys — **never an array of bare path strings**. A bare-string array
parses as valid JSON but silently breaks the orchestrator's artifact-linking read
(`.artifacts[0].path`), which yields an empty string against a string element instead of an
object. Minimal example:

```json
"artifacts": [
  {
    "type": "report",
    "path": "specs/{N}_{SLUG}/reports/{NN}_{slug}.md",
    "summary": "One-line description of what the report covers."
  }
]
```

See `@.claude/context/formats/return-metadata-file.md`'s `artifacts (required)` section for the
full field spec.

**`.orchestrator-handoff.json` prohibition**: this agent MUST NOT write
`.orchestrator-handoff.json`, in any mode, including when `orchestrator_mode: true` is present in
the delegation context. `.orchestrator-handoff.json` is formally hard-mode-implement-only per
`@.claude/docs/architecture/handoff-schema.md`; research agents return status exclusively through
`.return-meta.json`.
```

Also update MUST NOT #6 to give the correct alternative inline ("...use `\"researched\"`
instead — see Stage 7"), and add a MUST NOT bullet for the handoff prohibition to the Critical
Requirements list for symmetry with the new Stage 7 text.

**2. `cslib-implementation-agent.md`** — insert a new `## Stage 7: Write Final Metadata` section
(placed after `## Create Implementation Summary`, before `## CSLib Style Compliance`, matching
where the base agent's Final Verification → Summary → final-metadata sequence naturally falls):

```markdown
## Stage 7: Write Final Metadata

Write to `specs/{N}_{SLUG}/.return-meta.json` with `"status": "implemented"` (or `"partial"` per
the Final Verification Stage's failure branch). Include `completion_data.completion_summary` and
the `verification` object from the Final Verification Stage.

**`artifacts` shape (required)**: `artifacts` is a **required array of objects**, each with
`type`, `path`, and `summary` keys — **never an array of bare path strings**. A bare-string array
parses as valid JSON but silently breaks the orchestrator's artifact-linking read
(`.artifacts[0].path`), which yields an empty string against a string element instead of an
object. Minimal example:

```json
"artifacts": [
  {
    "type": "summary",
    "path": "specs/{N}_{SLUG}/summaries/{NN}_{slug}-summary.md",
    "summary": "One-line description of what was implemented."
  }
]
```

See `@.claude/context/formats/return-metadata-file.md`'s `artifacts (required)` section for the
full field spec.

**`.orchestrator-handoff.json` prohibition**: this agent MUST NOT write
`.orchestrator-handoff.json`, in any mode, including when `orchestrator_mode: true` is present in
the delegation context. `.orchestrator-handoff.json` is formally hard-mode-implement-only per
`@.claude/docs/architecture/handoff-schema.md`; base-mode implementation returns status
exclusively through `.return-meta.json`.
```

**3. `cslib-implementation-hard-agent.md`** — amend the existing `### Stage 7: Write Metadata
File` (already correctly named) to add the artifacts-shape-with-rationale text, and amend
`### Stage 5: Wrap-Up Contract (H9)` Step 2 to fix the `continuation_context: null` gap:

- Stage 7 addition:
  ```markdown
  **`artifacts` shape (required)**: `artifacts` is a **required array of objects**, each with
  `type`, `path`, and `summary` keys — **never an array of bare path strings**. A bare-string
  array parses as valid JSON but silently breaks the orchestrator's artifact-linking read
  (`.artifacts[0].path`). See `@.claude/context/formats/return-metadata-file.md`'s `artifacts
  (required)` section for the full field spec.
  ```

- Stage 5 Step 2 template fix — replace:
  ```json
  "continuation_context": null,
  ```
  with:
  ```json
  "continuation_path": null,
  ```
  and add the population rule (mirroring `wrap-up.md`'s field semantics verbatim): "`null` when
  `status == \"implemented\"`; when `status != \"implemented\"`, set to the path of the
  continuation handoff markdown artifact written under `handoffs/` — this is the ONLY canonical
  writable continuation form. Never write the nested `continuation_context` object; it has zero
  live writers system-wide and is retained only as a deprecated, read-only-accepted legacy shape."
  Also add the `artifacts`-linking rationale bullet (why `skill_link_artifacts` needs a populated
  `artifacts` array on `implemented`) alongside the existing field, since the table entry calls
  out that the file "lacks the `artifacts`-shape spec" despite the example's shape already being
  correct — the missing piece is the rationale prose, not the JSON.

### Additive-Only Constraint

All three edits are pure additions or narrow in-place corrections (`continuation_context` →
`continuation_path`, one wrong key) — no existing stage numbering, section ordering, or prose
needs to shift. `cslib-implementation-hard-agent.md`'s existing `### Stage 8: Return Brief Text
Summary` (currently following Stage 7) is unaffected since the new text is appended within Stage
7, not inserted as a new numbered stage.

## Decisions

- Mirror `general-research-agent.md`'s Stage 7 prose near-verbatim for `cslib-research-agent.md`
  and `cslib-implementation-agent.md` (new sections), rather than inventing new wording — this is
  explicitly what the task asks for ("mirror") and keeps the artifacts-shape rationale
  byte-consistent across the agent population, which is the property that stops future drift.
- For `cslib-implementation-hard-agent.md`, amend in place rather than duplicating a whole new
  Stage 7, since a correctly-named Stage 7 already exists — only the two missing pieces
  (artifacts rationale, `continuation_path` fix) need to land.
- Encode the `.orchestrator-handoff.json` question as an **explicit prohibition** for the two
  non-hard agents, per the task's own "CRITICAL - DO NOT PRE-COMMIT ITEM 3" instruction and the
  now-settled `handoff-schema.md` text — this is not an invented rule; it is a direct
  transcription of "research agents never write a handoff at all, in any mode" and "base-mode ...
  implement rely exclusively on `.return-meta.json`" from that document's Handoff Writers table.
- Fix `continuation_context: null` → `continuation_path: null` in the hard agent's inline
  template rather than leaving the deprecated nested form as a "still technically valid" no-op,
  because `handoff-schema.md`'s "Do not re-introduce a nested-form writer" guidance is explicit
  that no writer should ever produce that shape again, and the current template is the one
  concrete place in the cslib extension where a future implementer could copy-paste the
  deprecated form back into a live write path.

## Risks & Mitigations

- **Risk**: Editing `.claude/**` directly instead of the source store. **Mitigation**: all edits
  described above target `agent-system/extensions/cslib/agents/*.md` exclusively — the deploy
  tree at `.claude/` must not be hand-edited (per
  `.claude/rules/source-store-deploy-boundary.md`).
- **Risk**: Task-number citations landing in the edited agent files (deliverables outside
  `specs/**`). **Mitigation**: this report and the planned edits avoid any task-number reference;
  all cross-references above use durable anchors (file paths, section headings) as required by
  `.claude/rules/no-task-references-in-deliverables.md`.
- **Risk**: Drifting from the exact wrap-up.md/general-research-agent.md wording in a way that
  reintroduces inconsistency. **Mitigation**: the recommended text blocks above are copied
  near-verbatim from the two authoritative sources (`general-research-agent.md` Stage 7,
  `wrap-up.md`'s field-semantics section) rather than paraphrased.
- **Risk**: `cslib-vet-agent.md` and `cslib-research-hard-agent.md` were not read in depth for
  this task — they are out of the declared scope ("ALL THREE cslib agents" names research,
  implementation, and implementation-hard only) but may share the same gap. Not investigated
  further here; flagged as a possible follow-up below.

## Context Extension Recommendations

- **Topic**: cslib-research-hard-agent.md's terminal-metadata contract.
- **Gap**: This report did not audit `cslib-research-hard-agent.md` (a fourth cslib agent not
  named in this task's scope) for the same Stage 7 gap. Given `cslib-research-agent.md`'s
  confirmed total absence of a terminal-metadata stage, the hard-mode research counterpart is a
  plausible candidate for the same defect.
- **Recommendation**: A follow-up task should grep `cslib-research-hard-agent.md` for `Stage 7`
  and `status.*researched` to confirm whether it independently needs the same fix, or already
  inherits/duplicates the base research agent's (still-being-fixed) contract correctly.

## Appendix

### Search Queries / Reads Used

- Read: `agent-system/extensions/cslib/agents/cslib-research-agent.md` (full file)
- Read: `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` (full file)
- Read: `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` (full file)
- Read: `agent-system/extensions/core/agents/general-research-agent.md` (full file, reference contract)
- Read: `agent-system/extensions/core/context/formats/return-metadata-file.md` (full file)
- Read: `agent-system/extensions/core/docs/architecture/handoff-schema.md` (full file, current post-982 text)
- Read: `specs/982_unify_orchestrator_handoff_contract/summaries/01_unify-handoff-contract-summary.md`
- Read: `specs/963_resolve_cslib_summary_format_divergence/summaries/01_resolve-summary-format-divergence-summary.md`
- Read (excerpt): `agent-system/extensions/core/agents/general-implementation-hard-agent.md` (Stage 5 region)
- Read: `agent-system/extensions/core/context/contracts/wrap-up.md` (H9 canonical handoff schema)
- Grep: `orchestrator-handoff\|orchestrator_mode` across the three cslib agent files — confirmed
  base agent and research agent have zero references; hard agent has four, all consistent with
  the "keep writing it, fix two gaps" recommendation.
- Grep: `research_complete` across `agent-system/` — confirmed the off-vocabulary value is
  already independently known to `reconcile-task-status.sh`'s synonym-table mechanism and its
  test fixture (`test-reconcile-handoff-status.sh` case 5), which is a defense-in-depth
  reconciliation layer distinct from, and not a substitute for, fixing the producing agent's
  contract directly.

### References

- `agent-system/extensions/cslib/agents/cslib-research-agent.md`
- `agent-system/extensions/cslib/agents/cslib-implementation-agent.md`
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`
- `agent-system/extensions/core/agents/general-research-agent.md`
- `agent-system/extensions/core/context/formats/return-metadata-file.md`
- `agent-system/extensions/core/docs/architecture/handoff-schema.md`
- `agent-system/extensions/core/context/contracts/wrap-up.md`
- `specs/982_unify_orchestrator_handoff_contract/summaries/01_unify-handoff-contract-summary.md`
- `specs/963_resolve_cslib_summary_format_divergence/summaries/01_resolve-summary-format-divergence-summary.md`

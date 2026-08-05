# Implementation Plan: Task #948

- **Task**: 948 - Add a Stage 7 / final-metadata contract to all three cslib agents
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None (both cited prerequisites are [COMPLETED])
- **Research Inputs**: `specs/948_add_stage7_final_metadata_to_cslib_research_agent/reports/01_stage7-final-metadata-cslib-agents.md`
- **Artifacts**: plans/01_stage7-cslib-agent-contracts.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Three cslib agent definitions in the source store either lack a terminal-metadata stage entirely
or state it incompletely, which lets an agent invent an off-vocabulary `status` value at return
time and strands the task at its in-progress status. This plan lands three independent,
additive-only prose edits — a new `## Stage 7: Write Final Metadata` in `cslib-research-agent.md`
and `cslib-implementation-agent.md`, plus two narrow in-place corrections inside
`cslib-implementation-hard-agent.md`'s existing Stage 7 and Stage 5 — followed by one
cross-file consistency and lint gate. Definition of done: all three files name their terminal
status value explicitly, all three carry the `artifacts` array-of-objects shape with its
rationale, the two non-hard agents carry an explicit `.orchestrator-handoff.json` prohibition,
and the hard agent's handoff template emits the canonical flat `continuation_path` field.

### Research Integration

The research report supplies the confirmed root cause and ready-to-drop text for every edit; this
plan uses it verbatim rather than re-deriving wording. Key findings carried through:

- `cslib-research-agent.md` has a Stage 0 writing `"status": "in_progress"` but **no terminal
  stage of any kind** — no Stage 6, no Stage 7, no `artifacts` shape guidance. This is the
  confirmed root cause of the off-vocabulary-status incident.
- `cslib-implementation-agent.md` mentions `implemented`/`partial` inside its Final Verification
  Stage but never states the `artifacts` array-of-objects shape or its rationale.
- `cslib-implementation-hard-agent.md` already has a correctly-named Stage 7 naming
  `implemented|partial|failed`; it needs only the `artifacts`-shape rationale plus the two
  `.orchestrator-handoff.json` gaps named in `handoff-schema.md`'s own Handoff Writers table.
- The `.orchestrator-handoff.json` question is settled, not open: that file is formally
  hard-mode-implement-only. The research agent and the base implementation agent get an explicit
  prohibition; only the hard agent writes it, using flat `continuation_path`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:
- Give `cslib-research-agent.md` a terminal `## Stage 7: Write Final Metadata` naming
  `"status": "researched"` explicitly.
- Give `cslib-implementation-agent.md` a terminal `## Stage 7: Write Final Metadata` naming
  `"status": "implemented"` (with the `"partial"` failure branch).
- Give all three agents the `artifacts` array-of-objects shape **with its rationale**, mirrored
  near-verbatim from `general-research-agent.md`'s Stage 7 so the text stays greppable and
  byte-consistent across the agent population.
- Encode the settled `.orchestrator-handoff.json` rule: explicit prohibition in the two non-hard
  agents; flat `continuation_path` (never nested `continuation_context`) in the hard agent's
  Stage 5 write template.
- Keep every edit additive-only: no stage renumbering, no section reordering, no rewriting of
  existing prose beyond the one wrong key name.

**Non-Goals**:
- Auditing or editing `cslib-research-hard-agent.md` or `cslib-vet-agent.md`. Neither is in this
  task's `file_scope`; see Follow-Up Recommendations below.
- Any edit under `.claude/**`. That tree is a gitignored, disposable deploy artifact regenerated
  from the source store; hand-authored files there are silently wiped.
- Changing `handoff-schema.md`, `wrap-up.md`, `return-metadata-file.md`, or any core context file.
  This task consumes those contracts; it does not amend them.
- Redeploying the extension tree. Deployment is a separate, user-initiated step.
- Changing the hard agent's Stage 1 *read* of the delegation-context `continuation_context` field
  (see Decisions below).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Edits land in `.claude/**` instead of the source store | H | M | Every phase names an absolute `agent-system/extensions/cslib/agents/...` path; Phase 4 greps for any `.claude/` write in the diff |
| Task-number citation lands in a deliverable file | M | M | The drop-in text blocks below contain zero task numbers; Phase 4 runs `check-task-references.sh` |
| Paraphrasing drifts from the authoritative wording, reintroducing the inconsistency being fixed | M | M | Copy the text blocks in this plan verbatim; Phase 4 diffs the artifacts-rationale paragraph across all three files for byte-consistency |
| Accidental renumbering or reordering of existing stages | M | L | Insertion points are specified by neighboring section heading, not line number; Phase 4 confirms the pre-existing heading sequence is unchanged |
| The deprecated nested `continuation_context` form gets copy-pasted forward from the hard agent's template | M | L | Phase 3 replaces the key and adds an explicit never-write instruction naming the deprecation |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. Phases 1-3 touch three disjoint files and
have no ordering constraint between them.

---

### Phase 1: Add Stage 7 to cslib-research-agent.md [NOT STARTED]

**Goal**: Give the research agent an explicit terminal-metadata contract naming
`"status": "researched"`, the `artifacts` shape with rationale, and the
`.orchestrator-handoff.json` prohibition.

**Tasks**:
- [ ] Read `agent-system/extensions/cslib/agents/cslib-research-agent.md` and locate the
      `## Stage 0: Initialize Early Metadata` section and the `## Error Handling` section that
      follows it.
- [ ] Insert a new `## Stage 7: Write Final Metadata` section **between** `## Stage 0: Initialize
      Early Metadata` and `## Error Handling`, using the drop-in text below verbatim.
- [ ] In `## Critical Requirements` -> MUST NOT, amend the existing bullet reading
      `Use status value "completed" (triggers Claude stop behavior)` to supply the correct
      alternative inline: `Use status value "completed" (triggers Claude stop behavior) -- use
      "researched" instead; see Stage 7`.
- [ ] In `## Critical Requirements` -> MUST NOT, append a new bullet:
      `Write .orchestrator-handoff.json -- research agents never write a handoff, in any mode
      (see Stage 7)`.
- [ ] Confirm no existing heading was renumbered, reworded, or reordered.

**Drop-in text for the new Stage 7** (copy verbatim; the nested ```json fence is part of the
inserted content):

````markdown
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
````

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/cslib/agents/cslib-research-agent.md` - insert new Stage 7 section;
  amend two MUST NOT bullets

**Verification**:
- `grep -n '^## Stage 7: Write Final Metadata' agent-system/extensions/cslib/agents/cslib-research-agent.md` returns exactly one match.
- `grep -c 'researched' <file>` is at least 1 and the match sits inside the new Stage 7.
- `grep -n 'orchestrator-handoff' <file>` returns matches only inside the new Stage 7 and the new
  MUST NOT bullet — never as an instruction to write the file.
- The pre-edit heading sequence (`## Stage 0 ...`, `## Error Handling`, `## Critical Requirements`)
  is intact and in the same relative order, with the new heading inserted between the first two.
- Every changed hunk lies inside markdown prose (prose-tier diff read-through).

---

### Phase 2: Add Stage 7 to cslib-implementation-agent.md [NOT STARTED]

**Goal**: Give the base (non-hard) implementation agent an explicit terminal-metadata contract
naming `"status": "implemented"`, the `artifacts` shape with rationale, and the
`.orchestrator-handoff.json` prohibition.

**Tasks**:
- [ ] Read `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` and locate the
      `## Create Implementation Summary` section and the `## CSLib Style Compliance` section that
      follows it.
- [ ] Insert a new `## Stage 7: Write Final Metadata` section **between** those two headings,
      using the drop-in text below verbatim.
- [ ] In `## Critical Requirements` -> MUST NOT, append a bullet:
      `Write .orchestrator-handoff.json -- base-mode implementation never writes a handoff
      (see Stage 7)`.
- [ ] Confirm the existing `### Recording Verification Results` and `### On Verification Failure`
      subsections are left untouched — the new Stage 7 references them rather than restating them.

**Drop-in text for the new Stage 7** (copy verbatim):

````markdown
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
````

**Timing**: 0.4 hours

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` - insert new Stage 7
  section; append one MUST NOT bullet

**Verification**:
- `grep -n '^## Stage 7: Write Final Metadata' <file>` returns exactly one match, positioned after
  `## Create Implementation Summary` and before `## CSLib Style Compliance`.
- `grep -n 'orchestrator-handoff' <file>` returns matches only in the new Stage 7 and the new MUST
  NOT bullet. (Pre-edit this grep returned zero matches; every post-edit match must be a
  prohibition, never a write instruction.)
- The `### Recording Verification Results` example block is byte-unchanged.
- Every changed hunk lies inside markdown prose (prose-tier diff read-through).

---

### Phase 3: Close the two named gaps in cslib-implementation-hard-agent.md [NOT STARTED]

**Goal**: Add the `artifacts`-shape rationale to the existing Stage 7 and replace the deprecated
nested `continuation_context` key in the Stage 5 handoff template with the canonical flat
`continuation_path`, plus its population rule and the artifacts-linking rationale.

**Tasks**:
- [ ] Read `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` and locate
      `### Stage 5: Wrap-Up Contract (H9)` Step 2 and `### Stage 7: Write Metadata File`.
- [ ] **Gap A (Stage 7)**: append the artifacts-shape paragraph below to the existing
      `### Stage 7: Write Metadata File` section. Do NOT create a second Stage 7 and do NOT
      renumber `### Stage 8: Return Brief Text Summary`.
- [ ] **Gap B (Stage 5, Step 2)**: in the inline handoff JSON template, replace the line
      `"continuation_context": null,` with `"continuation_path": null,`.
- [ ] **Gap B, continued**: immediately below that template, add the population rule and the
      artifacts-linking rationale text below.
- [ ] Leave `### Stage 1: Parse Delegation Context`'s `continuation_context` bullets untouched —
      see Decisions.

**Gap A drop-in text** (append inside the existing Stage 7):

````markdown
**`artifacts` shape (required)**: `artifacts` is a **required array of objects**, each with
`type`, `path`, and `summary` keys — **never an array of bare path strings**. A bare-string
array parses as valid JSON but silently breaks the orchestrator's artifact-linking read
(`.artifacts[0].path`). See `@.claude/context/formats/return-metadata-file.md`'s `artifacts
(required)` section for the full field spec.
````

**Gap B drop-in text** (add below the corrected Stage 5 Step 2 JSON template):

````markdown
**`continuation_path` population rule**: `null` when `status == "implemented"`; when
`status != "implemented"`, set it to the path of the continuation handoff markdown artifact
written under `handoffs/`. This flat string field is the ONLY canonical writable continuation
form. Never write the nested `continuation_context` object — it has zero live writers
system-wide and is retained only as a deprecated, read-only-accepted legacy shape per
`@.claude/docs/architecture/handoff-schema.md`.

**`artifacts` linking rationale**: `artifacts` is what the orchestrator's artifact-linking step
consumes to link the produced summary file into `state.json`. It is an array of objects with
`path`, `type`, and `summary` keys — never bare path strings. An absent or empty `artifacts`
array on an `implemented` handoff silently prevents that linking from happening.
````

**Timing**: 0.4 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts exactly **two** gaps in this file (missing artifacts
rationale in Stage 7; deprecated `continuation_context` key plus missing rationale in Stage 5
Step 2), and asserts that **exactly one** occurrence of `"continuation_context": null` exists in
the Stage 5 write template. Confirm at implementation time with
`grep -n 'continuation_context\|continuation_path' <file>` before editing: the expected pre-edit
result is one occurrence inside the Stage 5 JSON template plus the Stage 1 delegation-context
read bullets. If the write-side count is anything other than one, stop and report the divergence
rather than editing blind.

**Files to modify**:
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` - append artifacts
  rationale to Stage 7; correct one key name and add two rationale paragraphs in Stage 5 Step 2

**Verification**:
- `grep -c '^### Stage 7: Write Metadata File' <file>` returns exactly 1 (no duplicate stage).
- `grep -n '^### Stage 8: Return Brief Text Summary' <file>` still returns exactly one match and
  still follows Stage 7.
- `grep -n '"continuation_context"' <file>` returns zero matches inside the Stage 5 JSON write
  template.
- `grep -n '"continuation_path"' <file>` returns exactly one match, inside that template.
- Every changed hunk lies inside markdown prose or an illustrative JSON code block (prose-tier
  diff read-through).

---

### Phase 4: Cross-file consistency and repository lint gate [NOT STARTED]

**Goal**: Confirm the three files are mutually consistent, that no edit escaped the source store,
and that the repository's standing lint gates pass.

**Tasks**:
- [ ] Confirm the changed-file set is exactly the three cslib agent files and nothing else:
      `git status --short` and `git diff --name-only`.
- [ ] Confirm zero writes under `.claude/**`: the diff must contain no `.claude/` path.
- [ ] Diff the artifacts-shape rationale paragraph across all three files and against
      `agent-system/extensions/core/agents/general-research-agent.md`'s Stage 7 to confirm the
      wording is mirrored, not paraphrased. The hard agent's variant is intentionally the
      condensed form (no inline JSON example) per Phase 3; the two non-hard agents carry the full
      form with the example.
- [ ] Run `bash .claude/scripts/check-task-references.sh` and confirm it exits 0 — no task-number
      citation may appear in any of the three edited files.
- [ ] Confirm every `@.claude/...` reference introduced by Phases 1-3 resolves to an existing
      file (this closes the `prose` tier's named blind spot for broken cross-references):
      `.claude/context/formats/return-metadata-file.md` and
      `.claude/docs/architecture/handoff-schema.md`.
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` if present and confirm it exits 0.
- [ ] Confirm each of the three files now names its terminal status value explicitly:
      `researched` in the research agent, `implemented` in both implementation agents.

**Timing**: 0.3 hours

**Depends on**: 1, 2, 3

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the changed-file set is **exactly three** files, all
under `agent-system/extensions/cslib/agents/`. Confirm with `git diff --name-only` at
implementation time; any fourth path is a scope violation to report, not to absorb.

**Files to modify**:
- None expected. If a lint gate fails, the corrective edit goes to the offending source-store
  file, never to `.claude/**`.

**Verification**:
- `git diff --name-only` lists exactly the three cslib agent file paths.
- `check-task-references.sh` exits 0.
- Both `@.claude/...` reference targets exist on disk.
- All three terminal status values are greppable in their respective files.

---

## Testing & Validation

- [ ] `grep -rn '^## Stage 7\|^### Stage 7' agent-system/extensions/cslib/agents/` shows a
      terminal-metadata stage in all three in-scope files.
- [ ] The exact off-vocabulary status string that caused the original incident appears nowhere in
      any of the three files.
- [ ] `grep -rn 'orchestrator-handoff' agent-system/extensions/cslib/agents/cslib-research-agent.md
      agent-system/extensions/cslib/agents/cslib-implementation-agent.md` yields only prohibition
      language, never a write instruction.
- [ ] `grep -rn 'continuation_context' agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`
      yields no match inside the Stage 5 handoff write template.
- [ ] `bash .claude/scripts/check-task-references.sh` exits 0.
- [ ] No file under `.claude/**` appears in the diff.

## Artifacts & Outputs

- `agent-system/extensions/cslib/agents/cslib-research-agent.md` (modified)
- `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` (modified)
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` (modified)
- `specs/948_add_stage7_final_metadata_to_cslib_research_agent/summaries/01_stage7-cslib-agent-contracts-summary.md`

## Decisions

- **Mirror, do not paraphrase.** The artifacts-shape rationale is copied near-verbatim from
  `general-research-agent.md`'s Stage 7 rather than reworded, so the text stays byte-consistent
  and greppable across the agent population. That consistency is the property that stops future
  drift; a paraphrase would defeat it.
- **Amend the hard agent's Stage 7 in place; do not add a second one.** A correctly-named Stage 7
  already exists there, and adding a parallel section would create exactly the ambiguity this task
  removes. The additive text lands inside the existing section, leaving Stage 8 unmoved.
- **The `.orchestrator-handoff.json` question is transcribed, not invented.** "Research agents
  never write a handoff at all, in any mode" and "base-mode implement rely exclusively on
  `.return-meta.json`" come directly from `handoff-schema.md`'s Handoff Writers table.
- **Leave the hard agent's Stage 1 `continuation_context` read untouched.** Stage 1 reads a
  *delegation-context* field of that name, which is a different channel from the handoff file the
  agent writes in Stage 5; the deprecated nested shape remains read-accepted by contract. Changing
  it is outside the settled scope. If the implementer observes that a flat-`continuation_path`
  handoff can no longer trigger Stage 1's `continuation_context.is_successor` resume branch, record
  that observation in the implementation summary as a follow-up rather than acting on it here.

## Follow-Up Recommendations (not phases)

- **`cslib-research-hard-agent.md`** is a fourth cslib agent, deliberately outside this task's
  `file_scope`, and was not audited. Given the base research agent's confirmed total absence of a
  terminal-metadata stage, its hard-mode counterpart is a plausible candidate for the same defect.
  A follow-up task should grep it for a Stage 7 heading and a `researched` status value to confirm
  whether it independently needs the same fix. Do not widen this task to cover it.
- **`cslib-vet-agent.md`** was likewise not audited and may share the gap.
- **Deployment**: these are source-store edits. They reach `.claude/` only via a subsequent
  `[Reload All]`/`[Regenerate]` sync or `deploy-headless.sh`, which is a separate, user-initiated
  step and not part of this plan.

## Rollback/Contingency

All four phases are confined to three markdown files under `agent-system/extensions/cslib/agents/`
and are committed per-phase. Reverting is a per-file `git revert` of the offending phase commit;
no build artifact, generated file, or deploy tree is touched, so a revert needs no follow-up
regeneration. If a phase is interrupted mid-edit, the file is left in a state where the pre-edit
sections are intact (all edits are insertions plus one single-key replacement), so the next
`/implement` can resume by re-running that phase's verification greps to determine what landed.

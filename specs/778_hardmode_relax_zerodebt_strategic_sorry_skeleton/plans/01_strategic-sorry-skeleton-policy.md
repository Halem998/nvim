# Implementation Plan: Task #778

- **Task**: 778 - Hard-mode: relax zero-debt for strategic-sorry skeletons (division mechanism)
- **Status**: [COMPLETED]
- **Effort**: 3.5 hours
- **Dependencies**: None (foundational; tasks 772 and 774 depend on this task)
- **Research Inputs**: specs/778_hardmode_relax_zerodebt_strategic_sorry_skeleton/reports/01_strategic-sorry-skeleton-policy.md
- **Artifacts**: plans/01_strategic-sorry-skeleton-policy.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/context/formats/return-metadata-file.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 778 relaxes the hard-mode zero-debt / build-green completeness bar so that a documented,
tracked "strategic sorry" skeleton is an acceptable `--hard` dispatch outcome, while STANDARD
mode and the build-green (must-typecheck) invariant remain unchanged. The change is confined to
four core files: the H2 anti-analysis contract (policy definition), the H9 wrap-up contract
(handoff schema + build-green invariant), the hard implementer skill (return parsing), and the
hard implementation agent (wrap-up execution). Gating is already structural — these files are
loaded only by `-hard` skills/agents — so the relaxation is `--hard`-only by construction; the
plan makes that gate explicit with a one-line note in each contract.

Definition of done: (1) anti-analysis.md defines a domain-agnostic 5-condition strategic-sorry
acceptance test; (2) wrap-up.md adds a `skeleton` boolean to the handoff schema and extends the
`sorry_inventory` entry schema, and amends the "No leftover scaffolding" clause with the
`--hard`-only exception; (3) skill-implementer-hard parses and logs skeleton dispatches;
(4) general-implementation-hard-agent.md reports a strategic-sorry skeleton as
`status: "implemented"` + `skeleton: true` rather than `partial`/`blocked`; (5) both deployed
and `extensions/core` source copies of the dual-tracked files stay byte-identical.

### Research Integration

The plan applies the exact clause edits recommended in
`reports/01_strategic-sorry-skeleton-policy.md`. Key decisions carried directly from research:
- **No 4th status enum**: keep `status ∈ {implemented, partial, blocked}` and add a boolean
  `skeleton` field, minimizing blast radius on `validate-handoff.sh` and every consumer that
  gates on `status == "implemented"`.
- **Division of responsibility**: the *policy* (5-condition test) lives in `anti-analysis.md`;
  the *schema/reporting mechanics* (`skeleton`, extended `sorry_inventory`) live in `wrap-up.md`;
  the two cross-reference rather than duplicate.
- **Canonical `sorry_inventory` entry schema** (pinned here so all phases stay consistent):
  `{file, line, statement, strategic, assumption, why_deferred, follow_up_task}`.
- **status / skeleton interaction** (pinned here): `implemented`+`skeleton:false` = fully
  complete (unchanged); `implemented`+`skeleton:true` = build-green with only tracked strategic
  sorries; `partial`/`blocked`+`skeleton:true` = invalid combination.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists but no `--roadmap` flag was passed to this planning dispatch, so no
ROADMAP review/update phases are included. Task 778 is the foundational leg of the three-part
hard-mode revision (777 research, 774 planning leg, 772 implementation leg); this plan does not
modify ROADMAP.md.

## Goals & Non-Goals

**Goals**:
- Define a domain-agnostic 5-condition test for a "strategic" sorry in `anti-analysis.md`.
- Add a `skeleton` boolean and extended `sorry_inventory` entry schema to `wrap-up.md`; amend
  the "No leftover scaffolding" build-green clause with the `--hard`-only strategic-sorry
  exception; keep build-green (must-typecheck) intact.
- Make the `--hard`-only gate explicit with a one-line note in both contract files.
- Require every strategic sorry to carry a non-null `follow_up_task` (task number or sub-phase).
- Update `skill-implementer-hard` (Stage 6 parsing + log line) and
  `general-implementation-hard-agent.md` (Stage 5 third worked example + policy subsection +
  MUST-DO line) so a skeleton dispatch reports "implemented (skeleton)".
- Keep the deployed copies and their `extensions/core` source copies byte-identical.

**Non-Goals**:
- Do NOT modify the lean or cslib extension override files
  (`.claude/extensions/lean/context/contracts/anti-analysis.md`,
  `lean-implementation-hard-agent.md`, `cslib-implementation-hard-agent.md`). They currently
  forbid main-target sorries unconditionally and contradict the new core policy; this is
  captured as a downstream note (Phase 5), not fixed here.
- Do NOT change STANDARD-mode behavior or any standard-mode skill/agent.
- Do NOT add a 4th `status` enum value.
- Do NOT modify `validate-handoff.sh` or `lint-contract-compliance.sh` (research confirms
  existing checks pass unchanged; structural validation is a flagged follow-up, not in scope).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Lean/cslib extension overrides contradict the new core policy for the exact (Lean4) domain that motivated 772/774 | H | H | Out of scope by task definition; captured explicitly as a downstream note in Phase 5 (surfaced for 772/774), with a recommended follow-up task to reconcile overrides + rename `next_dispatch`→`follow_up_task` |
| `sorry_inventory` schema drifts between anti-analysis.md (condition 4) and wrap-up.md (canonical schema) | M | M | Canonical entry schema pinned in this Overview; Phase 5 greps both files to confirm field names match |
| Deployed copy and `extensions/core` source copy diverge (dual-tracked files) | M | M | Phases 3 and 4 explicitly edit both copies and verify with `diff`; Phase 5 re-verifies all dual pairs are identical |
| Agent mislabels an abandoned/stuck sorry as "strategic" to dodge an honest `partial`/`blocked` | M | M | Non-null `follow_up_task` requirement is the load-bearing check; condition (1) "deliberate division boundary, not an abandoned proof" stated in policy; deeper validator enforcement flagged as follow-up |
| A future refactor causes a standard-mode skill to load these contracts, silently importing the relaxation | L | L | Explicit one-line `--hard`-only note added to both contract sections converts the accidental structural gate into a stated invariant |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4 | 1, 2 |
| 3 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch disjoint files
(`anti-analysis.md`, `wrap-up.md`) and share only the canonical schema pinned in the Overview,
so they are safely parallel.

---

### Phase 1: anti-analysis.md — strategic-sorry acceptance policy [COMPLETED]

**Goal**: Broaden the "Sub-Sorry Policy" section from leaf-only / formal-verification-only into a
domain-agnostic policy that defines the 5-condition strategic-sorry acceptance test, while
keeping the existing leaf-sorry bullets and the "main-target sorries forbidden" default intact
for non-strategic sorries.

**Tasks**:
- [ ] Edit `.claude/context/contracts/anti-analysis.md`, "Sub-Sorry Policy" section (lines ~45-51).
- [ ] Retitle the section to drop "(for formal verification domains)" and add a one-line note
      stating this policy applies only under `--hard` (this contract file is loaded exclusively
      by hard-mode dispatch paths).
- [ ] Keep the three existing leaf-sub-sorry bullets verbatim (unchanged behavior).
- [ ] Add a new "Strategic sorries (skeleton division points)" subsection defining the five
      acceptance conditions: (1) deliberate division boundary from a skeleton plan, NOT an
      abandoned/stuck proof; (2) tightly scoped to one theorem/function/definition; (3) documented
      with assumption + why-deferred + owning follow-up task/sub-phase; (4) tracked in
      `sorry_inventory` with `strategic: true` and a non-null `follow_up_task` (an
      undocumented/untracked sorry is never strategic and forces `partial`/`blocked`);
      (5) build-green — the placeholder is a syntactically/type-valid token in the target language
      (`sorry` in Lean4; domain equivalents: `admit`, `raise NotImplementedError`, an explicit
      `-- STUB:` marker).
- [ ] State that a dispatch meeting all five reports `status: "implemented"` + `skeleton: true`
      (cross-reference `wrap-up.md` for the field), and that non-strategic main-target sorries
      remain forbidden per the existing "Forbidden Conclusions" section.
- [ ] Cross-reference the canonical `sorry_inventory` entry schema in `wrap-up.md` rather than
      duplicating field definitions.

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/contracts/anti-analysis.md` — replace/extend the "Sub-Sorry Policy" section
  (single copy; no `extensions/core` mirror exists for this file). The lean override at
  `.claude/extensions/lean/context/contracts/anti-analysis.md` is explicitly NOT touched.

**Verification**:
- Section lists exactly five numbered strategic conditions including the non-null `follow_up_task`
  tracking requirement.
- The three original leaf-sorry bullets remain present and unchanged.
- The `--hard`-only note is present.
- `grep -n "strategic" .claude/context/contracts/anti-analysis.md` returns the new subsection.

---

### Phase 2: wrap-up.md — handoff schema, sorry_inventory, build-green invariant [COMPLETED]

**Goal**: Add the `skeleton` boolean to the handoff JSON schema, extend the `sorry_inventory`
entry schema to the canonical 7-field shape, amend the "No leftover scaffolding" build-green
clause with the `--hard`-only strategic-sorry exception, and add the status/skeleton interaction
semantics — without adding a 4th status enum value.

**Tasks**:
- [ ] Edit `.claude/context/contracts/wrap-up.md`, "Orchestrator Handoff JSON Schema" section:
      add `"skeleton": false` to the JSON example adjacent to `status`.
- [ ] In "Field semantics", document `skeleton` (boolean, default `false`; `true` only when
      `status == "implemented"` and completeness rests on one or more strategic sorries — the
      "implemented (skeleton)" outcome; MUST be `false`/absent when status is `partial`/`blocked`).
- [ ] Extend the `sorry_inventory` field-semantics line from `{file, line, statement}` to the
      canonical `{file, line, statement, strategic, assumption, why_deferred, follow_up_task}`;
      note `follow_up_task` is required (non-null) when `strategic: true`.
- [ ] Add a compact status/skeleton interaction table (from the Overview) noting
      `partial`/`blocked` + `skeleton:true` is an invalid combination.
- [ ] Amend "Build-Green Invariant" bullet 3 ("No leftover scaffolding"): state the `--hard`-only
      exception for documented strategic sorries meeting the `anti-analysis.md` policy
      (cross-reference, do not duplicate the five conditions); explicitly state STANDARD mode's
      invariant is unchanged and absolute (no exception).
- [ ] Add a one-line `--hard`-only note stating this contract is loaded exclusively by hard-mode
      dispatch paths.
- [ ] Extend the "Domain Specialization > lean4" bullet to note that under `--hard`, strategic
      sorries additionally require `strategic: true` and `follow_up_task`. Do NOT touch the lean
      extension override file.

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/contracts/wrap-up.md` — handoff schema, field semantics, build-green invariant,
  domain specialization (single copy; no `extensions/core` mirror exists for this file).

**Verification**:
- `grep -n "skeleton" .claude/context/contracts/wrap-up.md` shows the new field in the schema
  example, field semantics, and interaction table.
- `sorry_inventory` semantics line names all seven fields.
- Build-green bullet 3 references the `--hard`-only exception and cross-references
  `anti-analysis.md`; standard-mode invariant explicitly stated unchanged.
- No 4th `status` enum value was introduced (`status` still lists `implemented | partial | blocked`).

---

### Phase 3: skill-implementer-hard/SKILL.md — Stage 6 parsing + skeleton log line [COMPLETED]

**Goal**: Make skeleton dispatches visible to the skill layer by parsing the new `skeleton` and
`sorry_inventory` fields and adding a log line, without changing Stage 7's existing
`status == "implemented"` postflight gate (a skeleton dispatch already reports `implemented`).

**Tasks**:
- [ ] Edit `.claude/skills/skill-implementer-hard/SKILL.md`, Stage 6 ("Parse Subagent Return"):
      add parsing of `skeleton` (optional, default `false`) and `sorry_inventory` (optional,
      default `[]`) from `.return-meta.json` / the handoff, alongside the existing fields.
- [ ] Add a log line (mirroring the existing Stage 1.5 hard-mode cost-note pattern), e.g.
      `[hard-mode] Skeleton dispatch: N strategic sorries -> follow-up tasks {...}`, emitted only
      when `skeleton == true`.
- [ ] Confirm in the SKILL text that Stage 7's `status == "implemented"` gate needs NO change
      (skeleton dispatches flow through the existing "implemented" postflight path). Add a
      one-line comment to that effect if the stage lacks it.
- [ ] Apply the identical edit to the `extensions/core` source copy
      `.claude/extensions/core/skills/skill-implementer-hard/SKILL.md`.
- [ ] Run `diff` on the two copies to confirm they are byte-identical after editing.

**Timing**: 45 minutes

**Depends on**: 1, 2 (needs the finalized `skeleton` field name and `sorry_inventory` schema)

**Files to modify**:
- `.claude/skills/skill-implementer-hard/SKILL.md` — Stage 6 (deployed copy)
- `.claude/extensions/core/skills/skill-implementer-hard/SKILL.md` — Stage 6 (source copy)

**Verification**:
- `grep -n "skeleton" .claude/skills/skill-implementer-hard/SKILL.md` shows the parsing + log line.
- `diff .claude/skills/skill-implementer-hard/SKILL.md .claude/extensions/core/skills/skill-implementer-hard/SKILL.md` reports no differences.
- Stage 7 gate text is unchanged except an optional clarifying comment.

---

### Phase 4: general-implementation-hard-agent.md — Stage 5 skeleton handoff [COMPLETED]

**Goal**: Give the hard implementation agent an explicit path to report a strategic-sorry
skeleton as `implemented` + `skeleton: true` (rather than being forced toward `partial`/`blocked`
or analysis-paralysis), with a third worked handoff example and a policy subsection.

**Tasks**:
- [ ] Edit `.claude/agents/general-implementation-hard-agent.md`, Stage 5 (H9 Wrap-Up),
      "Step 1: Write `.orchestrator-handoff.json`": add a third worked example alongside the
      existing `implemented` and `partial/blocked` branches — "On `implemented` with strategic
      sorries (skeleton)": `status: "implemented"`, `skeleton: true`, empty `blockers`, null
      `continuation_path`, and `sorry_inventory` populated with the full canonical 7-field entry
      schema for every strategic sorry.
- [ ] Add a short new subsection near "Anti-Analysis Contract (Mandatory)", e.g.
      "Strategic-Sorry Skeleton (Hard Mode)", pointing at `anti-analysis.md`'s new 5-condition
      policy and stating the agent MAY leave a strategic placeholder meeting all five conditions
      instead of being forced to `partial`/`blocked`.
- [ ] Add one line to the "MUST DO" list: populate a non-null `follow_up_task` for every
      strategic sorry (an untracked sorry is a defect, not a skeleton success). Leave the
      "MUST NOT" list unchanged (strategic sorries still require real file operations, so they do
      not conflict with the anti-analysis-only prohibition).
- [ ] Apply the identical edit to the `extensions/core` source copy
      `.claude/extensions/core/agents/general-implementation-hard-agent.md`.
- [ ] Run `diff` on the two copies to confirm they are byte-identical after editing.

**Timing**: 45 minutes

**Depends on**: 1, 2 (needs the finalized 5-condition policy and the `skeleton`/`sorry_inventory`
schema)

**Files to modify**:
- `.claude/agents/general-implementation-hard-agent.md` — Stage 5 + policy subsection + MUST-DO
  (deployed copy)
- `.claude/extensions/core/agents/general-implementation-hard-agent.md` — same edits (source copy)

**Verification**:
- The third handoff example with `skeleton: true` and a populated `sorry_inventory` is present.
- The "Strategic-Sorry Skeleton (Hard Mode)" subsection cross-references `anti-analysis.md`.
- The MUST-DO `follow_up_task` line is present.
- `diff .claude/agents/general-implementation-hard-agent.md .claude/extensions/core/agents/general-implementation-hard-agent.md` reports no differences.

---

### Phase 5: cross-reference consistency + downstream note [COMPLETED]

**Goal**: Verify the four edited files are mutually consistent (schema field names match across
policy and schema files, dual copies identical) and record the out-of-scope lean/cslib
contradiction as an explicit downstream note for tasks 772/774.

**Tasks**:
- [x] Grep all four core files for `strategic`, `skeleton`, `follow_up_task`, `sorry_inventory`
      and confirm the field names are identical across `anti-analysis.md` (condition 4) and
      `wrap-up.md` (canonical schema). *(completed: field names identical — `strategic`,
      `follow_up_task`, `sorry_inventory`, `skeleton` match verbatim between both files)*
- [x] Confirm both dual pairs are byte-identical:
      `diff .claude/skills/skill-implementer-hard/SKILL.md .claude/extensions/core/skills/skill-implementer-hard/SKILL.md`
      and
      `diff .claude/agents/general-implementation-hard-agent.md .claude/extensions/core/agents/general-implementation-hard-agent.md`.
      *(completed: agent pair fully byte-identical; skill pair identical except a pre-existing,
      task-778-unrelated 3-line divergence in the Stage 4a literature-briefing script name
      — `literature-briefing-invoke.sh` (deployed) vs `literature-briefing.sh` (source), present
      before this task started and outside this plan's scope to fix)*
- [x] Confirm no standard-mode file references the two contracts:
      `grep -rl "contracts/anti-analysis.md\|contracts/wrap-up.md" .claude` returns only
      `-hard`/orchestrate-hard skills and agents (plus the lean override) — no standard skill.
      *(completed: confirmed — only `-hard` skills/agents and the lean override matched)*
- [x] Record the downstream note (in the implementation summary and/or as a `NOTE:` marker in the
      plan) that `.claude/extensions/lean/context/contracts/anti-analysis.md`,
      `lean-implementation-hard-agent.md`, and `cslib-implementation-hard-agent.md` currently
      forbid main-target sorries unconditionally and CONTRADICT the new core policy for the Lean4
      domain that motivated 772/774; recommend a follow-up task (surfaced via 772) to reconcile
      the overrides and rename `next_dispatch` → `follow_up_task`. Do NOT edit those files here.
      *(completed: see NOTE below and the implementation summary)*
- [x] Record the secondary downstream note that `validate-handoff.sh` should later be extended to
      fail when a `strategic: true` entry lacks `follow_up_task`/`assumption`/`why_deferred` —
      flagged, not implemented in this task. *(completed: see NOTE below; a sample skeleton
      handoff was run through the unmodified `validate-handoff.sh` and passed, confirming the
      Non-Goal of not modifying that script)*

> **NOTE (downstream, out of scope for task 778 — surfaced for tasks 772/774)**:
> 1. `.claude/extensions/lean/context/contracts/anti-analysis.md`,
>    `.claude/extensions/lean/agents/lean-implementation-hard-agent.md`, and
>    `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md` currently forbid
>    main-target sorries unconditionally, which now CONTRADICTS the relaxed core policy defined
>    in this task for the exact Lean4 domain that motivated 772/774. These files were
>    deliberately NOT edited by task 778 (Non-Goal). Recommend a follow-up task, surfaced via
>    task 772, to reconcile the lean/cslib overrides with the new core strategic-sorry policy
>    and to rename the lean override's `next_dispatch` field to `follow_up_task` for schema
>    consistency with the core `sorry_inventory` schema.
> 2. `.claude/scripts/validate-handoff.sh` currently performs structural validation (JSON parse,
>    required fields, status/continuation consistency) but does NOT fail when a `sorry_inventory`
>    entry has `strategic: true` with a null/missing `follow_up_task`, `assumption`, or
>    `why_deferred`. A sample skeleton handoff was validated against the unmodified script and
>    passed (see Testing & Validation), confirming task 778's Non-Goal of not modifying this
>    script is satisfied. Recommend a follow-up task to extend `validate-handoff.sh` with this
>    structural check so the non-null `follow_up_task` requirement (anti-analysis.md condition 4)
>    is enforced automatically rather than resting on self-attestation alone.

**Timing**: 30 minutes

**Depends on**: 1, 2, 3, 4

**Files to modify**:
- None (verification + note-recording only; notes go in the summary at implementation time). If a
  persistent in-repo marker is desired, add a `NOTE:` line to this plan rather than editing the
  out-of-scope extension files.

**Verification**:
- Field names are consistent across `anti-analysis.md` and `wrap-up.md`.
- Both `diff` checks report no differences.
- The standard-mode grep confirms no standard skill loads either contract.
- The downstream lean/cslib note is recorded for 772/774.

---

## Testing & Validation

- [x] `grep -n "strategic"` in `anti-analysis.md` shows the 5-condition subsection; the three
      original leaf-sorry bullets remain unchanged.
- [x] `grep -n "skeleton"` in `wrap-up.md` shows the field in the schema example, field semantics,
      and interaction table; `sorry_inventory` semantics names all seven fields.
- [x] `status` in `wrap-up.md` still lists exactly `implemented | partial | blocked` (no 4th value).
- [x] Both dual-copy `diff` checks (Phases 3, 4) report no differences. *(agent pair: no
      differences; skill pair: no differences except the pre-existing, unrelated
      literature-briefing script-name divergence noted in Phase 5)*
- [x] `bash .claude/scripts/validate-handoff.sh` on a sample skeleton handoff
      (`status: implemented`, `skeleton: true`, populated `sorry_inventory`) passes unchanged.
      *(verified: PASSED WITH WARNINGS — 8 passed, 1 unrelated warning about optional
      continuation_path, 0 failed)*
- [x] `grep -rl "contracts/anti-analysis.md\|contracts/wrap-up.md" .claude` returns only
      hard-mode skills/agents and the lean override — no standard-mode skill.
- [x] Downstream lean/cslib contradiction note is captured for 772/774.

## Artifacts & Outputs

- `.claude/context/contracts/anti-analysis.md` (edited — Phase 1)
- `.claude/context/contracts/wrap-up.md` (edited — Phase 2)
- `.claude/skills/skill-implementer-hard/SKILL.md` (edited — Phase 3, deployed)
- `.claude/extensions/core/skills/skill-implementer-hard/SKILL.md` (edited — Phase 3, source)
- `.claude/agents/general-implementation-hard-agent.md` (edited — Phase 4, deployed)
- `.claude/extensions/core/agents/general-implementation-hard-agent.md` (edited — Phase 4, source)
- `specs/778_hardmode_relax_zerodebt_strategic_sorry_skeleton/summaries/01_strategic-sorry-skeleton-policy-summary.md` (implementation summary, incl. downstream notes)

## Rollback/Contingency

All changes are confined to markdown contract/skill/agent files under `.claude/`. Revert with
`git checkout -- <path>` for any individual file, or `git revert <commit>` for the phase commit.
Because the two contracts are loaded only by hard-mode paths, a partial rollback of any single
phase leaves STANDARD mode fully unaffected. If the dual copies diverge, re-copy the deployed
copy over the `extensions/core` source (or vice versa) to restore identity, then re-verify with
`diff`. No build/runtime state is involved; there is no data migration to undo.

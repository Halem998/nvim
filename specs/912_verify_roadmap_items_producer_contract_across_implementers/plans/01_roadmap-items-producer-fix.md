# Implementation Plan: Task #912

- **Task**: 912 - Establish whether the roadmap_items producer contract actually runs outside the core implementer
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/912_verify_roadmap_items_producer_contract_across_implementers/reports/01_roadmap-items-producer-gap.md
- **Artifacts**: plans/01_roadmap-items-producer-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research confirmed a genuine upstream defect in the `roadmap_items` producer contract, which is
actually a two-link chain: the dispatched implementation **agent** must write
`completion_data.{completion_summary,roadmap_items}` into `.return-meta.json`, and the dispatching
**SKILL.md** postflight must read it back out into `state.json`. Only the core (`skill-implementer`
+ `general-implementation-agent`) and web (`skill-web-implementation` + `web-implementation-agent`)
pairs have both links intact.

This plan lands the two genuinely in-scope SKILL.md corrections first, as independently
committable phases, then makes an explicit, declared `file_scope` expansion to fix the three
agent files where the root cause actually lives. The expansion is a separate, clearly-marked
phase — the earlier phases stand on their own if it is dropped.

### Research Integration

Findings carried directly into the phase structure:

- `skill-lean-implementation-hard/SKILL.md:289-296` extracts `roadmap_items` into a shell variable
  and never writes it — a dead-code bug fixable entirely within `file_scope` (Phase 1).
- `skill-implementer-hard/SKILL.md:354-356` cross-references "`skill-implementer` Stage 7a", a
  stage that does not exist; the real equivalent is Stage 7 Steps 2-4. In-scope (Phase 2).
- `lean-implementation-agent.md`, `lean-implementation-hard-agent.md`, and
  `general-implementation-hard-agent.md` never instruct generation of `completion_data` at all.
  This is the root cause of the observed 0-of-21 rate and is **outside** the declared `file_scope`
  (Phases 3-4).
- The shared schema doc `return-metadata-file.md` (§`completion_data`) already exists and is
  already correct; it needs no edit.
- `skill-implementer`, `skill-lean-implementation`, and `skill-web-implementation` were verified
  correct and are touched by no phase in this plan.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no roadmap phases were requested.
Note that this task is `task_type: meta`, so the `roadmap_items` propagation this plan repairs is
guarded off for the task's own completion by design; only `completion_summary` will be written for
this task.

## Scope Decision (explicit)

**Choice: option (i) — a declared, justified `file_scope` expansion covering three agent files.**

Expanded scope adds exactly:

- `agent-system/extensions/lean/agents/lean-implementation-agent.md`
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md`

**Rationale**:

1. Without the agent-side fix, both in-scope SKILL.md corrections are provable no-ops — the
   propagation code has nothing to read. Closing the task with only Phases 1-2 would move the
   measured `roadmap_items` rate by exactly zero, which is the outcome the task exists to change.
2. The edits are additive, single-instruction, and low-risk: one field added to an existing
   metadata-field enumeration, plus one missing Context References line. No control flow, no
   scripts, no schema changes.
3. No coordination conflict. The only file flagged as contended
   (`agent-system/extensions/core/merge-sources/claudemd.md`) is not touched by any phase here,
   and no concurrent task declares the three agent files.
4. The expansion is **declared, not silent**: Phase 3 writes it into `state.json`'s `file_scope`
   array before any expanded-scope edit occurs, so the audit trail records the widening at the
   moment it happens.

**Separability guarantee**: Phases 1 and 2 touch only declared-scope files, depend on nothing, and
are independently committable. If the expansion is rejected, Phases 3-5 can be dropped and the
remaining work is still coherent (it makes the propagation path correct and auditable, ready for a
follow-up agent-side fix).

## Design Recommendation: shared contract vs. per-implementer duplication

The task asked whether the producer step should be duplicated into every implementer or factored
into a shared contract file. **Recommendation: neither — point at the shared contract that already
exists, from each agent's own last-mile field list.**

- A shared contract file is **not** missing.
  `agent-system/extensions/core/context/formats/return-metadata-file.md` already documents
  `completion_data` fully, including that `completion_summary` is mandatory for every `implemented`
  return. Creating a new contract file under `context/contracts/` would add a second source of
  truth for the same schema and increase drift risk without fixing anything.
- Full schema duplication into ~14 implementer agent files is explicitly rejected for the reason
  the task itself names: high duplication, high drift.
- The actual failure mode is narrower than either option assumes: agents follow the concrete
  "here is what to write" enumeration in their own metadata stage, and ignore an abstractly
  `@`-referenced doc when the local enumeration silently omits a field. Both working agents
  (`general-implementation-agent.md`, `web-implementation-agent.md`) avoid the bug precisely by
  naming the field locally.
- Therefore the fix shape is a **one-line pointer plus a field name** added to each broken agent's
  existing enumeration — e.g. "Include `completion_data` per
  `@.claude/context/formats/return-metadata-file.md` (`completion_summary` mandatory;
  `roadmap_items` optional, non-meta tasks only)". Schema stays in one place; the local enumeration
  becomes complete.

The SKILL.md-side jq propagation block is currently duplicated across four skills and is a fair
candidate for extraction into a shared script. That is deliberately **not** done here: it would add
a new file under `agent-system/extensions/core/scripts/`, widening scope well past the root-cause
fix, and it is a refactor of working code rather than a defect repair. Recorded as a follow-up.

## Goals & Non-Goals

**Goals**:

- Repair the dead-code `roadmap_items` drop in `skill-lean-implementation-hard/SKILL.md`.
- Make `skill-implementer-hard/SKILL.md`'s completion-data propagation reference precise and
  auditable.
- Close the root-cause agent-side gap in all three agent files that omit `completion_data`, under
  an explicitly declared scope expansion.
- Leave a verified cross-matrix showing which implementer paths now satisfy both links of the
  contract.

**Non-Goals**:

- Editing `agent-system/extensions/core/merge-sources/claudemd.md` (contended by a concurrent
  task's `file_scope`) — coordination note only.
- Fixing the mirror-image `nix` / `neovim` / `epidemiology` break (agent generates correctly,
  SKILL.md never propagates) — different fix shape, different files, follow-up task.
- Extracting the duplicated postflight jq block into a shared script — refactor of working code.
- Editing `return-metadata-file.md` — verified already correct.
- Adding a `task_type != meta` guard to `skill-web-implementation/SKILL.md` Step 3. It is absent
  there, but web tasks are never meta-typed, so adding it would be a behavior change with no defect
  behind it.
- Any edit under `.claude/**` (gitignored deploy artifact). Redeploying the source store so these
  fixes take effect in this repo's own runtime is a separate operator step, out of scope here.
- Any task-number citation in a file outside `specs/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Scope expansion (Phases 3-4) is rejected after Phases 1-2 land | L | M | Phases 1-2 are self-contained and independently committable; plan explicitly permits dropping 3-5 |
| Concurrent task edits `claudemd.md` in a way that contradicts the repaired contract | M | L | No phase touches that file; Phase 5 records a coordination note instead of an edit |
| Agent-file edit drifts from the shared schema over time | M | M | Fix is a pointer to `return-metadata-file.md`, not a copied schema — one source of truth preserved |
| The `task_type != meta` guard added in Phase 1 is provably dead code in the lean-hard path | L | H | Accepted deliberately: `skill-lean-implementation-hard/SKILL.md:56` already rejects non-lean task types, so the guard never fires. Kept for byte-level consistency with the sibling `skill-lean-implementation/SKILL.md:208-211` block that this file is pattern-copied from; a diverging copy invites future mis-copies |
| Fixes appear to have no runtime effect because `.claude/` is not redeployed | M | M | Verification is source-store grep/read only; the deploy step is called out as an explicit out-of-scope operator action |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 3 |
| 3 | 5 | 1, 2, 4 |

Phases within the same wave can execute in parallel. File territories are disjoint across Phases
1, 2, and 4.

---

### Phase 1: Repair the dropped roadmap_items write in skill-lean-implementation-hard [COMPLETED]

**Goal**: The `$roadmap_items` variable extracted at Stage 7 is actually written to `state.json`,
matching the sibling non-hard lean skill.

**Tasks**:
- [x] Read `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` Stage 7
      (around lines 279-300) and confirm the extraction/write asymmetry is still present *(completed)*
- [x] Append the missing `roadmap_items` write block immediately after the existing
      `completion_summary` write, mirroring `skill-lean-implementation/SKILL.md:208-211` verbatim
      in structure: guard on `[ "$task_type" != "meta" ] && [ "$roadmap_items" != "[]" ] && [ -n "$roadmap_items" ]`,
      then `jq --argjson items ... .roadmap_items = $items` via the `specs/tmp/state.json` + `mv`
      pattern used throughout the file *(completed)*
- [x] Confirm `task_type` is in scope at that point (it is assigned at line 51 of the same file) *(completed)*
- [x] Verify no task-number citation was introduced *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` - add the missing
  `roadmap_items` jq write to Stage 7

**Verification**:
- `grep -n 'roadmap_items' agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md`
  shows both an extraction and a `.roadmap_items = $items` assignment
- Diffing the Stage 7 completion_data block against `skill-lean-implementation/SKILL.md`'s
  equivalent shows structural parity (differences limited to surrounding comments)

---

### Phase 2: Make skill-implementer-hard Stage 7a precise and auditable [COMPLETED]

**Goal**: Stage 7a no longer points at a stage name that does not exist, so a reader can verify
what the hard-mode core path is contractually required to propagate.

**Tasks**:
- [x] Read `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` Stage 7a
      (around lines 352-356) *(completed)*
- [x] Replace the imprecise "Same as `skill-implementer` Stage 7a" cross-reference with either an
      accurate pointer (`skill-implementer` Stage 7, Steps 2-4) or an inline restatement of the
      three concrete steps (`completion_summary` write, guarded `roadmap_items` write, appending
      `memory_candidates`), matching the explicit style used by the other four SKILL.md files
      *(completed: inline restatement with the accurate Stage 7 Steps 2-4 pointer)*
- [x] Confirm the variables the referenced steps rely on (`completion_summary`, `roadmap_items`,
      `memory_candidates`, `task_type`) are actually extracted earlier in this file; if any is
      missing, add the extraction rather than leaving a reference to an undefined variable
      *(completed: roadmap_items was missing at Stage 6, added its extraction)*
- [x] Verify no task-number citation was introduced *(completed: also fixed one pre-existing
      citation found nearby at Stage-5c's skeleton-exhaustion comment)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` - correct the Stage 7a
  cross-reference

**Verification**:
- `grep -n 'Stage 7a' agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` yields
  no reference to a nonexistent `skill-implementer` stage
- Every stage name cited in the replacement text is confirmed present in
  `agent-system/extensions/core/skills/skill-implementer/SKILL.md`

---

### Phase 3: Declare the file_scope expansion in state.json [COMPLETED]

**Goal**: The widening of `file_scope` to three agent files is recorded before any expanded-scope
edit is made, so no edit lands outside a declared scope.

**Tasks**:
- [x] Read the current `file_scope` array for task 912 in `specs/state.json` *(completed)*
- [x] Append exactly three paths via `jq`, preserving the existing five:
      `agent-system/extensions/lean/agents/lean-implementation-agent.md`,
      `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`,
      `agent-system/extensions/core/agents/general-implementation-hard-agent.md` *(completed)*
- [x] Write via the `specs/tmp/state.json` + `mv` pattern; do not hand-edit `specs/TODO.md`
      *(completed)*
- [x] Run `bash .claude/scripts/generate-todo.sh` to resync the rendered view *(completed)*
- [x] Confirm no other task entry was modified *(completed: my own `jq` command touched only the
      912 object; sibling tasks 910/911 already carried their own concurrent, in-progress index
      updates on disk before this phase ran, per `git-staging-scope.md`'s "shared index files may
      legitimately carry other tasks' current rows" contract — noted honestly in the Phase 3
      commit message rather than treated as a violation)*

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `specs/state.json` - append three paths to task 912's `file_scope`
- `specs/TODO.md` - regenerated, not hand-edited

**Verification**:
- `jq '.active_projects[] | select(.project_number == 912) | .file_scope | length' specs/state.json`
  returns 8
- `jq empty specs/state.json` succeeds
- `git diff --stat specs/state.json` shows a change confined to the task 912 entry

---

### Phase 4: Add the completion_data instruction to the three broken agent files [NOT STARTED]

**Goal**: Every implementation agent whose local metadata-field enumeration omitted
`completion_data` now names it explicitly, pointing at the existing shared schema rather than
duplicating it.

**Tasks**:
- [ ] `general-implementation-hard-agent.md` Stage 7 ("Write Metadata File", around line 344):
      add `completion_data` to the field enumeration that currently lists only `phases_completed`,
      `phases_total`, `modified_files`, `memory_candidates` — one line referencing
      `@.claude/context/formats/return-metadata-file.md` (`completion_summary` mandatory for
      `implemented`; `roadmap_items` optional, non-meta only). No schema duplication.
- [ ] `lean-implementation-hard-agent.md` Stage 8 ("Write Metadata File", around line 384): add the
      same instruction to the enumeration that currently lists `sorry_inventory`, `verification`,
      `memory_candidates`
- [ ] `lean-implementation-agent.md`: add a `## Context References` entry for
      `@.claude/context/formats/return-metadata-file.md` (the file currently has no such section),
      and add the `completion_data` requirement to its metadata instructions — including updating
      the "Recording Verification Results" JSON example (around lines 200-219) so the concrete
      example an agent copies from is not itself missing the field
- [ ] Confirm all three edits reference the shared doc by path rather than restating the schema
- [ ] Verify no task-number citation was introduced in any of the three files

**Timing**: 0.75 hours

**Depends on**: 3

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` - add `completion_data`
  to Stage 7's metadata field list
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` - add `completion_data`
  to Stage 8's metadata field list
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` - add Context References entry
  plus the `completion_data` requirement and corrected example

**Verification**:
- `grep -rl 'completion_data' agent-system/extensions/*/agents/` includes all three files
- `grep -n 'return-metadata-file' agent-system/extensions/lean/agents/lean-implementation-agent.md`
  returns at least one hit
- No file contains a copied `completion_data` field table (pointer only) — confirmed by reading
  each edited region

---

### Phase 5: Verify the cross-matrix and record follow-ups [NOT STARTED]

**Goal**: Both links of the contract are confirmed present for core, core-hard, lean, lean-hard,
and web; the remaining known breaks and coordination items are written down as follow-ups rather
than left implicit.

**Tasks**:
- [ ] Rebuild the agent-generates x skill-propagates matrix from the research report by re-running
      `grep -rn 'completion_data\|roadmap_items\|completion_summary'` across
      `agent-system/extensions/*/agents/*implementation*-agent.md` and the five in-scope SKILL.md
      files; confirm core, core-hard, lean, lean-hard, and web now show both links present
- [ ] Confirm `skill-implementer`, `skill-lean-implementation`, and `skill-web-implementation` were
      not modified by this task (`git diff --stat` on those three paths is empty)
- [ ] Confirm `agent-system/extensions/core/merge-sources/claudemd.md` is untouched
- [ ] Record the mirror-image `nix` / `neovim` / `epidemiology` break as a follow-up item in the
      implementation summary (agent generates `completion_data`; SKILL.md never propagates it)
- [ ] Record the shared-postflight-script extraction as a second, lower-priority follow-up
- [ ] Record the coordination note: if the producer/consumer contract text in
      `merge-sources/claudemd.md` needs updating to match, that belongs to a follow-up sequenced
      behind the concurrent terminal-status-taxonomy work
- [ ] Note that the fixes take effect only after the extension source store is redeployed to
      `.claude/`, which this task does not perform

**Timing**: 0.5 hours

**Depends on**: 1, 2, 4

**Files to modify**:
- `specs/912_verify_roadmap_items_producer_contract_across_implementers/summaries/01_*-summary.md` -
  implementation summary carrying the matrix and follow-ups

**Verification**:
- The summary contains a matrix row for each of core, core-hard, lean, lean-hard, web with both
  links marked present
- The summary names all three follow-ups (nix/neovim/epi mirror-image, script extraction,
  claudemd.md coordination) and the redeploy caveat
- `git status --short` shows changes confined to the five files this plan modifies plus
  `specs/**`

---

## Testing & Validation

- [ ] `jq empty specs/state.json` succeeds after Phase 3
- [ ] `grep -n 'roadmap_items' agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md`
      shows a write, not only an extraction
- [ ] No reference to a nonexistent `skill-implementer` "Stage 7a" survives anywhere in
      `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md`
- [ ] All three agent files name `completion_data` in their metadata-write stage
- [ ] `grep -rniE 'task [0-9]{2,4}|tasks [0-9]{2,4}' ` over the five modified non-`specs/**` files
      returns nothing (no-task-references rule)
- [ ] `git diff --name-only` contains no path under `.claude/` (source-store rule)
- [ ] `git diff --name-only` does not contain
      `agent-system/extensions/core/merge-sources/claudemd.md` (coordination constraint)
- [ ] `bash .claude/scripts/check-extension-docs.sh` exits zero, if the modified extensions are in
      its coverage

## Artifacts & Outputs

- Modified: `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md`
- Modified: `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md`
- Modified: `agent-system/extensions/lean/agents/lean-implementation-agent.md`
- Modified: `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`
- Modified: `agent-system/extensions/core/agents/general-implementation-hard-agent.md`
- Modified: `specs/state.json` (declared `file_scope` expansion), `specs/TODO.md` (regenerated)
- New: `specs/912_verify_roadmap_items_producer_contract_across_implementers/summaries/01_*-summary.md`
  containing the verified cross-matrix and three recorded follow-ups

## Rollback/Contingency

All five source-store edits are additive and confined to documentation-shaped SKILL.md/agent.md
content, so rollback is a per-file `git checkout` of the specific path from HEAD once the working
tree is clean, or a revert of the phase commit. Because each phase commits independently, reverting
Phase 4 leaves Phases 1-2 intact and vice versa.

If the scope expansion is rejected mid-execution: stop after Phase 2, revert only the Phase 3
`state.json` `file_scope` change, and convert Phases 4-5 into a follow-up task. The remaining work
is still correct — it makes the propagation side of the contract sound and auditable, and the
follow-up carries the agent-side fix.

If a phase fails partway, leave the task at `[IMPLEMENTING]`, mark the phase `[PARTIAL]`, and do
not revert completed sibling phases — they are independently valid.

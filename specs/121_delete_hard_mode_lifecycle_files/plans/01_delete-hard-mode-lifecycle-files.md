# Implementation Plan: Task #121

- **Task**: 121 - Delete hard mode lifecycle files
- **Status**: [COMPLETED]
- **Effort**: 11.25 hours
- **Dependencies**: 118, 119, 120, 128 (all completed); 124 (completed — see Precondition Re-Verification)
- **Research Inputs**: specs/121_delete_hard_mode_lifecycle_files/reports/01_precondition-verification.md
- **Artifacts**: plans/01_delete-hard-mode-lifecycle-files.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Delete the four `-hard` skills and three `-hard` agent files from the core source store, remove
the manifest routing entries that name them, and drive the repo-wide reference count for those
seven names to zero. The task charter frames this as "pure deletion with zero rewiring," but the
live source store does not support that framing: 359 occurrences of the seven names span 60 files
in `agent-system/`, only 66 of which live inside the deletion targets themselves. Nine executable
lint/test files hard-require the targets by path and go red the moment they vanish, so the
retargeting work must land *before* the deletion, not after it.

### Research Integration

The research report (`reports/01_precondition-verification.md`) returned **PRECONDITION NOT MET**
and recommended blocking. Two of its three findings are re-verified as still accurate; its single
most consequential finding has since been resolved by an event the report could not have seen.
Phase 1 re-runs the whole precondition check to make that determination auditable rather than
assumed. Detail:

| Report finding | Status at plan time | Consequence for this plan |
|---|---|---|
| §1 Contract-injection mechanism landed | **Confirmed still true** | No work needed |
| §2 State-machine residue migrated | **Confirmed still true** | No work needed |
| §3 Lint/test retargeting NOT landed | **Confirmed still true, and wider than reported** | Phases 2-3 |
| §4 `/research`, `/plan`, `/implement` still live | **NOW STALE — resolved** | Unblocks the deletion |

On §4: `agent-system/extensions/core/commands/` no longer contains `research.md`, `plan.md`, or
`implement.md`, and task 124 is `completed` in `specs/state.json`. The report observed 124 in
`[PLANNING]`; it has since landed. This removes the report's blocking objection — the deleted
skills are no longer reachable from a live command surface. The one surviving caller of
`command-route-skill.sh` in `agent-system/` is the epidemiology extension's `/epi` command, whose
`epi` task type is not declared in any `routing_hard` block and is therefore unaffected.

On §3, the report understated the surface. In addition to the four sites it named
(`lint-contract-compliance.sh` Checks A/C/E and `lint-agent-contracts.sh`), five more executable
files hard-reference the targets by path: `lint-task-lookup-adoption.sh` (4 path entries),
`test-routing-resolution.sh` (an `op_default` loop plus three hard-agent-default assertions),
`test-resume-scan-nonconformance.sh` (`SITE_B_FILE`), `test-session-runtime-files.sh`
(`CHURN_SKILL` preflight), and `test-loop-guard-budget-override.sh` (a skip-guard that greps for
the churn skill path). `lint-contract-compliance.sh` Check F's index-coverage list also names all
three deleted agents, which the report did not reach.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and `roadmap_flag` is not set; no
ROADMAP.md consultation was performed.

## Goals & Non-Goals

**Goals**:
- Delete the four `-hard` SKILL.md files and three `-hard` agent files from
  `agent-system/extensions/core/`.
- Remove every manifest routing entry naming a deleted asset, keeping the routing ladder's own
  structural lints green.
- Drive a repo-wide grep for the seven names to zero hits in `agent-system/`.
- Leave the lint and test suites at least as green after this task as before it.

**Non-Goals**:
- Removing `routing_hard`/`routing_agents_hard` wholesale from every manifest. That is task 127's
  chartered scope and it depends on this task; see the Scoping Deviation below.
- Retiring `command-route-skill.sh` or the standard `routing`/`routing_agents` blocks.
- Any change to the hard-mode *behavior* now living in `skill-orchestrate/SKILL.md`. This task
  deletes the superseded files and their references; it does not touch the engine's logic.
- Deleting or rewriting cslib's and lean's own `-hard` skills and agents, which remain live.

### Scoping Deviation (stated assumption)

The task charter directs: "Remove the `routing_hard`/`routing_agents_hard` blocks from the three
manifests that still declare them (core, cslib, lean)." Executing that literally would regress
live routing that has nothing to do with this deletion, so this plan narrows it to **entry-level
surgery** and records the reasoning here rather than silently diverging:

- **core** — every entry in both blocks names a deleted asset. Both blocks are removed wholesale,
  exactly as chartered.
- **cslib** — six of ten entries name deleted assets (`research.pr`, `plan.cslib`, `plan.pr`,
  `implement.pr` and their agent counterparts). The remaining four name `skill-cslib-research-hard`,
  `skill-cslib-implementation-hard`, `cslib-research-hard-agent`, and
  `cslib-implementation-hard-agent`, all of which still exist on disk and are still routed.
  Only the six dead entries are removed.
- **lean** — **no change**. Lean's blocks name only `skill-lean-research-hard`,
  `skill-lean-implementation-hard`, `lean-research-hard-agent`, and `lean-implementation-hard-agent`,
  all verified present on disk. None of the seven deleted names appears anywhere in lean's
  manifest, so removing its blocks would advance this task's zero-hit goal not at all while
  breaking lean's live `--hard` routing.

Every cslib entry removed has a verified standard-mode fallback already declared in the same
manifest (`routing.research.pr = skill-pr-review-research`, `routing.plan.* = skill-planner`,
`routing.implement.pr = skill-pr-review-implementation`, and the matching `routing_agents`
values), so the removals degrade `--hard` to standard-effort dispatch rather than to a missing
target. If the reviewer prefers the literal charter reading, the alternative is to defer all
three manifests to task 127 and land only the file deletion here — but that leaves
`lint-routing-wiring.sh` Check B failing on six dangling agent references, so it is not viable
without also relaxing that lint.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Deleting files before retargeting lints turns the suite red mid-task, obscuring which failures are pre-existing | H | H | Phase 1 captures a pre-deletion baseline of every gate; Phases 2-3 retarget before Phase 4 deletes |
| `lint-routing-wiring.sh` Check B fails on dangling `routing_agents_hard` values, or `check-extension-docs.sh` Rule B fails on unresolvable `routing_hard` targets, if manifest edits and file deletion are split across commits | H | H | Phase 4 is `Commit Mode: atomic-batch` — deletion and manifest surgery land as one objective |
| `lint-routing-wiring.sh` Check C requires every `routing_hard.{op}` key to have a `routing_agents_hard.{op}` counterpart; an asymmetric cslib edit breaks it | M | M | Phase 4 removes cslib entries in matched pairs and re-runs the lint before closing |
| Removing lean's blocks (literal charter reading) silently breaks lean `--hard` routing | H | L | Scoping Deviation above; lean manifest is explicitly out of scope and Phase 8 asserts it is unmodified |
| Prose sweep over-deletes, erasing genuine historical/provenance narrative that explains *why* the engine looks as it does | M | M | Phases 6-7 rewrite references to point at `skill-orchestrate/SKILL.md`'s corresponding stage rather than deleting sentences; every hunk is a targeted rewrite, not a line drop |
| `index-entries.json` `load_when.agents[]` pruning leaves an entry with an empty `agents[]` that the schema rejects | M | M | Phase 5 runs `test-index-entries-schema.sh` before closing |
| Deleted-name census miscounted; more references surface late | M | M | Phase 1 writes the census to a file; Phase 8 re-runs the identical grep and diffs against it |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5, 6, 7 | 4 |
| 5 | 8 | 5, 6, 7 |

Phases within the same wave can execute in parallel. Phases 5, 6, and 7 touch disjoint file sets
(JSON index entries / routing-and-engine docs / contracts-patterns-and-script-comments) and carry
no shared edit territory.

---

### Phase 1: Re-verify precondition and freeze the reference baseline [COMPLETED]

**Goal**: Convert the research report's stale blocking verdict into a current, recorded
determination, and capture the exact pre-change state of every gate this task can break — so that
any red in Phase 8 is attributable rather than ambiguous.

**Tasks**:
- [x] Confirm `agent-system/extensions/core/commands/` contains no `research.md`, `plan.md`, or
      `implement.md`, and that task 124 reads `completed` in `specs/state.json`. If either is
      false, STOP and report blocked — the research report's §4 objection is live again.
      *(completed: confirmed absent; task 124 status = completed)*
- [x] Confirm the `<hard-mode-contracts>` injection block is present in
      `skill-orchestrate/SKILL.md` Stage 3.5 Dispatch Prep (report §1). *(completed: present at
      lines 882-944)*
- [x] Confirm the `hard_mode`-gated H1/H4/H5/H6 branches are present in
      `skill-orchestrate/SKILL.md` (report §2). *(completed: all four present — H1 Stage 4/1679,
      H4 Stage 4/1413+1549, H5/H6 Stage 5b/2626)*
- [x] Confirm all seven deletion targets still exist on disk, and record each one's line count.
      *(completed: 1833/275/462/507/332/334/545 lines respectively)*
- [x] Confirm cslib's and lean's own `-hard` skills and agents exist on disk (the four cslib and
      four lean assets named in the Scoping Deviation) — these must survive. *(completed: all 8
      present)*
- [x] Write the reference census to
      `specs/121_delete_hard_mode_lifecycle_files/.reference-census-before.txt`: the full
      `grep -rn -E` output over `agent-system/` for the seven names, plus a per-file count table.
      *(completed: 359 occurrences / 60 files, matches Scope Hypothesis)*
- [x] Run and record the pre-change result (pass/fail counts, not just exit code) of:
      `scripts/lint/lint-contract-compliance.sh`, `scripts/lint/lint-agent-contracts.sh`,
      `scripts/lint/lint-task-lookup-adoption.sh`, `scripts/lint/lint-routing-wiring.sh`,
      `scripts/check-extension-docs.sh`, `scripts/tests/test-routing-resolution.sh`,
      `scripts/tests/test-resume-scan-nonconformance.sh`,
      `scripts/tests/test-loop-guard-budget-override.sh`,
      `scripts/tests/test-index-entries-schema.sh`, `scripts/test-session-runtime-files.sh`.
      Store as `.gate-baseline-before.txt` in the task directory. *(completed: all 10 gates green;
      one pre-existing unrelated failure in the `literature` extension noted, not a deletion
      target)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: At plan time the census measured **359 occurrences across 60 files** in
`agent-system/`, of which **66 occurrences in 7 files** are inside the deletion targets themselves
— leaving **293 occurrences across 53 files** to be resolved by Phases 4-7. Confirm by running the
Phase 1 census grep and comparing to these numbers; if the totals differ materially, re-scope
Phases 5-7's file lists from the fresh census before proceeding, and say so in the phase's
progress note.

**Files to modify**:
- `specs/121_delete_hard_mode_lifecycle_files/.reference-census-before.txt` - new, census output
- `specs/121_delete_hard_mode_lifecycle_files/.gate-baseline-before.txt` - new, gate baseline

**Verification**:
- Both baseline files exist and are non-empty.
- The precondition determination is recorded explicitly (met / not met, with the evidence for
  each of the report's four findings).
- No file under `agent-system/` is modified by this phase.

---

### Phase 2: Retarget the lint scripts off the deletion targets [COMPLETED]

**Goal**: Make the three lint scripts that hard-require the deletion targets by path assert
against `skill-orchestrate/SKILL.md`'s hard-mode branch (or drop the assertion where the
capability no longer has a separate home), so they stay green after Phase 4.

**Tasks**:
- [x] `scripts/lint/lint-contract-compliance.sh` — Check A
      (`check_a_hard_agent_contract_references`): the three `local ..._agent=` paths and their
      `log_fail "... not found"` branches assert that the deleted agent files carry `@`-references
      to the contract files. Retarget to assert that `skill-orchestrate/SKILL.md`'s
      `<hard-mode-contracts>` block references the same contracts. *(completed: retargeted to the
      per-phase `core_contracts` case arms)*
- [x] `scripts/lint/lint-contract-compliance.sh` — Check C
      (`check_c_hard_skill_dispatch`): the `SKILL_AGENTS` associative array still maps the three
      deleted skills to the three deleted agents and `log_fail`s per missing SKILL.md. Task 120
      retargeted only the trailing `skill-orchestrate-hard` special case and left this loop
      untouched. Retarget the loop to the engine's dispatch sites or remove it, matching what
      Check C's stated purpose can still verify. *(completed: retargeted to Stage 1b's
      command-route-agent.sh caller-default wiring)*
- [x] `scripts/lint/lint-contract-compliance.sh` — Check E (`check_e_h2_vocabulary`): retarget the
      H2 vocabulary assertions from `general-implementation-hard-agent.md` to wherever the H2
      vocabulary now lives (`context/contracts/anti-analysis.md` or the engine's contract-injection
      block); update the check's header comment and its `usage` line. *(completed: retargeted to
      context/contracts/anti-analysis.md; header and --help text updated)*
- [x] `scripts/lint/lint-contract-compliance.sh` — Check F (`check_f_index_coverage`): remove the
      three deleted agent names from its coverage list. *(completed: coverage list emptied with an
      explanatory pass, per the header comment's reasoning)*
- [x] `scripts/lint/lint-agent-contracts.sh` — remove
      `"core/agents/general-implementation-hard-agent.md"` and `"core/agents/planner-hard-agent.md"`
      from `IN_SCOPE_RELATIVE_PATHS`. *(completed)*
- [ ] `scripts/lint/lint-task-lookup-adoption.sh` — remove the four
      `"core/skills/skill-{implementer,orchestrate,planner,researcher}-hard/SKILL.md"` entries from
      its path list. *(deviation: deferred to Phase 4 — see below)*
- [x] Re-run all three lints and confirm the pass/fail counts are no worse than
      `.gate-baseline-before.txt` (the targets still exist at this point, so these must be green
      *before* deletion too). *(completed: all three exit 0, plus their meta-tests
      test-lint-agent-contracts.sh and test-lint-task-lookup-adoption.sh both exit 0)*

**Deviation (recorded)**: the `lint-task-lookup-adoption.sh` `EXCLUDED_FILES` entry removal was
attempted as chartered and found to break this same phase's own verification requirement. That
array is a file-level *exemption* list (deferred-known-offenders), not a mere path inventory:
each of the four `-hard` SKILL.md files still contains exactly one genuine hand-rolled
`select(.project_number == $num)` shape that is only accepted today because the whole file is
allowlisted. Removing the allowlist entry while the file still exists (true until Phase 4 deletes
it) un-exempts that one real violation per file — 4 new failures, worse than
`.gate-baseline-before.txt`'s 0. Deleting the file and removing its exemption entry must land
together, exactly like the reasoning Phase 4 already gives for why its own deletion and manifest
surgery are one atomic-batch commit. The edit is therefore deferred to Phase 4's atomic batch,
where the file's removal and its exemption-list removal land in the same commit and the check
never goes red. Verified: reverting the edit restores `lint-task-lookup-adoption.sh` to the exact
baseline result (349 files checked, 329 scanned, 329 exempted, 0 violations, exit 0).

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: `lint-contract-compliance.sh` carries **36 occurrences** of the seven names
across Checks A, C, E, and F; `lint-agent-contracts.sh` carries **2**; `lint-task-lookup-adoption.sh`
carries **4**. Confirm per-file with the Phase 1 census before editing; if a check not listed here
also references a target, retarget it in this phase rather than deferring.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh` - retarget Checks A, C,
  E; prune Check F's coverage list
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - prune two in-scope paths
- `agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh` - prune four paths

**Verification**:
- All three lints exit 0 and report no new failures versus baseline.
- `scripts/tests/test-lint-agent-contracts.sh` and `scripts/tests/test-lint-task-lookup-adoption.sh`
  still pass (each lint has its own meta-test).
- Zero occurrences of the seven names remain in the three edited lint scripts.

---

### Phase 3: Retarget the test scripts off the deletion targets [COMPLETED]

**Goal**: Same as Phase 2, for the four test scripts that reference the targets by path or assert
on hard-mode routing that Phase 4 removes.

**Tasks**:
- [x] `scripts/tests/test-routing-resolution.sh` — the `for op_default in "research
      skill-researcher-hard" "plan skill-planner-hard" "implement skill-implementer-hard"` loop
      asserts hard-mode skill defaults for `general`/`meta`/`markdown`. After Phase 4 removes
      core's `routing_hard`, those pairs are gone by design. Remove or retarget the loop to assert
      the *new* correct behavior (hard mode on those task types resolves the standard skill).
      *(completed: removed, with a comment explaining Assert 1's mechanical matrix loop already
      covers this and that command-route-skill.sh is no longer a live research/plan/implement
      dispatch path)*
- [x] `scripts/tests/test-routing-resolution.sh` — Assert 2/3/4's four
      `general-research-hard-agent` caller-default arguments: these pass the deleted agent name as
      `command-route-agent.sh`'s fallback default. Replace with `general-research-agent`, which is
      what `skill-orchestrate` actually passes, and update the assertion messages. *(completed)*
- [x] `scripts/tests/test-resume-scan-nonconformance.sh` — `SITE_B_FILE` points at
      `skill-implementer-hard/SKILL.md`. Retarget Site B to the engine's resume-scan site in
      `skill-orchestrate/SKILL.md`, or drop Site B and renumber, updating `SITE_LABEL` and the
      header comment to match. *(completed: dropped Site B — skill-orchestrate/SKILL.md has only
      one resume-scan gate region (Site A's), no second distinct site to retarget onto; A/C kept
      as-is rather than relabeled)*
- [x] `scripts/test-session-runtime-files.sh` — `CHURN_SKILL` points at
      `skill-orchestrate-hard/SKILL.md`. Retarget to `skill-orchestrate/SKILL.md`, which now owns
      the churn-state write. *(completed: CHURN_SKILL now aliases LOOP_GUARD_SKILL, same file)*
- [x] `scripts/tests/test-loop-guard-budget-override.sh` — its skip-guard greps for
      `skill-orchestrate-hard/SKILL.md` and carries a three-line comment explaining that
      `test-session-runtime-files.sh` cannot run because its preflight requires that file. Once the
      previous bullet lands, the limitation is discharged: remove the skip-guard and the comment
      so the suite actually runs. *(completed: skip-guard removed; test-session-runtime-files.sh
      now actually executes and passes)*
- [x] Re-run all four and confirm no regression versus `.gate-baseline-before.txt`. *(completed:
      all four exit 0, zero occurrences of the seven names remain in any of the four files)*

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: `test-routing-resolution.sh` carries **8** occurrences,
`test-resume-scan-nonconformance.sh` **4**, `test-loop-guard-budget-override.sh` **3**, and
`test-session-runtime-files.sh` **2**. Confirm against the Phase 1 census before editing.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` - drop hard-default
  loop, replace hard-agent caller defaults
- `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` - retarget or
  drop Site B
- `agent-system/extensions/core/scripts/tests/test-loop-guard-budget-override.sh` - remove the
  now-discharged skip-guard
- `agent-system/extensions/core/scripts/test-session-runtime-files.sh` - retarget `CHURN_SKILL`

**Verification**:
- All four scripts exit 0.
- `test-session-runtime-files.sh` now actually executes under
  `test-loop-guard-budget-override.sh` rather than being skipped.
- Zero occurrences of the seven names remain in the four edited test scripts.

---

### Phase 4: Delete the seven files and perform manifest routing surgery [COMPLETED]

**Goal**: The deletion itself, together with the manifest edits it forces. These are one atomic
unit: `lint-routing-wiring.sh` Check B fails if the agents are deleted while
`routing_agents_hard` still names them, and `check-extension-docs.sh` Rule B fails if the skill
directories are deleted while `routing_hard` still targets them. Neither half is green alone.

**Tasks**:
- [x] Delete `agent-system/extensions/core/skills/skill-orchestrate-hard/` (SKILL.md and any
      sibling files in the directory). *(completed: directory contained only SKILL.md, no
      siblings)*
- [x] Delete `agent-system/extensions/core/skills/skill-researcher-hard/`,
      `skill-planner-hard/`, `skill-implementer-hard/`. *(completed)*
- [x] Delete `agent-system/extensions/core/agents/general-research-hard-agent.md`,
      `planner-hard-agent.md`, `general-implementation-hard-agent.md`. *(completed)*
- [x] `agent-system/extensions/core/manifest.json` — remove the `routing_hard` and
      `routing_agents_hard` top-level keys entirely (every entry names a deleted asset).
      *(completed)*
- [x] `agent-system/extensions/core/manifest.json` — remove the three deleted agent filenames from
      `provides.agents` and the four deleted skill names from `provides.skills`. *(completed)*
- [x] `agent-system/extensions/cslib/manifest.json` — remove exactly six entries in matched pairs:
      `routing_hard.research.pr`, `routing_hard.plan.cslib`, `routing_hard.plan.pr`,
      `routing_hard.implement.pr`, and their `routing_agents_hard` counterparts
      (`research.pr`, `plan.cslib`, `plan.pr`, `implement.pr`). Retain
      `routing_hard.research.cslib`, `routing_hard.implement.cslib`, and their agent counterparts.
      If `routing_hard.plan` and `routing_agents_hard.plan` become empty objects, remove both `plan`
      keys symmetrically. *(completed: on-disk verification found 4 entries removed from each of
      the two blocks — 8 raw key removals total — not 6 as this bullet's own summary line states;
      the itemized list of 4 op.subkey pairs above, doubled across routing_hard and
      routing_agents_hard, is what actually matched disk state and is what was removed. Both
      `plan` keys were empty after removal and were dropped symmetrically, exactly as specified)*
- [x] `agent-system/extensions/lean/manifest.json` — **no change**. Verify it contains none of the
      seven names and leave it untouched (see Scoping Deviation). *(completed: `git diff` on
      lean/manifest.json is empty)*
- [x] Validate all three manifests parse as JSON. *(completed)*
- [x] Run `scripts/lint/lint-routing-wiring.sh` and `scripts/check-extension-docs.sh` and confirm
      no new failures versus baseline. *(completed: lint-routing-wiring.sh exits 0 (297 passed).
      check-extension-docs.sh reports zero unresolvable/undeployed `routing_hard` target FAILs —
      its only new FAILs are "deployed script content drift" for the 4 lint/test scripts edited in
      Phases 2-3, an expected, self-resolving consequence of source-store edits made ahead of
      Phase 8's deploy regeneration, not a routing regression)*
- [x] *(deviation carried in from Phase 2)* `scripts/lint/lint-task-lookup-adoption.sh` — remove
      the four `"core/skills/skill-{implementer,orchestrate,planner,researcher}-hard/SKILL.md"`
      entries from `EXCLUDED_FILES`, in the same commit as the file deletion above (removing the
      exemption while the file still exists un-exempts one genuine hand-rolled violation per
      file — see Phase 2's Deviation note). Re-run the lint and its meta-test
      (`scripts/tests/test-lint-task-lookup-adoption.sh`) after both land together. *(completed:
      both exit 0, landing atomically with the deletion as intended)*

**Timing**: 1.0 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Scope Hypothesis**: The deletion set is exactly **7 files** measured at plan time as
1833 / 275 / 462 / 507 / 332 / 334 / 545 lines (the charter's ledger cites 1,784 and 538 for the
first and last; the on-disk values are authoritative and the discrepancy is expected drift, not a
different file). The manifest surgery is **2 top-level keys removed from core**, **7 entries
removed from core's `provides` lists**, **6 entries removed from cslib**, and **0 changes to
lean**. Confirm each file's existence and each manifest key's contents immediately before editing;
if cslib or lean has gained an entry naming a deleted asset since plan time, remove that too.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - deleted
- `agent-system/extensions/core/skills/skill-researcher-hard/SKILL.md` - deleted
- `agent-system/extensions/core/skills/skill-planner-hard/SKILL.md` - deleted
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` - deleted
- `agent-system/extensions/core/agents/general-research-hard-agent.md` - deleted
- `agent-system/extensions/core/agents/planner-hard-agent.md` - deleted
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` - deleted
- `agent-system/extensions/core/manifest.json` - drop both hard routing blocks and 7 `provides` entries
- `agent-system/extensions/cslib/manifest.json` - drop 6 dead hard routing entries

**Verification**:
- All seven paths are absent from disk.
- All three manifests parse as valid JSON.
- `lint-routing-wiring.sh` Check B (every routing_agents value names an existing agent) and Check
  C (routing_hard/routing_agents_hard key symmetry) both pass.
- `check-extension-docs.sh` reports no unresolvable `routing_hard` target.
- `test-routing-resolution.sh` still passes with the Phase 3 edits in place.
- `git diff` on `lean/manifest.json` is empty.

---

### Phase 5: Prune dead agent references from the index-entries files [COMPLETED]

**Goal**: Remove the deleted agent names from `load_when.agents[]` arrays across the three
extensions that register them. Entries listed in `agents[]` are auto-loaded at agent spawn
regardless of any tier label, so a dangling name there is a live dead reference, not cosmetic
metadata.

**Tasks**:
- [x] `agent-system/extensions/core/index-entries.json` — remove `general-research-hard-agent`,
      `planner-hard-agent`, and `general-implementation-hard-agent` from every
      `entries[].load_when.agents[]` array. *(completed: 45 occurrences pruned across the relevant
      entries; entry count unchanged at 145, no path lost)*
- [x] `agent-system/extensions/cslib/index-entries.json` — same removal from `load_when.agents[]`,
      plus one prose occurrence inside an `entries[].summary` string that must be reworded.
      *(completed: 3 array occurrences pruned; the `contracts/adversarial-verification.md` summary
      reworded to drop its "union with general-research-hard-agent" framing since that entry is
      now core-only-on-demand)*
- [x] `agent-system/extensions/lean/index-entries.json` — same removal from `load_when.agents[]`.
      *(completed: 5 occurrences pruned across 3 entries — reference-grounding.md (2),
      anti-analysis.md (2), adversarial-verification.md (1))*
- [x] For any entry whose `agents[]` becomes empty, decide per the schema whether an empty array
      is valid or the `load_when` key should be restructured; do not leave a schema violation.
      *(completed: 20 core entries whose entire `load_when` (agents+task_types+commands) became
      empty were marked `"on_demand": true`, per index.schema.json's documented Dead-Entry-Check
      exemption marker — verified this did NOT touch the 4 pre-existing, unrelated dead entries
      already lacking the marker before this task. One entry (`patterns/jq-escaping-workarounds.md`)
      needed no marker since its `commands[]` hook stayed non-empty. No cslib or lean entry's
      `load_when` became fully empty (all retain `task_types`))*
- [x] Validate all three files parse as JSON and run
      `scripts/tests/test-index-entries-schema.sh`. *(completed: all three valid JSON;
      test-index-entries-schema.sh exits 0, 9 passed 0 failed)*

**Timing**: 1.0 hours

**Depends on**: 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: The occurrences localize to exactly one JSON location class —
`entries[].load_when.agents[]` — with **45 in core, 3 in cslib, 5 in lean**, plus **1** cslib
`entries[].summary` prose mention: 54 total. Confirm with a structural walk of each file (not a
line grep) before editing; if any occurrence appears at a path other than
`load_when.agents[]` or `summary`, handle it explicitly rather than assuming the class.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - prune 45 agent-array members
- `agent-system/extensions/cslib/index-entries.json` - prune 3 members, reword 1 summary
- `agent-system/extensions/lean/index-entries.json` - prune 5 members

**Verification**:
- All three files parse as valid JSON.
- `test-index-entries-schema.sh` passes.
- Zero occurrences of the seven names remain in the three files.
- No entry gained or lost a `path`, and no entry was removed wholesale — only `agents[]` members.

---

### Phase 6: De-reference the routing and orchestration-engine documentation [COMPLETED]

**Goal**: Rewrite the documents that describe hard-mode routing and the orchestration engine so
they describe the post-deletion architecture. These are the highest-density and most load-bearing
references: read as live behavioral claims, they become false the moment Phase 4 lands.

**Tasks**:
- [x] `skills/skill-orchestrate/SKILL.md` — rewrite references to the deleted engine and agents.
      Many are provenance comments explaining what was migrated *from* `skill-orchestrate-hard`;
      keep the explanation, drop the implication that the source file still exists (e.g. phrase as
      "the superseded hard engine" rather than a live path). *(completed: all 19 occurrences
      rewritten to phrase past cross-file synchronization as within-file dual-branch handling, and
      provenance mentions as "the superseded standalone hard-mode engine")*
- [x] `commands/orchestrate.md` — remove `skill-orchestrate-hard` from the `--hard` dispatch
      description; `--hard` now sets `hard_mode` inside `skill-orchestrate`. *(completed: 2
      occurrences retargeted)*
- [x] `merge-sources/claudemd.md` — remove the four deleted skill/agent rows from the
      Skill-to-Agent Mapping table and any hard-routing prose naming them. This is the source of
      the generated `.claude/CLAUDE.md`, which currently lists all four as live skills.
      *(completed: 4 rows removed)*
- [x] `context/guides/hard-mode-routing.md` — the routing table's three
      "Core manifest routing_hard + Step 4e fallback" rows and the `skill-orchestrate-hard`
      row are now wrong. Rewrite for the single-engine model. *(completed: "Deployed Hard Skills"
      table rewritten to list only cslib/lean's surviving domain-specific -hard skills;
      "Orchestrate-Hard: Same Resolver, Different Block" section rewritten as "Orchestrate Hard
      Mode: One Engine, Effort-Gated")*
- [x] `context/guides/manifest-routing-schema.md` — update the two examples and the consumer list.
      *(completed: 3 occurrences retargeted, preserving the "before this task" provenance
      narrative)*
- [x] `docs/architecture/handoff-schema.md` — the "Read by" line, the Handoff Writers table
      (which names `general-implementation-hard-agent.md` as "the only writer"), and the Stage
      4/5 reader citations all need retargeting to the surviving writer/reader. *(completed: all
      16 occurrences retargeted. Surfaced and documented a real architectural consequence in the
      process: core's general/meta/markdown task types now resolve hard-mode implement dispatch
      to the SAME base-mode general-implementation-agent, which never writes a handoff — so core
      task types produce no `.orchestrator-handoff.json` under `--hard` any more than under
      standard mode; only cslib and lean, which still declare their own hard-mode implementation
      agents, remain active writers)*
- [x] `docs/architecture/batch-admit-schema.md` and `docs/architecture/orchestrate-state-machine.md`
      — retarget engine citations. *(completed: 6 + 2 occurrences retargeted; two Version History
      table rows describing the now-deleted file's historical co-maintenance updates were reworded
      to reference "the former standalone hard-mode orchestrator's own transcription (file since
      deleted)" rather than dropped, preserving the historical record)*
- [x] `context/reference/orchestrator-critical-paths.json` — remove or retarget the deleted path.
      *(completed: the dedicated skill-orchestrate-hard/SKILL.md entry removed; its "hard-mode
      dispatch contracts" label folded into the skill-orchestrate/SKILL.md entry's own label)*
- [x] `docs/reference/utility-scripts-inventory.md` — retarget its one citation. *(completed:
      lint-contract-compliance.sh's description rewritten to match its Phase 2 retargeted checks)*

**Timing**: 2.0 hours

**Depends on**: 4

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase's file set carries roughly **75 occurrences across 9-10 files**
(`skill-orchestrate/SKILL.md` 19, `handoff-schema.md` 16, `hard-mode-routing.md` 9,
`batch-admit-schema.md` 6, `manifest-routing-schema.md` 3, `merge-sources/claudemd.md` 4,
`orchestrate-state-machine.md` 2, `commands/orchestrate.md` 2, plus 1 each in
`orchestrator-critical-paths.json` and `utility-scripts-inventory.md`). Confirm from the Phase 1
census; any file in this class that the census lists but this task list omits must still be swept
here.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - provenance-comment rewrites
- `agent-system/extensions/core/commands/orchestrate.md` - `--hard` dispatch description
- `agent-system/extensions/core/merge-sources/claudemd.md` - skill mapping table rows
- `agent-system/extensions/core/context/guides/hard-mode-routing.md` - routing table and prose
- `agent-system/extensions/core/context/guides/manifest-routing-schema.md` - examples, consumers
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - readers/writers tables
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` - engine citations
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - engine citations
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` - path entry
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - one citation

**Verification**:
- Zero occurrences of the seven names remain in the listed files.
- `orchestrator-critical-paths.json` parses as valid JSON.
- Every rewritten passage still states a true claim about the current engine — spot-check each
  retargeted `skill-orchestrate/SKILL.md` stage citation actually names an existing stage.
- No `@`-reference or markdown link is left pointing at a deleted path (`check-extension-docs.sh`
  and any broken-reference lint stay green).

---

### Phase 7: De-reference contracts, patterns, standards, and script comments [COMPLETED]

**Goal**: Sweep the long tail — contract files, pattern docs, standards, format docs, and inline
script comments — plus the one surviving *live* code reference outside the manifests.

**Tasks**:
- [x] `scripts/skill-base.sh` — line ~889 is a live `case` arm mapping `[hard-orchestrate]` to
      `skills/skill-orchestrate-hard/SKILL.md` as `gate_attributed_path`. This is executable, not a
      comment: decide whether the `[hard-orchestrate]` label is still reachable and either
      retarget the path to `skill-orchestrate/SKILL.md` or remove the arm. Handle the file's four
      comment references separately. *(completed: confirmed `[hard-orchestrate]` is genuinely
      unreachable — skill-orchestrate/SKILL.md's sole call site always passes `"[orchestrate]"`
      regardless of effort mode — so the arm was removed rather than retargeted; all 4 comment
      references also rewritten)*
- [x] `scripts/command-route-agent.sh`, `scripts/validate-handoff.sh`,
      `scripts/update-task-status.sh`, `scripts/orchestrate-stage5-gates.sh`,
      `scripts/orchestrate-stage5-postflight.sh`, `scripts/check-extension-docs.sh` — comment-only
      references; retarget to the surviving engine. *(completed: also corrected two stale
      behavioral claims found while retargeting — command-route-agent.sh's caller-default doc no
      longer describes a "-hard"-suffixed default since none is ever passed in practice, and
      orchestrate-stage5-postflight.sh's tier_c_detecting_site doc no longer describes a
      base/hard split since there is one call site today)*
- [x] `context/contracts/` — `anti-analysis.md`, `orchestrator-discipline.md`, `recovery.md`,
      `territory.md`, `wrap-up.md`, `phase-closure.md`, `pre-edit-gate.md`,
      `no-task-references-bullet.md`. These name the deleted skills/agents as their consumers;
      rewrite the consumer lists to name the engine and the surviving agents. *(completed: all 8)*
- [x] `context/patterns/` — `skill-lifecycle.md` (its Autonomous Loop table and the three
      skill-pair lines), `task-lock.md`, `checkpoint-before-overflow.md`,
      `batch-orchestration-guardrails.md`, `system-defect-discrimination.md`,
      `infra-failure-discrimination.md`, `dispatch-report-not-termination.md`. *(completed: all
      7. batch-orchestration-guardrails.md's 10-row critical-paths table renumbered to 9 rows
      after folding the deleted hard-mode engine's row into skill-orchestrate's own, with
      downstream cross-references ("row 7", "seven of the ten") updated to match;
      system-defect-discrimination.md's 5-consumer-site list reduced to 4 with a similar
      downstream count fix)*
- [x] `context/standards/orchestrator-runtime-files.md`, `context/standards/task-reference-exemptions.md`,
      `context/architecture/context-layers.md`, `context/formats/plan-format.md` (its
      `{{FOLLOWUP:i}}` substitution owner and resume-scan citations name `skill-planner-hard` and
      `skill-implementer-hard` — retarget to whichever component now owns each). *(completed: all
      4. plan-format.md's skeleton/follow_up_tasks section surfaces and documents a real finding —
      no live planning skill or agent anywhere in the repo currently populates these fields or the
      `{{FOLLOWUP:i}}` substitution; core's own standalone hard-mode planner owned it and is
      deleted, and neither cslib nor lean has ever had a hard-mode planner of their own)*
- [x] `agent-system/extensions/cslib/README.md`,
      `cslib/context/contracts/adversarial-verification.md`,
      `cslib/skills/skill-cslib-implementation-hard/SKILL.md`,
      `lean/skills/skill-lean-implementation-hard/SKILL.md`,
      `lean/context/project/lean4/domain/hard-mode.md` — extension-side citations of the deleted
      core assets. *(completed: all 5. cslib/README.md's routing table and prose corrected —
      `pr`'s hard-mode routing row named the two exact dead entries this task's Phase 4 removed,
      so `pr` now genuinely has no hard-mode routing and falls back to standard skills, not merely
      a stale citation; lean/hard-mode.md's Plan column corrected the same way — lean4's
      `/plan --hard` now falls back to standard `skill-planner`, not the deleted `skill-planner-hard`)*

**Timing**: 2.0 hours

**Depends on**: 4

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Roughly **55 occurrences across 30 files**, of which exactly **one**
(`skill-base.sh`'s `gate_attributed_path` case arm) is executable code rather than prose or
comment. Confirm both figures from the Phase 1 census before editing; if a second executable
reference turns up outside the manifests and the Phase 2-3 lint/test files, treat this phase as
`full` tier rather than `local` and re-run the shell test suite before closing.

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - one live case arm plus comments
- `agent-system/extensions/core/scripts/{command-route-agent,validate-handoff,update-task-status,orchestrate-stage5-gates,orchestrate-stage5-postflight,check-extension-docs}.sh` - comments
- `agent-system/extensions/core/context/contracts/*.md` (8 files) - consumer lists
- `agent-system/extensions/core/context/patterns/*.md` (7 files) - engine and skill citations
- `agent-system/extensions/core/context/standards/*.md` (2 files) - citations
- `agent-system/extensions/core/context/architecture/context-layers.md` - citations
- `agent-system/extensions/core/context/formats/plan-format.md` - substitution-owner citations
- `agent-system/extensions/cslib/{README.md,context/contracts/adversarial-verification.md,skills/skill-cslib-implementation-hard/SKILL.md}` - citations
- `agent-system/extensions/lean/{skills/skill-lean-implementation-hard/SKILL.md,context/project/lean4/domain/hard-mode.md}` - citations

**Verification**:
- Zero occurrences of the seven names remain in the listed files.
- `bash -n` passes on every edited shell script.
- `scripts/tests/test-skill-base-lifecycle.sh` passes (guards the `skill-base.sh` edit).
- The `[hard-orchestrate]` decision is recorded in the phase's progress note with its reasoning.

---

### Phase 8: Zero-hit confirmation, full gate run, and deploy refresh [COMPLETED]

**Goal**: Discharge the task's own stated completion criterion and confirm the system is no worse
off than the Phase 1 baseline.

**Tasks**:
- [x] Re-run the Phase 1 census grep over `agent-system/` for all seven names and confirm **zero
      hits**. Write the result to `.reference-census-after.txt` and diff against
      `.reference-census-before.txt`. *(completed: zero hits confirmed; before-census counted
      449 raw name occurrences (skill-orchestrate-hard 148, general-implementation-hard-agent 87,
      general-research-hard-agent 63, planner-hard-agent 46, skill-implementer-hard 47,
      skill-planner-hard 33, skill-researcher-hard 25); after-census is empty for both the
      `agent-system/` grep and the repo-wide-excluding-`specs/` grep)*
- [x] Run the identical repo-wide grep excluding `specs/` and confirm zero hits outside this
      task's own artifacts — the charter's explicit completion gate. *(completed: 0 hits)*
- [x] Confirm `git diff` on `agent-system/extensions/lean/manifest.json` is empty. *(completed:
      empty diff confirmed)*
- [x] Confirm cslib's and lean's four-plus-four `-hard` assets still exist on disk and are still
      routed by their manifests. *(completed: all 8 files present; cslib's `routing_hard`/
      `routing_agents_hard` still route `research.cslib` -> skill-cslib-research-hard /
      cslib-research-hard-agent and `implement.cslib` -> skill-cslib-implementation-hard /
      cslib-implementation-hard-agent; lean's still route `research.lean4` and `implement.lean4`
      to their four `-hard` assets)*
- [x] Run the full gate set: `scripts/tests/run-all.sh`, all eight lints in `scripts/lint/`,
      `scripts/check-extension-docs.sh`, `scripts/verify-deploy.sh`. Compare against
      `.gate-baseline-before.txt`; any failure must be either pre-existing in the baseline or
      fixed before the task closes. *(completed: run-all.sh 62/62 passed; all 9 lint scripts in
      scripts/lint/ (one more than the plan's "eight" — lint-state-writer-boundary.sh was added
      by an unrelated task after this plan was authored) exit 0 except
      lint-state-writer-boundary.sh, which fails on 4 pre-existing hand-rolled state.json writes
      in test-force-phases.sh (last touched by an unrelated task, not part of this task's file
      scope, and not one of the 7 deletion targets); check-extension-docs.sh reproduces the exact
      same single pre-existing literature-extension failure recorded in the Phase 1 baseline;
      verify-deploy.sh reports 3 of 30 checks failed, all three independently confirmed
      pre-existing and unrelated: (1) the same literature doc-lint failure, (2) validate-state.sh
      --deep unknown-field findings on project_numbers 94/46/31/64/73/115/132/106/107/109 (none
      of which is task 121), confirmed present in specs/state.json before this task's first
      commit, and (3) the same lint-state-writer-boundary.sh finding. No new failure attributable
      to this task's changes)*
- [x] Regenerate the `.claude/` deploy artifact so the runtime stops advertising four deleted
      skills (the current `.claude/CLAUDE.md` Skill-to-Agent Mapping still lists all four, and
      `.claude/skills/`, `.claude/agents/` still hold the deleted copies). Confirm the deployed
      tree no longer contains any of the seven paths. *(completed: `deploy-headless.sh` re-run;
      deployed tree already carried zero hits for the seven names going in — a deploy refresh had
      evidently landed earlier in this task's lifecycle — and the fresh regeneration confirms
      `.claude/skills/`, `.claude/agents/`, and `.claude/CLAUDE.md` all remain clean. The
      regeneration also mechanically corrected `line_count` drift in three `index-entries.json`
      files for context files whose line counts changed during Phases 6-7's prose edits)*
- [x] Note in the summary that `verify-deploy.sh` gate 16 will still warn while cslib and lean
      declare `routing_hard`/`routing_agents_hard` — that residue is task 127's scope, not a
      failure of this task. *(completed: this repository's own `.claude-extensions.json` does not
      load the cslib or lean extensions, so this repo's own `verify-deploy.sh` run has no
      cslib/lean manifest to warn about and gate 16 reports PASS here; the warning is expected to
      surface in a deploy where cslib and/or lean ARE loaded (e.g. the cslib or Logos/Theory
      repos), and is out of this task's scope regardless — recorded in the summary as directed)*

**Timing**: 1.0 hours

**Depends on**: 5, 6, 7

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: The completion criterion asserts **zero hits repo-wide excluding `specs/`**.
Confirm by running the grep; if hits remain outside `agent-system/` (for example in `docs/` at the
repository root or in `.opencode/`), report them explicitly rather than silently narrowing the
criterion to `agent-system/` — the charter says repo-wide.

**Files to modify**:
- `specs/121_delete_hard_mode_lifecycle_files/.reference-census-after.txt` - new
- `.claude/**` - regenerated deploy artifact only (never hand-edited)

**Verification**:
- Census grep returns zero hits in `agent-system/` and zero outside `specs/`.
- Full gate set shows no regression versus the Phase 1 baseline.
- Deployed `.claude/` tree contains none of the seven paths and its CLAUDE.md no longer lists the
  four deleted skills.

---

## Testing & Validation

- [x] All eight scripts in `agent-system/extensions/core/scripts/lint/` exit 0 with no new
      failures versus the Phase 1 baseline. *(completed: of the 9 lint scripts now present in the
      directory — one, `lint-state-writer-boundary.sh`, was added by an unrelated task after this
      plan was authored — 8 exit 0; the 9th fails only on a pre-existing, unrelated
      `test-force-phases.sh` finding, confirmed via `git log` to predate this task's first commit)*
- [x] `scripts/tests/run-all.sh` shows no regression versus the Phase 1 baseline. *(completed:
      62 passed, 0 failed, 0 skipped)*
- [x] `scripts/tests/test-routing-resolution.sh` passes with core's hard blocks removed and
      cslib's partially removed. *(completed: 13/13 assertions passed)*
- [x] `scripts/tests/test-index-entries-schema.sh` passes after the `agents[]` pruning.
      *(completed: 9/9 passed)*
- [x] `scripts/check-extension-docs.sh` reports no unresolvable or undeployed `routing_hard`
      target. *(completed: core, cslib, and lean all report PASS with zero unresolvable/undeployed
      routing_hard findings; the one FAIL present is the pre-existing literature extension
      line_count drift, unrelated to routing)*
- [x] `scripts/verify-deploy.sh` passes (gate 16's cslib/lean warning is expected and out of scope).
      *(deviation: verify-deploy.sh reports 3 of 30 checks failed rather than a clean pass — all
      three independently confirmed pre-existing and unrelated to this task (literature doc-lint
      drift, validate-state.sh unknown-field findings on 9 unrelated project numbers, and the
      lint-state-writer-boundary.sh finding in test-force-phases.sh); gate 16 itself reports PASS
      in this repo since cslib/lean are not loaded extensions here)*
- [x] Repo-wide grep for the seven names returns zero hits outside `specs/`. *(completed: 0 hits)*
- [x] `/orchestrate --hard` still resolves: standard agents for `general`/`meta`/`markdown` with
      contract injection, `cslib-*-hard-agent` for `cslib`, `lean-*-hard-agent` for `lean4`.
      *(completed: verified via manifest inspection and test-routing-resolution.sh — core has no
      routing_hard block left (general/meta/markdown fall through to the standard skill, which
      carries the hard_mode contract-injection block per Phase 1's precondition re-verification);
      cslib's routing_hard.research/implement.cslib and lean's routing_hard.research/implement.lean4
      still route to their respective `-hard` skills and agents)*

## Artifacts & Outputs

- Seven deleted files under `agent-system/extensions/core/`.
- Modified: `core/manifest.json`, `cslib/manifest.json`, three `index-entries.json`, three lint
  scripts, four test scripts, and roughly 40 documentation/context/comment files.
- Unmodified by design: `lean/manifest.json`.
- `specs/121_delete_hard_mode_lifecycle_files/.reference-census-before.txt`,
  `.reference-census-after.txt`, `.gate-baseline-before.txt`.
- `specs/121_delete_hard_mode_lifecycle_files/summaries/01_*-summary.md`.
- Regenerated `.claude/` deploy tree.

## Rollback/Contingency

Every phase commits separately except Phase 4, which is a single atomic-batch commit — so
`git revert` of any one commit restores that phase's prior state cleanly. Phase 4 is the only
irreversible-feeling step, and it is fully recoverable: the seven deleted files remain in git
history and can be restored with `git checkout <pre-phase-4-sha> -- <path>` alongside a revert of
the manifest edits, since the two landed together.

If Phase 1 finds the precondition genuinely unmet — specifically, if `/research`, `/plan`, or
`/implement` have reappeared in `agent-system/extensions/core/commands/` — stop before Phase 2,
write `status: "blocked"` to the return metadata naming task 124 as the blocker, and do not
delete anything. Phase 1 makes no source-store change, so stopping there costs nothing.

If the Phase 7 prose sweep proves larger than its hypothesis and threatens to run long, close the
phase as `[COMPLETED WITH EXCLUSIONS]` with the remaining files enumerated, and do NOT let Phase 8
declare the zero-hit criterion satisfied — the criterion is binary and a partial sweep fails it.

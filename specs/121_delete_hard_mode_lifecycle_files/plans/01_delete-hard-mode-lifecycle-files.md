# Implementation Plan: Task #121

- **Task**: 121 - Delete hard mode lifecycle files
- **Status**: [NOT STARTED]
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

### Phase 1: Re-verify precondition and freeze the reference baseline [NOT STARTED]

**Goal**: Convert the research report's stale blocking verdict into a current, recorded
determination, and capture the exact pre-change state of every gate this task can break — so that
any red in Phase 8 is attributable rather than ambiguous.

**Tasks**:
- [ ] Confirm `agent-system/extensions/core/commands/` contains no `research.md`, `plan.md`, or
      `implement.md`, and that task 124 reads `completed` in `specs/state.json`. If either is
      false, STOP and report blocked — the research report's §4 objection is live again.
- [ ] Confirm the `<hard-mode-contracts>` injection block is present in
      `skill-orchestrate/SKILL.md` Stage 3.5 Dispatch Prep (report §1).
- [ ] Confirm the `hard_mode`-gated H1/H4/H5/H6 branches are present in
      `skill-orchestrate/SKILL.md` (report §2).
- [ ] Confirm all seven deletion targets still exist on disk, and record each one's line count.
- [ ] Confirm cslib's and lean's own `-hard` skills and agents exist on disk (the four cslib and
      four lean assets named in the Scoping Deviation) — these must survive.
- [ ] Write the reference census to
      `specs/121_delete_hard_mode_lifecycle_files/.reference-census-before.txt`: the full
      `grep -rn -E` output over `agent-system/` for the seven names, plus a per-file count table.
- [ ] Run and record the pre-change result (pass/fail counts, not just exit code) of:
      `scripts/lint/lint-contract-compliance.sh`, `scripts/lint/lint-agent-contracts.sh`,
      `scripts/lint/lint-task-lookup-adoption.sh`, `scripts/lint/lint-routing-wiring.sh`,
      `scripts/check-extension-docs.sh`, `scripts/tests/test-routing-resolution.sh`,
      `scripts/tests/test-resume-scan-nonconformance.sh`,
      `scripts/tests/test-loop-guard-budget-override.sh`,
      `scripts/tests/test-index-entries-schema.sh`, `scripts/test-session-runtime-files.sh`.
      Store as `.gate-baseline-before.txt` in the task directory.

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

### Phase 2: Retarget the lint scripts off the deletion targets [NOT STARTED]

**Goal**: Make the three lint scripts that hard-require the deletion targets by path assert
against `skill-orchestrate/SKILL.md`'s hard-mode branch (or drop the assertion where the
capability no longer has a separate home), so they stay green after Phase 4.

**Tasks**:
- [ ] `scripts/lint/lint-contract-compliance.sh` — Check A
      (`check_a_hard_agent_contract_references`): the three `local ..._agent=` paths and their
      `log_fail "... not found"` branches assert that the deleted agent files carry `@`-references
      to the contract files. Retarget to assert that `skill-orchestrate/SKILL.md`'s
      `<hard-mode-contracts>` block references the same contracts.
- [ ] `scripts/lint/lint-contract-compliance.sh` — Check C
      (`check_c_hard_skill_dispatch`): the `SKILL_AGENTS` associative array still maps the three
      deleted skills to the three deleted agents and `log_fail`s per missing SKILL.md. Task 120
      retargeted only the trailing `skill-orchestrate-hard` special case and left this loop
      untouched. Retarget the loop to the engine's dispatch sites or remove it, matching what
      Check C's stated purpose can still verify.
- [ ] `scripts/lint/lint-contract-compliance.sh` — Check E (`check_e_h2_vocabulary`): retarget the
      H2 vocabulary assertions from `general-implementation-hard-agent.md` to wherever the H2
      vocabulary now lives (`context/contracts/anti-analysis.md` or the engine's contract-injection
      block); update the check's header comment and its `usage` line.
- [ ] `scripts/lint/lint-contract-compliance.sh` — Check F (`check_f_index_coverage`): remove the
      three deleted agent names from its coverage list.
- [ ] `scripts/lint/lint-agent-contracts.sh` — remove
      `"core/agents/general-implementation-hard-agent.md"` and `"core/agents/planner-hard-agent.md"`
      from `IN_SCOPE_RELATIVE_PATHS`.
- [ ] `scripts/lint/lint-task-lookup-adoption.sh` — remove the four
      `"core/skills/skill-{implementer,orchestrate,planner,researcher}-hard/SKILL.md"` entries from
      its path list.
- [ ] Re-run all three lints and confirm the pass/fail counts are no worse than
      `.gate-baseline-before.txt` (the targets still exist at this point, so these must be green
      *before* deletion too).

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

### Phase 3: Retarget the test scripts off the deletion targets [NOT STARTED]

**Goal**: Same as Phase 2, for the four test scripts that reference the targets by path or assert
on hard-mode routing that Phase 4 removes.

**Tasks**:
- [ ] `scripts/tests/test-routing-resolution.sh` — the `for op_default in "research
      skill-researcher-hard" "plan skill-planner-hard" "implement skill-implementer-hard"` loop
      asserts hard-mode skill defaults for `general`/`meta`/`markdown`. After Phase 4 removes
      core's `routing_hard`, those pairs are gone by design. Remove or retarget the loop to assert
      the *new* correct behavior (hard mode on those task types resolves the standard skill).
- [ ] `scripts/tests/test-routing-resolution.sh` — Assert 2/3/4's four
      `general-research-hard-agent` caller-default arguments: these pass the deleted agent name as
      `command-route-agent.sh`'s fallback default. Replace with `general-research-agent`, which is
      what `skill-orchestrate` actually passes, and update the assertion messages.
- [ ] `scripts/tests/test-resume-scan-nonconformance.sh` — `SITE_B_FILE` points at
      `skill-implementer-hard/SKILL.md`. Retarget Site B to the engine's resume-scan site in
      `skill-orchestrate/SKILL.md`, or drop Site B and renumber, updating `SITE_LABEL` and the
      header comment to match.
- [ ] `scripts/test-session-runtime-files.sh` — `CHURN_SKILL` points at
      `skill-orchestrate-hard/SKILL.md`. Retarget to `skill-orchestrate/SKILL.md`, which now owns
      the churn-state write.
- [ ] `scripts/tests/test-loop-guard-budget-override.sh` — its skip-guard greps for
      `skill-orchestrate-hard/SKILL.md` and carries a three-line comment explaining that
      `test-session-runtime-files.sh` cannot run because its preflight requires that file. Once the
      previous bullet lands, the limitation is discharged: remove the skip-guard and the comment
      so the suite actually runs.
- [ ] Re-run all four and confirm no regression versus `.gate-baseline-before.txt`.

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

### Phase 4: Delete the seven files and perform manifest routing surgery [NOT STARTED]

**Goal**: The deletion itself, together with the manifest edits it forces. These are one atomic
unit: `lint-routing-wiring.sh` Check B fails if the agents are deleted while
`routing_agents_hard` still names them, and `check-extension-docs.sh` Rule B fails if the skill
directories are deleted while `routing_hard` still targets them. Neither half is green alone.

**Tasks**:
- [ ] Delete `agent-system/extensions/core/skills/skill-orchestrate-hard/` (SKILL.md and any
      sibling files in the directory).
- [ ] Delete `agent-system/extensions/core/skills/skill-researcher-hard/`,
      `skill-planner-hard/`, `skill-implementer-hard/`.
- [ ] Delete `agent-system/extensions/core/agents/general-research-hard-agent.md`,
      `planner-hard-agent.md`, `general-implementation-hard-agent.md`.
- [ ] `agent-system/extensions/core/manifest.json` — remove the `routing_hard` and
      `routing_agents_hard` top-level keys entirely (every entry names a deleted asset).
- [ ] `agent-system/extensions/core/manifest.json` — remove the three deleted agent filenames from
      `provides.agents` and the four deleted skill names from `provides.skills`.
- [ ] `agent-system/extensions/cslib/manifest.json` — remove exactly six entries in matched pairs:
      `routing_hard.research.pr`, `routing_hard.plan.cslib`, `routing_hard.plan.pr`,
      `routing_hard.implement.pr`, and their `routing_agents_hard` counterparts
      (`research.pr`, `plan.cslib`, `plan.pr`, `implement.pr`). Retain
      `routing_hard.research.cslib`, `routing_hard.implement.cslib`, and their agent counterparts.
      If `routing_hard.plan` and `routing_agents_hard.plan` become empty objects, remove both `plan`
      keys symmetrically.
- [ ] `agent-system/extensions/lean/manifest.json` — **no change**. Verify it contains none of the
      seven names and leave it untouched (see Scoping Deviation).
- [ ] Validate all three manifests parse as JSON.
- [ ] Run `scripts/lint/lint-routing-wiring.sh` and `scripts/check-extension-docs.sh` and confirm
      no new failures versus baseline.

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

### Phase 5: Prune dead agent references from the index-entries files [NOT STARTED]

**Goal**: Remove the deleted agent names from `load_when.agents[]` arrays across the three
extensions that register them. Entries listed in `agents[]` are auto-loaded at agent spawn
regardless of any tier label, so a dangling name there is a live dead reference, not cosmetic
metadata.

**Tasks**:
- [ ] `agent-system/extensions/core/index-entries.json` — remove `general-research-hard-agent`,
      `planner-hard-agent`, and `general-implementation-hard-agent` from every
      `entries[].load_when.agents[]` array.
- [ ] `agent-system/extensions/cslib/index-entries.json` — same removal from `load_when.agents[]`,
      plus one prose occurrence inside an `entries[].summary` string that must be reworded.
- [ ] `agent-system/extensions/lean/index-entries.json` — same removal from `load_when.agents[]`.
- [ ] For any entry whose `agents[]` becomes empty, decide per the schema whether an empty array
      is valid or the `load_when` key should be restructured; do not leave a schema violation.
- [ ] Validate all three files parse as JSON and run
      `scripts/tests/test-index-entries-schema.sh`.

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

### Phase 6: De-reference the routing and orchestration-engine documentation [NOT STARTED]

**Goal**: Rewrite the documents that describe hard-mode routing and the orchestration engine so
they describe the post-deletion architecture. These are the highest-density and most load-bearing
references: read as live behavioral claims, they become false the moment Phase 4 lands.

**Tasks**:
- [ ] `skills/skill-orchestrate/SKILL.md` — rewrite references to the deleted engine and agents.
      Many are provenance comments explaining what was migrated *from* `skill-orchestrate-hard`;
      keep the explanation, drop the implication that the source file still exists (e.g. phrase as
      "the superseded hard engine" rather than a live path).
- [ ] `commands/orchestrate.md` — remove `skill-orchestrate-hard` from the `--hard` dispatch
      description; `--hard` now sets `hard_mode` inside `skill-orchestrate`.
- [ ] `merge-sources/claudemd.md` — remove the four deleted skill/agent rows from the
      Skill-to-Agent Mapping table and any hard-routing prose naming them. This is the source of
      the generated `.claude/CLAUDE.md`, which currently lists all four as live skills.
- [ ] `context/guides/hard-mode-routing.md` — the routing table's three
      "Core manifest routing_hard + Step 4e fallback" rows and the `skill-orchestrate-hard`
      row are now wrong. Rewrite for the single-engine model.
- [ ] `context/guides/manifest-routing-schema.md` — update the two examples and the consumer list.
- [ ] `docs/architecture/handoff-schema.md` — the "Read by" line, the Handoff Writers table
      (which names `general-implementation-hard-agent.md` as "the only writer"), and the Stage
      4/5 reader citations all need retargeting to the surviving writer/reader.
- [ ] `docs/architecture/batch-admit-schema.md` and `docs/architecture/orchestrate-state-machine.md`
      — retarget engine citations.
- [ ] `context/reference/orchestrator-critical-paths.json` — remove or retarget the deleted path.
- [ ] `docs/reference/utility-scripts-inventory.md` — retarget its one citation.

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

### Phase 7: De-reference contracts, patterns, standards, and script comments [NOT STARTED]

**Goal**: Sweep the long tail — contract files, pattern docs, standards, format docs, and inline
script comments — plus the one surviving *live* code reference outside the manifests.

**Tasks**:
- [ ] `scripts/skill-base.sh` — line ~889 is a live `case` arm mapping `[hard-orchestrate]` to
      `skills/skill-orchestrate-hard/SKILL.md` as `gate_attributed_path`. This is executable, not a
      comment: decide whether the `[hard-orchestrate]` label is still reachable and either
      retarget the path to `skill-orchestrate/SKILL.md` or remove the arm. Handle the file's four
      comment references separately.
- [ ] `scripts/command-route-agent.sh`, `scripts/validate-handoff.sh`,
      `scripts/update-task-status.sh`, `scripts/orchestrate-stage5-gates.sh`,
      `scripts/orchestrate-stage5-postflight.sh`, `scripts/check-extension-docs.sh` — comment-only
      references; retarget to the surviving engine.
- [ ] `context/contracts/` — `anti-analysis.md`, `orchestrator-discipline.md`, `recovery.md`,
      `territory.md`, `wrap-up.md`, `phase-closure.md`, `pre-edit-gate.md`,
      `no-task-references-bullet.md`. These name the deleted skills/agents as their consumers;
      rewrite the consumer lists to name the engine and the surviving agents.
- [ ] `context/patterns/` — `skill-lifecycle.md` (its Autonomous Loop table and the three
      skill-pair lines), `task-lock.md`, `checkpoint-before-overflow.md`,
      `batch-orchestration-guardrails.md`, `system-defect-discrimination.md`,
      `infra-failure-discrimination.md`, `dispatch-report-not-termination.md`.
- [ ] `context/standards/orchestrator-runtime-files.md`, `context/standards/task-reference-exemptions.md`,
      `context/architecture/context-layers.md`, `context/formats/plan-format.md` (its
      `{{FOLLOWUP:i}}` substitution owner and resume-scan citations name `skill-planner-hard` and
      `skill-implementer-hard` — retarget to whichever component now owns each).
- [ ] `agent-system/extensions/cslib/README.md`,
      `cslib/context/contracts/adversarial-verification.md`,
      `cslib/skills/skill-cslib-implementation-hard/SKILL.md`,
      `lean/skills/skill-lean-implementation-hard/SKILL.md`,
      `lean/context/project/lean4/domain/hard-mode.md` — extension-side citations of the deleted
      core assets.

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

### Phase 8: Zero-hit confirmation, full gate run, and deploy refresh [NOT STARTED]

**Goal**: Discharge the task's own stated completion criterion and confirm the system is no worse
off than the Phase 1 baseline.

**Tasks**:
- [ ] Re-run the Phase 1 census grep over `agent-system/` for all seven names and confirm **zero
      hits**. Write the result to `.reference-census-after.txt` and diff against
      `.reference-census-before.txt`.
- [ ] Run the identical repo-wide grep excluding `specs/` and confirm zero hits outside this
      task's own artifacts — the charter's explicit completion gate.
- [ ] Confirm `git diff` on `agent-system/extensions/lean/manifest.json` is empty.
- [ ] Confirm cslib's and lean's four-plus-four `-hard` assets still exist on disk and are still
      routed by their manifests.
- [ ] Run the full gate set: `scripts/tests/run-all.sh`, all eight lints in `scripts/lint/`,
      `scripts/check-extension-docs.sh`, `scripts/verify-deploy.sh`. Compare against
      `.gate-baseline-before.txt`; any failure must be either pre-existing in the baseline or
      fixed before the task closes.
- [ ] Regenerate the `.claude/` deploy artifact so the runtime stops advertising four deleted
      skills (the current `.claude/CLAUDE.md` Skill-to-Agent Mapping still lists all four, and
      `.claude/skills/`, `.claude/agents/` still hold the deleted copies). Confirm the deployed
      tree no longer contains any of the seven paths.
- [ ] Note in the summary that `verify-deploy.sh` gate 16 will still warn while cslib and lean
      declare `routing_hard`/`routing_agents_hard` — that residue is task 127's scope, not a
      failure of this task.

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

- [ ] All eight scripts in `agent-system/extensions/core/scripts/lint/` exit 0 with no new
      failures versus the Phase 1 baseline.
- [ ] `scripts/tests/run-all.sh` shows no regression versus the Phase 1 baseline.
- [ ] `scripts/tests/test-routing-resolution.sh` passes with core's hard blocks removed and
      cslib's partially removed.
- [ ] `scripts/tests/test-index-entries-schema.sh` passes after the `agents[]` pruning.
- [ ] `scripts/check-extension-docs.sh` reports no unresolvable or undeployed `routing_hard`
      target.
- [ ] `scripts/verify-deploy.sh` passes (gate 16's cslib/lean warning is expected and out of scope).
- [ ] Repo-wide grep for the seven names returns zero hits outside `specs/`.
- [ ] `/orchestrate --hard` still resolves: standard agents for `general`/`meta`/`markdown` with
      contract injection, `cslib-*-hard-agent` for `cslib`, `lean-*-hard-agent` for `lean4`.

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

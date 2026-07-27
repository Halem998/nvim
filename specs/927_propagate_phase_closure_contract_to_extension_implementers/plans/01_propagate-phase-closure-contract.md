# Implementation Plan: Task #927

- **Task**: 927 - Propagate the depth-first phase-closure and pre-edit verification contract to extension implementers
- **Status**: [IMPLEMENTING]
- **Effort**: 2.75 hours
- **Dependencies**: 925 (contracts authored, core-only) — complete; 919 (`## Context References` sections added to overlapping agent files) — complete and merged
- **Research Inputs**: `specs/927_propagate_phase_closure_contract_to_extension_implementers/reports/01_propagate-phase-closure-contract.md`
- **Artifacts**: plans/01_propagate-phase-closure-contract.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two core contracts — `contracts/phase-closure.md` (depth-first close-before-open) and
`contracts/pre-edit-gate.md` (per-item evidence before applying a mechanical-list edit) — currently
reach only core's four implementer files. Because contract loading in this codebase is driven by an
explicit `@`-reference bullet in a consumer's `## Context References` section (directory placement in
`context/contracts/` is a naming convention only, and no central injection point exists), extension
implementers do not receive them. This plan adds one single-line pointer bullet per contract per
consuming file — never a prose copy — across the non-core extension implementer surface, then
refreshes the three places that enumerate the contracts' referrers so those enumerations stay honest.

**Definition of done**: every non-core extension implementer agent that runs a plan-phase loop carries
both pointer bullets inside its existing `## Context References` section; the two documented exclusions
are recorded with evidence rather than silently skipped; no prose from either contract is duplicated
anywhere; every edit lands in `agent-system/extensions/**`.

### Source-Store Rule (binding, applies to every phase)

The agent-system SOURCE of truth is `agent-system/extensions/`. The `.claude/` tree is a **gitignored,
disposable deploy artifact**. ALL edits MUST target `agent-system/extensions/**` and NEVER `.claude/**`.
Reads from `.claude/` are permitted for cross-checking deployed state; writes are not.

Note the resulting asymmetry, which is intentional and must not be "corrected": the **edit lands** in
`agent-system/extensions/{ext}/agents/*.md`, but the **bullet text written into it** names the
*deploy-time* path `.claude/context/contracts/phase-closure.md`. That is exactly what core's own
referrers and the `cslib-implementation-hard-agent.md` precedent already do — the source-store files
are literal copies of what gets deployed, so `@`-reference text is always written against the deployed
path.

### Research Integration

Key findings carried into this plan:
- Propagation is genuinely required; this task does **not** close as unnecessary. `skill-base.sh`'s
  `context_injection` hook runs extension -> core, the wrong direction for a core contract to reach
  extension implementers.
- The referencing mechanism already exists in-repo twice and must be **reused, not invented**:
  `cslib-implementation-hard-agent.md`'s `@`-bullets to core's `anti-analysis.md`/`wrap-up.md`/
  `territory.md`, and core's `skill-implementer{,-hard}/SKILL.md` `Path:` bullets.
- Six overlapping files already have a `## Context References` section created by the completed
  sibling effort; new bullets must land **inside** it, never as a duplicate section.
- Two agents have no `### Phase N [STATUS]` loop and are reasoned exclusions, not silent skips.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied and no ROADMAP.md consulted for this task.

## Goals & Non-Goals

**Goals**:
- Every non-core extension implementer agent with a plan-phase loop carries a one-line pointer bullet
  to each of the two contracts, inside its existing `## Context References` section.
- Where an extension skill file already maintains its own contract-bullet list, a matching
  discoverability bullet pair is added there too.
- The two agents with no phase-loop structure are excluded with a recorded `#### Reasoned Exclusions`
  entry carrying evidence — never silently skipped.
- The three documents that enumerate the contracts' referrers are updated to remain accurate without
  hardcoding a per-file list that will rot.

**Non-Goals**:
- No new indirection layer, alias file, shared-include mechanism, or injection hook. The existing
  pointer-bullet convention already solves the "don't repeat prose" problem.
- No prose from `phase-closure.md` or `pre-edit-gate.md` is copied into any consumer file.
- No edits to `.claude/**` (gitignored deploy artifact).
- No changes to the contracts' substantive content — only their referrer-enumeration sentences.
- No changes to extension `manifest.json` routing, `index.json` entries, or any skill dispatch logic.
- No changes to the six overlapping files' existing bullets from the sibling effort.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer copies contract prose instead of a pointer bullet, recreating the exact maintenance defect this task exists to remove | H | M | The verbatim bullet text is stated in this plan (Phase 2/3/4 below) — wording is not left to implementer discretion. Phase 6 greps for prose leakage. |
| A duplicate `## Context References` section is created in one of the six files the sibling effort already touched | M | M | Phase 1 probes every target's current section count before any edit; Phase 6 re-asserts exactly one section per file. |
| `phase-closure.md` over-applied to the two agents with no phase loop, yielding a contract reference with nothing to govern | M | L | Exclusions are decided explicitly in Phase 1 and recorded in a `#### Reasoned Exclusions` table with grep evidence. |
| Edits land in `.claude/**` and are silently lost on next deploy | H | L | Source-store rule restated in every phase; Phase 6 asserts `git status` shows zero `.claude/` modifications. |
| Research's asserted file count (14) does not match the real glob (15) | L | H (already observed) | Phase 1 carries a `Scope Hypothesis` requiring the implementer to re-enumerate from the filesystem, not from this plan's numbers. |
| Task-number citations leak into files outside `specs/**` | M | L | Referrer-enumeration edits in Phase 5 use durable anchors (file/section names) only; Phase 6 greps for `task N` patterns in the diff. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |
| 4 | 6 | 5 |

Phases within the same wave can execute in parallel. Phases 2, 3, and 4 touch disjoint file sets
(standard agents / hard agents / one skill file) and may be dispatched concurrently with explicit
territory ownership.

---

### Phase 1: Pre-edit probe and exclusion ledger [COMPLETED]

**Goal**: Establish the real, filesystem-confirmed edit surface and close the two exclusion decisions
with evidence, before any file is modified.

**Tasks**:
- [x] Enumerate the non-core implementer agent surface from the filesystem:
      `ls agent-system/extensions/*/agents/*implement*.md`, excluding `core/`. Record the actual count.
      *(completed: 15 files, matches Scope Hypothesis)*
- [x] For each enumerated file, record: count of `^## Context References` headings, count of
      `contracts/phase-closure.md` occurrences, count of `contracts/pre-edit-gate.md` occurrences.
      Any file with a count other than exactly one `## Context References` heading is a stop-and-report
      condition, not a file to guess at. *(completed: all 15 files have exactly one `## Context
      References` heading and zero pre-existing contract-bullet occurrences)*
- [x] For each enumerated file, probe for plan-phase-loop structure by grepping for the phase-heading
      vocabulary (`[NOT STARTED]` / `[IN PROGRESS]` on a phase heading, `for each phase`,
      `Phase Checkpoint Protocol`). Classify each file as phase-loop-present or phase-loop-absent.
      *(completed: 13 phase-loop-present, 2 phase-loop-absent — `pr-review-implementation-agent.md`
      and `email-implementation-agent.md`)*
- [x] Enumerate extension skill files that already carry their own contract-bullet list:
      `grep -l 'contracts/' agent-system/extensions/*/skills/*implement*/SKILL.md`. Any skill file with
      no existing contract-bullet list is out of scope (it is a thin dispatcher). *(completed: exactly
      one non-core hit, `cslib/skills/skill-cslib-implementation-hard/SKILL.md`)*
- [x] Decide and record the two exclusions in the `#### Reasoned Exclusions` table below, with the
      grep evidence gathered above. Decide `pre-edit-gate.md` applicability **independently** of
      `phase-closure.md` for each excluded file rather than excluding both by association.
      *(completed: table populated with implementation-time evidence)*
- [x] If the filesystem enumeration diverges from this plan's stated counts, update the phase bodies
      below to match the filesystem and note the divergence — the filesystem wins. *(completed: no
      divergence found; plan-time and implementation-time counts match exactly, recorded in the
      "Filesystem reconciliation" note below the exclusions table)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This plan asserts **15** non-core implementer agent files across **12** non-core
extensions (`cslib` x3, `lean` x2, and one each for `email`, `epidemiology`, `founder`, `latex`, `nix`,
`nvim`, `python`, `typst`, `web`, `z3`), of which **13** have a plan-phase loop and **2** do not; plus
**1** extension skill file carrying its own contract-bullet list
(`cslib/skills/skill-cslib-implementation-hard/SKILL.md`). The research report states fourteen agent
files, which is one short of the glob result — treat both numbers as unconfirmed. Confirm by direct
`ls`/`grep` at implementation time and adjust the phase bodies below to the filesystem result. Do not
proceed to Phase 2 on this plan's numbers alone.

**Files to modify**:
- `specs/927_propagate_phase_closure_contract_to_extension_implementers/plans/01_propagate-phase-closure-contract.md` - fill in the `#### Reasoned Exclusions` table with implementation-time evidence; correct any count divergence

**Verification**:
- The recorded enumeration is reproducible from a single `ls` plus per-file `grep -c` output pasted
  into the exclusion table's Evidence column.
- Every enumerated agent file has exactly one `## Context References` heading, or the divergence is
  reported rather than worked around.
- Both exclusion rows are populated with a Reason and an Evidence value; neither is left as a
  placeholder.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| `cslib/agents/pr-review-implementation-agent.md` — `phase-closure.md` | The agent has no plan-phase loop for a close-before-open contract to govern; it composes PR/Zulip response files in a single stage. A pointer here would reference a contract with nothing in the file for it to apply to. | `grep -ci 'phase' agent-system/extensions/cslib/agents/pr-review-implementation-agent.md` returns 0. The file's stage headings (`## Stage 0` through `## Stage 8`, e.g. `Stage 5: Compose pr-response.md`, `Stage 6: Compose zulip-response.md`) are a single linear sequence with no `### Phase N [STATUS]` loop or resume logic. |
| `cslib/agents/pr-review-implementation-agent.md` — `pre-edit-gate.md` | Judged independently of the row above, not by association. The agent's output is composed prose response files, not edits applied from a mechanically-generated candidate list (a plan file list, grep result set, or scan count). The contract's "probe before edit" ladder has no matching edit class here. | The file's `## Context References` section (lines 26-30) carries a single bullet — `return-metadata-file.md` — confirming no mechanical-list-edit workflow is documented for this agent. |
| `email/agents/email-implementation-agent.md` — `phase-closure.md` | No `### Phase N [STATUS]` loop; the agent executes plan "Steps" in a single pass via wrapper binaries. | `grep -ci 'phase' agent-system/extensions/email/agents/email-implementation-agent.md` returns 1: line 125, "Read the plan file; identify the current phase and its steps (census, classify, review-gate, ...)" — a single-pass description, not a `[NOT STARTED]`/`[IN PROGRESS]`/`[COMPLETED]` phase-heading loop. |
| `email/agents/email-implementation-agent.md` — `pre-edit-gate.md` | Judged independently. The domain's propose-review-confirm-execute manifest gate (`patterns/propose-review-confirm-execute.md`, already referenced in this agent's `## Context References`) is a stricter, domain-specific superset of the generic pre-edit gate. Adding a second, weaker generic gate alongside it presents two overlapping gates where one authoritative gate exists — a net loss in clarity for a mutation-critical agent. | The agent's `## Context References` section already carries `` `@.claude/context/project/email/patterns/propose-review-confirm-execute.md` - Manifest lifecycle `` (confirmed present), whose `--confirm-manifest <sha256>` gate over a human-reviewed manifest is strictly stronger than the generic per-item evidence ladder. |

**Filesystem reconciliation**: the plan-time Scope Hypothesis (15 non-core implementer agent files across 12 extensions, 13 phase-loop-present / 2 phase-loop-absent, 1 extension skill file with an existing contract-bullet list) matches the implementation-time filesystem enumeration exactly — no divergence to report. `ls agent-system/extensions/*/agents/*implement*.md | grep -v '/core/'` returns 15 files; every file has exactly one `## Context References` heading and zero pre-existing `contracts/phase-closure.md` / `contracts/pre-edit-gate.md` occurrences; `grep -l 'contracts/' agent-system/extensions/*/skills/*implement*/SKILL.md` (excluding core) returns exactly `cslib/skills/skill-cslib-implementation-hard/SKILL.md`.

---

### Phase 2: Propagate to standard-mode extension implementer agents [COMPLETED]

**Goal**: Add both pointer bullets to every standard-mode (non-hard) extension implementer agent that
has a plan-phase loop.

**Target files** (confirm against Phase 1's enumeration before editing):
`cslib/agents/cslib-implementation-agent.md`, `epidemiology/agents/epi-implement-agent.md`,
`founder/agents/founder-implement-agent.md`, `latex/agents/latex-implementation-agent.md`,
`lean/agents/lean-implementation-agent.md`, `nix/agents/nix-implementation-agent.md`,
`nvim/agents/neovim-implementation-agent.md`, `python/agents/python-implementation-agent.md`,
`typst/agents/typst-implementation-agent.md`, `web/agents/web-implementation-agent.md`,
`z3/agents/z3-implementation-agent.md` — all under `agent-system/extensions/`.

**Bullet text (verbatim — do not paraphrase, do not expand into prose)**:

```
- `@.claude/context/contracts/phase-closure.md` - depth-first phase closure: close one phase before opening the next (always load)
- `@.claude/context/contracts/pre-edit-gate.md` - per-item evidence before applying a mechanical-list edit (always load)
```

This matches `core/agents/general-implementation-agent.md`'s existing two bullets character-for-character.

**Placement rule (deterministic)**: insert the two bullets, adjacent and in the order above, as the
last two bullets of the file's existing `## Context References` list — **except** where that list ends
with trailing catch-all lines of the form `- For {something} tasks: ...`, in which case insert
immediately before the first such catch-all line. Never create a second `## Context References`
heading. Never reorder or reword any pre-existing bullet.

**Tasks**:
- [x] For each target file: re-grep its `## Context References` heading count and its current
      `contracts/phase-closure.md` / `contracts/pre-edit-gate.md` counts immediately before editing
      (per-item evidence, per the very contract being propagated). Skip-and-report any file already
      carrying either bullet rather than adding a duplicate. *(completed: all 11 files confirmed
      one `## Context References` heading, zero pre-existing contract bullets, per Phase 1's table)*
- [x] Apply the two bullets per the placement rule above. *(completed: all 11 files)*
- [x] Confirm the edit landed in `agent-system/extensions/**` and not in `.claude/**`. *(completed:
      all edits via Edit tool targeted `agent-system/extensions/**` paths only)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts **11** target files, enumerated above. The count and the list
are a hypothesis from a plan-time glob, not a fact. Confirm each path exists and each has a plan-phase
loop using Phase 1's recorded classification before editing; add or drop files to match.

**Files to modify**:
- The 11 agent files listed above - two pointer bullets appended into the existing
  `## Context References` section; no other change

**Verification**:
- `grep -c 'contracts/phase-closure.md'` returns 1 for each target file; same for
  `contracts/pre-edit-gate.md`.
- `grep -c '^## Context References'` still returns exactly 1 for each target file.
- The diff for each file shows exactly two added lines and zero removed lines.
- Every added line is a single bullet; no multi-line prose block was added.

---

### Phase 3: Propagate to hard-mode extension implementer agents [COMPLETED]

**Goal**: Add both pointer bullets to the hard-mode extension implementer agents, using the
hard-mode annotation convention already established by core's hard agent.

**Target files** (confirm against Phase 1's enumeration before editing):
`cslib/agents/cslib-implementation-hard-agent.md`, `lean/agents/lean-implementation-hard-agent.md` —
both under `agent-system/extensions/`.

**Bullet text (verbatim)**:

```
- `@.claude/context/contracts/phase-closure.md` - depth-first phase closure: close one phase before opening the next (MANDATORY)
- `@.claude/context/contracts/pre-edit-gate.md` - per-item evidence before applying a mechanical-list edit (MANDATORY)
```

This matches `core/agents/general-implementation-hard-agent.md`'s existing two bullets
character-for-character. The `(MANDATORY)` suffix — rather than `(always load)` — is the hard-mode
convention already used by the sibling `anti-analysis.md` / `wrap-up.md` / `recovery.md` bullets in
`cslib-implementation-hard-agent.md`.

**Placement rule**: `cslib-implementation-hard-agent.md` already carries a contiguous run of
`@.claude/context/contracts/...` bullets — insert the two new bullets at the end of that contiguous
contracts run, so all contract bullets stay grouped. For `lean-implementation-hard-agent.md`, apply
Phase 2's general placement rule (end of list, before any `- For {something} tasks:` catch-all).

**Tasks**:
- [x] Re-grep each target's `## Context References` heading count and existing contract-bullet counts
      immediately before editing. *(completed: both files at 1 heading, 0 pre-existing bullets)*
- [x] Apply the two bullets per the placement rules above. *(completed: cslib inserted at end of
      contiguous contracts run after `territory.md`; lean inserted at end of list before the next
      heading)*
- [x] Confirm the edits landed in `agent-system/extensions/**`. *(completed)*

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly **2** hard-mode extension implementer agents
(`cslib`, `lean`). Confirm via `ls agent-system/extensions/*/agents/*implementation-hard-agent.md`
plus Phase 1's classification before editing; a third hard-mode implementer, if present, joins this
phase rather than being skipped.

**Files to modify**:
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` - two pointer bullets at
  the end of the existing contracts bullet run
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` - two pointer bullets in the
  existing `## Context References` section

**Verification**:
- Both files return 1 for `grep -c 'contracts/phase-closure.md'` and for
  `grep -c 'contracts/pre-edit-gate.md'`.
- `cslib-implementation-hard-agent.md`'s contract bullets remain contiguous (no unrelated bullet
  interleaved into the run).
- Each file's diff shows exactly two added lines, zero removed.

---

### Phase 4: Skill-file discoverability bullets [COMPLETED]

**Goal**: Add matching discoverability bullets to the one extension skill file that already maintains
its own contract-bullet list, mirroring what core's `skill-implementer{,-hard}/SKILL.md` do.

**Target file** (confirm against Phase 1's skill enumeration):
`agent-system/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md`.

**Bullet text (verbatim)**:

```
- Path: `.claude/context/contracts/phase-closure.md` - depth-first phase closure: close one phase before opening the next (loaded by agent)
- Path: `.claude/context/contracts/pre-edit-gate.md` - per-item evidence before applying a mechanical-list edit (loaded by agent)
```

This matches `core/skills/skill-implementer-hard/SKILL.md`'s existing two `Path:` bullets
character-for-character. The `(loaded by agent)` suffix is load-bearing: these are discoverability
pointers, and the actual loading is the agent's job — matching what both contracts' own headers state.

**Placement rule**: append at the end of the file's existing contiguous `- Path: ...contracts/...`
bullet run, keeping contract entries grouped.

**Tasks**:
- [x] Re-grep the target's existing `contracts/` bullet lines immediately before editing.
      *(completed: existing contiguous run was `anti-analysis.md`/`wrap-up.md`/`territory.md`)*
- [x] Apply the two `Path:` bullets at the end of the contracts run. *(completed)*
- [x] Confirm no other extension skill file carries a contract-bullet list (per Phase 1's enumeration);
      thin dispatcher skills stay untouched. *(completed: `grep -l 'contracts/'` over all non-core
      extension implement skill files returns only this one file)*

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly **1** extension skill file with an existing
contract-bullet list. Confirm via
`grep -l 'contracts/' agent-system/extensions/*/skills/*implement*/SKILL.md` before editing. If the
grep returns more than one, each additional hit joins this phase; if it returns none for the asserted
path, stop and report rather than creating a new bullet list in a thin dispatcher.

**Files to modify**:
- `agent-system/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md` - two `Path:`
  discoverability bullets

**Verification**:
- `grep -c 'contracts/phase-closure.md'` returns 1 for the target; same for `pre-edit-gate.md`.
- The diff shows exactly two added lines, zero removed.
- No other `agent-system/extensions/*/skills/**/SKILL.md` file was modified.

---

### Phase 5: Refresh the referrer enumerations [COMPLETED]

**Goal**: Update the three documents that enumerate which files reference these contracts, so their
statements remain true after propagation — without hardcoding a per-file list that will rot on the next
extension added.

**Tasks**:
- [x] In `agent-system/extensions/core/context/contracts/phase-closure.md`, under its
      `## Loaded via explicit reference in BOTH modes` section, extend the referrer sentence (which
      today names only the four core files) with a **non-enumerating** clause covering the extension
      surface — e.g. that it is additionally referenced from every non-core extension implementer agent
      that runs a plan-phase loop, and from any extension skill maintaining its own contract-bullet
      list. Do not paste a fourteen-path list. *(completed)*
- [x] Apply the same edit to
      `agent-system/extensions/core/context/contracts/pre-edit-gate.md`'s equivalent section.
      *(completed)*
- [x] In `agent-system/extensions/core/context/architecture/context-layers.md`, update Finding (i)'s
      closing sentence (which today asserts both contracts are referenced from the four core files
      "alike") so it does not read as an exhaustive list. Leave Finding (ii) and the **Consequence**
      paragraph substantively intact — they remain true, and the `cslib-implementation-hard-agent.md`
      precedent named there is still the durable example. *(completed: Finding (ii) and Consequence
      left byte-for-byte unchanged; only Finding (i)'s closing sentence was edited)*
- [x] Verify no task-number citation (`task N`, `tasks N-M`, `(task N)`) was introduced in any of the
      three files. Cite durable anchors — file names and section headings — only. *(completed:
      `grep -inE '\btasks? [0-9]+'` over the diff returns no matches)*

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly **3** documents carry a referrer enumeration needing
refresh. Confirm by grepping the source store for other files naming both contracts:
`grep -rln 'phase-closure.md' agent-system/extensions/ | grep -v '/agents/\|/skills/'`. Any additional
hit is evaluated and either updated or recorded as needing no change. *(confirmed at implementation
time: the grep returns exactly the 3 asserted documents plus one incidental 4th hit,
`core/index-entries.json` — a mechanical index-entry `"path": "contracts/phase-closure.md"` field,
not a prose referrer-enumeration sentence. Evaluated and recorded as needing no change.)*

**Files to modify**:
- `agent-system/extensions/core/context/contracts/phase-closure.md` - referrer sentence generalized
- `agent-system/extensions/core/context/contracts/pre-edit-gate.md` - referrer sentence generalized
- `agent-system/extensions/core/context/architecture/context-layers.md` - Finding (i) closing sentence
  de-exhausted

**Verification**:
- Each of the three files still reads correctly end-to-end; the edited sentence is grammatical and
  does not contradict the surrounding paragraph.
- No absolute per-file path list of extension agents was added to any of the three.
- `grep -inE '\btasks? [0-9]+' ` over the three files returns no new matches.

---

### Phase 6: Consistency sweep and anti-copy-paste audit [COMPLETED]

**Goal**: Confirm the propagation is uniform, pointer-only, source-store-only, and free of the
duplicate-section and prose-copy failure modes this task exists to avoid.

**Tasks**:
- [x] Assert bullet coverage: for every agent file classified phase-loop-present in Phase 1,
      `grep -c 'contracts/phase-closure.md'` and `grep -c 'contracts/pre-edit-gate.md'` each return 1.
      *(PASS: all 13 phase-loop-present files return 1/1)*
- [x] Assert exclusions held: the two excluded agent files return 0 for both greps, and the
      `#### Reasoned Exclusions` table in this plan is fully populated with evidence.
      *(PASS: both excluded files return 0/0; table populated)*
- [x] Assert no duplicate sections: `grep -c '^## Context References'` returns exactly 1 for every
      touched agent file. *(PASS: all 14 touched files return 1)*
- [x] Assert pointer-only propagation (the core anti-copy-paste check): grep the touched files for
      distinctive phrases from the contracts' bodies (`close-before-open`, `cheapest-closure-first`,
      `stop-at-a-closed-boundary`, `Probe before edit`, `A planning-time list is a hypothesis`). Any
      hit outside `core/context/contracts/` and outside this plan indicates prose was copied and must
      be reverted to a bullet. *(PASS with one pre-existing, out-of-scope hit noted:
      `core/index-entries.json` contains "cheapest-closure-first" in a `summary` metadata field
      registered by a prior task (925) when the contract was first authored — this file was not
      touched by this task's Phase 2-5 edits (confirmed via `git diff --stat` showing no changes)
      and is not one of the 14 propagation-target consumer files; it is index metadata describing
      the contract, not a consumer-file prose copy, so it is out of this audit's scope. No hits
      found in any of the 14 touched agent/skill files.)*
- [x] Assert source-store discipline: `git status --short` shows zero modifications under `.claude/`.
      *(PASS: no `.claude/` entries in git status)*
- [x] Assert no task-number citations: grep the full diff for `task [0-9]`, `tasks [0-9]` outside
      `specs/**`. *(PASS: no matches in `agent-system/` diff across all phase commits)*
- [x] Assert diff shape: total added lines across Phases 2-4 equals two per touched file; no file shows
      removed lines. *(PASS: 14 files x 2 lines = 28 insertions, 0 deletions, confirmed via
      `git diff --stat` across the Phase 2-4 commit range)*

**Timing**: 0.25 hours

**Depends on**: 5

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts a touched-file set of **14** (11 standard agents + 2 hard
agents + 1 skill file) plus **3** documentation files, and **2** excluded agent files. All three counts
derive from Phase 1's filesystem enumeration, not from this plan — re-read Phase 1's recorded result
and audit against that, not against these numbers.

**Files to modify**:
- None (audit only). Any defect found is fixed in the owning phase and re-audited.

**Verification**:
- All seven assertions above pass, with command output recorded in the implementation summary.
- Any assertion that fails is fixed and the full sweep re-run, not partially re-run.

---

## Testing & Validation

- [x] Every phase-loop-present non-core extension implementer agent carries exactly one
      `phase-closure.md` bullet and exactly one `pre-edit-gate.md` bullet.
- [x] Every touched agent file has exactly one `## Context References` heading (no duplicate section
      introduced alongside the sibling effort's).
- [x] The six files overlapping the completed sibling effort retain their pre-existing bullets
      unchanged; the diff on those files shows additions only (confirmed: every touched file's diff
      is additions-only, 2 lines each, 0 removed).
- [x] No contract prose appears outside `agent-system/extensions/core/context/contracts/` (in any of
      the 14 propagation-target files; the one incidental `index-entries.json` metadata hit predates
      this task and is out of scope, see Phase 6's audit note).
- [x] `git status --short` shows zero modified paths under `.claude/`.
- [x] The two exclusions are documented in this plan's `#### Reasoned Exclusions` table with evidence,
      and neither excluded file was modified.
- [x] No file outside `specs/**` gained a task-number citation.

## Artifacts & Outputs

- 11 modified standard-mode extension implementer agent files under `agent-system/extensions/*/agents/`
- 2 modified hard-mode extension implementer agent files under `agent-system/extensions/*/agents/`
- 1 modified extension skill file:
  `agent-system/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md`
- 3 modified core documentation files: `core/context/contracts/phase-closure.md`,
  `core/context/contracts/pre-edit-gate.md`, `core/context/architecture/context-layers.md`
- This plan file, with its `#### Reasoned Exclusions` table populated at implementation time
- An implementation summary at
  `specs/927_propagate_phase_closure_contract_to_extension_implementers/summaries/01_propagate-phase-closure-contract-summary.md`

## Rollback/Contingency

Every edit is a two-line additive insertion into an existing markdown bullet list, with no code,
schema, or routing change — so rollback is a plain `git revert` of the phase commits, or a per-file
`git checkout HEAD~N -- <path>` for a single bad file. Because Phases 2, 3, and 4 own disjoint file
sets and commit per sub-step, a defect in one phase can be reverted without disturbing the others.
Phase 5's documentation edits are independently revertible and carry no behavioral coupling: reverting
them leaves the propagation bullets in place and merely restores a now-incomplete referrer sentence.
If the propagation must be abandoned entirely, reverting all phase commits restores the pre-task state
with no residue, since nothing in this task creates files, directories, or state entries.

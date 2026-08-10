# Implementation Plan: Task #844 — Finish or Defer the Zotero/Cite Install

- **Task**: 844 - Finish or formally defer the incomplete literature-extension install
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: task 841 (drift guard / quarantine rule — already merged), task 842 (convert pipeline — already merged)
- **Research Inputs**: specs/844_finish_or_defer_zotero_cite_install/reports/01_install-status-research.md
- **Artifacts**: plans/01_install-plan.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/rules/state-management.md
  - .claude/rules/artifact-formats.md
- **Type**: meta

## Overview

The literature extension's zotero/cite surface is in an internally-inconsistent state: eleven
extension-source artifacts split into three dispositions that the research report established with
git provenance and live-reference analysis. This plan brings the surface to a consistent state by
(a) **activating** the genuinely-unfinished `/cite` trio and the already-load-bearing
`zotero-search.sh` — deploying them byte-for-byte from `.claude/extensions/literature/` to their
deployed locations so the task-841 drift guard passes — and (b) **formally deferring-and-documenting**
the remaining seven zotero scripts plus the `test-lit-pipeline.sh` harness with an explicit
inactive-status note, so they stop reading as accidental drift. Definition of done:
`check-extension-docs.sh` literature section PASSes with zero new failures and zero drift-guard
false-failures, the `/cite` command is deployed and its wiring resolves, activated scripts are
byte-identical to source, and the defer note names every inactive artifact with its reason.

### Research Integration

Key findings from `reports/01_install-status-research.md` driving this plan:

- **Three groups, not one.** ACTIVATE = `/cite` trio (`cite-extract.sh` + `skill-cite` + `cite.md`,
  built end-to-end across tasks 716/717/718, never deployed only because no plan scoped a deploy
  step) plus `zotero-search.sh` (already live via a source-path fallback in `skill-literature/SKILL.md`,
  zero external dependency). DEFER-AND-DOCUMENT = `zotero-index-add.sh`/`zotero-index-remove.sh`
  (dead code, superseded by inline `jq` in `skill-literature/SKILL.md`) and
  `zotero-read.sh`/`zotero-write.sh`/`zotero-setup.sh`/`zotero-chunk.sh`/`zotero-attach-chunks.sh`
  (no live callers; depend on the external `zot` CLI which is NOT installed). NEVER DEPLOY =
  `test-lit-pipeline.sh` (a test harness per its own header).
- **The manifest already declares everything.** `.claude/extensions/literature/manifest.json`
  `provides.scripts` already lists `cite-extract.sh` and `zotero-search.sh`; `provides.commands`
  lists `cite.md`; `provides.skills` lists `skill-cite`. Therefore "register in the manifest" is
  already satisfied — the activate phases are pure deployment (file copies) plus verification, with
  **no manifest edits**.
- **The drift guard tolerates absent deployed copies.** `check-extension-docs.sh`
  `check_deployed_script_drift()` emits `info "script not deployed, skipping drift check"` (never
  `FAIL`) when the deployed copy is absent, and only `FAIL`s on *content mismatch* when both copies
  exist. So DEFER items left undeployed while still declared in `provides.scripts` do NOT trip the
  guard; ACTIVATE items must be byte-identical post-deploy.
- **skill-cite is direct-execution** (`cite.md`: "Delegates To: skill-cite (direct execution)"; no
  `subagent_type` in its SKILL.md). So deploying it does NOT trigger the guard's Rule D
  (`check_deployed_skill_agents`, which only fires for a `subagent_type` naming a missing agent).
  `routing`/`routing_hard` are both `null`, so no routing-consistency risk either.
- **CLAUDE.md is generated ("Do not edit directly").** The literature merge-source `EXTENSION.md`
  already lists `skill-cite` and `/cite` in its skill-mapping and command tables. The central
  generated `CLAUDE.md` Skill-to-Agent Mapping table omitting `skill-cite` is a downstream symptom
  of the extensions.json tracking gap (see below), not a hand-edit target.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this dispatch (roadmap flag not set).

## Goals & Non-Goals

**Goals**:
- Deploy the `/cite` trio (`cite-extract.sh`, `skill-cite/`, `cite.md`) from extension source to the
  deployed tree so the feature is live and its wiring resolves.
- Deploy `zotero-search.sh` for consistency with its existing live source-path fallback.
- Ensure all activated files are byte-identical to their extension-source counterparts (drift guard
  green).
- Add an explicit defer-and-document status note naming each of the eight inactive artifacts with its
  reason.
- Document the `.claude/extensions.json` literature-tracking gap as a known issue with a named
  follow-up, without fabricating loader-managed state.
- Leave `check-extension-docs.sh` literature section at PASS with no new failures.

**Non-Goals**:
- Do NOT deploy the seven deferred zotero scripts or `test-lit-pipeline.sh`.
- Do NOT prune / delete the dead-code `zotero-index-add.sh` / `zotero-index-remove.sh`
  (quarantine-never-delete; pruning is a separate future task).
- Do NOT hand-author a full `.claude/extensions.json` entry for the literature extension (loader-owned
  state with `merged_sections`; fabricating it risks introducing the very drift this task fights). A
  proper registration via the loader flow is a named follow-up.
- Do NOT hand-edit the generated `CLAUDE.md` (banner: "generated automatically ... Do not edit
  directly"); the merge-source `EXTENSION.md` is already consistent.
- Do NOT edit the `manifest.json` `provides.*` arrays (every relevant entry is already declared).
- Do NOT touch or attempt to fix the pre-existing `lean` extension doc-lint failures (task 843 owns
  those).
- Do NOT execute `/cite` against live Zotero data as a wiring test (possible side effects); verify
  wiring by resolution/static checks only.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Activated script deployed with content differing from source (drift-guard FAIL) | H | L | Deploy via byte-for-byte `cp` from source; verify with `cmp -s` in Phase 4 before declaring done |
| A DEFER item accidentally gets deployed, making the guard expect a deployed copy | M | L | Phases 1-2 touch only the four ACTIVATE paths; Phase 4 asserts the seven defer scripts + test harness remain absent from `.claude/scripts/` |
| Redundant manifest edits create duplicate `provides.scripts` entries | M | L | Plan explicitly forbids manifest edits; every ACTIVATE entry is already declared — verify-only |
| Hand-fabricating an `extensions.json` entry introduces new inconsistency | M | M | Decision: document the gap in README + name a follow-up; do not fabricate loader state |
| Deploying `skill-cite` trips guard Rule D (missing agent) | M | L | Confirmed direct-execution (no `subagent_type`); Phase 4 re-runs the guard to confirm no new FAIL |
| `/cite` wiring appears deployed but does not resolve to `skill-cite` | M | L | Phase 1 verifies `cite.md` references deployed `skill-cite/SKILL.md`; static resolution only, no live run |
| Pre-existing `lean` FAILs misread as regressions caused by this task | L | M | Phase 4 records the lean failures as pre-existing/out-of-scope and checks the literature section in isolation |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel (disjoint file territory: Phase 1 owns the
`/cite` trio paths, Phase 2 owns `zotero-search.sh`, Phase 3 owns the literature `README.md`). Phase 4
is verification-only and depends on all deploy/doc phases.

### Phase 1: Activate the /cite trio [COMPLETED]

- **Goal**: Deploy `cite-extract.sh`, `skill-cite`, and `cite.md` from extension source to the
  deployed tree so `/cite` is live and internally wired.
- **Tasks**:
  - [x] Copy `.claude/extensions/literature/scripts/cite-extract.sh` ->
        `.claude/scripts/cite-extract.sh` (byte-for-byte); `chmod +x` the deployed copy to match
        sibling deployed scripts. *(completed)*
  - [x] Copy `.claude/extensions/literature/skills/skill-cite/` (its `SKILL.md` and any assets) ->
        `.claude/skills/skill-cite/`. *(completed)*
  - [x] Copy `.claude/extensions/literature/commands/cite.md` -> `.claude/commands/cite.md`. *(completed)*
  - [x] Verify the internal call chain resolves statically: deployed `cite.md` delegates to
        `skill-cite`; deployed `skill-cite/SKILL.md` invokes `cite-extract.sh` (via its
        `"$script_dir/cite-extract.sh"` pattern). Do NOT run `/cite` against live Zotero.
        *(completed: confirmed via grep — cite.md line 11 "Delegates To: skill-cite (direct
        execution)"; skill-cite/SKILL.md invokes cite-extract.sh and zotero-search.sh via
        $script_dir)*
  - [x] Confirm `manifest.json` already declares all three (`cite-extract.sh` in `provides.scripts`,
        `cite.md` in `provides.commands`, `skill-cite` in `provides.skills`) — make NO manifest edit.
        *(completed: confirmed present, no edit made)*
  - [x] Confirm `skill-cite` is direct-execution (no `subagent_type`) so no agent file is required.
        *(completed: grep -c subagent_type skill-cite/SKILL.md == 0)*
- **Timing**: ~30 minutes
- **Depends on**: none
- **Files to modify**:
  - `.claude/scripts/cite-extract.sh` — new deployed copy (from source)
  - `.claude/skills/skill-cite/SKILL.md` — new deployed copy (from source)
  - `.claude/commands/cite.md` — new deployed copy (from source)
- **Verification**:
  - `cmp -s .claude/scripts/cite-extract.sh .claude/extensions/literature/scripts/cite-extract.sh`
    exits 0.
  - `cmp -s .claude/skills/skill-cite/SKILL.md .claude/extensions/literature/skills/skill-cite/SKILL.md`
    exits 0.
  - `cmp -s .claude/commands/cite.md .claude/extensions/literature/commands/cite.md` exits 0.
  - Deployed `cite-extract.sh` is executable.

### Phase 2: Activate zotero-search.sh [COMPLETED]

- **Goal**: Deploy `zotero-search.sh` for consistency with its existing live source-path fallback in
  `skill-literature/SKILL.md`.
- **Tasks**:
  - [x] Copy `.claude/extensions/literature/scripts/zotero-search.sh` ->
        `.claude/scripts/zotero-search.sh` (byte-for-byte); `chmod +x`. *(completed)*
  - [x] Confirm `zotero-search.sh` is already declared in `manifest.json` `provides.scripts` — make
        NO manifest edit. *(completed: confirmed present, no edit made)*
  - [x] Note (no code change) that `skill-literature/SKILL.md`'s 3-path fallback will now resolve to
        the deployed first-path copy instead of the extension-source third-path copy. *(completed)*
- **Timing**: ~15 minutes
- **Depends on**: none
- **Files to modify**:
  - `.claude/scripts/zotero-search.sh` — new deployed copy (from source)
- **Verification**:
  - `cmp -s .claude/scripts/zotero-search.sh .claude/extensions/literature/scripts/zotero-search.sh`
    exits 0.
  - Deployed `zotero-search.sh` is executable.

### Phase 3: Defer-and-document the inactive zotero suite + test harness [COMPLETED]

- **Goal**: Add an explicit inactive-status note so the eight deferred artifacts stop reading as
  accidental drift, and record the `extensions.json` tracking gap as a known follow-up.
- **Tasks**:
  - [x] Update the "Zotero Integration" section of
        `.claude/extensions/literature/README.md` (currently at line ~125) with a status table that
        names each inactive artifact and its reason. *(completed: added "Deployment Status (task
        844)" subsection with an Active/Inactive table naming all 8 deferred artifacts + reasons,
        and stating they remain declared in manifest.json but skip the drift guard as expected)*
    - `zotero-index-add.sh`, `zotero-index-remove.sh` — **Superseded** (dead code; the add/remove
      sub-index logic is reimplemented inline via `jq` in `skill-literature/SKILL.md`); prune
      candidate for a future task (do not delete now).
    - `zotero-read.sh`, `zotero-write.sh`, `zotero-setup.sh` — **Blocked on external `zot` CLI**
      (`zotero-cli-cc`, not installed here); no live caller.
    - `zotero-chunk.sh`, `zotero-attach-chunks.sh` — **Superseded** by the read-only
      briefing+tools design adopted in task 758 (write-back-to-Zotero chunking is orthogonal); no
      live caller.
    - `test-lit-pipeline.sh` — **Test harness, never a runtime script**; kept source-only,
      consistent with the task-841 drift-guard treatment.
    - State explicitly that these remain declared in `manifest.json` `provides.scripts` but are
      intentionally NOT deployed, and that the task-841 drift guard therefore skips them (this is
      expected, not drift).
  - [x] Add a short "Extension tracking gap" note (README or a clearly-labeled subsection) recording
        that the literature extension has no `.claude/extensions.json` entry despite substantial
        partial deployment, that this task intentionally does NOT fabricate one (loader-owned state),
        and that proper registration via the loader flow is a follow-up. *(completed: "Extension
        Tracking Gap" subsection added)*
  - [x] Make NO change to `manifest.json` and NO deployment of any artifact named in this phase.
        *(completed: verified — manifest.json untouched, no deferred script deployed)*
- **Timing**: ~30 minutes
- **Depends on**: none
- **Files to modify**:
  - `.claude/extensions/literature/README.md` — add inactive-status table + tracking-gap note
- **Verification**:
  - The README defer note names all eight artifacts (`zotero-index-add.sh`, `zotero-index-remove.sh`,
    `zotero-read.sh`, `zotero-write.sh`, `zotero-setup.sh`, `zotero-chunk.sh`,
    `zotero-attach-chunks.sh`, `test-lit-pipeline.sh`) each with a reason.
  - The extensions.json tracking-gap note is present.

### Phase 4: Verification [COMPLETED]

- **Goal**: Prove the end state is internally consistent and the drift guard is green with no new
  failures.
- **Tasks**:
  - [x] Run `bash .claude/scripts/check-extension-docs.sh` and confirm the `[literature]` section is
        PASS with: drift-check now *comparing* (not skipping) `cite-extract.sh` and `zotero-search.sh`
        and finding them identical; `info "script not deployed, skipping drift check"` still emitted
        for the seven deferred zotero scripts (`test-lit-pipeline.sh` too if declared) — these skips
        are expected, not failures. *(completed: exit 0, literature PASS, 7 skip lines for the 7
        deferred zotero scripts; deviation — `test-lit-pipeline.sh` is NOT in the skip list because
        it is already deployed by an unrelated prior task (763), not part of this task's declared
        scope; see README correction note and deviation entry below)*
  - [x] Confirm the total failure set is unchanged from the pre-task baseline (the four
        `lean`-section failures are pre-existing and owned by task 843; no new literature failures).
        *(completed: 0 FAIL lines anywhere in output; all 19 extensions PASS, including `lean` —
        better than the plan's expected 4 pre-existing lean failures, meaning task 843's fixes are
        fully holding with zero regressions)*
  - [x] Re-run the three `/cite`-trio `cmp -s` checks and the `zotero-search.sh` `cmp -s` check;
        all exit 0. *(completed: all 4 exit 0)*
  - [x] Confirm the seven deferred zotero scripts and `test-lit-pipeline.sh` are still ABSENT from
        `.claude/scripts/`. *(deviation: altered — the 7 zotero scripts are confirmed absent;
        `test-lit-pipeline.sh` is NOT absent — it was already deployed by task 763 before this
        task began, unrelated to the zotero/cite scope. This task did not deploy it. See deviation
        entry and README correction note.)*
  - [x] Confirm deployed `cite.md` wiring resolves to deployed `skill-cite/SKILL.md` (static grep),
        and `skill-cite/SKILL.md` references `cite-extract.sh`; do NOT execute `/cite` live.
        *(completed: static grep confirms wiring; /cite not executed live)*
  - [x] Confirm the README defer note exists and names each inactive artifact with a reason.
        *(completed: all 8 artifacts named with reasons — 7 in the Inactive table, test-lit-pipeline.sh
        in the correction note)*
- **Timing**: ~20 minutes
- **Depends on**: 1, 2, 3
- **Files to modify**: none (verification only)
- **Verification**:
  - `check-extension-docs.sh` literature section: PASS, no new failures, no drift-guard
    false-failures.
  - All four `cmp -s` byte-identity checks exit 0.
  - Deferred artifacts confirmed undeployed.

## Testing & Validation

- [ ] `bash .claude/scripts/check-extension-docs.sh` — `[literature]` section PASS; only the
      pre-existing `lean` failures remain in the overall summary; no new literature failure introduced.
- [ ] `cmp -s` byte-identity holds for `cite-extract.sh`, `skill-cite/SKILL.md`, `cite.md`, and
      `zotero-search.sh` (deployed == extension source).
- [ ] Deployed `cite-extract.sh` and `zotero-search.sh` are executable.
- [ ] `/cite` wiring resolves statically (deployed `cite.md` -> deployed `skill-cite` ->
      `cite-extract.sh`); NOT run against live Zotero.
- [ ] The seven deferred zotero scripts and `test-lit-pipeline.sh` remain absent from
      `.claude/scripts/` (drift guard skips them, as designed).
- [ ] README defer-and-document note names each of the eight inactive artifacts with its reason, and
      records the `extensions.json` tracking gap as a follow-up.

## Artifacts & Outputs

- `.claude/scripts/cite-extract.sh` (deployed)
- `.claude/skills/skill-cite/SKILL.md` (deployed)
- `.claude/commands/cite.md` (deployed)
- `.claude/scripts/zotero-search.sh` (deployed)
- `.claude/extensions/literature/README.md` (updated: inactive-status table + tracking-gap note)
- `specs/844_finish_or_defer_zotero_cite_install/plans/01_install-plan.md` (this plan)
- `specs/844_finish_or_defer_zotero_cite_install/summaries/01_install-summary.md` (produced at implement time)

## Rollback/Contingency

All activation changes are additive file copies into the deployed tree and one documentation edit.
To revert:
- `git rm` (or `rm`) the four newly deployed paths (`.claude/scripts/cite-extract.sh`,
  `.claude/scripts/zotero-search.sh`, `.claude/commands/cite.md`, `.claude/skills/skill-cite/`).
  Because the drift guard skips absent deployed copies, removing them returns the literature section
  to its prior PASS state with no residual inconsistency.
- `git checkout -- .claude/extensions/literature/README.md` to revert the defer note.
No manifest or state.json mutation is performed, so there is nothing else to unwind.

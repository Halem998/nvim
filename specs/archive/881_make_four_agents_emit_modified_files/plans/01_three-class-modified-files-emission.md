# Implementation Plan: Task #881

- **Task**: 881 - make_four_agents_emit_modified_files
- **Status**: [COMPLETED]
- **Effort**: 5.25 hours
- **Dependencies**: `modified_files`/`files_touched` schema (landed — `return-metadata-file.md` section `modified_files (optional)`, `progress-file.md` field `files_touched`)
- **Research Inputs**: specs/881_make_four_agents_emit_modified_files/reports/01_shared-fragment-and-agent-gaps.md
- **Artifacts**: plans/01_three-class-modified-files-emission.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Four implementation agents fail to self-report `modified_files`, so `orchestrator-postflight.sh`
Stage 9 falls back to the fixed task-directory scope and their source edits are never staged. The
fix is **not** a uniform replication of the reference chain: research established three distinct
classes (completion gap / structural gap / wrapper-only non-gap), and a copy-paste across all four
would over-fit two and under-fit two. This plan writes one shared producer-side procedure to a
single carrier, then applies three class-appropriate patches to it, then verifies behaviorally via
one minimal synthetic dispatch per agent — because for LLM prompt files there is no valid static
proxy.

### Research Integration

Research is adopted on every point except the carrier file (see the Carrier Decision below, which
this plan resolves against research's recommendation) and one verification detail (the probe-file
location, corrected below). Adopted as settled and not re-litigated:

- The shared-fragment approach is feasible and already-proven: `copy_context_dirs()` merges every
  extension's `provides.context` into one flat `.claude/context/` tree; `dependencies: ["core"]`
  orders load only. All four agents already successfully `@`-reference core-owned `formats/*.md`.
- The working reference chain is `general-implementation-agent.md`: Stage 3.5 progress file ->
  Stage 4B "track the path" -> Stage 6-modified-files (flatten+dedupe) -> Stage 7 field.
- Three classes, not one. Email's typical `modified_files: []` is *correct*, not a bug.

Three findings from plan-time inspection **extend** research and are load-bearing here:

1. **The hard agent's `files_touched` comment is a dead stub.** Its Stage 5 ("Wrap-Up Contract
   (H9)") Step 2 commit block carries the comment `# Append every path accumulated in this phase's
   progress-file files_touched arrays` — with **no `jq` loop beneath it**. The base agent's
   Phase Checkpoint Protocol has the real loop. So the hard agent's per-phase commits under-stage
   *today*, in addition to its Stage 7 omission. This makes its patch slightly larger than
   research's "smallest fix of the four" framing, though still a completion patch.
2. **nvim and nix under-stage at the per-phase commit too.** Both have a Phase Checkpoint Protocol
   whose step 5 stages exactly `task_dir/ specs/TODO.md specs/state.json` — so even once Stage 7
   emits `modified_files`, their *intermediate* phase commits would still silently drop every
   `.lua`/`.nix` edit. Fixing only Stage 7 would leave half the defect standing.
3. **Deploy-before-verify is a hard ordering constraint.** Dispatched agents load from the deployed
   `.claude/` tree, not from `agent-system/`. `diff -q` confirms the two are byte-identical copies
   today. Verification against an un-redeployed tree would silently exercise the *old* prompts and
   report a false negative.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in the delegation context and `roadmap_flag` is absent; no ROADMAP.md
was consulted or will be modified.

## Decisions

### Carrier Decision: `return-metadata-file.md`, not `git-staging-scope.md`

**Decision**: the shared producer-side procedure is authored as a new `#### How Implementation
Agents Populate modified_files` subsection **inside the existing `### modified_files (optional)`
section of `agent-system/extensions/core/context/formats/return-metadata-file.md`**.
`git-staging-scope.md` is **not edited at all** by this task.

This departs from research's recommendation. Reasoning, in priority order:

1. **Reference graph — decisive.** Measured, not assumed:

   | Agent | `@`-refs `return-metadata-file.md` | `@`-refs `git-staging-scope.md` |
   |---|---|---|
   | `email-implementation-agent.md` | YES (marked "always load") | **NO** |
   | `general-implementation-hard-agent.md` | YES | YES |
   | `neovim-implementation-agent.md` | YES | YES |
   | `nix-implementation-agent.md` | YES | YES |

   `return-metadata-file.md` already reaches all four. Choosing `git-staging-scope.md` would force
   a **new** `@`-reference onto email's Context References — adding coupling to the staging
   contract for the one agent that stages nothing and needs it least.

2. **Topical ownership.** `git-staging-scope.md` is a **consumer-side** contract: it describes what
   the postflight pipeline stages. The procedure being authored is **producer-side**: how an agent
   accumulates and emits the field. `return-metadata-file.md` is already the schema home for
   `modified_files` (the dependency task landed that section there) and already hosts producer
   prose under "Agent Instructions" -> "Writing Metadata". The procedure belongs beside the field
   spec it produces.

3. **Collision avoidance.** A sibling task (running serially after this one) already owns
   `git-staging-scope.md` for a state-write hazard note. Execution is serial so no data would be
   lost, but `return-metadata-file.md` is unclaimed — the collision is avoidable at zero cost, so
   avoid it.

4. **No reader is stranded.** The existing bidirectional links already carry
   `git-staging-scope.md` readers to the field spec: its "Related Documentation" section links
   `return-metadata-file.md — modified_files field schema`, and the `modified_files` section's
   "Provenance" paragraph links back to both `progress-file.md` and `git-staging-scope.md`. Adding
   the procedure under the field spec is reachable from the staging contract via a link that
   already exists. Nothing needs to be added to `git-staging-scope.md` to make this work.

### Class-appropriate scope, per research

| Class | Agent(s) | Gap | Treatment |
|---|---|---|---|
| 1. Completion | `core/agents/general-implementation-hard-agent.md` | Progress-file plumbing exists; never sums into `modified_files`; dead `files_touched` comment in its commit block | Add the sum step, the real `jq` append loop, and the Stage 7 field. No structural change. |
| 2. Structural | `nvim/agents/neovim-implementation-agent.md`, `nix/agents/nix-implementation-agent.md` | No progress-file machinery at all | Add minimal progress-file scaffolding sufficient to carry `files_touched`, plus track-on-write, sum step, Stage 7 field, and checkpoint-commit staging. **Highest-value fix** — editing non-`specs/` repo files is their entire job. |
| 3. Wrapper-only | `email/agents/email-implementation-agent.md` | Emits nothing either way; typically touches no repo-tracked file | Emit `[]` explicitly per the schema's never-omit rule; list a path only in the rare case a step really edits a repo-tracked file. **No progress-file/objectives machinery** — it has no use for it. |

## Goals & Non-Goals

**Goals**:
- One shared, `@`-referenced producer procedure that all four agents point at, so this contract has
  a single source of truth and stops drifting per-agent.
- Class 1 and Class 2 agents emit a non-empty, repo-relative, per-file `modified_files` that
  postflight Stage 9 actually stages.
- Class 2 agents additionally stage their source edits at per-phase checkpoint commits.
- Class 3 agent emits `modified_files: []` explicitly (never omitted), and a real path when it
  genuinely edits a repo-tracked file.
- Behavioral evidence per agent — not "the prose was added".

**Non-Goals**:
- Editing `git-staging-scope.md` (see Carrier Decision) — deliberately left to the sibling task.
- Editing `orchestrator-postflight.sh`. The consumer already works; this is a producer-side defect.
- Any new script (per CONSTRAINT). All edits are prose/`@`-reference changes to existing `.md`
  files. Progress files are JSON written by the agent via `Write`, exactly as the base agent does.
- Importing the base agent's full handoff/continuation apparatus into nvim/nix — only enough
  progress-file structure to carry `files_touched`.
- Editing `.claude/**` as a deliverable. It is a gitignored, regenerated build artifact
  (`.gitignore` ignores `/.claude/`); edits there are never committed and are wiped on reload. The
  one sanctioned touch is the disposable verification-window deploy in Phase 5.
- Changing the base `general-implementation-agent.md` behavior. It works and is the reference; it
  may be repointed at the shared section only if that is a pure no-op in meaning.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **Vacuous verification**: probe file placed under `specs/{task}/` would be staged by the fixed task-dir scope regardless, so the test would pass even if `modified_files` were empty | H | H | Probe files MUST live **outside `specs/`** (repo-root `verify-scratch/`). This corrects research's suggestion of a probe under `specs/881_.../scratch/`, which would have proven nothing. Gate: run the probe once *before* the fix and confirm it FAILS. |
| Verification runs against the stale deployed `.claude/` tree, silently testing old prompts | H | H | Phase 5 deploys the five edited files to `.claude/` by byte-copy *before* any dispatch, and asserts `diff -q` equality first. |
| Running full `orchestrator-postflight.sh` to test staging would create real junk commits | M | M | Do not run it. Re-execute its Stage 9 staging block verbatim (same `jq -r '.modified_files[]? // empty'` filter, same `git add`), assert via `git diff --staged --name-only`, then unstage with `git restore --staged` (safe; only `--staged`). |
| Retrofitting full objectives machinery onto nvim/nix is over-engineered for their single-pass loops | M | M | Scope to a flat one-objective-per-phase progress file carrying `files_touched` only; omit deviations/handoff arrays they do not use. |
| Email "verified" against a synthetic plan resembling no real email workflow -> false coverage | M | M | Test both paths explicitly and label them: (a) the **realistic** path — a wrapper-only plan emits `[]`; (b) the **synthetic mechanism exercise** — a repo-file-edit step emits that path. Document (b) as a mechanism probe, not a realistic workflow. |
| Synthetic dispatch trips `update-phase-status.sh` / state.json lookups for a task that is not a real state entry | M | M | The hard agent already documents an Edit-tool fallback when the script is unavailable; nvim/nix use Edit directly. Treat a status-script failure as non-fatal for the probe — the load-bearing assertion is the emitted `modified_files`. |
| Probe scratch files leak into this task's own commit | M | L | `verify-scratch/` is deleted in Phase 5's cleanup task; Phase 5 verification asserts `git status --porcelain` shows no `verify-scratch/` residue before the phase is marked complete. |
| Email agent aborts at its `$PATH` precondition gate | L | L | Retired: all five wrapper binaries confirmed present on `$PATH` (`/home/benjamin/.nix-profile/bin/`) at plan time. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel. Wave 2's three phases touch disjoint files
(core hard agent / nvim+nix agents / email agent) and share no edit territory.

---

### Phase 1: Author the Shared Producer Procedure [IN PROGRESS]

**Goal**: Create the single source of truth every implementation agent will point at, so the four
patches in Wave 2 are `@`-references plus a field, not four divergent prose copies.

**Tasks**:
- [ ] In `agent-system/extensions/core/context/formats/return-metadata-file.md`, add a
      `#### How Implementation Agents Populate modified_files` subsection nested under the existing
      `### modified_files (optional)` section, placed after the "Provenance" paragraph and before
      "Retrospective vs. prospective".
- [ ] Document the four-step producer procedure, written to serve both progress-file agents and
      agents without progress files:
  - [ ] **1. Track on write** — at the moment of every `Write`/`Edit`, append that file's
        repo-relative path to the current accumulation site. Not reconstructed from memory at the
        end.
  - [ ] **2. Accumulate** — agents with progress files append to the current objective's
        `files_touched` array, additively (never overwriting paths from earlier updates to the same
        objective), per `progress-file.md`. Agents without progress files keep a single flat list
        for the run.
  - [ ] **3. Sum** — before writing final metadata, flatten every phase's every
        `objectives[].files_touched` across all phases into one list and de-duplicate.
  - [ ] **4. Emit** — write the deduped list as top-level `modified_files` in `.return-meta.json`.
- [ ] State the field constraints inline so an agent following this section alone cannot get them
      wrong: repo-relative (never absolute), individual files (never directory prefixes), and
      `[]` when nothing was touched — **never omit the field**.
- [ ] Note that paths under the task directory are harmless if listed (the fixed task-dir scope
      already stages them); the load-bearing case is every repo-tracked file touched **outside**
      the task directory, which is staged only if self-reported here.
- [ ] Add a one-line note that wrapper-only or non-file-editing agents emit `[]` — this is correct
      schema behavior, not a defect to be worked around.
- [ ] Verify no task-number citations were introduced (DELIVERABLE RULE); cite section/field names
      as anchors.

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/context/formats/return-metadata-file.md` — new `#### How
  Implementation Agents Populate modified_files` subsection under the existing `modified_files`
  section. No other section altered.

**Verification**:
- The new subsection is nested under `### modified_files (optional)` and does not disturb the
  existing "Provenance" / "Retrospective vs. prospective" paragraphs or the two `modified_files`
  JSON examples.
- All four constraints (repo-relative / per-file / `[]`-never-omit / outside-task-dir is the
  load-bearing case) are stated in the section itself.
- `grep -nE '\btasks? [0-9]+' ` over the file returns no new hits.
- `git-staging-scope.md` is untouched: `git status --short` shows no modification to it.

---

### Phase 2: Class 1 — Complete the Hard Agent's Existing Chain [NOT STARTED]

**Goal**: The hard agent already has progress-file plumbing; make it actually sum and emit — and
replace its dead `files_touched` comment with the real append loop.

**Tasks**:
- [ ] In `agent-system/extensions/core/agents/general-implementation-hard-agent.md`, add
      `@.claude/context/formats/return-metadata-file.md` to Context References if absent, and point
      it at the `How Implementation Agents Populate modified_files` section by name.
- [ ] Disambiguate Stage 4 step B: its "following the same pattern as base agent" must explicitly
      include track-on-write, so an agent reading only this file does not miss the instruction that
      lives in the base agent's prose. Add a bullet naming `files_touched` and referencing the
      shared section.
- [ ] Fix the dead comment in Stage 5 ("Wrap-Up Contract (H9)") Step 2: the block's
      `# Append every path accumulated in this phase's progress-file files_touched arrays` comment
      has no loop beneath it. Add the real append, mirroring the base agent's Phase Checkpoint
      Protocol `jq` read of `objectives[].files_touched` into `stage_paths`, before `git add`.
- [ ] Add an explicit sum step before Stage 7 (mirroring the base agent's `Stage
      6-modified-files`), expressed as an `@`-reference to the shared section rather than re-copied
      prose.
- [ ] Extend Stage 7 ("Write Metadata File") — currently naming only `phases_completed`,
      `phases_total`, `memory_candidates` — to include `modified_files` at the top level, citing
      the shared section.
- [ ] Confirm no task-number citations introduced.

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — Context References,
  Stage 4 step B, Stage 5 Step 2 commit block, new pre-Stage-7 sum step, Stage 7 field list.

**Verification**:
- Stage 5 Step 2's `files_touched` comment is followed by an actual append loop; the comment no
  longer describes behavior the block does not perform.
- Stage 7 names `modified_files` as a top-level field.
- The file `@`-references the shared section rather than duplicating its prose.
- Behavioral confirmation deferred to Phase 5 (this phase's checks are structural only and are
  explicitly NOT acceptance evidence).

---

### Phase 3: Class 2 — Add the Missing Machinery to nvim and nix Agents [NOT STARTED]

**Goal**: The highest-value fix. Both agents `Write`/`Edit` real `.lua`/`.nix` source as their
entire purpose and currently have no tracking mechanism at all — at Stage 7 *or* at their
per-phase checkpoint commits.

**Tasks**:
- [ ] In **both** `agent-system/extensions/nvim/agents/neovim-implementation-agent.md` and
      `agent-system/extensions/nix/agents/nix-implementation-agent.md`:
  - [ ] Add `@.claude/context/formats/progress-file.md` to Context References (neither references
        it today), and point Stage 7 at the shared section in `return-metadata-file.md`.
  - [ ] Add a **Stage 3.5: Initialize Progress Tracking** step creating
        `specs/{NNN}_{SLUG}/progress/phase-{P}-progress.json`. Keep it minimal — a flat
        one-objective-per-phase array carrying `files_touched`; do not import the base agent's
        deviations/handoff apparatus.
  - [ ] Add track-on-write to the file-modifying step (nvim: Stage 4 step B item 2 "Create or
        modify files"; nix: the corresponding step in its Stage 4 loop): append each written path's
        repo-relative path to the current objective's `files_touched`.
  - [ ] Add a pre-Stage-7 sum step (`@`-referencing the shared section).
  - [ ] Add `modified_files` to the Stage 7 metadata JSON example — currently absent from both.
        Show it as a top-level sibling of `completion_data`/`metadata`, with a repo-relative,
        domain-appropriate example path (`lua/...` for nvim, a `.nix` path for nix).
  - [ ] **Fix the checkpoint under-staging**: Phase Checkpoint Protocol step 5 currently stages
        only `("${task_dir}/" "specs/TODO.md" "specs/state.json")`, silently dropping the very
        source files the phase just edited. Append this phase's accumulated `files_touched` to
        `stage_paths` before `git add`, mirroring the base agent. Keep the existing
        `git-staging-scope.md` reference and the never-stage-the-whole-tree language intact.
- [ ] Keep the two files' shapes parallel — they are near-identical by design; do not let them
      drift apart in this edit.
- [ ] Confirm no task-number citations introduced in either file.

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/nvim/agents/neovim-implementation-agent.md` — Context References, new
  Stage 3.5, Stage 4B item 2, pre-Stage-7 sum step, Stage 7 JSON example, Phase Checkpoint Protocol
  step 5.
- `agent-system/extensions/nix/agents/nix-implementation-agent.md` — same six sites.

**Verification**:
- Both files' Stage 7 JSON examples contain a top-level `modified_files` array with a
  repo-relative, per-file example path.
- Both files' Phase Checkpoint Protocol step 5 appends `files_touched` before `git add` and still
  contains no `git add -A`/`git add .`/`git commit -am`.
- Both retain their existing domain verification steps (`nvim --headless` checks; `nix flake
  check`/eval checks) unchanged.
- Behavioral confirmation deferred to Phase 5 (structural checks here are NOT acceptance evidence).

---

### Phase 4: Class 3 — Proportionate Emission for the Wrapper-Only Email Agent [NOT STARTED]

**Goal**: Make the email agent conform to the never-omit rule without pretending it has a
files_touched chain it has no use for. `modified_files: []` is the **correct** output for a typical
wrapper-only mailbox run — this phase must not "fix" that into something else.

**Tasks**:
- [ ] In `agent-system/extensions/email/agents/email-implementation-agent.md`, extend Stage 5
      ("Write Summary and Metadata") — currently only "per the standard formats referenced above" —
      with an explicit `modified_files` instruction:
  - [ ] Always emit the field. If no repo-tracked file was `Write`/`Edit`-ed during the run, emit
        `[]`. State plainly that `[]` is the **expected and correct** result for a wrapper-only
        propose->review->confirm->execute mailbox run, since mailbox mutation touches no
        repo-tracked source.
  - [ ] If a step did `Write`/`Edit` a repo-tracked file (the rarer case — e.g. a plan step editing
        a repo-tracked email context or hook file), append its repo-relative path.
  - [ ] Point at the `How Implementation Agents Populate modified_files` section by name for the
        field constraints.
- [ ] Do **not** add progress-file/objectives machinery, a Stage 3.5, or a sum step to this agent.
- [ ] Do **not** add a `@`-reference to `git-staging-scope.md` — this agent stages nothing, and the
      Carrier Decision exists specifically so it does not need one. It already references
      `return-metadata-file.md` as "always load".
- [ ] Leave the WRAPPER-ONLY CONTRACT, the five-binary allowlist, the `$PATH` precondition, and the
      review-gate requirements completely untouched.
- [ ] Confirm no task-number citations introduced.

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/email/agents/email-implementation-agent.md` — Stage 5 only.

**Verification**:
- Stage 5 instructs always-emit with `[]` as the documented normal case.
- No progress-file scaffolding and no new `git-staging-scope.md` reference were added.
- The wrapper-only contract sections are byte-unchanged (`git diff` touches Stage 5 only).

---

### Phase 5: Deploy and Behaviorally Verify — One Synthetic Dispatch Per Agent [NOT STARTED]

**Goal**: Produce the acceptance evidence the task demands. Research answered the proxy question
honestly: **there is no valid static/textual proxy for LLM prompt files.** Grepping the edited
`.md` files for `modified_files` is exactly the "the prose was added" failure this task rules out.
The cheapest valid test is one minimal synthetic single-phase dispatch per agent — four small
dispatches, not four task lifecycles. This plan accepts that cost rather than downgrading.

**Tasks**:
- [ ] **Deploy first (ordering constraint).** Agents load from `.claude/`, not `agent-system/`.
      Byte-copy the five edited files into their deployed paths (`.claude/context/formats/
      return-metadata-file.md` and `.claude/agents/{general-implementation-hard,
      neovim-implementation,nix-implementation,email-implementation}-agent.md`). This mirrors the
      loader's own copy semantics (source and deployed trees confirmed byte-identical via `diff
      -q`). Not a new script; `.claude/` is disposable and gitignored, so this cannot pollute the
      commit. Assert with `diff -q` per file afterward.
- [ ] **Create probes outside `specs/`** — at repo-root `verify-scratch/`: `probe.lua`,
      `probe.nix`, `probe.md`, `probe-email.md`. **This location is load-bearing**: a probe under
      `specs/{task}/` would be staged by the fixed task-dir scope even with an empty
      `modified_files`, making the whole test vacuous.
- [ ] **Run the pre-fix negative control** (do this before trusting any green): dispatch one agent
      (nvim) against its probe *using the old deployed prompt* and confirm it emits no
      `modified_files` / the postflight simulation stages nothing. A test that cannot fail is not
      evidence.
- [ ] For each of the four agents, hand-write a one-phase, one-step synthetic plan whose only
      action is a trivial edit to that agent's probe file, and dispatch the agent directly via the
      `Agent` tool with a synthetic delegation context (bypassing the skill wrapper). For email,
      run **both** paths: (a) a wrapper-free plan -> assert `[]` (realistic); (b) a probe-edit plan
      -> assert the path (mechanism exercise; label it as such in the summary, not as a realistic
      email workflow).
- [ ] **Assert the emission shape, not just presence**, per agent:
      `jq '.modified_files' specs/.../.return-meta.json` must be the exact repo-relative path of
      the probe — not `[]` (except email path (a)), not absolute, not a directory prefix. A
      non-empty array with the wrong path form passes a naive check and still fails `git add`.
- [ ] **Close the loop on the consumer.** Re-execute `orchestrator-postflight.sh` Stage 9's staging
      block verbatim — the same `jq -r '.modified_files[]? // empty'` filter into `stage_paths`,
      then `git add` — and assert `git diff --staged --name-only` contains the probe. Do **not**
      run the full postflight (it creates real commits). Unstage afterward with `git restore
      --staged` (safe: `--staged` only unstages).
- [ ] **Clean up**: `rm -rf verify-scratch/` and any synthetic task dirs; assert `git status
      --porcelain` shows no `verify-scratch/` residue and no unintended staged paths.
- [ ] If any agent's dispatch trips a status-script/state lookup for the synthetic task, record it
      and fall back to asserting the emitted `modified_files` — the load-bearing check — rather
      than abandoning the probe.
- [ ] Record per-agent results in the implementation summary, including honest labeling of email
      path (b) as a synthetic mechanism exercise.

**Timing**: 1.75 hours

**Depends on**: 2, 3, 4

**Files to modify**:
- `verify-scratch/` (repo-root, disposable; created and deleted within this phase)
- `.claude/**` (disposable deploy for the verification window only; never committed)
- No `agent-system/` source file is edited in this phase.

**Verification**:
- The negative control failed before the fix (proving the test can fail).
- All four agents dispatched against the **redeployed** prompts.
- Per-agent `jq '.modified_files'` shows the exact repo-relative probe path (email path (a): `[]`).
- The Stage 9 staging simulation staged the probe for each of the three file-editing classes,
  confirmed via `git diff --staged --name-only`.
- `verify-scratch/` removed; working tree clean of probe residue.
- **Not accepted as evidence**: grepping the agent `.md` files; "the prose was added"; reasoning by
  analogy from the base agent's correctness.

---

## Testing & Validation

- [ ] Negative control fails pre-fix (test can fail).
- [ ] Hard agent emits a non-empty repo-relative `modified_files`, and its Stage 5 commit block
      appends `files_touched` rather than only claiming to in a comment.
- [ ] nvim and nix agents each emit the exact repo-relative probe path.
- [ ] nvim and nix checkpoint-commit staging includes source files.
- [ ] Email emits `[]` on the wrapper-only path and the correct path on the mechanism probe.
- [ ] Stage 9 staging simulation stages the probe for each file-editing agent.
- [ ] No `git add -A` / `git add .` / `git commit -am` introduced anywhere.
- [ ] No task-number citations in any file outside `specs/**`.
- [ ] `git-staging-scope.md` untouched (sibling task's territory).
- [ ] No new scripts created.
- [ ] `verify-scratch/` and synthetic dirs removed; no `.claude/**` edits staged.

## Artifacts & Outputs

- `agent-system/extensions/core/context/formats/return-metadata-file.md` — shared producer section
  (new subsection under `modified_files`).
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — Class 1 completion.
- `agent-system/extensions/nvim/agents/neovim-implementation-agent.md` — Class 2 structural.
- `agent-system/extensions/nix/agents/nix-implementation-agent.md` — Class 2 structural.
- `agent-system/extensions/email/agents/email-implementation-agent.md` — Class 3 proportionate.
- `specs/881_make_four_agents_emit_modified_files/summaries/01_*-summary.md` — with per-agent
  behavioral verification results.

## Rollback/Contingency

All five source edits are additive prose/`@`-reference changes to existing `.md` files with no
schema or script changes, so per-file `git revert`/checkout of the phase commit restores prior
behavior with no migration. `.claude/**` needs no rollback — it is regenerated from
`agent-system/` by the loader and is never committed. `verify-scratch/` is untracked and deleted in
Phase 5. If Phase 5 reveals an agent ignores the new prose behaviorally, the correct contingency is
to strengthen that agent's own prose (inline the procedure rather than `@`-reference it) and
re-dispatch — **not** to accept the structural edit as done, and not to widen the postflight staging
scope toward `git add -A`, which the staging contract forbids.

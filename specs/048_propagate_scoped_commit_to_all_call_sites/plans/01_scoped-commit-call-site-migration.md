# Implementation Plan: Propagate scoped commit to all call sites

- **Task**: 48 - Propagate scoped commit to all call sites
- **Status**: [IMPLEMENTING]
- **Effort**: 11.25 hours
- **Dependencies**: Task 124
- **Research Inputs**: specs/048_propagate_scoped_commit_to_all_call_sites/reports/01_scoped-commit-propagation-inventory.md
- **Artifacts**: plans/01_scoped-commit-call-site-migration.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`agent-system/extensions/core/scripts/git-commit-scoped.sh` is the single sanctioned
implementation of the scoped-commit contract, and it is correct — it closes both the shared-index
sweep defect and the `index.lock` race, and injects the canonical ephemeral-exclusion set. What
never happened is adoption: 98 files in the source store still hand-roll a narrow `git add`
followed by a bare `git commit -m`. This plan migrates all 98, in leverage order (the two
scaffold templates and the four core "how to commit" reference docs first, because every
downstream extension site reproduces their exact shape), then exercises one migrated command
end-to-end with a real commit, then adds `lint-scoped-commit-boundary.sh` as a new
`verify-deploy.sh` gate so the pattern cannot regrow.

Definition of done: `grep -rl 'git commit -m' agent-system/extensions/` returns only
`git-commit-scoped.sh`, its test fixtures, and the four other named-and-reasoned exemptions; a
real commit has been produced through a converted path; and the new lint passes on the migrated
tree and fails on a dirty fixture.

### Research Integration

The plan is built directly on `reports/01_scoped-commit-propagation-inventory.md`:

- Its re-measured inventory (103 files / 161 occurrences / 98 genuine call sites / 5 exceptions)
  was independently re-confirmed at plan time by re-running the report's own measurement greps —
  identical numbers.
- Its Tier 0-4 ordering supplies the phase sequence. Tier 0 (the copy-paste root cause) is
  Phase 1 and blocks every other migration phase, so later phases crib a correct pattern rather
  than propagating the broken one further.
- Its Category A exemption set (5 files, each with a stated reason) is adopted verbatim as the
  lint allowlist and as the acceptance-criterion escape-clause list.
- Its recommendation to migrate the "Manual commit required" human-recovery blocks too (rather
  than skip them) is adopted, and is called out explicitly in Phase 4 as a deliberate judgment
  call rather than a mechanical rewrite.
- Its lint design (two-layer structural classifier + reason-carrying file allowlist, modeled on
  `lint-state-writer-boundary.sh`, wired as a new gate) is Phase 11, deliberately last: a lint
  added before migration would fail on ~98 pre-existing files and produce no usable signal.
- Its Tier 4 sampling caveat (only 7 of 68 extension files opened directly) is carried into every
  Tier 4 phase as a per-file-read requirement, not a blind mechanical rewrite.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context; no ROADMAP.md was consulted.

## Goals & Non-Goals

**Goals**:

- Migrate all 98 genuine raw-`git commit -m` call sites in `agent-system/extensions/**` to
  `git-commit-scoped.sh`, preserving each site's existing message text and staging pathspecs.
- Fix the two scaffold templates and four core reference docs first, so new commands and skills
  are generated from a correct pattern.
- Record each of the 5 non-migrated files with its stated exemption reason, satisfying the
  acceptance criterion's escape clause.
- Exercise at least one migrated command end-to-end — a real commit through the converted path,
  not a static read.
- Add `lint-scoped-commit-boundary.sh` with a test fixture, register it in
  `core/manifest.json`, and wire it as a new `verify-deploy.sh` gate.

**Non-Goals**:

- Any change to `git-commit-scoped.sh` itself. The mechanism is confirmed correct; this is
  propagation and verification, not design.
- Any edit to `.claude/**`. That tree is a disposable deploy artifact; all edits land in
  `agent-system/extensions/**` and reach `.claude/` only via redeploy.
- Any edit to `commands/research.md`, `commands/plan.md`, or `commands/implement.md`. These three
  lifecycle command files were deleted earlier in this same batch and no longer exist in the
  source store; their absence is confirmed, not assumed.
- Any edit to the inline task-lookup jq duplication class. That duplication class is a separate
  concurrent effort in the same source store; this plan's file scope is git-commit call sites
  only, and no phase here touches a task-lookup site.
- Rewriting commit message content. Migration extracts the existing body into `--message` and
  drops the trailing `Session:` line (the script appends it); it does not reword messages.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Blind mechanical rewrite converts a site whose staging scope is legitimately not task-scoped | H | M | Every migration phase requires opening each file before editing. Any site whose pathspecs fall outside the task directory, or that stages a whole tree, is recorded as a candidate exemption with a reason rather than converted. Only 7 of 68 extension files were read during research; the rest are hypotheses. |
| Dropping the `Session:` line incorrectly (double-appended or lost) | M | M | `git-commit-scoped.sh` appends `\n\nSession: <id>` itself. Each migrated snippet must pass the body WITHOUT that line and pass `--session "$session_id"`. Phase 10's end-to-end run inspects the resulting real commit message for exactly one Session line. |
| Missing `--honest-index-rows` on sites that stage `specs/state.json` or `specs/TODO.md` | M | M | Each phase's checklist includes an explicit "does this site stage state.json or TODO.md?" step; if yes, add `--honest-index-rows <task_number>` per `git-staging-scope.md`. |
| Migration drift: an earlier-migrated batch regresses while later batches land | M | L | Re-run the report's measurement grep at the end of every phase and record the remaining count in the phase's verification. The lint (Phase 11) is the durable guardrail; until it lands the grep is the check. |
| Lint added too early fails on ~98 pre-existing files, producing no signal | M | L | Lint is deliberately Phase 11, gated on Phase 10's clean acceptance grep. |
| Deployed `.claude/` tree goes stale relative to migrated source store, so gate runs test old content | M | M | Phases that require a gate run redeploy via `scripts/deploy-headless.sh` first, then run `verify-deploy.sh`. |
| Concurrent sessions committing during this task sweep in unrelated work — the exact defect being fixed | M | M | Every commit made during this task must itself go through `git-commit-scoped.sh` with explicit pathspecs. Do not use `git add -A` or a bare `git commit` at any point. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5, 6, 7, 8, 9 | 1 |
| 3 | 10 | 2, 3, 4, 5, 6, 7, 8, 9 |
| 4 | 11 | 10 |

Phases within the same wave can execute in parallel. Wave 2's eight phases occupy disjoint file
territories (core commands / core skills+agents / core process docs / core doc guides / founder /
present+lean / filetypes+web+epi+cslib / the remaining small extensions) and may be dispatched
concurrently, provided each uses its own scoped commit.

---

### Phase 1: Fix the copy-paste root cause [COMPLETED]

**Goal**: Correct the two scaffold templates and the four core "how to commit" reference docs, so
that every subsequent migration phase — and every future new command or skill — has a correct
pattern to copy.

**Tasks**:
- [x] `core/context/templates/command-template.md` (1 occurrence): replace the raw `git add` +
      bare `git commit -m` block with the `git-commit-scoped.sh` invocation shape.
- [x] `core/docs/templates/command-template.md` (1 occurrence): same replacement; confirm the two
      templates stay textually consistent with each other.
- [x] `core/context/standards/git-safety.md` (13 occurrences): the most stale artifact in the
      tree — it predates `git-commit-scoped.sh` and mentions it zero times. Rewrite its commit
      guidance to name `git-commit-scoped.sh` as the sanctioned path, and update every XML
      `<stage>` block (these are quoted near-verbatim by `implementation-workflow.md`, so the two
      must agree after Phase 4 lands).
- [x] `core/context/contracts/wrap-up.md` (1 occurrence): migrate the postflight commit reference.
- [x] `core/context/checkpoints/checkpoint-commit.md` (1 occurrence): migrate the generic
      "Create Commit" checkpoint stage.
- [x] `core/skills/skill-git-workflow/SKILL.md` (2 occurrences): the dedicated "how to git commit"
      skill currently does not use its own sibling script. Migrate both.
- [x] Use `core/skills/skill-planner/SKILL.md`'s existing invocation block as the reference shape:
      `bash .claude/scripts/git-commit-scoped.sh --message "..." --session "${session_id}" -- <pathspecs>`.
- [x] For any of these sites that stage `specs/state.json` or `specs/TODO.md`, add
      `--honest-index-rows <task_number>`.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: 6 files / 19 occurrences, per the research report's Tier 0 table
(re-confirmed at plan time by `grep -rc 'git commit -m'` over `core/`). Confirm at implementation
time by running `grep -c 'git commit -m' <file>` on each of the six before and after editing;
`git-safety.md`'s 13 is the number most likely to have drifted.

**Files to modify**:
- `agent-system/extensions/core/context/templates/command-template.md` - scaffold commit block
- `agent-system/extensions/core/docs/templates/command-template.md` - docs mirror of the same
- `agent-system/extensions/core/context/standards/git-safety.md` - all commit guidance and XML stage blocks
- `agent-system/extensions/core/context/contracts/wrap-up.md` - postflight commit reference
- `agent-system/extensions/core/context/checkpoints/checkpoint-commit.md` - Create Commit stage
- `agent-system/extensions/core/skills/skill-git-workflow/SKILL.md` - both commit snippets

**Verification**:
- `grep -c 'git commit -m'` returns 0 for each of the six files.
- `grep -c 'git-commit-scoped.sh'` returns at least 1 for each of the six files.
- Every migrated snippet passes a body without a trailing `Session:` line plus an explicit
  `--session` flag and at least one positive pathspec after `--`.
- Record the whole-tree remaining count: `grep -rl 'git commit -m' agent-system/extensions/ | wc -l`.

---

### Phase 2: Migrate the core commands [COMPLETED]

**Goal**: Convert the surviving high-traffic core command files.

**Tasks**:
- [x] `core/commands/todo.md` (7 occurrences) — the largest single command-file concentration;
      read the surrounding archival flow before converting, since some of its commits stage
      `specs/TODO.md` and `specs/state.json` and therefore need `--honest-index-rows`.
- [x] `core/commands/task.md` (2 occurrences).
- [x] `core/commands/errors.md` (1 occurrence).
- [x] `core/commands/review.md` (1 occurrence).
- [ ] Do NOT look for `commands/research.md`, `commands/plan.md`, or `commands/implement.md` —
      those three files were deleted earlier in this batch and their absence is confirmed.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: 4 files / 11 occurrences. Confirm with
`grep -rc 'git commit -m' agent-system/extensions/core/commands/` before editing; the result
should list exactly these four files and no others.

**Files to modify**:
- `agent-system/extensions/core/commands/todo.md` - 7 commit sites across the archival flow
- `agent-system/extensions/core/commands/task.md` - 2 commit sites
- `agent-system/extensions/core/commands/errors.md` - 1 commit site
- `agent-system/extensions/core/commands/review.md` - 1 commit site

**Verification**:
- `grep -rc 'git commit -m' agent-system/extensions/core/commands/` returns nothing (no file with
  a nonzero count).
- Each converted site names explicit pathspecs matching what its preceding `git add` staged.

---

### Phase 3: Migrate the core skills and agents [COMPLETED]

**Goal**: Convert the remaining core skill and agent definition files.

**Tasks**:
- [x] `core/skills/skill-reviser/SKILL.md` (2 occurrences).
- [x] `core/skills/skill-spawn/SKILL.md` (1 occurrence).
- [x] `core/skills/skill-meta/SKILL.md` (1 occurrence).
- [x] `core/skills/skill-project-overview/SKILL.md` (1 occurrence).
- [x] `core/skills/skill-fix-it/SKILL.md` (1 occurrence).
- [x] `core/agents/meta-builder-agent.md` (1 occurrence).
- [x] For each, reuse the pathspecs the site already stages; where a site stages a task directory,
      do not hand-write the ephemeral exclusion set — the script injects it.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: 6 files / 7 occurrences. Confirm with
`grep -rc 'git commit -m' agent-system/extensions/core/skills/ agent-system/extensions/core/agents/`
before editing.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-reviser/SKILL.md`
- `agent-system/extensions/core/skills/skill-spawn/SKILL.md`
- `agent-system/extensions/core/skills/skill-meta/SKILL.md`
- `agent-system/extensions/core/skills/skill-project-overview/SKILL.md`
- `agent-system/extensions/core/skills/skill-fix-it/SKILL.md`
- `agent-system/extensions/core/agents/meta-builder-agent.md`

**Verification**:
- `grep -rc 'git commit -m'` over `core/skills/` and `core/agents/` returns no nonzero counts.
- `skill-git-workflow/SKILL.md` (Phase 1) and these files agree on invocation shape.

---

### Phase 4: Migrate the core process and pattern docs, including the manual-recovery blocks [COMPLETED]

**Goal**: Convert the automated call sites embedded in workflow/pattern/troubleshooting docs, and
make the deliberate call on the "Manual commit required" human-recovery blocks.

**Tasks**:
- [x] `core/context/processes/implementation-workflow.md` (3 occurrences) — real automated call
      sites in the phase-commit and final-commit XML stages; these quote `git-safety.md` (Phase 1)
      near-verbatim, so reconcile the two texts.
- [x] `core/context/patterns/subagent-continuation-loop.md` (2 occurrences) — real automated sites
      (mid-loop and final commit).
- [x] `core/context/patterns/file-metadata-exchange.md` (1 occurrence) — real call site whose own
      comment already cites `git-staging-scope.md` yet ends in a bare commit.
- [x] `core/context/patterns/checkpoint-before-overflow.md` (1 occurrence) — checkpoint-before-handoff commit.
- [x] `core/context/troubleshooting/workflow-interruptions.md` (1 occurrence) — real automated site.
- [x] **Deliberate judgment call, adopted from the research recommendation**: migrate the
      "Manual commit required" human-recovery blocks too, in
      `core/context/processes/research-workflow.md` (1), `core/context/processes/planning-workflow.md` (1),
      and the manual-fallback occurrence in `core/context/standards/error-handling.md`. Nothing
      executes these unattended, but a hand-typed recovery commit is exactly the moment scope gets
      fat-fingered, and the scoped form is no harder to paste. Record this as a decision in the
      task summary, not a silent mechanical rewrite. *(completed: all three manual-recovery blocks
      migrated to git-commit-scoped.sh)*
- [x] `core/context/standards/error-handling.md`'s second occurrence
      (`git commit -m "feat: Add new module"`) is a generic illustrative example unrelated to the
      dispatch pipeline. Read it in place and decide: either recast it so it no longer models the
      raw form, or record it as a sixth exemption with a stated reason. Do not leave it
      undecided. *(completed: recast to the scoped-commit form rather than exempted — trivial to
      keep consistent with the rest of the guide)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: 8 files / 12 occurrences, of which 3 are manual-recovery prose and 1 is a
generic illustrative example. Confirm by reading each occurrence in context before converting —
the automated-vs-manual-vs-illustrative split is the load-bearing judgment in this phase and
cannot be derived from a grep count.

**Files to modify**:
- `agent-system/extensions/core/context/processes/implementation-workflow.md` - 3 automated sites
- `agent-system/extensions/core/context/processes/research-workflow.md` - manual-recovery block
- `agent-system/extensions/core/context/processes/planning-workflow.md` - manual-recovery block
- `agent-system/extensions/core/context/standards/error-handling.md` - 1 manual-recovery + 1 illustrative
- `agent-system/extensions/core/context/patterns/subagent-continuation-loop.md` - 2 automated sites
- `agent-system/extensions/core/context/patterns/file-metadata-exchange.md` - 1 automated site
- `agent-system/extensions/core/context/patterns/checkpoint-before-overflow.md` - 1 automated site
- `agent-system/extensions/core/context/troubleshooting/workflow-interruptions.md` - 1 automated site

**Verification**:
- Every remaining `git commit -m` occurrence in these eight files is either gone or recorded with
  a stated exemption reason.
- `implementation-workflow.md`'s XML stage blocks and `git-safety.md`'s corresponding blocks
  contain the same commit invocation text.

---

### Phase 5: Migrate the core doc guides and worked examples [COMPLETED WITH EXCLUSIONS]

**Goal**: Convert the remaining core documentation that teaches or demonstrates the commit shape.

**Tasks**:
- [x] `core/docs/guides/creating-commands.md` (1 occurrence).
- [x] `core/docs/guides/creating-skills.md` (1 occurrence).
- [x] `core/docs/guides/permission-configuration.md` (2 occurrences) — check whether either
      occurrence is a permission-rule pattern string rather than an invocation; if it is a
      permission matcher, record it as an exemption with a reason instead of rewriting it.
- [x] `core/docs/guides/user-installation.md` (1 occurrence). *(deviation: exempted — this is
      a one-time human bootstrap step run before the agent system exists in the project, so
      git-commit-scoped.sh is not yet available; outside the scoped-commit contract's scope.
      Annotated inline in the file.)*
- [x] `core/docs/examples/research-flow-example.md` (1 occurrence).
- [x] `core/docs/examples/fix-it-flow-example.md` (1 occurrence).

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: 6 files / 7 occurrences. Confirm with
`grep -rc 'git commit -m' agent-system/extensions/core/docs/` (excluding
`docs/templates/command-template.md`, which Phase 1 owns) before editing. The
`permission-configuration.md` pair is the occurrence most likely to be a non-invocation.

**Files to modify**:
- `agent-system/extensions/core/docs/guides/creating-commands.md`
- `agent-system/extensions/core/docs/guides/creating-skills.md`
- `agent-system/extensions/core/docs/guides/permission-configuration.md`
- `agent-system/extensions/core/docs/guides/user-installation.md`
- `agent-system/extensions/core/docs/examples/research-flow-example.md`
- `agent-system/extensions/core/docs/examples/fix-it-flow-example.md`

**Verification**:
- Diff read-through confirming every changed hunk lies inside a fenced code block or prose region
  of a documentation file — no executable surface is touched by this phase.
- `grep -rc 'git commit -m' agent-system/extensions/core/docs/` returns no nonzero counts apart
  from any explicitly recorded exemption.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| `core/docs/guides/user-installation.md` (`git commit -m "Initial commit"`) | One-time human bootstrap step (`git init && git add . && git commit -m "Initial commit"`) run by the user in their terminal before the agent system is installed in the project — `.claude/scripts/git-commit-scoped.sh` does not exist yet at this point in the walkthrough, so migrating it would reference a script the reader cannot yet call. Outside the scoped-commit contract's scope, which governs agent-driven task commits after installation. | `agent-system/extensions/core/docs/guides/user-installation.md` Step 2, annotated inline with this reasoning. |

---

### Phase 6: Migrate the founder extension [COMPLETED]

**Goal**: Convert the largest single extension territory: founder's commands, skills, and
implementation agent.

**Tasks**:
- [x] Enumerate the territory first:
      `grep -rln 'git commit -m' agent-system/extensions/founder/`.
- [x] Open each file before editing. Research sampled `skill-analyze` and `skill-grant` (2 sites)
      and found the uniform narrow-`git add` + bare-`git commit -m "task ${n}: ..."` shape, but
      the remaining files are hypotheses, not confirmed. *(note: `skill-grant` is actually under
      `present/`, not `founder/` — a stale cross-reference in the plan text, harmless since this
      phase's file list was re-derived from the live enumeration grep, not from this note)*
- [x] Convert each site, reusing its existing pathspecs and message body.
- [x] Flag any outlier — a site staging paths outside the task directory, or staging a whole tree
      — as a candidate exemption with a written reason rather than converting it. *(none found —
      all 26 founder sites matched the uniform task-scoped shape)*
- [x] Note that `skill-grant` carries two sites in one file; do not stop after the first.
      *(N/A to this phase — see note above; founder-implement-agent.md carried the multi-site
      file in this territory, all 5 sites converted)*

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: 26 files (10 commands + 15 skills + `founder-implement-agent.md`), ~26
occurrences. Confirm by running the enumeration grep above and comparing the file count to 26
before editing; a mismatch means the tree moved and the phase's file list must be re-derived from
the live grep, not from this plan.

**Files to modify**:
- `agent-system/extensions/founder/**` - all files returned by the enumeration grep (~26)

**Verification**:
- `grep -rl 'git commit -m' agent-system/extensions/founder/` returns nothing, or returns only
  files recorded as exemptions with stated reasons.
- Spot-check three converted files for: no trailing `Session:` line inside `--message`, an
  explicit `--session`, and at least one positive pathspec after `--`.

---

### Phase 7: Migrate the present and lean extensions [NOT STARTED]

**Goal**: Convert the second- and third-largest extension territories.

**Tasks**:
- [ ] Enumerate: `grep -rln 'git commit -m' agent-system/extensions/present/ agent-system/extensions/lean/`.
- [ ] present: 5 commands + 7 skills. Open each before editing.
- [ ] lean: 4 skills + 2 agents. Open each before editing; lean's implementation agents may
      commit proof artifacts, so check whether any stages paths outside a task directory.
- [ ] Convert each site; record any outlier as a candidate exemption with a reason.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: 18 files (present 12, lean 6), ~18 occurrences. Confirm with the
enumeration grep; `skill-lean-implementation` was one of the seven files research read directly
and is confirmed to follow the uniform shape, the rest are hypotheses.

**Files to modify**:
- `agent-system/extensions/present/**` - ~12 files
- `agent-system/extensions/lean/**` - ~6 files

**Verification**:
- `grep -rl 'git commit -m'` over both extension roots returns nothing, or only recorded
  exemptions.

---

### Phase 8: Migrate the filetypes, web, epidemiology, and cslib extensions [NOT STARTED]

**Goal**: Convert the mid-sized extension territories.

**Tasks**:
- [ ] Enumerate:
      `grep -rln 'git commit -m' agent-system/extensions/filetypes/ agent-system/extensions/web/ agent-system/extensions/epidemiology/ agent-system/extensions/cslib/`.
- [ ] filetypes: 5 commands (convert, edit, scrape, sheet, table). `table.md` was read directly
      during research and follows the uniform shape.
- [ ] web: 2 skills + 1 agent.
- [ ] epidemiology: `commands/epi.md` + 2 skills.
- [ ] cslib: `commands/pr.md` + `skill-cslib-vet` + `cslib-implementation-hard-agent.md`.
      `commands/pr.md` is the one user-invoked command permitted to push and open PRs — read its
      commit site carefully and confirm the commit being migrated is a local task-scoped commit
      and not part of the push/PR flow. If it is not task-scoped, record it as an exemption.
- [ ] Convert each site; record any outlier as a candidate exemption with a reason.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: 14 files (filetypes 5, web 3, epidemiology 3, cslib 3), ~14 occurrences.
Confirm with the enumeration grep. `cslib/commands/pr.md` is the site most likely to warrant an
exemption.

**Files to modify**:
- `agent-system/extensions/filetypes/**` - ~5 command files
- `agent-system/extensions/web/**` - ~3 files
- `agent-system/extensions/epidemiology/**` - ~3 files
- `agent-system/extensions/cslib/**` - ~3 files

**Verification**:
- `grep -rl 'git commit -m'` over the four extension roots returns nothing, or only recorded
  exemptions.
- The `cslib/commands/pr.md` decision (migrate or exempt) is written down with its reason.

---

### Phase 9: Migrate the remaining small extensions [NOT STARTED]

**Goal**: Clear the tail — one or two files per extension.

**Tasks**:
- [ ] Enumerate the remainder:
      `grep -rl 'git commit -m' agent-system/extensions/ | grep -v '/core/' | grep -vE '/(founder|present|lean|filetypes|web|epidemiology|cslib)/'`.
- [ ] nix: `nix-implementation-agent.md` + `nixos-rebuild-guide.md` (the guide occurrence may be
      illustrative prose about rebuilding, not a task commit — read before converting).
- [ ] memory: `skill-learn/SKILL.md` + `memory-troubleshooting.md`.
- [ ] One file each in: typst, python, z3, nvim, latex, literature.
- [ ] Convert each site; record any outlier as a candidate exemption with a reason.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: 10 files (nix 2, memory 2, and 1 each in z3, typst, python, nvim,
literature, latex), ~10 occurrences. Confirm with the enumeration grep above — this phase is
defined as "whatever the grep returns outside core and the seven named extensions", so its true
scope is whatever remains after Phases 6-8, not this count.

**Files to modify**:
- `agent-system/extensions/{nix,memory,typst,python,z3,nvim,latex,literature}/**` - all files
  returned by the enumeration grep (~10)

**Verification**:
- The enumeration grep returns nothing, or only recorded exemptions.
- Whole-tree count recorded: `grep -rl 'git commit -m' agent-system/extensions/ | wc -l`.

---

### Phase 10: End-to-end exercise and acceptance verification [NOT STARTED]

**Goal**: Prove the migrated path actually works by producing a real commit through it, and
confirm the acceptance criterion holds across the whole source store.

**Tasks**:
- [ ] Redeploy the source store so `.claude/` reflects the migration:
      `bash agent-system/extensions/core/scripts/deploy-headless.sh` (consult its `--help`/header
      for the correct invocation in this repo).
- [ ] Run `bash .claude/scripts/verify-deploy.sh` and confirm the existing gate set passes.
- [ ] **End-to-end exercise (required by the acceptance criterion)**: run one migrated command
      that commits — `/todo` or `/task` is the natural candidate since both were migrated in
      Phase 2 — against real repository state, and confirm a real commit is produced through
      `git-commit-scoped.sh`. Static inspection alone does not satisfy this.
- [ ] Inspect the resulting commit: `git show --stat HEAD` and `git log -1 --format=%B`. Confirm
      (a) only the intended pathspecs are in the commit, (b) the message carries exactly one
      `Session:` line, (c) no unrelated concurrently-staged file was swept in.
- [ ] Run the acceptance grep: `grep -rl 'git commit -m' agent-system/extensions/`. The result
      must be only the exemption set.
- [ ] Write out the final exemption record — each remaining file with its stated reason. Baseline
      set from research, to be re-confirmed rather than assumed:
      `core/scripts/git-commit-scoped.sh` (the sanctioned implementation itself);
      `core/scripts/git-snapshot.sh` (deliberate whole-tree WIP snapshot on a scratch branch,
      outside the dispatch pipeline);
      `core/scripts/tests/test-guard-destructive-git.sh` (string-literal test fixtures, no commit
      executed);
      `core/hooks/guard-destructive-git.sh` (a comment illustrating a parser edge case);
      `core/context/standards/git-staging-scope.md` (already self-disclaims its examples as
      illustrative and names `git-commit-scoped.sh` as canonical).
      Add any further exemptions decided in Phases 4, 5, 8, or 9.
- [ ] Run the existing test suites under `core/scripts/tests/` and confirm they still pass.

**Timing**: 1 hour

**Depends on**: 2, 3, 4, 5, 6, 7, 8, 9

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: the acceptance grep is expected to return exactly 5 files (the baseline
exemption set), plus any exemptions newly decided in Phases 4, 5, 8, or 9. Confirm by running the
grep and reconciling its output file-by-file against the written exemption record — an unexplained
file in the output means a phase missed a site, not that the exemption list should be widened to
absorb it.

**Files to modify**:
- No source-store files are expected to change in this phase; any file the acceptance grep
  surfaces as an unexplained miss is migrated here and attributed to the phase that missed it.

**Verification**:
- The complete repository gate set passes: `verify-deploy.sh` exits 0, and the
  `core/scripts/tests/` suites pass.
- A real commit exists whose message and file list were inspected and match expectations.
- `grep -rl 'git commit -m' agent-system/extensions/` output is fully accounted for by the
  written exemption record.

---

### Phase 11: Add lint-scoped-commit-boundary.sh and wire it into the deploy gate set [NOT STARTED]

**Goal**: Make the raw form mechanically impossible to reintroduce, closing the regrowth path the
task explicitly asks to settle.

**Tasks**:
- [ ] Read `core/scripts/lint/lint-state-writer-boundary.sh` in full — it is the design template
      (two layers: a broad candidate regex over `.md`/`.sh` files, narrowed by a structural line
      classifier, plus a short reason-carrying file-level allowlist).
- [ ] Write `core/scripts/lint/lint-scoped-commit-boundary.sh`:
      - Candidate detection: `git commit -m` across `.md` and `.sh` files in the source store.
      - Structural classifier: a compliant occurrence ends in a trailing `-- <pathspec>` — this
        mirrors `git-staging-scope.md`'s own stated rule that a commit lacking a trailing pathspec
        is a Forbidden Operation. Everything else is a candidate violation.
      - File-level allowlist: exactly the exemption set finalized in Phase 10, each entry carrying
        its reason inline — never a bare path list. Include the lint's own path and its test
        fixture, mirroring `lint-state-writer-boundary.sh`'s self-reference exemption.
      - Match the sibling lints' `--verbose` behavior and exit-code convention.
- [ ] Write `core/scripts/tests/test-lint-scoped-commit-boundary.sh`, mirroring
      `test-lint-state-writer-boundary.sh`'s structure: a dirty fixture the lint must flag, a
      clean fixture it must pass, and verbose-mode assertions.
- [ ] Register both in `core/manifest.json`: the lint in the `lint/` list (alongside
      `lint-state-writer-boundary.sh`), the test in the `tests/` list.
- [ ] Add the lint as a new numbered gate in `core/scripts/verify-deploy.sh`, immediately after
      the current final gate. Follow the `[SKIP]`-if-not-source-store posture used by the sibling
      gates, and match gate 12's invocation style
      (`lint-state-writer-boundary.sh --verbose`). Derive the new gate's number from the live
      file at implementation time rather than hardcoding it from this plan.
- [ ] Add a one-line pointer from `core/context/standards/git-staging-scope.md` to the new lint,
      so a future contributor discovers that a mechanical check exists.
- [ ] Redeploy and run the full gate set; the new gate must pass on the migrated tree.

**Timing**: 1.5 hours

**Depends on**: 10

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: 5 files touched (new lint script, new test script, `manifest.json`,
`verify-deploy.sh`, `git-staging-scope.md`). The research report placed the new gate at 17;
`verify-deploy.sh` currently ends at a gate numbered 16, but confirm the live final gate number by
reading the file before assigning one — do not trust either number from this plan.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh` - new lint
- `agent-system/extensions/core/scripts/tests/test-lint-scoped-commit-boundary.sh` - new test
- `agent-system/extensions/core/manifest.json` - register lint and test
- `agent-system/extensions/core/scripts/verify-deploy.sh` - new gate
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - pointer to the lint

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lint-scoped-commit-boundary.sh` passes
  (dirty fixture flagged, clean fixture passes).
- The new lint run standalone over the migrated source store reports zero violations.
- `verify-deploy.sh` exits 0 with the new gate present in its output and the check count
  incremented by one.
- The complete existing test suite under `core/scripts/tests/` still passes.

---

## Testing & Validation

- [ ] `grep -rl 'git commit -m' agent-system/extensions/` returns only files present in the written
      exemption record, each with a stated reason.
- [ ] `grep -rl 'git-commit-scoped.sh' agent-system/extensions/` has grown from 24 files to cover
      every migrated call site.
- [ ] Every existing test under `agent-system/extensions/core/scripts/tests/` passes.
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0 after redeploy, with the new gate included.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-lint-scoped-commit-boundary.sh` passes.
- [ ] At least one migrated command was run for real and produced a commit whose file list and
      message were inspected and match expectations (one `Session:` line, only intended paths).
- [ ] No file under `.claude/**` was hand-edited at any point; every deployed change arrived via
      redeploy from `agent-system/extensions/**`.
- [ ] No source-store file gained a task-number reference (commit messages are exempt).

## Artifacts & Outputs

- Migrated source-store files: ~98 files across `agent-system/extensions/core/**` and 15
  non-core extensions.
- `agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh` (new).
- `agent-system/extensions/core/scripts/tests/test-lint-scoped-commit-boundary.sh` (new).
- Updated `agent-system/extensions/core/manifest.json` and
  `agent-system/extensions/core/scripts/verify-deploy.sh`.
- An implementation summary at
  `specs/048_propagate_scoped_commit_to_all_call_sites/summaries/01_scoped-commit-call-site-migration-summary.md`
  containing the exemption record: every file still matching the acceptance grep, each with its
  stated reason, plus the recorded outcome of the manual-recovery-block judgment call and the
  `cslib/commands/pr.md` decision.

## Rollback/Contingency

Every phase commits through `git-commit-scoped.sh` with explicit pathspecs, so each phase is an
independently revertable commit — `git revert <sha>` for a single bad phase, without disturbing
the others. The migration is text-only in the source store and touches no runtime state, so a
revert restores prior behavior exactly once `.claude/` is redeployed from the reverted source
store.

If a phase is interrupted mid-way, mark it `[PARTIAL]`, record which files in its enumerated
territory were converted, and resume from the phase's own enumeration grep — the grep is
self-correcting and will list exactly the files still needing work.

If Phase 10's end-to-end run reveals a defect in a migrated invocation shape (rather than in
`git-commit-scoped.sh` itself), fix the shape at its source — the Phase 1 templates and reference
docs — and re-derive the affected downstream sites, rather than patching individual call sites.
If the defect is in `git-commit-scoped.sh`, stop: that is outside this task's scope and needs its
own task.

Phase 11 is independently revertable and carries no migration risk; if the new gate proves too
noisy, revert the `verify-deploy.sh` and `manifest.json` registration while keeping the lint
script on disk for standalone use.

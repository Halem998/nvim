# Implementation Plan: Task #786

- **Task**: 786 - Propagate scoped-staging convention across all agent/command/skill templates
- **Status**: [COMPLETED]
- **Effort**: 3.5 hours
- **Dependencies**: 785 (completed — canonical `git-staging-scope.md` pattern established)
- **Research Inputs**: specs/786_propagate_scoped_staging_templates/reports/01_propagate-scoped-staging-templates.md
- **Artifacts**: plans/01_propagate-scoped-staging.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Sweep every remaining `git add -A` reference in the agent system (124 raw grep hits) to the
canonical scoped-staging pattern defined in `.claude/context/standards/git-staging-scope.md`,
established by task 785. Task 785 fixed only the 6-item core commit pipeline; this task
propagates the same "under-stage, never over-stage" template to the parallel command/skill
final-commit stages, the generator templates that new components copy from, the hard-mode and
deployed-extension agents, and the large single-copy founder/present extension tail. Work is
grouped by category so related edits (and their byte-identical dual-copy pairs) land together,
every phase re-verifies dual-copy pairs with `diff -q`, the three intentional exceptions are
preserved, and an explicit decision is made on the one ambiguous site (`cslib/pr.md:569`).
Definition of done: `grep -rn "git add -A" .claude/` returns only the documented intentional
exceptions plus policy-prose mentions that must name the forbidden command.

### Research Integration

The plan follows the Category A-J classification in report `01_propagate-scoped-staging-templates.md`:
- **Category A** (already fixed by 785) is excluded — verified clean.
- **Categories B, B2** (core command/skill exec sites) are treated as highest priority,
  structurally equivalent to what 785 fixed. Each has a byte-identical core-extension mirror.
- **Category H** (generator templates + pattern docs) is required, not optional, per the task's
  explicit goal that new components inherit scoped staging by default.
- **Categories C, D, E** (hard-mode, deployed nix/nvim, non-deployed scattered agents/skills).
- **Categories F, G** (founder 21 sites, present 7 sites + 2 prose "manual commit recommended"
  mis-recommendations) — single-copy, mechanical.
- **Category I** (3 confirmed exceptions) is preserved untouched.
- **Category J** (`cslib/pr.md:569`) receives an explicit documented decision (Phase 6).

The canonical reference template every phase applies is the `plan`/`implement` scoped-staging
block and Forbidden-Operations list in `git-staging-scope.md` (reuse verbatim; do not reinvent).

### Prior Plan Reference

No prior plan for task 786. Task 785 (its dependency) is the calibration reference: 785 batched
core-pair edits per file and ran a single `diff -q` verification loop at the end (its Phase 7),
and incidentally repaired an unrelated dual-copy drift it encountered. This plan reuses both
practices: per-phase pair-sync plus a final repo-wide verification phase, and incidental repair
of the known `skill-planner` literature-briefing drift (Phase 2).

### Roadmap Alignment

No `roadmap_flag` set and no ROADMAP.md consultation requested for this dispatch. No roadmap
phases added.

## Goals & Non-Goals

**Goals**:
- Convert all Category B/B2/C/D/E/F/G/H `git add -A` exec and template sites to the canonical
  scoped-staging pattern from `git-staging-scope.md`.
- Keep every byte-identical dual-copy pair (core, nix, nvim mirrors) in sync — edit both copies,
  verify with `diff -q` per phase.
- Update generator templates so newly-created commands/skills inherit scoped staging by default.
- Make and implement an explicit decision on the ambiguous `cslib/pr.md:569` site.
- End state: `grep -rn "git add -A" .claude/` returns only documented intentional exceptions and
  required policy-prose mentions.

**Non-Goals**:
- Do NOT touch the 3 confirmed intentional exceptions: `git-snapshot.sh:150` (full-tree WIP
  snapshot), `cslib/pr.md` STEP 10 lines 1824/1849/1859 (deliberate add-then-exclude flow),
  `email-preferences.md:141` (already-aligned warning prose).
- Do NOT re-touch Category A files already fixed and verified clean by 785.
- Do NOT consolidate the two same-named `command-template.md` files (`docs/templates/` vs
  `context/templates/`) — fix both in place; consolidation is out of scope.
- Do NOT alter policy-prose that must name `git add -A` to forbid it (git-workflow.md,
  git-staging-scope.md, skill-git-workflow, git-safety.md "Never Run" lists).
- No new scoped-staging design — only propagation of the existing 785 template.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Dual-copy drift (core/nix/nvim pair edited on only one side) | M | M | Every phase edits both copies then runs `diff -q` on each pair; Phase 6 re-runs a repo-wide pair-diff sweep |
| Accidentally "fixing" cslib/pr.md STEP 10's deliberate exclude-flow | H | L | Phase 6 explicitly excludes lines 1824/1849/1859; only line 569 is in scope, and only as a documented decision |
| research.md CHECKPOINT 3 redundant with `orchestrator-postflight.sh` (`do_git_commit=false`) | M | M | Phase 1 confirms which path actually fires before deciding whether research.md needs full scoped logic or should reflect `do_git_commit=false`/delegate |
| skill-planner pre-existing literature-briefing drift causes `diff -q` mismatch after edit | L | H | Phase 2 repairs the known drift incidentally (as 785 did) and records it as a deviation |
| founder/present breadth (28+ sites) risks a missed site | M | M | Phases 5 uses per-extension grep-before/grep-after to confirm zero remaining hits in that subtree |
| Removing a template `git add -A` without a scoped replacement leaves a commit-less step | M | L | Each conversion substitutes the canonical scoped block (or `do_git_commit=false` delegation), never a bare deletion |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 4, 5 | -- |
| 2 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel — they touch disjoint file sets (verified
against the Category A-J inventory; no phase shares a file with another). Phase 6 is the
convergence/verification phase and depends on all edits landing first.

---

### Phase 1: Core command-pipeline exec sites (Category B) [COMPLETED]

**Goal**: Convert the inline "CHECKPOINT 3: COMMIT" `git add -A` in each core command file to the
canonical scoped-staging pattern, keeping each core-extension mirror byte-identical.

**Tasks**:
- [x] Re-read `git-staging-scope.md` Per-Operation Scope + Reference Template before editing. *(completed)*
- [x] `commands/research.md:473` — reconcile against `orchestrator-postflight.sh`'s `research`
      branch (`do_git_commit=false`): confirm which path fires; convert the inline step to reflect
      `do_git_commit=false`/delegate, or apply the `research` scope (reports/ + .return-meta.json
      + TODO.md + state.json) if the inline commit genuinely executes. *(completed: confirmed
      orchestrator-postflight.sh is not wired into the single-task /research command flow — the
      inline CHECKPOINT 3 genuinely executes — applied the `research` scope)*
- [x] `commands/plan.md:500` — apply `plan` scope (`specs/{padded}_{slug}/` + TODO.md + state.json). *(completed)*
- [x] `commands/implement.md:187,192` — apply `implement` scope (plan scope + plan_path +
      `modified_files`) on both completion and partial branches; include the loud under-stage warning. *(completed)*
- [x] `commands/orchestrate.md:250,258,375,382` — batch commit must iterate the scope over each
      task dir in the range; per-task commit uses single-task scope (complete + paused branches). *(completed)*
- [x] `commands/errors.md:197` — scope to `specs/errors.json` + generated task dir(s). *(completed)*
- [x] Mirror every edit into `.claude/extensions/core/commands/{research,plan,implement,orchestrate,errors}.md`
      at the same lines. *(completed)*
- [x] `diff -q` each of the 5 pairs; confirm identical. *(completed: all 5 pairs diff -q clean)*

**Timing**: 45 min

**Depends on**: none

**Files to modify**:
- `.claude/commands/{research,plan,implement,orchestrate,errors}.md` ↔ `.claude/extensions/core/commands/{...}.md`

**Verification**:
- `grep -n "git add -A" .claude/commands/{research,plan,implement,orchestrate,errors}.md` returns 0.
- `diff -q` clean for all 5 core-extension pairs.

---

### Phase 2: Core skill final-commit stages (Category B2) [COMPLETED]

**Goal**: Convert the final "Git Commit" stages in the four core skills to scoped staging, sync
their core mirrors, and incidentally repair the known `skill-planner` literature-briefing drift.

**Tasks**:
- [x] `skills/skill-planner/SKILL.md:501` — apply `plan` scope at Stage 9 Git Commit. *(completed)*
- [x] Repair the pre-existing `literature-briefing.sh` vs `literature-briefing-invoke.sh` drift
      (~lines 223/249/255/261) between `skill-planner` and its core mirror so `diff -q` passes;
      record this as a deviation in the summary. *(completed: repaired by copying the deployed
      skill-planner/SKILL.md over its core mirror — see Plan Deviations in the summary)*
- [x] `skills/skill-reviser/SKILL.md:426,438` — apply task-dir scope at Stage 9 (plan-revision +
      description-update branches). *(completed)*
- [x] `skills/skill-spawn/SKILL.md:445` — scope to parent task dir + new spawned task dirs +
      TODO.md + state.json. *(completed)*
- [x] `skills/skill-todo/SKILL.md:738` — purpose-built archive scope (`specs/archive/`,
      `specs/TODO.md`, `specs/state.json`, and `specs/CHANGE_LOG.md` when touched); NOT the
      single-task template. *(completed: also conditionally scoped ROADMAP.md, README.md, and
      .memory/ since those stages can also produce changes this run)*
- [x] Mirror each edit into `.claude/extensions/core/skills/{skill-planner,skill-reviser,skill-spawn,skill-todo}/SKILL.md`. *(completed)*
- [x] `diff -q` each of the 4 pairs (skill-planner pair only after drift repair). *(completed: all 4 pairs clean)*

**Timing**: 45 min

**Depends on**: none

**Files to modify**:
- `.claude/skills/{skill-planner,skill-reviser,skill-spawn,skill-todo}/SKILL.md` ↔ core mirrors

**Verification**:
- `grep -n "git add -A" .claude/skills/{skill-planner,skill-reviser,skill-spawn,skill-todo}/SKILL.md` returns 0.
- `diff -q` clean for all 4 pairs.

---

### Phase 3: Generator templates and pattern docs (Category H) [COMPLETED]

**Goal**: Replace the `git add -A` taught by generator templates and checkpoint/pattern docs with
the scoped-staging pattern, so any newly-generated command/skill inherits scoped staging. Sync all
core mirrors.

**Tasks**:
- [x] `docs/guides/creating-commands.md:127` (CHECKPOINT 3 template). *(completed)*
- [x] `docs/guides/creating-skills.md:403` (Stage 8 template). *(completed)*
- [x] `docs/templates/command-template.md:79` (CHECKPOINT 3 boilerplate). *(completed)*
- [x] `context/templates/command-template.md:69` (separate file, same fix in place — do NOT merge
      with the docs/templates copy; note the duplication in the summary). *(completed: both
      copies fixed independently, duplication preserved as-is per plan)*
- [x] `docs/examples/research-flow-example.md:239` (illustrative transcript — fix the example). *(completed)*
- [x] `context/patterns/subagent-continuation-loop.md:127` (Per-Continuation Git Commits pattern). *(completed)*
- [x] `context/patterns/file-metadata-exchange.md:274` (generic commit-after-metadata pattern). *(completed)*
- [x] `context/patterns/checkpoint-execution.md:114` (Checkpoint 3: COMMIT pattern). *(completed)*
- [x] `context/patterns/checkpoint-before-overflow.md:68` (overflow-handoff checkpoint). *(completed)*
- [x] `context/troubleshooting/workflow-interruptions.md:217` ("Manually commit if needed" snippet). *(completed)*
- [x] `context/checkpoints/checkpoint-commit.md:10` (standalone checkpoint-commit doc). *(completed)*
- [x] Mirror each edit into the corresponding `.claude/extensions/core/{...}` twin. *(completed)*
- [x] `diff -q` each pair. *(completed: all 11 pairs clean)*

**Timing**: 45 min

**Depends on**: none

**Files to modify**:
- The 11 files above under `.claude/{docs,context}/` ↔ their `.claude/extensions/core/` mirrors

**Verification**:
- `grep -rn "git add -A" .claude/docs/ .claude/context/` returns only intentional policy-prose
  (git-staging-scope.md, git-safety.md, return-metadata-file.md, progress-file.md).
- `diff -q` clean for all pairs.

---

### Phase 4: Hard-mode + deployed + scattered extension agents/skills (Categories C, D, E) [COMPLETED]

**Goal**: Convert per-phase/final commit templates in hard-mode agents, deployed nix/nvim agent
pairs, and the scattered single-copy non-deployed extension agents/skills.

**Tasks**:
- [x] `agents/general-implementation-hard-agent.md:301` ↔ core mirror — mirror the non-hard
      agent's scoped treatment (779/781 cluster completed; no edit conflict). *(completed)*
- [x] `extensions/lean/agents/lean-implementation-hard-agent.md:315` — single copy. *(completed)*
- [x] `extensions/cslib/agents/cslib-implementation-hard-agent.md:288` — single copy. *(completed)*
- [x] `agents/nix-implementation-agent.md:384` ↔ `extensions/nix/agents/nix-implementation-agent.md:384`. *(completed)*
- [x] `agents/neovim-implementation-agent.md:364` ↔ `extensions/nvim/agents/neovim-implementation-agent.md:364`. *(completed)*
- [x] `extensions/python/agents/python-implementation-agent.md:116`. *(completed)*
- [x] `extensions/web/agents/web-implementation-agent.md:432`,
      `extensions/web/skills/skill-web-implementation/SKILL.md:318`,
      `extensions/web/skills/skill-web-research/SKILL.md:213`. *(completed)*
- [x] `extensions/latex/agents/latex-implementation-agent.md:113`. *(completed)*
- [x] `extensions/z3/agents/z3-implementation-agent.md:111`. *(completed)*
- [x] `extensions/typst/agents/typst-implementation-agent.md:95`. *(completed)*
- [x] `extensions/literature/skills/skill-literature/SKILL.md:1573`. *(completed: deviation — this
      commit runs inside `$LITERATURE_DIR`, a separate git repo with no task-dir concept, so
      applied a targeted staging list of this import's own artifacts (symlink, index.json,
      converted markdown) instead of the standard task-dir scope; see Plan Deviations)*
- [x] `extensions/epidemiology/skills/skill-epi-implement/SKILL.md:223`,
      `extensions/epidemiology/skills/skill-epi-research/SKILL.md:213`. *(completed)*
- [x] `diff -q` the 3 dual-copy pairs (general-implementation-hard, nix, neovim). *(completed: all 3 clean)*

**Timing**: 40 min

**Depends on**: none

**Files to modify**:
- `.claude/agents/{general-implementation-hard-agent,nix-implementation-agent,neovim-implementation-agent}.md` ↔ mirrors
- Single-copy extension files under `extensions/{lean,cslib,python,web,latex,z3,typst,literature,epidemiology}/`

**Verification**:
- `grep -n "git add -A"` returns 0 for each edited file.
- `diff -q` clean for the 3 dual-copy pairs.

---

### Phase 5: founder + present extension sweep (Categories F, G) [COMPLETED]

**Goal**: Mechanically convert the founder (21 sites) and present (7 exec + 2 prose) single-copy
extension sites to scoped staging, including the two present "Manual commit recommended: git add
-A" prose lines that mis-recommend the forbidden pattern to the user.

**Tasks**:
- [x] founder: `extensions/founder/commands/consult.md:235`. *(completed)*
- [x] founder: `extensions/founder/agents/founder-implement-agent.md:235,263,290,341,396` (5 sites). *(completed:
      phase 4's typst/markdown/PDF outputs live outside the task dir under `founder/`/`strategy/`,
      so those two commits additionally stage `$typst_file`/`$output_path`/the compiled PDF)*
- [x] founder: the 15 skill files (`skill-deck-research`, `skill-strategy`, `skill-finance`,
      `skill-meeting`, `skill-founder-implement`, `skill-analyze`, `skill-legal`,
      `skill-founder-spreadsheet`, `skill-market`, `skill-deck-plan:470`, `skill-founder-plan:208`,
      `skill-consult:194`, `skill-deck-implement:243`, `skill-financial-analysis:210`,
      `skill-project:266`) — one `git add -A` each. *(completed)*
- [x] present: `skill-slide-critic:450`, `skill-slides:303`, `skill-budget:289`,
      `skill-timeline:330`, `skill-slide-planning:394` (exec sites). *(completed: skill-slides
      and skill-timeline are multi-workflow skills without a single fixed artifact sub-type per
      commit, so both use the task-dir-level scope — a superset covering reports/plans/summaries
      — rather than branching per workflow_type)*
- [x] present: `skill-grant:511` (exec) + `:966` (prose "Manual commit recommended" — correct it),
      `skill-funds:385` (exec) + `:479` (same prose — correct it). *(completed)*
- [x] Grep-before / grep-after per extension subtree to confirm zero remaining exec hits. *(completed:
      both subtrees return 0 hits)*

**Timing**: 35 min

**Depends on**: none

**Files to modify**:
- `extensions/founder/**` (17 files), `extensions/present/**` (7 files) — all single-copy

**Verification**:
- `grep -rn "git add -A" .claude/extensions/founder/ .claude/extensions/present/` returns 0.

---

### Phase 6: cslib/pr.md:569 decision + final verification [COMPLETED]

**Goal**: Implement the explicit decision on the ambiguous site, confirm the 3 intentional
exceptions survive untouched, re-verify every dual-copy pair, and assert the end-state grep.

**Decision on `cslib/pr.md:569` (STEP 0.5.4 "apply review feedback" commit)**: DOCUMENT AS
EXCEPTION — do NOT convert to scoped staging. Rationale: (1) this block executes inside
`$CSLIB_DIR`, a *separate* git repository from the agent-system working tree, so the
task-directory scoping model of `git-staging-scope.md` does not map — there is no agent-system
task-dir scope to fall back to; (2) a PR review-feedback commit is by design expected to capture
whatever files the reviewer asked to change across the branch; (3) it is already guarded by a
`git status --porcelain` emptiness check. To satisfy the requirement that this not be left to
silent chance, add a brief inline comment above the `git add -A` documenting *why* it is
intentionally full-tree (parallel to STEP 10's documented note), converting a bare undocumented
command into a documented, deliberate exception. This is a comment-only edit; no behavior change.

**Tasks**:
- [x] Add the documenting inline comment above `extensions/cslib/commands/pr.md:569` per the
      decision above; do not alter the command's behavior. *(completed: 8-line comment added,
      shifting the actual `git add -A` to line 577 — behavior unchanged, verified no other
      content in the file changed)*
- [x] Confirm the 3 intentional exceptions are untouched: `scripts/git-snapshot.sh:150` (+ core
      mirror), `cslib/pr.md` STEP 10 lines 1824/1849/1859, `email-preferences.md:141`. *(completed:
      all 3 confirmed unchanged; STEP 10 lines shifted to 1832/1857/1867 due to the +8 line
      insertion above them, content identical)*
- [x] Repo-wide dual-copy sweep: for every core/nix/nvim pair edited in Phases 1-4, run `diff -q`;
      confirm all identical. *(completed: all 20 pairs across Phases 1-4 diff -q clean)*
- [x] Run `grep -rn "git add -A" .claude/` and confirm every remaining hit is one of: the 3
      intentional exceptions (git-snapshot.sh pair, cslib/pr.md STEP 10, email-preferences.md),
      the now-documented cslib/pr.md:569, or required policy-prose that names the forbidden command
      (git-workflow.md, git-staging-scope.md, skill-git-workflow, git-safety.md, return-metadata-file.md,
      progress-file.md — and their core mirrors). *(completed: 28 hits remain, all classified —
      see summary for the full itemized list)*
- [x] Record the final grep output and the allow-list classification in the implementation summary. *(completed)*

**Timing**: 30 min

**Depends on**: 1, 2, 3, 4, 5

**Files to modify**:
- `extensions/cslib/commands/pr.md` (comment only, line ~569)

**Verification**:
- `grep -rn "git add -A" .claude/` output matches the documented allow-list exactly (no
  unclassified hits).
- All dual-copy pairs `diff -q` clean.

---

## Testing & Validation

- [x] `grep -rn "git add -A" .claude/` returns only the documented allow-list (3 exceptions +
      documented cslib:569 + policy-prose mentions). *(verified: 28 hits, all classified)*
- [x] Every core-extension dual-copy pair edited is byte-identical (`diff -q` clean). *(verified: 20/20 pairs clean)*
- [x] nix and neovim deployed agent pairs are `diff -q` clean. *(verified)*
- [x] No Category A file (already fixed by 785) was modified. *(verified via `git status --porcelain
      .claude/` — none of orchestrator-postflight.sh, general-implementation-agent.md,
      skill-implementer/SKILL.md, git-workflow.md, skill-git-workflow/SKILL.md,
      git-staging-scope.md, git-safety.md, return-metadata-file.md, progress-file.md appear)*
- [x] cslib/pr.md STEP 10 exclude-flow (lines 1824/1849/1859) is unchanged. *(verified: content
      identical, lines shifted to 1832/1857/1867 due to the +8 line comment inserted at 569)*
- [x] git-snapshot.sh:150 and email-preferences.md:141 are unchanged. *(verified)*
- [x] The two present "Manual commit recommended" prose lines no longer recommend `git add -A`. *(verified:
      skill-grant.md:968 and skill-funds.md:484 now recommend targeted task-dir staging)*
- [x] Spot-check one converted command (e.g. plan.md) against `git-staging-scope.md` to confirm
      the scoped block and under-stage warning are present. *(verified: plan.md CHECKPOINT 3 now
      applies the exact `plan` scope block from git-staging-scope.md)*

## Artifacts & Outputs

- plans/01_propagate-scoped-staging.md (this file)
- summaries/01_propagate-scoped-staging-summary.md (on completion)
- Converted exec/template sites across ~50 files (Categories B, B2, C, D, E, F, G, H) with
  dual-copy mirrors synced.
- One documented exception comment at cslib/pr.md:569.

## Rollback/Contingency

All edits are text substitutions in tracked files under `.claude/`. To revert, `git checkout --`
the affected files (or revert the phase commit). Because each phase touches a disjoint file set,
a single bad phase can be reverted without disturbing the others. If a `diff -q` mismatch is found
during Phase 6 that cannot be reconciled to a known pre-existing drift, halt and re-open the
owning phase rather than force-syncing, to avoid masking an unintended content change.

# Implementation Plan: Task #785

- **Task**: 785 - Scoped git staging: eliminate `git add -A` in the commit pipeline
- **Status**: [COMPLETED]
- **Effort**: 3.5 hours
- **Dependencies**: 780 (completed — prior edit to git-workflow.md; no section overlap)
- **Research Inputs**: reports/01_scoped-git-staging-commit-pipeline.md
- **Artifacts**: plans/01_scoped-git-staging.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Replace the repo-wide `git add -A` in the core single-agent commit pipeline with targeted,
work-scoped staging so every research/plan/implement commit contains only the files the
operation actually produced — never a concurrent session's stray edits. The fix defines an
operation-type commit-scope contract as a new standard document, adds an agent-self-reported
`modified_files` mechanism for the `implement` path (the one genuinely new design piece),
rewrites the single execution site (`orchestrator-postflight.sh` Stage 9) plus the two inline
`implement`-path sites (`skill-implementer` Stage 6b and `general-implementation-agent`
per-phase commit), hardens `git-workflow.md` to explicitly forbid `git add -A`/`git commit -am`,
and establishes `skill-git-workflow` as the canonical documentation front for the contract.
Definition of done: the pipeline stages only task-scoped paths, dual-copy files stay
byte-identical, and the previously dangling `git-staging-scope.md` reference resolves.

### Research Integration

Report 01 is fully integrated. Key facts honored:
- Root cause confirmed at `.claude/scripts/orchestrator-postflight.sh:322` (`git add -A && git commit`).
- `orchestrator-postflight.sh` has a **single** copy on disk — no dual edit for that script.
- Four other pipeline files have byte-identical `.claude/` + `.claude/extensions/core/` copies
  and MUST be edited in pairs: `skill-implementer/SKILL.md`, `general-implementation-agent.md`,
  `rules/git-workflow.md`, `skill-git-workflow/SKILL.md`.
- Reuse the already-working targeted-staging template from the `--team` skills
  (`git add "specs/{padded}_{slug}/..." "specs/TODO.md" "specs/state.json"`) — do not reinvent.
- `skill-git-workflow` is currently dead code; this task makes it the canonical documentation
  front for the scope contract (option (b): docs point at the standard, not literal invocation).
- The dangling reference `skill-team-research/SKILL.md:563 → .claude/context/standards/git-staging-scope.md`
  is closed by creating that file as the contract deliverable.
- `modified_files` does not exist in any schema — introduce it via agent self-report, not
  git-diff derivation (diffing cannot distinguish this task's changes from stray edits).
- Scope is the ~6-item core pipeline only; the ~80 other `git add -A` sites are a separate
  follow-up (task 786), explicitly out of scope here.

### Prior Plan Reference

No prior plan. This is the first plan for task 785.

### Roadmap Alignment

No `roadmap_path` provided and `roadmap_flag` not set; no ROADMAP.md consulted or modified.

## Goals & Non-Goals

**Goals**:
- Define an operation-type commit-scope contract in a single canonical standard document
  (`.claude/context/standards/git-staging-scope.md` + dual copy), closing the dangling reference.
- Introduce an optional `modified_files: string[]` self-report mechanism for the `implement`
  operation type (return-meta schema + progress-file field + agent population behavior).
- Rewrite `orchestrator-postflight.sh` Stage 9 to branch on `operation_type` and stage only
  scoped paths, with a **non-silent** fallback (never `git add -A`) when `modified_files` is absent.
- Fix the two inline `implement`-path `git add -A` sites (`skill-implementer` Stage 6b and
  `general-implementation-agent` per-phase commit) to incremental scoped staging.
- Harden `git-workflow.md` to explicitly forbid `git add -A` and `git commit -am`.
- Establish `skill-git-workflow` as the canonical documentation front for the scope contract.
- Keep all four dual-copy file pairs byte-identical (verified by `diff`).

**Non-Goals**:
- The ~80 extension-specific and command-doc `git add -A` sites (founder, present, epi, web,
  latex, z3, nix, neovim, typst, literature; CHECKPOINT 3 examples) — follow-up task 786.
- `git-snapshot.sh`'s internal `git add -A` (line 150) — intentionally exempt (full-tree WIP snapshot).
- Changing the `research` operation type behavior (already safe: `do_git_commit=false`).
- Any literal runtime "calling" of a skill markdown file from bash (not possible; docs-only wiring).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Editing only the project copy of a dual-deployed file; next sync silently reverts it | H | M | Treat every edit to the 4 dual files as a paired edit; Phase 7 verifies each pair with `diff` (empty = pass) |
| Fixing only `orchestrator-postflight.sh` leaves `implement` bug alive (2 inline sites run independently) | H | M | Phases 3 and 4 planned as a unit; Phase 7 greps for residual `git add -A` in all 6 core files |
| `modified_files` self-report incomplete → under-staging → orphaned working-tree changes | M | M | Fallback warns loudly (never `git add -A`); postflight logs `git status --porcelain` non-empty as a warning, surfacing rather than hiding the gap |
| Scope creep into the ~80-site sweep blows the 2-4h estimate | M | M | Explicit Non-Goals list; residual sites are task 786 |
| Dependency 780 also touched `git-workflow.md` | L | L | 780 completed; report confirms no section overlap (780 added the "No Destructive Git" block, lines 84-119; this task edits the "Never Run" list 77-82 and "Commit Scope" 51-62) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 5 | 1 |
| 3 | 3, 4 | 1, 2 |
| 4 | 6 | 1, 3, 4 |
| 5 | 7 | 1, 2, 3, 4, 5, 6 |

Phases within the same wave can execute in parallel.

### Phase 1: Create the commit-scope contract standard [COMPLETED]

**Goal**: Author `.claude/context/standards/git-staging-scope.md` (+ dual copy) defining the
operation-type commit-scope contract, closing the dangling reference from
`skill-team-research/SKILL.md:563`.

**Tasks**:
- [x] Create `.claude/context/standards/git-staging-scope.md` documenting the per-operation scope: *(completed)*
  - `research` — no commit (unchanged; `do_git_commit=false`).
  - `plan` — stage exactly `specs/{padded}_{slug}/`, `specs/TODO.md`, `specs/state.json`.
  - `implement` — stage the above + the plan file path + each entry of `modified_files`.
  - Fail-safe direction: under-stage with a loud warning, never over-stage with `git add -A`.
- [x] Include the proven `--team` template verbatim as the reference snippet (padded-num pattern). *(completed)*
- [x] State the forbidden operations (`git add -A`, `git commit -am`) and the required
  `git status --short` / `git diff --staged` review flow. *(completed)*
- [x] Create the byte-identical dual copy at `.claude/extensions/core/context/standards/git-staging-scope.md`
  (create the directory if absent). *(completed)*

**Timing**: 40 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/standards/git-staging-scope.md` - new standard document (create)
- `.claude/extensions/core/context/standards/git-staging-scope.md` - byte-identical dual copy (create)

**Verification**:
- Both files exist and `diff` between them is empty.
- Content covers all three operation types and the forbidden-operations list.

---

### Phase 2: Add `modified_files` self-report mechanism [COMPLETED]

**Goal**: Introduce the optional `modified_files: string[]` schema field and the agent behavior
that populates it, so the `implement` path can stage exactly the source files it touched.

**Tasks**:
- [x] Add optional `modified_files: string[]` to `.claude/context/formats/return-metadata-file.md`
  (documented like `completion_data`/`memory_candidates`, with `// []` jq-read fallback semantics). *(completed)*
- [x] Add an additive per-objective `files_touched: []` field to
  `.claude/context/formats/progress-file.md` so paths accumulate incrementally during Stage 4. *(completed)*
- [x] Update `general-implementation-agent.md` Stage 4/Stage 6 (+ dual copy) so the agent appends
  every `Write`/`Edit` target path to `files_touched` during execution and sums them into
  `modified_files` in the return-meta at Stage 6. *(completed)*
- [x] Reference `git-staging-scope.md` (Phase 1) as the authority for what `modified_files` feeds. *(completed)*

**Timing**: 40 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/context/formats/return-metadata-file.md` - add `modified_files` field spec
- `.claude/context/formats/progress-file.md` - add `files_touched` per-objective field
- `.claude/agents/general-implementation-agent.md` - populate behavior (Stage 4 + Stage 6)
- `.claude/extensions/core/agents/general-implementation-agent.md` - byte-identical dual copy

**Verification**:
- Schema docs describe `modified_files` and `files_touched` with fallback semantics.
- `diff` between the two `general-implementation-agent.md` copies is empty.

---

### Phase 3: Rewrite `orchestrator-postflight.sh` Stage 9 [COMPLETED]

**Goal**: Replace the single `git add -A && git commit` execution site with operation-type
branched targeted staging.

**Tasks**:
- [x] Rewrite Stage 9 (lines ~317-326) to branch on `operation_type`: *(completed)*
  - `plan`: `git add "specs/${padded}_${slug}/" "specs/TODO.md" "specs/state.json"` (no schema dep).
  - `implement`: the above + plan path + `jq -r '.modified_files[]? // empty' "$metadata_file"`.
- [x] Fallback when `modified_files` is absent/empty: stage only the fixed task-dir paths and
  print a **non-silent** warning (`[postflight] WARNING: no modified_files reported; source-file
  changes NOT committed automatically. Review and commit manually.`) — never `git add -A`. *(completed)*
- [x] After the targeted commit, run `git status --porcelain` and log a warning if non-empty. *(completed)*
- [x] Preserve the existing non-blocking "nothing to commit" behavior and session-ID trailer. *(completed)*

**Timing**: 40 minutes

**Depends on**: 1, 2

**Files to modify**:
- `.claude/scripts/orchestrator-postflight.sh` - Stage 9 rewrite (single copy; no dual edit)

**Verification**:
- `bash -n .claude/scripts/orchestrator-postflight.sh` parses clean.
- `grep -n "git add -A" .claude/scripts/orchestrator-postflight.sh` returns nothing.
- Manual read confirms both branches and the loud fallback path.

---

### Phase 4: Fix the two inline `implement`-path staging sites [COMPLETED]

**Goal**: Eliminate the per-phase `git add -A` sites that run independently of Stage 9, using
incremental scoped staging, and reconcile vestigial duplicate commit docs.

**Tasks**:
- [x] `skill-implementer/SKILL.md` Stage 6b (+ dual copy): replace `git add -A` with
  `git add "specs/${padded}_${slug}/" "specs/TODO.md" "$plan_path"` plus the paths accumulated
  in `files_touched` so far at the phase boundary. *(completed)*
- [x] `general-implementation-agent.md` Stage 4 per-phase commit (+ dual copy): same incremental
  scoped staging (innermost, once-per-phase site). *(completed)*
- [x] Verify whether `skill-implementer/SKILL.md` inline "Stage 9: Git Commit" text (lines ~641-650)
  is vestigial relative to the `orchestrator-postflight.sh` delegation; if confirmed dead,
  reconcile/remove it to avoid two divergent descriptions of the same commit. *(completed: not dead —
  it is skill-implementer's own final commit, run inline rather than via delegation to
  orchestrator-postflight.sh; fixed its git add -A and malformed code fence, and reconciled both
  descriptions to reference the same git-staging-scope.md contract)*

**Timing**: 45 minutes

**Depends on**: 1, 2

**Files to modify**:
- `.claude/skills/skill-implementer/SKILL.md` - Stage 6b (+ reconcile Stage 9 text)
- `.claude/extensions/core/skills/skill-implementer/SKILL.md` - byte-identical dual copy
- `.claude/agents/general-implementation-agent.md` - per-phase commit (coordinate with Phase 2 edits)
- `.claude/extensions/core/agents/general-implementation-agent.md` - byte-identical dual copy

**Verification**:
- `grep -rn "git add -A" .claude/skills/skill-implementer/ .claude/agents/general-implementation-agent.md` returns nothing.
- `diff` empty for both dual-copy pairs.

---

### Phase 5: Harden `git-workflow.md` [COMPLETED]

**Goal**: Make the policy match the implementation by explicitly forbidding `git add -A` and
`git commit -am`, and by pointing to the new standard.

**Tasks**:
- [x] Add `git add -A` and `git commit -am` to the "Never Run" list (lines ~77-82). *(completed)*
- [x] Reference `.claude/context/standards/git-staging-scope.md` from the "Commit Scope" section
  (lines ~51-62) and the "Always Check Before Commit" section (lines ~121-124). *(completed)*
- [x] Apply the identical edit to the `extensions/core` dual copy. *(completed)*

**Timing**: 25 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/rules/git-workflow.md` - forbid `git add -A`/`git commit -am`; reference standard
- `.claude/extensions/core/rules/git-workflow.md` - byte-identical dual copy

**Verification**:
- "Never Run" list contains both forbidden commands.
- `diff` between the two copies is empty.

---

### Phase 6: Establish `skill-git-workflow` as canonical [COMPLETED]

**Goal**: Make `skill-git-workflow` the documented, canonical reference for the scope contract,
and fix the referring pointer so the contract has a single source of truth.

**Tasks**:
- [x] Update `skill-git-workflow/SKILL.md` (+ dual copy) "Commit Scope Rules" / "Execution
  Commands" sections to point at `git-staging-scope.md` and describe the actual
  `orchestrator-postflight.sh` behavior (docs front, not literal invocation). *(completed)*
- [x] Update the `skill-team-research/SKILL.md:563` note (+ its dual copy) so the referenced path
  resolves to the now-existing standard. *(completed: reference already resolves as-is now that
  git-staging-scope.md exists from Phase 1 — no text change needed; both copies confirmed
  byte-identical)*
- [x] Confirm no other dangling references to `git-staging-scope.md` remain. *(completed: `grep -rn
  "git-staging-scope.md" .claude/` shows every reference resolves to an existing file)*

**Timing**: 30 minutes

**Depends on**: 1, 3, 4

**Files to modify**:
- `.claude/skills/skill-git-workflow/SKILL.md` - canonical scope-contract documentation front
- `.claude/extensions/core/skills/skill-git-workflow/SKILL.md` - byte-identical dual copy
- `.claude/skills/skill-team-research/SKILL.md` - fix dangling reference (+ dual copy if present)

**Verification**:
- `grep -rn "git-staging-scope.md" .claude/` shows all references resolve to an existing file.
- `diff` empty for the skill-git-workflow pair.

---

### Phase 7: Verification and dual-copy sync audit [COMPLETED]

**Goal**: Confirm the core pipeline is `git add -A`-free, all dual copies are in sync, and the
scripts parse.

**Tasks**:
- [x] `diff` each of the four dual-copy pairs (skill-implementer, general-implementation-agent,
  git-workflow.md, skill-git-workflow) and the new git-staging-scope.md pair; all must be empty. *(completed:
  all 5 pairs verified byte-identical via `diff -q`)*
- [x] `grep -rn "git add -A"` across the 6 core files; confirm zero residual hits. *(completed: zero
  hits in the 3 execution sites — orchestrator-postflight.sh, skill-implementer/SKILL.md,
  general-implementation-agent.md — including comments/prose. The 3 policy/documentation files
  (git-workflow.md, skill-git-workflow/SKILL.md, git-staging-scope.md) intentionally retain the
  literal string as required forbidden-command text per their own Phase 5/6 requirements; see
  Notes)*
- [x] `bash -n .claude/scripts/orchestrator-postflight.sh` parses clean. *(completed)*
- [x] Confirm `research` behavior unchanged (`do_git_commit=false` still set). *(completed:
  `do_git_commit="false"` still set for the `research` case in the operation-type mapping)*
- [x] Record any out-of-scope residual `git add -A` sites as confirmation that task 786 covers them. *(completed:
  92 files outside the 6-item core pipeline still contain `git add -A` — confirmed as task 786's
  scope; `.claude/scripts/git-snapshot.sh` line 150 confirmed untouched/exempt)*

**Timing**: 20 minutes

**Depends on**: 1, 2, 3, 4, 5, 6

**Files to modify**:
- None (verification only)

**Verification**:
- All `diff` checks empty; all `grep` checks zero; `bash -n` clean.

## Testing & Validation

- [x] `diff` of all five dual-copy pairs returns empty (byte-identical).
- [x] `grep -rn "git add -A"` across the 6 core pipeline files returns no hits *(the 3 execution
  sites are hit-free; the 3 policy/doc files correctly retain the literal string as required
  forbidden-command text — see Phase 7 Notes)*.
- [x] `bash -n .claude/scripts/orchestrator-postflight.sh` exits 0.
- [x] `git-staging-scope.md` exists at both paths and resolves every referring pointer.
- [x] `git-workflow.md` "Never Run" list contains `git add -A` and `git commit -am`.
- [x] `research` operation still sets `do_git_commit=false` (no behavior change).
- [x] `modified_files` / `files_touched` documented in the return-meta and progress-file schemas.

## Artifacts & Outputs

- `.claude/context/standards/git-staging-scope.md` (+ dual copy) — new commit-scope contract.
- `.claude/scripts/orchestrator-postflight.sh` — Stage 9 targeted-staging rewrite.
- `.claude/rules/git-workflow.md` (+ dual copy) — hardened Never Run list + standard reference.
- `.claude/skills/skill-implementer/SKILL.md` (+ dual copy) — scoped Stage 6b.
- `.claude/agents/general-implementation-agent.md` (+ dual copy) — scoped per-phase commit + `modified_files`.
- `.claude/skills/skill-git-workflow/SKILL.md` (+ dual copy) — canonical scope-contract docs.
- `.claude/context/formats/return-metadata-file.md`, `progress-file.md` — schema additions.
- `specs/785_scoped_git_staging_commit_pipeline/summaries/01_scoped-git-staging-summary.md` (on completion).

## Rollback/Contingency

- All changes are documentation/script edits under version control. To revert, `git checkout`
  the affected files from the pre-task commit (only after snapshotting per the "No Destructive
  Git on Uncommitted Work" rule if the tree is dirty).
- If the `modified_files` mechanism proves unreliable mid-implementation, the `plan` branch of
  Phase 3 (zero schema dependency) can ship independently, deferring the `implement` branch — this
  still eliminates the `plan`-commit half of the bug immediately.
- If a dual-copy drift is detected post-merge, re-sync from the canonical `.claude/` copy and
  re-run the Phase 7 `diff` audit.

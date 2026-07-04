# Research Report: Task #786

**Task**: 786 - Propagate scoped-staging convention across all agent/command/skill templates
**Started**: 2026-07-04
**Completed**: 2026-07-04
**Effort**: 2-4 hours (implementation)
**Dependencies**: 785 (completed — canonical pattern established)
**Sources/Inputs**: Codebase (`grep -rn "git add -A" .claude/`), `specs/785_.../reports/01_*.md`, `specs/785_.../summaries/01_*.md`, `.claude/context/standards/git-staging-scope.md`, `.claude/rules/git-workflow.md`
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `grep -rn "git add -A" .claude/` currently returns **124 lines**. After excluding intentional
  documentation prose (describing the forbidden pattern) and confirmed exceptions, **~95 lines
  across ~60 distinct template/exec sites** still need conversion to scoped staging.
- Task 785's 6-item core pipeline (`orchestrator-postflight.sh`, `git-workflow.md`,
  `skill-implementer/SKILL.md`, `general-implementation-agent.md`, `skill-git-workflow/SKILL.md`,
  `git-staging-scope.md`) is verified clean — confirmed by direct grep, zero hits in the
  execution files.
- A previously-unlisted but **high-priority** discovery: `/research`, `/plan`, `/implement`, and
  `/orchestrate` command files each contain their OWN inline "CHECKPOINT 3: COMMIT" step with a
  literal `git add -A`, separate from (and parallel to) `orchestrator-postflight.sh`. These are
  core-pipeline command templates, not edge-case extensions — they should be treated as the
  highest-priority remaining sites, on par with what 785 fixed.
- `skill-planner`, `skill-reviser`, `skill-spawn`, and `skill-todo` also have their own final
  "Git Commit" stages using `git add -A` that never got the 785 treatment.
- The **generator templates** (`creating-commands.md`, `creating-skills.md`, both
  `command-template.md` files, and the checkpoint/pattern docs referenced by them) all teach
  `git add -A` as the standard commit step — fixing these is required so newly-generated
  commands/skills inherit scoped staging by default, per the task's explicit goal.
- Confirmed exceptions to leave alone: `.claude/scripts/git-snapshot.sh:150` (full-tree WIP
  snapshot, already exempted by 785), `extensions/cslib/commands/pr.md`'s STEP 10 amend/new/
  stacked/update `git add -A` + `git reset HEAD pr-description.md` exclude-flow (deliberate,
  documented), and `extensions/email/.../email-preferences.md:141` (prose already *warns
  against* `git add -A` — aligned, not a violation).
- One ambiguous site needs an explicit decision at implementation time:
  `extensions/cslib/commands/pr.md:569` (STEP 0.5 "apply review feedback" commit) is a bare
  `git add -A` that is NOT part of the documented exclude-flow — it may be a genuine oversight
  distinct from the "leave alone" carve-out in the task description.
- Recommended approach: reuse the exact `--team` staging template (per `git-staging-scope.md`),
  fix all `.claude/{commands,skills,agents,rules,context,docs}/` sites first, then mirror each
  edit into its `.claude/extensions/core/` (or `nix`/`nvim`) dual copy, verifying `diff -q`
  afterward for every pair.

## Context & Scope

Task 785 established the canonical scoped-staging pattern (`git-staging-scope.md`) and fixed the
narrow 6-item core commit pipeline that actually executes on every `/research`/`/plan`/
`/implement` invocation via `orchestrator-postflight.sh`. Its own summary explicitly deferred "92
files outside the 6-item core pipeline" to task 786.

This research re-ran the audit from scratch (rather than trusting the original task-description
line numbers, which have drifted) via `grep -rn "git add -A" .claude/`, cross-referenced every
hit against what 785 already fixed, and classified the remainder into fix-required categories,
confirmed exceptions, and one ambiguous site.

**Verification that 785's scope is clean** (all zero hits):
```
grep -n "git add -A" .claude/agents/general-implementation-agent.md                    # 0 hits
grep -n "git add -A" .claude/extensions/core/agents/general-implementation-agent.md    # 0 hits
grep -n "git add -A" .claude/skills/skill-implementer/SKILL.md                         # 0 hits
grep -n "git add -A" .claude/extensions/core/skills/skill-implementer/SKILL.md         # 0 hits
grep -n "git add -A" .claude/scripts/orchestrator-postflight.sh                        # 0 hits (no core mirror exists for this script)
```
`git-workflow.md`, `skill-git-workflow/SKILL.md`, and `git-staging-scope.md` (+ their core
mirrors) still contain the literal string `git add -A`, but only inside "Never Run" / "Forbidden
Operations" prose that must name the forbidden command — this is intentional and correct, per
785's own Decisions section.

## Findings

### Dual-Copy Architecture (critical context for the sweep)

This repo mirrors two kinds of extension content into the top-level `.claude/` tree:

1. **Core extension**: nearly every top-level `.claude/{commands,agents,skills,rules,context,
   docs,scripts}/X` has a byte-identical twin at `.claude/extensions/core/{...}/X`. Every "core"
   site below is a **pair** — both copies must be edited identically and re-diffed.
2. **Deployed non-core extensions**: because this repo has the `nix` and `nvim` extensions
   loaded, `nix-implementation-agent.md` and `neovim-implementation-agent.md` are ALSO
   dual-copied (`.claude/agents/X` ↔ `.claude/extensions/{nix,nvim}/agents/X`).
3. **Non-deployed extensions** (python, web, founder, latex, lean, z3, present, epidemiology,
   typst, literature, cslib, email): these exist ONLY under `.claude/extensions/{ext}/...` —
   single copy, no top-level mirror, since those extensions are not loaded in this repo.

One pre-existing, unrelated drift was found between `.claude/skills/skill-planner/SKILL.md` and
its core mirror (a stale `literature-briefing.sh` vs `literature-briefing-invoke.sh` script-name
reference at lines ~223/249/255/261) — same class of drift 785 found and repaired in
`skill-implementer`. Whoever edits `skill-planner` for 786 should repair this incidentally, as
785 did, and note it as a deviation.

### Category A — Already fixed by 785 (verified clean, EXCLUDE)

- `.claude/scripts/orchestrator-postflight.sh` (no core mirror)
- `.claude/agents/general-implementation-agent.md` ↔ core mirror
- `.claude/skills/skill-implementer/SKILL.md` ↔ core mirror
- `.claude/rules/git-workflow.md` ↔ core mirror (prose-only remaining hits, intentional)
- `.claude/skills/skill-git-workflow/SKILL.md` ↔ core mirror (prose-only, intentional)
- `.claude/context/standards/git-staging-scope.md` ↔ core mirror (prose-only, intentional — this
  IS the standard)
- `.claude/context/standards/git-safety.md` ↔ core mirror (prose-only, pre-existing, aligned)
- `.claude/context/formats/return-metadata-file.md`, `progress-file.md` ↔ core mirrors
  (prose-only, describing `modified_files`/`files_touched` mechanism)

### Category B — Core command-pipeline exec sites (HIGHEST PRIORITY, not in original task audit's line list but structurally equivalent to what 785 fixed)

Each has an identical core-extension mirror; treat as one edit + one sync per row.

| File | Lines | What it does |
|---|---|---|
| `commands/research.md` | 473 | CHECKPOINT 3 inline commit for `/research` (parallel to `orchestrator-postflight.sh`'s `research` branch, which already has `do_git_commit=false` — reconcile whether this inline step should even run, or should delegate) |
| `commands/plan.md` | 500 | CHECKPOINT 3 inline commit for `/plan` — convert to `plan` scope (task dir + TODO.md + state.json) |
| `commands/implement.md` | 187, 192 | CHECKPOINT 3 inline commit, completion + partial branches — convert to `implement` scope w/ `modified_files` |
| `commands/orchestrate.md` | 250, 258, 375, 382 | Batch commit (all-succeeded / partial-success) + per-task commit (complete / paused) — batch case must iterate scope over each task dir in the range |
| `commands/errors.md` | 197 | Post-fix-plan commit — scope to `specs/errors.json` + generated task dir(s) |

All five files have byte-identical core-extension mirrors: `.claude/extensions/core/commands/
{research,plan,implement,orchestrate,errors}.md` at the same line numbers (verified — no drift).

### Category B2 — Skill final-commit stages needing the same treatment

| File | Lines | Notes |
|---|---|---|
| `skills/skill-planner/SKILL.md` | 501 (core mirror: 500 — pre-existing 1-line drift from the unrelated literature-briefing issue above) | Stage 9 Git Commit — convert to `plan` scope |
| `skills/skill-reviser/SKILL.md` | 426, 438 | Stage 9, plan-revision + description-update branches — convert to task-dir scope |
| `skills/skill-spawn/SKILL.md` | 445 | Stage 15 — scope to parent task dir + new spawned task dirs + TODO.md + state.json |
| `skills/skill-todo/SKILL.md` | 738 | Stage 15 GitCommit — special case: multi-task archive operation touches `specs/archive/`, `specs/TODO.md`, `specs/state.json`, possibly `specs/CHANGE_LOG.md` — needs a purpose-built archive-scope, not the single-task template |

All four have byte-identical core-extension mirrors at the same lines (skill-planner has the
1-line drift noted above; verify after fixing).

### Category C — Hard-mode agent commits (coordinate with 779/781 cluster)

- `agents/general-implementation-hard-agent.md:301` ↔ `extensions/core/agents/
  general-implementation-hard-agent.md:301` — per-phase commit template; should mirror the
  scoped-staging treatment 785 applied to the non-hard `general-implementation-agent.md`.
  **Coordination note**: tasks 779 and 781 (the hard-mode cluster mentioned in the task
  description) are both `status: completed` as of this research — there is no active in-flight
  edit conflict on this file; it is safe to edit directly.
- `extensions/lean/agents/lean-implementation-hard-agent.md:315` — single copy (lean not deployed
  in this repo)
- `extensions/cslib/agents/cslib-implementation-hard-agent.md:288` — single copy (cslib not
  deployed in this repo)

### Category D — Deployed non-core extension agents (dual-copy pairs)

- `agents/nix-implementation-agent.md:384` ↔ `extensions/nix/agents/nix-implementation-agent.md:384`
- `agents/neovim-implementation-agent.md:364` ↔ `extensions/nvim/agents/neovim-implementation-agent.md:364`
  (note: the nvim extension's directory is named `nvim` but its agent file is named
  `neovim-implementation-agent.md` — an existing naming asymmetry, not part of 786's scope)

### Category E — Non-deployed single-copy extension agents/skills

- `extensions/python/agents/python-implementation-agent.md:116`
- `extensions/web/agents/web-implementation-agent.md:432`
- `extensions/web/skills/skill-web-implementation/SKILL.md:318`
- `extensions/web/skills/skill-web-research/SKILL.md:213`
- `extensions/latex/agents/latex-implementation-agent.md:113`
- `extensions/z3/agents/z3-implementation-agent.md:111`
- `extensions/typst/agents/typst-implementation-agent.md:95`
- `extensions/literature/skills/skill-literature/SKILL.md:1573`
- `extensions/epidemiology/skills/skill-epi-implement/SKILL.md:223`
- `extensions/epidemiology/skills/skill-epi-research/SKILL.md:213`

### Category F — founder extension (largest single cluster, 21 sites, single copy)

- `extensions/founder/commands/consult.md:235`
- `extensions/founder/agents/founder-implement-agent.md:235,263,290,341,396` (5 per-phase commit
  sites in one file)
- `extensions/founder/skills/*.md` (15 files, one `git add -A` each): `skill-deck-research`,
  `skill-strategy`, `skill-finance`, `skill-meeting`, `skill-founder-implement`, `skill-analyze`,
  `skill-legal`, `skill-founder-spreadsheet`, `skill-market`, `skill-deck-plan` (470),
  `skill-founder-plan` (208), `skill-consult` (194), `skill-deck-implement` (243),
  `skill-financial-analysis` (210), `skill-project` (266)

### Category G — present extension (single copy)

- `extensions/present/skills/skill-slide-critic/SKILL.md:450`
- `extensions/present/skills/skill-slides/SKILL.md:303`
- `extensions/present/skills/skill-budget/SKILL.md:289`
- `extensions/present/skills/skill-grant/SKILL.md:511` (exec) and `:966` (prose: "Manual commit
  recommended: git add -A && git commit" — also needs correcting, it recommends the forbidden
  pattern to the user)
- `extensions/present/skills/skill-funds/SKILL.md:385` (exec) and `:479` (same "manual commit
  recommended" prose issue)
- `extensions/present/skills/skill-timeline/SKILL.md:330`
- `extensions/present/skills/skill-slide-planning/SKILL.md:394`

### Category H — Generator templates and pattern docs (HIGH PRIORITY per task's explicit goal: "newly-created components inherit scoped staging by default")

All have byte-identical core-extension mirrors; no line drift found in any of these pairs.

| File | Line | Role |
|---|---|---|
| `docs/guides/creating-commands.md` | 127 | CHECKPOINT 3 template shown when documenting how to build a new command |
| `docs/guides/creating-skills.md` | 403 | Stage 8 template shown when documenting how to build a new skill |
| `docs/templates/command-template.md` | 79 | CHECKPOINT 3 boilerplate copy-pasted into new commands |
| `context/templates/command-template.md` | 69 | A SEPARATE file, same name, different directory — also teaches `git add -A` as step 1 of CHECKPOINT 3; verify at implementation time whether this and `docs/templates/command-template.md` are meant to be the same content (currently they read as two independent templates with overlapping purpose — flag for the implementer/planner to decide whether to consolidate or just fix both in place, since consolidation is out of scope for 786) |
| `docs/examples/research-flow-example.md` | 239 | Illustrative example transcript, not literally copy-pasted, but still teaches the wrong pattern by example |
| `context/patterns/subagent-continuation-loop.md` | 127 | "Per-Continuation Git Commits" pattern used by hard-mode continuation loops |
| `context/patterns/file-metadata-exchange.md` | 274 | Generic git-commit-after-metadata-write pattern |
| `context/patterns/checkpoint-execution.md` | 114 | Checkpoint 3: COMMIT pattern doc (companion to command-template.md's CHECKPOINT 3) |
| `context/patterns/checkpoint-before-overflow.md` | 68 | CHECKPOINT-BEFORE-OVERFLOW git checkpoint procedure — notably, this is the SAME pattern this research agent's own instructions cite for its own Stage 3.6 handoff protocol; fixing it improves the whole context-exhaustion-handoff family, not just this file |
| `context/troubleshooting/workflow-interruptions.md` | 217 | "Manually commit if needed" recovery snippet |
| `context/checkpoints/checkpoint-commit.md` | 10 | Standalone checkpoint-commit execution-steps doc |

### Category I — Confirmed intentional exceptions (LEAVE ALONE)

- `.claude/scripts/git-snapshot.sh:150` ↔ `extensions/core/scripts/git-snapshot.sh:150` — full-tree
  WIP snapshot commit on a scratch branch before a context-overflow handoff; already reviewed and
  exempted in 785's verification ("confirmed untouched/exempt (full-tree WIP snapshot,
  intentionally out of scope)").
- `extensions/cslib/commands/pr.md` STEP 10 (`amend`/`new`/`stacked`/`update` workflows, lines
  1849, 1859) — the deliberate documented "git add -A, then `git reset HEAD pr-description.md`
  to exclude it" flow. Line 1824 is the prose note explaining this. Per the task description,
  leave this alone unless it can be made scoped safely — the working-tree diff at PR-commit time
  is by design "everything the branch's work touched," which is a different scope contract than
  the task-directory-based `/research`/`/plan`/`/implement` pipeline, so a safe scoped
  alternative is not obviously available without deeper cslib-specific research.
- `extensions/email/context/project/email/email-preferences.md:141` — prose that already
  correctly instructs a *different* migration task to use `git rm` on specific paths and
  explicitly says "never `git add -A`." This is aligned documentation, not a violation.

### Category J — Ambiguous, needs an explicit decision (flag, do not silently fix or silently skip)

- `extensions/cslib/commands/pr.md:569` — STEP 0.5's "apply review feedback" commit
  (`git status --porcelain` check, then bare `git add -A && git commit`). This is NOT part of the
  documented STEP 10 exclude-flow (which excludes `pr-description.md` specifically); it is a
  separate, earlier step with no exclusion logic at all. It may be a genuine pre-existing
  oversight distinct from the "deliberate flow" the task description says to leave alone.
  Recommend the planner/implementer make an explicit call — either scope it to the PR's actual
  changed files, or document why it's intentionally full-tree (e.g., "review feedback commits
  are expected to touch anything") — rather than silently converting or silently leaving it.

## Decisions

- Treat Category B and B2 (core command/skill final-commit sites) as equal-priority to what 785
  already fixed, even though they weren't itemized by line number in the original task
  description — they are structurally the same class of bug (a parallel, un-scoped commit path
  alongside the one 785 fixed) and sit on the same `/research`/`/plan`/`/implement` critical
  path.
- Treat Category H (generator templates/patterns) as required, not optional, since the task
  explicitly asks for templates to "inherit scoped staging by default" — these are exactly the
  templates a future `/meta`-driven command/skill creation would copy from.
- Defer a decision on Category J (`cslib/pr.md:569`) rather than resolving it in this research
  pass — it needs cslib-specific judgment about whether STEP 0.5's commit scope can safely be
  narrowed.
- Confirmed via `git status --porcelain` type verification pattern that 785's fail-safe
  ("under-stage, never over-stage" + loud warning) is the correct model to replicate everywhere
  in Category B/B2/C/D/E/F/G — no new design is needed, only propagation of the same template.

## Risks & Mitigations

- **Dual-copy drift risk**: Every core/nix/nvim pair must be re-diffed (`diff -q`) after editing.
  Mitigation: batch all core-pair edits together per file, then run a single verification loop
  over all pairs at the end (as 785 did in its Phase 7).
- **Scope creep into cslib/pr.md's legitimate exclude-flow**: risk of "fixing" STEP 10's
  intentional pattern and breaking PR submission. Mitigation: explicitly exclude STEP 10 (lines
  1849, 1859, 1824) from the sweep; only Category J's line 569 is in question, and only as a
  flagged decision, not an automatic edit.
- **founder/present extension breadth (28 sites across ~23 files)**: largest single chunk of
  remaining work by file count, but each site is a simple, mechanical, single-line commit-step
  edit (no dual-copy sync needed since these extensions aren't deployed in this repo). Lower risk
  per-site than Category B/B2/H, but higher total edit volume — good candidate for a dedicated
  phase or wave in the implementation plan, possibly parallelizable by extension.
- **`/research`'s CHECKPOINT 3 vs. `orchestrator-postflight.sh`'s `research` branch**: these two
  code paths (command's own inline instructions vs. the postflight script) may be redundant or
  may represent two different execution contexts (interactive command execution vs. delegated
  skill execution). The planner should confirm which path actually fires for `/research` before
  deciding whether commands/research.md:473 needs full scoped-staging logic or simply needs to
  reflect `do_git_commit=false` and delegate.

## Context Extension Recommendations

- **Topic**: Generator-template consolidation (`docs/templates/command-template.md` vs
  `context/templates/command-template.md`).
- **Gap**: Two same-named files exist with overlapping CHECKPOINT 3 content and no
  cross-reference explaining why both exist. Not directly a git-staging bug, but propagating the
  scoped-staging fix to both without addressing the duplication risks perpetuating drift the way
  785 found between `skill-implementer` and its core mirror.
- **Recommendation**: Note in the 786 plan/summary whether these two templates should be
  consolidated (out of scope) or merely kept in sync going forward; do not silently merge them
  during 786.

## Appendix

### Search queries used

```bash
grep -rn "git add -A" .claude/
grep -n "git add -A" .claude/agents/general-implementation-agent.md .claude/extensions/core/agents/general-implementation-agent.md
grep -n "git add -A" .claude/skills/skill-implementer/SKILL.md .claude/extensions/core/skills/skill-implementer/SKILL.md
grep -n "git add -A" .claude/scripts/orchestrator-postflight.sh
diff .claude/skills/skill-planner/SKILL.md .claude/extensions/core/skills/skill-planner/SKILL.md
jq -r '.active_projects[] | select(.project_number==779 or .project_number==781)' specs/state.json
```

### Full current inventory (124 raw hits, categorized above)

See Categories A-J above for the complete, current, line-verified breakdown. Category A (8
files/pairs) is excluded as already fixed. Categories B through H (~60 distinct sites across
~50 files, counting dual-copy pairs once each) are 786's remaining scope. Category I (3
sites/pairs) are confirmed intentional exceptions. Category J (1 site) needs an explicit
decision, not a default action.

### References

- `.claude/context/standards/git-staging-scope.md` — canonical contract and reference template
- `.claude/rules/git-workflow.md` — "Never Run" list and "Commit Scope" section
- `specs/785_scoped_git_staging_commit_pipeline/summaries/01_scoped-git-staging-summary.md` —
  what 785 did and its explicit deferral of "92 files" to this task
- `specs/785_scoped_git_staging_commit_pipeline/reports/01_scoped-git-staging-commit-pipeline.md`
  — 785's original audit and root-cause analysis

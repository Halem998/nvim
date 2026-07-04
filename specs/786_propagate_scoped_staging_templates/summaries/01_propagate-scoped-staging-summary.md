# Implementation Summary: Task #786

**Completed**: 2026-07-04
**Duration**: ~1 session (all 6 phases)

## Overview

Swept every remaining `git add -A` exec/template site in the agent system (124 raw grep hits at
task start) to the canonical scoped-staging pattern from `.claude/context/standards/git-staging-scope.md`
(established by task 785). All 6 phases completed: core command exec sites, core skill
final-commit stages, generator templates/pattern docs, hard-mode/deployed/scattered extension
agents, the founder+present extension tail, and the cslib/pr.md:569 documented-exception decision
plus final verification. 83 files modified across 39 conceptual sites (dual-copy pairs counted
once each).

## What Changed

### Phase 1 — Core command exec sites
- `.claude/commands/{research,plan,implement,orchestrate,errors}.md` ↔
  `.claude/extensions/core/commands/{...}.md` — converted CHECKPOINT 3 in each to the scoped
  `research`/`plan`/`implement` template. Confirmed `orchestrator-postflight.sh` is not wired into
  the single-task command pipeline (research.md's own inline commit genuinely executes), so
  applied the `research` scope (reports/ + .return-meta.json + TODO.md + state.json) rather than
  a no-op. orchestrate.md's batch commit now iterates the scope over `validated_tasks`.

### Phase 2 — Core skill final-commit stages
- `.claude/skills/{skill-planner,skill-reviser,skill-spawn,skill-todo}/SKILL.md` ↔ core mirrors —
  converted Stage 9/15 Git Commit to task-dir/plan/archive scopes. skill-spawn scopes to parent
  task dir + every newly spawned task dir. skill-todo uses a purpose-built archive scope
  (`specs/archive/`, TODO.md, state.json, plus CHANGE_LOG.md/ROADMAP.md/README.md/`.memory/`
  conditionally, per what that run actually touched).

### Phase 3 — Generator templates + pattern docs
- 11 files ↔ core mirrors: `docs/guides/{creating-commands,creating-skills}.md`,
  both `command-template.md` copies (`docs/templates/` and `context/templates/`, left
  un-consolidated per plan), `docs/examples/research-flow-example.md`,
  `context/patterns/{subagent-continuation-loop,file-metadata-exchange,checkpoint-execution,
  checkpoint-before-overflow}.md`, `context/troubleshooting/workflow-interruptions.md`,
  `context/checkpoints/checkpoint-commit.md`. All now teach scoped staging by default.

### Phase 4 — Hard-mode + deployed + scattered extension agents
- `agents/general-implementation-hard-agent.md` ↔ core mirror, `extensions/{lean,cslib}/agents/*-hard-agent.md`
  (single-copy), `agents/{nix,neovim}-implementation-agent.md` ↔ their deployed extension mirrors,
  `extensions/python/agents/python-implementation-agent.md`,
  `extensions/web/{agents/web-implementation-agent.md,skills/skill-web-implementation/SKILL.md,
  skills/skill-web-research/SKILL.md}`, `extensions/{latex,z3,typst}/agents/*-implementation-agent.md`,
  `extensions/literature/skills/skill-literature/SKILL.md`,
  `extensions/epidemiology/skills/skill-epi-{implement,research}/SKILL.md`.

### Phase 5 — founder + present extension sweep
- founder: `commands/consult.md`, `agents/founder-implement-agent.md` (5 phase commits), and 15
  skill files (research-scope, plan-scope, and implement-scope variants as appropriate).
- present: `skill-{slide-critic,slides,budget,timeline,slide-planning,grant,funds}/SKILL.md`,
  including the two "Manual commit recommended: git add -A" prose corrections in
  `skill-grant.md`/`skill-funds.md`.

### Phase 6 — cslib/pr.md:569 decision + final verification
- `.claude/extensions/cslib/commands/pr.md` — added an 8-line documenting comment above the
  STEP 0.5.4 `git add -A` (now at line 577) explaining why it is an intentional, deliberate
  full-tree exception (separate `$CSLIB_DIR` git repo, PR review-feedback commit by design
  captures whatever the reviewer asked to change, already guarded by a `git status --porcelain`
  check). Comment-only edit; no behavior change.

## Decisions

- **research.md CHECKPOINT 3 redundancy** (Phase 1 risk): confirmed `orchestrator-postflight.sh`
  is not called anywhere in the single-task `/research`, `/plan`, `/implement` command flow
  (`command-gate-out.sh` and inline CHECKPOINT 3 blocks are what actually execute). The command
  files' own inline commits genuinely fire, so applied the `research` scope to research.md rather
  than treating it as dead code.
- **cslib/pr.md:569** (Phase 6, per plan's pre-made decision): documented as an intentional
  exception rather than converted — this commit runs inside `$CSLIB_DIR`, a separate git
  repository with no task-dir concept to scope against.
- **skill-literature import commit** (Phase 4, `extensions/literature/skills/skill-literature/SKILL.md:1573`,
  not pre-flagged as an exception in the plan): this commit also runs inside a separate git repo
  (`$LITERATURE_DIR`/`specs/literature`), so instead of a task-dir scope (which doesn't apply) it
  now stages this import's own known artifacts (`pdfs/${ckey}.pdf` symlink, `index.json`, and the
  converted markdown matching `${entry_id}*.md`) rather than `git add -A` over the whole separate
  repo.
- **Multi-workflow present skills** (`skill-slides`, `skill-timeline`, `skill-grant`): these choose
  their commit message dynamically per `$workflow_type` (research/plan/implement-like branches
  within one skill). Rather than branching the staging scope per workflow type, applied the
  simpler task-dir-level scope (`specs/${padded_num}_${project_name}/` + TODO.md + state.json) —
  a safe superset covering reports/plans/summaries regardless of which workflow branch ran.
- **founder-implement-agent.md Phase 4/5 outputs**: this agent writes primary artifacts outside
  the task directory (`founder/*.typ`, `strategy/*.md` or `output_dir`, and the compiled `*.pdf`).
  Those phase commits now explicitly include `$typst_file`/`$output_path`/the PDF path in addition
  to the task dir, since under-staging here would silently leave the actual deliverable
  uncommitted.

## Plan Deviations

- **skill-planner literature-briefing drift** (Phase 2, anticipated by the plan): the deployed
  `.claude/skills/skill-planner/SKILL.md` already used the newer `literature-briefing-invoke.sh`
  wrapper while its core mirror `.claude/extensions/core/skills/skill-planner/SKILL.md` still
  called `literature-briefing.sh` directly (pre-existing drift, unrelated to this task). Repaired
  by copying the full deployed file over its core mirror so `diff -q` passes cleanly, per the
  plan's explicit instruction to incidentally fix this (as task 785 did for a similar drift).
- **skill-literature import commit** treated as an undocumented-in-plan de-facto exception (see
  Decisions above) rather than a plain task-dir conversion, since the plan's Phase 4 task list
  included this site without flagging the separate-repo nuance that cslib/pr.md:569 received.

## Verification

- Build: N/A (markdown/meta task, no build step)
- Tests: N/A
- Files verified: Yes — all 83 modified files exist and are non-empty

### Dual-copy pair sweep (20 pairs, all `diff -q` clean)
Phase 1 (5): research, plan, implement, orchestrate, errors (commands ↔ core mirrors)
Phase 2 (4): skill-planner, skill-reviser, skill-spawn, skill-todo (↔ core mirrors)
Phase 3 (11): creating-commands.md, creating-skills.md, both command-template.md copies,
research-flow-example.md, subagent-continuation-loop.md, file-metadata-exchange.md,
checkpoint-execution.md, checkpoint-before-overflow.md, workflow-interruptions.md,
checkpoint-commit.md (↔ core mirrors)
Phase 4 (3): general-implementation-hard-agent.md (↔ core), nix-implementation-agent.md
(↔ extensions/nix), neovim-implementation-agent.md (↔ extensions/nvim)

### Final `grep -rn "git add -A" .claude/` — 28 remaining hits, all classified

**Intentional exceptions (preserved unchanged, 6 lines)**:
- `.claude/scripts/git-snapshot.sh:150` + `.claude/extensions/core/scripts/git-snapshot.sh:150`
  (full-tree WIP snapshot commit)
- `.claude/extensions/cslib/commands/pr.md:1832,1857,1867` (STEP 10 add-then-exclude flow; line
  numbers shifted +8 from 1824/1849/1859 due to the Phase 6 comment insertion at line 569 —
  content itself unchanged)
- `.claude/extensions/email/context/project/email/email-preferences.md:141` (warning prose)

**Newly documented exception (1 line)**:
- `.claude/extensions/cslib/commands/pr.md:577` (was :569) — STEP 0.5.4 "apply review feedback"
  commit, now with an explanatory comment above it (see Phase 6 above)

**Required policy-prose naming the forbidden command (21 lines)**:
- `.claude/context/standards/git-staging-scope.md:6,62,110` ↔ core mirror (6 lines) — this IS the
  standard
- `.claude/rules/git-workflow.md:87,91` ↔ core mirror (4 lines)
- `.claude/context/standards/git-safety.md:182` ↔ core mirror (2 lines)
- `.claude/skills/skill-git-workflow/SKILL.md:140` ↔ core mirror (2 lines)
- `.claude/skills/skill-team-research/SKILL.md:563` ↔ core mirror (2 lines)
- `.claude/context/formats/return-metadata-file.md:170,183` (2 lines, no core-mirror hit found —
  outside this task's edit scope, Category A)
- `.claude/context/formats/progress-file.md:133` (1 line, no core-mirror hit found — Category A)
- `.claude/context/checkpoints/checkpoint-commit.md:10` ↔ core mirror (2 lines) — newly added by
  this task's Phase 3 edit, phrased to avoid the literal `git add -A` string except in the
  explicit "never X" naming, consistent with the other allow-listed policy-prose files

No Category A file (already fixed by task 785) was modified — confirmed via
`git status --porcelain .claude/`: none of `orchestrator-postflight.sh`,
`general-implementation-agent.md`, `skill-implementer/SKILL.md`, `git-workflow.md`,
`skill-git-workflow/SKILL.md`, `git-staging-scope.md`, `git-safety.md`,
`return-metadata-file.md`, `progress-file.md` appear in the modified-files list.

## Notes

- The founder/present sweep (Phase 5) was purely mechanical for the majority of sites but required
  judgment calls for outputs written outside `specs/` (founder's typst/PDF artifacts) and for
  multi-workflow skills with dynamic commit messages (skill-slides, skill-timeline, skill-grant) —
  see Decisions above.
- `extensions/literature/skills/skill-literature/SKILL.md`'s import-commit site is a second
  separate-git-repo case structurally identical to cslib/pr.md:569, but was not called out as such
  in the plan's Phase 4 task list. Handled it consistently with the cslib precedent (targeted
  staging of the import's own known artifacts) rather than either force-applying an inapplicable
  task-dir scope or leaving it as an un-converted `git add -A`.
- Total files touched: 83 (`.claude/` scope). All are markdown/shell-in-markdown template and
  documentation edits; no runtime script logic changed apart from the Phase 6 comment-only edit.

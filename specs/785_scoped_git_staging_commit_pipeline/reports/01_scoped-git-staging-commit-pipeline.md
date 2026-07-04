# Research Report: Task #785

**Task**: 785 - Scoped git staging: eliminate `git add -A` in the commit pipeline
**Started**: 2026-07-04T16:35:14Z
**Completed**: 2026-07-04T17:10:00Z
**Effort**: 2-4 hours (see scoping note in Decisions — full-repo sweep is materially larger)
**Dependencies**: 780 (completed — added "No Destructive Git on Uncommitted Work" to git-workflow.md; no conflict, no overlap in edited sections)
**Sources/Inputs**: Codebase read (scripts, skills, agents, rules, context, extensions), `git log`, `grep -rn`
**Artifacts**: specs/785_scoped_git_staging_commit_pipeline/reports/01_scoped-git-staging-commit-pipeline.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The root cause is confirmed exactly as described: `.claude/scripts/orchestrator-postflight.sh:322` runs `git add -A && git commit` for the `plan` and `implement` operation types (research never commits — `do_git_commit=false`). Both cited policy line ranges are byte-accurate: `git-workflow.md` "Commit Scope" is lines 51-62, and shared `context/core/standards/git-safety.md` "Avoid repo-wide adds" is lines 182-195 (identical in both the `~/.config/.claude/` shared copy and this repo's local `.claude/context/standards/git-safety.md`, 571 lines each).
- **Correction to the task premise**: `orchestrator-postflight.sh` has only **one copy** in the entire filesystem (`.claude/scripts/orchestrator-postflight.sh`) — there is no "shared copy" to dual-edit for this specific script. However, three *other* files in the actual commit pipeline **do** follow this repo's dual-deploy convention (byte-identical `.claude/X` + `.claude/extensions/core/X` pairs) and each independently runs its own `git add -A`: `skill-implementer/SKILL.md` (2 sites), `general-implementation-agent.md` (1 site), and `git-workflow.md`/`skill-git-workflow/SKILL.md` (the docs to harden). All of these need paired edits.
- **A working template already exists and should be reused, not invented**: `skill-team-research`, `skill-team-plan`, and `skill-team-implement` (the `--team` variants) already replaced `git add -A` with targeted `git add "specs/{padded}_{slug}/..." "specs/TODO.md" "specs/state.json"` staging. This is the exact operation-type contract task 785 asks to define for the single-agent path — it just needs to be lifted into `orchestrator-postflight.sh` and the non-team skills.
- **`skill-git-workflow` is currently dead/aspirational**: nothing in the actual pipeline invokes it. It documents a "Commit Scope Rules" section that already gestures at the right idea but is never executed. Task scope item (4) — "establish `skill-git-workflow` as the canonical scoped-commit helper" — has no prior wiring to build on; this needs new design, not a rename.
- **Dangling reference found**: `skill-team-research/SKILL.md:563` (and its extensions/core dual copy) says "See `.claude/context/standards/git-staging-scope.md`" — **this file does not exist anywhere in the repo**. Creating it is a natural, low-risk deliverable for task 785's "commit-scope contract" (scope item 1) and closes this dangling reference in the same edit.
- **`modified_files` does not exist anywhere** — no return-meta.json schema field, no agent behavior, no progress-file field tracks which source paths an implementation agent touched. The `research`/`plan` operation types don't need this (they only ever write to `specs/**`), but `implement` does, and this is the one genuinely new piece of design work in the task.
- **Scope-boundary finding**: `git add -A` appears in ~80 locations across the repo (extension-specific agents/skills for founder, present, epidemiology, web, latex, z3, nix, neovim, typst, literature; checkpoint-pattern docs; command-level CHECKPOINT 3 examples in `research.md`/`plan.md`/`implement.md`; `git-snapshot.sh`'s own internal use, which is intentionally exempt). Fixing all of them is a much larger effort than 2-4 hours. Recommend scoping task 785's implementation to the **core single-agent pipeline** (the 5 files above) and spawning a follow-up task for the extension/team-adjacent sweep.

## Context & Scope

Verified the exact commit pipeline named in the task description: `orchestrator-postflight.sh`'s Stage 9, called by `skill-researcher` (no commit), `skill-planner` (commit), and `skill-implementer` (commit, via Stages 8-10 delegation) after each `/research`, `/plan`, `/implement` invocation. Also traced the parallel, already-partially-fixed `--team` variants, the currently-unused `skill-git-workflow` skill, the return-meta.json schema that would need to carry a commit-scope contract, and the git-safety policy documents task 785 must harden. Read the actual file contents (not just grep hits) for every file cited below to confirm line numbers before writing this report.

## Findings

### Codebase Patterns

**1. The canonical single-agent pipeline (`orchestrator-postflight.sh`)**

`/home/benjamin/.config/nvim/.claude/scripts/orchestrator-postflight.sh` is a single 343-line script (only one copy on disk; confirmed via filesystem-wide search) with a documented `Operation Mappings` table in its header (lines 17-27):

```
research  -> git commit: NO   (do_git_commit="false", set at line 98)
plan      -> git commit: YES  (do_git_commit="true",  set at line 107)
implement -> git commit: YES  (do_git_commit="true",  set at line 116)
```

Stage 9 (lines 317-326) is the single point where the destructive commit happens:
```bash
if [ "$do_git_commit" = "true" ]; then
  echo "[postflight] Creating git commit: ${commit_message}"
  git add -A && git commit -m "${commit_message}

Session: ${session_id}
" || echo "[postflight] NOTE: Nothing to commit or git commit failed (non-blocking)" >&2
fi
```
This confirms the task's root-cause line number (322) exactly.

Callers, per the script's own header comment (lines 57-60):
- `skill-researcher/SKILL.md` calls it for Stages 6-9 — but `do_git_commit=false` for research, so this path is already safe from the `git add -A` issue (nothing is ever staged/committed here). **Research is not actually at risk from this bug today** — only `plan` and `implement` are.
- `skill-planner/SKILL.md` calls it for Stages 6-10 (full commit).
- `skill-implementer/SKILL.md` calls it for Stages 8-10 only; **Stages 6-7 (including a separate, earlier git commit) are handled inline inside `skill-implementer/SKILL.md` itself** — see finding 3 below, this is a second, independent `git add -A` site that `orchestrator-postflight.sh` alone does not cover.

**2. A working scoped-staging template already exists — in the `--team` skills**

`skill-team-research/SKILL.md` Stage 12 (lines 547-563), `skill-team-plan/SKILL.md` Stage 12, and `skill-team-implement/SKILL.md` Stages 10 and 14 all replaced `git add -A` with targeted staging months/tasks ago:
```bash
padded_num=$(printf "%03d" "$task_number")
git add \
  "specs/${padded_num}_${project_name}/reports/" \
  "specs/${padded_num}_${project_name}/.return-meta.json" \
  "specs/TODO.md" \
  "specs/state.json"
git commit -m "task ${task_number}: complete team research (${team_size} teammates)

Session: ${session_id}
```
`skill-team-research/SKILL.md:563` even has the note: *"Use targeted staging, NOT `git add -A`. See `.claude/context/standards/git-staging-scope.md`."* — **this referenced file does not exist** (confirmed via `find` across the whole `.claude/` tree). This is a real, fixable gap: task 785's "commit-scope contract" deliverable is exactly the content that file should hold, and creating it would close a currently-dangling doc reference for free.

Notably, even `skill-team-implement`'s "scoped" staging for the `implement` operation type (Stage 14, lines 546-561) stages only `specs/{padded}_{slug}/summaries/`, `.return-meta.json`, `specs/TODO.md`, `specs/state.json`, and the plan path — it does **not** explicitly stage the actual source files touched by phase work. This works in practice only because each phase's own inline `git add -A` commit (Stage 10, per-wave, still `git add -A`-free in team-implement... actually Stage 10 there uses `git add "specs/${padded_num}_${project_name}/" "specs/TODO.md" "$plan_path"` — also missing explicit source-file staging) relies on nothing else being present to sweep. In other words: **the team-implement precedent has not fully solved the "stage the source files the phase actually touched" problem either** — it just narrowed the blast radius to `specs/**`. This is exactly why task 785 correctly identifies "the source files the agent reports it modified" as unsolved and requiring a new contract.

**3. `skill-implementer/SKILL.md` has its own independent `git add -A` sites (2), not fixed by editing `orchestrator-postflight.sh` alone**

- **Stage 6b "Commit Phase Progress"** (lines 458-468): runs *inside* the per-subagent continuation loop, after each dispatched implementation subagent returns:
  ```bash
  git add -A
  git commit -m "task ${task_number} phase ${phases_completed}: implementation progress

  Session: ${session_id}
  " || echo "Note: Nothing to commit or commit failed (non-blocking)"
  ```
  This is a *different* commit from the final Stage 9 one — it fires once per phase/subagent iteration, before the implementation is fully complete, and before any final `modified_files` summary could exist.
- **Stage 9 "Git Commit"** (lines 641-650): documents its own `git add -A && git commit -m "task {N}: complete implementation..."`. Per the script's own header comment (line 60), Stages 8-10 for `implement` are actually delegated to `orchestrator-postflight.sh`, meaning this inline Stage 9 text in `skill-implementer/SKILL.md` **appears to be vestigial/duplicated documentation** left over from before the shared postflight script existed, rather than a second code path that actually executes. This should be verified and, if genuinely dead, removed/reconciled during implementation to avoid two independently-maintained descriptions of "the same" commit (one of which is stale).

- **`general-implementation-agent.md`** Stage 4, "Phase Checkpoint Protocol" (lines 428-448) — the actual per-phase commit that the agent itself runs, *before* skill-implementer's Stage 6b wrapper even sees it:
  ```bash
  git add -A && git commit -m "task {N} phase {P}: {phase_name}

  Session: {session_id}
  ```
  This is the innermost, most frequent `git add -A` invocation in the whole pipeline (once per plan phase). It runs **before** Stage 6 (Create Implementation Summary) exists, so no "final modified_files list" is available yet at this point — any fix here needs an *incremental* per-phase scope, not a end-of-run one.

**4. Dual-deploy convention — confirmed present for 4 of the 5 files that matter, absent for the postflight script itself**

This repo's convention (established by task 780, confirmed via byte-identical `diff`) is that canonical `.claude/` files are mirrored verbatim into `.claude/extensions/core/` as the "source of truth" that gets synced elsewhere:

| File | Project copy | `extensions/core` copy | Byte-identical? |
|---|---|---|---|
| `orchestrator-postflight.sh` | `.claude/scripts/orchestrator-postflight.sh` | **none exists** | N/A — single copy only |
| `skill-implementer/SKILL.md` | `.claude/skills/skill-implementer/SKILL.md` | `.claude/extensions/core/skills/skill-implementer/SKILL.md` | Yes (diff empty) |
| `general-implementation-agent.md` | `.claude/agents/general-implementation-agent.md` | `.claude/extensions/core/agents/general-implementation-agent.md` | Yes (diff empty) |
| `git-workflow.md` (rule) | `.claude/rules/git-workflow.md` | `.claude/extensions/core/rules/git-workflow.md` | Yes (diff empty) |
| `skill-git-workflow/SKILL.md` | `.claude/skills/skill-git-workflow/SKILL.md` | `.claude/extensions/core/skills/skill-git-workflow/SKILL.md` | Yes (diff empty) |

Implication for implementation planning: `orchestrator-postflight.sh` needs exactly one edit location; the other four files need paired edits (project + extensions/core) or they will silently diverge and a future sync could revert the project copy back to the old `extensions/core` behavior (this exact failure mode is called out explicitly in task 780's own research report as a prior incident).

**5. `skill-git-workflow` is currently unused/aspirational — not wired into the pipeline at all**

Searched every `.md` file referencing `skill-git-workflow` (16 hits): all are documentation/index/architecture references (`system-overview.md`, `component-selection.md`, `skill-agent-mapping.md`, `merge-sources/claudemd.md`, etc.) or the skill's own `SKILL.md`. **No skill or agent actually invokes `skill-git-workflow`** — `orchestrator-postflight.sh`, `skill-implementer.md`, and `general-implementation-agent.md` all run `git add`/`git commit` directly and inline, never delegating to this skill. Its own `SKILL.md` already documents a decent "Commit Scope Rules" section (task-specific vs. implementation vs. phase commits) but this is prose that nothing consults. Task scope item (4) is real net-new integration work: either (a) have `orchestrator-postflight.sh`/`skill-implementer.md` actually shell out to `skill-git-workflow`'s logic (hard, since skill-git-workflow is a *Claude Code skill* — a markdown behavioral contract read by an agent — not a callable script), or (b) extract the scoping logic into a shared bash helper script (e.g. `.claude/scripts/git-scoped-commit.sh`) that both `orchestrator-postflight.sh` and `skill-git-workflow`'s documented flow point to as the single source of truth, with `skill-git-workflow/SKILL.md` becoming primarily a *documentation* front for that shared script. **Recommendation: option (b)** — scripts are the only thing actually executed non-interactively in this pipeline; a skill markdown file cannot be "called" by another skill's bash stage.

**6. Documentation drift in command-level docs (out of `orchestrator-postflight.sh`'s control, but part of "the commit pipeline" as documented)**

`.claude/extensions/core/commands/research.md` CHECKPOINT 3 (lines 471-479) shows `git add -A && git commit -m "task {N}: complete research..."` — but `orchestrator-postflight.sh` explicitly sets `do_git_commit="false"` for the `research` operation type, meaning **research never commits in the actual pipeline**. This command doc is stale relative to the actual script behavior (likely predates the shared postflight script) and should be corrected or removed during implementation, independent of the `git add -A` fix, to avoid the doc actively telling a future reader that research commits when it does not.

`.claude/extensions/core/commands/plan.md` and `.claude/extensions/core/commands/implement.md` have their own CHECKPOINT 3 `git add -A` examples too (lines ~500 and ~187/192 respectively) — these are illustrative doc snippets, not executed code, but should be updated in lockstep with the real fix so the documentation doesn't contradict the implementation.

### External Resources

Not applicable in the traditional sense (no external library/API involved) — this is entirely an internal process/tooling fix. The one relevant piece of general git knowledge worth noting for the implementer: `git add <directory>/` is recursive and safe for scoping to a task's own `specs/{NNN}_{SLUG}/` tree (already proven by the team skills), but scoping *source* files (outside `specs/`) cannot be done by directory convention — there is no fixed directory for "files task N touched"; it must come from either agent self-report or a `git status`/`git diff` derivation, per the H7 "territory contracts" pattern already used in hard-mode (`.claude/context/patterns/...` — hard mode declares file ownership up front for parallel dispatch; standard mode has no equivalent declaration today).

### Recommendations

**Scope-in (matches the 2-4 hour estimate) — the core single-agent pipeline:**

1. **Create `.claude/context/standards/git-staging-scope.md`** (+ `extensions/core` dual copy) defining the commit-scope contract per operation type, closing the dangling reference from `skill-team-research/SKILL.md:563`:
   - `research` — no commit (unchanged; already safe).
   - `plan` — stage exactly `specs/{padded}_{slug}/`, `specs/TODO.md`, `specs/state.json` (mirrors the already-proven team-plan pattern; zero new contract needed, since plan never touches source files).
   - `implement` — stage `specs/{padded}_{slug}/`, `specs/TODO.md`, `specs/state.json`, the plan file path, **plus** each path in a new `modified_files` array (see below).

2. **Add optional `modified_files: string[]`** to the return-meta.json schema (`.claude/context/formats/return-metadata-file.md`), read the same way `completion_summary`/`roadmap_items`/`memory_candidates` already are (Stage 6 of both `orchestrator-postflight.sh` and `skill-implementer/SKILL.md`). Populate it in `general-implementation-agent.md` Stage 6 (Create Implementation Summary) by having the agent accumulate every `Write`/`Edit` target path during Stage 4 execution (simplest: append to an in-memory or progress-file-persisted list at Stage 4B, step "Create or modify files" — the progress-file schema (`.claude/context/formats/progress-file.md`) does not currently record file paths per objective and would need a small additive field, e.g. `files_touched: []` per objective, summed at Stage 6).

3. **Rewrite `orchestrator-postflight.sh` Stage 9** (single file, no dual copy) to branch on `operation_type`:
   - `plan`: targeted `git add` per item 1 above (no schema dependency — ship this first, it's zero-risk and immediately closes the `plan` half of the bug).
   - `implement`: targeted `git add` of the fixed paths + `jq -r '.modified_files[]? // empty' "$metadata_file"`, falling back to a **non-silent** warning (not `git add -A`) if `modified_files` is absent/empty — e.g., stage only the fixed task-dir paths and print `[postflight] WARNING: no modified_files reported; source-file changes NOT committed automatically. Review and commit manually.` This fail-safe direction (under-stage rather than over-stage) is the one that actually eliminates the "concurrent session's stray edits get swept in" failure mode, even in the degraded case.

4. **Fix `skill-implementer/SKILL.md` Stage 6b** (+ dual copy) and **`general-implementation-agent.md`'s per-phase commit** (+ dual copy): these run *before* the final `modified_files` list exists, so they need an **incremental** scope — accumulate `modified_files` entries into the progress file as the phase executes (same field as item 2), and stage `specs/{padded}_{slug}/ specs/TODO.md $plan_path` + only the paths accumulated *so far* at each phase boundary, not a repo-wide add. Reconcile/remove `skill-implementer/SKILL.md`'s apparently-vestigial inline "Stage 9: Git Commit" text (lines 641-650) if confirmed dead relative to the `orchestrator-postflight.sh` delegation, to avoid two divergent descriptions of the same commit.

5. **Harden `git-workflow.md`** (+ dual copy): add `git add -A` and `git commit -am` explicitly to the existing "Never Run" list (currently lines 77-82, which lists `push --force`, `reset --hard`, `rebase -i`, generic "destructive operations without confirmation" but not these two), and reference the new `git-staging-scope.md` from item 1 in the existing "Commit Scope" section (lines 51-62) and "Always Check Before Commit" section (lines 121-124).

6. **Wire `skill-git-workflow`** as the documented, canonical *reference* for the scope contract (update its "Execution Commands" and "Commit Scope Rules" sections to point at the same `git-staging-scope.md` + describe the actual `orchestrator-postflight.sh` behavior, since nothing can literally "call" a skill from a bash script) — extract the scope-selection logic into a small shared bash function/script if duplicated logic between `orchestrator-postflight.sh` and any future direct invocation of `skill-git-workflow`'s flow becomes a maintenance risk.

**Scope-out (flag as follow-up, do not attempt in this task's budget):**

- The ~15 extension-specific implementation agents/skills with their own `git add -A` (founder, present, epidemiology, web, latex, z3, nix, neovim, typst, literature) — same fix pattern applies but each is its own file/dual-copy pair; a dedicated sweep task is more appropriate.
- Checkpoint-pattern reference docs (`checkpoint-execution.md`, `checkpoint-commit.md`, `checkpoint-before-overflow.md`) and the command-level CHECKPOINT 3 examples in `research.md`/`plan.md`/`implement.md` — update for consistency once the real behavior is settled, but these are illustrative docs, not executed paths.
- `git-snapshot.sh`'s internal `git add -A` (line 150) — **intentionally exempt**: it is a full-tree WIP snapshot/stash mechanism (task 780), not a task-scoped commit, and sweeping everything is its correct, documented behavior.

## Decisions

- Confirmed both cited line ranges (git-workflow.md 51-62, git-safety.md 182-195) are accurate — no correction needed to the task's root-cause citation.
- Determined `orchestrator-postflight.sh` has no dual/shared copy today; the task description's "(project + shared copy)" instruction should be reinterpreted as applying to the *other* four files in the pipeline (skill-implementer, general-implementation-agent, git-workflow.md, skill-git-workflow) which do follow the dual-deploy convention, not to the postflight script itself.
- Recommend implementing the `plan`-operation-type fix first (item 3, plan branch) since it requires zero schema changes and can reuse the team-skill pattern verbatim — this alone eliminates the "plan commits sweep everything" half of the bug immediately.
- Recommend the `modified_files` contract be populated by agent self-report (accumulated during Stage 4 execution) rather than derived from `git status --porcelain` diffing, because diffing cannot distinguish "this task's changes" from "a concurrent session's stray edits to arbitrary source files outside the task directory" — which is precisely the failure mode task 785 exists to eliminate. Self-report is the only mechanism that is authoritative about *intent*.
- Recommend scoping the implementation plan to the 6 items above and explicitly excluding the extension-specific skills/agents sweep as a separate, spawned task.

## Risks & Mitigations

- **Risk**: `modified_files` self-report could be incomplete (agent forgets to append a path after an `Edit`/`Write` call) → under-staging → files silently left uncommitted, task looks "complete" but has orphaned working-tree changes. **Mitigation**: the fallback behavior in item 3 (warn loudly, don't silently drop) plus a post-commit `git status --porcelain` check the skill can log a warning against if it's non-empty after the targeted commit — surfacing rather than hiding the gap.
- **Risk**: Fixing `orchestrator-postflight.sh` alone (ignoring `skill-implementer.md`'s own inline Stage 6b/Stage 9 and `general-implementation-agent.md`'s per-phase commit) would leave the bug fully alive for `implement` tasks, since those three sites run independently of the shared script. **Mitigation**: explicitly plan all 3 sites (items 3 and 4) as one unit — this is called out because it's easy to believe editing only `orchestrator-postflight.sh:322` "fixes the pipeline" when it does not fix `implement`'s per-phase commits at all.
- **Risk**: Editing only the project copy of the 4 dual-deployed files without the `extensions/core` mirror will silently regress on the next full sync/`Ctrl-l` reload (this exact failure mode is documented as a prior real incident in task 780's report re: `block-pr-submission.sh`). **Mitigation**: treat every edit to these 4 files as a paired edit, verified with `diff` before considering the phase done (same practice task 780 used).
- **Risk**: Scope creep — attempting the full ~80-site sweep in one implementation pass blows the 2-4 hour estimate by an order of magnitude and risks an incomplete/inconsistent partial implementation. **Mitigation**: explicit "scope-out" list above; recommend `/spawn` or a manually created follow-up task for the extension sweep once the core pattern is proven.

## Context Extension Recommendations

- **Topic**: Commit-scope contract per operation type
- **Gap**: No canonical document exists today (`git-staging-scope.md` is referenced but absent); the contract is currently implicit and only partially realized in the `--team` skills.
- **Recommendation**: Task 785's implementation should create `.claude/context/standards/git-staging-scope.md` (+ dual copy) as this document, and update `git-workflow.md`, `skill-git-workflow/SKILL.md`, and `skill-team-research/SKILL.md`'s reference to point at the real file.

## Appendix

Search/verification commands used:
```
grep -n "git add -A\|git commit -am" across .claude/skills, .claude/scripts, .claude/agents, .claude/extensions
find . -iname "orchestrator-postflight.sh" (filesystem-wide, confirmed single copy)
find . -iname "git-staging-scope.md" (confirmed absent)
diff <project-copy> <extensions/core-copy> for skill-implementer, general-implementation-agent, git-workflow.md, skill-git-workflow (all byte-identical)
git log --oneline -- .claude/rules/git-workflow.md (confirmed task 780's prior edit, no conflict)
jq '.active_projects[] | select(.project_number==780)' specs/state.json (confirmed 780 completed, dependency satisfied)
```

References read in full: `.claude/scripts/orchestrator-postflight.sh`, `.claude/rules/git-workflow.md`, `.claude/context/standards/git-safety.md`, `.claude/skills/skill-git-workflow/SKILL.md`, `.claude/skills/skill-implementer/SKILL.md` (lines 400-680), `.claude/agents/general-implementation-agent.md` (lines 28-459), `.claude/skills/skill-team-research/SKILL.md` (lines 540-565), `.claude/skills/skill-team-implement/SKILL.md` (lines 390-561), `.claude/context/formats/return-metadata-file.md`.

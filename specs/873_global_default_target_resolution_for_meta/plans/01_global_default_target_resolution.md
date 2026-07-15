# Implementation Plan: Task #873

- **Task**: 873 - Add global-default target resolution and `--local` flag to `/meta`
- **Status**: [NOT STARTED]
- **Effort**: 5.25 hours
- **Dependencies**: None (this task establishes the mechanism task 875 consumes)
- **Research Inputs**: specs/873_global_default_target_resolution_for_meta/reports/01_global_default_target_resolution.md
- **Artifacts**: plans/01_global_default_target_resolution.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Make `/meta` default to creating tasks in the global agent-system root
(`GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"`) with `--local` as the only
opt-out and no interactive prompt. Three source files change, all under
`agent-system/extensions/core/`: a flag added to `parse-command-args.sh`, the resolution +
threading + postflight commit made concrete in `skill-meta/SKILL.md`, and the semantics
documented in `commands/meta.md`. The final two phases are empirical verification — a shell-level
proof of the chained-`cd` mechanism and an actual cross-repo `/meta` invocation — because the
research explicitly did not verify the mechanism live.

### Research Integration

The research materially refined the task description's stated mechanism, and this plan adopts the
refinement:

- **The description's premise is false as stated.** A single early `cd "$GLOBAL_ROOT"` does NOT
  make later Bash calls resolve at the global root: Bash-tool cwd does not persist across separate
  Bash tool invocations (confirmed by this repo's own `parse-command-args.sh` sourcing convention
  and by GitHub issue anthropics/claude-code#12748). The refinement honors the "do not redesign the
  cd mechanism" constraint — `cd` remains the mechanism, it is just applied at each point of use:
  re-derive `GLOBAL_ROOT` and chain `cd "$GLOBAL_ROOT" && ...` as ONE Bash tool call.
- **Write/Edit are not subject to shell cwd at all.** They take the literal path string. Task-directory
  writes must therefore use `$GLOBAL_ROOT`-qualified or absolute paths regardless of any `cd`. This is
  a stricter, separate requirement from the git-commit cwd question.
- **(a) Permission/sandbox is not a blocker.** Every sampled `settings.json` grants unscoped
  `Write`/`Edit`/`Bash(cd *)`; `literature-ingest.sh` is live cross-repo-write precedent. No permission
  pre-probing logic will be added. `--local` is retained as user-intent control, not as a workaround.
- **(b) `CLAUDE_AGENT_GLOBAL_ROOT` and Lua's `global_source_dir` cannot be literally coupled** (different
  runtimes, no shared IPC). Mitigation is documentation-only; the two Lua files are outside `file_scope`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided in the delegation context (`roadmap_path` absent, `roadmap_flag`
unset). No roadmap phases are included.

### Plan-Specific Findings (beyond the research report)

Three facts were confirmed while planning and drive concrete phase decisions:

1. **`/meta` cannot source `parse-command-args.sh`.** Step 6 of `parse_command_args()` hard-fails
   (`return 1`) when no task numbers are present, and `/meta` takes a free-form prompt, never
   `N[,N-N]`. Grep confirms neither `commands/meta.md` nor `skill-meta/SKILL.md` references the
   script today. Consequence: `LOCAL_FLAG` is added to `parse-command-args.sh` as the **canonical
   shared definition** (per `file_scope`), and `/meta` gets a **same-shaped standalone inline check**.
   These are deliberately parallel, not redundant — Phase 3 documents why.
2. **`skill-meta/SKILL.md` contains no literal git commands today.** Its postflight is prose only
   ("Git commit (if tasks were created)", lines 233-236). The concrete chained bash block must be
   *added*, not edited.
3. **`meta-builder-agent` — not `skill-meta` — performs the actual task-directory writes**, using bare
   `specs/` paths, and it is out of scope (task 875). Left unaddressed, a cross-repo `/meta` would write
   task dirs into the *foreign* repo, leaving `cd "$GLOBAL_ROOT" && git add specs/` with nothing to
   stage — making Phase 5's verification vacuous. **Mitigation within `file_scope`**: `skill-meta`
   constructs the Agent-tool prompt, so it will carry an explicit imperative path-qualification
   instruction alongside the threaded `mode`/`root`. Task 875 later makes this durable in the agent
   definition itself. This keeps task 873 independently verifiable.

## Goals & Non-Goals

**Goals**:
- `/meta` defaults to global mode; `--local` is the only opt-out; no interactive prompt.
- Resolution is a genuine no-op when `/meta` runs from within `~/.config/nvim` (not a special-cased branch).
- The postflight git commit provably lands in the global repo, verified live.
- `--local` follows the `parse-command-args.sh` regex-match + sed-strip convention verbatim.
- Semantics, the source-store-vs-deploy-tree distinction, and the parallel-defaults note are documented.

**Non-Goals**:
- Refactoring the ~49 scripts (explicitly forbidden).
- Introducing `CLAUDE_PROJECT_DIR` (deliberately never adopted; appears nowhere in live code).
- Editing `meta-builder-agent.md` (task 875) or any Lua file (`config.lua`, `scan.lua` — outside `file_scope`).
- Adding permission-probing / `additionalDirectories` logic (research finding (a): unnecessary).
- Code-coupling `CLAUDE_AGENT_GLOBAL_ROOT` to `global_source_dir` (research finding (b): not achievable in scope).
- Fixing the pre-existing "Task 594 / Task 595" task-number references in `parse-command-args.sh`'s
  header comment (lines 25-27). These violate `no-task-references-in-deliverables.md` and sit in a file
  this task edits, but removing them is unrelated churn. **Observed and flagged for a follow-up task; do
  not fix here, and do not add any new task-number references.**

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Chained-`cd` commit does not land in the global repo as theorized | H | L | Phase 4 proves it at shell level before Phase 5 spends effort end-to-end |
| Phase 5 blocked: `/meta` confirmation gate cannot be driven headlessly | M | M | Phase 5 has an explicit decision point and an honest [BLOCKED] fallback — never a fabricated pass |
| `meta-builder-agent` ignores the threaded root (its own file is task 875's scope) | M | M | skill-meta carries an imperative path-qualification instruction in the Agent prompt (Phase 2); if Phase 5 shows it ignored, that is a real finding handed to 875, not a failure to hide |
| Edits land in `.claude/` and are silently wiped by the next regeneration | H | L | Every phase asserts the `agent-system/extensions/core/` path; Phase 4 re-verifies source/deploy identity |
| Phase 5 leaves a throwaway task + commit polluting the global repo | M | H (by design) | Cleanup is a mandatory, explicitly-verified step of Phase 5 |
| Upstream bug anthropics/claude-code#33576 (subagent Bash cwd may default to `/root`) | M | L | Out of scope; blast radius reduced by using absolute/`$GLOBAL_ROOT`-qualified paths for Write/Edit. Noted, not actioned |
| Future project scopes `Write` to project-relative globs, breaking global mode | L | L | `--local` is the opt-out; Phase 3 documents the settings dependency so tightening is an informed choice |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2 |
| 3 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel. Wave 1 phases touch three disjoint files with
no shared edit surface, so they are safe to parallelize under a territory split.

---

### Phase 1: Add `--local` to parse-command-args.sh [COMPLETED]

**Goal**: Establish `LOCAL_FLAG` as the canonical shared flag definition, following the `--clean`
convention verbatim.

**Tasks**:
- [x] Add `LOCAL_FLAG` to the exported-variables header comment block (near line 18-23), matching the
      existing `CLEAN_FLAG — "true" or "false"` comment style. Describe it as the `/meta` local-mode opt-out. *(completed)*
- [x] Add `LOCAL_FLAG="false"` to the Step 4 initializer block (near line 71-75). *(completed)*
- [x] Add the regex check alongside the other flag checks (near lines 103-117):
      `if [[ "$remaining" =~ --local ]]; then LOCAL_FLAG="true"; fi` *(completed)*
- [x] Add `| sed 's/--local//g'` to the Step 5 `FOCUS_PROMPT` strip pipeline (near lines 129-133). *(completed)*
- [x] Add `LOCAL_FLAG` to the Step 6 `export` statement (line 142). *(completed)*
- [x] Do NOT touch the Step 6 task-number validation gate, and do NOT remove the stale
      "Task 594 / Task 595" comment (see Non-Goals). *(completed: left untouched, verified no new task-number references added)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/scripts/parse-command-args.sh` - add `LOCAL_FLAG` in five places
  (header comment, initializer, regex check, sed strip, export), mirroring `CLEAN_FLAG` exactly.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/parse-command-args.sh` passes.
- Sourcing with `"873 --local"` yields `LOCAL_FLAG=true` and a `FOCUS_PROMPT` with no `--local` residue.
- Sourcing with `"873"` yields `LOCAL_FLAG=false`.
- `git diff` confirms `CLEAN_FLAG` / `FORCE_FLAG` / `LIT_FLAG` behavior is byte-for-byte unchanged.

---

### Phase 2: GLOBAL_ROOT resolution, threading, and chained postflight in skill-meta [COMPLETED]

**Goal**: Make `skill-meta` resolve the root, detect `--local` inline, thread the resolved mode/root to
the agent with an imperative path-qualification instruction, and perform the postflight commit as a
single chained Bash invocation.

**Tasks**:
- [x] In Section 1 "Input Validation" (lines 46-64), extend the existing bash-fenced mode-detection block to:
      - Resolve `GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"` (mirrors the established
        `LIT_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"` pattern).
      - Detect `--local` with a standalone regex check shaped like `parse-command-args.sh`'s
        (`[[ "$args" =~ --local ]]`), and strip it from the prompt with `sed 's/--local//g'`.
        Add a comment stating why the shared script is not sourced here: its task-number
        validation gate hard-fails on `/meta`'s free-form argument grammar.
      - Set `target_root` = `$GLOBAL_ROOT` (global mode) or the current repo root (local mode).
      - Ensure `--local` is stripped before `mode` is classified, so `/meta --local` does not
        mis-classify as `mode=prompt` with `prompt="--local"`. *(completed)*
- [x] Add a note that global mode is a genuine no-op when invoked from within `$GLOBAL_ROOT` — the same
      code path runs and resolves to the same repo. No special-casing branch. *(completed)*
- [x] In Section 2 "Context Preparation" (lines 68-81), add `"mode_target": "global|local"` and
      `"target_root": "{resolved absolute path}"` to the delegation-context JSON. *(completed)*
- [x] In Section 3 "Invoke Subagent" (lines 83-100), require the Agent-tool prompt to carry an explicit
      imperative: **all task-directory Write/Edit paths MUST be qualified by `target_root` (or absolute) —
      never bare `specs/...`** — because Write/Edit path resolution is independent of any Bash-side `cd`.
      Note that this instruction is carried by the prompt today and is made durable in the agent
      definition by the dependent follow-up work. *(completed)*
- [x] Replace the prose-only postflight (lines 233-236) with a concrete chained bash block, and state
      that it MUST be issued as a single Bash tool call because cwd does not persist across invocations:
      ```bash
      GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"
      cd "$GLOBAL_ROOT" && git add specs/ && git commit -m "..."
      ```
      In local mode the same block runs with `target_root` = current repo (no-op-equivalent). *(completed)*
- [x] Keep the "MUST NOT (Postflight Boundary)" list intact; the postflight remains limited to reading
      the agent return and the git commit. *(completed)*
- [x] Do not add task-number references anywhere in this file. *(completed: grep confirmed clean)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/skills/skill-meta/SKILL.md` - Section 1 (resolution + `--local` +
  no-op note), Section 2 (thread `mode_target`/`target_root`), Section 3 (path-qualification imperative),
  postflight (concrete chained git block).

**Verification**:
- Extract each bash block and confirm `bash -n` passes.
- Confirm the postflight block re-derives `GLOBAL_ROOT` inline rather than depending on any earlier `cd`.
- Confirm `mode_target` and `target_root` appear in the Context Preparation JSON.
- Confirm the frontmatter `allowed-tools` already includes `Bash` (it does) — no change needed.
- Confirm no `.claude/` path is written and no task-number reference was introduced.

---

### Phase 3: Document global-default semantics in commands/meta.md [COMPLETED]

**Goal**: Document the flag, the semantics, the source-store-vs-deploy-tree distinction, the
parallel-defaults note, and the settings dependency.

**Tasks**:
- [x] Update the `argument-hint` frontmatter (line 4) from `"[PROMPT] | --analyze"` to include `--local`. *(completed)*
- [x] Add `--local` to the Arguments section (lines 14-18) with a one-line description. *(completed)*
- [x] Add a "Target Resolution" subsection to Mode Detection (Execution step 1, lines 57-69) documenting:
      - Global-by-default; `--local` is the only opt-out; there is no interactive prompt.
      - `GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"`.
      - Running from within the global root is a no-op, not a special case.
      - `cd "$GLOBAL_ROOT"` must be **chained at each point of use** in a single Bash invocation; a `cd`
        issued in an earlier, separate Bash call does not persist. Write/Edit take literal paths and are
        unaffected by shell cwd entirely — they must be `$GLOBAL_ROOT`-qualified or absolute. *(completed)*
- [x] Add a "Canonical Source vs Deploy Tree" note: the source of truth is `agent-system/extensions/core/`;
      each repo's `.claude/` is a gitignored, disposable deploy artifact regenerated from the source store
      (selection pinned by the project-root `.claude-extensions.json`). A change written to `.claude/` is
      silently wiped by the next regeneration. Tasks created by `/meta` targeting the agent system must
      edit the source store; each repo regenerates its own `.claude/` via the `<leader>al` loader. *(completed)*
- [x] Add the parallel-defaults note (research finding (b)): `CLAUDE_AGENT_GLOBAL_ROOT` (shell, consumed
      by `/meta`) and `global_source_dir` (Lua, `lua/neotex/plugins/ai/claude/config.lua`, consumed by the
      `<leader>al` picker/loader) are **independently-resolved values that share the `~/.config/nvim`
      default by convention, not by mechanism**, and must be updated together if either is customized.
      State plainly that they are deliberately not coupled: they live in different runtimes with no
      shared IPC. *(completed)*
- [x] Add the settings-dependency note (research finding (a)): global-mode writes rely on `Write`/`Edit`
      being unscoped in the effective `settings.json`; a project that scopes `Write` more tightly would
      need to add the global root to its own allowed paths, or use `--local`. *(completed)*
- [x] Confirm the Anti-Bypass Constraint section still reads correctly — global mode changes *which*
      repo's `specs/` is the legitimate target, not the `specs/`-allowed / `.claude/`-forbidden boundary.
      Amend only if the wording implies a single repo. *(completed: reviewed, wording is repo-agnostic already, no amendment needed)*
- [x] Do not add task-number references anywhere in this file (no "task 875", no "task 873"). *(completed: grep confirmed clean)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/commands/meta.md` - frontmatter `argument-hint`, Arguments section,
  Mode Detection "Target Resolution" subsection, source-vs-deploy note, parallel-defaults note,
  settings-dependency note.

**Verification**:
- `--local` appears in both the frontmatter hint and the Arguments section.
- All four required notes are present (semantics, source-vs-deploy, parallel-defaults, settings dependency).
- `grep -inE '\btasks? [0-9]{2,4}\b' agent-system/extensions/core/commands/meta.md` returns nothing.
- Documented semantics match what Phase 2 actually implemented (re-read Phase 2's diff to confirm).

---

### Phase 4: Shell-level verification of the chained-cd mechanism [COMPLETED]

**Goal**: Empirically prove — before spending effort on the end-to-end run — that a chained
`cd "$GLOBAL_ROOT" && git ...` from a foreign cwd operates on the global repo, and that an unchained
`cd` does not persist. This validates the research's central refinement.

**Tasks**:
- [x] From a foreign repo cwd (e.g. `~/Projects/cslib`), in a SINGLE Bash call, run:
      `cd ~/Projects/cslib && GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}" && cd "$GLOBAL_ROOT" && git rev-parse --show-toplevel`
      Record the actual output. Expected: `/home/benjamin/.config/nvim`. *(completed: deviation — used
      `$SCRATCH/fake-foreign-repo` instead of `~/Projects/cslib` to avoid side effects in a real
      external repo, per the plan's own "e.g." framing. OBSERVED output: `/home/benjamin/.config/nvim`
      — matches expected.)*
- [x] In a SEPARATE Bash call, run `git rev-parse --show-toplevel` with no `cd` and record the output.
      This demonstrates whether the prior call's `cd` persisted. Record the observed behavior verbatim
      whichever way it resolves — this is the empirical check on the research's claim. *(completed:
      OBSERVED — a follow-up separate Bash call's `pwd` reverted to `/home/benjamin/.config/nvim` (the
      session's default cwd) even after an explicit `cd "$SCRATCH/fake-foreign-repo"` in the prior,
      separate call. Confirms cwd does NOT persist across separate Bash tool invocations — the
      research's central refinement is empirically validated.)*
- [x] Confirm the `--local` path: with `target_root` = foreign repo, the same chained block resolves to the
      foreign repo, not the global root. *(completed: OBSERVED — `TARGET_ROOT="$SCRATCH/fake-foreign-repo" && cd "$TARGET_ROOT" && git rev-parse --show-toplevel` returned the scratch foreign-repo path, not the global root.)*
- [x] Confirm the no-op path: run the chained block with cwd already `~/.config/nvim` and confirm it
      resolves to `~/.config/nvim` (same code path, no special-casing). *(completed: OBSERVED — returned
      `/home/benjamin/.config/nvim`.)*
- [x] Re-confirm source/deploy identity for the three changed files
      (`diff agent-system/extensions/core/<f> .claude/<f>`) and record which now differ — after Wave 1 they
      SHOULD differ, proving edits landed in the source store and not the deploy tree. *(completed:
      OBSERVED — all three files now differ: `parse-command-args.sh` (diff exit 1, 14 lines of diff),
      `skill-meta/SKILL.md` (diff exit 1, 70 lines), `commands/meta.md` (diff exit 1, 55 lines). All
      three are byte-identical to `.claude/` copies pre-Wave-1 and now diverge, confirming edits landed
      exclusively in the source store.)*
- [x] Record every command and its actual output in the phase notes. Do not paraphrase expected output as
      observed output. *(completed: recorded in the implementation summary.)*

**Timing**: 0.75 hours

**Depends on**: 1, 2

**Files to modify**:
- None (read-only verification). No commits, no mutations.

**Verification**:
- The chained-`cd` `git rev-parse --show-toplevel` output was actually observed to be the global root.
- The unchained-`cd` behavior was actually observed and recorded.
- If the chained block does NOT resolve to the global root, STOP: the mechanism is wrong, Phase 5 is
  blocked, and the finding is reported rather than worked around.

---

### Phase 5: Live cross-repo `/meta` verification [BLOCKED]

**Goal**: Empirically confirm, via an actual cross-repo `/meta` invocation, that the commit lands in the
global repo. The research explicitly did NOT verify this live and flagged it as required. **This phase may
not be marked complete on reasoning alone.**

**Deviation from plan (orchestrator instruction)**: two sibling tasks were executing concurrently in this
same real nvim repo during this implementation, with postflight writes touching the real
`specs/state.json`. Running the live test against the real `~/.config/nvim` and `~/Projects/cslib` repos
(as originally planned) risked a lost update to the real system's machine truth. Per explicit orchestrator
instruction, this phase was redirected to run against a **temporary scratch global root and a temporary
scratch foreign repo** instead — testing the identical mechanism with zero blast radius on real state.

**Tasks**:
- [x] **Deploy for test**: built `$SCRATCH/fake-global-root/` (throwaway global root: `specs/state.json`
      skeleton with `next_project_number: 1` and empty `active_projects`, `specs/TODO.md`, git-initialized)
      and `$SCRATCH/fake-foreign-repo/` (throwaway foreign repo). Copied the real repo's full `.claude/`
      deploy tree into both, then overlaid the three Wave-1-edited source-store files
      (`parse-command-args.sh`, `skill-meta/SKILL.md`, `commands/meta.md`) on top — simulating exactly what
      the `<leader>al` loader's `copy` action does, scoped to scratch dirs instead of real repos.
      *(altered from plan: scratch dirs substituted for the real `~/.config/nvim`/`~/Projects/cslib` deploy
      trees, per orchestrator redirect above.)*
- [x] **Run the live test**: attempted a headless `claude -p '/meta "throwaway verification task: add a
      trivial no-op debug print statement"'` invocation from `$SCRATCH/fake-foreign-repo` (cwd), with
      `CLAUDE_AGENT_GLOBAL_ROOT=$SCRATCH/fake-global-root` exported, bounded by a 90s `timeout`.
      **OBSERVED result**: the process printed exactly one line and exited on its own (no timeout kill
      needed, confirmed via `pgrep` — no orphaned process):
      ```
      Ignoring 24 permissions.allow entries from .claude/settings.json: this workspace has not been
      trusted. Run Claude Code interactively here once and accept the trust dialog, or set
      projects["<path>"].hasTrustDialogAccepted: true in ~/.claude.json.
      ```
      **Decision point resolved as BLOCKED**: this is a *more fundamental* headless blocker than the plan's
      anticipated AskUserQuestion confirmation gate — it fires before permissions or any confirmation step
      are even reached. A freshly-created scratch directory has no accepted Claude Code trust dialog, and
      that dialog cannot be satisfied non-interactively. The only way to clear it (editing
      `~/.claude.json`'s per-project `hasTrustDialogAccepted` flag) mutates a real, global, user-wide config
      file outside both the sanctioned edit targets and the scratch test harness — out of scope for this
      task's blast radius, so it was deliberately NOT attempted. Per the orchestrator's explicit
      instruction, the result is reported honestly as BLOCKED rather than worked around or inferred.
- [x] **Observe and record**: no task directory was created anywhere (`$SCRATCH/fake-global-root/specs/`
      remains the untouched skeleton — `next_project_number` still `1`, `active_projects` still `[]`;
      `$SCRATCH/fake-foreign-repo` git log shows only the harness-setup commit). No `/meta` execution ever
      began — the run was blocked at the workspace-trust gate before mode detection or any skill/agent
      dispatch occurred.
- [x] **Interpret honestly**: the Agent-prompt path-qualification imperative added in Phase 2 was **never
      exercised** — the run never reached `skill-meta`, let alone `meta-builder-agent`. Phase 5 therefore
      provides **no evidence either way** about whether `meta-builder-agent` honors the threaded
      `target_root`. This is recorded as a genuine gap, not papered over: Phase 5's verification of the
      cross-task coupling with `meta-builder-agent` (out of this task's scope) remains **fully unverified**,
      to be exercised once that dependent work lands and once a properly-trusted headless or interactive
      test environment is available.
- [ ] **Verify `--local`**: not reached — blocked at the same workspace-trust gate before mode detection.
- [x] **Cleanup**: no cleanup was required — the workspace-trust block occurred before any write, so
      `$SCRATCH/fake-global-root/specs/state.json` was never mutated, no commit was made in either scratch
      repo beyond the harness-setup commit, and the real `~/.config/nvim` and `~/Projects/cslib` repos were
      never touched by this phase at all (confirmed: `git log --oneline -5` in the real repo shows no test
      commits; `diff .claude/commands/meta.md agent-system/extensions/core/commands/meta.md` still differs,
      confirming the real `.claude/` deploy tree was untouched by this test).
- [x] Write the observed results into the task summary. State plainly which claims are observed and which
      remain unverified. *(completed — see summary.)*

**Manual verification procedure** (for the user to run interactively, since headless cannot clear the
workspace-trust gate):
1. In a terminal, `cd ~/Projects/cslib` (or any other repo with `.claude/` deployed).
2. Run `<leader>al` in Neovim (or manually `cp` the three files) to deploy this task's changes:
   `agent-system/extensions/core/scripts/parse-command-args.sh` -> `.claude/scripts/parse-command-args.sh`,
   `agent-system/extensions/core/skills/skill-meta/SKILL.md` -> `.claude/skills/skill-meta/SKILL.md`,
   `agent-system/extensions/core/commands/meta.md` -> `.claude/commands/meta.md`.
3. Launch `claude` interactively in that repo (accepting the trust dialog if prompted).
4. Run `/meta "throwaway verification task"`.
5. At the confirmation prompt, answer to create the task(s).
6. Check: did the task directory land under `~/.config/nvim/specs/` (expected) or under
   `~/Projects/cslib/specs/` (would indicate the Agent-prompt imperative from Phase 2 was not honored)?
7. Check `git -C ~/.config/nvim log -1` for the new commit; check `git -C ~/Projects/cslib status
   --porcelain` stays clean.
8. Repeat with `/meta --local "throwaway verification task"` and confirm it now lands in
   `~/Projects/cslib/specs/` instead.
9. Clean up: remove the throwaway task dir + `state.json` entry, regenerate `TODO.md` via
   `bash .claude/scripts/generate-todo.sh`, and `git reset --soft HEAD~1` (never `--hard` on a dirty tree)
   to revert the throwaway commit(s).

**Timing**: 1.5 hours

**Depends on**: 1, 2, 3, 4

**Files to modify**:
- None in the source store. Temporary deploy-tree copies + throwaway task artifacts, all reverted by the
  mandatory cleanup step.

**Verification**:
- An actual cross-repo `/meta` invocation was run and its output observed — not inferred, not simulated.
- The commit was observed in `~/.config/nvim` and observed absent from `~/Projects/cslib`.
- `--local` was observed to invert that placement.
- Both repos are clean of test residue.
- If any of the above was not actually observed, the phase is [BLOCKED] or [PARTIAL] — never [COMPLETED].

---

## Testing & Validation

- [x] `bash -n` passes on `parse-command-args.sh` and on every bash block added to `skill-meta/SKILL.md`.
- [x] `LOCAL_FLAG` round-trips correctly (`true` with `--local`, `false` without, stripped from `FOCUS_PROMPT`).
- [x] Pre-existing flags (`--clean`, `--force`, `--lit`, `--team`, model/effort flags) are unchanged
      (observed: `CLEAN=true FORCE=true LIT=true TEAM=true EFFORT=fast MODEL=opus` with all flags combined).
- [x] All three edits are confirmed present in `agent-system/extensions/core/` and absent from any
      hand-authored `.claude/` change.
- [x] `grep -rinE '\btasks? [0-9]{2,4}\b'` over the three changed files introduces no new task-number
      references (the pre-existing `parse-command-args.sh` header comment is a known, flagged exception —
      confirmed the only two matches are the pre-existing "Task 594"/"Task 595" lines).
- [x] Chained-`cd` resolution observed correct from a foreign cwd (Phase 4).
- [ ] Cross-repo `/meta` commit placement observed correct (Phase 5) — **honestly reported as unverified**:
      headless invocation blocked at the workspace-trust-dialog gate before `/meta` execution began. See
      Phase 5 and the manual verification procedure recorded there.
- [ ] `--local` observed to place tasks in the local repo (Phase 5) — **not reached**, blocked at the same
      gate before mode detection.
- [x] Global mode observed to be a no-op from within `~/.config/nvim` (Phase 4, shell-level).

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/scripts/parse-command-args.sh` (`LOCAL_FLAG`)
- Modified: `agent-system/extensions/core/skills/skill-meta/SKILL.md` (resolution, threading, chained postflight)
- Modified: `agent-system/extensions/core/commands/meta.md` (flag + semantics + four required notes)
- `specs/873_global_default_target_resolution_for_meta/summaries/01_*-summary.md` recording the
  **actually observed** Phase 4 and Phase 5 verification output, including any unverified residue.
- Follow-up findings handed to the dependent agent-definition task (875) if Phase 5 shows the Agent-prompt
  imperative was not honored.
- Flagged (not fixed): stale task-number references in `parse-command-args.sh`'s header comment.

## Rollback/Contingency

- All three source edits are small, additive, and confined to files tracked in git. Revert with
  `git checkout HEAD -- agent-system/extensions/core/{scripts/parse-command-args.sh,skills/skill-meta/SKILL.md,commands/meta.md}`
  (clean-tree pathspec discard; snapshot via `bash .claude/scripts/git-snapshot.sh` first if the tree is dirty,
  per git-workflow.md).
- Deploy trees are disposable: any `.claude/` state left by Phase 5 is corrected by restoring the snapshot or
  by regenerating via `<leader>al`.
- If Phase 4 disproves the chained-`cd` mechanism, stop and re-plan — do not improvise a workaround
  (`CLAUDE_PROJECT_DIR` and script refactors remain forbidden).
- If Phase 5 cannot be driven to an actual observation, land Phases 1-4, mark the task [PARTIAL] with the
  exact manual verification procedure recorded, and leave the mechanism undeployed rather than declared working.

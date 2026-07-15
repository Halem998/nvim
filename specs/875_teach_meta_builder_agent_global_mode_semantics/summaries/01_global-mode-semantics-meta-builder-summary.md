# Implementation Summary: Task #875

**Completed**: 2026-07-15
**Duration**: ~55 minutes

## Overview

Taught `agent-system/extensions/core/agents/meta-builder-agent.md` global-mode semantics: it now
parses `mode_target`/`target_root` in Stage 1, holds `$TARGET_ROOT` for the whole run, and qualifies
every read-only inventory operation, task-creation `file_scope` heuristic, and write/mutate
operation against it. The conflated SCOPE BOUNDARY constraint was split into an actor/workflow rule
(unchanged: never implement directly) and a location-correctness rule (new: never target the
disposable `.claude/` deploy tree). All work is source-store-only; the deployed `.claude/` copy was
never touched.

## What Changed

- `agent-system/extensions/core/agents/meta-builder-agent.md` — the only file modified (source
  store; `.claude/agents/meta-builder-agent.md` is untouched and now diverges, as intended):
  - **Stage 1**: added `mode_target`/`target_root` fields to the delegation JSON example (matching
    `skill-meta/SKILL.md` field names exactly), extraction instructions, a CWD-never-fallback
    defensive default, and a new **Path Qualification Convention** block stating the
    absolute-path-default / chained-`cd`-for-`git`-only strategy.
  - **SCOPE BOUNDARY**: split into Rule 1 (actor/workflow, substance unchanged) and Rule 2
    (location-correctness, new), plus a `validate-meta-write.sh` hook-limitation note. The two
    FORBIDDEN/MUST NOT "outside specs/" entries now read `outside {target_root}/specs/`.
  - **Category B (read-only inventory)**: qualified Interview Stage 0's five commands, Stage 3B
    Step 2's related-task search, Stage 3C Step 1's four-block system-analysis inventory, and the
    Mode-Context Matrix `analyze` row (rewritten from static `@`-syntax to a runtime
    `Read {target_root}/...` instruction, since `@`-references cannot be parameterized). Also found
    and qualified a fifth read site the research report did not classify: the Stage 3
    External Dependency Validation's `jq ... specs/state.json` existence check (line ~415) — same
    bug class, same fix, discovered during Phase 6 self-review.
  - **Category C (task-creation paths)**: the file-footprint heuristic and Stage 3.5 "Affected
    Area" extraction now target `agent-system/extensions/core/{skills,agents,commands,rules,
    context}/`, never `.claude/**`; both worked examples updated; a documented known-limitation
    note (core is the default, extension-scoped disambiguation needs a human) was added. The
    `task_type = "meta"` classification keyword deliberately keeps the literal `.claude/` string
    (Decision 2), with an inline note explaining why this is not an inconsistency.
  - **Category D (write/mutate)**: `manage-topics.sh` (add + set) and `generate-todo.sh` (both the
    Stage 3A prose reference and the Stage 6 call) now use absolute
    `bash "${TARGET_ROOT}/.claude/scripts/..."` invocation, since both scripts self-resolve their
    project root from `BASH_SOURCE[0]` and `manage-topics.sh` has no override flag at all. The git
    commit is now a single chained `cd "$TARGET_ROOT" && git add specs/ && git commit -m ...` call
    (the one documented exception to absolute-path-default, matching `skill-meta`'s postflight
    form). Added an explicit `${TARGET_ROOT}`-qualified `Write(...)` example for task-directory
    creation (previously only prose comments). DeliverSummary's table generator and all three
    worked examples now render `{target_root}`-qualified paths under a new
    `**Created in**: {target_root} ({mode_target} mode)` header line. The Stage 5 return JSON
    schema's artifact path and metadata now render `{target_root}`-qualified paths and include
    `mode_target`/`target_root` fields, with an explicit path-rendering rule stated for all
    sibling schemas.

## Decisions

- Followed the plan's Decision 1 (absolute paths by default, chained `cd` for `git` only),
  Decision 2 (keep the `.claude/` classification keyword, only change produced `file_scope`), and
  Decision 3 (`core` as the documented default, extension-scoped disambiguation as a known
  limitation) verbatim — no deviation.
- Extended Phase 3's scope by one site beyond the plan's explicit task list: the External
  Dependency Validation `jq` read at (pre-edit) line ~415. This is the same Category B bug class
  the research report's own methodology targets ("every read/write path"), was not named in the
  research report's per-line classification, and was found during Phase 6's static verification
  pass. Fixing it in place (rather than leaving a known gap) is consistent with the plan's stated
  goal; it is recorded here as a plan-scope extension, not a deviation from an explicit
  instruction.

## Plan Deviations

- None from any explicitly stated plan task. One plan-scope extension is recorded above (Category
  B: qualified one additional read site the research report did not enumerate).

## Verification

**OBSERVED** (command run, output recorded):
- Source-vs-deploy divergence: `diff agent-system/.../meta-builder-agent.md .claude/agents/meta-builder-agent.md` — non-zero exit, file now 1528 lines vs 1429 in the untouched deploy copy. Confirms the edit landed in the source store only.
- Zero bare `bash .claude/scripts/` invocations: `grep -n 'bash \.claude/scripts/'` — zero hits.
- Bare `specs/state.json`/`specs/TODO.md` review: every remaining hit is either `${TARGET_ROOT}`-qualified, a comment pointing to a qualified target, or the one intentional-prose line (`- Direct file access: \`specs/TODO.md\`, \`specs/state.json\`` in the Context References section, describing file-access categories generically, not a literal invocation).
- Contract consistency: `mode_target`/`target_root` field names and value shapes in the agent's Stage 1 JSON example and Stage 5 return schema match `skill-meta/SKILL.md` lines 104-105 exactly.
- Category A untouched: `git diff` of the full task-875 change range shows zero touched lines among the `@.claude/docs/guides/{component-selection,creating-commands,creating-skills,creating-agents}.md` and `@.claude/context/templates/{thin-wrapper-skill,agent-template}.md` reference lines.
- No new task-number references: `git diff <pre-task-875-baseline>..HEAD -- agent-system/.../meta-builder-agent.md | grep '^\+' | grep -iE '\btasks? [0-9]{2,4}\b'` — zero hits. (Four pre-existing "task 796" references were untouched and are not part of this task's diff.)
- Bash syntax: extracted all 8 ```bash-fenced blocks from the file and ran `bash -n` on each. 7 pass clean. The 8th (Stage 6 CreateTasks "For each task" loop) fails — but this is a **pre-existing defect predating this task**: confirmed via `git show <pre-task-875-commit>:agent-system/.../meta-builder-agent.md` that the identical Python-style `for position, task_idx in enumerate(...)` pseudocode inside a ` ```bash ` fence already existed before any task-875 edit. My additions to that block (two comment lines) did not introduce or worsen the syntax error. My separate `Write(...)` task-directory example was deliberately placed in a plain (non-`bash`-labeled) fence, outside this pre-existing defect's scope.
- Scope discipline: all 6 task-875 commits (`git log --grep="^task 875"`) touched only `agent-system/extensions/core/agents/meta-builder-agent.md` and files under `specs/875_teach_meta_builder_agent_global_mode_semantics/`. `git status --short` on both paths is clean (fully committed). `lua/neotex/plugins/editor/which-key.lua` and `lua/neotex/plugins/tools/himalaya/utils/cli.lua` remain modified-but-unstaged, byte-identical to their pre-task-875 diff — untouched by this task. `specs/state.json` and `specs/TODO.md` show as modified in the working tree, but `git diff` confirms these changes are from prior `/meta`-task-creation and concurrent sibling-task orchestration (unrelated project entries), not from any task-875 commit — verified no task-875 commit's file list includes either path.
- Both SCOPE BOUNDARY rules present, separate, and non-contradictory: read back-to-back, Rule 1's "never implement directly" is textually intact; Rule 2 is purely additive about deploy-tree location.

**NOT OBSERVED**:
- Live cross-repo `/meta` test. This was never attempted in this implementation pass — it is
  explicitly out of scope for a success claim per the plan's Phase 6 contract, and is documented
  below as the user's manual procedure.

## Manual Live-Test Procedure (for the user)

Live cross-repo verification is blocked by Claude Code's non-interactive workspace-trust dialog
(the same blocker recorded against the dependency task) and was not attempted here. To verify
manually:

1. From a foreign repo's CWD, in an **interactive** Claude Code session (required — a
   non-interactive `claude -p` run cannot clear a fresh workspace's trust dialog), run `/meta`
   with a trivial prompt.
2. Confirm the created task directory, `state.json` entry, and `TODO.md` update all land under
   `~/.config/nvim/specs/` — **not** the foreign repo's `specs/`.
3. Confirm the foreign repo's `specs/` (if any) is untouched.
4. Confirm the DeliverSummary output shows the new `**Created in**: {target_root} ({mode_target}
   mode)` header line reporting the resolved global root.
5. Confirm `/meta --local` still resolves to the current (foreign) repo — the opt-out path.

## Notes

- The pre-existing pseudocode-in-`bash`-fence defect (Stage 6 CreateTasks per-task loop) is
  cosmetic/documentation-only — it does not affect the correctness of this task's path-qualification
  work, and fixing it was not in scope (not part of the plan's Non-Goals exclusions, but also not
  named as a required task). Flagging it here for visibility; a future task could relabel the fence
  or convert the pseudocode to literal bash.
- `validate-meta-write.sh`'s known limitation (it cannot distinguish repos) is now documented
  in-file per Phase 2, so a future reader will not mistake it for a target-root correctness backstop.

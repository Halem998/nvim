# Implementation Summary: Task #804

**Completed**: 2026-07-04
**Duration**: ~1 hour

## Overview

Wired `--fable` (the Fable 5 / `claude-fable-5` model family) into `parse-command-args.sh` as a
fourth first-class model flag alongside `--haiku`/`--sonnet`/`--opus`, and propagated its
documentation across every enumeration site the research report inventoried: command markdown
(Claude-Code + core mirror + OpenCode), the CLAUDE.md merge-source, the agent-frontmatter
standard, six skill SKILL.md files (+ mirrors), and three guide/architecture/meta-guide files
(+ mirrors). All 8 plan phases completed; all mirror pairs verified byte-identical.

## What Changed

- `.claude/scripts/parse-command-args.sh`, `.claude/extensions/core/scripts/parse-command-args.sh` — added `--fable` -> `MODEL_FLAG="fable"` branch (appended last, preserving last-match-wins precedence), `sed 's/--fable//g'` strip, header comment update. This is the only functional/behavioral change.
- `.claude/commands/{research,plan,implement}.md`, `.claude/extensions/core/commands/{research,plan,implement}.md` — argument-hint, Options table, Extract-Model-Flags step, focus-prompt strip line, model-resolution mapping updated with `--fable`.
- `.opencode/commands/{research,plan,implement}.md` — same flag surface added for design coherence with the claimed-active OpenCode runtime (not forced byte-identical to Claude-Code copies, per plan).
- `.claude/extensions/core/merge-sources/claudemd.md` — added `--fable` at the Command Reference usage strings, Model Enforcement paragraph, and Hard Mode composability bullet. `.claude/CLAUDE.md` (generated file) was intentionally left untouched — no runnable regeneration script was found in this environment; it will pick up the merge-source change on next extension load.
- `.claude/docs/reference/standards/agent-frontmatter-standard.md`, `.claude/extensions/core/docs/reference/standards/agent-frontmatter-standard.md` — added `--fable` to override-flags prose, a 4th "Model flags" table row, and an Examples entry. Default-tier tables left untouched (fable is override-only, matching `haiku`).
- `.claude/skills/skill-{researcher,planner,implementer}/SKILL.md` (+ core mirrors) — added `fable` to the prose "Model/Effort Flags" enumeration.
- `.claude/skills/skill-team-{research,plan,implement}/SKILL.md` (+ core mirrors) — added `fable` to the `model_flag` table-row description.
- `.claude/docs/guides/creating-commands.md`, `.claude/docs/architecture/architecture-spec.md`, `.claude/context/meta/meta-guide.md` (+ core mirrors) — added `--fable`/`"fable"` to the model-selectors prose, the `MODEL_FLAG` value comment, and the `/meta` negative enumeration respectively.

## Decisions

- Parser branch appended last (after `--opus`) to preserve documented last-match-wins precedence for combined model flags.
- CLAUDE.md content edited only in its merge-source (`claudemd.md`), never the generated `.claude/CLAUDE.md` file, per Recommendation 2.
- `--fable` scoped to the override-flags surface only in `agent-frontmatter-standard.md`; no new frontmatter default tier was added, matching how `haiku` is documented.
- `command-route-skill.sh`, `/orchestrate`, and `-hard` skill JSON passthrough fields were left untouched — confirmed out of scope by the research report (generic passthrough, no hardcoded model enumeration).
- `.opencode/commands/` copies were updated for design coherence even though the task's primary delegation path is Claude-Code, since they enumerate the identical flag surface and would otherwise silently omit `--fable`.

## Plan Deviations

- **Task 4.3** (locate and run CLAUDE.md regeneration mechanism) skipped: no runnable
  sync/regeneration script exists in `.claude/scripts/`; "Load Core" is an interactive picker
  action, not a script callable from this session. `.claude/CLAUDE.md` left untouched per the
  plan's documented fallback — it will regenerate correctly from the corrected merge-source on
  next extension load.
- **Task 7.4** (optional `research-flow-example.md` touch) skipped: plan explicitly marks this
  optional/low-priority since the file's example trace shows an empty `MODEL_FLAG=` and does not
  enumerate flag values, so there was nothing to add for consistency.

## Verification

- Build: N/A (documentation + one Bash parser)
- Tests: Passed — sourced `parse-command-args.sh "804 --fable some focus text"` produced `MODEL_FLAG=fable` and `FOCUS_PROMPT` with `--fable` removed.
- Mirror-pair `diff`: all 14 pairs (parser, 3 command files, agent-frontmatter-standard, 6 skill files, 3 guide/architecture/meta files) produced no output — byte-identical.
- `.opencode/commands/` `--fable` occurrence counts matched `--opus` counts in all three files.
- Repo-wide grep confirmed `--fable`/`fable` present at every one of the 30 inventoried target files; one unrelated substring false-positive ("diffable" in `plan-format.md`) noted and ignored.
- Territory check: `git diff --stat` shows `task-lock.sh`, `task-lock.md`, and `skill-orchestrate*/SKILL.md` as modified, but these are pre-existing dirty changes from the concurrently running task 808 batch (present in the working tree before this session started) — not touched by this task's edits. This task's edits are confined to the files listed under "What Changed" above.
- Files verified: Yes

## Notes

- `.claude/CLAUDE.md` will show `--fable` after the next extension-loader regeneration pass; until
  then its Command Reference table, Model Enforcement paragraph, and Hard Mode bullet remain in
  their pre-task state (this is expected and matches the project's own documented policy that the
  generated file is never hand-edited).
- No changes were made to `task-lock.sh`, `command-route-skill.sh`, `/orchestrate` skills, or
  `-hard` skill JSON passthrough fields, consistent with the plan's Non-Goals and the coordinated
  batch's territory split with tasks 808/809/810.

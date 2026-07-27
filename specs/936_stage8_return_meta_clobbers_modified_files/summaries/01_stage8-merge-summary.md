# Implementation Summary: Stop Stage 8 postflight from clobbering .return-meta.json modified_files

**Completed**: 2026-07-27
**Duration**: ~1 hour

## Overview

Fixed a defect in `skill-orchestrate`'s Stage 8 postflight where `.return-meta.json` was
overwritten wholesale (`jq -n '{status, metadata}' > file`) after an implementation agent had
already written a rich object to the same path, silently destroying `modified_files` and every
other field. This unconditionally caused CHECKPOINT 3 (the single-task commit site in
`commands/orchestrate.md`) to stage zero source-file changes on every single-task `/orchestrate`
run that reached Stage 8, with no warning. Converted both Stage 8 write sites to a read-modify-write
jq merge, added `modified_count` accounting plus the canonical fail-safe warning at CHECKPOINT 3,
documented the multiple-sequential-writers invariant, and proved the fix end-to-end with an
executable harness that produces real git commits and asserts on `git show --name-only`.

## What Changed

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — both Stage 8
  `.return-meta.json` writes (clean-exit and partial-exit) converted from a truncating `jq -n ...
  > file` redirect to a read-existing-then-merge-then-`mktemp`+`mv` form using jq's recursive
  merge operator `. * {...}`, with an inline comment explaining why the merge is required. The
  surrounding "do not correct this value back to completed" prose note was left byte-for-byte
  intact.
- `agent-system/extensions/core/commands/orchestrate.md` — CHECKPOINT 3's staging block gained
  `modified_count` accounting and the canonical, un-suffixed fail-safe warning (copied
  byte-for-byte from `git-staging-scope.md`'s "Fail-Safe Direction" section) emitted to stderr
  when zero `modified_files` entries are found, plus a short prose note above the block pointing
  at that canonical source.
- `agent-system/extensions/core/context/formats/return-metadata-file.md` — new "Multiple
  Sequential Writers" subsection added between `## Schema` and `## Field Specifications`, stating
  the read-modify-write invariant and naming the five producer-owned fields
  (`modified_files`, `completion_data`, `memory_candidates`, `reflection`, `artifacts`) that a
  later writer must never clobber.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — one-line cross-reference
  added to the existing `return-metadata-file.md` bullet under "Related Documentation", pointing
  at the new subsection.
- `specs/936_stage8_return_meta_clobbers_modified_files/tests/test-return-meta-merge.sh` — new
  executable harness (19 assertions, all passing) that extracts the shipped fenced ```bash```
  blocks from the four files above at runtime, builds a throwaway scratch git repo per case, and
  runs the real `git-commit-scoped.sh` against them.

## Decisions

- **Scope A: merge, not a distinct path.** Read the existing `.return-meta.json` (falling back to
  `{}` if absent) and apply jq's `. * {...}` recursive merge via `mktemp` + `mv`, rather than
  writing Stage 8's status/metadata to a second file. This preserves the existing single-reader
  contract (`orchestrate.md` CHECKPOINT 3, `orchestrate-recover-outcome.sh`) without touching
  either reader, and additionally deep-merges the `metadata` sub-object so `agent_type` /
  `session_id` / `delegation_path` survive alongside the newly written `cycles_used` /
  `final_state` — a strict improvement over a two-line `.status = ... | .metadata.cycles_used =
  ...` assignment, which would have preserved top-level fields but still discarded `metadata`
  sub-fields.
- **Scope B: un-suffixed canonical wording.** CHECKPOINT 3 is the single-task staging site, so it
  reuses the exact, un-suffixed warning from `git-staging-scope.md`'s "Fail-Safe Direction"
  section — the task-number-suffixed variant (`for task #{task_num}`) stays reserved for the
  multi-task per-task site (Stage MT-4 step 5.5), per that standard's own text.
- **Scope C: yes, added.** The absence of an explicit multi-writer invariant in
  `return-metadata-file.md` was the root enabler of the defect, so the new "Multiple Sequential
  Writers" subsection documents it going forward; this costs nothing since the Scope A fix already
  conforms to what the rule requires.

## Plan Deviations

- None (implementation followed plan). One clarification: the plan's Phase 1 verification step
  `grep -q 'do not "correct" this value back to' <file>` was confirmed present but observed to
  wrap across two source lines in the file's prose (pre-existing text, unrelated to this edit);
  confirmed via a newline-joined grep instead of a literal single-line match.

## Verification

- Build: N/A (markdown/shell-snippet task, no compiled build step).
- Tests: `bash specs/936_stage8_return_meta_clobbers_modified_files/tests/test-return-meta-merge.sh`
  — **PASS=19 FAIL=0**. Covers both Stage 8 exit paths (clean → `implemented`, partial →
  `partial`), confirms `modified_files`/`completion_data`/`memory_candidates`/`metadata.agent_type`
  all survive the merge, confirms two REAL commits (with printed SHAs) each contain
  `lua/harness_probe.lua` via `git show --name-only`, confirms the negative case emits the
  canonical un-suffixed warning on stderr and produces a commit containing only
  task-directory/specs paths, and a regression guard confirming no truncating `jq -n`
  `.return-meta.json` write remains in the Stage 8 region.
- Files verified: Yes — all four source-store files and the new test harness exist and contain
  the expected content; `bash -n` parses the harness cleanly.
- Consistency gates: `git status --short` shows zero `.claude/` paths touched — all edits are
  confined to `agent-system/extensions/core/` and `specs/936_.../`. A task-number-citation grep
  (`task [0-9]`, `tasks [0-9]`, `(task [0-9]`) over the diff of all four edited deliverable files
  returned nothing.

## Notes

- `bash .claude/scripts/check-extension-docs.sh` reports a pre-existing `core` extension FAIL (74
  "never deployed" advisory lines) that is unrelated to this task — it reflects a broad,
  pre-existing staleness of the deployed `.claude/` tree relative to the `agent-system/extensions/
  core/` source store, not anything newly introduced here. Per the SOURCE-STORE RULE, `.claude/`
  is a gitignored, disposable deploy artifact; this task's four edited source-store files
  (confirmed diffing against their currently-deployed `.claude/` counterparts) will pick up this
  fix automatically on the next extension sync (`<leader>al` → "Sync all (replace existing)", or
  `bash .claude/scripts/deploy-headless.sh`). No deploy-tree regeneration was performed as part of
  this task, consistent with the plan's "record explicitly... rather than reconcile" fallback,
  since the broader 74-item drift is out of this task's scope and a full regen risked unrelated
  side effects.
- Harness design note: `new_scratch_repo()` registers each scratch root via a manifest **file**
  (`SCRATCH_MANIFEST`) rather than an in-memory bash array, because the function is invoked via
  command substitution (`proj="$(new_scratch_repo)"`), which runs in a subshell — an array append
  there would never be visible to the parent script's `trap cleanup EXIT`. This was caught during
  Phase 5 execution (an earlier array-based draft silently leaked scratch directories under
  `/tmp`) and fixed before the harness was considered complete; the leaked directories from that
  draft run were manually removed and the fix was re-verified to leave zero scratch directories
  behind.

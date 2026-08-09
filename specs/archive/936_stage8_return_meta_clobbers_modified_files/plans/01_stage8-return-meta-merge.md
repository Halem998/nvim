# Implementation Plan: Task #936

- **Task**: 936 - Stop Stage 8 postflight from clobbering .return-meta.json modified_files
- **Status**: [COMPLETED]
- **Effort**: 2.75 hours
- **Dependencies**: None
- **Research Inputs**: `specs/936_stage8_return_meta_clobbers_modified_files/reports/01_stage8-clobber-fix.md`
- **Artifacts**: plans/01_stage8-return-meta-merge.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, git-staging-scope.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`skill-orchestrate`'s Stage 8 postflight writes `${TASK_DIR}/.return-meta.json` with
`jq -n '{status, metadata}' > file` — a truncating redirect that destroys every field the
implementation agent wrote, including `modified_files`. `commands/orchestrate.md`'s CHECKPOINT 3
runs strictly after Stage 8 and is the only single-task consumer of `modified_files`, so source
files edited outside `specs/` are unconditionally omitted from the completion/pause commit, with
no warning. This plan converts Stage 8's two write sites (clean exit, partial exit) to a
read-modify-write merge using jq's recursive-merge operator `*`, adds `modified_count` accounting
plus the canonical fail-safe warning at CHECKPOINT 3, records the multiple-sequential-writers
invariant in the schema doc, and lands an executable harness that proves a real commit actually
contains a source file outside `specs/`.

### Research Integration

The research report confirmed the defect in the source store (not just the deployed copy),
verified the read/write ordering (all in-loop `orchestrate-recover-outcome.sh` reads precede
Stage 8, so only CHECKPOINT 3 is harmed), and verified the scope boundary: multi-task mode writes
a different file (`specs/.return-meta-multi.json`) and commits inside the per-task loop before
that write, and `skill-orchestrate-hard`'s own Stage 8 contains no `.return-meta.json` write at
all. Both are out of scope and MUST NOT be modified. The report's Scope A decision (merge, not a
distinct path) and its deep-merge-`metadata` refinement are adopted verbatim as the design.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied in the delegation context; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Stage 8 preserves every `.return-meta.json` field it does not own, on both exit paths.
- CHECKPOINT 3 emits the canonical un-suffixed `git-staging-scope.md` warning when
  `modified_files` yields zero entries.
- `return-metadata-file.md` states the multiple-sequential-writers / no-clobber invariant.
- An executable harness proves a real commit contains a source file outside `specs/`, and proves
  the negative case emits the canonical warning.

**Non-Goals**:
- Changing the `.return-meta.json` path, or introducing a second file (option (ii) — rejected).
- Touching multi-task mode (Stage MT-4 / MT-5) or `skill-orchestrate-hard`.
- Changing the Stage 8 `status` vocabulary (`implemented` / `partial` stay as-is).
- Hardening against a malformed-but-present `.return-meta.json` (separate defect class).
- Editing anything under `.claude/` — that tree is a gitignored, disposable deploy artifact.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Edit lands in `.claude/` instead of `agent-system/extensions/core/` | H | M | Every phase's file list is absolute-pathed under `agent-system/extensions/core/`; Phase 6 greps for accidental `.claude/` edits in `git status --short` |
| The "do not correct back to `completed`" prose note gets dropped while rewriting Stage 8 | M | M | Phase 1 verification greps for that sentence explicitly after the edit |
| Verification tests a re-typed copy of the snippet rather than the shipped one | H | M | Harness EXTRACTS the fenced bash blocks from the source-store markdown at runtime and executes them; it never inlines its own copy |
| Harness writes into the real repo working tree / index | H | L | Harness builds a throwaway `mktemp -d` git repo and `trap`-removes it; mirrors `specs/902_.../tests/test-self-modifying-gate.sh` |
| A second, differently-worded warning convention gets introduced | M | L | Phase 2 copies the string byte-for-byte from `git-staging-scope.md`; Phase 4 asserts equality against the string extracted from that standard |
| Task-number citations leak into files outside `specs/**` | M | M | Phase 6 runs an explicit grep gate over the four edited deliverable files |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2 |
| 3 | 5 | 4 |
| 4 | 6 | 1, 2, 3, 5 |

Phases within the same wave can execute in parallel. Phases 1, 2, and 3 touch three disjoint
files and share no state.

---

### Phase 1: Stage 8 merge fix [COMPLETED]

**Goal**: Both Stage 8 `.return-meta.json` writes become read-modify-write merges that preserve
every field they do not own.

**Tasks**:
- [ ] Locate the two fenced `bash` blocks under the `### Stage 8: Postflight` heading in
      `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — identified by
      `--arg status "implemented"` (clean exit) and `--arg status "partial"` (partial exit).
      Anchor on those quoted strings, never on line numbers.
- [ ] Replace each `jq -n ... > "${TASK_DIR}/.return-meta.json"` with the merge form:
      read the existing file (`cat ... 2>/dev/null || echo '{}'`), pipe into
      `jq '. * { "status": $status, "metadata": { "cycles_used": $cycles, "final_state": $final_state } }'`
      writing to a `mktemp` temp file, then `&& mv "$tmp_meta" "$meta_file"`. Keep
      `mkdir -p "${TASK_DIR}/summaries"` and the `--arg`/`--argjson` bindings unchanged.
- [ ] Add a one-line comment inside each block naming why the merge is required (a later writer
      MUST NOT clobber an earlier writer's fields) — no task-number citation.
- [ ] Confirm the surrounding prose paragraph beginning `Write metadata file.` — including the
      sentence `do not "correct" this value back to` — is left byte-for-byte intact.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: exactly two truncating `> "${TASK_DIR}/.return-meta.json"` redirects exist
in this file, both under `### Stage 8: Postflight`. Confirm at implementation time with
`grep -n 'return-meta.json' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
before editing; if a third site appears, stop and re-scope rather than silently fixing two of
three.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - both Stage 8 write blocks

**Verification**:
- `grep -c 'jq -n' <file>` under the Stage 8 region returns 0 for the `.return-meta.json` writes.
- `grep -c 'mv "$tmp_meta"' <file>` returns 2.
- `grep -q 'do not "correct" this value back to' <file>` succeeds.
- Extract each edited block and run it in a scratch dir against a fixture
  `.return-meta.json` containing `modified_files`, `completion_data`, and
  `metadata.agent_type`; assert with `jq` that all three survive and that `status` and
  `metadata.cycles_used` were updated.
- `grep -n 'return-meta-multi\|Stage MT-' <file>` shows no diff in those regions
  (`git diff` touches only the Stage 8 hunk).

---

### Phase 2: CHECKPOINT 3 fail-safe warning [COMPLETED]

**Goal**: The single-task staging site counts `modified_files` entries and emits the canonical
un-suffixed warning when the count is zero.

**Tasks**:
- [ ] Locate the fenced `bash` block under `### CHECKPOINT 3: COMMIT` in
      `agent-system/extensions/core/commands/orchestrate.md`, identified by
      `stage_paths=("${task_dir}/"` and `jq -r '.modified_files[]? // empty'`.
- [ ] Add `modified_count=0` before the `while` loop and increment it inside the loop body,
      matching the shape already proven at the multi-task per-task site.
- [ ] Add the `if [ "$modified_count" -eq 0 ]` branch echoing to `>&2` the wording copied
      byte-for-byte from the `## Fail-Safe Direction` section of
      `agent-system/extensions/core/context/standards/git-staging-scope.md`. Use the
      **un-suffixed** form (no `for task #{task_num}`) — the suffixed variant is reserved for
      the multi-task site by that standard's own text.
- [ ] Add a short prose sentence above the block noting the warning is the canonical wording
      from the staging-scope standard, so a future editor does not invent a second convention.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/commands/orchestrate.md` - CHECKPOINT 3 staging block

**Verification**:
- `grep -c 'modified_count' <file>` returns at least 3 (init, increment, test).
- The echoed string, extracted from `orchestrate.md`, compares byte-equal to the string extracted
  from `git-staging-scope.md`'s `## Fail-Safe Direction` fenced block.
- `grep -q 'for task #' ` against the new branch returns nothing (no suffixed variant here).
- Extract and execute the edited block against a `.return-meta.json` with no `modified_files`;
  assert the warning appears on stderr and `stage_paths` still contains the three fixed paths.

---

### Phase 3: Record the multi-writer invariant [COMPLETED]

**Goal**: The schema doc states that `.return-meta.json` has multiple sequential writers per
orchestrate run and that later writers MUST NOT clobber earlier writers' fields.

**Tasks**:
- [ ] Add a `### Multiple Sequential Writers` subsection to
      `agent-system/extensions/core/context/formats/return-metadata-file.md`, placed immediately
      after the `## Schema` section and before `## Field Specifications`.
- [ ] State: the file may be written more than once within a single orchestrate invocation (an
      implementation agent writes the rich object, then the orchestrator skill's own postflight
      writes again to update `status`/`metadata`); any later writer MUST merge onto the existing
      file (read-modify-write) rather than overwrite wholesale, touching only fields it owns; and
      `modified_files`, `completion_data`, `memory_candidates`, `reflection`, and `artifacts` are
      producer-owned and MUST survive a later writer's update untouched.
- [ ] Add a one-line cross-reference from `git-staging-scope.md`'s `## Related Documentation`
      section (or nearest equivalent) back to that new subsection, closing the loop for a reader
      arriving from the staging-contract side.
- [ ] Record the Scope C decision as **yes, added** — the absence of this rule is the root
      enabler of the defect. No task-number citations in either file.

**Timing**: 0.4 hours

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - new subsection
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - one cross-reference line

**Verification**:
- `grep -q 'Multiple Sequential Writers' return-metadata-file.md` succeeds and the heading sits
  between `## Schema` and `## Field Specifications` (check with `grep -n` ordering).
- All five producer-owned field names appear in the new subsection.
- `grep -q 'Multiple Sequential Writers' git-staging-scope.md` succeeds.
- No task-number pattern (`task [0-9]`, `tasks [0-9]`) in either file's diff.

---

### Phase 4: Write the executable verification harness [COMPLETED]

**Goal**: A self-contained harness exists at
`specs/936_stage8_return_meta_clobbers_modified_files/tests/test-return-meta-merge.sh` that
executes the shipped snippets and asserts on a real git commit.

**Tasks**:
- [ ] Create the harness with `set -u`, `PASS`/`FAIL` counters, and a `trap`-based cleanup of
      every `mktemp -d` scratch root, mirroring the conventions in
      `specs/902_self_modification_hazard_gate/tests/test-self-modifying-gate.sh`.
- [ ] Implement `extract_block <markdown_file> <marker_string>`: scan fenced ```bash blocks and
      print the first block containing the marker. The harness MUST execute extracted blocks, not
      re-typed copies — this is what binds the test to the shipped text.
- [ ] Build a scratch git repo: `git init`, `git config user.email/user.name`, an initial commit,
      `specs/936_.../` task dir, `specs/TODO.md`, `specs/state.json`, and a source file **outside**
      `specs/` (e.g. `lua/harness_probe.lua`) that is modified but uncommitted.
- [ ] Copy `agent-system/extensions/core/scripts/git-commit-scoped.sh` (and any helper it sources,
      e.g. `task-lock.sh`, `deploy-root-guard.sh`) into the scratch tree at the `.claude/scripts/`
      path the extracted CHECKPOINT 3 block expects, so the real committer runs.
- [ ] **Positive case**: write a fixture `.return-meta.json` containing
      `modified_files: ["lua/harness_probe.lua"]`, `completion_data`, `memory_candidates`, and
      `metadata.agent_type`; run the extracted Stage 8 clean-exit block; then run the extracted
      CHECKPOINT 3 block; then invoke `git-commit-scoped.sh` with the resulting `stage_paths`;
      then assert `git show --name-only HEAD` **contains** `lua/harness_probe.lua`. Also assert
      the merge preserved `completion_data`, `memory_candidates`, and `metadata.agent_type`, and
      that `status` is `implemented`.
- [ ] **Partial-exit case**: repeat the positive case against the extracted Stage 8 partial-exit
      block; assert `status` is `partial` and `modified_files` still survives.
- [ ] **Negative case**: write a fixture `.return-meta.json` with no `modified_files`; run the
      extracted CHECKPOINT 3 block capturing stderr; assert stderr contains the canonical warning
      string extracted from `git-staging-scope.md`'s `## Fail-Safe Direction` block, and that the
      commit contains only task-directory / `specs/` paths.
- [ ] **Regression guard**: assert `grep -c 'jq -n' ` over the Stage 8 region of `SKILL.md` finds
      no truncating `.return-meta.json` write, so a future revert is caught even if the behavioral
      cases were to be skipped.
- [ ] `chmod +x` the harness; exit non-zero when `FAIL > 0`.

**Timing**: 0.75 hours

**Depends on**: 1, 2

**Verification Tier**: interface

**Scope Hypothesis**: `git-commit-scoped.sh` is self-contained apart from `task-lock.sh` and
`deploy-root-guard.sh`. Confirm at implementation time by grepping the script for `source`/`bash
.*\.sh` invocations and copying whatever it actually needs; do not assume the two named helpers
are the complete set.

**Files to modify**:
- `specs/936_stage8_return_meta_clobbers_modified_files/tests/test-return-meta-merge.sh` - new

**Verification**:
- `bash -n` parses the harness cleanly.
- The harness file exists, is executable, and is non-empty.
- (Execution is Phase 5 — this phase only proves the harness is well-formed.)

---

### Phase 5: Run the harness and meet the verification bar [COMPLETED]

**Goal**: The harness passes, with a real commit asserted via `git show --name-only`, plus the
negative case.

**Tasks**:
- [ ] Run `bash specs/936_stage8_return_meta_clobbers_modified_files/tests/test-return-meta-merge.sh`
      and capture full output.
- [ ] Confirm the positive case's asserted commit SHA is real: the harness must print the SHA and
      the `git show --name-only` output for it, so the evidence is inspectable in the transcript,
      not merely a PASS line.
- [ ] Confirm the negative case's captured stderr line is reproduced in the transcript.
- [ ] If any case fails, fix the underlying source-store edit from Phase 1 or Phase 2 (never the
      assertion) and re-run. A weakened assertion is not a fix.
- [ ] Confirm the repository's real working tree is unchanged by the run
      (`git status --short` before and after are identical apart from intended edits) and no
      scratch dir survives.

**Timing**: 0.4 hours

**Depends on**: 4

**Verification Tier**: full

**Files to modify**:
- (none — execution phase; harness fixes, if needed, land back in Phase 4's file)

**Verification**:
- Harness exits 0 with `FAIL=0`.
- Transcript shows a real commit SHA and its `git show --name-only` output containing the
  outside-`specs/` source file.
- Transcript shows the canonical warning string for the zero-`modified_files` case.
- Both Stage 8 exit paths (clean and partial) covered.

---

### Phase 6: Consistency gates and deploy note [COMPLETED]

**Goal**: All edits are in the source store, carry no task-number citations, and the deployed
copy is reconciled or explicitly noted as pending.

**Tasks**:
- [ ] `git status --short` — confirm every modified file is under `agent-system/extensions/core/`
      or `specs/936_.../`; confirm zero `.claude/` paths appear.
- [ ] Grep the four edited deliverable files for task-number citation patterns
      (`task [0-9]`, `tasks [0-9]`, `(task [0-9]`) — must return nothing.
- [ ] Run `bash agent-system/extensions/core/scripts/check-extension-docs.sh` if it applies to
      core; treat a pre-existing unrelated failure as non-blocking but report it.
- [ ] Reconcile the deployed copy: either regenerate `.claude/` from the source store via the
      sanctioned deploy path, or record explicitly in the summary that the fix takes effect on the
      next extension sync. Never hand-edit `.claude/`.
- [ ] Write the execution summary to `specs/936_.../summaries/01_*-summary.md` recording the three
      scope decisions (A: merge; B: un-suffixed canonical wording; C: yes, rule added).

**Timing**: 0.2 hours

**Depends on**: 1, 2, 3, 5

**Verification Tier**: full

**Files to modify**:
- `specs/936_stage8_return_meta_clobbers_modified_files/summaries/01_stage8-merge-summary.md` - new

**Verification**:
- No `.claude/` path in `git status --short`.
- Task-number grep over the four deliverable files returns nothing.
- Summary file exists and names all three decisions.

---

## Testing & Validation

- [ ] Positive: a real commit produced by the real `git-commit-scoped.sh`, asserted with
      `git show --name-only`, contains a source file outside `specs/`.
- [ ] Negative: a zero-`modified_files` metadata file produces the canonical un-suffixed warning
      on stderr.
- [ ] Merge preserves `modified_files`, `completion_data`, `memory_candidates`, `reflection`,
      `artifacts`, and `metadata.agent_type` across Stage 8.
- [ ] Both Stage 8 exit paths (clean → `implemented`, partial → `partial`) covered.
- [ ] Regression guard fires if a truncating `jq -n` write returns to Stage 8.
- [ ] Multi-task blocks (`Stage MT-4`, `Stage MT-5`) and `skill-orchestrate-hard` are untouched
      in the diff.
- [ ] No `.claude/` file edited; no task-number citation outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage 8 merge fix)
- `agent-system/extensions/core/commands/orchestrate.md` (CHECKPOINT 3 warning)
- `agent-system/extensions/core/context/formats/return-metadata-file.md` (multi-writer rule)
- `agent-system/extensions/core/context/standards/git-staging-scope.md` (cross-reference)
- `specs/936_stage8_return_meta_clobbers_modified_files/tests/test-return-meta-merge.sh`
- `specs/936_stage8_return_meta_clobbers_modified_files/summaries/01_stage8-merge-summary.md`

## Rollback/Contingency

All changes are confined to four markdown files in the source store plus two new files under
`specs/936_.../`. Revert with `git checkout HEAD -- agent-system/extensions/core/` and delete the
two new spec files; the `.claude/` deploy tree is disposable and regenerates from the source
store, so no deploy-side rollback is required. If the harness proves the merge form is wrong for
some path not anticipated here, the fallback is the narrower two-assignment form
(`jq '.status = $status | .metadata.cycles_used = $cycles | .metadata.final_state = $final_state'`),
which preserves top-level fields but not `metadata` sub-fields — strictly worse, but still fixes
the reported defect.

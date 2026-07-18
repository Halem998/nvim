# Implementation Plan: Back-port review-2026-07-16 tooling-defect fixes into core extension source

- **Task**: 890 - Back-port review-2026-07-16 tooling-defect fixes into core extension source
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_backport-verification.md
- **Artifacts**: plans/01_backport-defect-fixes.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Back-port five already-completed, already-verified tooling-defect fixes (provenance: review
review-2026-07-16, core extension) from a downstream project's disposable, git-ignored deploy
tree (`/home/benjamin/Projects/Logos/Hardware/.claude/`) into the agent-system SOURCE store
(`~/.config/nvim/agent-system/extensions/core/`) so the fixes survive the next `.claude/`
regeneration by the Neovim extension loader. This is a mechanical apply-then-verify operation
across six source files. The one non-mechanical hazard — confirmed by research — is that the
finished `generate-task-order.sh` in the deploy tree is stale and is missing the
`deploy-root-guard.sh` sourcing line present in current source; that file MUST be a targeted
edit (intended hunk only), never a whole-file copy. Definition of done: all six source files
carry the intended change, the `deploy-root-guard.sh` sourcing is preserved, every fix is
verified in the source context, and no `.claude/**` deploy file and no unrelated source file is
touched.

### Research Integration

The plan is built directly on `reports/01_backport-verification.md`, which:
- Verified all six destination paths and all five finished source-of-truth files exist with the
  expected line counts.
- Confirmed three of the four modified files (`roadmap-integration.sh`, `review.md`,
  `task-order-format.md`) have clean, single-purpose, additive diffs.
- Found the critical drift in `generate-task-order.sh` (missing `deploy-root-guard.sh` sourcing)
  and mandated a targeted-edit-only approach for that one file.
- Determined the exact `merge-sources/settings-hooks.json` PostToolUse entry to add (a NEW,
  standalone `Write|Edit` matcher block, not a merge into any existing block) and confirmed
  `manifest.json`'s `provides.hooks` already lists the new hook (no manifest edit needed).
- Specified the per-fix verification procedure reproduced in each phase below.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md context was provided to this planning run; no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Apply the intended fix for each of Defects 1-5 into the correct `agent-system/extensions/core/`
  source file, using targeted edits sourced from a diff review (never blind whole-file copies).
- Preserve the `deploy-root-guard.sh` sourcing line in `generate-task-order.sh`.
- Make the new advisory hook `validate-no-task-references.sh` executable (`chmod +x`) and register
  it via a new standalone `PostToolUse` `Write|Edit` block in `merge-sources/settings-hooks.json`.
- Verify each fix in the source context per the research report's procedure.

**Non-Goals**:
- Touching `rules/no-task-references-in-deliverables.md` (already byte-identical in source).
- Touching `root-files/settings.json` (out of scope; the deploy tree's stale `events-log-artifact.sh`
  omission is not this task's concern).
- Editing `manifest.json` (`provides.hooks` already lists the new hook).
- Back-porting per-repo data such as `active_topics` in any project's `state.json`.
- Editing anything under `.claude/**` (the disposable deploy tree).
- Redeploying affected projects via `<leader>al` (a follow-on user action, not this task).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Whole-file copy of `generate-task-order.sh` silently drops the `deploy-root-guard.sh` sourcing line | H | M | Apply ONLY the Defect-4 `undeclared_topics` hunk via targeted edit; post-edit assert `grep -n "deploy-root-guard" scripts/generate-task-order.sh` still matches (Phase 3) |
| Copying the deploy tree's full `PostToolUse` array into `settings-hooks.json` drops `events-log-artifact.sh` wiring (which lives in the out-of-scope `root-files/settings.json`) | M | M | Add ONLY the single new `validate-no-task-references.sh` `Write|Edit` block, exactly as specified in the report; do not use the deploy tree's array as a template (Phase 4) |
| A task-number citation leaks into a deliverable file outside `specs/**` | M | L | Use durable anchors (review-2026-07-16, core extension, defect descriptions) in all comments/prose; the very hook being installed enforces this going forward |
| New hook not marked executable, so it silently fails to fire once deployed | M | L | `chmod +x` immediately after creating the file; verify the `-x` bit and a live non-blocking invocation (Phase 4) |
| Editing a `.claude/**` deploy file by mistake instead of the source store | H | L | Every phase names the absolute `agent-system/extensions/core/` target; final cross-cutting phase asserts no `.claude/**` path was modified (Phase 5) |
| Deploy tree redeployed before back-port lands, losing the fixes | H | L | Non-deferrable same-session execution; this is the task's stated urgency |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 4 | -- |
| 2 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 1-4 each own a disjoint set of source
files (no shared file, no ordering dependency) and may be applied in any order or in parallel;
Phase 5 is a cross-cutting verification gate that depends on all four apply phases.

### Phase 1: Defects 1 & 3 — roadmap-integration.sh (argv overflow + table-format annotations) [COMPLETED]

**Goal**: Apply both the argv-length-overflow fix (Defect 1, both call sites) and the
table-format annotations-matcher fix (Defect 3) to
`agent-system/extensions/core/scripts/roadmap-integration.sh`, and verify both in the source
context.

**Tasks**:
- [x] `diff -u agent-system/extensions/core/scripts/roadmap-integration.sh /home/benjamin/Projects/Logos/Hardware/.claude/scripts/roadmap-integration.sh` and review the full unified diff before applying. *(completed)*
- [x] Confirm neither version sources `deploy-root-guard.sh` (research: absent in both), so this file has no drift hazard and its diff may be applied wholesale or hunk-by-hunk with equal safety. *(completed: grep confirmed absent in both, exit 1)*
- [x] Apply Defect 1, call site A (~line 111-113): replace the `ROADMAP_CONTENT=$(cat ...)` + argv-pass with passing `$ROADMAP_PATH` as argv and having Python `open(sys.argv[1]).read()` the file directly. *(completed: applied via whole-file copy, no drift)*
- [x] Apply Defect 1, call site B (~line 238 in source): write `ROADMAP_STATE`/`ALL_COMPLETED` to `mktemp` temp files with `printf '%s'`, add a `trap 'rm -f ...' EXIT` cleanup, and have the Python heredoc read them via `json.load(open(sys.argv[N]))` instead of `json.loads(sys.argv[N])`. *(completed)*
- [x] Apply Defect 3: replace the fixed 3-column regex with the generic `^\|(.*)\|\s*$` + `.split('|')` parse; switch separator detection to `^:?-+:?$` (any width); switch header detection to the next-line-is-separator lookahead; add the `find_match()` helper and the new additive loop over `status_tables` gated by `STATUS_ALLOWLIST_RE = r'\b(complete|resolved|done)\b'`. *(completed)*
- [x] Ensure all in-file comments/prose use durable anchors only (no task numbers). The incidental `"Hardware Port"` column-name example in a comment is a real ROADMAP schema column name, not a project-identifier leak — safe to keep, or generalize the wording (non-blocking). *(completed: kept verbatim per plan guidance, no task-number citations present)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` — apply Defect 1 (both call sites) and Defect 3.

**Verification**:
- Defect 1: construct a `state.json` whose `completed_tasks`/`archived_tasks` serialize to >131072 bytes, run `bash agent-system/extensions/core/scripts/roadmap-integration.sh --roadmap <path> --state <path> --annotate`, and confirm exit code 0 (previously exit 126, "Argument list too long"). `python3` confirmed available.
- Defect 3: run the script against a synthetic 4-5-column table-format `ROADMAP.md` (no checkboxes, ≥1 row whose status column matches `complete|resolved|done` and references a real completed task in a test `state.json`), and confirm `annotation_summary.annotations_made` in stdout is non-zero (previously always 0 for this input shape).

---

### Phase 2: Defect 2 — review.md (silent roadmap-integration guard) [COMPLETED]

**Goal**: Apply the exit-code-capture fix to
`agent-system/extensions/core/commands/review.md` so a non-zero exit from
`roadmap-integration.sh` is no longer swallowed, and verify.

**Tasks**:
- [x] `diff -u agent-system/extensions/core/commands/review.md /home/benjamin/Projects/Logos/Hardware/.claude/commands/review.md` and review (research: clean ~29-line additive diff, no drift). *(completed)*
- [x] Apply Defect 2: initialize `roadmap_exit=0` before the invocation, append `|| roadmap_exit=$?` to the `roadmap_output=$(bash .claude/scripts/roadmap-integration.sh ...)` line, and add the new `elif [[ "$roadmap_exit" -ne 0 ]] || [[ -z "$roadmap_output" ]]` branch that emits a warning and falls back to the same empty-state defaults as the file-missing branch. *(completed: applied via whole-file copy, no drift)*
- [x] Confirm no task-number citations are introduced (durable anchors only). *(completed: the sole "task 796" reference in the file is pre-existing content unrelated to this diff, confirmed via git show HEAD)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/commands/review.md` — capture and check `$?` of the roadmap-integration invocation.

**Verification**:
- Read-through confirming `roadmap_exit=$?` is captured immediately after the invocation and the new `elif` branch checks it; OR extract the documented snippet against a throwaway broken `roadmap-integration.sh` (`exit 1`) and confirm it surfaces the warning rather than silently defaulting `annotations_made=0` with no message.

---

### Phase 3: Defect 4 — generate-task-order.sh (targeted edit) + task-order-format.md doc [NOT STARTED]

**Goal**: Apply the undeclared-topic warning-symmetry fix to
`agent-system/extensions/core/scripts/generate-task-order.sh` via a TARGETED EDIT that preserves
the `deploy-root-guard.sh` sourcing line, and apply the matching documentation to
`agent-system/extensions/core/context/formats/task-order-format.md`.

**CAUTION (critical, from research)**: The finished deploy-tree `generate-task-order.sh` is stale
and does NOT contain `. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1`, which IS present in
current source (added by a later, unrelated core change wiring the guard into all core scripts).
A whole-file copy would silently REGRESS that guard. Apply ONLY the Defect-4 hunk via a targeted
edit — never `cp` this file.

**Tasks**:
- [ ] `diff -u agent-system/extensions/core/scripts/generate-task-order.sh /home/benjamin/Projects/Logos/Hardware/.claude/scripts/generate-task-order.sh` and identify the two changes: the intended Defect-4 `undeclared_topics` block (~line 455-475) AND the spurious removal of the `deploy-root-guard.sh` sourcing line (must NOT be ported).
- [ ] Confirm `grep -n "deploy-root-guard" agent-system/extensions/core/scripts/generate-task-order.sh` matches BEFORE editing (baseline).
- [ ] Apply ONLY the Defect-4 hunk via targeted edit: add `local -a undeclared_topics=()` / `declare -A undeclared_topic_task=()`, populate them in the existing loop that appends unseen topics to `topics_to_render`, and add the block that emits `echo "Warning: topic '$tp' on task ${undeclared_topic_task[$tp]} is not declared in active_topics and will render after curated topics" >&2` for each distinct undeclared topic (symmetric to the existing `Uncategorized` warning).
- [ ] Do NOT remove or alter the `deploy-root-guard.sh` sourcing line.
- [ ] `diff -u` the doc file and apply Defect 4 documentation to `task-order-format.md`: add the "Append-extras behavior" paragraph to step 7 of the algorithm description (undeclared topic rendered as its own appended section in first-encountered-task order, each triggering a one-time stderr warning). Leave the pre-existing unrelated `*Updated 2026-05-15 ...*` line untouched.

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/scripts/generate-task-order.sh` — targeted Defect-4 hunk only; preserve `deploy-root-guard.sh` sourcing.
- `agent-system/extensions/core/context/formats/task-order-format.md` — Defect-4 append-extras documentation.

**Verification**:
- Assert `grep -n "deploy-root-guard" agent-system/extensions/core/scripts/generate-task-order.sh` STILL matches after the edit (guard preserved — the primary drift-regression check).
- Confirm the new `undeclared_topics` warning block is present and syntactically valid (`bash -n scripts/generate-task-order.sh`).
- Read-through confirming the doc paragraph documents the append-extras behavior.

---

### Phase 4: Defect 5 — new advisory hook + settings-hooks.json wiring [NOT STARTED]

**Goal**: Create the new non-blocking advisory hook
`agent-system/extensions/core/hooks/validate-no-task-references.sh` (executable), and register it
via a NEW standalone `PostToolUse` `Write|Edit` block in
`agent-system/extensions/core/merge-sources/settings-hooks.json`.

**Tasks**:
- [ ] Copy `/home/benjamin/Projects/Logos/Hardware/.claude/hooks/validate-no-task-references.sh` (61 lines) into `agent-system/extensions/core/hooks/validate-no-task-references.sh`.
- [ ] `chmod +x agent-system/extensions/core/hooks/validate-no-task-references.sh`.
- [ ] Confirm the hook contains no task-number citations of its own and uses durable anchors (it enforces `rules/no-task-references-in-deliverables.md`).
- [ ] Edit `agent-system/extensions/core/merge-sources/settings-hooks.json`: add a NEW top-level `"PostToolUse"` key (the file currently has only `SessionStart`/`Stop`/`UserPromptSubmit`) containing ONE `Write|Edit` matcher block with a single hook command `bash .claude/hooks/validate-no-task-references.sh 2>/dev/null || echo '{}'` (exact shape in research report Finding 4). Do NOT fold into or copy the deploy tree's full array.
- [ ] Confirm `manifest.json`'s `provides.hooks` already lists `validate-no-task-references.sh` (no manifest edit) and validate the JSON parses (`jq . merge-sources/settings-hooks.json`).

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/hooks/validate-no-task-references.sh` — NEW file, `chmod +x`.
- `agent-system/extensions/core/merge-sources/settings-hooks.json` — new standalone `PostToolUse` `Write|Edit` block.

**Verification**:
- Confirm the `-x` bit: `test -x agent-system/extensions/core/hooks/validate-no-task-references.sh`.
- Invoke the hook directly with a synthetic PostToolUse JSON payload on stdin: (a) `file_path` OUTSIDE `specs/**` containing a "task 42" citation — expect an `additionalContext` reminder and exit 0; (b) `file_path` UNDER `specs/**` with the same text — expect bare `{}`, exit 0, silent. Both must exit 0 (never non-zero/blocking), confirming non-blocking behavior.
- `jq . agent-system/extensions/core/merge-sources/settings-hooks.json` parses and shows the new `PostToolUse` block as a distinct entry.

---

### Phase 5: Cross-cutting verification and location-correctness gate [NOT STARTED]

**Goal**: Confirm all six source files carry the intended change, no `.claude/**` deploy file was
touched, and no task-number citation leaked into any deliverable outside `specs/**`.

**Tasks**:
- [ ] Confirm all six target files under `agent-system/extensions/core/` were modified/created as intended (line-count sanity vs research report: roadmap-integration.sh ~548, review.md ~854, generate-task-order.sh source-count + Defect-4 hunk WITH guard line retained, task-order-format.md ~415, hook 61 lines, settings-hooks.json grown by the new block).
- [ ] Assert no file under `.claude/**` was modified by this task (`git status --short` shows only `agent-system/extensions/core/**` and `specs/890_*` paths).
- [ ] Re-assert `grep -n "deploy-root-guard" agent-system/extensions/core/scripts/generate-task-order.sh` matches (guard preserved).
- [ ] Scan the four non-`specs/**` deliverables touched for task-number citation patterns (the new hook's own pattern is a convenient checker) — confirm durable anchors only.
- [ ] Confirm `manifest.json` unchanged (no accidental edit).

**Timing**: 0.25 hours

**Depends on**: 1, 2, 3, 4

**Files to modify**:
- None (verification-only gate).

**Verification**:
- All six source targets present with intended changes; `deploy-root-guard.sh` sourcing intact; zero `.claude/**` modifications; zero task-number citations outside `specs/**`.

## Testing & Validation

- [ ] Defect 1: `roadmap-integration.sh` with a >131KB payload exits 0 (not 126).
- [ ] Defect 2: `review.md` guard propagates a non-zero exit / surfaces a warning on failure instead of silently defaulting.
- [ ] Defect 3: `annotations_made` is non-zero against a table-format `ROADMAP.md`.
- [ ] Defect 4: `generate-task-order.sh` emits the symmetric undeclared-topic stderr warning; `bash -n` clean; doc paragraph present.
- [ ] Defect 5: hook is `chmod +x`, fires non-blockingly (exit 0, reminder) outside `specs/**`, is silent (bare `{}`, exit 0) inside `specs/**`; `settings-hooks.json` parses with the new standalone `PostToolUse` block.
- [ ] `deploy-root-guard.sh` sourcing preserved in `generate-task-order.sh`.
- [ ] No `.claude/**` file modified; no task-number citation outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/roadmap-integration.sh` (modified)
- `agent-system/extensions/core/commands/review.md` (modified)
- `agent-system/extensions/core/scripts/generate-task-order.sh` (modified, targeted edit)
- `agent-system/extensions/core/context/formats/task-order-format.md` (modified)
- `agent-system/extensions/core/hooks/validate-no-task-references.sh` (new, executable)
- `agent-system/extensions/core/merge-sources/settings-hooks.json` (modified)
- `specs/890_backport_tooling_defect_fixes_into_core_source/summaries/01_backport-defect-fixes-summary.md` (implementation summary)

## Rollback/Contingency

All changes are confined to `agent-system/extensions/core/**` source files and are additive.
If a fix must be reverted, `git checkout -- <path>` the specific source file (after a snapshot if
the tree is dirty, per the No-Destructive-Git rule) — the finished source-of-truth still exists in
the deploy tree at `/home/benjamin/Projects/Logos/Hardware/.claude/` as a re-derivation reference
until the next `<leader>al` redeploy. The new hook file can simply be deleted and its
`settings-hooks.json` block removed to fully back out Defect 5. Because these are source-store
edits, no deployed project is affected until the user redeploys via `<leader>al`.

# Research Report: Task #896

**Task**: 896 - Fix cwd-relative artifact linking in skill-base.sh
**Started**: 2026-07-25T00:00:00Z
**Completed**: 2026-07-25T00:00:00Z
**Effort**: Small (single-function path fix + one CLI flag addition)
**Dependencies**: Task 892 (completed; file-overlap serializer only, not a logical prerequisite)
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/`, `agent-system/extensions/core/skills/`)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md, source-store rule (agent-system/extensions/core/ is source of truth; `.claude/` is a gitignored deploy artifact)

## Executive Summary

- The scope-correction in the task description is accurate: `skill_link_artifacts` is a live function at `agent-system/extensions/core/scripts/skill-base.sh:459` (doc comment `:452-458`), called from `skill-orchestrate`/`skill-orchestrate-hard`. No file needs to be created.
- Confirmed defect: `skill_link_artifacts` (lines 459-481) uses three bare, cwd-relative paths — `specs/state.json` (471, 477), `specs/tmp/state.json` (471, 477), and `bash .claude/scripts/generate-todo.sh` (479) — despite the file already computing a reliable, cwd-independent `SKILL_REPO_ROOT` at line 32 (`$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)`), and already using that anchor correctly elsewhere in the same file (`TASK_DIR_ABS` at line 187, `handoff_path` in `skill_write_orchestrator_handoff` at line 542).
- The task description's original line numbers are stale: `skill_link_artifacts` is no longer at the numbers implied by the defect report, and `update-task-status.sh`'s `PROJECT_ROOT` pattern is at line 44, not line 27 as cited. `generate-todo.sh:28-29` is correct. Corrected references are given below.
- `scripts/reconcile-artifacts.sh` (source: `agent-system/extensions/core/scripts/reconcile-artifacts.sh`) already resolves `PROJECT_ROOT` correctly via `BASH_SOURCE` (lines 22-24) and already `mkdir -p`s its tmp dir (line 127); its only gap relative to the task's ask is that it has no per-task filter — it always iterates every entry in `.active_projects` (loop starts line 79, `jq -r '.active_projects[] | ...'` at line 150). Adding an optional `--task N` filter is a small, additive change.
- Recommended scope: fix path-relativity **only inside `skill_link_artifacts`** (Stage 8), not the rest of `skill-base.sh`. The file has the same bare-`specs/state.json` / bare-`.claude/scripts/*.sh` pattern in `skill_validate_input` (174), `skill_read_artifact_number` (279), `skill_increment_artifact_number` (415/421), `skill_propagate_memory_candidates` (437/445), and the `bash .claude/scripts/{update-task-status,events-append,validate-artifact}.sh` calls (207, 213, 258, 341, 359, 390, 401) — this is a file-wide "Strategy-B/cwd-following" convention, not unique to Stage 8, and the task explicitly says not to refactor the whole file.

## Context & Scope

Verify and fix the reported defect that `skill_link_artifacts` (the function `skill-orchestrate`'s Stage 5 calls to register a produced artifact in `specs/state.json` and regenerate `specs/TODO.md`) depends on the shell's ambient working directory rather than a resolved project root, and that `scripts/reconcile-artifacts.sh` — the only available fallback when `skill_link_artifacts` silently no-ops — has no way to scope its backfill to a single task, so using it as a workaround inflates unrelated tasks' artifact lists.

All edits must target `agent-system/extensions/core/**`; `.claude/**` is a disposable, gitignored deploy artifact regenerated from the source store (confirmed: `.claude/scripts/skill-base.sh` is currently stale relative to the source copy — it is missing `skill_link_artifacts` and `skill_write_orchestrator_handoff` entirely, consistent with the "disposable, regenerated" description and *not* something to hand-edit).

## Findings

### Codebase Patterns

**`skill_link_artifacts` (source of the defect)** — `agent-system/extensions/core/scripts/skill-base.sh:452-481`:

```
452  # Stage 8: Link artifacts to state.json and TODO.md
459  skill_link_artifacts() {
...
466    if [ -n "$artifact_path" ]; then
467      # Step 1: Remove existing artifacts of same type ...
468      jq --arg atype "$artifact_type" \
469        '...' \
471        specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
472      # Step 2: Add new artifact entry
473      jq --arg path "$artifact_path" \
...
477        specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
478      # Regenerate TODO.md from state.json (replaces link-artifact-todo.sh call)
479      bash .claude/scripts/generate-todo.sh || echo "WARNING: generate-todo.sh failed (non-fatal)"
480    fi
481  }
```

All three of `specs/state.json`, `specs/tmp/state.json`, and `.claude/scripts/generate-todo.sh` are bare, cwd-relative. There is no `mkdir -p` for `specs/tmp/` before the jq round-trip on line 471/477.

**The correct pattern already exists in the same file**, just not applied here:

- `SKILL_REPO_ROOT` — `skill-base.sh:32`: `SKILL_REPO_ROOT="${SKILL_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"`, exported at line 33. Comment at lines 25-31 explicitly states the rationale: resolving from `BASH_SOURCE` rather than cwd or `git rev-parse --show-toplevel` "keeps paths built below correct no matter where the caller's shell happens to be."
- `TASK_DIR_ABS` — `skill-base.sh:184-187`: built as `"${SKILL_REPO_ROOT}/${TASK_DIR}"` specifically because (comment, line 184-186) "many existing consumers depend on [`TASK_DIR`'s] relative form; `TASK_DIR_ABS` is the anchor to hand to dispatched agents and to build write destinations from."
- `skill_write_orchestrator_handoff`'s `handoff_path` — `skill-base.sh:538-542`: explicit comment block warns that a bare `specs/...` string "lands wherever the shell's working directory happens to be at call time, which silently strands the handoff outside the task directory," and anchors on `"${SKILL_REPO_ROOT}/specs/${padded_num}_${project_name}/.orchestrator-handoff.json"`.

This is the exact failure mode `skill_link_artifacts` currently exhibits, already diagnosed and fixed once in the same file for a sibling function. `skill_link_artifacts` was evidently never updated to match.

**Sibling scripts' `PROJECT_ROOT` pattern** (cited in the task description, re-verified with corrected line numbers):

- `agent-system/extensions/core/scripts/generate-todo.sh:28-29`:
  ```
  28  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  29  PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
  ```
  (matches the task description's citation of `:28`)
- `agent-system/extensions/core/scripts/update-task-status.sh:43-44` (task description cited `:27`; **stale** — actual is `:43-44`):
  ```
  43  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  44  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
  ```
  `TMP_DIR="$PROJECT_ROOT/specs/tmp"` (line 47) is explicitly `mkdir -p`'d before use at line 342.
- Both scripts additionally source `deploy-root-guard.sh` (`agent-system/extensions/core/scripts/deploy-root-guard.sh`) immediately after computing `PROJECT_ROOT`, which fails loudly if the script is invoked directly from the `agent-system/extensions/` source store (where `../..` would resolve to a bogus root) rather than a deployed `.claude/scripts/` or `.opencode/scripts/` tree. `skill-base.sh` does not source this guard for its own `SKILL_REPO_ROOT` computation — a pre-existing gap orthogonal to this task's scope (it is sourced, not directly executed, and its own header comment at lines 25-26 already documents the "deployed at `<repo-root>/.claude/scripts/skill-base.sh`" assumption), noted here for completeness but out of scope to fix.

**`scripts/reconcile-artifacts.sh`** — `agent-system/extensions/core/scripts/reconcile-artifacts.sh`:

- Already correctly anchored: `SCRIPT_DIR`/`PROJECT_ROOT` computed at lines 22-23, `deploy-root-guard.sh` sourced at line 24, `STATE_FILE="$PROJECT_ROOT/specs/state.json"` at line 25. `mkdir -p "$PROJECT_ROOT/specs/tmp"` already present at line 127 before its own jq round-trip (135-136).
- Usage docstring, lines 9-13: `.claude/scripts/reconcile-artifacts.sh [--dry-run]` — no task filter exists today.
- Argument parsing loop, lines 28-37: any arg that is not `--dry-run` currently causes a hard usage error and `exit 1` (line 33-34) — so an unrecognized `--task N` flag today would abort rather than silently do the wrong thing. Adding the flag is additive and backward compatible.
- Main iteration source, line 150: `jq -r '.active_projects[] | "\(.project_number)|\(.project_name)"' "$STATE_FILE"` — feeds every active task into the `while` loop at line 79, unconditionally.
- Only one call site exists in the whole extension: `agent-system/extensions/core/commands/task.md:438`, inside `/task --sync` step "2.5. Artifact reconciliation," invoked with **no arguments** (`bash .claude/scripts/reconcile-artifacts.sh`). This is a legitimate, intentional repo-wide use (the `/task --sync` reconciliation sweep is explicitly meant to catch drift across the whole repo), so the fix must keep the no-argument, no-filter invocation as the unchanged default behavior — only *add* an opt-in filter, never make filtering the default.

**Call sites of `skill_link_artifacts`** (re-verified; task description's line numbers are stale):

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md:635-636` (task description cited `:441`, restated `:780` — both stale):
  ```
  635    skill_link_artifacts "$task_number" "$handoff_artifact_path" "$handoff_artifact_type" \
  636      "$handoff_artifact_summary" "$field_name" "$next_field"
  ```
  Also referenced descriptively (not a second call site) at line 1066: "Call `skill_link_artifacts` if artifact path is present (same field mapping as Stage 5)."
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md:860-861` (task description cited `:709` — stale):
  ```
  860    skill_link_artifacts "$task_number" "$handoff_artifact_path" "$handoff_artifact_type" \
  861      "$handoff_artifact_summary" "$field_name" "$next_field"
  ```

Neither call site passes any path-related argument beyond `$task_number` and the already-resolved `$handoff_artifact_path` (itself sourced from `.orchestrator-handoff.json`, which — per the `skill_write_orchestrator_handoff` fix already in place — is an absolute, `SKILL_REPO_ROOT`-anchored path). The defect is entirely internal to `skill_link_artifacts`'s own body; no caller-side change is needed.

### External Resources

Not applicable — this is a pure codebase-internal path-resolution defect; no external documentation informs the fix beyond standard Bash `BASH_SOURCE`-anchoring, which the file itself already demonstrates twice.

### Recommendations

**(a) `skill_link_artifacts` path fix — scoped to this function only**, in `agent-system/extensions/core/scripts/skill-base.sh`:

1. Replace `specs/state.json` (lines 471, 477) with `"${SKILL_REPO_ROOT}/specs/state.json"`.
2. Replace `specs/tmp/state.json` (lines 471, 477) with `"${SKILL_REPO_ROOT}/specs/tmp/state.json"`, and add `mkdir -p "${SKILL_REPO_ROOT}/specs/tmp"` before the first jq invocation (mirrors `update-task-status.sh:342` and `reconcile-artifacts.sh:127`, both of which already do this).
3. Replace `bash .claude/scripts/generate-todo.sh` (line 479) with `bash "${SKILL_REPO_ROOT}/.claude/scripts/generate-todo.sh"` — consistent with the file's own header comment (lines 25-26) that `skill-base.sh` is deployed at `<repo-root>/.claude/scripts/skill-base.sh`, and with every existing `source .claude/scripts/skill-base.sh` call site in the SKILL.md files (e.g. `skill-orchestrate-hard/SKILL.md:89`).
4. `SKILL_REPO_ROOT` is already exported (line 33) whenever `skill-base.sh` is sourced, so no new variable needs to be introduced or threaded through — the fix is a pure find-and-replace inside the function body, no signature change, no caller-side change.

**Scope decision (explicit, per the task's request)**: fix only `skill_link_artifacts`. The same bare-`specs/state.json` / bare-`.claude/scripts/*.sh` pattern recurs throughout the rest of `skill-base.sh` (`skill_validate_input:174`, `skill_read_artifact_number:279`, `skill_increment_artifact_number:415,421`, `skill_propagate_memory_candidates:437,445`, and the `bash .claude/scripts/{update-task-status,events-append,validate-artifact}.sh` calls at 207/213/258/341/359/390/401). This is a file-wide convention, not a localized bug — the task description itself calls it "a known Strategy-B/CWD-following pattern in this file" and explicitly forbids a whole-file refactor here. `skill_link_artifacts` is the one function with a *documented, observed* damage incident (the 47-artifact/12-task cross-contamination); the other functions have not been reported as causing damage and changing them is a larger, separately-scoped refactor better tracked as its own follow-up task if desired.

**(b) `reconcile-artifacts.sh` optional task filter**, in `agent-system/extensions/core/scripts/reconcile-artifacts.sh`:

1. Add a `TASK_FILTER=""` variable and extend the argument-parsing loop (lines 28-37) to accept `--task N` (set `TASK_FILTER="$N"`), alongside the existing `--dry-run`. Keep the existing `*)` fallthrough as a hard usage error for genuinely unrecognized args, updating the usage string (line 10, 33) to `[--dry-run] [--task N]`.
2. Scope the main loop (line 79-150) to the filter: either (i) change the source `jq` query at line 150 to `jq -r --argjson n "${TASK_FILTER:-null}" '.active_projects[] | select($n == null or .project_number == $n) | "\(.project_number)|\(.project_name)"'`, or (ii) keep line 150 unchanged and add `[[ -n "$TASK_FILTER" && "$task_num" != "$TASK_FILTER" ]] && continue` immediately after the `[[ -z "$task_num" ]] && continue` guard at line 80. Either is correct; (ii) is a smaller diff and keeps the filter logic co-located with the existing per-task skip logic rather than inside a jq expression.
3. No change to the no-argument default behavior — `task.md:438`'s existing repo-wide `/task --sync` call keeps working byte-for-byte, satisfying "the repo-wide sweep becomes opt-in rather than the only mode" by making the *filtered* mode the new opt-in addition (default stays repo-wide, exactly as the task description phrases it).
4. Update the summary/report echoes (lines 124, 137, 153-158) to optionally note the active filter for clarity when `--task` is used (cosmetic, not required for correctness).

## Decisions

- **Scope**: fix `skill_link_artifacts` only; leave the rest of `skill-base.sh`'s bare-relative-path convention unchanged (explicit per task instruction not to refactor the whole file).
- **Anchor choice**: use the already-exported `SKILL_REPO_ROOT` (not a new variable, not `git rev-parse --show-toplevel`, not a re-derivation) for all three paths inside `skill_link_artifacts`, matching the pattern already used for `TASK_DIR_ABS` (line 187) and the orchestrator handoff path (line 542) in the same file.
- **`generate-todo.sh` target path**: anchor at `${SKILL_REPO_ROOT}/.claude/scripts/generate-todo.sh`, matching the file's own documented deployment location (header comment, lines 25-26) and every `source .claude/scripts/skill-base.sh` call site in the SKILL.md files — not a generic "search both `.claude` and `.opencode`" resolution, since `.opencode` is a separate, independently-deployed system per the CLAUDE.md system-specific naming convention.
- **`reconcile-artifacts.sh` default behavior**: preserve unfiltered/repo-wide as the default with no arguments, to avoid silently changing `task.md:438`'s existing `/task --sync` behavior; the task filter is strictly additive/opt-in.

## Risks & Mitigations

- **Risk**: If `SKILL_REPO_ROOT` were ever unset when `skill_link_artifacts` is called (e.g. a caller invokes the function without having sourced `skill-base.sh` in the same Bash block, per the file's own "SOURCING SEMANTICS" note at lines 4-7). **Mitigation**: this is already a precondition for every other function in the file (all of them assume `skill-base.sh` was sourced in the same invocation); no new precondition is introduced, and both existing call sites (`skill-orchestrate/SKILL.md`, `skill-orchestrate-hard/SKILL.md`) already `source .claude/scripts/skill-base.sh` earlier in the same script before reaching Stage 5.
- **Risk**: Regression to the two-step jq pattern (Issue #1132 `!=`-escaping workaround, documented inline at line 458) if the path substitution is done carelessly. **Mitigation**: the fix only touches the *file path* operands of the existing `jq ... > ... && mv ...` idiom; the jq filter expressions themselves (lines 469-470, 476) are untouched.
- **Risk**: `reconcile-artifacts.sh`'s filter could silently no-op if given a task number with no matching directory. **Mitigation**: this already happens today for unfiltered runs (line 89-92, "No directory found for this task — skip silently") — behavior is consistent, not a new class of silence introduced by the filter.

## Context Extension Recommendations

None — this is a narrowly-scoped internal bug fix; no new context-file documentation gap was identified. The existing `SKILL_REPO_ROOT` pattern and its rationale are already well-documented inline in `skill-base.sh` itself (lines 24-33, 538-542), which is sufficient for a future maintainer to find and replicate.

## Appendix

**Files read**:
- `agent-system/extensions/core/scripts/skill-base.sh` (full file, 603 lines)
- `agent-system/extensions/core/scripts/reconcile-artifacts.sh` (full file, 161 lines)
- `agent-system/extensions/core/scripts/generate-todo.sh` (lines 1-40)
- `agent-system/extensions/core/scripts/update-task-status.sh` (lines 1-50, 340-360)
- `agent-system/extensions/core/scripts/deploy-root-guard.sh` (full file)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (grep + lines 615-645, 1060-1070)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (grep + lines 845-865)
- `agent-system/extensions/core/commands/task.md` (lines 420-445)

**Searches run**:
- `find . -name "skill-base.sh"` / `find . -name "reconcile-artifacts.sh"` — confirmed no `link-artifacts.sh` exists and located the source-store, `.claude`, and `.opencode` copies of both scripts.
- `grep -n "specs/state.json\|specs/tmp\|SKILL_REPO_ROOT\|\.claude/scripts" skill-base.sh` — enumerated every bare-relative-path use in the file.
- `grep -n "PROJECT_ROOT\|SCRIPT_DIR" generate-todo.sh update-task-status.sh` — verified the "correct pattern" citation and corrected its line numbers.
- `grep -n "skill_link_artifacts\|link-artifacts" skill-orchestrate/SKILL.md skill-orchestrate-hard/SKILL.md` — located and corrected the two call-site line numbers.
- `grep -rn "reconcile-artifacts" agent-system/extensions/core/` — confirmed the single call site (`task.md:438`) and its no-argument, repo-wide invocation.
- `diff` of deployed `.claude/scripts/skill-base.sh` against the source-store copy — confirmed the deployed tree is currently stale (missing `skill_link_artifacts` and `skill_write_orchestrator_handoff` entirely), consistent with the "disposable, gitignored, regenerated" source-store rule; no action needed on the deployed copy.

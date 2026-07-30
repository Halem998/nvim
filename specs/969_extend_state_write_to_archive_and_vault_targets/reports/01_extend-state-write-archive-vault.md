# Research Report: extend_state_write_to_archive_and_vault_targets

**Task**: extend_state_write_to_archive_and_vault_targets
**Started**: 2026-07-29
**Completed**: 2026-07-29
**Effort**: medium (multi-file, one nontrivial design fork)
**Dependencies**: None
**Sources/Inputs**: Codebase read (source store under `agent-system/extensions/core/`), git log
**Artifacts**: this report
**Standards**: report-format.md, return-metadata-file.md

## Executive Summary

- The declared `file_scope` (state-write.sh, its concurrency test, task.md, todo.md,
  skill-todo/SKILL.md, task-lock.md) accounts for **exactly 3 concrete hand-rolled write sites**
  plus **3 prose-only sites with no literal code shown**. All 3 concrete sites target
  `specs/archive/state.json`; none target a vault-root `state.json` directly (vault-root
  `state.json` is produced by an `mv`, not a jq write).
- **One genuine design fork the planner must resolve, not just "add `--state-file`"**: the vault
  archive-reinit site is a *fresh-file create* (`jq -n '{...}' > archive/state.json`, no existing
  file to transform), which does not fit `state-write.sh`'s current `jq $FILTER $EXISTING_FILE`
  contract at all. A plain `--state-file` flag alone cannot cover it.
- **Two scripts outside the declared `file_scope` — `scripts/archive-task.sh` and
  `scripts/vault-operation.sh` — already contain exactly the anti-pattern this task exists to
  fix**, including one write to the *live* `specs/state.json` with zero mutex protection at all
  (worse than any site the task description names). Both appear to be currently uncalled by any
  command/skill (likely dead/orphaned, deployed via manifest.json but unreferenced).
- `context/patterns/task-lock.md`'s own "Known residual surface" note (in file_scope) is now
  **stale**: it claims `task.md` has 5 unconverted sites and `todo.md` has 3; the repo currently
  has only 2 (task.md) and 1 concrete + 1 prose (todo.md), all archive-only — the live-state.json
  sites it refers to were evidently converted by separate, already-completed work. This note needs
  correcting regardless of what else this task does.
- The verification bar's literal "repo-wide grep, zero hits outside `state-write.sh`" is **not
  achievable within the declared `file_scope`** — it will also catch `context/patterns/
  jq-escaping-workarounds.md`'s two illustrative examples, `commands/review.md`'s two
  `specs/reviews/state.json` sites (a different file), and a large, already-documented,
  pre-existing body of un-converted `specs/state.json` writes across every non-core extension
  domain (founder, web, lean, present, epidemiology, cslib — roughly 100+ sites). None of these
  are new problems this task created; they need to be explicitly named as reported exclusions
  (or the grep scoped to `agent-system/extensions/core/**`), never silently passed.

## Context & Scope

Task 969 asks to generalize `state-write.sh` (currently hardcoded to
`$PROJECT_ROOT/specs/state.json`) so it can also serve as the mutex-guarded writer for
`specs/archive/state.json` and vault-root `state.json`, then convert the residual hand-rolled
sites in the declared `file_scope` to use it.

## Findings

### Current `state-write.sh` contract (must be preserved byte-for-byte for existing callers)

`agent-system/extensions/core/scripts/state-write.sh`:
- `STATE_FILE="$PROJECT_ROOT/specs/state.json"`, hardcoded, no override today.
- Usage: `state-write.sh <jq-filter> --session-id SID [--arg ...] [--argjson ...] [--regen-todo] [--dry-run]`.
- Sequence: parse args -> (dry-run: validate filter, exit) -> acquire `specs/.scope-lock` (fail
  closed, honors `SCOPE_MUTEX_HELD=1` guest mode) -> private `mktemp` under `specs/tmp/` ->
  `jq $FILTER $STATE_FILE > $STAGE` -> `jq empty` validate -> `mv` into place -> release mutex ->
  optional `generate-todo.sh` (outside the critical section) -> exit.
- Exit codes: 0 success/dry-run-ok, 1 usage error, 2 mutex-acquire ABORT (fail closed), 3 jq
  transform failed, 4 jq-empty validation failed.
- **Precondition**: `[ ! -f "$STATE_FILE" ]` is a hard error — the script assumes the target file
  already exists and only ever transforms it. There is no "create fresh" mode.
- 34 existing call sites reference `state-write.sh` across core commands/skills/scripts/docs (see
  full list gathered during research — commands/implement.md, commands/review.md, commands/
  task.md, commands/todo.md, scripts/archive-task.sh, scripts/manage-topics.sh, scripts/
  orchestrate-predispatch-review.sh, scripts/orchestrator-postflight.sh, scripts/
  reconcile-artifacts.sh, scripts/reconcile-task-status.sh, scripts/skill-base.sh,
  scripts/update-task-status.sh, and 9 skill SKILL.md files). None pass any file-targeting flag
  today, so a `--state-file` addition with a default preserves every one of them unchanged.

### The mutex is a single, unparameterized global (`specs/.scope-lock`) — recommend keeping it single, not per-file

`task-lock.sh`'s `scope-acquire`/`scope-release` (exposed via `acquire_named_mutex`/
`release_named_mutex`, mutex dir `.scope-lock`) take only a `session_id` and an optional
`stale_sec` — they know nothing about which file is being protected. This is exactly what makes a
single-lock design trivial: `state-write.sh` would keep calling `task-lock.sh scope-acquire`/
`scope-release` completely unchanged; only its own `STATE_FILE` variable becomes parameterized by
a new `--state-file <path>` flag (default unchanged: `$PROJECT_ROOT/specs/state.json`).

**Why single lock, not per-file, is the right call for this codebase** (the task description
flags this explicitly as a non-implicit decision): the `--recover` flow does an archive removal
followed immediately by a live-state insert in the same logical operation
(`commands/task.md`, recover mode); `--abandon` does the mirror image (live-state extract, archive
add, live-state remove). If archive and live state used *different* named mutexes, two concurrent
sessions doing opposite operations (one recovering, one abandoning) could acquire in opposite
order and deadlock (classic ABBA). A single lock name for every state-file target makes this
impossible by construction — each acquire/release pair is sequential, never nested, regardless of
which file it targets. The cost (all state-file writers serialize against each other, including
archive/vault writers against live-state writers) is negligible: these operations are rare,
human/agent-paced, and already serialize against each other today in practice.

### `--regen-todo` must be refused for non-default `--state-file` (WORK item 4)

`generate-todo.sh` regenerates `specs/TODO.md` from `specs/state.json` unconditionally. Running it
after a write to `specs/archive/state.json` or a vault-root `state.json` would not reflect what was
actually just written and could mislead a reader into thinking TODO.md was updated for that
change. Recommend: if `--regen-todo` is passed together with a `--state-file` naming anything
other than the default path, `state-write.sh` should exit with a usage error (loud, not silent)
rather than silently regenerating from the wrong source.

### Design fork: the vault archive-reinit site is a fresh-create, not a transform

`skills/skill-todo/SKILL.md`, Stage 9.2 "CreateVault" (~line 674-684):
```bash
# Reinitialize empty specs/archive/ with fresh state.json. Deliberately left hand-rolled:
# state-write.sh targets specs/state.json only, never specs/archive/state.json.
mkdir -p "specs/archive"
jq -n '{
  "_comment": "Archive state for completed and abandoned tasks",
  "completed_projects": [],
  "archived_at": "'"$current_timestamp"'"
}' > "specs/archive/state.json"
```
This runs immediately after the OLD `specs/archive/` (with its `state.json`) has just been `mv`'d
into the vault directory, so there is no pre-existing `specs/archive/state.json` left to read and
transform — `state-write.sh`'s `jq $FILTER $STATE_FILE` model requires an existing file and cannot
express `jq -n` (null-input, construct-from-scratch). A bare `--state-file` flag does not cover
this call by itself. Two ways to close it, for the planner to choose between:
1. Add a `--init`/`--no-input` mode to `state-write.sh` that runs `jq -n $FILTER` (skipping the
   existence precondition), still under the same acquire -> mktemp -> validate -> mv -> release
   sequence.
2. Leave this one call hand-rolled but wrap it in explicit `task-lock.sh scope-acquire`/
   `scope-release` calls (the same primitive `state-write.sh` itself uses internally), so it is at
   least now protected even though it does not go through `state-write.sh`'s CLI surface.

Every OTHER residual site found (below) IS a genuine read-modify-write against an existing file
and fits the plain `--state-file` model without modification.

### Concrete residual sites in the declared `file_scope` (verified by direct read, not grep alone)

| # | File | Site | Shape |
|---|------|------|-------|
| 1 | `commands/task.md` | Recover mode, "Step 1: Remove from archive" (~line 305-312) | `jq 'del(...)' specs/archive/state.json > specs/tmp/archive.json && mv ...` — existing-file transform, fits `--state-file` directly. Same block's Step 2 already calls `state-write.sh` for the live-state insert — this is the literal "interleaved block" the task description names. |
| 2 | `commands/task.md` | Abandon mode, "Step 1: Add to archive" (~line 886-893) | `jq '...' specs/archive/state.json > specs/tmp/archive.json && mv ...` — existing-file transform, fits directly. Step 2 already calls `state-write.sh` for the live-state removal. |
| 3 | `commands/todo.md` | Step 5E.2, "Add entry to archive/state.json" (~line 598-612) | `jq '.completed_projects += [...]' specs/archive/state.json > specs/archive/state.json.tmp && mv ...` — existing-file transform, fits directly. |
| 4 | `skills/skill-todo/SKILL.md` | Stage 9.2 CreateVault archive reinit (~line 674-684) | **Fresh-create, not a transform** — see design fork above. |

Two more sites in scope are **prose-only** (no literal bash/jq shown at all today): `commands/
todo.md` Step 5A ("Update archive/state.json" — completed/archived_projects append, described in
prose only) and `skills/skill-todo/SKILL.md` Stage 10 step 1 (identical prose) and step 8b ("Add
entry to specs/archive/state.json completed_projects array" for TODO.md orphans, prose only). None
of these are caught by a literal grep since no code exists to match — but since the task's WORK
item 3 asks to "replace the mechanism-naming... comments with the real invocation," and these
files are in `file_scope`, it is reasonable (and consistent with the spirit of the task) for the
implementer to also make these prose descriptions concrete `state-write.sh --state-file
specs/archive/state.json ...` invocations rather than leaving them as unspecified prose.

Separately confirmed: Stage 9.3 (RenumberTasks) and 9.4 (ResetState) in `skill-todo/SKILL.md`
**already** call `state-write.sh` correctly for every LIVE `specs/state.json` write in the vault
flow — only the one archive-reinit line (site #4 above) is unconverted there.

### `context/patterns/task-lock.md`'s "Known residual surface" note is stale (in file_scope, needs correcting regardless)

The note (in the "State-Write Convention" section) currently reads: "a re-measured, source-store-
wide grep found 14 `agent-system/extensions/core/` skill files (48 inline write sites total)...
plus two commands carrying 8 further sites (`commands/task.md` 5, `commands/todo.md` 3)." Current
repo state (re-grepped directly) shows `task.md` and `todo.md` have **only the archive-targeted
sites listed above** — 2 and 1 (+2 prose) respectively — with every live-`specs/state.json` site
in both files already routed through `state-write.sh`. Git log confirms a separate, already-merged
effort (commit history shows a distinct completed task converting "the one inline jq writer" and
related phases) closed the rest. This note must be corrected as part of this task since the file
is in `file_scope`; leaving the stale numbers in place would misinform future readers about what
is and isn't converted.

### Two out-of-scope scripts already contain exactly this task's target anti-pattern

Not listed in the declared `file_scope`, but directly relevant and worth flagging to the planner:

- **`scripts/archive-task.sh`** — a single-task archive helper. Its own header comment already
  says: *"Move task entry from state.json active_projects to archive/state.json completed_projects
  (archive/state.json is a DIFFERENT file from specs/state.json -- out of scope for the shared
  state-write.sh conversion; this step's write is unchanged.)"* — i.e. it already names itself as
  exactly the kind of site this task exists to close. Its live-state removal (step B) already
  correctly uses `state-write.sh`.
- **`scripts/vault-operation.sh`** — a full vault-archival helper. Its "Renumber tasks" and "Reset
  state" steps hand-roll **direct writes to the LIVE `specs/state.json`** via
  `jq ... "$state_json" > "${state_json}.tmp" && mv ...` (no mutex acquisition at all) — this is a
  *live-state* write bypassing `state-write.sh` entirely, strictly worse than any archive/vault-only
  site named in the task description.

Both scripts are deployed (present in `manifest.json`'s `provides.scripts` and copied to
`.claude/scripts/`) but a repo-wide grep found **no command or skill file that actually invokes
either one** — the only textual reference to `archive-task.sh` outside itself is an incidental
mention inside a comment in `commands/todo.md` ("following the same self-generating fallback used
elsewhere (`manage-topics.sh` / `archive-task.sh`)"), not a call. They read as orphaned/superseded
by the inline blocks in `task.md`/`todo.md`/`skill-todo/SKILL.md` that do the same work today.
Recommend the planner explicitly decide and record one of: (a) convert both scripts' hand-rolled
sites too, since they are cheap to fix and already deployed (a future caller could invoke them
without anyone noticing the gap), or (b) explicitly document them as known, deliberately
out-of-scope, currently-dead code in the same place `task-lock.md`'s residual-surface note lives —
either way, per the DELIVERABLE RULE, this must be a stated decision, not a silent gap.

### Two more files that will trip the verification bar's literal grep, both outside `file_scope`

- **`context/patterns/jq-escaping-workarounds.md`** — its "Task Recover"/"Task Abandon" example
  sections contain the identical `jq ... specs/archive/state.json > specs/tmp/archive.json && mv
  ...` pattern (illustrative code, matching the same "Deliberately left hand-rolled" comment
  wording found in `task.md`). These are examples, not live-executed code, but a literal grep
  cannot distinguish that.
- **`commands/review.md`** — two sites hand-rolling `specs/reviews/state.json > specs/reviews/
  state.json.tmp && mv ...` (lines ~670-677). This is a genuinely *different* state file (the
  `/review` command's own review-tracking state, unrelated to `active_projects`/archive/vault),
  so it is arguably out of this task's conceptual scope even though it matches the verification
  bar's literal wording ("any remaining state.json-targeted... sequence").

### Pre-existing, already-documented, much larger debt: extension-domain hand-rolled writes

A repo-wide grep for the same pattern across all of `agent-system/extensions/` (not just `core/`)
turns up roughly 100+ sites across `founder/`, `web/`, `lean/`, `present/`, `epidemiology/`, and
`cslib/` skill/command files, every one hand-rolling `specs/state.json > specs/tmp/state.json &&
mv ...` (or similar) with zero mutex protection. This is **not new** and **not part of this task's
declared scope** — `task-lock.md`'s own "Known residual surface" note already states "Every
extension `SKILL.md` file with its own inline `specs/state.json` write pattern is a further,
separately out-of-scope surface," which the plan/implementer inherits as an existing, acknowledged
exclusion rather than something to silently ignore or something newly discovered here.

### Net effect on the verification bar

Given the above, the literal instruction "a repo-wide grep... returns ZERO hits outside
`state-write.sh` itself" **cannot be satisfied** by work confined to the declared `file_scope`
without also either (a) scoping the verification grep to `agent-system/extensions/core/**` (which
still leaves `jq-escaping-workarounds.md` and `review.md` as residual unless also touched — both
outside `file_scope`), or (b) explicitly enumerating every known exclusion above in the
implementation summary as a reported, deliberate gap. Recommend the plan pick one of these two
paths explicitly rather than let the verification bar silently fail or silently pass on an
unscoped grep.

## Decisions

- Recommend a single, unparameterized `specs/.scope-lock` mutex covering every `--state-file`
  target (not per-file locks) — avoids a real ABBA-deadlock surface between concurrent
  recover/abandon-style interleaved operations, at negligible serialization cost.
- Recommend `--state-file <path>` as an optional flag on `state-write.sh`, defaulting to
  `$PROJECT_ROOT/specs/state.json`, preserving every existing caller unchanged.
- Recommend `--regen-todo` be a hard usage error when combined with a non-default `--state-file`.
- Recommend the vault archive-reinit site (skill-todo/SKILL.md Stage 9.2) be handled via either an
  `--init`/no-input mode on `state-write.sh` or an explicit `scope-acquire`/`scope-release`
  bracket around the existing hand-rolled `jq -n` — a plain `--state-file` flag cannot express it.

## Risks & Mitigations

- **Risk**: verification bar's literal repo-wide grep will not return zero hits even after full
  in-scope conversion, due to `jq-escaping-workarounds.md`, `review.md`, and the extension-domain
  debt. **Mitigation**: the plan should explicitly scope the verification grep and explicitly list
  every known exclusion (this report enumerates them) rather than treat a non-zero result as an
  unexplained failure.
- **Risk**: the two orphaned scripts (`archive-task.sh`, `vault-operation.sh`) could be invoked by
  a future task/command without anyone noticing they still hand-roll unprotected writes.
  **Mitigation**: explicit decision recorded in the plan (convert now, or document as dead code)
  rather than silence.
- **Risk**: treating the vault archive-reinit as a plain `--state-file` transform would either
  crash (file-must-exist precondition) or require inventing a workaround inline that reintroduces
  a hand-rolled write. **Mitigation**: resolved above as a named design fork requiring one of two
  explicit choices.

## Context Extension Recommendations

- **Topic**: `context/patterns/task-lock.md`'s "Known residual surface" note.
- **Gap**: Stale site counts for `commands/task.md` (says 5, actually 2) and `commands/todo.md`
  (says 3, actually 1 concrete + 2 prose across both task.md/todo.md/skill-todo combined).
- **Recommendation**: Update the note as part of this task's own work (the file is in
  `file_scope`) to reflect current state, and add the archive/vault conversion's outcome once
  done.

## Appendix

- Searches performed: repo-wide grep for `state\.json.*>.*tmp|tmp.*&&.*mv.*state\.json|
  state\.json\.tmp` across `agent-system/extensions/` (core and all non-core extensions); direct
  reads of `state-write.sh`, `test-state-write-concurrency.sh`, `task.md` (recover ~230-330, abandon
  ~860-935), `todo.md` (~1-40, ~470-620), `skill-todo/SKILL.md` (~439-620, ~618-838),
  `task-lock.md` (full scope/commit-mutex sections), `archive-task.sh`, `vault-operation.sh`,
  `jq-escaping-workarounds.md` (archive examples), `review.md` (~640-690); `git log` on
  `task-lock.md`/`state-write.sh` history for corroboration of the "already converted" claim.

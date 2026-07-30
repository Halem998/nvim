# Implementation Plan: Task #969

- **Task**: 969 - Extend state-write.sh to cover archive and vault state files and convert residual hand-rolled sites
- **Status**: [IMPLEMENTING]
- **Effort**: 7.5 hours
- **Dependencies**: 967
- **Research Inputs**: specs/969_extend_state_write_to_archive_and_vault_targets/reports/01_extend-state-write-archive-vault.md
- **Artifacts**: plans/01_extend-state-write-archive-vault.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`state-write.sh` is the single mutex-guarded `specs/state.json` writer, but its target is
hardcoded, so `specs/archive/state.json` and vault-root `state.json` writes remain hand-rolled
`jq > tmp && mv` sequences with no mutex, no `jq empty` validation, and no private staging. This
plan adds two orthogonal capabilities to the writer — an optional `--state-file <path>` (default
unchanged) and an `--init` no-input construct mode — then converts every hand-rolled archive/vault
write site in the source store to use them, corrects the stale residual-surface note in
`context/patterns/task-lock.md`, and closes the verification bar against an explicitly enumerated
exclusion list rather than an unsatisfiable "zero hits" grep.

**BINDING SOURCE-STORE RULE**: every edit in every phase targets
`agent-system/extensions/core/**`. `.claude/**` is a gitignored, disposable deploy artifact —
never an edit target. Runtime call strings inside converted blocks still read
`bash .claude/scripts/state-write.sh` (that is the deployed call path, and it stays), but the file
being edited is always the source-store copy.

**DELIVERABLE RULE**: none of this task's deliverables outside `specs/**` may cite a task number.
Reference durable anchors only: script names, flag names (`--state-file`, `--init`,
`--regen-todo`), mechanism names (`specs/.scope-lock`, guest mode, `SCOPE_MUTEX_HELD`), and
section headings.

### Research Integration

The research report's four escalated decisions are resolved in "Resolved Design Decisions" below
and are binding on the implementer. Its two out-of-`file_scope` findings
(`scripts/vault-operation.sh`, `scripts/archive-task.sh`) are resolved as **convert**, not
document-as-dead, with the rationale recorded. Its verification-bar analysis is resolved as
**scope the grep to `agent-system/extensions/core/**` plus an enumerated exclusion list**, given
verbatim in Phase 8.

**One site the research report missed, found during planning**: `commands/todo.md` Step 5.8.6
("Reinitialize archive") carries a *second* fresh-create site —
`jq -n '{ "completed_projects": [] }' > "specs/archive/state.json"` — mirroring
`skills/skill-todo/SKILL.md` Stage 9.2. That makes **6 concrete sites in the declared
`file_scope`** (not 4) plus 3 prose-only sites plus 4 more in the two out-of-scope scripts. The
report's own instruction to "re-grep the FULL source store rather than trusting this list" is
therefore load-bearing and repeated as a Scope Hypothesis on every conversion phase.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and no roadmap consultation was
requested; the `roadmap_flag` is absent, so no roadmap review/update phases are included.

## Resolved Design Decisions

These are decisions, not options. The implementer applies them as written.

### D1. `--state-file <path>`, optional, defaulting to `$PROJECT_ROOT/specs/state.json`

An explicit opt-in flag, never inference from the jq filter. Every one of the ~24 existing caller
files keeps working byte-for-byte unchanged because none passes the flag today.

### D2. ONE `specs/.scope-lock` mutex covering every `--state-file` target — not per-file locks

**Decision**: keep the mutex single and unparameterized. `state-write.sh` continues to call
`task-lock.sh scope-acquire`/`scope-release` with no file-derived lock name; only its internal
`STATE_FILE` variable becomes parameterized.

**Justification**: `commands/task.md`'s recover path removes from `specs/archive/state.json` and
then inserts into `specs/state.json` in the same logical operation; the abandon path does the
mirror image. Under per-file locks, one session recovering while another abandons acquires two
different locks in opposite order — textbook ABBA deadlock. A single lock name makes each
acquire/release pair sequential and never nested regardless of target, so the deadlock is
impossible by construction. The cost — archive/vault writers serializing against live-state
writers — is negligible: these are rare, human/agent-paced operations that already serialize in
practice. This decision MUST be recorded in both the script header and
`context/patterns/task-lock.md` (Phase 7), because the reasoning is non-obvious from the code.

### D3. `--init` mode on `state-write.sh` for the fresh-create sites — NOT a hand-rolled write wrapped in scope-acquire/scope-release

The research report presented this as a real fork. **Decision: add `--init`.**

**Justification for rejecting the wrap-it-in-a-bracket alternative**: the hand-rolled fresh-create
sites are `jq -n '{...}' > "specs/archive/state.json"` — a direct redirect into the destination.
Wrapping that in `scope-acquire`/`scope-release` closes only the *serialization* defect. It leaves
both other defects named in the task description intact: there is no private `mktemp` staging (a
jq failure truncates the destination in place) and no `jq empty` validation before the file becomes
authoritative. It also forces three separate call sites to hand-reimplement fail-closed acquire,
guest-mode `SCOPE_MUTEX_HELD` handling, and EXIT-trap release inside markdown-embedded bash —
exactly the per-site duplication `state-write.sh` exists to eliminate. `--init` costs two localized
changes inside the script (skip the existence precondition; run `jq -n "$FILTER"` instead of
`jq "$FILTER" "$STATE_FILE"`) and reuses the entire acquire -> mktemp -> transform -> validate ->
mv -> release sequence unchanged.

**`--init` semantics** (all four bullets are requirements, not suggestions):
- Skips the `[ ! -f "$STATE_FILE" ]` precondition; the target need not exist.
- Runs `jq -n "${JQ_ARGS[@]}" "$JQ_FILTER"` (null input). `--arg`/`--argjson` passthrough is
  unchanged, so callers can bind a timestamp rather than interpolating shell into the filter.
- **Overwrites an existing target, but never silently**: when the target already exists, emit a
  named stderr note ("Note: --init is replacing an existing <path>") before proceeding. An
  accidental clobber must be visible in the transcript.
- **Refuses `--init` against the default live path**: `--init` without an explicit `--state-file`,
  or with a `--state-file` that normalizes to `specs/state.json`, is a usage error (exit 1). This
  is a cheap, loud guard against a filter typo destroying live task state. `--init` is for archive
  and vault targets only.

### D4. `--regen-todo` combined with a non-default `--state-file` is a hard usage error (exit 1)

`generate-todo.sh` regenerates `specs/TODO.md` from `specs/state.json` unconditionally. Running it
after an archive or vault write would render a view of a file that was not the one just written.
Refuse loudly rather than regenerate from the wrong source. `--init` + `--regen-todo` is likewise a
usage error (it is unreachable given D3's default-path refusal, but assert it explicitly so the
combination cannot become reachable by a later edit).

**Path comparison must be normalized, not string-compared**: `./specs/state.json`,
`specs/state.json`, and an absolute `$PROJECT_ROOT/specs/state.json` are all the default. Use
`realpath -m` (which does not require the path to exist — required, since `--init` targets may not
exist yet) on both the resolved `--state-file` value and the default, and compare the results.

### D5. `scripts/vault-operation.sh` and `scripts/archive-task.sh` — CONVERT, do not document as dead

Both are outside the declared `file_scope`. **Decision: convert both** (Phase 6). This is a
deliberate, recorded `file_scope` expansion, and Phase 8 reports it explicitly.

**Justification**: `vault-operation.sh`'s "Renumber tasks" and "Reset state" steps hand-roll
writes to the **live** `specs/state.json` (`jq ... "$state_json" > "${state_json}.tmp" && mv`) with
**zero** mutex acquisition. That is a strictly worse violation of the convention this task extends
than any archive-only site the task description names, and it would make Phase 8's core-scoped grep
legitimately fail on a *live-state* site — which cannot honestly be filed as an acceptable
exclusion. Both scripts are already deployed to `.claude/scripts/` via `manifest.json`, so they are
one `bash` invocation away from becoming live regardless of having no caller today. Once
`--state-file` and `--init` exist, the conversion is mechanical.

`state.json` `file_scope` is a descriptive, creation-time field that status-sync never mutates
(see `rules/state-management.md`); do not edit it. Record the expansion in the summary instead.

### D6. Verification grep — scoped to `agent-system/extensions/core/**` with an enumerated exclusion list

The bar's literal "repo-wide grep, zero hits outside `state-write.sh`" is unsatisfiable. Phase 8
gives the exact scoped command and the exact expected residual set. A run is green when the
residual set matches the declared list exactly — not when it is empty. Any hit not on the list is a
failure. Exclusions are enumerated in Phase 8 with a reason each.

### D7. Prose-only archive sites become concrete invocations

`commands/todo.md` Step 5A and `skills/skill-todo/SKILL.md` Stage 10 step 1 and step 8b describe
archive/state.json writes in prose with no code. They are in `file_scope`, and leaving them as prose
next to newly-converted concrete siblings invites the next author to re-derive a hand-rolled block.
**Decision**: give each a concrete `state-write.sh --state-file specs/archive/state.json`
invocation, matching the jq filter shape of its already-concrete sibling, while preserving the
surrounding prose requirements (include all task fields; add the archived timestamp; route
`completed`/`expanded` to `completed_projects` and `abandoned` to `archived_projects`).

## Goals & Non-Goals

**Goals**:
- `state-write.sh` gains `--state-file <path>` (default unchanged) and `--init`, with `--regen-todo`
  refused for non-default targets, and its full existing contract preserved for the default path:
  bounded-retry fail-closed acquire, private `mktemp` staging, `--arg`/`--argjson` passthrough,
  `jq empty` validation, `mv` into place, optional post-release `--regen-todo`, and
  `SCOPE_MUTEX_HELD` guest mode.
- Every hand-rolled archive/vault `state.json` write in `agent-system/extensions/core/**` routes
  through `state-write.sh`, with the "left hand-rolled because the writer cannot target this file"
  comments replaced by the real invocation.
- `context/patterns/task-lock.md`'s stale "Known residual surface" note is corrected, and the
  single-mutex rationale, `--state-file`/`--init` contract, and `--regen-todo` refusal are
  documented there.
- `test-state-write-concurrency.sh` is extended with cases covering a non-default `--state-file`
  target, `--init`, and both usage-error refusals.
- Backward compatibility for every pre-existing caller is verified, not assumed.

**Non-Goals**:
- Converting `commands/review.md`'s `specs/reviews/state.json` writes (a different state file with
  different semantics — named exclusion, mechanically possible as follow-up now that
  `--state-file` exists).
- Converting the non-core extension-domain hand-rolled writes (measured during planning at 128
  sites across 56 files under `agent-system/extensions/` outside `core/`) — pre-existing,
  already-documented, separately out-of-scope surface.
- Per-file mutexes (explicitly rejected in D2).
- Hand-editing anything under `.claude/**`.
- Fixing the extension-loader deploy gaps documented in
  `rules/no-task-references-in-deliverables.md` (a new `scripts/**` file is not being added, so
  they are not on this task's path).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A regression in `state-write.sh` breaks all ~24 caller files at once | H | M | Phase 1 changes are additive with unchanged defaults; Phase 2 extends the concurrency suite before any caller is touched; Phase 8 re-runs `test-state-write-concurrency.sh`, `test-state-write-regen-timing.sh`, and `test-task-lock-reap.sh` and greps every caller for argument-shape changes |
| `--init` typo destroys live `specs/state.json` | H | L | D3's hard refusal of `--init` against the default path (exit 1), plus a loud stderr note on any existing-target overwrite; Phase 2 adds a case asserting the refusal |
| Site enumeration is wrong (the sibling conversion's audit undercounted twice; planning already found a 7th site the research report missed) | M | H | Every conversion phase carries a Scope Hypothesis requiring a fresh anchored grep before editing, and requires reporting any site found beyond the listed set rather than silently converting or skipping it |
| `--regen-todo` default-path detection breaks on a path form nobody tested | M | M | `realpath -m` normalization on both sides (D4), plus a Phase 2 case exercising at least two spellings of the default path |
| Phase 8's grep passes vacuously because the pattern is too narrow to match the pre-conversion sites | M | M | Phase 8 requires running the exact grep against `git stash`-free pre-edit content or an equivalent baseline first, confirming it *does* match the known pre-conversion sites, before trusting a clean post-conversion run |
| Converting the two dead scripts introduces a `session_id` plumbing bug in a script with no caller to catch it | M | M | Mirror `archive-task.sh`'s existing inline session-id generation pattern verbatim; Phase 6 verifies both scripts with `bash -n` plus a `--dry-run`/no-op invocation where the script supports one |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5, 6 | 1 |
| 3 | 7 | 3, 4, 5, 6 |
| 4 | 8 | 2, 7 |

Phases within the same wave can execute in parallel. Wave 2's five phases touch disjoint file
sets (territory below), so they are safe to parallelize.

**Wave 2 territory contract** (one owner per file, no overlap):
- Phase 2 owns `scripts/test-state-write-concurrency.sh`
- Phase 3 owns `commands/task.md`, `context/patterns/jq-escaping-workarounds.md`
- Phase 4 owns `commands/todo.md`
- Phase 5 owns `skills/skill-todo/SKILL.md`
- Phase 6 owns `scripts/archive-task.sh`, `scripts/vault-operation.sh`

---

### Phase 1: Extend `state-write.sh` with `--state-file` and `--init` [COMPLETED]

**Goal**: The single mutex-guarded writer can target any state file and can construct a fresh one,
with the default path's contract byte-for-byte unchanged and both new usage errors refused loudly.

**Tasks**:
- [x] Add `--state-file <path>` to the arg parser. Resolve relative values against the caller's
      working directory; keep `STATE_FILE="$PROJECT_ROOT/specs/state.json"` as the default so no
      existing caller changes behavior.
- [x] Add `--init` to the arg parser (boolean, default false).
- [x] Add the D4 refusal: `--regen-todo` together with a `--state-file` that does not
      `realpath -m`-normalize to the default path exits 1 with a named usage error naming both
      paths. `--init` together with `--regen-todo` also exits 1.
- [x] Add the D3 refusal: `--init` without `--state-file`, or with a `--state-file` normalizing to
      the default path, exits 1 with a named usage error.
- [x] Gate the `[ ! -f "$STATE_FILE" ]` precondition on `--init` being false. When `--init` is true
      and the target exists, emit the stderr overwrite note.
- [x] Branch the transform: `--init` runs `jq -n "${JQ_ARGS[@]}" "$JQ_FILTER" > "$STAGE_FILE"`;
      otherwise the existing `jq "${JQ_ARGS[@]}" "$JQ_FILTER" "$STATE_FILE" > "$STAGE_FILE"`.
      Apply the same branch inside the `--dry-run` validation path so dry-run stays meaningful for
      `--init`.
- [x] Keep `TMP_DIR="$PROJECT_ROOT/specs/tmp"` as the staging directory for **all** targets,
      including archive and vault ones. Staging stays project-local and private; do not derive a
      per-target temp directory.
- [x] Verify the acquire/release path is untouched: `task-lock.sh scope-acquire`/`scope-release`
      still receive only `SESSION_ID` and `STATE_WRITE_SCOPE_STALE_SEC` — no file-derived lock
      name (D2).
- [x] Update the header comment block: document both new flags, state D2's single-mutex decision
      and its ABBA rationale, state D3's `--init` semantics including both refusals, state D4's
      refusal, and update the "Usage:" line. Replace the header's "The single mutex-guarded writer
      for specs/state.json" framing with one that covers every state-file target.
- [x] Update the exit-code table in the header: the two new refusals are exit 1 (usage), and the
      "state.json left untouched" wording on codes 3 and 4 becomes target-agnostic.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: this phase's verification asserts `test-state-write-concurrency.sh` currently
has four cases and that ~24 caller files reference `state-write.sh`. Both are hypotheses — confirm
the case count from the suite's own "Results: N passed" line and the caller count from
`grep -rl 'state-write\.sh' agent-system/extensions/core/ | wc -l` before relying on either.

**Files to modify**:
- `agent-system/extensions/core/scripts/state-write.sh` - add both flags, both refusals, the
  `--init` transform branch, and the rewritten header contract

**Verification**:
- `bash -n agent-system/extensions/core/scripts/state-write.sh` clean.
- `bash agent-system/extensions/core/scripts/test-state-write-concurrency.sh` exits 0 (the
  pre-existing four cases, unextended — proves no default-path regression before Phase 2 adds
  coverage).
- `bash agent-system/extensions/core/scripts/test-state-write-regen-timing.sh` exits 0.
- `bash agent-system/extensions/core/scripts/test-task-lock-reap.sh` exits 0.
- Manual smoke against a throwaway temp root (never the real `specs/`): a default-path write with
  no new flags succeeds; `--state-file <tmp>/archive/state.json` transform succeeds; `--init
  --state-file <tmp>/archive/state.json` creates the file; `--regen-todo --state-file
  <tmp>/archive/state.json` exits 1; `--init` with no `--state-file` exits 1.

---

### Phase 2: Extend the concurrency suite for the new surface [NOT STARTED]

**Goal**: `test-state-write-concurrency.sh` proves the new flags' contracts with the same
isolated-temp-root, no-testability-hooks discipline the existing four cases use.

**Tasks**:
- [ ] Extend the fixture builder to also create `$TMPROOT/specs/archive/state.json` with a minimal
      `{"completed_projects": [...]}` document, and a `reset_archive_state_json()` helper mirroring
      the existing `reset_state_json()`.
- [ ] Case 5: non-default `--state-file` target — a transform against
      `$TMPROOT/specs/archive/state.json` lands, exits 0, leaves `specs/state.json` byte-identical
      (assert with a `jq -S .` before/after hash), and produces valid JSON.
- [ ] Case 6: single-mutex serialization ACROSS targets (D2's load-bearing property) — one heavy
      writer against the default path concurrent with one writer against
      `specs/archive/state.json`; both must land, and the second must genuinely have waited (assert
      no lost update on either file). This is the case that would fail under per-file locks and is
      the regression test for D2.
- [ ] Case 7: `--init` — against a target that does **not** exist, the file is created with the
      constructed document and exits 0; then a second `--init` against the now-existing target
      succeeds and emits the overwrite note on stderr.
- [ ] Case 8: `--regen-todo` refusal — with a non-default `--state-file`, exits 1, the target is
      untouched, and `specs/TODO.md` is not created/modified. Exercise at least two spellings of
      the default path (relative and absolute) to confirm the normalized comparison treats both as
      default and permits `--regen-todo` there.
- [ ] Case 9: `--init` default-path refusal — `--init` with no `--state-file` exits 1 and
      `specs/state.json` is byte-identical afterward; `--init --state-file <the default path>`
      likewise exits 1.
- [ ] Update the header comment's "Exit 0 when all four cases PASS" line and the file's opening
      description to reflect the new case count and what the added cases prove.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts the suite grows from 4 to 9 cases. The count is a
hypothesis — if a listed case turns out to be already covered by an existing case, or if a new
refusal in Phase 1 needs its own case, adjust the count and say so. Confirm by running the suite
and reading its "Results: N passed" line against the number of `pass`/`fail` call sites.

**Files to modify**:
- `agent-system/extensions/core/scripts/test-state-write-concurrency.sh` - fixture extension plus
  five new cases and an updated header

**Verification**:
- `bash -n` clean.
- `bash agent-system/extensions/core/scripts/test-state-write-concurrency.sh` exits 0 with all
  cases passing.
- Confirm the suite still never touches the real `specs/` tree (grep the new cases for any path not
  rooted at `$TMPROOT`).
- Adversarial check: temporarily revert one Phase 1 change (e.g. the `--regen-todo` refusal) and
  confirm the corresponding new case FAILS, then restore. A case that passes against the
  unmodified script proves nothing.

---

### Phase 3: Convert `commands/task.md`'s archive sites and the illustrative examples [NOT STARTED]

**Goal**: The recover and abandon paths' archive writes go through `state-write.sh`, and the
`jq-escaping-workarounds.md` examples they cross-reference stop demonstrating the anti-pattern.

**Tasks**:
- [ ] Re-grep `commands/task.md` for `specs/archive/state.json` anchored on quoted strings, and
      confirm the site set before editing.
- [ ] Convert recover mode "Step 1: Remove from archive": replace the
      `jq 'del(...)' specs/archive/state.json > specs/tmp/archive.json && mv ...` block with
      `bash .claude/scripts/state-write.sh 'del(.completed_projects[] | select(.project_number == ($num | tonumber)))' --state-file specs/archive/state.json --session-id "$session_id" --arg num "$task_number"`.
      Preserve the `del()`-not-`map(select(!=))` choice and its `jq-escaping-workarounds.md`
      cross-reference — that is an independent Issue #1132 workaround, not part of this conversion.
- [ ] Convert abandon mode "Step 1: Add to archive" the same way, keeping its `--arg ts` /
      `--argjson task` bindings and the `.completed_projects = [$task | ...] + .completed_projects`
      filter shape.
- [ ] Replace both "Deliberately left hand-rolled: state-write.sh targets specs/state.json only,
      never specs/archive/state.json" comments. Do not simply delete them: replace with a short
      note that the archive target is reached via `--state-file`, so a future reader does not
      re-derive the old rationale.
- [ ] In recover mode, verify the now-adjacent Step 1 and Step 2 both invoke `state-write.sh` and
      add a one-line note that the two sequential acquires are safe because a single
      `specs/.scope-lock` covers both targets (D2). Same for abandon mode's Step 1/Step 2 pair.
      This is the interleaved block the task description names; the safety must be visible at the
      site, not only in `task-lock.md`.
- [ ] Confirm abandon Step 2's existing `--regen-todo` stays on the **live-state** write only and
      is not folded into the archive write (D4 would refuse it, but the intent must also be
      correct at the site).
- [ ] Update `context/patterns/jq-escaping-workarounds.md`'s "Task Recovery (from archive)" and
      "Task Abandon (to archive)" examples to show the `state-write.sh --state-file` form, keeping
      each example's actual lesson (the `del()` / two-step escaping workaround) intact and removing
      the two "Deliberately left hand-rolled" comments.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: 2 concrete sites in `commands/task.md` and 2 illustrative examples in
`jq-escaping-workarounds.md`. Confirm at implementation time with an anchored grep for
`archive/state.json` across both files; report any additional site rather than converting it
silently.

**Files to modify**:
- `agent-system/extensions/core/commands/task.md` - recover Step 1 and abandon Step 1 conversions,
  comment replacement, single-mutex note at both interleaved blocks
- `agent-system/extensions/core/context/patterns/jq-escaping-workarounds.md` - both archive
  examples updated to the sanctioned form

**Verification**:
- Extract every edited bash fence and run `bash -n` on each; all clean.
- Anchored grep confirms no `specs/archive/state.json` write remains in either file that is not a
  `state-write.sh` invocation (reads via `jq -r ... specs/archive/state.json` are untouched and
  expected).
- Read-through of both edited blocks confirming `--session-id` uses the variable the surrounding
  block actually has in scope (`$session_id` in recover, `$SESSION_ID` in abandon — these differ;
  do not normalize one to the other).

---

### Phase 4: Convert `commands/todo.md`'s archive and vault sites [NOT STARTED]

**Goal**: Every `specs/archive/state.json` write in `commands/todo.md` — the orphan-entry
transform, the vault reinit fresh-create, and the prose-only archival step — routes through
`state-write.sh`.

**Tasks**:
- [ ] Re-grep `commands/todo.md` for `archive/state.json` and confirm the site set before editing.
- [ ] Convert Step 5E.2's orphan-entry block: replace
      `jq '.completed_projects += [...]' specs/archive/state.json > specs/archive/state.json.tmp && mv ...`
      with a `state-write.sh --state-file specs/archive/state.json` invocation carrying the same
      `--arg num/name/date` and `--argjson arts` bindings. Replace the "Deliberately left
      hand-rolled" comment per Phase 3's rule (replace, do not delete).
- [ ] Convert Step 5.8.6 "Reinitialize archive" — the site the research report missed. Replace
      `jq -n '{ "completed_projects": [] }' > "specs/archive/state.json"` with
      `bash .claude/scripts/state-write.sh '{ "completed_projects": [] }' --init --state-file specs/archive/state.json --session-id "$session_id"`,
      keeping the preceding `mkdir -p "specs/archive"`. Replace the "Deliberately left hand-rolled:
      `state-write.sh` targets `specs/state.json` only" prose that introduces the block.
- [ ] Make Step 5A ("Update archive/state.json") concrete per D7: keep the prose stating which
      array each status routes to and that all task fields plus an archived timestamp are included,
      and add a canonical `state-write.sh --state-file specs/archive/state.json` invocation whose
      filter shape matches `commands/task.md`'s abandon Step 1. Do not change the routing rules
      themselves (`completed`/`expanded` -> `completed_projects`, `abandoned` ->
      `archived_projects`, no third array).
- [ ] Confirm the `session_id` variable used at each site is actually in scope in that step; if a
      step has none, use the same inline generation pattern `archive-task.sh` uses rather than
      inventing a new one.
- [ ] Leave Step 5.8.4's `mv "${vault_path}/archive/state.json" "${vault_path}/state.json"`
      untouched — a file rename, not a state write, and correctly out of `state-write.sh`'s remit.
      Add a one-line note saying so, so the next auditor does not flag it.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: 2 concrete sites (Step 5E.2 transform, Step 5.8.6 fresh-create) plus 1
prose-only site (Step 5A) in `commands/todo.md`. The research report listed only 1 concrete site
here; planning found the second. Confirm with an anchored grep at implementation time and report
any further site.

**Files to modify**:
- `agent-system/extensions/core/commands/todo.md` - Step 5E.2 conversion, Step 5.8.6 `--init`
  conversion, Step 5A prose made concrete, Step 5.8.4 clarifying note

**Verification**:
- `bash -n` on every edited bash fence; all clean.
- Anchored grep confirms no remaining `> ... && mv` or `> "specs/archive/state.json"` write in the
  file; the only `archive/state.json` writes are `state-write.sh` invocations, and the `mv` at Step
  5.8.4 is the one intentional, annotated exception.
- Read-through confirming the `--init` invocation passes `--state-file` (D3 refuses `--init`
  without it, so a missing flag is a runtime exit-1, not a silent no-op).

---

### Phase 5: Convert `skills/skill-todo/SKILL.md`'s archive and vault sites [NOT STARTED]

**Goal**: The vault archive-reinit and both prose-only archive steps in `skill-todo` route through
`state-write.sh`.

**Tasks**:
- [ ] Re-grep `skills/skill-todo/SKILL.md` for `archive/state.json` and `jq -n` and confirm the
      site set before editing.
- [ ] Convert Stage 9.2 CreateVault's archive reinit — the design-fork site. Replace the
      `jq -n '{ "_comment": ..., "completed_projects": [], "archived_at": "'"$current_timestamp"'" }' > "specs/archive/state.json"`
      block with a `state-write.sh --init --state-file specs/archive/state.json` invocation. Bind
      the timestamp via `--arg ts "$current_timestamp"` and reference `$ts` inside the filter —
      do **not** carry over the shell-interpolation-inside-single-quotes construction, which is
      exactly what `--arg` passthrough exists to replace. Replace the "Deliberately left
      hand-rolled" prose that introduces the block.
- [ ] Make Stage 10 step 1 ("Update specs/archive/state.json") concrete per D7, matching Phase 4's
      Step 5A shape so the command file and the skill file describe the same invocation.
- [ ] Make Stage 10 step 8b ("Add entry to specs/archive/state.json completed_projects array" for
      TODO.md orphans) concrete per D7, matching Phase 4's Step 5E.2 shape.
- [ ] Confirm Stages 9.3 (RenumberTasks) and 9.4 (ResetState) already route every **live**
      `specs/state.json` write through `state-write.sh` and leave them unchanged — the research
      report verified this; re-confirm rather than trust it.
- [ ] Leave Stage 9.2's `mv "${vault_path}/archive/state.json" "${vault_path}/state.json"`
      untouched with the same clarifying note Phase 4 adds to its `commands/todo.md` twin.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: 1 concrete fresh-create site (Stage 9.2) plus 2 prose-only sites (Stage 10
step 1, step 8b) in `skills/skill-todo/SKILL.md`, with Stages 9.3/9.4 already converted. Confirm
each of the four claims independently at implementation time.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` - Stage 9.2 `--init` conversion, Stage
  10 steps 1 and 8b made concrete, Stage 9.2 `mv` clarifying note

**Verification**:
- `bash -n` on every edited bash fence; all clean.
- Anchored grep confirms the only `specs/archive/state.json` writes in the file are
  `state-write.sh` invocations.
- Read-through confirming the timestamp reaches jq via `--arg`, not shell interpolation, and that
  the resulting document has the same three keys (`_comment`, `completed_projects`, `archived_at`)
  the old block produced.

---

### Phase 6: Convert `scripts/archive-task.sh` and `scripts/vault-operation.sh` [NOT STARTED]

**Goal**: The two deployed-but-uncalled scripts — including `vault-operation.sh`'s two
**unprotected live-`specs/state.json`** writes — route through `state-write.sh`. This is the
recorded `file_scope` expansion from D5.

**Tasks**:
- [ ] `archive-task.sh`: convert step A's
      `jq ... "$ARCHIVE_STATE_FILE" > "${ARCHIVE_STATE_FILE}.tmp" && mv ...` to
      `"$SCRIPT_DIR/state-write.sh" '.[$array] += [$entry]' --state-file "$ARCHIVE_STATE_FILE" --session-id "$session_id" --argjson entry "$task_entry" --arg array "$archive_array"`.
      The script already resolves `$session_id` (inline-generated when `--session-id` is omitted) —
      reuse it, do not add a second generation path.
- [ ] `archive-task.sh`: convert the "Initialize archive/state.json if missing"
      `echo '{ "archived_projects": [], "completed_projects": [] }' > "$ARCHIVE_STATE_FILE"` to a
      `state-write.sh --init --state-file "$ARCHIVE_STATE_FILE"` invocation, keeping it inside the
      existing `if [ ! -f ... ]` guard and the existing `if ! $dry_run` guard.
- [ ] `archive-task.sh`: update the header's step-A description, which currently states archive
      state is "out of scope for the shared state-write.sh conversion; this step's write is
      unchanged." That sentence becomes false — rewrite it to name `--state-file`.
- [ ] `vault-operation.sh`: convert the "Renumber tasks" write
      (`jq ... "$state_json" > "${state_json}.tmp" && mv ...`) to a `state-write.sh` invocation
      with `--state-file "$state_json"`. This is a LIVE state write with no mutex today — the
      highest-value conversion in this phase.
- [ ] `vault-operation.sh`: convert the "Reset state" write the same way, preserving its
      `--argjson new_next` / `--argjson vault_num` / `--arg vault_path` / `--arg created` bindings.
- [ ] `vault-operation.sh`: convert step 5.8.6's
      `echo '{ "completed_projects": [] }' > "${ARCHIVE_DIR}/state.json"` to
      `state-write.sh --init --state-file "${ARCHIVE_DIR}/state.json"`.
- [ ] `vault-operation.sh`: add `session_id` plumbing — the script has none today. Add an optional
      `--session-id SID` argument plus inline generation when omitted, copying
      `archive-task.sh`'s existing pattern and header wording verbatim rather than inventing a
      variant. Update the `Usage:` line and the header's step list.
- [ ] Leave `vault-operation.sh`'s `mv "${vault_path}/archive/state.json" "${vault_path}/state.json"`
      untouched (rename, not a write), with the same clarifying note added in Phases 4 and 5.
- [ ] Confirm neither script's `set -euo pipefail` posture conflicts with `state-write.sh`'s exit
      codes: an exit 2 (mutex ABORT) or 3/4 must surface as a script failure, not be swallowed.
      Under `set -e` it propagates; assert this rather than assume it, and do not add a `|| true`.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: 2 sites in `archive-task.sh` (step-A transform, init-if-missing) and 3 in
`vault-operation.sh` (renumber write, reset write, archive reinit), plus session-id plumbing in
the latter. Confirm with an anchored grep for `> "${` / `.tmp` / `echo '{` across both scripts
before editing.

**Files to modify**:
- `agent-system/extensions/core/scripts/archive-task.sh` - step-A conversion, init conversion,
  corrected header
- `agent-system/extensions/core/scripts/vault-operation.sh` - two live-state conversions, archive
  reinit conversion, `--session-id` plumbing, corrected header

**Verification**:
- `bash -n` clean on both scripts.
- `bash archive-task.sh <n> <name> --dry-run` still exits 0 and prints the same dry-run lines
  (the script's dry-run path must not have acquired a mutex or written anything).
- `vault-operation.sh` invoked against a throwaway temp-root `state.json` whose
  `next_project_number` is `<= 1000` still exits 0 as a no-op (its threshold guard), and invoked
  with `--confirmed` against a fixtured `> 1000` state performs the conversion path without
  touching the real `specs/` tree.
- Anchored grep confirms no `state.json`-targeted `> tmp && mv`, `.tmp`, or `echo '{...}' >`
  sequence remains in either script.

---

### Phase 7: Correct `context/patterns/task-lock.md` [NOT STARTED]

**Goal**: The State-Write Convention section reflects reality: the corrected residual surface, the
single-mutex decision, the `--state-file`/`--init` contract, and the `--regen-todo` refusal.

**Tasks**:
- [ ] Replace the stale "Known residual surface (not yet converted)" paragraph. Its current claims
      — 14 core skill files with 48 inline write sites, `commands/task.md` 5 sites,
      `commands/todo.md` 3 sites — were verified stale during planning: a grep for hand-rolled
      `specs/state.json` writes across `agent-system/extensions/core/**` now returns only reads
      plus `commands/review.md`'s different `specs/reviews/state.json` file. Re-measure before
      writing the replacement; do not copy planning's numbers on faith.
- [ ] The replacement note must state: (a) every `specs/state.json` writer in
      `agent-system/extensions/core/**` routes through `state-write.sh`; (b) `specs/archive/state.json`
      and vault-root targets are now covered via `--state-file`, and fresh-creates via `--init`;
      (c) the remaining surface is the non-core extension domains (give the re-measured file and
      site counts, framed as a measurement with its date-free method stated, not a permanent fact)
      plus `commands/review.md`'s `specs/reviews/state.json` — a genuinely different state file,
      now mechanically convertible via `--state-file` and left as named follow-up.
- [ ] Document D2 in the same section: one `specs/.scope-lock` for every state-file target, with
      the ABBA-deadlock rationale and the recover/abandon interleaved-block example that motivates
      it. This is the durable home for the reasoning; the script header cross-references it.
- [ ] Document D3's `--init` semantics: no existence precondition, `jq -n` transform, loud
      overwrite note, and the hard refusal against the default live path.
- [ ] Document D4's `--regen-todo` refusal and the `realpath -m` normalized comparison.
- [ ] Check the section's other absolute claims against the new reality — in particular the "no
      other sanctioned way to write `specs/state.json`" line and the historical-narrative passages
      that quote the old `jq ... > tmp && mv` pattern. The historical passages stay (they explain
      why the mechanism exists); confirm none of them now reads as current-state guidance.

**Timing**: 1 hour

**Depends on**: 3, 4, 5, 6

**Verification Tier**: prose

**Scope Hypothesis**: this phase asserts the residual note's counts are stale in three specific
ways. Re-run the measurement grep and report the actual numbers; if any of the three claims turns
out still accurate, say so rather than "correcting" it to match this plan.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/task-lock.md` - State-Write Convention section:
  corrected residual note plus D2/D3/D4 documentation

**Verification**:
- Diff read-through confirming every changed hunk is prose or a fenced example, with no executable
  contract altered.
- Every count in the new note traces to a grep command run in this phase, with the command
  recorded in the phase's progress notes.
- Cross-reference check: the claims in `state-write.sh`'s header (Phase 1) and this section agree;
  neither states something the other contradicts.

---

### Phase 8: Verification bar, scoped grep, and exclusion report [NOT STARTED]

**Goal**: Every element of the task's verification bar is executed, and the unsatisfiable
"zero hits" grep is replaced by a scoped grep checked against an explicitly enumerated exclusion
list.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/test-state-write-concurrency.sh`; require
      exit 0 with the extended case set.
- [ ] Run `bash agent-system/extensions/core/scripts/test-task-lock-reap.sh`; require exit 0.
- [ ] Run `bash agent-system/extensions/core/scripts/test-state-write-regen-timing.sh`; require
      exit 0 (not named in the task's bar, but it is a `state-write.sh` suite and a regression here
      would be a real one).
- [ ] **Backward-compatibility check** (hard requirement): enumerate every `state-write.sh` caller
      with `grep -rl 'state-write\.sh' agent-system/extensions/core/` and confirm no pre-existing
      invocation's argument list changed. New `--state-file`/`--init` arguments appear only at sites
      converted in Phases 3-6; every other call site must be byte-identical to its pre-task form
      (`git diff` on those files must show no change to their `state-write.sh` lines).
- [ ] **Baseline the grep before trusting it**: run the scoped grep below against the pre-conversion
      content (e.g. `git stash`, or `git show HEAD:<path>` piped per file) and confirm it DOES match
      the known pre-conversion sites. A pattern that matches nothing before the work proves nothing
      after it.
- [ ] Run the scoped grep:
      ```bash
      grep -rnE 'state\.json[^ ]* *> *[^ ]*(tmp|\.tmp)|(tmp|state\.json\.tmp)[^|]*&&[^|]*mv[^|]*state\.json|(jq -n|echo)[^>]*> *"?[^ "]*archive/state\.json' \
        --include='*.md' --include='*.sh' agent-system/extensions/core/
      ```
- [ ] Compare the result against this **declared exclusion list**. Green means the residual set
      equals this list exactly; any hit not on it is a failure:
      1. `scripts/state-write.sh` itself — the sanctioned implementation.
      2. `commands/review.md` — two sites targeting `specs/reviews/state.json`, a different state
         file (`/review`'s own review-tracking state, unrelated to `active_projects`/archive/vault).
         Named exclusion; now mechanically convertible via `--state-file`, left as follow-up.
      3. `context/patterns/task-lock.md` — historical-narrative passages that quote the old
         `jq ... > tmp && mv` / `specs/state.json.tmp` pattern to explain why the mechanism exists.
         Prose about the past, not current guidance.
      4. Any doc passage that quotes the anti-pattern as a negative example while naming it as such.
      If a hit falls outside 1-4, it is a real residual site: convert it if it is a state write, or
      add it to the list with a stated reason. Never pass silently.
- [ ] Report the deliberately-out-of-scope surface explicitly in the summary (never silently
      passed): the non-core extension domains under `agent-system/extensions/` outside `core/`
      (re-measure the file and site counts here rather than quoting this plan), which
      `task-lock.md`'s residual note already records as a separate surface.
- [ ] Report the `file_scope` expansion explicitly: `scripts/archive-task.sh`,
      `scripts/vault-operation.sh`, and `context/patterns/jq-escaping-workarounds.md` were edited
      beyond the declared `file_scope`, per D5 and Phase 3. Do not edit `state.json`'s `file_scope`
      field.
- [ ] `bash -n` sweep: every edited `.sh` file directly, and every bash fence extracted from every
      edited `.md` file. Record the count of fences checked.
- [ ] Run `bash .claude/scripts/check-task-references.sh`; require exit 0. If it flags any of this
      task's own edits, fix by using a durable anchor — never by adding a `task-ref-ok` marker for
      a citation this task introduced.
- [ ] Run `bash .claude/scripts/check-extension-docs.sh`; require exit 0.
- [ ] Confirm no file under `.claude/**` was edited: `git status --short` plus a check that every
      modified path is under `agent-system/extensions/core/**` or `specs/**`.

**Timing**: 1 hour

**Depends on**: 2, 7

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts the post-conversion residual set equals the four-item
exclusion list. That is a hypothesis — the actual run may surface a site no phase enumerated.
Confirm by running the grep and diffing its output against the list item by item; report any
delta rather than widening the list silently.

**Files to modify**:
- None (verification only). Any fix required by a gate belongs to the owning phase's file and must
  be attributed there.

**Verification**:
- All four named suites/gates exit 0.
- The scoped grep's residual set matches the declared exclusion list exactly, with each residual
  hit mapped to its list item by number.
- The backward-compatibility enumeration shows zero unintended `state-write.sh` argument changes.
- `git status --short` shows no `.claude/**` modifications.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/test-state-write-concurrency.sh` exits 0, extended
      with a non-default `--state-file` case, a cross-target single-mutex serialization case, an
      `--init` case, and both usage-refusal cases.
- [ ] `bash agent-system/extensions/core/scripts/test-task-lock-reap.sh` exits 0.
- [ ] `bash agent-system/extensions/core/scripts/test-state-write-regen-timing.sh` exits 0.
- [ ] Every pre-existing `state-write.sh` caller works with no argument changes (enumerated and
      diff-verified, not assumed).
- [ ] `bash -n` clean on every edited script and every bash fence in every edited markdown file.
- [ ] `bash .claude/scripts/check-task-references.sh` exits 0.
- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0.
- [ ] The scoped residual grep's output equals the declared four-item exclusion list.
- [ ] Adversarial confirmation that at least one new test case fails when its Phase 1 change is
      reverted.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/state-write.sh` — `--state-file`, `--init`, two usage
  refusals, rewritten contract header
- `agent-system/extensions/core/scripts/test-state-write-concurrency.sh` — extended fixture and
  five new cases
- `agent-system/extensions/core/commands/task.md` — recover and abandon archive writes converted
- `agent-system/extensions/core/commands/todo.md` — orphan-entry write, vault archive reinit, and
  Step 5A converted/made concrete
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` — Stage 9.2 reinit converted, Stage 10
  steps 1 and 8b made concrete
- `agent-system/extensions/core/scripts/archive-task.sh` — step A and init converted, header
  corrected
- `agent-system/extensions/core/scripts/vault-operation.sh` — two live-state writes and archive
  reinit converted, `--session-id` plumbing added
- `agent-system/extensions/core/context/patterns/task-lock.md` — corrected residual note plus
  D2/D3/D4 documentation
- `agent-system/extensions/core/context/patterns/jq-escaping-workarounds.md` — archive examples
  updated to the sanctioned form
- `specs/969_extend_state_write_to_archive_and_vault_targets/summaries/01_*-summary.md` — must
  contain the reported exclusion list, the re-measured non-core surface, and the `file_scope`
  expansion

## Rollback/Contingency

- Every phase is a self-contained, independently revertible commit. Phase 1 is purely additive with
  unchanged defaults, so reverting any Wave 2 phase alone leaves a working system (the converted
  site returns to its hand-rolled form; the extended writer simply goes unused there).
- If Phase 1's `realpath -m` normalization proves unavailable or misbehaving on the target platform,
  fall back to a pure-shell normalization helper rather than to raw string comparison — string
  comparison would let `./specs/state.json` bypass D4's refusal, which is the failure mode the
  normalization exists to prevent. Do not skip the refusal.
- If a Wave 2 conversion cannot be completed (e.g. a site turns out to need semantics
  `state-write.sh` still cannot express), leave that single site hand-rolled, mark the phase
  `[COMPLETED WITH EXCLUSIONS]` with a `#### Reasoned Exclusions` record enumerating it, and add it
  to Phase 8's exclusion list with a stated reason. Do not force a conversion that changes behavior,
  and do not silently skip it.
- If Phase 6's `vault-operation.sh` conversion proves riskier than expected, its fallback is D5's
  rejected alternative — document both scripts as dead code in `task-lock.md`'s residual note — but
  this requires explicitly reporting that a live-`specs/state.json` write with zero mutex protection
  was knowingly left in a deployed script. Prefer completing the conversion.

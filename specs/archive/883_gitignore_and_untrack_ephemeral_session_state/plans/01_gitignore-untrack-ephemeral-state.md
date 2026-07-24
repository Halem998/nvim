# Implementation Plan: Task #883

- **Task**: 883 - gitignore_and_untrack_ephemeral_session_state
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/883_gitignore_and_untrack_ephemeral_session_state/reports/01_gitignore-ephemeral-session-state.md
- **Artifacts**: plans/01_gitignore-untrack-ephemeral-state.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, git-workflow.md, git-staging-scope.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Close the `.gitignore` gap that lets ephemeral orchestration session state (per-dispatch handoff
JSON, mutex lock directories, loop guards, multi-task scratch state) be committed into the
repository, then untrack the 198 instances already tracked. The change is exactly two mechanical
operations: add 9 patterns to the repo-root `.gitignore`, and `git rm --cached` the currently
tracked matches. `git rm --cached` is index-only — every working-tree file survives, so the
in-flight orchestrate batch (tasks 880/882/884, live right now) is undisturbed by construction.
Definition of done: no ephemeral pattern is tracked, every on-disk file still exists, and the
patterns provably match via `git check-ignore --no-index`.

### Research Integration

Findings from `reports/01_gitignore-ephemeral-session-state.md` integrated as follows:

- **`.orchestrator-handoff.json` resolved as ephemeral** — the task's explicit open question. Its
  own architecture doc (`.claude/docs/architecture/handoff-schema.md` line 5) specifies the path
  as "runtime; not checked in", and line 212 states each dispatch cycle overwrites the previous
  handoff. It is gitignored and untracked here, not preserved.
- **9 patterns, not 4** — the research expanded the description's 4 named artifacts with 3
  actively-churning (`.lock/`, `.orchestrator-loop-guard`, `.continuation-loop-guard`) and 3
  defensive (`.orchestrator-churn-state.json`, `.postflight-loop-guard`, `.events.lock`).
- **Out of scope, confirmed** — `specs/events.jsonl` (documented durable, "never-gitignored"),
  `.gitkeep`, the two dead legacy `.meta-*-return.json` files, and the archived audit/backup
  one-offs. None are touched.
- **The `.gitignore` gap is still open** even though `296c828af` already untracked
  `.return-meta-multi.json` / `.orchestrator-multi-state.json` — those two need no `git rm
  --cached` today, but without the patterns the next multi-task orchestrate run re-commits them.
  Both patterns are added defensively.
- **Root cause is context only** — postflight Stage 9 (commit) running before Stage 10 (cleanup)
  explains *why* these files get swept in, but the fix to that ordering is not this task's work.

### Live Verification Performed at Plan Time

Counts re-derived against the live index (they match the research exactly, 198 total):

| Pattern | Tracked |
|---|---|
| `.orchestrator-handoff.json` | 186 |
| `.orchestrator-loop-guard` | 4 |
| `.lock/holder.json` | 3 |
| `.return-meta*.json` | 3 |
| `.continuation-loop-guard` | 2 |
| `.orchestrator-multi-state.json`, `.orchestrator-churn-state.json`, `.postflight-loop-guard`, `.events.lock` | 0 (defensive) |
| **Total** | **198** |

Two mechanics were verified live at plan time and drive the phase design below:

1. **`git check-ignore -v` returns exit=1 and NO output for a tracked file** — it consults the
   index, and tracked files are by definition not ignored. Verifying the new patterns against the
   currently-tracked targets therefore **requires `--no-index`**, or the check reports zero
   matches and falsely suggests the patterns are broken. Confirmed against git 2.54.0.
2. **Postflight's Stage 9 `git commit` carries no pathspec** — it commits the entire index. Any
   staged content left sitting in the index will be swept into the next commit made by *any*
   concurrent sibling task's postflight. This makes "stage then commit atomically, never across a
   phase boundary" a hard requirement rather than a stylistic preference.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (no `roadmap_path` provided; `roadmap_flag` not set).

## Goals & Non-Goals

**Goals**:
- Add the 9 researched ephemeral patterns to the repo-root `.gitignore`, with a comment block that
  explains the rationale using durable anchors only.
- Untrack all 198 currently-tracked instances via `git rm --cached`, leaving every working-tree
  file byte-for-byte intact.
- Prove the patterns match before untracking (via `git check-ignore -v --no-index`) and prove the
  untracking is complete and non-destructive afterward.

**Non-Goals**:
- **No script edits.** `orchestrator-postflight.sh` (and its source under
  `agent-system/extensions/core/scripts/`) is owned by a parallel task and MUST NOT be touched.
  The Stage 9/Stage 10 ordering is diagnosis context here, not a work item.
- **No new scripts.** This task is `.gitignore` edits plus `git rm --cached` index operations only.
- **No on-disk deletion of any file**, including the orphaned archived lock. Untracking it is
  correct; releasing/removing it is a separate judgment call the research explicitly declined to
  force.
- **No changes to** `specs/events.jsonl`, `.gitkeep`, `.meta-return.json`,
  `.meta-builder-return.json`, or the `handoffs/*.md` continuation-handoff family (a deliberately
  durable, timestamped artifact family that must not be conflated with `.orchestrator-handoff.json`).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Concurrent sibling postflight (880/882/884) sweeps staged deletions into its own commit, because postflight's `git commit` has no pathspec | H | M | Stage and commit atomically within one phase; never end a phase with a dirty index. Inspect `git diff --cached --name-only` immediately before each commit and STOP if it contains anything unexpected. |
| Pattern verification silently reports zero matches, implementer wrongly concludes patterns are broken and "fixes" working patterns | M | H | Mandate `git check-ignore -v --no-index` for all tracked-file checks (verified necessary at plan time). Phase 1 asserts a non-empty result. |
| `git rm --cached` over-matches and untracks a durable artifact (`events.jsonl`, `.gitkeep`, report/plan files) | H | L | Enumerate to a reviewable manifest first, assert the count is exactly 198, and grep-assert the manifest contains no `events.jsonl` / `.gitkeep` / `reports/` / `plans/` / `summaries/` path before running `git rm`. |
| Working-tree files accidentally deleted (`git rm` without `--cached`) | H | L | `--cached` is mandatory in every invocation; Phase 3 re-asserts on-disk existence of a sample including the live 860 lock. |
| Manifest written into the task dir gets committed by postflight's wholesale `task_dir/` staging | L | M | Write the manifest to the session scratchpad, never under `specs/883_*/`. |
| Unrelated dirty files (`.claude-extensions.json`, two `lua/` files) get committed | M | L | They are unstaged (` M`); a bare `git commit` cannot include them. Never use `git add -A` / `git commit -am` (both forbidden by git-workflow.md). |
| The live 860 lock stops working after untracking | M | L | `git rm --cached` never touches the working tree; the lock directory and `holder.json` remain on disk and functional. Asserted in Phase 3. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel. This plan is fully sequential: patterns must
exist and be proven to match before anything is untracked, and the audit must observe the
post-untrack state.

---

### Phase 1: Add Ephemeral Patterns to `.gitignore` [COMPLETED]

**Goal**: The repo-root `.gitignore` carries all 9 patterns, each proven to match its intended
targets, committed as a standalone green milestone.

**Tasks**:
- [x] Read the repo-root `/home/benjamin/.config/nvim/.gitignore` (31 lines; the existing ephemeral
      block is lines 18-19: `**/.postflight-pending`, `**/.git-snapshot-marker`). *(completed)*
- [x] Insert the new block immediately after line 19, keeping the ephemeral entries contiguous: *(completed)*
  ```
  # Ephemeral orchestration session state: per-dispatch scratch, mutex directories,
  # and loop guards. All are runtime-only — each is overwritten or removed within a
  # single orchestrate run (see .claude/docs/architecture/handoff-schema.md, which
  # specifies .orchestrator-handoff.json as "runtime; not checked in" and overwritten
  # every dispatch cycle). They are ignored here because the postflight commit stage
  # runs before its own marker-cleanup stage, so anything left unignored is swept into
  # a commit mid-lifecycle.
  **/.lock/
  **/.orchestrator-handoff.json
  **/.orchestrator-loop-guard
  **/.continuation-loop-guard
  **/.orchestrator-churn-state.json
  **/.postflight-loop-guard
  **/.orchestrator-multi-state.json
  **/.return-meta-*.json
  **/.events.lock
  # Note: specs/events.jsonl is deliberately NOT ignored — it is an append-only durable
  # store (see .claude/context/formats/events-format.md). Do not add it here.
  ```
- [x] Confirm no comment text contains a task-number citation (`task N`, `tasks N-M`, `(task N)`)
      — `.gitignore` is outside `specs/**` and is bound by no-task-references-in-deliverables.md. *(completed)*
- [x] Verify each pattern matches a real target, using `--no-index` (REQUIRED — without it every
      check returns exit=1 with no output because the targets are still tracked):
  ```bash
  cd /home/benjamin/.config/nvim
  for p in \
    specs/883_x/.orchestrator-handoff.json \
    specs/860_enforce_plan_compliance_rule/.lock/holder.json \
    specs/859_fix_task_order_topic_case_indentation/.orchestrator-loop-guard \
    specs/archive/543_convert_opencode_json_to_computed_artifact/.continuation-loop-guard \
    specs/883_x/.orchestrator-churn-state.json \
    specs/883_x/.postflight-loop-guard \
    specs/.orchestrator-multi-state.json \
    specs/.return-meta-multi.json \
    specs/archive/609_refactor_team_research_context_protection/.return-meta-02.json \
    specs/.events.lock ; do
    git check-ignore -v --no-index "$p" || echo "NO MATCH: $p"
  done
  ```
  Every line must report a `.gitignore:{line}:{pattern}` match; any `NO MATCH` is a hard stop.
- [x] Assert the durable exclusions are NOT matched (negative control — each must print `OK`): *(completed)*
  ```bash
  for p in specs/events.jsonl specs/.gitkeep specs/.meta-return.json \
           specs/883_x/handoffs/phase-1-handoff-20260715T000000Z.md ; do
    git check-ignore -q --no-index "$p" && echo "OVER-MATCH: $p" || echo "OK: $p"
  done
  ```
- [x] Stage and commit atomically, asserting the staged set is exactly `.gitignore`: *(completed: commit 464f400bc)*
  ```bash
  git add .gitignore
  git diff --cached --name-only   # MUST print exactly: .gitignore
  git commit -m "task 883 phase 1: gitignore ephemeral orchestration session state

  Session: sess_1784155855_f90cfe_883"
  ```
  If `git diff --cached --name-only` shows anything besides `.gitignore`, STOP and reconcile —
  a concurrent sibling postflight may have staged content.

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `/home/benjamin/.config/nvim/.gitignore` — add a 9-pattern block plus rationale comments after
  line 19. This file is at the repo root and is tracked; it is the correct edit target as-is (no
  source-tree remap applies, unlike the gitignored `.claude/` deploy tree).

**Verification**:
- All 10 positive `check-ignore --no-index` probes report a matching pattern.
- All 4 negative-control probes report `OK`.
- `git log -1 --stat` shows a single-file commit touching only `.gitignore`.
- `git status --porcelain` shows a clean index (no staged entries carried into Phase 2).

---

### Phase 2: Untrack the 198 Tracked Instances [COMPLETED]

**Goal**: All 198 tracked ephemeral files are removed from the index and the removal is committed,
with every working-tree file left intact.

**Tasks**:
- [ ] Enumerate targets into a reviewable manifest in the **session scratchpad** (never under
      `specs/883_*/`, which postflight stages wholesale):
  ```bash
  cd /home/benjamin/.config/nvim
  MANIFEST=/tmp/claude-1000/-home-benjamin--config-nvim/5fc242af-eb58-4f68-aea9-f410205426c1/scratchpad/untrack-manifest.txt
  git ls-files \
    | grep -E '(^|/)(\.orchestrator-handoff\.json|\.orchestrator-loop-guard|\.continuation-loop-guard|\.postflight-loop-guard|\.orchestrator-churn-state\.json|\.orchestrator-multi-state\.json|\.return-meta\.json|\.return-meta-[^/]*\.json|\.events\.lock)$|(^|/)\.lock/holder\.json$' \
    > "$MANIFEST"
  wc -l < "$MANIFEST"    # MUST be exactly 198
  ```
  *(completed)*
- [x] Assert the manifest count is exactly **198**. Any other number is a hard stop — investigate
      before proceeding (a sibling task may have committed new ephemeral files mid-batch; if the
      count grew by a plausible amount and every added path matches the intended patterns, that is
      acceptable — but confirm explicitly, never assume). *(deviation: altered — actual count 202,
      not 198; +4 from live sibling task 880/884 activity (+2 .orchestrator-handoff.json, +2
      .lock/holder.json), all within intended pattern categories, confirmed not assumed)*
- [x] Assert the manifest contains no durable artifact (each grep must return nothing):
  ```bash
  grep -E '(events\.jsonl|\.gitkeep|/reports/|/plans/|/summaries/|/handoffs/|\.meta-return\.json|\.meta-builder-return\.json)' "$MANIFEST" \
    && echo "ABORT: manifest contains durable artifacts" || echo "OK: manifest is clean"
  ```
  *(completed)*
- [x] Assert no path contains whitespace (the newline-delimited manifest assumes this):
  ```bash
  grep -E '[[:space:]]' "$MANIFEST" && echo "ABORT: whitespace in paths" || echo "OK"
  ```
  *(completed)*
- [x] Untrack, index-only. `--cached` is mandatory — omitting it deletes working-tree files:
  ```bash
  git rm --cached --quiet --pathspec-from-file="$MANIFEST"
  ```
  Note `specs/876_wire_preflight_into_orchestrate_paths/.lock/holder.json` is already deleted on
  disk (` D` in `git status`); `git rm --cached` resolves its index entry cleanly. *(completed)*
- [x] Verify the staged set before committing:
  ```bash
  git diff --cached --name-only | wc -l         # MUST be 198
  git diff --cached --name-only | sort > /tmp/staged.txt
  sort "$MANIFEST" > /tmp/expected.txt
  diff /tmp/staged.txt /tmp/expected.txt && echo "OK: staged set matches manifest exactly"
  ```
  Any divergence is a hard stop — do NOT commit a superset. *(completed: 202 staged, matched
  manifest exactly)*
- [x] Commit **immediately** (do not end this phase with a dirty index — postflight's pathspec-less
      `git commit` means any sibling task's postflight would otherwise sweep these 198 staged
      deletions into its own commit):
  ```bash
  git commit -m "task 883 phase 2: untrack ephemeral orchestration session state

  Session: sess_1784155855_f90cfe_883"
  ```
  *(completed: commit cae265fbc, 202 files changed, 5129 deletions, 0 content modifications)*

**Timing**: 40 minutes

**Depends on**: 1

**Files to modify**:
- None on disk. This phase performs index-only mutations; the 198 working-tree files are
  deliberately preserved.

**Verification**:
- Manifest count is exactly 198 and contains zero durable artifacts.
- Staged set diffs clean against the manifest.
- `git log -1 --stat` shows 198 deletions and zero content modifications.
- `git status --porcelain` shows no staged entries remaining.

---

### Phase 3: Post-Untrack Audit [COMPLETED]

**Goal**: Prove the untracking is complete, non-destructive, and that in-flight batch state is
unharmed.

**Tasks**:
- [x] Assert zero ephemeral files remain tracked (must print 0):
  ```bash
  git ls-files | grep -E '(^|/)(\.orchestrator-handoff\.json|\.orchestrator-loop-guard|\.continuation-loop-guard|\.postflight-loop-guard|\.orchestrator-churn-state\.json|\.orchestrator-multi-state\.json|\.return-meta\.json|\.return-meta-[^/]*\.json|\.events\.lock)$|(^|/)\.lock/holder\.json$' | wc -l
  ```
  *(completed: printed 0)*
- [x] Assert working-tree files survived — `git rm --cached` must not have removed anything from
      disk. Spot-check the live lock and a sample handoff:
  ```bash
  test -f specs/860_enforce_plan_compliance_rule/.lock/holder.json && echo "OK: live 860 lock intact"
  test -f specs/archive/856_scrub_task_number_leaks_from_wrapper_contracts/.lock/holder.json && echo "OK: archived 856 lock intact on disk"
  test -f specs/859_fix_task_order_topic_case_indentation/.orchestrator-loop-guard && echo "OK: 859 loop guard intact"
  ```
  *(completed: all three OK)*
- [x] Assert the durable exclusions are still tracked (must each print a path):
  ```bash
  git ls-files | grep -E '(\.gitkeep|\.meta-return\.json|\.meta-builder-return\.json)$' | head
  ```
  `specs/events.jsonl` remains untracked-but-committable by design; confirm it is NOT ignored:
  ```bash
  git check-ignore -q --no-index specs/events.jsonl && echo "REGRESSION: events.jsonl ignored" || echo "OK: events.jsonl not ignored"
  ```
  *(completed)*
- [x] Assert the in-flight batch is undisturbed: `specs/.orchestrator-multi-state.json` and
      `specs/.events.lock` still exist on disk and now resolve as ignored rather than untracked:
  ```bash
  test -f specs/.orchestrator-multi-state.json && git check-ignore -v specs/.orchestrator-multi-state.json
  test -f specs/.events.lock && git check-ignore -v specs/.events.lock
  ```
  (`--no-index` is unnecessary here — these paths are untracked, so the plain form now works.)
  *(completed)*
- [x] Confirm the unrelated pre-existing working-tree edits were never committed:
  ```bash
  git status --porcelain | grep -E '(\.claude-extensions\.json|lua/neotex)'
  ```
  These must still appear as unstaged ` M` — if they were committed, that is an over-staging
  regression to report. *(completed: all three still unstaged ` M`)*

**Timing**: 20 minutes

**Depends on**: 2

**Files to modify**:
- None. Read-only audit.

**Verification**:
- Tracked ephemeral count is 0.
- All on-disk spot-checks pass.
- Durable exclusions still tracked; `events.jsonl` still not ignored.
- Unrelated `lua/` and `.claude-extensions.json` edits remain uncommitted.

---

## Testing & Validation

- [x] `git ls-files | grep -cE '<ephemeral pattern union>'` returns 0. *(completed)*
- [x] Every one of the 10 positive `git check-ignore -v --no-index` probes reports a match. *(completed)*
- [x] All 4 negative-control probes (`events.jsonl`, `.gitkeep`, `.meta-return.json`,
      `handoffs/*.md`) report `OK` — no over-match. *(completed)*
- [x] `git log -2 --stat` shows exactly two commits: one `.gitignore`-only, one with 202 pure
      deletions and no content changes. *(deviation: altered — 202 deletions, not 198; see Phase 2
      count deviation)*
- [x] Working tree spot-checks confirm the live 860 lock, the archived 856 lock, and the 859 loop
      guard all still exist on disk. *(completed)*
- [x] `git status --porcelain` contains no staged entries and still shows the three unrelated
      pre-existing modifications as unstaged. *(completed)*
- [x] A fresh ephemeral file is ignored end-to-end:
      `touch specs/883_*/.orchestrator-loop-guard && git status --porcelain | grep -c orchestrator-loop-guard` returns 0. *(completed)*

## Artifacts & Outputs

- `/home/benjamin/.config/nvim/.gitignore` — 9 new patterns plus a rationale comment block
  (task-number-free per no-task-references-in-deliverables.md).
- Two git commits: `task 883 phase 1: gitignore ephemeral orchestration session state` and
  `task 883 phase 2: untrack ephemeral orchestration session state`.
- `specs/883_gitignore_and_untrack_ephemeral_session_state/summaries/01_gitignore-untrack-ephemeral-state-summary.md`
- Scratchpad-only (not an artifact, not committed): `untrack-manifest.txt`.

## Rollback/Contingency

Both phases are individually revertable and neither touches file content, so rollback is
low-risk:

- **Phase 1 only**: `git revert <phase-1-sha>` restores the previous `.gitignore`. Nothing else
  is affected.
- **Phase 2**: `git revert <phase-2-sha>` restores all 198 index entries from the working-tree
  copies, which `--cached` left intact. Because the deletions are index-only and the files still
  exist on disk, the revert is lossless.
- **Both**: revert in reverse order (phase 2, then phase 1).
- **If a hard stop fires mid-phase** (unexpected staged set, wrong manifest count): run
  `git restore --staged <paths>` to unstage — this is explicitly safe and NOT blocked by the
  destructive-git guard, since `--staged` only unstages and never discards working-tree changes.
  Do not use `git reset --hard` or `git checkout --` here: the tree carries unrelated uncommitted
  edits, and those commands are forbidden on a dirty tree without a fresh `git-snapshot.sh` first.

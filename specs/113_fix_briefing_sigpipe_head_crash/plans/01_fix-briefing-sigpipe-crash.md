# Implementation Plan: Task #113

- **Task**: 113 - Fix the SIGPIPE crash that makes repo-mode `--lit` briefing fail outright
- **Status**: [COMPLETED]
- **Effort**: 1.75 hours
- **Dependencies**: None. Sequenced BEFORE the sibling task that edits this same file's
  global-mode query construction; that sibling's edits have already landed, so the line
  numbers below reflect the file's current 710-line state.
- **Research Inputs**: specs/113_fix_briefing_sigpipe_head_crash/reports/01_sigpipe-head-crash-fix.md
- **Artifacts**: plans/01_fix-briefing-sigpipe-crash.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md;
  .claude/rules/source-store-deploy-boundary.md; .claude/rules/git-workflow.md
- **Type**: meta

## Overview

`agent-system/extensions/literature/scripts/literature-briefing.sh` runs under
`set -euo pipefail` (line 63) and, at two sites in repo mode's `parent_entry` lookup
(lines 238-241 and 245-247), pipes a **whole-entry JSON object** from `jq` into `head -1`.
Without `-c`, jq pretty-prints the object across many lines; `head -1` consumes the opening
`{` and closes the pipe; jq receives SIGPIPE; `pipefail` promotes the pipeline status to 141
and `set -e` kills the script. The wrapper surfaces only `[lit] briefing generation failed
(exit 141)`. The fix replaces the pipe with a jq-internal bound — `jq -c 'first(.entries[] |
select(...))'` — at both sites, removing `head` from the pipeline entirely so no SIGPIPE is
structurally possible there regardless of entry size, and stopping jq's scan at the first match
instead of streaming every match into a discarded pipe. Done when repo-mode briefing exits 0
against the observed failing sub-index and emits byte-identical per-document content to the
pre-fix baseline for every document the pre-fix run managed to process.

### Research Integration

The research report (`reports/01_sigpipe-head-crash-fix.md`) contributes four findings this plan
builds on directly:

1. **Corrected line numbers.** The task description's `:227-230` / `:234-236` are stale; the
   sibling global-mode task's edits shifted the crash sites to **`:238-241`** and **`:245-247`**.
   Verified again at plan time: `grep -n parent_entry` returns exactly `238, 243, 245, 250`.
2. **Scope-reducing finding.** `parent_entry` is *never parsed for field content* anywhere
   downstream — the only four references in the file are the two assignments and the two
   `[ -z "$parent_entry" ]` emptiness checks that immediately follow. Every displayed field
   (`title`, `authors_raw`, `year`, `chunk_count`, `total_tokens`, `parent_path`) is extracted by
   *separate*, already-scalar `jq` calls keyed by `$doc_id`. Only **presence/absence of a match**
   must be preserved, not byte-for-byte JSON content or key order.
3. **Both fix options validated live.** Option 1 (`-c` alone) removes the crash; Option 2
   (`first(...)`, no `head`) removes it *and* the fragile idiom. `first(...)` over an empty stream
   emits nothing and exits 0 under `set -euo pipefail` — no `|| true` guard needed, and the
   existing `[ -z ... ]` fallback keeps working unmodified. Option 2 is the chosen direction.
4. **Full `| head -1` audit.** 10 sites total; the 8 non-crash sites (`:175, :262, :266, :270,
   :286, :292, :300, :321`) all extract a jq scalar and are confirmed unaffected.

### Prior Plan Reference

No prior plan. This is the first plan for this task.

### Roadmap Alignment

No ROADMAP.md found at `specs/ROADMAP.md`. No roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Eliminate the exit-141 SIGPIPE crash at both repo-mode `parent_entry` extraction sites by
  bounding the result inside jq (`first(...)`, `-c`) instead of truncating a pipe with `head -1`.
- Preserve the two behaviors the task description marks PRESERVE EXACTLY: the
  `(.id // .doc_id)` stub-entry tolerance at both sites, and the two-step strict-then-unfiltered
  lookup structure (they must remain two separate queries, not be collapsed into one).
- Prove, by diff against a pre-fix baseline, that the fix changes *which entry is selected* for
  no document.
- Close verification bar #4: confirm no `jq ... | head -1` site remains in the file where the jq
  program can emit a multi-line value.
- Verify end-to-end against the actual observed failing case:
  `~/Projects/Logos/Theory/specs/literature-index.json` (present on this machine) against the
  11,545-entry global index at `~/Projects/Literature/index.json`, which contains the
  crash-triggering `horty_2001_agency-and-deontic-logic` entry (confirmed present at plan time).

**Non-Goals**:
- Editing `.claude/scripts/literature-briefing.sh`. `.claude/**` is a gitignored, disposable
  deploy artifact regenerated from the source store; the only edit target is
  `agent-system/extensions/literature/scripts/literature-briefing.sh`. The two copies are
  byte-identical today (verified at plan time via `diff -q`), and will drift until the next
  deploy/sync — that drift is expected and is not this task's problem to reconcile.
- Removing or weakening `set -euo pipefail`. Both flags are load-bearing for the script's other
  failure handling (the `|| authors_raw=""`, `|| parent_tokens=0`, `|| { ...; total_tokens=0; }`
  guards at `:266`, `:286`, `:292` all depend on `set -e` propagating real failures).
- Fixing the `--global`-mode zero-segment FTS5 recall bug. Different failure, different sibling
  task, and this file must not be edited by both concurrently.
- Fixing the coverage-delta performance stall in `literature-lit-flag-resolve.sh`. Different
  script, different task.
- Changing the `<!-- lit-coverage ... -->` marker semantics that `lit-stage4a-flow.md` greps to
  drive sparse re-prompting.
- Introducing a shared `jq_first` helper as a prerequisite. The research report explicitly
  declines to recommend it for two call sites in one file. The implementer may add one only if it
  demonstrably simplifies the actual diff.
- A repo-wide sweep for the same `jq | head` idiom in other extension scripts. The research
  report flags this as a worthwhile follow-up (`/fix-it`-style sweep, plus a possible
  `context/patterns/jq-pipeline-safety.md`), but it is out of scope here.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Fix changes which entry wins when a doc_id has both a parent and child/duplicate entries, violating the "identical briefing content" bar | H | L | `first(.entries[] \| select(...))` iterates `.entries[]` in the same source-array order `head -1` was truncating to; only the early-stop *mechanism* moves, not the selection order. Phase 1 captures a pre-fix baseline and Phase 4 diffs against it, so any selection change is caught mechanically rather than argued about. |
| Pre-fix crash is a pipe-buffer race and may not reproduce on demand, leaving the "before" state unproven | M | M | Do not gate on the flaky live repro. Phase 1 records whatever the live run does AND captures the deterministic mechanism repro (`bash -c 'set -euo pipefail; jq -n "{d:[range(0;20000)]}" \| head -1'` -> 141). A non-reproducing live run is a recorded observation, not a blocker. The horty entry serializes to only ~8.8KB pretty-printed, well under the 64KB pipe buffer, so the live race may well not fire on this machine. |
| Collapsing the two-step lookup into one query while "simplifying" | H | L | Phase 2 tasks state the two-query structure explicitly; Phase 2 verification greps for two distinct `parent_entry=$(jq` assignments and two `[ -z "$parent_entry" ]` checks. |
| Dropping `-r` changes downstream behavior | L | L | Research confirmed `parent_entry` is only emptiness-tested, never string-parsed. `-c` alone is correct; `-rc` is functionally equivalent here. Phase 2 verification re-runs `grep -n parent_entry` and confirms the reference count is still exactly 4. |
| Concurrent edit to this file by the sibling global-mode task corrupts the diff | M | L | Do not run the two tasks concurrently. Phase 1 records `git rev-parse HEAD` and `git status --short` for this file; Phase 2 aborts if the file has unexpected uncommitted changes. |
| Local `specs/literature-index.json` is absent in this repo, so repo mode cannot be exercised here | M | H (already confirmed absent) | Phases 1 and 4 run the script from the `~/Projects/Logos/Theory` repo (confirmed present at plan time), which is the *observed failing case*, not a synthetic substitute. Invoke the source-store script by absolute path so the untouched `.claude/` deploy copy is never the thing under test. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Capture Pre-Fix Baseline and Reproduction Evidence [COMPLETED]

**Goal**: Record the pre-fix behavior of repo-mode briefing against the observed failing case, so
Phase 4's "identical content" comparison has a real baseline rather than an assertion. No code
changes in this phase.

**Tasks**:
- [x] Record the starting state: `git rev-parse HEAD` and
      `git status --short agent-system/extensions/literature/scripts/literature-briefing.sh`.
      Confirm the file has no unexpected uncommitted modifications. *(completed: HEAD
      cfbe27b3caf1a8f6763d84f73250d690a4d8b6c2, target file clean/no diff)*
- [x] Confirm the crash-site line numbers are still `238-241` and `245-247` via
      `grep -n parent_entry agent-system/extensions/literature/scripts/literature-briefing.sh`
      (expect exactly four hits: `238, 243, 245, 250`). If they have shifted, re-derive them and
      record the correction before proceeding. *(completed: confirmed exactly 238, 243, 245, 250 —
      no shift)*
- [x] Confirm `~/Projects/Literature/index.json` and
      `~/Projects/Logos/Theory/specs/literature-index.json` both exist, and that the global index
      contains `horty_2001_agency-and-deontic-logic`. *(completed: both present; horty entry found,
      892 grep hits in the 11,545-entry global index)*
- [x] Run the pre-fix script from the Logos/Theory repo, capturing stdout, stderr, and exit code
      to scratch files (do not discard stderr — the `2>/dev/null` inside the script hides jq's
      diagnostic, but the wrapper-level exit code is the signal):
      `cd ~/Projects/Logos/Theory && bash /home/benjamin/.config/nvim/agent-system/extensions/literature/scripts/literature-briefing.sh --query "game theory self-play" > BASELINE.out 2> BASELINE.err; echo $?`
      *(deviation: altered — see phase notes; the literal command never reaches repo mode because
      `literature-briefing.sh` resolves `PROJECT_ROOT` from its own on-disk location
      (`$SCRIPT_DIR/../..`), not from `$PWD`, so the source-store copy invoked by absolute path
      always looks for `agent-system/extensions/specs/literature-index.json` regardless of cwd —
      that path doesn't exist, so the script silently takes its documented
      sub-index-missing/exit-0/empty-stdout branch without ever reaching the `parent_entry` sites.
      Used an equivalent scratch harness mirroring the real per-repo `.claude/scripts/` deploy
      layout (script content + real sub-index content copied in, real live global index used
      unmodified) to genuinely exercise the crash sites — see progress/phase-1-progress.json.
      Result: live SIGPIPE reproduced, exit 141, BASELINE.out/err both 0 bytes)*
- [x] Record the observed exit code. **Either outcome is acceptable evidence**: 141 confirms the
      live crash; 0 means the pipe-buffer race did not fire on this machine's data — record that
      fact and continue. Do not treat a non-reproducing run as a blocker. *(completed: 141 — the
      live crash DID reproduce via the scratch-harness invocation, contra the plan's risk note that
      it might not fire on this machine)*
- [x] Capture the deterministic mechanism reproduction independently, as the authoritative "before"
      evidence: `bash -c 'set -euo pipefail; jq -n "{a:1,d:[range(0;20000)]}" | head -1'; echo $?`
      (expect 141), and its `-c` counterpart (expect 0). *(completed: 141 and 0 respectively, as
      expected)*
- [x] Preserve `BASELINE.out` / `BASELINE.err` and the recorded exit code in the session scratchpad
      for Phase 4. Do not commit them into the repo. *(completed: preserved in session scratchpad,
      not committed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the crash sites are at lines `238-241` and `245-247` and
that `parent_entry` has exactly 4 references. Confirm at implementation time with
`grep -n parent_entry` on the source-store file before relying on either number; if the counts or
line numbers differ, correct them in the phase record rather than proceeding on the stale figures.

**Files to modify**:
- None. This phase is read-and-record only; all outputs go to the session scratchpad.

**Verification**:
- `BASELINE.out` exists and its size is recorded (empty is a valid baseline if the script died
  before emitting).
- The recorded pre-fix exit code is written down explicitly (141 or 0, whichever was observed).
- The deterministic `jq | head -1` harness returned 141 and its `-c` counterpart returned 0.

---

### Phase 2: Replace Both Crash Sites With jq-Internal `first(...)` [COMPLETED]

**Goal**: Remove `head` from both `parent_entry` extraction pipelines by bounding the result
inside jq, eliminating the SIGPIPE structurally while preserving the `(.id // .doc_id)` tolerance
and the two-step strict-then-fallback lookup verbatim.

**Tasks**:
- [x] Edit **only** `agent-system/extensions/literature/scripts/literature-briefing.sh` (source
      store). Do not touch `.claude/scripts/literature-briefing.sh`. *(completed)*
- [x] Replace the site at `:238-241` with:
      `parent_entry=$(jq -c --arg id "$doc_id" 'first(.entries[] | select((.id // .doc_id) == $id and (.parent_doc == null or .parent_doc == "")))' "$GLOBAL_INDEX" 2>/dev/null)`
      keeping the existing multi-line formatting and the preceding explanatory comment about the
      stub-shaped-entry contract. *(completed)*
- [x] Replace the fallback site at `:245-247` with:
      `parent_entry=$(jq -c --arg id "$doc_id" 'first(.entries[] | select((.id // .doc_id) == $id))' "$GLOBAL_INDEX" 2>/dev/null)`
      keeping the `# Try without parent_doc filter (older entries may lack the field)` comment.
      *(completed)*
- [x] Do NOT add `|| true` / `|| :` guards — `first(...)` over an empty stream exits 0 with no
      output, confirmed in research. *(completed: no guards added)*
- [x] Do NOT collapse the two queries into one; do NOT alter the `if [ -z "$parent_entry" ]`
      checks at `:243` and `:250`. *(completed: two-step structure intact, `-z` checks unchanged)*
- [x] Do NOT modify `set -euo pipefail` at line 63. *(completed: unchanged)*
- [x] Run `bash -n` on the edited file to confirm it still parses. *(completed: exits 0)*
- [x] Commit this single-file change per the commit-per-green-substep mandate once `bash -n` and
      the greps below pass. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly **2** call sites need changing and that no other
line in the file requires modification. Confirm at implementation time: after the edit,
`grep -c 'head -1'` must drop from 10 to 8, and `git diff --stat` must show exactly one file with
a change confined to the `:238-247` region.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-briefing.sh` - replace the two
  `parent_entry` jq-into-`head -1` pipelines with `jq -c 'first(...)'`; no other change.

**Verification**:
- `bash -n agent-system/extensions/literature/scripts/literature-briefing.sh` exits 0.
- `grep -c "head -1"` on the file returns **8** (down from 10).
- `grep -n "parent_entry"` still returns exactly **4** hits (two assignments, two `-z` checks) —
  structure preserved.
- `grep -c "first(.entries\[\]"` returns **2**.
- `grep -n "(.id // .doc_id)"` still shows the tolerance present at both new sites.
- `grep -n "set -euo pipefail"` still shows line 63 unchanged.
- `git diff --stat` shows exactly one modified file.

---

### Phase 3: Audit Remaining `| head -1` Sites [COMPLETED]

**Goal**: Close verification bar #4 — confirm no `jq ... | head -1` site remains in the file where
the jq program can emit a multi-line value. This is an audit, not a refactor.

**Tasks**:
- [x] Enumerate every remaining `| head -1` site with
      `grep -n "head -1" agent-system/extensions/literature/scripts/literature-briefing.sh`.
      *(completed: 8 sites found at :175, :261, :265, :269, :285, :291, :299, :320)*
- [x] For each, read the enclosing jq program and classify its result shape: scalar string,
      `tostring`-coerced number, joined string, or object/array. *(completed, see progress file
      phase-3-progress.json for the full per-site classification)*
- [x] Confirm each remaining site is scalar-only. The research report's expected classification
      (post-fix line numbers will shift slightly): `:175` `.provenance_fidelity // empty`;
      `:262` `.title // "Unknown Title"`; `:266` joined `.authors`; `:270` `.year | tostring`;
      `:286` and `:292` `.token_count // 0`; `:300` `.path // ""`; `:321` `.relevance // ""`.
      *(completed: all 8 confirmed scalar-only; actual post-fix line numbers were :175, :261,
      :265, :269, :285, :291, :299, :320 -- close to but not identical to the research report's
      estimate, re-verified directly rather than trusted)*
- [x] If any site is found to emit an object or array, treat it as a newly discovered crash site
      and apply the same `first(...)` / `-c` fix, then re-run Phase 2's verification greps.
      *(completed: not applicable -- no such site found)*
- [x] Record the audit result (site count and per-site classification) in the phase notes for the
      implementation summary. Do not write a separate report file. *(completed: recorded in
      progress/phase-3-progress.json)*

**Timing**: 0.25 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts **8** remaining `| head -1` sites, all scalar-emitting and
all safe. Confirm at implementation time by counting `grep -n "head -1"` hits and reading each
enclosing jq program individually — do not accept the count or the safety classification from the
research report without re-reading the code, since Phase 2's edit shifts every line number below
`:247`.

**Files to modify**:
- Expected: none. Only if the audit finds a genuine object-emitting site does
  `agent-system/extensions/literature/scripts/literature-briefing.sh` change again.

**Verification**:
- Every remaining `| head -1` site is individually classified in the phase notes with its jq
  expression and result shape.
- Zero sites remain where the jq program can emit an object or array.
- If no site required a change, `git diff` for this phase is empty and that is the expected result.

---

### Phase 4: End-to-End Verification Against the Observed Failing Case [COMPLETED]

**Goal**: Satisfy verification bars #1, #2, and #3 — the fixed script completes with exit 0 and a
non-empty briefing against the real 52-entry Logos/Theory sub-index, and the emitted content is
identical to the Phase 1 baseline for every document the pre-fix run processed.

**Tasks**:
- [x] Re-run the same command Phase 1 ran, against the same repo and the same query, invoking the
      **source-store** script by absolute path:
      `cd ~/Projects/Logos/Theory && bash /home/benjamin/.config/nvim/agent-system/extensions/literature/scripts/literature-briefing.sh --query "game theory self-play" > FIXED.out 2> FIXED.err; echo $?`
      *(deviation: altered — same root cause as Phase 1's task 1.4: the literal command doesn't
      reach repo mode. Re-used the Phase 1 scratch harness, re-synced with the fixed source-store
      script, and ran the equivalent invocation there instead. Result: exit 0, FIXED.out 18774
      bytes)*
- [x] Confirm exit code is **0** (bar #1). *(completed: exit 0)*
- [x] Confirm `FIXED.out` is non-empty and contains actual briefing content, not just a header
      (bar #1). *(completed: 52 resolved documents listed with title/authors/chunk/token metadata,
      not just a header)*
- [x] Diff against the baseline: `diff BASELINE.out FIXED.out`. Every line present in
      `BASELINE.out` must appear identically in `FIXED.out`; `FIXED.out` may contain *additional*
      documents (the ones the pre-fix run died before reaching). A changed or reordered line for a
      document present in both is a **failed implementation** (bar #2). If the Phase 1 baseline
      was empty because the script died immediately, record that and rely on the per-document
      selection argument plus the Phase 2 structural greps instead. *(completed: Phase 1's
      authoritative baseline was 0 bytes — died immediately at exit 141 — so this falls under the
      explicit empty-baseline fallback clause; diff shows 238 pure additions, zero modified/removed
      shared lines, and Phase 2's structural greps plus the selection-order argument in the Risks
      table stand as the bar #2 evidence)*
- [x] Confirm the run covers `horty_2001_agency-and-deontic-logic` specifically (bar #3): grep
      `FIXED.out` for that doc_id, or if the chosen query does not surface it, re-run with a query
      that does and confirm exit 0 and a non-empty briefing for that document. *(completed: present
      as entry #48/52, 296 chunks, ~124241 tokens — this is the exact doc_id that crashed the Phase
      1 baseline run)*
- [x] Confirm the `<!-- lit-coverage ... -->` marker is still present and well-formed in
      `FIXED.out`, since `lit-stage4a-flow.md` greps it to drive sparse re-prompting. *(completed:
      `<!-- lit-coverage mode=repo seg_count=52 sparse=false threshold=3 requested=52 resolved=52
      skipped=0 skip_rate=0 delta_checked=true delta_gap=240 delta_candidates=73 -->`)*
- [x] Run a second repo-mode invocation with an unrelated query to confirm the fix is not
      query-specific. *(completed: `--query "separation logic frame rule"`, exit 0, 237 output
      lines)*
- [x] Confirm `.claude/scripts/literature-briefing.sh` was **not** modified by this task
      (`git status` plus a `diff` against the source store will now show expected drift — the
      deploy copy is stale until the next sync, which is correct and out of scope). *(completed:
      `git status --short .claude/scripts/literature-briefing.sh` returns no output — untouched)*

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: full

**Files to modify**:
- None. Verification only; all outputs go to the session scratchpad.

**Verification**:
- Exit code 0 on the repo-mode run against `~/Projects/Logos/Theory` (bar #1).
- Non-empty briefing emitted (bar #1).
- `diff BASELINE.out FIXED.out` shows only additions, never modifications to shared lines (bar #2).
- `horty_2001_agency-and-deontic-logic` is covered by at least one successful run (bar #3).
- `<!-- lit-coverage` marker present and well-formed.
- Second query also exits 0.
- No hand-edit landed in `.claude/`.

---

## Testing & Validation

- [x] `bash -n agent-system/extensions/literature/scripts/literature-briefing.sh` exits 0.
- [x] `grep -c "head -1"` on the file returns 8 (was 10).
- [x] `grep -n "parent_entry"` returns exactly 4 hits — the two-step lookup structure is intact.
- [x] `(.id // .doc_id)` tolerance present at both rewritten sites.
- [x] `set -euo pipefail` at line 63 unchanged.
- [x] Repo-mode run against `~/Projects/Logos/Theory` exits 0 and emits a non-empty briefing.
      *(via the equivalent scratch harness reproducing that repo's real sub-index content and the
      real live global index — see Phase 1/4 deviations)*
- [x] `diff BASELINE.out FIXED.out` contains no modified shared lines. *(baseline was 0 bytes; only
      additions, per the plan's own empty-baseline fallback clause)*
- [x] `horty_2001_agency-and-deontic-logic` covered by a successful run.
- [x] `<!-- lit-coverage ... -->` marker semantics unchanged.
- [x] Every remaining `| head -1` site individually classified as scalar-emitting.
- [x] Only `agent-system/extensions/literature/scripts/literature-briefing.sh` modified; nothing
      hand-written into `.claude/`.

## Artifacts & Outputs

- `agent-system/extensions/literature/scripts/literature-briefing.sh` — two `parent_entry`
  extraction sites rewritten to `jq -c 'first(...)'`, `head` removed from both pipelines.
- `specs/113_fix_briefing_sigpipe_head_crash/summaries/01_{short-slug}-summary.md` — implementation
  summary recording: the observed pre-fix exit code, the baseline-vs-fixed diff result, the
  per-site `| head -1` audit classification, and confirmation of each of the four verification bars.
- Scratchpad-only (not committed): `BASELINE.out`, `BASELINE.err`, `FIXED.out`, `FIXED.err`.

## Rollback/Contingency

The change is confined to one file and one ~10-line region, so rollback is a single-commit revert.

- Before any intentional rollback, run `bash .claude/scripts/git-snapshot.sh 113` — the sanctioned
  snapshot path. Do **not** use `git checkout -- <path>` or `git reset --hard` on a dirty tree;
  both are blocked by `guard-destructive-git.sh` and forbidden by `.claude/rules/git-workflow.md`.
- To revert after the Phase 2 commit lands: `git revert <phase-2-sha>` restores the two original
  `jq ... | head -1` pipelines and, with them, the pre-existing crash. This is a safe revert — the
  fix adds no new state, no new file, and no schema or interface change.
- Contingency if Phase 4's diff shows a *changed* shared line (selection order altered): revert
  Phase 2 and fall back to **Option 1** — add `-c` to both existing `jq -r ... | head -1`
  pipelines without introducing `first(...)`. This is a strictly smaller diff that provably cannot
  change selection (it changes only jq's output formatting), eliminates the race, and still
  satisfies bars #1-#3; it leaves the fragile idiom in place, which is why it is the fallback
  rather than the primary.
- Contingency if `~/Projects/Logos/Theory/specs/literature-index.json` becomes unavailable: build a
  minimal fixture sub-index plus a synthetic global index containing one entry large enough to
  exceed the 64KB pipe buffer, and run repo mode against that. Record clearly in the summary that
  bar #3 was satisfied by fixture rather than by the observed corpus.

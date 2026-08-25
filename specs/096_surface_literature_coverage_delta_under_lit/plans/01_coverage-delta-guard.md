# Implementation Plan: Task #96

- **Task**: 96 - surface_literature_coverage_delta_under_lit
- **Status**: [COMPLETED]
- **Effort**: 6.5 hours
- **Dependencies**: literature global-index schema-unification (COMPLETE — `literature-doc-key.sh`
  and the `.id // .doc_id` tolerance pattern are already in place and sufficient for a
  doc_id-keyed delta computation; confirmed by research)
- **Research Inputs**: specs/096_surface_literature_coverage_delta_under_lit/reports/01_lit-coverage-delta-guard.md
- **Artifacts**: plans/01_coverage-delta-guard.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Under `--lit`, a per-repo sub-index that clears the absolute sparsity floor
(`LITERATURE_SPARSE_THRESHOLD`, default 3) is reported healthy and the global corpus is never
consulted again for the rest of the run — so a 37-entry sub-index against a 399-entry global
index resolves 37/37 with zero warnings while topically relevant, already-indexed global sources
stay invisible. This plan adds a **topic-scoped coverage-delta guard**: one shared computation
(global top-level docs matching the task's own filtered search terms that are absent from the
sub-index), wired into two existing sites — `literature-lit-flag-resolve.sh`'s `SUBINDEX_PRESENT`
branch (directive downgrade, reusing the existing `SPARSE_PROMPT_NEEDED` token) and
`literature-briefing.sh`'s repo-mode coverage marker/banner family (in-band advisory that reaches
autonomous runs). No new directive token, no new `AskUserQuestion` option set, no parallel
mechanism. Definition of done: the delta fires on a topic-scoped miss, stays silent on an
ordinary curated sub-index, is visible inside `lit_context` in `orchestrator_mode=true`, and is
covered by a fixture regression section alongside the existing Section G.

### Research Integration

The plan is built directly on `reports/01_lit-coverage-delta-guard.md`:

- The resolver's `SUBINDEX_PRESENT` branch never opens the global index once `entry_count >=
  threshold` — confirmed by code reading, and the site Phase 3 extends.
- Global `.entries` mixes top-level docs and chunk children (measured 414 total vs 204 with
  `parent_doc == null`); the delta MUST filter the global side to `parent_doc == null` or it
  overstates the gap ~2x. Phase 2 owns this filter; Phase 6 has a dedicated chunk-inflation
  control case.
- A bare ratio/absolute-gap trigger would fire on nearly every repo. The firing condition is
  compound and topic-scoped (Decision D1/D2 below).
- Reuse `literature-discover.sh`'s Tier 1 matcher (`filter_terms`, `term_matches`, stop-words,
  `MULTI_TERM_MATCH_THRESHOLD`) rather than writing a second matcher — Phase 1 extracts it to a
  sourceable helper so there is one implementation with two call sites.
- Surfacing is both: mandatory in-band banner (the only channel that reaches an autonomous agent
  — stderr does not) plus the existing four-option `AskUserQuestion` reused interactively.
- The claim-level "no counterpart exists" verifier is explicitly out of scope and named as a
  follow-up (see Non-Goals and `## Named Follow-Up`), not silently folded in or dropped.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md consultation was
performed.

## Design Decisions Settled by This Plan

The task description requires these four to be decided rather than left implicit.

**D1 — What counts as "materially less"**: a **compound** condition, both halves required.
1. *Cheap pre-filter*: `global_doc_count - subindex_entry_count >=
   LITERATURE_COVERAGE_GAP_MIN` (env-overridable, default `25`), where `global_doc_count`
   counts only `parent_doc == null` entries. Its only job is to skip the keyword work entirely
   when the global corpus is small or the sub-index is already comprehensive.
2. *Actionable trigger*: `missing_candidates >= LITERATURE_COVERAGE_DELTA_THRESHOLD`
   (env-overridable, default `1`), where `missing_candidates` are global top-level documents
   matching the query's filtered terms whose doc key is absent from the sub-index.
   Boundary is `>=` on both (documented explicitly, in contrast to the absolute-count sparse
   rule's strict `<`, so the two rules' asymmetry is intentional and recorded rather than a
   drift).

**D2 — Whole global index or keyword-matched only**: the *trigger* is keyword-matched only. The
whole-index doc count appears solely as the cheap pre-filter and as a reported context field in
the marker — it never fires the guard on its own. This is what prevents alarm fatigue on an
ordinary curated sub-index.

**D3 — Where the guard fires**: one shared computation (`literature-coverage-delta.sh`), two
wiring sites — the resolver's `SUBINDEX_PRESENT` branch (Phase 3) and `literature-briefing.sh`'s
repo mode (Phase 4). Both consume the same script; neither reimplements the matching.

**D4 — Interactive, advisory-in-prompt, or both**: **both**.
- Advisory-in-prompt is **mandatory and unconditional**: a `[COVERAGE DELTA - ...]` banner inside
  the `<literature-briefing>` block, in the same family as `[SPARSE COVERAGE ...]` /
  `[SKIPPED SOURCES ...]`, bounded to a top-N candidate list. This is the channel that reaches
  `orchestrator_mode=true` runs, where `AskUserQuestion` is forbidden and stderr never enters
  the agent's prompt.
- Interactive is **additive, non-autonomous only**: the resolver downgrade to the existing
  `SPARSE_PROMPT_NEEDED` directive routes into the existing four-option `AskUserQuestion`
  unchanged, with prompt wording that names the topic-scoped miss instead of the absolute count.

**D5 — The delta does NOT set `sparse=true`** in the `lit-coverage` marker. `sparse-coverage.md`
warns against adding "a separate, unconsumed flag", and that warning is respected here by
construction rather than by overloading `sparse`: the delta has two real consumers on day one
(the resolver's directive downgrade and the always-emitted in-band banner), so it is not an
unpolled field. Overloading `sparse` instead would (a) conflate "this briefing resolved almost
nothing" with "more relevant material exists elsewhere", which are different operator actions,
and (b) leak into the two-checkpoint re-prompt logic keyed on `mode=global .*sparse=true`. The
delta gets its own marker fields and its own banner.

**D6 — A not-computed delta is never reported as zero.** The marker carries
`delta_checked=true|false`; when `literature-briefing.sh` repo mode is invoked without `--query`
(no task text available), it emits `delta_checked=false delta_gap=0 delta_candidates=0`, so a
zero can never be misread as a verified "no gap". Same silent-degradation discipline the
`requested=`/`skipped=` fields already follow.

## Goals & Non-Goals

**Goals**:
- Detect, under `--lit`, that the global corpus holds topic-relevant documents the per-repo
  sub-index never references, at briefing time and at directive-resolution time.
- Surface that detection in-band inside `lit_context` (mandatory, all contexts including
  autonomous) and interactively via the existing four-option prompt (non-autonomous only).
- Reuse existing machinery throughout: existing directive token, existing option set, existing
  marker/banner family, existing Tier 1 keyword matcher.
- Keep the guard silent on an ordinary curated sub-index (no alarm fatigue).
- Land a fixture regression section covering firing, non-firing, chunk-inflation, and
  not-computed cases.

**Non-Goals**:
- **A claim-level "no counterpart exists" verifier** that scans a draft's assertions against the
  global corpus before finalizing. This is a materially different, more expensive mechanism
  (post-hoc draft scanning, `/cite`-adjacent, not a Stage 4a briefing-time concern). It is
  explicitly named as a follow-up in `## Named Follow-Up` below — this task does NOT close that
  class of risk, and must not be reported as doing so.
- Merging with the completed briefing coverage-marker (resolution-failure-rate) work. That guard
  catches doc_ids that ARE requested but fail to resolve; this one catches sources never
  requested because never indexed. Same file scope, deliberately separate checks.
- Changing the global-mode (`--global`) path. The delta is a repo-mode/sub-index-present concern
  by definition.
- Adding a new directive token, a new `AskUserQuestion` option, or a new autonomy branch.
- Any network calls or caching. The delta is one extra `jq` pass over a local 200-400-entry JSON
  file.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Alarm fatigue — guard fires on nearly every repo | H | M | Compound topic-scoped condition (D1/D2); gap pre-filter default 25; Phase 6 negative-control case asserts non-firing on a non-matching global corpus |
| Chunk-count inflation — global side counted with chunk children, overstating the gap ~2x | M | H (default `jq '.entries \| length'` idiom invites it) | `parent_doc == null` filter mandated in Phase 2; dedicated Phase 6 fixture case with chunk children asserting the filtered count |
| Prompt bloat — banner lists every miss | M | M | Bounded top-N candidate list (default 5, env-overridable); total count stated separately from the truncated list |
| Behavior drift from extracting the matcher out of `literature-discover.sh` | H | L | Phase 1 is a pure extraction with a before/after output diff on a real query as its verification gate; no logic edits in the same phase |
| `--query` never reaches repo mode, so the guard silently never fires in production | H | M | Phase 5 updates both `lit-stage4a-flow.md` repo-mode call sites; D6's `delta_checked=false` makes the not-wired state visible rather than reading as a clean zero |
| Scope creep into the claim-level verifier | M | M | Named explicitly in Non-Goals and `## Named Follow-Up`; implementer must not attempt it in this task |
| Editing `.claude/**` instead of the source store | H | L | All phases target `agent-system/extensions/**`; `.claude/` is a regenerated deploy artifact |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5, 6 | 3, 4 |
| 5 | 7 | 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Extract the shared term-matching helper [COMPLETED]

**Goal**: One implementation of the Tier 1 keyword matcher, sourceable by both
`literature-discover.sh` and the new delta script — no second matcher anywhere.

**Tasks**:
- [x] Create `agent-system/extensions/literature/scripts/literature-term-match.sh` as a *(completed)*
      source-only helper (no `set -e`; guarded against double-sourcing), exporting `to_lower`,
      `STOP_WORDS`, `filter_terms`, `term_matches`, and `MULTI_TERM_MATCH_THRESHOLD` verbatim
      from their current definitions in `literature-discover.sh`.
- [x] Add a header comment naming both call sites and stating that the multi-term threshold *(completed)*
      semantics (accept-on-first-hit at or below the threshold, `>= 2` distinct hits above it)
      are the contract, not an implementation detail.
- [x] Edit `literature-discover.sh` to source the helper and delete its now-duplicated local *(completed)*
      definitions, leaving the Tier 1 loop's use of them byte-identical.
- [x] Confirm `literature-discover.sh` still resolves the helper from its own `SCRIPT_DIR` (it *(completed)*
      must work from both the source-store copy and the deployed `.claude/scripts/` copy).

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts that exactly five symbols (`to_lower`, `STOP_WORDS`,
`filter_terms`, `term_matches`, `MULTI_TERM_MATCH_THRESHOLD`) constitute the extractable matcher
and that `literature-discover.sh` is its only current consumer. Confirm at implementation time
with `grep -n 'to_lower\|filter_terms\|term_matches\|MULTI_TERM_MATCH_THRESHOLD\|STOP_WORDS'`
across `agent-system/extensions/literature/scripts/`; if another script defines or uses them,
widen the phase to cover it or record the divergence rather than assuming the list.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-term-match.sh` - new source-only helper
- `agent-system/extensions/literature/scripts/literature-discover.sh` - source the helper, drop
  the local definitions

**Verification**:
- `bash -n` clean on both files.
- Capture `literature-discover.sh "<some query>"` output before and after the extraction and
  diff — must be byte-identical (this is the phase's real gate; a behavior change here is a
  defect, not an improvement).
- Run the existing `test-lit-pipeline.sh` (static sections) with no new failures.

---

### Phase 2: Implement `literature-coverage-delta.sh` [COMPLETED]

**Goal**: One executable that computes the topic-scoped coverage delta and prints a single
machine-readable line, with no opinion about who consumes it.

**Tasks**:
- [x] Create `agent-system/extensions/literature/scripts/literature-coverage-delta.sh` accepting *(completed)*
      `--query "<text>"` (required), `--top-n N` (default 5, bounded candidate list),
      and honoring `LITERATURE_DIR`, `LITERATURE_COVERAGE_GAP_MIN` (default 25),
      `LITERATURE_COVERAGE_DELTA_THRESHOLD` (default 1).
- [x] Resolve `SUB_INDEX` / `GLOBAL_INDEX` using the same `SCRIPT_DIR`/`PROJECT_ROOT` idiom the *(completed)*
      resolver and briefing scripts already use.
- [x] Count the global side as top-level documents only: `select(.parent_doc == null or *(completed)*
      .parent_doc == "")` — never raw `.entries | length`. This is the plan's single most
      load-bearing implementation detail.
- [x] Build the sub-index doc-key set from `.entries[].doc_id`, and compare against global *(completed)*
      `(.id // .doc_id)` (the tolerant pattern already used throughout the extension).
- [x] Source `literature-term-match.sh`; filter the query; apply the same match rule as Tier 1 *(completed)*
      (title/keywords, `>= 2` distinct hits when the filtered term count exceeds
      `MULTI_TERM_MATCH_THRESHOLD`, accept-on-first-hit otherwise).
- [x] Apply the compound condition from D1: compute `delta_gap` always; run the keyword pass only *(completed)*
      when `delta_gap >= LITERATURE_COVERAGE_GAP_MIN`.
- [x] Print exactly one stdout line: *(completed)*
      `delta_checked=true delta_gap=N global_docs=G subindex_docs=S delta_candidates=M
      candidates=<id1,id2,...>` plus a parallel `candidate_titles=` payload the banner can render
      (bounded to `--top-n`; the untruncated total stays in `delta_candidates`).
- [x] Fail open, never fatal: missing global index, missing sub-index, unreadable JSON, or an *(completed)*
      empty filtered-term list all exit 0 with `delta_checked=false` and a stderr rationale.
      A `--lit` run must never be aborted by this script.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-coverage-delta.sh` - new executable

**Verification**:
- `bash -n` clean; `chmod +x`.
- Run by hand against the real `$LITERATURE_DIR` with a topical query and confirm `global_docs`
  matches `jq '[.entries[] | select(.parent_doc == null)] | length'` on the same index (and is
  roughly half of raw `.entries | length` in this environment) — the anti-inflation check.
- Run against a nonexistent `LITERATURE_DIR` and confirm exit 0 with `delta_checked=false`.

---

### Phase 3: Wire the guard into the resolver's `SUBINDEX_PRESENT` branch [COMPLETED]

**Goal**: A sub-index that clears the absolute floor but has topic-scoped misses downgrades to
the EXISTING `SPARSE_PROMPT_NEEDED` directive instead of short-circuiting as healthy.

**Tasks**:
- [x] In `literature-lit-flag-resolve.sh`, after the existing `entry_count -lt threshold` check *(completed)*
      passes, invoke `literature-coverage-delta.sh --query "$query"` and parse
      `delta_checked`/`delta_candidates`.
- [x] When `delta_checked=true` and `delta_candidates >= LITERATURE_COVERAGE_DELTA_THRESHOLD`, *(completed)*
      emit `SPARSE_PROMPT_NEEDED` (unchanged token) with a stderr rationale that explicitly
      distinguishes this cause ("sub-index clears the count floor but N topic-relevant global
      documents are absent from it: id1, id2, ...") from the absolute-count cause.
- [x] Otherwise emit `SUBINDEX_PRESENT` exactly as today, with the delta result appended to the *(completed)*
      existing rationale line so a non-firing check is still visible to an operator.
- [x] Guard the invocation so a delta-script failure or absence degrades to today's behavior *(completed)*
      (`SUBINDEX_PRESENT`) with a visible stderr notice — never a crash, never a silent skip.
- [x] Update the script's header directive documentation: `SPARSE_PROMPT_NEEDED` now has two *(completed)*
      causes; the token, option set, and autonomy contract are unchanged.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: interface

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-lit-flag-resolve.sh` - `SUBINDEX_PRESENT`
  branch + header docs

**Verification**:
- With a fixture sub-index of >= 3 entries and a global index containing topic-matching absent
  docs: resolver prints `SPARSE_PROMPT_NEEDED` and the distinguishing rationale on stderr.
- With the same sub-index and a global index whose docs do not match the query: resolver prints
  `SUBINDEX_PRESENT` (regression control).
- With `LITERATURE_DIR` pointing nowhere: resolver still prints `SUBINDEX_PRESENT`, exit 0.
- Exactly one token on stdout in every case (the script's standing contract).

---

### Phase 4: Wire the in-band banner into `literature-briefing.sh` repo mode [COMPLETED]

**Goal**: The delta reaches the consuming agent's prompt — including in `orchestrator_mode=true`,
where `AskUserQuestion` is forbidden and stderr never arrives.

**Tasks**:
- [x] Add an optional `--query "<text>"` argument to `literature-briefing.sh` (repo mode only; *(completed)*
      ignored with a warning in `--global` mode, which has its own query).
- [x] In repo mode, when `--query` is present, invoke `literature-coverage-delta.sh` and capture *(completed)*
      `delta_checked` / `delta_gap` / `delta_candidates` / the bounded candidate list.
- [x] Append `delta_checked=` `delta_gap=` `delta_candidates=` to the `<!-- lit-coverage ... -->` *(completed)*
      marker **strictly after** the existing `mode=`/`seg_count=`/`sparse=`/`threshold=`/
      `requested=`/`resolved=`/`skipped=`/`skip_rate=` fields, which stay byte-for-byte adjacent
      and in order (the established backward-compatibility rule for `.*`-tolerant greps).
- [x] When `--query` is absent, emit `delta_checked=false delta_gap=0 delta_candidates=0` (D6) — *(completed)*
      never omit the fields, never report an uncomputed zero as a verified zero.
- [x] Emit a `[COVERAGE DELTA - M topic-relevant document(s) in the global corpus are absent from *(completed)*
      this repo's sub-index]` banner when the trigger fires, in the same family as
      `[SPARSE COVERAGE ...]`, listing up to top-N candidate titles + doc_ids and stating the
      untruncated total separately.
- [x] Do NOT set `sparse=true` from the delta (D5). Leave the existing `sparse` computation *(completed)*
      untouched.
- [x] Confirm `literature-briefing-invoke.sh` needs no change (it forwards `"$@"` unchanged) and *(completed)*
      record that in the phase notes rather than editing it speculatively.

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: interface

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-briefing.sh` - arg parsing, marker
  fields, banner

**Verification**:
- Repo mode with no `--query`: marker contains `delta_checked=false`, and the pre-existing marker
  fields are byte-identical to today's output (diff against a captured baseline).
- Repo mode with `--query` on a firing fixture: marker shows `delta_checked=true` with a nonzero
  `delta_candidates`, and the `[COVERAGE DELTA ...]` banner appears inside the
  `<literature-briefing>` block with a bounded list.
- `sparse=` value unchanged across all of the above.
- The legitimately-empty sub-index silent-exit contract still holds.

---

### Phase 5: Update the shared Stage 4a flow [COMPLETED]

**Goal**: The `--query` actually reaches repo mode at every production call site, and the
interactive prompt wording distinguishes the two `SPARSE_PROMPT_NEEDED` causes.

**Tasks**:
- [x] In `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md`, update the *(completed)*
      `SUBINDEX_PRESENT` branch's call to
      `literature-briefing-invoke.sh --query "$description"`.
- [x] Update the autonomous `SPARSE_PROMPT_NEEDED` branch's repo-briefing call the same way, and *(completed)*
      extend its `[lit:auto]` notice to mention that a topic-scoped coverage delta, if any, is
      surfaced in-band inside `lit_context`.
- [x] Update the interactive `SPARSE_PROMPT_NEEDED` prompt wording so it covers both causes *(completed)*
      ("the sub-index is sparse, or topic-relevant global documents are absent from it"),
      keeping the four options and their order unchanged.
- [x] Add a short subsection documenting the `delta_checked=`/`delta_gap=`/`delta_candidates=` *(completed)*
      marker fields and stating that the delta deliberately does not set `sparse=true` (so the
      existing `grep 'lit-coverage mode=global .*sparse=true'` two-checkpoint logic is
      unaffected).
- [x] Do not add a directive token, an option, or an autonomy branch. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 3, 4

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md` - two call sites, prompt
  wording, new marker-fields subsection

**Verification**:
- Every changed hunk lies in prose or in a bash fence that is documentation-of-a-call-site, with
  no behavioral shell executed by this file itself.
- `grep -c 'literature-briefing-invoke.sh'` before/after confirms no call site was dropped, and
  every repo-mode call site now carries `--query "$description"`.
- The six-directive list and the four-option list are unchanged in count and order.

---

### Phase 6: Fixture regression suite (Section H) [COMPLETED]

**Goal**: The guard's firing and — more importantly — its **non**-firing behavior is pinned by
fixtures, in the idiom Section G already established.

**Tasks**:
- [x] Add `section_h` to `agent-system/extensions/literature/scripts/test-lit-pipeline.sh`, *(completed)*
      following Section G's fixture idiom (own `TEMP_LIT_DIR_H`, symlinked script under a
      `fakerepo/nested/scripts` tree, own cleanup registration), and call it from `main` under
      the `--runtime` guard.
- [x] Case H1 (fires): sub-index of >= 3 entries clearing the absolute floor; global index with *(completed)*
      topic-matching documents absent from it; assert the resolver prints `SPARSE_PROMPT_NEEDED`
      and the briefing marker reports `delta_checked=true` with `delta_candidates >= 1` plus a
      `[COVERAGE DELTA ...]` banner.
- [x] Case H2 (negative control, does NOT fire): same sub-index, global index whose documents do *(completed)*
      not match the query terms; assert `SUBINDEX_PRESENT`, `delta_candidates=0`, and no banner.
      This case is the anti-alarm-fatigue guarantee and must not be dropped.
- [x] Case H3 (chunk inflation): global index with top-level docs plus `parent_doc`-bearing chunk *(completed)*
      children; assert `global_docs` counts only the top-level docs (and specifically that the
      chunk children do not inflate `delta_gap`).
- [x] Case H4 (not computed): repo-mode briefing invoked without `--query`; assert *(completed)*
      `delta_checked=false` and that the pre-existing marker fields are unchanged.
- [x] Case H5 (fail-open): `LITERATURE_DIR` pointing at a nonexistent path; assert the resolver *(completed)*
      still emits `SUBINDEX_PRESENT` on stdout with exit 0.
- [x] Confirm Sections A-G still pass unchanged. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts five cases (H1-H5) are sufficient coverage. Confirm at
implementation time by re-reading Section G's case list for any pattern it covers that H omits
(e.g. a boundary case exactly at a threshold value); add cases rather than declaring the list
closed if a gap is found.

**Files to modify**:
- `agent-system/extensions/literature/scripts/test-lit-pipeline.sh` - new `section_h` + `main`
  dispatch

**Verification**:
- `bash agent-system/extensions/literature/scripts/test-lit-pipeline.sh --runtime` from the
  source-store copy: all sections pass, zero failures.
- Deliberately invert the trigger condition in a scratch copy and confirm H1 fails (the test
  actually tests something) before restoring.

---

### Phase 7: Documentation [COMPLETED]

**Goal**: The new mechanism is documented where the sparse family is documented, and the
out-of-scope claim-level verifier is recorded as a named follow-up rather than silently dropped.

**Tasks**:
- [x] Add a "Coverage-Delta Detection" section to *(completed)*
      `agent-system/extensions/literature/context/project/literature/domain/sparse-coverage.md`
      covering: the compound topic-scoped condition and both env vars with their defaults; the
      mandatory `parent_doc == null` filtering rule; the new marker fields and their
      append-after-existing-fields placement; the `delta_checked=false` not-computed convention;
      and the explicit rationale for NOT overloading `sparse=true` (D5), written to sit
      consistently beside that file's existing "Threshold Policy" section rather than
      contradicting it.
- [x] Follow the file's existing "Authority for the Full Decision Flow" pointer convention — *(completed)*
      point at `lit-stage4a-flow.md` for the decision flow, do not duplicate it.
- [x] Check `agent-system/extensions/literature/context/project/literature/patterns/adhoc-navigation-directive.md`'s *(completed)*
      `<!-- lit-coverage ... -->` references and update them only if the added fields make an
      existing statement inaccurate.
- [x] Record the claim-level verifier as future work in the documentation's own terms (durable *(completed)*
      description, no task-number reference in any file outside `specs/**`).

**Timing**: 0.5 hours

**Depends on**: 5, 6

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/literature/context/project/literature/domain/sparse-coverage.md` - new
  Coverage-Delta Detection section
- `agent-system/extensions/literature/context/project/literature/patterns/adhoc-navigation-directive.md` -
  marker reference accuracy check (edit only if inaccurate)

**Verification**:
- Every changed hunk is prose; no code surface touched.
- `grep -rn 'task [0-9]' ` over the changed files returns nothing (deliverable rule).
- The documented marker field names match the strings actually emitted in Phase 4 (compare
  against the script, not against this plan).

---

## Named Follow-Up (explicitly NOT delivered by this task)

**Claim-level "no counterpart exists" verification against the global corpus.** A check that
inspects a draft artifact's specific assertions of the form "the framework has no counterpart for
X" / "there is no existing treatment of X" and verifies each against the full global corpus
before the artifact is finalized. This is a materially different and more expensive mechanism
than the guard built here: post-hoc draft scanning at artifact-write time (likely `/cite`-adjacent),
not a Stage 4a briefing-time concern, and it needs claim extraction the delta guard has no part
of. It should be spawned as its own task (`/spawn` candidate). **This task's completion must not
be reported as closing that class of risk** — the guard here reduces the probability that
relevant sources are invisible; it does not verify any particular claim.

## Testing & Validation

- [x] `bash -n` clean on every modified/created shell script. *(completed)*
- [x] `literature-discover.sh` output byte-identical before/after the Phase 1 extraction. *(completed)*
- [x] `literature-coverage-delta.sh` `global_docs` equals `jq '[.entries[] | select(.parent_doc == *(completed)*
      null)] | length'` on the same index (anti-inflation).
- [x] Resolver emits exactly one directive token on stdout in every branch, including all failure *(completed)*
      modes.
- [x] `literature-briefing.sh` repo-mode marker without `--query` is byte-identical to the *(completed)*
      pre-change output except for the appended `delta_*` fields.
- [x] `bash agent-system/extensions/literature/scripts/test-lit-pipeline.sh --runtime` passes *(completed)*
      with zero failures, Sections A-H.
- [x] Manual autonomous-path check: with `orchestrator_mode=true` semantics (no *(completed)*
      `AskUserQuestion`), the `[COVERAGE DELTA ...]` banner is present inside the returned
      `<literature-briefing>` block.
- [x] No file under `.claude/**` was hand-edited (source-store rule). *(completed)*
- [x] No task-number references introduced outside `specs/**` (deliverable rule). *(completed)*

## Artifacts & Outputs

- `agent-system/extensions/literature/scripts/literature-term-match.sh` (new)
- `agent-system/extensions/literature/scripts/literature-coverage-delta.sh` (new)
- `agent-system/extensions/literature/scripts/literature-discover.sh` (modified)
- `agent-system/extensions/literature/scripts/literature-lit-flag-resolve.sh` (modified)
- `agent-system/extensions/literature/scripts/literature-briefing.sh` (modified)
- `agent-system/extensions/literature/scripts/test-lit-pipeline.sh` (modified — Section H)
- `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md` (modified)
- `agent-system/extensions/literature/context/project/literature/domain/sparse-coverage.md` (modified)
- `specs/096_surface_literature_coverage_delta_under_lit/summaries/01_*-summary.md` (implementation summary)

## Rollback/Contingency

Every phase is an additive, independently revertible commit. The two new scripts are inert until
Phases 3-5 wire them, so reverting Phases 3/4/5 alone restores today's behavior exactly while
leaving the computation available. If the guard proves too noisy in practice, the first response
is raising `LITERATURE_COVERAGE_GAP_MIN` / `LITERATURE_COVERAGE_DELTA_THRESHOLD` via env var —
no code change needed. Full rollback: revert the phase commits in reverse order; Phase 1's
extraction is behavior-neutral and may be kept independently.

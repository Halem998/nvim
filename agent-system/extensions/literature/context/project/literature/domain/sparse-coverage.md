# Sparse-Coverage Detection

Both `literature-briefing.sh` and `literature-lit-flag-resolve.sh` treat "found almost nothing"
as a loud, machine-readable signal rather than a silent thin result.

## Mechanisms

- **`LITERATURE_SPARSE_THRESHOLD`** (env var, default `3`): the minimum resolved segment/entry
  count before coverage counts as sparse. Comparison is strict (`< threshold`), never `<=`.
- **`LITERATURE_SKIP_RATE_THRESHOLD`** (env var, default `50`, percent): the resolution-failure
  rate — `skip_count * 100 / requested_count`, repo mode only — at or above which coverage also
  counts as sparse. Comparison is `>=`, unlike the absolute-count rule's strict `<`. Always `0` in
  global mode, where no per-item external lookup can fail.
- **`literature-briefing.sh`** emits a greppable
  `<!-- lit-coverage mode=repo|global seg_count=N sparse=true|false threshold=T requested=R
  resolved=N skipped=S skip_rate=P -->` marker after the header in both per-repo and
  global-corpus modes, plus a `[SPARSE COVERAGE - N segment(s), threshold T]` banner (same
  family as the existing `[UNVERIFIED ...]` / `[DEGRADED RETRIEVAL ...]` banners) when
  `sparse=true`. The `requested=`/`resolved=`/`skipped=`/`skip_rate=` fields are appended
  strictly after the original `mode=`/`seg_count=`/`sparse=`/`threshold=` fields, which stay
  byte-for-byte adjacent and in their original order for backward compatibility with existing
  `.*`-tolerant greps.
- **`literature-lit-flag-resolve.sh`** carries a sixth directive, `SPARSE_PROMPT_NEEDED`: a
  per-repo sub-index that exists but resolves to fewer than the threshold entries (including
  zero) downgrades from `SUBINDEX_PRESENT` to `SPARSE_PROMPT_NEEDED` instead of silently
  proceeding with thin coverage.
- Autonomous contexts (`orchestrator_mode == "true"`) never call `AskUserQuestion` and never
  trigger online ingest; they take the deterministic global-corpus (or existing-sub-index)
  fallback and emit a visible `[lit:auto]` notice.

## Threshold Policy: Skip Rate Folded Into `sparse`, Not a Separate Signal

A skip rate at or above `LITERATURE_SKIP_RATE_THRESHOLD` sets the *existing* `sparse` boolean
rather than a distinct, separate flag — even though a high skip rate and a low absolute count
are different failure modes. This is a deliberate reuse decision: both existing marker consumers
(`lit-stage4a-flow.md`'s literal `grep -q 'lit-coverage mode=global .*sparse=true'` and
`adhoc-navigation-directive.md`'s mirror of the same contract) already poll `sparse=true`. A
separate, unconsumed flag would reproduce the exact silent-degradation failure this mechanism
exists to close — a caller that never learns to check a new field learns nothing from it.

`50` (percent) is a conservative starting value chosen without calibration data — deliberately
loose enough that it will not flag a normal, partially-curated sub-index (e.g. 1 of 4 entries
legitimately superseded, a 25% skip rate), while still catching the "resolution silently dropped
most or all requested primary sources" case this mechanism targets.

`skip_count -gt 0` always emits the `[SKIPPED SOURCES ...]` banner and the
`## Unresolved Documents` briefing-body section, independent of whether the rate crosses
`LITERATURE_SKIP_RATE_THRESHOLD` — a low but nonzero skip rate is still visible without being
treated as untrustworthy enough to force `sparse=true`.

## Coverage-Delta Detection

A structurally prior failure mode to everything above: the mechanisms in "Mechanisms" all measure
properties of the sub-index's own resolution (how many entries it has, how many of them resolve
against the global index). None of them notice a source that was **never added to the sub-index
in the first place** — a sub-index can clear both the absolute-count floor and the skip-rate
check while topically relevant documents already sitting in the global corpus stay invisible,
because nothing was ever requested from them, so nothing is ever skipped.

- **`literature-coverage-delta.sh`** computes a **topic-scoped coverage delta**: is there a
  global top-level document matching this task's own search terms that the sub-index never
  references? The firing condition is **compound**, never a bare ratio (a bare ratio/absolute-gap
  trigger would fire on nearly every repo — a curated sub-index of 10-40 entries is always dwarfed
  by a 200-400-document global corpus, and that is normal, not a defect):
  1. **`LITERATURE_COVERAGE_GAP_MIN`** (env var, default `25`): a cheap pre-filter —
     `global_docs - subindex_docs >= LITERATURE_COVERAGE_GAP_MIN`. Its only job is to skip the
     more expensive keyword-matching pass when the global corpus is not materially larger than
     the sub-index, or the sub-index is already comprehensive. Comparison is `>=`, exercised at
     the boundary by the Section H fixture suite (`test-lit-pipeline.sh`).
  2. **`LITERATURE_COVERAGE_DELTA_THRESHOLD`** (env var, default `1`): the actionable trigger —
     at least this many global top-level documents must match the query's filtered terms (the
     same Tier 1 matcher `literature-discover.sh` uses, factored into the sourceable
     `literature-term-match.sh` helper) and be absent from the sub-index's doc-key set. This half
     is what makes the signal topic-scoped and actionable rather than an abstract percentage —
     it names specific candidate documents.
- **Mandatory `parent_doc == null` filtering on the global side.** The global index's `.entries`
  array mixes top-level documents with their chunk children in one flat array. Every count on the
  global side of the delta — the pre-filter's `global_docs` and every candidate the keyword pass
  considers — filters to `select(.parent_doc == null or .parent_doc == "")`. Counting raw
  `.entries | length` instead overstates the gap by roughly 2x (measured in one environment: 414
  total entries, 204 top-level documents) and is the single most load-bearing implementation
  detail in `literature-coverage-delta.sh`.
- **Marker fields.** `literature-briefing.sh` repo mode, when called with `--query`, appends
  `delta_checked=true|false delta_gap=N delta_candidates=M` to the `<!-- lit-coverage ... -->`
  marker, strictly AFTER the `mode=`/`seg_count=`/`sparse=`/`threshold=`/`requested=`/`resolved=`/
  `skipped=`/`skip_rate=` fields described above, which stay byte-for-byte adjacent and in order.
  `delta_checked=false` means the guard never ran (no `--query`, or a fail-open condition) — it is
  NOT the same as "ran and found zero"; a caller must never treat it as a verified absence of a
  gap. When it fires, a `[COVERAGE DELTA - M topic-relevant document(s) ...]` banner (same family
  as `[SPARSE COVERAGE ...]` / `[SKIPPED SOURCES ...]`) lists up to `--top-n` candidate titles and
  doc_ids, with the untruncated total stated separately.
- **`literature-lit-flag-resolve.sh`'s `SPARSE_PROMPT_NEEDED` now has a second, independent
  cause.** A sub-index that clears `LITERATURE_SPARSE_THRESHOLD` is still downgraded from
  `SUBINDEX_PRESENT` to `SPARSE_PROMPT_NEEDED` when the coverage-delta guard fires. The
  directive token, the four-option `AskUserQuestion` set, and the autonomy contract are
  UNCHANGED — only the stderr rationale distinguishes the two causes.
- **Why the delta does NOT set `sparse=true`.** The "Threshold Policy" section above folds skip
  rate into `sparse` because both existing consumers already poll `sparse=true` and a separate,
  unconsumed flag would reproduce the exact silent-degradation failure this mechanism exists to
  close. The coverage delta is the opposite case: it has two real consumers from day one (the
  resolver's directive downgrade and the always-emitted in-band banner), so it is not an unpolled
  field, and overloading `sparse` instead would (a) conflate "this briefing resolved almost
  nothing" with "more relevant material exists elsewhere in the global corpus" — different
  operator actions — and (b) leak into the two-checkpoint re-prompt logic keyed on
  `mode=global .*sparse=true`. The delta gets its own marker fields and its own banner instead.
- **Fail-open, never fatal.** `literature-coverage-delta.sh` never exits non-zero. A missing
  global index, missing sub-index, unreadable JSON, or an empty filtered-term list all degrade to
  `delta_checked=false` plus a stderr rationale — a `--lit` run is never aborted by this guard.
  Both wiring sites (`literature-lit-flag-resolve.sh`, `literature-briefing.sh`) additionally
  guard the invocation itself so a missing or non-executable delta script degrades to
  pre-existing behavior with a visible stderr notice, never a crash.

**Named follow-up, explicitly not covered here**: a claim-level verifier that inspects a draft
artifact's specific "no counterpart exists" / "there is no existing treatment of X" assertions
against the full global corpus before the artifact is finalized. This is a materially different,
more expensive mechanism (post-hoc draft scanning at artifact-write time, needing claim
extraction the delta guard has no part of) than the briefing-time topic-scoped delta documented
above, and reduces a different risk: the delta guard above lowers the probability that a
topically relevant source is invisible to a research run; it does not verify any specific claim
a draft makes. It is a candidate for a dedicated follow-up task, not something the mechanism
above should be read as having closed.

## Authority for the Full Decision Flow

This file is a pointer, not the specification. The full six-directive decision table — including
the interactive `AskUserQuestion` choices (among them the "Search online to ingest" option that
chains `literature-discover.sh` -> per-record `literature-ingest-online.sh --record` -> a re-run
of the per-repo briefing) and the autonomy contract — lives in the CLAUDE.md merge source at
`agent-system/extensions/core/merge-sources/claudemd.md`, section "Interactive Sub-Index Setup
Detection". Do not duplicate it here.

The single shared Stage 4a implementation that all six `--lit` skills import lives at
`agent-system/extensions/core/context/patterns/lit-stage4a-flow.md`.

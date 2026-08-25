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

## Authority for the Full Decision Flow

This file is a pointer, not the specification. The full six-directive decision table — including
the interactive `AskUserQuestion` choices (among them the "Search online to ingest" option that
chains `literature-discover.sh` -> per-record `literature-ingest-online.sh --record` -> a re-run
of the per-repo briefing) and the autonomy contract — lives in the CLAUDE.md merge source at
`agent-system/extensions/core/merge-sources/claudemd.md`, section "Interactive Sub-Index Setup
Detection". Do not duplicate it here.

The single shared Stage 4a implementation that all six `--lit` skills import lives at
`agent-system/extensions/core/context/patterns/lit-stage4a-flow.md`.

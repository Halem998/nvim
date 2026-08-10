# Sparse-Coverage Detection

Both `literature-briefing.sh` and `literature-lit-flag-resolve.sh` treat "found almost nothing"
as a loud, machine-readable signal rather than a silent thin result.

## Mechanisms

- **`LITERATURE_SPARSE_THRESHOLD`** (env var, default `3`): the minimum resolved segment/entry
  count before coverage counts as sparse. Comparison is strict (`< threshold`), never `<=`.
- **`literature-briefing.sh`** emits a greppable
  `<!-- lit-coverage mode=repo|global seg_count=N sparse=true|false threshold=T -->` marker after
  the header in both per-repo and global-corpus modes, plus a
  `[SPARSE COVERAGE - N segment(s), threshold T]` banner (same family as the existing
  `[UNVERIFIED ...]` / `[DEGRADED RETRIEVAL ...]` banners) when `sparse=true`.
- **`literature-lit-flag-resolve.sh`** carries a sixth directive, `SPARSE_PROMPT_NEEDED`: a
  per-repo sub-index that exists but resolves to fewer than the threshold entries (including
  zero) downgrades from `SUBINDEX_PRESENT` to `SPARSE_PROMPT_NEEDED` instead of silently
  proceeding with thin coverage.
- Autonomous contexts (`orchestrator_mode == "true"`) never call `AskUserQuestion` and never
  trigger online ingest; they take the deterministic global-corpus (or existing-sub-index)
  fallback and emit a visible `[lit:auto]` notice.

## Authority for the Full Decision Flow

This file is a pointer, not the specification. The full six-directive decision table — including
the interactive `AskUserQuestion` choices (among them the "Search online to ingest" option that
chains `literature-discover.sh` -> per-record `literature-ingest-online.sh --record` -> a re-run
of the per-repo briefing) and the autonomy contract — lives in the CLAUDE.md merge source at
`agent-system/extensions/core/merge-sources/claudemd.md`, section "Interactive Sub-Index Setup
Detection". Do not duplicate it here.

The single shared Stage 4a implementation that all six `--lit` skills import lives at
`agent-system/extensions/core/context/patterns/lit-stage4a-flow.md`.

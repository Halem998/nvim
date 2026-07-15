# Distill Usage Guide

Usage guide for the `/distill` command and memory vault maintenance.

## Quick Reference

```
/distill                  # Health report (read-only)
/distill --purge          # Tombstone stale memories
/distill --merge          # Combine duplicate memories
/distill --compress       # Summarize oversized memories
/distill --refine         # Improve metadata quality
/distill --gc             # Hard-delete tombstoned memories
/distill --auto           # Automated Tier 1 maintenance
/distill --dream          # Event-store review, revision, and improvement proposals

# Modifier flags (combinable with any sub-mode):
/distill --purge --dry-run    # Preview without changes
/distill --merge --verbose    # Show detailed scoring
```

## Sub-Mode Workflows

### Health Report (bare `/distill`)

Run with no arguments to get a vault health overview:
- Overview metrics (total memories, tokens, oldest/newest)
- Category distribution table
- Topic cluster analysis
- Retrieval statistics (never retrieved, most retrieved)
- Maintenance candidates (purge, merge, compress, review)
- Tombstoned memories section
- Health score (0-100) with status label

The report is read-only -- no files are modified.

### Purge (`/distill --purge`)

Identifies memories that are stale (staleness >0.8) or have zero retrievals past 30 days. Workflow:

1. Scoring engine runs on all non-tombstoned memories
2. Candidates sorted by category TTL and composite score
3. Interactive selection via AskUserQuestion (multiSelect)
4. Selected memories get tombstone frontmatter (`status: tombstoned`)
5. Link-scan warns about stale `[[MEM-*]]` references
6. Index regenerated, state.json updated

Tombstoned memories remain on disk for 7 days before `--gc` can remove them.

### Merge (`/distill --merge`)

Combines memories with >60% keyword overlap within topic clusters. Workflow:

1. Pairwise keyword overlap computed within each topic cluster
2. Pairs above 60% threshold presented per cluster
3. User selects pairs to merge
4. Primary determined by retrieval count (then age, then alphabetical)
5. Primary rewritten with merged content; secondary tombstoned
6. Keyword superset guarantee enforced (merge aborts if violated)
7. Cross-references updated (`[[secondary]]` -> `[[primary]]`)

### Compress (`/distill --compress`)

Reduces oversized memories (>900 tokens, size_penalty >0.5) to key points. Workflow:

1. Candidates identified by size penalty
2. User selects memories to compress
3. Key points extracted, code blocks preserved, prose reduced
4. Original content moved to `## History > ### Pre-Compression` section
5. Keywords checked and preserved in compressed content
6. Token count recalculated

Target: ~60% reduction (soft guideline).

### Refine (`/distill --refine`)

Two-tier metadata quality improvement:

**Tier 1 (automatic, no interaction)**:
- Keyword deduplication (case-insensitive)
- Summary generation for memories with empty summaries
- Topic normalization (lowercase, clean separators)

**Tier 2 (interactive, requires confirmation)**:
- Keyword enrichment (add suggested keywords when <4 present)
- Category reclassification (when content does not match tag)
- Topic path correction (when inconsistent with cluster patterns)

### GC (`/distill --gc`)

Hard-deletes tombstoned memories past the 7-day grace period:

1. Scans for tombstoned memories where `days_since_tombstoned >= 7`
2. Presents eligible memories for selection
3. Permanently removes .md files from disk
4. Removes entries from memory-index.json
5. Regenerates all indexes

This is the only destructive operation in the memory system.

### Auto (`/distill --auto`)

Non-interactive automated maintenance. Runs only Tier 1 refine fixes:
- Keyword deduplication
- Summary generation
- Topic normalization

Explicitly excludes: compress (needs AI review), purge, merge, dream, Tier 2 refine. Suitable for routine maintenance without human oversight.

### Dream (`/distill --dream`)

Ingests the unified event store (`specs/events.jsonl`, read exclusively via `events-query.sh`),
re-reviews the memory vault against captured event evidence, and surfaces a separate
agent-system improvement-proposal deliverable. Interactive by default (never runs under
`--auto`). Workflow:

1. Validate-on-read, then gate on vault emptiness (mirrors refine's early return)
2. Cheap event-count gate: `events-query.sh --format summary-counts [--since {last_dream}]`
   -- if `specs/events.jsonl` does not exist yet (`total_events: 0`), this is a normal,
   first-class outcome, not an error: dream review continues using vault scoring alone
   (staleness/duplicate/size) and reports zero correlations
3. Pull deviation/blocker events and reflection events via `events-query.sh
   --category deviation|blocker` / `--event-type reflection --format json-array`
4. Correlate events to memories: task-number substring match first, keyword/topic overlap
   fallback (same formula `/distill --merge` uses)
5. Classify each correlated memory as corroborated / contradicted / gap; a pattern needs
   3+ occurrences at the same checkpoint/event_type to count as contradicted or a gap
6. Interactive selection via AskUserQuestion -- corroborated memories are noted only;
   contradicted memories offer UPDATE (with the proposed new body shown for review) /
   TOMBSTONE (`tombstone_reason: "dream_superseded"`) / SKIP; gaps offer CREATE (if durable
   knowledge) or escalate to an improvement proposal (if a system change)
7. Memory revisions and improvement proposals are two distinct sections in the output --
   never merged. Improvement proposals go through their own AskUserQuestion (Create as task /
   Note in dream report only / Skip) with an explicit "Yes, create tasks" confirmation gate
   before any task is created
8. Index regenerated as a batch; operation logged to `.memory/dream-log.json`; state.json
   updated (`last_dream`, `dream_count`)

The narrative dream synthesis is terminal-only output, like the bare `/distill` health report --
no dated report file is written to disk.

## Scoring Formula

Each memory receives a composite score from four weighted components:

```
composite = (staleness * 0.3) + (zero_retrieval * 0.25) + (size_penalty * 0.2) + (duplicate * 0.25)
```

| Component | Range | Interpretation |
|-----------|-------|----------------|
| Staleness | 0.0-1.0 | Days since last retrieval / 90, with FSRS adjustment |
| Zero-retrieval | 0.0 or 1.0 | Binary: never retrieved and older than 30 days |
| Size penalty | 0.0+ | Linear above 600 tokens: (tokens - 600) / 600 |
| Duplicate | 0.0-1.0 | Max keyword overlap with any other memory |

Health score formula: `100 - (purge_count * 3) - (merge_count * 5) - (compress_count * 2)`

| Score | Status |
|-------|--------|
| 80-100 | healthy |
| 60-79 | manageable |
| 40-59 | concerning |
| 0-39 | critical |

## Recommended Maintenance Cadence

| Action | Frequency | Command |
|--------|-----------|---------|
| Health check | Weekly | `/distill` |
| Auto maintenance | After every 5-10 new memories | `/distill --auto` |
| Full refine | Monthly | `/distill --refine` |
| Purge review | Monthly or when health <60 | `/distill --purge` |
| Merge check | When duplicate score >0.6 appears | `/distill --merge` |
| Compress check | When size penalty >0.5 appears | `/distill --compress` |
| GC cleanup | After purge, when 7+ days elapsed | `/distill --gc` |
| Dream review | Periodically, or after a burst of deviations/blockers/reflections | `/distill --dream` |

## Memory Lifecycle

```
Create          Use               Capture           Maintain
------          ---               -------           --------
/learn    ->    auto-retrieval    ->    /todo        ->    /distill
                in /research,           harvests           scores,
                /plan, /implement       memory             reports,
                                        candidates         and maintains
```

## Dream Log Entry Shape

Dream runs log to `.memory/dream-log.json` (separate from `.memory/distill-log.json`), mirroring
its `version`/`operations[]`/`summary` shape with dream-specific fields:

```json
{
  "id": "dream_{timestamp}",
  "timestamp": "ISO8601",
  "type": "dream",
  "since": "ISO8601 or null (first run)",
  "events_ingested": {"total_events": 0, "deviation": 0, "blocker": 0, "reflection": 0},
  "classification": {"corroborated": 0, "contradicted": 0, "gap": 0},
  "affected_memories": [{"id": "MEM-...", "classification": "contradicted", "action": "updated"}],
  "proposals": {"surfaced": 0, "created_as_task": 0, "noted_only": 0, "skipped": 0}
}
```

## --dry-run and --verbose

- `--dry-run`: Available on all maintenance sub-modes (purge, merge, compress, refine, gc, dream). Shows what would happen without writing any files. Useful for previewing before committing to changes.
- `--verbose`: Shows detailed per-memory scoring breakdown including individual component values (staleness, zero_retrieval, size_penalty, duplicate) alongside the composite score.

---
name: skill-distill
description: Memory vault analysis and maintenance - scoring, health reporting, purge/merge/compress/refine/gc/auto, and telemetry-sourced review/revise/meta/learn/dream sub-modes. Invoke for /distill command operations.
allowed-tools: Bash, Grep, Read, Write, Edit, AskUserQuestion
---

# Distill Skill (Direct Execution)

Direct execution skill for memory vault analysis and maintenance. Handles the `/distill` command's sub-modes: the seven existing hygiene sub-modes (`report`/`purge`/`merge`/`compress`/`refine`/`gc`/`auto`) plus five new or redefined telemetry-sourced sub-modes (`--revise`/`--meta`/`--review`/`--learn`/`--dream`). Memory *creation* is a separate concern owned by the sibling `skill-learn` skill.

## Context References

Reference (do not load eagerly):
- Path: `@.memory/memory-index.json` - Machine-queryable memory index
- Path: `@.claude/context/project/memory/distill-usage.md` - Usage guide
- Path: `@.claude/context/project/memory/telemetry-guardrails.md` - Binding design constraints for the telemetry-sourced sub-modes (four-tier source model, evaluator-outside-the-loop rule, six failure modes, `gen_ai.*` borrowing rule, cross-repo invocation discipline)
- Path: `@.claude/skills/skill-learn/SKILL.md` - the sibling skill this file was split from. Its "Validate-on-Read" and "JSON Index Maintenance" sections are the shared procedures this file's body cites as "above" or "below" throughout -- both skills operate on the same `.memory/memory-index.json`, and those two procedures were not duplicated by the split; they live in `skill-learn/SKILL.md` only.

---

## Mode: distill

Memory vault distillation: scoring, health reporting, and maintenance operations. Invoked by `/distill` command with `mode=distill`.

### Prerequisites

**Validate-on-Read**: Before scoring, run the validate-on-read procedure from the "Validate-on-Read" section above to ensure `memory-index.json` is consistent with the filesystem. If stale, regenerate using the "JSON Index Maintenance" procedure before proceeding.

### Sub-Mode Dispatch

| Sub-Mode | Description | Status |
|----------|-------------|--------|
| `report` | Generate health report with scoring | Available (task 449) |
| `purge` | Tombstone stale/zero-retrieval memories | Available (task 450) |
| `merge` | Combine memories with duplicate score > 0.6 | Available (task 451) |
| `compress` | Summarize memories with size penalty > 0.5 | Available (task 452) |
| `refine` | Improve memory quality (keywords, tags) | Available (task 452) |
| `gc` | Hard-delete tombstoned memories past grace period | Available (task 450) |
| `auto` | Automated distillation (Tier 1 refine only) | Available (task 452) |
| `dream` | Event-store-informed memory review/revision plus improvement proposals | Available |

All sub-modes are now available. No placeholder responses needed.

### Scoring Engine

The scoring engine computes a composite maintenance score for each memory in the vault. Higher scores indicate memories that are better candidates for maintenance operations.

#### Input

Read all entries from `.memory/memory-index.json` after validate-on-read. Each entry provides:
- `created` (ISO date)
- `modified` (ISO date)
- `last_retrieved` (ISO date or null)
- `retrieval_count` (number)
- `token_count` (number)
- `keywords` (array of strings)

#### Component 1: Staleness Score (weight: 0.3)

Measures how long since the memory was last useful.

```
days_since_last = days_between(today, last_retrieved or created)

staleness = min(1.0, days_since_last / 90)

# FSRS adjustment: reduce staleness for actively retrieved old memories
if retrieval_count > 0 AND days_since_created > 60:
  staleness = max(0, staleness - 0.3)
```

- Range: 0.0 (fresh) to 1.0 (90+ days stale)
- FSRS adjustment rewards memories that have proven useful over time

#### Component 2: Zero-Retrieval Penalty (weight: 0.25)

Penalizes memories that have never been retrieved after a grace period.

```
if topic starts_with "email/preferences/":
  zero_retrieval = 0.0   # reserved-namespace exemption (task 822, design §5.1) -- these
                          # memories are intentionally never read back by /research /plan
                          # /implement auto-retrieval (see memory-retrieve.sh's topic-prefix
                          # pre-filter), so a zero retrieval_count is expected, not a staleness
                          # signal
elif retrieval_count == 0 AND days_since_created > 30:
  zero_retrieval = 1.0
else:
  zero_retrieval = 0.0
```

- Binary: 0.0 (has retrievals, too new, or `email/preferences/*` exempt) or 1.0 (never retrieved,
  older than 30 days, and not in the exempt namespace)

#### Component 3: Size Penalty (weight: 0.2)

Penalizes oversized memories that may benefit from compression.

```
size_penalty = max(0, (token_count - 600) / 600)
```

- Range: 0.0 (600 tokens or fewer) to unbounded (linear above 600)
- A 1200-token memory scores 1.0; a 300-token memory scores 0.0

#### Component 4: Duplicate Score (weight: 0.25)

Measures keyword overlap with the most similar other memory in the vault.

```
for each other_memory in vault:
  overlap = |memory.keywords intersect other_memory.keywords| / |memory.keywords|

duplicate = max(overlap across all other memories)
```

- Range: 0.0 (no keyword overlap) to 1.0 (complete keyword subset)
- Uses Jaccard-like ratio: intersection size divided by the memory's own keyword count

#### Composite Score

```
composite = (staleness * 0.3) + (zero_retrieval * 0.25) + (size_penalty * 0.2) + (duplicate * 0.25)
composite = clamp(composite, 0, 1)
```

- Weights sum to 1.0 (0.3 + 0.25 + 0.2 + 0.25)
- Range: 0.0 (healthy memory) to 1.0 (strong maintenance candidate)

#### Topic-Cluster Grouping

Group memories by topic cluster for the health report. The cluster key is the first path segment of the memory's `topic` field:

```
cluster_key = topic.split("/")[0]

# Example:
# topic "python/libs/requests" -> cluster "python"
# topic "lua/patterns" -> cluster "lua"
# topic "" or null -> cluster "uncategorized"
```

### Maintenance Candidate Classification

Based on composite scores, classify each memory:

| Composite Score | Classification | Recommended Action |
|-----------------|----------------|-------------------|
| >= 0.7 | Purge candidate | Remove (--purge) |
| >= 0.5 | Merge/compress candidate | Merge duplicates (--merge) or compress (--compress) |
| >= 0.3 | Review candidate | May benefit from refinement (--refine) |
| < 0.3 | Healthy | No action needed |

Additionally, flag specific conditions:
- `duplicate > 0.6` -> Merge candidate regardless of composite
- `size_penalty > 0.5` -> Compress candidate regardless of composite
- `zero_retrieval == 1.0` -> Review for relevance

### Health Report Template

The `report` sub-mode generates a formatted health report displayed to the user. Template:

```
## Memory Vault Health Report

**Generated**: {today}
**Vault**: .memory/

---

### Overview

| Metric | Value |
|--------|-------|
| Total memories | {total_count} |
| Total tokens | {total_tokens} |
| Average tokens/memory | {avg_tokens} |
| Oldest memory | {oldest_date} ({oldest_id}) |
| Newest memory | {newest_date} ({newest_id}) |

---

### Category Distribution

| Category | Count | Tokens | Avg Score |
|----------|-------|--------|-----------|
| {category_1} | {count} | {tokens} | {avg_composite} |
| {category_2} | {count} | {tokens} | {avg_composite} |
| ... | ... | ... | ... |

---

### Topic Clusters

| Cluster | Memories | Avg Staleness | Avg Duplicate |
|---------|----------|---------------|---------------|
| {cluster_1} | {count} | {avg_staleness} | {avg_duplicate} |
| {cluster_2} | {count} | {avg_staleness} | {avg_duplicate} |
| ... | ... | ... | ... |

---

### Retrieval Statistics

| Metric | Value |
|--------|-------|
| Never retrieved | {never_retrieved_count} ({never_retrieved_pct}%) |
| Retrieved 1-3 times | {low_retrieval_count} |
| Retrieved 4+ times | {high_retrieval_count} |
| Most retrieved | {most_retrieved_id} ({most_retrieved_count} times) |

---

### Maintenance Candidates

#### Purge Candidates (score >= 0.7)
{purge_list or "None"}

#### Merge Candidates (duplicate > 0.6)
{merge_list or "None"}

#### Compress Candidates (size > 0.5)
{compress_list or "None"}

#### Review Candidates (score 0.3-0.7)
{review_list or "None"}

---

### Health Score

**Score**: {health_score}/100
**Status**: {status_emoji} {status_label}

Formula: `100 - (purge_count * 3) - (merge_count * 5) - (compress_count * 2)`

| Threshold | Status |
|-----------|--------|
| 80-100 | Healthy |
| 60-79 | Manageable |
| 40-59 | Concerning |
| 0-39 | Critical |

---

### Recommended Actions

{action_list based on candidates found}
```

#### Health Score Formula

```
health_score = 100 - (purge_count * 3) - (merge_count * 5) - (compress_count * 2)
health_score = clamp(health_score, 0, 100)
```

Where:
- `purge_count` = number of memories with composite score >= 0.7
- `merge_count` = number of memories with duplicate score > 0.6
- `compress_count` = number of memories with size_penalty > 0.5

#### Health Status Thresholds

| Score Range | Status | Description |
|-------------|--------|-------------|
| 80-100 | healthy | Vault is well-maintained |
| 60-79 | manageable | Some maintenance recommended |
| 40-59 | concerning | Significant maintenance needed |
| 0-39 | critical | Urgent maintenance required |

These thresholds mirror `repository_health.status` vocabulary in state.json.

## Shared Sub-Mode Skeleton

Every mutating `/distill` sub-mode below (`purge`, `gc`, `merge`, `compress`, `refine`, `auto`,
and the telemetry-sourced sub-modes added after them) follows the same seven-step shape. This
section states that shape once, with named, generic placeholders; each sub-mode's own section
below states only its deltas from this skeleton -- its specific candidate logic, prompts,
execution steps, and log payload -- rather than restating the shape itself. This generalizes a
convention this file already used once for the `dream` section's `### Overlap Scoring`
cross-reference ("reference the section by name -- do not restate or fork the formula") into a
file-wide rule.

1. **Edge Case Checks** -- Validate preconditions before identifying candidates (e.g. run
   validate-on-read, confirm a minimum count of eligible memories). If a precondition fails,
   display a specific message and return early without further action.
2. **Candidate Identification** -- Compute the sub-mode's specific candidate set from scored or
   otherwise-derived memory data. If a shared dependency like validate-on-read or the Scoring
   Engine is used, cite it by name rather than re-deriving it.
3. **Dry-Run** -- When `--dry-run` is active, display what the sub-mode would do (the specific
   candidate list, with sub-mode-relevant fields) and return early. No file is modified.
4. **Interactive Selection (MANDATORY STOP)** -- Present candidates via `AskUserQuestion`
   (`multiSelect: true` for any sub-mode selecting among multiple candidates). **This step is
   non-negotiable in every sub-mode that mutates the vault: no mutation may proceed without an
   explicit, user-confirmed selection at this step.** If no candidates exist, or the user selects
   none, display a specific message and exit without changes.
5. **Execution** -- Apply the confirmed operation. This step's actual content is the most
   sub-mode-specific of the seven and is stated in full in each sub-mode's own section -- it is
   never usefully reduced to a generic placeholder, since the tombstone/merge/compress/refine/
   delete mechanics differ in every case.
6. **Batch Index Regeneration** -- After the entire batch of confirmed operations completes (not
   after each individual one), regenerate `memory-index.json` (via the "JSON Index Maintenance"
   procedure in `skill-learn/SKILL.md`), `index.md`, and `.memory/10-Memories/README.md`.
7. **Log Entry** -- Log the operation to `.memory/distill-log.json` per the Distill Log Schema
   below, and update the relevant `summary` counter. Also update `memory_health` in
   `specs/state.json` per the State Integration section below.

**Non-mutating sub-modes** (`report`, and later `--review`) do not carry step 4's mandatory stop,
since nothing is proposed for the user to confirm -- each such sub-mode states this exemption
explicitly in its own section rather than leaving it as a silent omission.

### Purge Sub-Mode

The purge sub-mode identifies stale or zero-retrieval memories, presents candidates interactively, and applies a tombstone pattern (frontmatter mutation) rather than deleting files. Follows the Shared Sub-Mode Skeleton above; deltas below.

#### Purge Candidate Identification

After scoring all memories via the Scoring Engine, select purge candidates using an OR condition:

```
purge_candidates = []
for each memory in scored_memories:
  if memory.status == "tombstoned":
    skip  # Already tombstoned
  if memory.topic starts_with "email/preferences/":
    skip  # reserved-namespace purge exemption (task 822, design §5.1) -- gates the WHOLE
          # OR-condition below, not just the zero-retrieval leg (Component 2 above already
          # zeroes zero_retrieval_penalty for this namespace; this second, independent gate is
          # defense-in-depth so a high staleness_score alone can never purge one of these
          # memories either)
  if memory.zero_retrieval_penalty == 1.0 OR memory.staleness_score > 0.8:
    purge_candidates.append(memory)
```

**Edge Case**: If `purge_candidates` is empty, display:
```
No purge candidates found. All memories are healthy or already tombstoned.
```
Then exit the purge sub-mode without further action.

#### Category-Aware TTL Advisory Thresholds

Category TTL thresholds affect **ranking only**, not automatic selection. Memories past their category TTL are sorted to the top of the candidate list.

| Category | TTL (days) | Description |
|----------|-----------|-------------|
| CONFIG | 180 | Configuration knowledge becomes stale fastest |
| WORKFLOW | 365 | Processes evolve but have longer relevance |
| PATTERN | 540 | Design patterns remain relevant longest |
| TECHNIQUE | 270 | Methods need periodic refresh |
| INSIGHT | none | Insights have no TTL (never auto-prioritized) |

#### TTL-Based Ranking

Sort purge candidates for presentation:

```
for each candidate in purge_candidates:
  category = candidate.category
  ttl = TTL_THRESHOLDS[category]  # from table above
  days_since_created = days_between(today, candidate.created)

  if ttl is not None AND days_since_created > ttl:
    candidate.past_ttl = true
    candidate.ttl_excess_days = days_since_created - ttl
  else:
    candidate.past_ttl = false
    candidate.ttl_excess_days = 0

# Sort: past-TTL memories first (by excess days descending), then by composite score descending
purge_candidates.sort(key=lambda c: (-int(c.past_ttl), -c.ttl_excess_days, -c.composite_score))
```

#### Interactive Selection -- MANDATORY STOP

**MANDATORY STOP (Shared Sub-Mode Skeleton, Interactive Selection step). Do NOT tombstone any memories without explicit user selection.**

Present candidates via AskUserQuestion multiSelect:

```json
{
  "question": "Select memories to tombstone (purge). Tombstoned memories are excluded from retrieval but preserved on disk for 7 days before gc can hard-delete them.",
  "header": "Purge Candidates ({count} found)",
  "multiSelect": true,
  "options": [
    {
      "label": "{memory.id}",
      "description": "Score: {composite_score:.2f} | Created: {created} | Retrievals: {retrieval_count} | Tokens: {token_count} | Category: {category}{ttl_warning}"
    }
  ]
}
```

Where `{ttl_warning}` is:
- ` | PAST TTL by {ttl_excess_days}d` if `past_ttl == true`
- empty string if `past_ttl == false`

If the user selects no memories, display:
```
No memories selected for purge. Operation cancelled.
```
Then exit without changes.

#### Dry-Run Behavior

When `--dry-run` is active, show the candidate list and scores but skip tombstone application:

```
[DRY RUN] Would tombstone {count} memories:
  - {memory.id} (score: {composite_score:.2f}, category: {category})
  - ...

No changes made.
```

Exit after displaying the dry-run summary.

#### Tombstone Application

For each selected memory, apply the tombstone by mutating its YAML frontmatter:

```
1. Read the memory file (.memory/10-Memories/MEM-{slug}.md)
2. Parse YAML frontmatter (between --- delimiters)
3. Add three fields after the `summary` field (before `token_count` if present):
   status: tombstoned
   tombstoned_at: {ISO8601 date, e.g., 2026-04-16}
   tombstone_reason: "purge"
4. Write the updated file back to disk
5. Update memory-index.json: set the entry's `status` to "tombstoned"
```

**Frontmatter Example (before)**:
```yaml
---
title: "HTTP request retry patterns"
created: 2026-01-15
tags: [PATTERN]
topic: "python/libs/requests"
source: "user input"
modified: 2026-01-15
summary: "HTTP retry with exponential backoff"
retrieval_count: 0
last_retrieved:
---
```

**Frontmatter Example (after)**:
```yaml
---
title: "HTTP request retry patterns"
created: 2026-01-15
tags: [PATTERN]
topic: "python/libs/requests"
source: "user input"
modified: 2026-01-15
summary: "HTTP retry with exponential backoff"
status: tombstoned
tombstoned_at: 2026-04-16
tombstone_reason: "purge"
retrieval_count: 0
last_retrieved:
---
```

#### Purge Log Entry

After tombstoning, log the operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "purge",
  "session_id": "sess_...",
  "pre_metrics": {
    "total_memories": 10,
    "total_tokens": 5000,
    "health_score": 65,
    "purge_candidates": 4,
    "merge_candidates": 2,
    "compress_candidates": 1
  },
  "post_metrics": {
    "total_memories": 10,
    "total_tokens": 5000,
    "health_score": 78,
    "purge_candidates": 1,
    "merge_candidates": 2,
    "compress_candidates": 1
  },
  "affected_memories": ["MEM-slug-1", "MEM-slug-2", "MEM-slug-3"],
  "notes": "Tombstoned 3 memories. Link-scan warnings: [list or 'none']"
}
```

**Key semantics**: `total_memories` and `total_tokens` remain unchanged in post_metrics because tombstoning preserves files on disk. `purge_candidates` decreases because tombstoned memories are excluded from future scoring. `health_score` improves as maintenance candidates are addressed.

Update the distill-log.json `summary.total_purged` counter by incrementing it by the number of tombstoned memories.

### Link-Scan Procedure

After tombstone application, scan for stale `[[MEM-{slug}]]` references in non-tombstoned memories.

#### Link-Scan Execution

```bash
# For each tombstoned memory slug
for slug in "${affected_slugs[@]}"; do
  # Search non-tombstoned memories for references
  grep -l "\[\[MEM-${slug}\]\]" .memory/10-Memories/MEM-*.md 2>/dev/null | while read ref_file; do
    # Check if the referencing file is itself tombstoned
    ref_status=$(grep -m1 "^status:" "$ref_file" | sed 's/^status: *//')
    if [ "$ref_status" == "tombstoned" ]; then
      continue  # Skip tombstoned files
    fi
    echo "WARNING: ${ref_file} references tombstoned [[MEM-${slug}]]"
  done
done
```

#### Warning Display

Display link-scan warnings to the user (no automatic modification):

```
## Link-Scan Warnings

The following active memories reference tombstoned memories:
- .memory/10-Memories/MEM-http-patterns.md -> [[MEM-requests-retry-patterns]] (tombstoned)
- .memory/10-Memories/MEM-library-setup.md -> [[MEM-requests-retry-patterns]] (tombstoned)

These references will become stale. Consider manually updating the Connections section
in the above files to remove or replace the references.
```

If no stale references are found:
```
Link-scan: No stale references found.
```

#### Link-Scan in Log

Include link-scan warnings in the purge operation's `notes` field in distill-log.json:

```
"notes": "Tombstoned 3 memories. Link-scan warnings: MEM-http-patterns.md->MEM-slug-1, MEM-library-setup.md->MEM-slug-1"
```

Or if none:
```
"notes": "Tombstoned 3 memories. Link-scan warnings: none"
```

### Retrieval Exclusion

Tombstoned memories must be excluded from all retrieval paths.

#### MCP Search Path Exclusion

After MCP search returns results, post-filter to exclude tombstoned entries:

```
For each segment in content_map.segments:
  query = segment.key_terms.join(" ")
  results = execute("search", {
    "query": query,
    "vault": ".memory",
    "limit": 5
  })

  # Post-filter: exclude tombstoned memories
  filtered_results = []
  for result in results:
    id = derive_id_from_result(result)
    index_entry = memory_index.entries[id]
    if index_entry.status == "tombstoned":
      continue  # Skip tombstoned memory
    filtered_results.append(result)
  results = filtered_results
```

#### Grep Fallback Path Exclusion

When using grep-based search, check frontmatter status before including in results:

```bash
# For each segment
for keyword in $key_terms; do
  grep -l -i "$keyword" .memory/10-Memories/*.md 2>/dev/null
done | sort | uniq -c | sort -rn | head -10 | while read count file; do
  # Check if memory is tombstoned
  status=$(grep -m1 "^status:" "$file" | sed 's/^status: *//')
  if [ "$status" == "tombstoned" ]; then
    continue  # Skip tombstoned memory
  fi
  echo "$count $file"
done | head -5
```

#### Scoring Engine Exclusion

In the scoring engine, skip tombstoned memories before computing scores:

```
for each entry in memory_index.entries:
  if entry.status == "tombstoned":
    skip  # Do not score tombstoned memories
  # Proceed with scoring...
```

This ensures tombstoned memories do not appear in:
- Purge candidates (already addressed)
- Merge candidates
- Compress candidates
- Health report statistics (except in a dedicated "Tombstoned Memories" section)

### Health Report -- Tombstoned Memories Section

Add a "Tombstoned Memories" section to the health report template, placed after the "Maintenance Candidates" section:

```
---

### Tombstoned Memories

| Memory | Tombstoned Date | Reason | Days Until GC |
|--------|----------------|--------|---------------|
| {memory.id} | {tombstoned_at} | {tombstone_reason} | {7 - days_since_tombstoned} |
| ... | ... | ... | ... |

**Total tombstoned**: {tombstoned_count}
**Eligible for GC**: {gc_eligible_count} (past 7-day grace period)
```

If no tombstoned memories exist:
```
### Tombstoned Memories

None.
```

### GC Sub-Mode

The gc sub-mode performs hard deletion of tombstoned memories that have passed the 7-day grace period. Follows the Shared Sub-Mode Skeleton above; deltas below. Its logical pair is the Purge Sub-Mode above (with only its own tombstone-related Link-Scan/Retrieval-Exclusion/health-report infrastructure between them, no other sub-mode) -- gc hard-deletes what purge has already tombstoned once the grace period elapses.

#### Grace Period Scan

Identify tombstoned memories eligible for garbage collection:

```
gc_candidates = []
for each entry in memory_index.entries:
  if entry.status == "tombstoned":
    tombstoned_at = parse_date(entry.tombstoned_at or read from frontmatter)
    days_since_tombstoned = days_between(today, tombstoned_at)
    if days_since_tombstoned >= 7:
      gc_candidates.append(entry)
```

**Edge Case**: If no tombstoned memories are past the grace period, display:
```
No tombstoned memories past the 7-day grace period.
{tombstoned_count} tombstoned memories are still within the grace period.
```
Then exit without further action.

#### GC Interactive Selection -- MANDATORY STOP

**MANDATORY STOP (Shared Sub-Mode Skeleton, Interactive Selection step). Do NOT delete any memories without explicit user confirmation.**

Present eligible memories via AskUserQuestion multiSelect:

```json
{
  "question": "Select tombstoned memories to permanently delete. This action cannot be undone.",
  "header": "GC Candidates ({count} past 7-day grace period)",
  "multiSelect": true,
  "options": [
    {
      "label": "{memory.id}",
      "description": "Tombstoned: {tombstoned_at} | Reason: {tombstone_reason} | Original score: {composite_score:.2f} | Tokens: {token_count}"
    }
  ]
}
```

If the user selects no memories, display:
```
No memories selected for deletion. GC cancelled.
```
Then exit without changes.

#### Dry-Run Behavior

When `--dry-run` is active, show eligible memories without deleting:

```
[DRY RUN] Would permanently delete {count} memories:
  - {memory.id} (tombstoned: {tombstoned_at}, reason: {tombstone_reason})
  - ...

No changes made.
```

#### GC Deletion Sequence

For each selected memory, perform hard deletion in this order:

```
1. Delete the .md file:
   rm .memory/10-Memories/MEM-{slug}.md

2. Remove the entry from memory-index.json:
   - Filter out the entry with matching id
   - Decrement entry_count
   - Subtract the entry's token_count from total_tokens
   - Write updated memory-index.json

3. Regenerate index.md:
   - Use the Index Regeneration Pattern (existing procedure)
   - Tombstoned+deleted entries will be absent from filesystem scan

4. Regenerate .memory/10-Memories/README.md:
   - Use the existing README regeneration procedure
   - Deleted files will be absent from the ls scan

5. Update memory_health in specs/state.json:
   - Decrement total_memories by the number of deleted memories
   - Recalculate health_score after removal
```

#### GC Log Entry

Log the gc operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "gc",
  "session_id": "sess_...",
  "pre_metrics": {
    "total_memories": 10,
    "total_tokens": 5000,
    "health_score": 78,
    "purge_candidates": 1,
    "merge_candidates": 2,
    "compress_candidates": 1
  },
  "post_metrics": {
    "total_memories": 7,
    "total_tokens": 3500,
    "health_score": 85,
    "purge_candidates": 1,
    "merge_candidates": 1,
    "compress_candidates": 1
  },
  "affected_memories": ["MEM-slug-1", "MEM-slug-2", "MEM-slug-3"],
  "notes": "Hard-deleted 3 tombstoned memories"
}
```

**Key semantics**: `total_memories` and `total_tokens` are decremented in post_metrics because gc removes files from disk. `health_score` is recalculated after deletion.
### Sub-Mode: merge

Combine duplicate memories with high keyword overlap. The merge operation identifies pairwise duplicate candidates within topic clusters, presents them for interactive selection, merges content with a keyword superset guarantee, tombstones the absorbed secondary, updates cross-references, and regenerates indexes. Follows the Shared Sub-Mode Skeleton above; deltas below. (Its Interactive Selection step below does not restate the MANDATORY STOP language verbatim -- see that step's own text for the exact wording used at this call site.)

#### Edge Case Checks

Before candidate identification, validate:

```
1. Run validate-on-read to ensure memory-index.json is consistent
2. Count non-tombstoned memories (status != "tombstoned" or status absent)
3. If fewer than 2 non-tombstoned memories:
   Display: "Merge requires at least 2 active memories. Vault has {count}."
   Return early.
```

#### Pairwise Keyword Overlap Algorithm

Compute pairwise overlap within each topic cluster:

```
1. Group non-tombstoned memories by topic cluster:
   cluster_key = topic.split("/")[0]
   If topic is empty or null: cluster_key = "uncategorized"

2. For each cluster with 2+ memories, compute pairwise overlap:
   for each pair (A, B) in cluster:
     overlap_ab = |A.keywords intersect B.keywords| / |A.keywords|
     overlap_ba = |A.keywords intersect B.keywords| / |B.keywords|
     pair_overlap = max(overlap_ab, overlap_ba)

   Note: Use max of both asymmetric directions so that a small memory
   with all keywords contained in a larger memory is detected.

3. Handle empty keyword arrays:
   If either A.keywords or B.keywords is empty: pair_overlap = 0.0
   (Cannot merge memories with no keyword basis for comparison)

4. Filter pairs where pair_overlap >= 0.6 (60% threshold)

5. Sort candidate pairs by pair_overlap descending within each cluster
```

#### Dry-Run Mode

When `--dry-run` is set, compute and display candidates without writing any files:

```
Display per cluster:
  ## Merge Candidates (Dry Run)

  ### Cluster: {cluster_key}

  | Primary | Secondary | Overlap | Shared Keywords |
  |---------|-----------|---------|-----------------|
  | {A.id} | {B.id} | {pair_overlap}% | {shared_keywords} |

  {total_pairs} merge candidate pair(s) found across {cluster_count} cluster(s).
  Run /distill --merge without --dry-run to execute.

Return early after display. No files are modified.
```

#### Interactive Selection (AskUserQuestion)

Present merge candidates per topic cluster for user selection:

```
For each cluster with candidates:
  AskUserQuestion({
    "question": "Select pairs to merge in cluster '{cluster_key}':",
    "header": "Merge Candidates: {cluster_key}",
    "multiSelect": true,
    "options": [
      {
        "label": "{A.title} + {B.title}",
        "description": "{pair_overlap}% overlap | Shared: {shared_keywords} | Retrievals: {A.retrieval_count}, {B.retrieval_count}"
      }
    ]
  })
```

If no pairs above threshold in any cluster:
```
Display: "No merge candidates found (no pairs with >= 60% keyword overlap)."
Return early.
```

If user selects no pairs across all clusters:
```
Display: "No pairs selected. No merges performed."
Return early.
```

#### Primary Determination

For each selected pair, determine which memory is primary (target) and which is secondary (absorbed):

```
Primary selection rules (first match wins):
1. Higher retrieval_count -> primary
2. If retrieval_count equal: older created date -> primary
3. If both equal: alphabetically first id -> primary (deterministic tiebreaker)
```

#### Merged Content Template

The primary memory file is rewritten with merged content:

**Frontmatter merging rules**:
```
title:            primary.title (unchanged)
created:          min(primary.created, secondary.created) -- earliest
modified:         today (ISO date)
tags:             union(primary.tags, secondary.tags) -- deduplicated
topic:            primary.topic (unchanged)
source:           primary.source (unchanged)
keywords:         union(primary.keywords, secondary.keywords) -- deduplicated, sorted
summary:          primary.summary (unchanged)
retrieval_count:  primary.retrieval_count + secondary.retrieval_count
last_retrieved:   max(primary.last_retrieved, secondary.last_retrieved) -- most recent, skip nulls
token_count:      recomputed after merge (word_count * 1.3, rounded down)
status:           omit (active is default when absent)
```

**Content structure**:
```markdown
---
{merged frontmatter}
---

# {primary.title}

{primary existing content - everything between title heading and first ## section}

## Merged From {secondary.id}

**Original Title**: {secondary.title}
**Merged**: {today}
**Overlap Score**: {pair_overlap}%

{secondary content - everything between title heading and ## Connections in secondary}

## Connections
{union of both connection sections, with [[{secondary.id}]] references replaced by [[{primary.id}]]}
```

#### Keyword Superset Guarantee

**CRITICAL INVARIANT**: Before writing the merged file, verify:

```
required_keywords = union(primary.keywords, secondary.keywords)
merged_keywords = merged_frontmatter.keywords

assertion: set(merged_keywords) >= set(required_keywords)

If assertion fails:
  Log error: "KEYWORD SUPERSET VIOLATION: missing keywords: {required - merged}"
  Abort this merge pair (do not write file)
  Preserve both original files unchanged
  Continue with remaining pairs
  Report violation in operation summary
```

This guarantee ensures no keyword coverage is lost during merging.

#### Tombstone Application

After successful merge, tombstone the secondary memory:

```
Add to secondary's frontmatter (preserve all existing fields):
  status: tombstoned
  tombstoned_at: {today ISO8601}
  tombstone_reason: "merged_into:{primary.id}"

Do NOT delete the file.
Do NOT remove from index (index regeneration will include tombstone status).
```

The tombstone fields are identical to those used by the purge sub-mode (task 450):
- `status: tombstoned`
- `tombstoned_at: {ISO8601 date}`
- `tombstone_reason: "{reason}"` -- for merge, reason is `"merged_into:{primary_id}"`

#### Cross-Reference Update

After tombstoning, update wiki-link references across all non-tombstoned memories:

```
1. Scan all .memory/10-Memories/*.md files
2. For each file that is NOT tombstoned:
   Search for [[{secondary.id}]] references
   Replace with [[{primary.id}]]
3. Log all replacements: "{file}: replaced [[{secondary.id}]] -> [[{primary.id}]]"
```

#### Index Regeneration

After ALL merges in the batch are complete (not after each individual merge):

```
1. Regenerate memory-index.json using "JSON Index Maintenance" procedure
   - Include tombstoned memories with status: "tombstoned"
2. Regenerate index.md using "Index Regeneration Pattern"
   - Exclude tombstoned memories from active listings
3. Regenerate .memory/10-Memories/README.md
   - Exclude tombstoned memories from the listing
```

#### Distill Log Entry

Log each merge operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "merge",
  "session_id": "sess_...",
  "pre_metrics": {
    "total_memories": N,
    "total_tokens": N,
    "health_score": N,
    "purge_candidates": N,
    "merge_candidates": N,
    "compress_candidates": N
  },
  "post_metrics": {
    "total_memories": N,
    "total_tokens": N,
    "health_score": N,
    "purge_candidates": N,
    "merge_candidates": N,
    "compress_candidates": N
  },
  "affected_memories": [
    {
      "primary": "{primary.id}",
      "secondary": "{secondary.id}",
      "overlap_score": 0.75,
      "keywords_before": [5, 4],
      "keywords_after": 7,
      "keyword_superset_verified": true,
      "action": "merged"
    }
  ],
  "notes": "Merged {N} pair(s) across {M} cluster(s)"
}
```

The `keywords_before` array contains `[primary_keyword_count, secondary_keyword_count]`. The `keywords_after` value is the merged keyword count. The `keyword_superset_verified` boolean confirms the superset guarantee held for this pair.

### Sub-Mode: compress

Reduce oversized memories to key points while preserving essential information. The compress operation identifies memories with high size penalty, presents them interactively, generates compressed versions, preserves originals in a History section, and ensures keyword preservation. Follows the Shared Sub-Mode Skeleton above; deltas below.

#### Edge Case Checks

Before candidate identification, validate:

```
1. Run validate-on-read to ensure memory-index.json is consistent
2. Count non-tombstoned memories (status != "tombstoned" or status absent)
3. If no non-tombstoned memories:
   Display: "No memories in vault to compress."
   Return early.
```

#### Compress Candidate Identification

After scoring all memories via the Scoring Engine, select compress candidates:

```
compress_candidates = []
for each memory in scored_memories:
  if memory.status == "tombstoned":
    skip  # Already tombstoned
  if memory.size_penalty > 0.5:  # token_count > 900
    compress_candidates.append(memory)

Sort by size_penalty descending (largest memories first)
```

**Edge Case**: If `compress_candidates` is empty, display:
```
No compress candidates found. All memories are within size limits (token_count <= 900).
```
Then exit the compress sub-mode without further action.

#### Dry-Run Behavior

When `--dry-run` is active, show candidates with estimates without writing any files:

```
## Compress Candidates (Dry Run)

| Memory | Tokens | Size Penalty | Topic | Est. Compressed |
|--------|--------|-------------|-------|-----------------|
| {id} | {token_count} | {size_penalty:.2f} | {topic} | ~{token_count * 0.4} |

{count} compress candidate(s) found.
Run /distill --compress without --dry-run to execute.
```

Return early after display. No files are modified.

#### Interactive Selection -- MANDATORY STOP

**MANDATORY STOP (Shared Sub-Mode Skeleton, Interactive Selection step). Do NOT compress any memories without explicit user selection.**

Present candidates via AskUserQuestion multiSelect:

```json
{
  "question": "Select memories to compress. Original content will be preserved in a History section.",
  "header": "Compress Candidates ({count} found)",
  "multiSelect": true,
  "options": [
    {
      "label": "{memory.id}",
      "description": "Tokens: {token_count} | Size penalty: {size_penalty:.2f} | Topic: {topic} | Retrievals: {retrieval_count}"
    }
  ]
}
```

If the user selects no memories, display:
```
No memories selected for compression. Operation cancelled.
```
Then exit without changes.

#### Compression Execution

For each selected memory, compress following these steps:

```
1. Read the full memory file (.memory/10-Memories/MEM-{slug}.md)
2. Parse frontmatter and content sections
3. Extract original keywords from frontmatter

4. Generate compressed content:
   - Extract key points as bullet list
   - Preserve code blocks and examples verbatim
   - Remove redundant prose, verbose explanations, and filler
   - Target ~60% reduction (soft guideline, not enforced)
   - Maintain the core information and actionable details

5. Move original content to History section:
   - Insert before ## Connections section (if present), or at end of file
   - Use heading: ## History > ### Pre-Compression ({today})
   - Include full original content (between title heading and ## Connections)

6. Write compressed content as main body (between title heading and ## History)

7. Update frontmatter:
   - Recalculate token_count: word_count * 1.3, rounded down
   - Update modified to today (ISO date)
   - Preserve all other frontmatter fields unchanged

8. Keyword preservation check:
   original_keywords = set(memory.keywords)
   compressed_keywords = extract_keywords(compressed_content)
   missing = original_keywords - keywords_in_compressed_content

   If missing keywords found:
     - Add missing keywords explicitly to the compressed content
       (append "**Keywords**: {missing_keywords}" line if needed)
     - Log: "Keyword preservation: added {N} missing keywords to compressed content"

9. Write the updated memory file
```

#### Compressed Content Template

```markdown
---
{preserved frontmatter with updated token_count and modified}
---

# {title}

{compressed content - key points as bullet list, preserved code blocks}

## History

### Pre-Compression ({today})

{original content that was between title heading and ## Connections}

## Connections
{preserved connections section}
```

#### Batch Index Regeneration

After ALL compressions in the batch are complete (not after each individual compression):

```
1. Regenerate memory-index.json using "JSON Index Maintenance" procedure
   - Updated token_count values will be reflected
2. Regenerate index.md using "Index Regeneration Pattern"
3. Regenerate .memory/10-Memories/README.md
```

#### Compress Log Entry

Log the compress operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "compress",
  "session_id": "sess_...",
  "pre_metrics": {
    "total_memories": N,
    "total_tokens": N,
    "health_score": N,
    "purge_candidates": N,
    "merge_candidates": N,
    "compress_candidates": N
  },
  "post_metrics": {
    "total_memories": N,
    "total_tokens": N,
    "health_score": N,
    "purge_candidates": N,
    "merge_candidates": N,
    "compress_candidates": N
  },
  "affected_memories": [
    {
      "id": "{memory.id}",
      "tokens_before": N,
      "tokens_after": N,
      "compression_ratio": 0.42,
      "keywords_preserved": true,
      "action": "compressed"
    }
  ],
  "notes": "Compressed {N} memories. Total tokens saved: {tokens_saved}"
}
```

The `compression_ratio` is `tokens_after / tokens_before` (lower means more compression). The `keywords_preserved` boolean confirms all original keywords are present in the compressed content.

Update the distill-log.json `summary.total_compressed` counter by incrementing it by the number of compressed memories.

### Sub-Mode: refine

Improve memory metadata quality through two tiers of fixes. Tier 1 fixes are safe automatic corrections that require no user interaction. Tier 2 fixes are interactive improvements that require user confirmation via AskUserQuestion. Follows the Shared Sub-Mode Skeleton above; deltas below. (Tier 1 has no Interactive Selection step by design -- see Tier 1 below for the exemption.)

#### Edge Case Checks

Before candidate scanning, validate:

```
1. Run validate-on-read to ensure memory-index.json is consistent
2. Count non-tombstoned memories (status != "tombstoned" or status absent)
3. If no non-tombstoned memories:
   Display: "No memories in vault to refine."
   Return early.
```

#### Quality Issue Scanning

Iterate all non-tombstoned memories and scan for quality issues:

```
tier1_fixes = []   # Automatic, no confirmation needed
tier2_fixes = []   # Interactive, require AskUserQuestion

for each memory in non_tombstoned_memories:
  # Read full memory file for content analysis

  # --- Tier 1: Automatic Fixes ---

  # 1. Keyword deduplication
  if memory.keywords has duplicates (case-insensitive):
    tier1_fixes.append({
      "memory": memory.id,
      "fix": "keyword_dedup",
      "description": "Remove duplicate keywords (case-insensitive, keep first occurrence)",
      "before": memory.keywords,
      "after": deduplicated_keywords
    })

  # 2. Summary generation
  if memory.summary is empty or missing:
    generated_summary = first_line_of_content[:100]  # Truncate to ~100 chars
    tier1_fixes.append({
      "memory": memory.id,
      "fix": "summary_gen",
      "description": "Generate summary from first line of content",
      "before": "",
      "after": generated_summary
    })

  # 3. Topic normalization
  if memory.topic has uppercase letters OR missing "/" separators OR trailing slashes:
    normalized_topic = memory.topic.lower().strip("/")
    tier1_fixes.append({
      "memory": memory.id,
      "fix": "topic_normalize",
      "description": "Normalize topic path (lowercase, clean separators)",
      "before": memory.topic,
      "after": normalized_topic
    })

  # --- Tier 2: Interactive Fixes ---

  # 4. Keyword enrichment
  if len(memory.keywords) < 4:
    suggested_keywords = extract_keywords_from_content(memory.content, 5)
    new_keywords = [k for k in suggested_keywords if k not in memory.keywords]
    if new_keywords:
      tier2_fixes.append({
        "memory": memory.id,
        "fix": "keyword_enrich",
        "description": "Add suggested keywords based on content analysis",
        "current_keywords": memory.keywords,
        "suggested_additions": new_keywords[:5]
      })

  # 5. Category reclassification
  # Skip entirely when the memory has an explicit frontmatter `category:` field (task 822,
  # design §3.4) -- an explicit category is authoritative and never content-inferred; this
  # only fires for the tags-derivation fallback path (pre-822 memories, and any future memory
  # without a `category:` field).
  if not memory.has_explicit_category_field:
    content_category = infer_category_from_content(memory.content)
    if content_category != memory.category:
      tier2_fixes.append({
        "memory": memory.id,
        "fix": "category_reclassify",
        "description": "Category may not match content",
        "current_category": memory.category,
        "suggested_category": content_category
      })

  # 6. Topic path correction
  cluster_topics = get_topic_patterns_from_cluster(memory.topic)
  if memory.topic not consistent with cluster_topics:
    tier2_fixes.append({
      "memory": memory.id,
      "fix": "topic_correct",
      "description": "Topic path inconsistent with cluster patterns",
      "current_topic": memory.topic,
      "suggested_topic": corrected_topic
    })
```

#### "No Issues Found" Early Return

If both `tier1_fixes` and `tier2_fixes` are empty:
```
No quality issues found. All memories have clean metadata.
```
Then exit without further action.

#### Tier 1 Execution (Automatic)

Tier 1 fixes run without user interaction:

```
1. Display summary of Tier 1 fixes to be applied:
   ## Tier 1 Automatic Fixes

   | Memory | Fix | Description |
   |--------|-----|-------------|
   | {id} | keyword_dedup | Removed {N} duplicate keywords |
   | {id} | summary_gen | Generated summary from content |
   | {id} | topic_normalize | Normalized topic path |

2. Apply each fix:
   - keyword_dedup: Rewrite keywords array in frontmatter (case-insensitive dedup, keep first)
   - summary_gen: Add/update summary field in frontmatter
   - topic_normalize: Update topic field in frontmatter

3. Update modified date to today for each affected memory
```

#### Tier 2 Interactive Selection -- MANDATORY STOP

**MANDATORY STOP (Shared Sub-Mode Skeleton, Interactive Selection step), if Tier 2 fixes exist. Do NOT apply Tier 2 fixes without explicit user selection.**

If `tier2_fixes` is not empty, present via AskUserQuestion multiSelect:

```json
{
  "question": "Select quality improvements to apply (Tier 2 - interactive fixes):",
  "header": "Refine Candidates ({count} issues found)",
  "multiSelect": true,
  "options": [
    {
      "label": "{memory.id}: {fix_type}",
      "description": "{description} | Current: {current_value} | Suggested: {suggested_value}"
    }
  ]
}
```

If the user selects no fixes, display:
```
No Tier 2 fixes selected. Only Tier 1 automatic fixes were applied.
```

#### Tier 2 Execution

For each selected Tier 2 fix:

```
- keyword_enrich: Append suggested keywords to frontmatter keywords array
- category_reclassify: Update first tag in frontmatter tags array
- topic_correct: Update topic field in frontmatter

Update modified date to today for each affected memory.
```

#### Batch Index Regeneration

After ALL fixes (Tier 1 and Tier 2) are complete:

```
1. Regenerate memory-index.json using "JSON Index Maintenance" procedure
2. Regenerate index.md using "Index Regeneration Pattern"
3. Regenerate .memory/10-Memories/README.md
```

#### Refine Log Entry

Log the refine operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "refine",
  "session_id": "sess_...",
  "pre_metrics": {
    "total_memories": N,
    "total_tokens": N,
    "health_score": N,
    "purge_candidates": N,
    "merge_candidates": N,
    "compress_candidates": N
  },
  "post_metrics": {
    "total_memories": N,
    "total_tokens": N,
    "health_score": N,
    "purge_candidates": N,
    "merge_candidates": N,
    "compress_candidates": N
  },
  "affected_memories": [
    {
      "id": "{memory.id}",
      "fixes_applied": ["keyword_dedup", "summary_gen"],
      "action": "refined"
    }
  ],
  "notes": "Refined {N} memories. Tier 1: {T1_count} fixes, Tier 2: {T2_count} fixes"
}
```

Update the distill-log.json `summary.total_refined` counter by incrementing it by the number of refined memories.

### Sub-Mode: auto

Automated non-interactive maintenance that runs only safe Tier 1 refine fixes. The auto mode is designed for routine maintenance without human oversight -- it explicitly excludes compress (requires AI-generated summaries that need review), purge, and merge. Its steps are a restricted delta against the Shared Sub-Mode Skeleton above: it has no Interactive Selection step by design (that is the whole point of "automated non-interactive"), so this is one of the sanctioned MANDATORY-STOP exemptions alongside `report` and (once specified) `--review`.

#### Auto Execution Flow

```
1. Run validate-on-read:
   - Check memory-index.json consistency with filesystem
   - Regenerate if stale

2. Run Tier 1 refine fixes ONLY (no AskUserQuestion calls):
   - Keyword deduplication: remove duplicate keywords (case-insensitive, keep first)
   - Summary generation: for memories with empty/missing summary, generate from first line of content (~100 chars)
   - Topic normalization: lowercase all topic paths, ensure "/" separators, no trailing slashes

3. For each fix applied:
   - Update the memory file frontmatter
   - Update modified date to today

4. Rebuild memory-index.json from filesystem state:
   - Use "JSON Index Maintenance" procedure
   - Regenerate index.md and .memory/10-Memories/README.md

5. Update memory_health in state.json:
   - Recalculate health_score
   - Update last_distilled timestamp
   - Increment distill_count

6. Skip ALL interactive operations:
   - No AskUserQuestion calls
   - No Tier 2 refine fixes
   - No compress operations
   - No purge operations
   - No merge operations
   - No dream operations
```

#### Explicitly Excluded Operations

| Operation | Reason for Exclusion |
|-----------|---------------------|
| Compress | AI-generated summaries require human review |
| Purge | Tombstoning decisions need user judgment |
| Merge | Content combination needs user oversight |
| Tier 2 Refine | Interactive fixes require user selection |
| Dream | Event-evidence-driven revision is a judgment call requiring human review |

#### Change Summary Display

After auto mode completes, display a summary of changes:

```
## Auto Distill Complete

| Fix Type | Count | Details |
|----------|-------|---------|
| Keyword dedup | {N} | Removed duplicates in {N} memories |
| Summary gen | {N} | Generated summaries for {N} memories |
| Topic normalize | {N} | Normalized topics in {N} memories |

**Total fixes**: {total_count} across {memory_count} memories
**Health score**: {score}/100 ({status})
```

#### "No Changes Needed" Edge Case

If no Tier 1 fixes are applicable:
```
Auto distill: No changes needed. All memories have clean metadata.
Health score: {score}/100 ({status})
```

#### Auto Log Entry

Log the auto operation to `.memory/distill-log.json`:

```json
{
  "id": "distill_{timestamp}",
  "timestamp": "ISO8601",
  "type": "refine",
  "session_id": "sess_...",
  "pre_metrics": { ... },
  "post_metrics": { ... },
  "affected_memories": [
    {
      "id": "{memory.id}",
      "fixes_applied": ["keyword_dedup"],
      "action": "refined"
    }
  ],
  "notes": "auto mode - Tier 1 fixes only. Applied {N} fixes to {M} memories"
}
```

Note: Auto mode uses `type: "refine"` (not a separate type) with `"notes"` containing `"auto mode"` to distinguish from interactive refine operations.

### Sub-Mode: revise

Event-and-OTel-correlated review and revision of the memory vault. `--revise` inherits, in
substance unchanged, the current `dream` section's Event Ingestion, Event-to-Memory Correlation,
corroborated/contradicted/gap Classification (three-strikes threshold), the `AskUserQuestion`
UPDATE/TOMBSTONE/CREATE gate, and Batch Index Regeneration -- this content is relocated from
`dream` (Phase 10 removes the now-duplicated copy from `dream` once this section and `--meta`
below fully contain it). **New in this sub-mode**: Tier 1 (OTel) supplies outcome evidence,
joined on `cc_session_id`, alongside the existing Tier 2 (`events.jsonl`) correlation. Follows
the Shared Sub-Mode Skeleton above; deltas below. See
`context/project/memory/telemetry-guardrails.md` for the miss-rate expectation and the
never-auto-apply rule -- not restated here.

#### Edge Case Checks

```
1. Run validate-on-read to ensure memory-index.json is consistent with the filesystem
2. Count non-tombstoned memories (status != "tombstoned" or status absent)
3. If no non-tombstoned memories:
   Display: "No memories in vault to revise. Use /learn to add memories first."
   Return early.
```

#### Candidate Identification: Event Ingestion (Tier 2)

`--revise` reads the unified event store exclusively through `events-query.sh` -- **hand-rolled
`jq` against `specs/events.jsonl` is prohibited**, per the script's own header contract. Every
call below additionally takes `--since {last_revise}` once `memory_health.last_revise` is set
(mirroring the existing `last_dream`/`dream_count` pattern in State Integration, with its own
`last_revise`/`revise_count` fields), so every run after the first is bounded to events captured
since the previous revise. Invoke via the mandatory chained relative form -- see
`telemetry-guardrails.md`'s cross-repo invocation discipline:

```bash
GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"
cd "$GLOBAL_ROOT" && bash .claude/scripts/events-query.sh --format summary-counts [--since {last_revise}]
```

In order:

1. **Cheap gate** -- an aggregate count before pulling full event bodies:
   ```bash
   events-query.sh --format summary-counts [--since {last_revise}]
   ```
2. **Deviation/blocker pull** -- the primary signal for memory contradiction/gap detection:
   ```bash
   events-query.sh --category deviation --format json-array [--since {last_revise}]
   events-query.sh --category blocker --format json-array [--since {last_revise}]
   ```
3. **Reflection pull** -- completion-time structured reflections:
   ```bash
   events-query.sh --event-type reflection --format json-array [--since {last_revise}]
   ```

**Why the event store, not `state.json`'s `reflection` field**: `state.json`'s per-task
`reflection` field is overwrite-only / most-recent-only. The event store's `reflection`-typed
events are append-only across a task's entire history, so `--revise` sees every reflection ever
captured for a task, not just whichever one happens to currently sit in `state.json`.

#### Candidate Identification: OTel Outcome Join (Tier 1, New)

For each event pulled above that carries a non-null `cc_session_id`, query OTel for outcome
records from that same session (via whatever OTel query surface is available in the deployment
-- this sub-mode does not itself stand up a collector or query language; it consumes an existing
one). The join is exact and requires no time-window heuristic:

```
cc_session_id (events.jsonl) == session.id (OTel event/span/metric)
```

A memory can be classified `contradicted` by citing an OTel `tool_result.error_type` alongside a
`deviation` event from the same session -- outcome evidence corroborating or sharpening the
`events.jsonl`-derived signal, never replacing it. OTel-derived evidence is cited inside `detail`
using the borrowed `gen_ai.*` / `error.type` keys, per `telemetry-guardrails.md`'s `gen_ai.*`
borrowing rule -- e.g.:

```json
{
  "detail": {
    "events_jsonl_event_id": "evt_1736700010789_g7h8i9",
    "gen_ai.usage.input_tokens": 1200,
    "error.type": "ENOENT"
  }
}
```

**Degraded path -- OTel not enabled**: when `CLAUDE_CODE_ENABLE_TELEMETRY=1` is unset, this join
contributes nothing. This is an explicitly-announced, first-class outcome, generalizing the
existing "No Events Yet" pattern below:

```
OTel not enabled for this session -- outcome evidence unavailable. Correlation proceeds using
events.jsonl alone (Tier 2), with zero OTel-sourced corroboration this run.
```

#### No Events Yet (Degraded Path)

**This is a normal, first-class outcome -- not an error.** Verified live: when
`specs/events.jsonl` does not exist yet, `events-query.sh --format summary-counts` returns
`{"total_events":0,"by_category":{},"by_event_type":{}}` and `--format json-array` returns `[]`,
both exiting 0. This is the expected day-one experience.

When the summary-counts gate reports `total_events: 0`, display:

```
No events captured yet in specs/events.jsonl -- revise proceeds using vault scoring alone
(staleness/duplicate/size), with zero event correlations this run.
```

Continuation rule: `--revise` does NOT stop or treat this as an error. It proceeds exactly as
`/distill --refine` would, using only the existing Scoring Engine, and reports zero
corroborated/contradicted/gap correlations.

#### Event-to-Memory Correlation

Two-tier correlation, reusing existing formulas rather than inventing a new one:

- **Tier (a) -- task-number substring match**: for each pulled event with a non-null `task`
  field, substring-match the task number against each memory's free-text `source` frontmatter
  field (e.g. an event with `"task": 259` matches a memory whose `source` contains `"259"` in a
  task-directory-shaped context). This is the high-confidence tier.
- **Tier (b) -- keyword/topic overlap fallback**: for events with no task-number match (or no
  `task` field), fall back to the existing overlap formula from `### Overlap Scoring` above,
  scoring the event's `message`/`detail` text against each memory's `keywords`. Reference that
  section by name -- do not restate or fork the formula here.

#### Classification

Each memory with at least one correlated event (Tier 2) or OTel outcome record (Tier 1) is
classified into exactly one bucket:

| Classification | Meaning |
|-----------------|---------|
| Corroborated | Correlated evidence is consistent with the memory's existing guidance -- no contradiction found. |
| Contradicted | Correlated evidence (deviation/blocker event, optionally sharpened by an OTel error outcome from the same `cc_session_id`) shows the memory's guidance no longer holds, or is stale relative to captured evidence. |
| Gap | Correlated evidence points at a recurring pattern with no existing memory covering it. |

**Recurrence threshold**: a pattern must occur **three or more times** at the same
checkpoint/event_type combination to be treated as `contradicted` (rather than a one-off) or
surfaced as a `gap` candidate. This three-strikes threshold is the same one the Convergence
Policing Contract's Divergence Audit precedent (`context/contracts/convergence.md`) uses for
churn detection -- reused here by name, not reinvented.

Memories with zero correlated evidence are left out of this classification entirely; they are
still covered by the ordinary Scoring Engine as usual.

#### Dry-Run

When `--dry-run` is active, print the full three-bucket classification (corroborated /
contradicted / gap) with per-memory counts and the specific correlated event IDs/messages (and
any OTel-sourced `detail` citations) cited as evidence, and perform **zero writes**:

```
[DRY RUN] Revise classification:
  Corroborated: {count} memories (no action)
  Contradicted: {count} memories -- would prompt UPDATE/tombstone/skip
  Gap: {count} candidate memories -- would prompt CREATE

No changes made.
```

Exit after displaying the dry-run summary.

#### Interactive Selection (MANDATORY STOP)

**MANDATORY STOP (Shared Sub-Mode Skeleton, Interactive Selection step). YOU MUST call
`AskUserQuestion` for the contradicted and gap buckets before writing anything. Do NOT infer what
the user wants. Do NOT apply any UPDATE/CREATE/tombstone without explicit user selection.** This
is the evaluator-outside-the-loop rule from `telemetry-guardrails.md`: no sub-mode may treat its
own prior output as primary evidence, and mutation never proceeds without this stop.

##### Corroborated Handling

No write. The memory and its corroborating evidence (event IDs, and OTel citations if present)
are recorded in the revise summary/log only (see Revise Log Schema below) -- corroboration is
informational, not actionable.

##### Contradicted / Stale Handling

Present each contradicted memory via `AskUserQuestion`, with three options. Each option's
`description` MUST cite the specific correlated evidence, and the UPDATE option MUST show the
**proposed new memory body** for review -- never a bare yes/no confirmation:

```json
{
  "question": "Memory '{memory.id}' appears contradicted by {N} captured events. How should it be handled?",
  "header": "Contradicted: {memory.id}",
  "multiSelect": false,
  "options": [
    {
      "label": "UPDATE",
      "description": "Evidence: {event_id_1} ({message_1}), {event_id_2} ({message_2})[, OTel: {error.type}]. Proposed new body:\n\n{proposed_new_memory_body}"
    },
    {
      "label": "TOMBSTONE",
      "description": "Mark superseded by revise evidence: {event_id_1} ({message_1})"
    },
    {
      "label": "SKIP",
      "description": "Take no action this run"
    }
  ]
}
```

- **UPDATE**: apply via the existing `### UPDATE Operation` template -- old guidance moves to
  `## History`, the corrected guidance (sourced from event/OTel evidence) becomes the new main
  content.
- **TOMBSTONE**: apply via the existing tombstone frontmatter pattern (see the Purge Sub-Mode's
  `#### Tombstone Application` above) with `tombstone_reason: "revise_superseded"` -- a new
  *value* for the existing field, not a new schema.
- **SKIP**: no write.

##### Gap Handling

Present each gap candidate via `AskUserQuestion`, evidence-cited the same way. Before offering
CREATE, apply the escalation discriminator:

- If the gap represents durable domain/technique knowledge that fits the existing
  TECHNIQUE/PATTERN/CONFIG/WORKFLOW/INSIGHT taxonomy, offer **CREATE** via the existing
  `### CREATE Operation` template, sourced from the event's `detail`/`message` content.
- If the gap instead represents a *system change* (a skill, hook, rule, or doc that should
  differ), it escalates to an **Improvement Proposal** (`--meta`, below) instead of a memory
  CREATE -- `--revise` never creates a memory to paper over a system defect.

#### Batch Index Regeneration

After all UPDATE/TOMBSTONE/CREATE writes for this revise run are complete (and only after --
never per-memory):

```
1. Regenerate memory-index.json using "JSON Index Maintenance" procedure
2. Regenerate index.md using "Index Regeneration Pattern"
3. Regenerate .memory/10-Memories/README.md
```

#### Revise Log Schema

Operations are logged to `.memory/revise-log.json`, mirroring the shape of
`.memory/distill-log.json`:

```json
{
  "version": "1.0.0",
  "operations": [
    {
      "id": "revise_{timestamp}",
      "timestamp": "ISO8601",
      "type": "revise",
      "session_id": "sess_...",
      "since": "ISO8601 or null (first run)",
      "events_ingested": {
        "total_events": 0,
        "deviation": 0,
        "blocker": 0,
        "reflection": 0
      },
      "otel_joins": {
        "sessions_with_cc_session_id": 0,
        "otel_enabled": true,
        "outcome_records_matched": 0
      },
      "classification": {
        "corroborated": 0,
        "contradicted": 0,
        "gap": 0
      },
      "affected_memories": [
        {
          "id": "{memory.id}",
          "classification": "contradicted",
          "action": "updated|tombstoned|skipped",
          "evidence_event_ids": ["evt_..."],
          "otel_evidence": {"error.type": "ENOENT"}
        }
      ],
      "notes": ""
    }
  ],
  "summary": {
    "total_revised": 0,
    "total_corroborated": 0,
    "total_contradicted": 0,
    "total_gaps_created": 0,
    "last_operation": null
  }
}
```

`otel_joins.otel_enabled: false` records the degraded path explicitly rather than leaving the
absence of OTel-sourced evidence ambiguous with "OTel was checked and found nothing."

### Sub-Mode: meta

Cross-repo agent-system improvement proposals. `--meta` inherits, in substance unchanged, the
current `dream` section's "Improvement Proposals" discovery, presentation, and confirmation
logic -- this content is relocated from `dream` (Phase 10 removes the now-duplicated copy from
`dream` once this section fully contains it). **New in this sub-mode**: explicit cross-repo
target resolution via the existing `$GLOBAL_ROOT` mechanism, and delegation of task creation to
`meta-builder-agent` rather than reimplementing the `/task` primitive inline. Follows the Shared
Sub-Mode Skeleton above; deltas below.

#### Edge Case Checks

```
1. Resolve target_root (see Target Resolution below)
2. Run validate-on-read against the resolved repo's event/reflection sources
3. If zero deviation/blocker/reflection signal is available at target_root:
   Display: "No agent-system improvement signal found in this repo's specs/events.jsonl or
   reflections. Nothing to propose this run."
   Return early.
```

#### Target Resolution (Consumes, Does Not Invent)

`--meta` consumes the existing global-root mechanism verbatim. **It does not invent a parallel
resolver.**

```bash
GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"
target_root="$GLOBAL_ROOT"
# --local opts out of the cross-repo default, scoping to the invoking repo instead:
if [ -n "${DISTILL_META_LOCAL:-}" ] || [[ " $* " == *" --local "* ]]; then
  target_root="$(pwd)"
fi
cd "$target_root" && bash .claude/scripts/events-query.sh --format summary-counts
```

Running `--meta` from a session already inside `$GLOBAL_ROOT` is a genuine no-op for this step
(`target_root` resolves to the same directory the session is already in), not a special branch
requiring its own handling.

**Single-repo signal limitation** (stated here, in this flag's own description, not only in
commentary): `events.jsonl` is a per-repo file. `--meta` invoked against `$GLOBAL_ROOT` sees only
`$GLOBAL_ROOT`'s own event store, not aggregated signal from every other repo this agent system
runs in. `events-query.sh`'s `--repo` filter operates within a single file and does **not** close
this gap. Cross-repo aggregation is an explicit out-of-scope follow-up (see
`telemetry-guardrails.md`'s Cross-Repo Signal Limitation).

#### Candidate Identification: Discovery

Unchanged in substance from the current `dream` section's discovery logic. A proposal candidate
is surfaced when either:
- A recurring (three-strikes, per the `--revise` Classification step above) deviation/blocker
  event points at a named skill, hook, rule, or lifecycle stage/checkpoint, or
- A recurring `what_was_hard` / `what_was_missed` phrase appears across reflection events for the
  same or related task types.

**Extension targeting**: `meta-builder-agent` is expected to decide which of this system's
extension directories (`agent-system/extensions/{core,cslib,email,epidemiology,filetypes,formal,
founder,latex,lean,literature,memory,nix,nvim,present,python,slidev,typst,web,z3}/`) a proposal
should contribute to. **Do not write new detection logic here.**
`meta-builder-agent.md`'s own documented "Known limitation" states its affected-area heuristic
"has no reliable signal to distinguish core scope from an extension's own source directory ...
without parsing extension manifests, so extension-scoped tasks require human correction rather
than a guess" -- it defaults to `agent-system/extensions/core/` and relies on the delegation
contract's own `AskUserQuestion` selection/modification step (below) for a human to correct
extension-scoped proposals. `--meta` inherits this exact limitation rather than working around
it; a future improvement to `meta-builder-agent`'s own detection benefits `--meta` automatically
with no change needed here.

#### Dry-Run

When `--dry-run` is active, display the full candidate list (summary, evidence citations, and the
`meta-builder-agent`-resolved affected area where available, or "core (default -- verify manually)"
where the known limitation above applies) and perform **zero task creation**:

```
[DRY RUN] Improvement proposal candidates ({count}):
  - {candidate.summary} (evidence: {event_id_1}, {event_id_2}, {event_id_3}; affected area:
    {affected_area or "core (default -- verify manually)"})
  - ...

No tasks created.
```

#### Interactive Selection (MANDATORY STOP)

**Presentation**: `AskUserQuestion` `multiSelect`, one row per candidate:

```json
{
  "question": "meta surfaced {N} recurring agent-system improvement candidates at {target_root}. What should happen with each?",
  "header": "Improvement Proposals",
  "multiSelect": true,
  "options": [
    {
      "label": "{candidate.summary}",
      "description": "Evidence: {event_id_1} ({message_1}), {event_id_2} ({message_2}), {event_id_3} ({message_3}) -- recurring at checkpoint '{checkpoint}'"
    }
  ]
}
```

For each selected candidate, a second `AskUserQuestion` (or a combined per-row selector) offers:
- **Create as task** -- delegated to `meta-builder-agent` (see Execution below)
- **Note in report only** -- recorded in the meta-log but no task created
- **Skip** -- discarded entirely

**MANDATORY STOP (Shared Sub-Mode Skeleton, Interactive Selection step). Do NOT delegate task
creation for any candidate without explicit user selection at this step.** This is the
evaluator-outside-the-loop rule from `telemetry-guardrails.md`.

**Confirmation gate**: before any task is actually created, show the full list of confirmed
"Create as task" candidates and require an explicit "Yes, create tasks" confirmation (Multi-Task
Creation Standard Component 7) -- mirroring every other multi-task creator in this codebase,
including the user's opportunity to select and modify the proposed tasks before anything is
created.

#### Execution: Delegation Contract to `meta-builder-agent`

**Task creation delegates to `meta-builder-agent` via the Agent tool. Do not reimplement the
`/task` primitive inline.**

**What is passed**:
```json
{
  "proposal_set": [
    {
      "summary": "{candidate.summary}",
      "evidence_event_ids": ["evt_..."],
      "checkpoint": "{checkpoint}",
      "affected_area_hint": "{meta-builder-agent-resolved area, or null}"
    }
  ],
  "target_root": "{resolved target_root}",
  "orchestrator_mode": false
}
```

**What comes back**: one created (or user-modified/declined) `task_type: "meta"` task entry per
confirmed proposal, each with its own task number, `file_scope` (seeded by `meta-builder-agent`
from the paths the triggering events implicate), and TODO.md/state.json entries -- all via
`meta-builder-agent`'s own existing Stage 0-N pipeline (interactive review, component selection,
multi-task creation standard compliance), not reinvented here.

**What `--meta` does with it**: records the returned task numbers in the meta-log (below) and
reports them to the user; performs no further mutation of `specs/state.json` or `TODO.md` itself
-- `meta-builder-agent` owns that write.

**Doc-edit-proposal rule**: a proposal whose remedy is "edit file X's prose" (rather than create a
new task) is a **report-only finding**. `--meta` MUST NOT edit any file itself. Recommending a doc
edit is always surfaced as a finding for the user to act on, never applied automatically.

**Cross-repo invocation discipline**: any `events-query.sh` (or other memory/event script) call
this sub-mode makes uses the mandatory chained relative form --
`cd "$target_root" && bash .claude/scripts/{name}.sh ...` in a single Bash tool call. Absolute-path
invocation is prohibited; a `cd` from an earlier, separate tool call must never be assumed to
persist. See `telemetry-guardrails.md`'s cross-repo invocation discipline -- not restated further
here.

#### Batch Index Regeneration

Not applicable to `--meta` in the vault-index sense (this sub-mode does not mutate
`.memory/10-Memories/*.md` or `memory-index.json`) -- its "batch" write is the set of
`meta-builder-agent`-created tasks, which regenerate their own `TODO.md`/`state.json` via
`meta-builder-agent`'s existing pipeline, not via the JSON Index Maintenance procedure this step
otherwise refers to.

#### Meta Log Schema

Operations are logged to `.memory/meta-log.json`, mirroring the shape of
`.memory/distill-log.json`:

```json
{
  "version": "1.0.0",
  "operations": [
    {
      "id": "meta_{timestamp}",
      "timestamp": "ISO8601",
      "type": "meta",
      "session_id": "sess_...",
      "target_root": "/home/user/.config/nvim",
      "proposals": {
        "surfaced": 0,
        "created_as_task": 0,
        "noted_only": 0,
        "skipped": 0,
        "task_numbers_created": []
      },
      "notes": ""
    }
  ],
  "summary": {
    "total_meta_runs": 0,
    "total_proposals_created": 0,
    "last_operation": null
  }
}
```

### Sub-Mode: dream

Event-store-informed review and revision of the memory vault, plus a separate improvement-proposal
deliverable for the agent system itself. Dream mode reuses every existing distill primitive
(Scoring Engine, UPDATE/EXTEND/CREATE/tombstone operations, batch index regeneration, distill-log
conventions) -- it adds event evidence as a new correlation input, not a new mutation mechanism.

#### Edge Case Checks

```
1. Run validate-on-read to ensure memory-index.json is consistent with the filesystem
2. Count non-tombstoned memories (status != "tombstoned" or status absent)
3. If no non-tombstoned memories:
   Display: "No memories in vault to dream over. Use /learn to add memories first."
   Return early.
```

#### Event Ingestion

Dream mode reads the unified event store exclusively through `events-query.sh` -- **hand-rolled
`jq` against `specs/events.jsonl` is prohibited**, per the script's own header contract. Every call
below additionally takes `--since {last_dream}` once `memory_health.last_dream` is set (see State
Integration below), so every run after the first is bounded to events captured since the previous
dream.

In order:

1. **Cheap gate** -- an aggregate count before pulling full event bodies:
   ```bash
   events-query.sh --format summary-counts [--since {last_dream}]
   ```
2. **Deviation/blocker pull** -- the primary signal for memory contradiction/gap detection:
   ```bash
   events-query.sh --category deviation --format json-array [--since {last_dream}]
   events-query.sh --category blocker --format json-array [--since {last_dream}]
   ```
3. **Reflection pull** -- completion-time structured reflections:
   ```bash
   events-query.sh --event-type reflection --format json-array [--since {last_dream}]
   ```

#### Why the Event Store, Not `state.json`'s `reflection` Field

`state.json`'s per-task `reflection` field is overwrite-only / most-recent-only -- it holds at most
the latest reflection captured for a task. The event store's `reflection`-typed events are
append-only across a task's entire history, so dream mode reads from the store to see every
reflection ever captured for a task, not just whichever one happens to currently sit in
`state.json`.

#### No Events Yet (Degraded Path)

**This is a normal, first-class outcome -- not an error.** Verified live: when
`specs/events.jsonl` does not exist yet, `events-query.sh --format summary-counts` returns
`{"total_events":0,"by_category":{},"by_event_type":{}}` and `--format json-array` returns `[]`,
both exiting 0. This is the expected day-one experience, and remains the expected experience for
any repository until the event store accumulates history.

When the summary-counts gate reports `total_events: 0`, display:

```
No events captured yet in specs/events.jsonl -- dream review proceeds using vault scoring alone
(staleness/duplicate/size), with zero event correlations this run.
```

Continuation rule: dream mode does NOT stop or treat this as an error. It proceeds exactly as
`/distill --refine` would, using only the existing Scoring Engine, and reports zero
corroborated/contradicted/gap correlations. The Improvement Proposals section (below) likewise
reports zero candidates in this case.

#### Event-to-Memory Correlation

Two-tier correlation, reusing existing formulas rather than inventing a new one:

- **Tier (a) -- task-number substring match**: for each pulled event with a non-null `task` field,
  substring-match the task number against each memory's free-text `source` frontmatter field
  (e.g. an event with `"task": 259` matches a memory whose `source` contains `"259"` in a
  task-directory-shaped context). This is the high-confidence tier.
- **Tier (b) -- keyword/topic overlap fallback**: for events with no task-number match (or no
  `task` field), fall back to the existing overlap formula from `### Overlap Scoring` above,
  scoring the event's `message`/`detail` text against each memory's `keywords`. Reference that
  section by name -- do not restate or fork the formula here.

#### Classification

Each memory with at least one correlated event is classified into exactly one bucket:

| Classification | Meaning |
|-----------------|---------|
| Corroborated | Correlated events are consistent with the memory's existing guidance -- no contradiction found. |
| Contradicted | Correlated events (deviation/blocker) show the memory's guidance no longer holds, or is stale relative to captured evidence. |
| Gap | Correlated events point at a recurring pattern with no existing memory covering it. |

**Recurrence threshold**: a pattern must occur **three or more times** at the same
checkpoint/event_type combination to be treated as `contradicted` (rather than a one-off) or
surfaced as a `gap` candidate. This three-strikes threshold is the same one the Convergence
Policing Contract's Divergence Audit precedent (`context/contracts/convergence.md`) uses for churn
detection -- reused here by name, not reinvented.

Memories with zero correlated events are left out of the dream classification entirely; they are
still covered by the ordinary Scoring Engine as usual.

#### Dry-Run Behavior

When `--dry-run` is active, print the full three-bucket classification (corroborated /
contradicted / gap) with per-memory counts and the specific correlated event IDs/messages cited as
evidence, and perform **zero writes** -- matching the contract every other distill sub-mode
honors:

```
[DRY RUN] Dream classification:
  Corroborated: {count} memories (no action)
  Contradicted: {count} memories -- would prompt UPDATE/tombstone/skip
  Gap: {count} candidate memories -- would prompt CREATE

No changes made.
```

Exit after displaying the dry-run summary.

#### Interactive Selection -- MANDATORY STOP

**YOU MUST call AskUserQuestion for the contradicted and gap buckets before writing anything. Do
NOT infer what the user wants. Do NOT apply any UPDATE/CREATE/tombstone without explicit user
selection.**

##### Corroborated Handling

No write. The memory and its corroborating event IDs are recorded in the dream summary/log only
(see Dream Log Schema below) -- corroboration is informational, not actionable.

##### Contradicted / Stale Handling

Present each contradicted memory via `AskUserQuestion`, with three options. Each option's
`description` MUST cite the specific correlated event IDs/messages as evidence, and the UPDATE
option MUST show the **proposed new memory body** for review -- never a bare yes/no confirmation:

```json
{
  "question": "Memory '{memory.id}' appears contradicted by {N} captured events. How should it be handled?",
  "header": "Contradicted: {memory.id}",
  "multiSelect": false,
  "options": [
    {
      "label": "UPDATE",
      "description": "Evidence: {event_id_1} ({message_1}), {event_id_2} ({message_2}). Proposed new body:\n\n{proposed_new_memory_body}"
    },
    {
      "label": "TOMBSTONE",
      "description": "Mark superseded by dream evidence: {event_id_1} ({message_1})"
    },
    {
      "label": "SKIP",
      "description": "Take no action this run"
    }
  ]
}
```

- **UPDATE**: apply via the existing `### UPDATE Operation` template -- old guidance moves to
  `## History`, the corrected guidance (sourced from event evidence) becomes the new main content.
- **TOMBSTONE**: apply via the existing tombstone frontmatter pattern (see `#### Tombstone
  Application` above) with `tombstone_reason: "dream_superseded"` -- a new *value* for the existing
  field, not a new schema.
- **SKIP**: no write.

##### Gap Handling

Present each gap candidate via `AskUserQuestion`, evidence-cited the same way. Before offering
CREATE, apply the escalation discriminator:

- If the gap represents durable domain/technique knowledge that fits the existing
  TECHNIQUE/PATTERN/CONFIG/WORKFLOW/INSIGHT taxonomy, offer **CREATE** via the existing
  `### CREATE Operation` template, sourced from the event's `detail`/`message` content.
- If the gap instead represents a *system change* (a skill, hook, rule, or doc that should differ),
  it escalates to an **Improvement Proposal** (below) instead of a memory CREATE -- dream mode
  never creates a memory to paper over a system defect.

#### Batch Index Regeneration

After all UPDATE/TOMBSTONE/CREATE writes for this dream run are complete (and only after -- never
per-memory):

```
1. Regenerate memory-index.json using "JSON Index Maintenance" procedure
2. Regenerate index.md using "Index Regeneration Pattern"
3. Regenerate .memory/10-Memories/README.md
```

#### Improvement Proposals

**A separate deliverable from memory revision** -- never merged into the same list. Memory
revisions mutate `.memory/10-Memories/*.md` under the primitives above; improvement proposals
optionally create new `task_type: "meta"` task directories under `specs/`. The two have different
destinations and different write permissions, and are presented as two distinct sections in every
dream run's output.

**Discovery**: a proposal candidate is surfaced when either:
- A recurring (three-strikes, per Classification above) deviation/blocker event points at a named
  skill, hook, rule, or lifecycle stage/checkpoint, or
- A recurring `what_was_hard` / `what_was_missed` phrase appears across reflection events for the
  same or related task types.

**Presentation**: `AskUserQuestion` `multiSelect`, one row per candidate:

```json
{
  "question": "Dream mode surfaced {N} recurring agent-system improvement candidates. What should happen with each?",
  "header": "Improvement Proposals",
  "multiSelect": true,
  "options": [
    {
      "label": "{candidate.summary}",
      "description": "Evidence: {event_id_1} ({message_1}), {event_id_2} ({message_2}), {event_id_3} ({message_3}) -- recurring at checkpoint '{checkpoint}'"
    }
  ]
}
```

For each selected candidate, a second `AskUserQuestion` (or a combined per-row selector) offers:
- **Create as task** -- becomes a new task (see Task Creation below)
- **Note in dream report only** -- recorded in the dream-log/report but no task created
- **Skip** -- discarded entirely

**Confirmation gate**: before any task is actually created, show the full list of confirmed
"Create as task" candidates and require an explicit "Yes, create tasks" confirmation (Multi-Task
Creation Standard Component 7) -- mirroring every other multi-task creator in this codebase.

**Task creation** (Required-components-only compliance, matching `/errors`' "Partial" framing):
each confirmed proposal becomes one independent `task_type: "meta"` entry, created via the same
primitive `/task`'s Create Task Mode uses: read and increment `next_project_number`, append to
`active_projects` in `specs/state.json`, call `generate-todo.sh`, and git commit. `file_scope` is
seeded from the paths the triggering events implicate (e.g. the named skill/hook/rule file).
Deliberately out of scope for v1: topic grouping, dependency interview, Kahn's-algorithm ordering,
and DAG visualization -- exactly the same intentional gap `/errors` documents for its own automatic
mode.

**Doc-edit-proposal rule**: a proposal whose remedy is "edit file X's prose" (rather than create a
new task) is a **report-only finding**. Dream mode MUST NOT edit any file outside `.memory/`,
`state.json`'s `memory_health` field, and the dream/distill logs. Recommending a doc edit is always
surfaced as a finding for the user to act on, never applied automatically.

#### Dream Log Schema

Operations are logged to `.memory/dream-log.json`, mirroring the shape of
`.memory/distill-log.json`:

```json
{
  "version": "1.0.0",
  "operations": [
    {
      "id": "dream_{timestamp}",
      "timestamp": "ISO8601",
      "type": "dream",
      "session_id": "sess_...",
      "since": "ISO8601 or null (first run)",
      "events_ingested": {
        "total_events": 0,
        "deviation": 0,
        "blocker": 0,
        "reflection": 0
      },
      "classification": {
        "corroborated": 0,
        "contradicted": 0,
        "gap": 0
      },
      "affected_memories": [
        {
          "id": "{memory.id}",
          "classification": "contradicted",
          "action": "updated|tombstoned|skipped",
          "evidence_event_ids": ["evt_..."]
        }
      ],
      "proposals": {
        "surfaced": 0,
        "created_as_task": 0,
        "noted_only": 0,
        "skipped": 0,
        "task_numbers_created": []
      },
      "notes": ""
    }
  ],
  "summary": {
    "total_dreamed": 0,
    "total_corroborated": 0,
    "total_contradicted": 0,
    "total_gaps_created": 0,
    "total_proposals_created": 0,
    "last_operation": null
  }
}
```

#### Narrative Dream Report (Terminal-Only)

The human-readable synthesis of a dream run -- vault classification summary plus improvement
proposal candidates -- is displayed **in-terminal only**, exactly as the bare `/distill` health
report already is (which is likewise never written to disk). `.memory/dream-log.json` is the
machine-queryable persisted record. Dream mode does **not** create a
`.memory/20-Indices/dream-report-{date}.md` file: `20-Indices/` holds regenerated vault indexes,
not dated run reports, and adding one would invent a new artifact type for no gain. A user who
wants the narrative persisted can redirect the command's output themselves.

### Distill Log Schema

Operations are logged to `.memory/distill-log.json` for tracking maintenance history.

#### Schema

```json
{
  "version": "1.0.0",
  "operations": [
    {
      "id": "distill_{timestamp}",
      "timestamp": "ISO8601",
      "type": "report|purge|merge|compress|refine|gc|dream",
      "session_id": "sess_...",
      "pre_metrics": {
        "total_memories": 0,
        "total_tokens": 0,
        "health_score": 100,
        "purge_candidates": 0,
        "merge_candidates": 0,
        "compress_candidates": 0
      },
      "post_metrics": {
        "total_memories": 0,
        "total_tokens": 0,
        "health_score": 100,
        "purge_candidates": 0,
        "merge_candidates": 0,
        "compress_candidates": 0
      },
      "affected_memories": [],
      "notes": ""
    }
  ],
  "summary": {
    "total_operations": 0,
    "total_purged": 0,
    "total_merged": 0,
    "total_compressed": 0,
    "total_refined": 0,
    "total_gc_deleted": 0,
    "total_dreamed": 0,
    "last_operation": null
  }
}
```

#### Operation Types

| Type | Description | Task |
|------|-------------|------|
| `report` | Health report generated (read-only) | 449 |
| `purge` | Memories removed via tombstone pattern | 450 |
| `merge` | Duplicate memories combined | 451 |
| `compress` | Oversized memories summarized | 452 |
| `refine` | Memory quality improved | 452 |
| `gc` | Hard-delete tombstoned memories past grace period | 450 |
| `dream` | Event-store-informed memory review plus improvement proposals | -- |

For `report` operations, `pre_metrics` and `post_metrics` are identical (no changes made).

### State Integration

After each distill operation, update `memory_health` in `specs/state.json`:

```json
{
  "memory_health": {
    "last_distilled": "ISO8601 timestamp",
    "distill_count": 1,
    "total_memories": 5,
    "never_retrieved": 2,
    "health_score": 85,
    "status": "healthy",
    "last_dream": "ISO8601 timestamp or null (never dreamed)",
    "dream_count": 0
  }
}
```

The `memory_health` field is a top-level sibling of `repository_health` in state.json. Update it after every distill operation (including report-only operations).

**Field update rules by sub-mode**:

| Field | report | purge/merge/compress/refine/gc/auto | dream |
|-------|--------|-------------------------------------|-------|
| `last_distilled` | Updated | Updated | Updated |
| `distill_count` | NOT incremented | Incremented | Incremented |
| `total_memories` | Updated | Updated | Updated |
| `never_retrieved` | Updated | Updated | Updated |
| `health_score` | Updated | Updated | Updated |
| `status` | Updated | Updated | Updated |
| `last_dream` | NOT updated | NOT updated | Updated |
| `dream_count` | NOT updated | NOT updated | Incremented |

**Rationale**: The `report` sub-mode is read-only -- it generates a health report without modifying any memory files. Since `distill_count` tracks the number of maintenance operations that actually changed the vault, report-only invocations should not increment it. The `last_distilled` timestamp is still updated for all sub-modes because it tracks when the vault was last assessed, not when it was last modified. `last_dream`/`dream_count` mirror `last_distilled`/`distill_count` but scoped to dream runs only -- they are untouched by every other sub-mode, including report, since those never ingest the event store.


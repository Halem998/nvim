# Plan: Clean orphaned index entries from Website index.json

**Task**: 302
**Date**: 2026-03-26
**Status**: Ready

## Updated Assessment

The research report identified 26 orphans (24 lean4 + 2 pitch-deck). Since then, tasks 297-300 modified the index significantly (now 256 entries). The lean4 entries have already been removed. Only **2 orphans remain**:

1. `project/filetypes/patterns/pitch-deck-structure.md`
2. `project/filetypes/patterns/touying-pitch-deck-template.md`

## Implementation

### Phase 1: Remove orphaned entries [NOT STARTED]

1. Build list of orphaned paths (files referenced but not on disk)
2. Use jq to filter them out of index.json
3. Write filtered result back

### Phase 2: Verify [NOT STARTED]

1. Count entries before/after (expect 256 -> 254)
2. Re-run orphan check to confirm zero remaining

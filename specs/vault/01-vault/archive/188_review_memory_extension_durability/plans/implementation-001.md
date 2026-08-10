# Implementation Plan: Task #188

- **Task**: 188 - review_memory_extension_durability
- **Status**: [COMPLETED]
- **Effort**: 2-3 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**:
  - .claude/context/core/formats/plan-format.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

This plan addresses durability and reliability concerns in the memory extension system identified during research. The key issues are: (1) memory ID race conditions during concurrent CREATE operations, (2) index.md concurrent write conflicts, and (3) system-specific branding in shared documentation. The approach modifies both Claude and OpenCode skill files to use collision-resistant IDs, adds atomic index regeneration patterns, and updates documentation to be system-agnostic.

### Research Integration

Key findings from research-001.md:
- Extension loader uses merge-copy semantics - existing files NEVER overwritten (no action needed)
- Both systems share `.memory/` vault at project root (by design, but documentation should clarify)
- Memory ID format `MEM-{date}-{sequence}` has race condition potential
- MCP ports differ (22360 vs 27124) - already isolated (document only)

## Goals & Non-Goals

**Goals**:
- Eliminate memory ID collision risk during concurrent writes
- Make index.md updates atomic or regenerable
- Update documentation to be system-agnostic for shared vault
- Document MCP usage patterns for dual-system awareness

**Non-Goals**:
- Changing shared vault architecture (this is intentional design)
- Adding cross-system locking (complexity not justified by risk)
- Modifying extension loader behavior (already safe)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing memory ID parsing | High | Low | New format is superset of old, existing IDs remain valid |
| Index regeneration adds latency | Low | Medium | Only regenerate; existing entries unaffected |
| Skill file drift between systems | Medium | Medium | Apply identical changes to both, document sync requirement |

## Implementation Phases

### Phase 1: Update Memory ID Generation [COMPLETED]

**Goal**: Replace sequence-based ID with collision-resistant format

**Tasks**:
- [ ] Update `.claude/extensions/memory/skills/skill-memory/SKILL.md` CREATE Operation section
- [ ] Update `.opencode/extensions/memory/skills/skill-memory/SKILL.md` CREATE Operation section
- [ ] Change ID format from `MEM-{today}-{sequence}` to `MEM-{today}-{unix_ms}-{random_4}`

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Lines 308-319 (CREATE Operation)
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md` - Lines 308-319 (CREATE Operation)

**Details**:

Current format:
```
MEM-{today}-{sequence}
Example: MEM-2026-03-12-001
```

New format:
```
MEM-{today}-{unix_ms}-{random_4}
Example: MEM-2026-03-12-1710256800123-a7b3
```

Generation algorithm:
```bash
today=$(date +%Y-%m-%d)
unix_ms=$(date +%s%N | head -c13)  # milliseconds
random_4=$(od -An -N2 -tx1 /dev/urandom | tr -d ' ')
memory_id="MEM-${today}-${unix_ms}-${random_4}"
```

**Verification**:
- ID format regex: `MEM-\d{4}-\d{2}-\d{2}-\d{13}-[a-f0-9]{4}`
- Test concurrent generation produces unique IDs

---

### Phase 2: Add Atomic Index Regeneration [COMPLETED]

**Goal**: Make index.md updates safe for concurrent access

**Tasks**:
- [ ] Add "Index Regeneration" section to both SKILL.md files
- [ ] Update Index Maintenance section with regeneration-first approach
- [ ] Specify filesystem-as-source-of-truth pattern

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - After Index Maintenance section (~line 387)
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md` - After Index Maintenance section (~line 387)

**Details**:

Add new "Index Regeneration" subsection under Index Maintenance:

```markdown
### Index Regeneration Pattern

To avoid concurrent write conflicts, regenerate index.md from filesystem state rather than append:

```bash
# 1. List all memory files
memories=$(ls .memory/10-Memories/MEM-*.md 2>/dev/null)

# 2. Extract metadata from each file
for mem in $memories; do
  id=$(grep -m1 "^id:" "$mem" | cut -d: -f2 | tr -d ' ')
  title=$(grep -m1 "^title:" "$mem" | cut -d'"' -f2)
  topic=$(grep -m1 "^topic:" "$mem" | cut -d'"' -f2)
  date=$(grep -m1 "^date:" "$mem" | cut -d: -f2 | tr -d ' ')
  # Store for index generation
done

# 3. Regenerate index.md from extracted data
# Sort by date descending, write complete file
```

Benefits:
- No append conflicts (complete overwrite)
- Self-healing (missing entries recovered)
- Idempotent (multiple regenerations produce same result)
```

**Verification**:
- Index regeneration produces valid index.md structure
- Running regeneration twice produces identical output

---

### Phase 3: Update Shared Vault Documentation [COMPLETED]

**Goal**: Make `.memory/README.md` system-agnostic

**Tasks**:
- [ ] Update `.claude/extensions/memory/data/.memory/README.md` with dual-system awareness
- [ ] Update `.opencode/extensions/memory/data/.memory/README.md` with same content
- [ ] Add "Concurrent Usage" section documenting single-MCP-at-a-time pattern

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/memory/data/.memory/README.md` - Full update
- `.opencode/extensions/memory/data/.memory/README.md` - Full update

**Details**:

Update header section:
```markdown
# Shared Memory Vault

This directory contains an Obsidian-compatible vault shared between Claude Code and OpenCode AI systems. Memories created by either system are accessible to both.

## Multi-System Usage

This vault is intentionally shared across AI systems:
- Both Claude Code and OpenCode can read all memories
- Both systems can create and update memories
- Memory IDs include timestamps for collision resistance
- Index files are regenerated from filesystem state

### MCP Server Considerations

Only one AI system should use MCP-based search at a time:
- Claude Code: Uses WebSocket port 22360
- OpenCode: Uses REST API port 27124

Both systems fall back to grep-based search when MCP is unavailable, which works safely in concurrent scenarios.
```

**Verification**:
- No Claude-specific or OpenCode-specific branding in shared docs
- Concurrent usage guidance is clear

---

### Phase 4: Update MCP Documentation [COMPLETED]

**Goal**: Document MCP isolation and concurrent usage patterns

**Tasks**:
- [ ] Update `.claude/extensions/memory/context/project/memory/memory-setup.md` if exists
- [ ] Create or update `.opencode/extensions/memory/context/project/memory/memory-setup.md`
- [ ] Add "Multi-System Architecture" section

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/memory/context/project/memory/memory-setup.md` (may need creation)
- `.opencode/extensions/memory/context/project/memory/memory-setup.md` (may need creation)

**Details**:

Add section explaining dual-system architecture:
```markdown
## Multi-System Architecture

The memory extension is designed to work across both Claude Code and OpenCode:

### Shared Components
- `.memory/` vault at project root (single source of truth)
- Memory ID format: `MEM-{date}-{unix_ms}-{random_4}`
- Index regeneration from filesystem

### System-Specific Components
- MCP server configuration (different ports, different protocols)
- Context reference paths (`.claude/` vs `.opencode/`)
- Extension loading mechanics

### Concurrent Usage Safety

| Scenario | Safety | Notes |
|----------|--------|-------|
| Both reading memories | Safe | No conflicts |
| One writing, one reading | Safe | Atomic file writes |
| Both writing different memories | Safe | Unique IDs per write |
| Both updating same memory | Last-write-wins | Rare edge case |
| Both using MCP | Avoid | Use one system's MCP at a time |
```

**Verification**:
- Documentation exists for both systems
- Concurrent patterns are clearly documented

---

### Phase 5: Verification and Testing [COMPLETED]

**Goal**: Validate all changes work correctly

**Tasks**:
- [ ] Verify SKILL.md files are syntactically valid (grep for template markers)
- [ ] Verify README.md files have no system-specific branding
- [ ] Test memory ID generation produces valid format
- [ ] Document verification results

**Timing**: 30 minutes

**Files to modify**:
- None (verification only)

**Verification**:
```bash
# Check ID format is updated in both SKILL files
grep -n "MEM-{today}-{unix_ms}" .claude/extensions/memory/skills/skill-memory/SKILL.md
grep -n "MEM-{today}-{unix_ms}" .opencode/extensions/memory/skills/skill-memory/SKILL.md

# Check README is system-agnostic
grep -i "claude code memory vault" .claude/extensions/memory/data/.memory/README.md  # Should fail
grep -i "shared memory vault" .claude/extensions/memory/data/.memory/README.md  # Should succeed

# Verify index regeneration pattern exists
grep -n "Index Regeneration Pattern" .claude/extensions/memory/skills/skill-memory/SKILL.md
grep -n "Index Regeneration Pattern" .opencode/extensions/memory/skills/skill-memory/SKILL.md
```

## Testing & Validation

- [ ] Both SKILL.md files contain identical CREATE operation logic
- [ ] Memory ID regex matches new format: `MEM-\d{4}-\d{2}-\d{2}-\d{13}-[a-f0-9]{4}`
- [ ] Index regeneration section present in both skills
- [ ] README.md is system-agnostic (no "Claude Code Memory Vault" title)
- [ ] MCP documentation exists for both systems

## Artifacts & Outputs

- `plans/implementation-001.md` (this file)
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` (updated)
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md` (updated)
- `.claude/extensions/memory/data/.memory/README.md` (updated)
- `.opencode/extensions/memory/data/.memory/README.md` (updated)
- `.claude/extensions/memory/context/project/memory/memory-setup.md` (created or updated)
- `.opencode/extensions/memory/context/project/memory/memory-setup.md` (created or updated)
- `summaries/implementation-summary-YYYYMMDD.md` (on completion)

## Rollback/Contingency

If implementation fails or causes issues:

1. **SKILL.md rollback**: Revert to `MEM-{today}-{sequence}` format; existing memories remain valid with either format
2. **Index regeneration rollback**: Remove new section; original append logic still present
3. **Documentation rollback**: Git revert to previous README.md versions

All changes are backward-compatible. Existing memory files with old ID format remain valid and searchable. No data migration required.

## Memory Extension

Knowledge capture and retrieval via the memory vault. Supports text, file, directory, and task-based memory creation with MCP-backed search and deduplication. Includes vault distillation for scoring, health reporting, and automated maintenance.

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-memory | (direct execution) | Memory creation, distillation, and management |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/learn` | `/learn "text"` | Add text as memory (with content mapping and deduplication) |
| `/learn` | `/learn /path/to/file` | Add file content as memory |
| `/learn` | `/learn /path/to/dir/` | Scan directory for learnable content |
| `/learn` | `/learn --task N` | Review task artifacts and create memories |
| `/distill` | `/distill` | Generate memory vault health report with scoring |
| `/distill` | `/distill --purge` | Tombstone stale memories (interactive purge) |
| `/distill` | `/distill --merge` | Combine duplicate memories by keyword overlap |
| `/distill` | `/distill --compress` | Summarize oversized memories to key points |
| `/distill` | `/distill --refine` | Improve memory metadata quality (keywords, tags, topics) |
| `/distill` | `/distill --gc` | Hard-delete tombstoned memories past 7-day grace period |
| `/distill` | `/distill --auto` | Automated Tier 1 maintenance (non-interactive) |

### Memory-Augmented Research

Memory retrieval is automatic: when the memory extension is loaded, `/research`, `/plan`, and `/implement` preflight stages call `memory-retrieve.sh` to inject relevant memories as `<memory-context>` into the agent context. The `--clean` flag on these commands suppresses auto-retrieval.

### Literature-Augmented Research

The `--lit` flag is the complementary context-injection mechanism to memory retrieval. While `--clean` suppresses memory retrieval, `--lit` adds literature file injection from `specs/literature/`. The two flags are independent and combinable: `--clean --lit` suppresses memory but still injects literature; `--lit` alone injects both memory (if available) and literature. See the "Literature Mode (`--lit`)" section in CLAUDE.md for full details on `specs/literature/` conventions, token budget, and composability with other flags.

### Memory Lifecycle

```
/learn -> create memories -> auto-retrieval in /research, /plan, /implement
                          -> /todo harvests memory candidates from completed tasks
                          -> /distill scores, reports, and maintains the vault
```

### Validate-on-Read

There is no `--reindex` command. The memory system uses validate-on-read: before any scoring or retrieval operation, `memory-index.json` is compared against the filesystem. If stale (missing entries or orphaned entries), the index is automatically regenerated. This provides self-healing index consistency without explicit user intervention.

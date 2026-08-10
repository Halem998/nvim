# Extension Consolidation Strategy: Literature + Zotero → Unified Literature Extension

## 1. Current Extension Inventory

### Literature Extension (fully implemented)

| Artifact Type | Files | Purpose |
|---------------|-------|---------|
| **Agent** | `literature-agent.md` | Documentation-only (direct execution pattern) |
| **Commands** | `literature.md`, `cite.md` | /literature and /cite entry points |
| **Skills** | `skill-literature/SKILL.md`, `skill-cite/SKILL.md` | Conversion, indexing, validation, search; citation verification |
| **Scripts** | `zotero-search.sh`, `cite-extract.sh` | CSL-JSON library search; citation pattern extraction |
| **Manifest** | `routing_exempt: true`, deps: `[core, filetypes]` | No task_type routing; provides tooling commands |
| **Merge targets** | EXTENSION.md → CLAUDE.md (section `extension_literature`) | Docs injection |

### Zotero Extension (skeleton only — scripts exit code 2)

| Artifact Type | Files | Purpose |
|---------------|-------|---------|
| **Agent** | `zotero-agent.md` | Documentation-only (direct execution pattern) |
| **Commands** | `zotero.md` | /zotero entry point |
| **Skills** | `skill-zotero/SKILL.md` | Per-repo index management, chunking, context injection |
| **Scripts** | 9 scripts (all stubs): `zotero-read.sh`, `zotero-write.sh`, `zotero-setup.sh`, `zotero-chunk.sh`, `zotero-attach-chunks.sh`, `zotero-index-add.sh`, `zotero-index-remove.sh`, `zotero-retrieve.sh`, `zotero-search-index.sh` | CLI wrappers, chunk pipeline, index management, context injection |
| **Context** | `project/zotero/domain/zotero-index.md`, `project/zotero/patterns/retrieval-flags.md` | Index schema reference, --zot vs --lit guide |
| **Manifest** | `routing_exempt: true`, deps: `[core, literature]`, keyword_overrides: `{zotero, bibliography, citation} → meta` | No task_type routing; depends on literature |
| **Merge targets** | EXTENSION.md → CLAUDE.md (section `extension_zotero`), index-entries.json → index.json | Docs + context injection |

### Implementation Status

| Zotero Task | Scope | Status |
|------------|-------|--------|
| Task 749 | Extension skeleton | Complete |
| Task 750 | CLI wrapper scripts (read/write/setup) | Not started |
| Task 751 | Index management (add/remove/search) | Not started |
| Task 752 | Chunk pipeline (convert/attach) | Not started |
| Task 753 | Context injection (--zot flag wiring) | Not started |

**Key finding**: The zotero extension is ~95% unimplemented. All 9 scripts are stubs that exit with code 2. This is a major advantage for consolidation — there is minimal working code to preserve from the zotero extension side.

## 2. Dependency and Overlap Analysis

### Dependency Chain

```
core ← filetypes ← literature ← zotero
```

The zotero extension explicitly depends on literature and shares chunk storage at `specs/literature/{citation_key}/`. The literature extension already contains `zotero-search.sh` for CSL-JSON search.

### Functional Overlap

| Capability | Literature Extension | Zotero Extension |
|-----------|---------------------|-----------------|
| PDF → markdown conversion | `skill-literature` Convert mode (pdftotext-based) | `zotero-chunk.sh` (stub; would call literature's converter) |
| Content-aware chunking | `skill-literature` (4,000-line threshold, heading detection) | `zotero-chunk.sh` (stub; would reuse literature's chunker) |
| Index maintenance | `specs/literature/index.json` (16 fields, enriched schema v2) | `specs/zotero-index.json` (20 fields, includes Zotero metadata) |
| Zotero library search | `zotero-search.sh` (CSL-JSON, weighted scoring) | `zotero-search-index.sh` (stub; per-repo index search) |
| Context injection | `literature-retrieve.sh` → `<literature-context>` (--lit flag) | `zotero-retrieve.sh` (stub) → `<zotero-context>` (--zot flag) |
| Import pipeline | `skill-literature` Search mode (symlink + convert + patch) | `zotero-index-add.sh` (stub; `zot` CLI-based metadata fetch) |
| Citation verification | `skill-cite` + `cite-extract.sh` | — |
| PDF upload to Zotero | — | `zotero-attach-chunks.sh` (stub; write-back via API) |
| Zotero SQLite access | — | `zotero-read.sh` (stub; via `zot` CLI) |

### Shared Storage

Both systems store chunks in `specs/literature/{citation_key}/`. The retrieval-flags.md context file explicitly documents this overlap: "Items chunked via `/zotero --convert KEY` are also discoverable by `--lit`."

### Dual Index Problem

Currently two separate indexes exist (or would exist when implemented):

| Index | Schema | Scoring Weights | Threshold |
|-------|--------|-----------------|-----------|
| `specs/literature/index.json` | 16 fields (enriched v2) | keyword overlap + summary bonus, min score ≥ 1 | ≥ 1 |
| `specs/zotero-index.json` | 20 fields (Zotero-specific) | title×4 + tags×3 + abstract×2 + keywords×2 + collections×1 + notes×1, min score ≥ 4 | ≥ 4 |

These two indexes serve the same fundamental purpose — "which literature is relevant to this task?" — with different scoring heuristics. Consolidation should merge them.

## 3. Flag Integration Status

### --lit Flag (fully wired)

```
parse-command-args.sh → LIT_FLAG="true"
  ↓
skill-researcher/SKILL.md → calls literature-retrieve.sh
skill-implementer/SKILL.md → calls literature-retrieve.sh
skill-orchestrate/SKILL.md → threads lit_flag through delegation_context
```

### --zot Flag (NOT wired)

`parse-command-args.sh` does NOT parse `--zot`. The flag appears only in:
- `skill-orchestrate/SKILL.md` — reads `zot_flag` from `delegation_context` JSON (but nothing sets it)
- `zotero-retrieve.sh` — stub script that would emit `<zotero-context>`
- Documentation files (`retrieval-flags.md`, `EXTENSION.md`, `zotero-agent.md`)

**Key finding**: `--zot` was designed but never integrated into the command argument parsing or skill dispatch pipeline. It exists only in documentation and the orchestrate skill's JSON contracts.

## 4. Consolidation Strategy

### 4.1 Merged Extension Structure

```
.claude/extensions/literature/          # Single unified extension
├── manifest.json                       # Merged manifest
├── EXTENSION.md                        # Merged CLAUDE.md section
├── README.md                           # Unified documentation
├── agents/
│   └── literature-agent.md            # NEW: Autonomous exploration agent (not just docs)
├── commands/
│   ├── literature.md                  # Keep: /literature command (expanded)
│   └── cite.md                        # Keep: /cite command
├── skills/
│   ├── skill-literature/SKILL.md      # Updated: merged conversion/index/management
│   └── skill-cite/SKILL.md            # Keep: citation verification
├── scripts/
│   ├── zotero-search.sh              # Keep: CSL-JSON library search
│   ├── cite-extract.sh               # Keep: citation pattern extraction
│   ├── literature-retrieve.sh         # MOVED from core (or keep in core with updated semantics)
│   └── zotero-read.sh                # NEW (selective adoption from zotero stubs)
├── context/
│   └── project/literature/
│       ├── domain/literature-index.md     # Merged index schema reference
│       └── patterns/retrieval-patterns.md # Unified retrieval guide
└── index-entries.json                 # Context index entries
```

### 4.2 What to Keep from Each Extension

**From literature extension** (keep all — fully implemented):
- `skill-literature/SKILL.md` — All conversion, indexing, validation logic
- `skill-cite/SKILL.md` — Citation verification
- `zotero-search.sh` — CSL-JSON library search (fully implemented, 409 lines)
- `cite-extract.sh` — Citation pattern extraction (fully implemented)
- `literature.md` command — Expand to absorb relevant `/zotero` subcommands
- `cite.md` command — Keep unchanged

**From zotero extension** (selective adoption — most is unimplemented):
- `zotero-read.sh` header/design — Adopt the `zot` CLI wrapper concept but implement from scratch
- `zotero-agent.md` context injection diagram — Merge into unified architecture docs
- `retrieval-flags.md` coexistence table — Useful as historical reference; superseded by new design
- Index schema (20-field) — Merge useful fields into unified index

**Drop entirely**:
- All 8 remaining zotero stub scripts (unimplemented; will be redesigned)
- `zotero.md` command (absorbed into `/literature`)
- `zotero-agent.md` (replaced by unified literature-agent)
- `skill-zotero/SKILL.md` (absorbed into skill-literature)
- `index-entries.json` context entries (replaced by unified context)
- `EXTENSION.md` for zotero (merged into unified EXTENSION.md)

### 4.3 Manifest Consolidation

```json
{
  "name": "literature",
  "version": "2.0.0",
  "description": "Unified literature management: global Literature/ repo, per-repo sub-index, autonomous literature-agent for research context",
  "dependencies": ["core", "filetypes"],
  "routing_exempt": true,
  "provides": {
    "agents": ["literature-agent.md"],
    "commands": ["literature.md", "cite.md"],
    "skills": ["skill-literature", "skill-cite"],
    "scripts": [
      "scripts/zotero-search.sh",
      "scripts/cite-extract.sh"
    ],
    "context": ["project/literature"]
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_literature"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    }
  },
  "keyword_overrides": {
    "zotero": "meta",
    "bibliography": "meta",
    "citation": "meta",
    "literature": "meta"
  },
  "hooks": {}
}
```

Key changes:
- Version bump to 2.0.0 (breaking: absorbs zotero extension)
- Absorbs keyword_overrides from zotero manifest
- Adds context entries (currently only in zotero)
- Drops filetypes dependency if unused (investigate)
- Adds index merge target (from zotero)

### 4.4 Command Surface Consolidation

**Option A: Single `/literature` command with expanded subcommands** (recommended)

Absorb Zotero-specific operations as subcommands of `/literature`:

| Current | Proposed | Notes |
|---------|----------|-------|
| `/literature` | `/literature` | Keep: status/health |
| `/literature --scan` | `/literature --scan` | Keep: find unprocessed files |
| `/literature --convert FILE` | `/literature --convert FILE` | Keep: PDF→markdown |
| `/literature --validate` | `/literature --validate` | Keep: index consistency |
| `/literature --index FILE` | `/literature --index FILE` | Keep: manual index entry |
| `/literature --search QUERY` | `/literature --search QUERY` | Keep: merged search |
| `/literature --task N` | `/literature --task N` | Keep: task-based search |
| `/zotero --setup` | `/literature --setup` | Absorb: Zotero config wizard |
| `/zotero --add KEY` | `/literature --add KEY` | Absorb: add Zotero item |
| `/zotero --remove KEY` | `/literature --remove KEY` | Absorb: remove item |
| `/zotero --convert KEY` | `/literature --convert KEY` (detect if KEY vs FILE) | Absorb: merge with file convert |
| `/zotero --attach KEY` | `/literature --attach KEY` | Absorb: upload chunks to Zotero |
| `/zotero --sync` | `/literature --sync` | Absorb: re-fetch metadata |
| `/zotero --status` | `/literature --status` | Absorb: detailed status report |
| `/cite N` | `/cite N` | Keep: citation verification |

**Option B: Keep `/zotero` as thin alias** (not recommended)

Would require maintaining two command files and increase complexity.

### 4.5 Skill Consolidation

The current skill-literature handles 7 modes. Adding absorbed zotero operations brings it to ~12 modes.

**Recommended approach**: Keep a single `skill-literature` but restructure around three capability groups:

| Group | Modes | Purpose |
|-------|-------|---------|
| **Conversion** | status, scan, convert, validate, index | PDF/DJVU → markdown pipeline |
| **Search & Import** | search, task, add, remove, sync, setup | Zotero integration and index management |
| **Agent Interface** | (new) explore, read-chunk, cross-ref | Tools exposed to the literature-agent |

The **Agent Interface** group is the critical new addition — these are not user-facing commands but tool functions that the literature-agent calls autonomously when exploring literature during /research, /plan, or /implement.

### 4.6 Flag Consolidation: --lit and --zot → Unified Approach

**Current state**: `--lit` is wired; `--zot` is not wired (only exists in docs and orchestrate stubs).

**Proposed**: Replace both injection flags with a single mechanism. Two design options:

**Option A: Keep --lit but change its semantics** (recommended)
- `--lit` triggers the literature-agent instead of static injection
- The literature-agent receives the per-repo sub-index and task description
- The agent autonomously searches, reads chunks, and decides what context to provide
- No `--zot` flag at all (unified under `--lit`)

**Option B: New --research-lit flag or automatic detection**
- Remove explicit flags entirely
- Literature context is always available to the literature-agent
- Agent is spawned as a teammate/tool when the task description matches literature keywords

Option A is simpler and backwards-compatible in flag syntax (just different behavior behind the flag).

## 5. Context File Consolidation

### Current Context Files (Zotero Extension)

| File | Load When | Line Count |
|------|-----------|------------|
| `project/zotero/domain/zotero-index.md` | agents: [zotero-agent], skills: [skill-zotero], commands: [/zotero] | ~80 |
| `project/zotero/patterns/retrieval-flags.md` | agents: [zotero-agent], skills: [skill-zotero], commands: [/zotero] | ~60 |

### Proposed Unified Context

| File | Load When | Purpose |
|------|-----------|---------|
| `project/literature/domain/literature-index.md` | agents: [literature-agent], skills: [skill-literature], commands: [/literature] | Unified index schema (merged from both) |
| `project/literature/patterns/agent-exploration.md` | agents: [literature-agent] | How the literature-agent explores the corpus |

The `retrieval-flags.md` file becomes obsolete in the unified design — there's only one retrieval mechanism.

## 6. Comparison with Other Extensions

### Memory Extension (closest analog)

The memory extension provides a useful architectural precedent:
- **Single command surface**: `/learn` and `/distill` (two commands, one extension)
- **Direct execution pattern**: skill-memory runs inline, no separate agent spawned
- **MCP integration**: Uses obsidian-claude-code-mcp for search
- **Context injection**: memory-retrieve.sh runs in preflight, gated by `--clean` flag
- **Validate-on-read**: Index self-heals without explicit reindex command

The proposed literature redesign should follow this pattern but with one key difference: the literature-agent is a **real agent** (not just a documentation stub) that can be spawned as a subagent to autonomously explore the corpus.

### Extension Pattern Observations

| Pattern | Literature | Zotero | Memory | Nix | Nvim |
|---------|-----------|--------|--------|-----|------|
| routing_exempt | yes | yes | no (has routing) | no | no |
| Has agent | docs-only | docs-only | no agent file | yes (real) | yes (real) |
| Has context entries | no | yes | yes | — | — |
| Has keyword_overrides | no | yes | no | no | no |
| Merge targets | claudemd only | claudemd + index | claudemd + index | — | — |

The unified extension should adopt the richer pattern: claudemd + index merge targets, keyword_overrides, and context entries.

## 7. Migration Path

### Phase 1: Consolidate Files
1. Copy useful zotero artifacts into literature extension directory
2. Update literature manifest.json to v2.0.0
3. Merge EXTENSION.md content
4. Update context index entries

### Phase 2: Remove Zotero Extension
1. Delete `.claude/extensions/zotero/` directory entirely
2. Remove zotero from any dependency chains in other manifests (none found beyond literature→zotero, which is reversed)
3. Update CLAUDE.md auto-generation to drop `extension_zotero` section

### Phase 3: Implement New Agent Interface
1. Design literature-agent as a real autonomous agent (not docs-only)
2. Define tool interface for corpus exploration
3. Wire --lit flag to spawn literature-agent instead of static injection
4. Update skill-researcher, skill-implementer, and skill-orchestrate

### Phase 4: Unify Index Schema
1. Design merged index schema (best of both: literature's 16 fields + zotero's unique fields)
2. Implement per-repo sub-index pointing to global Literature/ repo
3. Migration script for existing `specs/literature/index.json` files

## 8. Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Breaking existing `--lit` usage | Medium | Keep `--lit` flag syntax; change behavior behind it |
| Loss of Zotero-specific functionality | Low | Most zotero functionality is unimplemented stubs |
| Increased skill-literature complexity (12 modes) | Medium | Restructure into 3 capability groups |
| Literature-agent token cost | Medium | Agent should be lightweight; search-then-read, not read-everything |
| `--zot` flag in skill-orchestrate contracts | Low | Remove dead code; `--zot` was never parsed by parse-command-args.sh |

## 9. Summary

The consolidation is straightforward because:
1. The zotero extension is 95% unimplemented (stubs only)
2. The literature extension already contains the one implemented Zotero script (`zotero-search.sh`)
3. Both share chunk storage at `specs/literature/{citation_key}/`
4. `--zot` was never integrated into the command parsing pipeline
5. The dual-index design adds complexity without proportional benefit

The unified extension absorbs the zotero extension's design intent (Zotero library integration, per-repo curation) into the literature extension's proven implementation, while redesigning context injection from static file dumping to agent-driven exploration.

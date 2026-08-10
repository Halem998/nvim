# Research Report: Task #691

**Task**: 691 - Document --lit flag in CLAUDE.md and command reference
**Started**: 2026-06-12T00:00:00Z
**Completed**: 2026-06-12T00:30:00Z
**Effort**: ~30 minutes
**Dependencies**: Task 689 (literature-retrieve.sh + skill preflight injection), Task 690 (command-layer wiring)
**Sources/Inputs**: Codebase (merge sources, EXTENSION.md files, dependency summaries, command files, scripts)
**Artifacts**: specs/691_document_lit_flag_claude_md/reports/01_document-lit-flag.md
**Standards**: report-format.md

---

## Executive Summary

- The CLAUDE.md merge source is `.claude/extensions/core/merge-sources/claudemd.md`; all core content edits go there. The memory extension documents `--clean` in `.claude/extensions/memory/EXTENSION.md`. Both files must be updated to document `--lit`.
- CLAUDE.md is regenerated automatically by `merge.lua:generate_claudemd()` on every extension load/unload — no manual script needed. After editing the merge sources, the next load/unload cycle (or a re-load of any extension) regenerates the file. For immediate effect, an agent can copy the edited core merge source directly into CLAUDE.md, respecting the generated-file header.
- Three insertion points are required: (1) Command Reference table rows, (2) a new "Literature Mode (`--lit`)" section in the core merge source (parallel to the existing Hard Mode section), and (3) a "Literature-Augmented Research" subsection in memory's EXTENSION.md (parallel to the existing Memory-Augmented Research subsection). A `specs/literature/` directory convention note belongs in the new Literature Mode section.

---

## Context and Scope

Task 689 created `literature-retrieve.sh` and injected literature context retrieval into skill-researcher, skill-planner, skill-implementer, and skill-orchestrate. Task 690 threaded `--lit` through all four command files (research.md, plan.md, implement.md, orchestrate.md). Both tasks synced their changes to the `.claude/extensions/core/` copies.

This task documents those changes in the user-facing CLAUDE.md system so that:
1. The Command Reference table shows `--lit` in the usage strings for the four affected commands.
2. A new top-level section explains literature mode behavior and the `specs/literature/` convention.
3. The memory extension EXTENSION.md documents how `--lit` relates to (and complements) `--clean`.

---

## Findings

### Merge Source Locations

**Core content** (task management, command reference, hard mode, etc.):
- Active file: `/home/benjamin/.config/nvim/.claude/extensions/core/merge-sources/claudemd.md`
- This file is assembled verbatim into CLAUDE.md as the first section. The memory extension's EXTENSION.md is appended after it.

**Memory extension content** (`--clean` behavior):
- Active file: `/home/benjamin/.config/nvim/.claude/extensions/memory/EXTENSION.md`
- The "Memory-Augmented Research" subsection on line 27-29 reads:
  > Memory retrieval is automatic: when the memory extension is loaded, `/research`, `/plan`, and `/implement` preflight stages call `memory-retrieve.sh` to inject relevant memories as `<memory-context>` into the agent context. The `--clean` flag on these commands suppresses auto-retrieval.
- This is the exact style to mirror for `--lit`.

**Regeneration mechanism**: `merge.lua:generate_claudemd()` is called by the extension loader on every load/unload event. There is no standalone regeneration script. For the implementation task, the plan must either: (a) manually apply the same concatenation result to `.claude/CLAUDE.md`, or (b) document that the user should reload any extension to trigger regeneration.

### Command Reference Table (lines 86-104 in core merge source)

Current rows for the four affected commands:

```
| `/research`   | `/research N[,N-N] [focus] [--team] [--clean] [--fast\|--hard] [--haiku\|--sonnet\|--opus]` | Research task(s), route by task type |
| `/plan`       | `/plan N[,N-N] [--team] [--clean] [--fast\|--hard] [--haiku\|--sonnet\|--opus]` | Create implementation plan(s) |
| `/implement`  | `/implement N[,N-N] [--team] [--force] [--clean] [--fast\|--hard] [--haiku\|--sonnet\|--opus]` | Execute plan(s), resume from incomplete phase |
| `/orchestrate`| `/orchestrate N` | Drive task autonomously through full lifecycle (no confirmation gates) |
```

The `--lit` flag should be appended to all four usage strings, positioned after `--clean` (since `--lit` is independent of and parallel to `--clean`). The orchestrate row needs `[--lit]` added as well since orchestrate.md now supports it.

Proposed updated rows:
```
| `/research`   | `/research N[,N-N] [focus] [--team] [--clean] [--lit] [--fast\|--hard] [--haiku\|--sonnet\|--opus]` | Research task(s), route by task type |
| `/plan`       | `/plan N[,N-N] [--team] [--clean] [--lit] [--fast\|--hard] [--haiku\|--sonnet\|--opus]` | Create implementation plan(s) |
| `/implement`  | `/implement N[,N-N] [--team] [--force] [--clean] [--lit] [--fast\|--hard] [--haiku\|--sonnet\|--opus]` | Execute plan(s), resume from incomplete phase |
| `/orchestrate`| `/orchestrate N [--lit]` | Drive task autonomously through full lifecycle (no confirmation gates) |
```

The Multi-task syntax note on line 106 mentions "Flags like `--team` and `--force` apply to all tasks." This note should be extended to mention `--lit` and `--clean` as well since they also apply to all tasks in multi-task mode (or the note can stay general — judgment call for the implementer).

### Hard Mode Section Location (lines 230-285 in core merge source)

The Hard Mode (`--hard`) section begins at line 230. A new "Literature Mode (`--lit`)" section should be inserted immediately after Hard Mode ends (after line 285, before "## Rules References" at line 287).

This placement is natural because:
- `--hard` is a per-invocation effort flag section; `--lit` is also a per-invocation context flag section.
- Both sections follow the same document pattern: what it does, when to use it, composability, per-invocation-only note.

### New Literature Mode Section Content

The section should cover:
1. **What `--lit` does**: Activates literature context injection. Calls `literature-retrieve.sh` which reads `.md` and `.txt` files from `specs/literature/` (up to TOKEN_BUDGET=4000 tokens, MAX_FILES=10) and injects them as a `<literature-context>` block into the agent context, placed after `<memory-context>` (if any) and before task-specific instructions.
2. **specs/literature/ directory convention**: User-maintained directory at `specs/literature/`. Place paper summaries, specification documents, algorithm descriptions, or reference materials here as `.md` or `.txt` files. Files are not task-scoped — all files are included when `--lit` is active. The directory is silently skipped (no error) when absent.
3. **When to use `--lit`**: When a task involves implementing from a paper, specification, or reference document; when the agent needs stable reference material not captured in memory; or when using `--hard` for literature-based implementation (H3 reference grounding tier: "literature").
4. **Relationship to `--clean`**: The two flags are independent gates. `--clean --lit` suppresses memory retrieval but still injects literature. `--lit` alone injects both memory (if available) and literature. `--clean` alone suppresses memory but not literature.
5. **Composability**: Works with all other flags (`--team`, `--hard`, `--fast`, model flags). `--lit` is propagated through all dispatch contexts in skill-orchestrate, so it works with `/orchestrate` as well.
6. **Per-invocation only**: Like `--hard`, `--lit` has no sticky state in state.json. Each invocation must explicitly pass `--lit` to activate it.

### Memory Extension EXTENSION.md Insertion

In `/home/benjamin/.config/nvim/.claude/extensions/memory/EXTENSION.md`, after the existing "Memory-Augmented Research" subsection (lines 27-29), add a new parallel subsection:

**"Literature-Augmented Research"** explaining:
- `--lit` is the complementary flag to `--clean`: while `--clean` suppresses memory retrieval, `--lit` adds literature file injection
- The two flags are independent and combinable
- Refer to the "Literature Mode (`--lit`)" section in the core CLAUDE.md for full details on `specs/literature/` conventions

This keeps the memory EXTENSION.md as the place where `--clean` is documented and adds the natural parallel for `--lit`, while pointing to the core section for authoritative details.

### Regeneration After Editing

After editing both merge sources, CLAUDE.md must be updated. Options for the implementation task:
1. **Recommended (direct edit)**: Apply identical edits directly to `.claude/CLAUDE.md` in addition to the merge sources. The generated file and the merge source will stay in sync until the next extension load/unload cycle, which will overwrite `.claude/CLAUDE.md` from the merge sources anyway.
2. **Alternative**: Document that the user should toggle any extension (unload then load) to force `generate_claudemd()` to run.

The implementation task should use option 1 (direct edit to both places) to ensure CLAUDE.md reflects the changes immediately without requiring a user action.

### Extension Core Sync

Per the pattern established by tasks 689 and 690, all changes must be synced to the `.claude/extensions/core/` copies:
- `.claude/extensions/core/merge-sources/claudemd.md` is the canonical source; `.claude/extensions/core/merge-sources/claudemd.md` IS the active file (confirmed: only one copy, not duplicated between active and extension).
- For memory's EXTENSION.md: the file at `.claude/extensions/memory/EXTENSION.md` is both the source and the active copy (extensions are not copied to a separate active location for EXTENSION.md files — they're read in-place).

No separate sync step is needed for these two files.

---

## Decisions

- **Placement of new Literature Mode section**: After Hard Mode (`--hard`) and before "## Rules References". This mirrors the existing section layout where effort/context modifiers appear together near the bottom of the core content.
- **orchestrate row in Command Reference**: Update from `/orchestrate N` to `/orchestrate N [--lit]`. The orchestrate command now accepts `--lit` (added by Task 690), so the usage string should reflect it. Other flags (`--hard`, model flags) are not currently in the orchestrate row but that is a pre-existing omission; only `--lit` is in scope here.
- **Memory EXTENSION.md**: Add a "Literature-Augmented Research" subsection parallel to "Memory-Augmented Research", making the memory extension the authoritative cross-reference point for flag interactions.
- **specs/literature/ convention note**: Place in the new Literature Mode section in the core merge source (not in a separate standalone file), since this is a core workflow concept rather than an extension-specific convention.

---

## Recommendations

### Implementation Steps (for plan phase)

1. **Edit core merge source** (`/home/benjamin/.config/nvim/.claude/extensions/core/merge-sources/claudemd.md`):
   - Update 4 rows in the Command Reference table (lines 90-92, 102) to add `[--lit]`
   - Insert new "## Literature Mode (`--lit`)" section after line 285 (after `--hard` Per-Invocation Only paragraph)

2. **Edit memory EXTENSION.md** (`/home/benjamin/.config/nvim/.claude/extensions/memory/EXTENSION.md`):
   - Add "### Literature-Augmented Research" subsection after line 29 (after Memory-Augmented Research)

3. **Apply same edits to `.claude/CLAUDE.md`** directly (immediate effect, will be overwritten on next extension cycle but stays in sync until then)

4. No additional sync is needed; the merge sources ARE the extension files.

### Content for specs/literature/ Convention Note

```markdown
## Literature Mode (`--lit`)

Literature mode injects reference files from `specs/literature/` as `<literature-context>` into
agent prompts. Use this when a task involves implementing from a paper, specification, or
reference document.

### What `--lit` Does

When `--lit` is passed to `/research`, `/plan`, `/implement`, or `/orchestrate`:
- `literature-retrieve.sh` reads all `.md` and `.txt` files from `specs/literature/`
- Files are included up to TOKEN_BUDGET=4000 tokens (MAX_FILES=10)
- A `<literature-context>` block is injected after `<memory-context>` (if any) and before
  task-specific instructions
- If `specs/literature/` does not exist or is empty, the flag is silently ignored (no error)

### specs/literature/ Directory Convention

The `specs/literature/` directory is user-maintained and not task-scoped:
- Place paper summaries, specification documents, algorithm descriptions, or reference PDFs
  (converted to .md/.txt) here
- All files in the directory are available to any task when `--lit` is active
- The directory is not created automatically — create it before using `--lit`
- Suitable content: academic paper summaries, RFC/spec excerpts, algorithm pseudocode,
  mathematical definitions the agent should treat as ground truth

### When to Use `--lit`

- Task requires implementing from a paper or formal specification
- Agent needs stable reference material beyond what is in memory
- Using `--hard` with H3 reference grounding tier "literature"
- Task description mentions "paper to code", "spec to implementation", or cites a specific document

### Relationship to `--clean`

The two flags are independent:

| Flag combination | Memory retrieval | Literature injection |
|------------------|-----------------|---------------------|
| (neither)        | active          | inactive            |
| `--clean`        | suppressed      | inactive            |
| `--lit`          | active          | active              |
| `--clean --lit`  | suppressed      | active              |

### Composability

- `--lit` works with `--team`, `--hard`, `--fast`, and model flags
- `--lit` is threaded through all dispatch contexts in skill-orchestrate
- Per-invocation only: no sticky state in state.json

### Per-Invocation Only

`--lit` has no persistent state. Each invocation of `/research`, `/plan`, `/implement`, or
`/orchestrate` must explicitly pass `--lit` to activate literature injection.
```

---

## Risks and Mitigations

- **Risk**: CLAUDE.md gets overwritten on next extension cycle before the task is visible to users. **Mitigation**: The implementation edits both the merge source (permanent) and CLAUDE.md directly (immediate). Any subsequent extension load will regenerate from the updated merge source, preserving the changes.
- **Risk**: The `orchestrate.md` command usage row currently shows only `/orchestrate N`. Adding `[--lit]` while omitting `--hard` and model flags creates inconsistency. **Mitigation**: The scope of this task is only `--lit`; document in the plan that the orchestrate row pre-existing omissions are out of scope. The change is still correct since `--lit` is now supported.

---

## Appendix

### Files Consulted

- `/home/benjamin/.config/nvim/.claude/extensions/core/merge-sources/claudemd.md` — Core CLAUDE.md merge source (Command Reference table at lines 90-104, Hard Mode section at lines 230-285)
- `/home/benjamin/.config/nvim/.claude/extensions/memory/EXTENSION.md` — Memory extension content (Memory-Augmented Research at lines 27-29)
- `/home/benjamin/.config/nvim/.claude/CLAUDE.md` — Generated output (confirmed header says "do not edit directly")
- `/home/benjamin/.config/nvim/.claude/scripts/literature-retrieve.sh` — Script behavior (TOKEN_BUDGET, MAX_FILES, directory path, silent-skip behavior)
- `/home/benjamin/.config/nvim/specs/689_lit_context_injection_skill_preflight/summaries/01_lit-context-injection-summary.md` — Task 689 decisions and implementation details
- `/home/benjamin/.config/nvim/specs/690_wire_lit_flag_commands/summaries/01_wire-lit-commands-summary.md` — Task 690 decisions and implementation details
- `/home/benjamin/.config/nvim/.claude/commands/research.md`, `plan.md`, `implement.md`, `orchestrate.md` — Command files showing actual --lit Options table entries
- `/home/benjamin/.config/nvim/.claude/docs/architecture/system-overview.md` — Confirms CLAUDE.md is computed by `merge.lua:generate_claudemd()`

### Key Numbers

- `literature-retrieve.sh` TOKEN_BUDGET: 4000 tokens
- `literature-retrieve.sh` MAX_FILES: 10
- `specs/literature/` accepted extensions: `.md`, `.txt`
- Core merge source Command Reference table: lines 86-106
- Hard Mode section: lines 230-285
- New Literature Mode section insert point: after line 285 (before line 287 "## Rules References")
- Memory EXTENSION.md Memory-Augmented Research: lines 27-29
- New Literature-Augmented Research insert point: after line 29

# Implementation Plan: Create /literature Command

- **Task**: 702 - Create a /literature command
- **Status**: [COMPLETED]
- **Effort**: 3.5 hours
- **Dependencies**: 701 (upgrade literature-retrieve.sh)
- **Research Inputs**: specs/702_create_literature_command/reports/01_lit-command.md
- **Artifacts**: plans/01_lit-command.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a `/literature` command with associated skill and agent for managing `specs/literature/` directories. The command automates PDF/DJVU-to-markdown conversion, index.json maintenance, and filesystem validation. The architecture follows the direct-execution pattern (like `/distill` and `/fix-it`) where the command delegates to a skill that runs inline with `AskUserQuestion` for interactivity, with a lightweight agent file as documented infrastructure.

### Research Integration

Key findings from research report `01_lit-command.md`:
- **Architecture**: Direct-execution command+skill pattern (Pattern B), matching `/distill` and `/fix-it`. No agent subagent invocation during normal execution.
- **PDF tools**: `pdftotext` (poppler 25.10.0) is the primary conversion tool. `pandoc` does NOT support PDF input. `djvutxt` is NOT installed (needs `djvulibre` from nixpkgs) -- graceful degradation required.
- **Token counting**: Use `chars / 4 + 20` approximation (matches `memory-harvest.sh` pattern).
- **Chunking**: 10 pages per chunk (~4000 tokens) using `pdftotext -f/-l` page range flags; `pdfinfo` for page count detection.
- **index.json schema**: Root uses `entries[]` with `id`, `path`, `token_count`, `keywords`, `summary` fields. Subdirectory uses `chapters[]` with `file` field.
- **Command modes**: Status (default), Scan, Convert, Validate, Index -- matching `/distill` sub-mode pattern.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No specific ROADMAP.md items identified for this task.

## Goals & Non-Goals

**Goals**:
- Create `.claude/commands/literature.md` with argument parsing and sub-mode dispatch
- Create `.claude/skills/skill-literature/SKILL.md` with all conversion, indexing, and validation logic
- Create `.claude/agents/literature-agent.md` as lightweight agent documentation (per task description)
- Support five sub-modes: status (default), scan, convert, validate, index
- Handle PDF conversion via `pdftotext` with automatic chunking at ~4000 tokens
- Gracefully degrade when `djvutxt` is unavailable
- Generate and maintain `index.json` with proper schema (matching existing cslib format)
- Register the new command in CLAUDE.md merge-sources and skill-to-agent mapping

**Non-Goals**:
- OCR support for scanned/image-only PDFs (out of scope -- warn and skip)
- Automatic keyword extraction via LLM (use simple word-frequency approach inline)
- Support for formats beyond PDF and DJVU (e.g., EPUB, MOBI)
- Modifying `literature-retrieve.sh` (that is task 701's scope)
- Creating context documentation for the command (can be a follow-up task)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `djvutxt` not installed | M | H | Detect with `which djvutxt`, warn user, suggest `nix-env -iA nixpkgs.djvulibre`, skip DJVU files |
| PDF has no extractable text (scanned image) | M | M | Detect empty/whitespace-only pdftotext output, warn "no text extracted, OCR required" |
| Very large PDFs (100+ pages) | L | M | Auto-chunk with 10-page windows, prompt user for confirmation of chunk boundaries |
| Token count drift over time | L | M | Validate mode recounts and flags >20% drift from stored count |
| CLAUDE.md merge-source registration missed | M | L | Explicit phase for registration with verification step |
| Skill file too large for single phase | M | L | Skill logic is split across sub-modes; each mode is independently testable |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create Command File and Agent File [COMPLETED]

**Goal**: Create the command entry point (`.claude/commands/literature.md`) and the lightweight agent file (`.claude/agents/literature-agent.md`).

**Tasks**:
- [ ] Create `.claude/commands/literature.md` with YAML frontmatter (`description`, `allowed-tools: Skill`, `argument-hint: [--scan|--convert [FILE]|--validate|--index FILE]`)
- [ ] Implement argument parsing section: parse sub-mode from `$ARGUMENTS` (status/scan/convert/validate/index), extract optional FILE argument
- [ ] Implement workflow execution section: delegate to `skill-literature` via Skill tool with `mode={mode} file={file}` args
- [ ] Add error handling section for unknown flags and missing arguments
- [ ] Create `.claude/agents/literature-agent.md` as lightweight documentation agent (frontmatter with `name`, `description`, `model: sonnet`, `allowed-tools`)
- [ ] Agent file documents the direct-execution pattern and skill relationship

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/commands/literature.md` - New file: command entry point
- `.claude/agents/literature-agent.md` - New file: lightweight agent documentation

**Verification**:
- Command file has valid YAML frontmatter with `allowed-tools: Skill`
- All five sub-modes are parsed correctly from arguments
- Agent file follows established agent frontmatter format
- Both files match the structural patterns of existing commands/agents

---

### Phase 2: Create Skill File -- Core Logic (Status, Scan, Validate) [COMPLETED]

**Goal**: Create the skill file with the three read-only sub-modes (status, scan, validate) that do not modify the filesystem.

**Tasks**:
- [ ] Create `.claude/skills/skill-literature/SKILL.md` with YAML frontmatter (`name: skill-literature`, `description`, `allowed-tools: Bash, Read, Write, Edit, AskUserQuestion`)
- [ ] Write context references section linking to research report and relevant scripts
- [ ] Implement Step 1: Parse arguments (mode extraction from skill args)
- [ ] Implement Step 2: Session ID generation
- [ ] Implement **Status mode** (default): Read `index.json` if exists, scan for PDF/DJVU files in `specs/literature/`, compute processed vs unprocessed counts, display health report
- [ ] Implement **Scan mode**: Find PDF/DJVU files lacking corresponding markdown conversions, list unprocessed files with page counts via `pdfinfo`, detect `djvutxt` availability
- [ ] Implement **Validate mode**: Read all `index.json` entries, check each entry's file exists, recount token counts and flag >20% drift, detect unindexed `.md` files, report stale/missing/unindexed entries
- [ ] Add tool availability detection logic: `which pdftotext`, `which pdfinfo`, `which djvutxt` with graceful fallback messages

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-literature/SKILL.md` - New file: skill with status, scan, validate modes

**Verification**:
- Skill file has valid frontmatter matching `skill-fix-it` pattern
- Status mode produces readable health report when `specs/literature/` exists
- Status mode handles missing `specs/literature/` directory gracefully
- Scan mode correctly identifies PDFs without markdown counterparts
- Validate mode detects missing files, stale entries, and token count drift
- Tool detection works for both available and unavailable tools

---

### Phase 3: Create Skill File -- Mutation Logic (Convert, Index) [COMPLETED]

**Goal**: Add the two mutation sub-modes (convert, index) that create files and modify `index.json`.

**Tasks**:
- [ ] Implement **Convert mode**: For each unprocessed PDF/DJVU file:
  - [ ] Get page count via `pdfinfo`
  - [ ] Determine chunking: single file if <=10 pages, multi-chunk if >10 pages
  - [ ] Present chunk boundaries to user via `AskUserQuestion` for confirmation
  - [ ] Run `pdftotext -f {start} -l {end} -layout` for each chunk
  - [ ] Wrap output in minimal markdown with title header
  - [ ] Compute token count using `chars / 4 + 20`
  - [ ] Generate keywords via simple word-frequency extraction (top 10 content words after stopword removal)
  - [ ] Extract summary: look for "Abstract" in first 500 chars, fallback to first 2-3 sentences
  - [ ] Present auto-generated keywords/summary to user via `AskUserQuestion` for confirmation/editing
  - [ ] Write markdown file(s) to `specs/literature/`
  - [ ] Update/create `index.json` with new entry/entries
- [ ] Handle DJVU conversion: check `djvutxt` availability, use `djvutxt` if available, warn and skip if not
- [ ] Implement **Index mode**: For an existing markdown file in `specs/literature/`:
  - [ ] Compute token count
  - [ ] Prompt user for keywords and summary via `AskUserQuestion`
  - [ ] Add/update entry in `index.json`
- [ ] Handle `index.json` creation when it does not yet exist (initialize with `{"token_budget": 4000, "entries": []}`)
- [ ] Handle subdirectory indexes using `chapters[]` format when converting large documents into subdirectories

**Timing**: 1.5 hours

**Depends on**: 2

**Files to modify**:
- `.claude/skills/skill-literature/SKILL.md` - Add convert and index mode sections

**Verification**:
- Convert mode produces valid markdown from a test PDF
- Chunking splits files at correct page boundaries
- Token counts are computed correctly (chars / 4 + 20)
- Keywords and summary are generated and presented for user confirmation
- index.json is created or updated with correct schema
- DJVU files are skipped gracefully when djvutxt is unavailable
- Index mode adds entries for pre-existing markdown files

---

### Phase 4: Register Command in System Configuration [COMPLETED]

**Goal**: Register the new `/literature` command, `skill-literature`, and `literature-agent` in the appropriate CLAUDE.md merge-sources and configuration files so the command is discoverable and documented.

**Tasks**:
- [ ] Add `/literature` to the Command Reference table in `.claude/extensions/memory/merge-sources/claude-md-memory.md` (or the appropriate merge-source file where memory/literature commands are registered)
- [ ] Add `skill-literature` and `literature-agent` to the Skill-to-Agent Mapping table in the appropriate merge-source
- [ ] Add the skill entry in `.claude/context/index.json` if needed for context discovery
- [ ] Add `/literature` entry to the skills list in the system-reminder available skills (verify by checking where `/distill` and `/learn` are registered)
- [ ] Verify the command appears in the generated CLAUDE.md after running the merge-source generation

**Timing**: 0.5 hours (adjusted from initial -- mostly lookup and targeted edits)

**Depends on**: 3

**Files to modify**:
- `.claude/extensions/memory/merge-sources/claude-md-memory.md` - Add command and skill-to-agent entries
- `.claude/context/index.json` - Add skill-literature context entry (if applicable)
- `.claude/extensions/memory/manifest.json` - Register skill and command in extension manifest

**Verification**:
- `/literature` appears in the Command Reference table
- `skill-literature` and `literature-agent` appear in the Skill-to-Agent Mapping table
- Running the CLAUDE.md generation script includes the new entries
- The command is listed in the available skills section

---

## Testing & Validation

- [ ] Verify command file parses all five sub-modes correctly (status, scan, convert, validate, index)
- [ ] Verify skill handles missing `specs/literature/` directory (creates or reports empty)
- [ ] Test scan mode with a real PDF file in `specs/literature/`
- [ ] Test convert mode end-to-end: PDF -> markdown + index.json entry
- [ ] Test validate mode detects a deliberately stale index.json entry
- [ ] Test index mode adds an entry for a pre-existing markdown file
- [ ] Verify graceful degradation when `djvutxt` is not installed
- [ ] Verify `pdftotext` empty output detection (scanned PDF warning)
- [ ] Confirm CLAUDE.md regeneration includes new command entries

## Artifacts & Outputs

- `.claude/commands/literature.md` - Command entry point
- `.claude/skills/skill-literature/SKILL.md` - Skill with all five sub-modes
- `.claude/agents/literature-agent.md` - Lightweight agent documentation
- Updated merge-sources with command registration
- Updated `index.json` context entries (if applicable)

## Rollback/Contingency

All changes are new files. Rollback is straightforward:
1. Delete `.claude/commands/literature.md`
2. Delete `.claude/skills/skill-literature/` directory
3. Delete `.claude/agents/literature-agent.md`
4. Revert merge-source and index.json changes via `git checkout`

No existing functionality is modified, so rollback carries zero risk of breaking other commands.

# Implementation Plan: Pitch Deck Command-Skill-Agent for Typst

- **Task**: 162 - deck_command_skill_agent_typst_pitchdeck
- **Status**: [COMPLETED]
- **Effort**: 3-5 hours
- **Dependencies**: None (filetypes extension already exists)
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Date**: 2026-03-09
- **Feature**: /deck command for generating YC-style investor pitch decks in Typst using touying
- **Estimated Hours**: 3-5 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md

## Overview

Create a `/deck` command within the `.claude/extensions/filetypes/` extension that generates 10-slide investor pitch decks in Typst using the touying package. The command follows the existing command-skill-agent pattern (mirroring `/slides`) and embeds YC pitch deck best practices (from articles 2u and 4T) as context files. The agent accepts a prompt or file path describing a startup, maps the content to a 9+1 slide structure, and outputs a `.typ` file using the touying simple theme.

### Research Integration

Research report (research-001.md) provided:
- YC 9-slide structure with three design principles (Legibility, Simplicity, Obviousness)
- Touying 0.6.3 selected over Polylux for active development and heading-based syntax
- Simple theme recommended for investor decks (minimal, high-contrast)
- Extension placement in `.claude/extensions/filetypes/` confirmed
- Files to create/update identified: command, skill, agent, 2 context files, manifest, index-entries, EXTENSION.md

## Goals & Non-Goals

**Goals**:
- Create a fully functional `/deck` command that generates Typst pitch decks from a prompt or file
- Encode YC pitch deck structure and design principles as reusable context files
- Provide a touying template optimized for investor presentations (simple theme, 16:9, large fonts)
- Follow the exact command-skill-agent pattern established by `/slides`
- Integrate into the filetypes extension manifest, index-entries, and EXTENSION.md

**Non-Goals**:
- PDF compilation (generate .typ only; user compiles separately)
- Beamer/LaTeX output (Typst-only for this command)
- Interactive slide editing or preview
- Custom theme creation (use built-in touying themes)
- Integration with presentation-agent (deck-agent is a separate, dedicated agent)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Touying API changes (pre-1.0) | M | M | Pin version 0.6.3 in template, document upgrade path in context file |
| Incomplete user input for slides | L | H | Agent uses TODO placeholders and speaker notes for missing sections |
| Typst not installed on system | L | M | Agent generates .typ file regardless; warns about compilation |
| Template appears generic | M | M | Include customization guidance in speaker notes; allow --theme override |
| Content too verbose for slides | M | M | Agent instructions enforce one-idea-per-slide and word limits per YC principles |

## Implementation Phases

### Phase 1: Context Files [COMPLETED]

**Goal**: Create the two context files that encode YC pitch deck knowledge and touying template patterns for agent reference.

**Tasks**:
- [ ] Create `pitch-deck-structure.md` context file encoding YC 9-slide structure, content guidance per slide, three design principles (Legibility, Simplicity, Obviousness), and anti-patterns
- [ ] Create `touying-pitch-deck-template.md` context file with a complete touying 0.6.3 template using simple theme, 16:9 aspect ratio, large fonts, high-contrast colors, and slide-type-specific layouts (two-column for Team, chart placeholder for Traction)
- [ ] Verify both files are well-structured and cross-reference each other

**Timing**: 1 hour

**Files to create**:
- `.claude/extensions/filetypes/context/project/filetypes/patterns/pitch-deck-structure.md` - YC pitch deck structure and design principles
- `.claude/extensions/filetypes/context/project/filetypes/patterns/touying-pitch-deck-template.md` - Touying template for pitch decks

**Verification**:
- Both files exist and are non-empty
- pitch-deck-structure.md covers all 9+1 slides with content guidance
- touying-pitch-deck-template.md contains valid touying 0.6.3 syntax with simple theme
- Template uses heading-based syntax (`=` for title, `==` for slides)

---

### Phase 2: Deck Agent [COMPLETED]

**Goal**: Create the deck-agent that generates Typst pitch deck files from user input, following the presentation-agent pattern.

**Tasks**:
- [ ] Create `deck-agent.md` following the presentation-agent structure (frontmatter, overview, allowed tools, context references, execution flow, return format, error handling)
- [ ] Define execution flow: parse delegation context, validate inputs, determine input type (prompt vs file path vs both), read file content if needed, map content to 9+1 slide structure using pitch-deck-structure.md, generate Typst code using touying-pitch-deck-template.md, write output .typ file, validate output
- [ ] Define input handling for three modes: prompt-only, file-path-only, prompt+file
- [ ] Define placeholder strategy for incomplete input (TODO markers, speaker notes guidance)
- [ ] Define structured JSON return format matching subagent-return.md schema
- [ ] Define error handling for missing input, empty content, write failures

**Timing**: 1.5 hours

**Files to create**:
- `.claude/extensions/filetypes/agents/deck-agent.md` - Pitch deck generation agent

**Verification**:
- Agent file has valid frontmatter (name, description)
- Execution flow covers all 6 stages (parse context, validate, determine input type, generate slides, write output, return JSON)
- Context references point to the two context files from Phase 1
- Return format matches subagent-return.md schema
- Error handling covers missing input, file not found, write failure

---

### Phase 3: Deck Skill [COMPLETED]

**Goal**: Create the skill-deck skill wrapper that validates input and delegates to deck-agent via Task tool.

**Tasks**:
- [ ] Create `skill-deck/SKILL.md` following the skill-presentation pattern (frontmatter, context pointers, trigger conditions, execution flow, return format, error handling)
- [ ] Define trigger conditions: direct `/deck` invocation, implicit invocation patterns ("generate pitch deck", "create investor deck", "startup slides")
- [ ] Define input validation: check that prompt or file_path is provided, resolve file path to absolute, validate file exists if path provided
- [ ] Define delegation context JSON structure with source content, output_path, theme, slide_count, and metadata
- [ ] Define return validation against subagent-return.md schema

**Timing**: 0.5 hours

**Files to create**:
- `.claude/extensions/filetypes/skills/skill-deck/SKILL.md` - Deck generation skill wrapper

**Verification**:
- Skill file has valid frontmatter (name, description, allowed-tools: Task)
- Trigger conditions document when skill activates and when NOT to trigger
- Delegation uses Task tool (not Skill tool) to spawn deck-agent
- Return validation checks status, summary, artifacts, metadata fields

---

### Phase 4: Deck Command [COMPLETED]

**Goal**: Create the /deck command following the /slides checkpoint-based pattern.

**Tasks**:
- [ ] Create `deck.md` command following the /slides structure (frontmatter, arguments, usage examples, execution checkpoints)
- [ ] Define arguments: `$1` as prompt or file path (required), `--output PATH` (optional), `--theme NAME` (optional, default simple), `--slides N` (optional, default 10)
- [ ] Define CHECKPOINT 1 (GATE IN): generate session ID, parse arguments, determine if input is prompt or file path (check if arg is an existing file), convert paths to absolute, set defaults
- [ ] Define STAGE 2 (DELEGATE): invoke skill-deck with parsed arguments
- [ ] Define CHECKPOINT 2 (GATE OUT): validate return, verify output file exists and is non-empty, verify output contains touying import
- [ ] Define CHECKPOINT 3 (COMMIT): optional git commit for task workflows
- [ ] Define output format for success and failure cases
- [ ] Define error handling for all gate failures

**Timing**: 0.5 hours

**Files to create**:
- `.claude/extensions/filetypes/commands/deck.md` - /deck command definition

**Verification**:
- Command file has valid frontmatter (description, allowed-tools, argument-hint)
- All 3 checkpoints + 1 stage defined
- Usage examples cover: prompt-only, file-path, with --output, with --theme
- Error messages are clear and actionable

---

### Phase 5: Extension Integration and Validation [COMPLETED]

**Goal**: Update the filetypes extension manifest, index-entries, and EXTENSION.md to register the new command, skill, agent, and context files.

**Tasks**:
- [ ] Update `manifest.json` to add deck-agent.md to agents, skill-deck to skills, deck.md to commands
- [ ] Update `index-entries.json` to add entries for pitch-deck-structure.md and touying-pitch-deck-template.md with appropriate load_when targeting deck-agent and /deck command
- [ ] Update `EXTENSION.md` to add a "Pitch Deck Generation (via /deck)" section documenting the command, supported inputs, output format, prerequisites (typst for compilation), and usage examples
- [ ] Verify all file paths in manifest match actual files created in Phases 1-4
- [ ] Verify index-entries.json is valid JSON with correct schema
- [ ] Read back each created file to confirm it exists and is non-empty
- [ ] Verify the command, skill, and agent cross-reference each other correctly (command invokes skill-deck, skill delegates to deck-agent, agent references context files)

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/extensions/filetypes/manifest.json` - Add new command, skill, agent
- `.claude/extensions/filetypes/index-entries.json` - Add new context file entries
- `.claude/extensions/filetypes/EXTENSION.md` - Add /deck documentation section

**Verification**:
- `manifest.json` lists deck-agent.md, skill-deck, deck.md
- `index-entries.json` has entries for both new context files with deck-agent in agents and /deck in commands
- `EXTENSION.md` has a complete /deck section with usage examples
- All 7 files created/modified exist and are non-empty
- Cross-references between command -> skill -> agent -> context are consistent

## Testing & Validation

- [ ] All 5 new files exist at expected paths under `.claude/extensions/filetypes/`
- [ ] `manifest.json` is valid JSON and lists all new components
- [ ] `index-entries.json` is valid JSON with correct schema for new entries
- [ ] Command frontmatter has required fields (description, allowed-tools, argument-hint)
- [ ] Skill frontmatter has required fields (name, description, allowed-tools)
- [ ] Agent frontmatter has required fields (name, description)
- [ ] Context files contain substantive content (not just placeholders)
- [ ] touying-pitch-deck-template.md contains valid touying 0.6.3 syntax
- [ ] pitch-deck-structure.md covers all 9 YC slides plus closing slide
- [ ] EXTENSION.md /deck section matches actual command capabilities
- [ ] No circular references between new files

## Artifacts & Outputs

- `.claude/extensions/filetypes/context/project/filetypes/patterns/pitch-deck-structure.md` - YC deck structure context
- `.claude/extensions/filetypes/context/project/filetypes/patterns/touying-pitch-deck-template.md` - Touying template context
- `.claude/extensions/filetypes/agents/deck-agent.md` - Deck generation agent
- `.claude/extensions/filetypes/skills/skill-deck/SKILL.md` - Deck skill wrapper
- `.claude/extensions/filetypes/commands/deck.md` - /deck command
- `.claude/extensions/filetypes/manifest.json` (modified) - Extension manifest
- `.claude/extensions/filetypes/index-entries.json` (modified) - Context index entries
- `.claude/extensions/filetypes/EXTENSION.md` (modified) - Extension documentation

## Rollback/Contingency

All changes are additive (new files + appended entries in existing files). To revert:
1. Delete the 5 new files (deck.md, SKILL.md, deck-agent.md, pitch-deck-structure.md, touying-pitch-deck-template.md)
2. Revert manifest.json, index-entries.json, and EXTENSION.md to their previous versions via `git checkout`
3. No other files in the system are affected

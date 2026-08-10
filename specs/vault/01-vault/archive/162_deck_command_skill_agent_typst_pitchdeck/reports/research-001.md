# Research Report: Task #162

**Task**: 162 - deck_command_skill_agent_typst_pitchdeck
**Started**: 2026-03-09T00:00:00Z
**Completed**: 2026-03-09T00:45:00Z
**Effort**: 2-4 hours (implementation estimate)
**Dependencies**: Filetypes extension (exists), Typst (installed)
**Sources/Inputs**: YC Startup Library, Typst Universe, codebase patterns
**Artifacts**: specs/162_deck_command_skill_agent_typst_pitchdeck/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- YC recommends a 9-10 slide seed deck with three design principles: Legibility, Simplicity, Obviousness
- Touying 0.6.3 is the best Typst slide package for this use case (heading-based syntax, 6 built-in themes, active development)
- The `/deck` command should be placed in `.claude/extensions/filetypes/` following the existing command-skill-agent pattern (like `/slides`)
- The agent needs to generate Typst files from a user prompt or file path, using embedded YC best practices as context
- A pitch deck context file should encode the YC slide structure and design principles for agent reference

## Context & Scope

This research covers four areas needed to implement a `/deck` command:
1. YC pitch deck content and design guidance (from library articles 2u and 4T)
2. Typst slide generation with touying package
3. Existing command-skill-agent patterns in the .claude/ system
4. Extension structure for placement in `.claude/extensions/filetypes/`

## Findings

### 1. YC Pitch Deck Structure (from articles 2u and 4T)

YC recommends a concise 9-slide seed round pitch deck. The core content from both articles:

**Recommended Slides (in order)**:

| # | Slide | Content |
|---|-------|---------|
| 1 | Title | Company name, one-line description of what you do |
| 2 | Problem | Impact on real people/businesses; use statistics or relatable stories |
| 3 | Solution | How product addresses the problem; brief, concrete benefits |
| 4 | Traction | Chart/graph of key metrics (revenue, user growth); context for metrics |
| 5 | Unique Advantage | Unique insights, technology, or approach; differentiation |
| 6 | Business Model | Revenue streams, pricing strategy; early results if available |
| 7 | Market Opportunity | TAM with clean visual representation to convey scale |
| 8 | Team | Founder qualifications, relevant experience; focus on people leading |
| 9 | The Ask | Fundraising amount, fund allocation, projected milestones within 1 year |

An optional 10th "closing" slide can be added for contact information / Q&A.

**Three Design Principles (from Kevin Hale, article 4T)**:

1. **Legibility**: Large, bold fonts with high contrast. Simple, straightforward font choices. Place key text at top of slides. "Even old people in the back row with bad eyesight can read."
2. **Simplicity**: One idea per slide. Limit to 5-7 key ideas total. Remove excessive explanations and caveats. No animations, transitions, or distracting design.
3. **Obviousness**: Slides must be understood at a glance. Test with strangers who should "immediately" grasp the idea. Make ideas explicit, not implicit.

**Design Anti-Patterns**:
- Screenshots (break all 3 rules)
- Excessive branding per slide
- Memes and subtle humor
- Information overload
- Videos/screencasts without careful consideration
- Complicated layouts

**Key Philosophy**: "Investors invest in teams not slides. Your slides should make your ideas more clear." Focus on 5-7 most important ideas people should remember about your startup.

### 2. Typst Slide Generation with Touying

**Package Selection: Touying 0.6.3** (recommended over Polylux)

Rationale:
- More active development (v0.6.3 released March 2026 vs Polylux v0.4.0 with no backwards compat guarantees)
- Heading-based slide syntax (natural, document-like writing)
- 6 built-in themes: Simple, Metropolis, Dewdrop, University, Aqua, Stargazer
- Export to PDF (built-in), PPTX and HTML (via touying-exporter)
- Rich animation support (#pause, #meanwhile, #uncover, #only, #alternatives)
- Better for pitch decks: clean, professional themes

**Basic Touying Syntax**:

```typst
#import "@preview/touying:0.6.3": *
#import themes.simple: *

#show: simple-theme.with(aspect-ratio: "16-9")

= Presentation Title

== Slide Title

Content here

#pause

More content revealed on click
```

**Layout Features**:
- Side-by-side columns: `#slide(composer: (1fr, 1fr))[col1][col2]`
- Speaker notes: `#speaker-note[...]`
- Title slides via `=` heading level
- Regular slides via `==` heading level

**Theme Selection for Pitch Decks**:
- `simple` - Best for investor decks (minimal, clean, no distractions)
- `metropolis` - Professional with modern feel
- `stargazer` - Good for dark-themed presentations

**Recommended Approach**: Use `simple` theme as default for pitch decks, aligning with YC's simplicity principle.

### 3. Command-Skill-Agent Pattern Analysis

The existing filetypes extension uses this pattern:

```
Command (commands/slides.md)
  -> Skill (skills/skill-presentation/SKILL.md)
    -> Agent (agents/presentation-agent.md)
```

**Command** (`/slides`):
- Frontmatter: description, allowed-tools, argument-hint, model (optional)
- CHECKPOINT 1 (GATE IN): Parse args, validate inputs, generate session ID
- STAGE 2 (DELEGATE): Invoke Skill tool
- CHECKPOINT 2 (GATE OUT): Validate return, verify output
- CHECKPOINT 3 (COMMIT): Optional git commit

**Skill** (`skill-presentation/SKILL.md`):
- Thin wrapper pattern: validates input, prepares delegation context JSON, invokes agent via Task tool
- Trigger conditions section documents when skill activates
- Context pointers reference (not eagerly loaded)
- Return validation against subagent-return.md schema

**Agent** (`presentation-agent.md`):
- Full execution flow with stages
- Tool detection, content generation, output validation
- Structured JSON return with status, summary, artifacts, metadata
- Error handling for missing dependencies, corrupted files

**Key Differences for /deck vs /slides**:
- `/slides` converts existing PPTX files to typst/beamer
- `/deck` generates new Typst slides from a prompt or file content
- `/deck` needs embedded pitch deck knowledge (YC best practices)
- `/deck` does not need python-pptx or pandoc dependencies
- `/deck` only needs typst for compilation (optional)

### 4. Extension Structure

The `/deck` command belongs in `.claude/extensions/filetypes/` because:
- It generates a filetype (Typst presentations)
- It follows the same command-skill-agent pattern as `/slides`, `/convert`, `/table`
- The filetypes extension already has presentation-related context

**Files to create**:

```
.claude/extensions/filetypes/
  commands/deck.md                           # /deck command
  skills/skill-deck/SKILL.md                 # Skill wrapper
  agents/deck-agent.md                       # Deck generation agent
  context/project/filetypes/
    patterns/pitch-deck-structure.md          # YC deck structure & design principles
    patterns/touying-pitch-deck-template.md   # Touying template for pitch decks
```

**Files to update**:
- `manifest.json` - Add new command, skill, agent
- `index-entries.json` - Add new context file entries
- `EXTENSION.md` - Add /deck section to documentation

## Recommendations

### Implementation Architecture

1. **Command (`/deck`)**: Accept a prompt string OR a file path (markdown, text, etc.) containing startup information. Optional flags: `--output PATH`, `--theme NAME`, `--slides N` (default 10).

2. **Skill (`skill-deck`)**: Thin wrapper that validates input, determines if input is a file path or prompt, reads file content if needed, and delegates to deck-agent.

3. **Agent (`deck-agent`)**: The main intelligence. Uses YC pitch deck context to:
   - Parse input (prompt or file content) for startup information
   - Map content to the 9-10 slide structure
   - Generate Typst code using touying simple theme
   - Optionally compile to PDF if typst is available

4. **Context files**: Two context files encoding:
   - `pitch-deck-structure.md`: YC's 9-slide structure, content guidance per slide, design principles, anti-patterns
   - `touying-pitch-deck-template.md`: Ready-to-use touying template with placeholders for each slide type

### Template Design

The touying template should:
- Use `simple` theme for clean investor-friendly appearance
- Set 16:9 aspect ratio
- Use large font sizes (aligning with YC legibility principle)
- Include one idea per slide (simplicity principle)
- Use high-contrast colors (dark text on light background)
- Include slide-type-specific layouts (e.g., two-column for Team, chart placeholder for Traction)

### Input Handling Strategy

The agent should handle three input types:
1. **Prompt only**: "My startup Acme does X. We've grown 300% MoM. Team is..."
2. **File path**: Read markdown/text file with startup info
3. **Prompt + file**: Combine both sources of information

For incomplete information, the agent should:
- Generate slides with available information
- Add placeholder markers `[TODO: Add your ...]` for missing sections
- Include speaker notes explaining what content belongs in each slide

## Decisions

- **Touying over Polylux**: Touying is more actively maintained, has better heading-based syntax, and more professional themes
- **Simple theme as default**: Aligns perfectly with YC's design principles (legibility, simplicity, obviousness)
- **10-slide default**: 9 YC slides + optional closing slide for contact/Q&A
- **Extension placement**: In filetypes extension, not core system, since it generates a specific filetype
- **Typst-only output**: No Beamer/LaTeX variant; Typst is the right modern choice for this use case
- **No compilation requirement**: Generate .typ file; compilation to PDF is optional (user may want to edit first)

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Touying API changes (pre-1.0) | Pin specific version (0.6.3) in template, document upgrade path |
| Incomplete user input | Use TODO placeholders and speaker notes for guidance |
| Typst not installed | Agent generates .typ file regardless; warn about compilation |
| Template looks generic | Include customization guidance in speaker notes; allow theme override |
| Content too verbose for slides | Agent instructions enforce "one idea per slide" and word limits |

## Appendix

### Search Queries Used
- "YC how to build your seed round pitch deck slides structure recommended"
- "YC how to design a better pitch deck design principles tips"
- "typst presentation slides package polylux touying 2025 2026"
- "touying typst slides tutorial syntax example theme setup 2025"

### References
- [How to build your seed round pitch deck - YC](https://www.ycombinator.com/library/2u-how-to-build-your-seed-round-pitch-deck)
- [How to design a better pitch deck - YC](https://www.ycombinator.com/library/4T-how-to-design-a-better-pitch-deck)
- [How to design a better pitch deck - YC Blog](https://www.ycombinator.com/blog/how-to-design-a-better-pitch-deck/)
- [YC Guide analysis - The Venture Crew](https://theventurecrew.substack.com/p/y-combinator-guide-how-to-build-your)
- [Touying - Typst Universe](https://typst.app/universe/package/touying/)
- [Touying GitHub](https://github.com/touying-typ/touying)
- [Polylux - Typst Universe](https://typst.app/universe/package/polylux/)
- [Polylux Documentation](https://polylux.dev/book/)

### Existing Extension Files Referenced
- `.claude/extensions/filetypes/EXTENSION.md` - Extension documentation pattern
- `.claude/extensions/filetypes/manifest.json` - Manifest structure
- `.claude/extensions/filetypes/commands/slides.md` - Command pattern
- `.claude/extensions/filetypes/skills/skill-presentation/SKILL.md` - Skill pattern
- `.claude/extensions/filetypes/agents/presentation-agent.md` - Agent pattern
- `.claude/extensions/filetypes/index-entries.json` - Context index entries
- `.claude/extensions/filetypes/context/project/filetypes/patterns/presentation-slides.md` - Slide patterns

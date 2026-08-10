# Talk Modes and Talk Library

Routing summary of the /slides talk modes, and a map of the reusable assets the /slides pipeline
draws on when planning, assembling, and critiquing a deck.

## Talk Modes

| Mode | Duration | Slides | Use Case |
|------|----------|--------|----------|
| CONFERENCE | 15-20 min | 12-18 | Conference platform presentations |
| SEMINAR | 45-60 min | 30-45 | Departmental seminars, job talks |
| DEFENSE | 30-60 min | 25-40 | Grant defense, thesis defense |
| POSTER | N/A | 1 | Poster session presentations |
| JOURNAL_CLUB | 15-30 min | 10-15 | Paper review for journal club |

This table is the slide-count and duration summary only. For audience, format, key
considerations, common venues, and the mode selection guide, see `presentation-types.md` in this
same directory, which is the authoritative per-mode reference.

## Talk Library

The talk library lives at `context/project/present/talk/`. It is registered in
`talk/index.json`, the machine-readable manifest of everything listed below.

| Directory | Contents |
|-----------|----------|
| `talk/patterns/` | Slide structure definitions for each talk mode, plus Slidev and python-pptx generation guidance |
| `talk/contents/` | Slidev-compatible markdown templates for individual slide types (methods, discussion, conclusions, acknowledgments) |
| `talk/templates/` | Project scaffolds: a Slidev project skeleton, a python-pptx generation project, and a Playwright verification script |
| `talk/components/` | Vue components for Slidev decks: FigurePanel, DataTable, CitationBlock, StatResult, FlowDiagram |
| `talk/themes/` | Visual themes: academic-clean, clinical-teal, and ucsf-institutional |
| `talk/critique-rubric.md` | Six-category critique rubric with severity definitions and a talk-type priority matrix |

## How Agents Use It

- **Planning** (`slide-planner-agent`): reads `talk/index.json` and the mode's structure pattern
  in `talk/patterns/` to propose a slide-by-slide plan.
- **Assembly** (`slidev-assembly-agent`, `pptx-assembly-agent`): copies the matching scaffold from
  `talk/templates/`, applies a theme from `talk/themes/`, and fills slides using
  `talk/contents/` templates and `talk/components/`.
- **Critique** (`slide-critic-agent`): evaluates the assembled deck against
  `talk/critique-rubric.md`.

## Theme Selection

Themes are JSON constant files (colors, fonts, sizes, logos) consumed by both output formats.
`academic-clean` is the neutral default; `clinical-teal` suits clinical and translational
audiences; `ucsf-institutional` carries institutional branding. The python-pptx path reads the
same constants through `talk/templates/pptx-project/theme_mappings.json`, so a theme choice
applies identically to Slidev and PowerPoint output.

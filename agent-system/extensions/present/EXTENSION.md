## Present Extension

Structured proposal development (grants) and research presentation creation (talks) in Typst and Slidev formats.

### Routing

| Task Type | Operation | Skill | Agent | Model | Tools |
|-----------|-----------|-------|-------|-------|-------|
| `present` (bare), `present:grant` | research, implement | skill-grant | grant-agent | opus | WebSearch, WebFetch, Read, Write, Edit |
| `present:budget` | research, implement | skill-budget | budget-agent | opus | WebSearch, WebFetch, Read, Write, Edit, Bash |
| `present:timeline` | research, implement | skill-timeline | timeline-agent | opus | WebSearch, WebFetch, Read, Write, Edit |
| `present:funds` | research, implement | skill-funds | funds-agent | opus | WebSearch, WebFetch, Read, Write, Edit, Bash |
| `present:slides` | research, implement | skill-slides | slides-research-agent, pptx-assembly-agent, slidev-assembly-agent | opus | WebSearch, WebFetch, Read, Write, Edit |
| `present:slides` | plan | skill-slide-planning | slide-planner-agent | opus | Read, Write, Edit |
| `present:slides` | critique | skill-slide-critic | slide-critic-agent | opus | Read, Write, Edit |

All other `present:*` task types use `skill-planner` / `planner-agent` for the plan operation.

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/grant` | `"Description"` \| `N --draft ["focus"]` \| `N --budget ["guidance"]` \| `--revise N "description"` | Create grant task (stops at [NOT STARTED]); draft narrative sections (exploratory); develop budget with justification; create a revision task for an existing grant |
| `/budget` | `"Description"` \| `N` | Create or resume a grant budget task with forcing questions |
| `/timeline` | `"Description"` \| `N` | Create or resume a research timeline task |
| `/funds` | `"Description"` \| `N` | Create or resume a funding analysis task with forcing questions |
| `/slides` | `"Description"` \| `N` \| `/path/to/file` \| `N --critic [path\|prompt]` | Create or resume a research talk task; use a file as primary source material; critique slides with an interactive feedback loop |

### Context

- @context/project/present/domain/talk-modes-and-library.md - Talk modes (duration, slide counts) and the talk library
- @context/project/present/domain/presentation-types.md - Per-mode audience, format, and selection guide
- @context/project/present/domain/grant-workflow.md - Grant proposal development workflow
- @context/project/present/patterns/talk-structure.md - Cross-mode slide organization patterns
- @context/project/present/standards/character-limits.md - Section length and formatting limits

# Research Report: Task #741

**Task**: 741 - Convert TODO.md artifact references to markdown links
**Started**: 2026-06-17T00:00:00Z
**Completed**: 2026-06-17T00:00:00Z
**Effort**: < 30 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase (generate-todo.sh, artifact-linking-todo.md)
**Artifacts**: specs/741_todo_artifact_markdown_links/reports/01_markdown-links-research.md
**Standards**: report-format.md

## Executive Summary

- `generate-todo.sh` currently outputs artifact references as bare brackets `[path]` on lines 284 and 290
- The target format is proper markdown links `[path](specs/path)`, using the short path (with `specs/` prefix stripped) as display text and the full `specs/` prefixed path as the link target
- `artifact-linking-todo.md` currently documents the bracket-only format and needs updating to reflect the new markdown link format

## Context & Scope

This task updates two files:
1. `.claude/scripts/generate-todo.sh` - the script that regenerates `specs/TODO.md` from `state.json`
2. `.claude/context/patterns/artifact-linking-todo.md` - the pattern documentation for artifact linking

The goal is to make artifact references in `TODO.md` render as clickable markdown links rather than non-functional bracketed text.

## Findings

### Codebase Patterns

**generate-todo.sh artifact rendering block** (lines 282-292):

```bash
if [[ "$path_count" -le 1 ]]; then
  # Single artifact: inline format
  printf -- '- **%s**: [%s]\n' "$display_type" "$paths_str"
else
  # Multiple artifacts: multi-line list
  printf -- '- **%s**:\n' "$display_type"
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    printf '  - [%s]\n' "$p"
  done <<< "$paths_str"
fi
```

Key observations:
- `$short_path` is computed at line 266 by stripping the `specs/` prefix: `local short_path="${apath#specs/}"`
- `$paths_str` contains newline-separated `short_path` values (already stripped of `specs/`)
- Line 284: single artifact format uses `[%s]` — needs `[%s](specs/%s)`
- Line 290: multi-artifact list format uses `[%s]` — needs `[%s](specs/%s)`

**Current output format examples:**
- Single: `- **Research**: [741_todo_artifact_markdown_links/reports/01_markdown-links-research.md]`
- Multi: `  - [741_todo_artifact_markdown_links/plans/01_implementation-plan.md]`

**Target output format examples:**
- Single: `- **Research**: [741_todo_artifact_markdown_links/reports/01_markdown-links-research.md](specs/741_todo_artifact_markdown_links/reports/01_markdown-links-research.md)`
- Multi: `  - [741_todo_artifact_markdown_links/plans/01_implementation-plan.md](specs/741_todo_artifact_markdown_links/plans/01_implementation-plan.md)`

**artifact-linking-todo.md** (line 29):
```
All new artifact links use **bracket-only** format: `[{todo_link_path}]` (not markdown `[text](url)`).
```
This line directly contradicts the desired new behavior and must be updated. The four-case examples throughout the doc also show bracket-only `[path]` syntax.

### Required Changes

#### File 1: `.claude/scripts/generate-todo.sh`

**Line 284** (single artifact, inline format):
```bash
# Before:
printf -- '- **%s**: [%s]\n' "$display_type" "$paths_str"

# After:
printf -- '- **%s**: [%s](specs/%s)\n' "$display_type" "$paths_str" "$paths_str"
```

**Line 290** (multiple artifacts, list item):
```bash
# Before:
printf '  - [%s]\n' "$p"

# After:
printf '  - [%s](specs/%s)\n' "$p" "$p"
```

Both changes pass the short path twice to `printf` — once as the display text and once to construct the `specs/`-prefixed URL.

#### File 2: `.claude/context/patterns/artifact-linking-todo.md`

The following updates are needed:

1. **Line 29** — Replace the link format declaration:
   - Before: `All new artifact links use **bracket-only** format: \`[{todo_link_path}]\` (not markdown \`[text](url)\`).`
   - After: `All new artifact links use **markdown link** format: \`[{todo_link_path}](specs/{todo_link_path})\`. The short path (with \`specs/\` stripped) is used as display text; the full \`specs/\`-prefixed path is the link target.`

2. **Case 1 example** (lines 55-64) — Update the example link format from `[398_extract_artifact/reports/01_initial-research.md]` to `[398_extract_artifact/reports/01_initial-research.md](specs/398_extract_artifact/reports/01_initial-research.md)` and the template from `[{todo_link_path}]` to `[{todo_link_path}](specs/{todo_link_path})`.

3. **Case 2 example** (lines 73-84) — Update both existing and new link examples to markdown format.

4. **Case 3 example** (lines 94-106) — Update link examples to markdown format.

5. **Compact Reference** (line 122) — Update the template example to show markdown link format.

## Decisions

- The short path (without `specs/` prefix) is used as the display text, since `TODO.md` lives inside `specs/` — this keeps displayed text compact while the link target includes `specs/` so it works from the repo root
- The printf approach of passing `$paths_str` (or `$p`) twice is idiomatic shell — no intermediate variable needed
- The note `(not markdown [text](url))` in artifact-linking-todo.md line 29 is now inverted — the new format IS markdown `[text](url)`

## Risks & Mitigations

- **Risk**: Existing TODO.md entries with bracket-only format will not be auto-converted. They remain until the next `generate-todo.sh` regeneration for each task.
  - **Mitigation**: This is acceptable — the change is forward-looking. Existing entries will be corrected when tasks are next touched.

- **Risk**: The `specs/` prefix in URLs is relative to the repo root. If README or TODO.md is viewed from a subdirectory, links may not resolve.
  - **Mitigation**: Standard behavior for GitHub markdown — links resolve from repo root when viewed on GitHub. This is the expected environment.

## Context Extension Recommendations

None for this meta task.

## Appendix

- Reviewed: `/home/benjamin/.config/nvim/.claude/scripts/generate-todo.sh` lines 240-295
- Reviewed: `/home/benjamin/.config/nvim/.claude/context/patterns/artifact-linking-todo.md` lines 1-131

# Research Report: Task #743

**Task**: 743 - Fix inconsistent "## AI Tools Used" section in PR description generation
**Started**: 2026-06-18T00:00:00Z
**Completed**: 2026-06-18T00:05:00Z
**Effort**: Low (targeted text changes in 2 files)
**Dependencies**: None
**Sources/Inputs**: Codebase (cslib extension files)
**Artifacts**: specs/743_standardize_ai_tools_used_section/reports/01_ai-tools-standardization.md
**Standards**: report-format.md

## Executive Summary

- The canonical template in `pr-description-format.md` uses heading `## AI Tools Used` with fully rendered paragraph text
- `cslib-implementation-agent.md` (line 358-360) uses the correct `## AI Tools Used` heading but has a vague `[describe what it did]` placeholder — it should reference the canonical template instead
- `pr.md` command (lines 1441, 1468, 1403, 1468) uses `## AI Disclosure` heading in both the draft template and the edit-branch handler references — heading and body text need to align with the canonical format
- Two additional files (`index-entries.json`, `cslib.md` rules, `pr-conventions.md`, `contributing-standards.md`) use "AI Disclosure" as a general concept label but are not generating PR descriptions and do not need heading changes

## Context & Scope

The CSLib extension generates PR descriptions in two places: the `skill-pr-implementation` agent (dispatched via `/implement`) and the `/pr` command's Step 9 path/description mode. A canonical template exists in `pr-description-format.md`. The goal is to make both generation sites consistent with the canonical template.

## Findings

### Canonical Template (pr-description-format.md, lines 230-256)

Section heading: `### 9. AI Tools Used (always last)`

Note on line 234: "Older PRs used the heading 'AI Disclosure'; 'AI Tools Used' is the preferred heading for new PRs."

Full canonical template block (lines 237-246):
```markdown
## AI Tools Used

This PR was prepared with the assistance of Claude Code (Anthropic). The AI tool was used for:
- Drafting and extracting files from a development branch to create a clean PR branch
- Running CI verification commands
- Drafting this PR description

All Lean code was written by the {author(s) — names} and verified to compile cleanly on the PR branch.
```

Short variant (lines 250-256):
```markdown
## AI Tools Used

This PR was prepared with the assistance of Claude Code (Anthropic), used for drafting/extracting
files from a development branch, running CI verification commands, and drafting this description.
All Lean code was written by the author ({name}) and verified to compile on the PR branch.
```

### File 1: cslib-implementation-agent.md (lines 353-360)

**Path**: `.claude/extensions/cslib/agents/cslib-implementation-agent.md`

**Current text (lines 353-360)**:
```
### AI Usage Disclosure (MANDATORY)
If AI tools are used, the PR description MUST explain which tools and how they were used. This is mandatory per CSLib's adoption of the Mathlib AI policy.

Include in every PR description:
```
## AI Tools Used
- Claude Code (cslib-implementation-agent): [describe what it did]
```
```

**Problem**: The `[describe what it did]` placeholder is vague and doesn't direct the agent to use the canonical template. An agent following this instruction literally would insert a placeholder into the PR description rather than rendering the canonical paragraph text.

**Recommended change**: Replace the code block showing the placeholder with a reference to the canonical template in `pr-description-format.md`. The heading `## AI Tools Used` is already correct.

### File 2: pr.md command (lines 1420-1449 and 1403/1468)

**Path**: `.claude/extensions/cslib/commands/pr.md`

**Problem 1 — Draft template heading (line 1441)**:
The Step 9 path/description mode draft template uses `## AI Disclosure` as the heading:
```markdown
## AI Disclosure

This PR was prepared with the assistance of Claude Code (Anthropic). The AI tool was used for:
- Drafting and extracting files from a development branch to create a clean PR branch
- Running CI verification commands
- Drafting this PR description

All Lean code was written by the author (Benjamin Brast-McKie) and verified to compile cleanly on the PR branch.
```

**Problem 2 — Edit-branch handler references (lines 1403 and 1468)**:
Both Step 8 (non-path mode) and Step 9 (path/description mode) have an "Edit AI disclosure" handler that says:
```
- Edit AI disclosure: read user's next message as the new disclosure; replace `## AI Disclosure`
```
The `replace` target string uses `## AI Disclosure`, which won't match the body once the heading is fixed to `## AI Tools Used`.

**Recommended changes**:
1. Line 1441: Change `## AI Disclosure` heading to `## AI Tools Used`
2. Line 1403: Change `replace \`## AI Disclosure\`` to `replace \`## AI Tools Used\``
3. Line 1468: Same change as line 1403

### Additional Files (informational — no changes needed)

These files use "AI Disclosure" as a general concept name or section label (not as a markdown heading being generated into a PR description). They are consistent with their purpose:

| File | Usage | Action |
|------|-------|--------|
| `.claude/extensions/cslib/index-entries.json` line 89 | description field: "AI Disclosure" as topic label | No change needed — internal metadata label |
| `.claude/extensions/cslib/rules/cslib.md` line 105 | `### AI Disclosure` as a section in agent rules | No change needed — not a generated PR heading |
| `.claude/extensions/cslib/context/project/cslib/standards/pr-conventions.md` line 75 | `## AI Disclosure Requirement` as section title | No change needed — not a generated PR heading |
| `.claude/extensions/cslib/context/project/cslib/domain/contributing-standards.md` line 84 | `### AI Disclosure` as section in contributing docs | No change needed — not a generated PR heading |

### skill-pr-implementation/SKILL.md (lines 38-40)

References `pr-description-format.md` and `pr-conventions.md` as the loaded standards for the agent. No changes needed here — it already points to the canonical source.

## Decisions

- Only two files need changes: `cslib-implementation-agent.md` and `pr.md`
- `pr-description-format.md` is the canonical source and requires no changes
- Informational files using "AI Disclosure" as a concept label do not need changes (the policy name and the generated heading are different things)

## Risks & Mitigations

- **Risk**: Changing the replace target string in the edit-branch handlers (lines 1403, 1468) from `## AI Disclosure` to `## AI Tools Used` must match the new heading exactly, or the replacement will silently fail.
  - **Mitigation**: The change to both the heading (line 1441) and the replace target (lines 1403, 1468) must be made together as a set.
- **Risk**: The body text in the `pr.md` draft template has author hardcoded as "Benjamin Brast-McKie" — this is pre-existing and out of scope for this task.

## Context Extension Recommendations

None. This is a meta task — section omitted per agent instructions.

## Appendix

### Files Examined
1. `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` — canonical template (lines 220-257)
2. `.claude/extensions/cslib/agents/cslib-implementation-agent.md` — AI disclosure section (lines 353-360)
3. `.claude/extensions/cslib/commands/pr.md` — Step 9 draft template and edit handlers (lines 1395-1471)
4. `.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md` — standards reference (lines 38-40)
5. `.claude/extensions/cslib/rules/cslib.md` — AI Disclosure rule (lines 105-111)
6. `.claude/extensions/cslib/context/project/cslib/standards/pr-conventions.md` — AI Disclosure requirement (lines 75-83)
7. `.claude/extensions/cslib/context/project/cslib/domain/contributing-standards.md` — AI Disclosure section (lines 84-92)
8. `.claude/extensions/cslib/index-entries.json` — description metadata (line 89)

### Search Queries
- `grep -rn "AI Disclosure\|AI Tools Used" .claude/extensions/cslib/`

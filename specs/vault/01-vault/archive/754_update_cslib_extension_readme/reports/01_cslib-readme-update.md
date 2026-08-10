# Research Report: Task #754

**Task**: 754 - Update cslib extension README.md to reflect all capabilities
**Started**: 2026-06-22T00:00:00Z
**Completed**: 2026-06-22T00:05:00Z
**Effort**: 0.5h
**Dependencies**: None
**Sources/Inputs**: Codebase (README.md, EXTENSION.md, manifest.json, founder/README.md, filesystem listing)
**Artifacts**: specs/754_update_cslib_extension_readme/reports/01_cslib-readme-update.md
**Standards**: report-format.md

---

## Executive Summary

- The cslib extension README.md is significantly out of date, omitting 4 agents, 5 skills, 1 command, 1 rule, hard-mode support, and the PR review workflow.
- The founder extension README.md provides a clear template: per-command sections, workflow diagram, architecture tree with all files listed, and complete routing/skill-agent tables.
- The README.md needs to be rewritten to match EXTENSION.md and manifest.json as sources of truth, adding the `pr` task type, `/pr` command, hard-mode routing, and updated architecture tree.

---

## Context & Scope

This research catalogs every discrepancy between `.claude/extensions/cslib/README.md` (the outdated consumer-facing doc) and the two authoritative sources:
- `.claude/extensions/cslib/EXTENSION.md` (merged into CLAUDE.md on load)
- `.claude/extensions/cslib/manifest.json` (extension loader configuration)

The founder extension README.md is used as a formatting/structure template.

---

## Findings

### Codebase Patterns

#### Filesystem Ground Truth (verified via `ls`)

**agents/** (6 files):
- cslib-research-agent.md
- cslib-implementation-agent.md
- cslib-research-hard-agent.md
- cslib-implementation-hard-agent.md
- pr-review-research-agent.md
- pr-review-implementation-agent.md

**skills/** (7 directories):
- skill-cslib-research
- skill-cslib-implementation
- skill-pr-implementation
- skill-cslib-research-hard
- skill-cslib-implementation-hard
- skill-pr-review-research
- skill-pr-review-implementation

**commands/** (1 file):
- pr.md

**rules/** (2 files):
- cslib.md
- cslib-lint-fix.md

---

### Section-by-Section Discrepancy List

#### 1. Overview table (line 6-11 of README.md)

**Current README.md**:
```
| Task Type | Research | Plan | Implementation |
| `cslib` | skill-cslib-research | skill-planner | skill-cslib-implementation |
```

**Missing**:
- `pr` task type row entirely absent
- Hard-mode routing not shown at all
- The table format is different from EXTENSION.md which lists routing by operation

**Fix**: Add `pr` row. Consider a note on hard-mode routing or a separate table (see EXTENSION.md model).

---

#### 2. Architecture tree (lines 19-44 of README.md)

**Current README.md shows**:
- agents/: 2 files (cslib-research-agent.md, cslib-implementation-agent.md)
- skills/: 2 entries (skill-cslib-research, skill-cslib-implementation)
- commands/: "(none -- uses standard /research, /plan, /implement)"
- rules/: 1 file (cslib.md)

**Actual (from filesystem)**:
- agents/: 6 files
- skills/: 7 entries
- commands/: pr.md
- rules/: 2 files (cslib.md, cslib-lint-fix.md)

**Missing agents** (4):
- cslib-research-hard-agent.md
- cslib-implementation-hard-agent.md
- pr-review-research-agent.md
- pr-review-implementation-agent.md

**Missing skills** (5):
- skill-pr-implementation
- skill-cslib-research-hard
- skill-cslib-implementation-hard
- skill-pr-review-research
- skill-pr-review-implementation

**Wrong commands entry**: says "(none)" but `pr.md` exists.

**Missing rule**: cslib-lint-fix.md

---

#### 3. Skill-Agent Mapping table (lines 46-51 of README.md)

**Current README.md** (2 rows):
```
| skill-cslib-research | cslib-research-agent | opus | ... |
| skill-cslib-implementation | cslib-implementation-agent | sonnet | ... |
```

**EXTENSION.md shows** (7 rows):
```
| skill-cslib-research | cslib-research-agent | opus | CSLib formalization research |
| skill-cslib-implementation | cslib-implementation-agent | sonnet | CSLib proof implementation |
| skill-pr-implementation | cslib-implementation-agent | sonnet | PR description preparation -> [PR READY] |
| skill-cslib-research-hard | cslib-research-hard-agent | opus | Hard-mode research (H4, H3) |
| skill-cslib-implementation-hard | cslib-implementation-hard-agent | sonnet | Hard-mode impl (H2, H9, H7) |
| skill-pr-review-research | pr-review-research-agent | sonnet | Fetch/synthesize GitHub PR and Zulip |
| skill-pr-review-implementation | pr-review-implementation-agent | sonnet | Compose pr-response.md + zulip-response.md |
```

**Missing**: 5 rows.

---

#### 4. Language Routing table (lines 53-57 of README.md)

**Current README.md** (1 row, cslib only):
```
| `cslib` | skill-cslib-research | skill-cslib-implementation | WebSearch, ..., lean-lsp MCP |
```

**EXTENSION.md shows** (2 rows):
```
| `cslib` | WebSearch, WebFetch, Read, lean-lsp MCP (inherited) | Read, Write, Edit, Bash (lake ...) |
| `pr` | gh api, python3 zulip client, Read, Bash | Read, Write, Edit, Bash (git, lake build, lake test) |
```

**Missing**: `pr` task type row entirely absent.

---

#### 5. Commands section (line 33, architecture tree)

**Current README.md**: `+-- commands/  # (none -- uses standard /research, /plan, /implement)`

**Actual**: commands/pr.md exists.

**Missing entire section**: No "Commands" section documenting `/pr` with its usage forms.

EXTENSION.md documents three `/pr` forms:
```
/pr <task_number|path|description> [--draft] [--dry-run]  # Submit CSLib PR (user-only)
/pr --review <sources...>                                  # Create pr-type review task
/pr N  (when task is [PR READY] with sources)             # Post PR comment + Zulip message
```

---

#### 6. Hard-mode support section

**Current README.md**: No mention of hard mode at all.

**EXTENSION.md** has a complete "When to Use --hard for CSLib Tasks" section with:
- 5 numbered trigger conditions
- List of what hard mode adds (H2, H3, H4, H7, H9)
- Cost impact note (~3-5x)
- routing_hard entries for both cslib and pr task types

**manifest.json routing_hard block**:
```json
"routing_hard": {
  "research": { "cslib": "skill-cslib-research-hard", "pr": "skill-researcher-hard" },
  "plan":     { "cslib": "skill-planner-hard",         "pr": "skill-planner-hard" },
  "implement":{ "cslib": "skill-cslib-implementation-hard", "pr": "skill-implementer-hard" }
}
```

---

#### 7. PR review workflow section

**Current README.md**: No mention of PR review workflow.

**EXTENSION.md** and `rules/pr-prohibition.md` document a two-path PR workflow:
- **pr-submission** (no sources): `/implement` produces `pr-description.md` -> `[PR READY]` -> user runs `/pr N`
- **pr-review** (with sources): `/research N` fetches GitHub PR + Zulip; `/implement N` produces `pr-response.md` + `zulip-response.md` -> `[PR READY]` -> user runs `/pr N` to post

---

#### 8. Keyword overrides (manifest.json)

**Current README.md**: Not documented.

**manifest.json** shows keyword_overrides that auto-detect task types:
```json
"keyword_overrides": {
  "cslib": { "keywords": ["lean", "lean4", "mathlib", "theorem", "proof", "lint-fix"], "aliases": ["lean4"] },
  "pr":    { "keywords": ["pr", "pull request", "submit", "upstream", "branch", "rebase", "cherry-pick"] }
}
```

Useful to document so users understand how task type auto-detection works.

---

#### 9. Dependencies section

**Current README.md**: References section mentions CSLib repo, CONTRIBUTING.md, Lean 4 docs, Mathlib.

**manifest.json** declares:
```json
"dependencies": ["core", "lean", "literature"]
```

The README mentions only the lean dependency (providing lean-lsp MCP). The `literature` dependency is not mentioned. The founder README has a dedicated "Dependencies" section linking to other extension READMEs.

---

#### 10. Version field

**manifest.json**: `"version": "1.0.0"`

No version shown in README.md heading. The founder README shows `# Founder Extension (v3.0)` in the title. This is a low-priority cosmetic gap but worth updating consistently.

---

### Template Patterns from Founder Extension README

The founder extension README demonstrates these structural patterns worth adopting:

1. **Version in title**: `# CSLib Extension (v1.0.0)` (or bump to v1.1.0 if significant update)
2. **"What's New" section** (if version bump): highlights breaking changes and additions
3. **Command table at top**: Quick overview table of all commands with purpose and output
4. **Per-command sections**: Each command gets its own `###` heading with syntax block and mode list
5. **Architecture tree**: Lists every file under every subdirectory — no omissions
6. **Workflow diagram**: ASCII art showing the full lifecycle with status transitions
7. **Per-Type Research Agents table**: Separate table mapping commands to agents with specialization column
8. **Output Artifacts table**: What files are produced by which commands in which modes
9. **Dependencies section**: Links to other extension READMEs with `[extension/README.md]` links
10. **Key Patterns section**: Documents behavioral contracts and design principles

The cslib README should add sections 5, 6 (workflow), 7, 8, 9 from the above list, and expand the existing sections to match actual capabilities.

---

### Recommendations

#### Priority 1: Architecture Tree (high visibility, users see it first)

Update `agents/`, `skills/`, `commands/`, and `rules/` listings to show all files. Add `cslib-lint-fix.md` to rules, add `pr.md` to commands, list all 6 agents and 7 skills.

#### Priority 2: Skill-Agent Mapping Table

Expand from 2 rows to 7 rows using the EXTENSION.md table as the source. Copy verbatim with accurate model and purpose columns.

#### Priority 3: Language Routing Table

Add `pr` row with correct tool lists from EXTENSION.md.

#### Priority 4: Commands Section

Add a new "Commands" section (after Language Routing) documenting `/pr` with all three usage forms.

#### Priority 5: Hard-Mode Support Section

Add a new "Hard Mode" section with the 5 trigger conditions, H-technique list, and cost note from EXTENSION.md. Add a hard-mode routing table showing routing_hard entries from manifest.json.

#### Priority 6: PR Review Workflow Section

Add a new "PR Review Workflow" section explaining the two-path pr task type (pr-submission vs pr-review), the source detection logic, and the four-step review flow.

#### Priority 7: Keyword Auto-Detection

Add a brief note or table showing which keywords trigger automatic cslib vs pr task type detection.

#### Priority 8: Dependencies Section

Add a "Dependencies" section listing lean and literature extensions (with links), explaining what each provides.

---

## Decisions

- Use EXTENSION.md as the primary content source for all new sections (it is authoritative and maintained).
- Use manifest.json for routing tables, keyword_overrides, and dependencies.
- Use the founder extension README as the structural template.
- Do NOT change the CI Verification Pipeline section — it is accurate and complete.
- Do NOT change the References section beyond minor corrections.
- The version bump (1.0.0 -> 1.1.0) is optional but recommended if the update is substantial.

---

## Risks & Mitigations

- **Risk**: README.md and EXTENSION.md diverge again in the future.
  - **Mitigation**: The check-extension-docs.sh script validates cross-references; the implementation could add a note in README.md header pointing to EXTENSION.md as the authoritative source.

- **Risk**: `/pr` command details may change.
  - **Mitigation**: Summarize rather than duplicate; link to commands/pr.md for full syntax.

---

## Context Extension Recommendations

- None. The discrepancies found are within the cslib extension itself; no broader context layer changes are needed.

---

## Appendix

### Files Examined

- `/home/benjamin/.config/nvim/.claude/extensions/cslib/README.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/EXTENSION.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/manifest.json`
- `/home/benjamin/.config/nvim/.claude/extensions/founder/README.md`
- Filesystem listing of cslib/agents/, skills/, commands/, rules/

### Key Counts (README vs Actual)

| Component | README says | Actual |
|-----------|------------|--------|
| Agents | 2 | 6 |
| Skills | 2 | 7 |
| Commands | (none) | 1 (pr.md) |
| Rules | 1 | 2 |
| Task types | 1 (cslib) | 2 (cslib, pr) |
| Hard-mode section | absent | full section in EXTENSION.md |
| PR review workflow | absent | full workflow in EXTENSION.md |

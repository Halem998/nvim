# Research Report: Task #919

**Task**: 919 - reference_normative_status_vocabulary_in_agents
**Started**: 2026-07-27T00:00:00Z
**Completed**: 2026-07-27T00:00:00Z
**Effort**: small (mechanical, ~15 single-line insertions)
**Dependencies**: None
**Sources/Inputs**: - Codebase (agent-system/extensions/{core,cslib,latex,lean,python,typst,web,z3}/agents/*.md, agent-system/extensions/core/context/formats/return-metadata-file.md)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All 15 files named in the task description exist at the expected paths under
  `agent-system/extensions/**/agents/` (the SOURCE store — confirmed, none are stray/renamed) and
  every one of them genuinely has zero mentions of `return-metadata-file` (`grep` confirmed
  0 hits across all 15).
- The three conforming agents use ONE consistent convention: an `## Context References` section
  placed immediately after `## Overview` (and after the `**IMPORTANT**: this agent writes
  metadata to a file...` paragraph, where present) and immediately before `## Agent Metadata`,
  containing a bullet `- \`@.claude/context/formats/return-metadata-file.md\` - {description}`.
  `lean-implementation-agent.md` is the closest structural template for the 15 in-scope files
  because it shares their exact skeleton (`Overview` → `Agent Metadata` → ... → `Execution
  Flow`/`Stage N` headings), unlike `planner-agent.md`/`general-implementation-agent.md` which
  use the core-agent skeleton (`Overview` → `Context References` → `Execution Flow` directly,
  no `Agent Metadata` section).
- Recommendation: 15 individual single-line (or single-bullet) edits, all pointing at the same
  normative file — not a new shared context file, and not copy-pasting the enum. No existing
  shared/common template file is `@`-referenced by all 15 today, so there is no mechanical
  single-touchpoint fix; the "single shared reference" the task asks to prefer is satisfied by
  every file pointing at the *same* `return-metadata-file.md`, not by inventing a new
  intermediary file.
- Confirmed the requested class-of-defect check (worked examples of the success case): 13 of the
  15 in-scope files have **no `## Context References` section at all** (only the two `web/`
  files have one, placed later in the file, and it does not yet mention
  `return-metadata-file.md`). 8 of the 15 (`latex` x2, `python` x2, `typst` x2, `z3` x2) have
  **zero JSON examples anywhere** — not even a template for the terminal `researched`/
  `implemented` status — making them the most severe instances of the gap.
- Found one additional, adjacent schema-example defect worth flagging (not requested, but same
  defect class, and directly caused by the missing reference): `pr-review-implementation-agent.md`
  and `pr-review-research-agent.md`'s only worked "final metadata" JSON examples nest
  agent-specific fields (`pr_response_created`, `github_prs_fetched`, etc.) AND, worse, nest
  `completion_data` itself *inside* `metadata` — but per `return-metadata-file.md` lines 166-186,
  `completion_data` is a **top-level sibling of `metadata`**, not a child of it. This is exactly
  the kind of drift the task description predicts ("copy-paste is precisely how the vocabulary
  drifts out of sync with its normative source") and is independent evidence for the fix
  direction, though correcting that nested-`completion_data` bug is outside this task's stated
  scope (add the reference only).

## Context & Scope

Researched how to add an `@`-reference to
`agent-system/extensions/core/context/formats/return-metadata-file.md` (deploy path
`.claude/context/formats/return-metadata-file.md`) into the 15 named agent files, mirroring the
existing convention used by `planner-agent.md`, `general-implementation-agent.md`, and
`lean-implementation-agent.md`, per the task's explicit scope boundary: reference-only, no
handoff-contract additions, no task-number citations outside `specs/**`.

All file reads were performed against `agent-system/extensions/` (the source store), never
`.claude/` (gitignored deploy artifact), per the SOURCE-STORE RULE in the task description.

## Findings

### How the three conforming agents reference it (exact quotes)

**`agent-system/extensions/core/agents/planner-agent.md`** (core-agent skeleton: `Overview` →
`Context References` → `Execution Flow`, no `Agent Metadata` section):

```
## Context References

- `@.claude/context/formats/return-metadata-file.md` - Metadata file schema (always load)
- `@.claude/context/formats/plan-format.md` - Plan artifact structure and REQUIRED metadata fields (always load)
...
```
(lines 13-19; the bullet is the FIRST entry in the section)

Then reinforced inline at the point of use (Stage 0, line 27):
```
**CRITICAL**: Create `specs/{NNN}_{SLUG}/.return-meta.json` with `"status": "in_progress"`
BEFORE any substantive work. ... See `return-metadata-file.md` for full schema.
```
and again at Stage 1 (line 31): `Extract standard delegation fields (see \`return-metadata-file.md\` for schema).`

**`agent-system/extensions/core/agents/general-implementation-agent.md`** — identical pattern:
`## Context References` bullet at line 15 (`- \`@.claude/context/formats/return-metadata-file.md\`
- Metadata file schema (always load)`), plus the same Stage-0/Stage-1 inline callouts (lines 30,
34), plus a THIRD inline citation at Stage 6-modified-files (line 434) for a narrower,
unrelated field (`modified_files`) — not needed for this task's fix.

**`agent-system/extensions/lean/agents/lean-implementation-agent.md`** — this is the structural
template that matters most for the 15 in-scope files, because it shares their exact skeleton
(`## Overview` → `**IMPORTANT**: ...` paragraph → `## Agent Metadata` → ... `Stage N:` headings),
unlike the two core agents above which have no `## Agent Metadata` section at all:

```markdown
## Overview

Implementation agent specialized for Lean 4 proof development. Invoked by
`skill-lean-implementation` via the forked subagent pattern. Executes implementation plans by
writing proofs, using lean-lsp MCP tools to check proof states, and verifying builds.

**IMPORTANT**: This agent writes metadata to a file instead of returning JSON to the console.
The invoking skill reads this file during postflight operations.

## Context References

- `@.claude/context/formats/return-metadata-file.md` - Metadata file schema, including the
  `completion_data` object (always load before writing final metadata)

## Agent Metadata

- **Name**: lean-implementation-agent
...
```
(lines 9-24) plus a second inline citation at the point of the `implemented`-status
`completion_data` instruction (line 208): `per \`@.claude/context/formats/return-metadata-file.md\`,
every \`implemented\` return MUST include a \`completion_data\` object with...`.

**Path form used in the source store**: every one of the above `@`-references (including inside
`agent-system/extensions/{web,cslib,...}/agents/*.md` for their OWN extension-scoped context,
e.g. `@.claude/context/project/web/domain/astro-framework.md`) is written using the literal
DEPLOY-path prefix `@.claude/context/...`, never an `agent-system/extensions/...`-relative path.
This is a system-wide convention — the deploy step merges each extension's `context/` tree into
`.claude/context/`, and agent files are written against that merged deploy path regardless of
which extension's source directory they physically live in. The fix must use
`@.claude/context/formats/return-metadata-file.md` verbatim, not a source-relative path.

### Structural skeleton of the 15 in-scope files (confirmed via heading scan)

13 of 15 (all except the two `web/` files) share this exact `## `-heading skeleton:

```
## Overview
## Agent Metadata
## Allowed Tools      (or "## BLOCKED TOOLS (NEVER USE)" then "## Allowed Tools" for lean/cslib)
## <domain-specific sections, e.g. "## Compilation", "## Z3 Pattern Reference">
## Execution Flow  (or "## Stage 0: ..." directly, for cslib/pr-review agents)
```

None of these 13 has a `## Context References` heading anywhere in the file — confirmed by
`grep -c "^## Context References"` returning 0 for all 13. This means the fix is not "add a
bullet to an existing section" for 13/15 files; it is "insert a new two-line section" at the
same slot `lean-implementation-agent.md` already uses: immediately after the `## Overview`
paragraph (and its `**IMPORTANT**: ...` sentence, where present) and immediately before
`## Agent Metadata`.

The two `web/` files (`web-implementation-agent.md`, `web-research-agent.md`) are the exception:
they already have a `## Context References` section (further down, after `## Allowed Tools`,
before `## Execution Flow`), formatted differently — grouped under `**Load for Web Work**:` /
`**Load for Specific Tasks**:` subheadings with the framing "Load these on-demand using
@-references:". For these two, the correct fix is to add ONE new leading bullet/subgroup
(e.g. a `**Load Always**:` subgroup placed first) rather than creating a second
`## Context References` section — inserting into the existing section, not duplicating it. Since
`return-metadata-file.md` is an "always load" file elsewhere in the codebase (planner-agent.md,
general-implementation-agent.md, spawn-agent.md, reviser-agent.md all say "(always load)"), the
new bullet should carry that same qualifier even though it sits inside a section framed as
"on-demand" — that framing describes the OTHER bullets in that section, not this one.

### Recommendation: 15 individual edits pointing at the same file (not a new shared file)

There is no existing common/shared template `@`-referenced by all (or most) of the 15 files
today — `grep -rn "@\.claude" <each file>` shows each file's `@`-references are entirely
domain-specific (e.g. only `cslib-implementation-agent.md` references
`lint-prevention-rules.md`; `latex`/`python`/`typst`/`z3` implementation/research agents have
**zero** `@.claude/...` references anywhere in the file today). So there is no single upstream
file whose edit would propagate to all 15 automatically — each agent file is a self-contained
prompt read independently by its own `Agent` invocation, not composed from shared partials at
render time.

Given that, "prefer a single shared reference over copy-pasting the enum" is satisfied by making
all 15 files `@`-reference the ONE existing `return-metadata-file.md` (rather than, say,
re-stating the seven-row status table inline in each file, which is the anti-pattern the task
description is warning against). The concrete deliverable is 15 near-identical small edits, each
adding:

```markdown
## Context References

- `@.claude/context/formats/return-metadata-file.md` - Metadata file schema and normative status vocabulary (always load before writing final metadata)
```

placed between `## Overview` and `## Agent Metadata`, for the 13 non-web files (mirroring
`lean-implementation-agent.md`'s exact placement and two-line bullet-wrap style), and a single
new leading bullet inside the existing `## Context References` section for the 2 web files.

### Same-class gap: missing worked success-status examples

Per research focus #3, checked whether the 15 in-scope agents share the gap found in
`general-implementation-agent.md` (a sibling task's finding: that file's only worked example of
`phases_completed`/`phases_total` placement is in a `partial`-status/`partial_progress` block,
not an `implemented`-status/`metadata` block, and this caused a real off-schema write).

Findings, grouped by severity:

- **8 files with zero JSON examples anywhere** (`latex-implementation-agent.md`,
  `latex-research-agent.md`, `python-implementation-agent.md`, `python-research-agent.md`,
  `typst-implementation-agent.md`, `typst-research-agent.md`, `z3-implementation-agent.md`,
  `z3-research-agent.md`): the metadata-writing stage is a single unelaborated sentence,
  e.g. `latex-implementation-agent.md` line 136: `Write to
  \`specs/{N}_{SLUG}/.return-meta.json\`` — no status values, no field list, no example. These
  are the most severe instances of the same underlying defect class: an agent with no local
  guidance at all for what a correct terminal write looks like, worse than
  `general-implementation-agent.md`'s wrong-placement example because there is no example to be
  wrong. Adding the `@`-reference is the direct fix for exactly this severity tier — these 8
  files currently have nothing to point at without it.
- **`web-implementation-agent.md`**: HAS a correct, complete `implemented`-status example
  (Stage 7, lines ~367-390) with `phases_completed`/`phases_total` correctly nested under
  `metadata` — no gap here beyond the missing reference itself.
- **`web-research-agent.md`**: HAS a correct `researched`-status example (Stage 6, lines
  ~294-311) with `findings_count` correctly nested under `metadata` — no gap here either.
- **`cslib-implementation-agent.md`**: has a `partial_progress.phases_completed` field used for
  interim progress tracking (acceptable, different purpose from the terminal schema field of the
  same name) but its one `implemented`-status example (lines 287-301) is truncated
  (`"artifacts": [...]`) and does not show `phases_completed`/`phases_total` at all under
  `metadata` for the success case — a milder version of the same gap.
- **`cslib-research-agent.md`**, **`lean-research-agent.md`**: only worked example present is
  the Stage-0 `in_progress` template; no `researched`-status example with `findings_count` shown
  anywhere.
- **`pr-review-implementation-agent.md`** and **`pr-review-research-agent.md`**: DO have
  complete final-status examples, but — see Executive Summary — those examples themselves
  contain a schema violation (`completion_data` nested inside `metadata` rather than as a
  top-level sibling, per `return-metadata-file.md` lines 166-186). This is evidence that even a
  "complete-looking" local example is unsafe to trust without pointing back at the normative
  source, reinforcing rather than weakening the case for the `@`-reference fix.

## Decisions

- Use the exact string `@.claude/context/formats/return-metadata-file.md` (deploy-path form) in
  all 15 edits, matching the codebase-wide convention rather than an `agent-system/`-relative
  path.
- Mirror `lean-implementation-agent.md`'s placement (between `## Overview` and
  `## Agent Metadata`) and two-line bullet-wrap phrasing for the 13 non-web in-scope files.
- For the 2 web in-scope files, insert one new leading bullet into their EXISTING
  `## Context References` section rather than creating a duplicate section.
- Do not restate the status enum table inline in any of the 15 files — the reference IS the fix;
  copy-pasting the table would recreate the exact drift risk the task description warns against.
- Do not add `.orchestrator-handoff.json` writing instructions to any of these agents (explicit
  scope boundary in the task description, corroborated by
  `agent-system/extensions/core/docs/architecture/handoff-schema.md` and
  `general-research-agent.md`'s explicit "do NOT use ... `.orchestrator-handoff.json` for
  research" instruction).
- The `pr-review-*` nested-`completion_data` bug and the 8 zero-example files' complete absence
  of a worked success example are flagged as findings, not folded into this task's fix — the
  task description scopes the fix to "add the reference," and a planner should decide separately
  whether to expand scope to also correct the `pr-review` nesting bug or add worked examples,
  since both would be edits beyond a bare `@`-reference insertion.

## Risks & Mitigations

- **Risk**: Inserting a new `## Context References` heading into 13 files individually risks
  inconsistent placement or phrasing drift across files. **Mitigation**: use the verbatim
  `lean-implementation-agent.md` two-line block as a copy-paste template for the reference bullet
  text (only the placement paragraph before it varies per file, since each has a different
  Overview description).
- **Risk**: The 2 web files' existing `## Context References` section is framed as "on-demand,"
  which could lead an implementer to omit the "(always load)" qualifier that the fix needs for
  consistency with how every other conforming agent marks this specific file. **Mitigation**:
  called out explicitly above; the fix should carry the qualifier regardless of surrounding
  section framing.
- **Risk**: Scope creep — an implementer noticing the `pr-review-*` nested-`completion_data` bug
  or the 8 files' missing worked examples might be tempted to fix those too, expanding beyond
  the task's stated boundary (reference-only) and its explicit anti-goal (no new handoff
  contracts). **Mitigation**: flagged as separate findings above rather than folded into
  "Decisions," so a planner can consciously choose to scope them into this task or spin them out
  separately.

## Context Extension Recommendations

None — this is a meta task whose only defect is a missing pointer to already-existing,
already-correct normative documentation (`return-metadata-file.md`). No new context file is
warranted; the fix is entirely reference insertion into existing agent files.

## Appendix

### Search/verification commands used

```bash
find agent-system/extensions -iname "return-metadata-file.md"
grep -n "return-metadata-file" agent-system/extensions/core/agents/planner-agent.md
grep -n "return-metadata-file" agent-system/extensions/core/agents/general-implementation-agent.md
grep -n "return-metadata-file" agent-system/extensions/lean/agents/lean-implementation-agent.md
grep -q "^## Context References" <each of the 15 files>
grep -c '```json' <each of the 15 files>
grep -n '"status":' <each of the 15 files>
grep -rn "@\.claude" <each of the 15 files>
```

### File-by-file confirmation (all 15, source store, no `return-metadata-file` mentions found)

```
cslib/agents/cslib-implementation-agent.md
cslib/agents/cslib-research-agent.md
cslib/agents/pr-review-implementation-agent.md
cslib/agents/pr-review-research-agent.md
latex/agents/latex-implementation-agent.md
latex/agents/latex-research-agent.md
lean/agents/lean-research-agent.md
python/agents/python-implementation-agent.md
python/agents/python-research-agent.md
typst/agents/typst-implementation-agent.md
typst/agents/typst-research-agent.md
web/agents/web-implementation-agent.md
web/agents/web-research-agent.md
z3/agents/z3-implementation-agent.md
z3/agents/z3-research-agent.md
```

### Normative source, key line references (`agent-system/extensions/core/context/formats/return-metadata-file.md`)

- Lines 62-89: `status` field spec, including the seven-row normative table and the
  "Never use `completed`" note.
- Lines 91-104: "Three distinct vocabularies sharing the same words" — the disambiguation table
  that prevents cross-contamination with `state.json` status and lifecycle/notification status.
- Lines 123-138: `metadata` object spec, listing `phases_completed`/`phases_total`/
  `findings_count` as agent-specific optional fields nested under `metadata`.
- Lines 166-186: `completion_data` spec — explicitly a top-level object, not nested under
  `metadata` (the `pr-review-*` examples violate this).
- Lines 396-471: worked `Research Success` and `Implementation Success (Non-Meta)` examples —
  the canonical correct-placement examples that the 8 zero-example in-scope files currently have
  no equivalent of, and that a fixed `@`-reference would give them access to.

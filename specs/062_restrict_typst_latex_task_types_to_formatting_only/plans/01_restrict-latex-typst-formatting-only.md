# Implementation Plan: Task #62

- **Task**: 62 - Restrict typst and latex task types to formatting-only concerns
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: `specs/062_restrict_typst_latex_task_types_to_formatting_only/reports/01_restrict-latex-typst-formatting-only.md`
- **Artifacts**: plans/01_restrict-latex-typst-formatting-only.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Content-bearing work (proofs, theorems, textbook chapters, theses) currently routes to the
`latex`/`typst` task types because three independent surfaces conflate "the tool that formats the
document" with "the intellectual content being formatted". This plan narrows all three surfaces so
`latex`/`typst` are selected only for formatting/typesetting/compilation concerns, adds narrow
formatting-phrase `keyword_overrides` to both manifests (an additive change — neither manifest
declares that field today), reframes both extensions' self-description to state the
formatting-only boundary, and closes the two adjacent documentation gaps the research surfaced.

Every edit targets the source store under `agent-system/extensions/**`. No file under any deployed
`.claude/**` tree is hand-edited at any point.

### Research Integration

The research report supplies before/after text for all eight findings and establishes two premise
corrections that this plan is built on:

1. **Neither the `latex` nor the `typst` manifest declares `keyword_overrides` today.** Adding it
   (Phase 3) is an *additive* introduction of an early, high-precision match, not a narrowing of an
   existing over-broad list. The narrowing work happens entirely in the step 4d hardcoded table
   (Phase 1) and the `/fix-it` keyword table (Phase 2).
2. **Step 4e alias remapping is not a usable lever.** It matches on an already-resolved task_type
   string and has no visibility into *why* that string resolved, so it cannot discriminate content
   from formatting. Phase 1 records this as an intentional non-change so a future editor does not
   attempt the fix there.

Additional research findings folded in: the `"document"` keyword in the 4d latex row is a
false-positive magnet ("please **document** this function") and is dropped outright; the 4d table's
first-match-wins row ordering is currently undocumented and only accidentally correct, so it is
made explicit; and `formula` is deliberately omitted from every `/fix-it` row (it is genuinely
ambiguous between mathematical content and a rendering question, so it defaults to `general`).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- A description naming a formatting tool alongside mathematical or narrative content routes by
  content (`lean4`/`cslib`/`formal`/`general`), not by tool name.
- A description naming only a formatting tool, or using precise formatting vocabulary, still routes
  to `latex`/`typst`.
- The `/fix-it` QUESTION content-keyword table stops mapping pure math vocabulary to `latex`, and
  agrees with `/task`'s own 4d table rather than contradicting it.
- Both extensions state their formatting-only scope in their own agent and EXTENSION docs.
- The two adjacent doc gaps the research found (undocumented `keyword_overrides` schema, unstated
  alphabetical glob-scan order) are closed.

**Non-Goals**:
- Changing the **file-type**-based detection tables (`.tex -> latex` in `skill-fix-it`'s todo-task
  path, `*.tex`/`*.typ` in `review.md`). Those route by which file a tag or diff lives in — a
  different, legitimate mechanism — and are explicitly out of scope per the research.
- Changing step 4a (unconditional meta-keyword precedence) or step 4e's remapping *behavior*.
- Relocating the typst extension's mathematical-content standards library
  (`textbook-standards.md`, `type-theory-foundations.md`) to a content-focused extension. Phase 6
  applies a light scope-boundary note and records a follow-up recommendation instead; a full
  relocation is materially larger than the routing fix this task scopes.
- Running any deploy or regeneration of `.claude/**`. See the Rollback section.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A new `keyword_overrides` phrase collides with content vocabulary and steals a content-bearing task at step 4b (which short-circuits before 4d) | H | L | Every added phrase is multi-word or a compilation/tooling term (`latexmk`, `bibtex`, `latex macro`); Phase 3 verification greps the phrase list against the content vocabulary the 4d lean4/formal rows claim and asserts an empty intersection |
| Invalid JSON written into a manifest silently breaks the whole 4b cross-manifest scan (the reference jq pattern swallows errors with `2>/dev/null`) | H | L | Phase 3 verification runs `jq empty` on both manifests and re-reads the `keyword_overrides` block back via `jq` before the phase closes |
| The three `/fix-it` sites drift apart again (SKILL.md is the implementation; two docs merely illustrate it) | M | M | Phase 2 edits all three in one phase and its verification greps for the retired `theorem`→`latex` mapping across the entire source store, not just the three known paths |
| Editing the deployed `.claude/**` tree instead of the source store — the edit appears to succeed and is silently wiped by the next regeneration | H | L | Every phase names an `agent-system/extensions/**` path; Phase 6 verification asserts `git diff --name-only` contains no `.claude/` path |
| Reordering rows in the 4d table accidentally changes routing for an unrelated task type | M | L | Only the `formal` row moves and only the `lean4`/`latex` rows change content; Phase 1 verification diffs the row *set* before and after to confirm no row was dropped or duplicated |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 4 | -- |
| 2 | 5 | 1, 3 |
| 3 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel. Waves 1's four phases touch four disjoint file
sets (`commands/task.md`; the `/fix-it` trio; the two manifests; the four extension-framing docs),
so they carry no write conflicts.

---

### Phase 1: Narrow and document `/task` step 4 routing [COMPLETED]

**Goal**: Make content vocabulary win over tool-name vocabulary in the step 4d hardcoded keyword
table, and document the two ordering contracts (row order in 4d, glob order in 4b) plus the 4e
non-lever, so the fix cannot be accidentally reverted or re-attempted in the wrong place.

**Tasks**:
- [x] In the step 4d table, drop `"document"` from the latex row entirely, leaving
      `- "latex", "tex", "typeset" → latex`. (`"typeset"` stays: it is inherently formatting
      vocabulary with low false-positive risk.) *(completed)*
- [x] Extend the lean4 row to `"lean", "lean4", "mathlib", "theorem", "proof", "lemma", "axiom",
      "proposition", "corollary", "derivation"`, matching the vocabulary Phase 2 assigns to `lean4`
      in the `/fix-it` table. *(completed)*
- [x] Add a new content row `- "textbook", "chapter", "thesis", "dissertation" → general` directly
      after the lean4 row. *(completed)*
- [x] Move the existing `- "formal", "logic", "math", "physics", "modal", "kripke" → formal` row up
      so it sits with the other content rows, ahead of the latex/tex and typst rows. Do not change
      its keyword list. *(completed)*
- [x] Amend the `**4d. Hardcoded keyword table**` heading line to state the scan-order contract
      explicitly: evaluated top-to-bottom, first matching row wins, and content-signal rows are
      listed before the latex/tex and typst rows precisely so a description naming a formatting tool
      alongside mathematical or narrative content routes by content, not by tool name. *(completed)*
- [x] Add one sentence to step 4b's prose recording that the cross-manifest scan
      (`for manifest in .claude/extensions/*/manifest.json`) iterates in **alphabetical
      directory-name order** and breaks on first match, so a future extension author scoping new
      `keyword_overrides` knows first-match-wins is alphabetical, not intent-based. *(completed)*
- [x] Add one sentence to step 4e recording that alias remapping matches on an already-resolved
      task_type string, has no visibility into which keyword produced it, and is therefore
      intentionally not the place to solve content-vs-formatting discrimination. *(completed)*


**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts exactly one file is modified
(`agent-system/extensions/core/commands/task.md`) and that the 4d table's row *set* changes by
exactly one addition (the `general` content row) with two rows edited in place (lean4, latex) and
one row moved (formal). Confirm at implementation time by diffing the sorted list of `→ <type>`
row-tails before and after: the multiset must differ only by the single new `→ general` entry.

**Files to modify**:
- `agent-system/extensions/core/commands/task.md` - step 4b prose (glob-order caveat), step 4d
  table (row narrowing, row additions, row reordering, scan-order contract sentence), step 4e prose
  (non-lever note)

**Verification**:
- `grep -n '"document"' agent-system/extensions/core/commands/task.md` returns no hit inside the 4d
  latex row.
- The `→ formal`, `→ lean4`, and `→ general` rows all appear at lower line numbers than the
  `→ latex` and `→ typst` rows.
- The row-tail multiset diff described in Scope Hypothesis shows exactly one addition.
- Steps 4b, 4d, and 4e each contain the new documentation sentence.

---

### Phase 2: Correct `/fix-it` QUESTION content-keyword routing [NOT STARTED]

**Goal**: Stop the `/fix-it` QUESTION content-based detector from mapping pure mathematical
vocabulary to `latex`, and bring its two illustrative doc mirrors into agreement with it.

**Tasks**:
- [ ] In `skill-fix-it/SKILL.md` Step 8.5, replace the single
      `- latex: theorem, proof, lemma, axiom, logic, formula, derivation, proposition, corollary,
      latex, tex` row with the separated row set:
      `lean4: theorem, proof, lemma, axiom, proposition, corollary, derivation` /
      `formal: logic` /
      `latex: latex, tex, bibtex, biblatex, latex macro, latex package, compile error` /
      `typst: typst, typst package, typst compile` /
      `meta: .claude, command, agent, skill, workflow, state.json, TODO.md, specs/` (unchanged) /
      `Default: "general"` (unchanged).
- [ ] Deliberately omit `formula` from every row so it falls through to `general`. Record that
      choice in a short parenthetical beside the table: a formula can be either mathematical content
      or a rendering question, so it is not guessed at.
- [ ] In `commands/fix-it.md`, update the research-task prose so the illustrative example reads
      `theorem, proof, lemma, etc. -> "lean4"` and add a formatting-side pairing such as
      `bibtex, compile error -> "latex"`, so the example itself demonstrates the formatting-only
      boundary instead of contradicting it.
- [ ] In `docs/examples/fix-it-flow-example.md`, apply the same correction to the
      "QUESTION: language detection" paragraph (`theorem/proof/lemma -> lean4`, plus a
      formatting-side example).
- [ ] Leave every **file-type**-based table untouched (`.tex -> "latex"` in the todo-task path).

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts exactly three files carry the retired
`theorem`/`proof`/`lemma` → `latex` mapping. Confirm at implementation time with
`grep -rniE 'theorem[,/ ].*(proof|lemma).*latex' agent-system/extensions/` — the pre-edit hit set
must be exactly those three paths, and the post-edit hit set must be empty. If a fourth site
appears, fix it in this phase and record the widened file list in the summary.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-fix-it/SKILL.md` - Step 8.5 content-based keyword rows
- `agent-system/extensions/core/commands/fix-it.md` - research-task illustrative prose
- `agent-system/extensions/core/docs/examples/fix-it-flow-example.md` - QUESTION language-detection
  illustrative prose

**Verification**:
- The `grep` in Scope Hypothesis returns zero hits across the whole source store.
- `grep -n 'formula' agent-system/extensions/core/skills/skill-fix-it/SKILL.md` shows `formula` only
  in the explanatory parenthetical, never inside a keyword row.
- The `lean4`, `formal`, `latex`, `typst`, `meta`, and `Default` rows are all present in Step 8.5.
- The `.tex -> "latex"` file-type row is byte-identical to its pre-edit form.

---

### Phase 3: Add formatting-scoped `keyword_overrides` to the latex and typst manifests [NOT STARTED]

**Goal**: Give genuinely formatting-scoped requests an early, high-confidence step-4b match on
precise phrases, without creating any new path by which content vocabulary reaches `latex`/`typst`.

**Tasks**:
- [ ] Add a top-level `keyword_overrides` object to `agent-system/extensions/latex/manifest.json`
      with a single `"latex"` key whose `keywords` array is
      `["latex formatting", "latex compile", "latex compilation", "latexmk", "pdflatex", "bibtex",
      "biblatex", "latex package", "latex macro", "vimtex", "latex template", "tex compile error",
      "latex style"]` and whose `aliases` array is empty.
- [ ] Add the analogous block to `agent-system/extensions/typst/manifest.json` under a `"typst"`
      key: `["typst formatting", "typst compile", "typst compilation", "typst package",
      "typst template", "typst style", "typst layout", "fletcher diagram"]`, `aliases: []`.
- [ ] Keep `aliases` empty in both. A non-empty `aliases` list would make step 4e claim
      already-resolved task_types for these extensions — the exact content-capturing behavior this
      task exists to remove.
- [ ] Match the field placement and formatting conventions already used by the `email`, `cslib`, and
      `literature` manifests so the three worked examples stay visually consistent.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exactly two manifest files are modified and that the added
phrases have an empty intersection with the content vocabulary claimed by the 4d `lean4`, `formal`,
and `general` rows and by `cslib`'s existing `keyword_overrides`. Confirm at implementation time by
extracting both new keyword arrays with `jq` and grepping each phrase against that content
vocabulary list; a non-empty intersection blocks the phase.

**Files to modify**:
- `agent-system/extensions/latex/manifest.json` - add `keyword_overrides.latex`
- `agent-system/extensions/typst/manifest.json` - add `keyword_overrides.typst`

**Verification**:
- `jq empty` succeeds on both manifests (invalid JSON would be swallowed by the 4b scan's
  `2>/dev/null` and silently disable cross-manifest routing entirely).
- `jq -r '.keyword_overrides | keys[]'` returns exactly `latex` and `typst` respectively.
- `jq -r '.keyword_overrides[].aliases | length'` returns `0` for both.
- The keyword/content intersection check from Scope Hypothesis is empty.
- Direct dependents of the manifest contract are re-read and confirmed unaffected: step 4b's scan
  (whole-word `\b`-anchored `test()` over the description — every added phrase is alphanumeric plus
  spaces, so no regex metacharacter is introduced) and step 4e's alias scan (no-op, both `aliases`
  arrays empty).
- No other manifest under `agent-system/extensions/*/manifest.json` is modified.

---

### Phase 4: Reframe the latex and typst extensions as formatting-only [NOT STARTED]

**Goal**: Remove the "document creation" framing that invites content-authoring work to be
dispatched to these extensions, and state the formatting-only boundary in both extensions'
self-description.

**Tasks**:
- [ ] Reword the Overview line and the Agent Metadata `**Purpose**` line in
      `latex-implementation-agent.md` from document *creation*/*implementations* to document
      **formatting, structure, and compilation** / **formatting and structural changes from plans**,
      with an explicit parenthetical that authorship of the underlying content is out of scope.
- [ ] Apply the parallel rewording to `typst-implementation-agent.md`.
- [ ] Add a one-line `### Scope` note to `agent-system/extensions/latex/EXTENSION.md` stating that
      the extension covers formatting, compilation, styling, and structural concerns for existing
      document content, and that content-creation work (proofs, theorems, chapters, textbook prose)
      routes to `lean4`, `formal`, or `general` as appropriate.
- [ ] Add the same `### Scope` note to `agent-system/extensions/typst/EXTENSION.md`.
- [ ] Scan the rest of both extension trees for any other "document creation"/"authoring" framing in
      agent or EXTENSION prose and correct it in the same pass.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts four files carry the content-authoring framing. Confirm at
implementation time with `grep -rniE 'document (creation|authoring)|create.*document'
agent-system/extensions/latex/ agent-system/extensions/typst/`; if the hit set exceeds these four
paths, extend the phase to cover the additional prose sites and record the widened list.

**Files to modify**:
- `agent-system/extensions/latex/agents/latex-implementation-agent.md` - Overview + Purpose framing
- `agent-system/extensions/typst/agents/typst-implementation-agent.md` - Overview + Purpose framing
- `agent-system/extensions/latex/EXTENSION.md` - new `### Scope` note
- `agent-system/extensions/typst/EXTENSION.md` - new `### Scope` note

**Verification**:
- Both agent files' Overview and Purpose lines name formatting/structure/compilation and disclaim
  content authorship.
- Both `EXTENSION.md` files contain a `### Scope` heading whose body names `lean4`, `formal`, and
  `general` as the content-work destinations.
- The `grep` from Scope Hypothesis returns no remaining content-authoring framing.

---

### Phase 5: Document the `keyword_overrides` schema in the extension guide [NOT STARTED]

**Goal**: Close the dangling documentation pointer. The generated root CLAUDE.md tells extension
authors to see `context/guides/extension-development.md` for the `keyword_overrides` schema, and
that guide contains zero occurrences of the string `keyword`.

**Tasks**:
- [ ] Add a `### keyword_overrides` subsection under the guide's existing `## Manifest Format`
      section (not a new top-level section — the field is part of the manifest schema the guide
      already documents).
- [ ] Document the shape `{"<task_type>": {"keywords": [...], "aliases": [...]}}`, what each array
      does, and when the block is consulted: `keywords` at step 4b (before the 4d hardcoded
      fallback, short-circuiting it), `aliases` at step 4e (remapping an already-resolved
      task_type).
- [ ] Document the whole-word `\b<keyword>\b` case-insensitive matching semantics, and note that
      because matching is whole-word-anchored, multi-word phrases are the way to get precision.
- [ ] Cross-reference the alphabetical glob-scan-order caveat added to step 4b in Phase 1, so the
      two gaps close together and an author scoping a new block knows first-match-wins is
      directory-name-alphabetical.
- [ ] Point at the worked examples (`email`, `cslib`, `literature`, and now `latex`/`typst`) rather
      than duplicating their content.

**Timing**: 0.5 hours

**Depends on**: 1, 3

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/guides/extension-development.md` - new `keyword_overrides`
  subsection under `## Manifest Format`

**Verification**:
- `grep -c 'keyword_overrides' agent-system/extensions/core/context/guides/extension-development.md`
  returns a non-zero count (it was zero before).
- The documented shape matches what Phase 3 actually wrote into the two manifests (compare against
  `jq '.keyword_overrides' agent-system/extensions/latex/manifest.json`).
- The section names both step 4b and step 4e and the alphabetical scan-order caveat.
- The pointer in `agent-system/extensions/core/merge-sources/claudemd.md` now resolves to real
  content.

---

### Phase 6: Scope decision on the typst content standards, and cross-surface consistency check [NOT STARTED]

**Goal**: Resolve the flagged question about the typst extension's mathematical-content standards
library, and verify that all four routing/documentation surfaces now tell the same story.

**Tasks**:
- [ ] Record the scope decision: **re-scope in place, do not relocate.** Relocating an entire
      content-standards library is a materially larger structural change than the routing fix this
      task scopes, and doing it here would put an unreviewed cross-extension move inside a routing
      change.
- [ ] Add a short scope-boundary note at the top of
      `typst/context/project/typst/standards/textbook-standards.md` and
      `.../type-theory-foundations.md` stating that these are content conventions consulted when
      formatting existing material, and that authoring the underlying mathematical content is not a
      `typst` task type concern. Cite durable anchors only — no task-number references, since these
      files live outside `specs/**`.
- [ ] Record a follow-up recommendation in the implementation summary (which lives under `specs/**`,
      where task references are permitted) proposing a dedicated task to decide whether this
      standards library should move to a content-focused extension.
- [ ] Run the cross-surface consistency sweep: confirm the vocabulary assignments in `/task` step 4d
      (Phase 1) and `/fix-it` Step 8.5 (Phase 2) agree row-for-row on which words are content
      (`lean4`/`formal`/`general`) and which are formatting (`latex`/`typst`).
- [ ] Confirm the source-store boundary held: `git diff --name-only` lists only paths under
      `agent-system/extensions/**` and `specs/**`.

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts the complete modified-file set for the task is the eleven
source-store files enumerated across Phases 1-6. Confirm at implementation time against
`git diff --name-only -- agent-system/`; any file outside that enumeration must be explained in the
summary or reverted.

**Files to modify**:
- `agent-system/extensions/typst/context/project/typst/standards/textbook-standards.md` - scope note
- `agent-system/extensions/typst/context/project/typst/standards/type-theory-foundations.md` - scope
  note

**Verification**:
- Both standards files carry the scope note and neither contains a task-number reference.
- The content/formatting word assignments in step 4d and `/fix-it` Step 8.5 are consistent: no word
  is assigned to a content type in one and to `latex`/`typst` in the other.
- `git diff --name-only` contains no path beginning with `.claude/`.
- The modified-file set matches the Scope Hypothesis enumeration.

---

## Testing & Validation

- [ ] `jq empty` passes on `latex/manifest.json` and `typst/manifest.json`.
- [ ] Trace check — content + tool description ("prove a theorem, typeset in latex"): 4a no match;
      4b no match (no narrow formatting phrase present); 4d matches the `lean4` content row before
      reaching the latex row. Resolves to a content type.
- [ ] Trace check — pure formatting description ("fix the bibtex style in my latex preamble"): 4b
      matches `bibtex`/`latex style` and short-circuits to `latex`.
- [ ] Trace check — bare tool mention ("fix my typst file"): no 4b phrase match, falls through to
      4d's `typst` row. Resolves to `typst`, the desired behavior for genuinely
      ambiguous-but-likely-formatting requests.
- [ ] Trace check — false-positive regression ("document this function"): the `"document"` keyword
      no longer exists in the 4d latex row, so this no longer resolves to `latex`.
- [ ] Trace check — `/fix-it` QUESTION "why does this lemma need the axiom of choice?": resolves to
      `lean4`, not `latex`.
- [ ] `grep -rn 'theorem' agent-system/extensions/core/skills/skill-fix-it/SKILL.md` shows `theorem`
      only on the `lean4` row.
- [ ] No file under any `.claude/**` tree was created or modified.

## Artifacts & Outputs

- `agent-system/extensions/core/commands/task.md` (steps 4b, 4d, 4e revised)
- `agent-system/extensions/core/skills/skill-fix-it/SKILL.md` (Step 8.5 keyword rows split)
- `agent-system/extensions/core/commands/fix-it.md` (illustrative prose corrected)
- `agent-system/extensions/core/docs/examples/fix-it-flow-example.md` (illustrative prose corrected)
- `agent-system/extensions/latex/manifest.json` (`keyword_overrides` added)
- `agent-system/extensions/typst/manifest.json` (`keyword_overrides` added)
- `agent-system/extensions/latex/agents/latex-implementation-agent.md` (framing)
- `agent-system/extensions/typst/agents/typst-implementation-agent.md` (framing)
- `agent-system/extensions/latex/EXTENSION.md` (`### Scope` note)
- `agent-system/extensions/typst/EXTENSION.md` (`### Scope` note)
- `agent-system/extensions/core/context/guides/extension-development.md` (`keyword_overrides`
  schema subsection)
- `agent-system/extensions/typst/context/project/typst/standards/textbook-standards.md` (scope note)
- `agent-system/extensions/typst/context/project/typst/standards/type-theory-foundations.md` (scope
  note)
- Implementation summary under `specs/062_restrict_typst_latex_task_types_to_formatting_only/summaries/`,
  including the follow-up recommendation from Phase 6.

## Rollback/Contingency

Every change is a source-store text or JSON edit under `agent-system/extensions/**`, committed
per-substep, so `git revert` of the phase commit restores prior routing exactly. No migration, no
state mutation, no generated file is touched.

**Do not run `deploy-headless.sh` or any other regeneration as part of this implementation.** That
script's own header names exactly one sanctioned automated caller (`skill-orchestrate`'s inter-cycle
redeploy checkpoint) and states it must never run as a side effect of an unrelated operation. The
deployed `.claude/**` tree therefore stays on the old routing until a deliberate, separately
invoked deploy — which is the intended sequencing, not a gap. All verification in this plan reads
the source store directly and requires no deploy to be meaningful.

If a phase's verification fails, leave that phase `[PARTIAL]` and stop rather than proceeding:
Phases 1-3 each change live routing behavior, and a half-applied ordering change to the 4d table is
worse than no change at all.

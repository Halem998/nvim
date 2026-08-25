# Report: Restrict `typst`/`latex` task types to formatting-only concerns

- **Task**: 62 - Restrict typst and latex task types to formatting-only concerns
- **Started**: 2026-08-25T00:00:00Z
- **Completed**: 2026-08-25T01:10:00Z
- **Effort**: ~1.5 hours (research)
- **Dependencies**: None
- **Sources/Inputs**:
  - `agent-system/extensions/core/commands/task.md` (step 4a-4e routing chain)
  - `agent-system/extensions/latex/manifest.json`, `agent-system/extensions/typst/manifest.json`
  - `agent-system/extensions/email/manifest.json`, `cslib/manifest.json`, `literature/manifest.json`
    (existing `keyword_overrides` schema examples)
  - `agent-system/extensions/core/skills/skill-fix-it/SKILL.md`, `commands/fix-it.md`,
    `docs/examples/fix-it-flow-example.md`
  - `agent-system/extensions/latex/EXTENSION.md`, `typst/EXTENSION.md`, and both extensions'
    implementation-agent `.md` files
  - `agent-system/extensions/core/context/guides/extension-development.md`,
    `merge-sources/claudemd.md`
  - `agent-system/extensions/typst/context/project/typst/standards/{textbook-standards,type-theory-foundations}.md`
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Problem

The `typst` and `latex` task types are currently assigned to any description that merely
*mentions* the tool ("latex", "typst", "tex"), or that hits the overly generic word "document",
regardless of whether the work is about document **formatting/typesetting** (compilation, macros,
packages, bibliography style, layout, cross-references) or about the **intellectual content**
being formatted (a proof, a theorem, a textbook chapter, a thesis argument). Content-bearing work
should route to a substantive type (`lean4`, `formal`, `general`, etc.) instead.

Three independent routing/documentation surfaces need revision. None of them currently declare
`keyword_overrides` for latex/typst (the task description's premise that these fields already
exist on the extension manifests does not hold — they must be added).

## Finding 1 — `/task` step 4d hardcoded table (primary defect)

`agent-system/extensions/core/commands/task.md:146-149`:

```
**4d. Hardcoded keyword table** (fallback):
- "lean", "lean4", "mathlib", "theorem", "proof" → lean4
- "latex", "tex", "document", "typeset" → latex
- "typst" → typst
```

Problems:
- `"document"` is dangerously generic — it whole-word-matches "please **document** this
  function" or "update the API **document**ation" (the `\b`-anchored regex still matches the
  bare word "document" appearing anywhere), routing pure prose/docs work to `latex`.
- Bare `"latex"`/`"typst"`/`"tex"` mentions do not distinguish "fix the bibliography style in
  latex" (formatting) from "write a proof in latex" (content). Because rows are scanned in table
  order and the latex/typst rows currently have no earlier content-priority interception except
  for the two words already claimed by the lean4 row (`theorem`, `proof`), any other
  content-signal word (`lemma`, `axiom`, `chapter`, `textbook`, `thesis`) falls straight through
  to the latex/typst rows whenever the description also names the tool.
- The doc never states that table-row order is significant/first-match-wins at the row level —
  it currently works for `theorem`/`proof` only because the lean4 row happens to be listed first,
  which is incidental, not documented policy.

### Required revision (task.md step 4d)

1. Drop `"document"` from the latex row entirely (pure false-positive magnet).
2. Extend the lean4 row's keyword list for consistency with Finding 2's fix-it table, and add an
   explicit content-priority block, checked before the latex/tex and typst rows:

```
**4d. Hardcoded keyword table** (fallback, evaluated top-to-bottom — first matching row wins;
content-signal rows are listed before the latex/tex and typst rows so a description naming a
formatting tool alongside mathematical/textual content routes by content, not by tool name):
- "lean", "lean4", "mathlib", "theorem", "proof", "lemma", "axiom", "proposition", "corollary",
  "derivation" → lean4
- "formal", "logic", "math", "physics", "modal", "kripke" → formal   (unchanged; move earlier if
  not already ahead of latex/typst — currently it is listed AFTER latex/typst at line 155; move
  this row up to sit directly after the lean4 row so it also gets content-priority)
- "textbook", "chapter", "thesis", "dissertation" → general
- "latex", "tex" → latex
- "typst" → typst
- ...(rest unchanged)
```
3. Add one sentence documenting the scan-order contract explicitly (quoted above) so future
   editors don't reintroduce the same accidental-ordering trap.

`"typeset"` is a judgment call: it is inherently formatting vocabulary with low false-positive
risk, and can stay. Do not add it back for a keyword outside this exact word.

## Finding 2 — `/fix-it` QUESTION: content-based keyword table (three mirrored copies, most severe)

The actual implementation, `agent-system/extensions/core/skills/skill-fix-it/SKILL.md:443`:

```
- latex: theorem, proof, lemma, axiom, logic, formula, derivation, proposition, corollary, latex, tex
```

This directly maps pure mathematical **content** vocabulary — theorem, proof, lemma, axiom,
logic, formula, derivation, proposition, corollary — to the `latex` task type. It is also
internally inconsistent with `task.md`'s own 4d table, which already routes `theorem`/`proof` to
`lean4`, not `latex`. Two documentation sites mirror the same wrong example in prose:
- `agent-system/extensions/core/commands/fix-it.md:47`: "...latex keywords (theorem, proof,
  lemma, etc.) -> \"latex\"..."
- `agent-system/extensions/core/docs/examples/fix-it-flow-example.md:26`: "...theorem/proof/lemma
  -> latex..."

### Required revision (all three sites, kept consistent with each other and with task.md 4d)

`skill-fix-it/SKILL.md:443`, replace the single `latex:` row with:

```
- lean4: theorem, proof, lemma, axiom, proposition, corollary, derivation
- formal: logic
- latex: latex, tex, bibtex, biblatex, latex macro, latex package, compile error
- typst: typst, typst package, typst compile
- meta: .claude, command, agent, skill, workflow, state.json, TODO.md, specs/
- Default: general
```
(`formula` is ambiguous — a formula can be either mathematical content or a formatting/rendering
question; default it to `general` by omitting it from every row rather than guessing, unless the
plan phase decides otherwise.)

Update `fix-it.md:47` and `fix-it-flow-example.md:26` prose examples to match, e.g. replace
"theorem/proof/lemma -> latex" with "theorem/proof/lemma -> lean4" and add a formatting-example
pairing such as "bibtex/compile error -> latex" so the illustrative example itself demonstrates
the formatting-only boundary instead of contradicting it.

Note: the **file-type-based** detection tables (`todo-task`'s `.tex -> "latex"` in
`skill-fix-it/SKILL.md`, and `review.md`'s `*.tex -> latex` / `*.typ -> typst`) are out of scope
for this fix — they route by which file a tag/diff lives in, not by keyword content, and are a
legitimate, different mechanism.

## Finding 3 — Precedence rule (step 4a) and alias remapping (step 4e)

- **4a (meta keywords, unconditional)**: no change needed. It already runs before everything else
  and is orthogonal to the latex/typst content-vs-formatting problem.
- **4e (extension alias remapping)**: this step remaps an *already-resolved* 4c/4d task_type to a
  different extension's task_type by matching against that extension's declared `aliases` list
  (e.g. cslib claims `lean4`-resolved tasks for itself). It has no mechanism to discriminate *why*
  a task_type resolved to `latex`/`typst` (content word vs. formatting word) — it only sees the
  final string. **It is not a usable lever for this task** and needs no revision; the fix belongs
  entirely in 4b/4d (Findings 1 and 4). Worth one documentation sentence in task.md step 4e
  clarifying this is intentional, so a future editor doesn't try to solve the problem there.

## Finding 4 — `keyword_overrides` additions to the latex/typst manifests

Neither manifest currently declares `keyword_overrides` (confirmed by direct read of both
files). Per the schema already used by `email`, `cslib`, and `literature` manifests
(`{"<task_type>": {"keywords": [...], "aliases": [...]}}`, consumed by task.md step 4b before the
4d fallback ever runs), add narrow, high-precision, formatting-specific phrases — multi-word or
compilation/tooling terms with low collision risk with content vocabulary:

`agent-system/extensions/latex/manifest.json` — add:
```json
"keyword_overrides": {
  "latex": {
    "keywords": [
      "latex formatting", "latex compile", "latex compilation", "latexmk", "pdflatex",
      "bibtex", "biblatex", "latex package", "latex macro", "vimtex", "latex template",
      "tex compile error", "latex style"
    ],
    "aliases": []
  }
}
```

`agent-system/extensions/typst/manifest.json` — add:
```json
"keyword_overrides": {
  "typst": {
    "keywords": [
      "typst formatting", "typst compile", "typst compilation", "typst package",
      "typst template", "typst style", "typst layout", "fletcher diagram"
    ],
    "aliases": []
  }
}
```

Because 4b fires and short-circuits before 4d, this gives genuinely formatting-scoped requests an
early, high-confidence match on precise phrases, while the Finding-1 narrowing of 4d closes the
remaining false-positive surface for bare tool-name mentions that co-occur with content words.
Bare "fix my typst file" with no content signal still correctly falls through to 4d's `"typst"`
row — that is the desired behavior for genuinely ambiguous-but-likely-formatting requests.

## Finding 5 — Extension purpose framing assumes content authorship

`agent-system/extensions/latex/agents/latex-implementation-agent.md:11` and
`agent-system/extensions/typst/agents/typst-implementation-agent.md:11` (Overview + Agent
Metadata Purpose line) both currently read:

> "Implementation agent specialized for Typst/LaTeX **document creation** and compilation."
> "**Purpose**: Execute Typst/LaTeX document **implementations** from plans"

"Document creation" invites content-authoring work being dispatched here. Revise to state the
formatting-only boundary explicitly, e.g.:

> "Implementation agent specialized for Typst/LaTeX document **formatting, structure, and
> compilation** (not authorship of the underlying content)."
> "**Purpose**: Execute Typst/LaTeX document **formatting and structural** changes from plans"

Add a one-line "### Scope" note to both `agent-system/extensions/latex/EXTENSION.md` and
`agent-system/extensions/typst/EXTENSION.md`:

> This extension covers formatting, compilation, styling, and structural concerns for existing
> document content. It does not cover authoring the underlying mathematical, technical, or
> narrative content — route content-creation tasks (proofs, theorems, chapters, textbook prose)
> to `lean4`, `formal`, or `general` as appropriate.

## Finding 6 (flag for planning phase, not a required manifest/keyword edit)

`agent-system/extensions/typst/context/project/typst/standards/textbook-standards.md` and
`.../type-theory-foundations.md` are themselves mathematical-content-authoring standards
(definition-ordering rules, forward-reference prohibition, DTT-vs-set-notation foundational
conventions) bundled inside the typst extension's own context library — i.e. the extension's
context already assumes/encourages full textbook math-content authorship, which is the root cause
pulling content-bearing tasks toward `typst` in the first place, independent of keyword routing.
This is a larger structural question (relocate this content-authoring guidance to a
content-focused extension/context location, vs. re-scope it to formatting-only framing) that the
task description's explicit scope (manifests, keyword table, precedence, alias remapping, docs)
does not mandate resolving here. Recommend the plan phase decide whether to fold this in or spin
it into a follow-up task — flagging it is required by the task description's "any... documentation
that assumes content-bearing work routes to these types" clause, but relocating an entire content
standards library is a materially larger change than the routing fix.

## Finding 7 — 4b's cross-manifest scan order is alphabetical-glob-dependent (latent risk)

`task.md:132` implements the 4b scan as `for manifest in .claude/extensions/*/manifest.json`,
which shell-globs in **alphabetical directory-name order** and breaks on first match. Confirmed
directory listing: `core, cslib, email, epidemiology, filetypes, formal, founder, latex, lean,
literature, memory, nix, nvim, present, python, slidev, typst, web, z3`.

This means `latex` sorts *before* `lean` (`"latex" < "lean"` — the fourth character `t` < `n`... 
actually the divergence is at the second character, `a` < `e`), and `typst` sorts *after*
`python`/`slidev` but *before* `web`/`z3`. If a content-bearing extension (`lean`, `web`, `z3`,
`epidemiology`, `formal`, `founder`, `nix`, `python`) ever gains its own `keyword_overrides` block
in the future — which several currently lack, relying solely on the 4d hardcoded table instead —
a bare or loosely-scoped latex/typst keyword could win the 4b race purely by directory-name
alphabetical accident, independent of which extension's match is semantically more specific.

This is not a live bug today (no other extension besides `email`/`cslib`/`literature` currently
declares `keyword_overrides`, and Finding 4's proposed latex/typst keyword lists are narrow
multi-word phrases with negligible collision risk against math/content vocabulary), but it is a
structural fragility worth documenting rather than leaving implicit. Two options for the plan
phase to weigh, neither required to satisfy this task's stated scope:
- (a) Add one sentence to task.md step 4b's prose stating the glob-order dependency explicitly, as
  a known limitation, so a future extension author scoping new `keyword_overrides` is aware
  first-match-wins is alphabetical, not intent-based.
  (b) as a more robust option than sentence-only, scan latex/typst's `keyword_overrides` in a
  dedicated final sub-step *after* all other manifests' 4b matches have been tried (mirroring
  Finding 1's "content rows before tool rows" ordering fix at the 4d table level) — this would
  make the content-over-formatting precedence structurally guaranteed rather than accidental, at
  the cost of hardcoding `latex`/`typst` by name into task.md's step-4b loop (the same style of
  hardcoding step 4d already uses for its content-domain keyword table).

Recommend documenting (a) at minimum as part of this task's docs revision; defer (b) to the plan
phase as an optional strengthening, since Finding 4's narrow phrase-based keywords already make
the practical collision risk low.

## Finding 8 — dangling `keyword_overrides` schema doc pointer (adjacent doc gap)

The generated root CLAUDE.md (source: `agent-system/extensions/core/merge-sources/claudemd.md:89`)
tells extension authors: "Extensions can register `keyword_overrides` in their manifest.json...
See `.claude/context/guides/extension-development.md` for the keyword_overrides schema." Direct
read of `agent-system/extensions/core/context/guides/extension-development.md` confirms it
contains **zero** occurrences of the string `keyword` anywhere — the schema is not documented
there at all; the only two worked examples in the whole repo are the three manifests that already
use it (`email`, `cslib`, `literature`) and this task's own new latex/typst additions. This is a
pre-existing doc gap, not caused by this task, but it is directly in-scope under the task
description's "any routing or documentation that assumes content-bearing work routes to these
types" clause, since anyone who followed that pointer while adding the Finding 4 keyword_overrides
blocks would find nothing there. Recommend adding a short `## keyword_overrides Schema` section
to `extension-development.md` documenting the `{"<task_type>": {"keywords": [...], "aliases":
[...]}}` shape, the whole-word `\b...\b` matching semantics, and — as a cross-reference — a note
pointing at Finding 7's alphabetical-scan-order caveat so the two gaps are closed together.

## Summary of concrete revision targets

| File | Change |
|---|---|
| `agent-system/extensions/core/commands/task.md` | Drop `"document"` from 4d latex row; move `formal` row and extend `lean4` row ahead of latex/typst rows; add scan-order documentation sentence; add one-line note at 4e that it's not a usable lever here |
| `agent-system/extensions/core/skills/skill-fix-it/SKILL.md` | Replace single `latex:` QUESTION-routing row with separated `lean4`/`formal`/`latex`/`typst`/`meta` rows |
| `agent-system/extensions/core/commands/fix-it.md` | Update illustrative example prose to match corrected table |
| `agent-system/extensions/core/docs/examples/fix-it-flow-example.md` | Update illustrative example prose to match corrected table |
| `agent-system/extensions/latex/manifest.json` | Add `keyword_overrides.latex` with narrow formatting-phrase keywords |
| `agent-system/extensions/typst/manifest.json` | Add `keyword_overrides.typst` with narrow formatting-phrase keywords |
| `agent-system/extensions/latex/agents/latex-implementation-agent.md` | Reword Overview/Purpose to formatting-only framing |
| `agent-system/extensions/typst/agents/typst-implementation-agent.md` | Reword Overview/Purpose to formatting-only framing |
| `agent-system/extensions/latex/EXTENSION.md` | Add explicit Scope note |
| `agent-system/extensions/typst/EXTENSION.md` | Add explicit Scope note |
| `agent-system/extensions/typst/context/project/typst/standards/{textbook-standards,type-theory-foundations}.md` | Flagged for plan-phase decision (relocate vs. re-scope); not a required edit under this task's stated scope |
| `agent-system/extensions/core/commands/task.md` (step 4b) | Add one sentence documenting the alphabetical-glob-order dependency of the cross-manifest scan (Finding 7); optionally hoist latex/typst to a dedicated final sub-step |
| `agent-system/extensions/core/context/guides/extension-development.md` | Add a `## keyword_overrides Schema` section — currently a dangling doc pointer from the generated CLAUDE.md (Finding 8) |

All edits target the source store under `agent-system/extensions/**`, never the deployed
`.claude/**` tree.

## Appendix — Precedence Model After This Revision (informal trace)

```
description mentions BOTH a content word and "latex"/"typst"
  -> 4a meta check (unconditional) -- no change
  -> 4b: scan all keyword_overrides manifests (email, cslib, literature, + new latex/typst
         narrow-phrase blocks) -- narrow latex/typst phrases rarely collide with content words,
         so a content-only description (e.g. "prove a theorem") does not match latex/typst here
  -> 4c: project default_type, if set (unchanged, still short-circuits before 4d)
  -> 4d: hardcoded table, now content rows (lean4/formal, extended) ordered BEFORE latex/tex/typst
         rows (Finding 1) -- "prove a theorem, typeset in latex" now matches the lean4 row first
  -> 4e: alias remap (unchanged; not a usable lever here per Finding 3)
description mentions ONLY "latex"/"typst" with no content signal
  -> falls through to 4d's latex/tex or typst row (or 4b's narrow phrase match if precise enough)
     -- correctly resolves to latex/typst, matching the desired formatting-only behavior
```

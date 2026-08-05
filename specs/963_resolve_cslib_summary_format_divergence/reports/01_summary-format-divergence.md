# Research Report: Task #963

**Task**: 963 - Resolve the cslib implementation-summary format divergence from the core standard
**Started**: 2026-08-05T00:00:00Z
**Completed**: 2026-08-05T00:00:00Z
**Effort**: ~1 hour (research)
**Dependencies**: 972, 974
**Sources/Inputs**: Codebase (agent-system/extensions/**), validate-artifact.sh, summary-format.md, progress-file.md
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The task's own "corrected diagnosis" (findings a/b) is accurate for cslib, but the audit
  (WORK item 4) shows the failure mode is **not cslib-specific**: at least four other
  implementation-terminus agents (`web`, `lean` base variant, `epi`, `founder`) also have zero
  `summary-format.md` reference and fully improvised, non-conforming headings — the task's claim
  that "web" already conforms is **false**.
- `validate-artifact.sh` only flags **missing required sections/metadata fields**; it never
  rejects extra headings. This means `## Plan Deviations` (and, incidentally, `## Verification`)
  cause zero validator errors wherever they appear ALONGSIDE the six required headings. The
  gate-out failures the task describes for cslib come from replacing the required headings
  outright (`## What Was Done` instead of `## What Changed`, etc.), not from adding
  `## Plan Deviations`.
- Recommended decision: **Option (ii)** — formally admit `## Plan Deviations` as a recognized
  optional section in `summary-format.md`. Justification below is evidence-based, not a default.
- Both cslib agents need a direct `@.claude/context/formats/summary-format.md` context reference;
  the hard agent already has one and needs no other change once the standard is amended (its
  "contradiction" dissolves under Option (ii), it does not need a separate fix).
- Audit surfaces a broader systemic pattern worth flagging as follow-up but out of this task's
  named scope: 4 extensions (`epi`, `founder`, `lean` base, `web`) have implementation agents that
  never load `summary-format.md` at all, and a further 4 (`latex`, `python`, `typst`, `z3`) use a
  soft, non-`@`-reference pointer ("see general agent Stage 6 for format") rather than citing the
  standard directly.

## Context & Scope

Task 963 asks to (1) decide whether cslib's `## Plan Deviations` section should be dropped
(folded into `## Decisions`/`## Follow-ups`) or formally admitted into `summary-format.md`,
(2) wire `cslib-implementation-agent.md` to the standard, (3) resolve the hard agent's declared
internal contradiction consistently with the decision, and (4) audit other extension
implementation agents for the same "no reference -> improvised headings" failure mode, since the
task's own framing named four agents (general, nvim, nix, web) as already conforming and that
claim needed verification rather than being assumed.

This report covers only the research investigation and the recommended decision plus its
justification. No files in `agent-system/extensions/**` were modified — implementation is
deferred to `/plan` and `/implement`.

## Findings

### The gate-out validator's actual behavior

`agent-system/extensions/core/scripts/validate-artifact.sh` (deployed as
`.claude/scripts/validate-artifact.sh`, invoked from `skill-base.sh` and
`orchestrator-postflight.sh` for every task type, not cslib-specific):

- `SUMMARY_METADATA=("Task" "Status" "Started" "Completed" "Artifacts" "Standards")` — checked via
  `grep -qF "**${field}**:"` against the whole document (existence anywhere).
- `SUMMARY_SECTIONS=("Overview" "What Changed" "Decisions" "Impacts" "Follow-ups" "References")`
  — checked via `grep -qE "^##+ ${section}"`.
- The loop only `log_error`s on a **missing** required field/section. It never inspects the
  document for headings that are NOT in the required list — so extra headings (`## Plan
  Deviations`, `## Verification`, `## Notes`, etc.) are invisible to the validator and never cause
  errors, regardless of position.
- `--fix` mode only auto-repairs missing **metadata fields** (inserts `- **Field**: TBD`
  placeholders); it never auto-repairs missing sections.

This means the "4 errors, 4 fields auto-repaired" symptom described in the task is a **metadata
field** problem (likely `Task`/`Status`/`Started`/`Completed`/`Artifacts`/`Standards` bullets
missing or malformed) compounding with separate **missing-section** errors from the heading
substitution (`## What Was Done` etc. instead of the six required headings) — not something
`## Plan Deviations` itself would ever trigger. The task's diagnosis (a)/(b) both hold, but the
mechanism by which cslib trips the gate is heading *replacement*, not heading *addition*.

### Finding (a) confirmed: `cslib-implementation-agent.md`

`agent-system/extensions/cslib/agents/cslib-implementation-agent.md`:
- Zero occurrences of `summary-format.md` anywhere in the file.
- Its `## Context References` section lists only `return-metadata-file.md`,
  `phase-closure.md`, and `pre-edit-gate.md` — no summary format at all.
- Its only summary-structure instruction is MUST-DO #16: `**Include `## Plan Deviations` section**
  in implementation summary.` No other heading is specified anywhere in the file — the six
  required headings are never named, so the agent has no basis for choosing them, and improvises
  the observed `## What Was Done` / `## Task Completion Assessment` names.

### Finding (b) confirmed, but the "contradiction" is contingent, not absolute

`agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`:
- `## Context References` DOES list `@.claude/context/formats/summary-format.md` — "Summary
  structure (when creating summary)".
- Stage 6 ("Create Implementation Summary") has no full skeleton dump; it says only: "Write to
  `specs/{NNN}_{SLUG}/summaries/{NN}_{slug}-summary.md`. Include `## Plan Deviations` section
  (required)."
- Because the validator never rejects extra sections, this is only a "contradiction" in the sense
  that the written standard does not *name* `## Plan Deviations` as sanctioned — it is not a
  contradiction the validator would ever surface as an error today. It becomes a real, resolvable
  ambiguity (agent told to write something the standard doesn't document) rather than a live gate
  failure. Formally admitting the section removes the ambiguity outright; no other change to this
  file is needed.

### Evidence for Option (ii): `## Plan Deviations` is already ecosystem convention, not a cslib idiosyncrasy

Audit of every implementation-terminus agent under `agent-system/extensions/*/agents/`:

| Agent | `summary-format.md` ref | `## Plan Deviations` |
|---|---|---|
| `core/general-implementation-agent.md` | direct (3x) | yes — explicit skeleton, positioned after `## Decisions`, before `## Verification`/`## Impacts` |
| `core/general-implementation-hard-agent.md` | direct (1x) | not in this file (delegates deviation annotation to base agent's format) |
| `cslib/cslib-implementation-agent.md` | **none** | mandated (MUST-DO #16), heading unspecified elsewhere |
| `cslib/cslib-implementation-hard-agent.md` | direct (1x) | mandated ("required") |
| `nvim/neovim-implementation-agent.md` | direct (1x) | yes — same skeleton shape as general agent |
| `nix/nix-implementation-agent.md` | direct (1x) | yes — same skeleton shape as general agent |
| `web/web-implementation-agent.md` | **none** | yes, but skeleton diverges further (see below) |
| `latex/latex-implementation-agent.md` | none direct; soft pointer "see general agent Stage 6 for format" | yes |
| `python/python-implementation-agent.md` | none direct; same soft pointer | yes |
| `typst/typst-implementation-agent.md` | none direct; same soft pointer | yes |
| `z3/z3-implementation-agent.md` | none direct; same soft pointer | yes |
| `lean/lean-implementation-agent.md` (base) | **none**, no soft pointer either | mandated (MUST-DO #15), no other heading specified |
| `lean/lean-implementation-hard-agent.md` | direct (1x) | not named in this file |
| `email/email-implementation-agent.md` | direct (1x) | not present |
| `epidemiology/epi-implement-agent.md` | **none** | not present — fully custom domain headings instead |
| `founder/founder-implement-agent.md` | **none** | not present — fully custom domain headings instead |
| `cslib/pr-review-implementation-agent.md` | **none** | not present — different artifact type (`pr-response.md`/`zulip-response.md`), not a `summaries/*.md` gated as type=summary; likely out of scope for this failure mode |

**Count**: 11 of the 16 agents that write a `summaries/*.md`-style artifact either use or mandate
`## Plan Deviations` today (general, general-hard implicitly via base, cslib both, nvim, nix,
web, latex, python, typst, z3, lean-base). It is the dominant convention, not a cslib outlier.
It exists because it binds a distinct, structured concern — the plan-checklist deviation
annotations (`skipped`/`altered`/`deferred`, tied to specific checklist items) — that
`## Decisions` (why a choice was made) and `## Follow-ups` (what remains open) do not
structurally capture. Folding it into either would lose the skipped/altered/deferred taxonomy
that's already wired through the checklist-annotation flow in the four conforming core/extension
agents' Stage 4B/D-ii steps.

**Recommended decision: Option (ii).** Amend `summary-format.md`'s Structure list to add
`## Plan Deviations` as a recognized **optional** section (position: after `## Decisions`, before
`## Impacts`, matching the position already used by every agent above that has an explicit
skeleton), with guidance to use `- None (implementation followed plan)` when empty — this is the
wording every conforming agent already uses. Add `## Plan Deviations` to a new
`SUMMARY_SECTIONS_OPTIONAL` (or equivalent) array in `validate-artifact.sh` for documentation
parity only — no enforcement change is needed since optional/extra sections were never rejected,
but the standard and the validator's comments should stop being silently out of sync with actual
practice.

**Rejecting Option (i)** (fold into `## Decisions`/`## Follow-ups`, drop the heading): this would
require rewriting Stage 4B/D-ii/6 logic in 8+ already-conforming agent files (general, general-hard,
nvim, nix, latex, python, typst, z3) that have converged independently on the current shape, for
no validator benefit (extra sections were never the problem) and a real loss of the structured
skipped/altered/deferred deviation taxonomy. Option (i) would be solving a problem the validator
does not have.

### Web-implementation-agent does NOT conform (correcting the task's premise)

`agent-system/extensions/web/agents/web-implementation-agent.md`:
- Zero occurrences of `summary-format.md`.
- Its own Stage 6 skeleton (lines ~296-331) uses only `**Completed**: {ISO_DATE}` and
  `**Duration**: {time}` as metadata — **missing** `Task`, `Status`, `Started`, `Dependencies`,
  `Artifacts`, `Standards` (5 of 6 required metadata fields absent).
- Structurally it has `## Overview`, `## What Changed`, `## Decisions`, `## Plan Deviations`,
  `## Verification`, then **`## Notes`** where the standard requires `## Impacts`,
  `## Follow-ups`, `## References` (3 of 6 required sections absent, replaced by one nonstandard
  catch-all).
- This agent would trip the same class of gate-out errors cslib does. The task's framing ("the
  four core/extension implementation agents that DO conform (general, nvim, nix, web)") is
  incorrect for web; web should not be used as a conformance reference.

### `lean-implementation-agent.md` (base, non-hard) has the identical (a)-shaped gap

- Zero references to `summary-format.md`, direct or soft.
- No "Create Implementation Summary" stage/skeleton anywhere in the file at all — the only
  summary-structure instruction is MUST-DO #15: "Include `## Plan Deviations` section ... Use
  `- None (implementation followed plan)` when no deviations occurred," with every other heading
  entirely unspecified.
- Notably its hard variant, `lean-implementation-hard-agent.md`, DOES carry a direct
  `summary-format.md` reference. This is the exact same base/hard asymmetry pattern the task
  identified in cslib — it is **not unique to cslib**; at minimum lean shows it too.

### `epi-implement-agent.md` and `founder-implement-agent.md`: same failure class, different domain vocabulary

Both extensions write to a `summaries/`-style path with **zero** `summary-format.md` reference
and fully domain-custom headings that share no names with the standard:
- `epi-implement-agent.md`: `## Scripts Created` / `## Key Results` / `## Data Quality Notes`
  (only `## Overview` coincidentally matches).
- `founder-implement-agent.md`: `## Changes Made` / `## Files Created` / `## Research
  Integration` / `## Key Results` (no heading matches the standard at all).

These were not named in the task's audit item but were discovered by following its own
instruction not to assume scope. They are the same improvisation-into-a-vacuum failure mode as
cslib finding (a), just pre-existing in extensions the task didn't flag.

### `pr-review-implementation-agent.md`: likely a non-issue

This agent's terminal artifacts are `pr-response.md` and `zulip-response.md` under the task
directory, not a `summaries/*.md` file processed as `artifact_type=summary` by
`validate-artifact.sh`. It has a `## Summary` (singular) section as part of a different artifact
shape entirely. Recorded for completeness; not evidence of the same failure mode since it isn't
gated against `SUMMARY_SECTIONS` at all under its normal (non-`sources`) flow.

### `progress-file.md` schema gap (tangential, noted for follow-up only)

`general-implementation-agent.md`'s deviation-recording steps reference "the progress file
`deviations` array (see `.claude/context/formats/progress-file.md` for schema)", but
`progress-file.md`'s documented JSON schema (Schema section, `objectives`/`current_objective`/
`approaches_tried`/`handoff_count`) has **no `deviations` field at all**. This is a separate,
pre-existing documentation gap unrelated to the cslib divergence and out of this task's declared
`file_scope`; flagged here only as a Context Extension Recommendation, not something this task
should fix.

## Decisions

1. **Option (ii)** is the recommended resolution: amend `summary-format.md` to formally list
   `## Plan Deviations` as a recognized optional section (position: between `## Decisions` and
   `## Impacts`), using the `- None (implementation followed plan)` convention already standard
   across conforming agents.
2. `cslib-implementation-agent.md` needs a direct `@.claude/context/formats/summary-format.md`
   Context Reference added (unconditional on the Option (i)/(ii) choice — it needs the reference
   either way to stop improvising `## What Was Done` / `## Task Completion Assessment`).
3. `cslib-implementation-hard-agent.md` needs **no functional change** once `summary-format.md`
   is amended under Option (ii) — its existing reference plus `## Plan Deviations` mandate become
   consistent by construction. (Optional polish: it could gain an explicit inline skeleton like
   the base agent will have, for symmetry, but this is not required to resolve the contradiction.)
4. The audit (WORK item 4) should be reported as scope for a **separate follow-up task**, not
   folded into this task's `file_scope` (which names only the two cslib agent files,
   `summary-format.md`, and `validate-artifact.sh`). The newly discovered non-conforming agents
   (`web`, `lean` base, `epi`, `founder`) and the soft-reference group (`latex`, `python`, `typst`,
   `z3`) are real gaps but touch files outside this task's declared scope and dependencies
   (972, 974).

## Risks & Mitigations

- **Risk**: Amending a shared core standard (`summary-format.md`) could be read as scope creep
  beyond cslib. **Mitigation**: the change is additive-only (one new optional section), backed by
  the fact that 11 of 16 relevant agents already use the section; it formalizes existing practice
  rather than introducing new practice.
- **Risk**: `validate-artifact.sh`'s `SUMMARY_SECTIONS` array is the enforcement source of truth;
  if it's left undocumented as accepting extras, future maintainers might assume extra headings
  are silently unsafe. **Mitigation**: add an explicit code comment (and optionally a
  `SUMMARY_SECTIONS_OPTIONAL` array) noting `## Plan Deviations` is sanctioned, so the script and
  the standard stay in sync going forward.
- **Risk**: Fixing only the two cslib agents leaves 4 other extensions with the identical failure
  mode live. **Mitigation**: explicitly recommend a follow-up task (not this one) covering `web`,
  `lean` base, `epi`, `founder`, and tightening the `latex`/`python`/`typst`/`z3` soft-pointer
  group to direct `@`-references.

## Context Extension Recommendations

- **Topic**: `## Plan Deviations` as a summary section.
  **Gap**: `summary-format.md` does not document it despite majority adoption.
  **Recommendation**: implement Decision 1 above.
- **Topic**: `progress-file.md`'s `deviations` array.
  **Gap**: referenced by `general-implementation-agent.md` but absent from the documented schema.
  **Recommendation**: separate follow-up to add the field to `progress-file.md`'s Schema section.
- **Topic**: Implementation-agent conformance to `summary-format.md`.
  **Gap**: 4 agents (`web`, `lean` base, `epi`, `founder`) have zero reference and fully
  custom headings; 4 more (`latex`, `python`, `typst`, `z3`) use an indirect pointer instead of a
  direct `@`-reference.
  **Recommendation**: separate follow-up task auditing/fixing all extension implementation agents
  against `summary-format.md`, outside this task's `file_scope`.

## Appendix

- Searches: `grep -rn "summary-format.md"` and `grep -rn "Plan Deviations"` across
  `agent-system/extensions/*/agents/*implement*agent*.md`; direct reads of
  `cslib-implementation-agent.md`, `cslib-implementation-hard-agent.md`,
  `general-implementation-agent.md`, `web-implementation-agent.md`,
  `lean-implementation-agent.md`, `epi-implement-agent.md`, `founder-implement-agent.md`,
  `validate-artifact.sh`, `summary-format.md`, `progress-file.md`.
- Full agent inventory enumerated via `find agent-system/extensions -path "*/agents/*.md"`.

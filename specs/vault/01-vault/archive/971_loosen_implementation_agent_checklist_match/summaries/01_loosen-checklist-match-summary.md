# Implementation Summary: Task #971

- **Task**: 971 - Loosen implementation agents' plan-checklist match off the literal `**Task {P}.{N}**:` prefix
- **Status**: [COMPLETED]
- **Started**: 2026-07-29
- **Completed**: 2026-07-29
- **Effort**: ~45 minutes
- **Dependencies**: None
- **Artifacts**: plans/01_loosen-checklist-match.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Rewrote the plan-checklist matching contract in three implementation-agent files so items are
located by their existing item text rather than a literal `**Task {P}.{N}**:` prefix that
`planner-agent.md` never emits. All four phases of the plan completed; the annotation-suffix
vocabulary (`*(completed)*`, `*(deviation: skipped — {reason})*`, etc.) is byte-for-byte
unchanged, em-dashes included.

## Canonical Wording — Location for Downstream Sibling Tasks

**Canonical home**: `agent-system/extensions/core/agents/general-implementation-agent.md`,
section `#### 4B-ii. Check Off Completed Items in Plan File`, specifically the paragraph headed
**"Matching contract (canonical — quote this block verbatim; do not paraphrase it)"** immediately
following the section heading.

The two downstream sibling tasks (cslib implementation agent; hard-mode implementation variants)
should quote that paragraph plus the four numbered steps immediately below it verbatim. Key
points for those follow-ons:
- Use `{existing item text}` as the placeholder denoting whatever text already follows `- [ ]` in
  the plan — never assume a `**Task {P}.{N}**:` prefix or any other title template.
- The six annotation suffixes are unchanged: `*(completed)*`, `*(completed: {brief note})*`,
  `*(in progress)*`, `*(deviation: skipped — {reason})*`, `*(deviation: altered — {what
  changed})*`, `*(deviation: deferred to task {N})*`.
- **Em-dash note for the cslib file**: the canonical wording uses U+2014 (`—`) in the two
  deviation-annotation suffixes that carry one (`skipped — {reason}`, `altered — {what changed}`).
  The cslib implementation agent's existing file uses an ASCII `--` fallback instead in the same
  positions — the downstream task should preserve whichever dash its own file already uses rather
  than churning that file's punctuation to match this one.

## What Changed

- `agent-system/extensions/core/agents/general-implementation-agent.md` — Replaced the Stage
  4B-ii section body with the canonical, prefix-free matching contract (adds a new "Matching
  contract" paragraph, genericizes the two Edit-instruction examples and the three
  deviation-annotation examples to use `{existing item text}`); genericized the three
  Stage 4D-ii step-4 deviation example lines the same way; removed the dangling
  `.claude/rules/plan-format-enforcement.md` cross-reference (that file contains no
  deviation-annotation content).
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` — Genericized the three
  `### When Deviating from Plan Steps` annotation-format lines to `{existing item text}`; added a
  sentence naming the canonical matching contract in the core agent.
- `agent-system/extensions/nix/agents/nix-implementation-agent.md` — Genericized the three step-5
  "Annotate deviations in plan file" annotation lines to `{existing item text}`; added a sentence
  naming the canonical matching contract in the core agent.

## Decisions

- Followed the plan's Canonical Wording block verbatim in the core agent file rather than
  paraphrasing, per the plan's own explicit instruction and the downstream-dependency note in the
  dispatch.
- Left the two `## Plan Deviations` summary-template prose bullets in the core and nix files
  untouched (free prose in the implementation-summary template, not a checklist match), matching
  the plan's Non-Goals.
- Did not edit `planner-agent.md`, `cslib-implementation-agent.md`, the hard-mode implementation
  variants, `web-implementation-agent.md`, or `neovim-implementation-agent.md` — all explicitly
  out of scope per the plan's Non-Goals and Risks sections.

## Plan Deviations

- **Testing & Validation** bullet "Exactly four `**Task {P}.{N}**` occurrences survive" — altered:
  actual count is 7, not 4. All 4 predicted summary-template prose bullets survive unchanged as
  predicted. The other 3 are explanatory-prose mentions of the literal pattern that this plan's
  own instructions required adding: the core file's canonical "Matching contract" paragraph
  (quoted verbatim per the plan's mandate) contains "Do NOT assume a `**Task {P}.{N}**:` prefix
  ...", and the lean/nix pointer sentences the plan's own Phase 2/3 tasks instructed adding both
  say "no `**Task {P}.{N}**:` prefix assumed". None of the 7 surviving occurrences are in
  checklist-matching or annotation-format position — the actual invariant this bullet exists to
  protect — so the bug this task fixes remains fixed; only the raw grep count differs from the
  plan's prediction, for a reason inherent to following the plan's own verbatim-quote requirement.
- **Phase 4 task** "`check-extension-docs.sh` introduces no new failure" — altered: the `core`
  extension reports FAIL, but on 37 pre-existing deploy-drift advisories for literature/zotero
  scripts that were never deployed (`scripts/zotero-*.sh`, `scripts/literature-*.sh`, etc.) — none
  of which this task touches. All 19 other extensions (including `lean` and `nix`) report PASS.
  This failure pre-exists this task's edits and is unrelated to them.

## Verification

- Build: N/A (markdown-only agent-contract edits)
- Tests: N/A
- Files verified: Yes — `git diff` confirms only the intended lines changed in each of the three
  files; all six annotation suffixes are byte-identical across all three files, U+2014 em-dashes
  preserved; `grep -n 'Task {P}\.{N}'` shows zero remaining occurrences in any checklist-matching
  or annotation-format position; `check-task-references.sh` PASSes (0 unexempted occurrences);
  `git status --short` shows no path under `.claude/` modified by this work.

## Impacts

- Future `/implement` runs using the general, lean, or nix implementation agents against plans
  with free-form prose checklist items (the format `planner-agent.md` actually emits) will now
  successfully tick off completed items and annotate deviations, instead of the Edit match
  silently finding nothing.
- The two downstream sibling tasks (cslib implementation agent; hard-mode implementation
  variants) have one named, verbatim-quotable source of truth to copy from, reducing the risk of
  the same brittle prefix assumption reappearing via paraphrase drift.

## Follow-ups

- **Named gap, not fixed here**: `agent-system/extensions/web/agents/web-implementation-agent.md`
  and `agent-system/extensions/nvim/agents/neovim-implementation-agent.md` still carry the same
  brittle literal-`**Task {P}.{N}**:`-prefix idiom and are covered by no task in this cluster.
  This is a real gap recorded for a future follow-up task, not silently absorbed into this one's
  scope.
- The pre-existing `check-extension-docs.sh` core-extension deploy-drift advisory (37 items, all
  literature/zotero scripts never deployed) is unrelated to this task but remains open; resolving
  it is outside this task's scope.

## References

- `specs/971_loosen_implementation_agent_checklist_match/plans/01_loosen-checklist-match.md`
- `specs/971_loosen_implementation_agent_checklist_match/reports/01_loosen-checklist-match.md`

# Implementation Summary: Task #776

**Completed**: 2026-07-01
**Duration**: ~20 minutes

## Overview

Two coupled, documentation-only fixes for `--lit`. Requirement 1 (root cause G3) added a new
greenfield pattern file, `adhoc-navigation-directive.md` (canonical + byte-identical mirror),
that tells the primary/root session how to reproduce skill Stage 4a's literature navigation
conversationally — by directly reusing task-775's two scripts
(`literature-lit-flag-resolve.sh`, `literature-briefing.sh`) with `--orchestrator-mode false`
hardcoded — and registered it in the literature extension's `index-entries.json` for context
discovery. Requirement 2 (root cause G4) finished the CLAUDE.md doc sync task 775 deliberately
left half-done: the merge-source `claudemd.md` Literature Mode section now describes only the
live `literature-briefing.sh` -> `<literature-briefing>` navigate-on-demand model, with the
`TOKEN_BUDGET`/`MAX_FILES` static-dump claim and the orphaned scoping note both removed.

## What Changed

- `.claude/extensions/literature/context/project/literature/patterns/adhoc-navigation-directive.md` — new canonical pattern file (92 lines) documenting the conversational `--lit` navigation procedure: trigger, procedure (mirroring Stage 4a's directive branching with `--orchestrator-mode false`), routing (self-execution vs. subagent dispatch), the non-silence invariant, and sources of truth.
- `.claude/context/project/literature/patterns/adhoc-navigation-directive.md` — byte-identical mirror of the canonical file (verified via `diff`).
- `.claude/extensions/literature/index-entries.json` — added a sibling entry to `agent-exploration.md` for the new pattern file, same `domain`/`subdomain`/`load_when` shape, `line_count: 92` (verified against `wc -l`).
- `.claude/extensions/core/merge-sources/claudemd.md` — rewrote the Literature Mode preamble and "What `--lit` Does" (former lines 313-327) to describe the live `literature-briefing.sh` per-repo/global-corpus model with the `<literature-briefing>` block and "How to Use" footer, dropped `TOKEN_BUDGET`/`MAX_FILES` entirely (citing `--top-n`, default 8, for global-corpus mode only); deleted the orphaned scoping note (former lines 330-333); added a new "Ad-Hoc / Conversational Literature Requests" subsection naming and cross-referencing the new pattern file. The "Interactive Sub-Index Setup Detection" subsection body was left byte-for-byte unchanged (only the preceding scoping note was removed).

## Decisions

- Placed the new "Ad-Hoc / Conversational Literature Requests" subsection between "What `--lit`
  Does" and "Interactive Sub-Index Setup Detection", following the natural reading order: live
  model description -> ad-hoc alternate invocation path -> skill-dispatch-specific
  missing-sub-index decision flow.
- The new pattern file cites Stage 4a (`skill-researcher/SKILL.md` lines 146-278) and
  `literature-lit-flag-resolve.sh` as sources of truth rather than re-deriving classification
  prose, per the drift-mitigation risk in the plan.
- Confirmed only `SUBINDEX_PRESENT`, `GLOBAL_MISSING`, and `PROMPT_NEEDED` are reachable
  directives from the primary session (`LIT_DISABLED` and `AUTONOMOUS_GLOBAL` are excluded by
  construction: `--lit-flag` is always `true` and `--orchestrator-mode` is always `false` in this
  conversational context).

## Plan Deviations

- **Task 3.5** (consistency sweep) altered: the plan named the Memory Extension
  "Literature-Augmented Research" paragraph as an item to reconcile during the sweep, but that
  paragraph resides in `.claude/extensions/memory/EXTENSION.md` — a separate merge-source file,
  not `claudemd.md`. Left unedited per the explicit single-file scope instruction ("only edit the
  merge-source claudemd.md") and the plan's own caveat ("do not expand into other files"). No
  stale tokens were found within `claudemd.md`'s own remaining Literature Mode subsections (the
  "specs/literature/ Directory Convention" subsection was swept clean).

## Verification

- Build: N/A (documentation-only task)
- Tests: N/A
- Canonical vs. mirror pattern files: byte-identical (`diff` exit 0)
- `index-entries.json`: valid JSON (`jq empty` exit 0); new entry present with `line_count: 92`
  matching `wc -l` of the canonical file
- `claudemd.md` re-grep for `literature-retrieve.sh`, `<literature-context>`, `TOKEN_BUDGET`,
  `MAX_FILES`, `Scoping note`: no matches
- `claudemd.md` re-grep for `literature-briefing`: matches confirmed (live model documented)
- Deployed `.claude/CLAUDE.md`: unmodified (`git status --porcelain` empty)
- `bash .claude/scripts/check-extension-docs.sh`: `literature` extension = PASS, `core`
  extension = PASS. Overall summary reports `FAIL: 2 issue(s)`, both attributable to the
  pre-existing `lean` extension's undeployed `skill-lean-research-hard` /
  `skill-lean-implementation-hard` `routing_hard` targets — unrelated to this task, not a
  regression.
- Files verified: Yes

## Notes

Two out-of-scope follow-ups were confirmed still present and are recommended as small
fast-follow tasks (per plan Non-Goals and Phase 4 risk tracking):

1. **Six stale `.claude/extensions/core/skills/*/SKILL.md` mirrors** — task 775 updated only the
   deployed `.claude/skills/*/SKILL.md` copies with the Stage 4a rewrite (directive-based
   `literature-lit-flag-resolve.sh` branching); the extension merge-source mirrors under
   `.claude/extensions/core/skills/` were not updated (verified: 0 occurrences of
   `literature-lit-flag-resolve.sh` across all six mirrors vs. 1 in the deployed
   `skill-researcher/SKILL.md`). A future "Load Core Agent System" sync would revert 775's
   Stage 4a rewrite by re-deploying from these stale sources.
2. **`.claude/context/guides/literature-organization.md`** — shares the identical
   `literature-retrieve.sh` / `TOKEN_BUDGET=4000` stale-model drift that this task fixed in
   `claudemd.md` (verified: still references both at multiple lines). Not named in task 776's
   G3/G4 root causes, so left untouched, but the drift is real and should be fixed to keep the
   guide consistent with the live briefing model.

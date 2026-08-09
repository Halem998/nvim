# Implementation Summary: Task #994

- **Task**: 994 - Fix literature-extension tooling landmines and sync pruning
- **Status**: [COMPLETED]
- **Started**: 2026-08-05
- **Completed**: 2026-08-05
- **Effort**: ~1.5 hours
- **Dependencies**: None (item 2's premise was empirically disproved; see Out-of-Scope Finding below)
- **Artifacts**: plans/01_literature-tooling-doc-fixes.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed two of the task's three items via documentation-only edits to the literature extension's
source store. Item 1 (`zotero-search.sh` multi-term quoting) is now documented, with a single
canonical warning reused verbatim, in all four surfaces an agent or human could copy an
invocation from. Item 3 (`deprecated/README.md` retirement rationale) now records the concrete
schema-mismatch and dependency reasons `zotero-index-add.sh` was quarantined rather than
repaired. Item 2 (deployment hygiene) produced no file edits — its premise was empirically
disproved by research and is recorded below as an out-of-scope finding with a ready-to-use
follow-up task description, per the plan's explicit instruction not to fix it or build any
parallel pruning mechanism.

## What Changed

- `agent-system/extensions/literature/scripts/zotero-search.sh` — added the canonical
  separate-arguments warning (with a "Burgess axioms tense logic" wrong/right example) to both
  USAGE surfaces: the top-of-file comment block and the `show_usage()` heredoc. No change to
  argument parsing, scoring, or exit-code behavior.
- `agent-system/extensions/literature/context/project/literature/patterns/agent-exploration.md`
  — added a new "Two Search Tools: Corpus vs. Zotero Library" section distinguishing
  `literature-search.sh` (local corpus, single quoted query) from `zotero-search.sh` (Zotero
  library, separate-argument terms), carrying the same warning verbatim, and noting the two
  tools compose via `/literature --search`.
- `agent-system/extensions/literature/agents/literature-agent.md` — replaced the ambiguous
  `{terms}` placeholder in the Search-to-Import Pipeline Overview's step 1 with a concrete
  `{term1} {term2} ...` form plus a worked example, and a pointer to `zotero-search.sh --help`
  and `agent-exploration.md` for the full warning. This file is outside the task's declared
  `file_scope` (`agent-system/extensions/literature/scripts/` and
  `agent-system/extensions/literature/context/`); included deliberately per the plan's Scope
  Nuance section as the single most concrete place an agent copies a hand-written invocation
  from.
- `agent-system/extensions/literature/scripts/deprecated/README.md` — expanded the
  `zotero-index-add.sh` bullet with the four-point retirement rationale: the ~20-field vs.
  4-field (`doc_id`/`relevance`/`added`/`source`) schema mismatch, the wrong target file
  (`specs/zotero-index.json` vs. the actual `--lit` consumer's `specs/literature-index.json`),
  the unmet `zot` CLI / nonexistent `/zotero --setup` dependencies, and why retirement was chosen
  over repair. The `zotero-index-remove.sh` bullet, Migration Status, and Removal Policy
  sections are unchanged.
- `agent-system/extensions/literature/scripts/zotero-chunk.sh` and
  `agent-system/extensions/literature/scripts/zotero-attach-chunks.sh` — replaced the stale
  `echo "Run: zotero-index-add.sh $KEY" >&2` hint with a pointer to the live `jq` append pattern
  in `skills/skill-literature/SKILL.md`'s "Sub-Index Management > Add: Append a Document Entry"
  section. Message-text change only; surrounding `if`/`exit 2` control flow unchanged.
- `agent-system/extensions/literature/scripts/literature-normalize-authors.sh` — corrected a
  stale provenance comment (line 9) that cited a `.claude/extensions/...` deploy-time path to
  `zotero-index-add.sh`, which has since been quarantined. Now points at the script's current
  location under `scripts/deprecated/` and that directory's README.md. See Plan Deviations.

## Decisions

- Reused the Phase 1 canonical warning wording verbatim in Phases 2 and 3 rather than
  paraphrasing, so the four surfaces make an identical claim and carry an identical example —
  eliminates any risk of the warnings drifting apart or contradicting each other.
- Kept `zotero-search.sh`'s runtime behavior completely untouched (documentation-only diff),
  verified by confirming every changed line in the phase-1 commit lies inside the comment block
  or the heredoc.

## Plan Deviations

- **Phase 5** altered: the plan's Scope Hypothesis anticipated exactly two
  `Run: zotero-index-add.sh $KEY` hint strings outside `deprecated/`
  (`zotero-chunk.sh`, `zotero-attach-chunks.sh`) and explicitly instructed "if more appear, fix
  all of them and record the actual count." A third hit was found:
  `literature-normalize-authors.sh:9`, a provenance comment (not a runtime hint) citing a stale
  `.claude/extensions/literature/scripts/zotero-index-add.sh:142-148` path. Fixed it to point at
  the script's current quarantined location under `scripts/deprecated/` rather than leaving a
  reference to a path that no longer exists. Actual hit count: 3.

## Out-of-Scope Finding: Deploy-Engine Legacy Migration Gap (Item 2)

**This produced no file edits. Its premise was empirically disproved by research, and its
actual remediation lies outside this task's file scope.**

**Root cause**: `detect_legacy_core()` in `lua/neotex/plugins/ai/shared/extensions/init.lua`
migrates only the `core` extension from a repo bootstrapped under the retired glob-based deploy
engine into the new manifest-driven state system. No equivalent detection exists for any other
extension, and both `manager.resync_all()` and `manager.wipe()` -> `manager.regenerate()`
operate exclusively over the root `.claude-extensions.json` state file — never the
per-`base_dir` `.claude/extensions.json`, which does still correctly list the other extensions
that were active.

**Both empirical failure modes** (reproduced against scratch copies of a real downstream repo
with no root `.claude-extensions.json`):

- `deploy-headless.sh --wipe <repo>` reports "Wiped and regenerated 0 extension(s)" and leaves
  `.claude/` **completely absent**. `manager.wipe` deletes the tree unconditionally, then
  `manager.regenerate` reloads only extensions listed in the (nonexistent) root state file.
- `deploy-headless.sh <repo>` (default, non-destructive) force-loads only `core`, silently
  dropping every non-core extension's CLAUDE.md contribution — including the literature
  extension's entire "Zotero Integration" section — while leaving the stale
  `zotero-index-add.sh` file and stale generated rows physically untouched.

**Interim warning**: until a fix lands, `deploy-headless.sh --wipe` must not be run against any
repo lacking a root `.claude-extensions.json`, and the stale generated references in such repos
cannot be cleaned up via deploy at all.

**Recommended follow-up task** (ready to use as a `/task` argument; not created by this
implementation — task creation is a user decision):

> Extend the deploy engine's legacy-repo migration from `core`-only to all previously-loaded
> extensions. `detect_legacy_core()` in `lua/neotex/plugins/ai/shared/extensions/init.lua`
> migrates only `core` into the root `.claude-extensions.json`; extensions loaded under the
> retired glob engine are invisible to `manager.resync_all` and `manager.regenerate`. On such a
> repo the default deploy silently drops every non-core extension's CLAUDE.md contribution, and
> `--wipe` deletes `.claude/` and rebuilds nothing. Reconcile from the per-`base_dir`
> `.claude/extensions.json` (which does list them) during migration detection. Until this lands,
> do not run `deploy-headless.sh` in either mode against any repo lacking a root
> `.claude-extensions.json`.

No follow-up task was auto-created; the user should run `/task` with the description above if
they want it tracked.

## Verification

- Build: N/A (documentation-only changes to shell scripts and markdown)
- Tests: N/A (no test suite for this extension's documentation)
- Files verified: Yes — all seven modified files confirmed to exist and contain the expected
  content via targeted `grep`
- `bash -n` passed for all four modified shell scripts (`zotero-search.sh`, `zotero-chunk.sh`,
  `zotero-attach-chunks.sh`, `literature-normalize-authors.sh`)
- `zotero-search.sh --help` prints the warning; `grep -c 'SEPARATE argument'` on the file
  returns 2
- `agent-exploration.md` now mentions `zotero-search.sh` (previously zero hits) and carries the
  same warning
- `deprecated/README.md` names both `specs/zotero-index.json` and `specs/literature-index.json`,
  the `doc_id` 4-field consumer shape, and the `zot`/`/zotero --setup` dependencies;
  `zotero-index-remove.sh`'s sibling bullet, Migration Status, and Removal Policy sections are
  unchanged
- `grep -rn 'zotero-index-add' agent-system/extensions/literature/ --include=*.sh | grep -v
  '/deprecated/'` returns zero matches (post-fix; was 3 pre-fix)
- `git status --short` for all task-994 commits contains zero `.claude/` paths (boundary audit)
- `bash .claude/scripts/check-task-references.sh` passes with 0 unexempted occurrences across
  `agent-system/extensions`, `.opencode`, `lua`, and `.memory`
- `git diff` of `zotero-search.sh` from before phase 1 to the final state shows only additive
  lines inside the comment block and the heredoc — argument parsing, scoring, and exit codes are
  byte-identical
- No file under `agent-system/extensions/literature/scripts/deprecated/` other than `README.md`
  was modified

## Impacts

- An agent or human directly invoking `zotero-search.sh` with a quoted multi-word phrase will
  now see the quoting requirement in `--help` output before hitting the silent-zero-results
  landmine.
- A future reader of `deprecated/README.md` no longer needs to read the retired script's body to
  understand why it was quarantined instead of repaired.
- Two live scripts (`zotero-chunk.sh`, `zotero-attach-chunks.sh`) no longer point users at a
  script that is not deployed; a third stale comment reference was also corrected.
- The deploy-engine legacy-migration defect is now durably recorded in this summary (and was
  already recorded in the plan) with a ready-to-use follow-up task description, rather than
  being lost once this task closes.

## Follow-ups

- User may want to run `/task` with the recommended follow-up description above to track the
  deploy-engine `detect_legacy_core()` fix.
- None of the six modified deliverable files are deployed to any downstream repo by this task;
  a downstream repo's stale generated rows persist until either the deploy-engine defect is
  fixed or a manually-triggered sync succeeds on a repo with a root `.claude-extensions.json`.

## References

- `specs/994_fix_literature_tooling_landmines_and_sync_pruning/plans/01_literature-tooling-doc-fixes.md`
- `specs/994_fix_literature_tooling_landmines_and_sync_pruning/reports/01_literature-tooling-landmines-research.md`

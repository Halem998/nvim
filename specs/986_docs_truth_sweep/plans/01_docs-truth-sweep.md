# Implementation Plan: Task #986

- **Task**: 986 - Docs truth sweep: retire dispatch-agent fiction, dead-script refs, doc consolidation
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: 951, 960, 961, 962, 963, 969, 980, 982, 983, 984, 985, 987, 989, 992 (all landed)
- **Research Inputs**: specs/986_docs_truth_sweep/reports/01_docs-truth-sweep-findings.md
- **Artifacts**: plans/01_docs-truth-sweep.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Make the documentation layer stop describing machinery that does not exist, and consolidate the
redundant doc surfaces, editing `agent-system/extensions/**` only. Scope is the 7 live inventory
items confirmed by research (1-7 and 9; item 8 is already resolved and excised) plus three
out-of-inventory findings: a stale `settings.local.json` permission entry, ~13 broken relative
links in `docs/README.md`, and a meta-builder-agent double-load of 931 overlapping validation
lines. The definition of done is the task's three-part verification bar: zero dangling
nonexistent-script references, a clean `check-extension-docs.sh` run with no doc calling
dispatch-agent current, and `merge-sources/claudemd.md` shrunk by >=250 lines with every removed
section landing in a durable home.

### Research Integration

The research report's file:line evidence bounds every edit, so phases below cite it rather than
re-scanning. Four findings materially reshaped this plan:

- **Item 8 excised.** `context/patterns/skill-lifecycle.md` was fully rewritten by a predecessor
  task and already narrates the fix; the "skill-skeleton task" pointer is itself orphaned. No
  phase touches it.
- **Item 7 reframed.** The two agent templates are a deliberate canonical (`context/templates/`)
  vs. tutorial (`docs/templates/`) split, not accidental duplication. A predecessor updated the
  canonical side's frontmatter guidance and left the tutorial side stale. The action is a
  one-directional re-sync preserving the split, NOT a merge-and-redirect.
- **Item 6 estimates corrected.** True narrative is 52 lines (not ~90); the Exemption Taxonomy
  table is actionable enforcement content and stays. Realistic post-trim floor is ~114 lines, not
  ~60. The deploy-gap narrative was verified accurate against current Lua — it moves for
  readability, not because it is wrong.
- **Item 9 must precede item 5.** `context/patterns/context-discovery.md`'s broken jq recipe
  (declares `--arg lang`, references `$task_type`) is fixed using `claudemd.md`'s already-correct
  inline copy as the reference — and item 5 deletes that reference copy. Phase 4 orders these
  two edits within a single phase for exactly this reason.

### Planning-time verification beyond the report

The report flagged item 5's merge mechanism as unverified. It is now confirmed, and the finding
changes item 5's approach substantially:

- Merge sources are wired through `manifest.json`'s **`merge_targets`** object (not `provides`).
  `generate_claudemd()` reads `merge_targets.claudemd.source` per extension and concatenates.
- **Every non-core extension currently uses `EXTENSION.md` as that source; only core uses a
  `merge-sources/` directory.** Literature is no exception (`source: "EXTENSION.md"`,
  `section_id: "extension_literature"`).
- Rule U's 60-line `EXTENSION.md` cap is **manifest-authoritative**: `check_extension_md_length`
  returns early unless `claudemd_source_for` equals literally `EXTENSION.md`
  (`check-extension-docs.sh:773`). Repointing literature's source to `merge-sources/claudemd.md`
  therefore takes literature's `EXTENSION.md` out of Rule U's scope entirely — the task's
  "re-bloat the hardened gate" risk is avoided *by construction*, not by staying under a budget.
- The script's own rationale comment (lines 734-750) records that `core/EXTENSION.md` and
  `slidev/EXTENSION.md` were **deleted rather than trimmed** once they stopped being a declared
  merge source, because a non-source `EXTENSION.md` is dead weight no code path reads. Phase 4
  follows that established precedent for literature.

Two further wiring facts constrain phase ordering:

- `index-entries.json` paths are **context-relative**. No `docs/**` file has an index entry, so
  retiring `docs/architecture/architecture-spec.md` cannot orphan one. Consolidating
  `context/orchestration/*` files **does**, making Rule R/T updates mandatory in that phase.
- Rule R checks `line_count` accuracy for every entry. Any phase editing an indexed `context/`
  file must reconcile line counts, which serializes the phases that touch `index-entries.json`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied in the delegation context; no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Retire the dispatch-agent fiction: 13 references across 5 files, including the 599-line
  `architecture-spec.md` and 4 citations of a spec file that never existed.
- Purge or correct all 17 references to 11 nonexistent scripts across 7 files.
- Collapse three overlapping orchestration validation docs (1,244 lines) into one, ending the
  meta-builder-agent 931-line double-load, with `index-entries.json` rewired.
- Fold `docs/README.md` (263 lines, ~13 broken links, mislabeled "v3.0") into `docs-README.md`.
- Relocate the 162-line `--lit` section out of core's `claudemd.md` into a literature-owned
  merge source, plus four other sections that restate always-loaded files, for >=250 lines removed.
- Fix the broken jq recipe, trim the no-task-references rule to its actionable core, re-sync the
  tutorial agent template, and drop the stale `settings.local.json` permission entry.

**Non-Goals**:
- Rewriting `context/patterns/skill-lifecycle.md` (item 8 — already resolved).
- Merging `context/validation.md` (46L) into the consolidated orchestration doc — research
  confirmed it is a distinct skill-contract concern, `on_demand` only, and the least duplicative.
- Consolidating the two agent templates into one. The two-tier split is deliberate and preserved.
- Any write under `.claude/**`. That tree is a disposable deploy artifact.
- Correcting the deploy-gap narrative's Lua paths — verified current and accurate.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Deleting an indexed `context/` file leaves a dangling `index-entries.json` entry (Rule R/T are hard gates) | H | M | Every phase deleting or resizing an indexed file updates `index-entries.json` in the same phase and runs `generate-context-line-counts.sh --check` plus `check-extension-docs.sh` before closing |
| Concurrent `index-entries.json` edits from parallel phases clobber each other | H | M | Phases touching the index are strictly serialized (1 -> 3 -> 4); only Phase 2, which touches no indexed file, runs parallel |
| Repointing literature's `merge_targets.claudemd.source` silently drops the current 33-line `EXTENSION.md` content from generated CLAUDE.md | H | M | The new merge source must be a superset: current `EXTENSION.md` body first, then the `--lit` section. Phase 4 verification diffs the regenerated CLAUDE.md for both bodies |
| Phase 4's manifest repoint, file creation, and deletion are individually red | M | H | Phase 4 is declared `Commit Mode: atomic-batch`; intermediate per-file states are expected red and stay uncommitted |
| Deleting `architecture-spec.md` breaks inbound links from 4 other docs | M | H | Inbound referrers are enumerated (`docs/README.md`, `docs/docs-README.md`, `docs/architecture/handoff-schema.md`, `docs/architecture/orchestrate-state-machine.md`, `docs/templates/README.md`); all are fixed in the same phase |
| Narrative moved out of the rule file carries task numbers into a deliverable | M | L | Destination is under `specs/`, the one tree where task numbers are permitted; the write-time hook enforces this automatically |
| Consolidated validation doc loses unique content from the 698-line file (which is itself a 3-way merge) | M | M | Phase 3 extracts a heading inventory of all three sources first and checks it off against the result before deleting anything |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 1, 3, and 4 all write
`index-entries.json` and are therefore serialized; Phase 2 touches no indexed file and is the
only genuine parallel opportunity.

---

### Phase 1: Retire dispatch-agent fiction and purge dead script references [COMPLETED]

**Goal**: No document describes `dispatch-agent.sh` as current architecture, no citation points at
the nonexistent `dispatch-agent-spec.md`, and every reference to a nonexistent script is either
removed or explicitly marked as removed.

**Tasks**:
- [x] Retire `docs/architecture/architecture-spec.md` (599 lines). It carries 9 of the 13
      dispatch-agent hits, a full "Component 4: `dispatch_agent()` Function" section, a
      `**File location**: .claude/scripts/dispatch-agent.sh` claim, and 5 dead-script hits
      (`postflight-workflow.sh` x3, `nix-postflight.sh`, `nix-verify.sh`). Prefer outright
      deletion; if any section describes real current machinery, migrate only that content into
      `docs/architecture/system-overview.md` before deleting.
- [x] Fix `docs/architecture/system-overview.md:7`, which asserts the current architecture
      "includes ... dispatch-agent.sh". Remove the claim; do not replace it with a forward
      reference to a retired file.
- [x] Remove the 4 `dispatch-agent-spec.md` citations: 2 in `architecture-spec.md` (resolved by its
      deletion), plus `docs/guides/creating-agents.md` and `docs/templates/README.md`.
- [x] Reword `docs/fork-patterns.md`'s surviving mention so it no longer implies a reader can go
      look at `dispatch-agent.sh`; it already correctly calls the mechanism obsolete.
- [x] Repair inbound links to the retired spec in `docs/architecture/handoff-schema.md`,
      `docs/architecture/orchestrate-state-machine.md`, and `docs/templates/README.md`. Leave
      `docs/README.md` and `docs/docs-README.md` alone — Phase 3 owns those two files.
- [x] Purge the remaining dead-script references, following the "correctly marked removed" style
      of `artifact-linking-todo.md`: `postflight-research.sh` / `postflight-plan.sh` /
      `postflight-implement.sh` in `context/patterns/jq-escaping-workarounds.md` (the recipes are
      uncopyable as written — replace with a working example or delete the block);
      `cleanup-stale-sessions.sh` in `context/orchestration/sessions.md`;
      `validate-context-refs.sh` / `update-context-refs.sh` (5 hits) in
      `docs/guides/context-loading-best-practices.md`; `validate-all-standards.sh` in
      `context/standards/postflight-tool-restrictions.md`; `test-implement-pipeline.sh` in
      `context/standards/shell-script-testing.md`.
- [x] Reconcile `index-entries.json` `line_count` for the four indexed `context/` files edited
      here (`patterns/jq-escaping-workarounds.md`, `orchestration/sessions.md`,
      `standards/postflight-tool-restrictions.md`, `standards/shell-script-testing.md`) by running
      `bash .claude/scripts/generate-context-line-counts.sh --write`.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: Research measured 13 `dispatch-agent`/`dispatch_agent` hits across exactly 5
files (`architecture-spec.md` 9, plus 1 each in `docs/templates/README.md`,
`docs/guides/creating-agents.md`, `docs/fork-patterns.md`,
`docs/architecture/system-overview.md`), 4 `dispatch-agent-spec.md` citations, and 17 dead-script
hits across 7 files spanning 11 script names. Confirm at implementation time by re-running the
grep loop before editing; if any count differs, treat the delta as in-scope and reconcile the
inventory rather than editing only the pre-listed lines.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/architecture-spec.md` - delete (or reduce to
  verified-current content merged elsewhere)
- `agent-system/extensions/core/docs/architecture/system-overview.md` - remove dispatch-agent claim
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - repair inbound link
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - repair inbound link
- `agent-system/extensions/core/docs/templates/README.md` - drop spec citation and `dispatch_agent()` mention
- `agent-system/extensions/core/docs/guides/creating-agents.md` - drop spec citation
- `agent-system/extensions/core/docs/fork-patterns.md` - reword obsolete-mechanism note
- `agent-system/extensions/core/docs/guides/context-loading-best-practices.md` - purge 5 dead-script hits
- `agent-system/extensions/core/context/patterns/jq-escaping-workarounds.md` - fix or drop dead postflight recipes
- `agent-system/extensions/core/context/orchestration/sessions.md` - purge `cleanup-stale-sessions.sh`
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` - purge `validate-all-standards.sh`
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - purge `test-implement-pipeline.sh`
- `agent-system/extensions/core/index-entries.json` - line_count reconciliation only

**Verification**:
- `grep -rn "dispatch-agent\|dispatch_agent" agent-system/extensions/` returns only
  explicitly-marked-removed notes (target: zero unmarked hits).
- `grep -rn "dispatch-agent-spec" agent-system/extensions/` returns zero hits.
- For each of the 11 script names, `grep -rn "<name>" agent-system/extensions/` returns zero hits
  or only marked-removed notes.
- `bash .claude/scripts/generate-context-line-counts.sh --check` reports no mismatches.
- `bash .claude/scripts/check-extension-docs.sh` shows no new findings versus a pre-phase baseline
  run captured before any edit.
- No file under `agent-system/extensions/core/docs/` contains a link to a path that does not exist.

---

### Phase 2: Standalone trims — rule narrative, template re-sync, stale permission [COMPLETED]

**Goal**: The no-task-references rule reads as an actionable constraint rather than a changelog,
the tutorial agent template matches the canonical one's frontmatter guidance, and the stale
`mv` permission entry is gone.

**Tasks**:
- [x] Extract the 52 narrative lines from `rules/no-task-references-in-deliverables.md` into a
      decision record under `specs/` (create `specs/decisions/` if absent; name it for the rule,
      e.g. `no-task-references-enforcement-history.md`). The four blocks are: "Discovered during
      Phase 5 purge" (8L), "Discovered during Phase 10 purge" (9L), "Resolved test case" (8L), and
      the "Deploy-mechanism note" + "second, related class of symptom" run to EOF (27L).
- [x] **Keep** the Exemption Taxonomy table in the rule file. Research confirmed it is the
      enforcement mechanism the rule depends on, not narrative; the task description's ~90-line
      figure wrongly counted it.
- [x] Leave a one-line pointer in the rule file to the decision record so the provenance is not
      lost, phrased with a durable anchor rather than a task number.
- [x] Preserve the deploy-gap narrative's content verbatim on the move. It was verified accurate
      against current Lua (`manager.load` :269, `manager.resync_all` :901, `manager.wipe` :1200);
      do not "correct" paths.
- [x] Re-sync `docs/templates/agent-template.md`'s frontmatter block (currently 94 lines, still
      showing only `model: sonnet` plus tier comments) to match
      `context/templates/agent-template.md` and `docs/reference/standards/agent-frontmatter-standard.md`:
      add `tools` / `disallowedTools` / `mcpServers` documentation and the forbidden-fields list
      (`mode`, `version`, `temperature`, `max_tokens`, `timeout`, `allowed-tools:`,
      `mcp-servers:`, `return_format`).
- [x] **Preserve the two-tier split.** Keep `docs/templates/agent-template.md` as the user-facing
      tutorial and `context/templates/agent-template.md` as canonical; confirm each still names
      the other's role. Do not delete or redirect either.
- [x] Remove the stale allowlist entry
      `"Bash(mv .claude/context/project/repo/self-healing-implementation-details.md .claude/context/repo/)"`
      from `root-files/settings.local.json` (a one-time `mv` of a since-deleted file).
- [x] Confirm `root-files/settings.local.json` still parses as valid JSON after the removal.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Research measured the rule file at 166 lines with exactly 52 lines of true
narrative in 4 blocks, projecting a ~114-line result — explicitly correcting the task
description's "~60-line target" as unachievable without cutting actionable content. Confirm by
re-measuring `wc -l` before and after; if the result lands materially below ~110 lines, stop and
check whether actionable content was removed rather than accepting the smaller number as success.

**Files to modify**:
- `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` - remove 52 narrative lines, add pointer
- `specs/decisions/no-task-references-enforcement-history.md` - new decision record (task numbers permitted here)
- `agent-system/extensions/core/docs/templates/agent-template.md` - frontmatter re-sync
- `agent-system/extensions/core/root-files/settings.local.json` - drop stale `mv` permission entry

**Verification**:
- `wc -l agent-system/extensions/core/rules/no-task-references-in-deliverables.md` is ~110-115.
- The rule file retains its Path Pattern, Principle, Exceptions, Reference Durable Anchors,
  Exemption Taxonomy table, and Enforcement sections.
- `grep -rn "self-healing-implementation-details" agent-system/extensions/` returns zero hits.
- `jq empty agent-system/extensions/core/root-files/settings.local.json` exits 0.
- `diff` of the two templates' frontmatter sections shows the tutorial covers the same field set
  as the canonical, while the surrounding tutorial framing is unchanged.
- The write-time no-task-references hook does not block the rule-file edit.

---

### Phase 3: Consolidate validation docs and fold docs/README.md [COMPLETED]

**Goal**: One orchestration validation doc replaces three, meta-builder-agent no longer loads 931
overlapping lines, and `docs/` has exactly one README that is an accurate directory map.

**Tasks**:
- [x] Extract a heading inventory from all three sources before editing:
      `context/orchestration/validation.md` (698L), `subagent-validation.md` (313L),
      `orchestration-validation.md` (233L). Note that `validation.md` is itself already a 3-way
      merge (Validation Strategy L1-161, `/task` flag validation L161-380, Validation Rules
      Standard L382-692 nearly duplicating `subagent-validation.md`).
- [x] Merge into a single file, deduplicating the shared "Step 1: Validate JSON Structure ->
      Step 2: Validate Required Fields -> Step 3: Validate Status -> Step 4: Validate Session ID
      -> Step 5: Validate Artifacts (CRITICAL)" sequence that all three repeat.
- [x] Delete the two superseded files and check every heading from the inventory off against the
      merged result before deleting.
- [x] **Leave `context/validation.md` (46L) untouched and separate.** It is a distinct
      skill-contract concern (return schema / idempotency), `on_demand` only, and the least
      duplicative of the four.
- [x] Update `index-entries.json`: remove the entries for the two deleted files, update the
      surviving entry's `line_count`, and merge `load_when` so the survivor carries both
      `agents: ["meta-builder-agent"]` and `commands: ["/orchestrate"]` — otherwise `/orchestrate`
      silently loses its validation context.
- [x] Repair inbound references in `context/orchestration/orchestration-core.md`,
      `context/orchestration/delegation.md`, `context/orchestration/orchestration-reference.md`,
      and `context/architecture/system-overview.md`.
- [x] Fold `docs/README.md` (263L) into `docs/docs-README.md` (103L): move over any genuinely
      unique content, then delete `docs/README.md`. It is mislabeled "Version: 3.0", restates
      root CLAUDE.md tables rather than indexing `docs/`, and has ~13 broken relative links — every
      internal link is prefixed `docs/...` despite already living inside `docs/`, and
      `core/docs/docs/` does not exist.
- [x] Update the two `@.claude/docs/README.md` pointers in `merge-sources/claudemd.md` (lines 1
      and 8) and the `.claude/docs/README.md` mention in `core/README.md` to name the surviving
      file.
- [x] Run `generate-context-line-counts.sh --write` to reconcile.

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: Research measured the three orchestration docs at 698 + 313 + 233 = 1,244
lines with a genuine near-identical 5-step sequence in all three, and `docs/README.md` at 263
lines with ~13 broken links. Confirm both by re-measuring `wc -l` and by resolving every relative
link in `docs/README.md` against the filesystem before folding; if substantially fewer than 13
links are broken, re-read the file to check the fold is still warranted on content grounds.

**Files to modify**:
- `agent-system/extensions/core/context/orchestration/validation.md` - becomes the consolidated doc (or is superseded, implementer's choice of survivor)
- `agent-system/extensions/core/context/orchestration/subagent-validation.md` - delete after merge
- `agent-system/extensions/core/context/orchestration/orchestration-validation.md` - delete after merge
- `agent-system/extensions/core/context/orchestration/orchestration-core.md` - repair references
- `agent-system/extensions/core/context/orchestration/delegation.md` - repair references
- `agent-system/extensions/core/context/orchestration/orchestration-reference.md` - repair references
- `agent-system/extensions/core/context/architecture/system-overview.md` - repair references
- `agent-system/extensions/core/index-entries.json` - remove 2 entries, merge load_when, fix line_count
- `agent-system/extensions/core/docs/docs-README.md` - absorb unique content, refresh map
- `agent-system/extensions/core/docs/README.md` - delete
- `agent-system/extensions/core/README.md` - update docs-index pointer
- `agent-system/extensions/core/merge-sources/claudemd.md` - update 2 docs-README pointers

**Verification**:
- `ls agent-system/extensions/core/docs/*.md` shows exactly one README-role file.
- `grep -rn "subagent-validation\|orchestration-validation\|docs/README.md" agent-system/extensions/`
  returns zero references to the deleted files.
- `jq -r '.entries[].path' index-entries.json` contains no path lacking a file on disk (Rule R/T
  precondition).
- `bash .claude/scripts/check-extension-docs.sh` reports zero Rule R and zero Rule T findings.
- The context-discovery query for `meta-builder-agent` returns one validation doc, not two.
- Every heading from the pre-merge inventory is present in the merged file or consciously dropped
  as a verified duplicate.

---

### Phase 4: Relocate merge-source content and fix the jq recipe [COMPLETED]

**Goal**: `merge-sources/claudemd.md` sheds >=250 lines with every removed section in a durable
home, the `--lit` documentation merges into CLAUDE.md only where the literature extension is
loaded, and the always-loaded jq recipe is copy-pasteable.

**Tasks**:
- [x] **Do this first.** Fix `context/patterns/context-discovery.md`'s "Adaptive Context Loading
      (Recommended Pattern)" block: line 196 declares `--arg lang "meta"` while line 203
      references `$task_type`, so copy-pasting yields
      `jq: error: $task_type is not defined at <top-level>`. Use `claudemd.md`'s inline Context
      Discovery copy (lines 518-547, already correct with `--arg task_type`) as the reference
      text — the later steps of this phase delete that reference.
- [x] Create `agent-system/extensions/literature/merge-sources/claudemd.md` as a **superset**: the
      current 33-line `EXTENSION.md` body first, then the 162-line `## Literature Mode (\`--lit\`)`
      section lifted from `merge-sources/claudemd.md` lines 335-496.
- [x] Repoint `agent-system/extensions/literature/manifest.json`'s
      `merge_targets.claudemd.source` from `"EXTENSION.md"` to `"merge-sources/claudemd.md"`,
      keeping `target` and `section_id: "extension_literature"` unchanged.
- [x] Delete `agent-system/extensions/literature/EXTENSION.md`, following the documented precedent
      by which `core/EXTENSION.md` and `slidev/EXTENSION.md` were deleted rather than trimmed once
      they stopped being a declared merge source (`check-extension-docs.sh:734-750`). Because Rule
      U's length check returns early unless the claudemd source is literally `EXTENSION.md`
      (line 773), the repointed literature extension leaves Rule U's scope entirely — the 60-line
      cap is satisfied by construction, not by budget.
- [x] **Do not** park the `--lit` content in `EXTENSION.md`. That is the explicitly forbidden
      approach and would turn the hardened Rule U gate red.
- [x] Remove the `## Literature Mode (\`--lit\`)` section (162 lines) from
      `merge-sources/claudemd.md`.
- [x] Remove the four other sections that restate an always-loaded file, each of which has a
      confirmed durable home; before removing each, verify the home actually covers the content
      and extend the home file if it does not:
      State Synchronization (46L, L139-184) -> `rules/state-management.md` (86L);
      Context Discovery (30L, L518-547) -> `context/patterns/context-discovery.md` (375L);
      Context Architecture (33L, L548-580) -> `context/architecture/context-layers.md` (99L);
      Multi-Task Creation Standards (25L, L589-613) -> `docs/reference/standards/multi-task-creation-standard.md` (469L).
- [x] Leave the 16-line jq Command Safety section (L620-635) in place if removing it would drop
      `claudemd.md` below the point where the remaining prose still reads coherently; the >=250
      target is already met without it.
- [x] Replace each removed section with a one-line pointer to its durable home so no unique
      content and no discoverability is lost.
- [x] Reconcile `index-entries.json` line counts for any `context/` file extended above.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Scope Hypothesis**: Research measured `claudemd.md` at 645 lines with the `--lit` section at
exactly lines 335-496 (162 lines, next heading `## Rules References` at 497), and the four other
relocation candidates at 46 + 30 + 33 + 25 = 134 lines, for 296 removable lines against a >=250
target. Confirm line spans by re-reading before cutting — Phase 3 edits two pointer lines in this
same file, so every line number above may have shifted. Re-derive spans from headings, never from
the numbers quoted here.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/context-discovery.md` - fix jq recipe (first)
- `agent-system/extensions/literature/merge-sources/claudemd.md` - new file (EXTENSION.md body + `--lit` section)
- `agent-system/extensions/literature/manifest.json` - repoint `merge_targets.claudemd.source`
- `agent-system/extensions/literature/EXTENSION.md` - delete
- `agent-system/extensions/core/merge-sources/claudemd.md` - remove 5 sections, add pointers
- `agent-system/extensions/core/rules/state-management.md` - extend if needed
- `agent-system/extensions/core/context/architecture/context-layers.md` - extend if needed
- `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md` - extend if needed
- `agent-system/extensions/core/index-entries.json` - line_count reconciliation

**Verification**:
- `wc -l agent-system/extensions/core/merge-sources/claudemd.md` is <= 395 (645 - 250).
- The corrected jq block in `context-discovery.md` runs successfully when copy-pasted against
  `.claude/context/index.json` and returns a non-empty path list.
- `jq -r '.merge_targets.claudemd.source' agent-system/extensions/literature/manifest.json`
  returns `merge-sources/claudemd.md`, and that file exists.
- `agent-system/extensions/literature/EXTENSION.md` does not exist; `check-extension-docs.sh`
  reports zero Rule U findings and does not flag literature for a missing required file (the
  required-file check is gated on the manifest naming `EXTENSION.md`, line 1318).
- After a deploy regeneration, `.claude/CLAUDE.md` contains both the literature skill/command
  tables and the full `## Literature Mode (\`--lit\`)` section, and core's section no longer
  contains `--lit`.
- Each removed section's unique content is findable in its named durable home.

---

### Phase 5: Verification sweep [NOT STARTED]

**Goal**: The task's three-part verification bar is demonstrably met, with no dangling reference,
no failing gate, and a coherent regenerated CLAUDE.md.

**Tasks**:
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and confirm it exits zero, with
      particular attention to Rule R (line_count accuracy), Rule T (index schema conformance), and
      Rule U (EXTENSION.md length) across all extensions — not just core and literature.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` and confirm all gates pass, including gate 4
      (`check-task-references.sh`), which will scan the trimmed rule file and any content moved
      into it.
- [ ] Run `bash .claude/scripts/generate-context-line-counts.sh --check` and confirm zero
      mismatches across every extension.
- [ ] Dangling-reference sweep: for each of the 11 nonexistent script names, `dispatch-agent`,
      `dispatch-agent-spec.md`, the two deleted validation docs, `docs/README.md`, and
      `literature/EXTENSION.md`, confirm `grep -rn` over `agent-system/extensions/` returns zero
      hits or only explicitly-marked-removed notes.
- [ ] Confirm every `index-entries.json` entry across all extensions resolves to a file on disk,
      and that no `context/` file that agents load is missing an entry it previously had.
- [ ] Regenerate CLAUDE.md via the deploy path and sanity-read it: the literature section carries
      both its tables and the `--lit` documentation, core's section no longer duplicates it, the
      removed sections each leave a working pointer, and no section is orphaned or duplicated.
- [ ] Confirm no file was written under `.claude/**` by this task; all edits are in
      `agent-system/extensions/**` plus the `specs/` decision record.
- [ ] Spot-check that no task-number citation leaked into any deliverable outside `specs/**`.

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts that all prior phases' greps return zero. Treat any
non-zero result as an unfinished predecessor phase to be reopened and fixed, not as a finding to
document and pass over.

**Files to modify**:
- None expected. Any edit needed here indicates an incomplete predecessor phase; make the fix in
  the owning phase's file set and note it.

**Verification**:
- `check-extension-docs.sh` exits 0.
- `verify-deploy.sh` exits 0.
- `generate-context-line-counts.sh --check` reports no mismatches.
- All dangling-reference greps return zero unmarked hits.
- `git status` shows no modified path under `.claude/`.

## Testing & Validation

- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0 with zero Rule R / Rule T / Rule U findings.
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0, gate 4 included.
- [ ] `bash .claude/scripts/generate-context-line-counts.sh --check` reports no mismatches.
- [ ] Zero unmarked hits for all 11 nonexistent script names across `agent-system/extensions/`.
- [ ] Zero hits for `dispatch-agent`, `dispatch_agent`, and `dispatch-agent-spec` outside
      explicitly-marked-removed notes.
- [ ] `merge-sources/claudemd.md` shrinks from 645 to <= 395 lines.
- [ ] Every `index-entries.json` entry resolves to an on-disk file.
- [ ] The corrected `context-discovery.md` jq recipe executes without error when copy-pasted.
- [ ] Regenerated CLAUDE.md contains the `--lit` section exactly once, inside the literature section.
- [ ] No writes under `.claude/**`.

## Artifacts & Outputs

- Deleted: `core/docs/architecture/architecture-spec.md`, `core/docs/README.md`,
  `core/context/orchestration/subagent-validation.md`,
  `core/context/orchestration/orchestration-validation.md`, `literature/EXTENSION.md`.
- Created: `literature/merge-sources/claudemd.md`,
  `specs/decisions/no-task-references-enforcement-history.md`.
- Modified: ~22 files under `agent-system/extensions/core/**`, `literature/manifest.json`,
  `core/index-entries.json`, `core/root-files/settings.local.json`.
- Net effect: ~1,900 lines of fiction, duplication, and misplaced content removed from the
  documentation surface; `merge-sources/claudemd.md` reduced by >=250 lines.

## Rollback/Contingency

All work is confined to git-tracked files under `agent-system/extensions/**` plus one new
`specs/` file, so `git revert` of the phase commits fully restores prior state; the `.claude/`
deploy tree is regenerated from source and needs no separate rollback. If Phase 4's merge-source
repoint misbehaves after regeneration, the minimal fix is to revert
`literature/manifest.json`'s `merge_targets.claudemd.source` to `"EXTENSION.md"` and restore that
file from git — the other four section relocations in that phase are independent and need not be
reverted with it. If the Phase 3 consolidation is found to have dropped unique content, the
pre-merge heading inventory plus the deleted files' git history are sufficient to reconstruct it
without redoing the merge.
